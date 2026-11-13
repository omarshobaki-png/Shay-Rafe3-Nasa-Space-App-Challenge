# NASA resources: what each one says, and where it goes in our game

This is the AI- and teammate-readable version of our research. It's written so that someone (or a
Claude session) who has read nothing else can understand what each NASA resource contains, which real
numbers we took from it, where those numbers live in the code, and what is still unused.

Deeper detail and every source link are in [`/research`](../research/). Start with
[`research/STUDY.md`](../research/STUDY.md). The printable team guide is
[`reference/NASA_Resources_Team_Guide.pdf`](reference/NASA_Resources_Team_Guide.pdf).

**Rule for every number in the game:** it lives in `game/scripts/data.gd` with a `src` field. If it's
real, `src` names the source. If we invented it for gameplay, `src` says `"game rule"` or
`"game estimate"`. The in-game "NASA DATA & CREDITS" screen and every tooltip read from these fields.
Keep it that way, because it's how judges see NASA data "at the core" (the Relevance criterion).

---

## 0. Quick map

| # | Resource (official Resources tab) | One-line value for us | Used in game now? | Detail notes |
|---|---|---|---|---|
| 1 | NASA *Design and Develop Science Missions* (slides, 2025) | The mission process + the 4 segments → our 4 roles | Yes: roles, objective-first flow | `research/notes-mission-process.md` |
| 2 | NASA **GMAT** (orbit software) | Isp 300 s, solar-decay model, delta-v, eclipses | Yes: `ISP`, `SOLAR_DECAY_PER_YEAR`, Δv values | `research/notes-tools-gmat-mdl-viz.md` |
| 3 | JPL *Concept Maturity Levels* (2013 paper) | Margin rules (35%…) + green/yellow/red checklists | Yes: margin per destination, GO/NO-GO board | `research/notes-mission-process.md` |
| 4 | Goddard **Mission Design Lab** | How a real team designs in 1 week; ~20 discipline "seats" | Partly: role split | `research/notes-tools-gmat-mdl-viz.md` |
| 5 | NASA **Mission Viz** (WSMV) | Ideas for drawing orbits/trajectories (no licence: ideas only) | Ideas only (cruise map) | `research/notes-tools-gmat-mdl-viz.md` |
| 6 | NASA Webb *Build It Yourself* game | The closest existing game; "your design is like mission X" | Yes: real-mission comparison in report | `research/notes-existing-games.md` |
| 7 | NASA *CubeSat 101* (2017) | Real timelines, failure causes, "Free Advice" | Not much yet → hints and RNG events | `research/notes-cubesat101.md` |
| 8 | Space Apps 2023 *Visualize a Space Mission Using VR* | A mission timeline; what past teams did | Ideas only | `research/notes-existing-games.md` |
| 9 | CSA *Digital Games and Activities* | Partner-agency games (OSIRIS-REx, RADARSAT…) | Not used (cite if we borrow an idea) | `research/notes-existing-games.md` |
| + | **Extra NASA data we use:** DONKI, planetary fact sheets, MMRTG fact sheet, NASA Small Spacecraft Technology report, mission pages (Apollo, CAPSTONE, Perseverance, Cassini, MRO, LRO) | The real numbers behind every part and destination | Yes, throughout `data.gd` | `research/notes-real-numbers.md` |

---

## 1. Design and Develop Science Missions (NASA Small Spacecraft Systems Virtual Institute, slides, March 2025)

**What it is:** a 25-slide NASA webinar on how a science mission goes from an idea to operations.
URL: `nasa.gov/wp-content/uploads/2025/04/250323-design-and-develop-science-mission.pdf`

**Key content:**
- **6 steps:** Need & Goals → Concept (written as a *Concept of Operations*, a time-ordered story of
  the mission) → Requirements → Design → Build & Verify → Implement (operations).
- **"Begin with the end in mind":** start from what the scientist needs at the end, then work backwards
  to the spacecraft.
- **4 mission segments:** **Launch** (rocket), **Space** (spacecraft, instruments, landers, rovers),
  **Ground** (stations, mission control), **User** (scientists and the public who use the data).
