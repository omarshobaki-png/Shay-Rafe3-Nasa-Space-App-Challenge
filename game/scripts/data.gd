extends Node
## All game numbers. Each real number carries its source in `src`.
## "game rule" = a number we chose for gameplay, not a NASA fact.

const G0: float = 9.81          # m/s2, standard gravity (used in the rocket equation)
const ISP: float = 300.0        # s, engine efficiency; GMAT's default thruster Isp
const PASS_HOURS: float = 8.0   # game rule: hours of Deep Space Network contact per day
const OPS_COST_PER_YEAR: float = 10.0  # game rule: $M per year to run mission control
const SOLAR_DECAY_PER_YEAR: float = 0.05  # GMAT solar-array default: 5% loss per year

const DEST: Dictionary = {
	"moon": {
		"name": "MOON", "diff": "EASY", "color": Color("c9c9d6"),
		"sun_au": 1.0, "earth_au": 0.00257, "gravity": 1.62, "atmos": "none",
		"light_delay": "1.3 seconds", "sun_wm2": 1361.0,
		"budget": 300.0, "margin": 0.10, "time_limit_days": 365,
		"ops_days": 14, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 0.90, "landing_dv": 1.89,
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
			"A lunar day lasts about 14 Earth days",
		],
		"real": "CAPSTONE (2022): 25 kg CubeSat, $13.7M + $9.95M launch on Electron. Apollo 11 brought home 21.5 kg of Moon rock.",
	},
	"mars": {
		"name": "MARS", "diff": "MEDIUM", "color": Color("d0623a"),
		"sun_au": 1.52, "earth_au": 1.5, "gravity": 3.71, "atmos": "thin (under 1% of Earth's)",
		"light_delay": "4 to 24 minutes", "sun_wm2": 586.2,
		"budget": 500.0, "margin": 0.20, "time_limit_days": 730,
		"ops_days": 30, "night_hours": 12.3, "dust": 0.8,
		"capture_dv": 2.7, "landing_dv": 0.3,
		"samples_goal": 4,
		"objectives": ["launch", "arrive", "land", "samples", "downlink"],
		"traj": [
			{"id": "hohmann", "name": "Hohmann transfer", "days": 203, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Perseverance flew 203 days from Earth to Mars (2020-21). NASA"},
			{"id": "fast", "name": "Fast transfer", "days": 150, "dv_mult": 1.3, "cap_mult": 0.8,
				"src": "Faster paths need more energy: game estimate"},
		],
		"facts": [
			"Gravity 3.71 m/s2. NASA Mars fact sheet",
			"Sunlight 586 W/m2, 43% of Earth's",
			"Radio delay 4 to 24 min: landers land themselves",
			"A day (sol) lasts 24 h 40 min, nights are cold and dark",
		],
		"real": "Perseverance (2021): 1,025 kg rover on an Atlas V, nuclear MMRTG power, 203-day cruise, heat shield + parachute + sky crane.",
	},
	"saturn": {
		"name": "SATURN", "diff": "HARD", "color": Color("e3c27a"),
		"sun_au": 9.54, "earth_au": 9.5, "gravity": 10.44, "atmos": "giant gas planet, no surface",
		"light_delay": "about 80 minutes", "sun_wm2": 14.8,
		"budget": 900.0, "margin": 0.35, "time_limit_days": 5110,
		"ops_days": 30, "night_hours": 0.0, "dust": 1.0,
		"capture_dv": 0.63, "landing_dv": 0.0,
		"samples_goal": 5,
		"objectives": ["launch", "arrive", "deploy", "samples", "dock", "downlink"],
		"traj": [
			{"id": "assist", "name": "Gravity assists (Cassini path)", "days": 2447, "dv_mult": 1.0, "cap_mult": 1.0,
				"src": "Cassini flew past Venus twice, Earth and Jupiter, and reached Saturn after 6.7 years (1997-2004). NASA"},
			{"id": "direct", "name": "Direct Hohmann transfer", "days": 2225, "dv_mult": 1.0, "cap_mult": 0.3,
				"src": "Hohmann time to Saturn = 6.1 years (our maths). Needs far more launch energy: capacity cut is a game estimate"},
		],
		"facts": [
			"Gravity 10.44 m/s2 at the cloud tops. NASA Saturn fact sheet",
			"Sunlight 14.8 W/m2: about 1% of Earth's. Solar panels barely work",
			"No surface: send a robot through the rings instead",
			"Radio delay about 80 min each way",
		],
		"real": "Cassini (1997-2017): 5,712 kg at launch, 3 nuclear RTGs, 4 m dish. In its 2017 Grand Finale it dived 22 times between Saturn and its rings.",
	},
}

