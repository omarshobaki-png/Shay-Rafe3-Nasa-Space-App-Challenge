# Space Mission Designer v5: design for this round

Read `AGENT_BRIEF.md` first (rules, tools, conventions). This file says what changes now and how the
pieces fit. It is the contract between agents working in parallel: names and shapes written here are
fixed; ask for a change in your report rather than inventing a different one.

## Why (the team's words, 13 Nov, late)
"apply [the NASA margins]... the game needs some polishing, something to do during the flight and the real
tension, but make sure everything is on the NASA resources and rules for the game. We want the main menu
better and not only focusing on 3 planets: we want to see all the planets and choose which planet we want
to go to, then build based on the planet's requirements. The player must be more involved, not just press
random things. The harder the mission, the harder the task. Random events should happen while you are
going to the planet, on the planet, and going back, so we can see decision making and how it affects the
game and the final results. Make sure the journey is fun and a little easier to understand, because the
judges will be seeing the game for the first time and if they get confused we are [lost]."

Judges see it on 14 Nov. First-time clarity beats depth: every screen must say in one line what to do now.

## 1. Eight destinations
Ids: `moon`, `mercury`, `venus`, `mars`, `jupiter`, `saturn`, `uranus`, `neptune` (Earth is home).
Two mission kinds reuse the existing screens:
- `kind = "land"`: flight -> landing -> surface driving -> (return or downlink). Moon, Mercury, Venus, Mars.
- `kind = "ring"`: flight -> orbit -> sampling drone through the rings -> dock -> downlink. Jupiter, Saturn,
  Uranus, Neptune (all four have rings: real).

`Data.DEST[id]` keeps every existing field and gains:

| Field | Type | Meaning |
|---|---|---|
| `kind` | String | `"land"` or `"ring"` |
| `skin` | String | art key, equal to the id |
| `tier` | int 1..5 | difficulty: moon 1, mars 2, venus 3, mercury 3, jupiter 4, saturn 4, uranus 5, neptune 5 |
| `air` | String | `"none"`, `"thin"` (Mars: heat shield and parachute replace fuel) or `"thick"` (Venus: the air does all the braking; needs the pressure hull) |
| `returns` | bool | samples fly back to Earth (Moon only); otherwise the goal is the downlink |
| `critical` | Array[String] | which resources are critical here, from `mass power fuel budget time data comms`; shown on the menu, the briefing and the builder |
| `hazards` | Array[String] | from `heat`, `pressure`, `radiation`, `night`, `dark` (too far for solar), `delay` (long radio delay) |
| `surface_minutes` | float | Venus only: how long a lander lives on the surface (Venera 13: 127 minutes) |
| `goal` | String | one short line: what the player must achieve |
| `needs` | Array[String] | short plain lines: what this place demands of the ship ("Nuclear power: sunlight is 1% of Earth's") |

Screens must stop testing `Game.dest_id == "moon"` and friends. Use the fields: `Game.dest()["kind"]`,
`["air"]`, `["returns"]`, `["skin"]`, `["tier"]`. Art is looked up by skin (see section 7).

Every number carries its source in `src` text as today. A number we chose is marked "game rule" or "game
estimate". Launcher capacity to the new destinations is not published by NASA for most cases: estimate it,
say so, and name the real mission used as the anchor (MESSENGER, Venus Express, Juno, Europa Clipper,
Voyager 2).

## 2. Parts
Existing 26 parts stay. Changes:
- `dest: "saturn"` on the drone becomes `kinds: ["ring"]`. A part may carry `kinds: [...]` or
  `dests: [...]`; `Game.part_available(id)` honours both (and the old `tech` lock).
- Two new parts (sprites and bin icons are being made; ids are fixed):
  - `sunshade` (cat `protect`): a ceramic-cloth sunshade like MESSENGER's. Needed where `heat` is a
    hazard and the craft stays in space near the Sun (Mercury; useful at Venus).
  - `hull` (cat `landing`): a titanium pressure vessel like the Venera landers'. Needed to survive on the
    surface where `pressure` is a hazard (Venus).

## 3. Margins (the team's proposal, checked against JPL's Concept Maturity Level 4 checklist)
One rule everywhere, in `Data.MARGIN`; `DEST[*].margin` goes away.

| Bar | Green needs | Source |
|---|---|---|
| Mass | 35% spare launcher capacity | JPL CML 4 checklist (>= 35% early-design mass margin) |
| Power | 35% more made than used | same |
| Night battery | 35% more stored than the night needs | same ("energy") |
| Fuel | fuel for 110% of the delta-v | game rule (JPL gives no number at this stage) |
| Data storage | 20% spare | game rule |
| Comms | downlink >= 2x the data (3 dB link margin) | JPL CML 4: >= 3 dB deep-space links. The drone-to-orbiter link is a proximity link: 6 dB, shown as a fact |
| Budget | 25% reserve | NASA Discovery 2019 call: 25% reserve required |
| Time | development + cruise + operations inside the launch-to-deadline limit | the challenge asks for "time (development plus operations)" |

