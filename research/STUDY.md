# Space Mission Design Game: the full study

NASA Space Apps Challenge 2026. Read on 13 Nov 2026, the day before the hackathon.
Challenge page: https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/

This file is the summary. The detail and every source link are in the 6 notes files next to it (list at the end).

> **Two rules to keep in mind before reading**
> 1. **No building before Sat 14 Nov.** Teams may not start work on the challenge before the hackathon. This study is background reading only: no code, no art, no game design yet.
> 2. **The game idea must be the team's own.** The rules say AI ("SI") must not be used to come up with the idea. So this study lists facts, options and what judges reward. It does **not** pick a concept for you. Section 8 lists the choices; the team makes them on Saturday.

---

## 1. The challenge in one minute

**Task:** make an interactive game where players design, manage and simulate a whole space mission. They make engineering choices, juggle limited resources, and see how each choice changes whether the mission succeeds.

**Why it exists:** students rarely get to try a whole mission from idea to operations. Existing tools teach one piece (orbits, or spacecraft, or rockets) and never show how the pieces affect each other.

**The flow they describe:**
objective → requirements → spacecraft → instruments → launcher and orbit → manage limits (budget, mass, power, communications, data, lifetime) → simulate → feedback on *why* it worked or failed.

### Must-have checklist (from "what a strong solution includes")
- [ ] A working, playable game with a clear interface
- [ ] A mission set-up system (choose objective, parts, instruments, launcher, orbit)
- [ ] Resource management: mass, power, budget, data, communications, time
- [ ] **Collaboration or multiplayer for up to 4 people** (roles such as planning, spacecraft, science, communications, resources)
- [ ] A simulation and evaluation step
- [ ] Feedback that rewards good engineering, efficient resource use, teamwork and reaching the objective
- [ ] **A check that the spacecraft's mass and orbit fit the chosen launcher** (named explicitly)
- [ ] Simple words; teach orbit height, payload capacity, power, data rate and comms *inside* the game
- [ ] Explain *why*, not just right or wrong; allow redesign and re-run

### Nice-to-have list (theirs, "optional")
Several scenarios, random events, difficulty levels, real or simplified spacecraft, a 3D spacecraft view, live resource dashboards, leaderboards, end-of-mission report, save/share/compare designs, 4-player co-op, competing teams on one objective, sandbox, post-mission analysis.

Difficulty listed: Intermediate and Beginner/Youth. Subject: Games.

---

## 2. Rules that can get you disqualified

| Rule | Detail |
|---|---|
| Dates | Project page opens **Sat 14 Nov, 9:00** local time. Submission closes **Sun 15 Nov, 23:59** local time. Ask the Local Lead about local judging times. |
| No early work | No work on the challenge before the hackathon starts. |
| Team | 1–6 people, all registered at the **same Local Event**, all on the Members tab. Nobody can be added after the deadline. One team per person, one challenge per team. |
| Under 18 | Must be registered and accompanied by a parent or guardian. **No image, video, voice or likeness of anyone under 18 in the demo or project.** |
| Demo | **A video of 30 s or less, OR 7 slides or fewer** (title slide counts). Going over = not eligible for Global Judging. Public link, no login (YouTube, Drive or GitHub). English, or English subtitles. |
| Project link | Public, no password. Ideally the game is a website. For a new domain, request a FortiGuard classification so judges' school networks don't block it. |
| NASA data | Say exactly which NASA data or resources you used. **At least one is required for any Global Award.** Judges want it at the core, not stuck on. |
| AI ("SI") | AI must **not** create the idea. AI images and videos need a **visible watermark**. AI code, audio and data must be acknowledged in the description and metadata. No NASA logos, flags or mission identifiers in AI-made content. |
| Outside material | List every outside resource, open-source code included. No copyrighted material without permission. |
| Submit | Tick both boxes (terms; "all work original, all external resources listed"), then **Submit for Judging**. You can resubmit until the deadline; only the last save is judged. |

Results: Global Nominees 3 Dec 2026, Finalists 17 Dec 2026, Winners 26 Jan 2027.

**Suggested 30 s demo script (from the submission guide):**
0:00 who we are → 0:02 the challenge and why we chose it → 0:05 project name and tagline → 0:10 show it working, the player's experience, and how NASA data made it possible → 0:20–0:30 what it could do for people.

A slide deck must show: team name, members' names, the challenge, a picture of the project, the user experience, and how NASA data makes it possible.

