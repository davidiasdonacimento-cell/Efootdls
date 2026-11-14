extends Node
## Objetivos diários e semanais com acompanhamento e recompensas.

signal objective_progress(objective_id: String, progress: int, target: int)
signal objective_completed(objective_id: String, reward: int)
signal objectives_refreshed

const SAVE_PATH := "user://efootdls_objectives.cfg"
const DAILY_POOL := [
	{"id": "daily_goal", "title": "Marque 2 gols", "event": "goal", "target": 2, "reward": 150},
	{"id": "daily_pass", "title": "Complete 5 passes", "event": "pass", "target": 5, "reward": 120},
	{"id": "daily_tackle", "title": "Faça 3 desarmes", "event": "tackle", "target": 3, "reward": 130},
	{"id": "daily_shot", "title": "Finalize 4 vezes", "event": "shot", "target": 4, "reward": 110},
	{"id": "daily_win", "title": "Vença uma partida", "event": "win", "target": 1, "reward": 250}
]
const WEEKLY_POOL := [
	{"id": "weekly_goal", "title": "Marque 12 gols", "event": "goal", "target": 12, "reward": 600},
	{"id": "weekly_pass", "title": "Complete 35 passes", "event": "pass", "target": 35, "reward": 500},
	{"id": "weekly_match", "title": "Jogue 5 partidas", "event": "match", "target": 5, "reward": 450},
	{"id": "weekly_win", "title": "Vença 3 partidas", "event": "win", "target": 3, "reward": 700}
]

var daily_objectives: Array[Dictionary] = []
var weekly_objectives: Array[Dictionary] = []
var profile: Node
var daily_stamp := ""
var weekly_stamp := ""

func _ready() -> void:
	load_objectives()
	_refresh_expired_objectives()

func configure(profile_node: Node) -> void:
	profile = profile_node

func record_event(event_name: String, amount := 1) -> void:
	if amount <= 0:
		return
	_update_group(daily_objectives, event_name, amount)
	_update_group(weekly_objectives, event_name, amount)
	save_objectives()

func _update_group(group: Array[Dictionary], event_name: String, amount: int) -> void:
	for index in range(group.size()):
		var objective: Dictionary = group[index]
		if str(objective["event"]) != event_name or bool(objective["claimed"]):
			continue
		var target := int(objective["target"])
		var updated := mini(target, int(objective["progress"]) + amount)
		objective["progress"] = updated
		group[index] = objective
		objective_progress.emit(str(objective["id"]), updated, target)
		if updated >= target:
			objective["completed"] = true

func claim_objective(objective_id: String) -> int:
	var reward := _claim_from_group(daily_objectives, objective_id)
	if reward < 0:
		reward = _claim_from_group(weekly_objectives, objective_id)
	if reward <= 0:
		return 0
	if is_instance_valid(profile):
		profile.call("add_coins", reward)
	objective_completed.emit(objective_id, reward)
	save_objectives()
	return reward

func _claim_from_group(group: Array[Dictionary], objective_id: String) -> int:
	for index in range(group.size()):
		var objective: Dictionary = group[index]
		if str(objective["id"]) != objective_id:
			continue
		if not bool(objective["completed"]) or bool(objective["claimed"]):
			return 0
		objective["claimed"] = true
		group[index] = objective
		return int(objective["reward"])
	return -1

func _refresh_expired_objectives() -> void:
	var current_day := Time.get_date_string_from_system()
	var current_week := _week_stamp()
	if daily_stamp != current_day or daily_objectives.is_empty():
		daily_stamp = current_day
		daily_objectives = _choose_objectives(DAILY_POOL, 3)
	if weekly_stamp != current_week or weekly_objectives.is_empty():
		weekly_stamp = current_week
		weekly_objectives = _choose_objectives(WEEKLY_POOL, 2)
	save_objectives()
	objectives_refreshed.emit()

func _week_stamp() -> String:
	var date := Time.get_date_dict_from_system()
	var week_number := int((int(date["day"]) + 6) / 7)
	return "%04d-%02d-W%d" % [int(date["year"]), int(date["month"]), week_number]

func _choose_objectives(pool: Array[Dictionary], count: int) -> Array[Dictionary]:
	var choices := pool.duplicate(true)
	choices.shuffle()
	var result: Array[Dictionary] = []
	for index in range(mini(count, choices.size())):
		var objective: Dictionary = choices[index]
		objective["progress"] = 0
		objective["completed"] = false
		objective["claimed"] = false
		result.append(objective)
	return result

func get_daily_objectives() -> Array[Dictionary]:
	return daily_objectives.duplicate(true)

func get_weekly_objectives() -> Array[Dictionary]:
	return weekly_objectives.duplicate(true)

func get_objective(objective_id: String) -> Dictionary:
	for objective in daily_objectives + weekly_objectives:
		if str(objective["id"]) == objective_id:
			return objective.duplicate(true)
	return {}

func get_pending_reward_total() -> int:
	var total := 0
	for objective in daily_objectives + weekly_objectives:
		if bool(objective["completed"]) and not bool(objective["claimed"]):
			total += int(objective["reward"])
	return total

func save_objectives() -> bool:
	var config := ConfigFile.new()
	config.set_value("objectives", "daily", daily_objectives)
	config.set_value("objectives", "weekly", weekly_objectives)
	config.set_value("objectives", "daily_stamp", daily_stamp)
	config.set_value("objectives", "weekly_stamp", weekly_stamp)
	return config.save(SAVE_PATH) == OK

func load_objectives() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		_refresh_expired_objectives()
		return false
	daily_stamp = str(config.get_value("objectives", "daily_stamp", ""))
	weekly_stamp = str(config.get_value("objectives", "weekly_stamp", ""))
	daily_objectives = _read_objective_array(config.get_value("objectives", "daily", []))
	weekly_objectives = _read_objective_array(config.get_value("objectives", "weekly", []))
	return true

func _read_objective_array(source: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if source is Array:
		for objective in source:
			if objective is Dictionary:
				result.append(objective.duplicate(true))
	return result

func reset_objectives() -> void:
	daily_stamp = ""
	weekly_stamp = ""
	daily_objectives.clear()
	weekly_objectives.clear()
	_refresh_expired_objectives()
