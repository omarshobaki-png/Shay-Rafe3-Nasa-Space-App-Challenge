extends Node
## Sound effects, engine loops, ambience and music. Files: res://audio/<name>.wav, all synthesized in code
## by tools/audio/make_sounds.py and make_music.py. A name with no file is silently ignored.
##
## The web build plays samples that bypass bus effects, so reverb and saturation are baked into the
## files and the mix is done here with plain volumes: one base level per group, music ducked under the
## big events, every loop and track faded in and out, a cap on big sounds, jingles kept apart.
##
##   Audio.play("part_snap")                      one-shot; takes part_snap_1.wav ... rotate by themselves
##   Audio.loop("thrust", burning, -5.0, 0.9 + 0.2 * throttle)   call every frame or on change
##   Audio.music("drift")                         crossfades; theme | hangar | ascent | drift | descent
##   Audio.scene("landing")                       main.gd calls it: music + ambience for the screen
##   button.set_meta("snd", "ui_tab")             that button plays ui_tab instead of click ("" = silent)

# Base volume of each group in dB. The files already sit in loudness classes (big -12 LUFS, mid -15,
# UI -20, loops -14, ambience -24, music -18), so these only place the groups against each other.
const VOL_UI: float = -2.0
const VOL_SFX: float = 0.0
const VOL_LOOP: float = 3.0       # callers pass -4 to -12 for loops
const VOL_AMB: float = -4.0
const VOL_MUSIC: float = -3.0
const VOL_MUSIC_PLAY: float = -3.0  # extra, on the screens where the player flies or drives
const DUCK_DB: float = -7.0
const XFADE: float = 0.6
const MAX_BIG: int = 2
const JINGLE_GAP_MS: int = 550

## Sounds that repeat a lot get about +-4% pitch and a little level change, so they never machine-gun.
const VARY: Array[String] = ["click", "ui_hover", "ui_tab", "ui_deny", "blip", "poll_blip", "radio_blip",
	"warn_alt", "part_pick", "part_snap", "part_remove", "part_deny", "rcs", "hit", "jump", "land",
	"drill_hit", "ice_ping", "explosion", "stage_sep"]
## Heavy sounds: at most MAX_BIG at once (a third one replaces the oldest).
const BIG: Array[String] = ["explosion", "launch", "ignition", "land", "stage_sep", "dock", "hit"]
## Tuned phrases: never two on the same frame (the second waits JINGLE_GAP_MS).
const JINGLES: Array[String] = ["success", "coin", "confirm", "error", "all_go", "arrive", "sting_win", "sting_fail"]
## Seconds the music stays ducked under an event.
const DUCK: Dictionary = {"launch": 4.6, "ignition": 1.0, "explosion": 1.8, "all_go": 1.3, "arrive": 1.4,
	"success": 1.2, "sting_win": 3.0, "sting_fail": 2.6, "cheer": 3.5}
const ALIAS: Dictionary = {"mission": "ascent"}
const AMB_BY_DEST: Dictionary = {"moon": "amb_moon", "mars": "amb_mars_wind", "saturn": "amb_saturn"}

## Two players that crossfade: one pair for the music, one for the ambience bed.
class Bed:
	var players: Array[AudioStreamPlayer] = []
	var gain: Array[float] = [0.0, 0.0]
	var on: int = -1

	func switch_to(st: AudioStreamWAV) -> void:
		if st == null:
			on = -1
			return
		for i: int in 2:
			if players[i].playing and players[i].stream == st:
				on = i  # still fading out: bring it back instead of restarting it
				return
		on = 0 if gain[0] <= gain[1] else 1
		gain[on] = 0.0
		players[on].stream = st
		players[on].volume_db = -60.0
		players[on].play()

	func tick(delta: float, vol_db: float, fade_s: float) -> void:
		for i: int in 2:
			gain[i] = move_toward(gain[i], 1.0 if i == on else 0.0, delta / fade_s)
			if not players[i].playing:
				continue
			if gain[i] <= 0.0 and i != on:
				players[i].stop()
			else:
				# square root = equal power: two different tracks keep their level through the crossfade
				players[i].volume_db = vol_db + linear_to_db(maxf(sqrt(gain[i]), 0.001))

class Loop:
	var player: AudioStreamPlayer = null
	var on: bool = false
	var gain: float = 0.0
	var vol_db: float = -4.0
	var onset: bool = false  # <name>.wav is a one-shot played over <name>_loop.wav when the loop starts

