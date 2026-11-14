extends RigidBody3D
## Camada de física e ações da bola. Mantém força, passe, curva e último toque.

signal kicked(direction: Vector3, power: float, is_pass: bool)
signal touched_by(team_id: int)
signal stopped
signal left_play_area

const MAX_SHOT_POWER := 25.0
const MIN_SHOT_POWER := 4.0
const MAX_SPEED := 32.0
const FIELD_X_LIMIT := 25.0
const FIELD_Z_LIMIT := 38.0

var last_touch_team := 0
var last_touch_player := ""
var total_kicks := 0
var total_passes := 0
var total_shots := 0
var curve_strength := 0.0
var curve_time := 0.0
var out_of_bounds_reported := false
var previous_speed := 0.0
var spin_factor := 0.22

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	can_sleep = true
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	_apply_curve(delta)
	_limit_velocity()
	_check_bounds()
	var speed := linear_velocity.length()
	if previous_speed > 0.8 and speed < 0.12:
		stopped.emit()
	previous_speed = speed

func kick(direction: Vector3, power: float, loft: float = 0.12, team_id: int = 1) -> void:
	var safe_direction := direction
	if safe_direction.length_squared() < 0.001:
		safe_direction = Vector3.FORWARD
	safe_direction = safe_direction.normalized()
	var safe_power := clampf(power, MIN_SHOT_POWER, MAX_SHOT_POWER)
	var impulse := safe_direction * safe_power
	impulse.y += safe_power * clampf(loft, 0.0, 0.42)
	sleeping = false
	apply_central_impulse(impulse)
	linear_velocity = linear_velocity.limit_length(MAX_SPEED)
	last_touch_team = team_id
	total_kicks += 1
	total_shots += 1
	out_of_bounds_reported = false
	kicked.emit(safe_direction, safe_power, false)
	touched_by.emit(team_id)

func pass_to(target: Vector3, power: float = 8.5, team_id: int = 1) -> void:
	var direction := target - global_position
	direction.y = 0.08
	if direction.length_squared() < 0.01:
		return
	var distance_factor := clampf(direction.length() / 14.0, 0.72, 1.25)
	direction = direction.normalized()
	sleeping = false
	apply_central_impulse(direction * power * distance_factor + Vector3.UP * 0.35)
	linear_velocity = linear_velocity.limit_length(MAX_SPEED * 0.72)
	last_touch_team = team_id
	total_kicks += 1
	total_passes += 1
	out_of_bounds_reported = false
	kicked.emit(direction, power, true)
	touched_by.emit(team_id)

func apply_curve(amount: float, duration: float = 0.65) -> void:
	curve_strength = clampf(amount, -1.0, 1.0)
	curve_time = maxf(duration, 0.0)

func _apply_curve(delta: float) -> void:
	if curve_time <= 0.0:
		curve_strength = move_toward(curve_strength, 0.0, delta * 1.4)
		return
	curve_time = maxf(0.0, curve_time - delta)
	var horizontal := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if horizontal.length() > 1.0 and absf(curve_strength) > 0.01:
		var side := Vector3(-horizontal.z, 0.0, horizontal.x).normalized()
		apply_central_force(side * curve_strength * spin_factor * horizontal.length())

func _limit_velocity() -> void:
	if linear_velocity.length() > MAX_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_SPEED
	if absf(angular_velocity.x) > 30.0:
		angular_velocity.x = clampf(angular_velocity.x, -30.0, 30.0)
	if absf(angular_velocity.z) > 30.0:
		angular_velocity.z = clampf(angular_velocity.z, -30.0, 30.0)

func _check_bounds() -> void:
	if out_of_bounds_reported:
		return
	if absf(global_position.x) > FIELD_X_LIMIT or absf(global_position.z) > FIELD_Z_LIMIT or global_position.y < -3.0:
		out_of_bounds_reported = true
		left_play_area.emit()

func _on_body_entered(body: Node) -> void:
	if body == self:
		return
	if body is CharacterBody3D:
		var speed := linear_velocity.length()
		if speed > 0.7:
			touched_by.emit(last_touch_team)

func reset_ball(position: Vector3) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = position
	sleeping = false
	curve_strength = 0.0
	curve_time = 0.0
	out_of_bounds_reported = false
	previous_speed = 0.0

func set_last_touch(team_id: int, player_name: String) -> void:
	last_touch_team = team_id
	last_touch_player = player_name
	touched_by.emit(team_id)

func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6

func is_moving_fast() -> bool:
	return linear_velocity.length() > 8.0

func get_last_touch_team() -> int:
	return last_touch_team

func get_action_totals() -> Dictionary:
	return {
		"kicks": total_kicks,
		"passes": total_passes,
		"shots": total_shots
	}
