extends Node3D
## Lobby principal do Efootdls. Menus conectados a perfil, elenco, mercado e partida.

const MATCH_SCENE := "res://scenes/match.tscn"
const PROFILE_STORE = preload("res://scripts/profile_store.gd")
const ROSTER_MANAGER = preload("res://scripts/roster_manager.gd")
const TRANSFER_MARKET = preload("res://scripts/transfer_market.gd")
const STADIUM_ASSET = preload("res://scripts/stadium_asset.gd")
const FOOTBALLER_VISUAL = preload("res://scripts/footballer_visual.gd")
const FORMATIONS := ["4-3-3", "4-4-2", "4-2-3-1", "3-5-2", "5-3-2"]

const GOLD := Color(1.0, 0.76, 0.30)
const TEXT_MAIN := Color(0.94, 0.97, 1.0)
const TEXT_MUTED := Color(0.61, 0.69, 0.78)
const PANEL_COLOR := Color(0.025, 0.055, 0.09, 0.96)
const ACCENT_BLUE := Color(0.10, 0.43, 0.78)

var profile: Node
var roster: RefCounted
var market: RefCounted
var root_ui: Control
var page_title: Label
var page_subtitle: Label
var page_body: VBoxContainer
var wallet_label: Label
var notice_label: Label
var current_page := "home"
var time_passed := 0.0
var hero_ball: MeshInstance3D
var stadium_visual_root: Node3D

func _ready() -> void:
	profile = PROFILE_STORE.new()
	add_child(profile)
	roster = ROSTER_MANAGER.new()
	_load_roster()
	market = TRANSFER_MARKET.new()
	market.call("load_market")
	market.call("set_balance", int(profile.call("get_profile").get("coins", 0)))
	if market.call("get_offers").is_empty():
		market.call("refresh_market", 8)
	_build_stadium_background()
	_build_interface()
	_show_page("home")
	var stadium := STADIUM_ASSET.new()
	stadium.configure(0.75)
	stadium.finished.connect(_on_stadium_asset_finished)
	add_child(stadium)

func _process(delta: float) -> void:
	time_passed += delta
	if is_instance_valid(hero_ball):
		hero_ball.rotation.x += delta * 0.55
		hero_ball.rotation.y += delta * 0.9
		hero_ball.position.y = 0.48 + sin(time_passed * 1.5) * 0.08

func _build_stadium_background() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.018, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.52, 0.64, 0.82)
	environment.ambient_light_energy = 0.8
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 42, 78)
	camera.fov = 58
	add_child(camera)
	camera.look_at(Vector3(0, 4.0, 0), Vector3.UP)
	camera.current = true

	stadium_visual_root = Node3D.new()
	stadium_visual_root.name = "FallbackStadium"
	add_child(stadium_visual_root)
	_add_box(Vector3(100, 0.7, 82), Vector3(0, -0.5, 0), Color(0.018, 0.075, 0.065))
	_add_box(Vector3(78, 0.08, 54), Vector3(0, -0.08, 0), Color(0.035, 0.29, 0.13))
	for stripe in range(9):
		var shade := Color(0.045, 0.34, 0.15) if stripe % 2 == 0 else Color(0.03, 0.27, 0.12)
		_add_box(Vector3(78, 0.025, 6), Vector3(0, -0.025, -24 + stripe * 6), shade)
	_add_box(Vector3(0.12, 0.025, 52), Vector3(0, 0.02, 0), Color(0.86, 0.93, 0.87))
	_add_box(Vector3(78, 0.025, 0.12), Vector3(0, 0.02, 0), Color(0.86, 0.93, 0.87))
	_add_box(Vector3(0.12, 0.025, 52), Vector3(-39, 0.02, 0), Color(0.86, 0.93, 0.87))
	_add_box(Vector3(0.12, 0.025, 52), Vector3(39, 0.02, 0), Color(0.86, 0.93, 0.87))
	_add_box(Vector3(0.12, 0.025, 52), Vector3(0, 0.02, 0), Color(0.86, 0.93, 0.87))
	for side in [-1.0, 1.0]:
		for tier in range(4):
			_add_box(Vector3(82 - tier * 3, 2.1, 3.1), Vector3(0, 1.2 + tier * 1.8, side * (30 + tier * 2.0)), Color(0.025 + tier * 0.009, 0.055 + tier * 0.012, 0.10 + tier * 0.02))
		for tier in range(3):
			_add_box(Vector3(3.0, 2.0, 57 - tier * 4), Vector3(side * (43 + tier * 2.0), 1.0 + tier * 1.7, 0), Color(0.025, 0.07, 0.12))
	for index in range(8):
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(-34 + index * 9.7, 14, -29)
		lamp.light_color = Color(0.68, 0.82, 1.0)
		lamp.light_energy = 1.25
		lamp.omni_range = 28
		add_child(lamp)

	# Bola e atleta de destaque no cenário do menu.
	var player := Node3D.new()
	player.position = Vector3(13, 0.9, 0)
	player.rotation_degrees.y = -14
	add_child(player)
	var player_model := FOOTBALLER_VISUAL.new()
	player_model.name = "LobbyFootballer"
	player_model.configure(Color(0.06, 0.30, 0.82), 10)
	player.add_child(player_model)
	hero_ball = _add_sphere(self, 0.48, Vector3(8.2, 0.48, 4.8), Color(0.96, 0.97, 1.0))

