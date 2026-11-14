extends RefCounted
## Mercado local de atletas: ofertas, compra, venda e controle de orçamento.

signal market_refreshed(players: Array)
signal player_signed(player: Dictionary, remaining_coins: int)
signal player_sold(player: Dictionary, earned_coins: int)
signal market_error(message: String)

const SAVE_PATH := "user://efootdls_market.cfg"
const NAMES := [
	"Lucas Almeida", "Rafael Costa", "João Pedro", "Caio Martins",
	"Bruno Santos", "Gabriel Rocha", "Matheus Lima", "Enzo Carvalho",
	"Pedro Souza", "Thiago Oliveira", "Vitor Ferreira", "Arthur Gomes",
	"Samuel Ribeiro", "Felipe Barbosa", "Daniel Nunes", "Igor Mendes"
]
const POSITIONS := ["GK", "CB", "LB", "RB", "CM", "CDM", "CAM", "LW", "RW", "ST"]

var offers: Array[Dictionary] = []
var owned_players: Array[Dictionary] = []
var balance := 1200
var refresh_number := 0
var randomizer := RandomNumberGenerator.new()

func _init() -> void:
	randomizer.randomize()
	refresh_market()

func refresh_market(count := 8) -> void:
	offers.clear()
	refresh_number += 1
	for index in range(clampi(count, 4, 16)):
		offers.append(_generate_player(index))
	market_refreshed.emit(get_offers())

func _generate_player(index: int) -> Dictionary:
	var rating := randomizer.randi_range(58, 87)
	var position: String = str(POSITIONS[randomizer.randi_range(0, POSITIONS.size() - 1)])
	var value := _calculate_value(rating)
	return {
		"id": "market_%d_%d" % [refresh_number, index],
		"name": NAMES[randomizer.randi_range(0, NAMES.size() - 1)],
		"position": position,
		"rating": rating,
		"potential": mini(99, rating + randomizer.randi_range(1, 15)),
		"age": randomizer.randi_range(17, 34),
		"value": value,
		"wage": maxi(25, roundi(float(value) * 0.012)),
		"fitness": randomizer.randi_range(68, 100),
		"owned": false
	}

func _calculate_value(rating: int) -> int:
	var rating_factor := pow(float(rating) / 50.0, 3.0)
	return roundi(rating_factor * 900.0)

func buy_player(player_id: String) -> bool:
	var index := _find_offer(player_id)
	if index < 0:
		market_error.emit("Atleta não está mais disponível.")
		return false
	var player: Dictionary = offers[index]
	var cost := int(player["value"])
	if balance < cost:
		market_error.emit("Saldo insuficiente para contratar este atleta.")
		return false
	balance -= cost
	player["owned"] = true
	owned_players.append(player.duplicate(true))
	offers.remove_at(index)
	player_signed.emit(player.duplicate(true), balance)
	market_refreshed.emit(get_offers())
	save_market()
	return true

func sell_player(player_id: String) -> bool:
	var index := _find_owned(player_id)
	if index < 0:
		return false
	var player: Dictionary = owned_players[index]
	var value := int(player["value"])
	var payout := roundi(float(value) * 0.72)
	balance += payout
	owned_players.remove_at(index)
	player_sold.emit(player.duplicate(true), payout)
	save_market()
	return true

func _find_offer(player_id: String) -> int:
	for index in range(offers.size()):
		if str(offers[index]["id"]) == player_id:
			return index
	return -1

func _find_owned(player_id: String) -> int:
	for index in range(owned_players.size()):
		if str(owned_players[index]["id"]) == player_id:
			return index
	return -1

func set_balance(value: int) -> void:
	balance = maxi(0, value)

func add_balance(value: int) -> void:
	balance = maxi(0, balance + value)

func get_offers() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in offers:
		result.append(player.duplicate(true))
	return result

func get_owned_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in owned_players:
		result.append(player.duplicate(true))
	return result

func get_offers_by_position(position: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in offers:
		if str(player["position"]) == position:
			result.append(player.duplicate(true))
	return result

func get_offers_by_rating(minimum_rating: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for player in offers:
		if int(player["rating"]) >= minimum_rating:
			result.append(player.duplicate(true))
	return result

func get_market_summary() -> Dictionary:
	return {
		"balance": balance,
		"offers": offers.size(),
		"owned_players": owned_players.size(),
		"refresh_number": refresh_number,
		"total_squad_value": _calculate_squad_value()
	}

func _calculate_squad_value() -> int:
	var total := 0
	for player in owned_players:
		total += int(player["value"])
	return total

func save_market() -> bool:
	var config := ConfigFile.new()
	config.set_value("market", "balance", balance)
	config.set_value("market", "offers", offers)
	config.set_value("market", "owned", owned_players)
	config.set_value("market", "refresh_number", refresh_number)
	return config.save(SAVE_PATH) == OK

func load_market() -> bool:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return false
	balance = maxi(0, int(config.get_value("market", "balance", balance)))
	refresh_number = int(config.get_value("market", "refresh_number", 0))
	offers.clear()
	owned_players.clear()
	var saved_offers: Variant = config.get_value("market", "offers", [])
	var saved_owned: Variant = config.get_value("market", "owned", [])
	if saved_offers is Array:
		for player in saved_offers:
			if player is Dictionary:
				offers.append(player.duplicate(true))
	if saved_owned is Array:
		for player in saved_owned:
			if player is Dictionary:
				owned_players.append(player.duplicate(true))
	return true

func reset_market() -> void:
	offers.clear()
	owned_players.clear()
	balance = 1200
	refresh_number = 0
	refresh_market()
	save_market()
