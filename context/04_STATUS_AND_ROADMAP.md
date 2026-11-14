# Status and roadmap

_Last updated: 14 Nov 2026, when the partner's v5 source (AstroPixel) was merged into this repo._

## v6 is merged (14 Nov, morning)

The partner's v6 (built on their v5) is merged with our multiplayer: branch `v6-partner`, then a merge
into `main`. New in v6: the `cheer` cutscene between the site and the report (`screens/cheer.gd`); no
flight home any more (`main.gd` runs `phase_home()` and `finish()` before the cutscene); photo and crew
task jobs (`Game.job()`); landing assist; soft-crash damage on EASY/NORMAL; a reworked event pool.
Merge fixes:
- our multiplayer `Game.job(role)` is now `Game.role_job(role)`;
- online, only the host scores the run before the cutscene, then sends it to the others;
- `set_task()` no longer wipes `run["job"]` on screen changes;
- the report no longer re-rolls the run's storm.

Checked headless: BALANCE OK, the 66-screen smoke test and both two-player missions (Mars, Saturn) pass.
`docs/play/` holds the v6 web build with multiplayer (menu and builder checked in Chrome); README screenshots are from v6; a Windows build is in `builds/AstroPixel-windows.zip`.

## v5 is merged (14 Nov). Read this first

