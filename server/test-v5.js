'use strict';
// Headless v5 acceptance matrix and two-client missions. Usage: node server/test-v5.js <godot> [smoke|missions]
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const out = path.join(root, 'tmp', 'v5-validation');
fs.mkdirSync(out, { recursive: true });
const executable = process.argv[2];
const mode = process.argv[3] || 'smoke';
function run(args, label, timeout = 180000) {
  const child = spawn(executable, ['--headless', '--path', 'game', ...args], { cwd: root, windowsHide: true });
  child.output = '';
  child.on('error', error => { child.output += String(error); });
  for (const stream of [child.stdout, child.stderr]) stream.on('data', data => { child.output += data; });
  const timer = setTimeout(() => child.kill(), timeout);
  child.done = new Promise(resolve => child.on('close', code => {
    clearTimeout(timer);
    fs.writeFileSync(path.join(out, label + '.log'), child.output);
    resolve(code);
  }));
  return child;
}
async function until(child, pattern) {
  const deadline = Date.now() + 180000;
  while (Date.now() < deadline) {
    const match = child.output.match(pattern);
    if (match) return match;
    if (child.exitCode !== null) throw new Error('Exited before ' + pattern + '\n' + child.output);
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  throw new Error('Timeout waiting for ' + pattern + '\n' + child.output);
}
async function smoke() {
  const jobs = [];
  for (const roles of ['', 'engineer']) for (const dest of ['moon', 'mars', 'venus', 'saturn', 'neptune']) {
    const screens = ['menu', 'builder', 'launch', 'flight', 'report', ...(['saturn', 'neptune'].includes(dest) ? ['probe'] : ['landing', 'surface'])];
    for (const screen of screens) jobs.push({ screen, dest, roles });
  }
  let failures = 0;
  async function worker() {
    while (jobs.length) {
      const { screen, dest, roles } = jobs.shift();
      const label = `${roles || 'solo'}-${screen}-${dest}`;
      const child = run(['--quit-after', '180', '--', `screen=${screen}`, `dest=${dest}`, ...(roles ? [`roles=${roles}`] : [])], label);
      const code = await child.done;
      const ok = code === 0 && !/SCRIPT ERROR|Parse Error/.test(child.output);
      if (!ok) failures++;
      console.log(`${ok ? 'PASS' : 'FAIL'} ${label}`);
      if (!ok) console.log(child.output);
    }
  }
  await Promise.all(Array.from({ length: 4 }, worker));
  assert.equal(failures, 0);
  console.log('PASS 66 screen/destination/mode combinations; no SCRIPT ERROR or Parse Error');
}
async function missions() {
  const relay = spawn(process.execPath, ['server/server.js'], { cwd: root, windowsHide: true, env: { ...process.env, PORT: '18080' } });
  const children = [];
  try {
    await new Promise((resolve, reject) => { relay.stdout.once('data', resolve); relay.once('error', reject); relay.once('exit', code => reject(new Error('Relay exited ' + code))); });
    for (const dest of ['mars', 'saturn']) {
      const host = run(['--', 'server=ws://127.0.0.1:18080', 'mptest=host', `mpdest=${dest}`], `mp-${dest}-host`);
      children.push(host);
      const code = (await until(host, /MPTEST host code=([A-Z]{4})/))[1];
      const join = run(['--', 'server=ws://127.0.0.1:18080', `mptest=join:${code}`, `mpdest=${dest}`], `mp-${dest}-join`);
      children.push(join);
      await Promise.all([until(host, /MPTEST host DONE/), until(join, /MPTEST join DONE/)]);
      for (const child of [host, join]) {
        assert.equal(await child.done, 0, child.output);
        assert.doesNotMatch(child.output, /SCRIPT ERROR|Parse Error|MPTEST .*FAIL/);
        console.log(child.output);
      }
      console.log(`PASS two-client ${dest} mission`);
    }
  } finally {
    for (const child of children) if (child.exitCode === null) child.kill();
    relay.kill();
  }
}
(mode === 'missions' ? missions() : smoke()).catch(error => { console.error(error); process.exitCode = 1; });
