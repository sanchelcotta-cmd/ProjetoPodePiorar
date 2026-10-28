extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(game.start_new_game(selected, EventCampaignEligibility.Mode.COMPLETE)
		and rounds.start_first_map(), "Campanha Completa inicia.")
	var catalog := game.get_information_catalog()
	for index in 18:
		check(game.grant_information(catalog[index] as Informacao,
			&"test").get("success", false), "Pista da reta final válida.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3220
	var preprepared := game.prepare_map(catalog, &"suburbio",
		game.campaign.round_period, game.campaign.get_round_index(), rng)
	check(preprepared != null and preprepared.ppp_background_path.contains("suburbio"),
		"Portal foi preparado antes da 19ª Informação para o Subúrbio.")
	check(game.grant_information(catalog[18] as Informacao,
		&"event_bonus").get("success", false),
		"O mesmo Outcome concede a 19ª Informação antes da troca.")
	var actor := game.campaign.active_entity_states[0]
	var next_day := game.campaign.day + 1
	var transition := {"kind": &"new_map", "actor": actor,
		"map": preprepared, "district": &"suburbio", "next_day": next_day,
		"activate_arrival": false}
	check(executor._perform_world_transition(transition),
		"Portal/abdução conclui a troca preparada.")
	check(game.campaign.district == &"centro"
		and game.campaign.current_map.ppp_background_path.contains("centro")
		and game.campaign.final_center_intro_pending,
		"Destino é revalidado depois do Outcome e forçado ao Centro.")
	check(executor._final_center_arrival.get("kind") == &"pass_turn"
		and bar._pending_day_transition == next_day,
		"Virada do Dia aguarda introdução; ação do Evento aguarda as telas.")
	var codec := CampaignSaveCodec.new()
	var snapshot := codec.encode({"campaign": game.campaign,
		"deferred_arrival": executor._final_center_arrival})
	check(codec.error.is_empty() and codec.decode(snapshot) != null,
		"Introdução e continuação adiada podem ser salvas sem novo sorteio.")
	await process_frame
	check(bar._final_center_transition.is_open(),
		"A cena preta do Centro abre antes da tela de novo Dia.")
	bar._on_final_center_continue()
	await process_frame
	check(game.campaign.final_center_intro_seen
		and not game.campaign.final_center_intro_pending
		and bar._day_transition.is_open(),
		"Introdução é única e a virada do Dia vem em seguida.")
	bar._on_new_day_continue()
	await process_frame
	check(executor._final_center_arrival.is_empty(),
		"O turno pendente só continua após as duas telas pretas.")
	print("FINAL_CENTER_TRANSITION_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
