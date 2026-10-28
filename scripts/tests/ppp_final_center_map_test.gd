extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var gerencia := GerenciaJogo.new()
	root.add_child(gerencia)
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(gerencia.start_new_game(selected, EventCampaignEligibility.Mode.COMPLETE),
		"A Campanha Completa inicia com os desfechos ativos.")
	var campaign := gerencia.campaign
	var catalog := gerencia.get_information_catalog()
	_check(catalog.size() == 20, "O catálogo de teste contém vinte Informações.")
	_check(campaign.allows_free_information_on_next_map(),
		"Antes da reta final, o segundo hex de Informação continua possível.")
	for index in 18:
		var result := gerencia.grant_information(catalog[index] as Informacao, &"test")
		_check(result.get("success", false), "A Informação %d foi concedida." % index)
	_check(not campaign.allows_free_information_on_next_map() \
		and not campaign.requires_final_center_map(),
		"Com 18/20, o mapa ainda pode ser fora do Centro, sem Informação livre.")
	campaign.generated_map_count = 18
	var rng := RandomNumberGenerator.new()
	rng.seed = 7788
	var penultimate := gerencia.prepare_map(catalog, &"suburbio",
		PPPMapGenerator.RoundPeriod.MORNING, 19, rng)
	_check(penultimate != null and _information_hex_count(penultimate) == 1,
		"O mapa que pode conceder a 19ª parte tem só o hex fixo de Informação.")
	_check(gerencia.resolve_next_map_district(&"suburbio") == &"suburbio",
		"Aos 18/20, o destino não é forçado.")
	_check(gerencia.grant_information(catalog[18] as Informacao,
		&"fixed_hex").get("success", false), "A 19ª Informação é válida.")
	_check(campaign.requires_final_center_map() \
		and gerencia.resolve_next_map_district(&"suburbio") == &"centro",
		"A próxima troca aos 19/20 ignora a distância até o Centro.")
	var rounds := RoundManager.new()
	rounds.gerencia = gerencia
	_check(rounds.available_districts() == [&"centro"],
		"A escolha regular só oferece o Centro.")
	var last_map := gerencia.prepare_map(catalog, &"suburbio",
		PPPMapGenerator.RoundPeriod.AFTERNOON, 20, rng)
	_check(last_map != null and _information_hex_count(last_map) == 1 \
		and last_map.ppp_background_path.contains("centro"),
		"O último mapa é do Centro e possui apenas uma Informação fixa.")
	campaign.district = &"centro"
	_check(gerencia.install_map(last_map) and campaign.final_center_intro_pending,
		"A primeira chegada forçada agenda a introdução preta.")
	var codec := CampaignSaveCodec.new()
	var saved := codec.encode(campaign)
	var restored := codec.decode(saved) as CampaignState
	_check(restored != null and restored.final_center_intro_pending,
		"O aviso pendente sobrevive a save/load.")
	_check(gerencia.grant_information(catalog[19] as Informacao,
		&"event_bonus").get("victory", false),
		"A 20ª parte por fonte extra conclui a campanha sem gerar outro mapa.")
	_check(not campaign.requires_final_center_map(),
		"O estado terminal não força outro destino.")
	var early := GerenciaJogo.new()
	root.add_child(early)
	_check(early.start_new_game(selected, EventCampaignEligibility.Mode.COMPLETE),
		"Segunda campanha testa vitória antecipada fora do Centro.")
	var early_catalog := early.get_information_catalog()
	for index in early_catalog.size():
		_check(early.grant_information(early_catalog[index] as Informacao,
			&"event_bonus").get("success", false),
			"Bônus extra concede a Informação %d." % index)
	_check(early.campaign.is_terminal() and early.campaign.district == &"suburbio"
		and early.campaign.generated_map_count == 0
		and not early.campaign.requires_final_center_map()
		and early.prepare_map(early_catalog, &"centro",
			PPPMapGenerator.RoundPeriod.MORNING, 1) == null,
		"20ª Informação antecipada encerra sem criar mapa adicional no Centro.")
	print("FINAL_CENTER_MAP_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _information_hex_count(grid: HexGrid) -> int:
	if grid == null:
		return -1
	var count := 0
	for coord in grid.cells:
		if grid.get_ppp_block_type(coord) == HexGrid.PPPBlockType.INFORMATION:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
