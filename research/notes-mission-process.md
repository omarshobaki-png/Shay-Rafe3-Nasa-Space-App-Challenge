# Notes: how a real science mission is designed

Two sources, read on 2026-11-13. No game code written.

- **[NASA]** "Design and Develop Science Missions". NASA Small Spacecraft Systems Virtual Institute, Systems Engineering Webinar Series. Julie Levri, 26 March 2025. A 25-slide deck.
  URL: https://www.nasa.gov/wp-content/uploads/2025/04/250323-design-and-develop-science-mission.pdf?emrc=a454cf
  Page numbers below = PDF page = slide number.
- **[CML]** Wessen, Borden, Ziemer, Kwok (JPL). "Space Mission Concept Development Using Concept Maturity Levels". AIAA SPACE 2013, San Diego, 10-12 Sept 2013. 17 pages.
  Record page: https://dataverse.jpl.nasa.gov/dataset.xhtml?persistentId=hdl:2014/44299
  PDF read from: https://dataverse.jpl.nasa.gov/api/access/datafile/50237 (file "13-3547_A1b.pdf", 1.4 MB)

How I read them: WebFetch saved each PDF. I pulled the text out with `pdftotext`. I did not open any images.

**Gap.** The CML matrix (Figures 3-7, pages 5-10) and the CML 4 checklist (Figures 8a-8c, pages 12-14) are pictures inside the PDF. They hold no text. So I could not read the cell contents, and any margin values inside them. Only the captions and body text are covered here.

---

## 1. The big picture: six steps

[NASA p10] shows the whole process as six boxes in a row:

1. Identify need and goals
2. Define concept
3. Define requirements
4. Design
5. Build and verify
6. Implement (= launch and operate)

The deck walks one real example through every box: **BioNutrients-2** (pages 11-23). It is a small yeast experiment on the ISS. Can yeast make nutrients for long trips, such as to Mars? [NASA p11]

### Step 1: need and goals [NASA p12]
- Need: make nutrients in space, fast, safely and reliably, with little mass, power and volume, for long missions.
- Goals: (1) grow the yeast; (2) make beta carotene on the ISS; (3) use less mass and volume than BioNutrients-1.

### Step 2: concept, written as a Concept of Operations (ConOps) [NASA p13]
A ConOps is the story of how the system will be used, usually in time order. NASA's rule book (NPR 7123.1) says it:
- shows the system from the operator's point of view;
- drives the requirements and the architecture;
- is the base for later documents and long-range planning;
- gives the criteria for **validating** the system.

### Step 3: requirements. "Begin with the end in mind" [NASA p15, p18, p19]
Start at the **user**: what does the scientist need at the end? Then work backwards.
[NASA p15] shows the user's steps on the returned samples: delivery, thaw, empty and wash, centrifuge, analyse.

Requirements for BioNutrients-2:
- Science product [NASA p18]: at least 12 replicate samples; at least 30 mL per sample; at least 3 µg beta carotene per mL of returned sample; at least 1 mg dry cell weight per sample; no microbial contamination.
- Resource product [NASA p19], for the same starting sample size as BioNutrients-1: sample container under 250 g; total volume under 300 mL.

Key rule [NASA p19]: **when you write a requirement, also plan how you will verify it**, before you build. Example: "under 250 g" is verified by weighing an empty container.

### Step 4: design [NASA p20-21]
Hardware design, then the experiment design: hydrate and agitate, incubate, freeze. (These slides are mostly pictures.)

### Step 5: build and verify [NASA p22]
Hardware is made and sterilised. Then it is loaded with yeast and growth media, and the assembly is finished.

### Step 6: implement (operations) [NASA p23]
Scientists and engineers sit on console during the experiment, in case the crew has questions or something goes wrong.

---

## 2. The four mission segments [NASA p8, p14]