func _on_stadium_asset_finished(success: bool) -> void:
	if success and is_instance_valid(stadium_visual_root):
		stadium_visual_root.visible = false
		if is_instance_valid(notice_label):
			notice_label.text = "ESTÁDIO 3D CC0 CARREGADO"

func _add_box(size: Vector3, position_value: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = position_value
	item.material_override = _material(color)
	stadium_visual_root.add_child(item)
	return item

func _add_capsule(parent: Node3D, radius: float, height: float, position_value: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	item.mesh = mesh
	item.position = position_value
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _add_sphere(parent: Node3D, radius: float, position_value: Vector3, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	item.mesh = mesh
	item.position = position_value
	item.material_override = _material(color)
	parent.add_child(item)
	return item

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.58
	return material

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root_ui)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.012, 0.025, 0.50)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(shade)

	var header := PanelContainer.new()
	header.anchor_left = 0.025
	header.anchor_right = 0.975
	header.anchor_top = 0.025
	header.anchor_bottom = 0.14
	_style_panel(header, Color(0.012, 0.03, 0.055, 0.97))
	root_ui.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	header.add_child(header_row)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(brand)
	brand.add_child(_label("EFOOTDLS", 28, GOLD, true))
	brand.add_child(_label("CLUB FOOTBALL • MOBILE EDITION", 10, TEXT_MUTED))
	wallet_label = _label("", 16, TEXT_MAIN, true)
	wallet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(wallet_label)

	var nav := PanelContainer.new()
	nav.anchor_left = 0.025
	nav.anchor_right = 0.215
	nav.anchor_top = 0.17
	nav.anchor_bottom = 0.96
	_style_panel(nav)
	root_ui.add_child(nav)
	var nav_list := VBoxContainer.new()
	nav_list.add_theme_constant_override("separation", 9)
	nav.add_child(nav_list)
	nav_list.add_child(_label("CENTRAL DO CLUBE", 12, GOLD, true))
	_add_nav_button(nav_list, "INÍCIO", "home")
	_add_nav_button(nav_list, "DREAM TEAM", "dream")
	_add_nav_button(nav_list, "MEU ELENCO", "squad")
	_add_nav_button(nav_list, "MERCADO", "market")
	_add_nav_button(nav_list, "EVENTOS", "events")
	_add_nav_button(nav_list, "CONFIGURAÇÕES", "settings")
	var nav_spacer := Control.new()
	nav_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav_list.add_child(nav_spacer)
	notice_label = _label("SEU CLUBE. SUAS CONQUISTAS.", 10, TEXT_MUTED)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nav_list.add_child(notice_label)

	var content := PanelContainer.new()
	content.anchor_left = 0.235
	content.anchor_right = 0.975
	content.anchor_top = 0.17
	content.anchor_bottom = 0.96
	_style_panel(content, Color(0.012, 0.032, 0.058, 0.95))
	root_ui.add_child(content)
	var page_column := VBoxContainer.new()
	page_column.add_theme_constant_override("separation", 5)
	content.add_child(page_column)
	page_title = _label("", 27, TEXT_MAIN, true)
	page_column.add_child(page_title)
	page_subtitle = _label("", 12, TEXT_MUTED)
	page_column.add_child(page_subtitle)
	var separator := HSeparator.new()
	page_column.add_child(separator)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_column.add_child(scroll)
	page_body = VBoxContainer.new()
	page_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_body.add_theme_constant_override("separation", 12)
	scroll.add_child(page_body)
	_refresh_wallet()

func _add_nav_button(parent: VBoxContainer, caption: String, page: String) -> void:
	var button := _make_button(caption, false)
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func(): _show_page(page))
	parent.add_child(button)

