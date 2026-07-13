extends Control
## Battle screen. Host state machine per question:
##   IDLE -> [SHOW QUESTION] -> OPEN (phones answer, countdown)
##        -> auto/(LOCK NOW) -> LOCKED -> [REVEAL] -> REVEALED -> [NEXT ▸]
## After Q4: KO if HP is gone, otherwise OVERTIME sudden-death; overtime
## failure goes to the Defeat screen.

enum Phase { IDLE, OPEN, LOCKED, REVEALED, KO }

var phase := Phase.IDLE
var last_fraction := 0.0
var boss: Dictionary

var hero_f: Fighter
var boss_f: Fighter
var hp_bar: Control
var display_hp := 100.0
var combo_label: Label
var timer_label: Label
var answered_label: Label
var status_label: Label
var q_header: Label
var q_label: Label
var options_grid: GridContainer
var option_panels: Array = []
var fact_label: Label
var answer_label: Label
var btn_show: Button
var btn_lock: Button
var btn_reveal: Button
var btn_next: Button
var hype_label: Label
var ko_layer: Control
var _last_tick := -1

func _ready() -> void:
	boss = GameState.current_boss()
	add_child(Arena.new(boss["arena"]))

	# ---- fighters (low, flanking the question panel, feet aligned)
	hero_f = Fighter.new(Questions.HERO_SPRITE, Questions.HERO_COLOR, true)
	hero_f.position = Vector2(190, 700)
	add_child(hero_f)
	boss_f = Fighter.new(boss["sprite"], boss["color"], false, GameState.boss_pixel_scale())
	boss_f.position = Vector2(1730, 700 + hero_f.half_height() - boss_f.half_height())
	add_child(boss_f)

	# ---- top bars
	var hero_name := UIKit.label(GameState.team_name, 18, Questions.HERO_COLOR)
	hero_name.position = Vector2(40, 30)
	hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(hero_name)
	var hero_hp := ColorRect.new()
	hero_hp.color = Questions.HERO_COLOR
	hero_hp.position = Vector2(40, 66)
	hero_hp.size = Vector2(560, 26)
	add_child(hero_hp)

	var boss_name := UIKit.label(boss["name"], 18, boss["color"])
	boss_name.position = Vector2(1320, 30)
	boss_name.custom_minimum_size = Vector2(560, 0)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(boss_name)
	hp_bar = _make_hp_bar()
	hp_bar.position = Vector2(1320, 66)
	add_child(hp_bar)

	combo_label = UIKit.label("", 20, UIKit.C_GOLD)
	combo_label.position = Vector2(40, 110)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(combo_label)

	# ---- countdown + answered
	timer_label = UIKit.label("", 44, UIKit.C_GOLD)
	add_child(UIKit.center_x(timer_label, 24))
	answered_label = UIKit.label("", 13, UIKit.C_MUTED)
	add_child(UIKit.center_x(answered_label, 92))

	# ---- question panel
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.panel_box(boss["color"]))
	panel.position = Vector2(400, 150)
	panel.custom_minimum_size = Vector2(1120, 620)
	add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 20)
	panel.add_child(pv)

	q_header = UIKit.label("", 14, boss["color2"])
	pv.add_child(q_header)
	q_label = UIKit.label("", 22, UIKit.C_TEXT)
	q_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q_label.custom_minimum_size = Vector2(1040, 0)
	pv.add_child(q_label)
	pv.add_child(UIKit.vspace(6))

	options_grid = GridContainer.new()
	options_grid.columns = 2
	options_grid.add_theme_constant_override("h_separation", 20)
	options_grid.add_theme_constant_override("v_separation", 20)
	pv.add_child(options_grid)

	answer_label = UIKit.label("", 22, UIKit.C_GREEN)
	answer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	answer_label.custom_minimum_size = Vector2(1040, 0)
	pv.add_child(answer_label)
	fact_label = UIKit.label("", 14, UIKit.C_MUTED)
	fact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fact_label.custom_minimum_size = Vector2(1040, 0)
	pv.add_child(fact_label)

	# ---- host dock
	var dock := HBoxContainer.new()
	dock.add_theme_constant_override("separation", 24)
	add_child(UIKit.center_x_bottom(dock, 150))
	status_label = UIKit.label("", 13, UIKit.C_MUTED)
	add_child(UIKit.center_x_bottom(status_label, 44))

	btn_show = UIKit.button("SHOW QUESTION", 18)
	btn_show.pressed.connect(_show_question)
	dock.add_child(btn_show)
	btn_lock = UIKit.button("LOCK ANSWERS NOW", 18, UIKit.C_PINK)
	btn_lock.pressed.connect(_lock)
	dock.add_child(btn_lock)
	btn_reveal = UIKit.button("REVEAL ANSWER", 18, UIKit.C_CYAN)
	btn_reveal.pressed.connect(_reveal)
	dock.add_child(btn_reveal)
	btn_next = UIKit.button("NEXT ▸", 18, UIKit.C_GREEN)
	btn_next.pressed.connect(_next)
	dock.add_child(btn_next)

	# ---- hype popup
	hype_label = UIKit.label("", 64, UIKit.C_GOLD)
	hype_label.modulate.a = 0.0
	add_child(UIKit.center_x(hype_label, 600))

	GameState.answer_received.connect(_on_answer_received)
	_enter_idle()