| Segment | What it is [NASA p8] | BioNutrients-2 example [NASA p14, p17] |
|---|---|---|
| Launch | The launch vehicle and services that put the spacecraft in space. | Flew on NG-18 to the ISS. Soft-stowed, room temperature, protected from oxygen and moisture. |
| Space | The spacecraft and its parts (orbiters, landers, rovers, instruments) that collect data. | Experiment run on the ISS. Samples hydrated, incubated, frozen, sent back to Earth. |
| Ground | Ground stations and mission control. They talk to the spacecraft, receive data and run the mission. | Team watched the start live, then watched temperature from the ground. |
| User | Scientists and the public who use the data for research and education. | Scientists process the frozen samples and publish results. |

---

## 3. What a "requirement" is

Neither source gives a formal definition. What they do show:
- A requirement is a **measurable "shall"** with a number and a limit, e.g. "under 250 g" or "at least 12 samples" [NASA p18-19].
- Each one comes from a goal and, behind that, from what the end user needs [NASA p15, p18].
- Each one needs a **verification method** chosen up front [NASA p19].
- [CML p11] names "Level 1 requirements" and a "Science Traceability Matrix" as must-have items. A concept missing them is not complete, even if it scores 90 % on the checklist.

Working definition for the game (my words, not a quote): *a requirement is a pass/fail rule the mission must meet, with a number, a reason and a test.*

## 4. What a "trade study" is

Neither source uses the phrase "trade study" with a definition. [CML] talks about **trade space** and **trades**:
- CML 3, "Trade Space": explore around the science objectives. Trade the spacecraft, ground system and mission design against each other. See how they change **science return, cost and risk** [CML p2].
- **Science partials**: how science return changes when one parameter changes, e.g. spacecraft mass, data volume or orbital period [CML p3].
- Teams that skipped trade space and jumped to a point design ended up with less science, inefficient spacecraft and ground designs, and a weaker mission overall [CML p3].
- CML 4 adds **subsystem trades** [CML p2].

Working definition for the game (my words): *a trade study compares two or more design options on the same scorecard (science, cost, risk, mass, power) and picks one, writing down why.*

---

## 5. Concept Maturity Levels (CML)

JPL invented CMLs to measure how "done" a mission idea is before formal project work (Phase A/B) [CML p1]. Work on them started in 2008 [CML p1]. The paper covers CML 1-4 in depth; CML 5-6 are already set by NASA proposal rules [CML p1].

### The nine levels [CML p2]
1. **Cocktail Napkin.** The science questions are clear. The kind of observations needed is proposed. There is a rough sketch of the mission and its high-level objectives. What makes it unique is captured.
2. **Initial Feasibility.** The idea is questioned: science, technical and programme. Lower-level objectives are set. Key performance parameters get numbers. Basic first-order sums show if it can work.
3. **Trade Space.** Trades between spacecraft, ground system and mission design, measured by science return, cost and risk.
4. **Point Design.** One specific design and cost is chosen that returns the science. It is defined down to the major subsystems, **with acceptable margins and reserves**. Subsystem trades are done.
5. **Baseline Concept.** Partners, contracts, integration and test, cost and schedule are defined. Enough for a NASA Step 1 proposal, or a Mission Concept Review.
6. **Integrated Concept.** More technical, management and cost detail. Level of a Step 2 Concept Study Report.
7. **Preliminary Implementation Baseline.** System and subsystem requirements, demonstrated margins and reserves, prototypes, tech demos, risk plans.
8. **PDR** (Preliminary Design Review) level.
9. **CDR** (Critical Design Review) level.

### What CML 1 needs [CML p11]
Only four things: (1) the science objective; (2) what is unique about the mission; (3) a rough launch timeframe; (4) a target cost class.

### It is not a straight line [CML p3, Figure 1]
CML 2, 3 and 4 form a **loop**. Teams often go back from point design to trade space to find another way to get the science. The authors call this loop a strength.

### Mission classes [CML p15]
Cost classes named: Explorer, Discovery, New Frontiers, Flagship. (No dollar caps given in either source.)

