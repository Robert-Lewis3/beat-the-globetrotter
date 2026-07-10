extends Control
## Title screen: logo, team name input, Insert Coin ▸ Start.

var team_input: LineEdit

func _ready() -> void:
	add_child(Arena.new("title"))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	add_child(box)

	var t1 := UIKit.label("BEAT THE", 52, UIKit.C_GOLD)
	var t2 := UIKit.label("GLOBETROTTER", 84, UIKit.C_CYAN)
	box.add_child(t1)
	box.add_child(t2)
	box.add_child(UIKit.label("A RETRO BOSS-BATTLE TRIVIA SHOWDOWN", 16, UIKit.C_PINK))
	box.add_child(UIKit.vspace(30))

	box.add_child(UIKit.label("ENTER TEAM NAME", 14, UIKit.C_MUTED))
	team_input = UIKit.line_edit("THE OFFICE", 24)
	team_input.max_length = 20
	team_input.text = GameState.team_name
	team_input.custom_minimum_size = Vector2(560, 0)
	team_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(team_input)
	box.add_child(UIKit.vspace(20))

	var start := UIKit.button("INSERT COIN ▸ START", 24)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_start)
	box.add_child(start)
	box.add_child(UIKit.vspace(40))

	var help := UIKit.label(
		"HOST: PLAYERS JOIN BY QR CODE ON THE NEXT SCREEN.\nREAD EACH QUESTION ALOUD — THE ROOM ANSWERS ON THEIR PHONES.\nSHOW QUESTION ▸ TIMER RUNS ▸ REVEAL ▸ NEXT.",
		11, UIKit.C_MUTED)
	box.add_child(help)

	# pulse the title
	var tween := create_tween().set_loops()
	tween.tween_property(t2, "modulate:a", 0.7, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(t2, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not team_input.has_focus():
			_start()

func _start() -> void:
	var name_text := team_input.text.strip_edges().to_upper()
	GameState.team_name = name_text if name_text != "" else "THE OFFICE"
	GameState.reset_run()
	Sfx.play("select")
	Main.goto("lobby")
