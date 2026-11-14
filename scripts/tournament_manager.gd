extends RefCounted
## Torneios eliminatórios com chave, resultados, classificação e persistência.

signal round_started(round_number: int, fixtures: Array)
signal match_recorded(match_data: Dictionary)
signal tournament_finished(champion: String)

const SAVE_PATH := "user://efootdls_tournament.cfg"
const DEFAULT_TEAMS := [
	"Efootdls FC", "Bahia Azul", "Rio United", "Atlético Central",
	"Porto Verde", "Estrela do Norte", "Real Litoral", "Capital FC"
]

var teams: Array[String] = []
var rounds: Array[Array] = []
var current_round := 0
var champion := ""
var tournament_name := "Copa Efootdls"
var started := false
var finished := false
var randomizer := RandomNumberGenerator.new()

func _init() -> void:
	randomizer.randomize()

func create_tournament(team_list: Array[String] = [], name_value := "Copa Efootdls") -> bool:
	teams.clear()
	var source := team_list if not team_list.is_empty() else DEFAULT_TEAMS
	for team in source:
		if not teams.has(team):
			teams.append(team)
	if teams.size() < 4 or teams.size() % 2 != 0:
		return false
	tournament_name = name_value
	teams.shuffle()
	rounds.clear()
	current_round = 0
	champion = ""
	finished = false
	started = true
	var opening: Array[Dictionary] = []
	for index in range(0, teams.size(), 2):
		opening.append(_new_fixture(teams[index], teams[index + 1]))
	rounds.append(opening)
	_generate_empty_rounds(teams.size())
	round_started.emit(1, get_current_fixtures())
	return true

func _generate_empty_rounds(team_count: int) -> void:
	var advancing := team_count / 2
	while advancing >= 2:
		var next_round: Array[Dictionary] = []
		for index in range(advancing / 2):
			next_round.append(_new_fixture("", ""))
		rounds.append(next_round)
		advancing = int(advancing / 2)

func _new_fixture(home: String, away: String) -> Dictionary:
	return {
		"home": home,
		"away": away,
		"home_score": -1,
		"away_score": -1,
		"winner": "",
		"played": false
	}

func record_result(match_index: int, home_score: int, away_score: int, winner_on_draw := "") -> bool:
	if not started or finished or current_round >= rounds.size():
		return false
	var fixtures: Array = rounds[current_round]
	if match_index < 0 or match_index >= fixtures.size():
		return false
	var fixture: Dictionary = fixtures[match_index]
	if bool(fixture["played"]):
		return false
	if home_score == away_score and winner_on_draw.is_empty():
		return false
	fixture["home_score"] = maxi(0, home_score)
	fixture["away_score"] = maxi(0, away_score)
	fixture["winner"] = winner_on_draw if home_score == away_score else (str(fixture["home"]) if home_score > away_score else str(fixture["away"]))
	fixture["played"] = true
	fixtures[match_index] = fixture
	rounds[current_round] = fixtures
	match_recorded.emit(fixture.duplicate(true))
	if _round_is_complete(current_round):
		_advance_round()
	save_tournament()
	return true

func _round_is_complete(round_index: int) -> bool:
	for fixture in rounds[round_index]:
		if not bool(fixture["played"]):
			return false
	return true

func _advance_round() -> void:
	var winners: Array[String] = []
	for fixture in rounds[current_round]:
		winners.append(str(fixture["winner"]))
	if winners.size() == 1:
		champion = winners[0]
		finished = true
		tournament_finished.emit(champion)
		return
	current_round += 1
	if current_round >= rounds.size():
		var final_round: Array[Dictionary] = []
		for index in range(0, winners.size(), 2):
			final_round.append(_new_fixture(winners[index], winners[index + 1]))
		rounds.append(final_round)
	else:
		var next_round: Array = rounds[current_round]
		for index in range(mini(next_round.size(), int(winners.size() / 2))):
			next_round[index]["home"] = winners[index * 2]
			next_round[index]["away"] = winners[index * 2 + 1]
		rounds[current_round] = next_round
	round_started.emit(current_round + 1, get_current_fixtures())

func get_current_fixtures() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if current_round < 0 or current_round >= rounds.size():
		return result
	for fixture in rounds[current_round]:
		result.append(fixture.duplicate(true))
	return result

func get_round_name() -> String:
	var team_count := teams.size()
	var remaining := team_count / int(pow(2.0, current_round))
	match remaining:
		2:
			return "FINAL"
		4:
			return "SEMIFINAL"
		8:
			return "QUARTAS DE FINAL"
		16:
			return "OITAVAS DE FINAL"
	return "RODADA %d" % (current_round + 1)

func get_tournament_summary() -> Dictionary:
	return {
		"name": tournament_name,
		"teams": teams.duplicate(),
		"round": current_round + 1,
		"round_name": get_round_name(),
		"champion": champion,
		"started": started,
		"finished": finished
	}

func save_tournament() -> bool:
	var config := ConfigFile.new()
	config.set_value("tournament", "teams", teams)
	config.set_value("tournament", "rounds", rounds)
	config.set_value("tournament", "current_round", current_round)
	config.set_value("tournament", "champion", champion)
	config.set_value("tournament", "name", tournament_name)
	config.set_value("tournament", "started", started)
	config.set_value("tournament", "finished", finished)
	return config.save(SAVE_PATH) == OK

func load_tournament() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	teams.clear()
	var loaded_teams: Variant = config.get_value("tournament", "teams", [])
	if loaded_teams is Array:
		for team in loaded_teams:
			teams.append(str(team))
	rounds.clear()
	var loaded_rounds: Variant = config.get_value("tournament", "rounds", [])
	if loaded_rounds is Array:
		for group in loaded_rounds:
			var copied_group: Array[Dictionary] = []
			if group is Array:
				for fixture in group:
					if fixture is Dictionary:
						copied_group.append(fixture.duplicate(true))
			rounds.append(copied_group)
	current_round = int(config.get_value("tournament", "current_round", 0))
	champion = str(config.get_value("tournament", "champion", ""))
	tournament_name = str(config.get_value("tournament", "name", "Copa Efootdls"))
	started = bool(config.get_value("tournament", "started", false))
	finished = bool(config.get_value("tournament", "finished", false))
	return started and not rounds.is_empty()

func reset_tournament() -> void:
	teams.clear()
	rounds.clear()
	current_round = 0
	champion = ""
	started = false
	finished = false
