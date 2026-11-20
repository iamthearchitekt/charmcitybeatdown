"""Private two-player WebSocket rooms for Charm City Beatdown."""

import asyncio
import json
import os
import re
import secrets
from dataclasses import dataclass, field
from http import HTTPStatus
from urllib.parse import urlsplit

from websockets.asyncio.server import ServerConnection, serve
from websockets.exceptions import ConnectionClosed

ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
CODE = re.compile(r"[A-HJ-NP-Z2-9]{8}")
ROOM_LIMIT = 128
INVITE_LIFETIME = 600


@dataclass
class Room:
    code: str
    host: ServerConnection
    guest: ServerConnection | None = None
    paired: asyncio.Event = field(default_factory=asyncio.Event)
    expiry: asyncio.Task | None = None
    closed: bool = False


async def notice(socket: ServerConnection, kind: str, **fields):
    await socket.send(json.dumps({"type": kind, **fields}, separators=(",", ":")))


class Relay:
    def __init__(self, invite_lifetime=INVITE_LIFETIME):
        self.rooms: dict[str, Room] = {}
        self.invite_lifetime = invite_lifetime

    def new_room(self, socket: ServerConnection) -> Room:
        code = "".join(secrets.choice(ALPHABET) for _ in range(8))
        while code in self.rooms:
            code = "".join(secrets.choice(ALPHABET) for _ in range(8))
        room = Room(code, socket)
        self.rooms[code] = room
        return room

    async def expire(self, room: Room):
        await asyncio.sleep(self.invite_lifetime)
        if room.guest is None:
            await self.end(room, "expired")

    async def end(self, room: Room, reason: str, departing=None):
        if room.closed:
            return
        room.closed = True
        self.rooms.pop(room.code, None)
        room.paired.set()
        if room.expiry is not None and room.expiry is not asyncio.current_task():
            room.expiry.cancel()
        sockets = [socket for socket in (room.host, room.guest) if socket is not None]
        await asyncio.gather(
            *(notice(socket, "error", reason=reason) for socket in sockets if socket is not departing),
            return_exceptions=True,
        )
        await asyncio.gather(*(socket.close() for socket in sockets), return_exceptions=True)

    @staticmethod
    async def reject(socket: ServerConnection, reason: str):
        await notice(socket, "error", reason=reason)
        await socket.close()

    async def handle(self, socket: ServerConnection):
        path = urlsplit(socket.request.path).path
        room = None
        try:
            if path == "/create":
                if len(self.rooms) >= ROOM_LIMIT:
                    await self.reject(socket, "busy")
                    return
                room = self.new_room(socket)
                room.expiry = asyncio.create_task(self.expire(room))
                await notice(socket, "room", code=room.code)
            elif path.startswith("/join/"):
                code = path.removeprefix("/join/")
                if not CODE.fullmatch(code) or (room_to_join := self.rooms.get(code)) is None:
                    await self.reject(socket, "missing")
                    return
                if room_to_join.guest is not None:
                    await self.reject(socket, "full")
                    return
                room = room_to_join
                room.guest = socket
                room.expiry.cancel()
                await asyncio.gather(notice(room.host, "paired"), notice(socket, "paired"))
                room.paired.set()
            else:
                await self.reject(socket, "missing")
                return

            window = asyncio.get_running_loop().time()
            count = 0
            async for message in socket:
                # Real play sends about sixty small binary packets per player per second.
                now = asyncio.get_running_loop().time()
                if now - window >= 1:
                    window, count = now, 0
                count += 1
                if not isinstance(message, bytes) or not 1 <= len(message) <= 64 or count > 240 or room.guest is None:
                    await self.end(room, "invalid")
                    return
                await room.paired.wait()
                if room.closed:
                    return
                opponent = room.guest if socket is room.host else room.host
                await opponent.send(message)
        except ConnectionClosed:
            pass
        finally:
            if room is not None:
                await self.end(room, "left", departing=socket)


def health_check(socket, request):
    if urlsplit(request.path).path in ("/", "/healthz"):
        return socket.respond(HTTPStatus.OK, "Charm City Beatdown relay\n")
    return None


async def main():
    host = os.environ.get("CCBD_RELAY_HOST", "0.0.0.0")
    port = int(os.environ.get("PORT", "8765"))
    relay = Relay()
    async with serve(
        relay.handle, host, port, process_request=health_check, compression=None,
        max_size=64, max_queue=24, ping_interval=20, ping_timeout=15, close_timeout=3,
    ) as server:
        print(f"Charm City Beatdown relay listening on {host}:{port}", flush=True)
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
