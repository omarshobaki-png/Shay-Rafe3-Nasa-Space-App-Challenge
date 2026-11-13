# Previous build session: what was said, decided and built

Source: M7e's Claude Code session "Nasa" (shared read-only link:
https://claude.ai/code/cshk_01Ut5Tc172XeQ33sXj7v9yu3Bw9RiJ23b1GwcQS192uE2W).
Captured from the shared page. That session also contains an **unrelated project** (the "Hydrogen
Garden" / Pyrothalassa video and 4-page report for Team Selection Challenge A, team "Shay Rafe3").
Only the NASA game parts are summarized here.

> M7e = Mahdi. **This repository contains Mahdi's v3 export** (game/, research/, docs/ web build,
> screenshots/). The unfinished round 4 (section 1, step 12) is **not** included. Paths below like
> `C:\Games\space-apps-2026\` are on Mahdi's PC; in this repo the same files are at the repo root.
> See `04_STATUS_AND_ROADMAP.md`.

---

## 1. Timeline of the session (NASA game only)

1. **Challenge choice.** Two 2026 challenges were considered: *Space Mission Design Game* and
   *Junior Astronaut Mission Trainer*. Team chose **Space Mission Design**.
2. **Research.** Claude read the challenge Details + Resources tabs (9 resources), the submission
   guide and the judging guide, using 5 research agents. Notes were saved to
   `C:\Games\space-apps-2026\research\` (`notes-rules.md`, `notes-challenge.md`, `STUDY.md` and
   others).
3. **Engine.** Godot 4 (installed version: **4.7.2**, plus export templates). GDScript only, not C#,
   because Godot 4 can't export C# to the web.
4. **Team's idea (from the team, not AI).** A 2D game: build your rocket ship with limited resources.
   Each part has power use etc. The 6 resources are Mass, Power, Budget, Data, Communications and Time.
   You watch the ship fly from Earth to its destination; the outcome depends on how you built it (e.g.
   you land on the Moon but can't get home because you're out of power). It has a money system for
   upgrades, 3 difficulties (Easy = Moon, Medium = Mars, Hard = Saturn), landing animations, and
   walking on the planets.
5. **Claude's review of the idea.** Strong core loop. Problems: Saturn has no surface (suggested
   Titan). Missing pieces: up to 4 players with roles, a mission goal with instruments, a rocket +
   orbit choice with a mass-fits-rocket check, and NASA data at the core. Scope: 80–110 person-hours
   for everything, 45–60 for a trimmed version.
6. **Team decision on Saturn:** keep Saturn. The mission is to *get close to Saturn, then send a robot
   to collect something*. This became **orbit + a robot drone that flies into the rings to grab ice
   samples and docks back** (based on Cassini's 2017 Grand Finale).
7. **Build v1** (the hackathon had started). All 3 missions playable end to end, Windows build exported.
8. **Graphics pass 2.** Rotorfall-style pipeline: Blender 3D models, rendered and converted to
   toon-lit pixel sprites, generated planets and parallax backgrounds, Rotorfall's pixel font, particles,
   screen fades, sound effects and 2 music loops.
9. **Graphics pass 3 (Pixel Car Racer references).** Ships about twice as big with more detail, 3D-lit
   mountain ranges, a "Mode 7" perspective floor, rocks at many depths, contact shadows, tire tracks,
   Mars-night headlights, and the builder turned into a hangar with a glossy floor.
10. **Web build.** Only the 23 MB of web templates was fetched (the full 1.28 GB download was too
    slow). Outputs: `build\SpaceMissionDesigner-web.zip`, then `build\SpaceMissionDesigner-web-PLAY.zip`,
    which adds `PLAY.bat` + `serve.ps1` as a local server, because double-clicking index.html gives
    "Failed to fetch".
11. **Latest feedback from the team:** "interface is kinda trash, ship building too complicated, need
    hints / better UI, builder should be like Kerbal Space Program, sounds weak, visuals need polish."
12. **Round 4 (IN PROGRESS when the session ended; the CLI restarted and the `smd_implement` workflow
    shows "Stopped").** Claude ran 4 audits and then launched 10 build agents for:
    - a **Kerbal-style builder**: a parts bin on the left, snap parts onto the ship standing in the
      hangar, and the ship grows with each part;
    - a **GO / NO-GO mission-control board** on the right: one lamp per station, saying in plain words
      what's wrong and which part fixes it. Also a 3-step first-open guide and an AUTO-BUILD example;
    - layered, heavier sound effects, builder sounds, 5 music tracks and per-screen ambience;
    - a visual pass on every screen, a chunky pixel UI kit, and sprite effects for flames, smoke and
      explosions;
    - an **easier landing**: less starting drift, a stronger engine and side thrusters, legs that
      survive 4 m/s instead of 3, and a "BRAKE NOW" cue.

    Already done in this round: a single pixel scale everywhere, example ships cleaned up, and a backup
    at `C:\Games\space-apps-2026\backups`.
    **Not done:** nothing from round 4 was verified or exported. **Check what state the code is in
    before continuing.**

## 2. What the v1–v3 game contains (as reported)

- **Menu:** Moon (easy), Mars (medium), Saturn (hard); 1–4 players; Tech Lab (upgrades); How to Play;
  NASA data & credits page.
- **Builder:** 4 role tabs (**Planner, Engineer, Scientist, Comms**), each with its own Sign Off.
  - 7 live bars: mass, power, fuel, budget, time, data and comms. Hovering any part or bar shows its
    NASA source.
  - EXAMPLE SHIP button (a working ship for demos).
  - A review board gives GO / NO-GO per resource. You can still launch a bad ship and watch it fail.
- **Flight:** launch animation, then a transfer-orbit map, then arrival in orbit.
  - Solar power falls with distance from the Sun; fuel follows the rocket equation.
  - **A real 2024 solar storm from NASA DONKI** (e.g. the Kp 9 storm of 10 May 2024). Without
    shielding, an instrument is damaged.
- **Landing:** real gravity. Mars needs a heat shield and a parachute, or you burn up or crash.
- **Surface:** drive the rover and drill glowing rocks.
  - Jumps are 3.2 m on the Moon and 1.4 m on Mars (real gravity).
  - Mars nights drain the battery.
  - On the Moon you need 30% battery at the end, or you're stranded.
- **Saturn:** reach orbit, then fly the drone into the rings, grab ice, dodge rocks and dock back to the
  orbiter.
- **Report:** each goal met or missed, why, a tip, a score per role, a real-mission comparison, and
  credits for upgrades.
- **Data:** all numbers and their sources are in `game/scripts/data.gd`; values made up for gameplay
  are labelled "game rule".
- **Docs:** `game/README.md` has the controls and a ready-made AI disclosure. It says the idea is the
  team's, and that Claude wrote the code and the code-drawn art; no AI image generators were used.
- **Builds:**
  - `C:\Games\space-apps-2026\build\windows\SpaceMissionDesigner.exe` (keep the .pck next to it);
  - web zips in `build\`.

## 3. Key research findings from STUDY.md (as reported in the chat)

- **Judging:** 5 criteria scored 1–5 (incl. Relevance, Validity, Creativity). The demo is at most
  **30 s of video or 7 slides**. **The idea must not be AI-generated**, and AI use must be disclosed in
  the submission's AI field. Any AI-made image needs a visible watermark. 1,887 teams were listed for
  this challenge.
- **JPL CML margins (point design):**
  - ≥35% spare mass, power and battery energy;
  - ≥100% spare computer capacity;
  - comms link margin +3 dB for deep space, +6 dB for near links;
  - a backup rocket, a 5×5 risk chart, and "full" and "minimum" science goals.
- **GMAT:**
  - now on GitHub (github.com/nasa/GMAT) with its full manual;
  - tutorials include ~35 min eclipses and contact windows (6 min in LEO vs 29 h from GEO);
  - solar power model: falls with distance², −5% per year of age, zero in shadow.
- **Prices and rockets:**
  - SpaceX rideshare: $0.35M for up to 50 kg, then $7,000/kg ($0.7M for 100 kg, $5.82M for 1,000 kg);
  - Falcon 9: 22,800 kg to LEO, 8,300 kg to GTO, 4,020 kg to Mars;
  - Electron: 300 kg to LEO.
- **2025 finalists:** of all 45, none was a mission-design game. The closest was TechNova's asteroid game
  (Learn / Simulate / Mitigate).
- **CubeSat survey (855 CubeSats):** ~75% succeed (excluding rocket failures); ~20% of failures happen
  at launch or release; 64% are 3U.
- **Goddard MDL week:** Monday first mass and power numbers, Wednesday design frozen, Friday present.
  About 20 roles.
- **Real NASA values suggested:**
  - gravity: Moon 1.62, Mars 3.71, Titan 1.35 m/s²;
  - sunlight vs Earth: Moon 100%, Mars 43%, Saturn ~1%;
  - radio delay: Mars 3–22 min, Saturn ~1 h 20 min;
  - RTG 110 W / 45 kg.
- **NASA data ideas:**
  - Planetary Fact Sheet;
  - DONKI space weather (bundle a snapshot; don't call it live);
  - JPL Horizons;
  - DSN Now;
  - LRO / HiRISE / Huygens imagery;
  - an end-screen comparison with LRO, Perseverance/MRO, Huygens/Dragonfly.
- **Cut order if short on time** (Claude's advice): Titan/Saturn extras first, then the orbiter option,
  then photos. Never cut the roles, the rocket-fit check, the "why" report or the NASA data.

## 4. Settings and advice from that session

- Use Opus 5.5 for most coding, Fable 5.2 for the hardest problems, Sonnet 5.5 for small edits. Tell
  the model "Godot 4.x, GDScript".
- Godot pixel settings:
  - texture filter Nearest;
  - stretch mode `canvas_items` with a small base size (e.g. 640×360);
  - web export with threads off.
- Keep a list of which AI/model wrote what, for the submission's AI disclosure.

## 5. Files that session produced (Outputs panel list; contents are on M7e's PC)

| Area | Files |
|---|---|
| Game scripts | `main.gd`, `game.gd`, `data.gd`, `ui.gd`, `menu.gd`, `builder.gd`, `flight.gd`, `landing.gd`, `surface.gd`, `probe.gd`, `report.gd`, `pix.gd`, `audio.gd`, `fx.gd`, `ship_kit.gd`, `vab_meta.gd` |
| Tests | `fx_test.gd`, `kit_test.gd`, `check_builds.gd` |
| Shaders and data | `floor.gdshader`, `songs.json` |
| Art generators (Python/Blender) | `ships.py`, `gen_ships.py`, `gen_bg.py`, `gen_terrain.py`, `palette.py` |
| Tooling | `shot.sh`, `godot_import.sh`, `fetch_web_tpl.py`, `smd_implement.js` (agent build plan) |
| Docs | `README.md`, `STUDY.md`, `notes-challenge.md`, `notes-rules.md`, `AGENT_BRIEF.md`, `nasa-space-apps-2026.md` (memory) |
| Builds | `SpaceMissionDesigner-web.zip`, `SpaceMissionDesigner-web-PLAY.zip`, `PLAY.bat`, `serve.ps1` |
| Screenshots | `menu.png`, `builder.png`, `launch.png`, `moon_surface.png`, `mars_surface.png`, `saturn_arrive.png`, `saturn_drone.png`, `surf_mars.png`, `exe_probe.png`, `v3_before_after.png`, `v3_surface_moon.png`, `v3_surface_mars.png`, `v3_landing_mars.png` |
