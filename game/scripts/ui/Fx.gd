class_name Fx
## One-shot visual effects: impact sparks, dust, screen flash, screen shake.
## Every helper cleans up after itself and is safe to fire mid-animation.

## Self-destruct after `seconds`. The timer is a CHILD of the node, so if the
## screen is torn down first the timer dies with it — nothing is left holding a
## reference to a freed node.
static func _autofree(node: Node, seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = seconds
	timer.autostart = true
	node.add_child(timer)
	timer.timeout.connect(node.queue_free)

## Radial burst of hot sparks — used when a fighter connects.
static func sparks(parent: Node, pos: Vector2, color: Color, amount: int = 30, power: float = 620.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 900)
	p.initial_velocity_min = power * 0.3
	p.initial_velocity_max = power
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.35, color)
	p.color_ramp = g
	parent.add_child(p)
	p.emitting = true
	_autofree(p, 1.4)

## Low puff of dust — used at a fighter's feet when they push off.
static func dust(parent: Node, pos: Vector2, facing: int, color: Color = Color(0.75, 0.65, 0.55)) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 16
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.85
	p.direction = Vector2(-facing, -0.35)
	p.spread = 30.0
	p.gravity = Vector2(0, 140)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 280.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 14.0
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.55))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	parent.add_child(p)
	p.emitting = true
	_autofree(p, 1.4)

## Brief full-screen tint — a hit feels harder when the whole tube reacts.
static func flash(parent: Control, color: Color, peak: float = 0.22, seconds: float = 0.22) -> void:
	var r := ColorRect.new()
	r.color = Color(color.r, color.g, color.b, peak)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	var t := parent.create_tween()
	t.tween_property(r, "color:a", 0.0, seconds)
	t.tween_callback(r.queue_free)

## Decaying positional shake. Returns the control to its exact origin.
## The origin is remembered on the node, so overlapping shakes can never
## accumulate drift.
static func shake(c: Control, intensity: float = 18.0, seconds: float = 0.35) -> void:
	var origin: Vector2
	if c.has_meta("fx_shake_origin"):
		origin = c.get_meta("fx_shake_origin")
	else:
		origin = c.position
		c.set_meta("fx_shake_origin", origin)
	var steps := 8
	var t := c.create_tween()
	for i in range(steps):
		var falloff: float = intensity * (1.0 - float(i) / float(steps))
		var offset := Vector2(
			randf_range(-falloff, falloff),
			randf_range(-falloff * 0.6, falloff * 0.6))
		t.tween_property(c, "position", origin + offset, seconds / float(steps))
	t.tween_property(c, "position", origin, seconds / float(steps))
