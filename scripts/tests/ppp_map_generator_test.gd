extends SceneTree

## Rodar com: godot --headless --path . --script res://scripts/tests/ppp_map_generator_test.gd
## Testa muitos sorteios sem alterar os Resources do jogo.
var failures := 0


func _initialize() -> void:
	var information: Array[Resource] = []
	information.append(load("res://resources/informacoes/orchestra/orchestra_1.tres"))
	information.append(load("res://resources/informacoes/orchestra/orchestra_2.tres"))
	for item in information:
		check(item != null, "Informação de teste precisa existir")
	if failures > 0:
		quit(1)
		return

	var lightning_maps_seen := 0
	var grey_maps_seen := 0
	for district in [&"suburbio", &"baixo_centro", &"centro"]:
		var backgrounds_seen: Dictionary = {}
		var district_index := [&"suburbio", &"baixo_centro", &"centro"].find(district)
		for period in [
			PPPMapGenerator.RoundPeriod.MORNING,
			PPPMapGenerator.RoundPeriod.AFTERNOON,
			PPPMapGenerator.RoundPeriod.NIGHT,
		]:
			for seed in 12:
				var rng := RandomNumberGenerator.new()
				rng.seed = seed + 1000 * period + 10000 * district_index
				var already_occurred: Array[StringName] = []
				if seed % 2 == 1:
					already_occurred.append(&"enc_00011") # A Experiência
				var grid := PPPMapGenerator.new().generate_new_map(
					information, district, period, {}, already_occurred, rng
				)
				check(grid != null, "Mapa deve ser gerado: %s, período %d, seed %d" % [district, period, seed])
				if grid != null:
					check_map(grid, period, already_occurred)
					if _has_lightning_event(grid):
						lightning_maps_seen += 1
					if grid.ppp_parallax_path.get_file().begins_with("cinzento_"):
						grey_maps_seen += 1
					var prefix := "cena_%s_" % str(district).replace("_", "")
					check(grid.ppp_background_path.get_file().begins_with(prefix),
						"Cenário deve corresponder ao distrito: %s" % district)
					check(ResourceLoader.exists(grid.ppp_background_path),
						"Cenário sorteado precisa ser um PNG importado")
					var sky_name := grid.ppp_parallax_path.get_file()
					var expected_sky := "manha_" if period == PPPMapGenerator.RoundPeriod.MORNING else \
						("tarde_" if period == PPPMapGenerator.RoundPeriod.AFTERNOON else "noite_")
					check(sky_name.begins_with(expected_sky) or \
						(period != PPPMapGenerator.RoundPeriod.NIGHT and sky_name.begins_with("cinzento_")),
						"Céu deve respeitar o horário: %s" % sky_name)
					check(grid.ppp_aura_parallax_path.get_file().begins_with("cinzento_"),
						"Áurea Fúnebre deve ter uma variante cinzenta pronta")
					check(grid.ppp_snow_parallax_path.get_file().begins_with("nevasca_"),
						"Nevasca deve ter uma variante de tempestade pronta")
					check(grid.ppp_parallax_filter == PPPParallaxBackground.SkyFilter.NONE,
						"Dia 1 nunca usa filtro vermelho ou verde")
					backgrounds_seen[grid.ppp_background_path] = true
		check(backgrounds_seen.size() >= 2,
			"Mapas do mesmo distrito devem variar entre seus cenários disponíveis")
	check(lightning_maps_seen > 0 and grey_maps_seen > 0,
		"A amostra deve exercitar tanto mapas com Evento de raio quanto céus cinzentos.")
	for scenario in [
		{"day": 1, "information": 0, "previous_map": false},
		{"day": 1, "information": 1, "previous_map": true},
		{"day": 2, "information": 0, "previous_map": true},
		{"day": 2, "information": 1, "previous_map": false},
		{"day": 2, "information": 1, "previous_map": true},
	]:
		for seed in 12:
			var balance_rng := RandomNumberGenerator.new()
			balance_rng.seed = 30100 + seed + 100 * int(scenario["day"]) + \
				1000 * int(scenario["information"]) + \
				10000 * int(scenario["previous_map"])
			var balance_grid := PPPMapGenerator.new().generate_new_map(
				information, &"suburbio", PPPMapGenerator.RoundPeriod.MORNING,
				{}, [], balance_rng, [], int(scenario["day"]), false,
				int(scenario["information"]), bool(scenario["previous_map"])
			)
			check(balance_grid != null, "Cenário de balanceamento deve gerar mapa: %s" % scenario)
			if balance_grid != null:
				check_balance_rules(balance_grid, scenario)
	var sky_rng := RandomNumberGenerator.new()
	sky_rng.seed = 48072
	var special_filters := 0
	var red_seen := false
	var green_seen := false
	for _index in 2000:
		var sky := PPPParallaxBackground.choose_visuals(
			PPPMapGenerator.RoundPeriod.MORNING, 2, sky_rng)
		match sky.get("filter", -1):
			PPPParallaxBackground.SkyFilter.RED:
				red_seen = true
				special_filters += 1
			PPPParallaxBackground.SkyFilter.GREEN:
				green_seen = true
				special_filters += 1
	check(special_filters >= 60 and special_filters <= 140 and red_seen and green_seen,
		"Do Dia 2 em diante, filtros especiais devem aparecer perto de 5% no total")
	for _index in 50:
		var sky_without_grey := PPPParallaxBackground.choose_visuals(
			PPPMapGenerator.RoundPeriod.MORNING, 1, sky_rng, false)
		check(not str(sky_without_grey.get("path", "")).get_file().begins_with("cinzento_"),
			"Se há Evento de raio, o sorteio principal exclui todos os céus cinzentos.")
	var campaign := CampaignState.new()
	check(campaign.activate_visual_catastrophe(CampaignState.AURA_FUNEBRE_EVENT_ID),
		"Áurea Fúnebre deve alterar o céu")
	check(campaign.activate_visual_catastrophe(CampaignState.NEVASCA_EVENT_ID),
		"Nevasca deve alterar o céu")
	check(campaign.get_active_visual_weather() == CampaignState.NEVASCA_EVENT_ID and \
		campaign.aura_funebre_day == campaign.day,
		"Última catástrofe prevalece visualmente sem apagar a primeira")
	check(campaign.activate_visual_catastrophe(CampaignState.PORTAIS_INFERNAIS_EVENT_ID) and \
		campaign.are_infernal_portals_visuals_active(),
		"Portais Infernais liga o filtro vermelho sem trocar o céu")
	campaign.round_period = PPPMapGenerator.RoundPeriod.AFTERNOON
	check(not campaign.are_infernal_portals_visuals_active() and \
		campaign.get_active_visual_weather() == CampaignState.NEVASCA_EVENT_ID,
		"Vermelho infernal acaba na próxima Rodada; Nevasca permanece até o Dia")
	campaign.day += 1
	check(campaign.get_active_visual_weather() == &"",
		"Céu de catástrofe acaba automaticamente na virada do Dia")

	if failures == 0:
		print("PPP MapGenerator: limites e variedade passaram em 168 mapas")
	else:
		push_error("PPP MapGenerator: %d teste(s) falharam" % failures)
	quit(1 if failures > 0 else 0)


