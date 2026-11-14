# Session briefing: Space App Challenge (14 Nov 2026, 01:36)

> ⚠️ `docs/` is published by GitHub Pages. **Don't commit this folder.** Keep briefings local (it's untracked).

## Goal
Team Shay Rafe3's entry for **NASA Space Apps 2026, "Space Mission Design Game"**: a Godot 4.7.2 / GDScript
2D pixel-art game where 1–4 players design, launch, land and debrief a robotic mission (Moon / Mars / Saturn).
- **Deadline: Sun 15 Nov, 15:15** (Ramallah local event cut-off). Pitches 16:15 (3 min + 2 min Q&A), awards 19:00.
  The global portal closes at 23:59, but plan for 15:15.
- **My role:** the user acts as a relay. For feature tasks I write **two paste-ready prompts** (one for a Claude
  chat, one for a Codex chat) with non-overlapping file ownership, then review and merge what they return.
  I do the git work, merges, setup and verification myself.

## Done and verified
| What | Commit | Verified how |
|---|---|---|
| Repo cloned from GitHub; Godot 4.7.2 installed; `.venv` (numpy, Pillow, pypdf) | — | `godot --version`, imports clean |
| Teammate's **v4** merged (hangar builder, lamps, AUTO-BUILD, BRAKE light, 67 sounds, new art) | `4bc60f7` | Headless smoke of every screen × 3 planets |
| Status doc rewritten for v4 | `d0f5e1b` | — |
| **Multiplayer (D7)**: relay server + `net.gd` (Codex), lobby / shared builder / REQUEST / quick chat / sign-off / landing + Saturn jobs / team sync score (Claude) | `ce5c943` | `npm test` passes; 2 Godot processes exchange messages; **automatic 2-player Mars mission, lobby to report** (`mptest`); 42-run headless smoke, offline + `roles=` |
| Challenge study + v4 coverage table | in `research/notes-challenge.md` | Page read via Chrome |
| Pitch/judging study; deadline fixed to 15:15 in the context docs | `0884d0f` | — |

**Not verified:** nobody has played multiplayer **by hand**, on **2 real computers**, or in the **web build**.

## Decisions and why
- **D4:** 1–4 players over the network, one role each (Planner, Engineer, Scientist, Comms). Solo = offline, all roles.
- **D7 (team, 13 Nov):** builder + landing/Saturn role jobs; **hosted relay on Fly.io with 4-letter room codes**
  (the only way judges can try multiplayer in the browser); plus REQUEST, quick chat, sign-off reset, team sync score.
  The room host's game is authoritative.
- The worker invented small mechanics to fill gaps (landing sites, manual chute/legs, drone throttle, Comms
  downlink pick, sync weights). They're marked `"game rule"` in `data.gd` and **await team approval**.
- When merging teammate zips, **keep `CLAUDE.md` + `context/`** (the zips are built from older bases).
- I left `docs/briefings/` uncommitted: it holds private paths, session IDs and a line about an earlier push made
  "without Claude as contributor". Judges check AI disclosure.

## Open problems
1. **Relay not deployed.** Fly CLI isn't logged in. The user must run `fly auth login` (their account).
   `net.gd` `DEFAULT_URL` is still the placeholder `wss://smd-relay.fly.dev`.
2. **Web build (`docs/`) is old v4**, with no multiplayer. Re-export needs Godot export templates (~1 GB; slow network).
   The Windows exe in `builds/` is v3.
3. **Contract bugs** (found by the Claude worker, not yet fixed):
   - any server error (e.g. ROLE TAKEN) **disconnects the player**: fix first;
   - READY isn't enforced by the server;
   - the lobby has no destination field, so non-hosts can't see the planet;
   - `send()` broadcasts host-only inputs to everyone;
   - there's no "poll" message kind (it rides on "build");
   - JSON turns ints into floats (sanitised in `game.gd`).
