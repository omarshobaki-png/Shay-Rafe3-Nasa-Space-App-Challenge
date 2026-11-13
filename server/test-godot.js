'use strict';
// Optional integration test: node server/test-godot.js <path-to-godot>
const { spawn } = require('node:child_process');
const { once } = require('node:events');
const path = require('node:path');
const assert = require('node:assert/strict');
const { createRelay } = require('./server');

async function main() {
  const executable = process.argv[2] || 'godot';
  const relay = createRelay({ port: 0 });
  await once(relay.wss, 'listening');
  const url = 'ws://127.0.0.1:' + relay.wss.address().port;
  const children = [];
  function run(args) {
    console.log('COMMAND ' + JSON.stringify([executable, ...args]));
    const child = spawn(executable, args, { cwd: path.resolve(__dirname, '..'), windowsHide: true });
    children.push(child);
    child.output = '';
    for (const stream of [child.stdout, child.stderr]) stream.on('data', data => {
      child.output += data;
      process.stdout.write(data);
    });
    child.done = once(child, 'exit');
    return child;
  }
  async function until(child, pattern) {
    const deadline = Date.now() + 45000;
    while (Date.now() < deadline) {
      const match = child.output.match(pattern);
      if (match) return match;
      if (child.exitCode !== null) throw new Error('Godot exited before ' + pattern);
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    throw new Error('Timeout waiting for ' + pattern);
  }
  const timeout = setTimeout(() => {
    for (const child of children) child.kill();
  }, 90000);
  try {
    const host = run(['--headless', '--path', 'game', '--', 'server=' + url, 'nettest=host']);
    const code = (await until(host, /NETTEST code=([A-Z]{4})/))[1];
    const join = run(['--headless', '--path', 'game', '--', 'server=' + url, 'nettest=join:' + code]);
    await until(join, /NETTEST ok/);
    assert.equal((await join.done)[0], 0);
    host.kill();
    await host.done;
    for (const child of [host, join]) assert.doesNotMatch(child.output, /SCRIPT ERROR|Parse Error/);
    console.log('PASS two headless Godot processes exchanged chat');
    const offline = run(['--headless', '--path', 'game', '--quit-after', '120', '--', 'screen=builder', 'dest=moon']);
    assert.equal((await offline.done)[0], 0);
    assert.doesNotMatch(offline.output, /SCRIPT ERROR|Parse Error/);
    console.log('PASS offline builder: no script errors');
  } finally {
    clearTimeout(timeout);
    for (const child of children) if (child.exitCode === null) child.kill();
    await relay.close();
  }
}
main().catch(err => { console.error(err); process.exitCode = 1; });
