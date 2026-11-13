# Team notes: one merged version

This file merges the notes from **Omar**, **Ahmad** and **Ameen**, plus **Mahdi's** playtest feedback,
into one list with no repeats. Where the notes disagreed, one option was picked and the reason is given
in §9. The team can override any pick; if you do, change it here and in
`03_GAME_DESIGN.md` §5 in the same commit.

---

## 1. Why the game exists

Students and aspiring engineers learn space topics one at a time, in theory: orbits, rockets, power,
radios. They almost never get to run a **whole mission from idea to operation**, where every choice
affects every other one. Our game is that place. The player defines a mission, builds the spacecraft
for it, flies it, and lives with the results. It shows how **cruel and unforgiving, but also
rewarding**, engineering decisions can be.

**The one rule above all others: reward smart, effective engineering decisions. Everything else is
extra.** Every feature must make a player's choice matter, or it gets cut first.

## 2. Who it's for

- Students and aspiring engineers, **including people with little prior knowledge**.
- The science is explained **inside the game, in plain words**: orbit, payload capacity, power use,
  data rate and communications are learned by using them, not by reading about them first.

## 3. The missions

The player is the mission's engineer and controller. All missions are **robotic** (no crew).

| Difficulty | Destination | Goal | The one idea it teaches |
|---|---|---|---|
| **Easy** | Moon | Land a spacecraft safely, drive the rover and collect samples. Bonus: launch them back to Earth | **Fuel vs mass**: more fuel makes landing safer but the ship heavier and the rocket bigger |
| **Medium** | Mars | Land a rover (heat shield + parachute), drill a rock core and **deliver it to the sample pickup point** ("rescue the rock") | **Atmosphere and signal delay**: Mars air burns you up without a shield, and minutes of radio delay mean the lander must land itself |
| **Hard** | Saturn | Reach orbit and **photograph Saturn**, getting the photos home. Bonus: fly the ring drone to collect ice and dock it | **Power and data at extreme distance**: sunlight is ~1% of Earth's (you need nuclear power), and a slow, distant radio link means you choose which photos to send |

## 4. How a mission plays

1. **Mission briefing.** The goal, the requirements as numbers, and the resources you're given.
2. **Design the spacecraft.** Choose parts, a rocket and a flight path while watching the resource bars.
3. **Review.** Mission control gives GO / NO-GO for each system. You can still launch a NO-GO ship and
   watch what breaks.
4. **Fly the mission.** Launch, then cruise (with random events), then arrival, then landing or orbit,
   then the science.
5. **Report.** What succeeded, what failed and why, what you could have done better, and your rating.
6. **Redesign and try again.**

## 5. Systems

### 5.1 Resources
- The six resources: **Mass, Power, Budget, Data, Communications, Time** (plus fuel).
  - **Mass:** spacecraft and payload.
  - **Power:** energy for systems and instruments.
  - **Budget:** money to build and run the mission.
  - **Data:** information the instruments produce.
  - **Communications:** the ability to send data to Earth.
  - **Time:** development and operating life.
- **Each mission comes with a fixed allotment that is "not too much, not too little"**: enough for a good
  design, too little for a lazy one.
- **Mission budgets:** Moon (Easy) **$300M**, Mars (Medium) **$500M**, Saturn (Hard) **$900M**. These
  are the values already in Mahdi's v3 (`data.gd → DEST[*].budget`).
- Bars update live with every choice and show which resources are critical for this mission.

### 5.2 Spacecraft builder
- **Kerbal-style and visual.** The ship stands in a hangar. Each part snaps onto a slot on the ship, and
  the ship visibly grows. This replaces the current list of +/- counters, which playtesters found
  confusing.
- **Parts have real stats and trade-offs** (mass, power, cost, data, reliability), with simple and
  advanced versions. Categories: power, communications, science instruments, landing gear, robots,
  return stage, fuel and shielding.
- **Flight-heritage vs new-tech parts:** proven parts are cheaper and more reliable; new ones perform
  better but fail more often (a real NASA trade-off from CubeSat 101).
- **Staging and separation:** the lander, rover or drone separates from the main craft and is then
  controlled on its own. This is gameplay, not just an animation.