func check_map(grid: HexGrid, period: int, already_occurred: Array[StringName]) -> void:
	check(grid.cells.size() == 40, "Mapa deve ter 40 hexágonos")
	var copies: Dictionary = {}
	var has_lightning_event := false
	for coord in grid.cells:
		var block_type := grid.get_ppp_block_type(coord)
		var content := grid.get_ppp_block_resource(coord)
		check(content != null, "Hexágono deve conter Resource: %s" % coord)
		if content == null:
			continue
		check(block_type not in [HexGrid.PPPBlockType.TRAP, HexGrid.PPPBlockType.CATASTROPHE],
			"Dia 1 sem Informação e no primeiro mapa não pode ter Armadilha/Catástrofe.")
		var path := content.resource_path
		if content is EventData and (content as EventData).id in PPPMapGenerator.LIGHTNING_EVENT_IDS:
			has_lightning_event = true
		copies[path] = int(copies.get(path, 0)) + 1
		var amount: int = copies[path]
		if block_type == HexGrid.PPPBlockType.INFORMATION:
			check(amount <= 1, "Informação não pode repetir: %s" % path)
		elif block_type in [HexGrid.PPPBlockType.EVENT, HexGrid.PPPBlockType.CATASTROPHE, HexGrid.PPPBlockType.TRAP]:
			check(amount <= 1, "Evento/Armadilha/Catástrofe não pode repetir: %s" % path)
		elif block_type == HexGrid.PPPBlockType.ENCOUNTER:
			var encounter := content as EncounterData
			check(encounter != null, "Bloco de Encontro deve conter EncounterData")
			if encounter != null:
				check(amount <= (1 if encounter.unique_encounter else 3), "Encontro repetido demais: %s" % path)
				check(not encounter.night_only or period == PPPMapGenerator.RoundPeriod.NIGHT, "Encontro noturno apareceu de dia: %s" % path)
				check(not (encounter.unique_encounter and encounter.id in already_occurred), "Encontro único já ocorrido voltou: %s" % path)
		elif block_type == HexGrid.PPPBlockType.CURSE:
			check(amount <= 1, "Maldição não pode repetir: %s" % path)
		elif block_type in [HexGrid.PPPBlockType.CONSUMABLE, HexGrid.PPPBlockType.EQUIPMENT]:
			check(amount <= 3, "Item repetido demais: %s" % path)
	check(not (has_lightning_event and grid.ppp_parallax_path.get_file().begins_with("cinzento_")),
		"Evento de raio e céu cinzento principal não coexistem no mapa.")


