extends Node
## Campeonato local com calendário simples, tabela e histórico de resultados.

signal table_updated(table: Array)
signal fixture_completed(result: Dictionary)
signal season_completed(champion: String)

const SAVE_PATH := "user://efootdls_career.cfg"
const CLUBS := [
	"Efootdls FC", "Bahia Azul", "Rio United", "Atlético Central",
	"Porto Verde", "Estrela do Norte", "Real Litoral", "Capital FC"
]

var clubs: Array[String] = []
var table: Array[Dictionary] = []
var fixtures: Array[Dictionary] = []
var history: Array[Dictionary] = []
var current_round := 1
var season_number := 1
var user_club := "Efootdls FC"
var points_per_win := 3
var season_finished := false

func _ready() -> void:
	load_career()

func start_new_season() -> void:
	season_number += 1
	current_round = 1
	season_finished = false
	clubs.clear()
	for club in CLUBS:
		clubs.append(club)
	_reset_table()
	_generate_fixtures()
	save_career()

func _reset_table() -> void:
	table.clear()
	for club in clubs:
		table.append({
			"club": club,
			"played": 0,
			"won": 0,
			"drawn": 0,
			"lost": 0,
			"goals_for": 0,
			"goals_against": 0,
			"goal_difference": 0,
			"points": 0
		})
	_sort_table()

func _generate_fixtures() -> void:
	fixtures.clear()
	var participants := clubs.duplicate()
	var rounds := participants.size() - 1
	var half := int(participants.size() / 2)
	for round_index in range(rounds):
		for match_index in range(half):
			var home := participants[match_index]
			var away := participants[participants.size() - 1 - match_index]
			if round_index % 2 == 1:
				var swap := home
				home = away
				away = swap
			fixtures.append({
				"round": round_index + 1,
				"home": home,
				"away": away,
				"played": false,
				"home_score": 0,
				"away_score": 0
			})
		var last_participant: String = participants.pop_back()
		participants.insert(1, last_participant)
	var first_leg := fixtures.duplicate(true)
	for fixture in first_leg:
		fixtures.append({
			"round": int(fixture["round"]) + rounds,
			"home": fixture["away"],
			"away": fixture["home"],
			"played": false,
			"home_score": 0,
			"away_score": 0
		})

func record_fixture(home: String, away: String, home_goals: int, away_goals: int) -> bool:
	if season_finished:
		return false
	var fixture_index := _find_fixture(home, away)
	if fixture_index < 0:
		return false
	var fixture: Dictionary = fixtures[fixture_index]
	if bool(fixture["played"]):
		return false
	fixture["played"] = true
	fixture["home_score"] = maxi(0, home_goals)
	fixture["away_score"] = maxi(0, away_goals)
	fixtures[fixture_index] = fixture
	_apply_result(home, away, home_goals, away_goals)
	history.append(fixture.duplicate(true))
	current_round = _calculate_next_round()
	_sort_table()
	fixture_completed.emit(fixture.duplicate(true))
	table_updated.emit(get_table())
	if current_round > clubs.size() * 2 - 2:
		_finish_season()
	save_career()
	return true

func _find_fixture(home: String, away: String) -> int:
	for index in range(fixtures.size()):
		if str(fixtures[index]["home"]) == home and str(fixtures[index]["away"]) == away:
			return index
	return -1

func _apply_result(home: String, away: String, home_goals: int, away_goals: int) -> void:
	var home_row := _find_table_row(home)
	var away_row := _find_table_row(away)
	if home_row < 0 or away_row < 0:
		return
	var home_stats: Dictionary = table[home_row]
	var away_stats: Dictionary = table[away_row]
	home_stats["played"] = int(home_stats["played"]) + 1
	away_stats["played"] = int(away_stats["played"]) + 1
	home_stats["goals_for"] = int(home_stats["goals_for"]) + home_goals
	home_stats["goals_against"] = int(home_stats["goals_against"]) + away_goals
	away_stats["goals_for"] = int(away_stats["goals_for"]) + away_goals
	away_stats["goals_against"] = int(away_stats["goals_against"]) + home_goals
	if home_goals > away_goals:
		home_stats["won"] = int(home_stats["won"]) + 1
		away_stats["lost"] = int(away_stats["lost"]) + 1
		home_stats["points"] = int(home_stats["points"]) + points_per_win
	elif away_goals > home_goals:
		away_stats["won"] = int(away_stats["won"]) + 1
		home_stats["lost"] = int(home_stats["lost"]) + 1
		away_stats["points"] = int(away_stats["points"]) + points_per_win
	else:
		home_stats["drawn"] = int(home_stats["drawn"]) + 1
		away_stats["drawn"] = int(away_stats["drawn"]) + 1
		home_stats["points"] = int(home_stats["points"]) + 1
		away_stats["points"] = int(away_stats["points"]) + 1
	home_stats["goal_difference"] = int(home_stats["goals_for"]) - int(home_stats["goals_against"])
	away_stats["goal_difference"] = int(away_stats["goals_for"]) - int(away_stats["goals_against"])
	table[home_row] = home_stats
	table[away_row] = away_stats