### 5.3 Flight and physics
- **Realistic where the player can see it:** real gravity per world, thrust, mass, fuel use (rocket
  equation), momentum and stability.
- **Hand-flown parts:** the landing (and, on Saturn, the drone).
- **Computed parts:** the cruise between planets, using trajectories and Δv from NASA's GMAT, then
  animated on the map.
- **Flight instruments on screen:** altitude, speed, fuel, thrust, gravity, orientation/stability and
  orbit information, in pixel-art style.

### 5.4 Random events
- **No two runs are the same.** Events happen during the mission, based on real NASA history: solar
  storms from the DONKI database, sensor faults, dust storms, sand traps, radio faults.
- **Fair randomness:** the design sets both how likely an event is and how much it hurts. Redundancy,
  margin, shielding and tested parts turn a disaster into a non-event.

### 5.5 Hints and mission control
- Hints come from **mission control**, as messages and short voice lines: "low fuel", "approaching the
  Moon", "brake now", warnings about unstable flight, objective confirmations.
- **How much help depends on difficulty:**
  - **Easy:** full hints; warnings before bad choices; short tips quoting NASA's CubeSat 101 advice.
  - **Medium:** partial hints; warnings only after a mistake.
  - **Hard:** no hints; only the end report explains.
- Every part and bar has a one-line science explanation with its NASA source.

