extends Node3D
## Modelo humano articulado leve, com uniforme, rosto, chuteiras e ciclo de corrida.
## Mantém a física no CharacterBody3D pai e anima apenas a camada visual.

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var run_phase := 0.0
var shirt_color := Color(0.07, 0.28, 0.82)
var shorts_color := Color(0.035, 0.055, 0.09)
var skin_color := Color(0.58, 0.37, 0.25)

func configure(team_color: Color, shirt_number: int = 0) -> void:
	shirt_color = team_color
	_build_model(shirt_number)

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	var body := get_parent() as CharacterBody3D
	var speed := 0.0
	if is_instance_valid(body):
		speed = Vector2(body.velocity.x, body.velocity.z).length()
	set_motion(speed, delta)

func _material(color: Color, roughness := 0.72) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _capsule(parent: Node3D, part_name: String, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = part_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = at
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _sphere(parent: Node3D, part_name: String, radius: float, at: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = part_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	item.mesh = mesh
	item.position = at
	item.scale = scale_value
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _pivot(part_name: String, at: Vector3) -> Node3D:
	var item := Node3D.new()
	item.name = part_name
	item.position = at
	add_child(item)
	return item

func _build_model(shirt_number: int) -> void:
	# Tronco com volume humano, pescoço e gola.
	_capsule(self, "Jersey", 0.275, 0.78, Vector3(0, 0.12, 0), shirt_color)
	_capsule(self, "Neck", 0.078, 0.15, Vector3(0, 0.55, 0), skin_color)
	_capsule(self, "Collar", 0.092, 0.085, Vector3(0, 0.49, -0.005), Color(0.91, 0.94, 0.98))
	_sphere(self, "Head", 0.17, Vector3(0, 0.76, 0), Vector3(0.88, 1.12, 0.92), skin_color)
	_sphere(self, "Hair", 0.17, Vector3(0, 0.91, 0.018), Vector3(0.94, 0.48, 0.97), Color(0.09, 0.065, 0.045))
	_sphere(self, "LeftEar", 0.045, Vector3(-0.158, 0.75, 0), Vector3(0.65, 1.0, 0.8), skin_color)
	_sphere(self, "RightEar", 0.045, Vector3(0.158, 0.75, 0), Vector3(0.65, 1.0, 0.8), skin_color)
	for side in [-1.0, 1.0]:
		_sphere(self, "Eye", 0.018, Vector3(side * 0.060, 0.785, -0.145), Vector3(1.0, 0.82, 0.55), Color(0.025, 0.025, 0.03))
	_sphere(self, "Nose", 0.027, Vector3(0, 0.735, -0.16), Vector3(0.72, 0.82, 0.72), skin_color)

	# Calção com cintura e duas pernas articuladas.
	var shorts := MeshInstance3D.new()
	shorts.name = "Shorts"
	var shorts_mesh := CylinderMesh.new()
	shorts_mesh.top_radius = 0.225
	shorts_mesh.bottom_radius = 0.255
	shorts_mesh.height = 0.34
	shorts.mesh = shorts_mesh
	shorts.position = Vector3(0, -0.285, 0)
	shorts.material_override = _material(shorts_color)
	add_child(shorts)

	left_leg = _pivot("LeftLeg", Vector3(-0.145, -0.34, 0))
	right_leg = _pivot("RightLeg", Vector3(0.145, -0.34, 0))
	for leg in [left_leg, right_leg]:
		_capsule(leg, "Thigh", 0.115, 0.39, Vector3(0, -0.18, 0), skin_color)
		_capsule(leg, "Sock", 0.087, 0.36, Vector3(0, -0.50, 0), Color(0.91, 0.93, 0.96))
		_sphere(leg, "Boot", 0.105, Vector3(0, -0.70, -0.065), Vector3(1.0, 0.58, 1.65), Color(0.025, 0.035, 0.05))
		_sphere(leg, "BootSole", 0.085, Vector3(0, -0.745, -0.055), Vector3(1.05, 0.28, 1.55), Color(0.12, 0.13, 0.15))

	# Braços em dois segmentos, com mãos e mangas do uniforme.
	left_arm = _pivot("LeftArm", Vector3(-0.30, 0.39, 0))
	right_arm = _pivot("RightArm", Vector3(0.30, 0.39, 0))
	for arm in [left_arm, right_arm]:
		_capsule(arm, "Sleeve", 0.092, 0.36, Vector3(0, -0.16, 0), shirt_color)
		var forearm := _pivot("Forearm", Vector3(0, -0.31, 0))
		arm.add_child(forearm)
		_capsule(forearm, "ForearmMesh", 0.071, 0.31, Vector3(0, -0.15, 0), skin_color)
		_sphere(forearm, "Hand", 0.072, Vector3(0, -0.31, 0), Vector3(0.9, 1.0, 0.8), skin_color)

	# Número nas costas, visível quando o jogador se afasta da câmera.
	var number := Label3D.new()
	number.name = "ShirtNumber"
	number.text = str(shirt_number) if shirt_number > 0 else ""
	number.position = Vector3(0, 0.14, 0.279)
	number.rotation.y = PI
	number.pixel_size = 0.0045
	number.font_size = 44
	number.modulate = Color.WHITE
	add_child(number)

func set_motion(speed: float, delta: float) -> void:
	if not is_instance_valid(left_leg) or not is_instance_valid(right_leg):
		return
	var intensity := clampf(speed / 6.2, 0.0, 1.0)
	if intensity > 0.03:
		run_phase += delta * lerpf(4.0, 9.0, intensity)
	var swing := sin(run_phase) * 0.62 * intensity
	var blend := clampf(delta * 14.0, 0.0, 1.0)
	left_leg.rotation.x = lerpf(left_leg.rotation.x, swing, blend)
	right_leg.rotation.x = lerpf(right_leg.rotation.x, -swing, blend)
	if is_instance_valid(left_arm):
		left_arm.rotation.x = lerpf(left_arm.rotation.x, -swing * 0.72, blend)
	if is_instance_valid(right_arm):
		right_arm.rotation.x = lerpf(right_arm.rotation.x, swing * 0.72, blend)
	position.y = sin(run_phase * 2.0) * 0.025 * intensity
