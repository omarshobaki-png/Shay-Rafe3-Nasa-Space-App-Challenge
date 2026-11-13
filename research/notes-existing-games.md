# Existing games, past challenges and past winners

Notes for the 2026 NASA Space Apps challenge "Space Mission Design Game".
Research only. No game code. Written 13 Nov 2026.

Every number below has the URL where it was read. PDF numbers also give the page.

How pages were read:
- WebFetch read the NASA, CSA, Space Place, Wikipedia and 2015/2021 Space Apps pages.
- WebFetch fails on www.spaceappschallenge.org with an SSL error ("unable to get local issuer certificate").
  I read those pages in the built-in browser pane instead, as page text only (no screenshots, no images).
- The Webb game PDFs came back as binary. I extracted their text locally with pdftotext.

---

## 1. The gap in one paragraph

The challenge page says it plainly: "Existing tools often focus on individual topics such as orbital mechanics, spacecraft design, or rocket launches without demonstrating how these elements interact as a complete system."
(https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/?tab=details)

What I found confirms it. Each existing tool covers one slice:

| Tool | Slice it covers | What it lacks |
|---|---|---|
| NASA Webb "Build It Yourself: Satellite!" | science goal -> wavelength -> instrument -> optics | no budget, mass, power, data, comms, orbit, launch choice, lifetime, failure, team play |
| Science Learning Hub "Build a satellite" (NZ) | parts + payload + orbit, with a mass check | no budget, power, data, lifetime; one right answer per mission |
| NASA Space Place "CubeSat Builder" | assembling parts to match orders, against a clock | no mission design at all; it is a factory game |
| NASA "Rocket Science 101" (2012) | matching a rocket to a mission | no spacecraft or instruments |
| CSA OSIRIS-REx game | picking a sample site by 4 criteria | no spacecraft design |
| CSA RADARSAT game | using satellite data for 3 user tasks | no spacecraft design |
| JPL / NASA Eyes | watching real missions in 3D | not a game; no design or choices |
| 2023 Space Apps VR challenge | visualising trajectory and timeline | no design, no resources, no score |
| Kerbal Space Program | rockets, orbits, flight physics | hard for beginners; not about instruments, data or comms |
| Mars Horizon (ESA-backed, commercial) | agency budget, tech tree, mission resource minigames | not open, not a browser game, not about designing one spacecraft |

No tool I found lets a beginner do the whole chain in one place:
objective -> instruments -> spacecraft bus (power, comms, computer) -> launch vehicle + orbit -> simulate -> explained success or failure -> redesign.
None of them supports a team of up to four with different roles.
None of them explains *why* a mission failed in terms of mass, power, data or budget.
That is the gap to fill.

---

## 2. NASA Webb: "A Learning Game About Telescopes" / "Build It Yourself: Satellite!"

Source page: https://science.nasa.gov/mission/webb/game-build-it-yourself/
Transcript PDFs (read with pdftotext):
- Game text: https://science.nasa.gov/wp-content/uploads/2024/03/gametext.pdf
- Level 1 results: https://science.nasa.gov/wp-content/uploads/2024/03/level1-science.pdf
- Level 2 results: https://science.nasa.gov/wp-content/uploads/2024/03/level2-science.pdf
- Level 3 results: https://science.nasa.gov/wp-content/uploads/2024/03/level3-science.pdf

