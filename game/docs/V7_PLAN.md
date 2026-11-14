# AstroPixel v7: the level must matter

Read `AGENT_BRIEF.md` (rules, dev tools, conventions; its flow and destination list are out of date),
then `V6_PLAN.md` (flow, jobs, events, debug hook), then this file. This file wins where they differ.

## What the team asked for (their words, 14 Nov, after playing v6)
"make difficulties matter so its okay for ppl to fail the hard ones, medium diff shouldnt have auto build
and give less hints than easy also the tasks and mission and gameplay should be harder than easy, hard
diff shouldnt have hints nor autobuild and harder than medium in all the other ways (launching, landing,
alerts, coms ...), the minigames the small texts should have colors depending on the consequence for
example negative should be red and chances should be yellow and positive should be green, resources
should matter more like money and all these other things but as the diff changes the importance of
resources should matter more also the small changes and additions should matter drastically, also the
celebrating astronauts shouldnt be flying that much, ui for the ship building the one on the left change
icons to be bigger and more clearer and change their graphics to actually match what they mean, also when
the rover is extracting samples the battery wasnt draining."

Do not add features that are not on this list. EASY must stay as easy as v6 (their least experienced
teammate plays it). The new difficulty goes into NORMAL and above all HARD.

## The three levels (set by the chosen task, read ONLY through `Game.diff(key)`)
New keys, already in `Data.DIFFICULTY` (the old keys stay and keep their meaning):

| key | EASY | NORMAL | HARD | meaning |
|---|---|---|---|---|
| `hints` | 2 | 1 | 0 | builder help. 2: guide character, ghost cursor, pulsing tile, SHOW ME, AUTO-BUILD. 1: the guide character only says in one short line what is still missing; no ghost cursor, no pulsing tile, no SHOW ME, no AUTO-BUILD. 0: no guide, no hint texts, no AUTO-BUILD: only the lamps (GO / NO-GO) and the numbers |
| `assist` | 2 | 1 | 0 | minigame help. 2: the computer does the hard part and cues count down (as v6 EASY). 1: cues are shown but the player does every action; the windows are normal. 0: no cues and no countdowns, readouts only; narrow windows |
| `bite` | 0.5 | 1.0 | 1.6 | multiply every loss by this: damage, fuel wasted, minutes lost, event costs, score penalties |
| `fail` | 0 | 1 | 2 | what a player mistake may do. 0: nothing ends the mission; the worst case is a smaller result. 1: a crash, an empty tank or a dead battery loses something real (samples, a part, science), the mission goes on with a partial result. 2: it ends the mission (`Game.fail(text)`, then the report). People are allowed to fail HARD |
| `drain` | 0.6 | 1.0 | 1.4 | battery, oxygen and drone fuel use at the site |

Rule of thumb: NORMAL must feel clearly harder than EASY, and HARD clearly harder than NORMAL, in every
screen. A first-time player should pass EASY always, NORMAL usually, HARD only with a well-built ship
and clean flying. Every text that says why the player lost must name the cause and the fix.

## Consequence colours (every small text in the minigames and on the cards)
- a loss or a danger: `UI.BAD` (red)
- a chance, a risk, a warning that is not yet a loss ("30% chance", "LOW FUEL", "RISKY"): `UI.RISK` (yellow)
- a gain or a good result: `UI.GOOD` (green)
Use exactly these three constants (they are in `scripts/ui.gd`). Neutral facts stay white / dim. This
covers event card effect lines and result chips, pop-up texts over the scene, HUD warnings, result lines.

## Resources matter more, and more on harder levels
- The build must be felt in play: battery Wh = working time at the site, generation = recharge, fuel left
  = landing / drone fuel, mass margin = how the launch goes, antenna rate and storage = how much science
  gets home, money reserve = which event choices are open, instruments = points per sample.
- A small change must show: adding or removing ONE part must visibly move a lamp number in the builder
  and change the matching number in the minigame by a clear amount (about 15% or more).
- A resource rated UNDER at launch must cause something the player sees in flight, scaled by `bite` and
  `fail`: EASY a warning and a small cost, NORMAL a real loss, HARD it can end the mission.
- A resource rated OVER costs efficiency points, scaled by `bite`.
- Budgets: `budget_slack` becomes 1.2 / 1.0 / 0.9.

## Who owns what (edit nothing else; ownership as in V6_PLAN.md, with flight split from front)
| agent | files | work |
|---|---|---|
| core | `scripts/data.gd`, `game.gd`, `events.gd`, `event_card.gd`, `preflight.gd`, `tools/dev/balance.gd`, `art/ui/event_*` | events by level, resource bite, scores, card colours, hint texts by level |
| builder | `scripts/screens/builder.gd`, `ship_kit.gd`, `vab_meta.gd`, `art/parts`, `art/vab`, `tools/art/gen_parts.py`, `gen_vab.py` | hint levels, no AUTO-BUILD above EASY, bigger and truer category icons |
| launch | `scripts/screens/launch.gd` | assist levels, fail rule, colours |
| flight | `scripts/screens/flight.gd` | arrival burn and entry by level, colours |
| landing | `scripts/screens/landing.gd` | assist levels, fail rule, colours |
| surface | `scripts/screens/surface.gd`, `art/surface_v6/`, `tools/art/gen_surface_v6.py` | battery drain while drilling, drain and fail by level, colours |
| probe | `scripts/screens/probe.gd` | drain, assist and fail by level, colours |
| cheer | `scripts/screens/cheer.gd`, `art/cheer/`, `tools/art/gen_cheer.py` | astronauts float far less |
| front | `scripts/screens/menu.gd`, `report.gd`, `README.md` | the menu says what each level means; the report shows a failed mission clearly |
| orchestrator | `scripts/main.gd`, `scripts/ui.gd`, `project.godot`, exports, this file | |

