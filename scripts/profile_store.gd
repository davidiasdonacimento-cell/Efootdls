extends Node
## Perfil local persistente. Os dados ficam no armazenamento user:// do Godot.

signal profile_changed(profile: Dictionary)
signal save_completed(success: bool)

const SAVE_PATH := "user://efootdls_profile.cfg"
const PROFILE_SECTION := "profile"
const CAREER_SECTION := "career"
const SETTINGS_SECTION := "settings"

var profile := {
	"name": "Jogador",
	"coins": 12000000,
	"gems": 500000,
	"experience": 0,
	"level": 1,
	"matches": 0,
	"wins": 0,
	"draws": 0,
	"losses": 0,
	"goals": 0,
	"assists": 0,
	"best_streak": 0,
	"current_streak": 0
}

var career := {
	"season": 1,
	"week": 1,
	"league_points": 0,
	"league_position": 10,
	"last_opponent": "",
	"last_result": ""
}

var settings := {
	"music_enabled": true,
	"sfx_enabled": true,
	"camera_shake": true,
	"vibration": true,
	"quality": "balanced",
	"joystick_size": 1.0,
	"camera_distance": 1.0
}

var is_loaded := false
var dirty := false

func _ready() -> void:
	load_profile()

func load_profile() -> bool:
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		is_loaded = true
		dirty = true
		save_profile()
		return false
	for key in profile.keys():
		profile[key] = config.get_value(PROFILE_SECTION, key, profile[key])
	for key in career.keys():
		career[key] = config.get_value(CAREER_SECTION, key, career[key])
	for key in settings.keys():
		settings[key] = config.get_value(SETTINGS_SECTION, key, settings[key])
	_validate_profile()
	is_loaded = true
	dirty = false
	profile_changed.emit(get_profile())
	return true

func save_profile() -> bool:
	var config := ConfigFile.new()
	for key in profile.keys():
		config.set_value(PROFILE_SECTION, key, profile[key])
	for key in career.keys():
		config.set_value(CAREER_SECTION, key, career[key])
	for key in settings.keys():
		config.set_value(SETTINGS_SECTION, key, settings[key])
	var error := config.save(SAVE_PATH)
	var success := error == OK
	if success:
		dirty = false
	save_completed.emit(success)
	return success

func _validate_profile() -> void:
	profile["coins"] = maxi(0, int(profile["coins"]))
	profile["gems"] = maxi(0, int(profile["gems"]))
	profile["experience"] = maxi(0, int(profile["experience"]))
	profile["level"] = maxi(1, int(profile["level"]))
	profile["matches"] = maxi(0, int(profile["matches"]))
	profile["wins"] = maxi(0, int(profile["wins"]))
	profile["draws"] = maxi(0, int(profile["draws"]))
	profile["losses"] = maxi(0, int(profile["losses"]))
	profile["goals"] = maxi(0, int(profile["goals"]))
	profile["assists"] = maxi(0, int(profile["assists"]))

func get_profile() -> Dictionary:
	return profile.duplicate(true)

func get_career() -> Dictionary:
	return career.duplicate(true)

func get_settings() -> Dictionary:
	return settings.duplicate(true)

func set_player_name(value: String) -> void:
	var cleaned := value.strip_edges().substr(0, 18)
	if cleaned.is_empty():
		return
	profile["name"] = cleaned
	_mark_changed()

func add_coins(amount: int) -> void:
	profile["coins"] = maxi(0, int(profile["coins"]) + amount)
	_mark_changed()

func spend_coins(amount: int) -> bool:
	if amount <= 0 or int(profile["coins"]) < amount:
		return false
	profile["coins"] = int(profile["coins"]) - amount
	_mark_changed()
	return true

func add_gems(amount: int) -> void:
	profile["gems"] = maxi(0, int(profile["gems"]) + amount)
	_mark_changed()

func add_experience(amount: int) -> int:
	profile["experience"] = maxi(0, int(profile["experience"]) + amount)
	var levels_gained := 0
	while int(profile["experience"]) >= _experience_for_next_level():
		profile["experience"] = int(profile["experience"]) - _experience_for_next_level()
		profile["level"] = int(profile["level"]) + 1
		profile["coins"] = int(profile["coins"]) + 250
		levels_gained += 1
	_mark_changed()
	return levels_gained

func _experience_for_next_level() -> int:
	return 500 + int(profile["level"]) * 150

func record_match_result(result: String, goals: int, conceded: int) -> void:
	profile["matches"] = int(profile["matches"]) + 1
	profile["goals"] = int(profile["goals"]) + maxi(0, goals)
	if result == "win":
		profile["wins"] = int(profile["wins"]) + 1
		profile["current_streak"] = int(profile["current_streak"]) + 1
		profile["best_streak"] = maxi(int(profile["best_streak"]), int(profile["current_streak"]))
		add_coins(350 + goals * 40)
		add_experience(180 + goals * 25)
	elif result == "draw":
		profile["draws"] = int(profile["draws"]) + 1
		profile["current_streak"] = 0
		add_coins(120)
		add_experience(90)
	else:
		profile["losses"] = int(profile["losses"]) + 1
		profile["current_streak"] = 0
		add_coins(60)
		add_experience(60)
	career["last_result"] = result
	career["week"] = int(career["week"]) + 1
	career["league_points"] = int(career["league_points"]) + (3 if result == "win" else (1 if result == "draw" else 0))
	_mark_changed()
	save_profile()

func update_setting(key: String, value: Variant) -> bool:
	if not settings.has(key):
		return false
	settings[key] = value
	_mark_changed()
	return true

func _mark_changed() -> void:
	dirty = true
	profile_changed.emit(get_profile())

func reset_profile() -> void:
	profile = {
		"name": "Jogador",
		"coins": 1200,
		"gems": 50,
		"experience": 0,
		"level": 1,
		"matches": 0,
		"wins": 0,
		"draws": 0,
		"losses": 0,
		"goals": 0,
		"assists": 0,
		"best_streak": 0,
		"current_streak": 0
	}
	career = {
		"season": 1,
		"week": 1,
		"league_points": 0,
		"league_position": 10,
		"last_opponent": "",
		"last_result": ""
	}
	_mark_changed()
	save_profile()

func get_win_rate() -> float:
	var total := int(profile["matches"])
	if total <= 0:
		return 0.0
	return float(profile["wins"]) / float(total) * 100.0

func get_next_level_progress() -> float:
	var required := float(_experience_for_next_level())
	return clampf(float(profile["experience"]) / required, 0.0, 1.0)
