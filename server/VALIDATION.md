# Local verification

Tested with Node v26.7.0 and Godot v4.7.2.stable.official.ed1daf0bf.
Commands below ran in PowerShell, from the repository root unless noted.

## Dependency installation

From server/:

```powershell
npm.cmd install
```

```text
added 1 package, and audited 2 packages in 18s
found 0 vulnerabilities
```

## Relay tests

From server/:

```powershell
npm.cmd test
```

Final run exited 0:

```text
> smd-relay@1.0.0 test
> node test.js
PASS room schema, codes, capacity, roles, ready, start, relay, ping, host departure
PASS released roles, idle boundary despite pings, empty cleanup, solo start
PASS malformed/binary payloads and exact 64 KB frame boundary
All relay tests passed.
```

Two earlier runs exposed test-harness synchronization issues: stale lobby
snapshots and checking room deletion before the server close callback.
The tests now consume the departure snapshot and wait for both close callbacks.

## Standalone server

```powershell
node server/server.js
```

Output: `SMD relay listening on 8080`. Stopped after testing.

## Godot exchange and offline smoke

```powershell
node server/test-godot.js 'C:/Users/bsbra/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe'
```

Exited 0. The harness ran these exact arguments against that executable:

```text
--headless --path game -- server=ws://127.0.0.1:52600 nettest=host
--headless --path game -- server=ws://127.0.0.1:52600 nettest=join:VENT
--headless --path game --quit-after 120 -- screen=builder dest=moon
```

Observed output (engine banner repeated per process):

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
NETTEST code=VENT
NETTEST ok
PASS two headless Godot processes exchanged chat
PASS offline builder: no script errors
```

The offline command was also run separately:

```powershell
& 'C:/Users/bsbra/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe' --headless --path game --quit-after 120 -- screen=builder dest=moon
```

Exit 0; no script errors. Both runs reported:

```text
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
at: _set_size (scene/gui/control.cpp:1519)
[0] goto (res://scripts/main.gd:71)
```

The first standalone run additionally reported:

```text
WARNING: 4 ObjectDB instances were leaked at exit (run with --verbose for details).
at: cleanup (core/object/object.cpp:2536)
```

These were not changed; main.gd and other game files belong to the screen worker.
Node commands also emitted an environment warning that NO_COLOR was ignored
because FORCE_COLOR was set.

## Contract observations and remaining verification

- No public API, signal, or constant value was changed. All implementation
  TODO(net) markers are resolved. DEFAULT_URL is still the supplied placeholder;
  the team must confirm/set the actual URL after deployment.
- There is no recoverable action-error signal. Server errors disconnect the
  Godot client, including ROLE TAKEN. A future recoverable error UI would require
  a team-approved contract extension.
- The opening comment says one role each; explicit task rules allow multiple
  roles per player and assign all unpicked roles to the host. Implemented those rules.
- READY is state only; neither the task nor contract requires it before start.
- Non-host departure after start releases their roles but doesn't reassign them.
  The contract specifies automatic assignment only at start.
- No Fly login, deployment, account creation, commit, or push was performed.
- Docker image build, deployed wss/TLS, browser HTML5 export, two physical
  computers, and manual gameplay were not tested.
- The 8-second client timeout and 20-second ping scheduler are implemented but
  were not separately tested against a stalled endpoint or timed packet capture.
- Node 20 compatibility was not run on Node 20 specifically; local runtime was 26.7.0.
- Other screens/destinations were not smoke-tested in this scoped task.
- node_modules is local and ignored by server/.gitignore and .dockerignore.
