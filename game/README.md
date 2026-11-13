# AstroPixel: Mission Designer

Team Shay Rafe3, NASA Space Apps Challenge 2026, challenge "Space Mission Design Game".

## Run it

- Windows: `C:\Games\space-apps-2026\build\windows\AstroPixel.exe` (keep the `.pck` next to it).
- Editor: open `C:\Games\space-apps-2026\game\project.godot` in Godot 4.7.2 and press F5.

## How a mission goes

1. **Menu.** Pick the Moon (easy), Mars (medium) or Saturn (hard), and 1 to 4 players.
2. **Builder.** It works like Kerbal Space Program's assembly building:
   - Pick a part from the bin on the left and drop it on the ship standing in the hangar. The ship grows with every part.
   - Mission Control on the right has one lamp per station (booster, power, fuel, landing, science, data, comms, budget, time, risk). A red lamp says in plain words what is wrong, why (the real physics), and which part fixes it. **SHOW ME** points at that part.
   - Each station belongs to one of four roles (planner, engineer, scientist, comms), so 2 to 4 players each watch their own lamps.
   - **AUTO-BUILD** assembles a ship that works. Undo, redo, and "fill to need" for fuel are there too.
3. **Launch poll.** LAUNCH runs a GO / NO-GO poll station by station, like a real flight director. You can still launch a NO-GO ship to see what breaks.
4. **Flight.** Launch, cruise map, orbit arrival:
   - Power falls with distance from the Sun squared.
   - Fuel follows the rocket equation (Isp 300 s).
   - A real 2024 geomagnetic storm from NASA DONKI hits the ship.
5. **Landing (Moon, Mars).**
   - Controls: UP/W/SPACE fires the engine, LEFT/RIGHT steers.
   - Gravity is the real value, and fuel burns by real mass flow.
6. **Surface.**
   - Controls: arrows to drive, UP to jump, E to drill a rock, E at the lander to finish.
   - Jump height follows real gravity: 3.2 m on the Moon, 1.4 m on Mars.
   - On Mars, night lasts about 12 hours and the rover runs on its battery.
7. **Saturn drone.** Fly from the orbiter into the rings, grab ice grains, dodge rocks and dock back. It is inspired by Cassini's Grand Finale.
8. **Report.**
   - Goals met or missed, with the cause chain ("why") and a tip.
   - A score per role, and a comparison with a real mission.
   - Credits earned. Credits buy tech in the Tech Lab.

## What is real and what is a game rule

- **Real (from NASA and makers):**
  - Gravity, sunlight and distances.
  - Radio delays.
  - Rocket capacities and prices.
  - MMRTG 110 W / 45 kg.
  - Li-ion Wh/kg and solar array W/kg.
  - MRO and LRO data rates.
  - CTX, CRISM and Cassini MAG specs.
  - Delta-v values.
  - Apollo, CAPSTONE, Perseverance and Cassini facts.
  - DONKI storms.
- **Game rules** are marked "game rule" or "game estimate" in `scripts/data.gd`:
  - Part prices for some parts.
  - Landing leg limits.
  - 8 h of DSN contact a day.
  - $10M per year operations.
  - Drone fuel.
- Every number's source is in `scripts/data.gd` (`src` fields) and on the in-game "NASA DATA & CREDITS" screen.

## AI disclosure (for the submission form)

- The game idea and design are the team's.
- Claude (AI) wrote the GDScript code and the scripts that make the art and sound, and the team reviewed it:
  - Spacecraft sprites (rocket, lander, rover, drone, orbiter): simple 3D models built by a Python script in Blender, rendered and turned into palette pixel art (`tools/blender/ships.py`, `tools/art/gen_ships.py`).
  - Planets, backgrounds, ground, rocks and clouds: generated with numpy noise and dithering (`tools/art/gen_bg.py`).
  - Spacecraft parts, launch vehicles, the assembly hall, UI frames and icons, effects (flames, smoke, explosions) and all planets: Blender renders and numpy/PIL generators (`tools/blender/parts.py`, `tools/art/gen_*.py`).
  - All 67 sounds and the five music tracks: synthesized with numpy (`tools/audio/make_sounds.py`, `tools/audio/make_music.py`). No recordings, no samples.
  - The pixel font comes from our earlier game, Rotorfall.
- No NASA logos are used.
- No AI image or video generators were used: every picture is made by code you can re-run.

## Files

- `scripts/data.gd`: all numbers and sources.
- `scripts/donki_data.gd`: real NASA DONKI storm snapshot.
- `scripts/game.gd`: ship maths, simulation, money, save.
- `scripts/screens/*.gd`: menu, builder, flight, landing, surface, probe, report.
- `scripts/preflight.gd`: the GO / NO-GO rules and hints. `scripts/ship_kit.gd`: assembles the ship from part sprites.
- `scripts/fx.gd`: shared sprite effects. `scripts/ui.gd`: the UI kit.
- `scripts/pix.gd`: loads the art, draws pixel text, HUD panels and parallax layers.
- `scripts/audio.gd`: sound effects, engine loops and music.
- `art/`, `audio/`: generated assets. Re-make them with `tools/` (Blender 4+/5, Python with numpy and Pillow).

Debug: `AstroPixel.exe -- screen=builder dest=mars` opens a screen directly, with the example ship.
