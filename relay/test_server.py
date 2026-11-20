import asyncio
import json
import unittest

from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

from server import CODE, Relay


class RelayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.relay = Relay(invite_lifetime=0.3)
        self.server = await serve(self.relay.handle, "127.0.0.1", 0)
        self.origin = f"ws://127.0.0.1:{self.server.sockets[0].getsockname()[1]}"

    async def asyncTearDown(self):
        self.server.close()
        await self.server.wait_closed()

    async def message(self, socket):
        return json.loads(await asyncio.wait_for(socket.recv(), timeout=2))

    async def test_room_pair_binary_full_and_disconnect(self):
        async with connect(self.origin + "/create") as host:
            announcement = await self.message(host)
            self.assertEqual(announcement["type"], "room")
            code = announcement["code"]
            self.assertIsNotNone(CODE.fullmatch(code))
            async with connect(self.origin + "/join/" + code) as guest:
                self.assertEqual((await self.message(host))["type"], "paired")
                self.assertEqual((await self.message(guest))["type"], "paired")
                async with connect(self.origin + "/join/" + code) as extra:
                    self.assertEqual((await self.message(extra))["reason"], "full")
                await guest.send(b"\x01\x00\x06")
                self.assertEqual(await host.recv(), b"\x01\x00\x06")
                await host.send(b"\x05\x01")
                self.assertEqual(await guest.recv(), b"\x05\x01")
            self.assertEqual((await self.message(host))["reason"], "left")
        async with connect(self.origin + "/join/" + code) as late:
            self.assertEqual((await self.message(late))["reason"], "missing")

    async def test_expiration(self):
        async with connect(self.origin + "/create") as host:
            code = (await self.message(host))["code"]
            self.assertEqual((await self.message(host))["reason"], "expired")
            with self.assertRaises(ConnectionClosed):
                await host.recv()
        self.assertNotIn(code, self.relay.rooms)

    async def test_invalid_message_ends_room(self):
        async with connect(self.origin + "/create") as host:
            code = (await self.message(host))["code"]
            async with connect(self.origin + "/join/" + code) as guest:
                await self.message(guest)
                await self.message(host)
                await guest.send('{"type":"paired"}')
                self.assertEqual((await self.message(host))["reason"], "invalid")
                self.assertEqual((await self.message(guest))["reason"], "invalid")


if __name__ == "__main__":
    unittest.main()
