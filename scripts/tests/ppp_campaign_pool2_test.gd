extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	var catalog := GerenciaJogo.new().get_information_catalog()
	_check(catalog.size() == 20, "O catálogo contém vinte Informações estáveis.")
	_test_goal(selected, catalog, EventCampaignEligibility.Mode.SHORT,
		[&"khainokata"], 5)
	_test_goal(selected, catalog, EventCampaignEligibility.Mode.MEDIUM,
		[&"khainokata", &"orchestra"], 10)
	_test_goal(selected, catalog, EventCampaignEligibility.Mode.COMPLETE, [], 20)
	_test_extra_maps_and_capacity(selected, catalog)
	_test_solo_death(selected)
	print("CAMPAIGN_POOL2_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _test_goal(selected: Array[EntityData], catalog: Array[Resource],
		mode: int, endings: Array[StringName], goal: int) -> void:
	var gerencia := GerenciaJogo.new()
	root.add_child(gerencia)
	_check(gerencia.start_new_game(selected, mode, endings),
		"Campanha de meta %d inicia." % goal)
	var campaign := gerencia.campaign
	var terminal_changes: Array[int] = []
	campaign.campaign_terminal_changed.connect(func(status: int, _count: int) -> void:
		terminal_changes.append(status))
	var signals: Array[StringName] = []
	gerencia.information_granted.connect(func(info: Informacao, _result: Dictionary) -> void:
		signals.append(info.id))
	var active := campaign.filter_uncollected_information(catalog)
	_check(active.size() == goal, "Meta %d possui exatamente %d partes elegíveis." %
		[goal, goal])
	if goal < 20:
		var inactive: Informacao = null
		for resource in catalog:
			var candidate := resource as Informacao
			if candidate != null and candidate not in active:
				inactive = candidate
				break
		var refused := gerencia.grant_information(inactive, &"test_inactive")
		_check(refused.get("code") == &"inactive_ending" and signals.is_empty(),
			"Desfecho inativo é recusado sem emissão ou substituição.")
	for index in active.size():
		var info := active[index] as Informacao
		var result := gerencia.grant_information(info, &"test_source")
		_check(result.get("success", false)
			and result.get("information_count", -1) == index + 1,
			"Parte %d/%d é registrada uma vez." % [index + 1, goal])
		if index == 0:
			var repeated := gerencia.grant_information(info, &"test_duplicate")
			_check(repeated.get("code") == &"already_obtained"
				and signals.size() == 1,
				"Duplicata mantém a contagem e retorna motivo específico.")
		_check(campaign.is_terminal() == (index + 1 == goal),
			"Meta %d só encerra exatamente na parte %d." % [goal, goal])
	_check(campaign.campaign_status == CampaignState.CampaignStatus.VICTORY
		and terminal_changes == [CampaignState.CampaignStatus.VICTORY]
		and signals.size() == goal,
		"Vitória %d é sinalizada uma única vez." % goal)
	_check(gerencia.grant_information(active[0] as Informacao).get("code")
		== &"campaign_not_active" and terminal_changes.size() == 1,
		"Estado terminal recusa novas concessões sem repetir a vitória.")
	_check(campaign.forget_last_information() == &""
		and not campaign.information_allows_round_advance()
		and gerencia.prepare_map(catalog, campaign.district,
			campaign.round_period, campaign.get_round_index()) == null,
		"Vitória bloqueia remoção de partes e avanço acidental.")
	gerencia.queue_free()


func _test_extra_maps_and_capacity(selected: Array[EntityData],
		catalog: Array[Resource]) -> void:
	for setup in [
		{"mode": EventCampaignEligibility.Mode.SHORT,
			"endings": [&"khainokata"], "maps": 6},
		{"mode": EventCampaignEligibility.Mode.MEDIUM,
			"endings": [&"khainokata", &"orchestra"], "maps": 11}]:
		var gerencia := GerenciaJogo.new()
		root.add_child(gerencia)
		var endings: Array[StringName] = []
		endings.assign(setup["endings"])
		_check(gerencia.start_new_game(selected, setup["mode"], endings),
			"Campanha extra-mapas inicia.")
		var campaign := gerencia.campaign
		for map_index in setup["maps"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 456700 + map_index
			var next_map := gerencia.prepare_map(catalog, campaign.district,
				campaign.round_period, campaign.get_round_index(), rng)
			if next_map == null:
				_check(false, "Mapa extra %d foi preparado." % (map_index + 1))
				break
			var map_information_ids: Dictionary = {}
			var map_information_hexes := 0
			for coord in next_map.cells:
				var map_info := next_map.get_ppp_block_resource(coord) as Informacao
				if map_info != null:
					map_information_hexes += 1
					map_information_ids[map_info.id] = true
					_check(campaign.is_information_eligible(map_info.id, map_info.tipo),
						"Mapa extra não contém parte de desfecho inativo.")
			_check(map_information_hexes in [1, 2]
				and map_information_ids.size() == map_information_hexes,
				"Mapa extra preserva um hex fixo e no máximo um livre, sem duplicatas.")
			_check(gerencia.install_map(next_map),
				"Mapa extra %d foi instalado sem cota artificial." % (map_index + 1))
		_check(campaign.generated_map_count == setup["maps"]
			and campaign.obtained_information_ids.is_empty()
			and campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE,
			"%d mapas não encerram nem alteram a meta de Informações." % setup["maps"])
		var prior_map := campaign.current_map
		var prior_day := campaign.day
		var prior_period := campaign.round_period
		var prior_count := campaign.generated_map_count
		var empty_catalog: Array[Resource] = []
		_check(gerencia.prepare_map(empty_catalog, campaign.district,
				campaign.round_period, campaign.get_round_index()) == null
			and campaign.current_map == prior_map and campaign.day == prior_day
			and campaign.round_period == prior_period
			and campaign.generated_map_count == prior_count,
			"Pool vazio falha sem mudar mapa, Dia ou Rodada.")
		gerencia.queue_free()


func _test_solo_death(selected: Array[EntityData]) -> void:
	var campaign := CampaignState.new()
	_check(campaign.start_new_game(selected), "Campanha de morte isolada inicia.")
	var terminal_changes: Array[int] = []
	campaign.campaign_terminal_changed.connect(func(status: int, _count: int) -> void:
		terminal_changes.append(status))
	var owner := campaign.active_entity_states[0]
	var others := [campaign.active_entity_states[1], campaign.active_entity_states[2]]
	var original_positions := [others[0].position, others[1].position]
	_check(campaign.start_solo_exploration(owner, 3),
		"Exploração isolada começa.")
	_check(others[0].temporarily_absent_from_map
		and others[1].temporarily_absent_from_map
		and campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE,
		"Demais jogáveis estão apenas temporariamente ausentes.")
	owner.current_health = 0
	campaign.on_temporary_event_turn_finished(owner)
	_check(not others[0].temporarily_absent_from_map
		and not others[1].temporarily_absent_from_map
		and others[0].position == original_positions[0]
		and others[1].position == original_positions[1],
		"Morte do isolado devolve sobreviventes às posições originais.")
	campaign.finalize_dead_playables(null)
	_check(campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE
		and owner in campaign.dead_playable_states,
		"Morte do isolado não derrota o grupo sobrevivente.")
	for other in others:
		other.current_health = 0
	campaign.finalize_dead_playables(null)
	campaign.finalize_dead_playables(null)
	_check(campaign.campaign_status == CampaignState.CampaignStatus.DEFEAT
		and terminal_changes == [CampaignState.CampaignStatus.DEFEAT],
		"Derrota exige morte real dos três e é sinalizada uma só vez.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
