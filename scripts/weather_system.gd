extends Node
## Condições climáticas da partida e ajustes leves de ambiente e física.

signal weather_changed(weather_id: String, display_name: String)

enum Weather { CLEAR, CLOUDY, RAIN, NIGHT, FOG }

const WEATHER_NAMES := {
	Weather.CLEAR: "CÉU LIMPO",
	Weather.CLOUDY: "NUBLADO",
	Weather.RAIN: "CHUVA",
	Weather.NIGHT: "NOITE",
	Weather.FOG: "NEBLINA"
}

var current_weather := Weather.CLEAR
var environment_node: WorldEnvironment
var directional_light: DirectionalLight3D
var ball_body: RigidBody3D
var original_ball_damp := 0.7
var original_light_energy := 1.15
var weather_seed := 0
var transition_time := 0.0
var target_light_energy := 1.15
var target_ambient := Color(0.62, 0.70, 0.82)
var enabled := true

func configure(world_environment: WorldEnvironment, sun: DirectionalLight3D, ball: RigidBody3D) -> void:
	environment_node = world_environment
	directional_light = sun
	ball_body = ball
	if is_instance_valid(ball_body):
		original_ball_damp = ball_body.linear_damp
	if is_instance_valid(directional_light):
		original_light_energy = directional_light.light_energy

func set_weather(value: int) -> void:
	if value < Weather.CLEAR or value > Weather.FOG:
		return
	current_weather = value
	_apply_weather()
	weather_changed.emit(str(WEATHER_NAMES[current_weather]).to_lower(), str(WEATHER_NAMES[current_weather]))

func set_weather_by_name(value: String) -> bool:
	match value.to_lower():
		"clear", "limpo":
			set_weather(Weather.CLEAR)
		"cloudy", "nublado":
			set_weather(Weather.CLOUDY)
		"rain", "chuva":
			set_weather(Weather.RAIN)
		"night", "noite":
			set_weather(Weather.NIGHT)
		"fog", "neblina":
			set_weather(Weather.FOG)
		_:
			return false
	return true

func _apply_weather() -> void:
	if not is_instance_valid(environment_node) or environment_node.environment == null:
		return
	var environment := environment_node.environment
	match current_weather:
		Weather.CLEAR:
			target_light_energy = original_light_energy
			target_ambient = Color(0.62, 0.70, 0.82)
			environment.fog_enabled = false
		Weather.CLOUDY:
			target_light_energy = original_light_energy * 0.72
			target_ambient = Color(0.42, 0.48, 0.58)
			environment.fog_enabled = false
		Weather.RAIN:
			target_light_energy = original_light_energy * 0.62
			target_ambient = Color(0.32, 0.40, 0.52)
			environment.fog_enabled = true
			environment.fog_density = 0.006
		Weather.NIGHT:
			target_light_energy = 0.32
			target_ambient = Color(0.16, 0.20, 0.32)
			environment.fog_enabled = false
		Weather.FOG:
			target_light_energy = original_light_energy * 0.55
			target_ambient = Color(0.48, 0.53, 0.62)
			environment.fog_enabled = true
			environment.fog_density = 0.018
	transition_time = 1.0

func _process(delta: float) -> void:
	if not enabled or transition_time <= 0.0:
		return
	transition_time = maxf(0.0, transition_time - delta)
	if is_instance_valid(directional_light):
		directional_light.light_energy = move_toward(directional_light.light_energy, target_light_energy, delta * 1.5)
	if is_instance_valid(environment_node) and environment_node.environment:
		environment_node.environment.ambient_light_color = environment_node.environment.ambient_light_color.lerp(target_ambient, minf(1.0, delta * 1.5))
	if is_instance_valid(ball_body):
		var target_damp := original_ball_damp * 1.25 if current_weather == Weather.RAIN else original_ball_damp
		ball_body.linear_damp = move_toward(ball_body.linear_damp, target_damp, delta * 0.5)

func get_weather_name() -> String:
	return str(WEATHER_NAMES[current_weather])

func get_weather_id() -> String:
	match current_weather:
		Weather.CLEAR:
			return "clear"
		Weather.CLOUDY:
			return "cloudy"
		Weather.RAIN:
			return "rain"
		Weather.NIGHT:
			return "night"
		Weather.FOG:
			return "fog"
	return "clear"

func set_enabled(value: bool) -> void:
	enabled = value

func reset_weather() -> void:
	set_weather(Weather.CLEAR)
