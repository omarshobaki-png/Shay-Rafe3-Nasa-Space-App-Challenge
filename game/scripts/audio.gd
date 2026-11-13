extends Node
## Sound effects, engine loops and music. Files: res://audio/<name>.wav
## (made by the godot skill's make_sfx.py / make_music.py; recipes in tools/audio).

var pool: Array[AudioStreamPlayer] = []
var loops: Dictionary = {}
var music_player: AudioStreamPlayer = null
var music_name: String = ""
var cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i: int in 8:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -9.0
	add_child(music_player)
	# every button in the game clicks
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is BaseButton:
			(n as BaseButton).pressed.connect(func() -> void: play("click", -6.0)))

func _stream(sound: String, looped: bool = false) -> AudioStreamWAV:
	var key: String = sound + ("@loop" if looped else "")
	if not cache.has(key):
		var s: AudioStreamWAV = load("res://audio/%s.wav" % sound) as AudioStreamWAV
		if looped:
			s = s.duplicate() as AudioStreamWAV
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		cache[key] = s
	return cache[key]

func play(sound: String, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	for p: AudioStreamPlayer in pool:
		if not p.playing:
			p.stream = _stream(sound)
			p.volume_db = vol_db
			p.pitch_scale = pitch
			p.play()
			return

## A looping sound (engine, thrusters) switched on and off every frame.
func loop(sound: String, on: bool, vol_db: float = -4.0) -> void:
	if not loops.has(sound):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.stream = _stream(sound, true)
		add_child(p)
		loops[sound] = p
	var lp: AudioStreamPlayer = loops[sound]
	lp.volume_db = vol_db
	if on and not lp.playing:
		lp.play()
	elif not on and lp.playing:
		lp.stop()

func stop_loops() -> void:
	for k: String in loops:
		(loops[k] as AudioStreamPlayer).stop()

func music(song: String) -> void:
	if song == music_name:
		return
	music_name = song
	if song == "":
		music_player.stop()
		return
	music_player.stream = _stream("music_" + song, true)
	music_player.play()
