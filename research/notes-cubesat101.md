# Notes: NASA "CubeSat 101: Basic Concepts and Processes for First-Time CubeSat Developers"

Source: https://www3.nasa.gov/sites/default/files/atoms/files/nasa_csli_cubesat_101_508.pdf

## How I read it

- WebFetch could not turn the PDF into text, but it saved the PDF file locally.
- I extracted the text with `pdftotext` and read all 96 PDF pages.
- I did not look at any images. Figure captions only.
- Page references below use two numbers: **p. X** is the page number printed on the page, and **PDF Y** is the page in the PDF file. For the body text, PDF = printed + 8.
- The document is "Revision Dated October 2017" (PDF 1). It is a NASA CubeSat Launch Initiative (CSLI) guide, written by Cal Poly. Document number NP-2017-10-2470-HQ (PDF 96).

## The big honest warning first

This guide is about the **process**: how to get a CubeSat selected, licensed, tested and launched. It is **not** a parts catalogue.

It does **not** give any of these. I searched the full text for them:

- No mass or size limits for 6U or 12U. It only names them.
- No masses, power figures, costs or data rates for any subsystem (solar panels, batteries, radios, computers, ADCS, propulsion).
- No orbit altitudes and no orbital lifetime numbers.
- No "25-year rule". The words "25 year" and "lifetime" do not appear.
- No statistics on how often CubeSats fail.

