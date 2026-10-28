extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(InformationCampaignEligibility.catalog_errors().is_empty(),
		"O catálogo de Informações tem IDs únicos e tags/tipos coerentes: %s" %
		[InformationCampaignEligibility.catalog_errors()])
	_check(InformationCampaignEligibility.catalog_size() == 20,
		"Os vinte Resources de Informação são consultáveis por ID.")
	var campaign := CampaignState.new()
	var counts: Dictionary = {}
	for ending_id in CampaignState.ALL_ENDING_IDS:
		counts[ending_id] = 0
	for number in range(1, 21):
		var information_id := StringName("in_%05d" % number)
		var ending_id := InformationCampaignEligibility.ending_for_id(information_id)
		_check(ending_id in CampaignState.ALL_ENDING_IDS,
			"ID %s tem um desfecho cadastrado." % information_id)
		counts[ending_id] = int(counts.get(ending_id, 0)) + 1
		_check(campaign.is_information_eligible(information_id),
			"Campanha completa aceita %s." % information_id)
	for ending_id in CampaignState.ALL_ENDING_IDS:
		_check(int(counts[ending_id]) == 5,
			"Desfecho %s tem cinco Informações." % ending_id)
	campaign.active_ending_ids = [&"orchestra"]
	for number in range(1, 21):
		var information_id := StringName("in_%05d" % number)
		var expected := number in range(16, 21)
		_check(campaign.is_information_eligible(information_id) == expected,
			"Curta Orchestra filtra %s pelo ID/tag." % information_id)
	_check(campaign.is_information_eligible(&"", Informacao.TipoInformacao.ORCHESTRA),
		"Consulta por tipo aceita Orchestra ativo.")
	_check(not campaign.is_information_eligible(&"", Informacao.TipoInformacao.KHAINOKATA),
		"Consulta por tipo rejeita desfecho inativo.")
	_check(not campaign.is_information_eligible(&"in_00016",
		Informacao.TipoInformacao.CONTROLE_DA_MENTE),
		"ID e tipo discordantes são rejeitados.")
	_check(not campaign.is_information_eligible(&"in_99999"),
		"ID inexistente é rejeitado.")
	_check(not campaign.is_information_eligible(),
		"Consulta sem ID nem tipo é rejeitada.")
	campaign.active_ending_ids = [&"orchestra", &"controle_da_mente"]
	_check(campaign.is_information_eligible(&"in_00004",
		Informacao.TipoInformacao.CONTROLE_DA_MENTE)
		and campaign.is_information_eligible(&"in_00005",
		Informacao.TipoInformacao.CONTROLE_DA_MENTE),
		"Partes 4 e 5 de Controle da Mente têm tipo e tag corretos.")
	var manager := GerenciaJogo.new()
	root.add_child(manager)
	var playables: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	_check(manager.start_new_game(playables, EventCampaignEligibility.Mode.SHORT,
		[&"khainokata"]), "Campanha curta Khainokata começa antes da concessão.")
	var full_catalog := manager.get_information_catalog()
	var filtered := manager.campaign.filter_uncollected_information(full_catalog)
	_check(filtered.size() == 5, "Curta Khainokata filtra o catálogo a cinco partes.")
	for resource in filtered:
		var info := resource as Informacao
		_check(info != null and manager.campaign.is_information_eligible(info.id, info.tipo),
			"Filtro não entrega Informação de outro desfecho.")
	var wrong := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	_check(not manager.record_information_obtained(wrong),
		"Concessão direta recusa Orchestra quando só Khainokata está ativo.")
	for seed in 8:
		var rng := RandomNumberGenerator.new()
		rng.seed = 50100 + seed
		var grid := manager.prepare_map(full_catalog, &"suburbio",
			PPPMapGenerator.RoundPeriod.MORNING, 0, rng)
		_check(grid != null, "Mapa curto %d é gerado." % seed)
		if grid == null:
			continue
		for coord in grid.cells:
			var map_info := grid.get_ppp_block_resource(coord) as Informacao
			if map_info != null:
				_check(manager.campaign.is_information_eligible(map_info.id, map_info.tipo),
					"Mapa curto não sorteia Orchestra/Homens de Preto (%s)." % map_info.id)
	var first := filtered[0] as Informacao
	_check(manager.record_information_obtained(first),
		"Informação Khainokata válida pode ser concedida.")
	_check(not manager.record_information_obtained(first),
		"A mesma Informação não pode ser concedida duas vezes.")
	print("CAMPAIGN_INFORMATION_ELIGIBILITY_TEST: %s" %
		("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
