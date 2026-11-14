extends Node
## Relógio independente da partida, com pausa, acréscimos e mudança de período.

signal time_changed(display_text: String, seconds_left: int)
signal period_changed(period: int)
signal match_finished
signal match_started
signal match_paused
signal match_resumed

enum State { READY, PLAYING, PAUSED, HALF_TIME, FINISHED }

@export_range(30, 900, 30) var half_duration := 180
@export_range(0, 60, 5) var half_time_duration := 8

var state: State = State.READY
var period := 1
var elapsed_seconds := 0.0
var half_time_remaining := 0.0
var added_time := 0
var tick_accumulator := 0.0
var duration_override := 0
var clock_speed := 1.0

func start_match(custom_half_duration := 0) -> void:
	if custom_half_duration > 0:
		duration_override = custom_half_duration
	else:
		duration_override = half_duration
	period = 1
	elapsed_seconds = 0.0
	half_time_remaining = 0.0
	tick_accumulator = 0.0
	state = State.PLAYING
	match_started.emit()
	_emit_time()

func tick(delta: float) -> void:
	if state == State.HALF_TIME:
		_tick_half_time(delta)
		return
	if state != State.PLAYING:
		return
	elapsed_seconds += delta * clock_speed
	tick_accumulator += delta
	if tick_accumulator >= 1.0:
		tick_accumulator = 0.0
		_emit_time()
	if elapsed_seconds >= _current_period_length():
		_finish_period()

func pause_match() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	match_paused.emit()

func resume_match() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	match_resumed.emit()

func toggle_pause() -> void:
	if state == State.PLAYING:
		pause_match()
	elif state == State.PAUSED:
		resume_match()

func _finish_period() -> void:
	if period == 1:
		state = State.HALF_TIME
		half_time_remaining = float(half_time_duration)
		period_changed.emit(period)
	else:
		state = State.FINISHED
		_emit_time()
		match_finished.emit()

func _tick_half_time(delta: float) -> void:
	half_time_remaining = maxf(0.0, half_time_remaining - delta)
	if half_time_remaining <= 0.0:
		period = 2
		elapsed_seconds = 0.0
		tick_accumulator = 0.0
		state = State.PLAYING
		period_changed.emit(period)
		_emit_time()

func _current_period_length() -> float:
	return float(maxi(duration_override, 30) + added_time)

func set_added_time(seconds: int) -> void:
	added_time = clampi(seconds, 0, 60)

func set_clock_speed(multiplier: float) -> void:
	clock_speed = clampf(multiplier, 0.1, 10.0)

func reset_clock() -> void:
	state = State.READY
	period = 1
	elapsed_seconds = 0.0
	half_time_remaining = 0.0
	added_time = 0
	tick_accumulator = 0.0
	_emit_time()

func get_seconds_left() -> int:
	return maxi(0, int(ceil(_current_period_length() - elapsed_seconds)))

func get_elapsed_seconds() -> int:
	return int(floor(elapsed_seconds))

func get_period() -> int:
	return period

func is_active() -> bool:
	return state == State.PLAYING

func is_finished() -> bool:
	return state == State.FINISHED

func get_state_name() -> String:
	match state:
		State.READY:
			return "PRONTO"
		State.PLAYING:
			return "EM JOGO"
		State.PAUSED:
			return "PAUSADO"
		State.HALF_TIME:
			return "INTERVALO"
		State.FINISHED:
			return "ENCERRADO"
	return "DESCONHECIDO"

func _emit_time() -> void:
	var left := get_seconds_left()
	var minutes := int(left / 60)
	var seconds := left % 60
	var prefix := "1T" if period == 1 else "2T"
	time_changed.emit("%s  %02d:%02d" % [prefix, minutes, seconds], left)