We need other sources for those (for example the CubeSat Design Specification at cubesat.org, which this guide points to on p. 4 / PDF 12, and NASA's Small Spacecraft State of the Art report).

---

## 1. CubeSat sizes

| Item | Value | Page |
|---|---|---|
| "Small satellite" | any satellite under 300 kg (1,100 lb) | p. 4 / PDF 12 |
| 1U | a 10 cm cube, mass about 1 to 1.33 kg | p. 4 / PDF 12 |
| 1U standard dimensions | 10 cm x 10 cm x 11 cm | Fig. 2, p. 4 / PDF 12 |
| 3U standard dimensions | 10 cm x 10 cm x 34 cm | Fig. 2, p. 4 / PDF 12 |
| Popular larger sizes | 1.5U, 2U, 3U, 6U, 12U | p. 4 / PDF 12 |
| 6U | born in 2014; "essentially the same as two 3Us side-by-side", twice as wide | p. 6 / PDF 14 |
| Protrusions allowed by the CDS | up to 6.5 mm from the surface | p. 16 / PDF 24 |

### Acceptance checklist limits (Appendix C.6, checklist revision dated 02/20/2014)

These are the clearest size and mass numbers in the guide. The text extraction lost some symbols. "±" showed as an unknown character, and the symbol before "6.5 mm" on the RBF pin line was lost (probably "≤"). Check the PDF page by eye before quoting these in the game.

| Size | Max mass | Width | Length (Z axis) | Page |
|---|---|---|---|---|
| 1U | < 1.33 kg | 100 ± 0.1 mm | 113.5 ± 0.1 mm | p. 79 / PDF 87 |
| 1.5U | < 2.00 kg | 100 ± 0.1 mm | 170.2 ± 0.1 mm | p. 80 / PDF 88 |
| 2U | < 2.66 kg | 100 ± 0.1 mm | 227.0 ± 0.2 mm | p. 81 / PDF 89 |
| 3U | < 4.00 kg | 100 ± 0.1 mm | 340.5 ± 0.3 mm | p. 82 / PDF 90 |
| 3U+ | < 4.00 kg | 100 ± 0.1 mm | 340.5 ± 0.3 mm, plus an extra volume of 36 mm length and 64 mm diameter | p. 83 / PDF 91 |

- Each checklist also lists 6.5 mm for the +Z and -Z standoffs and for protrusions. The RBF pin line also reads 6.5 mm (same pages).
- There is **no** 6U or 12U checklist.

---

## 2. Subsystems: what the guide says (no numbers)

The guide names subsystems and gives design advice. It never gives masses, powers, costs or data rates for them.

**Structure**
- Example structure material: Aluminum 6061-T6 (example ODAR, p. 70 / PDF 78).
- Use low melting point materials, "aluminum and steel as opposed to tantalum, titanium, or tungsten". Parts that survive reentry are a danger to people, and they can lead to a licence condition to buy insurance (p. 54 / PDF 62).
- Do not design right to the edge of the size envelope. "If your CubeSat doesn't fit, it doesn't fly" (p. 16 / PDF 24).
- Put important parts near the outside so repairs do not force a retest (p. 16 / PDF 24).

**Power (solar and batteries)**
- Many CubeSats use deployable solar panels to get more sunlight (p. 16 / PDF 24).
- ChargerSat-1: deployable solar panels "nearly double the power input" (caption, PDF 6). No number in watts.
- Use UL-listed batteries. Unlisted or home-made batteries need extra testing (p. 16 / PDF 24).
- Example ODAR: lithium-ion batteries with over-charge and over-current protection (p. 70 / PDF 78).
- The battery report needs: dimensions, UL number, mass, cell count and wiring, charge and discharge data, a short circuit test, and a safety circuit diagram (p. 57 / PDF 65).

**Communications**
- "Virtually all CubeSats use some form of deployable antenna" (p. 16 / PDF 24).
- Antennas and solar panels are held down by a burn wire (fishing line around a resistor). Advice: use two burn wires, because the line can come loose during vibration or launch (p. 16 / PDF 24).
- Bands named: the 437 MHz (70 cm) band has many CubeSat beacons. The guide also names a 140 MHz (2 m) band for NOAA weather satellites (p. 23 / PDF 31). These are as written in the guide.
- A primary and a secondary radio are expected, "e.g., 70 cm and S-Band" (transmitter survey, p. 72 / PDF 80).
- Example ODAR: a UHF beacon, plus a "high-speed radio" with a ceramic patch antenna (p. 70 / PDF 78).
- **No data rates are given anywhere.**
- Amateur-licensed satellites may not encrypt anything (p. 45 / PDF 53).
- Experimental licences: the satellite must be able to stop transmitting, and may have to stay below power limits (p. 47-48 / PDF 55-56).

**Ground station**
- At minimum you need a radio and an antenna. Most teams use amateur radio parts (p. 22 / PDF 30).
- A TNC packs data into AX.25 packets (p. 22 / PDF 30).
- Cheap software-defined radios (RTL2832, FunCube) are good for practice (p. 22 / PDF 30).
- "Launching with an inadequate ground station is a mission killer" (p. 22 / PDF 30).

**Onboard computer**
- Only named indirectly: a "C&DH Board" row in the ODAR component template, next to the payload, comm and battery boards (p. 71 / PDF 79).
- Safety parts: a Remove Before Flight (RBF) pin, separation switches on the rails, and timers. A timer does not count as an independent inhibit (p. 58 / PDF 66).

**Attitude control (ADCS)**
- ADCS is "a critical system for mission success". You need it to point solar panels at the Sun or a camera at Earth (p. 17 / PDF 25).
- Examples of methods in the captions:
  - gravity gradient (passive), ChargerSat-1 (PDF 6);
  - passive magnetic stabilisation, BisonSat (p. 47 / PDF 55);
  - control moment gyroscopes for three-axis control, SwampSat (p. 42 / PDF 50);
  - a "Stellar Gyroscope" that uses photos to measure rotation, KySat-2 (p. 43 / PDF 51).
- Some CubeSats carry GPS receivers. This helps identify them after launch (p. 30 / PDF 38).

**Propulsion**
- Propulsion may make the launch provider nervous. Some refuse to carry CubeSats with it, so finding a ride takes longer (p. 16 / PDF 24).
- The example compliance letter says the CubeSat "shall not contain" propulsion systems, pressure vessels or explosive devices (p. 77 / PDF 85).
- The CDS prohibits pyrotechnics (p. 16 / PDF 24).

**Instruments (payloads) seen in the examples**
- A camera for Earth photos (STMSat-1, p. 17 / PDF 25). BisonSat aims for visible imagery at 100 m resolution or better (p. 47 / PDF 55).
- An X-ray detector, 30-50 keV (CXBN, p. 50 / PDF 58).
- A solar X-ray spectrometer (MinXSS, p. 30 / PDF 38).
- A sub-millimetre radiometer for cloud ice at 5-15 km altitude (IceCube, p. 31 / PDF 39).
- A solar sail of 32 square metres on a 3U (LightSail, p. 13 / PDF 21).
- A voice synthesizer (TJ3Sat, p. 63 / PDF 71).
- 104 "ChipSats" deployed from one CubeSat (KickSat, p. 13 / PDF 21).

**Flight heritage**
- Choose major parts (batteries, antennas, ADCS) that have flown before. This "reduces the risk of failure" (p. 16 / PDF 24).

---

## 3. Orbits, lifetime and deorbit

- **No altitudes, no lifetimes and no 25-year rule in this document.**
- The ODAR (Orbital Debris Assessment Report) must show three things: the CubeSat is no danger to other spacecraft, it "will deorbit in a reasonable amount of time", and no large piece survives reentry (p. 54 / PDF 62).
- Without an approved ODAR there are no FCC or NOAA licences, and no flight (p. 55 / PDF 63).
- NASA's Debris Assessment Software (DAS) can do the analysis (p. 55 / PDF 63).
- Reference standards listed: NASA-STD-8719.14A and NPR 8715.6A (orbital debris) (p. 84 / PDF 92).
- A flexible orbit requirement means an easier match to a launch and a shorter wait (p. 9 / PDF 17; Free Advice, p. 11 / PDF 19).
- $300,000 is "typically enough to launch a 3U into low-Earth orbit" (p. 11 / PDF 19).
- Example two-line element set (TLE) for CXBN-2 shows inclination 51.6386 and mean motion 15.60423680 (p. 29 / PDF 37). These are raw TLE fields. The guide does not explain them.
- Mission operations: "variable, up to 20 years" (p. 10 / PDF 18).

---

## 4. Launch: how CubeSats ride along

**Dispensers**
- The dispenser attaches to the rocket, protects the CubeSat, and releases it at the right time (p. 4 / PDF 12).
- P-POD (Poly-Picosatellite Orbital Deployer), made by Cal Poly, was the first dispenser. It holds up to three Us, for example three 1Us, two 1.5Us or one 3U. The rocket sends a signal, the door opens, and the CubeSats are pushed out (p. 5 / PDF 13).
- 6U dispensers mostly allow any mix, for example one 6U, six 1Us or two 3Us (p. 6 / PDF 14).
- You usually do not choose the dispenser. Whoever pays for the launch does (p. 5 / PDF 13).
- NPSCul-Lite holds eight 3U P-PODs, mounted on an Aft Bulkhead Carrier plate (Fig. 5, p. 7 / PDF 15).

**Rideshare as a secondary payload**
- The rocket must have spare performance, be going to your orbit, and be able to take dispensers (p. 8 / PDF 16).
- US rockets that had flown CSLI CubeSats by 2017: Super Strypi, Minotaur I, Minotaur IV, Taurus XL, Delta II, Antares, Falcon 9, Atlas V (Fig. 7, p. 8 / PDF 16).
- Planned but not yet flown with CubeSats in 2017: Electron, "Falcon 9 Heavy", LauncherOne, SLS (Fig. 7, p. 8 / PDF 16).
- Fig. 7 also shows heights of 17 m and 58.3 m. The text does not say which rocket each height belongs to.
- Examples of how many CubeSats fly at once:
  - five on ELaNa-III (PDF 9);
  - eleven on a Minotaur I, ELaNa IV (p. 33 / PDF 41);
  - thirteen in NRO's GRACE carrier, four of them CSLI (p. 14 / PDF 22).
- CubeSats cannot change the launch date. "If your CubeSat is not delivered in time, the LV will definitely leave without your CubeSat onboard" (p. 28 / PDF 36).
- Day-of-launch scrubs because of weather are common (p. 28 / PDF 36).

**Five "mission models" (Chapter 3, p. 31-38 / PDF 39-46)**
1. NASA-procured launch vehicle (p. 32 / PDF 40).
2. Operationally Responsive Space (ORS) rideshare, US Department of Defense (p. 34 / PDF 42).
3. National Reconnaissance Office (NRO) rideshare, with biweekly tag-up calls (p. 35-36 / PDF 43-44).
4. Commercial launch bought through a third-party broker (p. 37 / PDF 45).
5. ISS deployment (p. 38 / PDF 46).

**ISS deployment**
- CubeSats go into dispensers on the ground and ride up inside a pressurised cargo ship (Dragon, Cygnus). They are carried into the ISS by hand, and astronauts deploy them "typically 1-3 months after arrival" (p. 38 / PDF 46).
- In 2017 NanoRacks was "the only commercial organization" able to deploy CubeSats from the ISS (p. 38 / PDF 46).
- Chasqui 1 (1U) was thrown by hand by a cosmonaut during a spacewalk in 2014. The guide calls this "extremely uncommon" (p. 7 / PDF 15).

---

## 5. Licensing

**Radio (RF) licence**
- US government satellites are licensed by the NTIA. Everyone else in the US goes through the FCC (p. 20 / PDF 28).
- Four licence types (p. 44 / PDF 52):
  - **Amateur (FCC Part 97):** the hardest to qualify for. No government or commercial involvement at all, so a government grant disqualifies you. No encryption. Every operator needs an amateur licence (p. 45 / PDF 53).
  - **Experimental (FCC Part 5):** the usual licence for universities and CSLI teams (p. 47 / PDF 55).
  - **Commercial (FCC Part 25):** not covered by the guide (p. 50 / PDF 58).
  - **Government (NTIA):** handled through the agency's spectrum office (p. 50-51 / PDF 58-59).
- IARU frequency coordination is needed for any use of amateur-satellite bands. The IARU is run by volunteers who meet only periodically, so it can be slow (p. 45-46 / PDF 53-54).
- ITU paperwork: a "SpaceCap" file, and an ITU Cost Recovery letter. Projects pay the fees for international coordination filings (p. 46 / PDF 54; p. 48 / PDF 56).

**Imaging licence (NOAA)**
- Any non-government US CubeSat with an imager must contact NOAA's CRSRA. NOAA alone decides if a licence is needed: "always assume a license is needed" (p. 41 / PDF 49; p. 51 / PDF 59).
- The FCC will not finish the radio licence until it sees the NOAA result (p. 21 / PDF 29).
- Imaging anything other than Earth (other CubeSats, the rocket stage) needs a Non-Earth Imaging (NEI) waiver. This "can add a significant amount of time". Changing the application restarts the process from the beginning (p. 52 / PDF 60).
- After launch: audits and inspections of the ground station (p. 52 / PDF 60).
- If licences are not done before integration into the dispenser, "your CubeSat will not fly on that mission" (p. 52 / PDF 60).

**A real near-miss story (p. 21 / PDF 29)**
- A CubeSat was already on the rocket without its FCC licence.
- The integrator planned to disable its release mechanism.
- The licence arrived just in time.

---

## 6. Schedule from idea to launch

- "As little as 9 months" to design, build, test and deliver, but "typically 18 to 24 months" (p. 9 / PDF 17).
- After delivery, the wait for launch is "a few months to a few years" (p. 9 / PDF 17).
- The rocket needs the CubeSat 4 weeks to 6 months before launch (p. 9 / PDF 17).

**Phases and typical durations (p. 9-10 / PDF 17-18; TOC PDF 5-6)**

| # | Phase | Duration |
|---|---|---|
| 1 | Concept development | 1-6 months |
| 2 | Securing funding | 1-12 months |
| 3 | Merit and feasibility reviews | 1-2 months |
| 4 | CubeSat design | 1-6 months |
| 5 | Proposal to CSLI | 3-4 months |
| 6 | Selection and manifesting | 1-36 months |
| 7 | Mission coordination | 9-18 months |
| 8 | Licensing | 4-6 months |
| 9 | Flight documents | 10-12 months |
| 10 | Ground station build and test | 2-12 months |
| 11 | Hardware build and test | 2-12 months |
| 12 | Mission Readiness Review | half a day |
| 13 | CubeSat-to-dispenser integration | 2 days (TOC and section heading); the list on p. 10 says 1 day |
| 14 | Dispenser-to-rocket integration | 1 day |
| 15 | Launch | 1 day |
| 16 | Mission operations | variable, up to 20 years |

**Other timing numbers**
- The CSLI call opens in early August. Proposals are due in November, usually within 4 months (p. 3 / PDF 11; p. 17 / PDF 25).
- The priority list comes out 12 to 16 weeks after the deadline (p. 18 / PDF 26).
- Mission coordination starts about 18 months before launch (p. 19 / PDF 27).
- Apply for licences within 30 days of being manifested (p. 20 / PDF 28).
- The FCC needs at least 90 days from receiving the application (p. 49 / PDF 57; p. 50 / PDF 58).
- Amateur prelaunch notice: no later than 30 days after manifest. If the schedule is short: no later than 90 days before integration (p. 46 / PDF 54).
- Experimental licence form: STA for experiments under six months, Form 442 for longer ones. The source says "Form 422" once and "Form 442" elsewhere, so it is a typo (p. 47 / PDF 55; p. 50 / PDF 58).
- NOAA, Earth-only imager: about 120 days after the application (p. 51 / PDF 59).
- The first flight documents are due about 10 months before delivery (p. 53 / PDF 61).
- Testing and all documents must be done at least 1 month before the readiness review. The review template arrives at least 1 month before, and the draft is due 2 weeks or more before (p. 25 / PDF 33).
- Rocket integration happens 2 weeks to 4 months before launch (p. 28 / PDF 36).
- The safety package (MSPSP) is due at least 45 days before arrival at the range (p. 64 / PDF 72).
- After launch, rough TLEs take a couple of days up to a week or so. It can take several weeks to know which object is yours (p. 30 / PDF 38).

**Example first hours in orbit (example ODAR, p. 70 / PDF 78)**
- 30 minutes after release: antennas deploy.
- 45 minutes: the UHF beacon turns on.
- First few passes: checkout.
- About 4 days after launch: payload tests start. They continue "for at least 1 year".
- The example compliance letter also says there are no ground-commanded transmissions before 45 minutes after deployment (p. 78 / PDF 86).

---

## 7. Costs

- "There isn't a standard price tag" (p. 12 / PDF 20).
- Cost depends on mission complexity, team experience, project length and special hardware (p. 12 / PDF 20).
- Four cost categories: Materials, Labor, Environmental Testing, Travel (Fig. 9, p. 12 / PDF 20).
- CSLI pays the launch "up to $300,000, typically enough to launch a 3U into low-Earth orbit" (p. 11 / PDF 19).
- CSLI covers the dispenser, the integration services and the launch itself (p. 14 / PDF 22).
- The team pays everything else: build, tests, ground station, operations and travel (p. 11 / PDF 19).
- Keep reserves of at least 10% (p. 13 / PDF 21).
- A team that misses delivery may have to repay NASA's integration and launch costs under the CRADA contract (p. 11-12 / PDF 19-20).
- Running out of money can lose the launch, and can even get other CubeSats on the same launch removed (p. 11 / PDF 19).
- Crowdfunding works. LightSail-2 raised over $1.24 million on Kickstarter (p. 13 / PDF 21). KickSat had over 300 backers (p. 13 / PDF 21).
- Technology demonstration funding: a JPL team on a "$100 million satellite" may pay for a CubeSat to test a new part first (p. 13 / PDF 21).
- "It's cheaper to build two satellites at once" than one now and one later. Ideal set: an engineering test unit (ETU), a FlatSat, and two flight units (p. 23 / PDF 31).
- Test facilities cost money. Teams on the same launch can share a test setup (p. 61 / PDF 69).
- Travel is often forgotten. At least one review and the delivery need a trip (p. 13 / PDF 21). The readiness review must be in person (p. 25 / PDF 33).

---

## 8. Reviews and paperwork (mission phases)

**Reviews**
- Merit review: is the science, technology or education worth flying, and does it support the NASA Strategic Plan? (p. 14 / PDF 22)
- Feasibility review: can this team really do it, on time and on budget? (p. 15 / PDF 23)
- Reviewers must not be on the team (p. 14 / PDF 22).
- "Keys to CSLI Selection": adequate funding, great merit and feasibility reviews, and clear benefit to NASA (p. 11 / PDF 19).
- Choosing more than one focus area (science, technology, education) means every one is judged equally (p. 17-18 / PDF 25-26).
- Mission Readiness Review (MRR): half a day, in person, after all testing and documents are done (p. 25 / PDF 33).
- A "CubeSat Interface Review (CIR)" is mentioned in the ODAR template (p. 69 / PDF 77).

**Flight certification documents (11 items, p. 54 / PDF 62)**
1. ODAR
2. Transmitter survey
3. Materials list
4. Mass properties report
5. Battery report
6. Dimensional checks
7. Electrical report
8. Venting analysis
9. Test procedures and reports
10. Compliance letter
11. Safety package inputs

**Tests (p. 24 / PDF 32; p. 59-63 / PDF 67-71)**
- Vibration: "required for all launches".
- Shock: not always required.
- Thermal vacuum bakeout: "required on almost all missions".
- Thermal vacuum cycling: optional, but a good idea.
- Sometimes EMI/EMC tests and static load tests.
- Day In The Life (DITL) test: checks the timers and inhibits.
- After the DITL test you may not change any code. After the vibration test you may not touch the hardware. Either change means a retest (p. 60-61 / PDF 68-69).

**Data on CSLI missions**
- "About half" of CSLI missions do science, most often space weather and Earth science (p. 3 / PDF 11).
- "Sixty-six percent" do technology development or demos (p. 3 / PDF 11). These overlap, so they add up to more than 100%.

---

## 9. Common reasons CubeSats fail or do not fly (from the guide; no statistics given)

| Reason | Page |
|---|---|
| Runs out of money, so the launch is lost | p. 11 / PDF 19 |
| Not delivered on time: the rocket leaves without it | p. 28 / PDF 36 |
| Licences missing at integration, so it is demanifested | p. 20 / PDF 28; p. 52 / PDF 60 |
| Final mass outside the stated tolerance, so it may be demanifested | p. 56 / PDF 64 |
| Does not fit the dispenser: "it doesn't fly" | p. 16 / PDF 24 |
| "Almost certain that something will break" in vibration or shock testing | p. 16 / PDF 24 |
| Burn wire line comes loose and a deployable opens early | p. 16 / PDF 24 |
| Untested parts with no flight heritage carry a higher risk of failure | p. 16 / PDF 24 |
| Inadequate ground station: "a mission killer" | p. 22 / PDF 30 |
| Knowledge lost when students graduate | p. 24 / PDF 32 |
| Proposal not compliant, so it is removed and must wait for next year's call | p. 17 / PDF 25 |
| Changes after a verification test, so the test must be redone | p. 60-61 / PDF 68-69 |
| Hard to find which tracked object is yours after launch | p. 30 / PDF 38 |
| Launch failures happen, so building two flight units helps | p. 23 / PDF 31 |
| Boards that work alone may fail when joined together | p. 25 / PDF 33 |
| Outgassing from materials can coat sensitive parts | p. 56 / PDF 64 |
| Trapped air with no venting can burst the structure during ascent | p. 58 / PDF 66 |

---

## 10. Game mechanics this suggests

1. **Size picker with real mass caps.** 1U < 1.33 kg, 1.5U < 2.00 kg, 2U < 2.66 kg, 3U < 4.00 kg (p. 79-82 / PDF 87-90). Going over the cap blocks launch. (6U and 12U limits need another source.)
2. **Dispenser packing puzzle.** A P-POD holds 3U in any mix, and a 6U dispenser holds 6U in any mix (p. 5-6 / PDF 13-14). A team of up to 4 players could share one dispenser on a rideshare.
3. **Launch route cards.** Pick one of the 5 mission models (Ch. 3). The ISS route adds a 1-3 month wait after arrival (p. 38 / PDF 46). A flexible orbit shortens the wait (p. 9 / PDF 17).
4. **Budget with a reserve.** Launch is free up to $300,000 if "selected" (p. 11 / PDF 19). Build costs come from four categories (Fig. 9). Keeping a 10% reserve (p. 13 / PDF 21) protects against random events.
5. **Timeline mode.** Phases with real month ranges (p. 9-10 / PDF 17-18). The rocket does not wait: a late CubeSat misses the launch (p. 28 / PDF 36).
6. **Paperwork side quest.** Adding a camera triggers a NOAA licence of about 120 days (p. 51 / PDF 59). The radio needs an FCC licence of at least 90 days (p. 49 / PDF 57). Pointing the camera at anything but Earth needs an NEI waiver, which restarts the clock (p. 52 / PDF 60).
7. **Radio band choice.** An amateur band means no encryption, open data and no government money (p. 45 / PDF 53). Experimental is the default (p. 47 / PDF 55).
8. **Test gauntlet.** The vibration test can break parts (p. 16 / PDF 24). Rewards for:
   - a second burn wire;
   - parts placed on the outside, so repairs are cheaper;
   - flight-heritage parts.

   Changing code after the DITL test forces a retest (p. 60 / PDF 68).
9. **Optional spare units.** Buy an ETU, a FlatSat or a second flight unit: more cost, less risk (p. 23 / PDF 31).
10. **Propulsion trade-off.** Better mission ability, but fewer rockets will take you, so a longer wait (p. 16 / PDF 24).
11. **Material choice and reentry.** Titanium or tungsten parts may survive reentry, which fails the debris check or needs insurance. Aluminium is safe (p. 54 / PDF 62).
12. **Deployment sequence animation.** Separation switches release, then antennas deploy at 30 min, then the beacon starts at 45 min (p. 70 / PDF 78; p. 78 / PDF 86). It is a nice tense moment for the player.
13. **"Which dot is yours?" mini-game.** After launch, find your CubeSat among many tracked objects in a few days to weeks (p. 30 / PDF 38). A GPS receiver makes it easier (p. 30 / PDF 38).
14. **Ground station quality slider.** A poor ground station means few or no contacts (p. 22 / PDF 30).
15. **Team events.** "Senior student graduates", so knowledge is lost unless the team kept records (p. 24 / PDF 32).
16. **Debrief screen.** Map each failure to a plain sentence from the table in section 9.

---

## Cautions

- **The document is from 2017.** Some facts are out of date:
  - the rocket list (Fig. 7);
  - "NanoRacks is the only" ISS deployer;
  - JSpOC and space-track wording;
  - the IRC channel on freenode;
  - the $300,000 cap.

  Label these as "2017" in the game, or check current sources.
- **It is US-centric.** FCC, NOAA and NTIA are US agencies. Non-US teams use their own national regulator (p. 43 / PDF 51).
- **Text extraction lost some symbols** (± and probably ≤) in the checklists, and the checklist layout came out jumbled. Check those pages by eye before quoting exact tolerances.
- **The source contradicts itself in one place.** Integration is "2 days" in the TOC and the section heading, but "1 day" on p. 10.
- **Missing data.** It has no data for 6U or 12U limits, subsystem specs, data rates, altitudes, orbital lifetime or the 25-year rule. Do not quote this guide for those.
- **Image rights.** NASA text is generally free to use, but many photos are credited to universities and companies (Cal Poly, ULA, The Planetary Society). Do not copy the photos. Do not use the NASA logo or imply NASA endorsement.
