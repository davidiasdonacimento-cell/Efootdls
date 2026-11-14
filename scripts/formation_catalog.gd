extends RefCounted
## Catálogo de formações e posições relativas para escalação de 11 jogadores.

const FORMATIONS := {
	"4-3-3": {
		"name": "Ofensivo 4-3-3",
		"defenders": 4,
		"midfielders": 3,
		"forwards": 3,
		"defensive": 0.42,
		"width": 1.0
	},
	"4-4-2": {
		"name": "Equilibrado 4-4-2",
		"defenders": 4,
		"midfielders": 4,
		"forwards": 2,
		"defensive": 0.58,
		"width": 0.86
	},
	"3-5-2": {
		"name": "Controle 3-5-2",
		"defenders": 3,
		"midfielders": 5,
		"forwards": 2,
		"defensive": 0.52,
		"width": 1.08
	},
	"4-2-3-1": {
		"name": "Compacto 4-2-3-1",
		"defenders": 4,
		"midfielders": 5,
		"forwards": 1,
		"defensive": 0.66,
		"width": 0.92
	},
	"5-3-2": {
		"name": "Defensivo 5-3-2",
		"defenders": 5,
		"midfielders": 3,
		"forwards": 2,
		"defensive": 0.78,
		"width": 0.82
	}
}

const DEFAULT_ROSTER := [
	{"number": 1, "position": "GK", "name": "Goleiro", "rating": 72},
	{"number": 2, "position": "RB", "name": "Lateral Direito", "rating": 70},
	{"number": 3, "position": "CB", "name": "Zagueiro 1", "rating": 73},
	{"number": 4, "position": "CB", "name": "Zagueiro 2", "rating": 71},
	{"number": 6, "position": "LB", "name": "Lateral Esquerdo", "rating": 70},
	{"number": 5, "position": "CDM", "name": "Volante 1", "rating": 74},
	{"number": 8, "position": "CM", "name": "Meio Campo 1", "rating": 73},
	{"number": 10, "position": "CAM", "name": "Meio Campo 2", "rating": 77},
	{"number": 7, "position": "RW", "name": "Ponta Direita", "rating": 75},
	{"number": 9, "position": "ST", "name": "Atacante", "rating": 78},
	{"number": 11, "position": "LW", "name": "Ponta Esquerda", "rating": 74}
]

static func get_formation_names() -> Array[String]:
	var names: Array[String] = []
	for key in FORMATIONS.keys():
		names.append(str(key))
	names.sort()
	return names

static func get_formation(code: String) -> Dictionary:
	if not FORMATIONS.has(code):
		return FORMATIONS["4-3-3"].duplicate(true)
	return FORMATIONS[code].duplicate(true)

static func get_default_roster() -> Array[Dictionary]:
	var roster: Array[Dictionary] = []
	for entry in DEFAULT_ROSTER:
		roster.append(entry.duplicate(true))
	return roster

static func get_positions(code: String, field_length := 64.0, field_width := 42.0) -> Array[Vector3]:
	var formation := get_formation(code)
	var result: Array[Vector3] = []
	result.append(Vector3(0.0, 0.9, field_length * 0.42))
	var defender_count := int(formation["defenders"])
	var midfielder_count := int(formation["midfielders"])
	var forward_count := int(formation["forwards"])
	var width_multiplier := float(formation["width"])
	_add_line(result, defender_count, field_width * 0.34 * width_multiplier, field_length * 0.28)
	_add_line(result, midfielder_count, field_width * 0.36 * width_multiplier, field_length * 0.05)
	_add_line(result, forward_count, field_width * 0.31 * width_multiplier, -field_length * 0.22)
	return result

static func _add_line(target: Array[Vector3], count: int, width: float, z_position: float) -> void:
	if count <= 0:
		return
	if count == 1:
		target.append(Vector3(0.0, 0.9, z_position))
		return
	for index in range(count):
		var ratio := float(index) / float(count - 1)
		var x_position := lerpf(-width, width, ratio)
		target.append(Vector3(x_position, 0.9, z_position))

static func get_tactical_description(code: String) -> String:
	match code:
		"4-3-3":
			return "Três atacantes, amplitude pelos lados e pressão alta."
		"4-4-2":
			return "Duas linhas equilibradas e dois jogadores no ataque."
		"3-5-2":
			return "Meio-campo povoado e alas avançados."
		"4-2-3-1":
			return "Dois volantes protegem a defesa e um meia arma o jogo."
		"5-3-2":
			return "Linha defensiva reforçada para proteger o resultado."
	return "Formação equilibrada."

static func calculate_team_rating(roster: Array[Dictionary]) -> int:
	if roster.is_empty():
		return 0
	var total := 0
	for player in roster:
		total += int(player.get("rating", 0))
	return roundi(float(total) / float(roster.size()))

static func validate_roster(roster: Array[Dictionary]) -> bool:
	if roster.size() < 11:
		return false
	var numbers := {}
	for player in roster:
		var number := int(player.get("number", -1))
		if number < 1 or number > 99 or numbers.has(number):
			return false
		numbers[number] = true
	return true

static func sort_roster_by_rating(roster: Array[Dictionary]) -> Array[Dictionary]:
	var result := roster.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("rating", 0)) > int(b.get("rating", 0))
	)
	return result
