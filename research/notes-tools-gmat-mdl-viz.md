# Notes: GMAT, Goddard Mission Design Lab, NASA Mission Viz

Read on 13 Nov 2026. Notes only. No game code.
Every number has the URL where I read it. PDFs give the page number.
Where I add my own reasoning, I mark it **[my inference]**. Where I use general knowledge, I mark it **[general knowledge, no source here]** and give no numbers.

Short URL names used below:

- `GMAT-SF` = https://sourceforge.net/projects/gmat/
- `GMAT-GIT` = https://sourceforge.net/p/gmat/git/
- `GMAT-TREE` = https://sourceforge.net/p/gmat/git/ci/47f1a6eb89f3653a542195d42c225c6b0d6746a9/tree/ (the R2026a tree)
- `GMAT-SAMPLES` = `GMAT-TREE` + `application/samples/` (each script read with `?format=raw`)
- `MDL` = https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/mission-design-lab/
- `IDC` = https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/
- `MOTON` = https://ntrs.nasa.gov/api/citations/20160010586/downloads/20160010586.pdf
- `IMDC` = https://ntrs.nasa.gov/api/citations/20030025769/downloads/20030025769.pdf
- `MV` = https://nasa.github.io/mission-viz/
- `MV-REPO` = https://github.com/nasa/mission-viz

---

## 1. GMAT (General Mission Analysis Tool)

### What it is

- NASA's open-source tool for mission design, optimisation and navigation. It covers "low Earth orbit through lunar, libration point, and deep space". Source: https://software.nasa.gov/software/GSC-19468-1
- It is used for real missions, engineering studies, education and public outreach (same page).
- It runs on Windows, Linux and Mac. It is a desktop program (C++, wxWidgets GUI, command line). It does not run in a browser. Source: `GMAT-SF`.
- You can drive it from the GUI, its own script language, or Python or Java. Source: https://software.nasa.gov/software/GSC-19640-1 (the "R2026" entry).

### Versions (they disagree a little)

- software.nasa.gov GSC-19468-1 calls itself "Version R2025a". Source: https://software.nasa.gov/software/GSC-19468-1
- But the R2026a README in the code says R2026a has docket "GSC-19468-1". Source: `GMAT-TREE` + `application/README.txt`
- A separate page, GSC-19640-1, says "R2026". Source: https://software.nasa.gov/software/GSC-19640-1
- SourceForge shows R2026a, "Last Update: 2026-04-03". Source: `GMAT-SF`.
- The GMAT wiki also says the latest is R2026a. Source: https://gmat.atlassian.net/wiki/spaces/GW/overview
- The source zip is 322.0 MB. SourceForge showed 1,520 downloads in the week. Rating 4.4 of 5 from 16 reviews. Source: `GMAT-SF`.

### Licence

- **Apache License 2.0.** SourceForge says "Apache License V2.0". Source: `GMAT-SF`.
- The top-level `License.txt` holds the Apache License "Version 2.0, January 2004". Source: `GMAT-TREE` + `License.txt`
- README: "Copyright (c) 2002-2026 United States Government, as represented by the NASA Administrator", licensed under Apache 2.0. Source: `GMAT-TREE` + `application/README.txt`
- The README lists third-party parts: wxWidgets 3.2.9, TSPlot, SOFA, Apache Xerces, JPL SPICE, OpenFramesInterface, Boost, f2c, MSISE 1990, NRLMSISE-00, IRI 2007. It does not give each one's licence. Same source.
- The software.nasa.gov pages only say "Open Source" and name no licence.
- Apache 2.0 section 6 gives no right to use NASA's trade names or marks (read in `License.txt`).

### What it models (from the wiki and the sample scripts)

- Resources listed on the wiki: impulsive burn, finite burn, propagators, differential corrector, optimizer, estimator, Moon, libration points, planets, comets, asteroids. Source: https://gmat.atlassian.net/wiki/spaces/GW/overview
- SourceForge lists: optimised manoeuvre and trajectory design, orbit determination, impulsive delta-V, and low/medium/high continuous thrust. Source: `GMAT-SF`.
- R2026a news: exponential drag at any solar system body, a new 2D ground track, the MSISE-00 atmosphere model. Source: https://gmat.atlassian.net/wiki/spaces/GW/overview
- The R2026a tree ships **88 sample scripts** (78 `Ex_`, 10 `Tut_`). Source: `GMAT-SAMPLES`. The names show the mission types it covers:
  - Earth orbit transfer: `Ex_HohmannTransfer`, `Ex_GEOTransfer`, `Tut_SimpleOrbitTransfer`, `Tut_Target_Finite_Burn_to_Raise_Apogee`.
  - LEO upkeep: `Ex_LEOStationKeeping`.
  - Moon: `Ex_LunarTransfer`, `Ex_GivenEpochGoToTheMoon`, `Ex_LunarOrbitStationKeeping`, `Ex_DoubleLunarSwingby`, `Ex_MMSSingleLunarSwingby`, `Ex_LCROSSTrajectory`.
  - Libration points: `Ex_L2Design`, `Ex_LibrationPointStationKeeping_ESM`.
  - Mars and beyond: `Ex_MarsBPlane`, `Tut_Mars_B_Plane_Targeting`, `Ex_MarsOrbit`, `Ex_Yukon_MarsLaunchWindowAnalysis`.
  - Electric propulsion: `Ex_ElectricPropulsion`, `Tut_ElectricPropulsionModelling`.
  - Many craft: `Ex_ConstellationScript`.
  - Ground contact and eclipse: `Ex_StationContactLocator`, `Ex_Contact_Location_Station_Mask`, `Ex_EclipseLocation`.
  - Data formats: `Ex_OEMPropagation`, `Ex_TLE_Propagation`, `Ex_STKEphemOutput`, `Ex_CCSDSAEMAttitude`.
