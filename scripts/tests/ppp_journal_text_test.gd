extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(game)
	await process_frame
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5503
	_check(gerencia.start_new_game(selected) and \
		(game.get_node("RoundManager") as RoundManager).start_first_map(rng),
		"Campanha de teste inicia.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	var recorder := game.get_node_or_null("CampaignJournalRecorder") as CampaignJournalRecorder
	_check(recorder != null, "Gravador do livro está presente.")
	if recorder == null:
		quit(1)
		return
	var before := campaign.journal_entries.size()
	var dummy_path: Array[Vector2i] = [Vector2i(1, 1)]
	(game.get_node("ExplorationManager") as ExplorationManager).actor_moved.emit(
		actor, dummy_path, 1)
	_check(campaign.journal_entries.size() == before,
		"Movimento comum entre hexes não gera linha.")
	var item := ItemData.new()
	item.id = &"test_cafe"
	item.display_name = "Café"
	recorder._on_block_finished({"actor": actor, "resource": item,
		"completion_kind": BlockManager.CompletionKind.ITEM_COLLECTED})
	_check(_last(campaign).contains("Café encontrado em Subúrbio"),
		"Coleta usa nome do distrito em vez de 'bloco'.")
	var reveal_coord := EntityState.UNPLACED
	var reveal_title := ""
	for value in campaign.current_map.cells.keys():
		var coord: Vector2i = value
		var content := campaign.current_map.get_ppp_block_resource(coord)
		if content is EventData or content is EncounterData or content is ItemData:
			reveal_coord = coord
			reveal_title = content.display_name
			break
	if reveal_coord != EntityState.UNPLACED:
		var skill := load("res://resources/skills/actives/playables/velha_fofoqueira/olhar_afiado.tres") as ActiveSkillData
		var viewer := campaign.active_entity_states[1]
		(game.get_node("PlayerSkillManager") as PlayerSkillManager).skill_manager.last_exploration_result = {
			"actor_id": viewer.instance_id, "skill_id": skill.id,
			"effects": [{"revealed_tiles": [reveal_coord]}]}
		recorder._on_exploration_skill(viewer, skill, reveal_coord)
		_check(_last(campaign).contains("revelou: %s" % reveal_title),
			"Ativa de revelação registra o título do bloco.")
	else:
		_check(false, "Mapa de teste tem bloco para revelar.")
	var event := EventData.new()
	event.id = &"ev_test_text"
	event.display_name = "A Florzinha"
	event.resolution_mode = EventData.ResolutionMode.PLAYER_ACCEPTS_THEN_OUTCOME
	recorder._on_event_result({"actor": actor, "resource": event},
		{"accepted": true, "effects": [{"effect": Event_EffectData.EffectType.MODIFY_MAX_HP,
			"before": 30, "after": 35}]})
	_check(_last(campaign).contains("Aceitou.") \
		and _last(campaign).contains("Ganhou 5 de Vida máxima."),
		"Aceite e consequência numérica aparecem em texto concreto.")
	recorder._on_event_result({"actor": actor, "resource": event},
		{"accepted": false, "effects": []})
	_check(_last(campaign).contains("Recusou."),
		"Recusa aplicável é explícita.")
	var shop := EventData.new()
	shop.id = &"ev_00046"
	shop.display_name = "Loja de Acessórios da Miss Fortuna"
	recorder._on_event_result({"actor": actor, "resource": shop,
		"decision": {"selected_catalog_item": item}},
		{"accepted": true, "effects": [{"effect": Event_EffectData.EffectType.GRANT_ITEM,
			"item_name": item.display_name}]})
	_check(_last(campaign).contains("Escolheu Café."),
		"Escolha de item mostra o item, não o nome genérico do outcome.")
	var encounter := EncounterData.new()
	encounter.display_name = "Zumbis Dançarinos"
	recorder._encounter_activator = actor
	recorder.combat._combat_id = &"journal-test-combat"
	recorder._on_combat_prepared(encounter, [], [])
	_check(_last(campaign).contains("caiu em um Encontro Indesejado com Zumbis Dançarinos"),
		"Encontro cita o nome encontrado.")
	var attacked := campaign.active_entity_states[1]
	recorder._on_combat_action(actor, &"attack", {"target": attacked,
		"damage": 8, "critical": true, "applied_statuses": ["sangramento"]})
	_check(_last(campaign).contains("8 de dano — CRITOU! e aplicou sangramento."),
		"Ataque crítico cita dano, crítico e status aplicado.")
	var critical_segments: Array = campaign.journal_entries.back().get("segments", [])
	_check(critical_segments.any(func(segment: Dictionary) -> bool:
		return str(segment.get("text", "")) == " — CRITOU!" \
			and str(segment.get("tone", "")) == "critical"),
		"CRITOU! tem tom dourado próprio no livro.")
	var before_roll := campaign.journal_entries.size()
	recorder._on_combat_action(actor, &"roll", {"die": 6})
	_check(campaign.journal_entries.size() == before_roll,
		"Lançamento de dado não cria linha editorial.")
	recorder._on_combat_finished({"reason": "victory"})
	_check(_last(campaign).contains("Zumbis Dançarinos"),
		"Conclusão cita o nome do encontro.")
	game.queue_free()
	await process_frame
	print("PPP_JOURNAL_TEXT_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _last(campaign: CampaignState) -> String:
	return str(campaign.journal_entries.back().get("text", ""))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
