# Real numbers for the mission-design game

Research notes for NASA Space Apps 2026, challenge "Space Mission Design Game".
Written 13 Nov 2026. Notes only. No game code.

Every number below has the URL where I read it.
"(secondary)" means the number comes from Wikipedia or a catalogue site, not the maker or NASA.
"(my maths)" means I divided or added two sourced numbers myself.
If a cell says "not found", I looked and did not find a source I could read.

---

## 1. Launch vehicles

The SpaceX website did not load for me (it is built with JavaScript, and the price PDF gave 404).
So the Falcon numbers come from Wikipedia, which cites SpaceX's own price page.

| Rocket | Class | To LEO | To SSO | To GTO / beyond | Price | Sources |
|---|---|---|---|---|---|---|
| Rocket Lab Electron | small | 300 kg (updated, 2020) | 200 kg | NASA bought a CAPSTONE launch to the Moon (with Photon stage) for $9.95M | about $7.5M (2020) | [Wikipedia Electron](https://en.wikipedia.org/wiki/Electron_(rocket)) (secondary); [NASA CAPSTONE launch](https://www.nasa.gov/news-release/nasa-awards-contract-to-launch-cubesat-to-moon-from-virginia/) |
| Firefly Alpha | small | 1,030 kg (300 km) | 630 kg (500 km) | - | $15M to $17.6M (2022) | [Firefly Alpha](https://fireflyspace.com/alpha/); price: [Wikipedia Firefly Alpha](https://en.wikipedia.org/wiki/Firefly_Alpha) (secondary) |
| ISRO PSLV-XL | medium | 3,800 kg (200 km, 30 deg) | 1,750 kg (600 km) | Sub-GTO 1,425 kg; GTO 1,300 kg | about $18M to $27M (2026 money) | SSO and sub-GTO: [ISRO PSLV](https://www.isro.gov.in/PSLV_CON.html); rest: [Wikipedia PSLV](https://en.wikipedia.org/wiki/Polar_Satellite_Launch_Vehicle) (secondary) |
| SpaceX Falcon 9 | medium-heavy | 22,800 kg expendable; 17,500 kg with booster landing | - | GTO 8,300 kg expendable, 5,500 kg reusable; Mars 4,020 kg | $74M (2026) | [Wikipedia Falcon 9](https://en.wikipedia.org/wiki/Falcon_9) (secondary, cites SpaceX price page) |
| SpaceX Falcon Heavy | heavy | 63,800 kg expendable | - | GTO 26,700 kg; Mars 16,800 kg | $97M reusable (2022); $150M expendable (2017) | [Wikipedia Falcon Heavy](https://en.wikipedia.org/wiki/Falcon_Heavy) (secondary) |
| ULA Vulcan (VC6, 6 solids) | heavy | 27,200 kg | LEO-polar 23,900 kg | GTO 14,500 kg; GEO 6,500 kg; TLI (Moon) 11,500 kg | about $110M (starting) | [ULA Vulcan](https://www.ulalaunch.com/rockets/vulcan-centaur); price: [Wikipedia Vulcan](https://en.wikipedia.org/wiki/Vulcan_Centaur) (secondary) |
| ULA Vulcan (VC0, no solids) | medium | 10,800 kg | LEO-polar 8,500 kg | GTO 3,500 kg; TLI 2,300 kg | not found | [ULA Vulcan](https://www.ulalaunch.com/rockets/vulcan-centaur) |
| Ariane 62 | medium | 10.3 t | 7,200 kg | GTO 4.5 t | about EUR 100M (2024 estimate) | LEO/GTO: [CNES](https://cnes.fr/en/news/new-ariane-6-four-booster-a64-variant-changes-game); SSO and price: [Wikipedia Ariane 6](https://en.wikipedia.org/wiki/Ariane_6) (secondary) |
| Ariane 64 | heavy | 21.6 t | 15,500 kg | GTO 11.5 t | about EUR 115M (2018 estimate) | same as above |

### Rideshare (small satellites)

| Item | Value | Source |
|---|---|---|
| SpaceX Transporter rideshare | rides start at $350k for about 50 kg | [NASA SST State of the Art 2026, ch. 10](https://www.nasa.gov/smallsat-institute/sst-soa/integration-launch-and-deployment/) |
| Same, per kg | about $7,000/kg (my maths: 350,000 / 50) | same |

### Notes on launch data

- NASA's 2026 small-launch table lists Electron at 200 kg and Alpha at 630 kg "to LEO". Those match the SSO numbers above, so NASA's table likely means SSO. [NASA SST ch. 10](https://www.nasa.gov/smallsat-institute/sst-soa/integration-launch-and-deployment/)
- Vulcan has five set-ups (0, 2, 4 or 6 solids, plus an upgrade). The ULA page has the full table. [ULA](https://www.ulalaunch.com/rockets/vulcan-centaur)
- Ariane 64 first flew on 12 Feb 2026. [CNES](https://cnes.fr/en/news/new-ariane-6-four-booster-a64-variant-changes-game)

---

## 2. Orbits

| Orbit | Altitude | Period | Good for | Source |
|---|---|---|---|---|
| LEO | under 2,000 km, usually not below 180 km | about 90 min; speed about 7.8 km/s | high-resolution imaging; ISS; constellations | [ESA types of orbits](https://www.esa.int/Enabling_Support/Space_Transportation/Types_of_orbits) |
| ISS orbit | (not given on page) | 90 to 93 min; 15.5 to 15.9 orbits per day; inclination 51.6 deg; track moves 22.9 deg west each orbit | crew, ISS-deployed CubeSats | [NASA JSC orbit tutorial](https://eol.jsc.nasa.gov/Tools/orbitTutorial.htm) |
| Polar | 200 to 1,000 km | - | sees the whole planet over time | [ESA](https://www.esa.int/Enabling_Support/Space_Transportation/Types_of_orbits) |
| Sun-synchronous (SSO) | 600 to 800 km; about 7.5 km/s at 800 km | Aqua at 705 km takes about 99 min | same local time every pass, so images compare well (fires, floods, forests) | [ESA](https://www.esa.int/Enabling_Support/Space_Transportation/Types_of_orbits); [NASA orbit catalog](https://science.nasa.gov/earth/earth-observatory/catalog-of-earth-satellite-orbits) |
| Landsat 8 (real SSO example) | 705 km, 98.2 deg | repeats every 16 days; crosses equator 10:12 a.m. | land imaging | [USGS Landsat 8](https://www.usgs.gov/landsat-missions/landsat-8) |
| MEO (GPS) | about 20,200 km above surface | 12 h | navigation | [NASA orbit catalog](https://science.nasa.gov/earth/earth-observatory/catalog-of-earth-satellite-orbits) |
| Molniya (HEO) | inclination 63.4 deg, eccentricity 0.722 | 12 h; two thirds of the time over one hemisphere | comms at high latitudes | [NASA orbit catalog](https://science.nasa.gov/earth/earth-observatory/catalog-of-earth-satellite-orbits) |
| GEO | 35,786 km | 23 h 56 min 4 s; about 3 km/s | stays over one spot; TV, comms, weather; three satellites give near-global cover | [ESA](https://www.esa.int/Enabling_Support/Space_Transportation/Types_of_orbits) |
| Sun-Earth L1 / L2 | about 1.5 million km from Earth | halo or Lissajous orbit | L1: steady Sun view (SOHO). L2: space telescopes (JWST, Gaia, Euclid) | [ESA](https://www.esa.int/Enabling_Support/Space_Transportation/Types_of_orbits); [NASA orbit catalog](https://science.nasa.gov/earth/earth-observatory/catalog-of-earth-satellite-orbits) |
| Low lunar orbit (LRO) | 50 km polar | mean 113 min | lunar mapping | [LRO mission design paper, p. 4](https://science.nasa.gov/wp-content/uploads/2024/01/iac-07-c1-7-06.pdf); [NSSDCA LRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2009-031A) |
| Mars orbit (MRO) | 255 x 320 km science orbit | not given on page | Mars imaging and relay | [NSSDCA MRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2005-029A) |

### Eclipse (time in shadow, on batteries)

| Orbit | Eclipse | Source |
|---|---|---|
| ISS (LEO) | 90 min orbit, 30 min eclipse | [NASA ISS power overview 2016, p. 4](https://ntrs.nasa.gov/api/citations/20160014034/downloads/20160014034.pdf) |
| GEO (GOES) | up to 72 min per day, only in two seasons: late Feb to mid Apr, late Aug to mid Oct | [NOAA OSPO GOES eclipse](https://ospo.noaa.gov/operations/goes/eclipse.html) |
| Low lunar orbit (LRO) | up to 48 min of a 113 min orbit | [LRO paper, p. 4](https://science.nasa.gov/wp-content/uploads/2024/01/iac-07-c1-7-06.pdf) |

### Radiation

| Item | Value | Source |
|---|---|---|
| Inner Van Allen belt | reaches down to about 1,000 km; protons and electrons | [NASA Earth Observatory](https://science.nasa.gov/earth/earth-observatory/probing-the-electric-space-around-earth-78985/) |
| Outer Van Allen belt | up to about 60,000 km; mainly energetic electrons | same |
| Belt latitude | both reach about 65 deg north and south | same |
| Juno radiation vault (Jupiter) | titanium, almost 400 lb (172 kg); cuts radiation 800 times | [JPL Juno](https://www.jpl.nasa.gov/news/nasas-juno-spacecraft-to-risk-jupiters-fireworks-for-science/) |
| Europa Clipper shielding | aluminum-zinc sheets up to 9.2 mm thick | [JPL Europa Clipper quick facts](https://www.jpl.nasa.gov/press-kits/europa-clipper/quick-facts/) |

Plain reading: LEO below about 1,000 km is calm. MEO (GPS) sits in the belts. GEO is near the outer belt. Jupiter is the worst.

### Delta-v (km/s)

Most of these come from Wikipedia's "Delta-v budget" table (secondary).
That table's columns came through as plain text. I matched values to columns by order, so please check before using.

| Move | Delta-v (km/s) | Source |
|---|---|---|
| Ground to LEO | 9.3 to 10 | [Wikipedia Delta-v budget](https://en.wikipedia.org/wiki/Delta-v_budget) (secondary) |
| LEO to GTO (from a 700 km LEO) | 2.3 | same, note 1 |
| LEO (equatorial) to GEO | 3.90 | same, high-thrust table |
| LEO at Kennedy's inclination ("LEO-Ken") to GEO | 4.33 | same |
| LEO to Earth escape (C3 = 0) | 3.22 | same |
| GEO to Earth escape | 1.30 | same |
| LEO to trans-lunar injection | 3.20 | same (cites NASA, Whitley and Martinez 2015) |
| TLI to low lunar orbit | 0.90 | same |
| LEO to low lunar orbit | 4.04 | same |
| LEO to Moon surface | 5.93 | same |
| LEO to Earth-Moon L1 / L2 | 3.77 / 3.43 | same |
| LEO to Sun-Earth L2 (low thrust, electric) | 7.4 | same, low-thrust table |
| LEO to Mars transfer | 4.3 ("typical, not minimal") | same |
| Delta-v from LEO: Venus / Mars / Jupiter | 3.5 / 3.6 / 6.3 | same, solar system table |
| Mars transfer to low Mars orbit (no aerobraking) | 2.7 (not minimal) | same |
| Low Mars orbit to Mars surface | 4.1 | same |
| LRO total delta-v budget (real mission) | 1,270 m/s | [LRO paper, p. 2](https://science.nasa.gov/wp-content/uploads/2024/01/iac-07-c1-7-06.pdf) |
| Keeping a 50 km lunar orbit | about 150 m/s per year | [LRO paper, p. 6](https://science.nasa.gov/wp-content/uploads/2024/01/iac-07-c1-7-06.pdf) |
| LEO to Molniya | not found | - |

---

## 3. Power

### Sunlight

| Place | Solar power per m2 | Source |
|---|---|---|
| Earth | 1,361.0 W/m2 | [NASA Earth fact sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html) |
| Mars | 586.2 W/m2 | [NASA Mars fact sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/marsfact.html) |
| Jupiter | 50.26 W/m2 | [NASA Jupiter fact sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/jupiterfact.html) |

Rule: power falls with the square of distance from the Sun. NASA SST ch. 3 says this in words.
Distances from the Sun: Earth 149.598, Mars 227.956, Jupiter 778.479 (million km). Same fact sheets.

### Solar cells and arrays

| Item | Value | Source |
|---|---|---|
| Silicon cell efficiency | about 20% | [NASA SST 2026 ch. 3 Power](https://www.nasa.gov/smallsat-institute/sst-soa/power-subsystems/) |
| Space multi-junction cells (3 to 5 junctions) | nominal 30%, best 34% | same |
| Best flight cells (start of life) | 29.5% to 32.2% (Table 3-1) | same |
| Cell power per area (Table 3-1) | silicon 229.2 W/m2; multi-junction 403 to 433.4 W/m2 | same |
| Array power per mass | most missions near 30 W/kg; range 1 to 200 W/kg | same, Fig. 3.3 |
| CubeSat body panels, peak at start of life | 2.3 W (1U), 8.1 W (3U), 27.8 W (6U) (Exobotics) | same, Table 3-2 |
| ISS solar arrays | 8 arrays, 75 to 90 kW | [NASA ISS facts](https://www.nasa.gov/international-space-station/space-station-facts-and-figures/) |
| MRO at Mars | 1,000 W | [NSSDCA MRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2005-029A) |
| LRO at the Moon | 800 W average per orbit | [NSSDCA LRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2009-031A) |
| Europa Clipper arrays | two arrays, each 14.2 m x 4.1 m (Jupiter is over 5 times farther from the Sun) | [JPL Europa Clipper](https://www.jpl.nasa.gov/press-kits/europa-clipper/quick-facts/) |

### Batteries

| Item | Value | Source |
|---|---|---|
| Commercial Li-ion | 150 to 270 Wh/kg | [NASA SST ch. 3](https://www.nasa.gov/smallsat-institute/sst-soa/power-subsystems/) |
| Common 18650 cells | 182 to 260 Wh/kg (Table 3-4) | same |
| LiPo | 150 to 200 Wh/kg | same |
| Supercapacitors | 5 to 20 Wh/kg (Table 3-6) | same |
| LRO battery | 80 A-hr Li-ion | [NSSDCA LRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2009-031A) |
| MRO batteries | two NiH2, 50 A-hr each, 32 V | [NSSDCA MRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2005-029A) |

### Nuclear (RTG)

| Item | Value | Source |
|---|---|---|
| MMRTG electric power at launch | about 110 W | [NASA MMRTG fact sheet 2013](https://mars.nasa.gov/files/mep/MMRTG_FactSheet_update_10-2-13.pdf) |
| MMRTG heat | about 2,000 W thermal | same |
| MMRTG mass | about 45 kg (94 lb) | same |
| MMRTG size | 64 cm wide, 66 cm tall | same |
| Plutonium dioxide fuel | 4.8 kg | same; [NASA RPS FAQ](https://science.nasa.gov/planetary-science/programs/radioisotope-power-systems/faq/) |
| Design life | 14 years (plus 3 years storage) | [NASA RPS FAQ](https://science.nasa.gov/planetary-science/programs/radioisotope-power-systems/faq/) |
| Power loss per year | "a few percent", not given as a number on the pages I read | - |

---

## 4. Communications

### Deep Space Network

| Item | Value | Source |
|---|---|---|
| Sites | Goldstone (California), Madrid (Spain), Canberra (Australia) | [NASA DSN](https://www.nasa.gov/communicating-with-missions/dsn/) |
| Spacing | about 120 deg apart in longitude | [JPL DSN](https://www.jpl.nasa.gov/missions/dsn/) |
| Dishes per site | one 70 m, several 34 m, one 26 m | [NASA DSN](https://www.nasa.gov/communicating-with-missions/dsn/) |
| One DSN dish can track | up to 4 spacecraft if they sit in the same beam | [NASA SST ch. 11](https://www.nasa.gov/smallsat-institute/sst-soa/ground-data-systems-and-mission-operations/) |

### Real data rates

| Mission | Rate | Source |
|---|---|---|
| MRO at Mars (3 m dish, X-band) | up to 6 Mbps | [NSSDCA MRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2005-029A) |
| New Horizons at Pluto (about 3 billion miles) | about 1 to 4 kbps; full download took about one year | [NASA 2015](https://www.nasa.gov/general/nasas-new-horizons-spacecraft-begins-intensive-data-downlink-phase/) |
| LRO at the Moon (Ka-band) | 100 to 300 Mbps | [NSSDCA LRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2009-031A) |
| Landsat 8 (LEO) | 384 Mbps X-band; 3.14 Tbit recorder; about 750 scenes per day | [USGS Landsat 8](https://www.usgs.gov/landsat-missions/landsat-8) |
| MarCO CubeSats at Mars | relayed InSight at 8 kbps (UHF) | [JPL InSight press kit, MarCO](https://www.jpl.nasa.gov/news/press_kits/insight/landing/appendix/mars-cube-one/) |
| ISARA 3U CubeSat | over 100 Mbps Ka-band | [NASA SST ch. 9](https://www.nasa.gov/smallsat-institute/sst-soa/soa-communications/) |
| TBIRD laser CubeSat | 200 Gbps; 4.8 Tb in one pass | same |

### CubeSat radios (NASA SST 2026, Table 9-3, maker figures)

| Band | Typical rate | Mass | Source |
|---|---|---|---|
| UHF/VHF | 1.2 to 38.4 kbps (most 9.6 kbps) | 7.5 g to 140 g | [NASA SST ch. 9](https://www.nasa.gov/smallsat-institute/sst-soa/soa-communications/) |
| S-band | 1 to 20 Mbps | 70 g to 405 g | same |
| X-band | 50 Mbps to 2.5 Gbps | 130 g to 1,600 g | same |
| Ka/K-band | 25 Mbps to 2 Gbps | 300 g to under 5,000 g | same |
| Smallsat to ground station, direct | 3 Mbps or more | - | [NASA SST ch. 11](https://www.nasa.gov/smallsat-institute/sst-soa/ground-data-systems-and-mission-operations/) |

### Ground passes and delay

| Item | Value | Source |
|---|---|---|
| LEO pass | horizon to horizon in less than 10 minutes | [NASA GSFC S-band CubeSat paper, p. 4](https://ntrs.nasa.gov/api/citations/20210022422/downloads/S-band%20Network%20Analysis%20and%20Strategies%20for%20LEO%20Multi-CubeSat%20Science%20Missions_15Oct21c_final.pdf) |
| Real CubeSat contact needs (400 km orbit) | 1 to 6 contacts per day, 6 to 9 min each (Table 1) | same, p. 2 |
| Light delay Earth to Mars | about 4 min (closest) to about 24 min (farthest), one way | [NASA Goddard, 7 things](https://www.nasa.gov/centers-and-facilities/goddard/space-communications-7-things-you-need-to-know/) |
| Light delay during InSight landing | 8 min 7 s | [JPL MarCO](https://www.jpl.nasa.gov/news/press_kits/insight/landing/appendix/mars-cube-one/) |

---

## 5. Instruments

| Instrument (mission) | Type | Mass | Power | Data | Source |
|---|---|---|---|---|---|
| MARCI (MRO) | small colour camera | 0.481 kg | under 5 W | about 6.2 Gb/day for a global map; 1 to 10 km per pixel | [NASA MRO instruments](https://science.nasa.gov/mission/mars-reconnaissance-orbiter/science-instruments/) |
| MultiScape100 CIS (Simera Sense) | CubeSat multispectral camera | 1.2 kg | 5.8 W average | not listed | [satcatalog](https://www.satcatalog.com/component/multiscape100-cis/) (secondary, maker data) |
| CTX (MRO) | context camera | 3 kg | 7 W imaging, 5 W idle | 6 m per pixel from 300 km | [NASA MRO instruments](https://science.nasa.gov/mission/mars-reconnaissance-orbiter/science-instruments/) |
| HiRISE (MRO) | big telescope camera | 65 kg | 60 W | up to 28 Gb per image; 30 to 60 cm pixels | same |
| CRISM (MRO) | imaging spectrometer | 32.92 kg | 44.4 to 47.3 W | 2 to 2.5 Gb per observation; 18.4 m per pixel | same |
| SHARAD (MRO) | ground-penetrating radar | 15 kg | not given | 40 to 90 Gb/day (15% of MRO's data) | same |
| MCS (MRO) | infrared sounder (weather) | 9 kg | 11 W | not given | same |
| MAG (Cassini) | magnetometer | 3.00 kg | 3.10 W | 3.60 kbps | [NASA Cassini MAG](https://science.nasa.gov/mission/cassini/spacecraft/cassini-orbiter/magnetometer/mag-technical-write-up/) |
| MAG (Voyager 1) | magnetometer | 5.6 kg | 2.2 W | 0.12 kbps | [NSSDCA Voyager 1 MAG](https://nssdc.gsfc.nasa.gov/nmc/experiment/display.action?id=1977-084A-05) |
| OLI (Landsat 8) | land imager, 9 bands | not found | not found | 185 km swath; 15 m and 30 m pixels; 5-year design life | [NASA OLI](https://science.nasa.gov/mission/landsat/oli) |
| NIRCam (JWST) | infrared camera | not found | not found | not found | - |

JWST as a whole: about 6,200 kg payload mass (with adaptor), 6.5 m mirror, sunshield 21.197 x 14.162 m, under 50 K. [NASA Webb fact sheet](https://science.nasa.gov/mission/webb/fact-sheet)

---

## 6. Mission costs

| Mission or class | Cost | What it covers | Source |
|---|---|---|---|
| CAPSTONE (12U lunar CubeSat) | $13.7M | build and operate (contract) | [NASA 2019](https://www.nasa.gov/news-release/nasa-funds-cubesat-pathfinder-mission-to-unique-lunar-orbit/) |
| CAPSTONE launch (Electron + Photon) | $9.95M | launch to the Moon | [NASA](https://www.nasa.gov/news-release/nasa-awards-contract-to-launch-cubesat-to-moon-from-virginia/) |
| All NASA CubeSats 2006 to 2023 | over $275M total for 115 CubeSats on 91 missions | slide layout; check | [JPL COMPACT slides 2023, p. 4](https://www.nasa.gov/wp-content/uploads/2023/06/50-2023-04-10-cost-symp-2023-compact-v2.pdf) |
| Astrophysics Pioneers (smallsat) | $20M cap | per mission | [NASA Pioneers](https://science.nasa.gov/astrophysics/programs/astrophysics-pioneers/) |
| SMEX (Small Explorer), 2025 call | $170M cap (FY25 dollars) | phases A to F, launch not included | [NASA SMEX 2025](https://science.nasa.gov/astrophysics/programs/physics-of-the-cosmos/community/2025-astrophysics-small-explorer-announcement-of-opportunity/) |
| Discovery, 2019 call | $495M cap (FY19 dollars) | phases A to D, launch not included; 25% reserve required inside the cap | [NASA Discovery 2019 notice](https://astrobiology.nasa.gov/nai/articles/2017/12/15/nasa-discovery-program-announcement-of-opportunity-long-range-planning-information/) |
| LRO | about $460M | mission | [NSSDCA LRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2009-031A) |
| MRO | about $720M | mission | [NSSDCA MRO](https://nssdc.gsfc.nasa.gov/nmc/spacecraft/display.action?id=2005-029A) |
| Dragonfly (Titan) | $3.4B | life cycle | [GAO-26-108556](https://files.gao.gov/reports/GAO-26-108556/index.html) |
| Roman Space Telescope | $4.316B | life cycle (2021 replan) | same |
| Europa Clipper (flagship) | $5.2B | whole mission, 2015 to 2034 | [JPL Europa Clipper](https://www.jpl.nasa.gov/press-kits/europa-clipper/quick-facts/) |
| JWST (flagship) | $9.66B life cycle; $8.8B development | 2018 replan | [NASA 2018](https://www.nasa.gov/news-release/nasa-completes-webb-telescope-review-commits-to-launch-in-early-2021/) |

### Cost growth

| Item | Value | Source |
|---|---|---|
| JWST | cost "nearly doubled" to $9.7B since 2009; launch delayed over 7 years | [GAO-21-406](https://www.gao.gov/products/gao-21-406) |
| NASA major projects, 2026 | 36 projects; at least $70B life cycle; total overrun grew from $4.4B to nearly $4.7B; total delays 14 years | [GAO-26-108556](https://files.gao.gov/reports/GAO-26-108556/index.html) |
| History | 30 of 53 past major projects stayed under 15% cost growth | [GAO-25-107591](https://www.gao.gov/products/gao-25-107591) |
| Good news example | IMAP launched 3 months early and returned $22.2M of unused reserve | [GAO-26-108556](https://files.gao.gov/reports/GAO-26-108556/index.html) |
| Small overrun example | NISAR: 1-month delay, $11.0M overrun | same |

---

## 7. Why small satellites fail (for random events)

| Finding | Value | Source |
|---|---|---|
| Langer (TU Munich): 178 CubeSats launched to mid-2014 | 18% dead on arrival | [The Space Review, 22 Aug 2016](https://thespacereview.com/article/3047/1) |
| Langer: failures after 30+ days | power systems caused nearly half; then on-board computers and comms | same |
| Langer: failures with no known cause | one third (including dead on arrival) | same |
| Langer: still working after 2 years | about 60% | same |
| Swartwout (Saint Louis Univ.): 244 university smallsats, 2000 to 2015 | about one eighth lost in launch failures | same |
| Swartwout: of those that reached orbit | nearly 30% dead on arrival; another 15% failed early; about one quarter finished the full mission | same |
| Experience matters | flagship universities: about one quarter DOA or early failure. Teams with 3 or fewer satellites: more than three fifths | same |
| Main named causes | electrical power, on-board computers, communications | same |

Note: these are 2014 to 2016 studies. Newer numbers (for example a 2019 study of 855 CubeSats) were behind paywalls or bot walls, so I did not read them.

---

## 8. Sources I could not read

- spacex.com vehicle pages and rideshare page: JavaScript only, no text.
- spacex.com/media/Capabilities&Services.pdf: 404.
- rocketlabcorp.com/launch/electron: 403.
- arianespace.com Ariane 6 page: loads, but no numbers on it.
- Landsat 8 page on eoportal.org: no content came through.
- pluto.jhuapl.edu pages: timed out.
- TU Delft and TUM PDFs of Langer's CubeSat reliability work: connection refused / bot wall.
- Villela et al. 2019 (Hindawi / Wiley): 403.
- NASA SSRI knowledge-base PDF: file too large to fetch.
- web.archive.org: blocked for my fetch tool.

---

## 9. Added 13 Nov: prices and specs read straight from SpaceX and Rocket Lab (in the browser)

### SpaceX Rideshare price calculator (https://rideshare.spacex.com/, default orbit SSO), read 13 Nov 2026
| Payload mass | Estimated price |
|---|---|
| 1 kg, 10 kg, 50 kg | **$0.35M** (minimum price, covers up to 50 kg) |
| 51 kg | $0.36M |
| 100 kg | $0.70M |
| 200 kg | $1.40M |
| 300 kg | $2.10M |
| 500 kg | $3.50M |
| 1,000 kg | $5.82M |
So: **$350k up to 50 kg, then $7,000 per kg**, with a discount at large masses. Only SSO is self-serve; other orbits (MEO, GTO, lunar) need an email to SpaceX. This replaces the Wikipedia figure.

### Falcon 9 (https://www.spacex.com/vehicles/falcon-9/), read 13 Nov 2026
- Payload: **22,800 kg to LEO; 8,300 kg to GTO; 4,020 kg to Mars.**
- Height 70 m, diameter 3.7 m, mass 549,054 kg. Fairing 13.1 m tall, 5.2 m wide.
- No price on the page (price stays from secondary sources).

### Rocket Lab Electron (https://rocketlabcorp.com/launch/electron/), read 13 Nov 2026
- **300 kg to LEO.** 18 m tall, 1.2 m wide, 13,000 kg wet mass, 2 stages + Kick Stage.
- 99 launches to date; 272+ satellites deployed; 3 launch pads.
- Engines: first stage Isp 311 s, second stage Isp 343 s.
- No price on the page (stays ~$7.5M, secondary).

### Villela et al. 2019, "Towards the Thousandth CubeSat: A Statistical Overview" (read 13 Nov in the browser; open access)
https://onlinelibrary.wiley.com/doi/10.1155/2019/5063145 — Int. J. Aerospace Engineering, 2019, 5063145.
- **855 CubeSats launched by 31 May 2018**, from 58 countries.
- Uses: Earth remote sensing about **45%**; technology demonstration also large.
- Sizes: **3U about 64%, 1U 18%, 6U about 4%.**
- **Success rate about 75%** (excluding launch failures). "Success" = survived deployment and commissioning, i.e. did not "die as an infant".
- **About 20% of failures happen during launch or deployment**, not the CubeSat's fault.
- Success rate rises over time; launch failures fall; early-life ("infant") failures stayed about constant.
