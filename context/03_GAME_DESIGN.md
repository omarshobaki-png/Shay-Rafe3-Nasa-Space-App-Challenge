# Game design: what is built (v3), what's still missing, and the decisions

## 1. The loop

```
MENU ──► BUILDER ──► REVIEW BOARD ──► FLIGHT ──► LANDING ──► SURFACE ──► REPORT ──► TECH LAB ──► (retry)
 pick     4 roles,     GO / NO-GO       launch,     Moon/Mars   drive,      why it     spend
 Moon/    7 bars,      per resource     cruise      real        drill,      worked /   credits
 Mars/    real parts   (can launch      + DONKI     gravity     battery     failed,
 Saturn   + rocket     a NO-GO ship     storm,                  (Mars       score per
 1-4 pl.  + path       anyway)          arrive      Saturn ──►  nights)     role, real
                                                    PROBE (drone            mission
                                                    in the rings, dock)     comparison
```

## 2. Code map (all under `game/`)

| File | What it does |
|---|---|
| `project.godot` | Godot 4.7 config: 640×360, `canvas_items`, nearest filter, autoloads `Data`, `Game`, `Audio` |
| `scripts/data.gd` | **All numbers + sources**: `DEST` (Moon/Mars/Saturn), `ROCKETS`, `PARTS`, `ROLES`, `TECH`, `OBJ_NAMES`, `SOURCES` |
| `scripts/donki_data.gd`, `data/donki.json` | Real NASA DONKI geomagnetic-storm snapshot (2024–25) |
| `scripts/game.gd` | State + maths: `calc()` (totals and bar status), `role_issues()` (GO/NO-GO text), rocket equation, `phase_launch/cruise/arrive/home`, `landing_result`, `surface_result`, `probe_result`, `finish()` (score, credits, role scores), save/load (`user://save.json`), `buy_tech()` |
| `scripts/main.gd` | Screen switching; debug args (`-- screen=builder dest=mars`) |
| `scripts/screens/menu.gd` | Title, mission select, player count, Tech Lab, How to Play, NASA data & credits |
| `scripts/screens/builder.gd` | Role tabs, part list (+/- counts), bars, rocket/trajectory pick, EXAMPLE SHIP, sign-off, review board |
| `scripts/screens/flight.gd` | Launch animation, cruise map (transfer orbit), arrival, trip home |
| `scripts/screens/landing.gd` | Lander physics with real gravity, fuel by mass flow, touchdown limits |
| `scripts/screens/surface.gd` | Rover drive/jump/drill, parallax + perspective floor, Mars night battery drain |
| `scripts/screens/probe.gd` | Saturn ring drone: collect ice, dodge rocks, dock to the orbiter |
| `scripts/screens/report.gd` | Objectives, cause chain, tips, role scores, real-mission comparison, credits |
| `scripts/pix.gd`, `scripts/ui.gd` | Pixel text, panels, parallax helpers, UI widgets |
| `scripts/audio.gd` | Sound effects, engine loops, 2 music tracks |
| `shaders/floor.gdshader` | "Mode 7" perspective ground |
| `tools/blender/*.py` | Blender scripts that model and render the ships → `tools/art/gen_ships.py` turns them into pixel sprites |
| `tools/art/gen_bg.py`, `gen_terrain.py`, `palette.py`, `compose3d.py` | Generated planets, backgrounds, terrain, palette |
| `tools/audio/*.json` | Sound and music generator recipes |

## 3. The three missions as built (numbers from `data.gd`)

| | **MOON (Easy)** | **MARS (Medium)** | **SATURN (Hard)** |
|---|---|---|---|
| Budget | $300M | $500M | $900M |
| Required mass margin | 10% | 20% | **35% (real JPL CML 4 value)** |
| Time limit | 365 days | 730 days | 5,110 days |
| Gravity | 1.62 m/s² | 3.71 m/s² | 10.44 m/s² (cloud tops) |
| Sunlight | 1,361 W/m² | 586 W/m² (43%) | 14.8 W/m² (~1%) → needs RTG |
| Atmosphere | none (no chutes/shields) | thin → **heat shield + parachute needed** | gas giant, no surface |
| Paths | Direct (Apollo, 3 d) / Low-energy (CAPSTONE, 138 d, −25% Δv) | Hohmann (Perseverance, 203 d) / Fast (150 d) | Gravity assists (Cassini, 2,447 d) / Direct Hohmann (2,225 d, capacity ×0.3) |
| Objectives | launch, arrive, land, samples (3), **return** | launch, arrive, land, samples (4), downlink | launch, arrive, deploy drone, samples (5), dock, downlink |
| Special rules | Keep 30% battery at the end or you're stranded; needs an ascent stage to bring samples home | Nights of 12.3 h on the battery; dust lowers solar (0.8) | Drone through the rings (Cassini Grand Finale) |
| Reward per objective | 20 | 30 | 50 |

**Parts** (`PARTS`; the `cat` field):
- **core:** bus (always included);
- **power:** solar 1 kW, light solar 2 kW (tech), MMRTG 110 W, battery 2 kWh, high-capacity battery
  4 kWh (tech);