Status stays three-state: `bad` (does not work at all: NO-GO), `warn` (works but under the margin: GO, at
risk), `ok` (GO with margin). **Margins are what random events eat.** A ship with no margin flies, and the
first surprise ends it. That is the tension, and it is the real reason NASA carries margin.

Budgets, time limits and launcher capacities are re-tuned so that for every destination at least one ship
is all green, and the cheapest all-green ship leaves under about 10% slack on the binding resource.

Development time (new, game rule): a ship takes longer to build the more kinds of parts it has, and
nuclear power adds time (launch approval for nuclear material is long in reality).

## 4. Decision events
New file `scripts/events.gd` (data + engine) and `scripts/event_card.gd` (the shared pop-up).

An event is a Dictionary:
```
{ "id": String, "phase": "cruise" | "site" | "home",          # site = on the surface or in orbit at the rings
  "kinds": Array (optional), "dests": Array (optional), "needs_part": String (optional),
  "tier_min": int (optional),
  "role": "planner" | "engineer" | "science" | "comms",        # who decides (shown on the card)
  "title": String (<= 28 chars), "text": String (<= 150 chars, what just happened),
  "real": String (<= 140 chars: the real mission this happened to, with year and agency),
  "choices": [ { "label": String (<= 22 chars), "text": String (<= 90 chars: what it costs or risks,
                 with numbers), "cost": {...}, "risk": {"chance": float, "bad": {...}, "save_part": String},
                 "good": bool } , ... 2 or 3 choices ] }
```
Costs and bad outcomes are plain keys the engine applies to `Game.run`: `fuel_kg`, `battery_wh`,
`data_gb`, `days`, `break` (a part id or a category), `samples`, `score`, `hull` (drone), `fail` (text: the
mission ends). `save_part` names a part that removes the risk (radiation shield, sunshade, spare battery).
Every card states the odds and the price in numbers before the player chooses, and the result afterwards.

Engine API (in `Game`, implemented by `events.gd`):
- `Game.event_plan()`: called by `start_run()`; rolls which events this flight gets. Count grows with the
  tier: tier 1: 1 on the way, 1 at the site, 1 on the way back; tier 5: 3, 2, 2. Seeded per run.
- `Game.next_event(phase: String) -> Dictionary`: the next unresolved event of that phase, or `{}`.
- `Game.resolve_event(ev: Dictionary, choice: int) -> Dictionary`: applies it; returns
  `{"ok": bool, "text": String (what happened, <= 120 chars), "effects": Array[String]}` and logs it for
  the report (which choice, good or bad call, what it cost).
- `EventCard.open(parent: Control, ev: Dictionary, done: Callable) -> Control`: pauses the screen's own
  clock (the screen checks `EventCard.is_open()`), shows the card, plays sounds, calls `done(result)`.