- **There is no `Molniya` or `SunSync` sample** in that list. Source: `GMAT-SAMPLES`.

### Real numbers from GMAT sample scripts (useful as game reference values)

GMAT scripts do not print units. GMAT's defaults are km and km/s. **[general knowledge, no source here]** Treat units below as km, km/s, degrees.

**Tut_SimpleOrbitTransfer** (LEO to GEO, two burns). Source: `GMAT-SAMPLES` + `Tut_SimpleOrbitTransfer.script?format=raw`
- Start state: X = 7100, Y = 0, Z = 1300, VX = 0, VY = 7.35, VZ = 1. DryMass = 850.
- Two impulsive burns named TOI and GOI ("Geosynchronous Orbit Insertion"). Both Isp = 300.
- The targeter varies TOI, coasts to apoapsis, and must reach RMAG = 42164.169 (tolerance 0.1).
- Then it varies GOI and must reach ECC = 0.005.
- Vary bounds for each burn: Lower = 0.0, Upper = 3.14159.
- Spacecraft 3D model: `../data/vehicle/models/aura.3ds`.

**Ex_GEOTransfer** (inclined LEO to equatorial GEO, three burns). Source: `GMAT-SAMPLES` + `Ex_GEOTransfer.script?format=raw`
- Start: SMA = 6578, ECC = 0.001, INC = 28.5 (shown as 28.49999999999999).
- Burn 1 (TOI): raise apogee to RMAG = 85000.
- Burn 2 (MCC, at apogee): change plane to INC = 2 and raise perigee to RMAG = 42195.
- Burn 3 (MOI): lower apogee to SMA = 42166.90.
- Then coast 10 days.
- **[my inference]** The script raises apogee *above* GEO height before it changes plane. This hints that a plane change is cheaper far from Earth. The game could teach "turn where you are slow".

**Ex_LEOStationKeeping** (drag in LEO). Source: `GMAT-SAMPLES` + `Ex_LEOStationKeeping.script?format=raw`
- Drag is on: Cd = 2.2, DragArea = 15, JacchiaRoberts atmosphere, F107 = 150.
- Loop for 10 days. If altitude < 342, burn to raise RMAG to 6737, then trim ECC to 0.00005.
- **[my inference]** Game lesson: low orbits decay. Staying up costs fuel. Lifetime in LEO depends on fuel and solar activity.

**Ex_LunarTransfer** (Earth to Moon orbit). Source: `GMAT-SAMPLES` + `Ex_LunarTransfer.script?format=raw`
- Epoch '22 Jul 2014 11:29:10.811'. DryMass = 1000.
- TOI (trans-lunar burn) Element1 varied between .13 and .5; solved value in file 0.14676929889.
- Coast until RMAG = 325000 (labelled "Prop to Moon SOI"), then switch to a Moon-centred propagator.
- Target the lunar B-plane: BdotT = 15000.4401777, BdotR = 4000.59308992.
- LOI (lunar orbit insertion) Element1 nominal -0.652, varied between -3 and 0. Goal: lunar ECC = 0.
- Then coast 15 days around the Moon.
- Earth gravity 20x20 plus Sun, Moon and planets as point masses. Solar flux 1367.

**Ex_L2Design** (Earth-Moon L2 station-keeping). Source: `GMAT-SAMPLES` + `Ex_L2Design.script?format=raw`
- The libration point is **Earth-Moon L2**, not Sun-Earth L2.
- Start: X = 406326.2, Y = 177458.4, Z = 145838.6 (rounded by me). DryMass = 850.
- One tiny burn dV. Start value -3e-005. Vary bounds -0.04 to 0.0297.
- **[my inference]** Burns near L2 are tiny but must repeat. A missed burn lets the craft drift away.

