extends Node
## Multiplayer (decision D7): 1-4 players, one room on a relay server, one role each.
##
## THIS FILE IS THE CONTRACT between the network layer and the game screens.
## - The network worker owns this file and implements the TODOs. Don't rename or remove anything public.
## - Screens only call the public API below and listen to the signals. They never touch sockets.
## - Offline (solo, the default) everything works with no server: this player owns all 4 roles,
##   send() goes nowhere, is_online() is false. Solo play must behave exactly as before.
##
## Authority: the room HOST's game is the truth. Other players send their role's actions to everyone;
## the host applies them and broadcasts results (builder snapshots, landing/probe state, the run).
##
## Lobby dictionary (lobby_changed and lobby()):
##   {"code": "ABCD", "started": false, "me": 2,
##    "players": [{"id": 1, "name": "PLAYER 1", "host": true, "ready": false, "roles": ["planner"]}, ...]}
## Role ids are Data.ROLES ids: "planner", "engineer", "science", "comms".
## When the host calls start(), every role nobody picked goes to the host.
##
## Message kinds the screens use with send()/received (the network layer just relays them as JSON):
##   "build"   host -> all     {"build": {...}, "rocket": "falcon9", "traj": 0}   builder snapshot
##   "edit"    any -> host     {"op": "add"|"remove"|"rocket"|"traj", ...}        a role's builder action
##   "sign"    any -> all      {"role": "engineer", "on": true}
##   "request" any -> all      {"id": "r7", "from": "science", "to": "engineer", "text": "..."}
##   "reply"   any -> all      {"id": "r7", "ok": true}
##   "chat"    any -> all      {"msg": 3}                                          index into Data.QUICK_CHAT
##   "goto"    host -> all     {"screen": "landing"}
##   "input"   any -> host     {"role": "engineer", "keys": {"up": true}}          flight controls, ~20 Hz
##   "state"   host -> all     {...}                                               landing/probe sim state, ~15 Hz
##   "run"     host -> all     {"run": {...}}                                      Game.run for the report
## Payloads must be JSON-safe: no Color, Vector2 or Objects. Send numbers, strings, arrays, dictionaries.

signal connected                                     ## joined the room (host() or join() succeeded)
signal disconnected(reason: String)                  ## lost the server, kicked, or room closed
signal lobby_changed(lobby: Dictionary)              ## anything in the lobby changed (players, roles, ready, started)
signal started                                       ## host pressed START; roles are final
signal received(kind: String, data: Dictionary, from_id: int)   ## a message from another player

const ALL_ROLES: Array[String] = ["planner", "engineer", "science", "comms"]
## Relay server address. Override for local testing with:  godot ... -- server=ws://127.0.0.1:8080
const DEFAULT_URL: String = "wss://smd-relay.onrender.com"   # The deployed relay (Render, see render.yaml).

var _lobby: Dictionary = {}
var _online: bool = false
var _debug_roles: Array[String] = []   # see debug_set_roles()


# ------------------------------------------------------------------ public API

## Creates a room on the server and joins it as host. Emits connected + lobby_changed (with the code).
func host(player_name: String = "") -> void:
	_connect_room({"t": "host", "name": player_name})

## Joins an existing room by its 4-letter code. Emits connected + lobby_changed, or disconnected(reason).
func join(code: String, player_name: String = "") -> void:
	_connect_room({"t": "join", "code": code.strip_edges().to_upper(), "name": player_name})

## True while HOST / JOIN is still waiting for a sleeping server to wake (Data.NET_WAKE).
func is_waking() -> bool:
	return _retry_request.size() > 0 or (_retries > 0 and not _online)

## Leaves the room and goes back to offline solo play.
func leave() -> void:
	_wake_until = 0
	_retry_at = 0
	_retries = 0
	_retry_request = {}
	if _peer != null:
		_peer.close(1000, "LEAVING")
	_peer = null
	_pending = {}
	_joined_id = 0
	_online = false
	_lobby = {}

func is_online() -> bool:
	return _online

