extends Node
## Comentários curtos de jogo para dar retorno às ações sem depender de arquivos de áudio.

signal commentary(message: String, category: String)

var message_cooldown := 0.0
var enabled := true
var event_counter := 0
var last_event := ""
var randomizer := RandomNumberGenerator.new()
var goal_messages := ["GOOOOOOL! QUE FINALIZAÇÃO!", "É REDE! GOL DO EFOOTDLS!", "NA GAVETA! GOLAÇO!"]
var save_messages := ["DEFESAÇA DO GOLEIRO!", "QUE DEFESA!", "O GOLEIRO SALVOU!"]
var shot_messages := ["BOA FINALIZAÇÃO!", "BATEU PRO GOL!", "TENTA MAIS UMA!"]
var pass_messages := ["PASSE CERTO!", "BOA TROCA DE PASSES!", "JOGO COLETIVO!"]
var tackle_messages := ["DESARME PERFEITO!", "RECUPEROU A BOLA!", "BOA MARCAÇÃO!"]

func _ready() -> void:
	randomizer.randomize()

func _process(delta: float) -> void:
	message_cooldown = maxf(0.0, message_cooldown - delta)

func announce(event_name: String, extra := {}) -> void:
	if not enabled or message_cooldown > 0.0:
		return
	var message := ""
	var category := "info"
	match event_name:
		"goal":
			message = _pick(goal_messages)
			category = "goal"
		"save":
			message = _pick(save_messages)
			category = "save"
		"shot":
			message = _pick(shot_messages)
			category = "shot"
		"pass":
			message = _pick(pass_messages)
			category = "pass"
		"tackle":
			message = _pick(tackle_messages)
			category = "tackle"
		"half_time":
			message = "INTERVALO! HORA DE AJUSTAR O TIME."
			category = "match"
		"full_time":
			message = "APITA O ÁRBITRO! FIM DE JOGO."
			category = "match"
		"stamina_low":
			message = "O JOGADOR ESTÁ CANSADO. DIMINUA O RITMO."
			category = "warning"
		"tactic":
			message = "TÁTICA: %s" % str(extra.get("title", "EQUILIBRADO"))
			category = "tactic"
		_:
			return
	last_event = event_name
	event_counter += 1
	message_cooldown = 1.1 if event_name == "goal" else 0.65
	commentary.emit(message, category)

func _pick(options: Array) -> String:
	if options.is_empty():
		return ""
	return str(options[randomizer.randi_range(0, options.size() - 1)])

func set_enabled(value: bool) -> void:
	enabled = value

func reset_feedback() -> void:
	message_cooldown = 0.0
	event_counter = 0
	last_event = ""

func get_event_count() -> int:
	return event_counter