- **Requirements are numbers, and each one has a verification method chosen before building.** The
  example (BioNutrients-2) has "12 samples", "< 250 g container" (verified by weighing) and
  "< 300 mL".

**In our game:**
- The 4 builder role tabs (Planner, Engineer, Scientist, Comms) map loosely onto the 4 segments.
  Planner ≈ Launch, Engineer ≈ Space, Comms ≈ Ground, Scientist ≈ User.
- Each destination has numeric objectives in `data.gd → DEST[*].objectives` and `samples_goal`
  (Moon 3, Mars 4, Saturn 5).

**Unused ideas worth adding:**
- A 3–4 panel ConOps strip at the start of each mission: launch → cruise → arrive → do science → send
  data home.
- Show the objectives as a requirements checklist with real numbers ("land below X m/s", "return 3
  samples", "downlink N Gb"). Tick each one off in the report.

## 2. GMAT, the General Mission Analysis Tool (NASA Goddard)

**What it is:** NASA's professional open-source software for orbits and trajectories. Apache 2.0
licence, desktop only. Now at **github.com/nasa/GMAT** with its full user guide. Old downloads are on
SourceForge.

**Key content:**
- It models orbits, burns, launch windows, eclipses, ground-station contact and interplanetary
  transfers. There are 12 tutorials: Hohmann to GEO, Mars arrival, lunar flyby, eclipses and contacts,
  electric propulsion, DSN tracking.
- Default thruster **Isp = 300 s**.
- **Solar-array model:** power falls with (distance from the Sun)², loses **5% per year**, and is 0 in
  shadow.
- Eclipse example: about 35 minutes of shadow per orbit in low orbit. Contact windows: about 6 min per
  pass in low orbit vs 29 h from GEO.

**Important limit:** GMAT can't run inside Godot or in a browser. "Using GMAT physics" means:
1. run GMAT offline;
2. export ReportFile tables (time, x, y, Δv…);
3. store the results in our data files;
4. play them back or check against them in Godot.

The real-time landing and driving use Godot 2D physics with real gravity.

**In our game:**
- `Data.ISP = 300.0` (GMAT default), `Data.SOLAR_DECAY_PER_YEAR = 0.05`.
- Fuel uses the rocket equation in `game.gd → rocket_eq_prop()` and `burn()`.
- Per-destination Δv lives in `DEST[*].capture_dv` and `landing_dv`.

**Unused ideas:**
- Run the real GMAT tutorials (lunar transfer, Mars arrival) and replace the Δv values with GMAT
  outputs. Then the submission can say "trajectories computed with NASA GMAT".
- Use an exported trajectory point list for the cruise-map animation.
- Use eclipse time to size batteries for orbiters.

## 3. Space Mission Concept Development Using Concept Maturity Levels (JPL; Wessen, Borden, Ziemer, Kwok; AIAA SPACE 2013)

**What it is:** how JPL judges whether a mission concept is mature. It's the best source for "how do
we score a design?".

**Key content:**
- **CML ladder:**
  - 1 "Cocktail napkin": the objective in one sentence;
  - 2 Initial feasibility: rough sums, compared with past missions;
  - 3 Trade space: compare options on science, cost and risk;
  - 4 Point design: one design, defined down to the subsystems;
  - 5–9: formal NASA review stages.
- **Iteration is normal.** Going back from CML 4 to 3 is good. Teams that skipped trade studies got
  less science and worse designs.
- **Checklist scoring:** each item is green, yellow or red. A level is reached at about **80% green**,
  but missing a *critical* item outweighs a high percentage. Self-assessment runs too optimistic, so
  use an independent reviewer.
- **CML 4 margins (real JPL numbers):**
  - **≥ 35% spare mass, power and battery energy**;
  - **≥ 100% spare computer capacity**;
  - **telecom link ≥ 3 dB above the minimum for deep space, ≥ 6 dB for near-Earth links**.

  CML 4 also needs a backup launch vehicle, a 5×5 risk matrix, and both a *baseline* and a *minimum*
  science goal.
- **Cost classes:** Explorer, Discovery, New Frontiers, Flagship.

**In our game:**
- `DEST[*].margin` is the required mass margin: Moon 0.10, Mars 0.20, **Saturn 0.35** (the real JPL
  value, used on Hard).
- The GO/NO-GO review board (`game.gd → role_issues()`, `calc()` status per resource) gives each
  resource "ok", "warn" or "bad". That is the CML green/yellow/red idea.

**Unused ideas:**
- Make the report a CML-style checklist with **critical items** that fail the mission even at 90% green.
- A "minimum vs baseline science" goal: partial success scores partially.
- The second player acts as the independent reviewer who must sign off before launch.
- Label budgets with the real program classes (Discovery / New Frontiers / Flagship).

## 4. NASA Goddard Mission Design Lab (MDL, part of the Integrated Design Center)

**What it is:** Goddard's concurrent-engineering lab, where about 20 engineers design a mission in about
a week. URL: `etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/`

**Key content:**
- **Study types:** Office Hours (about 1 h), Concept Development, Tailored Trade Study, Point Design
  (6 days: CAD, Master Equipment List, cost).
- **16 disciplines:** attitude control, cost, propulsion, avionics, mechanical, reliability, flight
  dynamics, flight software, mechanical systems, orbital debris, radiation, structures,
  communications, mission operations, power, thermal.
- **The week:**
  - Mon: mission plan; everyone enters first mass and power numbers.
  - Tue: sketch and block diagram.
  - Wed: whole-spacecraft totals, then **design frozen**.
  - Thu: presentations.
  - Fri: present to the customer.

**In our game:** the 4 roles are these disciplines grouped into 4 seats.
- Planner = flight dynamics, cost, launch.
- Engineer = power, propulsion, mass.
- Scientist = instruments.
- Comms = communications.

The builder's part list is our "Master Equipment List".

**Unused ideas:**
- A visible "design freeze" moment ("FREEZE DESIGN & LAUNCH").
- Show the parts table as a Master Equipment List: mass, power and cost per part, plus totals.

## 5. NASA Mission Viz (WSMV, `nasa.github.io/mission-viz/`)

**What it is:** web demos and tutorials for showing missions in 3D: orreries, a planetary
orbital-parameters table, an Earth–Moon transfer, and a 2D-ellipse-to-3D-orbit tutorial. Its tutorial
loads a GMAT trajectory as x, y, z points and animates a spacecraft along it.

**Licence:** **none published, so don't copy its code.** Take ideas and NASA's orbital numbers only.

**In our game:** the cruise map in `screens/flight.gd` draws a transfer orbit. Mission Viz is the
reference for doing it from real orbital parameters.

## 6. NASA Webb, *A Learning Game About Telescopes* / *Build It Yourself*

**What it is:** the closest existing game (`science.nasa.gov/mission/webb/game-build-it-yourself/`).

**Key content:**
- Flow: choose the science goal → wavelengths → instruments → mirror, launch, see results.
- The end screen compares your design with real missions ("your telescope is like…").
- Limited picks force priorities; impossible options are greyed out; everything is reversible until
  launch; 3 levels.
- Weak points: single player, one mission type, no accessibility features, not for phones.

**In our game:** the report's real-mission comparison (`DEST[*].real` text: CAPSTONE / Apollo,
Perseverance, Cassini).