func _show_page(page: String) -> void:
	current_page = page
	for child in page_body.get_children():
		child.queue_free()

	if page == "home":
		page_title.text = "PAINEL DO CLUBE"
		page_subtitle.text = "Entre em campo, construa seu elenco e avance na temporada."
		_build_home_page()
	elif page == "dream":
		page_title.text = "DREAM TEAM"
		page_subtitle.text = "Seu projeto de equipe começa com uma escalação forte."
		_build_dream_page()
	elif page == "squad":
		page_title.text = "MEU ELENCO"
		page_subtitle.text = "Gerencie titulares, reservas e formação tática."
		_build_squad_page()
	elif page == "market":
		page_title.text = "MERCADO DE ATLETAS"
		page_subtitle.text = "Contrate jogadores usando as moedas do seu perfil."
		_build_market_page()
	elif page == "events":
		page_title.text = "EVENTOS"
		page_subtitle.text = "Partidas e desafios disponíveis no Efootdls."
		_build_events_page()
	elif page == "settings":
		page_title.text = "CONFIGURAÇÕES"
		page_subtitle.text = "Preferências do seu clube e do jogo."
		_build_settings_page()
	else:
		page_title.text = "PAINEL DO CLUBE"
		page_subtitle.text = "Entre em campo, construa seu elenco e avance na temporada."
		_build_home_page()

	_refresh_wallet()

func _build_home_page() -> void:
	var hero := _card()
	var hero_column := VBoxContainer.new()
	hero_column.add_theme_constant_override("separation", 9)
	hero.add_child(hero_column)
	hero_column.add_child(_label("TEMPORADA 2026", 12, GOLD, true))
	var title := _label("O PRÓXIMO CAPÍTULO COMEÇA NO CAMPO.", 25, TEXT_MAIN, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_column.add_child(title)
	hero_column.add_child(_label("Controle seu time, marque gols e monte uma equipe competitiva.", 14, TEXT_MUTED))
	var play := _make_button("▶  JOGAR PARTIDA", true)
	play.custom_minimum_size = Vector2(250, 56)
	play.pressed.connect(_start_match)
	hero_column.add_child(play)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 12)
	page_body.add_child(stats_row)
	var data: Dictionary = profile.call("get_profile")
	_add_stat_card(stats_row, "PARTIDAS", str(data.get("matches", 0)))
	_add_stat_card(stats_row, "VITÓRIAS", str(data.get("wins", 0)))
	_add_stat_card(stats_row, "GOLS", str(data.get("goals", 0)))
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 12)
	page_body.add_child(quick)
	var squad_button := _make_button("ABRIR ELENCO", false)
	squad_button.pressed.connect(func(): _show_page("squad"))
	quick.add_child(squad_button)
	var market_button := _make_button("CONTRATAR ATLETAS", false)
	market_button.pressed.connect(func(): _show_page("market"))
	quick.add_child(market_button)

func _build_dream_page() -> void:
	var summary: Dictionary = roster.call("get_roster_summary")
	var card := _card()
	var column := VBoxContainer.new()
	card.add_child(column)
	column.add_child(_label("EFOOTDLS FC", 22, GOLD, true))
	column.add_child(_label("FORÇA DO TIME: %d OVR" % int(summary.get("rating", 0)), 20, TEXT_MAIN, true))
	column.add_child(_label("Formação: %s   •   Condicionamento: %d%%   •   Moral: %d%%" % [str(summary.get("formation", "4-3-3")), int(summary.get("fitness", 0)), int(summary.get("morale", 0))], 14, TEXT_MUTED))
	column.add_child(_label("Construa o elenco no Mercado e ajuste os titulares na página Meu Elenco.", 13, TEXT_MUTED))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	page_body.add_child(buttons)
	var squad_button := _make_button("GERENCIAR ELENCO", true)
	squad_button.pressed.connect(func(): _show_page("squad"))
	buttons.add_child(squad_button)
	var market_button := _make_button("ABRIR MERCADO", false)
	market_button.pressed.connect(func(): _show_page("market"))
	buttons.add_child(market_button)

