extends Node3D

const GOLD := Color(0.95, 0.72, 0.28)
const PANEL := Color(0.035, 0.065, 0.10, 0.94)
const MUTED := Color(0.68, 0.75, 0.82)

var camera: Camera3D
var ball: MeshInstance3D
var time_passed := 0.0

func _ready() -> void:
	_build_stadium()
	_build_hero_player()
	_build_interface()

func _process(delta: float) -> void:
	time_passed += delta
	if ball:
		ball.rotation.y += delta * 0.7
		ball.position.y = 0.55 + sin(time_passed * 1.4) * 0.06
	if camera:
		camera.position.x = sin(time_passed * 0.12) * 1.8
		camera.look_at(Vector3(0, 2.0, 0), Vector3.UP)

func _material(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _build_stadium() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.42, 0.56)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	camera = Camera3D.new()
	camera.position = Vector3(0, 16, 31)
	camera.fov = 48
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0, 2, 0), Vector3.UP)

	_box(self, Vector3(112, 0.5, 76), Vector3(0, -0.45, 0), Color(0.035, 0.25, 0.12))
	_box(self, Vector3(104, 0.08, 68), Vector3(0, -0.16, 0), Color(0.08, 0.39, 0.18))
	# Marcação simplificada do gramado.
	_box(self, Vector3(0.12, 0.025, 60), Vector3(0, -0.105, 0), Color(0.78, 0.91, 0.78))
	_box(self, Vector3(92, 0.025, 0.12), Vector3(0, -0.105, 0), Color(0.78, 0.91, 0.78))
	_box(self, Vector3(0.12, 0.025, 60), Vector3(-46, -0.105, 0), Color(0.78, 0.91, 0.78))
	_box(self, Vector3(0.12, 0.025, 60), Vector3(46, -0.105, 0), Color(0.78, 0.91, 0.78))
	_box(self, Vector3(0.12, 0.025, 20), Vector3(-35, -0.105, 0), Color(0.78, 0.91, 0.78))
	_box(self, Vector3(0.12, 0.025, 20), Vector3(35, -0.105, 0), Color(0.78, 0.91, 0.78))

	# Arquibancadas em níveis, com iluminação de estádio.
	for side in [-1.0, 1.0]:
		for tier in range(4):
			var z := side * (39.0 + tier * 2.0)
			_box(self, Vector3(112 - tier * 4, 2.3, 3.8), Vector3(0, 2.0 + tier * 2.0, z), Color(0.055 + tier * 0.012, 0.09 + tier * 0.012, 0.15 + tier * 0.015))
	for side in [-1.0, 1.0]:
		for tier in range(3):
			var x := side * (57.0 + tier * 2.0)
			_box(self, Vector3(3.8, 2.2, 70 - tier * 5), Vector3(x, 2.0 + tier * 2.0, 0), Color(0.06, 0.10, 0.16))
	for i in range(12):
		var light := OmniLight3D.new()
		light.position = Vector3(-48 + i * 8.7, 13, -39)
		light.light_color = Color(0.72, 0.83, 1.0)
		light.light_energy = 1.3
		light.omni_range = 23
		add_child(light)

	# Bola decorativa em primeiro plano.
	ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	ball.mesh = sphere
	ball.position = Vector3(13, 0.55, 4)
	ball.material_override = _material(Color(0.92, 0.94, 0.98), 0.35)
	add_child(ball)


func _capsule(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	part.mesh = shape
	part.position = pos
	part.material_override = _material(color, 0.62)
	parent.add_child(part)
	return part

func _build_hero_player() -> void:
	# Atleta estilizado original para dar vida ao lobby sem depender de modelos externos.
	var player := Node3D.new()
	player.position = Vector3(8.5, 0.0, 0.0)
	player.rotation_degrees.y = -18
	add_child(player)
	_capsule(player, 0.29, 1.12, Vector3(0, 1.18, 0), Color(0.08, 0.32, 0.78))
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position = Vector3(0, 1.92, 0)
	head.material_override = _material(Color(0.72, 0.48, 0.32))
	player.add_child(head)
	_capsule(player, 0.14, 0.92, Vector3(-0.17, 0.48, 0), Color(0.08, 0.09, 0.13))
	_capsule(player, 0.14, 0.92, Vector3(0.17, 0.48, 0), Color(0.08, 0.09, 0.13))
	var left_arm := _capsule(player, 0.105, 0.82, Vector3(-0.39, 1.18, 0), Color(0.72, 0.48, 0.32))
	left_arm.rotation_degrees.z = -12
	var right_arm := _capsule(player, 0.105, 0.82, Vector3(0.39, 1.18, 0), Color(0.72, 0.48, 0.32))
	right_arm.rotation_degrees.z = 12

func _style_panel(panel: PanelContainer, color := PANEL) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.28, 0.39, 0.52, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)