### The CML Matrix [CML p4]
- 7 columns (CML 1-7) and 24 rows.
- Rows grouped as: Science 2, Technical 13, Management 5, Cost 1, Other 3.
- Groups follow how NASA judges a mission: a **science review** first, then a **TMCO** review (Technical, Management, Cost, Other).
- Science rows cover "why are we doing this?" (objectives) and "what will we produce?" (data products). Science must be in every trade [CML p5, Fig 3 caption].
- Technical rows design the spacecraft and ground system together as one system [CML p8, Fig 4 caption].
- Management rows: missing them can force a full redesign or big cost growth [CML p9, Fig 5 caption].
- Cost row: a cost estimate, its uncertainty, how cost changes across the trade space, and checking the estimate and its **reserve** [CML p10, Fig 6 caption].
- "Other" rows: often left until late, which causes cost growth or makes the mission impossible as planned [CML p10, Fig 7 caption].

### The CML checklists [CML p11, p14]
- Made for CML 2 to 6. None for CML 1 (too free-form) or 7+ (NASA rules take over).
- Three columns: functional area, criteria, status.
- Status colours: **green = done, yellow = in progress, red = not started**.
- A concept is "at" a level when **80 %** of that level's items are green. The 80 % is not magic: 78 % green is probably fine. But 90 % with no Science Traceability Matrix, no Level 1 requirements and no Master Equipment List is not complete. Use judgment.
- Teams never have the time, money or people to fix every red item. Leaders must choose which gaps to fix first.
- Caveats [CML p14]: the checklist measures completeness, not quality. It does not weight items. **Self-assessment is dangerous**; an independent assessor should talk with the team for about half an hour. Self-scores tend to be too optimistic.
- Figure 8b caption [CML p13]: at CML 4 there are **no** requirements for propellant, data storage or attitude-control margins. (So the CML 4 checklist does track some other technical margins, but which ones and what values sit in the image I could not read.)

### Who does what at JPL [CML p15]
- **A-Team** handles CML 1-3: ideas, feasibility, trade space, science traceability. Small team of experts.
- Cost tools match the level. A CML 2 cost tool has large uncertainty, but it should be good enough to tell which cost class a concept is in.
- **Team X** does CML 4 point designs. Created in 1995. Over 1000 studies. A study is usually 3 collaborative sessions over one week. Output: mission design, spacecraft design, cost and risk.

### How CMLs line up with NASA reviews [CML p3-4]
- End of Pre-Phase A: Mission Concept Review (MCR, for assigned projects) or Step 1 proposal (competed).
- Assigned projects should be at CML 5 by MCR. The paper says competed proposals should be at CML 5 by the Baseline Commitment Review (BCR). (This reads oddly next to p2, which ties CML 5 to the Step 1 proposal. Reported as written.)
- Later reviews in the acronym list [CML p16]: SRR, MDR, PMSR, PDR, CDR.

---

## 6. Margins and reserves

**Neither source gives any margin percentage in readable text.**
- [CML p2] says CML 4 needs "acceptable margins and reserves", and CML 7 needs "demonstrated (and acceptable)" margins and reserves.
- [CML p10] says the cost row checks the cost estimate's "level of reserve".
- [CML p13] says propellant, data-storage and attitude-control margins are not required at CML 4.
- [NASA p24] says SLS offers "increased mass margins". No number.
- Any percentages are probably inside the matrix/checklist images (unread) or in other NASA documents.

Next places to look (named by [NASA p2], not read here): NASA Systems Engineering Handbook SP-2016-6105 Rev 2; NPR 7123.1D; NPR 7120.5F; NPR 8705.4B (payload risk classes).

## 7. Cost and schedule numbers

None in dollars in either source. The only schedule-type numbers:
- Team X study: usually 3 sessions over a week [CML p15].
- CML work since 2008 [CML p1]; "over five years" of use [CML p15].
- Team X since 1995; over 1000 studies [CML p15].
- Checklist half-hour independent review talk [CML p14].

## 8. Example missions for scenarios [NASA p24]
- PUNCH: 4 small satellites in low Earth orbit; 3D views of the Sun's corona and how it becomes the solar wind.
- PILOT: 34 satellites in two different orbits; plasma flowing into and out of Earth's magnetosphere.
- Dawn: first spacecraft to orbit two small bodies (Vesta and Ceres).
- Mars moon sampler: return samples from Phobos/Deimos (a New Frontiers-class concept).
NASA science covers four fields: Earth science, heliophysics, planetary science, astrophysics [NASA p5]. These could be the four mission "tracks" in the game.