Events come from things that really happened (solar storms from DONKI, Galileo's stuck antenna,
Opportunity's dust storm, Spirit's stuck wheel, Apollo 13's tank, Juno's stuck valves, Voyager 2's
receiver, MESSENGER's sunshade, Venera's short life, InSight's dusty panels, Mars Climate Orbiter's units,
JWST's micrometeoroid...). The "real" line is the learning moment; a researcher is verifying every one.

## 5. More to do in flight
- **Launch (the team asked for this by name):** "add how the shuttle gets deployed and detach the
  fuselage, altitude, vertical velocity and pressure when launching the rocket so you could control it
  better". The player flies the ascent instead of watching it:
  - Live gauges: altitude (km), vertical speed (m/s), and air pressure on the rocket (dynamic pressure,
    "max-Q": the moment of greatest stress, real on every launch), plus fuel per stage.
  - Controls a first-timer gets in one line: a throttle (up / down). Throttle back through max-Q or the
    pressure gauge goes red and the rocket takes damage (real rockets throttle down there); push too
    little and gravity eats the fuel.
  - Staged events the player triggers at the right moment, each shown clearly and named: booster or
    first-stage separation (the empty stage falls away), fairing release once the air is thin enough
    (the two shell halves open and drop), second-stage burn to orbit speed, then spacecraft deployment
    (the craft built in the builder, drawn with ShipKit, springs free of the stage and unfolds). A late
    or early call costs fuel or risks damage; the hint line says what to press and when.
  - Outcome feeds the mission: fuel margin used, or damage, through the existing launch simulation
    (keep `Game.phase_launch()` as the source of truth for whether the mass can be lifted at all).
  - Numbers come from real ascents (typical max-Q near 11-14 km altitude and about 30-35 kPa, fairing
    release above about 100 km, orbit near 7.8 km/s); label what is simplified as a game rule.
- Cruise and trip home: the decision events above, at their real point on the map.
- Arrival: the player flies the braking burn: hold to burn, watch the orbit close, release in the green
  band (delta-v from `Game.dv_plan()`, fuel by the rocket equation as today). Too little: the ship flies
  past. Too much: wasted fuel that the landing or the trip home needed. Aerobraking destinations (heat
  shield in thin or thick air) steer an entry corridor instead.
- Harder tiers: narrower bands, more events, less forgiving minigames (more samples, more rocks,
  radiation at Jupiter, the heat clock on Venus). Real gravity always.

## 6. Scoring (the challenge asks for exactly these four)
Mission success (objectives), science value, resource efficiency (money and mass not wasted beyond the
margins), good decisions (event calls). The report shows the four parts and what would raise each.

## 7. Art names (fixed)
Surface and landing, per land skin `S` in `moon`, `mars`, `mercury`, `venus`:
`art/S_range_far.png`, `art/S_range_near.png`, `art/floor_S.png`, `art/pebble_S_0..5.png`,
`art/boulder_S_23.png`, `art/boulder_S_50.png`, `art/sample_S_big.png`, and skies `art/surface/sky_S_*.png`
as the surface agent's code already expects for moon and mars (read `scripts/screens/surface.gd` and
`landing.gd` and match what they load).
Drone screen, per ring skin `R` in `saturn`, `jupiter`, `uranus`, `neptune`: the same set of files that
`scripts/screens/probe.gd` loads for Saturn today, under `art/probe/R_*` (match its naming exactly).
Arrival and menu: `art/planet_<id>_<9|12|22|36|60>.png` exist for all eight planets and the Moon.
Flight arrival close-ups follow whatever `scripts/screens/flight.gd` loads for the current three.
New parts: `art/parts/sunshade.png`, `art/parts/hull.png`, `art/parts/icon_sunshade.png`,
`art/parts/icon_hull.png`, placed by `scripts/ship_kit.gd` like every other part.

## 8. First-time clarity (applies to every screen)
- One line at the top or bottom always says what to do now, in plain words, with the key to press.
- After choosing a destination: a short briefing (goal, what is critical here, what will kill the mission)
  before the builder.
- No jargon without a plain-word gloss the first time it appears (delta-v = "speed change", RTG = "nuclear
  battery").
- Text budgets: titles <= 28 characters, body lines <= 60 characters, never more than 3 lines in a hint.

## 8b. The builder must be calmer (the team, 14 Nov 00:15)
"make the UI simpler for students to play the game, the building menu is overstimulating, we want it
simpler, and some components that tell you that it's required and not required."
- **Every part says how much this mission needs it**, on its bin tile and in its detail card, in words:
  `REQUIRED` (the mission cannot succeed without it here), `RECOMMENDED` (it protects against a named
  risk or raises the score), `OPTIONAL` (extra science or comfort), `NOT NEEDED HERE` (does nothing at
  this destination: a parachute on the airless Moon). The rule lives in `Preflight.part_need(id)` (core
  API) with a one-line reason ("REQUIRED: Mars nights last 12 hours"). Required parts come first in each
  category and carry a small solid badge; not-needed parts are dimmed, sorted last, and say why.
- **One thing at a time.** A short mission checklist (about six steps in plain words: power, radio,
  science, getting down, fuel, rocket) with only the current step lit; the hint box shows only the next
  step. No field of pulsing markers on the craft: at most ONE dashed outline (the next required part).
- **Less on screen.** Mission Control shows a compact row of lamps by default (name + lamp + one short
  value); the need-versus-have numbers and the explanation appear for the selected station only. At most
  three text colours per screen. No more than about 40 words visible in any one panel. Remove or tuck
  away anything a first-time student does not need in the first minute (undo/redo become small icons;
  role legend only when 2+ players).
- A first-time student should finish a working Moon ship in under two minutes by following the
  highlighted step, without reading a number.

## 8c. Details must be true (the team, 14 Nov 00:15)
"the moon is further than the other planets while travelling to it, which is wrong. These little details
you need to focus on, because they help a lot with everything. Make sure you do them 100% correct."
- **No picture may contradict the real scale order.** On the Moon trip map the other planets were drawn as
  nearby points between Earth and the Moon: wrong (Venus at its closest is about 100 times farther than
  the Moon; Mars at least 140 times). On an Earth-Moon map the planets may appear only as an explicitly
  far background: tiny, dim, at the edge, labelled with the true ratio ("VENUS: 100x FARTHER"), never
  between Earth and the Moon or nearer the ship than the Moon.
  Closest distance from Earth divided by the Moon's 384,400 km (NASA planetary fact sheets, minimum
  distance from Earth): Venus 38.2 million km = about 100x; Mars 55.7 = 145x; Mercury 77.3 = 200x;
  Jupiter 588.5 = 1,500x; Saturn 1,195.5 = 3,100x; Uranus 2,581.9 = 6,700x; Neptune 4,305.9 = 11,200x.
  Show them in a small framed strip titled "FAR BEYOND THE MOON (not to scale)".
