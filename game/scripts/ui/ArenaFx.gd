class_name ArenaFx
extends Control
## Animated layer that sits over the (static, drawn-once) Arena: twinkling
## stars, a turning globe, and drifting weather particles per stage.

var theme_name := "title"
var t := 0.0
var _animates_draw := false
var _stars := []       # Vector3(x_frac, y_frac, phase)

func _init(arena_theme: String = "title") -> void:
	theme_name = arena_theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_animates_draw = theme_name == "worldtour" or theme_name == "title"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(arena_theme) + 991
	var count := 30 if _animates_draw else 0
	for i in range(count):
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.7, rng.randf() * TAU))

func _ready() -> void:
	match theme_name:
		"desert":
			# sand blowing across the flats, plus a lazy high-altitude drift
			_weather(Vector2(-1, -0.05), 26, Color(0.92, 0.76, 0.52), 0.62, 150.0, 320.0, 4.0, 9.0)
			_weather(Vector2(-1, 0.02), 10, Color(1.0, 0.88, 0.66), 0.30, 60.0, 140.0, 3.0, 6.0)
		"temple":
			# cold mist rolling through the valley
			_weather(Vector2(1, -0.08), 18, Color(0.85, 0.75, 0.95), 0.22, 40.0, 110.0, 26.0, 54.0)
		"airport":
			_weather(Vector2(-1, 0.0), 14, Color(0.95, 0.85, 0.7), 0.28, 70.0, 170.0, 5.0, 11.0)

## A slow horizontal particle band covering the full screen.
func _weather(dir: Vector2, amount: int, color: Color, alpha: float,
		vmin: float, vmax: float, smin: float, smax: float) -> void:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0            # start mid-flight, no empty first seconds
	p.position = Vector2(960, 540)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1150, 540)
	p.direction = dir
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.25, Color(color.r, color.g, color.b, alpha))
	g.add_point(0.75, Color(color.r, color.g, color.b, alpha))
	p.color_ramp = g
	add_child(p)
	p.emitting = true

func _process(delta: float) -> void:
	t += delta
	if _animates_draw:
		queue_redraw()

func _draw() -> void:
	if not _animates_draw:
		return
	# twinkling stars
	for s in _stars:
		var star: Vector3 = s
		var tw: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 1.9 + star.z))
		draw_circle(Vector2(star.x * size.x, star.y * size.y),
			2.2 + tw, Color(1, 1, 1, 0.30 * tw))

	if theme_name == "worldtour":
		# meridians sweeping around the globe, so it reads as turning
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		var r := 190.0
		var col := Color(0.55, 0.75, 1.0, 0.22)
		for k in range(4):
			var phase: float = t * 0.35 + TAU * k / 4.0
			var rx: float = abs(cos(phase)) * r
			if rx < 2.0:
				continue
			var a: float = 0.10 + 0.16 * abs(cos(phase))
			_meridian(c, rx, r, Color(col.r, col.g, col.b, a))

func _meridian(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(41):
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, color, 2.0)
