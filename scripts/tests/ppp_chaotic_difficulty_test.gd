extends SceneTree

## Rodar com: godot --headless --path . --script res://scripts/tests/ppp_chaotic_difficulty_test.gd
var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var information: Array[Resource] = [
		load("res://resources/informacoes/orchestra/orchestra_1.tres"),
		load("res://resources/informacoes/orchestra/orchestra_2.tres"),
	]
	var quota_signatures: Dictionary = {}
	var valence_signatures: Dictionary = {}
	var tested := 0
	for mode in [EventCampaignEligibility.Mode.SHORT,
			EventCampaignEligibility.Mode.MEDIUM,
			EventCampaignEligibility.Mode.COMPLETE]:
		for district in [&"suburbio", &"baixo_centro", &"centro"]:
			for period in [PPPMapGenerator.RoundPeriod.MORNING,
					PPPMapGenerator.RoundPeriod.AFTERNOON,
					PPPMapGenerator.RoundPeriod.NIGHT]:
				for seed in 3:
					var rng := RandomNumberGenerator.new()
					rng.seed = 10000 * mode + 1000 * int(period) + \
						100 * [&"suburbio", &"baixo_centro", &"centro"].find(district) + seed + 74001
					var generator := PPPMapGenerator.new()
					var first_map := seed == 0
					var grid := generator.generate_new_map(information, district, period,
						{}, [], rng, [], 1 if first_map else 2, false,
						0 if first_map else 1, not first_map, false, mode,
						true, GameDifficulty.Mode.CHAOTIC)
					_check(grid != null, "Caótico gera mapa: modo %d, distrito %s, período %d, seed %d." % [
						mode, district, period, seed])
					if grid == null:
						continue
					tested += 1
					_check(grid.cells.size() == 40, "Caótico preenche os 40 hexes.")
					var fixed_counts := {"information": 0, "consumable": 0,
						"equipment": 0, "encounter": 0, "event": 0}
					var valences := {EventData.Valence.GOOD: 0,
						EventData.Valence.AMBIGUOUS: 0, EventData.Valence.BAD: 0}
					var free_counts: Dictionary = {}
					var entry_item := false
					var seen_events: Dictionary = {}
					for coord in grid.cells:
						var block_type := grid.get_ppp_block_type(coord)
						var content := grid.get_ppp_block_resource(coord)
						_check(content != null, "Hex caótico tem Resource.")
						if content == null:
							continue
						if coord.x == 0 and block_type in [HexGrid.PPPBlockType.CONSUMABLE,
								HexGrid.PPPBlockType.EQUIPMENT]:
							entry_item = true
						if first_map:
							_check(block_type not in [HexGrid.PPPBlockType.TRAP,
								HexGrid.PPPBlockType.CATASTROPHE],
								"Primeiro mapa caótico respeita desbloqueios de perigos.")
						var is_free := bool(grid.get_ppp_block_data(coord).get(
							"generated_from_random_block", false))
						if is_free:
							free_counts[block_type] = int(free_counts.get(block_type, 0)) + 1
							_check(block_type != HexGrid.PPPBlockType.INFORMATION,
								"Caótico não sorteia segunda Informação em hex livre.")
						elif block_type == HexGrid.PPPBlockType.INFORMATION:
							fixed_counts["information"] += 1
						elif block_type == HexGrid.PPPBlockType.CONSUMABLE:
							fixed_counts["consumable"] += 1
						elif block_type == HexGrid.PPPBlockType.EQUIPMENT:
							fixed_counts["equipment"] += 1
						elif block_type == HexGrid.PPPBlockType.ENCOUNTER:
							fixed_counts["encounter"] += 1
						elif content is EventData:
							fixed_counts["event"] += 1
						if content is EventData:
							var event := content as EventData
							valences[event.valence] = int(valences.get(event.valence, 0)) + 1
							_check(not seen_events.has(event.resource_path),
								"Evento caótico não duplica Resource no mapa.")
							seen_events[event.resource_path] = true
							_check(EventCampaignEligibility.allows_event(event, mode),
								"Evento caótico respeita elegibilidade da campanha.")
					_check(entry_item, "Caótico garante um item na borda de entrada.")
					_check(fixed_counts["information"] == 1, "Caótico tem 1 Informação fixa.")
					var free_total := 0
					for block_type in free_counts:
						free_total += int(free_counts[block_type])
						var allowed := 2 if block_type in [HexGrid.PPPBlockType.CONSUMABLE,
							HexGrid.PPPBlockType.EQUIPMENT, HexGrid.PPPBlockType.EVENT,
							HexGrid.PPPBlockType.ENCOUNTER] else 1
						_check(int(free_counts[block_type]) <= allowed,
							"Repetição de tipo livre caótico respeita limite.")
					_check(free_total == 3, "Caótico tem 3 hexes livres.")
					var fixed_total := 0
					for count in fixed_counts.values():
						fixed_total += int(count)
					_check(fixed_total == 37, "Caótico tem 37 hexes fixos.")
					for category in PPPMapGenerator.CHAOTIC_BASE_COUNTS:
						_check(int(fixed_counts[category]) >= int(PPPMapGenerator.CHAOTIC_MIN_COUNTS[category])
							and int(fixed_counts[category]) <= int(PPPMapGenerator.CHAOTIC_MAX_COUNTS[category]),
							"Cota caótica %s dentro do intervalo." % category)
					quota_signatures[str(fixed_counts)] = true
					valence_signatures[str(valences)] = true
	_check(tested == 81, "Cobertura de 81 mapas caóticos em todos os tamanhos, distritos e períodos.")
	_check(quota_signatures.size() >= 4, "Composição de categorias varia entre mapas.")
	_check(valence_signatures.size() >= 4, "Valência varia sem cotas fixas.")
	var ally_rng := RandomNumberGenerator.new()
	ally_rng.seed = 95437
	var ally_grid := PPPMapGenerator.new().generate_new_map(information,
		&"suburbio", PPPMapGenerator.RoundPeriod.MORNING, {}, [],
		ally_rng, [], 2, false, 1, true, true,
		EventCampaignEligibility.Mode.MEDIUM, true, GameDifficulty.Mode.CHAOTIC)
	_check(ally_grid != null, "Caótico preserva mapa com aliado substituto obrigatório.")
	if ally_grid != null:
		var ally_count := 0
		for coord in ally_grid.cells:
			var event := ally_grid.get_ppp_block_resource(coord) as EventData
			if event != null and event.id == \
					(PPPMapGenerator.REPLACEMENT_ALLY_EVENT as EventData).id:
				ally_count += 1
		_check(ally_count == 1, "Aliado substituto obrigatório aparece uma única vez.")
	var catalog := CampaignState.new().get_playable_catalog()
	var party: Array[EntityData] = [catalog[0], catalog[1], catalog[2]]
	var campaign := CampaignState.new()
	_check(campaign.start_new_game(party, 12, null,
		EventCampaignEligibility.Mode.MEDIUM, [], GameDifficulty.Mode.CHAOTIC),
		"Campanha Média inicia diretamente no Caótico.")
	_check(campaign.request_difficulty(GameDifficulty.Mode.STANDARD),
		"Troca Caótico → Padrão fica disponível.")
	var codec := CampaignSaveCodec.new()
	var graph := codec.encode(campaign)
	var restored := codec.decode(graph) as CampaignState
	_check(restored != null and codec.error.is_empty() \
		and restored.difficulty == GameDifficulty.Mode.CHAOTIC \
		and restored.pending_difficulty == GameDifficulty.Mode.STANDARD,
		"Save preserva Caótico vigente e troca pendente separadamente.")
	print("PPP_CHAOTIC_DIFFICULTY_TEST_OK" if failures == 0 else \
		"PPP_CHAOTIC_DIFFICULTY_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
