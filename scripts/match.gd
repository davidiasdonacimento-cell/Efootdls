extends Node3D

const FIELD_LENGTH := 64.0
const FIELD_WIDTH := 42.0
const PLAYER_SPEED := 7.0
const SPRINT_SPEED := 11.5
const BALL_KICK_FORCE := 13.5
const FootballerAI = preload("res://scripts/footballer_ai.gd")
const GoalkeeperAI = preload("res://scripts/goalkeeper_ai.gd")
const BallPhysics = preload("res://scripts/ball_physics.gd")
const MatchClock = preload("res://scripts/match_clock.gd")
const MatchStats = preload("res://scripts/match_stats.gd")
const ProfileStore = preload("res://scripts/profile_store.gd")
const CameraRig = preload("res://scripts/camera_rig.gd")
const MatchSettings = preload("res://scripts/match_settings.gd")
const TacticsManager = preload("res://scripts/tactics_manager.gd")
const MinimapOverlay = preload("res://scripts/minimap_overlay.gd")
const WeatherSystem = preload("res://scripts/weather_system.gd")
const MatchRules = preload("res://scripts/match_rules.gd")
const CareerManager = preload("res://scripts/career_manager.gd")
const AchievementManager = preload("res://scripts/achievement_manager.gd")
const MatchFeedback = preload("res://scripts/match_feedback.gd")
const RosterManager = preload("res://scripts/roster_manager.gd")
const ReplayRecorder = preload("res://scripts/replay_recorder.gd")
const ObjectivesManager = preload("res://scripts/objectives_manager.gd")
const AccessibilityManager = preload("res://scripts/accessibility_manager.gd")

var player: CharacterBody3D
var ball: RigidBody3D
var camera: Camera3D
var joystick_base: Control
var joystick_knob: Control
var sprint_button: Button
var kick_button: Button
var pass_button: Button
var tackle_button: Button
var pause_button: Button
var menu_button: Button
var tactics_button: Button
var score_label: Label
var status_label: Label
var timer_label: Label
var stamina_bar: ProgressBar
var clock: Node
var stats: Node
var profile: Node
var settings: RefCounted
var tactics: Node
var minimap: Control
var weather: Node
var rules: Node
var career: Node
var achievements: Node
var feedback: Node
var roster: RefCounted
var replay: Node
var objectives: Node
var accessibility: RefCounted
var world_environment: WorldEnvironment
var sun_light: DirectionalLight3D
var allies: Array[CharacterBody3D] = []
var opponents: Array[CharacterBody3D] = []
var goalkeeper: CharacterBody3D
var opponent_goalkeeper: CharacterBody3D
var score := 0
var opponent_score := 0
var player_stamina := 100.0
var game_paused := false
var match_ended := false
var joystick_vector := Vector2.ZERO
var joystick_touch_id := -1
var sprinting := false
var goal_areas: Array[Area3D] = []
var kick_cooldown := 0.0
var message_time := 0.0

func _ready() -> void:
	clock = MatchClock.new()
	add_child(clock)
	clock.connect("time_changed", Callable(self, "_on_clock_time_changed"))
	clock.connect("match_finished", Callable(self, "_on_match_finished"))
	clock.connect("period_changed", Callable(self, "_on_period_changed"))
	stats = MatchStats.new()
	add_child(stats)
	profile = ProfileStore.new()
	add_child(profile)
	settings = MatchSettings.new()
	rules = MatchRules.new()
	add_child(rules)
	rules.connect("restart_requested", Callable(self, "_on_restart_requested"))
	rules.call("start_match", 900.0)
	rules.call("start_play_after_restart")
	career = CareerManager.new()
	add_child(career)
	roster = RosterManager.new()
	achievements = AchievementManager.new()
	add_child(achievements)
	achievements.call("configure", profile)
	achievements.connect("achievement_unlocked", Callable(self, "_on_achievement_unlocked"))
	feedback = MatchFeedback.new()
	add_child(feedback)
	feedback.connect("commentary", Callable(self, "_on_commentary"))
	objectives = ObjectivesManager.new()
	add_child(objectives)
	objectives.call("configure", profile)
	accessibility = AccessibilityManager.new()
	accessibility.call("load_options")

	_build_world()
	_build_player()
	_build_ball()
	weather = WeatherSystem.new()
	add_child(weather)
	weather.call("configure", world_environment, sun_light, ball)
	_build_ai_teams()
	replay = ReplayRecorder.new()
	add_child(replay)
	replay.call("configure", player, ball, allies, opponents)
	replay.call("start_recording")
	tactics = TacticsManager.new()
	add_child(tactics)
	tactics.call("configure", allies, opponents, ball)
	tactics.connect("tactic_changed", Callable(self, "_on_tactic_changed"))
	_build_goal()
	_build_camera()
	_build_hud()
	_update_score()
	clock.call("start_match", int(settings.call("get_value", "match_length")) )