**Ex_OEMPropagation** (data format). Source: `GMAT-SAMPLES` + `Ex_OEMPropagation.script?format=raw`
- GMAT reads a CCSDS OEM file: `EphProp.Type = 'CCSDS-OEM'`, file `SampleOEMEphem.oem`, step 60. Released in R2022a.

### GMAT 3D model

- The repo has one spacecraft model: `aura.3ds` plus `aura_map.jpg` (texture). Last changed 2011-03-30. Source: `GMAT-TREE` + `application/data/vehicle/models/`
- three.js can load `.3ds` (TDSLoader). **[general knowledge, no source here]**
- The file sits in the Apache 2.0 repo, but no per-file licence is stated.

### Documentation status

- User Guide: PDF, Windows help and HTML, shipped in `docs/help` of the install. Source: https://gmat.atlassian.net/wiki/spaces/GW/pages/380273265/User+Documentation
- **Unread:** the wiki's User Guide PDF (`help-letter.pdf`). It is over 10 MB and WebFetch refused it.
- **Unread:** `gmat.sourceforge.net/docs/...` returned 403 / 404.
- **Unread:** `documentation.help/GMAT/...` returned 403 (third-party mirror anyway).
- No official GitHub repo found. `api.github.com/repos/NASA-AMMOS/GMAT` returned 404. Code is on SourceForge git.

---

## 2. Goddard Mission Design Lab (MDL) and the Integrated Design Center (IDC)

### What the IDC is

- A concurrent-engineering facility at Goddard. Made in **1997**. Source: `IDC`.
- Labs: Mission Design Lab (MDL), Instrument Design Lab (IDL), Mission Planning Lab (MPL, at Wallops), NASA DOME. Source: `IDC`.
- Each lab has core staff: team leads and a lead systems engineer. Experts come from across the engineering directorate. Source: `IDC`.
- The site had a banner: NASA was not updating it during a funding lapse. Pages last updated 23 Jul 2026. Source: `MDL`.

### MDL study levels (from the MDL page)

| Study | Time | Products |
|---|---|---|
| Office Hours | "~ 1 hr" | Brainstorm. Find "tall poles" and key trades. Next steps. |
| Concept Development | "A few half days" | Feasibility and risk check. |
| Tailored Trade Study | "Variable" | Concept, ConOps, resources summary, trade tree, maybe a rough cost. |
| Point Design Study | "6 days" | CAD, Master Equipment List (MEL), engineering models, cost. Must pass a CML checklist first. |

Source: `MDL`.
- Studies cover Concept Maturity Level (CML) 1 to 4. Source: `MDL`.
- The IDL point design is "6.5 days". Source: https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/instrument-design-lab/

### MDL orbit and mission capabilities

- Orbit design: "LEO, GEO, libration, retrograde, drift away, lunar, and deep space". Source: `MDL`.
- Single craft, constellations, formation flying, distributed systems. Source: `MDL`.
- Ground systems, launch vehicle fit, end of mission (controlled and uncontrolled de-orbit, landing, sample return). Source: `MDL`.

### MDL disciplines (16 on today's page)

Attitude Control, Mission Cost, Propulsion, Avionics, Mechanical Designer, Reliability, Flight Dynamics, Flight Software, Mechanical Systems, Orbital Debris, Radiation Environment, Structural, Communications, Mission Operations, Power Systems, Thermal. Source: `MDL`.

Each discipline reports: requirements, baseline and alternative designs, trades, diagrams, interfaces, **mass, power and data-rate estimates**, risk, issues, cost. Source: `MDL`.

The older IMDC (2003 paper) listed **17** disciplines: flight dynamics and attitude control; propulsion and propellant; command and data handling; communications and RF links; flight software; solar array, battery and power electronics; mechanical and structures; thermal; mission operations and ground systems; launch vehicle capability; reliability and safety; integration and test; mission cost; mission risk; orbital debris and de-orbit; orbit environment; risk management. Source: `IMDC`, page 3.

The IDL lists 21 instrument disciplines (optics, detectors, cryogenics, etc.). Source: https://etd.gsfc.nasa.gov/capabilities/integrated-design-center/instrument-design-lab/

### How a study runs (day by day)

From Moton 2016 (`MOTON`):
- Customer contacts the IDC Lead. IDC Lead, MDL Team Lead and MDL Systems Engineer meet several times. Page 1.
- Pre-study work is **2-4 weeks**. They check instrument mass, power, data volume, fields of view. They do first trades on orbits, trajectories and launch vehicles. A questionnaire goes to the customer. The planning meeting is about one month before the study. Page 2.
- The week before: a **2-hour** pre-work meeting. Page 3.
- Day 1 (usually Monday): recap the goals. First product is the **ConOps**, because mission duration, power profiles, **delta-V budgets** and attitude hardware all depend on it. Page 3.
- Tag-ups **twice a day, 9:30 AM and 1:30 PM**. Problems go to small "sidebar" meetings with only the needed engineers. Page 3.
- **By the end of day 1, every discipline lists its mass and power**, kept in the MEL and a mass summary. Page 4.
- **Next three days**: refine the design. If a requirement cannot be met, a sidebar with the customer finds a fix. Page 4.
- **Last day**: present results. Key output: a "Mission Mass Summary and Launch Vehicle Capability" table that shows if the mission is viable. Page 4.
- Results stay private to the customer. Page 4.

