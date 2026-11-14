# AstroPixel v6: simpler, shorter, clearer

Read `AGENT_BRIEF.md` first (rules, dev tools, code conventions; its "flow of screens" and destination
list are out of date, this file wins), then this file. `V5_DESIGN.md` is the v5 contract; it still holds
wherever this file does not change it.

## What the team asked for (their words, 14 Nov, after playing v5)
"less random events, better building ui a little bigger and more clearer, when i press a budget or weight
where the show me button shows it should stay there when i click it like the ui that comes when i hover,
simplex the launching and landing a little more, there should be a diff between random events and coms
from earth u could tell the diff, simplex a little the random events and they should be a little lower
and a lower impact, hopping above rocks are a little not realistic lets make it better, the landing on
planets are a little too long, the coms tells u what to do with options but without alot of bad impacts
its not that important on the gameplay make it a little simpler, make launching the rocket a little
faster and simpler, the spaceship shouldnt go back to earth only send what the task needs, the ui of the
launching is a little complex needs just a little simplification, in general the game is good yet it
needs just a little simplification bcs we also want students to know how to play the game, the drone
dropped on no landing planets should get u a confirmation if u want to go back to the ship bcs sometimes
u go back by accident, there should be diff tasks like take pictures, moon and mars a task that need an
astronaut not a rover like a human being with a diff task, add a cutscene when we go back to the
spaceship after getting samples the scientists in the ship are cheering for the discovery."

The audience is students and first-time judges. When in doubt: fewer things on screen, bigger text, one
instruction at a time, shorter waits. Do not add features that are not on this list.

## Team rules that still hold
- Every number is real NASA data or labelled "game rule". Details must be true (scale order, units, facts).
- No "THIS REALLY HAPPENED" strip on decision cards.
- Directions stay on screen until the player has done them.
- The difficulty comes from the chosen TASK, never from the planet. Screens read it only via `Game.diff(key)`.

## New flow
menu -> builder -> launch -> flight (cruise + arrival) -> landing -> surface   (land worlds)
                                                       -> probe             (ring worlds)
-> cheer (new cutscene) -> report.

**There is no flight home any more.** The ship stays at the destination. Only what the task needs goes
to Earth: the data by radio, and for some tasks a small sample capsule or the crew capsule. The "home"
stage in `flight.gd` is no longer reached.