---

## 3. How it is judged

Five criteria, each scored 1–5, at local and global level:

| Criterion | What judges look for | What it means for this game |
|---|---|---|
| **Impact** | How big the problem is, how many people it reaches or inspires | Students everywhere; works in a browser with no install |
| **Creativity** | Original idea, or a real improvement on one | Something the existing tools (section 5) don't do |
| **Validity** | Grounded in science, feasible, complete, usable | Real numbers (section 7); a finished, playable loop |
| **Relevance** | Fully answers *this* challenge; **NASA data is core** | Hit the must-have checklist; NASA data drives the gameplay |
| **Presentation** | The demo and the whole project | The guide says to give this "equal attention". 30 s is very short: plan it early |

**Global awards that fit a mission-design game best:**
- **Best Mission Concept**: "the most plausible concept and design". Won in 2025 by PureFlow (section 6).
- **Best Storytelling**
- **Art & Technology**: won in 2025 by Henry's Farm.
- Also possible: Best Use of Data, Best Use of Science, Most Inspirational.

---

## 4. The 9 official resources: what each one gives you

| # | Resource | What's useful in it | Notes file |
|---|---|---|---|
| 1 | NASA, *Design and Develop Science Missions* (slides) | The real 6-step process: need → concept → requirements → design → build and verify → operate. **4 mission segments: Launch, Space, Ground, User**, which line up with up to 4 players. A small worked example (BioNutrients-2) with real numbers. "Begin with the end in mind": start from what the scientist needs. Every requirement gets a test, chosen before building. | mission-process |
| 2 | NASA GMAT | Professional orbit software. Apache 2.0 licence, desktop only, so **it can't run in a browser game**. NASA now hosts it on GitHub (github.com/nasa/GMAT), full user guide included. 12 tutorials: Hohmann transfer to GEO, Mars arrival, lunar flyby, **eclipses and ground-station contacts** (about 35 min of shadow; contact windows of 6 min in low orbit vs. 29 h from GEO), electric propulsion, Deep Space Network tracking. Its **solar power formula** (power falls with distance², ages 5%/year, drops to 0 in shadow) can be reused with credit. | tools-gmat-mdl-viz |
| 3 | JPL *Concept Maturity Levels* | A ladder from idea to design: CML 1 "cocktail napkin" (objective in **one sentence**) → 2 feasibility (rough sums, compare with past missions) → 3 trade space (compare options on science, cost, risk) → 4 point design. A concept is "at" a level when about **80% of its checklist is green**. Going back from 4 to 3 is normal and good. Skipping trade space gives worse missions. Self-scores run too high. **The CML 4 checklist sets real margins: ≥ 35% spare mass, power and battery energy; ≥ 100% spare computer capacity; telecom link ≥ 3 dB (deep space) or ≥ 6 dB (nearby).** Also: a backup rocket, a 5 × 5 risk matrix, a "baseline" and a "minimum" science goal. | mission-process |
| 4 | Goddard Mission Design Lab | How NASA engineers design a mission in one week: about **20 seats** (power, thermal, comms, propulsion, flight dynamics, launch vehicle, costing, radiation, team lead…). Mon: mission plan, everyone enters first mass and power. Tue: sketch and block diagram. Wed: whole-spacecraft mass/power total, then **design frozen**. Thu: presentations. Fri: present to the customer. Close to how a team game could feel. | tools-gmat-mdl-viz |
| 5 | NASA Mission Viz | A web 3D viewer of spacecraft and orbits. Its tutorials export a GMAT trajectory as a list of x, y, z points and animate a spacecraft along it in the browser (2015 tech). **No licence file, so don't copy its code**; take ideas only. | tools-gmat-mdl-viz |
| 6 | NASA Webb, *A Learning Game About Telescopes* | The nearest existing game: pick goals → wavelengths → instruments → mirror, launch, see results, then a screen comparing your design with real missions ("your telescope is like…"). Single player, one mission type. | existing-games |
| 7 | NASA *CubeSat 101* (2017) | Real CubeSat sizes and mass limits (1U under 1.33 kg, 3U under 4.00 kg). Real timeline: typically 18–24 months to build, launch slots via NASA's CubeSat Launch Initiative (up to $300k of launch paid). Licensing, testing, common reasons CubeSats fail. **No subsystem numbers** (those come from other sources). | cubesat101 |
| 8 | Space Apps 2023, *Visualize a Space Mission Using VR* | An earlier challenge on mission visualisation. | existing-games |
| 9 | CSA *Digital Games and Activities* | The Canadian Space Agency's (a Space Apps partner) learning games; counts as partner data if used. | existing-games |

