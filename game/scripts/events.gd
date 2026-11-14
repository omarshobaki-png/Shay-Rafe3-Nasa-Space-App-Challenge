extends RefCounted
## Decision events: things that really happened to real spacecraft, turned into a choice.
## Data and pure helpers only. The engine that rolls and applies them is in scripts/game.gd
## (Game.event_plan, Game.next_event, Game.event_choice, Game.resolve_event); the pop-up is scripts/event_card.gd.
##
## Event:  id, phase ("cruise" | "site" | "home"), role, title (<= 28), text (<= 150), real (<= 140), choices (2 or 3)
##   filters, all optional: kinds [..], dests [..], needs_part id or [ids: any one of them],
##                          returns bool (true: only where samples fly home; false: only where they do not)
## Choice: label (<= 22), text (<= 90, the price or the odds in numbers), and any of
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
##   fail       text: the mission ends
## Every number in a choice text is a game rule; the "real" line is the fact. The number in the comment after
## each "real" line is its entry in research/v5/events.md (57 verified incidents).

const LIST: Array = [
	# ------------------------------------------------------------------ on the way
	{"id": "storm", "phase": "cruise", "role": "engineer", "title": "SOLAR STORM INCOMING",
		"text": "The Sun has thrown a cloud of charged particles at the ship. It arrives in hours and can damage electronics.",
		"real": "In Oct 2003 a solar storm killed the MARIE radiation instrument on NASA's Mars Odyssey.",  # 2
		"choices": [
			{"label": "TURN TAIL TO THE STORM", "text": "Hide the electronics behind the engine: a 10 m/s turn burn and 2 days lost.",
				"cost": {"dv_ms": 10.0, "days": 2}},
			{"label": "KEEP WORKING", "text": "{pct}% chance an instrument or the antenna is damaged. Radiation shielding stops it.",
				"risk": {"chance": 0.5, "bad": {"break": "electronics"}, "save_part": "shield"}},
		]},
	{"id": "micro", "phase": "cruise", "role": "engineer", "title": "MICROMETEOROID HIT",
		"text": "A dust grain smaller than sand hit the ship at 20 km/s. One power line now reads low.",
		"real": "In May 2022 a micrometeoroid hit a mirror of the James Webb Space Telescope harder than planned for (NASA/ESA/CSA).",  # 53
		"choices": [
			{"label": "REWIRE AROUND IT", "text": "Engineers re-route the power: 5 days of tests and $3M. Full power back.",
				"cost": {"days": 5, "money": 3.0}},
			{"label": "LIVE WITH IT", "text": "Lose 12% of your power for good. Fine if you carry a power margin.",
				"cost": {"power": 0.88}},
		]},
	{"id": "antenna_stuck", "phase": "cruise", "role": "comms", "needs_part": "hga", "title": "DISH WILL NOT OPEN",
		"text": "The big dish is stuck half open, like a broken umbrella. Without it the ship can only whisper to Earth.",
		"real": "Galileo's main antenna jammed in 1991. NASA saved the Jupiter mission with the small antenna and new software.",  # 3
		"choices": [
			{"label": "SHAKE IT LOOSE", "text": "Pulse the motor again and again. 40% it opens. 60% it jams for good: radio x0.3.",
				"risk": {"chance": 0.6, "bad": {"rate": 0.3}}},
			{"label": "NEW SOFTWARE", "text": "Squeeze the data instead: 20 days of work, then radio x0.6 for sure.",
				"cost": {"days": 20, "rate": 0.6}},
		]},
	{"id": "units", "phase": "cruise", "role": "planner", "title": "THE NUMBERS DISAGREE",
		"text": "Two teams get different answers for the next course burn. One of them is using the wrong units.",
		"real": "Mars Climate Orbiter was lost in 1999: one team worked in pound-seconds, the other in newton-seconds (NASA).",  # 33
		"choices": [
			{"label": "STOP AND RE-CHECK", "text": "Both teams go through every number: 7 days and $4M.",
				"cost": {"days": 7, "money": 4.0}},
			{"label": "EXTRA TRACKING BURN", "text": "Track the ship closely and fix the path with a 15 m/s burn.",
				"cost": {"dv_ms": 15.0}},
			{"label": "TRUST THE PLAN", "text": "Costs nothing. 35% chance the ship arrives too low and is lost.",
				"risk": {"chance": 0.35, "bad": {"fail": "LOST ON ARRIVAL. The course burn used the wrong units and the ship came in too low. Nobody re-checked the numbers."}}},
		]},
	{"id": "receiver", "phase": "cruise", "role": "comms", "dests": ["mercury", "venus", "jupiter", "saturn", "uranus", "neptune"], "title": "MAIN RECEIVER IS DEAD",
		"text": "The ship stopped hearing Earth. The backup receiver works, but only on one exact frequency that drifts.",
		"real": "Voyager 2 lost its main receiver in 1978. NASA has tuned every command to the half-deaf backup ever since.",  # 13
		"choices": [
			{"label": "TUNE EVERY COMMAND", "text": "Measure the drift before each message. Slow and safe: 25 days.",
				"cost": {"days": 25}},
			{"label": "RESET THE MAIN ONE", "text": "50% it wakes up. 50% the surge hurts the radio: radio x0.5 and 10 days.",
				"risk": {"chance": 0.5, "bad": {"rate": 0.5, "days": 10}}},
		]},
	{"id": "shade_burn", "phase": "cruise", "role": "engineer", "dests": ["mercury"], "title": "BURN POINTS AT THE SUN",
		"text": "The next course burn needs the engine facing away from the Sun. That turns the ship out from behind its sunshade.",
		"real": "MESSENGER's sunshade had to stay within 12 degrees of the Sun at all times. Some pointings were never allowed (NASA).",  # 20
		"choices": [
			{"label": "BURN IN TWO PARTS", "text": "Stay in the shade and burn at a bad angle: costs a 25 m/s burn.",
				"cost": {"dv_ms": 25.0}},
			{"label": "TURN OUT, BURN FAST", "text": "45% chance the Sun cooks one instrument in the minutes it takes.",
				"risk": {"chance": 0.45, "bad": {"break": "science"}}},
			{"label": "WAIT FOR THE ANGLE", "text": "Let the orbit bring a better angle: 40 days lost.",
				"cost": {"days": 40}},
		]},
	{"id": "hot_electronics", "phase": "cruise", "role": "engineer", "dests": ["venus"], "title": "ELECTRONICS RUN HOT",
		"text": "This close to the Sun the computer is 15 C over its limit and starting to make errors.",
		"real": "The front of MESSENGER's sunshade ran above 300 C while the craft behind it stayed near room temperature (NASA).",  # 20
		"choices": [
			{"label": "KEEP WORKING", "text": "50% chance heat kills one instrument. A sunshade on board removes the risk.",
				"risk": {"chance": 0.5, "bad": {"break": "science"}, "save_part": "sunshade"}},
			{"label": "HIDE BEHIND THE DISH", "needs_part": "hga", "text": "Point the high-gain dish at the Sun as a shade: 6 days with no radio.",
				"cost": {"days": 6}},
			{"label": "COOL DOWN IN SAFE MODE", "text": "Switch most things off for 12 days. Ground crews cost $3M.",
				"cost": {"days": 12, "money": 3.0}},
		]},
	{"id": "wheel", "phase": "cruise", "role": "engineer", "dests": ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"], "title": "A REACTION WHEEL FAILS",
		"text": "One of the spinning wheels that point the ship has seized. The others are the same model.",
		"real": "Dawn lost reaction wheels in 2010 and 2012. NASA flew on with two wheels plus thrusters: 'hybrid control'.",  # 51
		"choices": [
			{"label": "POINT WITH THRUSTERS", "text": "Rest the wheels. Costs fuel worth a 20 m/s burn over the trip.",
				"cost": {"dv_ms": 20.0}},
			{"label": "HYBRID MODE", "text": "New software mixes wheels and thrusters: 15 days and $5M.",
				"cost": {"days": 15, "money": 5.0}},
			{"label": "RUN THE OTHER WHEELS", "text": "Free. 35% chance a second wheel dies and the dish cannot point: radio x0.4.",
				"risk": {"chance": 0.35, "bad": {"rate": 0.4}}},
		]},
	{"id": "tumble", "phase": "cruise", "role": "engineer", "dests": ["moon"], "title": "THE SHIP IS TUMBLING",
		"text": "A thruster valve stuck open during a course burn. The ship is spinning and the solar panels cannot hold the Sun.",
		"real": "CAPSTONE tumbled for weeks on its way to the Moon in 2022: a thruster valve was stuck partly open (NASA).",  # 30
		"choices": [
			{"label": "FIRE AGAINST THE SPIN", "text": "Stop it now with the other thrusters: a 20 m/s burn.",
				"cost": {"dv_ms": 20.0}},
			{"label": "WARM THE VALVE, WAIT", "text": "Heaters may free it. 30% chance the battery runs half down first.",
				"risk": {"chance": 0.3, "bad": {"battery_pct": 50.0}}},
		]},
	{"id": "sun_push", "phase": "cruise", "role": "planner", "dests": ["mercury", "venus"], "title": "SUNLIGHT PUSHES THE SHIP",
		"text": "This close to the Sun, the push of sunlight on the panels keeps turning the ship. Holding its aim burns steering gas fast.",
		"real": "Kepler lost its second reaction wheel in 2013. NASA balanced it against the push of sunlight and flew on as K2.",  # 55
		"choices": [
			{"label": "BALANCE ON SUNLIGHT", "needs_part": "solar", "text": "Tilt the solar panels until the push evens out. Slow to set up: 8 days.",
				"cost": {"days": 8}},
			{"label": "BURN TO HOLD COURSE", "text": "Use main-engine fuel instead: a 20 m/s burn.",
				"cost": {"dv_ms": 20.0}},
			{"label": "DRIFT AND FIX LATER", "text": "50% nothing happens. 50% you drift far off and need a 45 m/s burn.",
				"risk": {"chance": 0.5, "bad": {"dv_ms": 45.0}}},
		]},
	{"id": "valve_engine", "phase": "cruise", "role": "engineer", "dests": ["mercury", "venus", "mars", "jupiter", "saturn", "uranus", "neptune"], "title": "ENGINE VALVE CLOGGED",
		"text": "A fuel valve in the main engine is sticking. A full-power burn could overheat and crack the nozzle.",
		"real": "Akatsuki's engine failed at Venus in 2010 and it flew past. JAXA got it into orbit in 2015 on small thrusters.",  # 23
		"choices": [
			{"label": "SMALL THRUSTERS ONLY", "text": "Safe but wasteful: costs fuel worth a 30 m/s burn.",
				"cost": {"dv_ms": 30.0}},
			{"label": "TEST THE MAIN ENGINE", "text": "A 10-day test. 70% it holds and nothing is lost. 30% it cracks: a 40 m/s burn.",
				"cost": {"days": 10}, "risk": {"chance": 0.3, "bad": {"dv_ms": 40.0}}},
		]},
	{"id": "bepi_thrust", "phase": "cruise", "role": "planner", "dests": ["mercury"], "title": "THRUSTERS LOSE POWER",
		"text": "A power fault leaves the engines at 90% thrust. On the planned path the ship will miss its arrival date.",
		"real": "BepiColombo's thrusters lost power in 2024. ESA designed a new path and moved the arrival to November 2026.",  # 22
		"choices": [
			{"label": "FLY THE LONGER PATH", "text": "Arrive later with the thrust you have: 330 days lost.",
				"cost": {"days": 330}},
			{"label": "BURN CHEMICAL FUEL", "text": "Make up the thrust with the main engine: a 35 m/s burn.",
				"cost": {"dv_ms": 35.0}},
		]},
	# ------------------------------------------------------------------ on the ground
	{"id": "tipped", "phase": "site", "role": "engineer", "dests": ["moon"], "title": "LANDER LEANS: NO SUN",
		"text": "The lander came to rest tilted. Its solar panels face away from the Sun and the battery is draining.",
		"real": "Odysseus landed on the Moon in Feb 2024 and tipped over, resting about 30 degrees tilted. It still sent data.",  # 31
		"choices": [
			{"label": "SLEEP UNTIL SUNLIGHT", "text": "Switch off and wait for the Sun to swing round: 9 days lost.",
				"cost": {"days": 9}},
			{"label": "WORK ON BATTERY NOW", "text": "Do the science at once. Uses 45% of the battery.",
				"cost": {"battery_pct": 45.0}},
			{"label": "RUN ON NUCLEAR POWER", "needs_part": "rtg", "text": "Your nuclear battery does not need the Sun. No cost.",
				"cost": {}},
		]},
	{"id": "sharp_rocks", "phase": "site", "role": "science", "dests": ["moon", "mars", "mercury"], "needs_part": ["rover", "rover_big"], "title": "SHARP ROCKS AHEAD",
		"text": "The shortest way to the next sample crosses a field of pointed rocks that can tear the rover's thin wheels.",
		"real": "From 2013 sharp rocks punctured Curiosity's wheels. NASA re-planned its routes and taught it to drive softly.",  # 41
		"choices": [
			{"label": "GO AROUND", "text": "The long way on smooth ground: 2 days and 15% of the battery.",
				"cost": {"days": 2, "battery_pct": 15.0}},
			{"label": "DRIVE SOFTLY", "text": "Creep across, one wheel at a time: 5 days.",
				"cost": {"days": 5}},
			{"label": "STRAIGHT ACROSS", "text": "60% no harm. 40% a torn wheel drags and drains 35% of the battery.",
				"risk": {"chance": 0.4, "bad": {"battery_pct": 35.0}}},
		]},
	{"id": "stuck_wheel", "phase": "site", "role": "science", "dests": ["moon", "mars", "mercury"], "needs_part": ["rover", "rover_big"], "title": "WHEEL STUCK IN SOFT SOIL",
		"text": "The rover broke through a crust into loose sand. One wheel spins without grip and is digging itself in.",
		"real": "NASA's Spirit dragged a dead wheel from 2006, then broke into soft sand at 'Troy' in 2009. It never got out.",  # 37
		"choices": [
			{"label": "BACK OUT SLOWLY", "text": "Small careful moves: 6 days and 15% of the battery.",
				"cost": {"days": 6, "battery_pct": 15.0}},
			{"label": "FULL POWER", "text": "60% it is free at once. 40% it digs in deeper and drains 40% of the battery.",
				"risk": {"chance": 0.4, "bad": {"battery_pct": 40.0}}},
			{"label": "STUDY THE DUG-UP SOIL", "text": "Stay 4 days and look at what the wheel dug up: 10% battery, +6 science.",
				"cost": {"days": 4, "battery_pct": 10.0}, "gain": {"score": 6}},
		]},
	{"id": "dust_storm", "phase": "site", "role": "engineer", "dests": ["mars"], "title": "DUST STORM COVERS THE SKY",
		"text": "A storm is turning day into night. Solar panels will make almost nothing for weeks.",
		"real": "A 2018 dust storm blocked the Sun for four months and ended NASA's solar-powered rover Opportunity.",  # 38
		"choices": [
			{"label": "SLEEP THROUGH IT", "text": "Heaters only: 20 days lost and 35% of the battery.",
				"cost": {"days": 20, "battery_pct": 35.0}},
			{"label": "KEEP DRIVING", "text": "50% the storm passes early. 50% the battery drops by 70%.",
				"risk": {"chance": 0.5, "bad": {"battery_pct": 70.0}}},
			{"label": "RUN ON NUCLEAR POWER", "needs_part": "rtg", "text": "Your nuclear battery does not need the Sun. No cost.",
				"cost": {}},
		]},
	{"id": "dusty_panels", "phase": "site", "role": "engineer", "dests": ["mars"], "needs_part": ["solar", "solar_lite"], "title": "DUST ON THE PANELS",
		"text": "Dust has settled on the solar arrays. Power is falling a little more every day.",
		"real": "NASA's InSight sprinkled sand on its dusty solar panels on windy days: the falling grains swept dust off.",  # 40
		"choices": [
			{"label": "TRICKLE SAND ON THEM", "needs_part": "drill", "text": "Use the arm: 3 days. 30% chance it fails and you lose 20% of your power.",
				"cost": {"days": 3}, "risk": {"chance": 0.3, "bad": {"power": 0.8}}},
			{"label": "SWITCH ONE THING OFF", "text": "Turn one instrument off for good to save power.",
				"cost": {"break": "science"}},
			{"label": "ACCEPT LESS POWER", "text": "Lose 25% of your power for good. Fine if you carry a power margin.",
				"cost": {"power": 0.75}},
		]},
	{"id": "sample_tube", "phase": "site", "role": "science", "dests": ["mars", "mercury"], "needs_part": "drill", "title": "THE SAMPLE TUBE IS EMPTY",
		"text": "The drill went in, but the rock crumbled to powder and the tube came up empty.",
		"real": "Perseverance's first Mars sample tube came up empty in Aug 2021: the rock crumbled. NASA drove on to harder rock.",  # 43
		"choices": [
			{"label": "DRILL HERE AGAIN", "text": "50% it works this time. 50% it crumbles again and wastes 25% of the battery.",
				"risk": {"chance": 0.5, "bad": {"battery_pct": 25.0}}},
			{"label": "DRIVE TO HARDER ROCK", "text": "A safe new spot: 4 days and 15% of the battery.",
				"cost": {"days": 4, "battery_pct": 15.0}},
		]},
	{"id": "reboot", "phase": "site", "role": "comms", "kinds": ["land"], "title": "COMPUTER KEEPS REBOOTING",
		"text": "The lander's computer restarts again and again. Part of its flash memory is corrupted.",
		"real": "In Feb 2013 Curiosity's computer showed corrupted flash memory. NASA switched the rover to its backup computer.",  # 42
		"choices": [
			{"label": "WIPE THE MEMORY", "text": "Fast and sure, but 40% of the science stored on board is deleted.",
				"cost": {"data_pct": 40.0}},
			{"label": "DEBUG IT STEP BY STEP", "text": "Keep the data. Awake all night: uses 30% of the battery.",
				"cost": {"battery_pct": 30.0}},
			{"label": "BOOT FROM THE RECORDER", "needs_part": "recorder", "text": "Your data recorder holds a clean copy. No cost.",
				"cost": {}},
		]},
	{"id": "venera_cap", "phase": "site", "role": "science", "dests": ["venus"], "title": "LENS CAP UNDER THE ARM",
		"text": "The camera's lens cap popped off and landed exactly where the soil-testing arm comes down.",
		"real": "Venera 14 (1982) dropped its lens cap right where its soil probe came down, and may have measured the cap (USSR).",  # 24
		"choices": [
			{"label": "MOVE THE ARM ASIDE", "text": "Re-aim the arm by radio. Costs 15 of your minutes on the surface.",
				"cost": {"minutes": 15.0}},
			{"label": "TEST IT ANYWAY", "text": "No time lost, but this soil test is worthless: -6 science.",
				"cost": {"score": -6}},
		]},
	{"id": "hull_heat", "phase": "site", "role": "engineer", "dests": ["venus"], "title": "INSIDE TEMPERATURE CLIMBS",
		"text": "The inside of the hull is warming faster than planned. The electronics will overheat sooner.",
		"real": "Venera 13 and 14 sent data from the surface of Venus for 127 and 57 minutes in 1982, until heat ended it (USSR).",  # 24
		"choices": [
			{"label": "SHUT DOWN ONE SYSTEM", "text": "Less heat inside: one instrument goes off for good.",
				"cost": {"break": "science"}},
			{"label": "RACE THE CLOCK", "text": "Keep everything on. You lose 25 minutes of surface time.",
				"cost": {"minutes": 25.0}},
		]},
	{"id": "mercury_noon", "phase": "site", "role": "science", "dests": ["mercury"], "title": "NOON IS COMING",
		"text": "The Sun climbs higher every hour. By noon the ground under the rover will reach 430 C.",
		"real": "Mercury's ground reaches 430 C by day and falls to -180 C at night (NASA).",  # destinations.md, hazards
		"choices": [
			{"label": "WAIT IN THE SHADE", "text": "Park in a crater's shadow until the Sun drops: 12 days lost.",
				"cost": {"days": 12}},
			{"label": "WORK THROUGH NOON", "text": "45% chance the heat kills one instrument.",
				"risk": {"chance": 0.45, "bad": {"break": "science"}}},
			{"label": "DRIVE INTO THE DARK", "text": "Cross to the night side, -180 C: 25% of the battery, +8 science.",
				"cost": {"battery_pct": 25.0}, "gain": {"score": 8}},
		]},
	# ------------------------------------------------------------------ in orbit at the rings
	{"id": "ring_cross", "phase": "site", "role": "engineer", "kinds": ["ring"], "title": "RING PLANE CROSSING",
		"text": "The orbit takes the ship through the ring plane. Dust grains will hit at 20 km/s.",
		"real": "In April 2017 Cassini dived between Saturn and its rings with its 4 m dish turned forward as a shield (NASA).",  # 11
		"choices": [
			{"label": "DISH FORWARD AS SHIELD", "needs_part": "hga", "text": "Safe, but no science and no radio during the pass: -3 science.",
				"cost": {"score": -3}},
			{"label": "INSTRUMENTS FORWARD", "text": "Taste the dust: +6 science. 35% chance a grain breaks an instrument.",
				"risk": {"chance": 0.35, "bad": {"break": "science"}}, "gain": {"score": 6}},
			{"label": "RAISE THE ORBIT", "text": "Cross where the dust is thin: a 15 m/s burn.",
				"cost": {"dv_ms": 15.0}},
		]},
	{"id": "juno_valve", "phase": "site", "role": "planner", "kinds": ["ring"], "title": "ENGINE VALVES ARE SLOW",
		"text": "Two helium valves took minutes to open instead of seconds. The burn to a closer orbit may misfire.",
		"real": "Juno's valves stuck in Oct 2016. NASA cancelled the burn and kept it in a 53-day orbit instead of 14 days.",  # 7
		"choices": [
			{"label": "STAY IN THE WIDE ORBIT", "text": "No burn, no risk. Every pass takes longer: 120 days more.",
				"cost": {"days": 120}},
			{"label": "BURN ANYWAY", "text": "65% it works. 35% the engine misfires and wastes fuel worth 40 m/s.",
				"risk": {"chance": 0.35, "bad": {"dv_ms": 40.0}}},
		]},
	{"id": "tape_stuck", "phase": "site", "role": "comms", "dests": ["jupiter"], "title": "DATA RECORDER JAMMED",
		"text": "The tape recorder ran 15 hours in rewind with the tape stuck. It may tear the next time it is used.",
		"real": "Galileo's tape recorder jammed in Oct 1995, weeks before Jupiter. NASA kept it alive with careful, gentle use.",  # 5
		"choices": [
			{"label": "USE IT GENTLY", "text": "Skip the first pictures to rest the tape: -5 science.",
				"cost": {"score": -5}},
			{"label": "RUN THE FULL PLAN", "text": "40% chance the tape tears and only live data gets home: radio x0.5.",
				"risk": {"chance": 0.4, "bad": {"rate": 0.5}}},
		]},
	{"id": "junocam", "phase": "site", "role": "science", "dests": ["jupiter"], "title": "CAMERA GOING BLIND",
		"text": "Radiation has damaged an instrument's sensor. Its pictures are filling with noise.",
		"real": "Radiation damaged Juno's camera in 2023. NASA baked it with its own heater and the pictures came back.",  # 8
		"choices": [
			{"label": "BAKE IT WITH A HEATER", "text": "Heat the sensor for 5 days. 70% it heals. 30% it dies.",
				"cost": {"days": 5}, "risk": {"chance": 0.3, "bad": {"break": "science"}}},
			{"label": "USE IT AS IT IS", "text": "Noisy data from now on: -5 science.",
				"cost": {"score": -5}},
		]},
	{"id": "scan_platform", "phase": "site", "role": "science", "dests": ["saturn", "uranus", "neptune"], "title": "CAMERA PLATFORM JAMMED",
		"text": "The turntable that aims the instruments has seized. It will not turn toward the rings.",
		"real": "Voyager 2's scan platform jammed at Saturn in 1981. NASA freed it with heat and cold, then moved it gently.",  # 14
		"choices": [
			{"label": "ROLL THE WHOLE SHIP", "text": "Aim by turning the spacecraft. Costs fuel worth a 12 m/s burn.",
				"cost": {"dv_ms": 12.0}},
			{"label": "MOVE IT VERY SLOWLY", "text": "Gentle, low-speed turns only: 14 days more.",
				"cost": {"days": 14}},
			{"label": "FORCE THE MOTOR", "text": "50% it frees. 50% it strips the gears and one instrument is lost.",
				"risk": {"chance": 0.5, "bad": {"break": "science"}}},
		]},
	{"id": "deaf_relay", "phase": "site", "role": "comms", "kinds": ["ring"], "needs_part": "drone", "title": "ORBITER CANNOT HEAR DRONE",
		"text": "A test shows the orbiter's receiver loses the drone's signal when the two fly fast past each other.",
		"real": "In 2000 a test showed Cassini could not hear its Huygens probe. A new flight path fixed it, at a cost in fuel (ESA/NASA).",  # 10
		"choices": [
			{"label": "CHANGE THE ORBIT", "text": "Fly a slower pass so the signal holds: a 15 m/s burn.",
				"cost": {"dv_ms": 15.0}},
			{"label": "SEND IT SLOWER", "text": "A slow signal gets through: 4 days more to hand the data over.",
				"cost": {"days": 4}},
			{"label": "FLY AS PLANNED", "text": "45% chance half of the drone's science never reaches the orbiter: -6 science.",
				"risk": {"chance": 0.45, "bad": {"score": -6}}},
		]},
	# ------------------------------------------------------------------ bringing samples home
	{"id": "tank", "phase": "home", "role": "engineer", "returns": true, "title": "TANK PRESSURE DROPS",
		"text": "A tank on the return stage is leaking. The capsule's power will not last the planned trip home.",
		"real": "An oxygen tank burst on Apollo 13 in 1970. The crew powered down the ship and burned an engine to steer home.",  # 29
		"choices": [
			{"label": "POWER DOWN, COAST HOME", "text": "Everything off but the radio. 30% of the stored science data is lost.",
				"cost": {"data_pct": 30.0}},
			{"label": "STEERING BURN", "text": "Burn onto a quicker, safer path home: a 30 m/s burn.",
				"cost": {"dv_ms": 30.0}},
			{"label": "CHANGE NOTHING", "text": "40% chance the capsule loses power and 2 samples are ruined.",
				"risk": {"chance": 0.4, "bad": {"samples": -2}}},
		]},
	{"id": "genesis", "phase": "home", "role": "planner", "returns": true, "title": "PARACHUTE SENSOR FAILS TEST",
		"text": "A last check says the capsule's parachute trigger may be fitted backwards. It cannot be seen from here.",
		"real": "NASA's Genesis capsule crashed in Utah in 2004: its gravity switches had been installed upside down.",  # 49
		"choices": [
			{"label": "REWRITE THE TIMER", "text": "Open the parachute by clock instead of by sensor: 3 days and $4M.",
				"cost": {"days": 3, "money": 4.0}},
			{"label": "TRUST THE DESIGN", "text": "45% chance the parachute stays shut and 2 samples are smashed.",
				"risk": {"chance": 0.45, "bad": {"samples": -2}}},
		]},
	{"id": "hayabusa", "phase": "home", "role": "engineer", "returns": true, "title": "FUEL LEAK ON THE WAY HOME",
		"text": "A leak is pushing the return stage off course and its main thruster is failing.",
		"real": "Japan's Hayabusa leaked fuel in 2005 and came home in 2010, 3 years late, on one engine made from two (JAXA).",  # 47
		"choices": [
			{"label": "TAKE THE LONG WAY HOME", "text": "Wait for the next good line-up with Earth: 60 days lost.",
				"cost": {"days": 60}},
			{"label": "PUSH THE LAST ENGINE", "text": "On time. 35% chance the engine dies and 2 samples are lost.",
				"risk": {"chance": 0.35, "bad": {"samples": -2}}},
			{"label": "CORRECT WITH FUEL", "text": "A 25 m/s burn puts the capsule back on course.",
				"cost": {"dv_ms": 25.0}},
		]},
	# ------------------------------------------------------------------ sending the science home
	{"id": "squeeze", "phase": "home", "role": "comms", "kinds": ["land"], "returns": false, "title": "THE LINK IS TOO SLOW",
		"text": "The radio link carries less than planned. At this rate not all the science gets home in time.",
		"real": "For Uranus in 1986 NASA taught Voyager 2 to squeeze its pictures and linked dishes on Earth: 3 times the data.",  # 15
		"choices": [
			{"label": "SQUEEZE THE DATA", "text": "Load new compression software first: 20 days.",
				"cost": {"days": 20}},
			{"label": "ACCEPT THE SLOW LINK", "text": "Send as it is: radio x0.6.",
				"cost": {"rate": 0.6}},
			{"label": "LINK MORE DISHES", "text": "Pay for more antennas on Earth to listen together: $10M.",
				"cost": {"money": 10.0}},
		]},
	{"id": "gyro", "phase": "home", "role": "engineer", "returns": false, "title": "A POINTING GYRO IS FAILING",
		"text": "One of the gyroscopes that keep the dish aimed at Earth gives faulty readings.",
		"real": "Hubble went to one-gyro mode in 2024 after a gyro gave faulty readings: about 12% less efficient (NASA).",  # 54
		"choices": [
			{"label": "ONE-GYRO MODE", "text": "Slower to point, but safe: radio x0.85.",
				"cost": {"rate": 0.85}},
			{"label": "KEEP USING ALL", "text": "Full speed. 30% chance another gyro fails in mid-pass: radio x0.5.",
				"risk": {"chance": 0.3, "bad": {"rate": 0.5}}},
		]},
	{"id": "faint", "phase": "home", "role": "comms", "kinds": ["ring"], "title": "SIGNAL TOO FAINT",
		"text": "From this far away your signal reaches Earth weaker than a watch battery could send. Words are being lost.",
		"real": "For Voyager 2 at Neptune in 1989, NASA linked its dishes to the 27 antennas of the Very Large Array.",  # 16
		"choices": [
			{"label": "LINK MORE DISHES", "text": "Rent a whole array of antennas to listen together: $12M.",
				"cost": {"money": 12.0}},
			{"label": "SEND IT SLOWER", "text": "Slower is clearer: radio x0.6.",
				"cost": {"rate": 0.6}},
			{"label": "SEND ONLY THE BEST", "text": "Throw away 40% of the science data and send the rest safely.",
				"cost": {"data_pct": 40.0}},
		]},
	{"id": "safe_mode", "phase": "home", "role": "engineer", "returns": false, "title": "COMPUTER OVERLOAD",
		"text": "The computer tried to do two big jobs at once and dropped into safe mode. The radio link is down.",
		"real": "New Horizons went into safe mode 10 days before Pluto in July 2015. NASA had it working again in 3 days.",  # 19
		"choices": [
			{"label": "FULL CAREFUL RESTART", "text": "Reload everything step by step: 4 days and $2M.",
				"cost": {"days": 4, "money": 2.0}},
			{"label": "QUICK RESTART", "text": "Back in hours. 30% chance half of the stored science is wiped.",
				"risk": {"chance": 0.3, "bad": {"data_pct": 50.0}}},
		]},
	{"id": "memory", "phase": "home", "role": "comms", "returns": false, "title": "MEMORY CHIP FAILED",
		"text": "The ship is sending garbled data. One memory chip has died and corrupted part of the computer's code.",
		"real": "Voyager 1 sent garbled data for 5 months in 2023-24. NASA split the code and moved it around the dead chip.",  # 17
		"choices": [
			{"label": "REWRITE AND MOVE CODE", "text": "Fit the code into the healthy memory, piece by piece: 30 days.",
				"cost": {"days": 30}},
			{"label": "SEND WHAT STILL WORKS", "text": "No waiting, but 40% of the science data stays garbled.",
				"cost": {"data_pct": 40.0}},
			{"label": "USE THE SPARE RECORDER", "needs_part": "recorder", "text": "Your data recorder takes over. No cost.",
				"cost": {}},
		]},
	{"id": "helium", "phase": "home", "role": "engineer", "dests": ["mercury"], "title": "RELAY ORBIT IS SINKING",
		"text": "The Sun's pull is dragging the relay orbiter down toward Mercury, and its fuel tanks read empty.",
		"real": "Out of fuel in 2015, MESSENGER raised its orbit with the helium gas that pressurised its tanks (NASA).",  # 21
		"choices": [
			{"label": "PUSH WITH TANK GAS", "text": "Vent the helium as a tiny rocket. 25% it is too weak: radio x0.6.",
				"risk": {"chance": 0.25, "bad": {"rate": 0.6}}},
			{"label": "SEND THE BEST DATA NOW", "text": "Send fast before it falls: 30% of the science is left behind.",
				"cost": {"data_pct": 30.0}},
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
	if ev.has("returns") and bool(ev["returns"]) != bool(dest["returns"]):
		return false
	if ev.has("needs_part") and not has_part(build, ev["needs_part"]):
		return false
	return true
