class_name UIKit
## Small factory helpers so every screen shares the same arcade look.

const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")

const C_BG := Color(0.04, 0.04, 0.10)
const C_TEXT := Color(0.91, 0.91, 1.0)
const C_MUTED := Color(0.53, 0.53, 0.73)
const C_CYAN := Color(0.29, 0.89, 1.0)
const C_GOLD := Color(1.0, 0.82, 0.29)
const C_GREEN := Color(0.35, 1.0, 0.61)
const C_RED := Color(1.0, 0.35, 0.35)
const C_PINK := Color(1.0, 0.48, 0.85)

static func label(text: String, size: int = 16, color: Color = C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func button(text: String, size: int = 18, color: Color = C_GOLD) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", color)
	b.add_theme_color_override("font_disabled_color", C_MUTED)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.08, 0.19)
	normal.border_color = color
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(12)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	b.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.13, 0.13, 0.28)
	b.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = color.darkened(0.6)
	b.add_theme_stylebox_override("pressed", pressed)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.border_color = Color(0.25, 0.25, 0.42)
	b.add_theme_stylebox_override("disabled", disabled)
	return b

static func line_edit(placeholder: String, size: int = 20) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.add_theme_font_override("font", FONT)
	e.add_theme_font_size_override("font_size", size)
	e.add_theme_color_override("font_color", C_CYAN)
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.19)
	sb.border_color = C_CYAN
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(14)
	e.add_theme_stylebox_override("normal", sb)
	e.add_theme_stylebox_override("focus", sb)
	return e

static func panel_box(border: Color = Color(0.29, 0.89, 1.0, 0.6)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.09, 0.86)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(28)
	return sb

static func vspace(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

## Anchor a control as a horizontally centered strip at y from the top.
## (PRESET_CENTER_TOP alone grows content rightward from center — this doesn't.)
static func center_x(c: Control, y: float, width: float = 1920.0) -> Control:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = -width / 2.0
	c.offset_right = width / 2.0
	c.offset_top = y
	if c is BoxContainer:
		c.alignment = BoxContainer.ALIGNMENT_CENTER
	return c

## Same, anchored up from the bottom edge. Pass height for containers whose
## children would otherwise stretch to fill the whole strip (e.g. buttons).
static func center_x_bottom(c: Control, y_above_bottom: float, width: float = 1920.0, height: float = 0.0) -> Control:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = -width / 2.0
	c.offset_right = width / 2.0
	c.offset_top = -y_above_bottom
	if height > 0.0:
		c.offset_bottom = -y_above_bottom + height
	if c is BoxContainer:
		c.alignment = BoxContainer.ALIGNMENT_CENTER
	return c
