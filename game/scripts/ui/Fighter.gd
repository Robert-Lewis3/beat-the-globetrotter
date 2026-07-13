class_name Fighter
extends Node2D
## A pixel fighter: Kenney 16x16 sprite scaled up, with a colored glow outline
## and tween animations (idle bob, lunge, hit flash, KO fall, victory hop).

const PIXEL_SCALE := 11.0       # default; bosses pass bigger values per round

var sprite: Sprite2D
var glow_color: Color
var facing := 1                 # 1 = faces right (hero), -1 = faces left (boss)
var px := PIXEL_SCALE
var _home := Vector2.ZERO
var _bob: Tween

func _init(texture_path: String, color: Color, face_right: bool, pixel_scale: float = PIXEL_SCALE) -> void:
	glow_color = color
	facing = 1 if face_right else -1
	px = pixel_scale
	var tex: Texture2D = load(texture_path)

	# glow: four offset copies behind the sprite
	for offset in [Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		var g := Sprite2D.new()
		g.texture = tex
		g.scale = Vector2(px, px)
		g.position = offset * 1.2
		g.modulate = Color(color.r, color.g, color.b, 0.45)
		g.flip_h = not face_right
		add_child(g)

	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.scale = Vector2(px, px)
	sprite.flip_h = not face_right
	add_child(sprite)

## Half the rendered sprite height — used to keep feet on the same floor
## line regardless of scale.
func half_height() -> float:
	return 8.0 * px

func _ready() -> void:
	_home = position
	start_idle()

func start_idle() -> void:
	if _bob:
		_bob.kill()
	_bob = create_tween().set_loops()
	_bob.tween_property(self, "position:y", _home.y - 10.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob.tween_property(self, "position:y", _home.y, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_idle() -> void:
	if _bob:
		_bob.kill()
		_bob = null

## Attack lunge toward the opponent, then return.
func lunge() -> void:
	stop_idle()
	position = _home
	var t := create_tween()
	t.tween_property(self, "position:x", _home.x + 260.0 * facing, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:x", _home.x, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(start_idle)

## Take a hit: white flash + shake.
func hit() -> void:
	stop_idle()
	position = _home
	var t := create_tween()
	sprite.modulate = Color(6, 6, 6)
	t.tween_property(sprite, "modulate", Color.WHITE, 0.35)
	var shake := create_tween()
	for i in range(5):
		shake.tween_property(self, "position:x", _home.x + (14.0 if i % 2 == 0 else -14.0), 0.05)
	shake.tween_property(self, "position:x", _home.x, 0.05)
	shake.tween_callback(start_idle)

## KO: fall over and fade.
func ko_fall() -> void:
	stop_idle()
	var t := create_tween().set_parallel()
	t.tween_property(self, "rotation_degrees", 90.0 * -facing, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", _home.y + 70.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.25, 1.2)

func victory_hop() -> void:
	stop_idle()
	position = _home
	var t := create_tween().set_loops(3)
	t.tween_property(self, "position:y", _home.y - 60.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position:y", _home.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.finished.connect(start_idle)
