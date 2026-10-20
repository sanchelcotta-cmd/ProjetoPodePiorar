extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var excluded: Array[EventData] = [
		load("res://resources/events/random_events/01-artefato_do_vazio.tres"),
		load("res://resources/events/random_events/02-cobaia_secreta.tres"),
		load("res://resources/events/random_events/03-o_velho_louco.tres"),
		load("res://resources/events/random_events/04-termos_de_uso.tres"),
		load("res://resources/events/random_events/17-o_informante.tres"),
		load("res://resources/events/random_events/44-duas_caras.tres"),
	]
	for event in excluded:
		check(not EventCampaignEligibility.allows_event(event,
			EventCampaignEligibility.Mode.SHORT), "Curta exclui %s." % event.id)
		check(not EventCampaignEligibility.allows_event(event,
			EventCampaignEligibility.Mode.MEDIUM), "Média exclui %s." % event.id)
		check(EventCampaignEligibility.allows_event(event,
			EventCampaignEligibility.Mode.COMPLETE), "Completa permite %s." % event.id)
	var standby_generator := PPPMapGenerator.new()
	var older_ambiguous := load(
		"res://resources/events/random_events/20-um_artefato_magico.tres") as EventData
	var needed_good := load(
		"res://resources/events/random_events/05-um_raio_te_atingiu_na_cabeça_1.tres") as EventData
	var standby_pool: Array[Resource] = [older_ambiguous, needed_good]
	standby_generator._pools["all_events"] = standby_pool
	standby_generator._events_on_standby = {
		older_ambiguous.resource_path: true, needed_good.resource_path: true}
	standby_generator._standby_oldest_first = [
		older_ambiguous.resource_path, needed_good.resource_path]
	standby_generator._release_oldest_standby_events_if_needed(
		{EventData.Valence.GOOD: 1})
	check(standby_generator._events_on_standby.has(older_ambiguous.resource_path)
		and not standby_generator._events_on_standby.has(needed_good.resource_path),
		"Standby libera o mais antigo da valência necessária, não outro mais antigo.")

	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(party), "Campanha de teste inicia.")
	gerencia.campaign.campaign_mode = EventCampaignEligibility.Mode.SHORT
	check(rounds.start_first_map(), "Curta gera mapa inicial.")
	check(_map_has_no_excluded(gerencia.campaign.current_map),
		"Gerador normal não coloca Eventos exclusivos na curta.")
	var saci := load("res://resources/events/random_events/41-traquinagens_do_saci.tres") as EventData
	var result := executor._replace_map_row(saci.outcomes[0].effects[0],
		{"coord": Vector2i(0, 1)}, gerencia.campaign.current_map)
	check(result.get("success", false), "Saci recompõe uma linha na curta.")
	check(_map_has_no_excluded(gerencia.campaign.current_map),
		"A linha recomposta pelo Saci não introduz Eventos exclusivos.")
	var gnomes := scene.get_node("Gnomes3Manager") as Gnomes3Manager
	var generated_parent := EventData.new()
	generated_parent.custom_rule = &"spawn_gnomes_3"
	generated_parent.generated_events.append(excluded[0])
	generated_parent.generated_events.append(load(
		"res://resources/events/random_events/gnomes_3/01-raio_misterioso.tres"))
	gnomes._on_event_requested({"resource": generated_parent,
		"map": gerencia.campaign.current_map, "coord": Vector2i(0, 0)})
	check(_map_has_no_excluded(gerencia.campaign.current_map),
		"Evento gerado por outro Evento não injeta Resource exclusivo na curta.")
	var produced_gnome := false
	for coord in gerencia.campaign.current_map.cells:
		var placed := gerencia.campaign.current_map.get_ppp_block_resource(coord) as EventData
		if placed != null and placed.id == &"gn_00001":
			produced_gnome = true
	check(produced_gnome, "Um filho permitido ainda pode ser gerado.")

	var chained := EventOutcomeData.new()
	var trigger := Event_EffectData.new()
	trigger.effect_type = Event_EffectData.EffectType.TRIGGER_EVENT
	trigger.event_id = excluded[0].id
	chained.effects.append(trigger)
	check(not executor._outcome_is_campaign_eligible(chained),
		"Ramo que encadearia Evento exclusivo sai antes do sorteio na curta.")
	gerencia.campaign.campaign_mode = EventCampaignEligibility.Mode.COMPLETE
	check(executor._outcome_is_campaign_eligible(chained),
		"O mesmo encadeamento é elegível na campanha completa.")
	gerencia.campaign.campaign_mode = EventCampaignEligibility.Mode.MEDIUM
	var medium_map := gerencia.prepare_map(gerencia.get_information_catalog(),
		gerencia.campaign.district, gerencia.campaign.round_period,
		gerencia.campaign.get_round_index())
	check(_map_has_no_excluded(medium_map),
		"Gerador normal também exclui os seis Eventos na média.")

	var genie := load("res://resources/events/random_events/49-genio_da_lampada.tres") as EventData
	var information_outcome: EventOutcomeData
	for outcome in genie.outcomes:
		if outcome.id == &"random_information":
			information_outcome = outcome
			break
	check(not executor._select_outcome(genie,
		{"outcome": information_outcome}).get("success", false),
		"Executor rejeita o desejo de Informação na média mesmo por chamada direta.")
	popup._context = {"actor": gerencia.campaign.active_entity_states[0]}
	popup._show_genie_wishes(genie)
	check(popup.buttons.get_child_count() == 6,
		"UI da média oculta só o desejo de Informação (e ressurreição sem morto).")
	gerencia.campaign.campaign_mode = EventCampaignEligibility.Mode.COMPLETE
	popup._show_genie_wishes(genie)
	check(popup.buttons.get_child_count() == 7,
		"UI da completa mantém o desejo de Informação.")

	print("CAMPAIGN_SECONDARY_EVENT_FILTER_TEST: %s" %
		("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)


func _map_has_no_excluded(grid: HexGrid) -> bool:
	if grid == null:
		return false
	for coord in grid.cells:
		var event := grid.get_ppp_block_resource(coord) as EventData
		if event != null and &"somente_campanha_completa" in event.tags:
			return false
	return true


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
