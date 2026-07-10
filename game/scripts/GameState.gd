extends Node
## Central game state: players, scores, boss HP, combo, question grading,
## and the phone-facing state broadcasts. Screens drive this; it owns the rules.

signal players_changed
signal answer_received(answer_count: int)

const QUESTION_SECONDS := 25
const HIT_THRESHOLD := 0.5      # fraction correct that counts as "the room got it"
const BASE_POINTS := 100
const SPEED_BONUS_MAX := 50

var server_url := "http://localhost:3000"
var team_name := "THE OFFICE"

var boss_index := 0
var question_index := 0
var in_overtime := false
var boss_hp := 100.0            # percent
var combo := 0
var max_combo := 0

var players := {}               # id -> {name: String, score: int, correct: int, connected: bool}
var answers := {}               # id -> {answer, at}  (current question only)
var collecting := false
var question_started_ms := 0
var question_deadline_ms := 0
var question_serial := 0        # unique id per asked question, for phones

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://server_config.cfg") == OK:
		server_url = str(cfg.get_value("server", "url", server_url))
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.player_answer.connect(_on_player_answer)

# ------------------------------------------------------------------ players
func _on_player_joined(id: String, player_name: String) -> void:
	if players.has(id):
		players[id]["connected"] = true
		players[id]["name"] = player_name
	else:
		players[id] = {"name": player_name, "score": 0, "correct": 0, "connected": true}
	players_changed.emit()

func _on_player_left(id: String) -> void:
	if players.has(id):
		players[id]["connected"] = false
		players_changed.emit()

func connected_count() -> int:
	var n := 0
	for id in players:
		if players[id]["connected"]:
			n += 1
	return n

# ------------------------------------------------------------------ run
func reset_run() -> void:
	boss_index = 0
	question_index = 0
	in_overtime = false
	boss_hp = 100.0
	combo = 0
	max_combo = 0
	answers = {}
	collecting = false
	for id in players:
		players[id]["score"] = 0
		players[id]["correct"] = 0

func reset_boss_fight() -> void:
	question_index = 0
	in_overtime = false
	boss_hp = 100.0
	combo = 0
	answers = {}
	collecting = false

func current_boss() -> Dictionary:
	return Questions.BOSSES[boss_index]

func current_question() -> Dictionary:
	var boss := current_boss()
	if in_overtime:
		return boss["overtime"]
	return boss["questions"][question_index]

func question_number() -> int:
	# 1-based across the whole game, matching the handoff numbering
	return boss_index * Questions.QUESTIONS_PER_BOSS + question_index + 1

# ------------------------------------------------------------------ questions
func start_question() -> void:
	answers = {}
	collecting = true
	question_serial += 1
	question_started_ms = _now_ms()
	question_deadline_ms = question_started_ms + QUESTION_SECONDS * 1000
	var q := current_question()
	var shared := {
		"phase": "question",
		"qId": question_serial,
		"qNum": question_index + 1,
		"qTotal": Questions.QUESTIONS_PER_BOSS,
		"bossName": current_boss()["name"],
		"kind": q["kind"],
		"text": q["text"],
		"deadlineMs": question_deadline_ms,
	}
	if q["kind"] == "mc":
		shared["options"] = q["options"]
	if in_overtime:
		shared["qNum"] = "OT"
	Net.broadcast(shared)

func _on_player_answer(id: String, answer, at: int) -> void:
	if not collecting:
		return
	if not players.has(id):
		return
	if answers.has(id):
		return                    # first answer locks in
	answers[id] = {"answer": answer, "at": at}
	answer_received.emit(answers.size())

func lock_question() -> void:
	collecting = false
	Net.broadcast({"phase": "locked"})

func all_answered() -> bool:
	var n := connected_count()
	return n > 0 and answers.size() >= n

func seconds_left() -> float:
	return max(0.0, (question_deadline_ms - _now_ms()) / 1000.0)

