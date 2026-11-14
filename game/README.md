# AstroPixel v6: Mission Designer

Team Shay Rafe3, NASA Space Apps Challenge 2026, challenge "Space Mission Design Game".
Pick a world, choose a task, build a spacecraft under real limits, fly it, land it, do the job and send the result to Earth.

## Run it

- Windows: run `build/windows/AstroPixel.exe` (keep the `.pck` next to it).
- Web: `build/web/index.html` (serve the folder over http; it needs WebGL 2).
- Editor: open `game/project.godot` in Godot 4.7.2 and press F5.
- Export: Project > Export, presets "Windows Desktop" (`build/windows/AstroPixel.exe`) and "Web" (`build/web/index.html`). Headless: `godot --headless --path game --export-release "Windows Desktop"`.
- Jump to a screen for testing: `AstroPixel.exe -- screen=builder dest=mars task=1` (screens: menu, builder, launch, flight, landing, surface, probe, cheer, report; destinations as below). Add `call=debug_x` to run a `debug_*` method of the screen.

## How a mission goes

1. **Menu.** Click a world, then one of its 3 tasks. Each task shows its job (SAMPLES, PHOTOS or CREW) and its difficulty. The briefing says what is critical, what ends the mission, and what goes to Earth. 1 to 4 players share the roles: planner, engineer, scientist, comms.
2. **Builder.** Drag parts onto the ship in the hangar, like Kerbal Space Program. Mission Control has a lamp per limit (mass, power, fuel, landing, science, data, comms, budget, time). A red lamp says what is wrong and which part fixes it; SHOW ME points at the part. AUTO-BUILD makes a ship that works.
3. **Launch.** A GO / NO-GO poll, then the rocket lifts off.
4. **Flight.** A cruise map and the arrival burn. Sunlight, fuel and radio delay follow real physics. At most one or two events happen on the way: an amber "!" is something that happened to the ship, a blue "!" is a message from Earth.
5. **Landing** (land worlds). Fire the engine and steer down gently.
6. **At the site.**
   - Land worlds: drive the rover, or walk as an astronaut on a crew task.
   - Ring worlds: fly the drone from the orbiter into the rings.
   - After a drone drop you are asked before you go back to the ship, so nobody leaves by accident.
7. **Discovery cutscene.** The scientists on the ship cheer for what you found.
8. **Report.** A grade (A, B or C), then three pages: overview, journey, build report. Credits go to the Tech Lab.

The ship never flies home. Only what the task needs goes to Earth: the data by radio, a small sample capsule, or the crew capsule.

## 8 destinations, 3 tasks each

Moon, Mercury, Venus, Mars (land worlds) and Jupiter, Saturn, Uranus, Neptune (ring worlds, flown with a drone). Every world has an easy, a normal and a hard task. Difficulty comes from the task, never from the planet. Each task has one job:

| job | what you do | counted as |
|---|---|---|
| drill (SAMPLES) | drill rocks with the rover, or grab ring grains with the drone | samples |
| photo (PHOTOS) | take pictures at viewpoints, or photograph ring features | photos |
| crew (CREW) | astronauts set up science stations by hand (Moon and Mars) | stations |

## Controls

- Mouse: click and drag in menus and the builder.
- Flight, landing: SPACE or UP fires the engine or holds the burn, LEFT and RIGHT steer. Hold SPACE to fast-forward the cruise.
- Surface and drone: arrows or WASD move, E acts (drill, photo, set up a station, finish), SPACE or UP jumps or thrusts.
- ESC goes back or closes a card; ENTER confirms.
- Event cards: click one of the two choices.

## What is real and what is a game rule

- **Real (NASA and makers):** gravity, sunlight and distances, radio delays, rocket capacities and prices, MMRTG 110 W / 45 kg, battery and solar array specific energy and power, MRO and LRO data rates, delta-v values, Apollo, Chang'e 5, Venera 13, Perseverance and Cassini facts, and real DONKI space-weather storms.
- **Game rule** (marked "game rule" or "game estimate" in the data): some part prices, landing leg limits, 8 h of DSN contact a day, $10M a year of operations, drone fuel, task budgets and counts.
- Where the NASA numbers come from: every number's source is in `scripts/data.gd` (`src` fields and the `SOURCES` list) and on the in-game "NASA DATA & CREDITS" screen. Storm data is a snapshot in `scripts/donki_data.gd`.

## AI disclosure (for the submission form)

- The game idea and design are the team's.
- Claude (AI) wrote the GDScript and the scripts that make the art and sound; the team reviewed it.
  - Spacecraft, parts and launch vehicles: simple 3D models built by Python scripts in Blender, rendered and turned into palette pixel art (`tools/blender/`, `tools/art/gen_*.py`).
  - Planets, backgrounds, ground, rocks, clouds, UI frames, icons and effects: numpy and PIL generators (`tools/art/`).
  - All sounds and music: synthesized with numpy (`tools/audio/`). No recordings, no samples.
  - The pixel font comes from the team's earlier game, Rotorfall.
- No NASA logos are used. No AI image or video generators were used: every picture is made by code you can re-run.

## Files

- `scripts/data.gd`: all numbers, tasks and sources. `scripts/game.gd`: ship maths, simulation, money, save.
- `scripts/events.gd`, `scripts/event_card.gd`: the events and their cards.
- `scripts/screens/*.gd`: menu, builder, launch, flight, landing, surface, probe, cheer, report.
- `scripts/preflight.gd`: the GO / NO-GO rules and hints. `scripts/ship_kit.gd`: builds the ship from part sprites.
- `scripts/fx.gd` effects, `scripts/ui.gd` UI kit, `scripts/pix.gd` art and pixel text, `scripts/audio.gd` sound.
- `art/`, `audio/`: generated assets. Re-make them with `tools/` (Blender 4+, Python with numpy and Pillow).
