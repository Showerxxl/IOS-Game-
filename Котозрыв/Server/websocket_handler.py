from __future__ import annotations
import asyncio
import json
import logging

from aiohttp import web, WSMsgType
from storage import storage
from game_engine import handle_action, handle_disconnect

logger = logging.getLogger("kotozryv.ws")


async def websocket_handler(request: web.Request) -> web.WebSocketResponse:
    player_id = request.rel_url.query.get("player_id")
    room_id    = request.rel_url.query.get("room_id")

    if not player_id or not room_id:
        raise web.HTTPBadRequest(text="Нужны параметры player_id и room_id.")

    room = storage.get_room(room_id)
    if not room:
        raise web.HTTPNotFound(text="Комната не найдена.")

    player = room.get_player(player_id)
    if not player:
        raise web.HTTPForbidden(text="Игрок не найден в данной комнате. Сначала вызовите /join.")

    ws = web.WebSocketResponse(heartbeat=30)
    await ws.prepare(request)

    storage.register_ws(player_id, ws)
    logger.info("WS: %s (%s) подключился к комнате %s", player.name, player_id[:8], room_id)

    await ws.send_str(json.dumps({
        "event": "connected",
        "data":  {
            "player_id": player_id,
            "room_id":   room_id,
            "message":   f"Добро пожаловать, {player.name}!",
        },
    }))

    try:
        async for msg in ws:
            if msg.type == WSMsgType.TEXT:
                await _process_message(player_id, msg.data)
            elif msg.type == WSMsgType.ERROR:
                logger.warning("WS ошибка от %s: %s", player_id[:8], ws.exception())
            elif msg.type in (WSMsgType.CLOSE, WSMsgType.CLOSING, WSMsgType.CLOSED):
                break
    except asyncio.CancelledError:
        pass
    finally:
        logger.info("WS: %s (%s) отключился", player.name, player_id[:8])
        await handle_disconnect(player_id)

    return ws


async def _process_message(player_id: str, raw: str) -> None:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        ws = storage.get_ws(player_id)
        if ws:
            await ws.send_str(json.dumps({
                "event": "error",
                "data":  {"message": "Неверный JSON."},
            }))
        return

    if "action" not in data:
        ws = storage.get_ws(player_id)
        if ws:
            await ws.send_str(json.dumps({
                "event": "error",
                "data":  {"message": "Отсутствует поле 'action'."},
            }))
        return

    await handle_action(player_id, data)


def setup_websocket(app: web.Application) -> None:
    app.router.add_get("/ws", websocket_handler)
