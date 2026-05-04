from __future__ import annotations
import asyncio
import json
import logging
import random
from typing import Optional

from models import Card, CardType, GameState, Player, Room, RoomStatus
from storage import storage

logger = logging.getLogger("kotozryv.engine")

_CAT_TYPES = {
    CardType.CAT_TACO, CardType.CAT_WATERMELON,
    CardType.CAT_BEARD, CardType.CAT_POTATO,
}

def _can_be_noped(card_type: CardType) -> bool:
    return card_type not in (CardType.EXPLODING_KITTEN, CardType.DEFUSE)



async def broadcast(room: Room, event: dict, exclude: Optional[str] = None) -> None:
    connections = storage.get_room_connections(room)
    for player_id, ws in connections.items():
        if player_id == exclude:
            continue
        try:
            await ws.send_str(json.dumps(event))
        except Exception as e:
            logger.warning("Не удалось отправить событие игроку %s: %s", player_id, e)


async def send_to(player_id: str, event: dict) -> None:
    ws = storage.get_ws(player_id)
    if ws and not ws.closed:
        try:
            await ws.send_str(json.dumps(event))
        except Exception as e:
            logger.warning("Не удалось отправить событие %s: %s", player_id, e)


async def send_state(room: Room) -> None:
    if not room.game_state:
        return
    for player in room.players:
        await send_to(player.player_id, {
            "event": "stateUpdate",
            "data": room.game_state.to_dict(for_player_id=player.player_id),
        })


async def send_error(player_id: str, message: str) -> None:
    await send_to(player_id, {"event": "error", "data": {"message": message}})


async def start_game(room: Room) -> None:
    if room.status != RoomStatus.WAITING:
        return
    if len(room.players) < 2:
        return

    room.status = RoomStatus.PLAYING
    room.game_state = GameState(room.players)

    await broadcast(room, {
        "event": "gameStarted",
        "data": {
            "room_id":           room.room_id,
            "player_order":      [p.player_id for p in room.players],
            "current_player_id": room.game_state.current_player.player_id,
        },
    })
    await send_state(room)
    logger.info("Игра началась в комнате %s", room.room_id)



async def handle_action(player_id: str, action: dict) -> None:
    room = storage.get_room_of_player(player_id)
    if not room or not room.game_state:
        await send_error(player_id, "Вы не в активной игровой комнате.")
        return

    gs = room.game_state
    if gs.finished:
        await send_error(player_id, "Игра уже завершена.")
        return

    action_type = action.get("action")

    if action_type == "playNope":
        await _handle_play_nope(room, gs, player_id, action)
        return
    if action_type == "declineNope":
        await _handle_decline_nope(room, gs, player_id)
        return
    if action_type == "comboResponse":
        await _handle_combo_response(room, gs, player_id, action)
        return
    if action_type == "favorResponse":
        await _handle_favor_response(room, gs, player_id, action)
        return

    if gs.current_player.player_id != player_id:
        await send_error(player_id, "Сейчас не ваш ход.")
        return

    if action_type == "playCard":
        await _handle_play_card(room, gs, player_id, action)
    elif action_type == "drawCard":
        await _handle_draw_card(room, gs, player_id)
    elif action_type == "defusePlacement":
        await _handle_defuse_placement(room, gs, player_id, action)
    else:
        await send_error(player_id, f"Неизвестное действие: {action_type}")




NOPE_WINDOW = 5  


async def _start_nope_window(
    room: Room, gs: GameState,
    player: Player, card: Card, action: dict,
    is_combo: bool = False, combo_count: int = 1,
) -> None:
    opponents_have_nope = any(
        CardType.NOPE in (c.card_type for c in p.hand)
        for p in gs.alive_players
        if p.player_id != player.player_id
    )
    if not opponents_have_nope:
        if is_combo:
            await _apply_combo_effect(room, gs, player, card, action)
        else:
            await _apply_card_effect(room, gs, player, card, action)
        if gs.finished:
            await _end_game(room, gs)
            return
        await send_state(room)
        return

    gs._pending_action = {
        "card":          card,
        "player":        player,
        "action_data":   action,
        "is_combo":      is_combo,
        "combo_count":   combo_count,
        "declined":      set(),
        "nope_count":    0,
        "last_actor_id": player.player_id,
    }
    await _broadcast_pending_and_arm_timer(room, gs)