func _build_squad_page() -> void:
	var formation_card := _card()
	var formation_row := HBoxContainer.new()
	formation_row.add_theme_constant_override("separation", 12)
	formation_card.add_child(formation_row)
	formation_row.add_child(_label("FORMAÇÃO", 14, GOLD, true))
	var formation_select := OptionButton.new()
	formation_select.custom_minimum_size = Vector2(170, 42)
	for formation in FORMATIONS:
		formation_select.add_item(formation)
		if formation == str(roster.call("get_roster_summary").get("formation", "4-3-3")):
			formation_select.select(formation_select.item_count - 1)
	formation_select.item_selected.connect(_on_formation_selected)
	formation_row.add_child(formation_select)
	formation_row.add_child(_label("Titulares: %d  •  Reservas: %d" % [roster.call("get_starting_eleven").size(), roster.call("get_substitutes").size()], 13, TEXT_MUTED))
	var player_card := _card()
	var player_list := VBoxContainer.new()
	player_list.add_theme_constant_override("separation", 6)
	player_card.add_child(player_list)
	player_list.add_child(_label("TIME TITULAR", 15, GOLD, true))
	for athlete in roster.call("get_starting_eleven"):
		var line := HBoxContainer.new()
		line.add_child(_label("%02d  %-22s  %s" % [int(athlete.get("number", 0)), str(athlete.get("name", "Jogador")), str(athlete.get("position", "CM"))], 13, TEXT_MAIN))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(spacer)
		line.add_child(_label("%d OVR" % int(athlete.get("rating", 0)), 14, GOLD, true))
		player_list.add_child(line)
	player_list.add_child(HSeparator.new())
	player_list.add_child(_label("BANCO", 14, GOLD, true))
	for substitute in roster.call("get_substitutes"):
		player_list.add_child(_label("%02d  %s  •  %s  •  %d OVR" % [int(substitute.get("number", 0)), str(substitute.get("name", "Reserva")), str(substitute.get("position", "CM")), int(substitute.get("rating", 0))], 12, TEXT_MUTED))

func _on_formation_selected(index: int) -> void:
	if index < 0 or index >= FORMATIONS.size():
		return
	if roster.call("set_formation", FORMATIONS[index]):
		_save_roster()
		_show_page("squad")

func _build_market_page() -> void:
	var balance := int(profile.call("get_profile").get("coins", 0))
	page_body.add_child(_label("SALDO DISPONÍVEL: %s moedas" % _format_number(balance), 16, GOLD, true))
	var offers: Array = market.call("get_offers")
	if offers.is_empty():
		page_body.add_child(_label("Não há atletas disponíveis neste momento.", 13, TEXT_MUTED))
		var refresh := _make_button("ATUALIZAR OFERTAS", true)
		refresh.pressed.connect(_refresh_market)
		page_body.add_child(refresh)
		return
	for athlete in offers:
		var row := _card()
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		row.add_child(line)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		info.add_child(_label("%s  •  %s  •  %d OVR" % [str(athlete.get("name", "Atleta")), str(athlete.get("position", "CM")), int(athlete.get("rating", 0))], 14, TEXT_MAIN, true))
		info.add_child(_label("Idade %d  •  Potencial %d  •  Salário %s" % [int(athlete.get("age", 0)), int(athlete.get("potential", 0)), _format_number(int(athlete.get("wage", 0)))], 11, TEXT_MUTED))
		var action := _make_button("CONTRATAR • %s" % _format_number(int(athlete.get("value", 0))), true)
		action.custom_minimum_size = Vector2(190, 48)
		var player_id := str(athlete.get("id", ""))
		action.pressed.connect(func(): _buy_player(player_id))
		line.add_child(action)
	var refresh_button := _make_button("RENOVAR OFERTAS", false)
	refresh_button.pressed.connect(_refresh_market)
	page_body.add_child(refresh_button)

