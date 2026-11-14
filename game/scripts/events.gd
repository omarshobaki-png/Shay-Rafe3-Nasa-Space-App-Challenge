extends RefCounted
## Decision events (v6): fewer, shorter, softer, and two kinds you can tell apart at a glance.
## Data and pure helpers only. The engine that rolls and applies them is in scripts/game.gd
## (Game.event_plan, Game.next_event, Game.event_choice, Game.resolve_event); the pop-up is scripts/event_card.gd.
##
## Event:  id, phase ("cruise" | "site"; nothing happens after the site), from ("ship": a hazard, the amber
##         ALERT card | "earth": advice from mission control, the blue MESSAGE card), role, title (<= 28),
##         text (<= 90), real (<= 140), choices (exactly 2), intro (< 80: Mission Control's line before the card,
##         v8; it sets the scene, never the outcome), urgent (optional, true: no lead-in line)
##   filters, all optional: kinds [..], dests [..], jobs [..], needs_part id or [ids: any one of them],
##                          returns bool (true: only where a capsule flies home; false: only where it does not)
## Choice: label (<= 22), text (<= 60; every number in it is one of its effects or its odds), and any of
##   cost {..}        paid for sure
##   risk {chance, bad {..}, save_part}   `chance` of the bad effects; a `save_part` on board removes the risk
##   gain {..}        applied when the choice goes well
##   needs_part id    the choice is only open with that part on board
## Effect keys (cost, bad, gain):
##   dv_ms      a burn of that many m/s, paid in fuel by the rocket equation      (fuel margin)
##   battery_pct  percent of the battery's capacity                              (battery margin)
##   power      factor on the power the ship makes, for good                     (power margin)
##   rate       factor on the radio speed to Earth, for good                     (comms margin)
##   money      $M from the budget reserve                                       (budget margin)
##   days       days added to the mission                                        (time)
##   data_pct   percent of the science data on board that is lost
##   break      a part id, or "science" / "electronics" (a random instrument, or instrument or antenna)
##   samples    change in samples on board        score   change in science points
##   minutes    minutes of Venus surface life lost        hull   change in the drone's hit points
##   fail       text: the mission ends (v6: no event uses it; tools/dev/balance.gd forbids it)
## Every number in a choice text is a game rule, about half the v5 value; the "real" line is the fact.

