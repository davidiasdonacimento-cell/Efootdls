extends Node
## Conquistas locais, progresso persistente e recompensas de jogo.

signal achievement_unlocked(achievement_id: String, title: String, reward: int)
signal progress_changed(achievement_id: String, progress: int, target: int)

const SAVE_PATH := "user://efootdls_achievements.cfg"
const DEFINITIONS := {
	"first_goal": {"title": "Primeiro gol", "description": "Marque seu primeiro gol.", "target": 1, "reward": 100, "event": "goal"},
	"sniper": {"title": "Artilheiro", "description": "Marque 10 gols.", "target": 10, "reward": 300, "event": "goal"},
	"goal_machine": {"title": "Máquina de gols", "description": "Marque 50 gols.", "target": 50, "reward": 900, "event": "goal"},
	"first_pass": {"title": "Jogo coletivo", "description": "Faça seu primeiro passe.", "target": 1, "reward": 80, "event": "pass"},
	"playmaker": {"title": "Armador", "description": "Complete 25 passes.", "target": 25, "reward": 250, "event": "pass"},
	"tackler": {"title": "Muralha", "description": "Faça 10 desarmes.", "target": 10, "reward": 250, "event": "tackle"},
	"speedster": {"title": "Velocista", "description": "Corra por 300 segundos.", "target": 300, "reward": 200, "event": "sprint"},
	"debut": {"title": "Estreia", "description": "Termine uma partida.", "target": 1, "reward": 150, "event": "match"},
	"champion": {"title": "Vitória", "description": "Vença uma partida.", "target": 1, "reward": 250, "event": "win"},
	"veteran": {"title": "Veterano", "description": "Jogue 20 partidas.", "target": 20, "reward": 700, "event": "match"}
}

var progress: Dictionary = {}
var unlocked: Dictionary = {}
var profile: Node
var total_sprint_seconds := 0.0
var save_dirty := false

func _ready() -> void:
	load_achievements()

func configure(profile_node: Node) -> void:
	profile = profile_node

func record_event(event_name: String, amount := 1) -> void:
	if amount <= 0:
		return
	for achievement_id in DEFINITIONS.keys():
		var data: Dictionary = DEFINITIONS[achievement_id]
		if str(data["event"]) != event_name:
			continue
		_add_progress(str(achievement_id), amount)

func record_goal(amount := 1) -> void:
	record_event("goal", amount)

func record_pass(amount := 1) -> void:
	record_event("pass", amount)

func record_tackle(amount := 1) -> void:
	record_event("tackle", amount)

func record_match(won: bool) -> void:
	record_event("match", 1)
	if won:
		record_event("win", 1)

func record_sprint(delta: float) -> void:
	total_sprint_seconds += maxf(0.0, delta)
	var whole_seconds := int(floor(total_sprint_seconds))
	if whole_seconds > 0:
		record_event("sprint", whole_seconds)
		total_sprint_seconds -= float(whole_seconds)

func _add_progress(achievement_id: String, amount: int) -> void:
	if unlocked.has(achievement_id):
		return
	var data: Dictionary = DEFINITIONS[achievement_id]
	var current := int(progress.get(achievement_id, 0))
	var target := int(data["target"])
	var updated := mini(target, current + amount)
	progress[achievement_id] = updated
	save_dirty = true
	progress_changed.emit(achievement_id, updated, target)
	if updated >= target:
		_unlock(achievement_id)

func _unlock(achievement_id: String) -> void:
	if unlocked.has(achievement_id):
		return
	var data: Dictionary = DEFINITIONS[achievement_id]
	unlocked[achievement_id] = Time.get_unix_time_from_system()
	var reward := int(data["reward"])
	if is_instance_valid(profile):
		profile.call("add_coins", reward)
	achievement_unlocked.emit(achievement_id, str(data["title"]), reward)
	save_achievements()

func get_achievement(achievement_id: String) -> Dictionary:
	if not DEFINITIONS.has(achievement_id):
		return {}
	var data: Dictionary = DEFINITIONS[achievement_id].duplicate(true)
	data["progress"] = int(progress.get(achievement_id, 0))
	data["unlocked"] = unlocked.has(achievement_id)
	data["ratio"] = clampf(float(data["progress"]) / float(data["target"]), 0.0, 1.0)
	return data

func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for achievement_id in DEFINITIONS.keys():
		result.append(get_achievement(str(achievement_id)))
	return result

func get_unlocked_count() -> int:
	return unlocked.size()

func get_total_count() -> int:
	return DEFINITIONS.size()

func get_completion_percent() -> int:
	if DEFINITIONS.is_empty():
		return 0
	return roundi(float(unlocked.size()) / float(DEFINITIONS.size()) * 100.0)

func save_achievements() -> bool:
	var config := ConfigFile.new()
	config.set_value("achievements", "progress", progress)
	config.set_value("achievements", "unlocked", unlocked)
	var success := config.save(SAVE_PATH) == OK
	if success:
		save_dirty = false
	return success

func load_achievements() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		progress.clear()
		unlocked.clear()
		return false
	progress = config.get_value("achievements", "progress", {})
	unlocked = config.get_value("achievements", "unlocked", {})
	return true

func reset_achievements() -> void:
	progress.clear()
	unlocked.clear()
	total_sprint_seconds = 0.0
	save_dirty = true
	save_achievements()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and save_dirty:
		save_achievements()