How the site screens end (surface.gd and probe.gd):
```gdscript
Game.surface_result(got, battery, data)      # or Game.probe_result(got, docked, data), unchanged signatures
Game.goto("cheer")                           # always; nothing else
```
`main.gd` (orchestrator's file) handles "cheer": it calls `Game.phase_home()` and `Game.finish()`, then
shows the cutscene, or jumps straight to the report when the ship is dead or nothing was collected.
The cutscene screen only presents: it reads `Game.run` / `Game.run["report"]` and ends with `Game.goto("report")`.

## Jobs: three kinds of task
Each task in `Data.TASKS` gets `"job"`: `"drill"` (as v5), `"photo"` or `"crew"`.
The count stays in the task's `samples` field / `Game.dest()["samples_goal"]` for every job, and the
site screens still report one number (`got`), so `surface_result` / `probe_result` do not change.

| job | land world | ring world | needs on board |
|---|---|---|---|
| drill | drive the rover, drill rocks | drone collects ring samples | drill (land) / drone (ring) |
| photo | drive to viewpoints, take pictures | drone photographs ring features | camera; drill NOT NEEDED |
| crew  | an astronaut walks, sets up science stations by hand (Moon and Mars only) | none | crew cabin (new part `crew`), ascent stage; rover NOT NEEDED |

Screens read the job with this exact helper (it works before and after the core lands, and the debug
hook can override it with `job=photo` / `job=crew`):
```gdscript
func _job() -> String:
	return String(Game.run.get("job", Game.task().get("job", "drill")))
```
Words: drill -> "SAMPLES" (noun from the skin, as v5); photo -> "PHOTOS"; crew -> "STATIONS".

Task list (core agent finalises names, texts and numbers; three per destination, EASY / NORMAL / HARD):
- Moon: PHOTO SURVEY (photo) / SAMPLE RETURN (drill, sample capsule goes home) / CREW MOONWALK (crew:
  2 astronauts set up 3 science stations, as Artemis III plans with LEMS, LEAF and LDA; crew capsule goes home)
- Mars: PHOTO SCOUT (photo) / ROCK SURVEY (drill) / FIRST FOOTSTEPS (crew; a future mission in NASA's
  Moon to Mars plan, say so in the text)
- Mercury, Venus: one photo task each (Venera 13 sent the first colour panoramas from Venus), two drill tasks
- Jupiter, Saturn, Uranus, Neptune: EASY task is photo (the drone photographs the rings), the others drill

## Events: fewer, simpler, softer, and two clearly different kinds
- Count: at most 1 on the way and 1 at the site on EASY and NORMAL, at most 2 on the way on HARD. None after the site.
- Every event has `"from"`: `"ship"` (something happened to the ship: a hazard) or `"earth"` (a message
  from mission control). The card shows them differently at a glance:
  - ship: amber ALERT card, hazard stripes, warning icon, alarm sound.
  - earth: blue/green MESSAGE FROM EARTH card, radio-wave icon and an operator portrait, a radio blip,
    one line "sent N minutes ago" from the destination's real light delay. Short advice, two options, small effects.
- Two choices per event, text short enough for a student to read in 5 seconds.
- Lower impact: roughly half the v5 costs; no event ends the mission by itself.
- API unchanged: `Game.next_event(phase)`, `EventCard.open(parent, ev, done)`, `EventCard.is_open()`,
  `Game.event_choice`, `Game.resolve_event`.

## Who owns what (edit nothing else)
| agent | files |
|---|---|
| core | `scripts/data.gd`, `scripts/game.gd`, `scripts/events.gd`, `scripts/event_card.gd`, `scripts/preflight.gd`, `tools/dev/balance.gd`, `art/ui/event_*` |
| builder | `scripts/screens/builder.gd`, `scripts/ship_kit.gd`, `scripts/vab_meta.gd`, `art/parts`, `art/vab`, `tools/art/gen_parts.py`, `tools/art/gen_vab.py` |
| launch | `scripts/screens/launch.gd`, `art/launch`, `tools/art/gen_launch.py` |
| landing | `scripts/screens/landing.gd` |
| surface | `scripts/screens/surface.gd`, `art/surface_v6/` (new), `tools/art/gen_surface_v6.py` (new) |
| probe | `scripts/screens/probe.gd` |
| cheer | `scripts/screens/cheer.gd`, `art/cheer/` (new), `tools/art/gen_cheer.py` (new), `audio/` one new cheer sound + its one line in `scripts/audio.gd` |
| front | `scripts/screens/menu.gd`, `scripts/screens/report.gd`, `scripts/screens/flight.gd`, `README.md` |
| orchestrator | `scripts/main.gd`, `project.godot`, exports |

Shared files nobody edits: `scripts/ui.gd`, `scripts/pix.gd`, `scripts/fx.gd`, `scripts/audio.gd` (except the cheer line).
No new sounds except the cheer; reuse what `Audio` has (a missing name is silently ignored).

## Working while others work
- The core agent is editing `data.gd` / `game.gd` at the same time as you. If a screenshot run fails with a
  parse error in a file you do not own, wait a minute and run it again. Do not fix other agents' files.
- Debug hook (in `main.gd`): `shot.sh <screen> <dest> out.png [wait] task=0|1|2 job=drill|photo|crew call=debug_x`.
  dest: moon mercury venus mars jupiter saturn uranus neptune. `task=` picks the task (default 1).
  `job=` forces `Game.run["job"]` so you can test photo and crew before the core's task list lands.
- Scratch files under `<local path>\Games\space-apps-2026\research\work\v6_<your label>\`.
- Keep every `debug_*` hook working; the orchestrator's end-to-end test uses them (`debug_auto` etc.).
- Final report: under 200 words. What changed, what you verified by screenshot, what is not done.
