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

func _ready() -> void:
	I = self
	goto("title")

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
