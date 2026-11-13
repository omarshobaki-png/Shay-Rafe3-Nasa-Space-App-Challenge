# The challenge: Space Mission Design Game (read 13 Nov 2026)

Source: https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/ (Details and Resources tabs).
- Difficulty: Intermediate and Beginner/Youth.
- Subject: Games.

## The task in one sentence
Create an interactive game in which participants design, manage and simulate a complete space mission. They make engineering decisions, manage limited resources and see how each choice shapes the mission's success.

## Why it exists (the problem)
- Students rarely get to experiment with a whole mission from concept to operation.
- Existing tools cover single topics (orbital mechanics, spacecraft design or rocket launches) and don't show how they interact as a system.
- The game should close that gap: experiment, hit constraints, and learn from missions that succeed and missions that fail.

## What a strong solution includes (their words, condensed)
- A working interactive game or simulation with a clear interface.
- A mission configuration system.
- Resource management.
- **Collaboration or multiplayer for up to 4 participants.**
- A mission simulation and evaluation system.
- Feedback that rewards good engineering decisions, efficient resource use, successful collaboration and achieved objectives.
- Encouraged: creative mechanics, visualisations, scoring systems and mission scenarios that need problem solving, trade-offs and teamwork.

## The game flow they describe
Define a mission objective → set requirements → design the spacecraft → choose instruments → choose a launch vehicle and an orbit → manage the constraints (budget, mass, power, communications, data, lifetime) → simulate → get feedback.

## "Potential considerations" (optional ideas, grouped)
- **Game design:**
  - Accessible at different knowledge levels.
  - Single player and teams of up to 4, with roles such as mission planning, spacecraft design, science, communications and resources.
  - Clear objectives, and feedback that says *why* a mission succeeded or failed.
  - Redesign and re-simulate many times.
  - Scoring for success, science value, resource efficiency and good decisions.
  - Difficulty levels, mission types and scenarios.
- **Mission design:**
  - Start from the objective.
  - Every major decision has a consequence. Example: more instruments give more science but also more mass, power, cost and data.
  - There is rarely one perfect solution, and different combinations can reach the same goal.
  - Realistic limits on budget, mass, power, communications and lifetime.
- **Spacecraft and payload:**
  - Parts: structure, power, batteries, communications, onboard computer, attitude control and instruments.
  - Instruments differ in mass, power, cost, data and science value.
  - Simple or advanced parts depending on difficulty.
- **Orbit and launch:**
  - Several orbits, each with its basics explained: coverage, observation, communications and lifetime.
  - Launchers differ in payload capacity, cost and orbit capability.
  - **Check that the spacecraft mass and orbit fit the launcher.**
- **Resources to show clearly:** mass, power, budget, data, communications and time (development plus operations). Say which ones are critical for each mission.
- **Collaboration:**
  - Up to 4 people on one mission, each with a role, deciding together.
  - Situations where they must **negotiate competing priorities**.
  - The result depends on how well the team coordinates.
- **Education:**
  - Simple words.
  - Teach orbit altitude, payload capacity, power use, data rate and communications *inside the game*.
  - Short explanations, tutorials and visual indicators.
  - Teach *why* a decision matters, not just right or wrong.
- **Optional features they list:**
  - Several scenarios
  - Random events
  - Difficulty levels
  - Real or simplified spacecraft models
  - An interactive spacecraft view
  - Live resource dashboards
  - Leaderboards
  - End-of-mission reports
  - Saving, sharing and comparing designs
  - Co-op for 4
  - Competitive teams on the same objective
  - A sandbox
  - A post-mission analysis of why it worked or failed

## Resources tab (9 links; "more may be added before the hackathon")
_Re-checked 13 Nov 2026 (night): Details text unchanged, still the same 9 resources._
1. NASA, *Design and Develop Science Missions* (PDF): the systems-engineering path and the 4 segments (launch, space, ground, user).
   https://www.nasa.gov/wp-content/uploads/2025/04/250323-design-and-develop-science-mission.pdf
2. NASA GMAT, the General Mission Analysis Tool: open-source trajectory and orbit software.
   https://software.nasa.gov/software/GSC-19468-1
