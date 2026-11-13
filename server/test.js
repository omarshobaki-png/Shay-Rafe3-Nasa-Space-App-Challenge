'use strict';
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { WebSocket } = require('ws');
const { createRelay, IDLE_MS, MAX_BYTES } = require('./server');

async function main() {
  let time = 1000;
  const relay = createRelay({ port: 0, now: () => time });
  await once(relay.wss, 'listening');
  const url = `ws://127.0.0.1:${relay.wss.address().port}`;
  const clients = [];
  async function client() {
    const ws = new WebSocket(url);
    const messages = [];
    ws.on('message', raw => messages.push(JSON.parse(raw)));
    ws.on('error', () => {});
    await once(ws, 'open');
    const c = {
      ws, messages,
      send: m => ws.send(JSON.stringify(m)),
      async take(t, predicate = () => true) {
        const end = Date.now() + 3000;
        while (Date.now() < end) {
          const i = messages.findIndex(m => m.t === t && predicate(m));
          if (i >= 0) return messages.splice(i, 1)[0];
          await new Promise(r => setTimeout(r, 5));
        }
        throw new Error('Timed out: ' + t + ' ' + JSON.stringify(messages));
      },
      async close() {
        if (ws.readyState === WebSocket.CLOSED) return;
        const remote = [...relay.wss.clients].find(socket =>
          socket._socket.remotePort === ws._socket.localPort);
        const serverClosed = remote ? once(remote, 'close') : Promise.resolve();
        const done = once(ws, 'close');
        ws.close();
        await Promise.all([done, serverClosed]);
      }
    };
    clients.push(c);
    return c;
  }
  async function expectError(c, message, reason) {
    c.send(message);
    assert.equal((await c.take('error')).reason, reason);
  }
  try {
    const a = await client(), b = await client(), c = await client(), d = await client();
    a.send({ t: 'host', name: 'HOST' });
    const welcome = await a.take('welcome');
    const code = welcome.code;
    assert.match(code, /^[A-HJ-NP-Z]{4}$/);
    assert.equal(welcome.id, 1);
    const initial = (await a.take('lobby')).lobby;
    assert.deepEqual(initial, { code, started: false, me: 1,
      players: [{ id: 1, name: 'HOST', host: true, ready: false, roles: [] }] });
    for (const [index, peer] of [b, c, d].entries()) {
      peer.send({ t: 'join', code, name: 'PLAYER' });
      assert.equal((await peer.take('welcome')).id, index + 2);
      const lobby = (await peer.take('lobby')).lobby;
      assert.equal(lobby.me, index + 2);
      assert.deepEqual(Object.keys(lobby).sort(), ['code', 'me', 'players', 'started']);
    }
    await a.take('lobby', m => m.lobby.players.length === 4);
    // A fifth connection is necessary to prove the four-player cap.
    const extra = await client();
    await expectError(extra, { t: 'join', code }, 'ROOM FULL');
    await expectError(a, { t: 'host' }, 'ALREADY IN ROOM');
    await expectError(extra, { t: 'join', code: 'IIII' }, 'ROOM NOT FOUND');
    b.send({ t: 'pick', role: 'engineer' });
    await b.take('lobby', m => m.lobby.players.find(p => p.id === 2).roles.includes('engineer'));
    b.send({ t: 'pick', role: 'science' });
    await b.take('lobby', m => m.lobby.players.find(p => p.id === 2).roles.length === 2);
    await expectError(c, { t: 'pick', role: 'engineer' }, 'ROLE TAKEN');
    await expectError(c, { t: 'pick', role: 'pilot' }, 'INVALID ROLE');
    c.send({ t: 'drop', role: 'engineer' });
    assert((await c.take('lobby', m => m.lobby.players.find(p => p.id === 2).roles.length === 2)).lobby);
    b.send({ t: 'drop', role: 'science' });
    await b.take('lobby', m => m.lobby.players.find(p => p.id === 2).roles.join() === 'engineer');
    for (const on of [true, false]) {
      b.messages.length = 0;
      b.send({ t: 'ready', on });
      await b.take('lobby', m => m.lobby.players.find(p => p.id === 2).ready === on);
    }
    await expectError(b, { t: 'start' }, 'HOST ONLY');
    for (const peer of [a, b, c, d]) peer.messages.length = 0;
    b.send({ t: 'msg', kind: 'chat', data: { msg: 1 }, from: 999 });
    for (const peer of [a, c, d]) assert.deepEqual(await peer.take('msg'),
      { t: 'msg', kind: 'chat', data: { msg: 1 }, from: 2 });
    b.send({ t: 'ping' });
    await b.take('pong');
    assert(!b.messages.some(m => m.t === 'msg'));
    a.send({ t: 'start' });
    for (const peer of [a, b, c, d]) {
      const lobby = (await peer.take('lobby', m => m.lobby.started)).lobby;
      assert.deepEqual(lobby.players[0].roles, ['planner', 'science', 'comms']);
      assert.deepEqual(lobby.players[1].roles, ['engineer']);
      await peer.take('started');
    }
    await expectError(b, { t: 'drop', role: 'engineer' }, 'ROOM STARTED');
    await expectError(extra, { t: 'join', code }, 'ROOM STARTED');
    await d.close();
    await a.take('lobby', m => m.lobby.players.length === 3);
    await expectError(extra, { t: 'join', code }, 'ROOM STARTED');
    await a.close();
    for (const peer of [b, c]) assert.equal((await peer.take('error')).reason, 'HOST LEFT');
    assert.equal(relay.rooms.size, 0);
    console.log('PASS room schema, codes, capacity, roles, ready, start, relay, ping, host departure');

    extra.send({ t: 'host' });
    const second = await extra.take('welcome');
    const reconnect = await client();
    reconnect.send({ t: 'join', code: second.code });
    await reconnect.take('welcome');
    reconnect.send({ t: 'pick', role: 'science' });
    await extra.take('lobby', m => m.lobby.players.some(p => p.roles.includes('science')));
    extra.messages.length = 0;
    await reconnect.close();
    await extra.take('lobby', m => m.lobby.players.length === 1);
    extra.send({ t: 'pick', role: 'science' });
    await extra.take('lobby', m => m.lobby.players[0].roles.includes('science'));
    time += IDLE_MS - 1;
    extra.send({ t: 'ping' });
    await extra.take('pong');
    relay.sweep();
    assert.equal(relay.rooms.size, 1);
    time += 1;
    relay.sweep();
    assert.equal((await extra.take('error')).reason, 'ROOM IDLE');
    assert.equal(relay.rooms.size, 0);
    const solo = await client();
    solo.send({ t: 'host' });
    await solo.take('welcome');
    solo.send({ t: 'start' });
    const soloLobby = (await solo.take('lobby', m => m.lobby.started)).lobby;
    assert.equal(soloLobby.players[0].roles.length, 4);
    await solo.close();
    assert.equal(relay.rooms.size, 0);
    console.log('PASS released roles, idle boundary despite pings, empty cleanup, solo start');

    const invalid = await client();
    invalid.ws.send('{');
    assert.equal((await invalid.take('error')).reason, 'INVALID JSON');
    invalid.ws.send('[]');
    assert.equal((await invalid.take('error')).reason, 'INVALID MESSAGE');
    invalid.ws.send(Buffer.from('{}'));
    assert.equal((await invalid.take('error')).reason, 'TEXT REQUIRED');
    await expectError(invalid, { t: 'msg', kind: 'chat', data: {} }, 'NOT IN ROOM');
    invalid.send({ t: 'host' });
    await invalid.take('welcome');
    await expectError(invalid, { t: 'ready', on: 1 }, 'INVALID READY');
    await expectError(invalid, { t: 'msg', kind: 'chat', data: [] }, 'INVALID PAYLOAD');
    const boundary = JSON.stringify({ t: 'ping', padding: '' });
    invalid.ws.send(JSON.stringify({ t: 'ping', padding: 'x'.repeat(MAX_BYTES - Buffer.byteLength(boundary)) }));
    await invalid.take('pong');
    const closed = once(invalid.ws, 'close');
    invalid.ws.send('x'.repeat(MAX_BYTES + 1));
    assert.equal((await closed)[0], 1009);
    console.log('PASS malformed/binary payloads and exact 64 KB frame boundary');
    console.log('All relay tests passed.');
  } finally {
    for (const c of clients) c.ws.terminate();
    await relay.close();
  }
}
main().catch(err => { console.error(err); process.exitCode = 1; });
