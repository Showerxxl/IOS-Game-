from __future__ import annotations
import uuid
import logging

from aiohttp import web
from models import Player
from storage import storage
from game_engine import start_game

logger = logging.getLogger("kotozryv.routes")



async def create_room(request: web.Request) -> web.Response:
    body = await request.json() if request.can_read_body else {}
    max_players = int(body.get("max_players", 5))
    max_players = max(2, min(6, max_players))

    room = storage.create_room(max_players=max_players)
    logger.info("Создана комната %s", room.room_id)
    return web.json_response(room.to_dict(), status=201)




async def list_rooms(request: web.Request) -> web.Response:
    rooms = storage.list_waiting_rooms()
    return web.json_response([r.to_dict() for r in rooms])




async def room_info(request: web.Request) -> web.Response:
    room_id = request.match_info["room_id"]
    room = storage.get_room(room_id)
    if not room:
        raise web.HTTPNotFound(text="Комната не найдена.")
    return web.json_response(room.to_dict())



async def join_room(request: web.Request) -> web.Response:
    room_id = request.match_info["room_id"]
    room = storage.get_room(room_id)
    if not room:
        raise web.HTTPNotFound(text="Комната не найдена.")

    from models import RoomStatus
    if room.status != RoomStatus.WAITING:
        raise web.HTTPConflict(text="Игра уже началась или завершена.")

    if len(room.players) >= room.max_players:
        raise web.HTTPConflict(text="Комната заполнена.")

    body = await request.json() if request.can_read_body else {}
    name = str(body.get("name", "Игрок")).strip()[:24] or "Игрок"

    player_id = str(uuid.uuid4())
    player = Player(player_id=player_id, name=name)
    room.players.append(player)
    storage.register_player_in_room(player_id, room_id)

    logger.info("Игрок %s (%s) вошёл в комнату %s", name, player_id[:8], room_id)
    return web.json_response({
        "player_id": player_id,
        "room":      room.to_dict(),
    }, status=200)



async def start_room(request: web.Request) -> web.Response:
    room_id = request.match_info["room_id"]
    room = storage.get_room(room_id)
    if not room:
        raise web.HTTPNotFound(text="Комната не найдена.")

    body = await request.json() if request.can_read_body else {}
    player_id = body.get("player_id")

    if player_id != room.host_id:
        raise web.HTTPForbidden(text="Только хост может запустить игру.")

    if len(room.players) < 2:
        raise web.HTTPBadRequest(text="Нужно минимум 2 игрока.")

    import asyncio
    asyncio.create_task(start_game(room))
    return web.json_response({"status": "starting"})



def setup_routes(app: web.Application) -> None:
    app.router.add_post("/rooms",                   create_room)
    app.router.add_get("/rooms",                    list_rooms)
    app.router.add_get("/rooms/{room_id}",          room_info)
    app.router.add_post("/rooms/{room_id}/join",    join_room)
    app.router.add_post("/rooms/{room_id}/start",   start_room)