- **comms:** low-gain, medium-gain, high-gain 3 m dish, Ka-band dish (tech), recorder 256 Gb;
- **science:** CTX camera, CRISM spectrometer, Cassini MAG, dust analyzer, drill and arm;
- **landing:** legs, airbags, heat shield, parachute;
- **robot:** small rover, big rover (tech), drone;
- **return:** ascent stage + capsule;
- **fuel:** propellant 100 kg;
- **protect:** radiation shielding.

**Rockets** (`ROCKETS`): Electron + Photon ($9.95M, 25 kg to the Moon), Falcon 9 ($74M, 4,020 kg),
Vulcan VC6 ($110M, 11,500 kg to the Moon), Falcon Heavy ($150M, 16,800 kg Mars / 6,065 kg Saturn).

**Tech Lab** (`TECH`): light solar, high-energy batteries, Ka-band, big rover, armored drone (3 ring
hits), bigger NASA grant (+$100M).

**Scoring** (`game.gd → finish()`):
- Score = % of objectives met.
- Credits = objectives × reward + samples × science points × 2.
- Role scores:
  - Planner: budget, time, launch.
  - Engineer: mass and power status, arrival.
  - Science: samples vs goal.
  - Comms: % of data sent.

**Random event:** one real DONKI storm per cruise (on Saturn always the strongest, Kp 9). Kp ≥ 7.5 with
no shielding breaks a random science or comms part.

## 4. Gap: the team plan vs v3 code

The plan itself is in [`00_TEAM_NOTES.md`](00_TEAM_NOTES.md). This table lists only what the **code**
still lacks, by section of that file.

| Team notes § | Missing in v3 | Code to touch |
|---|---|---|
| §3 Saturn | Photograph + downlink as the main objective (ring drone becomes a bonus) | `data.gd → DEST.saturn.objectives`, `game.gd`, new photo step, `report.gd` |
| §3 Mars | Deliver the core to a pickup point | `surface.gd`, `game.gd → surface_result()` |
| §3 Moon | "Return" is a bonus, not required | `DEST.moon.objectives`, `finish()` |
| §5.2 Builder | Visual slot builder on the hangar ship (v3 uses +/- lists); heritage vs new-tech parts | `builder.gd`, `PARTS` (add `heritage`, `reliability`) |
| §5.3 Physics | GMAT-computed Δv/trajectories (v3 uses estimates); fuller flight HUD | `DEST[*]` Δv, `flight.gd`, `landing.gd` |
| §5.4 Events | Only DONKI storms exist; add real-story events with design-driven chance and damage | `game.gd → phase_cruise()`, new events table in `data.gd` |
| §5.5 Hints | Mission-control messages/voice; hint level by difficulty; "BRAKE NOW" | new hint helper, all screens |
| §5.6 Report | Resource-use rating; "what you could have done better" | `game.gd → finish()`, `report.gd` |
| §5.7 Progression | Remove the "+$100M grant" tech | `data.gd → TECH.grant`, `game.gd → budget()` |
| §5.8 Multiplayer | Networked 1–4 players, one role each, each on their own computer (v3 only has "share the keyboard" role tabs); host/join lobby; synced build + sign-offs; per-role jobs in flight; solo stays fully offline | `menu.gd` (lobby), `game.gd` (sync state through the host), `builder.gd` (lock other roles' parts), `landing.gd`/`probe.gd` (split controls), new `net.gd` autoload |
| §5.9 Sound | Heavier layered effects, more music | `audio.gd`, `tools/audio/` |

## 5. Decisions

All the earlier open decisions were resolved on 13 Nov 2026 (Claude's pick, at Omar's request). The
reasons are in [`00_TEAM_NOTES.md` §9](00_TEAM_NOTES.md#9-conflicts-resolved).
- **D1 Saturn:** photograph + downlink is the main goal; the ring drone is a bonus.
- **D2 Mars:** drill a core and deliver it to a pickup point.
- **D3 Builder:** visual slots on the hangar ship, using the existing `PARTS` data and maths.
- **D4 Multiplayer (Omar, 13 Nov):** 1–4 players over the network, one role each, each on their own
  computer. No shared keyboard. A single player plays all roles offline.
- **D6 Budgets (Omar, 13 Nov):** Moon $300M, Mars $500M, Saturn $900M, the v3 values (no code change).
- **D5 Efficiency rating:** a separate score for resource use, reported next to the success score.
  Proposed formula: for each of budget, mass and power, full marks when 10–35% of the allotment is left
  at launch, falling off toward 0% (no margin) and toward 60%+ (waste). Average the three.

To change a decision, edit `00_TEAM_NOTES.md` §9 and this list together.

## 6. Code rules

1. Every number lives in `data.gd` with a `src` field.
2. Failure messages explain themselves in plain words, with the real cause and a number ("At 9.54 AU
   your arrays give only 14 W…").
3. The design rules from the team notes (§1, §3, §5.4) still apply: every feature must make a choice
   matter; each mission teaches one idea; randomness is fair; players can always launch a bad ship.
