extends Node
## All game numbers. Each real number carries its source in `src` or in a comment.
## "game rule" = a number we chose for gameplay, not a NASA fact. "game estimate" = our guess from a real anchor.
## "CHECK" in a trailing comment = a real number written from memory that the fact pass must confirm.

const G0: float = 9.81          # m/s2, standard gravity (used in the rocket equation)
const ISP: float = 300.0        # s, engine efficiency; GMAT's default thruster Isp
const PASS_HOURS: float = 8.0   # game rule: hours of Deep Space Network contact per day
const OPS_COST_PER_YEAR: float = 10.0  # game rule: $M per year to run mission control
const SOLAR_DECAY_PER_YEAR: float = 0.05  # GMAT solar-array default: 5% loss per year
const CRUISE_DV: float = 0.03   # km/s, game rule: fuel every ship needs for course corrections on the way (real missions budget tens of m/s)
const SHADE_ABOVE_WM2: float = 5000.0  # game rule: above this sunlight (3.7x Earth's) a craft needs a sunshade. Mercury 9,083, Venus 2,601 (NASA fact sheets)
const VENUS_TOUCHDOWN: float = 7.5  # m/s, game estimate: the Venera landers dropped their parachutes high up and sank the rest of the way on a drag plate (touchdown speed from secondary sources)  # CHECK
const RTG_LIFE_YEARS: float = 14.0  # NASA MMRTG fact sheet: 14-year design life; half power after that = game rule

## The one margin rule (V5_DESIGN.md section 3). A bar is green only with this much to spare.
## "comms" is a factor (downlink >= 2 x the data = a 3 dB link margin); the others are fractions.
const MARGIN: Dictionary = {"mass": 0.35, "power": 0.35, "battery": 0.35, "fuel": 0.10, "data": 0.20, "comms": 2.0, "budget": 0.25}
## Tooltip-ready: where each margin comes from.
const MARGIN_SRC: Dictionary = {
	"mass": "JPL asks for a 35% margin on a spacecraft's dry mass this early (CML 4 checklist). The game simplifies it: 35% of the rocket's lift stays spare.",
	"power": "JPL's CML 4 checklist asks for a power margin of 35% this early. In the game: make 35% more than the ship uses.",
	"battery": "JPL's CML 4 checklist asks for an energy margin of 35% this early. In the game: store 35% more than the dark hours need.",
	"fuel": "Game rule: carry fuel for 110% of the planned speed change. JPL gives no number this early.",
	"data": "Game rule: keep 20% of the storage spare.",
	"comms": "JPL's CML 4 checklist asks for a 3 dB margin on deep-space radio links (twice the signal power). The game translates it: room to send twice the data.",
	"budget": "NASA's Discovery 2019 call required a 25% cost reserve.",
	"time": "The challenge counts time as development plus operations. Game rule: no reserve is required.",
}

## Development time, game rule: every kind of part must be designed and tested, and nuclear power
## needs a launch safety approval that takes years in reality.
const DEV_BASE_DAYS: float = 200.0
const DEV_DAYS_PER_KIND: float = 30.0
const DEV_NUCLEAR_DAYS: float = 300.0

## Difficulty is the player's choice (Game.difficulty), never the planet's. All game rules. Read with Game.diff(key).
##   events_per_leg   decision events on the way, at the site and after it
##   burn_band        width of the green band of the arrival burn (x)
##   landing_forgive  touchdown speed limit (x); Game.landing_setup() already applies it to "touch"
##   surface_hazards  rocks and craters on the rover's lane (x)
##   drone_rocks      rocks in the ring field (x)
##   budget_slack     budget (x); Game.budget() already applies it
##   over_mult        a resource is OVER above the need plus this many margins (see USE_RULE)
##   storm_strong     chance that a solar storm is the strongest real one of the year
const DIFFICULTY: Array = [
	{"name": "EASY", "events_per_leg": 1.0, "burn_band": 1.5, "landing_forgive": 1.3, "surface_hazards": 0.6, "drone_rocks": 0.7, "budget_slack": 1.15, "over_mult": 4.0, "storm_strong": 0.15},
	{"name": "NORMAL", "events_per_leg": 2.0, "burn_band": 1.0, "landing_forgive": 1.0, "surface_hazards": 1.0, "drone_rocks": 1.0, "budget_slack": 1.0, "over_mult": 3.0, "storm_strong": 0.35},
	{"name": "HARD", "events_per_leg": 3.0, "burn_band": 0.7, "landing_forgive": 0.85, "surface_hazards": 1.4, "drone_rocks": 1.4, "budget_slack": 0.95, "over_mult": 2.0, "storm_strong": 0.6},
]

## How every resource is rated (Game.calc()["use"], shown in the builder and in the build report). Game rule.
const USE_RULE: String = "WELL USED: the ship carries what the mission needs plus the NASA margin, and no more than the need plus %d margins (or the smallest part that covers it). UNDER: less than that, a risk. OVER: more than that, wasted mass and money. The rocket, the budget and the deadline are fixed limits, so there the rating reads how much of the limit the ship uses."
const USE_NAMES: Dictionary = {"mass": "ROCKET LIFT", "power": "POWER", "battery": "BATTERY", "fuel": "FUEL", "data": "DATA STORAGE", "comms": "RADIO LINK", "budget": "BUDGET", "time": "TIME"}

