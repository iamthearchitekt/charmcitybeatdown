# Charm City Beatdown online relay

The relay creates private two-player rooms and forwards the fighters' input packets over WebSockets. A waiting code expires after 10 minutes. Closing either player's connection ends the room.

## Deploy

For Cloudflare, run `wrangler deploy --config cloudflare/wrangler.toml` from this directory. The Worker uses one SQLite-backed Durable Object per active room and can run on Workers Free. Use the deployed `workers.dev` host with the `wss://` scheme in `data/online-relay.json`.

The Python relay remains available for a standard WebSocket host:

- Deploy the `relay` directory as a Python web service on Render or another host that supports long-lived WebSockets. Run `pip install -r requirements.txt` to build and `python server.py` to start.
- Run one process and one service instance so both players reach the same rooms. The server listens on the platform's `PORT` and answers health checks at `/healthz`.
- Set `url` in `data/online-relay.json` to the public `wss://` origin before building the Windows playtest and installer. Both builds should point to the same relay. The TLS endpoint is provided by the host or reverse proxy.

## Test locally

In this directory, install the requirements and run `python -m unittest -v`. Start `python server.py`, then from the Godot project run:

```text
godot --headless --script res://tests/online_versus_verify.gd -- ws://127.0.0.1:8765
```
