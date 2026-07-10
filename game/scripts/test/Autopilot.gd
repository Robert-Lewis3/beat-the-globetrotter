extends Node
## Headless E2E driver. Inert unless the GT_AUTOPILOT env var is set to "1"
## (win) or "2" (expect defeat: give up when the Defeat screen appears).
## Prints ROOMCODE:XXXX so an external script can join simulated players,
## then plays through the whole game and exits 0 on the expected ending.

var mode := ""
var shots_dir := ""
var _timer: Timer
var _last_screen := ""
var _open_since := 0.0
var _started := false
var _shot_taken := {}

func _ready() -> void:
	mode = OS.get_environment("GT_AUTOPILOT")
	if mode == "":
		return
	shots_dir = OS.get_environment("GT_SHOTS_DIR")
	print("AUTOPILOT: active mode=", mode)
	Net.room_ready.connect(func(code): print("ROOMCODE:", code))
	_timer = Timer.new()
	_timer.wait_time = 0.4
	_timer.timeout.connect(_tick)
	add_child(_timer)
	_timer.start()
	get_tree().create_timer(180.0).timeout.connect(func():
		printerr("AUTOPILOT: TIMEOUT")
		get_tree().quit(1))

func _tick() -> void:
	if Main.I == null or Main.I.current == null:
		return
	var s: Control = Main.I.current
	var path: String = s.get_script().resource_path
	var screen: String = path.get_file().get_basename()
	if screen != _last_screen:
		_last_screen = screen
		print("AUTOPILOT: screen=", screen)
		if shots_dir != "" and not _shot_taken.has(screen):
			_shot(screen)
			return    # act on the next tick, after the screenshot

	match screen:
		"TitleScreen":
			s._start()
		"LobbyScreen":
			if Net.room_code != "" and GameState.connected_count() >= 4 and not _started:
				_started = true
				print("AUTOPILOT: players=", GameState.connected_count(), " starting game")
				s._start_game()
		"VSScreen":
			s._fight()
		"BattleScreen":
			_battle_tick(s)
		"VictoryScreen":
			var board := GameState.leaderboard()
			print("AUTOPILOT: VICTORY board=", JSON.stringify(board))
			if mode == "1":
				if board.size() >= 1 and int(board[0]["score"]) > 0:
					print("AUTOPILOT: PASS")
					get_tree().quit(0)
				else:
					printerr("AUTOPILOT: FAIL empty leaderboard")
					get_tree().quit(1)
			else:
				printerr("AUTOPILOT: FAIL expected defeat, got victory")
				get_tree().quit(1)
		"DefeatScreen":
			if mode == "2":
				print("AUTOPILOT: DEFEAT reached as expected — PASS")
				get_tree().quit(0)
			else:
				printerr("AUTOPILOT: FAIL unexpected defeat")
				get_tree().quit(1)

func _battle_tick(s: Control) -> void:
	match s.phase:
		s.Phase.IDLE:
			_open_since = Time.get_ticks_msec() / 1000.0
			s._show_question()
		s.Phase.OPEN:
			# players answer on their own; force the lock if they stall
			if Time.get_ticks_msec() / 1000.0 - _open_since > 6.0:
				print("AUTOPILOT: forcing lock (answers=", GameState.answers.size(), ")")
				s._lock()
		s.Phase.LOCKED:
			s._reveal()
			print("AUTOPILOT: boss=", GameState.boss_index,
				" q=", GameState.question_index, " ot=", GameState.in_overtime,
				" fraction=", s.last_fraction, " hp=", GameState.boss_hp,
				" combo=", GameState.combo)
		s.Phase.REVEALED:
			var key := "BattleScreen_reveal_boss%d" % GameState.boss_index
			if shots_dir != "" and not _shot_taken.has(key):
				_shot(key)
				return
			s._next()
		s.Phase.KO:
			if shots_dir != "" and not _shot_taken.has("BattleScreen_ko"):
				_shot("BattleScreen_ko")
				return
			s._continue_after_ko()

## Save a screenshot once per unique key (skipped in headless / when unset).
func _shot(key: String) -> void:
	if shots_dir == "" or _shot_taken.has(key):
		return
	_shot_taken[key] = true
	_timer.paused = true
	await get_tree().create_timer(0.7).timeout
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(shots_dir.path_join(key + ".png"))
		print("AUTOPILOT: shot ", key)
	_timer.paused = false
