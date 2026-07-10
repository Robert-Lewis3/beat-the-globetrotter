extends Control
## Defeat: arcade CONTINUE? countdown. Try again replays the current boss;
## countdown hitting zero (or GIVE UP) ends the run.

var count := 9
var count_label: Label
var timer: Timer

func _ready() -> void:
	var boss: Dictionary = GameState.current_boss()
	add_child(Arena.new(boss["arena"]))

	var dim := ColorRect.new()
	dim.color = Color(0.15, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	Sfx.play("defeat")

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	add_child(box)

	box.add_child(UIKit.label("DEFEAT...", 96, UIKit.C_RED))
	box.add_child(UIKit.label(boss["name"] + " STANDS TALL", 22, boss["color"]))
	box.add_child(UIKit.label("\"" + boss["taunt"].to_upper() + "\"", 14, UIKit.C_MUTED))
	box.add_child(UIKit.vspace(30))
	box.add_child(UIKit.label("CONTINUE?", 34, UIKit.C_GOLD))
	count_label = UIKit.label("9", 80, UIKit.C_TEXT)
	box.add_child(count_label)
	box.add_child(UIKit.vspace(20))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(row)

	var retry := UIKit.button("INSERT COIN ▸ TRY AGAIN", 20)
	retry.pressed.connect(_retry)
	row.add_child(retry)
	var give_up := UIKit.button("GIVE UP", 20, UIKit.C_MUTED)
	give_up.pressed.connect(_game_over)
	row.add_child(give_up)

	timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_tick)
	add_child(timer)
	timer.start()

func _tick() -> void:
	count -= 1
	count_label.text = str(count)
	Sfx.play("tick", -8.0)
	if count <= 0:
		_game_over()

func _retry() -> void:
	timer.stop()
	Sfx.play("select")
	GameState.reset_boss_fight()
	Main.goto("vs")

func _game_over() -> void:
	timer.stop()
	GameState.broadcast_end(false)
	Sfx.play("wrong")
	for c in get_children():
		if c is VBoxContainer:
			c.queue_free()
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)
	box.add_child(UIKit.label("GAME OVER", 96, UIKit.C_RED))
	box.add_child(UIKit.label("THE GLOBETROTTER REMAINS UNBEATEN", 18, UIKit.C_MUTED))
	var board := GameState.leaderboard()
	if board.size() > 0:
		box.add_child(UIKit.vspace(16))
		box.add_child(UIKit.label("— TOP CHALLENGERS —", 16, UIKit.C_TEXT))
		for i in range(min(3, board.size())):
			var r: Dictionary = board[i]
			box.add_child(UIKit.label("%d. %s — %d PTS" % [i + 1, r["name"], r["score"]], 15, UIKit.C_TEXT))
	box.add_child(UIKit.vspace(24))
	var again := UIKit.button("BACK TO TITLE", 20)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func():
		GameState.reset_run()
		Main.goto("title"))
	box.add_child(again)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if timer and not timer.is_stopped():
			_retry()
