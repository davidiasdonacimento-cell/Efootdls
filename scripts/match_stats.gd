extends Node
## Estatísticas da partida e dados para o resumo pós-jogo.

signal stats_changed(snapshot: Dictionary)

var home_shots := 0
var away_shots := 0
var home_shots_on_target := 0
var away_shots_on_target := 0
var home_passes := 0
var away_passes := 0
var home_tackles := 0
var away_tackles := 0
var home_saves := 0
var away_saves := 0
var home_corners := 0
var away_corners := 0
var home_fouls := 0
var away_fouls := 0
var home_possession_seconds := 0.0
var away_possession_seconds := 0.0
var last_possession_team := 0
var match_seconds := 0.0
var successful_home_passes := 0
var successful_away_passes := 0
var longest_home_shot := 0.0
var fastest_ball_speed := 0.0
var goal_events: Array[Dictionary] = []
var event_log: Array[Dictionary] = []

func _process(delta: float) -> void:
	match_seconds += delta
	if last_possession_team == 1:
		home_possession_seconds += delta
	elif last_possession_team == 2:
		away_possession_seconds += delta

func record_shot(team: int, on_target: bool, distance: float = 0.0) -> void:
	if team == 1:
		home_shots += 1
		if on_target:
			home_shots_on_target += 1
		longest_home_shot = maxf(longest_home_shot, distance)
	else:
		away_shots += 1
		if on_target:
			away_shots_on_target += 1
	_add_event("CHUTE", team, {"on_target": on_target, "distance": distance})
	_emit_snapshot()

func record_pass(team: int, successful: bool = true) -> void:
	if team == 1:
		home_passes += 1
		if successful:
			successful_home_passes += 1
	else:
		away_passes += 1
		if successful:
			successful_away_passes += 1
	_add_event("PASSE", team, {"successful": successful})
	_emit_snapshot()

func record_tackle(team: int, successful: bool) -> void:
	if team == 1:
		home_tackles += 1
	else:
		away_tackles += 1
	_add_event("DESARME", team, {"successful": successful})
	_emit_snapshot()

func record_save(team: int) -> void:
	if team == 1:
		home_saves += 1
	else:
		away_saves += 1
	_add_event("DEFESA", team)
	_emit_snapshot()

func record_goal(team: int, scorer: String = "Jogador") -> void:
	var event := {
		"team": team,
		"scorer": scorer,
		"minute": int(match_seconds / 60.0),
		"period": 1 if match_seconds < 180.0 else 2
	}
	goal_events.append(event)
	_add_event("GOL", team, event)
	_emit_snapshot()

func record_corner(team: int) -> void:
	if team == 1:
		home_corners += 1
	else:
		away_corners += 1
	_emit_snapshot()

func record_foul(team: int) -> void:
	if team == 1:
		home_fouls += 1
	else:
		away_fouls += 1
	_emit_snapshot()

func set_possession_team(team: int) -> void:
	last_possession_team = team

func update_ball_speed(speed: float) -> void:
	fastest_ball_speed = maxf(fastest_ball_speed, speed)

func get_home_possession_percent() -> int:
	var total := home_possession_seconds + away_possession_seconds
	if total <= 0.0:
		return 50
	return roundi(home_possession_seconds / total * 100.0)

func get_away_possession_percent() -> int:
	return 100 - get_home_possession_percent()

func get_shot_accuracy(team: int) -> float:
	if team == 1:
		return 0.0 if home_shots == 0 else float(home_shots_on_target) / home_shots
	return 0.0 if away_shots == 0 else float(away_shots_on_target) / away_shots

func get_summary() -> Dictionary:
	return {
		"home_shots": home_shots,
		"away_shots": away_shots,
		"home_shots_on_target": home_shots_on_target,
		"away_shots_on_target": away_shots_on_target,
		"home_passes": home_passes,
		"away_passes": away_passes,
		"home_tackles": home_tackles,
		"away_tackles": away_tackles,
		"home_saves": home_saves,
		"away_saves": away_saves,
		"home_possession": get_home_possession_percent(),
		"away_possession": get_away_possession_percent(),
		"goal_events": goal_events.duplicate(true),
		"fastest_ball_speed": fastest_ball_speed
	}

func _add_event(event_type: String, team: int, extra := {}) -> void:
	var entry := {
		"type": event_type,
		"team": team,
		"time": match_seconds,
		"data": extra.duplicate(true)
	}
	event_log.append(entry)
	if event_log.size() > 120:
		event_log.pop_front()

func _emit_snapshot() -> void:
	stats_changed.emit(get_summary())

func reset_stats() -> void:
	home_shots = 0
	away_shots = 0
	home_shots_on_target = 0
	away_shots_on_target = 0
	home_passes = 0
	away_passes = 0
	home_tackles = 0
	away_tackles = 0
	home_saves = 0
	away_saves = 0
	home_corners = 0
	away_corners = 0
	home_fouls = 0
	away_fouls = 0
	home_possession_seconds = 0.0
	away_possession_seconds = 0.0
	last_possession_team = 0
	match_seconds = 0.0
	successful_home_passes = 0
	successful_away_passes = 0
	longest_home_shot = 0.0
	fastest_ball_speed = 0.0
	goal_events.clear()
	event_log.clear()
	_emit_snapshot()