func _physics_process(delta: float) -> void:
	if clock:
		clock.call("tick", delta)
	if rules:
		rules.call("update_rules", delta)
	if achievements and sprinting and not game_paused and not match_ended:
		achievements.call("record_sprint", delta)
	if game_paused or match_ended:
		return
	kick_cooldown = maxf(0.0, kick_cooldown - delta)
	message_time = maxf(0.0, message_time - delta)
	if message_time <= 0.0 and status_label:
		status_label.text = "CONTROLE O JOGADOR E FAÇA O GOL"
	_move_player(delta)
	_update_ball_control(delta)
	_keep_ball_on_field()
	if stats and ball:
		stats.call("update_ball_speed", ball.linear_velocity.length() * 3.6)

func _input(event: InputEvent) -> void:
	if joystick_base == null:
		return
	if event is InputEventScreenTouch:
		var rect := joystick_base.get_global_rect()
		if event.pressed and rect.has_point(event.position):
			joystick_touch_id = event.index
			_update_joystick(event.position)
		elif not event.pressed and event.index == joystick_touch_id:
			joystick_touch_id = -1
			joystick_vector = Vector2.ZERO
			_update_joystick_visual()
	elif event is InputEventScreenDrag and event.index == joystick_touch_id:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if joystick_base.get_global_rect().has_point(event.position):
			joystick_touch_id = -2
	elif event is InputEventMouseMotion and joystick_touch_id == -2 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and joystick_touch_id == -2:
		joystick_touch_id = -1
		joystick_vector = Vector2.ZERO
		_update_joystick_visual()

func _unhandled_input(event: InputEvent) -> void:
	# Toque no lado direito do campo também executa o chute, como em jogos mobile.
	if event is InputEventScreenTouch and event.pressed:
		var screen_width := get_viewport().get_visible_rect().size.x
		var screen_height := get_viewport().get_visible_rect().size.y
		if event.position.x > screen_width * 0.52 and event.position.y > screen_height * 0.42:
			_kick_ball()

