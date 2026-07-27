class_name CRT
extends CanvasLayer
## Full-screen arcade-cabinet post-processing, sitting above every screen.
## Purely visual: it never accepts input (see mouse_filter below), so buttons
## underneath keep working.

const SHADER := preload("res://shaders/crt.gdshader")

var rect: ColorRect

func _init() -> void:
	layer = 100

func _ready() -> void:
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	# Critical: without this the full-screen rect would swallow every click.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)

## Screens that need pixel-exact output (the QR code) turn this off.
func set_active(on: bool) -> void:
	visible = on
