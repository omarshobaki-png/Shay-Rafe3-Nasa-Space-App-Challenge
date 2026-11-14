# Status and roadmap

_Last updated: 14 Nov 2026, when the partner's v8 (the final game version) was merged and published._

## Phone play, option A (14 Nov, Claude): built and tested, NOT yet copied to `docs/play/`

So judges can scan the deck's QR and play for a minute. Taps already arrive as mouse clicks and v8 already
shows touch buttons (BRAKE, < >, HOLD: BURN, rover buttons), so the changes are small:
- `flight.gd`: holding a finger anywhere fast-forwards the cruise (was SPACE only); the hint says
  SCREEN / BUTTON instead of SPACE on a touch screen.
- `landing.gd`, `surface.gd`: hints name the touch button (BRAKE, PHOTO, DRILL, SET UP) instead of SPACE / E.
- `export_presets.cfg` (Web → `html/head_include`): a "turn your phone sideways" screen in portrait, and on
  the first tap the page goes full screen and locks landscape (Android Chrome; iPhone Safari ignores both).
Tested in a touch-emulated phone-sized Chrome (Playwright, 915×412): Moon and Mars played start to rover
with taps and holds only. Headless boot of every screen for all 3 destinations: no script errors. Not
tested: a real phone, iPhone Safari, two-finger input (brake and steer at once still can't work: one touch
= one mouse), the help (?) overlays, which still list keyboard keys.

## v8 is merged and published (14 Nov). The partner calls it the final version

Applied from `AstroPixel-v8.patch` (made on 607a34f) with no conflicts. Checked headless after the merge:
BALANCE OK, the 66-boot smoke test and both two-client online missions (Mars, Saturn) pass. `docs/play/`
is the v8 web build exported from this source; `builds/AstroPixel-windows.zip` is the v8 Windows build
(also on the GitHub release). Website, README screenshots and texts are updated for v8. Not checked: a
full mission by hand, online play on 2 real computers, the web build in a browser.

### What v8 changed (partner's notes)

Made on top of 607a34f; the team's words and the design are in `game/docs/V8_PLAN.md`.
- **One dialogue component, `game/scripts/talk.gd`**, taken from the builder's guide (portrait, typed
  speech bubble) and now used by the builder, the menu briefing, the rover/astronaut site and the ring
  drone. It has no buttons and adds no decisions. Mission Control explains each task once
  (`Game.task_talk("brief" | "builder" | "site")`, built from `Data.JOBS` / `Data.DEST`), and the short
  objective comes from `Game.task_short()`. Replay: click YOUR GOAL or its "i" in the briefing, the task
  title in the builder, "?" at the site.
- **Event lead-in**: `EventCard.open()` shows one Mission Control line for about 2 s (`Data.TALK`), then
  the same card as before. `is_open()` is true from the first moment, so no screen's timing changed; the
  card's input delay starts when the card appears. Every event in `events.gd` has an `"intro"` line.
- **"bibi" chatter** while text types: `audio/talk_bi*.wav` from `tools/audio/make_chatter.py`,
  `Audio.chatter()` / `chatter_stop()`, switch in HOW TO PLAY (TALK SOUND, kept in `user://audio.cfg`).
- **NORMAL builder** sits between EASY and HARD: full hint sentence and SHOW ME, no AUTO-BUILD, no ghost.
- **EASY retry**: `main.goto()` calls `Game.checkpoint(screen)`; a missed-goal EASY solo report shows
  TRY THE ... AGAIN (`Game.can_retry()`, `retry()`), which restores the run and the credits. Off online.
- **Scrolling** (`Scroll` class in `menu.gd`, reused by `report.gd`): the briefing, NASA DATA, THE LESSON.
- **Ring drone** steers with cold nitrogen gas (as NASA's MMU jetpack, 24 nitrogen thrusters): pale puffs
  instead of flames, GAS wording, a hiss instead of the rocket roar.
- `tools/dev/shot.sh` and `godot_import.sh` find the project and Godot by themselves again (`GODOT` env).
Checked headless: BALANCE OK; the self-play test (`tools/dev/e2e.sh`) on all 24 tasks; screenshots of each
change. Not checked: online play (the lead-in and the dialogue are local only, nothing new is sent over
`Net`), a mission by hand, the sound by ear. `docs/play/` still holds the v7 web build.

## v7 is merged (14 Nov, morning). The partner calls it the last game update

Branch `v7-partner` (off `v6-partner`), merged into `main` as 1d1476a. v7 does what the team asked
after playing v6 (their words are in `game/docs/V7_PLAN.md`): the level must matter. New keys in
`Data.DIFFICULTY`, read through `Game.diff()`: `hints` (EASY guide + auto-build, NORMAL one-line hint,
HARD none), `assist`, `bite` (losses x0.5 / x1 / x1.6), `fail` (EASY can't lose, NORMAL loses
samples or science, HARD a crash or empty battery ends the mission), `drain`. Small texts are coloured
red (loss), yellow (risk), green (gain). New builder tab icons; the rover drains its battery while
drilling; budgets retuned. Roadmap #2 (hints by difficulty) is done by this.
Merge fixes (kept both sides): the stored storm in `event_by_id()` plus v7's `_bite_event()`; landing
damage levels plus the legs-up crash; the drone throttle multiplied by `drain`; the comms downlink after
v7's partial-result rule; `surface._finish()` driver-only.
Checked headless: BALANCE OK, 9 screens x Moon/Mars/Saturn, the 66-boot smoke test (`server/test-v5.js smoke`) and both two-client online missions (Mars landing, Saturn drone: identical runs, role locks, requests, signatures, remote events) all pass. Not checked: online
play on 2 real computers, a full mission by hand, the web build in a browser. `docs/play/`, the website
screenshots, README screenshots and both PDFs are refreshed for v7 (29 parts, 20 events).

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
| 2 | ✅ *Done in v7 (`hints` / `assist` keys).* **Hints by difficulty**: Easy shows every hint and warns before a bad launch; Medium shows a warning only after a mistake, or hints that cost points; Hard has none, and only the report explains. Use CubeSat 101 Free-Advice quotes on Easy | Omar's notes; the challenge's "accessible to different knowledge levels" | M |
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