## Fields: see V5_DESIGN.md section 1. `dust` = share of the sunlight in space that the arrays can use while
## working at the destination. Budgets, time limits, ops_days and samples_goal are game rules. `margin` is a leftover that only the old builder's FILL TO NEED button reads
## (fuel head-room); the margin rules are Data.MARGIN. Budgets, time limits and samples_goal are game rules.
const DEST: Dictionary = {
	"moon": {
		"earth_min_mkm": 0.3844,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "MOON", "diff": "EASY", "color": Color("c9c9d6"),
		"kind": "land", "skin": "moon", "tier": 1, "air": "none", "returns": true,
		"critical": ["fuel", "mass"], "hazards": [],
		"goal": "Land, drill 3 samples, fly them home",
		"needs": ["Engine landing: no air to slow you down", "Ascent stage: the rocks must fly home", "Lots of fuel: stop, land, come back"],
		"sun_au": 1.0, "earth_au": 0.00257, "gravity": 1.62, "atmos": "none",
		"light_delay": "1.3 seconds", "sun_wm2": 1361.0,
		"budget": 395.0, "margin": 0.2, "time_limit_days": 680,
		"ops_days": 14, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 0.90, "landing_dv": 2.0,   # capture: Apollo 11 braked 0.89 km/s into lunar orbit. landing: Apollo descents took about 2 km/s = game estimate
		"samples_goal": 3,
		"objectives": ["launch", "arrive", "land", "samples", "return"],
		"traj": [
			{"id": "direct", "name": "Direct (Apollo style)", "days": 3, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Apollo 11 reached lunar orbit about 3 days (76 h) after launch. NASA"},
			{"id": "low", "name": "Low-energy (CAPSTONE style)", "days": 138, "dv_mult": 0.75, "cap_mult": 1.0,
				"src": "CAPSTONE took 4.5 months (28 Jun - 13 Nov 2022) on a ballistic path that saves fuel. NASA. Fuel saving = game estimate"},
		],
		"facts": [
			"Gravity 1.62 m/s2 (Earth 9.81). NASA Moon fact sheet",
			"No air: parachutes and heat shields do nothing here",
			"384,400 km away. Radio delay 1.3 s",
			"Daylight lasts about 15 Earth days",
		],
		"real": "CAPSTONE (2022): 25 kg CubeSat, $13.7M + $9.95M launch on Electron. Apollo 11 brought home 21.5 kg of Moon rock.",
	},
	"mercury": {
		"earth_min_mkm": 77.3,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "MERCURY", "diff": "HARD", "color": Color("a89c8c"),
		"kind": "land", "skin": "mercury", "tier": 3, "air": "none", "returns": false,
		"critical": ["fuel", "mass", "time"], "hazards": ["heat"],
		"goal": "Land, drill 4 samples, send data home",
		"needs": ["Sunshade: sunlight is 6.7 times Earth's", "A huge fuel load: no air to brake in", "Patience: the cheap path takes 6.6 years"],
		"sun_au": 0.387, "earth_au": 1.0, "gravity": 3.70, "atmos": "none",   # earth_au: Earth-Mercury distance swings 0.52 to 1.48 AU; 1.0 = game estimate
		"light_delay": "4 to 12 minutes", "sun_wm2": 9082.7,
		"budget": 445.0, "margin": 0.2, "time_limit_days": 3500,
		"ops_days": 30, "night_hours": 0.0, "dust": 0.33,   # MESSENGER's arrays were two-thirds mirrors to stay cool: one third counts = game estimate
		"capture_dv": 0.86, "landing_dv": 3.0,   # capture: MESSENGER's orbit insertion burn, 862 m/s (2011, NASA NSSDC). landing: no lander has flown; low orbit speed is 2.9 km/s, 3.0 = game estimate
		"samples_goal": 4,
		"objectives": ["launch", "arrive", "land", "samples", "downlink"],
		"traj": [
			{"id": "assist", "name": "Six flybys (MESSENGER path)", "days": 2418, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "MESSENGER flew past Earth once, Venus twice and Mercury three times to slow down: 6.6 years, 3 Aug 2004 to 18 Mar 2011. NASA/JHUAPL"},
			{"id": "slow", "name": "Nine flybys (BepiColombo path)", "days": 2954, "dv_mult": 0.6, "cap_mult": 1.0,
				"src": "BepiColombo left on 20 Oct 2018 for a planned capture on 21 Nov 2026 after 9 flybys: 8.1 years. ESA/JAXA. Fuel saving = game estimate"},
		],
		"facts": [
			"Gravity 3.70 m/s2. NASA Mercury fact sheet",
			"Sunlight 9,083 W/m2: 6.7 times Earth's. Day side up to 430 C",
			"No air: only the engine can land you",
			"Radio delay 4 to 12 min",
		],
		"real": "MESSENGER (2004-2015): about 1,100 kg at launch, behind a ceramic-cloth sunshade. First to orbit Mercury. No lander has ever been sent.",
	},
	"venus": {
		"earth_min_mkm": 38.2,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "VENUS", "diff": "HARD", "color": Color("e8c27a"),
		"kind": "land", "skin": "venus", "tier": 3, "air": "thick", "returns": false,
		"critical": ["time", "comms", "mass"], "hazards": ["pressure", "heat"],
		"surface_minutes": 127.0,
		"goal": "Land, drill 3 samples in 127 minutes",
		"needs": ["Pressure hull: the air crushes like 900 m of sea", "Heat shield: the thick air does all the braking", "Batteries and a fast dish: you get 127 minutes"],
		"sun_au": 0.723, "earth_au": 1.0, "gravity": 8.87, "atmos": "thick: 92 times Earth's pressure, 464 C",   # earth_au: 0.26 to 1.75 AU; 1.0 = game estimate
		"light_delay": "2 to 14 minutes", "sun_wm2": 2601.3,
		"budget": 360.0, "margin": 0.2, "time_limit_days": 660,
		"ops_days": 1, "night_hours": 0.0, "dust": 0.0,   # dust 0: no usable sunlight on the ground; the Venera landers ran on batteries only
		"capture_dv": 1.25, "landing_dv": 0.0,   # capture: Venus Express braked 1,251 m/s into a long orbit (ESA, 2006); a lander with a heat shield dives straight in
		"samples_goal": 3,
		"objectives": ["launch", "arrive", "land", "samples", "downlink"],
		"traj": [
			{"id": "direct", "name": "Direct (Venus Express path)", "days": 153, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Venus Express flew 153 days, 9 Nov 2005 to 11 Apr 2006. ESA"},
			{"id": "fast", "name": "Fast (Venera 13 path)", "days": 122, "dv_mult": 1.3, "cap_mult": 0.8,
				"src": "Venera 13 flew 122 days, 30 Oct 1981 to 1 Mar 1982. Faster paths need more energy: capacity cut is a game estimate"},
		],
		"facts": [
			"Gravity 8.87 m/s2. NASA Venus fact sheet",
			"Surface: 464 C and 92 bar, hot enough to melt lead",
			"Venera 13 lived 127 minutes on the ground (1982)",
			"Radio delay 2 to 14 min",
		],
		"real": "Venera 13 (1982): a Soviet lander that drilled the soil, sent the first colour pictures from Venus and died after 127 minutes.",
	},
	"mars": {
		"earth_min_mkm": 55.7,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "MARS", "diff": "MEDIUM", "color": Color("d0623a"),
		"kind": "land", "skin": "mars", "tier": 2, "air": "thin", "returns": false,
		"critical": ["power", "mass"], "hazards": ["night"],
		"goal": "Land, drill 4 samples, send data home",
		"needs": ["Heat shield and parachute: landers dive straight into the thin air", "Batteries for a 12-hour night", "A medium dish or better"],
		"sun_au": 1.52, "earth_au": 1.5, "gravity": 3.73, "atmos": "thin (under 1% of Earth's)",   # earth_au: Mars is 0.37 to 2.68 AU away; 1.5 = game estimate
		"light_delay": "4 to 24 minutes", "sun_wm2": 586.2,
		"budget": 325.0, "margin": 0.2, "time_limit_days": 800,
		"ops_days": 30, "night_hours": 12.3, "dust": 0.8,
		"capture_dv": 2.1, "landing_dv": 0.3,   # capture: Hohmann arrival into a 300 km orbit = our maths (MRO braked 1 km/s into a long ellipse). landing: the rocket part after the parachute = game estimate
		"samples_goal": 4,
		"objectives": ["launch", "arrive", "land", "samples", "downlink"],
		"traj": [
			{"id": "hohmann", "name": "Hohmann transfer", "days": 203, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Perseverance flew 203 days from Earth to Mars (2020-21). NASA"},
			{"id": "fast", "name": "Fast transfer", "days": 150, "dv_mult": 1.3, "cap_mult": 0.8,
				"src": "Faster paths need more energy: game estimate"},
		],
		"facts": [
			"Gravity 3.73 m/s2. NASA Mars fact sheet",
			"Sunlight 586 W/m2, 43% of Earth's",
			"Radio delay 4 to 24 min: landers land themselves",
			"A day (sol) lasts 24 h 40 min, nights are cold and dark",
		],
		"real": "Perseverance (2021): 1,025 kg rover on an Atlas V, nuclear MMRTG power, 203-day cruise, heat shield + parachute + sky crane.",
	},
	"jupiter": {
		"earth_min_mkm": 588.5,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "JUPITER", "diff": "EXPERT", "color": Color("d9a066"),
		"kind": "ring", "skin": "jupiter", "tier": 4, "air": "none", "returns": false,
		"critical": ["power", "comms", "budget"], "hazards": ["radiation", "delay"],
		"goal": "Orbit, fly the drone for 5 ring samples",
		"needs": ["Radiation shield: the belts fry electronics", "Nuclear power, or huge solar arrays like Juno", "High-gain dish: 5 times farther than the Sun"],
		"sun_au": 5.20, "earth_au": 5.2, "gravity": 25.92, "atmos": "giant gas planet, no surface",
		"light_delay": "33 to 54 minutes", "sun_wm2": 50.26,
		"budget": 460.0, "margin": 0.2, "time_limit_days": 2400,
		"ops_days": 30, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 0.54, "landing_dv": 0.0,   # Juno's orbit insertion burn: 542 m/s in 35 minutes (4 Jul 2016). NASA
		"samples_goal": 5,
		"objectives": ["launch", "arrive", "deploy", "samples", "dock", "downlink"],
		"traj": [
			{"id": "assist", "name": "Earth flyby (Juno path)", "days": 1796, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Juno left on 5 Aug 2011, swung past Earth in 2013 and reached Jupiter on 4 Jul 2016: 4.9 years. NASA"},
			{"id": "direct", "name": "Direct Hohmann transfer", "days": 998, "dv_mult": 1.0, "cap_mult": 0.5,
				"src": "Hohmann time to Jupiter = 2.7 years (our maths). Needs far more launch energy: capacity cut is a game estimate"},
		],
		"facts": [
			"Gravity 25.92 m/s2 at 1 bar (mean). NASA Jupiter fact sheet",
			"Sunlight 50 W/m2: under 4% of Earth's",
			"Faint dust rings: a halo, a main ring, two gossamer rings",
			"Radiation belts strong enough to kill electronics",
		],
		"real": "Juno (2011-): 3,625 kg at launch, three 9 m solar wings that make about 400 W at Jupiter, electronics inside a titanium vault.",
	},
	"saturn": {
		"earth_min_mkm": 1195.5,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "SATURN", "diff": "EXPERT", "color": Color("e3c27a"),
		"kind": "ring", "skin": "saturn", "tier": 4, "air": "none", "returns": false,
		"critical": ["power", "comms", "time"], "hazards": ["dark", "delay"],
		"goal": "Orbit, fly the drone for 5 ring samples",
		"needs": ["Nuclear power: sunlight is 1% of Earth's", "High-gain dish: 9.5 times farther than the Sun", "A 6 to 7 year cruise: plan the time"],
		"sun_au": 9.54, "earth_au": 9.5, "gravity": 11.19, "atmos": "giant gas planet, no surface",
		"light_delay": "about 80 minutes", "sun_wm2": 14.8,
		"budget": 700.0, "margin": 0.2, "time_limit_days": 3300,
		"ops_days": 30, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 0.63, "landing_dv": 0.0,
		"samples_goal": 5,
		"objectives": ["launch", "arrive", "deploy", "samples", "dock", "downlink"],
		"traj": [
			{"id": "assist", "name": "Gravity assists (Cassini path)", "days": 2451, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Cassini flew past Venus twice, Earth and Jupiter, and reached Saturn after 6.7 years (1997-2004). NASA"},
			{"id": "direct", "name": "Direct Hohmann transfer", "days": 2208, "dv_mult": 1.0, "cap_mult": 0.3,
				"src": "Hohmann time to Saturn = 6.1 years (our maths). Needs far more launch energy: capacity cut is a game estimate"},
		],
		"facts": [
			"Gravity 11.19 m/s2 at 1 bar (mean). NASA Saturn fact sheet",
			"Sunlight 14.8 W/m2: about 1% of Earth's. Solar panels barely work",
			"No surface: send a robot through the rings instead",
			"Radio delay about 80 min each way",
		],
		"real": "Cassini (1997-2017): 5,712 kg at launch, 3 nuclear RTGs, 4 m dish. In its 2017 Grand Finale it dived 22 times between Saturn and its rings.",
	},
	"uranus": {
		"earth_min_mkm": 2581.9,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "URANUS", "diff": "EXTREME", "color": Color("9fe0e0"),
		"kind": "ring", "skin": "uranus", "tier": 5, "air": "none", "returns": false,
		"critical": ["power", "comms", "time", "budget"], "hazards": ["dark", "delay"],
		"goal": "Orbit, fly the drone for 6 ring samples",
		"needs": ["Nuclear power: sunlight is 0.3% of Earth's", "Every bit counts: radio 370 times slower than at Earth", "13 years of cruise: plan the time and the money"],
		"sun_au": 19.19, "earth_au": 19.2, "gravity": 9.01, "atmos": "giant ice planet, no surface",
		"light_delay": "2.4 to 2.9 hours", "sun_wm2": 3.69,
		"budget": 745.0, "margin": 0.2, "time_limit_days": 5600,
		"ops_days": 30, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 1.09, "landing_dv": 0.0,   # NASA's Uranus Orbiter and Probe design (2021) brakes 1.09 km/s into orbit
		"samples_goal": 6,
		"objectives": ["launch", "arrive", "deploy", "samples", "dock", "downlink"],
		"traj": [
			{"id": "slow", "name": "Slow arrival (orbiter study)", "days": 4750, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "NASA's Uranus Orbiter and Probe design (2021): about 13 years with a Jupiter flyby, slow enough to brake into orbit"},
			{"id": "fast", "name": "Fast (Voyager 2 speed)", "days": 3079, "dv_mult": 2.3, "cap_mult": 1.0,
				"src": "Voyager 2 reached Uranus in 8.4 years (20 Aug 1977 - 24 Jan 1986) but flew straight past. Braking 2.5 km/s from a fast path: game estimate from NASA's 2017 Ice Giants study"},
		],
		"facts": [
			"Gravity 9.01 m/s2 at 1 bar (mean). NASA Uranus fact sheet",
			"Sunlight 3.7 W/m2: 0.3% of Earth's",
			"13 dark, narrow rings (NASA)",
			"Radio delay 2.4 to 2.9 hours each way",
		],
		"real": "Voyager 2 (1986) is the only craft to visit Uranus: one flyby, 8.4 years after launch. No orbiter has ever been sent.",
	},
	"neptune": {
		"earth_min_mkm": 4305.9,   # closest distance from Earth, million km. NASA planetary fact sheet
		"name": "NEPTUNE", "diff": "EXTREME", "color": Color("4f7be0"),
		"kind": "ring", "skin": "neptune", "tier": 5, "air": "none", "returns": false,
		"critical": ["power", "comms", "time", "fuel"], "hazards": ["dark", "delay"],
		"goal": "Orbit, fly the drone for 6 ring samples",
		"needs": ["Nuclear power: sunlight is 0.1% of Earth's", "Brake hard after 12 years, or fly 16 and let the nuclear power fade", "The slowest radio link in the game"],
		"sun_au": 30.07, "earth_au": 30.2, "gravity": 11.27, "atmos": "giant ice planet, no surface",
		"light_delay": "about 4 hours", "sun_wm2": 1.508,
		"budget": 795.0, "margin": 0.2, "time_limit_days": 5600,
		"ops_days": 60, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 2.5, "landing_dv": 0.0,   # game estimate: NASA's 2017 Ice Giants study gives 2.3 to 3.5 km/s to brake into Neptune orbit
		"samples_goal": 6,
		"objectives": ["launch", "arrive", "deploy", "samples", "dock", "downlink"],
		"traj": [
			{"id": "fast", "name": "Jupiter flyby (12 years)", "days": 4388, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Voyager 2 reached Neptune in 12 years (20 Aug 1977 - 25 Aug 1989); the Neptune Odyssey orbiter study also plans about 12 years with a Jupiter flyby"},
			{"id": "slow", "name": "Direct, slow arrival (16 years)", "days": 5844, "dv_mult": 0.5, "cap_mult": 1.0,
				"src": "The Neptune Odyssey study (2021) needs 16 years if it flies direct, without Jupiter. Arriving slower needs less braking: game estimate"},
		],
		"facts": [
			"Gravity 11.27 m/s2 at 1 bar (mean). NASA Neptune fact sheet",
			"Sunlight 1.5 W/m2: 0.1% of Earth's",
			"Five named rings; the outer one has bright arcs",
			"Radio delay about 4 hours each way",
		],
		"real": "Voyager 2 (1989) is the only craft to visit Neptune: one flyby, 12 years after launch, sending 21.6 kilobits per second.",
	},
}

## The three tasks each destination offers, easiest first. Choosing a task sets the difficulty (`diff`).
## Game.dest() returns the destination with the chosen task's "samples" (as samples_goal) and "goal" merged in,
## and "budget", "returns", "objectives" where a task changes them (the Moon scout sends data and brings
## nothing home; the easy tasks need a smaller ship, so they get a smaller budget). Budgets ($M, before the
## difficulty's budget_slack) and sample counts are game rules, tuned by tools/dev/balance.gd.
const TASKS: Dictionary = {
	"moon": [
		{"id": "scout", "name": "SCOUT LANDER", "diff": 0, "level": "EASY", "samples": 2, "budget": 270.0,
			"needs": ["Engine landing: no air to slow you down", "A drill and a radio: the data is the prize", "Fuel to stop and land (nothing flies home)"],
			"text": "Land, drill 2 rocks and radio what you find to Earth. Nothing flies home.",
			"goal": "Land, drill 2 samples, send data home",
			"returns": false, "objectives": ["launch", "arrive", "land", "samples", "downlink"]},
		{"id": "return", "name": "SAMPLE RETURN", "diff": 1, "level": "NORMAL", "samples": 3,
			"text": "Land, drill 3 rocks and fly them home to Earth, as Apollo and Chang'e 5 did.",
			"goal": "Land, drill 3 samples, fly them home"},
		{"id": "polar", "name": "POLAR ICE HUNT", "diff": 2, "level": "HARD", "samples": 5,
			"text": "Drill 5 samples beside a dark polar crater and fly every one of them home.",
			"goal": "Land, drill 5 samples, fly them home"},
	],
	"mercury": [
		{"id": "first", "name": "FIRST TOUCHDOWN", "diff": 0, "level": "EASY", "samples": 2, "budget": 430.0,
			"text": "Be the first to land on Mercury. Drill 2 rocks and send the data home.",
			"goal": "Land, drill 2 samples, send data home"},
		{"id": "survey", "name": "SURFACE SURVEY", "diff": 1, "level": "NORMAL", "samples": 4,
			"text": "Land, drill 4 rocks across the plain and send the data home.",
			"goal": "Land, drill 4 samples, send data home"},
		{"id": "traverse", "name": "CRATER TRAVERSE", "diff": 2, "level": "HARD", "samples": 6,
			"text": "Drive far across the hot, cratered plain: drill 6 rocks and send every bit home.",
			"goal": "Land, drill 6 samples, send data home"},
	],
	"venus": [
		{"id": "look", "name": "QUICK LOOK", "diff": 0, "level": "EASY", "samples": 2, "budget": 350.0,
			"text": "Land and drill 2 rocks before the heat kills the lander. Send the data at once.",
			"goal": "Land, drill 2 samples in 127 minutes"},
		{"id": "soil", "name": "SOIL SURVEY", "diff": 1, "level": "NORMAL", "samples": 3,
			"text": "Drill 3 rocks in the 127 minutes the lander lives. Venera 13 managed one.",
			"goal": "Land, drill 3 samples in 127 minutes"},
		{"id": "dash", "name": "FOUR-ROCK DASH", "diff": 2, "level": "HARD", "samples": 4,
			"text": "Drive out and drill 4 rocks in 127 minutes. Every minute counts.",
			"goal": "Land, drill 4 samples in 127 minutes"},
	],
	"mars": [
		{"id": "scout", "name": "LANDING SITE SCOUT", "diff": 0, "level": "EASY", "samples": 2, "budget": 315.0,
			"text": "Land and drill 2 rocks close to the lander. Send the data home.",
			"goal": "Land, drill 2 samples, send data home"},
		{"id": "survey", "name": "ROCK SURVEY", "diff": 1, "level": "NORMAL", "samples": 4,
			"text": "Drive across the plain, drill 4 rocks and send the data home.",
			"goal": "Land, drill 4 samples, send data home"},
		{"id": "cache", "name": "SAMPLE CACHE", "diff": 2, "level": "HARD", "samples": 6,
			"text": "Drill and seal 6 rock cores, as Perseverance has. Send all the data home.",
			"goal": "Land, drill 6 samples, send data home"},
	],
	"jupiter": [
		{"id": "pass", "name": "RING FLYTHROUGH", "diff": 0, "level": "EASY", "samples": 3, "budget": 440.0,
			"text": "Fly the drone through the faint dust rings once and catch 3 grains.",
			"goal": "Orbit, fly the drone for 3 ring samples"},
		{"id": "survey", "name": "RING SURVEY", "diff": 1, "level": "NORMAL", "samples": 5,
			"text": "Catch 5 ring grains with the drone, dock and send the data home.",
			"goal": "Orbit, fly the drone for 5 ring samples"},
		{"id": "dive", "name": "DEEP RING DIVE", "diff": 2, "level": "HARD", "samples": 7,
			"text": "Catch 7 grains deep in the rings, inside the radiation belts. Dock and send it all.",
			"goal": "Orbit, fly the drone for 7 ring samples"},
	],
	"saturn": [
		{"id": "skim", "name": "RING SKIM", "diff": 0, "level": "EASY", "samples": 3, "budget": 605.0,
			"text": "Skim the edge of the rings with the drone and catch 3 ice grains.",
			"goal": "Orbit, fly the drone for 3 ring samples"},
		{"id": "survey", "name": "RING SURVEY", "diff": 1, "level": "NORMAL", "samples": 5,
			"text": "Catch 5 ice grains, dock with the orbiter and send the data home.",
			"goal": "Orbit, fly the drone for 5 ring samples"},
		{"id": "finale", "name": "GRAND FINALE DIVE", "diff": 2, "level": "HARD", "samples": 7,
			"text": "Dive between the rings like Cassini in 2017: catch 7 ice grains and get out.",
			"goal": "Orbit, fly the drone for 7 ring samples"},
	],
	"uranus": [
		{"id": "first", "name": "FIRST ORBITER", "diff": 0, "level": "EASY", "samples": 4, "budget": 720.0,
			"text": "Be the first to orbit Uranus. Catch 4 ring grains with the drone.",
			"goal": "Orbit, fly the drone for 4 ring samples"},
		{"id": "survey", "name": "RING SURVEY", "diff": 1, "level": "NORMAL", "samples": 6,
			"text": "Catch 6 grains from the dark, narrow rings and send the data home.",
			"goal": "Orbit, fly the drone for 6 ring samples"},
		{"id": "traverse", "name": "LONG RING TRAVERSE", "diff": 2, "level": "HARD", "samples": 8,
			"text": "Cross all the rings: catch 8 grains and send every bit over a very slow link.",
			"goal": "Orbit, fly the drone for 8 ring samples"},
	],
	"neptune": [
		{"id": "first", "name": "FIRST ORBITER", "diff": 0, "level": "EASY", "samples": 4, "budget": 770.0,
			"text": "Be the first to orbit Neptune. Catch 4 ring grains with the drone.",
			"goal": "Orbit, fly the drone for 4 ring samples"},
		{"id": "survey", "name": "RING SURVEY", "diff": 1, "level": "NORMAL", "samples": 6,
			"text": "Catch 6 grains from the thin rings and send the data home.",
			"goal": "Orbit, fly the drone for 6 ring samples"},
		{"id": "arcs", "name": "RING ARC HUNT", "diff": 2, "level": "HARD", "samples": 8,
			"text": "Catch 8 grains from the bright arcs of the outer ring. The slowest link there is.",
			"goal": "Orbit, fly the drone for 8 ring samples"},
	],
}

## Letter grade of a successful mission, from the total of the four score parts. Game rule.
const GRADE_A: int = 85
const GRADE_B: int = 70
const GRADE_RULE: String = "A: every goal met and a total of 85 or more. B: 70 or more. C: every goal met. No letter if a goal was missed."

## Launcher lift to each destination, kg. Real where a mission flew it; the rest are game estimates
## anchored on the real mission named in `src`.
const ROCKETS: Dictionary = {
	"electron": {"name": "Electron + Photon", "cost": 9.95,
		"cap": {"moon": 25.0},
		"src": "Rocket Lab. NASA paid $9.95M to send the 25 kg CAPSTONE to the Moon (2022)"},
	"falcon9": {"name": "Falcon 9", "cost": 74.0,
		"cap": {"moon": 4020.0, "mars": 4020.0, "venus": 4020.0, "mercury": 2500.0},
		"src": "SpaceX: $74M, 4,020 kg to Mars (Wikipedia). Moon, Venus = the Mars value (game estimate). Mercury = game estimate from MESSENGER: about 1,100 kg on a Delta II"},
	"vulcan": {"name": "Vulcan VC6", "cost": 110.0,
		"cap": {"moon": 11500.0, "mercury": 5200.0, "jupiter": 3900.0},
		"src": "ULA: 11,500 kg to the Moon, about $110M (Wikipedia). Game estimates: Mercury from BepiColombo (about 4,100 kg, Ariane 5), Jupiter from Juno (3,625 kg, Atlas V 551)"},
	"heavy": {"name": "Falcon Heavy", "cost": 150.0,
		"cap": {"moon": 16800.0, "mars": 16800.0, "venus": 16800.0, "mercury": 9000.0, "jupiter": 6000.0, "saturn": 6000.0, "uranus": 5000.0, "neptune": 3600.0},
		"src": "SpaceX: $150M, 16,800 kg to Mars (Wikipedia). Jupiter: Europa Clipper, about 6,000 kg (NASA). Game estimates: Saturn from Clipper, Uranus from NASA's Uranus Orbiter design, Neptune from Voyager 2 (722 kg)"},
}

## cat: core, power, comms, science, landing, robot, return, fuel, protect
## `kinds` / `dests` (optional): the mission kinds or destinations a part can fly on. Game.part_available() reads them.
const PARTS: Dictionary = {
	"bus": {"name": "Spacecraft bus", "cat": "core", "mass": 300.0, "cost": 50.0, "draw": 80.0, "store_gb": 32.0,
		"max": 1, "locked_in": true,
		"desc": "Frame, computer, engine and heaters. Always included.",
		"src": "game rule"},
	"solar": {"name": "Solar array 1 kW", "cat": "power", "mass": 33.0, "cost": 5.0, "gen": 1000.0, "kind": "solar", "max": 8,
		"desc": "1,000 W near Earth. Power drops with distance from the Sun squared.",
		"src": "Most arrays give about 30 W per kg. NASA Small Spacecraft Tech 2026, ch. 3"},
	"solar_lite": {"name": "Light solar array 2 kW", "cat": "power", "mass": 20.0, "cost": 8.0, "gen": 2000.0, "kind": "solar", "max": 8, "tech": "solar2",
		"desc": "100 W per kg. Unlocked in the Tech Lab.",
		"src": "Arrays range from 1 to 200 W/kg. NASA SST 2026, ch. 3"},
	"rtg": {"name": "MMRTG nuclear power", "cat": "power", "mass": 45.0, "cost": 40.0, "gen": 110.0, "kind": "rtg", "max": 4,
		"desc": "110 W day and night, at any distance. Lasts 14 years.",
		"src": "NASA MMRTG fact sheet: about 110 W, 45 kg, 14-year design life. Price = game estimate"},
	"battery": {"name": "Li-ion battery 2 kWh", "cat": "power", "mass": 10.0, "cost": 1.0, "wh": 2000.0, "max": 6,
		"desc": "Stores 2,000 Wh for nights and peaks.",
		"src": "Li-ion: 150-270 Wh/kg. NASA SST 2026, ch. 3"},
	"battery_hi": {"name": "Hi-cap battery 4 kWh", "cat": "power", "mass": 15.0, "cost": 3.0, "wh": 4000.0, "max": 6, "tech": "batt2",
		"desc": "270 Wh per kg. Unlocked in the Tech Lab.",
		"src": "Best Li-ion cells: 270 Wh/kg. NASA SST 2026, ch. 3"},
	"lga": {"name": "Low-gain antenna", "cat": "comms", "mass": 2.0, "cost": 0.5, "draw": 10.0, "rate": 0.01, "rate_cap": 2.0, "max": 1,
		"desc": "Small and cheap. Very slow far from Earth.",
		"src": "game estimate"},
	"mga": {"name": "Medium-gain antenna", "cat": "comms", "mass": 10.0, "cost": 3.0, "draw": 40.0, "rate": 0.3, "rate_cap": 20.0, "max": 1,
		"desc": "Good near Earth and Mars.",
		"src": "game estimate"},
	"hga": {"name": "High-gain dish 3 m", "cat": "comms", "mass": 50.0, "cost": 15.0, "draw": 100.0, "rate": 3.0, "rate_cap": 300.0, "max": 1,
		"desc": "Like MRO's dish: 6 Mbps from Mars. Needed for the outer planets.",
		"src": "MRO: 3 m dish, up to 6 Mbps from Mars. NASA NSSDCA"},
	"ka": {"name": "Ka-band dish", "cat": "comms", "mass": 40.0, "cost": 25.0, "draw": 90.0, "rate": 10.0, "rate_cap": 300.0, "max": 1, "tech": "ka",
		"desc": "Faster band. LRO sends 100-300 Mbps from the Moon.",
		"src": "LRO Ka-band: 100-300 Mbps. NASA NSSDCA"},
	"recorder": {"name": "Data recorder 256 Gb", "cat": "comms", "mass": 2.0, "cost": 1.0, "store_gb": 256.0, "max": 4,
		"desc": "Stores science until it can be sent home.",
		"src": "game estimate"},
	"camera": {"name": "Context camera (CTX)", "cat": "science", "mass": 3.0, "cost": 10.0, "draw": 7.0, "gb": 0.5, "pts": 1, "max": 1,
		"desc": "B/W camera. Each sample: 0.5 Gb (game rule).",
		"src": "MRO CTX: 3 kg, 7 W. NASA"},
	"spectro": {"name": "Imaging spectrometer (CRISM)", "cat": "science", "mass": 33.0, "cost": 30.0, "draw": 46.0, "gb": 2.5, "pts": 3, "max": 1,
		"desc": "Finds what rocks are made of. 2.5 Gb per look.",
		"src": "MRO CRISM: 32.9 kg, 44-47 W, 2-2.5 Gb per observation. NASA"},
	"mag": {"name": "Magnetometer (Cassini MAG)", "cat": "science", "mass": 3.0, "cost": 5.0, "draw": 3.1, "gb": 0.05, "pts": 1, "max": 1,
		"desc": "Measures magnetic fields.",
		"src": "Cassini MAG: 3.0 kg, 3.1 W. NASA"},
	"dust": {"name": "Dust analyzer", "cat": "science", "mass": 17.0, "cost": 20.0, "draw": 12.0, "gb": 0.3, "pts": 3, "max": 1,
		"desc": "Tastes ring and dust grains (like Cassini's CDA).",
		"src": "Cassini Cosmic Dust Analyzer studied ring grains. Mass and power = game estimate"},
	"drill": {"name": "Sample drill and arm", "cat": "science", "mass": 30.0, "cost": 10.0, "draw": 50.0, "gb": 0.1, "pts": 1, "max": 1, "kinds": ["land"],
		"desc": "Needed to pick up rock samples on the ground.",
		"src": "game estimate"},
	"legs": {"name": "Landing legs", "cat": "landing", "mass": 50.0, "cost": 5.0, "touch": 4.0, "max": 1, "kinds": ["land"],
		"desc": "Safe touchdown below 4 m/s.",
		"src": "game rule"},
	"airbags": {"name": "Airbags", "cat": "landing", "mass": 100.0, "cost": 10.0, "touch": 12.0, "max": 1, "kinds": ["land"],
		"desc": "Bounce down at up to 12 m/s, like Spirit and Opportunity.",
		"src": "Spirit and Opportunity landed on airbags (2004). Speed limit = game rule"},
	"heatshield": {"name": "Heat shield", "cat": "landing", "mass": 150.0, "cost": 20.0, "max": 1, "kinds": ["land"],
		"desc": "Uses the air to slow down and land. Useless where there is no air.",
		"src": "Landers enter the air straight from their cruise path (direct entry). Mass = game estimate"},
	"chute": {"name": "Supersonic parachute", "cat": "landing", "mass": 50.0, "cost": 10.0, "max": 1, "kinds": ["land"],
		"desc": "Mars: slows you from about 420 m/s to 85 m/s.",
		"src": "Perseverance's chute opened near 1,512 km/h and slowed it to about 306 km/h. NASA"},
	"hull": {"name": "Pressure hull", "cat": "landing", "mass": 120.0, "cost": 30.0, "touch": 9.0, "max": 1, "dests": ["venus"],
		"desc": "Sealed ball that holds off 92 bar and 464 C for about two hours. Lands on its own crush ring.",
		"src": "Venera 13 survived 127 minutes on Venus (1982). NASA NSSDC. Titanium hull, crush ring: secondary sources. Mass, price, 9 m/s limit = game estimate"},
	"rover": {"name": "Small rover", "cat": "robot", "mass": 25.0, "cost": 25.0, "draw": 15.0, "speed": 1.0, "max": 1, "kinds": ["land"],
		"desc": "A robot that drives out to collect samples.",
		"src": "Sojourner (1997) weighed 11.5 kg. Ours = game estimate"},
	"rover_big": {"name": "Big rover", "cat": "robot", "mass": 300.0, "cost": 90.0, "draw": 60.0, "speed": 1.8, "max": 1, "tech": "rover2", "kinds": ["land"],
		"desc": "Faster, jumps higher, own solar. Unlocked in the Tech Lab.",
		"src": "Curiosity weighs 899 kg. Ours = game estimate"},
	"drone": {"name": "Sampling drone", "cat": "robot", "mass": 150.0, "cost": 60.0, "draw": 20.0, "max": 1, "kinds": ["ring"],
		"desc": "Ringed planets: flies into the rings and brings samples back.",
		"src": "game design, inspired by Cassini's Grand Finale dives (2017)"},
	"ascent": {"name": "Ascent stage + return capsule", "cat": "return", "mass": 600.0, "cost": 40.0, "max": 1, "dests": ["moon"],
		"desc": "Takes samples back to Earth. Game rule: needs 30% battery to start.",
		"src": "Apollo used a separate ascent stage. Mass and the 30% rule = game rule"},
	"prop": {"name": "Propellant 100 kg", "cat": "fuel", "mass": 100.0, "cost": 0.5, "max": 80,
		"desc": "Fuel for course corrections, braking into orbit and landing. Engine Isp 300 s.",
		"src": "Rocket equation; Isp 300 s = NASA GMAT default"},
	"sunshade": {"name": "Sunshade", "cat": "protect", "mass": 20.0, "cost": 8.0, "max": 1, "dests": ["mercury", "venus"],
		"desc": "Ceramic-cloth shade that keeps the craft cool close to the Sun.",
		"src": "MESSENGER flew behind a 2.5 x 2 m ceramic-cloth sunshade at Mercury. NASA/JHUAPL. Mass and price = game estimate"},
	"shield": {"name": "Radiation shielding", "cat": "protect", "mass": 30.0, "cost": 5.0, "max": 1,
		"desc": "Protects electronics from solar storms and Jupiter's radiation belts.",
		"src": "JPL: Juno's 172 kg titanium vault cut Jupiter's radiation 800 times. Ours (30 kg): game rule"},
}

const CATS: Array = ["power", "comms", "science", "landing", "robot", "return", "fuel", "protect"]
const CAT_NAMES: Dictionary = {
	"power": "POWER", "comms": "COMMS", "science": "SCIENCE", "landing": "LANDING",
	"robot": "ROBOTS", "return": "RETURN", "fuel": "FUEL", "protect": "SHIELD",
}

const ROLES: Array = [
	{"id": "planner", "name": "MISSION PLANNER", "color": Color("ffd75e"),
		"job": "Pick the rocket and path. Keep the BUDGET and TIME in limits."},
	{"id": "engineer", "name": "ENGINEER", "color": Color("4fd6ff"),
		"job": "Keep MASS under rocket capacity and POWER above what the ship uses."},
	{"id": "science", "name": "SCIENTIST", "color": Color("6dff8a"),
		"job": "Pick instruments and robots that can reach the mission goal."},
	{"id": "comms", "name": "COMMS OFFICER", "color": Color("ff7ad9"),
		"job": "Make sure all the DATA fits in storage and gets sent to Earth."},
]

# ---------------------------------------------------------------- multiplayer (decision D7)

## Which role may change each builder tab. Lookups use the tab name; "src" is not a tab.
const TAB_ROLE: Dictionary = {
	"launcher": "planner",
	"power": "engineer", "fuel": "engineer", "landing": "engineer", "protect": "engineer",
	"science": "science", "robot": "science", "return": "science",
	"comms": "comms",
	"src": "game rule",
}

## Quick-chat presets (keys 1-8 in the builder). Index = the number sent in a "chat" message.
const QUICK_CHAT: Array[String] = [
	"OK!", "WAIT, I'M CHANGING SOMETHING", "MY PART IS DONE", "WHO IS OVER BUDGET?",
	"WE NEED MORE POWER", "TOO HEAVY FOR THE ROCKET", "READY TO SIGN", "GOOD JOB, TEAM!",
]

## REQUEST presets: what one role can ask another for.
const REQUESTS: Array[String] = [
	"NEED MORE POWER", "WE ARE OVER BUDGET", "NEED MORE DATA STORAGE", "OVER ROCKET MASS",
	"CAN I ADD AN INSTRUMENT?", "PLEASE SIGN OFF",
]

## Network send rates for flight controls and the host's simulation state.
const NET_RATES: Dictionary = {"input_hz": 20.0, "state_hz": 15.0, "src": "game rule"}

## Team sync score on the report: weights of the three parts, and the times that score full and zero marks.
const TEAM_SYNC: Dictionary = {
	"w_answered": 0.4, "w_reply": 0.3, "w_sign": 0.3,
	"reply_good_s": 5.0, "reply_bad_s": 30.0,     # average time to answer a REQUEST
	"sign_good_s": 10.0, "sign_bad_s": 90.0,      # all lamps green -> all 4 roles signed
	"src": "game rule",
}

## Landing jobs online: the Scientist opens the Mars parachute and lowers the legs.
## The descent then starts above the parachute: 420 m/s is the no-parachute entry speed already in game.gd,
## 90 m/s the speed under the canopy (Perseverance, see the "chute" part).
const LANDING_JOBS: Dictionary = {
	"site_secs": 12.0,       # time the Planner has to pick a site; then the first site is used
	"gear_secs": 1.5,        # legs (or airbags) take this long to deploy
	"chute_decel": 80.0,     # m/s2 the open canopy removes while faster than chute_vy
	"chute_vy": 90.0,        # m/s under the canopy
	"chute_cut_alt": 1000.0, # m: the canopy is cut away here, opened or not
	"mars_alt": 4500.0,      # m: start of the descent when the parachute is still packed
	"mars_vy": 420.0,        # m/s
	"mars_vx": 8.0,          # m/s
	"src": "game rule",
}

## Landing sites the Planner picks from before the descent. drift: extra sideways speed (m/s) to cancel;
## touch_mult: rough ground lowers the safe touchdown speed; credit_mult: more interesting rocks pay more.
const LANDING_SITES: Array = [
	{"name": "FLAT PLAIN", "drift": 0.0, "touch_mult": 1.0, "credit_mult": 1.0,
		"desc": "Safe and dull.", "src": "game rule"},
	{"name": "CRATER RIM", "drift": 3.0, "touch_mult": 0.75, "credit_mult": 1.25,
		"desc": "Drift and rocks. +25% credits.", "src": "game rule"},
	{"name": "BOULDER FIELD", "drift": 5.0, "touch_mult": 0.6, "credit_mult": 1.5,
		"desc": "Hard landing. +50% credits.", "src": "game rule"},
]

## Saturn drone: the Engineer sets the throttle. thrust and burn multiply the solo values (NORMAL = solo).
const DRONE_THROTTLE: Array = [
	{"name": "ECO", "thrust": 0.8, "burn": 0.6, "src": "game rule"},
	{"name": "NORMAL", "thrust": 1.0, "burn": 1.0, "src": "game rule"},
	{"name": "BOOST", "thrust": 1.3, "burn": 1.6, "src": "game rule"},
]

## Saturn downlink online: after docking, the Comms officer picks what to send home within `limit` units.
## Each ice sample's kind follows the grain it came from; the orbiter adds two photos.
const DRONE_DOWNLINK: Dictionary = {
	"max_samples": 8, # existing D7 manifest cap (ce5c943); src below
	"limit": 6, "secs": 20.0, "credits_per_pt": 2,
	"samples": [
		{"name": "ICE GRAIN", "size": 1, "pts": 1},
		{"name": "ICE CRYSTAL", "size": 2, "pts": 3},
		{"name": "DIRTY ICE", "size": 3, "pts": 4},
	],
	"photos": [
		{"name": "RING CLOSE-UP", "size": 2, "pts": 2},
		{"name": "SATURN LIMB", "size": 1, "pts": 1},
	],
	"src": "game rule",
}

const TECH: Dictionary = {
	"solar2": {"name": "Light solar arrays", "cost": 60, "desc": "Unlocks 2 kW arrays at 100 W/kg."},
	"batt2": {"name": "High-energy batteries", "cost": 40, "desc": "Unlocks 4 kWh batteries at 270 Wh/kg."},
	"ka": {"name": "Ka-band radio", "cost": 80, "desc": "Unlocks a 3x faster dish (game rule)."},
	"rover2": {"name": "Big rover", "cost": 100, "desc": "Unlocks a fast rover."},
	"armor": {"name": "Armored drone", "cost": 70, "desc": "Saturn drone survives 3 ring hits instead of 1."},
	"grant": {"name": "Bigger NASA grant", "cost": 120, "desc": "+$100M budget on every mission."},
}

const OBJ_NAMES: Dictionary = {
	"launch": "Launch", "arrive": "Arrive safely", "land": "Land safely", "deploy": "Deploy the drone",
	"samples": "Collect samples", "return": "Return samples to Earth", "dock": "Drone docks with orbiter",
	"downlink": "Send the science to Earth",
}

const SOURCES: Array = [
	"NASA planetary fact sheets (gravity, sunlight, distance): nssdc.gsfc.nasa.gov/planetary/factsheet",
	"NASA DONKI space weather database, real 2024 geomagnetic storms: api.nasa.gov",
	"NASA Small Spacecraft Technology State of the Art 2026 (solar arrays, batteries, radios)",
	"NASA MMRTG fact sheet (110 W, 45 kg, 14-year life)",
	"NASA NSSDCA: MRO, LRO (instruments, data rates, dishes)",
	"NASA GMAT user guide (Isp 300 s, solar array decay defaults)",
	"JPL CML 4 checklist (Wessen et al. 2013): dry mass, power and energy margins of 35%, telecom 3 dB",
	"NASA Discovery 2019 call: 25% cost reserve",
	"Mission facts: Apollo, CAPSTONE, Perseverance, Cassini, Juno, Galileo, Europa Clipper, MESSENGER, Voyager 2 (nasa.gov)",
	"Mission facts: Venus Express, BepiColombo (esa.int), Venera 13 (Soviet Venera programme)",
	"Rocket capacity and prices: SpaceX, ULA, Rocket Lab, Wikipedia (secondary)",
]

const DonkiData = preload("res://scripts/donki_data.gd")
var donki: Array = DonkiData.EVENTS