var pool: Array[AudioStreamPlayer] = []
var pool_ms: Array[int] = []
var pool_big: Array[bool] = []
var loops: Dictionary = {}
var cache: Dictionary = {}
var take_count: Dictionary = {}
var last_take: Dictionary = {}
var last_ms: Dictionary = {}
var music_bed: Bed = Bed.new()
var amb_bed: Bed = Bed.new()
var music_name: String = ""
var amb_name: String = ""
var music_scene_db: float = 0.0
var duck_db: float = 0.0
var duck_until_ms: int = 0
var jingle_free_ms: int = 0
## v8: the dialogue's "bibi" chatter (talk_bi*.wav from tools/audio/make_chatter.py), on its own player so
## two blips never overlap. chatter_on is the dialogue-sound switch, kept in user://audio.cfg (the game has
## no other sound settings).
const CHATTER_CFG: String = "user://audio.cfg"
var chatter_on: bool = true
var chatter_player: AudioStreamPlayer = null
var chatter_count: int = 0
var chatter_next: int = 2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	chatter_player = _player()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CHATTER_CFG) == OK:
		chatter_on = bool(cfg.get_value("audio", "chatter", true))
	for i: int in 12:
		pool.append(_player())
		pool_ms.append(0)
		pool_big.append(false)
	for i: int in 2:
		music_bed.players.append(_player())
		amb_bed.players.append(_player())
	# every button in the game ticks under the mouse and clicks
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			var b: BaseButton = n as BaseButton
			b.pressed.connect(func() -> void: play(String(b.get_meta("snd", "click"))))
			b.mouse_entered.connect(func() -> void:
				if not b.disabled:
					play("ui_hover", -3.0)))

func _player() -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	add_child(p)
	return p

func _process(delta: float) -> void:
	# duck fast, come back slowly
	if Time.get_ticks_msec() < duck_until_ms:
		duck_db = move_toward(duck_db, DUCK_DB, delta * absf(DUCK_DB) / 0.12)
	else:
		duck_db = move_toward(duck_db, 0.0, delta * absf(DUCK_DB) / 0.9)
	music_bed.tick(delta, VOL_MUSIC + music_scene_db + duck_db, XFADE)
	amb_bed.tick(delta, VOL_AMB, 0.8)
	var paused: bool = get_tree().paused
	for k: String in loops:
		var l: Loop = loops[k]
		var want: bool = l.on and not paused
		l.gain = move_toward(l.gain, 1.0 if want else 0.0, delta / (0.06 if want else 0.12))
		if l.gain <= 0.0:
			if l.player.playing:
				l.player.stop()
			continue
		if not l.player.playing:
			l.player.play(randf() * l.player.stream.get_length())  # never the same start twice
		l.player.volume_db = minf(VOL_LOOP + l.vol_db, 0.0) + linear_to_db(maxf(l.gain, 0.001))

## Returns null for a sound that does not exist (yet), so callers never crash on a missing file.
func _stream(sound: String, looped: bool = false) -> AudioStreamWAV:
	var key: String = sound + ("@loop" if looped else "")
	if not cache.has(key):
		var path: String = "res://audio/%s.wav" % sound
		if not ResourceLoader.exists(path):
			cache[key] = null
			return null
		var s: AudioStreamWAV = load(path) as AudioStreamWAV
		if looped and s != null:
			s = s.duplicate() as AudioStreamWAV
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		cache[key] = s
	return cache[key]

## How many takes a sound has: <name>.wav plus <name>_1.wav, <name>_2.wav ... (0 = no such sound).
func _takes(sound: String) -> int:
	if not take_count.has(sound):
		var n: int = 0
		if sound != "" and _stream(sound) != null:
			n = 1
			while n < 6 and ResourceLoader.exists("res://audio/%s_%d.wav" % [sound, n]):
				n += 1
		take_count[sound] = n
	return take_count[sound]

func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if _takes(sound) == 0:
		return
	var now: int = Time.get_ticks_msec()
	if now - int(last_ms.get(sound, -1000)) < 40:
		return  # the same sound twice in one frame only adds level
	last_ms[sound] = now
	if JINGLES.has(sound):
		if now < jingle_free_ms:
			var wait: float = float(jingle_free_ms - now) / 1000.0
			jingle_free_ms += JINGLE_GAP_MS
			get_tree().create_timer(wait).timeout.connect(_start.bind(sound, vol_db, pitch))
			return
		jingle_free_ms = now + JINGLE_GAP_MS
	_start(sound, vol_db, pitch)

func _start(sound: String, vol_db: float, pitch: float) -> void:
	var n: int = _takes(sound)
	var take: int = 0
	if n > 1:
		take = (int(last_take.get(sound, 0)) + 1 + randi() % (n - 1)) % n  # never the same take twice in a row
		last_take[sound] = take
	var st: AudioStreamWAV = _stream(sound if take == 0 else "%s_%d" % [sound, take])
	if st == null:
		return
	if VARY.has(sound):
		pitch *= randf_range(0.96, 1.04)
		vol_db -= randf() * 1.5
	var big: bool = BIG.has(sound)
	var slot: int = -1
	var old_any: int = -1
	var old_big: int = -1
	var n_big: int = 0
	for i: int in pool.size():
		if not pool[i].playing:
			if slot < 0:
				slot = i
		elif pool_big[i]:
			n_big += 1
			if old_big < 0 or pool_ms[i] < pool_ms[old_big]:
				old_big = i
		elif old_any < 0 or pool_ms[i] < pool_ms[old_any]:
			old_any = i
	if big and n_big >= MAX_BIG:
		slot = old_big
	elif slot < 0:
		slot = old_any if old_any >= 0 else old_big
	var p: AudioStreamPlayer = pool[slot]
	p.stream = st
	p.volume_db = (VOL_UI if (sound == "click" or sound.begins_with("ui_")) else VOL_SFX) + vol_db
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.play()
	pool_ms[slot] = Time.get_ticks_msec()
	pool_big[slot] = big
	if DUCK.has(sound):
		duck_until_ms = maxi(duck_until_ms, pool_ms[slot] + int(float(DUCK[sound]) * 1000.0))

