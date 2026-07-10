extends Control
## Lobby: connects to the relay, shows the QR code + room code, lists players
## as they join, and starts the game.

var status_label: Label
var code_label: Label
var url_label: Label
var qr_rect: TextureRect
var players_grid: GridContainer
var count_label: Label
var start_btn: Button
var http: HTTPRequest

func _ready() -> void:
	add_child(Arena.new("title"))

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 60)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)

	# --- left: QR + join info
	var left := VBoxContainer.new()
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 18)
	root.add_child(left)

	left.add_child(UIKit.label("SCAN TO JOIN THE FIGHT", 22, UIKit.C_GOLD))

	var qr_frame := PanelContainer.new()
	qr_frame.add_theme_stylebox_override("panel", UIKit.panel_box(UIKit.C_CYAN))
	qr_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(qr_frame)
	qr_rect = TextureRect.new()
	qr_rect.custom_minimum_size = Vector2(420, 420)
	qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	qr_frame.add_child(qr_rect)

	code_label = UIKit.label("", 44, UIKit.C_CYAN)
	left.add_child(code_label)
	url_label = UIKit.label("", 12, UIKit.C_MUTED)
	left.add_child(url_label)
	status_label = UIKit.label("CONNECTING TO SERVER...", 14, UIKit.C_PINK)
	left.add_child(status_label)

	# --- right: team + player list + start
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 18)
	right.custom_minimum_size = Vector2(760, 0)
	root.add_child(right)

	right.add_child(UIKit.label("TEAM", 14, UIKit.C_MUTED))
	right.add_child(UIKit.label(GameState.team_name, 40, UIKit.C_CYAN))
	count_label = UIKit.label("0 CHALLENGERS READY", 16, UIKit.C_TEXT)
	right.add_child(count_label)

	var list_frame := PanelContainer.new()
	list_frame.add_theme_stylebox_override("panel", UIKit.panel_box(Color(0.53, 0.53, 0.73, 0.5)))
	list_frame.custom_minimum_size = Vector2(760, 420)
	right.add_child(list_frame)
	players_grid = GridContainer.new()
	players_grid.columns = 3
	players_grid.add_theme_constant_override("h_separation", 24)
	players_grid.add_theme_constant_override("v_separation", 16)
	list_frame.add_child(players_grid)

	start_btn = UIKit.button("START GAME ▸", 22)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.disabled = true
	start_btn.pressed.connect(_start_game)
	right.add_child(start_btn)

	var back := UIKit.button("◂ BACK", 12, UIKit.C_MUTED)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		Net.stop()
		Main.goto("title"))
	right.add_child(back)

	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_qr_fetched)

	Net.room_ready.connect(_on_room_ready)
	Net.socket_lost.connect(_on_socket_lost)
	GameState.players_changed.connect(_refresh_players)

	if Net.room_code != "":
		_on_room_ready(Net.room_code)
	else:
		Net.start(GameState.server_url)
	_refresh_players()

func _exit_tree() -> void:
	Net.room_ready.disconnect(_on_room_ready)
	Net.socket_lost.disconnect(_on_socket_lost)
	GameState.players_changed.disconnect(_refresh_players)

func _on_room_ready(code: String) -> void:
	code_label.text = "ROOM  " + code
	url_label.text = Net.join_url().replace("https://", "").replace("http://", "")
	status_label.text = "WAITING FOR CHALLENGERS..."
	status_label.add_theme_color_override("font_color", UIKit.C_GREEN)
	GameState.broadcast_lobby()
	http.request(Net.qr_url())

func _on_socket_lost() -> void:
	status_label.text = "CONNECTION LOST — RETRYING..."
	status_label.add_theme_color_override("font_color", UIKit.C_RED)

func _on_qr_fetched(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "QR FETCH FAILED — SHARE THE URL + ROOM CODE INSTEAD"
		return
	var img := Image.new()
	if img.load_png_from_buffer(body) == OK:
		qr_rect.texture = ImageTexture.create_from_image(img)

func _refresh_players() -> void:
	for c in players_grid.get_children():
		c.queue_free()
	var n := 0
	for id in GameState.players:
		var p: Dictionary = GameState.players[id]
		var color: Color = UIKit.C_TEXT if p["connected"] else UIKit.C_MUTED
		var l := UIKit.label(("● " if p["connected"] else "○ ") + str(p["name"]), 15, color)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		players_grid.add_child(l)
		if p["connected"]:
			n += 1
	count_label.text = "%d CHALLENGER%s READY" % [n, "" if n == 1 else "S"]
	start_btn.disabled = n == 0
	if n > 0:
		Sfx.play("select", -12.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not start_btn.disabled:
			_start_game()

func _start_game() -> void:
	Sfx.play("select")
	Main.goto("vs")