## True offline too: a solo player is their own host.
func is_host() -> bool:
	if not _online:
		return true
	return bool(_my_player().get("host", false))

## This player's id in the room (1 offline).
func my_id() -> int:
	return int(_lobby.get("me", _joined_id)) if _online else 1

## Roles this player controls. Offline: all 4 (or the debug override).
func my_roles() -> Array[String]:
	if not _online:
		return _debug_roles if not _debug_roles.is_empty() else ALL_ROLES.duplicate()
	var roles: Array[String] = []
	for role: String in _my_player().get("roles", []):
		roles.append(role)
	return roles

## Does this player control that role? Screens use this to lock parts and controls.
func owns(role: String) -> bool:
	return my_roles().has(role)

## Lobby actions (online only; ignored offline).
func pick_role(role: String) -> void:
	_send_online({"t": "pick", "role": role})

func drop_role(role: String) -> void:
	_send_online({"t": "drop", "role": role})

func set_ready(on: bool) -> void:
	_send_online({"t": "ready", "on": on})

## Host only: locks roles (free roles go to the host) and emits started on every player.
func start() -> void:
	_send_online({"t": "start"})

func lobby() -> Dictionary:
	return _lobby

## Sends a message to every other player in the room. Does nothing offline.
func send(kind: String, data: Dictionary) -> void:
	if not _online:
		return
	# "state" is a full snapshot that the next one replaces: over a slow internet link, skip it while
	# earlier data is still waiting to go out, instead of overflowing the send buffer.
	if kind == "state" and _peer != null and _peer.get_current_outbound_buffered_amount() > int(Data.NET_WAKE["state_backlog_bytes"]):
		return
	_send_online({"t": "msg", "kind": kind, "data": data})


# ------------------------------------------------------------------ testing

## Offline only: pretend this player controls just these roles, to test locks and split controls
## without a server. Pass [] to go back to all roles. Also settable from the command line:
##   godot ... -- roles=engineer,science
func debug_set_roles(roles: Array[String]) -> void:
	_debug_roles = roles

func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("roles="):
			var r: Array[String] = []
			for s: String in a.trim_prefix("roles=").split(",", false):
				r.append(s)
			_debug_roles = r
		elif a.begins_with("server="):
			_url = a.trim_prefix("server=")
		elif a.begins_with("nettest="):
			_nettest = a.trim_prefix("nettest=")
	if not _nettest.is_empty():
		lobby_changed.connect(_nettest_lobby)
		received.connect(_nettest_received)
		disconnected.connect(_nettest_disconnected)
		_nettest_deadline = Time.get_ticks_msec() + 60000
		if _nettest == "host":
			host("NETTEST HOST")
		elif _nettest.begins_with("join:"):
			join(_nettest.trim_prefix("join:"), "NETTEST JOIN")


# ------------------------------------------------------------------ transport (no threads)

var _peer: WebSocketPeer = null
var _url: String = DEFAULT_URL
var _pending: Dictionary = {}
var _joined_id: int = 0
var _connect_deadline: int = 0
var _reached: bool = false            # the socket opened at least once for this HOST / JOIN
var _wake_until: int = 0              # retry a failed connection until then (the server may be asleep)
var _retry_at: int = 0
var _retries: int = 0
var _retry_request: Dictionary = {}
var _next_ping: int = 0
var _nettest: String = ""
var _nettest_deadline: int = 0
var _nettest_printed: bool = false
var _nettest_sent: bool = false

func _my_player() -> Dictionary:
	for player: Dictionary in _lobby.get("players", []):
		if int(player.get("id", 0)) == my_id():
			return player
	return {}

func _connect_room(request: Dictionary) -> void:
	leave()
	_reached = false
	_wake_until = Time.get_ticks_msec() + int(float(Data.NET_WAKE["secs"]) * 1000.0)
	_open_peer(request)

