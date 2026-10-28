extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(EventCampaignDependencies.catalog_errors().is_empty(),
		"Catálogo de dependências valida IDs, tags, condições e pistas: %s" %
		[EventCampaignDependencies.catalog_errors()])
	var paths := [
		"res://resources/events/random_events/01-artefato_do_vazio.tres",
		"res://resources/events/random_events/02-cobaia_secreta.tres",
		"res://resources/events/random_events/03-o_velho_louco.tres",
		"res://resources/events/random_events/04-termos_de_uso.tres",
		"res://resources/events/random_events/17-o_informante.tres",
		"res://resources/events/random_events/44-duas_caras.tres"]
	var excluded: Array[EventData] = []
	for path in paths:
		var event := load(path) as EventData
		excluded.append(event)
		_check(event != null and not EventCampaignEligibility.allows_event(event,
			EventCampaignEligibility.Mode.SHORT)
			and not EventCampaignEligibility.allows_event(event,
				EventCampaignEligibility.Mode.MEDIUM)
			and EventCampaignEligibility.allows_event(event,
				EventCampaignEligibility.Mode.COMPLETE),
			"Evento %s só entra no pool normal completo." % event.id)
	for index in 4:
		var event := excluded[index]
		_check(EventCampaignDependencies.direct_ending(event.id) != &""
			and event.outcomes.any(func(outcome: EventOutcomeData) -> bool:
				return outcome != null and EventCampaignDependencies.classify_outcome(
					event, outcome)["requires_information"]),
			"Dependência direta do Evento %s está no nível de outcome." % event.id)
	_check(EventCampaignDependencies.classify_outcome(excluded[2],
		excluded[2].outcomes[0])["encounter_rule"] \
		== &"start_crazy_old_man_combat_scaled_to_group"
		and EventCampaignDependencies.classify_outcome(excluded[3],
			excluded[3].outcomes[0])["encounter_rule"] \
		== &"start_dancing_zombie_horde_by_district",
		"Velho Louco e Termos de Uso registram a regra de Encontro por outcome.")
	var captive := excluded[1]
	var fixed := EventCampaignDependencies.classify_outcome(captive,
		captive.outcomes[0])
	_check(fixed["grants_information"] and fixed["fixed_information_id"] \
		== &"in_00019" and fixed["direct_ending"] == &"orchestra",
		"Cobaia Secreta é direta e concede ID fixo, sem substituição.")
	var informant := excluded[4]
	_check(EventCampaignDependencies.classify_outcome(informant,
		informant.outcomes[0])["grants_information"]
		and not EventCampaignDependencies.classify_outcome(informant,
			informant.outcomes[1])["grants_information"],
		"Informante classifica aceite e recusa separadamente.")
	var two_face := excluded[5]
	_check(EventCampaignDependencies.classify_outcome(two_face,
		two_face.outcomes[0])["grants_information"]
		and EventCampaignDependencies.classify_outcome(two_face,
			two_face.outcomes[1])["forgets_information"],
		"Duas-Caras diferencia ganho e perda de Informação por outcome.")
	var genie := load("res://resources/events/random_events/49-genio_da_lampada.tres") as EventData
	for mode in [EventCampaignEligibility.Mode.SHORT,
			EventCampaignEligibility.Mode.MEDIUM,
			EventCampaignEligibility.Mode.COMPLETE]:
		_check(EventCampaignEligibility.allows_event(genie, mode),
			"Gênio permanece elegível no modo %d." % mode)
	for outcome in genie.outcomes:
		var record := EventCampaignDependencies.classify_outcome(genie, outcome)
		var is_information: bool = outcome.id \
			== EventCampaignDependencies.GENIE_INFORMATION_OUTCOME_ID
		_check(record["complete_only"] == is_information
			and EventCampaignEligibility.allows_outcome(outcome,
				EventCampaignEligibility.Mode.SHORT) != is_information,
			"Somente o desejo de Informação é restrito: %s." % outcome.id)
	var experience := load("res://resources/encounters/enc_a_experiencia.tres") as EncounterData
	var association := EventCampaignDependencies.classify_encounter(experience)
	_check(not association["entry_requires_information"]
		and association["associated_ending"] == &"orchestra"
		and association["recruitment_global_short_threshold"] == 2
		and association["recruitment_global_medium_threshold"] == 4,
		"A Experiência aparece sem pista; só a oferta de recrutamento depende dela.")
	var generator := PPPMapGenerator.new()
	generator._rng = RandomNumberGenerator.new()
	generator._rng.seed = 3312
	generator._campaign_mode = EventCampaignEligibility.Mode.SHORT
	var thematic: Array[EncounterData] = [experience]
	_check(experience in generator._encounter_candidates(thematic),
		"Encontro associado tematicamente continua elegível sem Orchestra.")
	var only_excluded: Array[Resource] = [excluded[0]]
	_check(generator._event_candidates(only_excluded,
		EventData.Valence.AMBIGUOUS).is_empty()
		and generator._draw_event(only_excluded,
			EventData.Valence.AMBIGUOUS) == null,
		"Valência vazia não recebe fallback de Evento excluído.")
	var allowed := load("res://resources/events/random_events/07-gnomos_do_caos_1.tres") as EventData
	var mixed: Array[Resource] = [excluded[0], allowed]
	_check(generator._event_candidates(mixed,
		EventData.Valence.AMBIGUOUS) == [allowed]
		and generator._draw_event(mixed,
			EventData.Valence.AMBIGUOUS) == allowed
		and allowed.selection_weight == 1,
		"Sorteio preserva o peso do candidato elegível, sem substituição.")
	var heavy := load(
		"res://resources/events/random_events/05-um_raio_te_atingiu_na_cabeça_1.tres") as EventData
	var light := load(
		"res://resources/events/random_events/14-amigo_imaginario.tres") as EventData
	var weighted_pool: Array[Resource] = [heavy, light]
	var heavy_draws := 0
	for index in 500:
		generator._event_placements.clear()
		if generator._draw_event(weighted_pool, EventData.Valence.GOOD) == heavy:
			heavy_draws += 1
	_check(heavy.selection_weight == 4 and light.selection_weight == 1
		and heavy_draws > 330 and heavy_draws < 460,
		"Sorteio entre elegíveis conserva a proporção 4:1 dos Resources.")
	await _check_forced_information(excluded)
	print("CAMPAIGN_POOL3_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check_forced_information(excluded: Array[EventData]) -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(party, EventCampaignEligibility.Mode.SHORT,
		[&"khainokata"]), "Campanha curta Khainokata inicia.")
	var actor := gerencia.campaign.active_entity_states[0]
	var captive := excluded[1]
	var fixed_effect := captive.outcomes[0].effects[0]
	var fixed_result := executor._apply_effect(fixed_effect, actor, captive,
		{"actor": actor}, false)
	_check(fixed_result.get("success", false)
		and fixed_result.get("information_not_granted", false)
		and str(fixed_result.get("reason", "")).contains("desfechos ativos")
		and gerencia.campaign.obtained_information_ids.is_empty(),
		"ID fixo Orchestra forçado não é substituído por Khainokata.")
	var informant := excluded[4]
	var reward := executor._apply_effect(informant.outcomes[0].effects[0],
		actor, informant, {"actor": actor}, false)
	var first_id: StringName = reward.get("information_id", &"")
	_check(reward.get("success", false) and first_id != &""
		and InformationCampaignEligibility.ending_for_id(first_id) == &"khainokata",
		"Informante forçado só concede Informação nova do desfecho ativo.")
	var two_face := excluded[5]
	var second := executor._apply_effect(two_face.outcomes[0].effects[0],
		actor, two_face, {"actor": actor}, false)
	var second_id: StringName = second.get("information_id", &"")
	_check(second.get("success", false) and second_id != first_id
		and InformationCampaignEligibility.ending_for_id(second_id) == &"khainokata",
		"Duas-Caras forçado não repete nem concede outro desfecho.")
	var independent := EventData.new()
	independent.id = &"test_independent_effects"
	var outcome := EventOutcomeData.new()
	outcome.id = &"test_independent_effects_outcome"
	var composite_effects: Array[Event_EffectData] = [fixed_effect,
		informant.outcomes[0].effects[1]]
	var health_before := actor.max_health
	var information_before := gerencia.campaign.obtained_information_ids.size()
	executor._prepared = {"context": {"actor": actor}, "event": independent,
		"outcome": outcome, "selected": {}, "effects": composite_effects,
		"narrative": "Efeitos independentes.", "unsupported_reason": ""}
	_check(executor.apply_prepared_result()
		and actor.max_health == health_before - 5
		and gerencia.campaign.obtained_information_ids.size() == information_before
		and executor._pending_result.get("effects", [])[0].get(
			"information_not_granted", false),
		"Recompensa inativa é pulada, mas perda independente de Vida é aplicada.")
	_check(gerencia.start_new_game(party, EventCampaignEligibility.Mode.MEDIUM,
		[&"homens_de_preto", &"controle_da_mente"]),
		"Campanha média sem Orchestra inicia para depuração forçada.")
	actor = gerencia.campaign.active_entity_states[0]
	var medium_reward := executor._apply_effect(
		informant.outcomes[0].effects[0], actor, informant,
		{"actor": actor}, false)
	var medium_id: StringName = medium_reward.get("information_id", &"")
	_check(medium_reward.get("success", false) and medium_id != &""
		and InformationCampaignEligibility.ending_for_id(medium_id) \
		in [&"homens_de_preto", &"controle_da_mente"],
		"Informante forçado na média sorteia só entre os dois desfechos ativos.")
	scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
