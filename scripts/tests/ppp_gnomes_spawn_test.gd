extends SceneTree

## Evento 09: surgimento no mapa, preservação de Informação e limite de
## três duendes resolvidos, exercendo a cadeia de janelas e Outcomes reais.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var gnomes := scene.get_node("Gnomes3Manager") as Gnomes3Manager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha para o evento dos cinco duendes.")
	var campaign := gerencia.campaign
	var grid := campaign.current_map
	var actor := campaign.active_entity_states[0]
	for member in campaign.active_entity_states:
		member.inventory_items.clear()
	var source := Vector2i(2, 1)
	var info_coord := Vector2i(3, 1)
	var occupied_coord := Vector2i(4, 1)
	actor.position = source
	campaign.active_entity_states[1].position = occupied_coord
	var information := load(
		"res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	grid.set_ppp_block(info_coord, HexGrid.PPPBlockType.INFORMATION, information)
	var event := load(
		"res://resources/events/random_events/09-gnomos_do_caos_3.tres") as EventData
	grid.set_ppp_block(source, HexGrid.PPPBlockType.EVENT, event)
	_check(block.begin_activation(source, actor), "Evento 09 abre a narrativa.")
	popup._confirm_event({})
	if popup._outcome_reading:
		popup._execute_prepared_event()
	var generated: Dictionary = {}
	var colors: Dictionary = {}
	for coord in grid.cells:
		var candidate := grid.get_ppp_block_resource(coord) as EventData
		if candidate != null and candidate in event.generated_events:
			generated[candidate.id] = coord
			var visual := grid.get_ppp_map_visual(coord)
			colors[visual] = true
	_check(not block.is_busy() and generated.size() == 5 \
		and colors.size() == 5 and gnomes._generated_paths.size() == 5,
		"Cinco duendes surgem com cinco cores sem associação fixa.")
	_check(grid.get_ppp_block_resource(info_coord) == information \
		and not generated.values().has(occupied_coord),
		"Informação e hex ocupado não são substituídos.")
	for id in [&"gn_00002", &"gn_00005", &"gn_00004"]:
		if not generated.has(id):
			continue
		var coord: Vector2i = generated[id]
		actor.position = coord
		_check(block.begin_activation(coord, actor), "Duende %s abre." % id)
		popup._confirm_event({})
		if popup._outcome_reading:
			popup._execute_prepared_event()
		_check(not block.is_busy(), "Duende %s conclui seu Outcome." % id)
	var remaining := 0
	for id in [&"gn_00001", &"gn_00003"]:
		if not generated.has(id):
			continue
		var cell := grid.get_cell(generated[id] as Vector2i)
		if cell != null and cell.state in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			remaining += 1
	_check(gnomes._activated_count == 3 and remaining == 0,
		"Após três duendes ativados, os dois restantes desaparecem.")
	var moving_gnomes := scene.get_node("Gnomes2Manager") as Gnomes2Manager
	for coord in grid.cells:
		grid.activate_ppp_block(coord)
	for coord in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]:
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.INFORMATION, information)
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	if encounter != null:
		for coord in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1)]:
			grid.set_ppp_block(coord, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	var started := moving_gnomes.start_effect()
	_check(started.get("success", false) and moving_gnomes.positions.size() == 3,
		"Evento 08 deve posicionar três gnomos em Informação/Encontro.")
	var first_gnome := moving_gnomes.positions[0]
	_check(grid.get_ppp_block_resource(first_gnome) != null,
		"Gnomo visual preserva o conteúdo original do hex.")
	moving_gnomes._on_actor_will_arrive(actor, first_gnome)
	_check(first_gnome not in moving_gnomes.positions,
		"O gnomo desaparece antes da chegada do personagem.")
	moving_gnomes._on_combat_prepared(null, [], [])
	_check(not moving_gnomes.visual_root.visible,
		"Gnomos visuais se escondem durante Encontro Indesejado.")
	moving_gnomes._on_combat_finished({})
	_check(moving_gnomes.visual_root.visible,
		"Gnomos retornam após o combate quando o efeito ainda vale.")
	moving_gnomes.stop_effect()
	var saci := load("res://resources/events/random_events/41-traquinagens_do_saci.tres") as EventData
	var saci_coord := Vector2i(4, 1)
	grid.set_ppp_block(saci_coord, HexGrid.PPPBlockType.EVENT, saci)
	var old_paths: Dictionary = {}
	for coord in grid.cells:
		old_paths[grid.get_cell(coord).resource_path] = true
	var effect := saci.outcomes[0].effects[0] as Event_EffectData
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var replaced := executor._apply_map_effect(effect,
		{"coord": saci_coord, "map": grid, "actor": actor},)
	_check(replaced.get("success", false), "Saci deve refazer a linha horizontal.")
	var new_paths: Dictionary = {}
	for column in HexGrid.PPP_MAP_WIDTH:
		var coord := Vector2i(column, saci_coord.y)
		var cell := grid.get_cell(coord)
		if column in [1, 2, 3]:
			_check(cell.block_type == HexGrid.PPPBlockType.INFORMATION
				and cell.resource_path == information.resource_path,
				"Saci preserva cada Informação da linha.")
		else:
			_check(cell.state == HexGrid.PPPBlockState.HIDDEN
				and not old_paths.has(cell.resource_path)
				and not new_paths.has(cell.resource_path),
				"Cada hex substituído recebe Resource novo, único e oculto.")
			new_paths[cell.resource_path] = true
	print("PPP gnomes spawn: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