func _mat(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, collision := false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.position = pos
	mesh_instance.material_override = _mat(color)
	parent.add_child(mesh_instance)
	if collision:
		var body := StaticBody3D.new()
		body.position = pos
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)
	return mesh_instance

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.045, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.70, 0.82)
	environment.ambient_light_energy = 0.8
	world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-52, -25, 0)
	sun_light.light_energy = 1.15
	sun_light.shadow_enabled = true
	add_child(sun_light)

	_add_box(self, Vector3(FIELD_WIDTH, 0.5, FIELD_LENGTH), Vector3(0, -0.35, 0), Color(0.035, 0.27, 0.12), true)
	for i in range(8):
		var stripe_color := Color(0.045, 0.32, 0.14) if i % 2 == 0 else Color(0.035, 0.27, 0.12)
		_add_box(self, Vector3(FIELD_WIDTH, 0.025, FIELD_LENGTH / 8.0), Vector3(0, -0.085, -FIELD_LENGTH / 2.0 + FIELD_LENGTH / 16.0 + i * FIELD_LENGTH / 8.0), stripe_color)

	# Linhas do campo.
	_add_box(self, Vector3(0.12, 0.025, FIELD_LENGTH), Vector3(-FIELD_WIDTH / 2.0, -0.06, 0), Color.WHITE)
	_add_box(self, Vector3(0.12, 0.025, FIELD_LENGTH), Vector3(FIELD_WIDTH / 2.0, -0.06, 0), Color.WHITE)
	_add_box(self, Vector3(FIELD_WIDTH, 0.025, 0.12), Vector3(0, -0.06, FIELD_LENGTH / 2.0), Color.WHITE)
	_add_box(self, Vector3(FIELD_WIDTH, 0.025, 0.12), Vector3(0, -0.06, -FIELD_LENGTH / 2.0), Color.WHITE)
	_add_box(self, Vector3(0.12, 0.025, FIELD_WIDTH * 0.45), Vector3(0, -0.06, 0), Color.WHITE)
	_add_box(self, Vector3(18, 0.025, 0.12), Vector3(0, -0.055, -FIELD_LENGTH / 2.0 + 8), Color.WHITE)
	_add_box(self, Vector3(18, 0.025, 0.12), Vector3(0, -0.055, FIELD_LENGTH / 2.0 - 8), Color.WHITE)
	_add_box(self, Vector3(0.12, 0.025, 8), Vector3(-9, -0.055, -FIELD_LENGTH / 2.0 + 4), Color.WHITE)
	_add_box(self, Vector3(0.12, 0.025, 8), Vector3(9, -0.055, -FIELD_LENGTH / 2.0 + 4), Color.WHITE)

	# Arquibancadas simples em volta do gramado.
	for side in [-1.0, 1.0]:
		for tier in range(3):
			_add_box(self, Vector3(FIELD_WIDTH + 10, 1.6, 2.4), Vector3(0, 1.0 + tier * 1.4, side * (FIELD_LENGTH / 2.0 + 4.0 + tier * 1.4)), Color(0.035 + tier * 0.012, 0.07, 0.13))
	for side in [-1.0, 1.0]:
		for tier in range(3):
			_add_box(self, Vector3(2.4, 1.6, FIELD_LENGTH + 8), Vector3(side * (FIELD_WIDTH / 2.0 + 5.0 + tier * 1.4), 1.0 + tier * 1.4, 0), Color(0.035, 0.07, 0.13))

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.9, 2.2)
	add_child(player)

	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	player.add_child(collision)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position.y = 0
	body.material_override = _mat(Color(0.06, 0.25, 0.82))
	player.add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head.mesh = head_mesh
	head.position.y = 1.02
	head.material_override = _mat(Color(0.68, 0.46, 0.31))
	player.add_child(head)

	var number := Label3D.new()
	number.text = "10"
	number.position = Vector3(0, 0.1, -0.43)
	number.pixel_size = 0.006
	number.modulate = Color.WHITE
	player.add_child(number)

func _build_ball() -> void:
	ball = RigidBody3D.new()
	ball.set_script(BallPhysics)
	ball.position = Vector3(0, 0.55, 0.65)
	ball.mass = 0.45
	ball.linear_damp = 0.7
	ball.angular_damp = 0.8
	ball.continuous_cd = true
	add_child(ball)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	collision.shape = shape
	ball.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.76
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _mat(Color(0.96, 0.97, 1.0), 0.3)
	ball.add_child(mesh_instance)

func _build_goal() -> void:
	_build_goal_at(-FIELD_LENGTH / 2.0 + 1.2, 1)
	_build_goal_at(FIELD_LENGTH / 2.0 - 1.2, 2)

func _build_goal_at(goal_z: float, scoring_team: int) -> void:
	var post_material := Color(0.92, 0.96, 1.0)
	for side in [-1.0, 1.0]:
		_add_box(self, Vector3(0.28, 3.2, 0.28), Vector3(side * 4.0, 1.6, goal_z), post_material, true)
	_add_box(self, Vector3(8.2, 0.25, 0.28), Vector3(0, 3.2, goal_z), post_material, true)
	_add_box(self, Vector3(0.10, 3.0, 2.8), Vector3(-4.0, 1.5, goal_z + (-1.4 if goal_z < 0.0 else 1.4)), Color(0.48, 0.62, 0.78), true)
	_add_box(self, Vector3(0.10, 3.0, 2.8), Vector3(4.0, 1.5, goal_z + (-1.4 if goal_z < 0.0 else 1.4)), Color(0.48, 0.62, 0.78), true)
	var area := Area3D.new()
	area.position = Vector3(0, 1.5, goal_z + (-1.15 if goal_z < 0.0 else 1.15))
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.5, 3.0, 1.2)
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_goal_body_entered.bind(scoring_team))
	add_child(area)
	goal_areas.append(area)