### Facts about the game
- Aim: it "teaches the player that science requirements drive telescope mission design and engineering." (source page)
- Approved by the NASA Education product review in 2013. (source page)
- Minimum screen size 1024 x 768. Made for tablets, laptops and desktops. Not for most phones. (source page)
- No built-in accessibility. A full text transcript is offered instead. (source page)
- No age is given on the NASA page. TryEngineering lists it as "High School: Ages 14–17". (https://tryengineering.org/resource/game/build-it-yourself-satellite-game)
- Credits: written by Maggie Masetti, with a programmer, an artist and six scientists thanked. (gametext.pdf, page 1)

### How it plays (from gametext.pdf)
1. Start screen, then a level select: Level 1, Level 2, Level 3, plus a "Need a hint" button. (page 1)
2. **Science screen.** Pick a science goal. There are 5: Black Holes, Star Formation, Early Universe, Galaxies, Exoplanets. Hovering an icon shows a short text. (page 1)
3. **Wavelength screen.** The options depend on the goal. The full set is X-ray, gamma ray, optical, ultraviolet, infrared and microwave. Example: Early Universe offers optical, microwave and IR. (pages 2 to 7)
4. **Instrument screen.** The options depend on the wavelength: camera, spectrometer, radiometer (microwave only), proportional counter (X-ray only), scintillator (gamma ray only). (pages 8 to 9)
5. **Optics screen.** Single primary mirror, segmented mirror, or no optics. Gamma rays get no optics because they cannot be focused. A proportional counter needs no optics. (pages 10 to 12)
6. **Launch.** A rocket animation crosses the screen over the Earth. (page 12)
7. **Result.** A drawing of a real satellite like yours, real data like yours, and a text about the science. (page 12)

You can go back and change anything until launch. Some options are greyed out because they "may not be scientifically or technologically viable". (source page, "Playing Hints")

### Levels
- Level 1: one goal, one wavelength, one instrument. Smallest mission. (source page; gametext.pdf page 1)
- Level 2: up to two science goals and up to two wavelengths. Each wavelength needs at least one instrument. A bigger rocket launches. You can get more than one result. (gametext.pdf, page 13)
- Level 3: you may select 4 science goals, 3 wavelengths in total and 3 instruments in total. Optical and infrared optics include a segmented mirror "like Webb". An even bigger rocket. (gametext.pdf, page 13)

### Constraints, as the game teaches them
Constraints exist only as text, not as numbers:
- Bigger mirrors are heavier and "more expensive to launch". (gametext.pdf, page 11)
- Glass X-ray mirrors are heavier, so "just four or so" fit. (gametext.pdf, page 11)
- A segmented mirror costs more than a small one but less than launching "a single giant mirror". (gametext.pdf, page 11)
- Thin-foil X-ray mirrors "fit the budget that a smaller satellite would have". (gametext.pdf, page 11)

### Results and the link to real missions
- Each result names a real mission and shows its real data. Missions named:
  - Level 1: RXTE, Swift, CGRO (COMPTEL), GALEX, COBE, ISO, WISE, TESS, Suzaku, ASCA, ESO's VLT. (level1-science.pdf, pages 1 to 18)
  - Level 2: Chandra, Swift, FUSE, COBE, GALEX, Fermi, Gemini, Spitzer, WISE, ESO's VLT. (level2-science.pdf, pages 1 to 15)
  - Level 3: Chandra, Hubble, James Webb, Fermi, Herschel, WMAP. (level3-science.pdf, pages 1 to 31)
- Results are keyed by the path you chose, for example "Black Holes -> X-ray -> Proportional Counter" gives RXTE data. (level1-science.pdf, page 1)
- The page says the missions run from the 1980s to today. (source page)
- Collection hook: each played result unlocks a mystery silhouette on the main menu. The hint list has 7 entries, one per silhouette. (gametext.pdf, page 13)

### What it lacks
- **Budget:** none as a number. Cost is only mentioned in text.
- **Mass:** none as a number.
- **Power, data, communications, lifetime:** not present.
- **Orbit and launch vehicle:** not chosen by the player. The rocket simply gets bigger per level.
- **Failure:** no fail state. The page warns that too many incompatible choices can make the satellite "a mess", but the transcript shows every valid path ends with a real mission result.
- **Multiplayer or roles:** none.
- **Score:** none.
- **Accessibility and phones:** none built in.

Related NASA game: "Scope It Out" teaches basic telescope design through telescope-matching puzzles. "Best suited for teens and interested adults". Approved by NASA Education product review in 2010. (https://science.nasa.gov/mission/webb/game-scope-it-out/)

---

## 3. Canadian Space Agency: "Digital Games and Activities"

Source: https://www.asc-csa.gc.ca/eng/youth-educators/digital-games-and-activities.asp

The page lists 11 items: Tomatosphere Adventure (Minecraft Education), Mission: Astronaut, Exploring Earth, RADARSAT Constellation Mission game, OSIRIS-REx game, The Explorers Club e-books, quizzes, 3D printing models, astronaut cutouts, a "Canada from space" puzzle, and playlists. (source)

None of them is a spacecraft or mission design game. Three are useful as patterns:

### Game – OSIRIS-REx (closest to a mission decision)
Read from the game itself: https://www.asc-csa.gc.ca/app/game/OSIRIS-REx/index.html?lang=en&returnHome=true
- Goal: help the spacecraft pick the best place on asteroid Bennu to take a sample.
- 4 candidate sites: Kingfisher, Osprey, Nightingale, Sandpiper.
- Each site is rated on 4 criteria: Accessibility, Safety, Sampling capacity, Scientific value.
- You "Analyze" a site with Canada's OSIRIS-REx Laser Altimeter (OLA), then "Send".
- Win text says the sample was "large enough and excellent in quality" and that Canada gets part of it.
- Lesson for us: a clear multi-criteria trade-off on one screen, and an instrument you "use" to reveal data.

### Game – RADARSAT Constellation Mission
Read from the game itself: https://www.asc-csa.gc.ca/app/game/RADARSAT/index.html?lang=en&returnHome=true
- 3 missions: Arctic (find a safe ship route through ice), Inundation (find flooded areas), Agriculture (monitor soil moisture).
- Route analysis shows Distance, Accessibility or Ice hardness, and Travel time. Then "Analyze the route" and "Send".
- Lesson for us: missions framed as helping a real person (farmer, first responder, ship captain).

### Game – Mission: Astronaut
Source: https://www.asc-csa.gc.ca/eng/youth-educators/activities/game-mission-astronaut.asp
- Free online game for grades 3 to 6. Computers or tablets.
- 8 missions made of short activities. 6 minigames. One minigame, Lunar Rover, uses coding blocks.
- Players earn stars and spend them on cards from 7 collections.
- A teacher account gives 50 student keys. Students need no email.
- Lesson for us: a no-login classroom mode and a light collection reward.

---

## 4. 2023 Space Apps: "Visualize a Space Mission Using Virtual Reality"

Source (read in the browser pane): https://www.spaceappschallenge.org/2023/challenges/visualize-a-space-mission-using-virtual-reality/?tab=details

What it asked:
- An interactive VR app, inside a web browser, to visualise a space mission: the concept, the orbital trajectories and the timeline.
- Examples: an Earth-orbiting satellite, an Earth-to-Moon transfer, an Earth-Mars cycler, a deep-space probe crossing the asteroid belt.
- Three skill tiers:
  - Beginner: use GMAT or design a 3D elliptical orbit.
  - Intermediate: draw an orbit on a digital globe (NASA Web WorldWind), or build an orrery with an Earth-Mars cycler.
  - Advanced: an orrery with a planetary fly-by (slingshot).
- It notes that free digital globes exist but "there isn't a comparable virtual orrery".
- Resources: NASA Eyes, GMAT, Web WorldWind, NASA Mission Viz (https://nasa.github.io/mission-viz/), a Three.js orrery, ESA pykep.

Winners:
- None of the 10 global winners of 2023 came from this challenge. (https://science.nasa.gov/directorates/smd/2023-nasa-international-space-apps-challenge-announces-10-global-winners/)
- One team I could read: Team Robust (Dhaka) built "Hubble Service Mission VR", a VR walk-through of Hubble Servicing Mission 1 with an AI helper. It is a self-description, not an award. (https://www.spaceappschallenge.org/2023/find-a-team/team-robust/)
- The challenge's full team list loads by script and I could not read it.

Lesson for us: pure visualisation did not win. It had no choices, no stakes, no score. Our game can reuse the visual idea (an orbit view, a mission timeline) as the *payoff* of design choices, not as the whole product.

---

## 5. Other mission-design or spacecraft-building games

### NASA Space Place – CubeSat Builder
Source: https://spaceplace.nasa.gov/cubesat-builder-game/en
- Build as many CubeSats as you can in a NASA cleanroom before time runs out.
- Steps: test parts at stations, put a box on a workstation, add tested parts that match an order, run the vacuum test and the weighing station, ship on the conveyor.
- 7 part types: antenna, battery, "brain", steering wheel, compass, propulsion unit, camera. Propulsion is only for far targets like Mars.
- Keyboard (WASD or arrows, space) and a mobile joystick.
- Lesson: nice kid-level names for subsystems ("brain" = computer). Testing before flight is a real step.

### NASA Space Place – Build Your Own Spacecraft (hands-on, not digital)
Source: https://spaceplace.nasa.gov/build-a-spacecraft/en/
- You are "chief engineer". Pick one of 4 goals: study Earth, photograph planets, monitor the Sun, find planets elsewhere.
- Every craft needs 5 parts: container, power source, science instruments, communication device, orientation finder.
- No mass, power or budget limits.
- Lesson: the 5-part checklist is a good minimum bus for beginners.

### Science Learning Hub (New Zealand) – Build a satellite
Sources: https://www.sciencelearn.org.nz/embeds/149-build-a-satellite and the app https://hubs-satellite.netlify.app/
- 3 missions: find "dark vessels" fishing illegally, track an albatross population, monitor Earth movements.
- Drag parts onto a satellite outline: structure, solar panels, batteries, heat control, computer, thrusters, transmitter/receiver, antenna. Payloads include radar and camera.
- A weight bar in kg. If too heavy: "Satellite is too heavy to launch!" and you must remove items.
- 3 orbits: low Earth, medium Earth (labelled 20,000 km) and geostationary (labelled 35,768 km in the app).
- Wrong payload or wrong orbit: "Not quite!" and no data. A "Try again" button.
- Success: you see the real data your satellite "sent back", then follow-up data activities.
- Published 25 July 2022. Funded by New Zealand's MBIE and the New Zealand Space Agency. Crown copyright.
- Lesson: the closest existing design loop. It has a mass check and an orbit choice. It lacks budget, power, data, comms, lifetime, scoring and team play, and has one right answer.

### NASA – Rocket Science 101 (Launch Services Program)
Source: https://prnewswire.com/news-releases/new-nasa-game-lets-players-build-and-launch-a-virtual-rocket-160601575.html
- Announced 27 June 2012. Web and iPad.
- Pick a NASA mission, pick one of 3 skill levels, build a rocket for it, launch.
- Lesson: launch-vehicle matching was once its own game. In our game it is one step.
- I did not confirm it is still online.

### NASA's Eyes on the Solar System (JPL)
Source: https://www.jpl.nasa.gov/news/explore-the-solar-system-with-nasas-new-and-improved-3d-eyes/
- Browser-based 3D. 126 NASA spacecraft. Paths from 1949 to 2049. Article dated 2 Sept 2022.
- Not a game. Good as a "see the real mission" link from our results screen.

### Mars Horizon (commercial, reference only)
Source: https://en.wikipedia.org/wiki/Mars_Horizon
- 2020 management game by Auroch Digital, made with ESA and the UK Space Agency.
- Public support sets the budget. A tech tree unlocks missions, buildings and rocket parts.
- Each mission has a minigame where you trade resources (navigation, communications, power, data) to meet quotas. Radiation, heat and drift come in later. Missing a quota fails the mission.
- Lesson: the strongest proof that "power / data / comms as spendable resources" is fun. Do not copy its art or names.

### Kerbal Space Program (commercial, reference only)
Source: https://en.wikipedia.org/wiki/Kerbal_Space_Program
- Full release 27 April 2015. 3 modes: Sandbox (no limits), Science (unlock parts with experiments), Career (funds, reputation, contracts).
- Career: parts and fuel cost funds. Late contracts or dead crew cost reputation.
- Physics: Newtonian, patched conics.
- KerbalEdu exists for classrooms.
- Lesson: a Sandbox / Career split maps directly to the challenge's "sandbox mode" idea. KSP's flight piloting is too hard for our audience; skip it.

### Older Space Apps entries on the same theme
- **2021 challenge "Space Quest: The Game"** (https://2021.spaceappschallenge.org/challenges/statements/space-quest-the-game). A near twin of 2026. It asked for a game about mission architecture: goal, destination, crew or robot, trajectory, launch, communications, risks (asteroid strikes, radiation, dusty solar panels, software bugs) and ideas like fixed budgets, turns and co-op resource pooling. 155 teams entered.
  - SMK Pujut Educators (Malaysia), "Space Quest: The Card Game". Global Finalist. 4 to 6 players, each an agency with a one-use superpower. Buy resource cards (real technologies) to redeem exploration cards. No budget mechanic. (https://2021.spaceappschallenge.org/challenges/statements/space-quest-the-game/teams/smk-pujut-educators/)
  - SocialSpacing (Chino Hills, USA), "Spazio" board game. Listed as Global Finalist and Honorable Mention on its page. 2 to 6 players race on a spiral board, 3 turns per planet, chance cards from real hazards. A budget of about 200 million dollars appears only in their proposed future video game. (https://2021.spaceappschallenge.org/challenges/statements/space-quest-the-game/teams/socialspacing)
  - The 2021 finalists page lists 27 teams; Space Quest has one (SMK Pujut Educators). It also lists "Planetary Lander Video Game" (Cosmos Unity) and "The Trail to Mars" (LMC). (https://2021.spaceappschallenge.org/awards/global-finalists/)
  - No 2021 global winner came from Space Quest. "The Trail to Mars: Can You Keep Your Crew Alive?" won Best Storytelling (team Space Travelers, Ecuador). (https://earthdata.nasa.gov/news/nasa-announces-2021-international-space-apps-challenge-global-award-winners) Its project page returned 404, so I do not know how it played.
- **2015 "Start to Finish; NASA Mission"** (https://2015.spaceappschallenge.org/project/start-to-finish-nasa-mission). One-person team. Choose a mission, get funding, pick a rocket, engineers and test facilities, on a limited budget "given to you by congress". Before launch, rocket, payload and range must all be "green". MIT licence. No award shown.

---

## 6. Past Space Apps global winners (2023, 2024, 2025)

### Scale
- 2023: 57,999 registered participants, 152 countries and territories, 5,556 submissions. (https://science.nasa.gov/directorates/smd/2023-nasa-international-space-apps-challenge-announces-10-global-winners/)
- 2024: 485 events, 163 countries and territories, 93,520 registered participants, 9,996 submissions. (https://www.nasa.gov/learning-resources/stem-engagement-at-nasa/nasa-international-space-apps-challenge-announces-2024-global-winners/)
- 2025: 551 local events, 167 countries and territories, more than 114,000 participants, more than 11,500 submissions. (https://www.nasa.gov/learning-resources/stem-engagement-at-nasa/nasa-announces-2025-international-space-apps-challenge-global-winners/)
- Each year has 10 global winners. (same three URLs)

### Game projects among winners
- **2023 Best Use of Science – LunarTech Ensemble (Egypt).** A website and immersive game about Apollo moonquake data. (2023 URL above)
- **2023 Best Storytelling – TeamVoyagers (Bangladesh).** A web game about the water cycle and climate effects on freshwater. (2023 URL above)
- **2024 Most Inspirational – Innovisionaries (Sharjah, UAE), "Eco-Metropolis".** A city-building game; players plan a city and manage resources based on real environmental data. (2024 URL above)
- **2024 Best Storytelling – TerraTales (Egypt).** Climate stories plus an interactive game about eco-friendly choices. (2024 URL above)
- **2025 Art & Technology – Zumorroda-X (Egypt), "Henry's Farm Adventure".** Pixel-art story game. Henry, a farmer, visits farmers in 5 countries (India heatwave 2021, Pakistan floods 2022, Egypt salinisation, US drought, Brazil crops). Each stop shows real NASA data (heat maps, before/after Landsat slider, NDVI, US Drought Monitor) and then a minigame or quiz. Built with JavaScript and Phaser; a Python ML model; sprites in Piskel. The team said its members started with only "some programming experience". (https://www.spaceappschallenge.org/2025/find-a-team/zumorroda-x/ and https://www.spaceappschallenge.org/2025/meet-the-2025-global-winners/)

### The most relevant non-game winner
- **2025 Best Mission Concept – PureFlow (Brazil).** A habitat design tool. You place modules in 3D. It recalculates mass, power and life support in real time from crew size and mission length. It then hits your design with live space-weather events from NASA's DONKI API and asks whether the crew survives. They call it "a survival simulator", not a layout tool. (https://www.spaceappschallenge.org/2025/find-a-team/pureflow2/)
- This is the closest past winner to our challenge: live resource totals while you design, then a stress test with real NASA data.

### Best Mission Concept in earlier years (for contrast)
- 2023: ASTROGENESIS (Peru), a planner for trips to planets and moons. (2023 URL above)
- 2024: AsturExplorers (Spain), "Landsat Connect", tracks Landsat passes. (2024 URL above)

### 2025 finalists
- https://www.spaceappschallenge.org/2025/awards/global-finalists/ loads its team list by script. I could not read the names. Unknown whether any finalist was a mission design game.

---

## 7. How judging works (what wins)

Source: https://www.spaceappschallenge.org/resources/judging-awards-guide/
- Every level of judging scores each project 1 to 5 on 5 criteria: **Impact, Creativity, Validity, Relevance, Presentation.**
- Relevance means NASA data must be "a core component" and not "a superficial addition".
- Validity includes "usability and user-friendliness".
- Presentation: judges score the demo and the full project. The guide says to give it equal weight and to recruit people for storytelling and design.
- Demo: a slide deck of at most 7 slides, or a video of at most 30 seconds. English, or subtitles in English.
- Teams: at most 6 members.
- Submit before Sunday 15 November, 11:59 pm local time.
- Global Nominees announced 3 Dec 2026. Global Finalists announced 17 Dec 2026.
- 10 global awards. "Best Mission Concept" = "the most plausible concept and design". "Art & Technology" = combines technical and creative skills. "Best Storytelling" = communicates open data through story.
- All external code, text and images must be listed in References. No copyrighted media without permission.

The 2026 challenge is tagged "Intermediate" and "Beginner/Youth", with the skill "Games". (https://www.spaceappschallenge.org/2026/challenges/space-mission-design-game/?tab=details)

### What made past winners win (my reading of the above)
1. **Real NASA data at the centre.** Henry's Farm shows real Landsat and NDVI data at every stop. PureFlow pulls live DONKI data. LunarTech used Apollo seismic data. This is the Relevance criterion.
2. **A human story and a role.** "Henry", "you are the Mission Architect", "help a farmer". Three of the game winners won storytelling or inspiration awards, not technology awards.
3. **Instant feedback on choices.** PureFlow recalculates mass and power on every click and then stress-tests the design.
4. **Scoped, finished, playable.** Henry's Farm is 5 short stops with one minigame each, not a huge simulation. It was built by a team new to the subject.
5. **A clean pitch.** The guide stresses the 30-second video or 7 slides.
6. Pure visualisation (2023 VR challenge) and card/board games (2021 Space Quest) reached finalist at best; none won a global award.

---

## 8. Game ideas, each tied to a source

1. **Science drives design (Webb).** Start with an objective, then only show instruments that fit it, greying out impossible ones with a one-line reason. (Webb game, "Playing Hints")
2. **"Your mission is like..." result card (Webb).** After the sim, show the real NASA mission closest to the player's design, with its real data image and a link to NASA Eyes. (Webb level PDFs; JPL Eyes)
3. **Collection of mystery missions (Webb).** Silhouettes on the menu that fill in when a design matches a real mission. Gives replay value. (gametext.pdf, page 13)
4. **Hard mass gate at launch (Science Learning Hub).** "Too heavy for this rocket" blocks launch and says by how many kg. Extend it to every resource: power, data, budget. (hubs-satellite app)
5. **Orbit choice with consequences (Science Learning Hub; 2026 challenge).** LEO / MEO / GEO (plus maybe sun-synchronous) changes coverage, comms windows, lifetime and launch cost. Wrong orbit = poor data, not just "wrong".
6. **Live resource bars (PureFlow; 2026 challenge).** Mass, power, budget, data per day, downlink per day, lifetime, all updating on every click. (PureFlow page; challenge "Resource Management")
7. **Stress test with real NASA data (PureFlow).** During the simulation, inject a real solar event from DONKI or a real eclipse season. Shows NASA data as core, which scores on Relevance.
8. **Explain the failure (2026 challenge).** End report in the form: "Your camera made X GB a day but your antenna sent only Y GB, so most of the science was lost." (X and Y come from the player's own design; no real figures here.) The challenge asks to teach why, not just right or wrong.
9. **Multi-criteria scoring like OSIRIS-REx.** Score the mission on 4 axes (science value, cost, risk, lifetime) instead of pass or fail. (CSA OSIRIS-REx game)
10. **Missions framed as helping people (RADARSAT, Henry's Farm).** Scenarios like "find illegal fishing boats", "watch a flood", "count albatrosses", "find an exoplanet". (CSA RADARSAT; Science Learning Hub)
11. **Kid-friendly subsystem names (CubeSat Builder).** "Brain" for computer, "compass" for attitude, with the real term underneath. (CubeSat Builder)
12. **Five-part minimum bus (Space Place).** Structure, power, instruments, comms, attitude. Beginner mode starts with only these. (Build Your Own Spacecraft)
13. **Team roles for up to 4 (2026 challenge; 2021 Space Quest).** Science lead, spacecraft engineer, launch and orbit lead, budget and comms lead. Each sees a different panel and must agree before launch. Agency "one-use superpower" idea from SMK Pujut could be a role ability (for example, the budget lead can request one extra funding round).
14. **Random events (2021 Space Quest; Mars Horizon).** Dusty panels, radiation, a stuck antenna, a software bug. Each hits one resource and tests the margin the team left.
15. **Sandbox vs Career (KSP).** Sandbox with no limits for learning; Career with a budget cap and contracts. (KSP; challenge "sandbox mode")
16. **Before / after data slider (Henry's Farm).** Show what the player's instrument "sees" next to real NASA imagery. (Zumorroda-X page)
17. **Levels by mission size (Webb).** Level 1 CubeSat, Level 2 small satellite, Level 3 flagship telescope, like Webb's small / medium / large. (Webb page)
18. **Classroom mode without accounts (Mission: Astronaut).** A share code instead of logins. (CSA Mission: Astronaut page)

---

## 9. Cautions

- **Licences.** NASA text and data are generally usable, but some Webb result images carry other credits (ESA, Max Planck Institute, Nature). Check each image before reuse. CSA content is Government of Canada material. Science Learning Hub content is Crown copyright. Mars Horizon and KSP are commercial: reference only, copy no art, names or text.
- **Judging rule.** Every external asset and code library must be listed in References.
- **Relevance.** A game with no real NASA data will score lower on Relevance.
- **Demo limits.** 30-second video or 7 slides. Plan the pitch early.
- **Accessibility.** The Webb game has none and does not work on phones. A keyboard-usable, phone-friendly game is a real difference, and Validity counts usability.
- **Scope.** Past winning games were small and finished. A full physics sim is a trap.
- **Do not claim our game is "the first".** Science Learning Hub already checks mass and orbit, and 2021 Space Quest teams covered mission architecture. Our claim should be "the whole system in one loop, with team roles and explained failure".
- **Unverified.** I could not read the 2025 global finalists list or the 2023 VR challenge team list. "The Trail to Mars" (2021 winner) page is gone, so I do not know its mechanics.
- **Access issue.** WebFetch and curl fail on www.spaceappschallenge.org (SSL). The browser pane works.

---

## 10. Pages that failed

- https://www.spaceappschallenge.org/... via WebFetch: SSL error. Read in the browser pane instead.
- https://www.spaceappschallenge.org/2025/awards/global-finalists/ : list loads by script; names not readable.
- https://www.spaceappschallenge.org/2025/awards/global-winners/ : winner names load by script; used the NASA news page instead.
- https://data.nasa.gov/blog/spaceapps-judging-and-awards/ (redirect from open.nasa.gov): 404.
- https://legacy.spaceappschallenge.org/awards/ and /awards/global-finalists/ : 404.
- https://2021.spaceappschallenge.org/challenges/statements/the-trail-to-mars-can-you-keep-your-crew-alive/teams/space-travelers : 404.
- https://4h.okstate.edu/.../marsbound-space-explorers-2024-a.pdf : 403.
- https://www.learner.org/.../Build-a-Satellite-to-Orbit-the-Moon.pdf (NASA BEST activity): 404.
- https://sispprogram.schools.nsw.gov.au/... (UNSW Canberra satellite mission activity): DNS failure.
- https://esa.int/kids/en/Games : 404.
- https://medialabamsterdam.com/?p=3879 (ESA AIM Space Challenge): page no longer about the game.
- https://www.americaspace.com/2012/06/28/new-game-lets-you-build-and-launch-rockets/ : 404.
- https://wiki.kerbalspaceprogram.com/wiki/Career : bot protection. Not bypassed.
- https://www.wikiwand.com/en/articles/Mars_Horizon : 403.
- web.archive.org : WebFetch cannot fetch it.

---

## Added 13 Nov: the 2025 Global Finalists list, read in the browser

45 Global Finalists (https://www.spaceappschallenge.org/2025/awards/global-finalists/; the list loads in 3 batches). Grouped by challenge:
- Stellar Stories (space weather): 9 teams — CosmicNova, Earth Tellers 2, ExoVisionaries, HerCode Space, Luminexus (a high school), SPACEWALK, Stellar Narrators, Team Nomads, and others.
- Will It Rain On My Parade?: 7. A World Away (exoplanets + AI): 5. Commercializing LEO: 4 (Astro Sweepers, Gaia+LEO, NEIL A, Photonics Odyssey). Space Biology Knowledge Engine: 4. SpaceTrash Hack (Mars recycling): 2. Meteor Madness: 2 (Meteor Rizzlers, TechNova). Embiggen Your Eyes: 2. Cloud computing / Earth data: 2. **Habitat Layout Creator: 2 (BuBu, PureFlow)**. One each: Sharks from Space, Terra animation, BloomWatch, ISS 25th anniversary, SAR radar, Healthy Cities, Deep Dive, Farm Navigators (Zumorroda-X).
- **No 2025 challenge was a mission-design game**, so no direct twin among the finalists.

### Finalists closest to this challenge
- **TechNova (Morocco), "Meteor Madness".** Web app with 3 modes: **Learn** (XP points, levels unlock as you finish lessons and quizzes), **Simulate** (real near-Earth asteroids from **NASA's NEO API** in 3D, pick a date range, hazardous ones in red, crash one into any place on Earth), **Mitigate** (try deflection: kinetic impactor, laser ablation). Six engineering students. https://www.spaceappschallenge.org/2025/find-a-team/technova3/
  - Pattern: learn → simulate → fix, with live NASA data in the middle.
- **BuBu (Taiwan), habitat layout.** Drag furniture into a scene, then an AI image model redraws the layout. Said "over 90% of the code" was written with Claude Code, images by Google's image model. Listed 4 NASA documents as its NASA data. https://www.spaceappschallenge.org/2025/find-a-team/bubu/
  - Note: this was under the 2025 rules. The 2026 rules are stricter (idea must not come from AI; visible watermark on AI images).
- **GRIT-X Awa** (exoplanets challenge) mentions mission design with NASA GMAT and STK in its team profile.
