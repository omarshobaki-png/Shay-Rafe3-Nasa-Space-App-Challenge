'use strict';
const { randomInt } = require('node:crypto');
const { WebSocketServer, WebSocket } = require('ws');

const ROLES = ['planner', 'engineer', 'science', 'comms'];
const MAX_BYTES = 64 * 1024;
const IDLE_MS = 30 * 60 * 1000;
const LETTERS = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

// Clock injection lets tests exercise the real 30-minute boundary without waiting.
function createRelay({ port = Number(process.env.PORT || 8080), now = Date.now } = {}) {
  const rooms = new Map();
  const wss = new WebSocketServer({ port, host: '0.0.0.0', maxPayload: MAX_BYTES, perMessageDeflate: false });
  function send(ws, message) {
    if (ws.readyState === WebSocket.OPEN) {
      if (ws.bufferedAmount > MAX_BYTES * 16) return ws.terminate();
      ws.send(JSON.stringify(message));
    }
  }
  const error = (ws, reason) => send(ws, { t: 'error', reason });
  function broadcast(room) {
    const players = [...room.players.values()].map(p => ({
      id: p.id, name: p.name, host: p.host, ready: p.ready, roles: [...p.roles]
    }));
    for (const p of room.players.values()) send(p.ws, {
      t: 'lobby', lobby: { code: room.code, started: room.started, me: p.id, players }
    });
  }
  function closeRoom(room, reason) {
    rooms.delete(room.code);
    for (const p of room.players.values()) {
      p.ws.room = null;
      error(p.ws, reason);
      p.ws.close(1000, reason);
    }
    room.players.clear();
  }
  function sweep() {
    for (const room of rooms.values()) {
      if (!room.players.size || now() - room.active >= IDLE_MS) closeRoom(room, 'ROOM IDLE');
    }
  }
  const timer = setInterval(sweep, 1000);
  timer.unref();
  wss.on('close', () => clearInterval(timer));
  wss.on('connection', ws => {
    ws.room = null;
    ws.on('error', () => {}); // ws closes invalid/oversized frames itself.
    ws.on('message', (raw, binary) => {
      if (binary) return error(ws, 'TEXT REQUIRED');
      let m;
      try { m = JSON.parse(raw.toString()); } catch { return error(ws, 'INVALID JSON'); }
      if (!m || typeof m !== 'object' || Array.isArray(m)) return error(ws, 'INVALID MESSAGE');
      sweep();
      if (ws.readyState !== WebSocket.OPEN) return;
      if (m.t === 'ping') return send(ws, { t: 'pong' }); // Keepalive isn't room activity.
      if (m.t === 'host' || m.t === 'join') {
        if (ws.room) return error(ws, 'ALREADY IN ROOM');
        if (m.name !== undefined && typeof m.name !== 'string') return error(ws, 'INVALID NAME');
        let room;
        if (m.t === 'host') {
          if (rooms.size >= LETTERS.length ** 4) return error(ws, 'SERVER FULL');
          let code;
          do { code = Array.from({ length: 4 }, () => LETTERS[randomInt(LETTERS.length)]).join(''); }
          while (rooms.has(code));
          room = { code, started: false, players: new Map(), nextId: 1, active: now() };
          rooms.set(code, room);
        } else {
          room = rooms.get(m.code);
          if (!room) return error(ws, 'ROOM NOT FOUND');
          if (room.started) return error(ws, 'ROOM STARTED');
          if (room.players.size >= 4) return error(ws, 'ROOM FULL');
        }
        const id = room.nextId++;
        const p = { id, name: m.name?.trim().slice(0, 48) || `PLAYER ${id}`,
          host: m.t === 'host', ready: false, roles: [], ws };
        room.players.set(id, p);
        ws.room = room;
        ws.player = p;
        room.active = now();
        send(ws, { t: 'welcome', id, code: room.code });
        return broadcast(room);
      }
      const room = ws.room;
      if (!room) return error(ws, 'NOT IN ROOM');
      const p = ws.player;
      switch (m.t) {
        case 'pick':
        case 'drop':
          if (room.started) return error(ws, 'ROOM STARTED');
          if (!ROLES.includes(m.role)) return error(ws, 'INVALID ROLE');
          if (m.t === 'pick') {
            if ([...room.players.values()].some(other => other !== p && other.roles.includes(m.role)))
              return error(ws, 'ROLE TAKEN');
            if (!p.roles.includes(m.role)) p.roles.push(m.role);
          } else p.roles = p.roles.filter(role => role !== m.role);
          break;
        case 'ready':
          if (room.started) return error(ws, 'ROOM STARTED');
          if (typeof m.on !== 'boolean') return error(ws, 'INVALID READY');
          p.ready = m.on;
          break;
        case 'start':
          if (!p.host) return error(ws, 'HOST ONLY');
          if (room.started) return error(ws, 'ROOM STARTED');
          for (const role of ROLES)
            if (![...room.players.values()].some(other => other.roles.includes(role))) p.roles.push(role);
          room.started = true;
          room.active = now();
          broadcast(room);
          for (const other of room.players.values()) send(other.ws, { t: 'started' });
          return;
        case 'msg': {
          if (typeof m.kind !== 'string' || !m.data || typeof m.data !== 'object' || Array.isArray(m.data))
            return error(ws, 'INVALID PAYLOAD');
          const message = { t: 'msg', kind: m.kind, data: m.data, from: p.id };
          if (Buffer.byteLength(JSON.stringify(message)) > MAX_BYTES) return error(ws, 'MESSAGE TOO LARGE');
          room.active = now();
          for (const other of room.players.values()) if (other !== p) send(other.ws, message);
          return;
        }
        default: return error(ws, 'UNKNOWN MESSAGE');
      }
      room.active = now();
      broadcast(room);
    });
    ws.on('close', () => {
      const room = ws.room;
      if (!room) return;
      room.players.delete(ws.player.id);
      ws.room = null;
      if (ws.player.host) return closeRoom(room, 'HOST LEFT');
      room.active = now();
      broadcast(room);
    });
  });
  return { wss, rooms, sweep, close: () => {
    clearInterval(timer);
    for (const ws of wss.clients) ws.terminate();
    return new Promise(resolve => wss.close(resolve));
  } };
}

if (require.main === module) {
  const relay = createRelay();
  relay.wss.on('listening', () => console.log(`SMD relay listening on ${relay.wss.address().port}`));
  relay.wss.on('error', err => { console.error(err.message); process.exitCode = 1; });
  for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => relay.close());
}
module.exports = { createRelay, IDLE_MS, MAX_BYTES };