const LIST: Array = [
	# ------------------------------------------------------------------ on the way: ship hazards
	{"id": "storm", "phase": "cruise", "from": "ship", "role": "engineer", "title": "SOLAR STORM INCOMING", "intro": "Our Sun watchers just saw a big flare. Something is heading your way.",
		"text": "A cloud of charged particles from the Sun will hit the ship in a few hours.",
		"real": "In Oct 2003 a solar storm killed the MARIE radiation instrument on NASA's Mars Odyssey.",
		"choices": [
			{"label": "TURN TAIL TO IT", "text": "Hide behind the engine: a 5 m/s burn and 1 day.",
				"cost": {"dv_ms": 5.0, "days": 1}},
			{"label": "KEEP WORKING", "text": "{pct}% chance a part breaks. Radiation shielding stops it.",
				"risk": {"chance": 0.4, "bad": {"break": "electronics"}, "save_part": "shield"}},
		]},
	{"id": "micro", "phase": "cruise", "from": "ship", "role": "engineer", "title": "MICROMETEOROID HIT", "intro": "We are seeing odd readings from your power system.",
		"text": "A dust grain hit the ship at 20 km/s. One power line now reads low.",
		"real": "In May 2022 a micrometeoroid hit a mirror of the James Webb Space Telescope harder than planned for (NASA/ESA/CSA).",
		"choices": [
			{"label": "REWIRE AROUND IT", "text": "3 days of tests and $2M. Full power back.",
				"cost": {"days": 3, "money": 2.0}},
			{"label": "LIVE WITH IT", "text": "Lose 6% of your power for good.",
				"cost": {"power": 0.94}},
		]},
	{"id": "antenna_stuck", "phase": "cruise", "from": "ship", "role": "comms", "needs_part": "hga", "title": "DISH WILL NOT OPEN", "intro": "The big dish should be open by now. Its sensors say something else.",
		"text": "The big dish is stuck half open, like a broken umbrella.",
		"real": "Galileo's main antenna jammed in 1991. NASA saved the Jupiter mission with the small antenna and new software.",
		"choices": [
			{"label": "SHAKE IT LOOSE", "text": "60% it opens. 40% the radio stays 35% slower.",
				"risk": {"chance": 0.4, "bad": {"rate": 0.65}}},
			{"label": "NEW SOFTWARE", "text": "10 days of work, then the radio is 20% slower.",
				"cost": {"days": 10, "rate": 0.8}},
		]},
	{"id": "units", "phase": "cruise", "from": "ship", "role": "planner", "title": "THE NUMBERS DISAGREE", "intro": "Our flight dynamics teams are arguing about your next burn.",
		"text": "Two teams got different answers for the next burn. One used the wrong units.",
		"real": "Mars Climate Orbiter was lost in 1999: one team worked in pound-seconds, the other in newton-seconds (NASA).",
		"choices": [
			{"label": "RE-CHECK EVERYTHING", "text": "Both teams check every number: 4 days and $2M.",
				"cost": {"days": 4, "money": 2.0}},
			{"label": "TRUST THE PLAN", "text": "35% chance you need a 20 m/s fix-up burn.",
				"risk": {"chance": 0.35, "bad": {"dv_ms": 20.0}}},
		]},
	{"id": "receiver", "phase": "cruise", "from": "ship", "role": "comms", "dests": ["mercury", "venus", "jupiter", "saturn", "uranus", "neptune"], "title": "MAIN RECEIVER IS DEAD", "intro": "Your ship has gone quiet on our commands. Checking the radio now.",
		"text": "The ship stopped hearing Earth. The backup receiver only hears one exact tone.",
		"real": "Voyager 2 lost its main receiver in 1978. NASA has tuned every command to the half-deaf backup ever since.",
		"choices": [
			{"label": "TUNE EVERY COMMAND", "text": "Slow but safe: 12 days.",
				"cost": {"days": 12}},
			{"label": "RESET THE MAIN ONE", "text": "50% it wakes up. 50% the radio is 25% slower.",
				"risk": {"chance": 0.5, "bad": {"rate": 0.75}}},
		]},
	{"id": "hot_electronics", "phase": "cruise", "from": "ship", "role": "engineer", "dests": ["mercury", "venus"], "title": "ELECTRONICS RUN HOT", "intro": "Your computer's temperature keeps climbing. We are watching it.",
		"text": "This close to the Sun the computer is too hot and starts making errors.",
		"real": "The front of MESSENGER's sunshade ran above 300 C while the craft behind it stayed near room temperature (NASA).",
		"choices": [
			{"label": "KEEP WORKING", "text": "25% chance the heat kills one instrument.",
				"risk": {"chance": 0.25, "bad": {"break": "science"}, "save_part": "sunshade"}},
			{"label": "SAFE MODE", "text": "Switch most things off for 6 days.",
				"cost": {"days": 6}},
		]},
	{"id": "wheel", "phase": "cruise", "from": "ship", "role": "engineer", "title": "A REACTION WHEEL FAILS", "intro": "Your ship is wobbling. We are seeing odd readings from its pointing.",
		"text": "One of the spinning wheels that point the ship has stopped.",
		"real": "Dawn lost reaction wheels in 2010 and 2012. NASA flew on with two wheels plus thrusters: 'hybrid control'.",
		"choices": [
			{"label": "USE THRUSTERS", "text": "Point with thrusters: a 10 m/s burn.",
				"cost": {"dv_ms": 10.0}},
			{"label": "NEW SOFTWARE", "text": "Mix wheels and thrusters: 8 days.",
				"cost": {"days": 8}},
		]},
	# ------------------------------------------------------------------ on the way: messages from Earth
	{"id": "update", "phase": "cruise", "from": "earth", "role": "science", "title": "NEW SOFTWARE READY", "intro": "A message from the software team just came in.",
		"text": "We have an update that makes your instruments sharper. Install it?",
		"real": "Days after landing in 2012, NASA sent Curiosity new software for driving on Mars: a four-day 'brain transplant'.",
		"choices": [
			{"label": "INSTALL IT", "text": "Takes 2 days: +3 science.",
				"cost": {"days": 2}, "gain": {"score": 3}},
			{"label": "NOT NOW", "text": "Keep flying as you are.",
				"cost": {}},
		]},
	{"id": "trim", "phase": "cruise", "from": "earth", "role": "planner", "title": "SMALL COURSE FIX", "intro": "A message from our navigators just came in.",
		"text": "Our navigators see the ship drifting a little off course.",
		"real": "Every deep-space craft makes small course fixes on the way. Perseverance made several on its way to Mars (NASA).",
		"choices": [
			{"label": "FIX IT NOW", "text": "A small 3 m/s burn.",
				"cost": {"dv_ms": 3.0}},
			{"label": "FIX IT LATER", "text": "50% it is fine. 50% it needs a 6 m/s burn.",
				"risk": {"chance": 0.5, "bad": {"dv_ms": 6.0}}},
		]},
	{"id": "earth_photo", "phase": "cruise", "from": "earth", "role": "science", "title": "A PHOTO OF HOME?", "intro": "A message from a school outreach team just came in.",
		"text": "Students ask for a picture of Earth from deep space. Can you take one?",
		"real": "In 1990 Voyager 1 turned round and took the 'Pale Blue Dot' photo of Earth from 6 billion km away (NASA).",
		"choices": [
			{"label": "TAKE THE PHOTO", "needs_part": "camera", "text": "Turn the camera back: +2 science.",
				"cost": {}, "gain": {"score": 2}},
			{"label": "STAY ON TASK", "text": "Keep the camera on the mission.",
				"cost": {}},
		]},
	# ------------------------------------------------------------------ at the site: ship hazards
	{"id": "stuck_wheel", "phase": "site", "from": "ship", "role": "science", "dests": ["moon", "mars", "mercury"], "needs_part": ["rover", "rover_big"], "title": "WHEEL STUCK IN SAND", "intro": "Your rover has stopped moving, but its motors are still running.",
		"text": "The rover broke through a crust into loose sand. One wheel just spins.",
		"real": "NASA's Spirit broke into soft sand at 'Troy' on Mars in 2009. It never got out.",
		"choices": [
			{"label": "BACK OUT SLOWLY", "text": "Small careful moves: 3 days.",
				"cost": {"days": 3}},
			{"label": "FULL POWER", "text": "60% it is free. 40% it costs 20% of the battery.",
				"risk": {"chance": 0.4, "bad": {"battery_pct": 20.0}}},
		]},
	{"id": "reboot", "phase": "site", "from": "ship", "role": "comms", "kinds": ["land"], "title": "COMPUTER KEEPS REBOOTING", "intro": "We keep losing the lander's signal for a few seconds at a time.",
		"text": "The lander's computer restarts again and again. Part of its memory is damaged.",
		"real": "In Feb 2013 Curiosity's computer showed corrupted flash memory. NASA switched the rover to its backup computer.",
		"choices": [
			{"label": "WIPE THE MEMORY", "text": "Fast, but 20% of the stored data is lost.",
				"cost": {"data_pct": 20.0}},
			{"label": "FIX IT STEP BY STEP", "text": "Keep the data. Uses 15% of the battery.",
				"cost": {"battery_pct": 15.0}},
		]},
	{"id": "tipped", "phase": "site", "from": "ship", "role": "engineer", "dests": ["moon"], "title": "LANDER LEANS: NO SUN", "intro": "The lander is down, but its power readings look low.",
		"text": "The lander came to rest tilted. Its solar panels miss the Sun.",
		"real": "Odysseus landed on the Moon in Feb 2024 and tipped over, resting about 30 degrees tilted. It still sent data.",
		"choices": [
			{"label": "WAIT FOR THE SUN", "text": "Sleep until the Sun moves round: 5 days.",
				"cost": {"days": 5}},
			{"label": "WORK ON BATTERY", "text": "Do the work now: 20% of the battery.",
				"cost": {"battery_pct": 20.0}},
		]},
	{"id": "dust_storm", "phase": "site", "from": "ship", "role": "engineer", "dests": ["mars"], "title": "DUST STORM", "intro": "The sky over your site is getting darker on our images.",
		"text": "A storm is turning day into night. The solar panels make almost nothing.",
		"real": "A 2018 dust storm blocked the Sun for four months and ended NASA's solar-powered rover Opportunity.",
		"choices": [
			{"label": "SLEEP THROUGH IT", "text": "Heaters only: 10 days.",
				"cost": {"days": 10}},
			{"label": "KEEP WORKING", "text": "50% it passes soon. 50% it costs 35% of the battery.",
				"risk": {"chance": 0.5, "bad": {"battery_pct": 35.0}}},
		]},
	{"id": "hull_heat", "phase": "site", "from": "ship", "role": "engineer", "dests": ["venus"], "title": "IT IS GETTING HOT INSIDE", "intro": "Temperatures inside your lander are rising on our screens.",
		"text": "The inside of the hull is warming faster than planned.",
		"real": "Venera 13 and 14 sent data from the surface of Venus for 127 and 57 minutes in 1982, until heat ended it (USSR).",
		"choices": [
			{"label": "SHUT ONE THING DOWN", "text": "Less heat: one instrument goes off for good.",
				"cost": {"break": "science"}},
			{"label": "RACE THE CLOCK", "text": "Keep everything on: lose 12 minutes.",
				"cost": {"minutes": 12.0}},
		]},
	{"id": "ring_cross", "phase": "site", "from": "ship", "role": "engineer", "kinds": ["ring"], "title": "RING PLANE CROSSING", "intro": "Your orbit is about to take you through the ring plane.",
		"text": "The orbit crosses the ring plane. Dust grains will hit at 20 km/s.",
		"real": "In April 2017 Cassini dived between Saturn and its rings with its 4 m dish turned forward as a shield (NASA).",
		"choices": [
			{"label": "RAISE THE ORBIT", "text": "Cross where the dust is thin: an 8 m/s burn.",
				"cost": {"dv_ms": 8.0}},
			{"label": "FLY STRAIGHT ON", "text": "20% chance a grain breaks an instrument.",
				"risk": {"chance": 0.2, "bad": {"break": "science"}}},
		]},
	{"id": "deaf_relay", "phase": "site", "from": "ship", "role": "comms", "kinds": ["ring"], "needs_part": "drone", "title": "ORBITER CANNOT HEAR DRONE", "intro": "We are seeing gaps in the drone's signal at the orbiter.",
		"text": "The orbiter loses the drone's signal when the two pass each other fast.",
		"real": "In 2000 a test showed Cassini could not hear its Huygens probe. A new flight path fixed it, at a cost in fuel (ESA/NASA).",
		"choices": [
			{"label": "SEND IT SLOWER", "text": "A slow signal gets through: 2 days.",
				"cost": {"days": 2}},
			{"label": "FLY AS PLANNED", "text": "25% chance some drone data is lost: -3 science.",
				"risk": {"chance": 0.25, "bad": {"score": -3}}},
		]},
	# ------------------------------------------------------------------ at the site: messages from Earth
	{"id": "odd_rock", "phase": "site", "from": "earth", "role": "science", "kinds": ["land"], "title": "WE SPOTTED SOMETHING", "intro": "A message from the science team just came in.",
		"text": "Scientists saw an odd, shiny rock near you in the last pictures. Take a look?",
		"real": "In 2005 Opportunity found 'Heat Shield Rock', the first meteorite ever seen on another planet (NASA).",
		"choices": [
			{"label": "GO AND LOOK", "text": "A short detour: 10% of the battery, +4 science.",
				"cost": {"battery_pct": 10.0}, "gain": {"score": 4}},
			{"label": "STAY ON PLAN", "text": "Keep to the plan.",
				"cost": {}},
		]},
	{"id": "dsn_slot", "phase": "site", "from": "earth", "role": "comms", "kinds": ["land"], "title": "A BIG DISH IS FREE", "intro": "A message from the Deep Space Network schedulers just came in.",
		"text": "A big dish on Earth is free tonight. Send your data early?",
		"real": "NASA's Deep Space Network has big dishes in California, Spain and Australia, so one always faces the ship.",
		"choices": [
			{"label": "SEND IT NOW", "text": "Uses 5% of the battery: +2 science.",
				"cost": {"battery_pct": 5.0}, "gain": {"score": 2}},
			{"label": "SEND IT LATER", "text": "Keep the battery for the work.",
				"cost": {}},
		]},
	{"id": "ring_tip", "phase": "site", "from": "earth", "role": "science", "kinds": ["ring"], "title": "ONE MORE LOOK?", "intro": "A message from the ring science team just came in.",
		"text": "Scientists ask for one extra pass near a bright clump in the ring.",
		"real": "In 2017 Cassini flew close to Saturn's rings and photographed 'propellers' stirred up by hidden moonlets (NASA).",
		"choices": [
			{"label": "FLY THE PASS", "text": "A 4 m/s burn: +4 science.",
				"cost": {"dv_ms": 4.0}, "gain": {"score": 4}},
			{"label": "NO THANKS", "text": "Keep to the plan.",
				"cost": {}},
		]},
]

