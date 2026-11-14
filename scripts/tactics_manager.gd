extends Node
## Gerencia comportamento coletivo e altera a postura do time durante o jogo.

signal tactic_changed(tactic_id: String, title: String)

enum Tactic { BALANCED, ATTACKING, DEFENSIVE, PRESSING }

const TACTIC_DATA := {
	Tactic.BALANCED: {"id": "balanced", "title": "EQUILIBRADO", "line": 0.0, "width": 1.0, "pressure": 1.0, "speed": 1.0},
	Tactic.ATTACKING: {"id": "attacking", "title": "OFENSIVO", "line": -5.0, "width": 1.12, "pressure": 1.22, "speed": 1.08},
	Tactic.DEFENSIVE: {"id": "defensive", "title": "DEFENSIVO", "line": 5.0, "width": 0.82, "pressure": 0.76, "speed": 0.92},
	Tactic.PRESSING: {"id": "pressing", "title": "PRESSÃO ALTA", "line": -2.0, "width": 1.05, "pressure": 1.5, "speed": 1.12}
}

var allies: Array[CharacterBody3D] = []
var opponents: Array[CharacterBody3D] = []
var home_positions: Array[Vector3] = []
var opponent_positions: Array[Vector3] = []
var current_tactic := Tactic.BALANCED
var update_timer := 0.0
var update_interval := 0.75
var ball: Node3D
var active := true
var tactical_bonus := 1.0

func configure(home_team: Array[CharacterBody3D], away_team: Array[CharacterBody3D], match_ball: Node3D) -> void:
	allies = home_team.duplicate()
	opponents = away_team.duplicate()
	ball = match_ball
	home_positions.clear()
	opponent_positions.clear()
	for athlete in allies:
		home_positions.append(athlete.global_position if is_instance_valid(athlete) else Vector3.ZERO)
	for rival in opponents:
		opponent_positions.append(rival.global_position if is_instance_valid(rival) else Vector3.ZERO)
	_apply_tactic()

func _process(delta: float) -> void:
	if not active:
		return
	update_timer -= delta
	if update_timer > 0.0:
		return
	update_timer = update_interval
	_update_team_shape()

func cycle_tactic() -> String:
	var next_value := (int(current_tactic) + 1) % TACTIC_DATA.size()
	set_tactic(next_value)
	return get_tactic_title()

func set_tactic(value: int) -> void:
	if value < Tactic.BALANCED or value > Tactic.PRESSING:
		return
	if current_tactic == value:
		return
	current_tactic = value
	_apply_tactic()
	tactic_changed.emit(str(TACTIC_DATA[current_tactic]["id"]), get_tactic_title())

func set_tactic_by_name(value: String) -> bool:
	for key in TACTIC_DATA.keys():
		if str(TACTIC_DATA[key]["id"]) == value:
			set_tactic(int(key))
			return true
	return false

func _apply_tactic() -> void:
	var data: Dictionary = TACTIC_DATA[current_tactic]
	tactical_bonus = float(data["pressure"])
	for index in range(allies.size()):
		if not is_instance_valid(allies[index]):
			continue
		var base := home_positions[index] if index < home_positions.size() else allies[index].global_position
		var moved := base
		moved.z += float(data["line"])
		moved.x *= float(data["width"])
		allies[index].call("set_home_position", moved)
	for index in range(opponents.size()):
		if not is_instance_valid(opponents[index]):
			continue
		var base := opponent_positions[index] if index < opponent_positions.size() else opponents[index].global_position
		var moved := base
		moved.z -= float(data["line"]) * 0.35
		moved.x *= 1.0 / maxf(float(data["width"]), 0.1)
		opponents[index].call("set_home_position", moved)

func _update_team_shape() -> void:
	if not is_instance_valid(ball):
		return
	var ball_position: Vector3 = ball.global_position
	for index in range(allies.size()):
		var athlete := allies[index]
		if not is_instance_valid(athlete):
			continue
		var base := home_positions[index] if index < home_positions.size() else athlete.global_position
		var support_shift := clampf((19.0 - ball_position.z) * 0.22, -4.0, 4.0)
		var target := base + Vector3(0.0, 0.0, support_shift)
		var data: Dictionary = TACTIC_DATA[current_tactic]
		target.z += float(data["line"])
		athlete.call("set_home_position", target)

func get_tactic_id() -> String:
	return str(TACTIC_DATA[current_tactic]["id"])

func get_tactic_title() -> String:
	return str(TACTIC_DATA[current_tactic]["title"])

func get_pressure_multiplier() -> float:
	return tactical_bonus

func get_tactic_description() -> String:
	match current_tactic:
		Tactic.ATTACKING:
			return "A equipe avança e ocupa o campo ofensivo."
		Tactic.DEFENSIVE:
			return "A equipe recua e protege o próprio campo."
		Tactic.PRESSING:
			return "Os jogadores pressionam a saída de bola."
	return "A equipe mantém equilíbrio entre defesa e ataque."

func pause_tactics() -> void:
	active = false

func resume_tactics() -> void:
	active = true
	update_timer = 0.0

func reset_tactics() -> void:
	current_tactic = Tactic.BALANCED
	_apply_tactic()

func get_team_shape() -> Dictionary:
	var positions: Array[Vector3] = []
	for athlete in allies:
		if is_instance_valid(athlete):
			positions.append(athlete.global_position)
	return {"tactic": get_tactic_id(), "positions": positions, "pressure": tactical_bonus}
