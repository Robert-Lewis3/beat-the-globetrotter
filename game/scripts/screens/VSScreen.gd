extends Control
## VS screen before each boss: hero vs boss, pop-in VS, taunt, boss pips.

var fight_btn: Button

func _ready() -> void:
	var boss: Dictionary = GameState.current_boss()
	add_child(Arena.new(boss["arena"]))
	GameState.broadcast_vs()

	# boss progress pips
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 20)
	add_child(UIKit.center_x(pips, 40))
	for i in range(Questions.BOSSES.size()):
		var mark := "✖" if i < GameState.boss_index else ("▶" if i == GameState.boss_index else "●")
		var color: Color = UIKit.C_MUTED
		if i < GameState.boss_index:
			color = UIKit.C_GREEN
		elif i == GameState.boss_index:
			color = UIKit.C_GOLD
		pips.add_child(UIKit.label("BOSS %d %s" % [i + 1, mark], 14, color))

	# fighters
	var hero := Fighter.new(Questions.HERO_SPRITE, Questions.HERO_COLOR, true)
	hero.position = Vector2(480, 560)
	add_child(hero)
	var boss_f := Fighter.new(boss["sprite"], boss["color"], false)
	boss_f.position = Vector2(1440, 560)
	add_child(boss_f)

	# names
	var hero_name := UIKit.label(GameState.team_name, 26, Questions.HERO_COLOR)
	hero_name.custom_minimum_size = Vector2(700, 0)
	hero_name.position = Vector2(130, 720)
	add_child(hero_name)
	add_child(_sub("REPRESENTS THE WHOLE ROOM", Vector2(130, 760)))

	var boss_name := UIKit.label(boss["name"], 26, boss["color"])
	boss_name.custom_minimum_size = Vector2(700, 0)
	boss_name.position = Vector2(1090, 720)
	add_child(boss_name)
	add_child(_sub(boss["title"], Vector2(1090, 760)))

	# taunt
	var taunt := UIKit.label("\"" + boss["taunt"].to_upper() + "\"", 15, UIKit.C_PINK)
	add_child(UIKit.center_x(taunt, 850))

	# big VS pop-in
	var vs := UIKit.label("VS", 170, UIKit.C_GOLD)
	vs.scale = Vector2(6, 6)
	vs.modulate.a = 0.0
	add_child(UIKit.center_x(vs, 380))

	fight_btn = UIKit.button("FIGHT!", 26, UIKit.C_RED)
	fight_btn.pressed.connect(_fight)
	var btn_row := HBoxContainer.new()
	btn_row.add_child(fight_btn)
	add_child(UIKit.center_x_bottom(btn_row, 140))

	await get_tree().process_frame   # let layout settle so the pivot is centered
	vs.pivot_offset = vs.size / 2.0
	var t := create_tween().set_parallel()
	t.tween_property(vs, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(vs, "modulate:a", 1.0, 0.3)
	t.chain().tween_callback(func(): Sfx.play("hit"))

func _sub(text: String, pos: Vector2) -> Label:
	var l := UIKit.label(text, 12, UIKit.C_MUTED)
	l.custom_minimum_size = Vector2(700, 0)
	l.position = pos + Vector2(0, 24)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_fight()

func _fight() -> void:
	Sfx.play("select")
	Main.goto("battle")