func _make_label(text_value: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _make_button(caption: String, primary := false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(210, 54)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.035, 0.055, 0.08) if primary else Color(0.92, 0.95, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD if primary else Color(0.08, 0.14, 0.21, 0.96)
	normal.border_color = Color(1, 0.82, 0.48, 0.8) if primary else Color(0.30, 0.43, 0.56, 0.8)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.82, 0.42) if primary else Color(0.13, 0.22, 0.32)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.008, 0.018, 0.035, 0.48)
	root.add_child(shade)

	var header := PanelContainer.new()
	header.anchor_left = 0.025
	header.anchor_right = 0.975
	header.anchor_top = 0.035
	header.anchor_bottom = 0.15
	_style_panel(header, Color(0.018, 0.035, 0.06, 0.92))
	root.add_child(header)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	header.add_child(top)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	brand.add_child(_make_label("EFOOTDLS", 27, GOLD, true))
	brand.add_child(_make_label("FOOTBALL • CLUB EXPERIENCE", 10, MUTED))
	top.add_child(_make_label("PERFIL  01     ◈  12.500     ◆  850", 15, Color(0.95, 0.97, 1.0), true))

	var left := VBoxContainer.new()
	left.anchor_left = 0.045
	left.anchor_top = 0.24
	left.anchor_bottom = 0.91
	left.custom_minimum_size = Vector2(300, 0)
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)

	left.add_child(_make_label("BEM-VINDO DE VOLTA", 13, GOLD, true))
	left.add_child(_make_label("O campo é seu.", 34, Color(1, 1, 1), true))
	left.add_child(_make_label("Monte seu time e entre em campo.", 15, MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	left.add_child(spacer)

	var play := _make_button("▶   JOGAR PARTIDA", true)
	play.pressed.connect(_on_play_pressed)
	left.add_child(play)
	var dream := _make_button("✦   DREAM TEAM")
	dream.pressed.connect(_on_dream_team_pressed)
	left.add_child(dream)
	var squad := _make_button("♟   MEU ELENCO")
	squad.pressed.connect(_on_squad_pressed)
	left.add_child(squad)
	var shop := _make_button("◇   LOJA")
	shop.pressed.connect(_on_shop_pressed)
	left.add_child(shop)

	var event_panel := PanelContainer.new()
	event_panel.anchor_left = 0.69
	event_panel.anchor_right = 0.96
	event_panel.anchor_top = 0.64
	event_panel.anchor_bottom = 0.90
	_style_panel(event_panel, Color(0.025, 0.055, 0.085, 0.94))
	root.add_child(event_panel)
	var event_content := VBoxContainer.new()
	event_content.add_theme_constant_override("separation", 7)
	event_panel.add_child(event_content)
	event_content.add_child(_make_label("EVENTO EM DESTAQUE", 11, GOLD, true))
	event_content.add_child(_make_label("NOITE DOS CAMPEÕES", 19, Color.WHITE, true))
	event_content.add_child(_make_label("Desafie equipes e conquiste recompensas.", 12, MUTED))
	var event_button := _make_button("VER EVENTO")
	event_button.custom_minimum_size = Vector2(0, 42)
	event_button.pressed.connect(_on_event_pressed)
	event_content.add_child(event_button)

	var footer := _make_label("EFOOTDLS  •  TEMPORADA 2026  •  MENU INICIAL", 10, Color(0.75, 0.82, 0.9, 0.8))
	footer.anchor_left = 0.03
	footer.anchor_right = 0.97
	footer.anchor_top = 0.955
	footer.anchor_bottom = 0.99
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(footer)

func _show_message(title_text: String, body_text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body_text
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(420, 180))

func _on_play_pressed() -> void:
	_show_message("Partida", "O lobby está pronto. O modo de partida será implementado na próxima etapa.")

func _on_dream_team_pressed() -> void:
	_show_message("Dream Team", "A área de montagem do seu time será construída na próxima etapa.")

func _on_squad_pressed() -> void:
	_show_message("Meu Elenco", "Aqui ficará a escalação, formação e gerenciamento dos jogadores.")

func _on_shop_pressed() -> void:
	_show_message("Loja", "A loja do Efootdls será conectada ao sistema de itens do jogo.")

func _on_event_pressed() -> void:
	_show_message("Evento", "Os eventos e desafios serão adicionados ao modo carreira.")