async def _broadcast_pending_and_arm_timer(room: Room, gs: GameState) -> None:
    pending = gs._pending_action
    await broadcast(room, {
        "event": "actionPending",
        "data": {
            "player_id":      pending["player"].player_id,
            "last_actor_id":  pending["last_actor_id"],
            "nope_count":     pending["nope_count"],
            "card":           pending["card"].to_dict(),
            "is_combo":       pending["is_combo"],
            "combo_count":    pending["combo_count"],
            "window_secs":    NOPE_WINDOW,
        },
    })
    task = asyncio.create_task(_nope_timer(room, gs))
    gs._nope_task = task


async def _nope_timer(room: Room, gs: GameState) -> None:
    try:
        await asyncio.sleep(NOPE_WINDOW)
    except asyncio.CancelledError:
        return

    if getattr(gs, "_pending_action", None) is None:
        return
    await _resolve_pending(room, gs)


async def _resolve_pending(room: Room, gs: GameState) -> None:
    pending = getattr(gs, "_pending_action", None)
    if pending is None:
        return

    task = getattr(gs, "_nope_task", None)
    if task:
        task.cancel()

    apply_effect = (pending["nope_count"] % 2 == 0)
    card        = pending["card"]
    player      = pending["player"]
    action_data = pending["action_data"]
    is_combo    = pending["is_combo"]
    _clear_pending(gs)

    if apply_effect:
        if is_combo:
            await _apply_combo_effect(room, gs, player, card, action_data)
        else:
            await _apply_card_effect(room, gs, player, card, action_data)

    await broadcast(room, {
        "event": "actionResolved",
        "data": {"applied": apply_effect},
    })

    if gs.finished:
        await _end_game(room, gs)
        return
    await send_state(room)


def _clear_pending(gs: GameState) -> None:
    for attr in ("_pending_action", "_nope_task"):
        if hasattr(gs, attr):
            delattr(gs, attr)


async def _handle_decline_nope(room: Room, gs: GameState, player_id: str) -> None:

    pending = getattr(gs, "_pending_action", None)
    if not pending:
        return
    if pending["last_actor_id"] == player_id:
        return

    pending["declined"].add(player_id)

    alive_opponents = {
        p.player_id for p in gs.alive_players
        if p.player_id != pending["last_actor_id"]
    }
    if not alive_opponents.issubset(pending["declined"]):
        return

    await _resolve_pending(room, gs)


async def _handle_play_nope(room: Room, gs: GameState, player_id: str, action: dict) -> None:
    pending = getattr(gs, "_pending_action", None)
    if not pending:
        await send_error(player_id, "Нет активного действия для отмены.")
        return

    if pending["last_actor_id"] == player_id:
        await send_error(player_id, "Нельзя нопнуть свой ход.")
        return

    nope_player = next((p for p in gs.players if p.player_id == player_id and p.alive), None)
    if not nope_player:
        await send_error(player_id, "Игрок не найден.")
        return

    card_id = action.get("card_id")
    nope_card = nope_player.take_card(card_id)
    if not nope_card or nope_card.card_type != CardType.NOPE:
        if nope_card:
            nope_player.add_card(nope_card)
        await send_error(player_id, "Карта Нет не найдена.")
        return

    gs.discard.append(nope_card)

    task = getattr(gs, "_nope_task", None)
    if task:
        task.cancel()

    pending["nope_count"]    += 1
    pending["last_actor_id"]  = player_id
    pending["declined"]       = set()

    await broadcast(room, {
        "event": "actionNoped",
        "data": {
            "nope_player_id":   player_id,
            "nope_player_name": nope_player.name,
            "nope_count":       pending["nope_count"],
        },
    })

    await send_state(room)


    others_with_nope = [
        p.player_id[:8] for p in gs.alive_players
        if p.player_id != player_id
           and CardType.NOPE in (c.card_type for c in p.hand)
    ]
    logger.info("После нопа от %s в цепочке (count=%d): остались с Нетью %s",
                player_id[:8], pending["nope_count"], others_with_nope or "никого")

    if not others_with_nope:
        await _resolve_pending(room, gs)
        return

    await _broadcast_pending_and_arm_timer(room, gs)
    logger.info("Окно нопа продолжается, last_actor=%s, count=%d",
                player_id[:8], pending["nope_count"])



