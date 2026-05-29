"""
Движок игры «Котозрыв» для self-play обучения RL-агента.

Класс KotozryvGame реализует полный игровой цикл по тем же правилам,
что и Swift-версия:
  - раздача 7 карт + 1 defuse каждому;
  - exploding kittens и доп. defuse в колоде;
  - ходы: сыграть карту (attack/skip/favor/shuffle/see)/комбо котов/взять карту;
  - attack передаёт ход и удваивает (turnsRemaining);
  - skip завершает ход без взятия;
  - favor/комбо котов крадут карту у соперника;
  - see the future показывает топ-3 карты (приватное знание игрока);
  - взрыв: если есть defuse — котёнок возвращается в колоду, иначе игрок выбывает;
  - nope — реактивная отмена (упрощённая эвристика оппонентов).

Действия игрока выражены дискретным action space (см. ACTIONS ниже).
Решения принимает callback-политика: policy(game, player) -> action_id.
Это позволяет стравливать любые политики (random / heuristic / нейросеть).
"""
from __future__ import annotations

import random
from dataclasses import dataclass, field

from . import cards
from .cards import (
    EXPLODING, DEFUSE, NOPE, ATTACK, SKIP, FAVOR, SHUFFLE, SEE_FUTURE,
    CAT_TYPES, is_cat, can_be_noped,
)

# --- Дискретный набор действий агента (на своём ходу) ---
A_DRAW = 0          # взять карту из колоды (завершает «взятие» хода)
A_ATTACK = 1        # сыграть Attack
A_SKIP = 2          # сыграть Skip
A_FAVOR = 3         # сыграть Favor (украсть карту у соперника)
A_SHUFFLE = 4       # сыграть Shuffle
A_SEE_FUTURE = 5    # сыграть See the Future
A_CAT_PAIR = 6      # сыграть пару одинаковых котов (украсть случайную карту)
A_CAT_TRIO = 7      # сыграть трио одинаковых котов (украсть нужную карту)

NUM_ACTIONS = 8

ACTION_NAMES = {
    A_DRAW: "DRAW",
    A_ATTACK: "ATTACK",
    A_SKIP: "SKIP",
    A_FAVOR: "FAVOR",
    A_SHUFFLE: "SHUFFLE",
    A_SEE_FUTURE: "SEE_FUTURE",
    A_CAT_PAIR: "CAT_PAIR",
    A_CAT_TRIO: "CAT_TRIO",
}

# Карта «действие -> тип карты, которую оно тратит» (для одиночных карт)
_ACTION_CARD = {
    A_ATTACK: ATTACK,
    A_SKIP: SKIP,
    A_FAVOR: FAVOR,
    A_SHUFFLE: SHUFFLE,
    A_SEE_FUTURE: SEE_FUTURE,
}


@dataclass
class PlayerState:
    idx: int
    hand: list[int] = field(default_factory=list)
    alive: bool = True
    turns_remaining: int = 1
    # Приватное знание верхних карт колоды (после See the Future).
    # Список типов сверху вниз; по мере взятия карт укорачивается.
    known_top: list[int] = field(default_factory=list)

    def count(self, card: int) -> int:
        return self.hand.count(card)

    def has(self, card: int) -> bool:
        return card in self.hand

    def remove(self, card: int) -> bool:
        if card in self.hand:
            self.hand.remove(card)
            return True
        return False