### 5.6 Report and rating
- Each objective is shown as met or missed, with the **cause chain** ("battery empty on night 3: at Mars
  your panels made 57% less power than on Earth").
- Explain **how each decision affected performance**, not just whether it was right or wrong. Show
  small effects too.
- **"What you could have done better":** the top changes that would have helped most.
- **Two separate ratings:**
  1. **Mission success:** objectives and science returned.
  2. **Resource use:** how well the allotment was used, judged without looking at *how* the problem was
     solved. A healthy safety margin is good; waste and running everything to zero are not.
- **No single perfect answer.** Several designs can succeed, but one can score better than another.
- "Your design is closest to real mission X": a real mission and a fact for comparison.
- A score per role.

### 5.7 Progression
- Successful missions earn **credits**. Credits **unlock better technologies** (lighter solar arrays,
  better batteries, faster radios, a bigger rover, an armored drone) for the next attempt.
- **Credits never raise the mission budget.** The allotment stays fixed, so the resource rating stays
  meaningful.

### 5.8 Multiplayer and roles
- **1 to 4 players, each on their own computer**, joined over the network into one shared mission. No
  shared keyboard or split screen.
- **Each player has their own role**, with their own responsibilities and score:
  - **Mission Planner:** rocket, flight path, budget, time.
  - **Engineer:** mass, power, fuel.
  - **Scientist:** instruments, robots (rover, drone), samples.
  - **Comms officer:** data storage, antennas, downlink.
- In the builder, each player edits only their own role's parts and bars, but everyone sees the whole
  ship and all bars live. **All players must sign off before launch**, so they have to negotiate when
  priorities clash (e.g. the Scientist wants another instrument but the Engineer is out of power).
- In flight, each role has its own job. For example, during the landing the Engineer flies the engine
  and the Scientist times the parachute; at Saturn the Comms officer picks which photos to send.
- **Single player is a full mode:** one player can play the whole game alone, offline with no network
  needed, controlling all 4 roles. This is the default when you start the game.
- **With 2–3 players,** the free roles are shared out among them.
- The report gives a score per role, and mission success depends on how well the team coordinated.

### 5.9 Look and feel
- **2D pixel art with a sense of 3D depth:** 8-bit look, detailed sprites and depth (parallax, perspective
  floor, shadows), inspired by Pixel Car Racer.
- Space should feel immersive, with the Sun, planets and moons each looking distinct.
- Strong, heavy sounds that work on laptop speakers.

## 6. Engine and tech

- **Godot 4.7.2, GDScript.** Web build for judges (GitHub Pages) + a Windows build.
- **Multiplayer networking:** Godot's high-level multiplayer, with one player hosting. The browser
  build can't use Godot's ENet networking, so it needs WebSocket (or WebRTC) peers plus a small relay
  server; the Windows build can use ENet on a LAN directly. Build and test this early, since it's the
  riskiest feature.
- **GMAT** is used offline for trajectories and Δv; landing and driving use Godot 2D physics with each
  world's real gravity.
- Every number has a source in `game/scripts/data.gd`.

## 7. Out of scope (decided, so nobody re-asks)

- Crewed missions, life support and returning people to Earth.
- Extra destinations (Pluto, Saturn atmosphere dives, "missions NASA hasn't done").
- A full free-flight solar-system sandbox.
- Local multiplayer on one keyboard or a split screen (replaced by networked multiplayer, §5.8).
- Cables and fins as structural parts. They matter for rockets in air, not for our spacecraft. The
  launcher is picked from real rockets instead.

## 8. Working rules for the team

- The hackathon deadline is **Sun 15 Nov 2026, 15:15** at the Ramallah local event (projects submitted; pitches 16:15, 3 min + 2 min Q&A). The global portal closes at 23:59. Plan backwards from the 30 s demo
  video.
- Read the NASA resources properly; every feature should be traceable to one (see
  `02_NASA_RESOURCES.md`).
- Keep it simple, test early, document decisions here.

## 9. Conflicts resolved

| Topic | The options in the notes | Picked | Why |
|---|---|---|---|
| Saturn goal | Omar: get near and photograph · built v3: ring drone collecting ice · Ameen: atmospheric exploration | **Photograph + downlink as the main goal; ring drone as a bonus** | Photos teach Saturn's real lesson (power and data far from the Sun). The drone already works and is fun, so keeping it as a bonus costs nothing. An atmosphere dive would be new work |
| Mars goal | Omar: a robot lands and rescues a rock · Ameen: send a rover · v3: drill rocks | **Drill a core and deliver it to a pickup point** | It matches Omar's "rescue" idea and NASA's real Mars Sample Return plan; a small addition to v3 |
| Moon goal | Omar: land safely · Ameen: launch/altitude/land · v3: land + samples + return | **Land + samples; return as a bonus** | Landing is the Easy core. Return stays because it teaches fuel vs mass |
| Builder style | Ameen: detailed KSP parts (cockpit, fuselage, thrusters, cables, fins, free building) · v3: subsystem lists | **Visual slot builder on the hangar ship, using v3's real subsystem parts** | The challenge is about mission subsystems (power, comms, instruments), and a free-form builder can't be finished in the time left. Slots fix the "too complicated" complaint |
| Physics depth | Ameen: full realistic flight with orbital mechanics everywhere · Omar/PDF: GMAT physics | **Hand-flown landing + GMAT-computed cruise** | Realistic where the player sees it; GMAT can't run in real time inside Godot |
| Money | Ameen: an economy to buy and upgrade · Ahmad: a fixed allotment per mission, rated at the end | **Fixed budget per mission; credits only unlock tech** | Otherwise the resource rating would mean nothing. The "+$100M grant" upgrade is removed |
| Multiplayer | Challenge: up to 4 with roles · Omar: 2-player Fireboy & Watergirl or LAN · v3: shared keyboard | **1–4 players over the network, one role each, each on their own computer** (Omar's decision, 13 Nov) | Meets the challenge's "up to 4 with roles" fully, and each player owns a real job |
| Multiplayer scope (D7) | Builder-only · builder + landing/Saturn jobs · jobs on every screen; LAN vs hosted server | **Builder + landing/Saturn jobs, hosted relay server with room codes**, plus REQUEST, quick chat, sign-off reset, team sync score (team, 13 Nov night) | Fits the 2 days left; the hosted server is the only way judges can try multiplayer in the web build |
| Mission budgets | Mahdi's v3: Moon $300M, Mars $500M, Saturn $900M · Omar: Moon 300, Mars 500–600, Hard 900 | **$300M / $500M / $900M** | Omar's range includes Mahdi's tested value, and v3's example ships are balanced for it |
| Hints | Omar: by difficulty · Ameen: mission-control comms | **Both: mission control delivers the hints, at a level set by difficulty** | One system covers both ideas |
| Crew | Omar: maybe crew and a return to Earth · Ahmad: "the astronaut" | **Robotic only; the player is the mission engineer** | Crew adds life support and reentry, two whole systems |
| Difficulty range | Ameen: Hard = Pluto, unexplored targets · everyone else: Moon/Mars/Saturn | **Moon / Mars / Saturn only** | Three finished missions beat more unfinished ones |