func _open_peer(request: Dictionary) -> void:
	_pending = request
	_peer = WebSocketPeer.new()
	_peer.inbound_buffer_size = 131072
	_peer.outbound_buffer_size = int(Data.NET_WAKE["out_buffer_bytes"])
	_connect_deadline = Time.get_ticks_msec() + 8000
	_next_ping = Time.get_ticks_msec() + 20000
	if _peer.connect_to_url(_url) != OK:
		_fail("CONNECTION FAILED")

func _send_online(message: Dictionary) -> void:
	if _online:
		_write(message)

func _write(message: Dictionary) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var json: String = JSON.stringify(message)
	if json.to_utf8_buffer().size() > 65536:
		_fail("MESSAGE TOO LARGE")
	elif _peer.send_text(json) != OK:
		_fail("SEND FAILED")

func _fail(reason: String) -> void:
	var now: int = Time.get_ticks_msec()
	if not _online and not _reached and now < _wake_until and not _pending.is_empty():
		# never reached the server: it may be waking up, so try again shortly (nothing was sent yet)
		_retry_request = _pending
		_retries += 1
		if _peer != null:
			_peer.close()
		_peer = null
		_pending = {}
		_retry_at = now + int(float(Data.NET_WAKE["retry_secs"]) * 1000.0)
		return
	leave()
	disconnected.emit(reason)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if _nettest_deadline > 0 and now >= _nettest_deadline:
		_nettest_deadline = 0
		_nettest_disconnected("TEST TIMEOUT")
	if _peer == null:
		if _retry_at > 0 and now >= _retry_at:
			var request: Dictionary = _retry_request
			_retry_at = 0
			_retry_request = {}
			_open_peer(request)
		return
	_peer.poll()
	var state: int = _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_reached = true
		if not _pending.is_empty():
			var request: Dictionary = _pending
			_pending = {}
			_write(request)
		while _peer != null and _peer.get_available_packet_count() > 0:
			var packet: PackedByteArray = _peer.get_packet()
			if not _peer.was_string_packet() or packet.size() > 65536:
				_fail("INVALID MESSAGE")
				return
			var parser: JSON = JSON.new()
			if parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary:
				_fail("INVALID MESSAGE")
				return
			_handle_message(parser.data)
		if _peer != null and now >= _next_ping:
			_next_ping = now + 20000
			_write({"t": "ping"})
	elif state == WebSocketPeer.STATE_CLOSED:
		var reason: String = _peer.get_close_reason()
		_fail(reason if not reason.is_empty() else "CONNECTION CLOSED")
	if _peer != null and not _online and now >= _connect_deadline:
		_fail("TIMEOUT")

func _handle_message(message: Dictionary) -> void:
	match str(message.get("t", "")):
		"welcome":
			_joined_id = int(message.get("id", 0))
		"lobby":
			if not message.get("lobby") is Dictionary or _joined_id <= 0:
				_fail("INVALID LOBBY")
				return
			_lobby = message["lobby"]
			var first: bool = not _online
			_online = true
			if first:
				connected.emit()
			if _online:
				lobby_changed.emit(_lobby)
		"started":
			started.emit()
		"msg":
			if message.get("data") is Dictionary:
				received.emit(str(message.get("kind", "")), message["data"], int(message.get("from", 0)))
		"error":
			_fail(str(message.get("reason", "SERVER ERROR")))
		"pong":
			pass

func _nettest_lobby(current: Dictionary) -> void:
	if _nettest != "host":
		return
	if not _nettest_printed:
		_nettest_printed = true
		print("NETTEST code=" + str(current.get("code", "")))
	if current.get("players", []).size() >= 2 and not _nettest_sent:
		_nettest_sent = true
		send("chat", {"msg": 1})

func _nettest_received(kind: String, data: Dictionary, _from_id: int) -> void:
	if _nettest.begins_with("join:") and kind == "chat" and data.get("msg") == 1:
		print("NETTEST ok")
		leave()
		get_tree().quit()

func _nettest_disconnected(reason: String) -> void:
	printerr("NETTEST failed: " + reason)
	get_tree().quit(1)
