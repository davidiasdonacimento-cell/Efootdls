extends CharacterBody3D
## Jogador controlado pela IA. Pode atuar como apoio ou como defensor adversário.
## A lógica usa steering simples para manter desempenho em aparelhos Android.

const FIELD_HALF_WIDTH := 21.0
const FIELD_HALF_LENGTH := 32.0
const BODY_COLOR_ALLY := Color(0.08, 0.34, 0.88)
const BODY_COLOR_ENEMY := Color(0.78, 0.12, 0.15)

var football: RigidBody3D
var team_id := 2
var role := "defender"
var home_position := Vector3.ZERO
var movement_speed := 5.2
var acceleration := 12.0
var enabled := true
var action_cooldown := 0.0
var decision_cooldown := 0.0
var current_target := Vector3.ZERO
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var number_label: Label3D
var stamina := 100.0
var shirt_color := BODY_COLOR_ENEMY
var player_number := 2
var match_side := 1.0
var is_goalkeeper_support := false

func configure(ball: RigidBody3D, side: int, home: Vector3, player_role: String, number: int) -> void:
	football = ball
	team_id = side
	home_position = home
	role = player_role
	player_number = number
	shirt_color = BODY_COLOR_ALLY if team_id == 1 else BODY_COLOR_ENEMY
	match_side = -1.0 if team_id == 1 else 1.0
	name = "AI_%s_%02d" % [role, player_number]
	movement_speed = 5.8 if role == "winger" else 5.0

func _ready() -> void:
	_build_physics()
	_build_appearance()
	global_position = home_position
	current_target = home_position

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(football):
		velocity = Vector3.ZERO
		return
	action_cooldown = maxf(0.0, action_cooldown - delta)
	decision_cooldown = maxf(0.0, decision_cooldown - delta)
	stamina = minf(100.0, stamina + delta * 2.0)
	if decision_cooldown <= 0.0:
		current_target = _choose_target()
		decision_cooldown = 0.22
	_move_toward_target(delta)
	_try_interact_with_ball()

func _build_physics() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.65
	collision.shape = capsule
	add_child(collision)
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(48.0)

func _build_appearance() -> void:
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.37
	capsule.height = 1.55
	torso.mesh = capsule
	torso.position.y = 0.82
	torso.material_override = _make_material(shirt_color)
	add_child(torso)
	body_mesh = torso

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	head.mesh = sphere
	head.position.y = 1.72
	head.material_override = _make_material(Color(0.68, 0.46, 0.32))
	add_child(head)
	head_mesh = head

	var shorts := MeshInstance3D.new()
	var shorts_mesh := BoxMesh.new()
	shorts_mesh.size = Vector3(0.62, 0.36, 0.38)
	shorts.mesh = shorts_mesh
	shorts.position.y = 0.32
	shorts.material_override = _make_material(Color(0.055, 0.07, 0.10))
	add_child(shorts)

	number_label = Label3D.new()
	number_label.text = str(player_number)
	number_label.position = Vector3(0, 1.0, -0.39)
	number_label.pixel_size = 0.007
	number_label.modulate = Color.WHITE
	add_child(number_label)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	return material

func _choose_target() -> Vector3:
	var ball_position := football.global_position
	var ball_distance := global_position.distance_to(ball_position)
	if team_id == 2:
		return _enemy_target(ball_position, ball_distance)
	return _ally_target(ball_position, ball_distance)

func _enemy_target(ball_position: Vector3, ball_distance: float) -> Vector3:
	var defensive_line := clampf(ball_position.z + 5.0, -25.0, 8.0)
	var target := home_position
	target.z = minf(home_position.z, defensive_line)
	if role == "presser":
		if ball_distance < 25.0:
			target = ball_position + Vector3(0, 0, 1.1)
	elif role == "defender":
		if ball_distance < 17.0:
			target.x = lerpf(home_position.x, ball_position.x, 0.42)
			target.z = lerpf(home_position.z, ball_position.z + 3.0, 0.35)
	elif role == "winger":
		target.x = lerpf(home_position.x, ball_position.x, 0.30)
		if ball_distance < 12.0:
			target.z = ball_position.z + 5.0
	return _clamp_target(target)

func _ally_target(ball_position: Vector3, ball_distance: float) -> Vector3:
	var target := home_position
	if role == "winger":
		target.z = clampf(ball_position.z - 7.0, -25.0, 20.0)
		target.x = lerpf(home_position.x, ball_position.x, 0.38)
	elif role == "support":
		target.z = clampf(ball_position.z - 4.5, -24.0, 20.0)
		target.x = lerpf(home_position.x, ball_position.x, 0.55)
	else:
		target.z = clampf(ball_position.z + 3.5, -20.0, 27.0)
	if ball_distance < 4.5:
		target.x += signf(global_position.x - ball_position.x) * 1.4
	return _clamp_target(target)

func _move_toward_target(delta: float) -> void:
	var flat_target := Vector3(current_target.x, global_position.y, current_target.z)
	var offset := flat_target - global_position
	offset.y = 0.0
	var desired := Vector3.ZERO
	if offset.length() > 0.55:
		desired = offset.normalized() * movement_speed
	var blend := minf(1.0, acceleration * delta)
	velocity.x = lerpf(velocity.x, desired.x, blend)
	velocity.z = lerpf(velocity.z, desired.z, blend)
	velocity.y -= 22.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -FIELD_HALF_WIDTH + 1.0, FIELD_HALF_WIDTH - 1.0)
	global_position.z = clampf(global_position.z, -FIELD_HALF_LENGTH + 1.0, FIELD_HALF_LENGTH - 1.0)
	if Vector2(velocity.x, velocity.z).length() > 0.2:
		rotation.y = atan2(-velocity.x, -velocity.z)

func _try_interact_with_ball() -> void:
	if team_id != 2 or action_cooldown > 0.0:
		return
	var separation := global_position.distance_to(football.global_position)
	if separation > 1.55:
		return
	var clear_direction := Vector3(0.0, 0.10, 1.0)
	if football.global_position.x > 2.0:
		clear_direction.x = -0.22
	elif football.global_position.x < -2.0:
		clear_direction.x = 0.22
	football.sleeping = false
	football.apply_central_impulse(clear_direction.normalized() * 7.8 + Vector3.UP * 1.1)
	action_cooldown = 1.35
	stamina = maxf(0.0, stamina - 5.0)

func _clamp_target(target: Vector3) -> Vector3:
	target.x = clampf(target.x, -FIELD_HALF_WIDTH + 2.0, FIELD_HALF_WIDTH - 2.0)
	target.z = clampf(target.z, -FIELD_HALF_LENGTH + 2.0, FIELD_HALF_LENGTH - 2.0)
	target.y = 0.0
	return target

func set_ai_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		velocity = Vector3.ZERO

func set_home_position(value: Vector3) -> void:
	home_position = value
	current_target = value

func get_pass_target() -> Vector3:
	return global_position + Vector3(0.0, 0.2, -1.0)

func get_team_id() -> int:
	return team_id

func is_available_for_pass() -> bool:
	return enabled and stamina > 8.0 and is_inside_tree()

func apply_fatigue(amount: float) -> void:
	stamina = clampf(stamina - amount, 0.0, 100.0)
	movement_speed = 3.8 if stamina < 15.0 else (4.8 if stamina < 35.0 else 5.8)

func recover_fatigue(amount: float) -> void:
	stamina = minf(100.0, stamina + amount)