func _exit_tree() -> void:
	GameState.answer_received.disconnect(_on_answer_received)

# ------------------------------------------------------------------ phases
func _enter_idle() -> void:
	phase = Phase.IDLE
	var qn := "OVERTIME" if GameState.in_overtime else "QUESTION %d/%d" % [GameState.question_index + 1, Questions.QUESTIONS_PER_BOSS]
	q_header.text = qn + "  —  VS " + boss["name"]
	q_label.text = "READY?" if not GameState.in_overtime else "SUDDEN DEATH! WIN THIS OR IT'S OVER!"
	_clear_options()
	answer_label.text = ""
	fact_label.text = ""
	timer_label.text = ""
	answered_label.text = ""
	status_label.text = "READ THE QUESTION ALOUD, THEN SHOW IT"
	_buttons(true, false, false, false)
	_update_combo()

func _show_question() -> void:
	Sfx.play("select")
	GameState.start_question()
	phase = Phase.OPEN
	var q := GameState.current_question()
	q_label.text = q["text"]
	_clear_options()
	if q["kind"] == "mc":
		for i in range(4):
			var op := _make_option("ABCD"[i], q["options"][i])
			option_panels.append(op)
			options_grid.add_child(op)
	else:
		var open_note := UIKit.label("OPEN ANSWER — PLAYERS TYPE ON THEIR PHONES", 13, UIKit.C_PINK)
		options_grid.add_child(open_note)
	answered_label.text = "0/%d ANSWERED" % GameState.connected_count()
	status_label.text = "ANSWERS OPEN — LOCKS WHEN TIME'S UP OR EVERYONE'S IN"
	_buttons(false, true, false, false)
	_last_tick = -1

func _lock() -> void:
	if phase != Phase.OPEN:
		return
	phase = Phase.LOCKED
	GameState.lock_question()
	timer_label.text = "0"
	status_label.text = "ANSWERS LOCKED — BUILD THE SUSPENSE, THEN REVEAL"
	_buttons(false, false, true, false)
	Sfx.play("tick")

func _reveal() -> void:
	if phase != Phase.LOCKED:
		return
	phase = Phase.REVEALED
	var q := GameState.current_question()
	var result := GameState.grade_question()
	last_fraction = result["fraction"]

	# answer + fact
	answer_label.text = "✔ " + q["answer_text"]
	fact_label.text = q["fact"]
	timer_label.text = ""

	# distribution on MC options
	if q["kind"] == "mc":
		for i in range(option_panels.size()):
			var op: PanelContainer = option_panels[i]
			var count: int = result["distribution"][i]
			var total: int = max(1, result["total"])
			var lbl: Label = op.get_child(0)
			lbl.text += "   — %d (%d%%)" % [count, int(round(100.0 * count / total))]
			var sb: StyleBoxFlat = op.get_theme_stylebox("panel").duplicate()
			if i == int(q["correct"]):
				sb.border_color = UIKit.C_GREEN
				sb.bg_color = Color(0.1, 0.3, 0.16, 0.9)
			else:
				sb.border_color = Color(0.3, 0.3, 0.5)
			op.add_theme_stylebox_override("panel", sb)

	answered_label.text = "%d/%d GOT IT RIGHT" % [result["correct_count"], result["total"]]

	# fight animation + hp + combo + hype
	var got_it: bool = last_fraction >= GameState.HIT_THRESHOLD
	if got_it:
		hero_f.lunge()
		boss_f.hit()
		Sfx.play("hit")
		if GameState.combo >= 2:
			Sfx.play("combo", -6.0)
	else:
		boss_f.lunge()
		hero_f.hit()
		Sfx.play("wrong")
	_pop_hype(_hype_text(last_fraction), UIKit.C_GOLD if got_it else UIKit.C_RED)
	_tween_hp(GameState.boss_hp)
	_update_combo()

	status_label.text = "READ THE FUN FACT, THEN NEXT"
	_buttons(false, false, false, true)

func _next() -> void:
	Sfx.play("select")
	match GameState.next_step(last_fraction):
		"next_question":
			GameState.advance_question()
			_enter_idle()
		"overtime":
			GameState.enter_overtime()
			_pop_hype("OVERTIME!", UIKit.C_PINK)
			_enter_idle()
		"ko":
			_ko_sequence()
		"defeat":
			Main.goto("defeat")