**Beat it on:**
- multiplayer roles;
- 3 destinations;
- "why it failed" explanations;
- accessibility (readable pixel font, colour plus text labels on the bars, keyboard control).

## 7. CubeSat 101 (NASA CubeSat Launch Initiative, Oct 2017, 96 pages)

**What it is:** NASA's practical guide for first-time CubeSat teams. **Read chapters 1, 2 and 6.**

**Key content:**
- **Sizes:** 1U is a 10 cm cube under 1.33 kg; 3U under 4.00 kg; also 6U and 12U. A "small satellite"
  is under 300 kg.
- **Timeline:** typically 18–24 months.
  - concept 1–6 mo, funding 1–12, design 1–6;
  - waiting for a launch slot 1–36, licensing 4–6;
  - ground station 2–12, build and test 2–12;
  - operations up to years.
- **Money:** NASA's CSLI pays the launch (up to about $300k). Keep **≥ 10% budget reserve**.
- **"Free Advice" boxes:** keep it simple; don't design to the exact limit; something breaks in vibration
  testing; use two burn wires for deployables; prefer **flight-heritage** parts; use certified
  batteries.
- **"Launching with an inadequate ground station is a mission killer."**
- **Testing:** vibration/shock, thermal vacuum, and "Day In The Life" (DITL: the final software running
  the real timeline).
