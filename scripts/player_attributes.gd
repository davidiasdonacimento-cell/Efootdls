extends RefCounted
## Atributos de atletas, cálculo de overall e progressão individual.

const ATTRIBUTE_KEYS := [
	"pace", "shooting", "passing", "dribbling", "defending", "physical",
	"stamina", "vision", "finishing", "crossing", "strength", "agility"
]

var player_name := "Jogador"
var position := "ST"
var overall := 65
var level := 1
var experience := 0
var attributes: Dictionary = {}
var potential := 88
var morale := 70
var fitness := 100
var training_points := 0
var goals := 0
var assists := 0
var matches := 0

func _init() -> void:
	attributes = {
		"pace": 68, "shooting": 66, "passing": 62, "dribbling": 67,
		"defending": 35, "physical": 64, "stamina": 72, "vision": 63,
		"finishing": 68, "crossing": 58, "strength": 65, "agility": 69
	}
	recalculate_overall()

func setup(name_value: String, position_value: String, base_attributes: Dictionary) -> void:
	player_name = name_value
	position = position_value
	for key in ATTRIBUTE_KEYS:
		if base_attributes.has(key):
			attributes[key] = clampi(int(base_attributes[key]), 1, 99)
	recalculate_overall()

func recalculate_overall() -> int:
	var weights := _get_position_weights()
	var weighted_sum := 0.0
	var total_weight := 0.0
	for key in ATTRIBUTE_KEYS:
		var weight := float(weights.get(key, 1.0))
		weighted_sum += float(attributes.get(key, 50)) * weight
		total_weight += weight
	overall = roundi(weighted_sum / maxf(total_weight, 0.01))
	overall = clampi(overall, 1, 99)
	return overall

func _get_position_weights() -> Dictionary:
	match position:
		"GK":
			return {"pace": 0.5, "shooting": 0.1, "passing": 1.0, "dribbling": 0.3, "defending": 2.0, "physical": 1.5, "stamina": 1.0, "vision": 1.1, "finishing": 0.1, "crossing": 0.4, "strength": 1.3, "agility": 1.7}
		"CB", "LB", "RB":
			return {"pace": 1.0, "shooting": 0.4, "passing": 0.9, "dribbling": 0.6, "defending": 2.0, "physical": 1.6, "stamina": 1.2, "vision": 0.8, "finishing": 0.2, "crossing": 0.7, "strength": 1.7, "agility": 0.8}
		"CM", "CDM", "CAM":
			return {"pace": 0.9, "shooting": 0.9, "passing": 1.7, "dribbling": 1.3, "defending": 1.1, "physical": 0.9, "stamina": 1.3, "vision": 1.8, "finishing": 0.8, "crossing": 1.0, "strength": 0.7, "agility": 1.0}
		"LW", "RW", "ST", "CF":
			return {"pace": 1.5, "shooting": 1.5, "passing": 0.9, "dribbling": 1.5, "defending": 0.2, "physical": 1.0, "stamina": 1.0, "vision": 0.8, "finishing": 1.8, "crossing": 1.0, "strength": 0.9, "agility": 1.2}
	return {}

func add_experience(amount: int) -> int:
	experience += maxi(0, amount)
	var gained := 0
	while experience >= _experience_required() and level < 50:
		experience -= _experience_required()
		level += 1
		training_points += 2
		gained += 1
	return gained

func _experience_required() -> int:
	return 120 + level * 45

func improve_attribute(attribute: String, amount := 1) -> bool:
	if attribute not in ATTRIBUTE_KEYS or training_points <= 0:
		return false
	var current := int(attributes.get(attribute, 50))
	if current >= potential:
		return false
	var increase := clampi(amount, 1, 3)
	var actual := mini(increase, potential - current)
	attributes[attribute] = current + actual
	training_points -= 1
	recalculate_overall()
	return true

func apply_match_performance(goals_scored: int, assists_made: int, minutes: int, match_rating: float) -> void:
	matches += 1
	goals += maxi(0, goals_scored)
	assists += maxi(0, assists_made)
	fitness = clampi(fitness - roundi(float(minutes) * 0.24), 0, 100)
	var earned := 15 + goals_scored * 30 + assists_made * 20 + roundi(match_rating * 8.0)
	add_experience(earned)
	morale = clampi(morale + (4 if match_rating >= 7.0 else -2), 0, 100)

func recover(energy: int) -> void:
	fitness = mini(100, fitness + maxi(0, energy))

func get_effective_attribute(attribute: String) -> float:
	var base := float(attributes.get(attribute, 50))
	var fitness_multiplier := lerpf(0.62, 1.0, float(fitness) / 100.0)
	var morale_multiplier := lerpf(0.92, 1.04, float(morale) / 100.0)
	return base * fitness_multiplier * morale_multiplier

func get_summary() -> Dictionary:
	return {
		"name": player_name,
		"position": position,
		"overall": overall,
		"level": level,
		"experience": experience,
		"potential": potential,
		"morale": morale,
		"fitness": fitness,
		"goals": goals,
		"assists": assists,
		"matches": matches,
		"attributes": attributes.duplicate(true)
	}

func save_to_config(config: ConfigFile, section: String) -> void:
	config.set_value(section, "name", player_name)
	config.set_value(section, "position", position)
	config.set_value(section, "overall", overall)
	config.set_value(section, "level", level)
	config.set_value(section, "experience", experience)
	config.set_value(section, "potential", potential)
	config.set_value(section, "morale", morale)
	config.set_value(section, "fitness", fitness)
	config.set_value(section, "attributes", attributes)
	config.set_value(section, "goals", goals)
	config.set_value(section, "assists", assists)
	config.set_value(section, "matches", matches)

func load_from_config(config: ConfigFile, section: String) -> void:
	player_name = str(config.get_value(section, "name", player_name))
	position = str(config.get_value(section, "position", position))
	level = clampi(int(config.get_value(section, "level", level)), 1, 50)
	experience = maxi(0, int(config.get_value(section, "experience", experience)))
	potential = clampi(int(config.get_value(section, "potential", potential)), 1, 99)
	morale = clampi(int(config.get_value(section, "morale", morale)), 0, 100)
	fitness = clampi(int(config.get_value(section, "fitness", fitness)), 0, 100)
	attributes = config.get_value(section, "attributes", attributes)
	goals = maxi(0, int(config.get_value(section, "goals", goals)))
	assists = maxi(0, int(config.get_value(section, "assists", assists)))
	matches = maxi(0, int(config.get_value(section, "matches", matches)))
	recalculate_overall()