func _find_table_row(club: String) -> int:
	for index in range(table.size()):
		if str(table[index]["club"]) == club:
			return index
	return -1

func _sort_table() -> void:
	table.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["points"]) != int(b["points"]):
			return int(a["points"]) > int(b["points"])
		if int(a["goal_difference"]) != int(b["goal_difference"]):
			return int(a["goal_difference"]) > int(b["goal_difference"])
		return int(a["goals_for"]) > int(b["goals_for"])
	)

func _calculate_next_round() -> int:
	var next_value := 1
	for fixture in fixtures:
		if not bool(fixture["played"]):
			next_value = int(fixture["round"])
			break
	return next_value

func _finish_season() -> void:
	season_finished = true
	var champion := str(table[0]["club"]) if not table.is_empty() else ""
	season_completed.emit(champion)

func get_table() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for row in table:
		copy.append(row.duplicate(true))
	return copy

func get_current_fixtures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fixture in fixtures:
		if int(fixture["round"]) == current_round:
			result.append(fixture.duplicate(true))
	return result

func get_next_user_fixture() -> Dictionary:
	for fixture in fixtures:
		if not bool(fixture["played"]) and (str(fixture["home"]) == user_club or str(fixture["away"]) == user_club):
			return fixture.duplicate(true)
	return {}

func get_user_position() -> int:
	for index in range(table.size()):
		if str(table[index]["club"]) == user_club:
			return index + 1
	return 0

func save_career() -> bool:
	var config := ConfigFile.new()
	config.set_value("career", "clubs", clubs)
	config.set_value("career", "table", table)
	config.set_value("career", "fixtures", fixtures)
	config.set_value("career", "history", history)
	config.set_value("career", "round", current_round)
	config.set_value("career", "season", season_number)
	config.set_value("career", "user_club", user_club)
	config.set_value("career", "finished", season_finished)
	return config.save(SAVE_PATH) == OK

func load_career() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		clubs = CLUBS.duplicate()
		_reset_table()
		_generate_fixtures()
		return false
	clubs.clear()
	var loaded_clubs: Variant = config.get_value("career", "clubs", CLUBS)
	if loaded_clubs is Array:
		for club in loaded_clubs:
			clubs.append(str(club))
	table.clear()
	var loaded_table: Variant = config.get_value("career", "table", [])
	if loaded_table is Array:
		for row in loaded_table:
			if row is Dictionary:
				table.append(row.duplicate(true))
	fixtures.clear()
	var loaded_fixtures: Variant = config.get_value("career", "fixtures", [])
	if loaded_fixtures is Array:
		for fixture in loaded_fixtures:
			if fixture is Dictionary:
				fixtures.append(fixture.duplicate(true))
	history.clear()
	var loaded_history: Variant = config.get_value("career", "history", [])
	if loaded_history is Array:
		for item in loaded_history:
			if item is Dictionary:
				history.append(item.duplicate(true))
	current_round = int(config.get_value("career", "round", 1))
	season_number = int(config.get_value("career", "season", 1))
	user_club = str(config.get_value("career", "user_club", "Efootdls FC"))
	season_finished = bool(config.get_value("career", "finished", false))
	if table.is_empty():
		_reset_table()
	if fixtures.is_empty():
		_generate_fixtures()
	return true

func reset_all_data() -> void:
	season_number = 0
	history.clear()
	start_new_season()
