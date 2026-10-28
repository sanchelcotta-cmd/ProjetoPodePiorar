extends SceneTree

## Aceite cruzado: seleção sorteada persistida, falha de escrita recuperável
## e os três motivos de autosave efetivamente gravados e relidos.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var autosave := scene.get_node("CampaignAutosaveController") as CampaignAutosaveController
	var repository := CampaignSaveRepository.new(
		"user://ppp_pool7_cross_acceptance_%d" % Time.get_ticks_usec())
	gerencia.save_repository = repository
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 70307
	_check(gerencia.start_new_game(selected, EventCampaignEligibility.Mode.MEDIUM)
		and rounds.start_first_map(rng), "C03: campanha média sorteada inicia com mapa.")
	var campaign := gerencia.campaign
	var rolled := campaign.active_ending_ids.duplicate()
	_check(rolled.size() == 2 and rolled[0] != rolled[1],
		"C03: sorteio inicial contém dois desfechos distintos.")
	var first_health := campaign.active_entity_states[0].current_health
	var initial_save := repository.save_campaign(campaign, 1, scene)
	_check(initial_save.get("success", false), "C03/C16: primeiro slot é válido.")
	var first_load := repository.load_campaign(campaign.campaign_id, 1)
	_check(first_load.get("success", false)
		and (first_load["campaign"] as CampaignState).active_ending_ids == rolled,
		"C03: carregar preserva os desfechos sorteados, sem novo sorteio.")

	# Diretório não vazio no caminho do backup simula uma falha real de I/O
	# antes da substituição. A falha não pode tocar o save principal válido.
	var backup_path := repository._slot_path(campaign.campaign_id, 1) + ".bak"
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	_check(DirAccess.make_dir_recursive_absolute(backup_absolute) == OK,
		"C16: obstáculo de I/O foi preparado em diretório de teste isolado.")
	var marker := FileAccess.open(backup_path.path_join("bloqueio.txt"), FileAccess.WRITE)
	_check(marker != null, "C16: diretório de backup é não vazio.")
	if marker != null:
		marker.store_string("teste Pool 7")
		marker.close()
	campaign.active_entity_states[0].current_health = maxi(1, first_health - 1)
	var refused := repository.save_campaign(campaign, 1, scene, true)
	var after_failure := repository.load_campaign(campaign.campaign_id, 1)
	_check(not refused.get("success", false)
		and not str(refused.get("reason", "")).is_empty(),
		"C16: falha de I/O retorna erro real, não 'Salvo'.")
	_check(after_failure.get("success", false)
		and (after_failure["campaign"] as CampaignState)
			.active_entity_states[0].current_health == first_health,
		"C16: último save válido permanece legível e inalterado.")

	autosave.enabled = true
	await process_frame
	var available := campaign.filter_uncollected_information(
		gerencia.get_information_catalog())
	_check(not available.is_empty(), "S01: Informação ativa está disponível.")
	if not available.is_empty():
		# C06 não tem hoje Resource de produção próprio: valida o contrato com
		# um Evento geral sintético, sem nome exibido como chave de regra.
		var general_event := EventData.new()
		general_event.id = &"ev_09999"
		var condition := EventConditionData.new()
		condition.condition_type = EventConditionData.ConditionType.HAS_INFORMATION
		condition.tag = InformationCampaignEligibility.ending_for_id(
			(available[0] as Informacao).id)
		var conditional_outcome := EventOutcomeData.new()
		conditional_outcome.id = &"ev_09999_out_01"
		conditional_outcome.condition = condition
		general_event.outcomes = [conditional_outcome]
		var executor := scene.get_node("EventExecutor") as EventExecutor
		_check(EventCampaignEligibility.allows_event(general_event,
			EventCampaignEligibility.Mode.SHORT)
			and EventCampaignEligibility.allows_event(general_event,
			EventCampaignEligibility.Mode.MEDIUM)
			and not executor._condition_matches(condition),
			"C06: Evento geral condicional permanece elegível, mas sem pista o ramo não abre.")
		_check(gerencia.grant_information(available[0] as Informacao)
			.get("success", false), "S01: Informação válida foi concedida.")
		_check(executor._condition_matches(condition),
			"C06: condição passa a usar a Informação realmente obtida pelo grupo.")
		await process_frame
		_check(_autosave_trigger(repository, campaign.campaign_id) == "informacao",
			"S01: Informação grava backup com motivo correto.")
		_check(rounds.advance_to_district(&"baixo_centro", rng),
			"S01: avanço regular muda a Rodada após Informação.")
		await process_frame
		_check(_autosave_trigger(repository, campaign.campaign_id) == "virada_rodada",
			"S01: virada efetiva grava backup com motivo correto.")
		combat.combat_finished.emit({"reason": "victory"})
		await process_frame
		_check(_autosave_trigger(repository, campaign.campaign_id) == "vitoria_combate",
			"S01: vitória sinalizada grava backup com motivo correto.")
	var recovered := repository.load_autosave(campaign.campaign_id)
	_check(recovered.get("success", false)
		and recovered.get("trigger", "") == "vitoria_combate",
		"S02: backup final é íntegro e recuperável.")
	var slots := []
	for entry in repository.list_campaigns():
		if entry["campaign_id"] == campaign.campaign_id:
			slots = entry["slots"]
	_check(slots.size() == 1 and slots[0]["slot_number"] == 1,
		"S03: autosave não ocupa nem sobrescreve slots manuais.")
	_test_early_short_victory(selected, repository.storage_root)
	scene.queue_free()
	await process_frame
	print("POOL7_CROSS_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _autosave_trigger(repository: CampaignSaveRepository,
		campaign_id: String) -> String:
	var restored := repository.load_autosave(campaign_id)
	return str(restored.get("trigger", "")) if restored.get("success", false) else ""


func _test_early_short_victory(selected: Array[EntityData],
		storage_root: String) -> void:
	var manager := GerenciaJogo.new()
	root.add_child(manager)
	manager.save_repository = CampaignSaveRepository.new(storage_root)
	_check(manager.start_new_game(selected, EventCampaignEligibility.Mode.SHORT,
		[&"khainokata"]), "R03: campanha curta para conclusão antecipada inicia.")
	var campaign := manager.campaign
	var catalog := manager.get_information_catalog()
	var eligible := campaign.filter_uncollected_information(catalog)
	_check(eligible.size() == 5, "R03: cinco partes distintas estão disponíveis.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 70308
	for map_index in 4:
		var next_map := manager.prepare_map(catalog, campaign.district,
			campaign.round_period, map_index, rng)
		_check(next_map != null and manager.install_map(next_map),
			"R03: mapa %d foi instalado." % (map_index + 1))
		var grant_count := 2 if map_index == 0 else 1
		for local_index in grant_count:
			var information_index := map_index + local_index \
				+ (0 if map_index == 0 else 1)
			_check(manager.grant_information(eligible[information_index] as Informacao,
				&"pool7_early_map").get("success", false),
				"R03: Informação %d foi concedida no mapa %d." % [
					information_index + 1, map_index + 1])
		if map_index == 0:
			_check(campaign.obtained_information_ids.size() == 2
				and campaign.information_obtained_on_current_map
				and not campaign.is_terminal(),
				"R03: duas partes no primeiro mapa contam sem encerrar cedo demais.")
	_check(campaign.obtained_information_ids.size() == 5
		and campaign.generated_map_count == 4
		and campaign.campaign_status == CampaignState.CampaignStatus.VICTORY,
		"R03: quinta Informação vence no quarto mapa, sem exigir quinto.")
	manager.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
