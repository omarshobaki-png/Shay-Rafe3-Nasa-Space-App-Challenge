# Pitch training (Birzeit, 2026): judging, rules, and what it means for us

Source: *Pitching to the Jury*, NASA Space Apps 2026 pitch training, Birzeit University (Atef Shkokani),
31 slides, read 14 Nov 2026. The deck's rules come from the **2025** guides; the 2026 Submission &
Judging guides were due on 13 Nov at spaceappschallenge.org/resources. **Re-check them before submitting.**

## ⏰ Our real deadlines (Ramallah local event, A. M. Qattan Foundation)

| When | What |
|---|---|
| Sat 14 – Sun 15 Nov | Hackathon weekend (48 h) |
| **Sun 15 Nov, 15:15** | **Projects submitted** (the local event's cut-off; plan for this, not 23:59) |
| Sun 15 Nov, 16:15 | Live team pitches: **3 min pitch + 2 min judges' Q&A** |
| Sun 15 Nov, 19:00 | Awards and Global Nominees |
| Sun 15 Nov, 23:59 | Global submission portal closes |
| Dec 2026 / Jan 2027 | Global Nominees/Finalists, then 10 Global Winners |

## How judges score: 5 criteria, 1–5 each, no weighting

| Criterion | The question | What a 5 looks like | Our status |
|---|---|---|---|
| **Impact** | How big is the problem, and how many people does it help or inspire? | A major problem, wide reach, quality beyond expectations | 🟡 We need a person + a number for "students rarely get to try a whole mission" |
| **Creativity** | New idea, or a meaningful improvement on existing ones? | A fresh approach nobody has tried | 🟡 Say "unlike KSP / NASA's Webb game, we…" (whole mission + 4 roles + real NASA numbers + "why it failed") |
| **Validity** | Scientifically sound, feasible, easy to use? | Fully developed, user-friendly, ready for real use | ✅ Real physics, sources in `data.gd`; ⚠️ needs first-timer playtests |
| **Relevance** | Fully answers the challenge, with NASA data at its core? | NASA data central to the result, not decoration | 🟡 DONKI drives a real event; the rest is NASA fact-sheet numbers. Name products exactly (see below) |
| **Presentation** | Clear, engaging, well structured? | Judges grasp problem, method and impact at once | ❌ Not started: no slides, video or project page yet |

Presentation is judged from the demo **and** the project page.

## Hard rules (break one = not eligible for Global Judging)

- Demo: **7 slides max (title included) OR a video of 30 s max**. Over the limit (8 slides, 35 s) = out.
- **Public link, no login, no permission request.** No locked Drive/YouTube links.
- **English**; videos need **English subtitles**.
- The project page takes images only (JPG, PNG, GIF ≤ 10 MB). Host the video and slides elsewhere.
- **2026 requires an AI disclosure** (how AI tools were used). Ours is in the root `README.md`.
- Advice: build the 7 slides first, then record the 30 s video from them. One story, two formats.

## The "Space Apps 7": slide by slide, applied to our game (draft for the team)

The order matches NASA's official 30 s video script: team → challenge & why → title + tagline →
how it works + data → future. Handout: "Space Apps 7 - Student Pitch Template.pptx".

| # | Slide | Scores | Must contain | For Space Mission Designer (team to finalise) |
|---|---|---|---|---|
| 1 | Title & tagline | Presentation | Name + one-line promise (what, for whom); team + members; **exact challenge title**; local event | "Space Mission Designer" · Team Shay Rafe3 · *Space Mission Design Game* · Ramallah. Tagline must be understood in 5 s |
| 2 | Problem through one person | Impact | One real person (name, place, situation); **the number that hurts**; why now; ≤ 2 sentences | A student who has learned orbits and rockets separately but never designed a whole mission. Needs one sourced number (team to find) |
| 3 | Our solution | Creativity, Relevance | What we built in one sentence; the key screen; "unlike X, we…"; which part of the challenge it answers | Key screen: hangar builder with Mission Control lamps. "Unlike single-topic tools, players build, launch, land and get told *why* it failed, as a team of 4" |
| 4 | How it works + NASA data | Relevance, Validity | Pipeline data → method → output; **each NASA dataset by name and ID**; the formula in one line; partner data credited | DONKI GST storms → cruise damage; NASA fact sheets → gravity, sunlight, delay; GMAT Isp 300 s → rocket equation. Formulas: Δm = m(1 − e^(−Δv/(Isp·g0))), power ∝ 1/AU² |
| 5 | Demo | Validity, Presentation | 2–3 real screenshots or a GIF; **public link or QR (no login)**; real NASA data on screen; what works today vs. planned | GitHub Pages link + QR; builder → launch → DONKI storm note → landing → report |
| 6 | Impact | Impact | 2–3 named user groups; how much; the local angle; evidence (test, quote) | Students, teachers/schools, space clubs; Palestinian/Arabic-speaking learners; a playtest quote |
| 7 | Future & team | Validity, Impact | Next 3 steps; **honest limits**; bigger vision; roles + links | Limits: robotic only, 3 destinations, Δv estimates not full GMAT runs. Next: classroom pilot, more events, GMAT trajectories |

### Live pitch timing (3:00 + 2:00 Q&A)
Title 0:15 · Problem 0:30 · Solution 0:25 · How it works 0:35 · Demo 0:40 · Impact 0:20 · Future 0:15.
On the day: one speaker per part, one person drives the demo, **an offline screen recording as backup**,
rehearse 3 times with a timer, deck on a USB stick and in the cloud.

## NASA data, named the way judges want (Relevance)

"We used NASA data" with no names costs points. Use exact names and say what each one does in the game:

| NASA source | Exact name / ID to say | What it does in the game |
|---|---|---|
| DONKI | NASA DONKI (Space Weather Database Of Notifications, Knowledge, Information), **GST** geomagnetic storm records 2024–25, via api.nasa.gov | A real storm (e.g. Kp 9, 10 May 2024) hits the ship in cruise; no shielding → a part is damaged |
| Planetary fact sheets | NASA NSSDCA Planetary Fact Sheets | Gravity (landing, jump height), sunlight (solar power), distance, radio delay |
| MMRTG | NASA MMRTG fact sheet | 110 W / 45 kg nuclear power part |
| Small Spacecraft Technology | NASA *State of the Art of Small Spacecraft Technology* | Solar W/kg and battery Wh/kg |
| Mission instruments | MRO CTX, MRO CRISM, Cassini MAG | Real camera, spectrometer, magnetometer specs |
| GMAT | NASA GMAT defaults (Isp 300 s) | Rocket-equation fuel |
| JPL CMLs | JPL Concept Maturity Levels | Design margins / GO-NO-GO review |

Cheap upgrade from `context/02_NASA_RESOURCES.md` §10: a real NASA photo (LRO, HiRISE, Cassini) as
"the photo your mission took" in the report. Very visible, and it puts NASA data on screen for slide 5.

## Judges' questions: have these ready

Answer in three beats: one-sentence answer → evidence (data, test, number) → back to impact. Max 20 s.

| Criterion | Likely question | Our answer needs |
|---|---|---|
| Impact | Who exactly will use this, and how will it reach them? | A named group (students), a channel (schools, clubs, the free web link), one number |
| Creativity | What already exists, and why is yours different? | KSP (fun, no mission-design trade-offs or NASA sourcing) and NASA's Webb game (one telescope, solo) → our one-line difference |
| Validity | How do you know the output is right? What is real and what is mocked? | Every number has a `src` in `data.gd`; "game rule" items are labelled; a playtest we ran |
| Relevance | Which NASA datasets, and what breaks without them? | The table above; without DONKI there's no real storm; without fact sheets the physics is fake |
| Presentation | Explain your project in one sentence. | The tagline, memorised by everyone on the team |

## 8 mistakes that cost points (check before submitting)
1. Over the limit (8 slides / 35 s). 2. "We used NASA data" with no names. 3. No working demo (mock-ups only).
4. Jargon (pitch to a curious non-specialist). 5. Investor slides (market size earns 0 points).
6. Reading the slides. 7. Locked links. 8. **No AI disclosure.**

## 10 things winning teams do (2023–2025 Global Winners)
Name exact datasets · open with a person or hook · quantify problem and impact · name the users ·
follow the official questions as headings · show the method · ship something that works (live URL +
30 s demo + screenshots) · concrete next steps · make it local and specific · be honest about limits.

## What this means for our plan (priority order)

1. **Deadline is 15:15 Sunday**, not 23:59. Everything below must be finished before then.
2. **Working public demo:** re-export the web build with multiplayer and deploy the relay server; check
   the GitHub Pages link opens with no login. The demo is judged on Validity and Presentation.
3. **Slides (≤ 7) + 30 s video with English subtitles**, from one script. Public links.
4. **Project page:** answer the official questions as headings, screenshots ≤ 10 MB, NASA data list
   with exact names, AI disclosure.
5. **Find real numbers** for slide 2 (problem) and slide 6 (impact). Don't invent them.
6. **First-timer playtest** before Sunday: it's evidence for Validity and Impact (a quote).
7. Optional, high value for Relevance: real NASA mission photo in the report.
