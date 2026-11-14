# Session briefing: Space Mission Designer, multiplayer screens (14 Nov 2026, 01:36)

## Goal
Build the networked multiplayer **screens** (decisions D4/D7 in `context/03_GAME_DESIGN.md` §5) on top of
the `net.gd` relay contract, which another worker wrote. Solo (offline, the default) must look and play
exactly as before.

**Deadline: Sun 15 Nov 2026, 15:15 Ramallah time** (see memory `challenge-brief.md`).

## Status in one line
Done and tested, both headless and with a scripted 2-instance online test. The team has committed it
(`ce5c943 Multiplayer for 1-4 players (decision D7)`). **Nobody has played it by hand yet.**

## What's done (and how it was checked)
| Area | What | Checked by |
|---|---|---|
| Menu lobby | MULTIPLAYER button; HOST/JOIN with a 4-letter code and a name; 4 role slots; READY; the host picks the destination and presses START; LEAVE; plain-word errors | screenshots + `mp_test.gd` |
| Shared builder | role locks (`Data.TAB_ROLE`, "ENGINEER's part: use REQUEST"); host-authority `edit`/`build` messages; undo/redo/AUTO-BUILD hidden online; any change clears signatures; only the host can LAUNCH, and only once all 4 have signed; the poll runs for everyone; REQUEST with ACCEPT/DECLINE; quick chat with keys 1-8 | `mp_test.gd` (Mars + Saturn) |
| Landing jobs | Engineer flies the engine; Scientist opens the parachute (Mars) and lowers the legs; Planner picks the site | `mp_test.gd` Mars |
| Saturn drone jobs | Scientist flies; Engineer sets the throttle (fuel); Comms picks the downlink | `mp_test.gd` Saturn |
| Watched screens | flight (shared seed → same cruise), surface (the host drives and streams `state`), report | `mp_test.gd` |
| Team sync score | online only; shown as a row on the report | `mp_test.gd` (100) |
| Solo regression | headless: 7 screens × 3 destinations × {offline, `roles=engineer`} = 42 runs, no script errors | headless only |

Online results against the local relay (port 8095):
- **Mars:** score 60, team_sync 100.
- **Saturn:** score 100, reward 366, team_sync 100.

The logs are in the session scratchpad (`host2.log` etc.) and won't survive the session.

## Decisions made and why
- **Host authority.** The host's `Game` is the truth. Non-hosts send `edit`/`input` and apply the host's `build`/`state`. This is the simplest way to stay in sync with a dumb relay.
- **Shared cruise seed** (`Game.rng`, sent in `goto.seed`). Flight is deterministic, so nothing needs streaming during cruise.
- **Undo/redo/AUTO-BUILD are off online.** Turning them off was cheaper than making them host-only.
- **Offline `roles=` debug mode.** The computer plays the roles nobody owns (autopilot, auto-sign, auto-accept), so one person can test a job alone.
- **Extra fields added beside the `net.gd` contract, without editing `net.gd`:**
  - `goto` carries `dest`, `build` and `seed`;
  - `build` carries `poll: "start"|"stop"`.
- **Invented mechanics.** These fill gaps in D7 and are **not approved by the team yet**. Each one is marked "game rule" in `data.gd`, listed in the D7 note in `03_GAME_DESIGN.md`, and disclosed in the `README.md` AI section:
  - `LANDING_SITES`: plain / crater rim / boulder field, with drift 0/3/5, touch ×1/0.75/0.6 and credits ×1/1.25/1.5; the Planner picks within 12 s.
  - `LANDING_JOBS`: the Mars chute; online the descent starts at 4500 m and 420 m/s; the chute slows the lander by 80 m/s² down to 90 m/s and is cut away at 1000 m; the legs take 1.5 s to lower and a legs-up touchdown is a crash.
  - `DRONE_THROTTLE`: ECO thrust ×0.8, fuel ×0.6 / NORMAL ×1, ×1 / BOOST ×1.3, ×1.6.
  - `DRONE_DOWNLINK`: limit 6 units, 20 s to choose, 2 credits per science point.
  - `TEAM_SYNC`: weights 0.4 answered / 0.3 reply time (5 s→30 s) / 0.3 sign time (10 s→90 s).