- **Orbital debris rules:** deorbit in reasonable time; prefer aluminium over titanium.
- **Failure data** (from `notes-real-numbers.md`, Villela 2019 survey of 855 CubeSats):
  - about **75% succeed** (excluding rocket failures);
  - about 20% of failures happen at launch or deployment;
  - about 18–30% are dead on arrival;
  - **power causes about half of later failures**.

**In our game:** hardly used yet. Best uses:
- **Easy-mode hints** = Free Advice quotes, credited "NASA CubeSat 101".
- **Flight heritage vs new tech parts:** heritage is cheaper and more reliable but weaker; new tech is
  stronger but has a higher RNG failure chance.
- **An optional pre-launch test step:** spend money and time on vibration / thermal / DITL tests to
  reveal hidden faults; skipped tests become RNG failures in flight.
- **Weight RNG failures by the real failure causes** (power first).

## 8. Space Apps 2023, *Visualize a Space Mission Using Virtual Reality*

A past challenge on showing a whole mission: concept, trajectory, timeline and 3D understanding. It had
one global finalist (CodeGalore, India) and no winner.

**For us:** a mission timeline bar (Launch → Cruise → Arrival → Science → Downlink → End). Also proof that
pure visualisation isn't enough to win; the decisions and consequences are.

## 9. CSA (Canadian Space Agency) *Digital Games and Activities*

A partner agency's learning games: OSIRIS-REx (the closest to a mission decision), RADARSAT
Constellation, Mission: Astronaut. Worth 20 minutes for ideas. If we use an idea from it, list it under
"Space Agency Partner data" in the submission; it may count for partner recognition.

---

## 10. Extra NASA data already in the game (outside the official 9)

| Data | Real values used | Where in code |
|---|---|---|
| **NASA DONKI** space-weather database (api.nasa.gov), geomagnetic storms 2024–25, snapshot taken 13 Nov 2026 | Real storms with real Kp, e.g. **Kp 9, 10 May 2024** | `game/data/donki.json`, `scripts/donki_data.gd`, applied in `game.gd → phase_cruise()`: Kp ≥ 7.5 without shielding damages a science or comms part |
| NASA planetary fact sheets | Gravity Moon 1.62, Mars 3.71, Saturn 10.44 m/s²; sunlight 1361 / 586 / 14.8 W/m²; distance in AU; Mars night 12.3 h | `data.gd → DEST` |
| Radio light delay | Moon 1.3 s, Mars 4–24 min, Saturn ~80 min | `DEST[*].light_delay` |
| NASA MMRTG fact sheet | 110 W, 45 kg, 14-year life | `PARTS.rtg` |
| NASA Small Spacecraft Technology report (2026) | Solar ~30 W/kg (range 1–200); Li-ion 150–270 Wh/kg | `PARTS.solar*`, `PARTS.battery*` |
| Mission instruments | MRO CTX camera, CRISM spectrometer, Cassini MAG magnetometer | `PARTS.camera/spectro/mag` |
| Mission facts | Apollo 11 3-day trip + 21.5 kg of rock; CAPSTONE 25 kg, $13.7M + $9.95M on Electron, 4.5-month low-energy path; Perseverance 1,025 kg, 203-day cruise, MMRTG; Cassini 5,712 kg, 3 RTGs, 6.7-year gravity-assist path, Grand Finale 2017 | `DEST[*].traj`, `DEST[*].real`, `ROCKETS` |
| Rockets (maker sites + Wikipedia, labelled) | Electron 300 kg LEO; Falcon 9 22,800 kg LEO / 4,020 kg Mars, ~$74M; Vulcan 11,500 kg TLI; Falcon Heavy 16,800 kg Mars; SpaceX rideshare $0.35M up to 50 kg, then $7k/kg | `data.gd → ROCKETS` |