- On Sun-centred maps the orbit ORDER must be right (Mercury, Venus, Earth, Mars, Jupiter, Saturn, Uranus,
  Neptune) and the map must say "not to scale" when radii are compressed.
- Relative sizes on any screen that shows several bodies together must not invert reality (Jupiter is
  never smaller than Earth; the Moon is never larger than Earth).
- Every number shown to the player has a unit and comes from Data (never typed into a screen); every
  factual sentence is checked against research5actcheck.md before release.

## 8d. Team review notes (14 Nov, from the team chat) - these override anything above that disagrees
1. **Difficulty is not tied to the planet.** The player picks EASY, NORMAL or HARD separately
   (`Game.difficulty`: 0, 1, 2; default NORMAL; chosen on the menu or the briefing, remembered in the
   save). The planet sets the physics and what the ship needs (real numbers: gravity, sunlight, distance,
   air). The difficulty sets how forgiving the game is: how many decision events happen (EASY 1 per leg,
   NORMAL 2, HARD 3), how tight the minigames are (bands, speeds, hazards), how much slack the budget
   has, and how strict the rating is. `tier` in Data.DEST stays only as a description of how demanding
   the destination is ("far and dark"), shown as text; nothing in the rules reads it for difficulty.
   Wherever sections 1, 4 and 5 say "by tier", read "by `Game.difficulty`".
2. **Resources are rated: under-used, well used, or over-used.** For every resource (mass, power, night
   battery, fuel, data storage, comms, budget, time) the game knows how much THIS mission needs. The
   rating per resource: UNDER (below the need, or below the need plus the NASA margin: risky), WELL USED
   (need plus margin, up to a stated ceiling), OVER (far more than the mission needs: wasted mass and
   money). The ceiling is a game rule, stated in the report (suggested: more than twice the margin on top
   of the need). The builder shows the band on each gauge (a green zone between two ticks); the final
   rating uses it. Budgets and limits are tuned to what each mission needs: not so much that anything
   passes, not so little that nothing fits.
3. **Directions stay until the player does the thing.** Every screen where the player has controls
   (launch, cruise, arrival burn, landing, surface driving, ring drone, builder) shows step-by-step
   directions for the tools available right now ("HOLD SPACE TO BURN", "PRESS E TO DRILL"). A direction
   does not disappear on a timer or on any click: it goes away only when the player has performed that
   action, then the next direction appears. Never more than one direction at a time. A small "?" brings
   back the list of controls at any moment.
4. **Report everything at the end.** The final report covers the whole journey: every phase with what
   happened, every decision event with the choice made and what it cost, every objective, the four score
   parts, and the credits.
5. **The build report is at the end too.** The final report has a BUILD REPORT section: for each
   resource, what the mission needed, what the ship carried, the rating (UNDER / WELL USED / OVER) and
   one line on what to change next time. This is where the player learns whether the design was right.

## 9. Core API as built
Written by the core-systems agent after the code passed `tools/dev/balance.gd`. Where this section and
sections 1 to 8 disagree, this section is what the code does. Run the check after any change to the numbers:
`<Godot console binary> --headless --path game --script tools/dev/balance.gd` (prints `BALANCE OK`, exit 0).

### 9.1 Data (`scripts/data.gd`)
- `Data.DEST[id]`: ids `moon mercury venus mars jupiter saturn uranus neptune`. Old fields kept; new:
  `kind` ("land" | "ring"), `skin`, `tier` (text only, no rule reads it), `air` ("none" | "thin" | "thick"),
  `returns` (bool), `critical` (Array of `mass power fuel budget time data comms`), `hazards` (Array of
  `heat pressure radiation night dark delay`), `goal`, `needs` (Array of short lines), `earth_min_mkm`
  (closest distance from Earth, million km, for section 8c), Venus only `surface_minutes` (127.0).
  `margin` is a leftover (0.2) that only the old builder's FILL TO NEED reads: do not use it.
  ```gdscript
  var d: Dictionary = Game.dest()
  if d["kind"] == "ring": Game.goto("probe")     # never test Game.dest_id against a name
  ```