func check_balance_rules(grid: HexGrid, scenario: Dictionary) -> void:
	var valence_types: Dictionary = {}
	var free_types: Dictionary = {}
	for coord in grid.cells:
		var block_type := grid.get_ppp_block_type(coord)
		if block_type not in [HexGrid.PPPBlockType.TRAP, HexGrid.PPPBlockType.CATASTROPHE]:
			continue
		if bool(grid.get_ppp_block_data(coord).get("generated_from_random_block", false)):
			free_types[block_type] = true
		else:
			valence_types[block_type] = true
	var traps_allowed: bool = int(scenario["information"]) > 0 and bool(scenario["previous_map"])
	if not traps_allowed:
		check(not valence_types.has(HexGrid.PPPBlockType.TRAP) and \
			not free_types.has(HexGrid.PPPBlockType.TRAP),
			"Armadilha exige Informação obtida e mapa anterior: %s" % scenario)
	if int(scenario["day"]) <= 1:
		check(not valence_types.has(HexGrid.PPPBlockType.CATASTROPHE) and \
			not free_types.has(HexGrid.PPPBlockType.CATASTROPHE),
			"Catástrofe só aparece do Dia 2 em diante: %s" % scenario)
	for block_type in [HexGrid.PPPBlockType.TRAP, HexGrid.PPPBlockType.CATASTROPHE]:
		check(not (valence_types.has(block_type) and free_types.has(block_type)),
			"Tipo já sorteado por valência não pode ocupar bloco livre: %s / %s" % [scenario, block_type])


func _has_lightning_event(grid: HexGrid) -> bool:
	for coord in grid.cells:
		var event := grid.get_ppp_block_resource(coord) as EventData
		if event != null and event.id in PPPMapGenerator.LIGHTNING_EVENT_IDS:
			return true
	return false


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