## Effect keys a choice can only take when the ship can pay: the rest are always open.
const PAID_KEYS: Array = ["dv_ms", "fuel_kg", "battery_pct", "battery_wh", "money"]
const ROLE_WORD: Dictionary = {"planner": "PLANNER", "engineer": "ENGINEER", "science": "SCIENTIST", "comms": "COMMS OFFICER"}

static func by_id(id: String) -> Dictionary:
	for ev: Dictionary in LIST:
		if ev["id"] == id:
			return ev
	return {}

## True when `build` carries the part (or any part of a list).
static func has_part(build: Dictionary, part: Variant) -> bool:
	if part is Array:
		for p: String in part:
			if int(build.get(p, 0)) > 0:
				return true
		return false
	return int(build.get(String(part), 0)) > 0

## Can this event happen on a flight to `dest` (a Data.DEST entry) with this ship?
static func eligible(ev: Dictionary, phase: String, dest_id: String, dest: Dictionary, build: Dictionary) -> bool:
	if ev["phase"] != phase:
		return false
	if ev.has("kinds") and not (ev["kinds"] as Array).has(dest["kind"]):
		return false
	if ev.has("dests") and not (ev["dests"] as Array).has(dest_id):
		return false
	if ev.has("jobs") and not (ev["jobs"] as Array).has(String(dest.get("job", "drill"))):
		return false
	if ev.has("returns") and bool(ev["returns"]) != bool(dest["returns"]):
		return false
	if ev.has("needs_part") and not has_part(build, ev["needs_part"]):
		return false
	return true
