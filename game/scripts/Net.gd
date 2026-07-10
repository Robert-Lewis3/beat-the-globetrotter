extends Node
## WebSocket client that connects the game (as "host") to the relay server.
## Auto-reconnects and reclaims the room if the connection drops mid-game.

signal socket_connected
signal socket_lost
signal room_ready(code: String)
signal player_joined(id: String, player_name: String)
signal player_left(id: String)
signal player_answer(id: String, answer, at: int)

var socket := WebSocketPeer.new()
var active := false
var room_code := ""
var http_url := ""

var _was_open := false
var _retry_wait := 0.0

func start(server_http_url: String) -> void:
	http_url = server_http_url.rstrip("/")
	active = true
	_open_socket()

func stop() -> void:
	active = false
	room_code = ""
	socket.close()

func ws_url() -> String:
	var u := http_url
	u = u.replace("https://", "wss://")
	u = u.replace("http://", "ws://")
	return u

func join_url() -> String:
	return http_url + "/" + room_code

func qr_url() -> String:
	return http_url + "/qr?data=" + join_url().uri_encode()

func send_msg(data: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(data))

## Broadcast a state snapshot to every phone. per_player maps playerId ->
## extra data only that phone receives (merged in as payload.you).
func broadcast(shared: Dictionary, per_player: Dictionary = {}) -> void:
	var msg := {"type": "state", "shared": shared}
	if not per_player.is_empty():
		msg["perPlayer"] = per_player
	send_msg(msg)

func _open_socket() -> void:
	socket = WebSocketPeer.new()
	_was_open = false
	var err := socket.connect_to_url(ws_url())
	if err != OK:
		_retry_wait = 2.0

func _process(delta: float) -> void:
	if not active:
		return
	if _retry_wait > 0.0:
		_retry_wait -= delta
		if _retry_wait <= 0.0:
			_open_socket()
		return

	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			socket_connected.emit()
			if room_code == "":
				send_msg({"type": "host_create"})
			else:
				send_msg({"type": "host_reclaim", "code": room_code})
		while socket.get_available_packet_count() > 0:
			var text := socket.get_packet().get_string_from_utf8()
			var msg = JSON.parse_string(text)
			if msg is Dictionary:
				_handle(msg)
	elif state == WebSocketPeer.STATE_CLOSED:
		if _was_open:
			socket_lost.emit()
		_retry_wait = 2.0

func _handle(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"room_created":
			room_code = str(msg.get("code", ""))
			room_ready.emit(room_code)
		"room_reclaimed":
			room_ready.emit(room_code)
			for p in msg.get("players", []):
				player_joined.emit(str(p.get("playerId")), str(p.get("name")))
		"player_joined", "player_rejoined":
			player_joined.emit(str(msg.get("playerId")), str(msg.get("name")))
		"player_left":
			player_left.emit(str(msg.get("playerId")))
		"player_answer":
			player_answer.emit(str(msg.get("playerId")), msg.get("answer"), int(msg.get("at", 0)))