## Working while others work
- **Keep your file parse-valid at every save.** `main.gd` preloads every screen, so one broken file
  breaks every other agent's screenshots. Make each edit complete before you save; never leave a
  half-renamed variable. If a run fails with a parse error in a file you do not own, wait a minute and retry.
- The core agent is changing `game.gd` while you work. Use only the API that exists today plus
  `Game.diff()` with the keys above. Do not wait for the core.
- Screenshots: `bash tools/dev/shot.sh <screen> <dest> <ABSOLUTE out.png> [wait] task=0|1|2 call=debug_x`
  (task 0 EASY, 1 NORMAL, 2 HARD). Scratch files under `<local path>\Games\space-apps-2026\research\work\v7_<label>\`.
- Keep every `debug_*` hook working: the self-play test (`tools/dev/e2e.sh`, `auto=1`) calls `debug_auto` /
  `debug_autopilot` on each screen. The autopilot must still finish EASY and NORMAL tasks; on HARD it may fail.
- The team reviews by eye, so do not over-test: check each level once by screenshot, then stop.
- Final report: under 150 words. What changed per level, what you checked, what is not done.

## v7 core as built (core agent; API notes for the other agents)
Everything old keeps its name and signature. New, all safe to call today:
- **Event counts** (`Data.DIFFICULTY` events_cruise / events_site): EASY 1 / 0, NORMAL 1 / 1, HARD 2 / 1.
  Planned events are already scaled: every cost (fuel, money, days, battery, data, minutes, lost science) x
  `bite`, risk odds x (0.5 + 0.5 x bite), capped at 90%; the choice texts show the scaled numbers.
- **Result chips** `res["chips"]` stay `[icon, text, bad: bool]` and gain a 4th element, the tone:
  `"bad" | "risk" | "good" | "info"`. Colour with `Game.tone_color(tone)` -> `UI.BAD / UI.RISK / UI.GOOD / UI.TEXT`.
  A chip read as `bool(chip[2])` still works. `res["tone"]` is the tone of the whole result.
- `Game.event_choice(ev, i)` adds `"tone"` (of the choice text: risk / bad / good / info) and `"note_tone"`
  (of its note line), and `"tip": bool` = MISSION CONTROL RECOMMENDS this choice (EASY only, hints = 2).
  `Game.recommended(ev) -> int` gives that index, or -1 above EASY.
- **HARD events can end the mission** only when the ship truly cannot pay (a risk burn bigger than the tank,
  power below what keeps the ship alive): `run["dead"]` is set and the log names the cause and the fix.
  On EASY and NORMAL the same cases leave a warning or a real loss instead.
- **Resources rated UNDER at launch** (`run["use"][k]["state"] == "risk"`) now act in the phase functions and
  write a log line (shown in the report): EASY a warning and a small efficiency cost, NORMAL a real loss
  (instrument switched off, data lost, fuel or money lost, days late), HARD the same, bigger, and it can end the
  mission (fuel, power, battery). Penalties collect in `run["short_pts"]` (efficiency points) and
  `run["shorts"]` ([{"key", "text"}]). OVER costs 45 x bite efficiency points per resource. Late days and money
  overspent cost 10 x bite each.
- **A fuel shortfall at arrival or a crash on landing** (`landing_result(false, ...)`) ends the mission only on
  HARD. NORMAL: a real loss (a part broken, days late), the mission goes on. EASY: a warning and a small cost.
- **Builder hints** `Preflight.hint_line(level = Game.diff("hints")) -> String`: 2 = the first open checklist
  step's full hint (as today), 1 = one short line naming only what is missing ("Missing: a power source"),
  0 = "". `Preflight.missing_line() -> String` is the level-1 line on its own. `checklist()`, `stations()` and
  the lamp tips are unchanged for every level.
- Task budgets retuned for `budget_slack` 1.2 / 1.0 / 0.9 (HARD tasks have their own budget now);
  `Game.example_build()` is all green on every task.
- `Preflight.effect(id, n)` also returns `"prop"`, `"pts"` and `"downlink"` deltas. Measured (balance.gd, "one part
  more"): one solar array +100% power on the Moon and Mars (+2% at Saturn, where the RTG gives +33%), one battery
  +50..100% Wh, one instrument +100..150% points a sample, one recorder +800% storage, one tank +5% fuel on the
  Moon's big lander (+50..100% on small ships). The tank step is the only weak one; it is not changed yet.