**More NASA data we could add (ranked by effort):**
1. **NASA imagery** (LRO for the Moon, HiRISE for Mars, Cassini for Saturn) as "the photo your mission
   took" in the report. Pixelate it into our palette and credit it. Cheap, and very visible to judges.
   Note: our art rule is "no AI images"; real NASA photos are fine with credit, but no NASA logos.
2. **Cassini's "The Day the Earth Smiled" (2013)** shown next to the player's Saturn photo.
3. **JPL Horizons** (real planet positions) for launch windows or the cruise-map layout.
4. **DSN Now** (live dish status) as flavour for the Comms role. Bundle a snapshot; don't call it live.

## 11. Real mission stories for RNG events and lessons

Each event's **chance** should come from the design (low reliability, untested parts, no margin mean a
higher chance). Its **damage** should come from the design too (redundancy, margin or the right part
means less damage). Show "this really happened to ___" in the report. Verify the details on the NASA or
agency page before shipping.

| Mission | What happened | Event idea | Fits |
|---|---|---|---|
| Apollo 11 (1969) | Computer overload alarms during descent; landed with little fuel left | "Computer alarm! Better avionics = no effect" | Moon |
| Beresheet (SpaceIL, 2019) | Sensor glitch + engine shutdown during descent → crash | "Sensor fault: a redundant sensor saves you" | Moon |
| IM-1 Odysseus (2024) | Laser rangefinder problem; landed but tipped over | "Altimeter failure: land by camera only" | Moon |
| Chandrayaan-3 (ISRO, 2023) | Succeeded after Chandrayaan-2's lander crashed | "Learn from failure" report note | Moon |
| Mars Climate Orbiter (1999) | Lost because of an imperial/metric unit mix-up | "Units mismatch!" (a quiz-style event) | Mars |
| Opportunity (2018) | A global dust storm covered its solar panels; it never woke | "Dust storm: solar drops to ~10%" (code has `DEST.mars.dust = 0.8`) | Mars |
| Spirit (2009) | Stuck in soft sand for good | "Sand trap: was your route scanned?" | Mars |
| Schiaparelli (ESA, 2016) | A bad sensor reading made it think it had landed; engines cut early | "Sensor lie during descent" | Mars |
| Huygens (found 2000) | Relay radio couldn't handle the Doppler shift; fixed by changing the trajectory | "Comms fault mid-cruise: replan the route" | Saturn |
| Huygens (2005) | One of two radio channels never switched on (missing command), so half the images were lost | "Redundancy + command checklist" lesson | Saturn |
| May 2024 storm (DONKI, Kp 9) | Strongest geomagnetic storm in ~20 years | Already in the game | All |

## 12. Formulas (keep them visible in tooltips; most are already in `game.gd`)

```
Rocket equation:   Δv = Isp · g0 · ln(m_full / m_empty)
                   prop_needed = m_dry · (exp(Δv / (Isp·g0)) − 1)      # g0 = 9.81, Isp = 300 s
Solar power:       P = P_1AU · (1 / d_AU²) · (1 − 0.05)^years · sunlight_fraction
Battery (night):   energy_needed_Wh = power_draw_W · night_hours  ≤  battery_Wh
Data:              downlink_Gb = data_rate · contact_hours_per_day (game rule 8 h) · days
                   lost_data = science_data − downlink − storage
Mass margin:       (rocket_capacity − ship_mass) / rocket_capacity  ≥  DEST.margin
Jump height:       h = v² / (2g)   → 3.2 m on the Moon, 1.4 m on Mars for the same jump speed
```

## 13. What to tell the judges (NASA-data statement draft)

> "Every number in Space Mission Designer carries its source. Gravity, sunlight, distances and radio
> delays come from NASA planetary fact sheets. Parts use NASA specifications (MMRTG, MRO and Cassini
> instruments, NASA Small Spacecraft Technology data). Design margins follow JPL's Concept Maturity
> Level rules. Engine and solar models use NASA GMAT defaults. During cruise, ships face real 2024
> geomagnetic storms from NASA's DONKI database. Values we invented for gameplay are labelled
> 'game rule' in the game."

Update this statement if we add GMAT runs or NASA imagery.