class KotozryvGame:
    def __init__(self, num_players: int = 2, rng: random.Random | None = None,
                 enable_nope: bool = True):
        assert 2 <= num_players <= 5
        self.num_players = num_players
        self.rng = rng or random.Random()
        self.enable_nope = enable_nope

        self.players: list[PlayerState] = []
        self.deck: list[int] = []
        self.discard: list[int] = []
        self.current = 0
        self.game_over = False
        self.winner: int | None = None
        self.turn_log: list[dict] = []   # история для коуча/анализа

        self._setup()

    # ------------------------------------------------------------------ setup
    def _setup(self) -> None:
        n = self.num_players
        self.players = [PlayerState(idx=i) for i in range(n)]

        deck = cards.build_base_deck()
        self.rng.shuffle(deck)

        # Раздача: 7 карт из колоды + 1 defuse в руку каждому.
        for p in self.players:
            for _ in range(7):
                if deck:
                    p.hand.append(deck.pop(0))
            p.hand.append(DEFUSE)

        # Доп. defuse и взрывные котята добавляются в колоду.
        deck += [DEFUSE] * cards.defuse_count_for(n)
        deck += [EXPLODING] * cards.exploding_count_for(n)
        self.rng.shuffle(deck)

        self.deck = deck
        self.current = 0

    # -------------------------------------------------------------- utilities
    def alive_players(self) -> list[PlayerState]:
        return [p for p in self.players if p.alive]

    def cur_player(self) -> PlayerState:
        return self.players[self.current]

    def exploding_in_deck(self) -> int:
        return self.deck.count(EXPLODING)

    def danger_score(self) -> float:
        if not self.deck:
            return 0.0
        return self.exploding_in_deck() / len(self.deck)

    def _next_alive_index(self, start: int) -> int:
        idx = start
        for _ in range(self.num_players):
            idx = (idx + 1) % self.num_players
            if self.players[idx].alive:
                return idx
        return start

    def _advance_turn(self) -> None:
        """Аналог endTurn(): тратит один turnsRemaining, иначе передаёт ход."""
        p = self.cur_player()
        if not p.alive:
            p.turns_remaining = 1
            self.current = self._next_alive_index(self.current)
            return
        if p.turns_remaining > 0:
            p.turns_remaining -= 1
        if p.turns_remaining == 0:
            p.turns_remaining = 1
            self.current = self._next_alive_index(self.current)

    # --------------------------------------------------------- legal actions
    def legal_actions(self, p: PlayerState | None = None) -> list[int]:
        p = p or self.cur_player()
        legal = [A_DRAW]  # взять карту можно всегда
        for action, card in _ACTION_CARD.items():
            if action == A_FAVOR:
                # favor имеет смысл только если есть у кого красть
                if p.has(FAVOR) and self._favor_target(p) is not None:
                    legal.append(action)
            elif p.has(card):
                legal.append(action)
        # комбо котов
        if self._best_cat_group(p, 2) is not None and self._cat_target(p) is not None:
            legal.append(A_CAT_PAIR)
        if self._best_cat_group(p, 3) is not None and self._cat_target(p) is not None:
            legal.append(A_CAT_TRIO)
        return legal

    def legal_mask(self, p: PlayerState | None = None) -> list[bool]:
        legal = set(self.legal_actions(p))
        return [a in legal for a in range(NUM_ACTIONS)]

    # ----------------------------------------------------------- target logic
    def _opponents_with_cards(self, p: PlayerState) -> list[PlayerState]:
        return [q for q in self.players
                if q.idx != p.idx and q.alive and q.hand]

    def _favor_target(self, p: PlayerState) -> PlayerState | None:
        opp = self._opponents_with_cards(p)
        if not opp:
            return None
        return max(opp, key=lambda q: len(q.hand))

    _cat_target = _favor_target  # та же логика выбора цели

    def _best_cat_group(self, p: PlayerState, size: int) -> int | None:
        for cat in CAT_TYPES:
            if p.count(cat) >= size:
                return cat
        return None

    # ------------------------------------------------------------- main step
    def play_action(self, action: int) -> None:
        """Выполнить действие текущего игрока. Может НЕ завершать ход
        (favor/shuffle/see/cat-комбо позволяют ходить дальше)."""
        if self.game_over:
            return
        p = self.cur_player()

        if action == A_DRAW:
            self._do_draw(p)
            return

        if action in _ACTION_CARD:
            card = _ACTION_CARD[action]
            if not p.remove(card):
                # нелегально — трактуем как взятие, чтобы не зависнуть
                self._do_draw(p)
                return
            self.discard.append(card)
            noped = self._resolve_nope(card, p)
            if noped:
                # действие отменено; ход продолжается (как в Swift)
                self._log(p, action, noped=True)
                return
            self._apply_single_card(card, p)
            self._log(p, action, noped=False)
            return

        if action in (A_CAT_PAIR, A_CAT_TRIO):
            size = 2 if action == A_CAT_PAIR else 3
            self._play_cat_combo(p, size)
            self._log(p, action, noped=False)
            return

        # неизвестное действие — взять карту
        self._do_draw(p)

    def _apply_single_card(self, card: int, p: PlayerState) -> None:
        if card == ATTACK:
            self._apply_attack(p)
        elif card == SKIP:
            self._advance_turn()  # завершает ход без взятия
        elif card == FAVOR:
            self._apply_favor(p)
        elif card == SHUFFLE:
            self.rng.shuffle(self.deck)
            for q in self.players:
                q.known_top = []
        elif card == SEE_FUTURE:
            p.known_top = list(self.deck[:3])

    def _apply_attack(self, p: PlayerState) -> None:
        leftover = max(0, p.turns_remaining - 1)
        p.turns_remaining = 0
        nxt = self._next_alive_index(self.current)
        self.current = nxt
        self.players[nxt].turns_remaining = leftover + 2

    def _apply_favor(self, p: PlayerState) -> None:
        target = self._favor_target(p)
        if target is None:
            return
        give = self._choose_card_to_give(target)
        if give is not None and target.remove(give):
            p.hand.append(give)

    def _play_cat_combo(self, p: PlayerState, size: int) -> None:
        cat = self._best_cat_group(p, size)
        target = self._cat_target(p)
        if cat is None or target is None:
            return
        for _ in range(size):
            p.remove(cat)
            self.discard.append(cat)
        if not target.hand:
            return
        if size >= 3:
            stolen = self._select_card_to_steal(target)
        else:
            stolen = self.rng.choice(target.hand)
        if target.remove(stolen):
            p.hand.append(stolen)

    # ------------------------------------------------------------- drawing
    def _do_draw(self, p: PlayerState) -> None:
        if not self.deck:
            self._advance_turn()
            return
        card = self.deck.pop(0)
        if p.known_top:
            p.known_top.pop(0)

        if card == EXPLODING:
            if p.has(DEFUSE):
                p.remove(DEFUSE)
                self.discard.append(DEFUSE)
                # вернуть котёнка в колоду (в самый низ — безопасная эвристика)
                self.deck.append(EXPLODING)
                # после defuse ход завершается
                self._advance_turn()
            else:
                p.alive = False
                self.discard.append(EXPLODING)
                self._check_game_over()
                if not self.game_over:
                    self._advance_turn()
        else:
            p.hand.append(card)
            self._advance_turn()

    def _check_game_over(self) -> None:
        alive = self.alive_players()
        if len(alive) <= 1:
            self.game_over = True
            self.winner = alive[0].idx if alive else None

    # --------------------------------------------------------------- nope
    def _resolve_nope(self, card: int, actor: PlayerState) -> bool:
        """Возвращает True, если действие было отменено (нечётное число nope)."""
        if not self.enable_nope or not can_be_noped(card):
            return False
        nope_count = 0
        last_actor = actor
        while nope_count < 8:
            noper = self._ai_decides_nope(card, last_actor)
            if noper is None:
                break
            noper.remove(NOPE)
            self.discard.append(NOPE)
            nope_count += 1
            last_actor = noper
        return nope_count % 2 == 1

    def _ai_decides_nope(self, card: int, except_player: PlayerState):
        """Упрощённая эвристика: соперник может «нетнуть» attack/favor,
        направленные против него, если держит nope."""
        candidates = [q for q in self.players
                      if q.idx != except_player.idx and q.alive and q.has(NOPE)]
        if not candidates:
            return None
        if card == ATTACK:
            nxt = self.players[self._next_alive_index(self.current)]
            if nxt.has(NOPE) and nxt.idx != except_player.idx:
                thr = 0.8 if len(nxt.hand) <= 3 else (0.4 if len(nxt.hand) <= 5 else 0.0)
                if self.rng.random() < thr:
                    return nxt
            return None
        if card == FAVOR:
            weakest = min(candidates, key=lambda q: len(q.hand))
            thr = 0.6 if len(weakest.hand) <= 3 else (0.2 if len(weakest.hand) <= 5 else 0.0)
            if self.rng.random() < thr:
                return weakest
            return None
        return None

    # -------------------------------------------------------- give/steal AI
    def _choose_card_to_give(self, target: PlayerState) -> int | None:
        priority = list(CAT_TYPES) + [SEE_FUTURE, SHUFFLE, SKIP, FAVOR, ATTACK, NOPE, DEFUSE]
        for t in priority:
            if target.has(t):
                return t
        return target.hand[0] if target.hand else None

    def _select_card_to_steal(self, target: PlayerState) -> int:
        priority = [DEFUSE, ATTACK, SKIP, SHUFFLE, FAVOR, SEE_FUTURE, NOPE]
        for t in priority:
            if target.has(t):
                return t
        return target.hand[0]

    # --------------------------------------------------------------- logging
    def _log(self, p: PlayerState, action: int, noped: bool) -> None:
        self.turn_log.append({
            "player": p.idx,
            "action": action,
            "noped": noped,
            "hand_size": len(p.hand),
            "deck_size": len(self.deck),
            "danger": round(self.danger_score(), 3),
        })