## Open problems
1. **The relay is not deployed** and `net.gd` `DEFAULT_URL` is a placeholder, so online play is impossible in the real builds.
2. **The `net.gd` contract has problems** (the other worker owns `net.gd` and `server/`):
   - any server error is fatal, so for example ROLE TAKEN disconnects the player (a race between two players clicking the same free role);
   - the server doesn't enforce READY (only the menu does);
   - the lobby dict has no destination, so joiners can't see it before START;
   - when the host leaves, the room closes (no host change);
   - `send()` broadcasts, so host-only `input`/`edit` at about 20 Hz also reach the non-hosts;
   - JSON turns ints into floats (the screens sanitize them).
3. **Never tested:**
   - any hand play, including solo in the editor;
   - lobby clicks, chat, DECLINE, disconnect messages and the Moon jobs online;
   - the web build;
   - two real computers;
   - the deployed relay.
4. The team hasn't approved the invented mechanics yet.
5. Possible extra: "Ring samples collected: 7 of 5" appears in the Saturn log. It may be pre-existing wording.

## Exact next steps
1. **Hand-test solo** in the editor (F5): all 3 missions start to finish. This confirms the golden rule.
2. **Deploy the relay** (`server/`), set `DEFAULT_URL` in `net.gd` (other worker or team), re-export the web build to `docs/`.
3. **2-computer hand test** (web + Windows): lobby clicks, chat 1-8, REQUEST→DECLINE, a player leaving mid-game, the Moon online.
4. **Team review** of the invented mechanics (D7 note). Change the numbers in `data.gd` only.
5. Fix the contract issues that bite in the hand test. Top priority: make the server's ROLE TAKEN non-fatal.
6. Then continue the roadmap in `context/04_STATUS_AND_ROADMAP.md` (#2 hints by difficulty, #4 efficiency rating, #11 re-export + play, #12 video/submission).

## Gotchas
- **Never `git stash` in this tree.** Other workers have uncommitted files in it. I did it once by mistake and restored them immediately.
- **Don't commit or push** unless the user explicitly asks (CLAUDE.md). The user once asked for a push with Claude *not* credited, and it was done as author Brawly0.
- **Don't edit** `net.gd`, `project.godot` or `server/`. They belong to the other worker.
- Every number goes in `data.gd` with `src`. Game-design ideas must come from the team: lay out options and ask.
- Python isn't installed on this machine. Long bash heredocs fail, so use the Edit tool or sed.
- The "N resources still in use at exit" / "ObjectDB leaked" messages at headless quit are pre-existing (a wav still playing). Ignore them.
- Grep pipes buffer the room code, so log to a file and read it.
- Headless runs: `-- screen=<s> dest=<d>` plus optionally `roles=engineer`.
- Online test:
  - start the relay in `server/` (Node);
  - host: `-- server=ws://127.0.0.1:8095 mptest=host [mpdest=saturn]`, which prints `MPTEST host code=XXXX`;
  - joiner: `mptest=join:XXXX`.
- `Engine.time_scale = 2` inside `mp_test.gd`.

## Files that matter
- `game/scripts/data.gd`: `TAB_ROLE`, `QUICK_CHAT`, `REQUESTS`, `NET_RATES`, `TEAM_SYNC`, `LANDING_JOBS`, `LANDING_SITES`, `DRONE_THROTTLE`, `DRONE_DOWNLINK`.
- `game/scripts/game.gd`:
  - `multi()`, `cpu()`, `job()`, `my_role()`, `all_signed()`;
  - `snap()`/`apply_snap()`, `flow()`, `host_goto()`, `launch()`;
  - `_on_net`, `_remote_goto`, `_on_net_lost`;
  - `team_*`, `team_sync()`;
  - `finish()` (the host only; site and downlink credits).
- `game/scripts/team_ui.gd` (new): chat, REQUEST, ACCEPT/DECLINE queue, toasts.
- `game/scripts/screens/`:
  - `menu.gd`: lobby;
  - `builder.gd`: locks, sign, poll;
  - `landing.gd`: jobs, sites, chute;
  - `probe.gd`: throttle, downlink;
  - `surface.gd`, `flight.gd`, `report.gd`.
- `game/scripts/mp_test.gd` (new, dev only) and `main.gd` (loads it with `mptest=`).
- `game/scripts/net.gd` and `server/`: the contract (read only for us).
- Docs:
  - `context/03_GAME_DESIGN.md`: code map + D7 note;
  - `context/04_STATUS_AND_ROADMAP.md`: row 9;
  - `README.md`: AI disclosure.
