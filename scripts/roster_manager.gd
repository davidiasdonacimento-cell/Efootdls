extends RefCounted
## Escalação, banco, capitão, formação e cálculo geral do elenco.

const FormationCatalog = preload("res://scripts/formation_catalog.gd")

var starting_eleven: Array[Dictionary] = []
var substitutes: Array[Dictionary] = []
var formation_code := "4-3-3"
var captain_number := 10
var chemistry := 70
var team_name := "Efootdls FC"
var team_color := Color(0.08, 0.34, 0.88)

func _init() -> void:
	load_default_roster()

func load_default_roster() -> void:
	var defaults := FormationCatalog.get_default_roster()
	starting_eleven.clear()
	substitutes.clear()
	for player in defaults:
		starting_eleven.append(player.duplicate(true))
	for index in range(5):
		substitutes.append({
			"number": 12 + index,
			"position": ["GK", "CB", "CM", "RW", "ST"][index],
			"name": "Reserva %d" % (index + 1),
			"rating": 67 + index,
			"fitness": 100,
			"morale": 70
		})
	_validate_lineup()

func set_team_name(value: String) -> void:
	var cleaned := value.strip_edges().substr(0, 24)
	if not cleaned.is_empty():
		team_name = cleaned

func set_formation(value: String) -> bool:
	if not FormationCatalog.FORMATIONS.has(value):
		return false
	formation_code = value
	return true

func set_captain(number: int) -> bool:
	for player in starting_eleven:
		if int(player.get("number", -1)) == number:
			captain_number = number
			return true
	return false

func substitute_player(starting_number: int, substitute_number: int) -> bool:
	var starting_index := _find_player_index(starting_eleven, starting_number)
	var substitute_index := _find_player_index(substitutes, substitute_number)
	if starting_index < 0 or substitute_index < 0:
		return false
	var outgoing := starting_eleven[starting_index]
	var incoming := substitutes[substitute_index]
	if not _positions_compatible(str(outgoing["position"]), str(incoming["position"])):
		return false
	starting_eleven[starting_index] = incoming
	substitutes[substitute_index] = outgoing
	_validate_lineup()
	return true

func _positions_compatible(first: String, second: String) -> bool:
	if first == second:
		return true
	var groups := [
		["CB", "LB", "RB", "LWB", "RWB"],
		["CM", "CDM", "CAM", "LM", "RM"],
		["ST", "CF", "LW", "RW"]
	]
	for group in groups:
		if first in group and second in group:
			return true
	return false

func _find_player_index(roster: Array[Dictionary], number: int) -> int:
	for index in range(roster.size()):
		if int(roster[index].get("number", -1)) == number:
			return index
	return -1

func _validate_lineup() -> void:
	if starting_eleven.size() > 11:
		starting_eleven.resize(11)
	if substitutes.size() > 7:
		substitutes.resize(7)
	for player in starting_eleven:
		player["rating"] = clampi(int(player.get("rating", 50)), 1, 99)
		player["fitness"] = clampi(int(player.get("fitness", 100)), 0, 100)
		player["morale"] = clampi(int(player.get("morale", 70)), 0, 100)

func get_team_rating() -> int:
	return FormationCatalog.calculate_team_rating(starting_eleven)

func get_average_fitness() -> int:
	if starting_eleven.is_empty():
		return 0
	var sum := 0
	for player in starting_eleven:
		sum += int(player.get("fitness", 100))
	return roundi(float(sum) / starting_eleven.size())

func get_average_morale() -> int:
	if starting_eleven.is_empty():
		return 0
	var sum := 0
	for player in starting_eleven:
		sum += int(player.get("morale", 70))
	return roundi(float(sum) / starting_eleven.size())

func apply_match_fatigue(minutes_played: int) -> void:
	var fatigue := clampi(roundi(float(minutes_played) * 0.28), 1, 45)
	for player in starting_eleven:
		player["fitness"] = maxi(0, int(player.get("fitness", 100)) - fatigue)
	_update_morale(1)

func recover_squad(amount: int) -> void:
	for player in starting_eleven + substitutes:
		player["fitness"] = mini(100, int(player.get("fitness", 100)) + maxi(0, amount))

func _update_morale(change: int) -> void:
	for player in starting_eleven:
		player["morale"] = clampi(int(player.get("morale", 70)) + change, 0, 100)

func get_starting_eleven() -> Array[Dictionary]:
	return starting_eleven.duplicate(true)

func get_substitutes() -> Array[Dictionary]:
	return substitutes.duplicate(true)

func get_formation_positions() -> Array[Vector3]:
	return FormationCatalog.get_positions(formation_code)

func get_roster_summary() -> Dictionary:
	return {
		"team_name": team_name,
		"formation": formation_code,
		"rating": get_team_rating(),
		"fitness": get_average_fitness(),
		"morale": get_average_morale(),
		"captain": captain_number,
		"players": starting_eleven.size(),
		"substitutes": substitutes.size()
	}

func save_to_config(config: ConfigFile) -> void:
	config.set_value("roster", "team_name", team_name)
	config.set_value("roster", "formation", formation_code)
	config.set_value("roster", "captain", captain_number)
	config.set_value("roster", "starting_eleven", starting_eleven)
	config.set_value("roster", "substitutes", substitutes)

func load_from_config(config: ConfigFile) -> void:
	team_name = str(config.get_value("roster", "team_name", team_name))
	formation_code = str(config.get_value("roster", "formation", formation_code))
	captain_number = int(config.get_value("roster", "captain", captain_number))
	var loaded_starting: Variant = config.get_value("roster", "starting_eleven", [])
	var loaded_substitutes: Variant = config.get_value("roster", "substitutes", [])
	if loaded_starting is Array and loaded_starting.size() >= 11:
		starting_eleven.clear()
		for player in loaded_starting:
			if player is Dictionary:
				starting_eleven.append(player.duplicate(true))
	if loaded_substitutes is Array:
		substitutes.clear()
		for player in loaded_substitutes:
			if player is Dictionary:
				substitutes.append(player.duplicate(true))
	_validate_lineup()

func reset_team() -> void:
	formation_code = "4-3-3"
	captain_number = 10
	team_name = "Efootdls FC"
	load_default_roster()
