extends Node
## Grava posições da partida em intervalos curtos para replay e revisão de jogadas.

signal recording_started
signal recording_stopped(frame_count: int)
signal playback_started
signal playback_finished
signal replay_event_added(event_name: String, timestamp: float)

@export_range(0.03, 1.0, 0.01) var sample_interval := 0.12
@export_range(10, 300, 10) var maximum_seconds := 90
@export_range(30, 30_000, 30) var maximum_frames := 9000

var player: Node3D
var ball: Node3D
var allies: Array[Node3D] = []
var opponents: Array[Node3D] = []
var frames: Array[Dictionary] = []
var events: Array[Dictionary] = []
var recording := false
var playing := false
var sample_accumulator := 0.0
var elapsed := 0.0
var playback_position := 0.0
var playback_speed := 1.0
var replay_duration := 0.0
var last_frame: Dictionary = {}

func configure(controlled_player: Node3D, match_ball: Node3D, team_mates: Array[CharacterBody3D], rivals: Array[CharacterBody3D]) -> void:
	player = controlled_player
	ball = match_ball
	allies.clear()
	opponents.clear()
	for athlete in team_mates:
		allies.append(athlete)
	for rival in rivals:
		opponents.append(rival)

func start_recording() -> void:
	frames.clear()
	events.clear()
	elapsed = 0.0
	sample_accumulator = 0.0
	recording = true
	playing = false
	recording_started.emit()

func stop_recording() -> void:
	if not recording:
		return
	recording = false
	replay_duration = elapsed
	recording_stopped.emit(frames.size())

func _process(delta: float) -> void:
	if recording:
		_capture_tick(delta)
	elif playing:
		_playback_tick(delta)

func _capture_tick(delta: float) -> void:
	elapsed += delta
	sample_accumulator += delta
	if sample_accumulator < sample_interval:
		return
	sample_accumulator = 0.0
	_capture_frame()
	var max_count := mini(maximum_frames, ceili(float(maximum_seconds) / sample_interval))
	while frames.size() > max_count:
		frames.pop_front()

func _capture_frame() -> void:
	var frame := {
		"time": elapsed,
		"player": _capture_actor(player),
		"ball": _capture_actor(ball),
		"allies": _capture_team(allies),
		"opponents": _capture_team(opponents)
	}
	frames.append(frame)
	last_frame = frame

func _capture_actor(actor: Node3D) -> Dictionary:
	if not is_instance_valid(actor):
		return {}
	return {
		"position": actor.global_position,
		"rotation": actor.global_rotation,
		"visible": actor.visible
	}

func _capture_team(team: Array[Node3D]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for athlete in team:
		result.append(_capture_actor(athlete))
	return result

func add_event(event_name: String, details := {}) -> void:
	if not recording:
		return
	var entry := {
		"name": event_name,
		"time": elapsed,
		"details": details.duplicate(true)
	}
	events.append(entry)
	replay_event_added.emit(event_name, elapsed)

func play_replay(speed := 1.0) -> bool:
	if frames.size() < 2:
		return false
	recording = false
	playing = true
	playback_position = 0.0
	playback_speed = clampf(speed, 0.25, 2.0)
	playback_started.emit()
	return true

func stop_replay() -> void:
	if not playing:
		return
	playing = false
	playback_position = 0.0
	playback_finished.emit()

func _playback_tick(delta: float) -> void:
	playback_position += delta * playback_speed
	if playback_position >= replay_duration:
		stop_replay()

func seek(position_seconds: float) -> Dictionary:
	if frames.is_empty():
		return {}
	playback_position = clampf(position_seconds, 0.0, replay_duration)
	return get_frame_at(playback_position)

func get_frame_at(time_seconds: float) -> Dictionary:
	if frames.is_empty():
		return {}
	var target := clampf(time_seconds, float(frames[0]["time"]), float(frames[-1]["time"]))
	var first_index := 0
	while first_index < frames.size() - 1 and float(frames[first_index + 1]["time"]) < target:
		first_index += 1
	var second_index := mini(first_index + 1, frames.size() - 1)
	var first: Dictionary = frames[first_index]
	var second: Dictionary = frames[second_index]
	var span := float(second["time"]) - float(first["time"])
	var weight := 0.0 if span <= 0.0001 else clampf((target - float(first["time"])) / span, 0.0, 1.0)
	return _interpolate_frame(first, second, weight)

func _interpolate_frame(first: Dictionary, second: Dictionary, weight: float) -> Dictionary:
	return {
		"time": lerpf(float(first["time"]), float(second["time"]), weight),
		"player": _interpolate_actor(first.get("player", {}), second.get("player", {}), weight),
		"ball": _interpolate_actor(first.get("ball", {}), second.get("ball", {}), weight),
		"allies": _interpolate_team(first.get("allies", []), second.get("allies", []), weight),
		"opponents": _interpolate_team(first.get("opponents", []), second.get("opponents", []), weight)
	}

func _interpolate_actor(first: Dictionary, second: Dictionary, weight: float) -> Dictionary:
	if first.is_empty():
		return second.duplicate(true)
	if second.is_empty():
		return first.duplicate(true)
	return {
		"position": first["position"].lerp(second["position"], weight),
		"rotation": first["rotation"].lerp(second["rotation"], weight),
		"visible": bool(first["visible"]) and bool(second["visible"])
	}

func _interpolate_team(first: Array, second: Array, weight: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var count := mini(first.size(), second.size())
	for index in range(count):
		result.append(_interpolate_actor(first[index], second[index], weight))
	return result

func get_events_between(start_time: float, end_time: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if float(event["time"]) >= start_time and float(event["time"]) <= end_time:
			result.append(event.duplicate(true))
	return result

func get_highlights() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if str(event["name"]) in ["goal", "save", "shot", "tackle"]:
			result.append(event.duplicate(true))
	return result

func get_frame_count() -> int:
	return frames.size()

func get_duration() -> float:
	return replay_duration if not recording else elapsed

func get_recording_snapshot() -> Dictionary:
	return {
		"recording": recording,
		"playing": playing,
		"frames": frames.size(),
		"events": events.size(),
		"duration": get_duration(),
		"playback_position": playback_position
	}

func clear_replay() -> void:
	recording = false
	playing = false
	frames.clear()
	events.clear()
	elapsed = 0.0
	replay_duration = 0.0
	last_frame.clear()

func save_replay(path := "user://efootdls_last_replay.cfg") -> bool:
	var config := ConfigFile.new()
	config.set_value("replay", "frames", frames)
	config.set_value("replay", "events", events)
	config.set_value("replay", "duration", get_duration())
	return config.save(path) == OK

func load_replay(path := "user://efootdls_last_replay.cfg") -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	frames.clear()
	events.clear()
	var loaded_frames: Variant = config.get_value("replay", "frames", [])
	var loaded_events: Variant = config.get_value("replay", "events", [])
	if loaded_frames is Array:
		for frame in loaded_frames:
			if frame is Dictionary:
				frames.append(frame.duplicate(true))
	if loaded_events is Array:
		for event in loaded_events:
			if event is Dictionary:
				events.append(event.duplicate(true))
	replay_duration = float(config.get_value("replay", "duration", 0.0))
	return frames.size() >= 2
