extends SceneTree

const COMPLETE_ONLY: StringName = &"somente_campanha_completa"
const MIXED_OUTCOMES: StringName = &"contem_outcomes_restritos_por_modo"
const COMPLETE_ONLY_EVENTS := [
	"01-artefato_do_vazio",
	"02-cobaia_secreta",
	"03-o_velho_louco",
	"04-termos_de_uso",
	"17-o_informante",
	"44-duas_caras",
]

var failures := 0


func _initialize() -> void:
	for filename: String in COMPLETE_ONLY_EVENTS:
		var event := load("res://resources/events/random_events/%s.tres" % filename) as EventData
		check(event != null, "%s carrega como Evento." % filename)
		if event != null:
			check(COMPLETE_ONLY in event.tags,
				"%s restringe o Evento inteiro à campanha completa." % filename)

	var genie := load("res://resources/events/random_events/49-genio_da_lampada.tres") as EventData
	check(genie != null, "O Gênio carrega como Evento.")
	if genie != null:
		check(MIXED_OUTCOMES in genie.tags and COMPLETE_ONLY not in genie.tags,
			"O Gênio permanece elegível como Evento; seus outcomes são mistos.")
		var information_count := 0
		for outcome: EventOutcomeData in genie.outcomes:
			if outcome.id == &"random_information":
				information_count += 1
				check(COMPLETE_ONLY in outcome.tags,
					"O desejo de Informação é exclusivo da campanha completa.")
			else:
				check(COMPLETE_ONLY not in outcome.tags,
					"O desejo %s não é restringido por esta regra." % outcome.id)
		check(information_count == 1, "Há exatamente um desejo de Informação.")

	print("CAMPAIGN_EVENT_TAGS_TEST: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
