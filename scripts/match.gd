extends Node3D

const FIELD_LENGTH := 64.0
const FIELD_WIDTH := 42.0
const PLAYER_SPEED := 7.0
const SPRINT_SPEED := 11.5
const BALL_KICK_FORCE := 13.5

var player: CharacterBody3D
var ball: RigidBody3D
var camera: Camera3D
var joystick_base: Control
var joystick_knob: Control
var sprint_button: Button
var kick_button: Button
var score_label: Label
var status_label: Label
var score := 0
var joystick_vector := Vector2.ZERO
var joystick_touch_id := -1
var sprinting := false
var goal_area: Area3D
var kick_cooldown := 0.0
var message_time := 0.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_ball()
	_build_goal()
	_build_camera()
	_build_hud()
	_update_score()

func _physics_process(delta: float) -> void:
	kick_cooldown = maxf(0.0, kick_cooldown - delta)
	message_time = maxf(0.0, message_time - delta)
	if message_time <= 0.0 and status_label:
		status_label.text = "CONTROLE O JOGADOR E FAÇA O GOL"
	_move_player(delta)
	_update_camera(delta)
	_keep_ball_on_field()

func _input(event: InputEvent) -> void:
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
		if event.position.x > screen_width * 0.52:
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
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.045, 0.075)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.70, 0.82)
	environment.ambient_light_energy = 0.8
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -25, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

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
	player.position = Vector3(0, 0.9, 19)
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
	ball.position = Vector3(0, 0.55, 16.8)
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
	var goal_z := -FIELD_LENGTH / 2.0 + 1.2
	var post_material := Color(0.9, 0.94, 1.0)
	_add_box(self, Vector3(0.28, 3.2, 0.28), Vector3(-4.0, 1.6, goal_z), post_material, true)
	_add_box(self, Vector3(0.28, 3.2, 0.28), Vector3(4.0, 1.6, goal_z), post_material, true)
	_add_box(self, Vector3(8.2, 0.25, 0.28), Vector3(0, 3.2, goal_z), post_material, true)
	_add_box(self, Vector3(0.12, 3.0, 3.0), Vector3(-4.0, 1.5, goal_z - 1.5), Color(0.55, 0.65, 0.78, 0.5), true)
	_add_box(self, Vector3(0.12, 3.0, 3.0), Vector3(4.0, 1.5, goal_z - 1.5), Color(0.55, 0.65, 0.78, 0.5), true)

	goal_area = Area3D.new()
	goal_area.position = Vector3(0, 1.5, goal_z - 1.3)
	var area_collision := CollisionShape3D.new()
	var area_shape := BoxShape3D.new()
	area_shape.size = Vector3(7.6, 3.0, 2.4)
	area_collision.shape = area_shape
	goal_area.add_child(area_collision)
	goal_area.body_entered.connect(_on_goal_body_entered)
	add_child(goal_area)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 10, 29)
	camera.fov = 62
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0, 0, 8), Vector3.UP)

func _update_camera(delta: float) -> void:
	var target := player.global_position + Vector3(0, 8.5, 10.5)
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 4.0))
	camera.look_at(player.global_position + Vector3(0, 0.8, -7.0), Vector3.UP)

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

	var speed := SPRINT_SPEED if sprinting or Input.is_key_pressed(KEY_SHIFT) else PLAYER_SPEED
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.velocity.y -= 24.0 * get_physics_process_delta_time()
	player.move_and_slide()
	player.position.x = clampf(player.position.x, -FIELD_WIDTH / 2.0 + 1.2, FIELD_WIDTH / 2.0 - 1.2)
	player.position.z = clampf(player.position.z, -FIELD_LENGTH / 2.0 + 2.0, FIELD_LENGTH / 2.0 - 2.0)
	if Vector2(direction.x, direction.z).length() > 0.12:
		player.rotation.y = atan2(-direction.x, -direction.z)

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
	if kick_cooldown > 0.0:
		return
	kick_cooldown = 0.45
	var forward := -player.global_transform.basis.z
	var to_ball := ball.global_position - player.global_position
	if to_ball.length() > 4.0:
		forward = Vector3(0, 0, -1)
	var direction := (forward + Vector3(0, 0.12, 0)).normalized()
	ball.sleeping = false
	ball.apply_central_impulse(direction * BALL_KICK_FORCE + Vector3.UP * 1.8)
	status_label.text = "CHUTE!"
	message_time = 1.0

func _on_goal_body_entered(body: Node3D) -> void:
	if body == ball:
		score += 1
		_update_score()
		status_label.text = "GOOOOOOL! ⚽"
		message_time = 2.0
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.global_position = Vector3(0, 0.55, 16.8)
		player.global_position = Vector3(0, 0.9, 19)
		player.velocity = Vector3.ZERO

func _keep_ball_on_field() -> void:
	if ball.global_position.y < -3.0 or absf(ball.global_position.x) > FIELD_WIDTH / 2.0 + 3.0 or absf(ball.global_position.z) > FIELD_LENGTH / 2.0 + 5.0:
		ball.linear_velocity = Vector3.ZERO
		ball.angular_velocity = Vector3.ZERO
		ball.global_position = Vector3(0, 0.55, 16.8)

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

	var instructions := Label.new()
	instructions.text = "DESLIZE O JOYSTICK • TOQUE EM CHUTAR"
	instructions.anchor_left = 0.29
	instructions.anchor_right = 0.71
	instructions.anchor_top = 0.94
	instructions.anchor_bottom = 0.99
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_font_size_override("font_size", 11)
	instructions.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98, 0.85))
	ui.add_child(instructions)

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
		score_label.text = "EFOOTDLS     %d  -  0" % score