func _buy_player(player_id: String) -> void:
	if roster.call("get_substitutes").size() >= 7:
		_set_notice("Banco cheio. Libere uma vaga antes de contratar.")
		return
	market.call("set_balance", int(profile.call("get_profile").get("coins", 0)))
	var offer: Dictionary = {}
	for item in market.call("get_offers"):
		if str(item.get("id", "")) == player_id:
			offer = item
			break
	if offer.is_empty():
		_set_notice("Esta oferta não está mais disponível.")
		return
	var cost := int(offer.get("value", 0))
	if cost > int(profile.call("get_profile").get("coins", 0)):
		_set_notice("Moedas insuficientes para esta contratação.")
		return
	if not bool(market.call("buy_player", player_id)):
		_set_notice("Não foi possível concluir a contratação.")
		return
	if not bool(profile.call("spend_coins", cost)):
		_set_notice("Não foi possível atualizar o saldo do perfil.")
		return
	var owned: Array = market.call("get_owned_players")
	var signed: Dictionary = owned[owned.size() - 1].duplicate(true)
	signed["number"] = 12 + roster.call("get_substitutes").size()
	if not bool(roster.call("add_player_to_bench", signed)):
		_set_notice("Atleta contratado, mas não foi possível adicioná-lo ao banco.")
	else:
		_save_roster()
		_set_notice("%s contratado para o banco!" % str(signed.get("name", "Atleta")))
	market.call("set_balance", int(profile.call("get_profile").get("coins", 0)))
	market.call("save_market")
	_show_page("market")

func _refresh_market() -> void:
	market.call("refresh_market", 8)
	market.call("set_balance", int(profile.call("get_profile").get("coins", 0)))
	_show_page("market")

func _build_events_page() -> void:
	var card := _card()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	column.add_child(_label("COPA RELÂMPAGO", 20, GOLD, true))
	column.add_child(_label("Jogue uma partida completa contra o time adversário. O resultado fica salvo no seu perfil e na carreira.", 13, TEXT_MUTED))
	var play := _make_button("JOGAR DESAFIO", true)
	play.custom_minimum_size = Vector2(220, 54)
	play.pressed.connect(_start_match)
	column.add_child(play)

func _build_settings_page() -> void:
	var card := _card()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	column.add_child(_label("PERFIL", 16, GOLD, true))
	column.add_child(_label("Nome: %s" % str(profile.call("get_profile").get("name", "Jogador")), 14, TEXT_MAIN))
	column.add_child(_label("Progresso salvo localmente no dispositivo.", 12, TEXT_MUTED))
	var save_button := _make_button("SALVAR PERFIL", false)
	save_button.pressed.connect(func(): profile.call("save_profile"); _set_notice("Perfil salvo com sucesso."))
	column.add_child(save_button)
	var reset_hint := _label("Os dados de carreira e moedas permanecem no aparelho. Evite limpar os dados do aplicativo para não perder o progresso.", 11, TEXT_MUTED)
	reset_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(reset_hint)

func _start_match() -> void:
	profile.call("save_profile")
	_save_roster()
	var result := get_tree().change_scene_to_file(MATCH_SCENE)
	if result != OK:
		_set_notice("Não foi possível abrir a partida. Verifique scenes/match.tscn.")

func _load_roster() -> void:
	var config := ConfigFile.new()
	if config.load("user://efootdls_roster.cfg") == OK:
		roster.call("load_from_config", config)

func _save_roster() -> void:
	var config := ConfigFile.new()
	roster.call("save_to_config", config)
	config.save("user://efootdls_roster.cfg")

func _refresh_wallet() -> void:
	if is_instance_valid(wallet_label):
		wallet_label.text = "%s moedas    •    NÍVEL %d" % [_format_number(int(profile.call("get_profile").get("coins", 0))), int(profile.call("get_profile").get("level", 1))]

func _set_notice(message: String) -> void:
	if is_instance_valid(notice_label):
		notice_label.text = message
	_refresh_wallet()

func _format_number(value: int) -> String:
	return str(value)

func _add_stat_card(parent: HBoxContainer, caption: String, value: String) -> void:
	var card := _card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_child(_label(caption, 10, TEXT_MUTED, true))
	column.add_child(_label(value, 24, GOLD, true))
	card.add_child(column)
	parent.add_child(card)

func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	_style_panel(panel, Color(0.025, 0.065, 0.105, 0.94))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return panel

func _label(value: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _make_button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.025, 0.055, 0.085) if primary else TEXT_MAIN)
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD if primary else Color(0.055, 0.12, 0.19, 0.98)
	normal.border_color = Color(1.0, 0.84, 0.55, 0.82) if primary else Color(0.23, 0.39, 0.56, 0.82)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(9)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", normal)
	return button

func _style_panel(panel: PanelContainer, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.20, 0.37, 0.53, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
