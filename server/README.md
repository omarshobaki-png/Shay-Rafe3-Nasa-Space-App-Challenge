# Space Mission Designer relay

Node 20+; the only dependency is ws. Run from the repository root:

```powershell
cd server
npm ci
npm test
npm start
```

PORT defaults to 8080. In PowerShell, set another port with
`$env:PORT = "8081"` before starting. Rooms live only in memory.

In two terminals at the repository root (Godot must be on PATH):

```powershell
godot --headless --path game -- server=ws://127.0.0.1:8080 nettest=host
godot --headless --path game -- server=ws://127.0.0.1:8080 nettest=join:ABCD
```

Replace ABCD with the host's printed `NETTEST code=XXXX`. The joiner prints
`NETTEST ok` and exits. Stop the host with Ctrl+C; debug tests time out after
60 seconds. The host sends one chat message when a second player arrives.

Automated two-process exchange plus offline builder smoke test, from the repo root:

```powershell
node server/test-godot.js "C:/path/to/godot.exe"
```

This uses a temporary local relay on an available port and stops its processes
after testing. See VALIDATION.md for the commands and observed results.

v5 checks (from the repo root; logs go to `tmp/v5-validation/`, which git ignores):

```powershell
node server/test-v5.js "C:/path/to/godot.exe" smoke     # 66 screen/destination/mode boots, solo and roles=engineer
node server/test-v5.js "C:/path/to/godot.exe" missions  # relay on port 18080 + two clients fly Mars and Saturn
```

## Team deployment (not run by the implementation worker)

Install Fly CLI, then run from server/:

```powershell
fly auth login
fly launch --no-deploy
fly deploy --ha=false
fly scale count 1
fly status
```

When launch finds fly.toml, use that existing configuration, retain smd-relay
if available, and decline databases. If that globally unique app name is
unavailable, choose a real available name and update fly.toml.
The deploy flag disables Fly's automatic spare machine. Keep exactly one
machine: rooms are in memory, so multiple machines would split room membership.
Deploys/restarts end existing rooms.

Set `game/scripts/net.gd` DEFAULT_URL to the real app URL, for example
`wss://smd-relay.fly.dev`, and rebuild the clients. The placeholder currently
has that value; deployment has not been performed or verified.

Test TLS from the repository root in two terminals:

```powershell
godot --headless --path game -- server=wss://smd-relay.fly.dev nettest=host
godot --headless --path game -- server=wss://smd-relay.fly.dev nettest=join:ABCD
```

Use the actual app hostname and newly printed room code. HTTPS web exports
must use wss. Godot polls WebSocketPeer in _process with no threads.

## Protocol details

The contract is game/scripts/net.gd. Lobby and player keys are exactly as
documented there. Player IDs are room-local, positive, and never reused in a room.
Names default to PLAYER N and are limited to 48 characters.
Ready is displayed state; it is not a prerequisite for start. Roles lock on start.
Departing non-host players release their roles; there is no automatic reassignment
after start in the contract. A host departure destroys the room with HOST LEFT.

Frames and relayed messages are limited to 65,536 UTF-8 bytes; the added
sender field also counts toward the outgoing limit. Binary frames and malformed
JSON are rejected. Messages cannot spoof the sender ID. Slow readers with more
than 1 MiB queued are disconnected.

Rooms expire after 30 minutes without room actions/messages (checked each second
and before handling messages). Ping/pong keeps the transport alive but does not
extend that lifetime. Empty rooms are removed immediately.

The game contract has no action-error signal: any server error maps to
disconnected(reason), closes the client connection, and restores offline state.
connected is emitted after the first lobby arrives, so signal listeners can
already read their ID, roles and host state. Intentional leave emits no signal.

Tests launch a local relay, use four room participants plus a rejected overflow
connection, and advance an injected clock to verify the real 30-minute threshold.
No game simulation or action authorization is implemented by the relay; screens
must enforce host authority for game messages.

References: [Godot WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html),
[Fly configuration](https://fly.io/docs/reference/configuration/).