- `Data.MARGIN = {"mass": 0.35, "power": 0.35, "battery": 0.35, "fuel": 0.10, "data": 0.20, "comms": 2.0, "budget": 0.25}`
  (`comms` is a factor: downlink >= 2 x the data). `Data.MARGIN_SRC[key]`: one tooltip sentence per margin
  (also `"time"`), worded as the fact check asked (35% is JPL's dry-mass margin, simplified to rocket lift).
  ```gdscript
  tip.text = Data.MARGIN_SRC["mass"]
  var green_at: float = need * (1.0 + float(Data.MARGIN["power"]))
  ```
- `Data.DIFFICULTY` (Array of 3) and `Data.USE_RULE`, `Data.USE_NAMES`: read them through `Game.diff()` and
  `Game.calc()["use_rule"]`.
- Game-rule constants: `CRUISE_DV` (0.03 km/s of course corrections every ship must carry), `SHADE_ABOVE_WM2`,
  `VENUS_TOUCHDOWN` (7.5 m/s), `RTG_LIFE_YEARS`, `DEV_BASE_DAYS` (200), `DEV_DAYS_PER_KIND` (30),
  `DEV_NUCLEAR_DAYS` (300).
- Parts: `kinds: [...]` and `dests: [...]` limit where a part can fly (drone: `kinds ["ring"]`; drill, legs,
  airbags, heat shield, parachute, rovers: `kinds ["land"]`; `hull`: `dests ["venus"]`; `ascent`:
  `dests ["moon"]`; `sunshade`: `dests ["mercury", "venus"]`). `hull` has `touch: 9.0`. The old `dest` key is gone.
  `OBJ_NAMES["arrive"]` is now "Arrive safely" (Mars and Venus landers enter directly, they do not orbit).
- Rockets: `cap` now covers all eight (`falcon9`: moon mars venus mercury; `vulcan`: moon mercury jupiter;
  `heavy`: all).

### 9.2 Game: tasks and difficulty (`scripts/game.gd`)
- Tasks (team decision, 14 Nov 01:05): the player picks one of three tasks per destination; the task sets
  the difficulty. Data: `Data.TASKS[dest_id]` (three, easiest first).
  - `Game.tasks() -> Array`: the tasks at `Game.dest_id`. `Game.task() -> Dictionary`: the chosen one.
    `Game.task_idx: int`. `Game.set_task(i: int) -> void`: sets `task_idx` and `Game.difficulty`, clears the
    sign-offs, keeps the ship. `Game.last_task: Dictionary` ({dest id: index}, saved) for a menu to preselect.
  - A task: `{"id", "name" (<= 18, capitals), "diff" 0..2, "level" "EASY" | "NORMAL" | "HARD", "text" (<= 90),
    "goal" (<= 60), "samples": int}`; some also carry `"budget"`, `"returns"`, `"objectives"`.
  - `Game.dest()` now returns the destination AS THE TASK SEES IT: a cached copy of `Data.DEST[id]` with
    `samples_goal` and `goal` from the task, plus `budget`, `returns`, `objectives` where the task changes
    them, and `"task"` (the task id). Read `Game.dest()`, never `Data.DEST[Game.dest_id]`, for those fields.
    The Moon's easy task (SCOUT LANDER) has `returns = false` and ends with the downlink: no ascent stage,
    no RETURN station, downlink events on the way back.
  - `Game.new_mission(id)` picks the task whose `diff` equals `Game.difficulty` (the hook's `diff=0|1|2`).
  - `Game.example_build()` fits the example to the chosen task (antenna, power parts, ascent stage, fuel,
    rocket): it is all green and WELL USED for all 24 tasks (checked by `balance.gd`).
  ```gdscript
  Game.new_mission("moon"); Game.set_task(0)             # SCOUT LANDER, EASY
  title.text = "%s  %s" % [Game.task()["name"], Game.task()["level"]]; goal.text = Game.dest()["goal"]
  ```
  Task names, easy / normal / hard: moon SCOUT LANDER / SAMPLE RETURN / POLAR ICE HUNT; mercury FIRST
  TOUCHDOWN / SURFACE SURVEY / CRATER TRAVERSE; venus QUICK LOOK / SOIL SURVEY / FOUR-ROCK DASH; mars
  LANDING SITE SCOUT / ROCK SURVEY / SAMPLE CACHE; jupiter RING FLYTHROUGH / RING SURVEY / DEEP RING DIVE;
  saturn RING SKIM / RING SURVEY / GRAND FINALE DIVE; uranus FIRST ORBITER / RING SURVEY / LONG RING
  TRAVERSE; neptune FIRST ORBITER / RING SURVEY / RING ARC HUNT.
- `Game.difficulty: int` (0 EASY, 1 NORMAL, 2 HARD; saved; set by `set_task`). `Game.difficulty_name() -> String`.
- `Game.diff(key: String) -> float`. Keys: `events_per_leg` (1 / 2 / 3), `burn_band` (1.5 / 1.0 / 0.7, width
  of the arrival burn's green band), `landing_forgive` (1.3 / 1.0 / 0.85, already applied to `touch` by
  `landing_setup()`), `surface_hazards` (0.6 / 1.0 / 1.4), `drone_rocks` (0.7 / 1.0 / 1.4), `budget_slack`
  (1.15 / 1.0 / 0.95, already applied by `Game.budget()`), `over_mult` (4 / 3 / 2), `storm_strong`.
  ```gdscript
  Game.difficulty = 2; Game.save_game()
  var rocks: int = roundi(BASE_ROCKS * Game.diff("drone_rocks"))
  ```

### 9.3 Game: the build
- `Game.place() -> String` ("THE MOON", "NEPTUNE"), `Game.has_hazard(h: String) -> bool`,
  `Game.needs_shade() -> bool`, `Game.part_available(id) -> bool` (tech, `kinds`, `dests`).
- `Game.example_build()`: an all-green, right-sized ship for all eight (`Game.EXAMPLES`).
- `Game.dv_plan() -> {"cruise", "capture", "landing", "total"}` km/s. With a heat shield where there is air,
  `capture` is 0 (direct entry); in thick air `landing` is 0.
- `Game.calc() -> Dictionary`. Old keys kept. Changed: `days` = development + cruise + operations;
  `status` has the same seven keys plus `"battery"`; fuel is green at `prop_ok`. New keys:
  `dev_days`, `cruise_days`, `ops_days`, `flight_days`, `kinds`, `dev_text` (tooltip sentence),
  `budget_margin`, `solar_space`, `gen_space`, `power_need` (what `gen` is compared with: `draw_ops`, or
  `draw_cruise` at Venus where the lander lives on its battery), `dark_hours`, `prop_ok` (kg for 110% of the
  delta-v), `window_s` (seconds of downlink time), `slack` (per resource, fraction above the green line),
  `use`, `use_rule`.
  ```gdscript
  var c: Dictionary = Game.calc()
  time_label.text = "%s days: %s" % [Game.fmt(c["days"]), c["dev_text"]]
  ```
- `c["use"][res]` for `res` in `mass power battery fuel data comms budget time`:
  `{"name", "need", "have", "lo", "hi", "unit", "band_on", "rating", "state", "tip"}`.
  `rating` is "under" | "well" | "over". `band_on` says which number the band `[lo, hi]` applies to:
  "have" for what the ship carries (power, battery, fuel, data, comms: under = risk, over = waste) and "need"
  for fixed limits (rocket lift, budget, time: over = risk, under = waste). `state` is "risk" | "well" |
  "waste" for colours, the same meaning in both cases. `c["use_rule"]` is the rule in words.
  ```gdscript
  var u: Dictionary = Game.calc()["use"]["fuel"]
  row.text = "%s: need %s, have %s %s. %s" % [u["name"], Game.fmt(u["need"]), Game.fmt(u["have"]), u["unit"], u["tip"]]
  ```

### 9.4 Game: the flight
Order for a screen that shows events (old screens may keep calling the phases alone):
`start_run()` -> `phase_launch()` -> `phase_cruise(false)` -> cruise events -> `phase_arrive()` ->
land: `landing_setup()`, `landing_result()`, site events during the surface game, `surface_result()`;
ring: site events, `probe_result()` -> home events -> `phase_home()` -> `finish()`.
- `Game.start_run(seed_n: int = -1)`: also plans the events and snapshots the build ratings.
- `Game.phase_cruise(auto_events: bool = true)`: power, sunshade (Mercury: no sunshade = OVERHEATED) and the
  course-correction burn. With `true` an undecided solar storm is flown through as before; pass `false`
  when the screen shows the cards.
- `Game.phase_arrive()`: braking burn, or direct entry behind a heat shield; at Jupiter no shield =
  the antenna and an instrument break.
- `Game.landing_setup() -> {"g", "alt", "vy", "vx", "drag", "prop", "mass", "touch", "air", "vterm"}`.
  `air == "thick"` (Venus): `vterm` is 7.5, the lander cannot fall faster and needs no engine; the player
  only steers. `touch` already includes the difficulty.
- `Game.landing_result(ok, vy, prop_left)`: at Venus a landing without the hull fails with "CRUSHED".
- `Game.phase_home()`: downlink (`Game.live_rate()`, `Game.live_store()`, `calc["window_s"]`; Venus sends
  only during its 127 minutes) and the sample return where `returns`.
- `Game.run` new keys: `events`, `decisions`, `days_extra`, `money` ($M spent on events), `rate_mult`,
  `gen_mult`, `score_bonus`, `minutes_lost` (Venus clock), `hull_delta` (drone hit points), `use`,
  `difficulty`; after `finish()`: `scores`, `total`, `late_days`, `report`. Each log line has a `phase`.
  ```gdscript
  Game.phase_cruise(false)
  var solar_now: float = float(Game.run["calc"]["solar_dest"]) * float(Game.run["gen_mult"])
  ```

### 9.5 Game: decision events (`scripts/events.gd` holds the 37 events)
- `Game.event_plan()` (called by `start_run`): `Game.diff("events_per_leg")` events per phase, seeded,
  no event twice. Each planned event has `at` (0..1, progress through its phase) and `done`.
- `Game.next_event(phase: String) -> Dictionary`: `phase` is "cruise", "site" or "home"; `{}` when none is left.
- `Game.event_choice(ev, i) -> {"can": bool, "why", "line", "warn", "safe": bool}`: whether the ship can pay
  for choice `i` (fuel, battery, budget reserve, a part on board) and what it leaves short.
- `Game.resolve_event(ev, choice: int) -> {"ok": bool, "text", "effects": Array[String], "chips": Array,
  "applied": Dictionary, "grade": "good" | "risky" | "bad", "points": int}` and logs it in
  `Game.run["decisions"]`: `{"id", "title", "phase", "role", "choice", "ok", "good", "grade", "points", "cost", "text"}`.
  `applied` holds what a screen must mirror in its own variables: `battery_wh`, `data_gb`, `samples`,
  `minutes`, `hull`, `power`, `broken` (part ids).
- `Game.event_by_id(id) -> Dictionary`: a playable copy of any event, for debug hooks.
- `Game.money_left() -> float`, `Game.days_over() -> float`.
- Event effect keys differ a little from section 4: `dv_ms` (a burn, paid in fuel by the rocket equation;
  `fuel_kg` also works), `battery_pct`, `data_pct`, `days`, `money`, `power`, `rate`, `break`, `samples`,
  `score`, `minutes`, `hull`, `fail`. Choices may carry `needs_part`, `risk.save_part`, `gain`.
  ```gdscript
  # in the screen's clock, only while no card is open:
  var ev: Dictionary = Game.next_event("cruise")
  if not ev.is_empty() and progress >= float(ev["at"]):
      EventCard.open(self, ev, _after_event)
  ```
  Site events happen in the middle of a minigame, so sync first and read back afterwards:
  ```gdscript
  Game.run["battery"] = battery; Game.run["data"] = data; Game.run["samples"] = got
  EventCard.open(self, ev, func(res: Dictionary) -> void:
      battery = float(Game.run["battery"]); data = float(Game.run["data"]); got = int(Game.run["samples"])
      _reload_instruments())      # Game.run["broken"] may have grown; res["applied"] says what changed
  ```

### 9.6 EventCard (`scripts/event_card.gd`)
`const EventCard = preload("res://scripts/event_card.gd")`
- `EventCard.open(parent: Control, ev: Dictionary, done: Callable) -> Control`: covers `parent`, takes mouse
  and keys (1-3, then Enter or Space; click and tap work), calls `Game.resolve_event`, shows the outcome,
  frees itself and calls `done.call(result)`. The card shows who decides, the title, what happened, the
  choices and the outcome. It no longer draws the "THIS REALLY HAPPENED" strip (team decision); the real
  line is still in `ev["real"]` and in every `Game.run["decisions"]` entry (`"real"`) for the end report.
- `EventCard.is_open() -> bool`: stop the screen's clock, movement and input while true.
- `EventCard.demo(parent: Control, id: String = "", choice: int = -1) -> Control`: for `debug_*` hooks.
  ```gdscript
  func _physics_process(delta: float) -> void:
      if EventCard.is_open(): return
  func debug_event() -> void:
      EventCard.demo(self, "dust_storm")          # EventCard.demo(self, "units", 2) shows an outcome
  ```

### 9.7 Scoring and the report (`Game.finish()`)
- Unchanged: `run["score"]` (objectives, 0-100), `run["reward"]`, `run["roles"]`.
- `run["scores"] = {"success" | "science" | "efficiency" | "decisions": {"name", "value" 0-100, "tip"}}`,
  `run["total"]` (success 40%, the others 20% each). Efficiency comes from the `use` ratings at launch.
- `run["report"] = {"phases": [{"id", "name", "ok", "lines": [{"ok", "text"}]}], "decisions", "objectives":
  [{"id", "name", "done"}], "scores", "total", "credits", "build" (the `use` table at launch), "build_rule",
  "difficulty", "late_days", "money_spent", "money_left", "task" (the task flown), "grade", "grade_text",
  "grade_rule"}`.
- Letter grade: `run["report"]["grade"]` is "A", "B" or "C" when every objective of the task was met
  (total >= 85: A, >= 70: B, else C; `Data.GRADE_A`, `Data.GRADE_B`) and "" when a goal was missed.
  `["grade_text"]` (<= 50 characters) says what the next grade up needs; `["grade_rule"]` is the rule in
  one sentence, to show small. Also `run["grade"]`.
  ```gdscript
  for key: String in Game.run["report"]["build"]:
      var u: Dictionary = Game.run["report"]["build"][key]   # u["rating"], u["state"], u["tip"]
  for part: String in ["success", "science", "efficiency", "decisions"]:
      var sc: Dictionary = Game.run["scores"][part]          # sc["name"], sc["value"], sc["tip"]
  var rep: Dictionary = Game.run["report"]
  if rep["grade"] != "": _stamp(rep["grade"])              # then rep["grade_text"], rep["grade_rule"] small
  ```

### 9.8 Preflight (`scripts/preflight.gd`)
- `Preflight.stations() -> Array`: same shape as before plus `lo`, `hi` (gauge fractions where the WELL USED
  zone starts and ends, -1.0 = none) and `critical` (bool). Order: booster, power, fuel, landing | drone,
  [heat], [pressure], [radiation], science, data, comms, [return], budget, time, risk. `stations[2]` is fuel.
- `Preflight.top()`, `count()`, `effect()`, `what_if()`, `money()`, `place()`, `RANK`, `WORD`, `DEAD` (now
  with all eight ids): unchanged. `Preflight.YELLOW` = "GO, but an unlucky event could end it."
- `Preflight.part_need(id: String) -> {"level": "required" | "recommended" | "optional" | "not_needed",
  "label": String, "why": String (<= 60)}`.
- `Preflight.checklist() -> Array` of `{"id", "title", "done", "hint", "parts", "next", "tab"}`: steps
  `power`, `radio`, `science`, `down` ("GETTING DOWN", or "PROTECTION" at Mercury and Jupiter; absent when
  nothing is needed), `fuel`, `rocket`. `next` is the first missing part ("" if none); the rocket step's
  `parts` are `"rocket:<id>"` tiles.
  ```gdscript
  var need: Dictionary = Preflight.part_need("chute")        # {"level": "not_needed", "label": "NOT NEEDED HERE", "why": "No air at the Moon: ..."}
  for step: Dictionary in Preflight.checklist():
      if not bool(step["done"]): _light(step); break         # step["hint"], step["next"], step["tab"]
  ```

### 9.9 What changed for the three old missions
- The Moon's all-green ship now flies on Vulcan (Falcon 9 leaves 18% of its lift spare: a yellow lamp). Mars landers use
  legs in the example. Saturn's gravity is 11.19 m/s2 (was 10.44): the drone feels 7% heavier.
- Budgets (NORMAL and HARD tasks, $M): moon 395, mercury 445, venus 360, mars 325, jupiter 460, saturn 700,
  uranus 745, neptune 795. Easy tasks: 270, 430, 350, 315, 440, 605, 720, 770. The difficulty's
  `budget_slack` multiplies them. Time limits (days): 680, 3500, 660, 800, 2400, 3300, 5600, 5600.


## 10. Round 2: who owns what (eight agents in parallel)
| Agent | Owns |
|---|---|
| launch | scripts/screens/launch.gd, art/launch/**, tools/art/gen_launch*.py |
| flight | scripts/screens/flight.gd, new files under art/flight/, tools/art/gen_flight2*.py |
| landing | scripts/screens/landing.gd |
| surface | scripts/screens/surface.gd |
| drone | scripts/screens/probe.gd |
| menu | scripts/screens/menu.gd, art/menu/**, tools/art/gen_menu*.py |
| report | scripts/screens/report.gd |
| builder | scripts/screens/builder.gd, scripts/vab/** |
Nobody edits data.gd, game.gd, preflight.gd, events.gd, event_card.gd, ui.gd, pix.gd, fx.gd, ship_kit.gd,
audio.gd or main.gd in this round: list needed changes in your report.

Routing (main.gd, already in place): the builder still calls `Game.goto("flight")`; main sends an outbound
flight that has not launched yet to the `launch` screen. `launch.gd` calls `Game.phase_launch()` exactly
once, then sets `Game.run["launched"] = true` and calls `Game.goto("flight")` (or, if the launch failed,
shows why, then `Game.finish()` and `Game.goto("report")`). `flight.gd` therefore starts at the cruise on
the way out and never calls `phase_launch()`.
Debug hook additions: `diff=0|1|2` sets the difficulty; `screen=launch` starts on the pad;
`screen=flight` starts at the cruise with the launch already done.