async def _handle_play_card(room: Room, gs: GameState, player_id: str, action: dict) -> None:
    player = gs.current_player

    card_ids = action.get("card_ids")
    if isinstance(card_ids, list) and len(card_ids) > 1:
        await _handle_combo_play(room, gs, player, card_ids, action)
        return

    card_id = action.get("card_id")
    card = player.take_card(card_id)
    if not card:
        await send_error(player_id, "Карта не найдена в руке.")
        return
    if not card.card_type.playable:
        player.add_card(card)
        await send_error(player_id, "Эту карту нельзя сыграть напрямую.")
        return

    gs.discard.append(card)

    await broadcast(room, {
        "event": "cardPlayed",
        "data": {"player_id": player_id, "card": card.to_dict()},
    })


    await send_state(room)

    if _can_be_noped(card.card_type):
        await _start_nope_window(room, gs, player, card, action)
    else:
        await _apply_card_effect(room, gs, player, card, action)
        if gs.finished:
            await _end_game(room, gs)
            return
        await send_state(room)




async def _handle_combo_play(
    room: Room, gs: GameState, player: Player, card_ids: list[str], action: dict
) -> None:
    if len(card_ids) not in (2, 3):
        await send_error(player.player_id, "Комбо: 2 или 3 карты.")
        return

    taken: list[Card] = []
    for cid in card_ids:
        c = player.take_card(cid)
        if not c:
            for back in taken:
                player.add_card(back)
            await send_error(player.player_id, f"Карта {cid} не найдена.")
            return
        taken.append(c)

    if not all(c.card_type == taken[0].card_type for c in taken):
        for back in taken:
            player.add_card(back)
        await send_error(player.player_id, "Комбо: карты должны быть одного типа.")
        return
    if taken[0].card_type in (CardType.EXPLODING_KITTEN, CardType.DEFUSE):
        for back in taken:
            player.add_card(back)
        await send_error(player.player_id, "Нельзя использовать эту карту в комбо.")
        return

    for c in taken:
        gs.discard.append(c)

    sample = taken[0]
    await broadcast(room, {
        "event": "cardPlayed",
        "data": {
            "player_id":  player.player_id,
            "card":       sample.to_dict(),
            "is_combo":   True,
            "combo_count": len(taken),
        },
    })

    await send_state(room)

    await _start_nope_window(
        room, gs, player, sample, action,
        is_combo=True, combo_count=len(taken),
    )


async def _apply_combo_effect(
    room: Room, gs: GameState, player: Player, card: Card, action: dict
) -> None:
    combo_count    = action.get("combo_count", 2)
    target_id      = action.get("target_player_id")
    target = next((p for p in gs.players if p.player_id == target_id and p.alive), None)

    if not target or not target.hand:
        await send_error(player.player_id, "Цель недоступна или у неё нет карт.")
        return

    if combo_count == 2:
        gs._pending_combo = {
            "requester_id": player.player_id,
            "target_id":    target_id,
        }
        await send_to(target_id, {
            "event": "comboRequest",
            "data": {
                "requester_id":   player.player_id,
                "requester_name": player.name,
                "your_hand": [c.to_dict(hidden=False) for c in target.hand],
            },
        })

    elif combo_count == 3:
        requested = action.get("requested_card_type")
        if not requested:
            await send_error(player.player_id, "Не указан тип запрашиваемой карты.")
            return
        try:
            req_ct = CardType(requested)
        except ValueError:
            await send_error(player.player_id, "Неизвестный тип карты.")
            return

        stolen = target.take_card_of_type(req_ct)
        if stolen:
            player.add_card(stolen)
            await send_to(player.player_id, {
                "event": "comboStolen",
                "data": {"from_player_id": target_id, "card": stolen.to_dict()},
            })
            await send_to(target_id, {
                "event": "comboLost",
                "data": {"to_player_id": player.player_id, "card_name": stolen.card_type.display_name},
            })
        else:
            await send_to(player.player_id, {
                "event": "comboMiss",
                "data": {"from_player_id": target_id, "requested": requested},
            })

        await broadcast(room, {
            "event": "comboResult",
            "data": {
                "player_id":   player.player_id,
                "target_id":   target_id,
                "combo_count": 3,
                "requested":   requested,
            },
        })


