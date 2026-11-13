# Status and roadmap

_Last updated: 13 Nov 2026 (evening), when this repo was assembled from Mahdi's v3 export._

## Where we are

**This repository = game v3**, exported by Mahdi after the third build round. It plays end to end on
Windows and in the browser:
- Moon, Mars and Saturn, each start to finish;
- builder with 4 roles and 7 bars;
- GO/NO-GO review board;
- DONKI storm;
- real-gravity landing;
- rover surface;
- Saturn ring drone;
- report;
- Tech Lab;
- Blender pixel art with the depth pass;
- sound and music.

**Not in this repo: "round 4".** After v3, Mahdi's Claude session started a big rebuild with 10
parallel agents:
- a Kerbal-style snap-together builder;
- a mission-control GO/NO-GO hint board with a 3-step first-open guide and AUTO-BUILD;
- a chunky pixel UI kit;
- layered sounds, 5 music tracks and ambience;
- an easier landing (less drift, stronger engine, legs survive 4 m/s instead of 3, a "BRAKE NOW" cue).

That session ended mid-work and nothing was verified. It exists, if at all, only on Mahdi's PC at
`C:\Games\space-apps-2026\` (files such as `ship_kit.gd`, `vab_meta.gd`, `fx.gd`, `AGENT_BRIEF.md`,
`smd_implement.js`). **Treat round 4 as "not done": redo it here on top of v3**, or ask Mahdi for those
files if anyone wants to salvage them.

**Known v3 issues (from playtests and audits):**
- The builder is hard to understand: +/- counters, no clear mission statement, no guidance. **This is
  priority #1.**
- Sounds are thin; the heavy ones are inaudible on laptop speakers.
- Flat UI panels; some screens are still plain shapes. The near mountains have faint vertical streaks
  at their base. The Saturn drone looks crowded next to the ring rocks.
- The landing is hard for first-timers (drift, weak engine, 3 m/s leg limit).
- Nobody has played the landing, rover or drone by hand much yet. Do it.
- Web build: the surface and Saturn screens haven't been clicked through in a browser. Opening
  `docs/index.html` by double-click fails ("Failed to fetch"); it must be served (GitHub Pages, or any
  local server).

## Roadmap (in order; cut from the bottom when time runs out)

| # | Task | Why | Size |
|---|---|---|---|
| 1 | **Builder UX**: a clear mission card at the top; visual slots on the ship in the hangar (click a slot → pick a part); a hint panel saying what's wrong and which part fixes it (reuse `role_issues()` text) | Team's top complaint; judges' first impression | L |
| 2 | **Hints by difficulty**: Easy shows every hint and warns before a bad launch; Medium shows a warning only after a mistake, or hints that cost points; Hard has none, and only the report explains. Use CubeSat 101 Free-Advice quotes on Easy | Omar's notes; the challenge's "accessible to different knowledge levels" | M |
| 3 | **Easier landing** + a "BRAKE NOW" cue on Easy | Playability | S |
| 4 | **Resource-efficiency rating** in the report (Ahmad), separate from success | Challenge: "rewards efficient resource use" | S |
| 5 | **More RNG events** from real stories (`02_NASA_RESOURCES.md` §11), with chance and damage set by the design | "Not the same every time"; the lessons | M |
| 6 | **Report upgrade**: CML-style green/yellow/red with critical items; "top 2 changes that would have helped most" (re-score with alternative parts); "this really happened to ___" | Strongest judging screen | M |
| 7 | **Mission goals per the team notes (§3):** Saturn photo + downlink as the main goal (drone as bonus); Mars core delivered to a pickup point; Moon return as a bonus. Remove the "+$100M grant" tech (§5.7) | Match the team's mission vision (decisions D1, D2 in `03_GAME_DESIGN.md` §5) | M |
| 8 | Sound pass (heavier layered effects, more music) | Polish | M |
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
