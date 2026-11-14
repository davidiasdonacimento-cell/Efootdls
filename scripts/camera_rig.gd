extends Camera3D
## Câmera de jogo: acompanha o atleta com suavização, limites e zoom.

@export var follow_height := 9.0
@export var follow_distance := 12.5
@export var look_ahead := 6.0
@export var position_smoothing := 4.8
@export var rotation_smoothing := 5.5
@export var minimum_fov := 56.0
@export var maximum_fov := 68.0

var target: Node3D
var ball_target: Node3D
var desired_distance := 12.5
var shake_strength := 0.0
var shake_time := 0.0
var base_position := Vector3.ZERO
var is_enabled := true
var camera_mode := "broadcast"
var manual_offset := Vector3.ZERO

func _ready() -> void:
	current = true
	fov = 62.0
	desired_distance = follow_distance

func _process(delta: float) -> void:
	if not is_enabled or not is_instance_valid(target):
		return
	_update_shake(delta)
	var focus := _get_focus_point()
	var direction := Vector3(0.0, follow_height, desired_distance)
	if camera_mode == "close":
		direction = Vector3(0.0, follow_height * 0.76, desired_distance * 0.72)
	elif camera_mode == "wide":
		direction = Vector3(0.0, follow_height * 1.24, desired_distance * 1.28)
	var desired_position := target.global_position + direction + manual_offset
	desired_position.x = clampf(desired_position.x, -18.0, 18.0)
	desired_position.z = clampf(desired_position.z, -38.0, 43.0)
	desired_position += _shake_offset()
	global_position = global_position.lerp(desired_position, minf(1.0, position_smoothing * delta))
	var look_point := focus + Vector3(0.0, 0.7, -look_ahead)
	var look_transform := global_transform.looking_at(look_point, Vector3.UP)
	global_basis = global_basis.slerp(look_transform.basis, minf(1.0, rotation_smoothing * delta))
	_update_fov(delta)

func _get_focus_point() -> Vector3:
	var focus := target.global_position
	if is_instance_valid(ball_target):
		var ball_position := ball_target.global_position
		var distance := focus.distance_to(ball_position)
		if distance < 15.0:
			focus = focus.lerp(ball_position, 0.22)
	return focus

func _update_fov(delta: float) -> void:
	if is_instance_valid(ball_target) and is_instance_valid(target):
		var distance := target.global_position.distance_to(ball_target.global_position)
		var target_fov := lerpf(minimum_fov, maximum_fov, clampf(distance / 18.0, 0.0, 1.0))
		fov = lerpf(fov, target_fov, minf(1.0, delta * 1.8))

func _update_shake(delta: float) -> void:
	if shake_time > 0.0:
		shake_time = maxf(0.0, shake_time - delta)
		shake_strength = lerpf(shake_strength, 0.0, delta * 3.5)
	else:
		shake_strength = 0.0

func _shake_offset() -> Vector3:
	if shake_strength <= 0.001:
		return Vector3.ZERO
	var time_value := Time.get_ticks_msec() / 1000.0
	return Vector3(sin(time_value * 43.0), cos(time_value * 37.0), sin(time_value * 29.0)) * shake_strength

func configure(player_target: Node3D, ball: Node3D = null) -> void:
	target = player_target
	ball_target = ball

func set_camera_mode(mode: String) -> void:
	if mode not in ["broadcast", "close", "wide"]:
		return
	camera_mode = mode

func set_zoom(value: float) -> void:
	desired_distance = clampf(value, 8.0, 20.0)

func add_shake(strength := 0.18, duration := 0.22) -> void:
	shake_strength = maxf(shake_strength, clampf(strength, 0.0, 1.0))
	shake_time = maxf(shake_time, clampf(duration, 0.0, 1.0))

func set_enabled(value: bool) -> void:
	is_enabled = value
	current = value

func reset_camera() -> void:
	shake_strength = 0.0
	shake_time = 0.0
	desired_distance = follow_distance
	manual_offset = Vector3.ZERO

func set_manual_offset(value: Vector3) -> void:
	manual_offset = value.limit_length(4.0)
