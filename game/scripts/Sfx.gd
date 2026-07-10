extends Node
## Fire-and-forget retro sound effects (Kenney Digital Audio, CC0).

var streams := {}

func _ready() -> void:
	for key in ["hit", "wrong", "ko", "victory", "select", "combo", "defeat", "tick"]:
		var path := "res://assets/audio/%s.ogg" % key
		if ResourceLoader.exists(path):
			streams[key] = load(path)

func play(key: String, volume_db: float = 0.0) -> void:
	if not streams.has(key):
		return
	var p := AudioStreamPlayer.new()
	p.stream = streams[key]
	p.volume_db = volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
