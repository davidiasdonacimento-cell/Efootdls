extends Control
## Minimapa 2D com posições relativas do atleta, bola, companheiros e adversários.

var player_target: Node3D
var ball_target: Node3D
var allies: Array[Node3D] = []
var opponents: Array[Node3D] = []
var field_width := 42.0
var field_length := 64.0
var background_color := Color(0.015, 0.08, 0.045, 0.82)
var line_color := Color(0.85, 0.92, 0.86, 0.8)
var ally_color := Color(0.20, 0.66, 1.0)
var opponent_color := Color(1.0, 0.24, 0.24)
var ball_color := Color(1.0, 0.86, 0.20)
var player_color := Color(1.0, 1.0, 1.0)
var refresh_timer := 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(160, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func configure(player: Node3D, ball: Node3D, team_mates: Array[CharacterBody3D], rivals: Array[CharacterBody3D]) -> void:
	player_target = player
	ball_target = ball
	allies.clear()
	opponents.clear()
	for athlete in team_mates:
		allies.append(athlete)
	for rival in rivals:
		opponents.append(rival)
	queue_redraw()

func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer <= 0.0:
		refresh_timer = 0.08
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, background_color, true)
	var field_rect := Rect2(Vector2(8, 6), Vector2(maxf(1.0, size.x - 16), maxf(1.0, size.y - 12)))
	draw_rect(field_rect, Color(0.035, 0.20, 0.09, 0.95), true)
	draw_rect(field_rect, line_color, false, 1.2)
	var center_y := field_rect.position.y + field_rect.size.y * 0.5
	draw_line(Vector2(field_rect.position.x, center_y), Vector2(field_rect.end.x, center_y), line_color, 1.0)
	draw_arc(field_rect.get_center(), minf(field_rect.size.x, field_rect.size.y) * 0.16, 0.0, TAU, 32, line_color, 1.0)
	var box_width := field_rect.size.x * 0.42
	var box_height := field_rect.size.y * 0.13
	draw_rect(Rect2(Vector2(field_rect.position.x + (field_rect.size.x - box_width) * 0.5, field_rect.position.y), Vector2(box_width, box_height)), line_color, false, 1.0)
	draw_rect(Rect2(Vector2(field_rect.position.x + (field_rect.size.x - box_width) * 0.5, field_rect.end.y - box_height), Vector2(box_width, box_height)), line_color, false, 1.0)
	_draw_entities(field_rect)
	draw_rect(rect, Color(0.6, 0.8, 0.7, 0.65), false, 1.0)

func _draw_entities(field_rect: Rect2) -> void:
	for athlete in allies:
		if is_instance_valid(athlete) and athlete != player_target:
			draw_circle(_world_to_map(athlete.global_position, field_rect), 3.0, ally_color)
	for rival in opponents:
		if is_instance_valid(rival):
			draw_circle(_world_to_map(rival.global_position, field_rect), 3.0, opponent_color)
	if is_instance_valid(player_target):
		var point := _world_to_map(player_target.global_position, field_rect)
		draw_circle(point, 4.5, player_color)
		draw_arc(point, 6.5, 0.0, TAU, 20, player_color, 1.1)
	if is_instance_valid(ball_target):
		var ball_point := _world_to_map(ball_target.global_position, field_rect)
		draw_circle(ball_point, 3.2, ball_color)

func _world_to_map(world_position: Vector3, field_rect: Rect2) -> Vector2:
	var horizontal_ratio := clampf((world_position.x + field_width * 0.5) / field_width, 0.0, 1.0)
	var vertical_ratio := clampf((world_position.z + field_length * 0.5) / field_length, 0.0, 1.0)
	return Vector2(
		field_rect.position.x + horizontal_ratio * field_rect.size.x,
		field_rect.position.y + vertical_ratio * field_rect.size.y
	)

func set_field_size(width_value: float, length_value: float) -> void:
	field_width = maxf(width_value, 1.0)
	field_length = maxf(length_value, 1.0)
	queue_redraw()

func set_palette(field: Color, lines: Color, home: Color, away: Color) -> void:
	background_color = field
	line_color = lines
	ally_color = home
	opponent_color = away
	queue_redraw()

func set_visible_map(value: bool) -> void:
	visible = value
