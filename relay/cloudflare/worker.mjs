import { DurableObject } from "cloudflare:workers";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE = /^[A-HJ-NP-Z2-9]{8}$/;
const INVITE_LIFETIME_MS = 600_000;
const CREATE_ATTEMPTS = 6;
const MAX_PACKET_BYTES = 64;
const MAX_PACKETS_PER_SECOND = 240;

function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes, (byte) => ALPHABET[byte & 31]).join("");
}

function notice(socket, type, fields = {}) {
  socket.send(JSON.stringify({ type, ...fields }));
}

function upgraded(socket) {
  return new Response(null, { status: 101, webSocket: socket });
}

function reject(reason) {
  const [client, server] = Object.values(new WebSocketPair());
  server.accept();
  notice(server, "error", { reason });
  server.close(1000);
  return upgraded(client);
}

function roomRequest(request, env, role, code) {
  const room = env.ROOMS.get(env.ROOMS.idFromName(code));
  return room.fetch(new Request(`https://room.internal/${role}/${code}`, request));
}

export default {
  async fetch(request, env) {
    const { pathname } = new URL(request.url);
    if (pathname === "/" || pathname === "/healthz") {
      return new Response("Charm City Beatdown relay\n");
    }
    if (request.method !== "GET" || request.headers.get("Upgrade")?.toLowerCase() !== "websocket") {
      return new Response("WebSocket upgrade required", { status: 426 });
    }
    if (pathname === "/create") {
      for (let attempt = 0; attempt < CREATE_ATTEMPTS; attempt++) {
        const response = await roomRequest(request, env, "host", randomCode());
        if (response.status !== 409) return response;
      }
      return reject("busy");
    }
    if (pathname.startsWith("/join/")) {
      const code = pathname.slice("/join/".length);
      if (CODE.test(code)) return roomRequest(request, env, "guest", code);
    }
    return reject("missing");
  },
};

export class VersusRoom extends DurableObject {
  constructor(ctx, env) {
    super(ctx, env);
    this.ending = false;
    this.rates = new WeakMap();
  }

  active(role) {
    return this.ctx.getWebSockets(role).find((socket) => socket.readyState === WebSocket.OPEN);
  }

  async fetch(request) {
    const [, role, code] = new URL(request.url).pathname.split("/");
    const host = this.active("host");
    const guest = this.active("guest");
    if (role === "host") {
      if (host || guest || this.ending) return new Response(null, { status: 409 });
    } else {
      if (!host || this.ending) return reject("missing");
      if (guest) return reject("full");
    }

    const [client, server] = Object.values(new WebSocketPair());
    this.ctx.acceptWebSocket(server, [role]);
    if (role === "host") {
      try {
        await this.ctx.storage.setAlarm(Date.now() + INVITE_LIFETIME_MS);
        notice(server, "room", { code });
      } catch {
        await this.end("busy");
      }
    } else {
      try {
        notice(host, "paired");
        notice(server, "paired");
        await this.ctx.storage.deleteAlarm();
      } catch {
        await this.end("left");
      }
    }
    return upgraded(client);
  }

  allowed(socket, message) {
    if (!(message instanceof ArrayBuffer) || !message.byteLength || message.byteLength > MAX_PACKET_BYTES) {
      return false;
    }
    const now = Date.now();
    const previous = this.rates.get(socket);
    const rate = previous && now - previous.started < 1000 ? previous : { started: now, count: 0 };
    rate.count++;
    this.rates.set(socket, rate);
    return rate.count <= MAX_PACKETS_PER_SECOND;
  }

  async webSocketMessage(socket, message) {
    if (this.ending) return;
    const role = this.ctx.getTags(socket)[0];
    const other = this.active(role === "host" ? "guest" : "host");
    if (!other || !this.allowed(socket, message)) {
      await this.end("invalid");
      return;
    }
    try {
      other.send(message);
    } catch {
      await this.end("left");
    }
  }

  async webSocketClose(socket) {
    await this.end("left", socket);
  }

  async webSocketError(socket) {
    await this.end("left", socket);
  }

  async alarm() {
    if (!this.active("guest")) await this.end("expired");
  }

  async end(reason, departing) {
    if (this.ending) return;
    this.ending = true;
    for (const socket of this.ctx.getWebSockets()) {
      try {
        if (socket !== departing && socket.readyState === WebSocket.OPEN) {
          notice(socket, "error", { reason });
        }
        socket.close(1000);
      } catch {
        // Closing a socket that already disconnected is harmless.
      }
    }
    await this.ctx.storage.deleteAlarm();
  }
}
