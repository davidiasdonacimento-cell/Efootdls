extends RefCounted
## Sistema de treinos com metas, pontuação e evolução de habilidades.

signal training_completed(drill_id: String, score: int, stars: int)

const DRILLS := {
	"shooting": {"title": "Finalização", "target": 8, "time": 60, "reward": 120},
	"passing": {"title": "Precisão de passe", "target": 12, "time": 75, "reward": 100},
	"dribbling": {"title": "Condução", "target": 10, "time": 60, "reward": 110},
	"sprint": {"title": "Velocidade", "target": 6, "time": 45, "reward": 90},
	"defending": {"title": "Desarme", "target": 7, "time": 60, "reward": 105}
}

var active_drill := ""
var remaining_time := 0.0
var current_score := 0
var target_score := 0
var reward := 0
var completed := false
var best_scores: Dictionary = {}
var action_history: Array[Dictionary] = []

func start_drill(drill_id: String) -> bool:
	if not DRILLS.has(drill_id):
		return false
	active_drill = drill_id
	var data: Dictionary = DRILLS[drill_id]
	remaining_time = float(data["time"])
	target_score = int(data["target"])
	reward = int(data["reward"])
	current_score = 0
	completed = false
	action_history.clear()
	return true

func tick(delta: float) -> void:
	if active_drill.is_empty() or completed:
		return
	remaining_time = maxf(0.0, remaining_time - delta)
	if remaining_time <= 0.0:
		_finish_drill()

func register_action(action: String, quality: float = 1.0) -> int:
	if active_drill.is_empty() or completed:
		return 0
	var points := _score_action(action, quality)
	current_score += points
	action_history.append({
		"action": action,
		"quality": clampf(quality, 0.0, 1.0),
		"points": points,
		"time_left": remaining_time
	})
	if current_score >= target_score:
		_finish_drill()
	return points

func _score_action(action: String, quality: float) -> int:
	var accepted := false
	match active_drill:
		"shooting":
			accepted = action in ["goal", "shot_on_target"]
		"passing":
			accepted = action in ["accurate_pass", "assist"]
		"dribbling":
			accepted = action in ["successful_dribble", "cone_pass"]
		"sprint":
			accepted = action in ["sprint_finish", "speed_gate"]
		"defending":
			accepted = action in ["tackle", "interception"]
	if not accepted:
		return 0
	var multiplier := 1.0 + clampf(quality, 0.0, 1.0)
	return maxi(1, roundi(2.0 * multiplier))

func _finish_drill() -> void:
	if completed:
		return
	completed = true
	var stars := get_stars()
	var previous := int(best_scores.get(active_drill, 0))
	best_scores[active_drill] = maxi(previous, current_score)
	training_completed.emit(active_drill, current_score, stars)

func get_stars() -> int:
	if current_score >= target_score * 1.5:
		return 3
	if current_score >= target_score:
		return 2
	if current_score >= target_score * 0.5:
		return 1
	return 0

func get_completion_ratio() -> float:
	if target_score <= 0:
		return 0.0
	return clampf(float(current_score) / float(target_score), 0.0, 1.0)

func get_remaining_time_text() -> String:
	var seconds := int(ceil(remaining_time))
	return "%02d:%02d" % [int(seconds / 60), seconds % 60]

func get_drill_info(drill_id: String) -> Dictionary:
	if not DRILLS.has(drill_id):
		return {}
	var info: Dictionary = DRILLS[drill_id].duplicate(true)
	info["best_score"] = int(best_scores.get(drill_id, 0))
	return info

func get_all_drills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for drill_id in DRILLS.keys():
		result.append(get_drill_info(str(drill_id)))
	return result

func claim_reward() -> int:
	if not completed:
		return 0
	var multiplier := 1.0 + float(get_stars()) * 0.25
	var earned := roundi(float(reward) * multiplier)
	active_drill = ""
	completed = false
	return earned

func save_to_config(config: ConfigFile) -> void:
	config.set_value("training", "best_scores", best_scores)

func load_from_config(config: ConfigFile) -> void:
	best_scores = config.get_value("training", "best_scores", {})