async def _handle_combo_response(room: Room, gs: GameState, player_id: str, action: dict) -> None:
    pending = getattr(gs, "_pending_combo", None)
    if not pending or pending["target_id"] != player_id:
        await send_error(player_id, "Нет активного запроса комбо.")
        return

    requester_id = pending["requester_id"]
    requester = next((p for p in gs.players if p.player_id == requester_id), None)
    target    = next((p for p in gs.players if p.player_id == player_id), None)
    if not requester or not target:
        return

    card_id = action.get("card_id")
    stolen  = target.take_card(card_id) if card_id else None
    if not stolen and target.hand:
        stolen = random.choice(target.hand)
        target.hand.remove(stolen)

    if hasattr(gs, "_pending_combo"):
        del gs._pending_combo

    if not stolen:
        await send_to(requester_id, {
            "event": "comboMiss",
            "data": {"from_player_id": player_id},
        })
    else:
        requester.add_card(stolen)
        await send_to(requester_id, {
            "event": "comboStolen",
            "data": {"from_player_id": player_id, "card": stolen.to_dict()},
        })
        await send_to(player_id, {
            "event": "comboLost",
            "data": {"to_player_id": requester_id, "card_name": stolen.card_type.display_name},
        })

    await broadcast(room, {
        "event": "comboResult",
        "data": {"player_id": requester_id, "target_id": player_id, "combo_count": 2},
    })
    await send_state(room)



async def _apply_card_effect(
    room: Room, gs: GameState, player: Player, card: Card, action: dict
) -> None:
    ct = card.card_type

    if ct == CardType.ATTACK:
        next_idx = gs._next_alive_index()
        gs.players[next_idx].turns_remaining += 1
        player.turns_remaining = 0
        gs.advance_turn()
        await broadcast(room, {"event": "turnEnded", "data": {"player_id": player.player_id}})

    elif ct == CardType.SKIP:
        player.turns_remaining -= 1
        if player.turns_remaining <= 0:
            player.turns_remaining = 1
            gs.current_player_index = gs._next_alive_index()
        await broadcast(room, {"event": "turnEnded", "data": {"player_id": player.player_id}})

    elif ct == CardType.SHUFFLE:
        random.shuffle(gs.deck)
        await broadcast(room, {"event": "deckShuffled", "data": {}})

    elif ct == CardType.SEE_THE_FUTURE:
        top = gs.top_of_deck(3)
        await send_to(player.player_id, {
            "event": "seeTheFuture",
            "data": {"cards": [c.to_dict() for c in top]},
        })

    elif ct == CardType.NOPE:
        await broadcast(room, {"event": "nopeUsed", "data": {"player_id": player.player_id}})

    elif ct == CardType.FAVOR:
        target_id = action.get("target_player_id")
        await _apply_favor(room, gs, player, target_id)

    elif ct in _CAT_TYPES:
        await broadcast(room, {
            "event": "catCardPlayed",
            "data": {"player_id": player.player_id, "card_type": ct.value},
        })


async def _apply_favor(
    room: Room, gs: GameState, player: Player, target_id: Optional[str]
) -> None:
    if not target_id:
        await send_error(player.player_id, "Не указана цель для Подлижись.")
        return
    target = next((p for p in gs.players if p.player_id == target_id and p.alive), None)
    if not target or not target.hand:
        await send_error(player.player_id, "Неверная цель или у неё нет карт.")
        return
    gs._pending_favor = {
        "requester_id": player.player_id,
        "target_id":    target_id,
    }
    await send_to(target_id, {
        "event": "favorRequest",
        "data": {
            "requester_id":   player.player_id,
            "requester_name": player.name,
            "your_hand": [c.to_dict(hidden=False) for c in target.hand],
        },
    })


async def _handle_favor_response(room: Room, gs: GameState, player_id: str, action: dict) -> None:
    pending = getattr(gs, "_pending_favor", None)
    if not pending or pending["target_id"] != player_id:
        await send_error(player_id, "Нет активного запроса Подлижись.")
        return

    requester_id = pending["requester_id"]
    requester = next((p for p in gs.players if p.player_id == requester_id), None)
    target    = next((p for p in gs.players if p.player_id == player_id), None)
    if not requester or not target:
        return

    card_id = action.get("card_id")
    stolen  = target.take_card(card_id) if card_id else None
    if not stolen and target.hand:
        stolen = random.choice(target.hand)
        target.hand.remove(stolen)

    if hasattr(gs, "_pending_favor"):
        del gs._pending_favor

    if stolen:
        requester.add_card(stolen)
        await send_to(requester_id, {
            "event": "favorReceived",
            "data": {"from_player_id": player_id, "card": stolen.to_dict()},
        })
        await send_to(player_id, {
            "event": "favorLost",
            "data": {"to_player_id": requester_id, "card_name": stolen.card_type.display_name},
        })

    await send_state(room)



