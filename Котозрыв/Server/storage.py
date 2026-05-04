from __future__ import annotations
from typing import Optional
from aiohttp.web import WebSocketResponse
from models import Room


class Storage:
    def __init__(self):
        self._rooms: dict[str, Room] = {}

        self._connections: dict[str, WebSocketResponse] = {}

        self._player_room: dict[str, str] = {}


    def create_room(self, max_players: int = 5) -> Room:
        room = Room(max_players=max_players)
        self._rooms[room.room_id] = room
        return room

    def get_room(self, room_id: str) -> Optional[Room]:
        return self._rooms.get(room_id)

    def get_room_of_player(self, player_id: str) -> Optional[Room]:
        room_id = self._player_room.get(player_id)
        if room_id:
            return self._rooms.get(room_id)
        return None

    def register_player_in_room(self, player_id: str, room_id: str) -> None:
        self._player_room[player_id] = room_id

    def remove_player(self, player_id: str) -> None:
        self._player_room.pop(player_id, None)
        self._connections.pop(player_id, None)

    def list_waiting_rooms(self) -> list[Room]:
        from models import RoomStatus
        return [r for r in self._rooms.values() if r.status == RoomStatus.WAITING]


    def register_ws(self, player_id: str, ws: WebSocketResponse) -> None:
        self._connections[player_id] = ws

    def get_ws(self, player_id: str) -> Optional[WebSocketResponse]:
        return self._connections.get(player_id)

    def get_room_connections(self, room: Room) -> dict[str, WebSocketResponse]:
        result = {}
        for player in room.players:
            ws = self._connections.get(player.player_id)
            if ws and not ws.closed:
                result[player.player_id] = ws
        return result


storage = Storage()