---

## 9. How a game could use this

**A. CML ladder as the campaign spine.** One mission = climb the ladder, then fly it.

| Game stage | Real source | What the player does |
|---|---|---|
| 0. Pick a need | Need & goals [NASA p10, p12] | Choose a science question from one of 4 fields [NASA p5]. |
| 1. Cocktail Napkin | CML 1 [CML p2, p11] | Fill exactly 4 cards: objective, what's unique, launch year, cost class. Napkin-sketch art style. |
| 2. Initial Feasibility | CML 2 [CML p2] | Quick sums: is mass under the rocket's limit, is power enough, does the data fit the downlink? Red/green lights. |
| 3. Trade Space | CML 3 [CML p2, p3] | Compare 2-3 options (orbit, rocket, instrument) side by side on science, cost, risk. Show a "science partial" graph: drag mass or orbit, watch science change. |
| 4. Point Design | CML 4 [CML p2] | Lock one design down to subsystems. Must keep margins (values to be sourced elsewhere). |
| 5. Gate review | Checklist [CML p11, p14] | An NPC review board scores a G/Y/R checklist. Pass at 80 % green, but 3 items are must-haves (science traceability, top requirements, equipment list). |
| 6. Build & verify | [NASA p10, p19, p22] | Each requirement is tested by its chosen method. Failures name the requirement. |
| 7. Launch & operate | Implement [NASA p10, p23] | Simulate launch, then operations; random anomalies the ground team must handle. |
| 8. Users get data | User segment [NASA p8, p15] | Score = did the scientist get what the requirements promised? |

**B. Four segments = four players.** A team of up to 4 maps one-to-one onto the four segments [NASA p8]: Launch, Space, Ground, User. Solo play: the player switches tabs.

**C. "Begin with the end in mind."** Make the player start from the User screen: "what does the scientist need?". Requirements are derived from that [NASA p15-19].

**D. Requirement cards with a test.** Every requirement card has a number, a reason (which goal) and a verification method, set before building [NASA p19]. The debrief says which card failed and why.

**E. Loop back is allowed.** Going from Point Design back to Trade Space costs nothing or little. The paper calls the loop a strength [CML p3]. Skipping Trade Space gives a weaker mission [CML p3]: the game can show a "you never compared options" note.

**F. Cost uncertainty shrinks with maturity.** Show cost as a wide range at CML 2 and a narrow one at CML 4 [CML p15].

**G. Limited study points.** Give the team a small budget of time/money/people to fix red checklist items. They cannot fix all [CML p11].

**H. Self-score vs. honest review.** Let players rate their own design first, then show the review board's score. Teach that self-scores run high [CML p14].

**I. Two-step judging.** Science review first, then TMCO (Technical, Management, Cost, Other) [CML p4]. Use these as the final report card headings.

**J. Tutorial mission.** BioNutrients-2 is small and has real numbers (12 samples, 30 mL, under 250 g, under 300 mL) [NASA p18-19]. Good first level.

**K. "Other" surprises.** Late "Other" items cause cost growth [CML p10]. A late event card can model this.

---

## 10. Cautions
- No margin percentages and no dollar costs in either source. Do not put numbers in the game "from these papers".
- CML matrix and checklist cells are images; unread here.
- The CML paper is from 2013 and cites NPR 7120.5E; the NASA deck (2025) lists version F [NASA p2].
- The CML paper is copyright 2013 Caltech. Paraphrase and cite; do not copy the matrix.
- [NASA p24] cites Wikipedia and a Stanford page for some examples. Check facts at the mission's own NASA page before use.
- Do not use NASA logos in the game without checking NASA's media-use rules.

---

## 11. Added 13 Nov: the CML matrix and CML 4 checklist images, read

The images (Figures 3-8c) were read from the saved PDF at native resolution. What they say:

### Margin numbers (CML 4 checklist, Fig. 8b, dated 2013 April 11) [CML p13]
These are JPL's minimum margins at the Point Design stage ("margins defined by DP Section 6.3", i.e. JPL Design Principles):