func _build_camera() -> void:
	camera = CameraRig.new()
	camera.position = Vector3(0, 10, 29)
	camera.fov = 62
	add_child(camera)
	camera.call("configure", player, ball)
	camera.current = true
	camera.look_at(Vector3(0, 0, 8), Vector3.UP)

func _move_player(_delta: float) -> void:
	var direction := Vector3(joystick_vector.x, 0, joystick_vector.y)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.z += 1
	if direction.length() > 1.0:
		direction = direction.normalized()

	var wants_sprint := sprinting or Input.is_key_pressed(KEY_SHIFT)
	if wants_sprint and direction.length() > 0.12 and player_stamina > 1.0:
		player_stamina = maxf(0.0, player_stamina - _delta * 20.0)
	else:
		player_stamina = minf(100.0, player_stamina + _delta * 10.0)
	if stamina_bar:
		stamina_bar.value = player_stamina
	var speed := SPRINT_SPEED if wants_sprint and player_stamina > 1.0 else PLAYER_SPEED
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y -= 24.0 * get_physics_process_delta_time()
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -FIELD_WIDTH / 2.0 + 1.2, FIELD_WIDTH / 2.0 - 1.2)
	player.position.z = clampf(player.position.z, -FIELD_LENGTH / 2.0 + 2.0, FIELD_LENGTH / 2.0 - 2.0)
	if Vector2(direction.x, direction.z).length() > 0.12:
		player.rotation.y = atan2(-direction.x, -direction.z)

