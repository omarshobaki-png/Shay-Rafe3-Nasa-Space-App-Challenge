# Status and roadmap

_Last updated: 13 Nov 2026 (night), when Mahdi's v4 export (round 4) was merged into this repo._

## Where we are

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
| 9 | **Networked multiplayer, 1–4 players** (team notes §5.8): host/join lobby, one role per player, synced builder and sign-offs, per-role jobs in flight. The web build needs WebSocket/WebRTC + a relay server; the Windows build can use ENet on a LAN. **Do a 2-computer test in the first hour of this task**, since it's the riskiest item (earlier estimate: 10–15 h) | Challenge "collaboration for up to 4" | L |
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
- [ ] Submitted before **Sun 15 Nov 2026, 23:59 local time**