const ROCKETS: Dictionary = {
	"electron": {"name": "Electron + Photon", "cost": 9.95,
		"cap": {"moon": 25.0},
		"src": "Rocket Lab. NASA paid $9.95M to send the 25 kg CAPSTONE to the Moon (2022)"},
	"falcon9": {"name": "Falcon 9", "cost": 74.0,
		"cap": {"moon": 4020.0, "mars": 4020.0},
		"src": "SpaceX: $74M, 4,020 kg to Mars (Wikipedia). Moon value = at least the Mars value, since the Moon needs less energy (our maths)"},
	"vulcan": {"name": "Vulcan VC6", "cost": 110.0,
		"cap": {"moon": 11500.0},
		"src": "ULA: 11,500 kg to the Moon (trans-lunar injection). Price about $110M (Wikipedia)"},
	"heavy": {"name": "Falcon Heavy", "cost": 150.0,
		"cap": {"moon": 16800.0, "mars": 16800.0, "saturn": 6065.0},
		"src": "SpaceX: $150M expendable, 16,800 kg to Mars (Wikipedia). Saturn value from Europa Clipper: 6,065 kg sent to Jupiter with gravity assists (NASA)"},
}

## cat: core, power, comms, science, landing, robot, return, fuel, protect
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
		"desc": "Black-and-white camera. Each sample: 0.5 Gb.",
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
	"drill": {"name": "Sample drill and arm", "cat": "science", "mass": 30.0, "cost": 10.0, "draw": 50.0, "gb": 0.1, "pts": 1, "max": 1,
		"desc": "Needed to pick up rock samples on the ground.",
		"src": "game estimate"},
	"legs": {"name": "Landing legs", "cat": "landing", "mass": 50.0, "cost": 5.0, "touch": 4.0, "max": 1,
		"desc": "Safe touchdown below 4 m/s.",
		"src": "game rule"},
	"airbags": {"name": "Airbags", "cat": "landing", "mass": 100.0, "cost": 10.0, "touch": 12.0, "max": 1,
		"desc": "Bounce down at up to 12 m/s, like Spirit and Opportunity.",
		"src": "Spirit and Opportunity landed on airbags (2004). Speed limit = game rule"},
	"heatshield": {"name": "Heat shield", "cat": "landing", "mass": 150.0, "cost": 20.0, "max": 1,
		"desc": "Uses the air to brake into orbit and land. Useless on the Moon.",
		"src": "Air braking replaces fuel only where there is air. Mass = game estimate"},
	"chute": {"name": "Supersonic parachute", "cat": "landing", "mass": 50.0, "cost": 10.0, "max": 1,
		"desc": "Mars: slows you from about 420 m/s to 90 m/s.",
		"src": "Perseverance's chute opened near 1,500 km/h and slowed it to about 320 km/h. NASA"},
	"rover": {"name": "Small rover", "cat": "robot", "mass": 25.0, "cost": 25.0, "draw": 15.0, "speed": 1.0, "max": 1,
		"desc": "A robot that drives out to collect samples.",
		"src": "Sojourner (1997) weighed 11.5 kg. Ours = game estimate"},
	"rover_big": {"name": "Big rover", "cat": "robot", "mass": 300.0, "cost": 90.0, "draw": 60.0, "speed": 1.8, "max": 1, "tech": "rover2",
		"desc": "Faster, jumps higher, own solar. Unlocked in the Tech Lab.",
		"src": "Curiosity weighs 899 kg. Ours = game estimate"},
	"drone": {"name": "Sampling drone", "cat": "robot", "mass": 150.0, "cost": 60.0, "draw": 20.0, "max": 1, "dest": "saturn",
		"desc": "Saturn only: flies into the rings and brings samples back.",
		"src": "game design, inspired by Cassini's Grand Finale dives (2017)"},
	"ascent": {"name": "Ascent stage + return capsule", "cat": "return", "mass": 600.0, "cost": 40.0, "max": 1,
		"desc": "Takes samples back to Earth. Needs 30% battery to start.",
		"src": "Apollo used a separate ascent stage. Mass and the 30% rule = game rule"},
	"prop": {"name": "Propellant 100 kg", "cat": "fuel", "mass": 100.0, "cost": 0.5, "max": 80,
		"desc": "Fuel for braking into orbit and landing. Engine Isp 300 s.",
		"src": "Rocket equation; Isp 300 s = NASA GMAT default"},
	"shield": {"name": "Radiation shielding", "cat": "protect", "mass": 30.0, "cost": 5.0, "max": 1,
		"desc": "Protects electronics from solar storms.",
		"src": "Juno's 172 kg titanium vault cuts radiation 800 times. NASA JPL"},
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
	"ka": {"name": "Ka-band radio", "cost": 80, "desc": "Unlocks a dish 3x faster than X-band."},
	"rover2": {"name": "Big rover", "cost": 100, "desc": "Unlocks a fast rover."},
	"armor": {"name": "Armored drone", "cost": 70, "desc": "Saturn drone survives 3 ring hits instead of 1."},
	"grant": {"name": "Bigger NASA grant", "cost": 120, "desc": "+$100M budget on every mission."},
}

const OBJ_NAMES: Dictionary = {
	"launch": "Launch", "arrive": "Reach orbit", "land": "Land safely", "deploy": "Deploy the drone",
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
	"JPL Design Principles: power and mass margins (35% early in design)",
	"Mission facts: Apollo 11, CAPSTONE, Perseverance, Cassini, Juno, Europa Clipper (nasa.gov)",
	"Rocket capacity and prices: SpaceX, ULA, Rocket Lab, Wikipedia (secondary)",
]

const DonkiData = preload("res://scripts/donki_data.gd")
var donki: Array = DonkiData.EVENTS