4. **Pitch material:** nothing made yet (≤ 7 slides, ≤ 30 s video with English subtitles, project page).
5. Real numbers for pitch slides 2 (problem) and 6 (impact) must come from the team. **Don't invent them.**
6. Still from v3: the "+$100M grant" tech is still in (roadmap #7); there's no efficiency rating (#4, D5).

## Exact next steps
1. User runs `fly auth login`, then from `server/`: `fly launch --no-deploy --copy-config` and `fly deploy`.
   Set `net.gd` `DEFAULT_URL` to the real `wss://…fly.dev`, test with 2 windows, commit and push.
2. Write the **next two worker prompts** (the user agreed in principle):
   - **Codex:** fix the contract bugs (non-fatal errors, server-side READY, destination in the lobby), install the
     export templates, re-export the web build to `docs/` (threads off, keep `docs/.nojekyll`) and Windows to `builds/`.
   - **Claude:** 7-slide deck + 30 s video script + project-page text from `research/notes-pitch-and-judging.md`,
     with the NASA data named exactly.
3. Check the GitHub Pages link opens with no login and multiplayer works in the browser.
4. Team: first-timer playtest (evidence + quote), approve the `"game rule"` mechanics, pick the tagline.
5. Optional, high value for judges: a real NASA photo (LRO / HiRISE / Cassini) in the report.

## Gotchas
- **Network is slow and flaky:** wrap `git fetch/push` in retry loops. Shallow fetch worked when a clone failed.
- **SSL interception:** `curl`, WebFetch and the fetch tool all fail on spaceappschallenge.org. Use **Chrome** (claude-in-chrome).
- **Zips:** `unzip` fails (exit 81). Use `C:/Windows/System32/tar.exe -xf`.
- **Godot import rewrites `.import` files** (CRLF, font.png.import). Run `git checkout -- game/art game/audio` before committing.
- **Godot:** no PATH alias (winget had no admin). Use `~/bin/godot` in Git Bash, or the full path:
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v4.7.2-stable_win64(_console).exe`.
  `Play Game.bat` in the repo root launches it.
- **Python:** `python` is the Store alias. Use `py` or `.venv/Scripts/python.exe`.
- **Commits:** `CLAUDE.md` says "the team commits". Only commit or push when the user asks (they have, each time).
- **Don't `git stash`** in this shared tree: workers edit it at the same time.
- "resources still in use at exit" / leaked ObjectDB warnings in headless runs are harmless.
- **Test commands:**
  - Screen smoke: `godot --headless --path game --quit-after 180 -- screen=<builder|flight|landing|surface|probe|report> dest=<moon|mars|saturn> [roles=engineer]`
  - Local relay: `cd server && PORT=8080 node server.js`
  - 2 windows: `godot --path game -- server=ws://127.0.0.1:8080` (run twice)
  - Self-playing 2-player test: `mptest=host` / `mptest=join:CODE` (`mpdest=saturn` for the drone)
  - Server tests: `cd server && npm test`; `node server/test-godot.js "<godot console exe>"`

## Files that matter
- `CLAUDE.md`: hard rules (GDScript only, every number in `data.gd` with `src`, no AI art, disclose AI use, don't commit).
- `context/README.md` → `00_TEAM_NOTES.md` (vision, §5.8 multiplayer, §9 decisions), `03_GAME_DESIGN.md` §5
  (D1–D7), `04_STATUS_AND_ROADMAP.md` (roadmap + definition of done), `02_NASA_RESOURCES.md` (§10 data, §13 judge statement).
- `research/notes-challenge.md` (challenge + coverage table), `research/notes-pitch-and-judging.md` (judging + 7-slide plan).
- Game: `game/scripts/net.gd` (network contract), `game.gd` (state, sim, scoring, MP flow), `data.gd`
  (all numbers + MP game rules), `team_ui.gd` (chat/REQUEST), `screens/menu.gd` (lobby), `screens/builder.gd`,
  `screens/landing.gd`, `screens/probe.gd`, `mp_test.gd` (dev test).
- Server: `server/server.js`, `server/test.js`, `server/fly.toml`, `server/README.md` (deploy steps), `server/VALIDATION.md`.
- Local only (git-ignored): `builds/` (v3 Windows exe + original zips), `.venv/`.
- Memory: `~/.claude/projects/C--Users-bsbra-Desktop-Space-App-Challenge/memory/` (challenge-brief, project-setup, manager-workflow).