async def _handle_draw_card(room: Room, gs: GameState, player_id: str) -> None:
    player = gs.current_player
    if not gs.deck:
        await send_error(player_id, "Колода пуста.")
        return

    card = gs.draw_card()
    await broadcast(room, {
        "event": "cardDrawn",
        "data": {"player_id": player_id, "deck_size": len(gs.deck)},
    })

    if card.card_type == CardType.EXPLODING_KITTEN:
        await _handle_exploding_kitten(room, gs, player, card)
    else:
        player.add_card(card)
        await send_to(player_id, {
            "event": "cardReceived",
            "data": {"card": card.to_dict()},
        })
        gs.advance_turn()
        await broadcast(room, {"event": "turnEnded", "data": {"player_id": player_id}})
        if gs.finished:
            await _end_game(room, gs)
            return

    await send_state(room)



async def _handle_exploding_kitten(
    room: Room, gs: GameState, player: Player, bomb: Card
) -> None:
    await broadcast(room, {
        "event": "explodingKittenDrawn",
        "data": {"player_id": player.player_id},
    })
    defuse = player.take_card_of_type(CardType.DEFUSE)
    if defuse:
        gs.discard.append(defuse)
        await broadcast(room, {"event": "defuseUsed", "data": {"player_id": player.player_id}})
        await send_to(player.player_id, {
            "event": "defuseRequested",
            "data": {
                "bomb_card_id": bomb.id,
                "deck_size":    len(gs.deck),
                "options":      ["top", "bottom", "random"],
            },
        })
        gs._pending_bomb = bomb
    else:
        player.alive = False
        await broadcast(room, {"event": "playerEliminated", "data": {"player_id": player.player_id}})
        alive = gs.alive_players
        if len(alive) == 1:
            gs.winner = alive[0]
            gs.finished = True
            await _end_game(room, gs)
        else:
            gs.current_player_index = gs._next_alive_index()
            gs.current_player.turns_remaining = 1


async def _handle_defuse_placement(
    room: Room, gs: GameState, player_id: str, action: dict
) -> None:
    bomb: Optional[Card] = getattr(gs, "_pending_bomb", None)
    if not bomb:
        await send_error(player_id, "Нет ожидающей бомбы.")
        return
    position = action.get("position", "random")
    if position not in ("top", "bottom", "random"):
        position = "random"
    gs.insert_card_at(bomb, position)
    del gs._pending_bomb
    await broadcast(room, {
        "event": "explodingKittenPlaced",
        "data": {"player_id": player_id, "position": position, "deck_size": len(gs.deck)},
    })
    gs.advance_turn()
    await broadcast(room, {"event": "turnEnded", "data": {"player_id": player_id}})
    if gs.finished:
        await _end_game(room, gs)
        return
    await send_state(room)




async def _end_game(room: Room, gs: GameState) -> None:
    room.status = RoomStatus.FINISHED
    await broadcast(room, {
        "event": "gameFinished",
        "data": {
            "winner_id":   gs.winner.player_id if gs.winner else None,
            "winner_name": gs.winner.name if gs.winner else "Никто",
        },
    })
    logger.info("Игра завершена в комнате %s. Победитель: %s",
                room.room_id, gs.winner.name if gs.winner else "—")




async def handle_disconnect(player_id: str) -> None:
    room = storage.get_room_of_player(player_id)
    if not room:
        return
    player = room.get_player(player_id)
    if player:
        player.alive = False
    await broadcast(room, {
        "event": "playerLeft",
        "data": {"player_id": player_id},
    }, exclude=player_id)
    gs = room.game_state
    if gs and not gs.finished:
        task = getattr(gs, "_nope_task", None)
        if task:
            task.cancel()
        alive = gs.alive_players
        if len(alive) == 1:
            gs.winner = alive[0]
            gs.finished = True
            await _end_game(room, gs)
        elif gs.current_player.player_id == player_id and alive:
            gs.current_player_index = gs._next_alive_index()
            await send_state(room)
    storage.remove_player(player_id)