## A looping sound (engine, thrusters, drill, wheels): switch it on and off every frame or on change.
## It fades in over 60 ms and out over 120 ms; pitch lets an engine follow the throttle.
func loop(sound: String, on: bool, vol_db: float = -4.0, pitch: float = 1.0) -> void:
	if not loops.has(sound):
		if not on:
			return
		var ls: AudioStreamWAV = _stream(sound + "_loop", true)
		var nl: Loop = Loop.new()
		nl.onset = ls != null
		if ls == null:
			ls = _stream(sound, true)
		if ls == null:
			return
		nl.player = _player()
		nl.player.stream = ls
		loops[sound] = nl
	var l: Loop = loops[sound]
	if on and not l.on and l.onset:
		play(sound, vol_db + VOL_LOOP)
	l.on = on
	l.vol_db = vol_db
	l.player.pitch_scale = clampf(pitch, 0.25, 4.0)

func stop_loops() -> void:
	for k: String in loops:
		(loops[k] as Loop).on = false

## Music by short name (theme, hangar, ascent, drift, descent; "mission" = ascent; "" = silence).
## Crossfades, and a track that is already playing is left alone.
func music(song: String) -> void:
	song = String(ALIAS.get(song, song))
	if song == music_name:
		return
	music_name = song
	music_bed.switch_to(null if song == "" else _stream("music_" + song, true))

## Call once per letter the dialogue reveals: a short blip on every 2nd or 3rd letter (never for spaces or
## punctuation), a random take and pitch, Data.TALK["chatter_db"] under the sound effects. A new blip cuts
## the one before, so they never overlap.
func chatter(ch: String) -> void:
	if not chatter_on or ch.strip_edges() == "" or ".,:;!?-'\"()".contains(ch):
		return
	chatter_count += 1
	if chatter_count < chatter_next:
		return
	chatter_count = 0
	var every: Array = Data.TALK["chatter_every"]
	chatter_next = randi_range(int(every[0]), int(every[1]))
	var n: int = _takes("talk_bi")
	if n == 0:
		return
	var take: int = randi() % n
	chatter_player.stream = _stream("talk_bi" if take == 0 else "talk_bi_%d" % take)
	var p: float = float(Data.TALK["chatter_pitch"])
	chatter_player.pitch_scale = randf_range(1.0 - p, 1.0 + p)
	chatter_player.volume_db = VOL_SFX + float(Data.TALK["chatter_db"])
	chatter_player.play()

## Cuts the chatter at once (the line finished, was skipped or closed).
func chatter_stop() -> void:
	if chatter_player != null:
		chatter_player.stop()
	chatter_count = chatter_next - 1   # the next line starts with a blip

## The dialogue-sound switch; remembered between runs.
func set_chatter(on: bool) -> void:
	chatter_on = on
	if not on:
		chatter_stop()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "chatter", on)
	cfg.save(CHATTER_CFG)

## Ambience bed by file name (amb_hangar, amb_space, amb_moon, amb_mars_wind, amb_saturn; "" = none).
func ambience(bed: String) -> void:
	if bed == amb_name:
		return
	amb_name = bed
	amb_bed.switch_to(null if bed == "" else _stream(bed, true))

## Music and ambience for a screen; main.gd calls it on every screen change. A screen may still call
## music() afterwards for its own stages (flight: "drift" for the cruise, "ascent" for the burns).
func scene(screen: String) -> void:
	var song: String = "theme"
	var bed: String = ""
	match screen:
		"builder":
			song = "hangar"
			bed = "amb_hangar"
		"flight":
			song = "drift" if String(Game.run.get("mode", "out")) == "home" else "ascent"
			bed = "amb_space"
		"landing":
			song = "descent"
			bed = String(AMB_BY_DEST.get(Game.dest_id, "amb_space"))
		"surface":
			song = "drift"
			bed = String(AMB_BY_DEST.get(Game.dest_id, "amb_space"))
		"probe":
			song = "descent"
			bed = "amb_saturn"
	music_scene_db = VOL_MUSIC_PLAY if bed != "" and screen != "builder" else 0.0
	music(song)
	ambience(bed)