func _ko_sequence() -> void:
	phase = Phase.KO
	GameState.broadcast_ko()
	boss_f.ko_fall()
	hero_f.victory_hop()
	Sfx.play("ko")
	_tween_hp(0.0)
	_buttons(false, false, false, false)
	status_label.text = ""

	ko_layer = Control.new()
	ko_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ko_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ko_layer.add_child(dim)
	var ko := UIKit.label("K.O.!", 200, UIKit.C_RED)
	ko.scale = Vector2(5, 5)
	ko.modulate.a = 0.0
	ko_layer.add_child(UIKit.center_x(ko, 320))
	var flawless := GameState.combo >= Questions.QUESTIONS_PER_BOSS and not GameState.in_overtime
	var sub := UIKit.label("FLAWLESS VICTORY!" if flawless else boss["name"] + " GOES DOWN!", 22, UIKit.C_GOLD)
	ko_layer.add_child(UIKit.center_x(sub, 640))
	var cont_row := HBoxContainer.new()
	ko_layer.add_child(UIKit.center_x_bottom(cont_row, 160))
	var cont := UIKit.button("CONTINUE ▸", 22)
	cont.pressed.connect(_continue_after_ko)
	cont_row.add_child(cont)

	await get_tree().process_frame   # let layout settle so the pivot is centered
	ko.pivot_offset = ko.size / 2.0
	var t := create_tween().set_parallel()
	t.tween_property(ko, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ko, "modulate:a", 1.0, 0.25)

func _continue_after_ko() -> void:
	Sfx.play("select")
	GameState.boss_index += 1
	if GameState.boss_index >= Questions.BOSSES.size():
		Main.goto("victory")
	else:
		GameState.reset_boss_fight()
		Main.goto("vs")

# ------------------------------------------------------------------ ticking
func _process(_delta: float) -> void:
	if phase != Phase.OPEN:
		return
	var left := GameState.seconds_left()
	var s := int(ceil(left))
	timer_label.text = str(s)
	if left <= 5.0:
		timer_label.add_theme_color_override("font_color", UIKit.C_RED)
		if s != _last_tick:
			_last_tick = s
			Sfx.play("tick", -10.0)
	else:
		timer_label.add_theme_color_override("font_color", UIKit.C_GOLD)
	if left <= 0.0:
		_lock()

func _on_answer_received(count: int) -> void:
	if phase != Phase.OPEN:
		return
	answered_label.text = "%d/%d ANSWERED" % [count, GameState.connected_count()]
	Sfx.play("select", -18.0)
	if GameState.all_answered():
		_lock()

# ------------------------------------------------------------------ helpers
func _buttons(show: bool, lock: bool, reveal: bool, next: bool) -> void:
	btn_show.visible = show
	btn_lock.visible = lock
	btn_reveal.visible = reveal
	btn_next.visible = next

func _primary_action() -> void:
	match phase:
		Phase.IDLE: _show_question()
		Phase.OPEN: _lock()
		Phase.LOCKED: _reveal()
		Phase.REVEALED: _next()
		Phase.KO: _continue_after_ko()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_primary_action()

func _clear_options() -> void:
	option_panels.clear()
	for c in options_grid.get_children():
		c.queue_free()

func _make_option(letter: String, text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.19, 0.9)
	sb.border_color = UIKit.C_CYAN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(510, 0)
	var l := UIKit.label(letter + ")  " + text, 16, UIKit.C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	return p

func _make_hp_bar() -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(560, 26)
	bar.size = Vector2(560, 26)
	bar.draw.connect(func():
		var w := 560.0
		var h := 26.0
		bar.draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.1, 0.2))
		var frac: float = clamp(display_hp / 100.0, 0.0, 1.0)
		var col: Color = boss["color"] if frac > 0.3 else UIKit.C_RED
		bar.draw_rect(Rect2(w * (1.0 - frac), 0, w * frac, h), col)   # drains leftward
		for i in range(1, 4):
			bar.draw_rect(Rect2(w * i / 4.0 - 1, 0, 2, h), Color(0, 0, 0, 0.6))
		bar.draw_rect(Rect2(0, 0, w, h), Color.WHITE, false, 2.0))
	return bar

func _tween_hp(target: float) -> void:
	var t := create_tween()
	t.tween_method(func(v): display_hp = v; hp_bar.queue_redraw(), display_hp, target, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_combo() -> void:
	combo_label.text = "COMBO x%d" % GameState.combo if GameState.combo > 0 else ""

func _hype_text(fraction: float) -> String:
	if fraction >= 0.999:
		return "PERFECT!"
	if fraction >= 0.75:
		return "GREAT!"
	if fraction >= GameState.HIT_THRESHOLD:
		return "NICE!"
	if fraction > 0.0:
		return "OOF!"
	return "BRUTAL!"

func _pop_hype(text: String, color: Color) -> void:
	hype_label.text = text
	hype_label.add_theme_color_override("font_color", color)
	hype_label.pivot_offset = hype_label.size / 2.0
	hype_label.scale = Vector2(0.3, 0.3)
	hype_label.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel()
	t.tween_property(hype_label, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(hype_label, "modulate:a", 1.0, 0.15)
	t.chain().tween_interval(0.8)
	t.chain().tween_property(hype_label, "modulate:a", 0.0, 0.35)