| Resource | Minimum margin |
|---|---|
| Spacecraft dry mass (mass growth allowance and margin) | **>= 35%** * |
| Power | **>= 35%** * |
| Energy (battery) | **>= 35%** * |
| Flight software (CPU timing and memory) | **>= 100%** |
| Telecom link | **>= 3 dB** (deep space); **>= 6 dB** (proximity links) |
| Propellant, data storage, attitude control | N/A at CML 4 |

\* Footnote, partly cut off in the image: "Margins can be relaxed down to PMSR levels if equivalent of 5…". So 35% is the early-stage figure; later reviews allow less.

Game use: a design "passes" CML 4 only with at least 35% spare mass, power and energy. 3 dB = the signal is twice as strong as the minimum needed; 6 dB = four times.

### CML 4 checklist example [CML p12-14]
- The sample sheet shows green, yellow and red marks. Science data system sized = **red**; data processing approach = yellow; most science and mission items = green.
- One example item: "Launch period is 20 days long" (green).
- Other CML 4 must-haves: preliminary launch vehicle **and a backup**; top risks in a **5 x 5 matrix** (likelihood x consequence) with mitigations; fallback options for every new technology; equipment list (MEL) to assembly level (antenna, propellant tank, star tracker); schedule margin by formula; cost reserve based on known risks.

### The matrix rows, CML 1 → 4 (the game-relevant ones) [CML p5-10]
| Row | CML 1 | CML 2 | CML 3 | CML 4 |
|---|---|---|---|---|
| Science objectives | Described in **one sentence** | Compared with earlier missions and NASA science documents | Linked to measurements; science return as a function of cost, risk | Draft Science Traceability Matrix; **one Baseline and one Threshold** (minimum) science goal; key performance parameters |
| Science data | — | Identify what drives data | Data rates and volume in the trade study | Data system sized |
| Mission | One-sentence unique mission | Key parameters quantified; rough sums; **compare with similar past missions**; rough space environment | Several architectures compared on science, cost, risk; space hazards bounded | Scenarios and timelines; **propellant and delta-v budget**; power, telecom, data approach; descopes and backups |
| Spacecraft | — | Key parts listed; compared with similar spacecraft | What makes each option different; sensitivity studies | Configuration drawings, block diagrams, descope options |
| Instruments | — | Measurement technique in one sentence | Instruments picked against science, cost, risk | Instrument design; requirements traced to Level 1 |
| Ground / operations | — | Ops approach | Ops drivers; flight vs ground trades | Ops architecture from scenarios |
| Risk | — | Identify risks and areas of concern | Compare risks across options; mitigations | Risk drivers in a 5 x 5 matrix |
| Technology | — | Technologies needed to reach TRL 6 by PDR | Compare technologies | Options picked and justified; fallbacks |
| Inheritance | — | Where reused parts come from | Benefits and risks of reuse | Major reused items picked |
| Equipment list | — | — | Mass of major elements | MEL to assembly level |
| Margins | — | **Find high-risk areas that need big margins; assess uncertainty** | Use institutional margins; best and worst cases | Margin policies followed; critical margins estimated |
| Systems engineering | — | First trade-space options | Relative merits of performance, cost, risk; subsystem dependencies | Key science / spacecraft / ground trades done |
| Launch | — | Launch approach and performance | **Trades on candidate rockets: performance and fairing size** | Preliminary rocket and backup |
| Planetary protection | — | Identify the need | Options | Approach defined |
| Testing (V&V) | — | — | Unusual tests identified | How each new function will be verified |
| Cost | — | **Cost range from similar missions; uncertainty** | Cost vs. major drivers | Detailed estimate; reserve from known risks; fits NASA's funding profile |
| Schedule | **Identify time frame** | Launch opportunities; rules of thumb for duration | Schedule risks to science | Top-level Gantt chart |
| NEPA (environment law) | — | Any nuclear or public-safety issue? | Non-nuclear options for nuclear-power missions | Requirements evaluated |
| Launch approval, export | — | — | — | Only from CML 4-5 on |

Management rows (acquisition, partners, organisation, WBS, mission assurance) are mostly CML 3+ paperwork; skipped as not useful for a game.
