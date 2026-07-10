class_name Arena
extends Control
## Fully coded arena backgrounds matching the handoff briefs:
##   "airport"   — sunrise tarmac: dawn gradient, runway lights, control tower
##   "temple"    — mountain temple at dusk: purple-to-rose, mountains, pagoda
##   "worldtour" — night stage: starry navy-to-violet, globe motif, skyline
##   "title"     — generic starfield for menu screens

var theme_name := "title"
var _stars := []

func _init(arena_theme: String = "title") -> void:
	theme_name = arena_theme
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(arena_theme)
	for i in range(90):
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(1.0, 3.0)))

func _draw() -> void:
	var w := size.x
	var h := size.y
	match theme_name:
		"airport":
			_gradient(Color(0.16, 0.10, 0.29), Color(1.0, 0.60, 0.29))
			# sun
			draw_circle(Vector2(w * 0.5, h * 0.72), 110, Color(1.0, 0.85, 0.45, 0.9))
			var sil := Color(0.07, 0.05, 0.13)
			# tarmac
			draw_rect(Rect2(0, h * 0.78, w, h * 0.22), sil)
			# runway centerline dashes + edge lights
			for i in range(9):
				var x := w * (0.06 + 0.11 * i)
				draw_rect(Rect2(x, h * 0.885, w * 0.05, 10), Color(1.0, 0.85, 0.45, 0.5))
				draw_circle(Vector2(x, h * 0.81), 5, Color(0.4, 0.9, 1.0, 0.9))
				draw_circle(Vector2(x, h * 0.97), 5, Color(1.0, 0.55, 0.3, 0.9))
			# control tower
			draw_rect(Rect2(w * 0.82, h * 0.46, 36, h * 0.32), sil)
			draw_rect(Rect2(w * 0.82 - 34, h * 0.40, 104, 52), sil)
			draw_circle(Vector2(w * 0.82 + 18, h * 0.40), 7, Color(1.0, 0.3, 0.3))
			# distant terminal
			draw_rect(Rect2(w * 0.04, h * 0.68, w * 0.22, h * 0.10), sil)
		"temple":
			_gradient(Color(0.23, 0.10, 0.36), Color(1.0, 0.45, 0.62))
			var far := Color(0.16, 0.08, 0.26)
			var near := Color(0.09, 0.05, 0.16)
			# far mountain range
			_triangle(Vector2(w * 0.05, h), Vector2(w * 0.28, h * 0.34), Vector2(w * 0.55, h), far)
			_triangle(Vector2(w * 0.40, h), Vector2(w * 0.68, h * 0.26), Vector2(w * 0.98, h), far)
			_triangle(Vector2(w * 0.70, h), Vector2(w * 0.95, h * 0.40), Vector2(w * 1.2, h), far)
			# near ridge
			_triangle(Vector2(-w * 0.1, h), Vector2(w * 0.18, h * 0.55), Vector2(w * 0.5, h), near)
			# pagoda silhouette on the ridge
			var px := w * 0.18
			var py := h * 0.55
			for tier in range(3):
				var tw := 150.0 - tier * 40.0
				var ty := py - 34 - tier * 44.0
				draw_rect(Rect2(px - tw / 2, ty, tw, 16), near)
				draw_rect(Rect2(px - (tw - 60) / 2, ty + 16, tw - 60, 28), near)
			# ground
			draw_rect(Rect2(0, h * 0.86, w, h * 0.14), near)
		"worldtour":
			_gradient(Color(0.03, 0.03, 0.14), Color(0.26, 0.13, 0.42))
			_draw_stars()
			# globe motif
			var c := Vector2(w * 0.5, h * 0.42)
			var gc := Color(0.45, 0.65, 1.0, 0.22)
			draw_arc(c, 190, 0, TAU, 64, gc, 4.0)
			draw_arc(c, 190, 0, TAU, 64, Color(0.45, 0.65, 1.0, 0.06), 40.0)
			for k in range(1, 4):
				var rx := 190.0 * (k / 4.0)
				_ellipse_arc(c, rx, 190, gc)
			for k in range(1, 4):
				var ry := 190.0 * (k / 4.0)
				_ellipse_arc_h(c, 190, ry * 0.5 + 40, gc)
			# skyline
			var sil := Color(0.05, 0.04, 0.12)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var x := 0.0
			while x < w:
				var bw := rng.randf_range(60, 140)
				var bh := rng.randf_range(h * 0.08, h * 0.26)
				draw_rect(Rect2(x, h - bh, bw, bh), sil)
				for wy in range(3):
					for wx in range(2):
						if rng.randf() < 0.5:
							draw_rect(Rect2(x + 14 + wx * 26, h - bh + 16 + wy * 30, 12, 14), Color(1.0, 0.82, 0.29, 0.35))
				x += bw + rng.randf_range(8, 30)
			# stage floor
			draw_rect(Rect2(0, h * 0.9, w, h * 0.1), Color(0.07, 0.05, 0.14))
		_:
			_gradient(Color(0.04, 0.04, 0.10), Color(0.10, 0.06, 0.21))
			_draw_stars()

func _gradient(top: Color, bottom: Color) -> void:
	var strips := 48
	var sh := size.y / strips
	for i in range(strips):
		draw_rect(Rect2(0, i * sh, size.x, sh + 1), top.lerp(bottom, float(i) / strips))

func _draw_stars() -> void:
	for s in _stars:
		var star: Vector3 = s
		draw_circle(Vector2(star.x * size.x, star.y * size.y * 0.75), star.z, Color(1, 1, 1, 0.55))

func _triangle(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), color)

func _ellipse_arc(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(49):
		var t := TAU * i / 48.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_polyline(pts, color, 2.0)

func _ellipse_arc_h(c: Vector2, rx: float, ry: float, color: Color) -> void:
	_ellipse_arc(c, rx, ry, color)