3. JPL, *Concept Maturity Levels* (CML 1–4: idea → feasibility → trades → point design).
   https://dataverse.jpl.nasa.gov/dataset.xhtml?persistentId=hdl:2014/44299
4. NASA Goddard Mission Design Lab: concurrent engineering, study levels and disciplines (office hours → concept development → trade studies → point design).
   https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/
5. NASA Mission Viz: a web 3D visualiser of missions and trajectories.
   https://nasa.github.io/mission-viz/
6. NASA Webb, *A Learning Game About Telescopes*: pick objectives → wavelengths → instruments → optics, launch it, see results, and compare with real missions. 3 levels of increasing complexity.
   https://science.nasa.gov/mission/webb/game-build-it-yourself/
7. NASA, *CubeSat 101* (PDF): every phase of a CubeSat mission.
   https://www3.nasa.gov/sites/default/files/atoms/files/nasa_csli_cubesat_101_508.pdf
8. Space Apps 2023 challenge, *Visualize a Space Mission Using Virtual Reality* (mission concept, trajectories, timeline, 3D view).
   https://www.spaceappschallenge.org/2023/challenges/visualize-a-space-mission-using-virtual-reality/
9. CSA, *Digital Games and Activities* (a space agency partner resource).
   https://www.asc-csa.gc.ca/eng/youth-educators/digital-games-and-activities.asp

## How game v4 covers the challenge (checked against the code, 13 Nov 2026 night)

Legend: ✅ covered · 🟡 partly · ❌ missing. "Roadmap #n" = `context/04_STATUS_AND_ROADMAP.md`.

| Challenge asks for | v4 | Notes |
|---|---|---|
| Interactive game, clear UI | ✅ | Hangar builder, Mission Control lamps, every screen playable |
| Mission configuration (objective → spacecraft → instruments → launcher) | ✅ | Destination picks the objective; parts bin; launcher choice |
| Launcher mass/orbit compatibility check | ✅ | Booster lamp + GO/NO-GO poll |
| Resources shown: mass, power, budget, data, comms, time | ✅ | One lamp per station (booster, power, fuel, landing, science, data, comms, budget, time, risk) |
| Explain *why* a decision matters / why a mission failed | ✅ | Plain-words lamp hints with physics + NASA sources; report cause chain |
| Roles: planning, spacecraft, science, comms | ✅ | 4 roles, each owns its lamps |
| Up to 4 players collaborating | 🟡 | Local, one screen, roles split lamps. No networked play (roadmap #9) |
| Negotiating competing priorities | 🟡 | Implicit (shared budget/mass); no explicit trade-off or vote moment |
| Reward **efficient resource use** (named in "strong solution") | ❌ | No efficiency score (roadmap #4) |
| Score for success, science value, decisions | 🟡 | Per-role score + credits; no science-value vs. cost breakdown |
| Difficulty levels | 🟡 | Destinations are easy/medium/hard; hints don't change with difficulty (roadmap #2) |
| Several orbits explained (coverage, lifetime, comms) | 🟡 | Destinations + flight path; no choice between orbit types around a body |
| Random events | 🟡 | One real DONKI solar storm; more events planned (roadmap #5) |
| End-of-mission report / post-mission analysis | ✅ | Goals, cause chain, tip, real-mission comparison (upgrade = roadmap #6) |
| Redesign and re-fly many times | ✅ | Back to builder; Tech Lab with credits |
| Save designs | 🟡 | Saves progress (funds, tech, best); not ship designs |
| Share/compare designs, leaderboard | ❌ | Not planned |
| Sandbox mode | ❌ | Not planned |
| Competitive teams on the same objective | ❌ | Not planned |
| Teach concepts in simple words inside the game | ✅ | Hover formulas, lamp hints, NASA DATA screen |

**Biggest scoring gaps, in order:** efficiency score (#4, named directly in "strong solution"); explicit team
trade-off moments for 2–4 players; difficulty-based hints (#2); more random events (#5). The remaining ❌ items
are optional ideas in the brief.
