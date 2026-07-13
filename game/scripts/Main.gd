class_name Main
extends Control
## Root node: swaps between the game's screens. Screens are plain Controls
## that build their own UI in code; navigate with Main.goto("name").

static var I: Control = null

const SCREENS := {
	"title": preload("res://scripts/screens/TitleScreen.gd"),
	"lobby": preload("res://scripts/screens/LobbyScreen.gd"),
	"vs": preload("res://scripts/screens/VSScreen.gd"),
	"battle": preload("res://scripts/screens/BattleScreen.gd"),
	"victory": preload("res://scripts/screens/VictoryScreen.gd"),
	"defeat": preload("res://scripts/screens/DefeatScreen.gd"),
}

var current: Control = null
var _quit_armed := false
var _quit_hint: Label = null

func _ready() -> void:
	I = self
	goto("title")

## Esc twice within 2s quits (single press is easy to hit mid-game);
## F11 toggles fullscreen for projector use.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if _quit_armed:
				get_tree().quit()
			_quit_armed = true
			_show_quit_hint()
			get_tree().create_timer(2.0).timeout.connect(func():
				_quit_armed = false
				if _quit_hint:
					_quit_hint.queue_free()
					_quit_hint = null)
		elif event.keycode == KEY_F11:
			var mode := DisplayServer.window_get_mode()
			if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _show_quit_hint() -> void:
	if _quit_hint:
		return
	_quit_hint = UIKit.label("PRESS ESC AGAIN TO QUIT", 14, UIKit.C_RED)
	add_child(UIKit.center_x(_quit_hint, 12))

static func goto(screen: String) -> void:
	I._goto(screen)

func _goto(screen: String) -> void:
	if current:
		current.queue_free()
		current = null
	var s: Control = SCREENS[screen].new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(s)
	current = s
