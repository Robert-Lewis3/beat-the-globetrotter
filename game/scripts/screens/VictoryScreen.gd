extends Control
## Victory: banner, confetti, top-3 leaderboard, play again.

func _ready() -> void:
	add_child(Arena.new("worldtour"))
	GameState.broadcast_end(true)
	Sfx.play("victory")

	_confetti(Vector2(480, -20))
	_confetti(Vector2(960, -20))
	_confetti(Vector2(1440, -20))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	add_child(box)

	var v := UIKit.label("VICTORY!", 110, UIKit.C_GOLD)
	box.add_child(v)
	box.add_child(UIKit.label("TEAM " + GameState.team_name + " BEAT THE GLOBETROTTER!", 24, UIKit.C_CYAN))
	box.add_child(UIKit.label("MAX COMBO x%d" % GameState.max_combo, 15, UIKit.C_PINK))
	box.add_child(UIKit.vspace(16))

	var board := GameState.leaderboard()
	if board.size() > 0:
		box.add_child(UIKit.label("— TOP CHALLENGERS —", 18, UIKit.C_TEXT))
		var medals := ["1ST", "2ND", "3RD"]
		for i in range(min(3, board.size())):
			var row: Dictionary = board[i]
			var color: Color = UIKit.C_GOLD if i == 0 else UIKit.C_TEXT
			box.add_child(UIKit.label(
				"%s %s — %d PTS (%d CORRECT)" % [medals[i], row["name"], row["score"], row["correct"]],
				20 if i == 0 else 16, color))
	box.add_child(UIKit.vspace(24))

	var again := UIKit.button("PLAY AGAIN", 22)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func():
		Sfx.play("select")
		GameState.reset_run()
		GameState.broadcast_lobby()
		Main.goto("lobby"))
	box.add_child(again)

	var pulse := create_tween().set_loops()
	pulse.tween_property(v, "modulate:a", 0.65, 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(v, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)

func _confetti(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 120
	p.lifetime = 3.5
	p.explosiveness = 0.0
	p.direction = Vector2(0, 1)
	p.spread = 60.0
	p.gravity = Vector2(0, 320)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 420.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color_ramp = _confetti_gradient()
	p.emitting = true
	add_child(p)

func _confetti_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, UIKit.C_GOLD)
	g.set_color(1, UIKit.C_CYAN)
	g.add_point(0.5, UIKit.C_PINK)
	return g
