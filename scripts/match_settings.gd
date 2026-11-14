extends RefCounted
## Configurações da partida com validação e valores padrão seguros.

const DEFAULTS := {
	"match_length": 180,
	"difficulty": "normal",
	"camera_mode": "broadcast",
	"camera_distance": 12.5,
	"player_speed": 7.0,
	"sprint_speed": 11.5,
	"shot_power": 13.5,
	"ai_speed": 5.0,
	"ai_pressure": 1.0,
	"show_names": true,
	"show_minimap": false,
	"vibration": true,
	"auto_switch": true
}

var values: Dictionary = DEFAULTS.duplicate(true)

func reset() -> void:
	values = DEFAULTS.duplicate(true)

func set_value(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	values[key] = value
	_validate()
	return true

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func get_all() -> Dictionary:
	return values.duplicate(true)

func load_from_config(config: ConfigFile, section := "match") -> void:
	for key in DEFAULTS.keys():
		values[key] = config.get_value(section, key, DEFAULTS[key])
	_validate()

func save_to_config(config: ConfigFile, section := "match") -> void:
	for key in DEFAULTS.keys():
		config.set_value(section, key, values.get(key, DEFAULTS[key]))

func _validate() -> void:
	values["match_length"] = clampi(int(values["match_length"]), 60, 900)
	values["camera_distance"] = clampf(float(values["camera_distance"]), 8.0, 20.0)
	values["player_speed"] = clampf(float(values["player_speed"]), 3.0, 12.0)
	values["sprint_speed"] = clampf(float(values["sprint_speed"]), 4.0, 16.0)
	values["shot_power"] = clampf(float(values["shot_power"]), 6.0, 25.0)
	values["ai_speed"] = clampf(float(values["ai_speed"]), 2.5, 9.0)
	values["ai_pressure"] = clampf(float(values["ai_pressure"]), 0.3, 2.0)
	if values["difficulty"] not in ["easy", "normal", "hard"]:
		values["difficulty"] = "normal"
	if values["camera_mode"] not in ["broadcast", "close", "wide"]:
		values["camera_mode"] = "broadcast"

func apply_difficulty() -> void:
	match values["difficulty"]:
		"easy":
			values["ai_speed"] = 3.8
			values["ai_pressure"] = 0.7
		"normal":
			values["ai_speed"] = 5.0
			values["ai_pressure"] = 1.0
		"hard":
			values["ai_speed"] = 6.2
			values["ai_pressure"] = 1.35

func get_difficulty_label() -> String:
	match values["difficulty"]:
		"easy":
			return "FÁCIL"
		"hard":
			return "DIFÍCIL"
	return "NORMAL"

func validate_settings(candidate: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	for key in candidate.keys():
		if DEFAULTS.has(key):
			result[key] = candidate[key]
	values = result
	_validate()
	return get_all()