**The game is now v5, named "AstroPixel".** The full design and core API are in
[`../game/docs/V5_DESIGN.md`](../game/docs/V5_DESIGN.md). Where it disagrees with the older text
below, V5_DESIGN.md wins (it records the team's 13–14 Nov decisions). What's new in v5:
- 8 destinations (moon, mercury, venus, mars = `kind "land"`; jupiter, saturn, uranus, neptune =
  `kind "ring"`); screens read `Game.dest()["kind"/"air"/"returns"/"skin"]`, never the dest id;
- 3 tasks per destination (`Data.TASKS`), which set `Game.difficulty` (EASY/NORMAL/HARD);
- NASA margins in `Data.MARGIN` (JPL CML 4); the UNDER / WELL USED / OVER rating per resource;
- 37 decision events (`events.gd`) with a shared pop-up (`event_card.gd`) on cruise, site and home;
- a new flown launch screen (`screens/launch.gd`: throttle, max-Q, staging, fairing, deploy);
- calmer builder (REQUIRED / RECOMMENDED / OPTIONAL / NOT NEEDED tags, a checklist);
- report with the 4 score parts, a build report and a letter grade;
- `tools/dev/balance.gd` checks every task has an all-green ship (prints `BALANCE OK`).

**Multiplayer (roadmap #9) is wired into v5 again (14 Nov, Codex then Claude).** Lobby with the
destination and task picked by the host, shared builder (role locks, SIGN, REQUEST, quick chat),
landing jobs on all land destinations, drone jobs on all ring destinations, role-owned decision
events, host-flown launch/cruise/surface for the others to watch, team sync on the report.
`mp_test.gd` is updated. Checked headless: `node server/test-v5.js <godot> smoke` (66 boots, solo
and `roles=engineer`), `... missions` (two clients complete Mars and Saturn with identical
`Game.run`), `npm test` in `server/`, and `balance.gd` (BALANCE OK). **Not tested:** two real
computers, a deployed relay (`net.gd` DEFAULT_URL points at `wss://smd-relay.fly.dev`, which is not
deployed yet: until it is, HOST on the live site shows "The connection to the server was lost").
**Web build re-exported 14 Nov with multiplayer** into `docs/play/` (Godot 4.7.2 templates now
installed on this PC). In Chrome against a local relay, one tab hosted a room and a second tab joined
it. A Windows build is in `builds/AstroPixel-windows.zip` (not in git; meant for GitHub Releases). Two new mappings need
team approval (D7 note in `03_GAME_DESIGN.md`).

Checked after the merge (headless only, not played by hand): `balance.gd` prints BALANCE OK, and
menu/builder/launch/flight/landing/surface/probe/report boot without script errors for moon, mars,
venus, saturn and neptune. `docs/` now holds the partner's v5 web export.

## Where we were (v4, 13 Nov)

**This repository = game v4.** v4 is the "round 4" rebuild described further down. It is merged and
every screen loads without script errors for all 3 destinations (headless smoke test, not played by
hand). New in v4:
- Kerbal-style hangar builder: parts bin, ship assembled from part sprites (`ship_kit.gd`,
  `vab_meta.gd`), Mission Control lamps per station with plain-words hints and SHOW ME
  (`preflight.gd`), AUTO-BUILD, undo/redo, "fill to need" for fuel;
- LAUNCH runs a station-by-station GO / NO-GO poll;
- landing HUD with a BRAKE light, burn-start mark, safe-speed gauge and drift arrow; legs survive 4 m/s;
- chunky pixel UI kit and shared effects (`ui.gd`, `fx.gd`);
- 67 synthesized sounds, 5 music tracks and ambience beds;
- integer viewport scaling; re-exported web build in `docs/`; new screenshots.
- `screens/fx_test.gd` and `screens/kit_test.gd` are dev test screens.

Still from v3 and still true:
- Moon, Mars and Saturn, each start to finish;
- 4 roles (now one set of lamps each in the builder);
- DONKI storm;
- real-gravity landing;
- rover surface;
- Saturn ring drone;
- report;
- Tech Lab;
- Blender pixel art with the depth pass;
- sound and music.

**Round 4 is now in the repo (v4, above).** The v3 issues it targeted (confusing builder, thin
sounds, flat UI, hard landing) need a hand playtest to confirm they're fixed.

**Open issues:**
- Nobody has played v4 by hand yet: builder with a first-timer, landing, rover, drone. Do it.
- Still in from v3: the "+$100M grant" Tech Lab item (roadmap #7 says remove it); no efficiency rating
  in the report (#4).
- Unchecked from v3: faint vertical streaks at the base of the near mountains; the Saturn drone looks
  crowded next to the ring rocks.
- Web build: the surface and Saturn screens haven't been clicked through in a browser. Opening
  `docs/index.html` by double-click fails ("Failed to fetch"); it must be served (GitHub Pages, or any
  local server).

## Roadmap (in order; cut from the bottom when time runs out)

| # | Task | Why | Size |
|---|---|---|---|
| 1 | ✅ *Done in v4; needs a first-timer playtest.* **Builder UX**: a clear mission card at the top; visual slots on the ship in the hangar (click a slot → pick a part); a hint panel saying what's wrong and which part fixes it (reuse `role_issues()` text) | Team's top complaint; judges' first impression | L |
| 2 | **Hints by difficulty**: Easy shows every hint and warns before a bad launch; Medium shows a warning only after a mistake, or hints that cost points; Hard has none, and only the report explains. Use CubeSat 101 Free-Advice quotes on Easy | Omar's notes; the challenge's "accessible to different knowledge levels" | M |
| 3 | ✅ *Done in v4 (BRAKE light, 4 m/s legs); needs a hand playtest.* **Easier landing** + a "BRAKE NOW" cue on Easy | Playability | S |
| 4 | **Resource-efficiency rating** in the report (Ahmad), separate from success | Challenge: "rewards efficient resource use" | S |
| 5 | **More RNG events** from real stories (`02_NASA_RESOURCES.md` §11), with chance and damage set by the design | "Not the same every time"; the lessons | M |
| 6 | **Report upgrade**: CML-style green/yellow/red with critical items; "top 2 changes that would have helped most" (re-score with alternative parts); "this really happened to ___" | Strongest judging screen | M |
| 7 | **Mission goals per the team notes (§3):** Saturn photo + downlink as the main goal (drone as bonus); Mars core delivered to a pickup point; Moon return as a bonus. Remove the "+$100M grant" tech (§5.7) | Match the team's mission vision (decisions D1, D2 in `03_GAME_DESIGN.md` §5) | M |
| 8 | ✅ *Done in v4 (67 sounds, 5 tracks, ambience).* Sound pass (heavier layered effects, more music) | Polish | M |
| 9 | 🔨 *Screens built 14 Nov: lobby, shared builder (locks, host-authority edits, SIGN, REQUEST, quick chat), landing and Saturn jobs, watched flight/surface, team sync on the report. Tested headless on every screen (offline and `roles=engineer`) and with two instances against the local relay (Mars and Saturn, scripted by `mp_test.gd`). Still to do: deploy the relay and set `net.gd` DEFAULT_URL, a hand test on 2 real computers and in the web build, team approval of the invented mechanics (D7 note in `03_GAME_DESIGN.md`).* Scope fixed by D7 (`03_GAME_DESIGN.md` §5). **Networked multiplayer, 1–4 players** (team notes §5.8): host/join lobby, one role per player, synced builder and sign-offs, per-role jobs in flight. The web build needs WebSocket/WebRTC + a relay server; the Windows build can use ENet on a LAN. **Do a 2-computer test in the first hour of this task**, since it's the riskiest item (earlier estimate: 10–15 h) | Challenge "collaboration for up to 4" | L |
| 10 | GMAT runs to replace Δv estimates; NASA imagery in the report | Relevance score | M |
| 11 | Re-export web (`docs/`) and Windows; play every mission by hand in both | Must happen before submitting | S |
| 12 | 30 s demo video + submission text + AI disclosure + NASA data list | Required | M |

## Definition of done for submission

- [ ] All 3 missions playable by hand, start to finish, in the **web build** on GitHub Pages
- [ ] A first-timer can build a working Moon ship without help (Easy hints)
- [ ] Report explains the why and gives an efficiency rating
- [ ] Demo video ≤ 30 s, public link, English, no under-18 faces or voices
- [ ] Submission: NASA data list (from `02_NASA_RESOURCES.md` §13), all outside resources, AI disclosure
      (root `README.md`)
- [ ] Submitted before **Sun 15 Nov 2026, 15:15** (Ramallah cut-off; global portal 23:59)
- [ ] Live pitch ready: 3 min, 7 slides, offline demo recording as backup (see `research/notes-pitch-and-judging.md`)
