extends Node
## Regras centrais: início, reinício, gols, bola fora e encerramento.

signal phase_changed(phase: String)
signal goal_awarded(team_id: int, home_score: int, away_score: int)
signal restart_requested(restart_type: String, position: Vector3)
signal match_over(home_score: int, away_score: int)
signal warning(message: String)

enum Phase { PRE_MATCH, KICKOFF, PLAYING, GOAL_PAUSE, HALF_TIME, FULL_TIME, PAUSED }
enum Restart { KICKOFF, THROW_IN, GOAL_KICK, CORNER, FREE_KICK }

var phase: Phase = Phase.PRE_MATCH
var home_score := 0
var away_score := 0
var home_kickoff := true
var last_touch_team := 0
var restart_position := Vector3.ZERO
var goal_pause_remaining := 0.0
var halftime_reached := false
var match_duration := 180.0
var elapsed := 0.0
var home_fouls := 0
var away_fouls := 0
var home_corners := 0
var away_corners := 0
var home_throw_ins := 0
var away_throw_ins := 0
var allow_extra_time := false
var is_tutorial := false

func start_match(duration_seconds := 180.0) -> void:
	home_score = 0
	away_score = 0
	elapsed = 0.0
	home_kickoff = true
	halftime_reached = false
	match_duration = maxf(duration_seconds, 60.0)
	home_fouls = 0
	away_fouls = 0
	home_corners = 0
	away_corners = 0
	home_throw_ins = 0
	away_throw_ins = 0
	_set_phase(Phase.KICKOFF)
	restart_requested.emit("kickoff", Vector3.ZERO)

func update_rules(delta: float) -> void:
	if phase == Phase.PLAYING:
		elapsed += delta
	elif phase == Phase.GOAL_PAUSE:
		goal_pause_remaining = maxf(0.0, goal_pause_remaining - delta)
		if goal_pause_remaining <= 0.0:
			_set_phase(Phase.KICKOFF)
			restart_requested.emit("kickoff", Vector3.ZERO)
	if phase == Phase.PLAYING and elapsed >= match_duration and not allow_extra_time:
		_finish_match()

func start_play_after_restart() -> void:
	if phase == Phase.KICKOFF:
		_set_phase(Phase.PLAYING)

func award_goal(team_id: int) -> void:
	if phase not in [Phase.PLAYING, Phase.KICKOFF]:
		return
	if team_id == 1:
		home_score += 1
	else:
		away_score += 1
	home_kickoff = not home_kickoff
	goal_pause_remaining = 2.0
	_set_phase(Phase.GOAL_PAUSE)
	goal_awarded.emit(team_id, home_score, away_score)

func report_ball_out(position: Vector3, last_team: int, crossed_goal_line: bool) -> void:
	if phase != Phase.PLAYING:
		return
	last_touch_team = last_team
	restart_position = position
	if crossed_goal_line:
		if last_team == 1:
			away_corners += 1
			restart_requested.emit("corner_away", _corner_position(position))
		else:
			restart_requested.emit("goal_kick_home", Vector3(0.0, 0.5, 25.0))
	else:
		if last_team == 1:
			away_throw_ins += 1
		else:
			home_throw_ins += 1
		restart_requested.emit("throw_in", _throw_in_position(position))

func register_foul(team_id: int, position: Vector3) -> void:
	if team_id == 1:
		home_fouls += 1
	else:
		away_fouls += 1
	restart_position = position
	warning.emit("FALTA")
	restart_requested.emit("free_kick", position)

func set_half_time() -> void:
	if halftime_reached:
		return
	halftime_reached = true
	_set_phase(Phase.HALF_TIME)

func resume_second_half() -> void:
	if phase != Phase.HALF_TIME:
		return
	_set_phase(Phase.KICKOFF)
	restart_requested.emit("kickoff", Vector3.ZERO)

func pause_game() -> void:
	if phase in [Phase.PLAYING, Phase.KICKOFF]:
		_set_phase(Phase.PAUSED)

func resume_game() -> void:
	if phase == Phase.PAUSED:
		_set_phase(Phase.PLAYING)

func _finish_match() -> void:
	_set_phase(Phase.FULL_TIME)
	match_over.emit(home_score, away_score)

func _set_phase(value: Phase) -> void:
	phase = value
	phase_changed.emit(get_phase_name())

func _throw_in_position(position: Vector3) -> Vector3:
	return Vector3(clampf(position.x, -20.0, 20.0), 0.35, clampf(position.z, -30.0, 30.0))

func _corner_position(position: Vector3) -> Vector3:
	var x_side := -20.0 if position.x < 0.0 else 20.0
	var z_side := -31.0 if position.z < 0.0 else 31.0
	return Vector3(x_side, 0.25, z_side)

func get_phase_name() -> String:
	match phase:
		Phase.PRE_MATCH:
			return "PRÉ-JOGO"
		Phase.KICKOFF:
			return "SAÍDA DE BOLA"
		Phase.PLAYING:
			return "EM JOGO"
		Phase.GOAL_PAUSE:
			return "GOL"
		Phase.HALF_TIME:
			return "INTERVALO"
		Phase.FULL_TIME:
			return "FIM DE JOGO"
		Phase.PAUSED:
			return "PAUSADO"
	return "DESCONHECIDO"

func get_score() -> Vector2i:
	return Vector2i(home_score, away_score)

func get_match_minute() -> int:
	return int(floor(elapsed / 60.0))

func get_statistics() -> Dictionary:
	return {
		"home_score": home_score,
		"away_score": away_score,
		"home_fouls": home_fouls,
		"away_fouls": away_fouls,
		"home_corners": home_corners,
		"away_corners": away_corners,
		"home_throw_ins": home_throw_ins,
		"away_throw_ins": away_throw_ins,
		"elapsed": elapsed,
		"phase": get_phase_name()
	}