## Grade the current question. Returns:
##   fraction, correct_count, total, distribution (mc: count per option),
##   per_player: id -> {answered, correct, points}
func grade_question() -> Dictionary:
	collecting = false
	var q := current_question()
	var total := connected_count()
	var correct_count := 0
	var distribution := [0, 0, 0, 0]
	var per_player := {}

	for id in players:
		if not players[id]["connected"] and not answers.has(id):
			continue
		if not answers.has(id):
			per_player[id] = {"answered": false, "correct": false, "points": 0}
			continue
		var a: Dictionary = answers[id]
		var is_correct := false
		if q["kind"] == "mc":
			# JSON numbers arrive as floats; strings from a tampered client too
			var raw = a["answer"]
			var idx := -1
			if raw is float or raw is int:
				idx = int(raw)
			elif str(raw).is_valid_int():
				idx = int(str(raw))
			if idx >= 0 and idx < 4:
				distribution[idx] += 1
			is_correct = idx == int(q["correct"])
		else:
			is_correct = Questions.open_answer_correct(str(a["answer"]), q["accepted"])
		var points := 0
		if is_correct:
			correct_count += 1
			var elapsed: float = clamp((int(a["at"]) - question_started_ms) / 1000.0, 0.0, QUESTION_SECONDS)
			var frac_left: float = 1.0 - elapsed / float(QUESTION_SECONDS)
			points = BASE_POINTS + int(round(SPEED_BONUS_MAX * frac_left))
			players[id]["score"] += points
			players[id]["correct"] += 1
		per_player[id] = {"answered": true, "correct": is_correct, "points": points}

	var fraction := 0.0
	if total > 0:
		fraction = float(correct_count) / float(total)

	# Damage + combo
	if not in_overtime:
		boss_hp = max(0.0, boss_hp - 25.0 * fraction)
	if fraction >= HIT_THRESHOLD:
		combo += 1
		max_combo = max(max_combo, combo)
	else:
		combo = 0

	# Tell every phone its own result
	Net.broadcast({
		"phase": "reveal",
		"answerText": q["answer_text"],
		"fact": q["fact"],
	}, per_player)

	return {
		"fraction": fraction,
		"correct_count": correct_count,
		"total": total,
		"distribution": distribution,
		"per_player": per_player,
	}

## After grading question 4 (or overtime): what happens next?
##   "next_question" | "overtime" | "ko" | "defeat"
func next_step(last_fraction: float) -> String:
	if in_overtime:
		if last_fraction >= HIT_THRESHOLD:
			boss_hp = 0.0
			return "ko"
		return "defeat"
	if question_index < Questions.QUESTIONS_PER_BOSS - 1:
		return "next_question"
	if boss_hp <= 0.01:
		return "ko"
	return "overtime"

func advance_question() -> void:
	question_index += 1

func enter_overtime() -> void:
	in_overtime = true

# ------------------------------------------------------------------ broadcasts
func broadcast_lobby() -> void:
	Net.broadcast({"phase": "lobby"})

func broadcast_vs() -> void:
	var boss := current_boss()
	Net.broadcast({"phase": "vs", "bossName": boss["name"] + " — " + boss["title"]})

func broadcast_ko() -> void:
	Net.broadcast({"phase": "ko", "bossName": current_boss()["name"]})

func broadcast_end(victory: bool) -> void:
	var board := leaderboard()
	var top := []
	for i in range(min(3, board.size())):
		top.append(board[i])
	var per_player := {}
	for i in range(board.size()):
		per_player[board[i]["playerId"]] = {"rank": i + 1, "score": board[i]["score"]}
	Net.broadcast({
		"phase": "end",
		"victory": victory,
		"teamName": team_name,
		"leaderboard": top,
	}, per_player)

func leaderboard() -> Array:
	var rows := []
	for id in players:
		rows.append({
			"playerId": id,
			"name": players[id]["name"],
			"score": players[id]["score"],
			"correct": players[id]["correct"],
		})
	rows.sort_custom(func(a, b): return a["score"] > b["score"])
	return rows

func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