The challenge page says "more resources may be added before the hackathon". **Check the Resources tab again on Saturday morning.**

---

## 5. What already exists, and the gap

- Many tools teach one piece: orbit simulators, rocket builders, spacecraft part pickers, the Webb telescope game, CSA activities, Science Learning Hub's mission-planning activity (the closest loop found).
- **No tool found does the whole chain** (objective → design → launch → operate → explained result) **with team roles and an explanation of why it failed.** That is the gap the challenge describes.
- **A near-twin challenge ran in 2021: "Space Quest: The Game"** (155 teams). Best results were a card game and a board game, both Global Finalists; none won a global award. Pure visualisation (2023 VR challenge) also stopped at finalist. So judges have seen the idea, but nobody has nailed it.
- Competition: **1,887 teams** had picked this challenge on 13 Nov (challenge page). In 2025 there were 11,500+ submissions from 167 countries.

Full comparison table: `notes-existing-games.md`.

---

## 6. What past winners did

| Winner | Award | What they did |
|---|---|---|
| **PureFlow** (Brazil, 2025) | Best Mission Concept | Habitat design tool. Every click recalculates mass, power and life support. Then it **stress-tests the design with live space-weather events from NASA's DONKI API**. They called it "a survival simulator", not a layout tool. |
| Henry's Farm (2025) | Art & Technology | A story game; real Landsat and NDVI data shown at every stop. |
| LunarTech, Eco-Metropolis, TeamVoyagers | various | Real NASA data sets (e.g. Apollo seismic data) inside the experience. |
| TechNova (Morocco, 2025) | Global Finalist | "Meteor Madness": **Learn** (earn XP, unlock levels) → **Simulate** (real asteroids from NASA's NEO API in 3D, crash one anywhere on Earth) → **Mitigate** (try deflection methods). |

All **45 Global Finalists of 2025** were read. None was a mission-design game (there was no such challenge in 2025); the closest were the habitat-layout, asteroid and Low-Earth-orbit business challenges. In 2023 the VR mission challenge had one finalist (CodeGalore, India) and no winner.

**Patterns in what wins:**
1. Real NASA data at the centre of the gameplay (Relevance).
2. A human story or a clear "why should I care".
3. Instant feedback on every choice.
4. A small scope that is actually finished and playable.
5. A clean, fast pitch.

---

## 7. Real numbers you can use

All with sources in `notes-real-numbers.md` (and `notes-cubesat101.md`). A few examples:

| Thing | Value |
|---|---|
| Sunlight at Earth / Mars / Jupiter | 1361 / 586 / 50 W per m² |
| Solar arrays | about 30 W per kg; cells about 30% efficient |
| CubeSat body panels (peak, start of life) | 2.3 W (1U), 8.1 W (3U), 27.8 W (6U) |
| Li-ion batteries | 150–270 Wh per kg |
| Nuclear power (MMRTG) | about 110 W, 45 kg |
| CubeSat mass limits | 1U < 1.33 kg, 3U < 4.00 kg |
| SpaceX rideshare (SpaceX's own calculator, read 13 Nov) | **$0.35M up to 50 kg, then $7,000 per kg** ($0.7M for 100 kg, $3.5M for 500 kg, $5.82M for 1,000 kg) |
| Rocket Lab Electron (its own site) | **300 kg to low orbit**; 99 launches so far; price about $7.5M (secondary) |
| Falcon 9 (SpaceX site) | **22,800 kg to low orbit, 8,300 kg to GTO, 4,020 kg to Mars**; price about $74M (secondary) |
| JPL design margins (CML 4) | ≥ 35% spare mass, power and energy; ≥ 100% spare computing; ≥ 3 dB / 6 dB telecom |
| GMAT defaults | Engine Isp 300 s; solar power 1.2 kW at start, loses 5% a year |
| Mission cost classes | CAPSTONE $13.7M; Pioneers $20M; SMEX $170M; Discovery $495M; Europa Clipper $5.2B; JWST $9.66B |
| CubeSat failure rates | about 18–30% dead on arrival; power causes about half of later failures |
| CubeSat survey to 2018 (Villela 2019) | 855 launched; **about 75% succeed** (not counting rocket failures); about 20% of failures happen at launch or deployment; 3U is 64% of all CubeSats |

The notes also have: launchers (Electron, Alpha, PSLV-XL, Falcon 9, Falcon Heavy, Vulcan, Ariane 6) with mass to each orbit; orbits with eclipse times, radiation and delta-v; Deep Space Network and CubeSat radio data rates; Mars light delay; real instruments (MRO's cameras and radar, Cassini and Voyager magnetometers) with mass, power and data rate.

**Live NASA data sources that could feed a game** (all mentioned in the notes): DONKI space weather (used by PureFlow), real mission specifications, Landsat/Earth imagery, planetary data. Which one, and how, is a team decision.

---

## 8. The choices the team has to make on Saturday

Not answers, just the questions. Each row lists options the sources support.

| Decision | Options seen in the sources |
|---|---|
| What kind of mission | Earth science, heliophysics (the Sun), planetary, astrophysics (NASA's 4 fields); CubeSat vs. big mission |
| How 4 players split the work | By the 4 segments (Launch, Space, Ground, User); by challenge roles (planning, spacecraft, science, comms, resources); by MDL disciplines grouped into 4 |
| Same screen or online | One shared screen (pass-and-play), or networked play (much harder in 2 days) |
| Structure | Free sandbox; scenario missions; a ladder like CML 1→4 then launch |
| How "simulation" works | A simple timeline with events; a numbers check with red/green lights; a visual orbit |
| Where NASA data is core | Live data during the simulation; real mission specs as parts and benchmarks; real data as the reward ("your mission saw this") |
| How the result is explained | A report card per resource; per requirement; a "your mission is like…" comparison with a real mission |
| Look and tone | Engineering dashboard, story, cartoon, retro… |
| Tech | A browser game (the guide prefers a website). The team's own tools |

---

## 9. Cautions

- **Scope trap.** The wish list is huge and you have about 39 hours. Judges reward a finished small loop over an unfinished big one. Decide early what "done" means.
- **Licences.** GMAT is Apache 2.0 (fine with credit). Mission Viz has no licence: ideas only, no code. List every outside asset.
- **Secondary numbers.** Rideshare prices are now from SpaceX itself, but full-rocket prices (Falcon 9, Electron) still come from Wikipedia; neither company publishes them. Label those "approximate" in the game.
- **Margins are now sourced:** JPL's CML 4 checklist (2013) in the official CML resource. Note the footnote: later design stages allow smaller margins.
- **Under-18 likeness.** No team faces or voices in the demo.
- **AI marks.** Any AI image or video in the game or demo needs a visible watermark.
- **Demo limit.** 31 seconds or 8 slides = out of Global Judging.

---

## 10. Not read, or open

Read on 13 Nov in a second pass: the CML matrix and checklist images, the GMAT user guide (from NASA's GitHub), SpaceX's and Rocket Lab's own pages, all 45 2025 finalists, the 2023 VR finalists, the Villela 2019 CubeSat survey, the Goddard team table and week plan, and Mission Viz tutorial Part 2. The Resources tab was checked again: still the same 9 links.

Still not read:
- GMAT's tutorial results are in screenshots, so the exact delta-v numbers weren't extracted. GMAT's 100+ reference pages were skimmed only for power, fuel tank, burns and cameras.
- Full-rocket prices: neither SpaceX nor Rocket Lab publishes them.
- Pages that no longer exist (404): the 2021 "Trail to Mars" winner, some ESA and NASA BEST activity pages. CodeGalore's 2023 project page isn't public.
- The Resources tab may still get new links on Saturday morning.
- Unknown: your Local Event's judging time and whether it allows online multiplayer demos.

---

## Files in this folder

| File | What's in it |
|---|---|
| `notes-challenge.md` | The challenge text, condensed, plus the 9 resources |
| `notes-rules.md` | Dates, team rules, submission fields, AI rules, judging, awards |
| `notes-mission-process.md` | NASA's 6 steps, 4 segments, requirements, CML levels |
| `notes-cubesat101.md` | CubeSat sizes, timeline, licensing, launch, failures |
| `notes-tools-gmat-mdl-viz.md` | GMAT, Mission Design Lab, Mission Viz, licences |
| `notes-existing-games.md` | Existing games and tools, past winners, what wins |
| `notes-real-numbers.md` | Launchers, orbits, power, comms, instruments, costs, failure rates, all sourced |