func _update_ball_control(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(ball):
		return
	var flat_distance := Vector2(ball.global_position.x - player.global_position.x, ball.global_position.z - player.global_position.z).length()
	if flat_distance > 1.85 or ball.linear_velocity.length() > 5.2:
		return
	# Condução assistida mantém a bola junto ao atleta sem anular a física do chute.
	var forward := -player.global_transform.basis.z
	var target_x := player.global_position.x + forward.x * 1.05
	var target_z := player.global_position.z + forward.z * 1.05
	var desired_x := clampf((target_x - ball.global_position.x) * 7.0 + player.velocity.x * 0.55, -8.0, 8.0)
	var desired_z := clampf((target_z - ball.global_position.z) * 7.0 + player.velocity.z * 0.55, -8.0, 8.0)
	ball.sleeping = false
	ball.linear_velocity.x = move_toward(ball.linear_velocity.x, desired_x, 18.0 * delta)
	ball.linear_velocity.z = move_toward(ball.linear_velocity.z, desired_z, 18.0 * delta)
	ball.linear_velocity.y = maxf(ball.linear_velocity.y, 0.0)

func _update_joystick(screen_position: Vector2) -> void:
	var rect := joystick_base.get_global_rect()
	var center := rect.position + rect.size * 0.5
	var offset := screen_position - center
	var radius := minf(rect.size.x, rect.size.y) * 0.34
	if offset.length() > radius:
		offset = offset.normalized() * radius
	joystick_vector = Vector2(offset.x / radius, offset.y / radius)
	_update_joystick_visual()

func _update_joystick_visual() -> void:
	if not joystick_knob:
		return
	var radius := minf(joystick_base.size.x, joystick_base.size.y) * 0.34
	joystick_knob.position = joystick_base.size * 0.5 + Vector2(joystick_vector.x, joystick_vector.y) * radius - joystick_knob.size * 0.5

func _kick_ball() -> void:
	if kick_cooldown > 0.0 or game_paused or match_ended:
		return
	kick_cooldown = 0.45
	var to_ball := ball.global_position - player.global_position
	if to_ball.length() > 4.8:
		status_label.text = "CHEGUE MAIS PERTO DA BOLA"
		message_time = 0.8
		return
	var forward := -player.global_transform.basis.z
	var direction := (forward + Vector3(0, 0.12, 0)).normalized()
	ball.call("kick", direction, BALL_KICK_FORCE, 0.14, 1)
	feedback.call("announce", "shot")
	replay.call("add_event", "shot")
	objectives.call("record_event", "shot")
	stats.call("record_shot", 1, true, player.global_position.distance_to(ball.global_position))
	camera.call("add_shake", 0.12, 0.18)
	status_label.text = "CHUTE!"
	message_time = 1.0

func _pass_ball() -> void:
	if game_paused or match_ended or ball.global_position.distance_to(player.global_position) > 4.8:
		status_label.text = "CHEGUE PERTO DA BOLA PARA PASSAR"
		message_time = 0.9
		return
	var best_player: CharacterBody3D = null
	var best_distance := INF
	for teammate in allies:
		if not is_instance_valid(teammate):
			continue
		var distance := player.global_position.distance_to(teammate.global_position)
		if distance < best_distance and bool(teammate.call("is_available_for_pass")):
			best_distance = distance
			best_player = teammate
	if best_player == null:
		status_label.text = "NENHUM COMPANHEIRO DISPONÍVEL"
		message_time = 0.9
		return
	ball.call("pass_to", best_player.global_position + Vector3(0, 0.2, -0.3), 9.2, 1)
	stats.call("record_pass", 1, true)
	achievements.call("record_pass")
	objectives.call("record_event", "pass")
	replay.call("add_event", "pass")
	feedback.call("announce", "pass")
	status_label.text = "PASSE!"
	message_time = 0.7

func _tackle() -> void:
	if game_paused or match_ended:
		return
	var nearest: CharacterBody3D = null
	var nearest_distance := 3.0
	for rival in opponents:
		if not is_instance_valid(rival):
			continue
		var distance := player.global_position.distance_to(rival.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = rival
	if nearest == null:
		status_label.text = "NÃO HÁ ADVERSÁRIO PERTO"
		message_time = 0.7
		stats.call("record_tackle", 1, false)
		return
	var push := nearest.global_position - player.global_position
	push.y = 0.0
	if push.length_squared() > 0.01:
		nearest.velocity = push.normalized() * 5.5 + Vector3.UP * 1.5
		nearest.call("apply_fatigue", 8.0)
		if nearest_distance < 1.65:
			ball.call("set_last_touch", 1, "Jogador 10")
			stats.call("record_tackle", 1, true)
			achievements.call("record_tackle")
			objectives.call("record_event", "tackle")
			replay.call("add_event", "tackle")
			feedback.call("announce", "tackle")
			status_label.text = "DESARME!"
		else:
			stats.call("record_tackle", 1, false)
			status_label.text = "CHEGUE MAIS PERTO"
	message_time = 0.9

func _build_ai_teams() -> void:
	# Dez atletas de linha em cada equipe, além do jogador controlado e dos goleiros.
	_spawn_ai(1, Vector3(-15.0, 0.9, 11.0), "defender", 3)
	_spawn_ai(1, Vector3(-7.0, 0.9, 13.0), "defender", 4)
	_spawn_ai(1, Vector3(7.0, 0.9, 13.0), "defender", 5)
	_spawn_ai(1, Vector3(15.0, 0.9, 11.0), "defender", 2)
	_spawn_ai(1, Vector3(-9.0, 0.9, 6.0), "support", 8)
	_spawn_ai(1, Vector3(9.0, 0.9, 6.0), "support", 6)
	_spawn_ai(1, Vector3(-13.0, 0.9, 0.0), "winger", 7)
	_spawn_ai(1, Vector3(13.0, 0.9, 0.0), "winger", 11)
	_spawn_ai(1, Vector3(0.0, 0.9, -5.0), "support", 9)
	_spawn_ai(2, Vector3(-15.0, 0.9, -11.0), "defender", 3)
	_spawn_ai(2, Vector3(-7.0, 0.9, -13.0), "defender", 4)
	_spawn_ai(2, Vector3(7.0, 0.9, -13.0), "defender", 5)
	_spawn_ai(2, Vector3(15.0, 0.9, -11.0), "defender", 2)
	_spawn_ai(2, Vector3(-9.0, 0.9, -6.0), "presser", 8)
	_spawn_ai(2, Vector3(9.0, 0.9, -6.0), "presser", 6)
	_spawn_ai(2, Vector3(-13.0, 0.9, 0.0), "winger", 7)
	_spawn_ai(2, Vector3(13.0, 0.9, 0.0), "winger", 11)
	_spawn_ai(2, Vector3(0.0, 0.9, 5.0), "support", 9)
	_spawn_ai(2, Vector3(0.0, 0.9, -9.0), "support", 10)
	goalkeeper = GoalkeeperAI.new()
	goalkeeper.call("configure", ball, true)
	add_child(goalkeeper)
	opponent_goalkeeper = GoalkeeperAI.new()
	opponent_goalkeeper.call("configure", ball, false)
	add_child(opponent_goalkeeper)

func _spawn_ai(team_id: int, start: Vector3, role: String, shirt_number: int) -> void:
	var athlete: CharacterBody3D = FootballerAI.new()
	athlete.call("configure", ball, team_id, start, role, shirt_number)
	add_child(athlete)
	if team_id == 1:
		allies.append(athlete)
	else:
		opponents.append(athlete)

func _toggle_pause() -> void:
	if match_ended:
		return
	game_paused = not game_paused
	if game_paused:
		clock.call("pause_match")
		rules.call("pause_game")
		tactics.call("pause_tactics")
		status_label.text = "PARTIDA PAUSADA"
		pause_button.text = "CONTINUAR"
	else:
		clock.call("resume_match")
		rules.call("resume_game")
		tactics.call("resume_tactics")
		status_label.text = "PARTIDA RETOMADA"
		pause_button.text = "PAUSAR"
		message_time = 1.0
	for athlete in allies + opponents:
		if is_instance_valid(athlete):
			athlete.call("set_ai_enabled", not game_paused)
	if is_instance_valid(goalkeeper):
		goalkeeper.call("set_enabled", not game_paused)

func _on_clock_time_changed(display_text: String, _seconds_left: int) -> void:
	if timer_label:
		timer_label.text = display_text

func _on_period_changed(period: int) -> void:
	if period == 1:
		rules.call("set_half_time")
		feedback.call("announce", "half_time")
		status_label.text = "INTERVALO"
		message_time = 2.0
	else:
		rules.call("resume_second_half")
		rules.call("start_play_after_restart")
		status_label.text = "SEGUNDO TEMPO"
		message_time = 1.5

func _on_restart_requested(restart_type: String, _position: Vector3) -> void:
	if restart_type == "kickoff" and not match_ended:
		rules.call("start_play_after_restart")

func _on_achievement_unlocked(_achievement_id: String, title: String, reward: int) -> void:
	if status_label:
		status_label.text = "CONQUISTA: %s  +%d MOEDAS" % [title, reward]
		message_time = 2.2

func _on_commentary(message: String, _category: String) -> void:
	if status_label and not match_ended:
		status_label.text = message
		message_time = 1.4

func _on_tactic_changed(_tactic_id: String, title: String) -> void:
	feedback.call("announce", "tactic", {"title": title})
	if tactics_button:
		tactics_button.text = title

func _cycle_tactic() -> void:
	var title: String = tactics.call("cycle_tactic")
	if status_label:
		status_label.text = "TÁTICA: %s" % title
		message_time = 1.2

func _on_match_finished() -> void:
	match_ended = true
	feedback.call("announce", "full_time")
	achievements.call("record_match", score > opponent_score)
	achievements.call("save_achievements")
	objectives.call("record_event", "match")
	if score > opponent_score:
		objectives.call("record_event", "win")
	replay.call("stop_recording")
	replay.call("add_event", "full_time")
	replay.call("save_replay")
	game_paused = false
	status_label.text = "FIM DE JOGO • %d - %d" % [score, opponent_score]
	for athlete in allies + opponents:
		if is_instance_valid(athlete):
			athlete.call("set_ai_enabled", false)
	if is_instance_valid(goalkeeper):
		goalkeeper.call("set_enabled", false)
	if is_instance_valid(opponent_goalkeeper):
		opponent_goalkeeper.call("set_enabled", false)
	if profile:
		var result := "win" if score > opponent_score else ("draw" if score == opponent_score else "loss")
		profile.call("record_match_result", result, score, opponent_score)
	if career:
		var fixture: Dictionary = career.call("get_next_user_fixture")
		if not fixture.is_empty():
			var user_is_home := str(fixture.get("home", "")) == str(career.get("user_club"))
			var home_goals := score if user_is_home else opponent_score
			var away_goals := opponent_score if user_is_home else score
			career.call("record_fixture", str(fixture["home"]), str(fixture["away"]), home_goals, away_goals)

func _on_goal_body_entered(body: Node3D, scoring_team: int) -> void:
	if body != ball or match_ended:
		return
	if scoring_team == 1:
		score += 1
		stats.call("record_goal", 1, "Jogador 10")
		status_label.text = "GOOOOOOL! EFOOTDLS! ⚽"
		feedback.call("announce", "goal")
		achievements.call("record_goal")
		objectives.call("record_event", "goal")
	else:
		opponent_score += 1
		status_label.text = "GOL DO ADVERSÁRIO"
		feedback.call("announce", "save")
	message_time = 2.0
	_update_score()
	replay.call("add_event", "goal", {"home": score, "away": opponent_score})
	ball.call("reset_ball", Vector3(0, 0.55, 0.65))
	rules.call("award_goal", scoring_team)
	player.global_position = Vector3(0, 0.9, 2.2)
	player.velocity = Vector3.ZERO
	player_stamina = minf(100.0, player_stamina + 20.0)
	if is_instance_valid(goalkeeper):
		goalkeeper.call("reset_keeper")
	if is_instance_valid(opponent_goalkeeper):
		opponent_goalkeeper.call("reset_keeper")
	for athlete in allies + opponents:
		if is_instance_valid(athlete):
			athlete.velocity = Vector3.ZERO

func _keep_ball_on_field() -> void:
	if ball.global_position.y < -3.0 or absf(ball.global_position.x) > FIELD_WIDTH / 2.0 + 3.0 or absf(ball.global_position.z) > FIELD_LENGTH / 2.0 + 5.0:
		ball.call("reset_ball", Vector3(0, 0.55, 0.65))

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)

	var top := PanelContainer.new()
	top.anchor_left = 0.36
	top.anchor_right = 0.64
	top.anchor_top = 0.025
	top.anchor_bottom = 0.12
	_style_panel(top, Color(0.015, 0.035, 0.06, 0.92))
	ui.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(top_row)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 25)
	score_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	top_row.add_child(score_label)

	timer_label = Label.new()
	timer_label.anchor_left = 0.78
	timer_label.anchor_right = 0.96
	timer_label.anchor_top = 0.035
	timer_label.anchor_bottom = 0.09
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	ui.add_child(timer_label)

	menu_button = _make_action_button("MENU", Color(0.10, 0.18, 0.28))
	menu_button.anchor_left = 0.025
	menu_button.anchor_right = 0.025
	menu_button.anchor_top = 0.035
	menu_button.anchor_bottom = 0.035
	menu_button.offset_left = 0
	menu_button.offset_top = 0
	menu_button.offset_right = 100
	menu_button.offset_bottom = 42
	ui.add_child(menu_button)
	menu_button.pressed.connect(_return_to_lobby)

	pause_button = _make_action_button("PAUSAR", Color(0.18, 0.22, 0.30))
	pause_button.anchor_left = 0.87
	pause_button.anchor_right = 0.87
	pause_button.anchor_top = 0.12
	pause_button.anchor_bottom = 0.12
	pause_button.offset_left = -8
	pause_button.offset_top = 0
	pause_button.offset_right = 112
	pause_button.offset_bottom = 42
	ui.add_child(pause_button)
	pause_button.pressed.connect(_toggle_pause)

	status_label = Label.new()
	status_label.text = "CONTROLE O JOGADOR E FAÇA O GOL"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.anchor_left = 0.25
	status_label.anchor_right = 0.75
	status_label.anchor_top = 0.14
	status_label.anchor_bottom = 0.20
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	ui.add_child(status_label)

	joystick_base = Panel.new()
	joystick_base.anchor_left = 0.055
	joystick_base.anchor_top = 0.69
	joystick_base.anchor_right = 0.055
	joystick_base.anchor_bottom = 0.69
	joystick_base.offset_left = 0
	joystick_base.offset_top = 0
	joystick_base.offset_right = 154
	joystick_base.offset_bottom = 154
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(0.04, 0.10, 0.16, 0.68)
	base_style.border_color = Color(0.72, 0.82, 0.95, 0.55)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(100)
	joystick_base.add_theme_stylebox_override("panel", base_style)
	ui.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.position = Vector2(48, 48)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = Color(0.86, 0.91, 0.98, 0.88)
	knob_style.set_corner_radius_all(50)
	joystick_knob.add_theme_stylebox_override("panel", knob_style)
	joystick_base.add_child(joystick_knob)

	sprint_button = _make_action_button("CORRER", Color(0.12, 0.35, 0.62))
	sprint_button.anchor_left = 0.79
	sprint_button.anchor_right = 0.79
	sprint_button.anchor_top = 0.77
	sprint_button.anchor_bottom = 0.77
	sprint_button.offset_left = -10
	sprint_button.offset_top = -5
	sprint_button.offset_right = 120
	sprint_button.offset_bottom = 55
	ui.add_child(sprint_button)
	sprint_button.button_down.connect(func(): sprinting = true)
	sprint_button.button_up.connect(func(): sprinting = false)

	kick_button = _make_action_button("CHUTAR", Color(0.82, 0.56, 0.12))
	kick_button.anchor_left = 0.86
	kick_button.anchor_right = 0.86
	kick_button.anchor_top = 0.87
	kick_button.anchor_bottom = 0.87
	kick_button.offset_left = -8
	kick_button.offset_top = -8
	kick_button.offset_right = 125
	kick_button.offset_bottom = 58
	ui.add_child(kick_button)
	kick_button.pressed.connect(_kick_ball)

	pass_button = _make_action_button("PASSE", Color(0.12, 0.48, 0.34))
	pass_button.anchor_left = 0.69
	pass_button.anchor_right = 0.69
	pass_button.anchor_top = 0.88
	pass_button.anchor_bottom = 0.88
	pass_button.offset_left = -6
	pass_button.offset_top = -8
	pass_button.offset_right = 106
	pass_button.offset_bottom = 48
	ui.add_child(pass_button)
	pass_button.pressed.connect(_pass_ball)

	tactics_button = _make_action_button("EQUILIBRADO", Color(0.20, 0.34, 0.52))
	tactics_button.anchor_left = 0.68
	tactics_button.anchor_right = 0.68
	tactics_button.anchor_top = 0.16
	tactics_button.anchor_bottom = 0.16
	tactics_button.offset_left = -7
	tactics_button.offset_top = 0
	tactics_button.offset_right = 128
	tactics_button.offset_bottom = 42
	ui.add_child(tactics_button)
	tactics_button.pressed.connect(_cycle_tactic)

	tackle_button = _make_action_button("DESARME", Color(0.62, 0.18, 0.20))
	tackle_button.anchor_left = 0.72
	tackle_button.anchor_right = 0.72
	tackle_button.anchor_top = 0.68
	tackle_button.anchor_bottom = 0.68
	tackle_button.offset_left = -7
	tackle_button.offset_top = -4
	tackle_button.offset_right = 109
	tackle_button.offset_bottom = 48
	ui.add_child(tackle_button)
	tackle_button.pressed.connect(_tackle)

	stamina_bar = ProgressBar.new()
	stamina_bar.anchor_left = 0.055
	stamina_bar.anchor_right = 0.28
	stamina_bar.anchor_top = 0.65
	stamina_bar.anchor_bottom = 0.65
	stamina_bar.offset_bottom = 12
	stamina_bar.min_value = 0
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	ui.add_child(stamina_bar)

	var instructions := Label.new()
	instructions.text = "JOYSTICK: MOVER  •  PASSE  •  CHUTAR  •  DESARME"
	instructions.anchor_left = 0.29
	instructions.anchor_right = 0.71
	instructions.anchor_top = 0.94
	instructions.anchor_bottom = 0.99
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 11)
	instructions.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.85))
	ui.add_child(instructions)

	minimap = MinimapOverlay.new()
	minimap.anchor_left = 0.80
	minimap.anchor_right = 0.98
	minimap.anchor_top = 0.20
	minimap.anchor_bottom = 0.37
	minimap.offset_left = 0
	minimap.offset_top = 0
	minimap.offset_right = 0
	minimap.offset_bottom = 0
	ui.add_child(minimap)
	minimap.call("configure", player, ball, allies, opponents)
	accessibility.call("apply_interface", ui)

func _make_action_button(caption: String, color: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(1, 1, 1, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(40)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button

func _style_panel(panel: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.65, 0.76, 0.9, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

func _update_score() -> void:
	if score_label:
		score_label.text = "EFOOTDLS     %d  -  %d" % [score, opponent_score]


func _return_to_lobby() -> void:
	var result := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if result != OK:
		status_label.text = "NÃO FOI POSSÍVEL VOLTAR AO LOBBY"
