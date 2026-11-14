extends CharacterBody3D
## Goleiro controlado pela IA. Faz posicionamento lateral e defesas por proximidade.

const GOAL_LINE_Z := -30.0
const GOAL_HALF_WIDTH := 3.55
const MOVE_SPEED := 7.2

var football: RigidBody3D
var defend_positive_z := false
var home_z := GOAL_LINE_Z
var reaction_radius := 13.0
var save_cooldown := 0.0
var dive_time := 0.0
var dive_direction := 0.0
var goalkeeper_number := 1
var keeper_color := Color(0.96, 0.72, 0.12)
var body_visual: MeshInstance3D
var glove_left: MeshInstance3D
var glove_right: MeshInstance3D
var enabled := true
var saves := 0

func configure(ball: RigidBody3D, defend_other_end := false) -> void:
	football = ball
	defend_positive_z = defend_other_end
	home_z = 30.0 if defend_positive_z else GOAL_LINE_Z
	if defend_positive_z:
		name = "Goalkeeper_HomeEnd"
	else:
		name = "Goalkeeper_AwayEnd"

func _ready() -> void:
	global_position = Vector3(0.0, 0.9, home_z)
	_build_collision()
	_build_model()

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(football):
		return
	save_cooldown = maxf(0.0, save_cooldown - delta)
	dive_time = maxf(0.0, dive_time - delta)
	var ball_position := football.global_position
	var ball_velocity := football.linear_velocity
	var target_x := _predict_ball_x(ball_position, ball_velocity)
	var distance_to_goal := absf(ball_position.z - home_z)
	if distance_to_goal < reaction_radius:
		target_x = clampf(target_x, -GOAL_HALF_WIDTH, GOAL_HALF_WIDTH)
	else:
		target_x = clampf(ball_position.x * 0.18, -1.1, 1.1)
	var target := Vector3(target_x, 0.9, home_z + (0.45 if defend_positive_z else -0.45))
	var displacement := target - global_position
	displacement.y = 0.0
	var desired := Vector3.ZERO
	if displacement.length() > 0.12:
		desired = displacement.normalized() * MOVE_SPEED
	velocity.x = move_toward(velocity.x, desired.x, 18.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 18.0 * delta)
	velocity.y -= 22.0 * delta
	move_and_slide()
	global_position.x = clampf(global_position.x, -GOAL_HALF_WIDTH, GOAL_HALF_WIDTH)
	global_position.z = home_z
	_try_save(distance_to_goal, ball_position, ball_velocity)
	_update_dive_visual()

func _predict_ball_x(position: Vector3, ball_velocity: Vector3) -> float:
	var goal_direction := 1.0 if defend_positive_z else -1.0
	var toward_goal := ball_velocity.z * goal_direction
	if toward_goal <= 0.1:
		return position.x
	var travel_time := absf(home_z - position.z) / maxf(absf(ball_velocity.z), 0.1)
	return position.x + ball_velocity.x * minf(travel_time, 1.0)

func _try_save(distance_to_goal: float, position: Vector3, ball_velocity: Vector3) -> void:
	if save_cooldown > 0.0 or distance_to_goal > 2.25:
		return
	var horizontal_distance := absf(position.x - global_position.x)
	if horizontal_distance > 2.0:
		return
	if position.y > 3.2:
		return
	var goal_direction := 1.0 if defend_positive_z else -1.0
	if ball_velocity.z * goal_direction < 0.2:
		return
	var clear_direction := Vector3(signf(position.x - global_position.x) * 0.25, 0.18, -goal_direction)
	football.sleeping = false
	football.apply_central_impulse(clear_direction.normalized() * 10.5 + Vector3.UP * 1.8)
	save_cooldown = 1.1
	dive_time = 0.42
	dive_direction = signf(position.x - global_position.x)
	saves += 1

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 1.75
	collision.shape = capsule
	add_child(collision)
	floor_snap_length = 0.2

func _build_model() -> void:
	var torso := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.40
	capsule.height = 1.6
	torso.mesh = capsule
	torso.position.y = 0.82
	torso.material_override = _make_material(keeper_color)
	add_child(torso)
	body_visual = torso

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	head.mesh = sphere
	head.position.y = 1.76
	head.material_override = _make_material(Color(0.68, 0.46, 0.32))
	add_child(head)

	glove_left = _make_glove(Vector3(-0.56, 1.0, 0.0))
	glove_right = _make_glove(Vector3(0.56, 1.0, 0.0))

	var number := Label3D.new()
	number.text = str(goalkeeper_number)
	number.position = Vector3(0, 1.0, -0.4)
	number.pixel_size = 0.007
	number.modulate = Color.WHITE
	add_child(number)

func _make_glove(local_position: Vector3) -> MeshInstance3D:
	var glove := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.17
	sphere.height = 0.34
	glove.mesh = sphere
	glove.position = local_position
	glove.material_override = _make_material(Color(0.92, 0.94, 0.98))
	add_child(glove)
	return glove

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material

func _update_dive_visual() -> void:
	if body_visual == null:
		return
	if dive_time > 0.0:
		body_visual.rotation.z = lerpf(body_visual.rotation.z, -dive_direction * 0.75, 0.3)
	else:
		body_visual.rotation.z = lerpf(body_visual.rotation.z, 0.0, 0.18)
	if glove_left:
		glove_left.position.y = 1.0 + (0.32 if dive_time > 0.0 else 0.0)
	if glove_right:
		glove_right.position.y = 1.0 + (0.32 if dive_time > 0.0 else 0.0)

func reset_keeper() -> void:
	global_position = Vector3(0.0, 0.9, home_z)
	velocity = Vector3.ZERO
	dive_time = 0.0
	if body_visual:
		body_visual.rotation = Vector3.ZERO

func set_enabled(value: bool) -> void:
	enabled = value
	velocity = Vector3.ZERO