From the IMDC 2003 paper (`IMDC`):
- More than 150 studies; "typically in just 4 days". Page 1.
- First study June 1997. 153 studies done: 82 space science, 56 Earth science, 15 other. About 20% had a technology focus. Page 10.
- Old way took "three months or more"; IMDC did it in "less than one week". Page 2.
- Discipline engineers mostly have 10-15 years of experience. Page 2.
- The pre-work questionnaire has roughly 100 entries. Preparation starts 2 to 4 months before. Page 3.
- 4-day flow (page 3): Day 1 client briefing, then a coordination meeting to find open issues. Days 2 and 3: morning and afternoon coordination meetings, splinter sessions. Day 4: final analysis, presentation to client, debrief.
- Every discipline gives a first estimate at the start, then reports key numbers in a **roll-call at twice-daily tag-ups**. Page 4.
- Design converges in about **3 iterations**: straw man, then baseline, then final baseline. Page 5.
- Some clients asked for **"unattainable or sub-optimal orbits"**, so an orbit expert now joins pre-work. Page 7.
- Three, or sometimes four, distinct options is the most a study can handle and stay focused. Page 7.
- Lab: nearly 1000 sq ft, roughly 20 work areas, three projection screens. Page 10.

From the Goddard podcast (https://www.nasa.gov/podcasts/small-steps-giant-leaps/small-steps-giant-leaps-podcast-episode-151-designing-missions/):
- About 10 experts in the room (mechanical, flight dynamics, propulsion, avionics, power, attitude control). Team lead facilitates.
- About a week; "five, six days". Eight hours a day.
- The "Wednesday surprise": a mid-week problem that forces new trades across disciplines.
- The IDC sees concepts about 10 years before launch. It has 28 years of design archives.

Related but **not Goddard** (NASA Langley IDC paper, https://ntrs.nasa.gov/api/citations/20080009754/downloads/20080009754.pdf):
- Typical study: planning 1 to 8 weeks, session 2 to 10 half-days, then a report. Page 3.
- A neat ripple example: a mirror was too big for the chosen rocket's fairing. They split it into folding petals. That added structure mass, which changed power and propellant, which changed cost and thermal. Pages 14-15.
- The facilitator is a "traffic cop" for information. Page 10.

---

## 3. NASA Mission Viz (nasa.github.io/mission-viz)

### What it is

- A small NASA repo of web visualisation demos and tutorials: orreries, an Earth-Moon mission, and a 3-part tutorial on showing a **GMAT trajectory in a browser**. Source: `MV`.
- Author of the tutorials and demos: Daniel A. O'Neil (NASA Marshall). Ontology by Robert Rovetto. Source: `MV`; PDFs below.
- Repo: 33 stars, 8 forks, 16 commits. Created 2022-04-28. Last push 2022-05-16. Main language HTML. Source: https://api.github.com/repos/nasa/mission-viz and `MV-REPO`.
- It is **old code**. The tutorials use GMAT R2014a and are dated 2015-2016. Source: Part 1 PDF, page 2.

### Tech stack (mixed)

- **X3DOM** (`x3dom.js`, XML scene graph in the page) for: Inner Solar System, Earth-Moon mission, GMAT trajectory demos. Source: repo tree https://api.github.com/repos/nasa/mission-viz/git/trees/main?recursive=1
- **three.js r79** (from cdnjs) plus jsonld.js 0.3.15 and jQuery 1.11.1 for "An Orrery in ThreeJS". Source: https://raw.githubusercontent.com/nasa/mission-viz/main/OntologyDrivenOrrery/An_Orrery_in_ThreeJS.html
- Note: the gh-pages text calls the ontology orrery X3DOM, but the file itself uses three.js.
- **R / rgl / htmlwidgets** for the R Markdown pages. Source: repo tree.
- **Cesium**: only named in `X3Dom/README.md`, which describes an Earth-to-Moon Cesium demo with two `.czml` files. **Those files are not in the repo.** Source: https://raw.githubusercontent.com/nasa/mission-viz/main/X3Dom/README.md and the repo tree (132 files, none `.czml`).

### Data formats it loads

- A simple JSON: `{"coordinates":[{"Date","Time","X","Y","Z"}, ...]}`. Made from a GMAT `ReportFile` with columns `Sat.UTCGregorian, Sat.EarthMJ2000Eq.X/Y/Z`. Source: Part 1 PDF (https://nasa.github.io/mission-viz/X3Dom/20150918_WebVisualization_of_a_GMAT_GeneratedTrajectory_Part1.pdf), pages 2-4.
- The demos divide coordinates by 10000 to fit the scene. Part 1 PDF, page 5. The Earth-Moon demo scales by 0.000006. Source: https://raw.githubusercontent.com/nasa/mission-viz/main/X3Dom/20160129_Earth_MoonMission_X3D.html
- Part 3 adds a browser converter (HTML5 FileReader) from GMAT fixed-width text to that JSON. Source: Part 3 PDF (https://nasa.github.io/mission-viz/X3Dom/20151102_WebVisualization_of_a_GMAT_generatedTrajectory_Part3.pdf), pages 1-4.
- 3D model: `TrianaSatellite.x3d`, made in Blender 2.71, X3D 3.0. No creator or licence meta. Source: https://raw.githubusercontent.com/nasa/mission-viz/main/X3Dom/TrianaSatellite.x3d
- Ontology: JSON-LD and OWL. Source: `MV`.
- **No CCSDS OEM. No CZML files. No SPICE. No glTF.** Source: repo tree.
- `MolniyaOrbit.txt` has 155 rows over exactly 3 days, 22 Jul 2014 11:29:10.811 to 25 Jul 2014 11:29:10.811. Source: https://raw.githubusercontent.com/nasa/mission-viz/main/X3Dom/MolniyaOrbit.txt
- **[my inference]** The name "Molniya" looks wrong. Its start epoch equals GMAT's `Ex_LunarTransfer` epoch. Its first point (137380, -75679.6, 21487.6) matches that sample's start position in size, with X and Y signs flipped. So it is likely a lunar-transfer leg, not a Molniya orbit.

### Licence and reuse (important)

- **The repo has no licence.** GitHub API: `"license": null`. Source: https://api.github.com/repos/nasa/mission-viz
- `https://github.com/nasa/mission-viz/blob/main/LICENSE` returns 404.
- The only licence file is `X3Dom/LICENSE`. It is the **X3DOM library's** MIT / GPL-3.0-or-later dual licence (copyright X3DOM, 2009). It covers x3dom.js, not NASA's code. Source: https://raw.githubusercontent.com/nasa/mission-viz/main/X3Dom/LICENSE
- The demo pages carry `<meta name="copyright" content="? Daniel A. O'Neil">` (garbled symbol). Source: Part 1 PDF page 7; Earth-Moon and Inner Solar System HTML.
- The source repo it came from (daoneil/spacemission) also has `"license": null`. Source: https://api.github.com/repos/daoneil/spacemission
- The NTRS memo on the orrery says "Portions of document may include copyright protected material". Source: https://ntrs.nasa.gov/citations/20210000030
- **Conclusion [my inference, not legal advice]:** do not copy Mission Viz code or the Triana model into the game. Re-implement the ideas. Use x3dom or three.js from their own official releases. The *ideas* (GMAT, then JSON, then animate along the path) are free to use.

### Code quality warning

- `InnerSolarSystem.html` computes `var sLR = smA * (1 - oE^2)`. In JavaScript `^` is bitwise XOR, not a power. So the orbit shapes are wrong. Source: https://raw.githubusercontent.com/nasa/mission-viz/main/X3Dom/InnerSolarSystem.html
- That page solves Kepler's equation with Newton-Raphson, tolerance 0.0001, every 50 ms. Same source. The idea is fine; the code is not.
- Earth-Moon demo: clicking Start again stacks timers. Source: 20160129_Earth_MoonMission_X3D.html (read via WebFetch summary).

### The 2015 vision paper (good design ideas)

Source: https://nasa.github.io/mission-viz/X3Dom/20150611_WebBasedMissionVisualizationSystem.pdf
- A web orrery for teachers, students, planners and **game developers**. Page 1.
- It names **"Serious Games"** as a use case, and asks for a licence that allows commercial use. Page 2.
- Run in the browser with no plug-in. Page 2.
- 600,000 known asteroids would overwhelm a browser, so let users pick what to show. Page 2.
- Level of detail: particles far away, real models up close. Page 3.
- Start simple: propagate orbital elements, add perturbations later. Page 3.
- Widgets: timeline, time-acceleration dial, way-point jumps (reset the propagator to avoid error build-up), camera picker. Pages 3-4.
- Mission planning: 2D map views to place 3D way-points; Bezier curves if no orbital elements given; each way-point stores the **rationale** for a manoeuvre. Page 4.
- It names the International Space Apps Challenge as a way to build it. Page 7.

---

## 4. Orbit types for the game: what these sources say

Sources only mention orbits by name. They give few trade-offs. I keep the two apart.

| Orbit | Named in | What the sources show | Plain trade-off |
|---|---|---|---|
| LEO | MDL page; GMAT (Ex_LEOStationKeeping) | Drag pulls the craft down. GMAT burns when altitude < 342 km. | Cheap to reach, close for good images. Short passes over ground stations. Drag uses fuel. **[general knowledge]** |
| SSO (Sun-synchronous) | **Not in any of these sources** | — | Same light at every pass, good for Earth imaging. **[general knowledge]** |
| GEO | MDL page; GMAT (Tut_SimpleOrbitTransfer, Ex_GEOTransfer) | Target radius 42164.169 km; GEO SMA 42166.90 km; three-burn transfer from 28.5 deg | Stays over one spot. Always in contact. Far, so costly to reach and weak resolution. **[general knowledge for trade-off]** |
| HEO / Molniya | Only as a mislabelled file name in Mission Viz | No real Molniya data found | Long dwell over high latitudes. **[general knowledge]** |
| Lunar | MDL page; GMAT (Ex_LunarTransfer etc.); Mission Viz Earth-Moon demo | TOI, coast, B-plane target, LOI; Moon SOI at 325000 km | Needs two big burns. Radio delay longer. **[general knowledge for trade-off]** |
| L2 (libration) | MDL page ("libration"); GMAT (Ex_L2Design = Earth-Moon L2) | Tiny repeat burns (bounds -0.04 to 0.0297) | Stable view, quiet place for telescopes, but needs regular station-keeping. **[general knowledge for trade-off]** |
| Interplanetary / deep space | MDL page; GMAT (Mars B-plane, Mars orbit, launch-window samples) | B-plane targeting; launch windows | Launch windows, long trips, weak signal and power far from Sun. **[general knowledge]** |
| Retrograde, drift-away | MDL page | Named only | Drift-away = Earth-trailing; easy to reach, but the link gets weaker as it drifts. **[general knowledge]** |

### Delta-v ideas from the sources

- Delta-V budget is one of the first numbers the MDL needs, right after the ConOps. Source: `MOTON`, page 3.
- GMAT models both **impulsive** (instant) and **finite** (real duration) burns. Source: https://gmat.atlassian.net/wiki/spaces/GW/overview
- All the sample burns use Isp = 300 and g = 9.81. Source: `GMAT-SAMPLES` scripts above.
- Transfers are split into named burns: TOI/GOI (GEO), TOI/MCC/MOI (GEO with plane change), TOI/LOI (Moon). Sources above.
- A burn is solved by a "targeter": vary the burn until a goal is met (radius, eccentricity, inclination). Sources above.
- Station-keeping is repeated small burns (LEO drag; L2). Sources above.
- **[my inference]** For the game, use a simple rocket-equation check: propellant mass from delta-V, Isp and dry mass. Show "fuel left" as the lifetime gauge.

---

## 5. Reusable things (with licence status)

| Thing | Licence | Safe to reuse? |
|---|---|---|
| GMAT program and its outputs | Apache 2.0 | Yes. Run it offline, export data, keep the NOTICE/attribution. Do not use NASA marks. |
| GMAT sample scripts (numbers above) | Apache 2.0 (repo licence) | Yes, as reference values and as scripts to run. Credit GMAT. |
| GMAT `aura.3ds` + `aura_map.jpg` | In the Apache 2.0 repo; no per-file note | Probably yes with credit; check before shipping. |
| Mission Viz code, demos, Triana model | **No licence**; author copyright meta | No. Re-implement ideas only. |
| x3dom.js | MIT or GPL-3.0+ | Yes (take it from x3dom's own release). |
| three.js | Not checked here | Not read in this task. |
| MDL process (roles, tag-ups, MEL, LV capability table) | Ideas, not code | Yes. Ideas are free. |

---

## 6. Game ideas from these sources

1. **Four roles that mirror MDL disciplines.** Group the 16 MDL disciplines (`MDL`) into four seats:
   - *Flight Dynamics and Propulsion*: orbit, launch vehicle, delta-V, fuel. (Flight Dynamics, Propulsion, Orbital Debris)
   - *Power and Thermal*: solar arrays, battery, heat. (Power Systems, Thermal, Radiation Environment)
   - *Avionics and Comms*: data rate, downlink, software, ground passes. (Avionics, Flight Software, Communications, Mission Operations)
   - *Systems Engineer and Cost*: mass budget, MEL, structure, reliability, money. (Mechanical, Structural, Reliability, Mission Cost, Attitude Control)
   The MDL Team Lead and Systems Engineer are real roles too (`MOTON` page 1-2; `IDC`).
2. **"Study week" structure.** Five short rounds: Day 1 pick ConOps (objective, orbit, life), Days 2-4 refine, Day 5 present. Mirrors `MOTON` pages 3-4 and `IMDC` page 3.
3. **Tag-up roll-call.** Twice per "day", each role reports mass and power into a shared MEL table. Mirrors `IMDC` page 4 and `MOTON` page 4.
4. **The "Wednesday surprise".** Mid-game random event (part too heavy, instrument needs more power, fairing too small). From the podcast. The Langley mirror-in-fairing story is a perfect script (Langley paper pages 14-15).
5. **Launch Vehicle Capability check.** End screen = "Mission Mass Summary vs Launch Vehicle Capability" table, the MDL's own pass/fail. `MOTON` page 4.
6. **Study level = difficulty.** Office Hours (tutorial, 1 choice), Concept Development (easy), Trade Study (compare options), Point Design (full game). From `MDL`.
7. **Orbit expert warns early.** If the player picks an orbit that cannot meet the goal, show a warning, as the IMDC added an orbit expert for "unattainable or sub-optimal orbits". `IMDC` page 7.
8. **Limit options to 3-4.** At most 3-4 choices per decision, as the IMDC found that is the focus limit. `IMDC` page 7.
9. **Mission presets taken from GMAT samples.** LEO imager with drag upkeep (342 km trigger), GEO comms sat (42164 km), Moon orbiter (TOI + LOI), Earth-Moon L2 station-keeping, Mars B-plane. Each with GMAT's real numbers in a "Did you know?" card.
10. **Replay along a path.** Pre-compute a few trajectories with GMAT (Apache 2.0). Store as Date/Time/X/Y/Z JSON (the Mission Viz format). Animate a craft along it with a timeline and speed dial (vision paper pages 3-4).
11. **Way-points with rationale.** Each burn shows *why* it happens ("raise apogee to 85000 km so the plane change is cheaper"). Vision paper page 4; Ex_GEOTransfer.
12. **Debrief like an MDL report.** Show each discipline's verdict, risks, and what to change. `MDL` (each discipline reports requirements, trades, risks).

---

## 7. Cautions

- **Mission Viz has no licence.** Don't copy its code or the Triana model.
- **Mission Viz code is old and buggy** (XOR bug; 2015-2016; three.js r79; HTTP CDN links).
- **GMAT is a desktop app.** It will not run in the browser. Use it offline only, to make data or check numbers.
- **Building before 14 Nov is not allowed.** Generating GMAT data before the event may count as building. Check the rules or wait until 14 Nov.
- **Version mismatch** for GMAT: GSC-19468-1 is shown as R2025a on software.nasa.gov but as R2026a in the README.
- **SSO and Molniya are not covered by any of these three sources.** Get their numbers from other notes.
- The MDL disciplines are 16 now (`MDL`) and were 17 in 2003 (`IMDC` p3). Don't mix the lists.
- MDL point design is "6 days" on the page, "about one week" in the podcast, "typically one week" in Moton, and "4 days" in the 2003 paper. All are true for their time.
- GMAT unit labels are not in the scripts; km and km/s are GMAT defaults.

## 8. Unread

- GMAT User Guide PDF (`https://gmat.atlassian.net/wiki/download/attachments/380273216/help-letter.pdf?api=v2`): over 10 MB, WebFetch refused.
- `https://gmat.sourceforge.net/docs/nightly/html/Tutorials.html` and `SimpleOrbitTransfer.html`: 404.
- `https://gmat.sourceforge.net/docs/`: 403.
- `https://documentation.help/GMAT/Tutorials.html` and `SimpleOrbitTransfer.html`: 403.
- `https://github.com/nasa/mission-viz/blob/main/LICENSE`: 404 (no such file).
- `https://api.github.com/repos/NASA-AMMOS/GMAT`: 404.
- Mission Viz tutorial Part 2 PDF: not opened (Parts 1 and 3 read).
- `MOTON` Table 1 (team list) and Figure 3 (week plan) are images; their text did not extract.

---

## 9. Added 13 Nov: the GMAT User Guide, read from its source

**New find: NASA now has an official GMAT repo on GitHub: https://github.com/nasa/GMAT** (Apache-2.0, default branch `main`, last push 10 Nov 2026). The whole User Guide is there as DocBook XML in `doc/help/src/`, so the 10 MB PDF is no longer needed. (gmat.sourceforge.net/docs gives 403/404; SourceForge's code browser is behind a Cloudflare bot check.)

### The 12 tutorials (Part_Tutorials.xml)
| Tutorial | What it teaches | Numbers in the text |
|---|---|---|
| Simulating an Orbit | Set up a spacecraft and propagate it to periapsis | — |
| Simple Orbit Transfer | **Hohmann transfer** LEO → geostationary with 2 burns | Target apoapsis 42,165 km (GEO radius) |
| Target Finite Burn | A real (non-instant) burn at perigee to raise apogee | Target apogee radius 12,000 km |
| Mars B-Plane Targeting | Course-correction burn to aim at Mars, then Mars Orbit Insertion | Final orbit inclination 90° |
| Optimal Lunar Flyby | Use the Moon's gravity instead of fuel | Goal: periapsis 15 Earth radii, inclination 10° |
| Mars B-Plane with GMAT functions | Same as above, scripted | — |
| **Finding Eclipses and Station Contacts** | EclipseLocator + ContactLocator on the Hohmann mission | One total eclipse of **about 35 min**; contacts of **about 6 min** (in LEO) and **about 29 h** (once in GEO) |
| Electric Propulsion | Low-thrust spiral away from Earth | Thrust deliberately exaggerated to show change in 2 days |
| Simulate DSN Range and Doppler | Fake tracking data from the Deep Space Network | Spacecraft ~1 AU from Sun, almost **300 million km** from Earth |
| Orbit Estimation with DSN data | Work out the orbit from that data | same |
| Filter and Smoother with GPS | Orbit determination from on-board GPS | — |
| Inter-Spacecraft Tracking | Two spacecraft tracking each other | — |

The tutorials are click-by-click software how-tos; their numeric results are shown in screenshots/GMAT output, not in the text.

### GMAT's solar power model (Resource_SolarPowerSystem) — a ready formula for a game
```
P_base   = P0 * (1 - tau/100)^dt                       # ageing: tau = % loss per year, dt in years
P_bus    = A + B/r + C/r^2                              # power the spacecraft itself needs (r = distance from Sun in AU)
P_total  = P_sun * (P_base / r^2) * (C1 + C2/r + C3/r^2) / (1 + C4*r + C5*r^2)
P_thrust = (1 - margin/100) * (P_total - P_bus)         # what is left for electric thrusters
```
- `P_sun` = fraction of sunlight: 1 in full sun, 0 in shadow (eclipse). Shadow model "DualCone" (umbra + penumbra).
- Defaults: P0 = **1.2 kW**, decay **5 %/year**, bus need A = **0.3 kW**, margin **5 %**, C1..C5 = 1.32077, -0.10848, -0.11665, 0.10843, -0.01279.
- Main idea for players: power falls with **1/r²** (half the distance → 4x the power) and slowly with age.

### Nuclear power model (Resource_NuclearPowerSystem)
Same ageing and bus formulas, **no 1/r² and no shadow** (works anywhere). Same defaults (1.2 kW, 5 %/yr).

### Other defaults
- Chemical fuel tank: 756 kg fuel, 0.75 m³, density 1260 kg/m³ (hydrazine-like), 1500 kPa, 20 °C.
- Impulsive burn: **Isp 300 s**, g = 9.81 m/s². GMAT uses the rocket equation to burn fuel mass.
- Imager: a camera with a field-of-view cone; GMAT can report when a target is in view (IntrusionLocator / ContactLocator).

### Licence reminder
Apache-2.0: formulas and default values can be reused with credit ("Based on NASA GMAT, Apache License 2.0").

### Moton 2016 images, read 13 Nov (`MOTON` p3)
**MDL Engineering Team (Table 1), 20 seats:** Attitude Control; Avionics; Communications; Costing; Debris Analysis / End of Mission; Electro-Mechanical; Electrical Power; Flight Dynamics; Flight Software; Integration & Testing; Launch Vehicle; Mechanical Designer; Mechanical Systems; Mission Ops; Mission Systems Engineer (x2); Propulsion; Radiation; Reliability; Thermal; Team Lead.

**MDL Study Plan (Figure 3), one week:**
- **Mon** AM: meet the customer team, expectations, key issues. PM: define the ConOps; derive subsystem requirements; every subsystem enters first **mass and power** estimates into the bookkeeping software.
- **Tue** AM: first mechanical sketch (key parts, fields of view); block diagram ("architecture"). PM: subsystem status; component info entered by close of business.
- **Wed** AM: the systems engineer presents the whole spacecraft's first **mass/power total**; integration-and-test flow. PM: review design concerns; **finalise the design**.
- **Thu**: prepare presentations, check them for consistency.
- **Fri**: present to the customer.
- **Following Mon**: lessons learned; final write-up.

### Mission Viz tutorial Part 2, read 13 Nov (nasa/mission-viz repo, X3Dom/20150923_..._Part2.pdf, 10 pages)
- Builds on Part 1: texture-map the Earth, keep the trajectory data in a separate JSON file (`mission.js`), **animate a spacecraft along a GMAT Hohmann-transfer trajectory**, show date/time stamps, add a reset button.
- Data format is simple: a list of `{Date, Time, X, Y, Z}` points in km exported from GMAT.
- Uses X3Dom (2015 WebGL library); old tech today, but the idea (GMAT export → JSON → animate in browser) still works with any 3D library.
- Live demo it links to: http://daoneil.github.io/spacemission/X3Dom/AHohmannTrajectory_JSON.html (not opened).
