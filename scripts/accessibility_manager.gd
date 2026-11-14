extends RefCounted
## Preferências de acessibilidade para interface, controles e conforto visual.

const SAVE_PATH := "user://efootdls_accessibility.cfg"
const DEFAULTS := {
	"ui_scale": 1.0,
	"large_text": false,
	"high_contrast": false,
	"color_profile": "normal",
	"reduced_motion": false,
	"screen_shake": true,
	"joystick_scale": 1.0,
	"button_scale": 1.0,
	"joystick_opacity": 0.72,
	"left_handed": false,
	"hold_to_sprint": true,
	"tap_to_shoot": true,
	"subtitles": true,
	"menu_sound": true
}

var options: Dictionary = DEFAULTS.duplicate(true)
var key_bindings: Dictionary = {
	"move_up": "W",
	"move_down": "S",
	"move_left": "A",
	"move_right": "D",
	"sprint": "SHIFT",
	"shoot": "SPACE",
	"pass": "E",
	"tackle": "Q"
}

func reset() -> void:
	options = DEFAULTS.duplicate(true)
	key_bindings = {
		"move_up": "W",
		"move_down": "S",
		"move_left": "A",
		"move_right": "D",
		"sprint": "SHIFT",
		"shoot": "SPACE",
		"pass": "E",
		"tackle": "Q"
	}

func set_option(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	options[key] = value
	_validate_options()
	return true

func get_option(key: String) -> Variant:
	return options.get(key, DEFAULTS.get(key))

func set_key_binding(action: String, key_name: String) -> bool:
	if not key_bindings.has(action):
		return false
	var cleaned := key_name.strip_edges().to_upper()
	if cleaned.is_empty() or cleaned.length() > 12:
		return false
	key_bindings[action] = cleaned
	return true

func get_key_binding(action: String) -> String:
	return str(key_bindings.get(action, ""))

func _validate_options() -> void:
	options["ui_scale"] = clampf(float(options["ui_scale"]), 0.8, 1.5)
	options["joystick_scale"] = clampf(float(options["joystick_scale"]), 0.75, 1.5)
	options["button_scale"] = clampf(float(options["button_scale"]), 0.75, 1.5)
	options["joystick_opacity"] = clampf(float(options["joystick_opacity"]), 0.25, 1.0)
	if options["color_profile"] not in ["normal", "deuteranopia", "protanopia", "tritanopia"]:
		options["color_profile"] = "normal"

func apply_interface(root: Control) -> void:
	if not is_instance_valid(root):
		return
	_validate_options()
	root.scale = Vector2.ONE * float(options["ui_scale"])
	root.modulate = Color.WHITE
	if bool(options["high_contrast"]):
		root.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_apply_to_children(root)

func _apply_to_children(parent: Node) -> void:
	for child in parent.get_children():
		if child is Control:
			var control := child as Control
			if control is Button:
				control.scale = Vector2.ONE * float(options["button_scale"])
			if control is Label and bool(options["large_text"]):
				var current_size := int(control.get_theme_font_size("font_size"))
				if current_size <= 0:
					current_size = 14
				control.add_theme_font_size_override("font_size", roundi(float(current_size) * 1.25))
			if control.name.to_lower().contains("joystick"):
				control.modulate.a = float(options["joystick_opacity"])
		_apply_to_children(child)

func get_color_for_team(team_id: int) -> Color:
	var profile := str(options["color_profile"])
	if profile == "deuteranopia" or profile == "protanopia":
		return Color(0.95, 0.72, 0.12) if team_id == 1 else Color(0.10, 0.55, 0.95)
	if profile == "tritanopia":
		return Color(0.15, 0.72, 0.34) if team_id == 1 else Color(0.88, 0.30, 0.18)
	return Color(0.08, 0.34, 0.88) if team_id == 1 else Color(0.78, 0.12, 0.15)

func should_reduce_motion() -> bool:
	return bool(options["reduced_motion"])

func should_shake_camera() -> bool:
	return bool(options["screen_shake"]) and not should_reduce_motion()

func should_show_subtitles() -> bool:
	return bool(options["subtitles"])

func get_all_options() -> Dictionary:
	return options.duplicate(true)

func save_options() -> bool:
	var config := ConfigFile.new()
	config.set_value("accessibility", "options", options)
	config.set_value("accessibility", "bindings", key_bindings)
	return config.save(SAVE_PATH) == OK

func load_options() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	var loaded_options: Variant = config.get_value("accessibility", "options", DEFAULTS)
	var loaded_bindings: Variant = config.get_value("accessibility", "bindings", key_bindings)
	if loaded_options is Dictionary:
		for key in DEFAULTS.keys():
			options[key] = loaded_options.get(key, DEFAULTS[key])
	if loaded_bindings is Dictionary:
		for key in key_bindings.keys():
			key_bindings[key] = str(loaded_bindings.get(key, key_bindings[key]))
	_validate_options()
	return true
