extends SceneTree

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as Node
	# Este teste isola a preparação/encerramento; o ciclo de turnos tem teste próprio.
	combat.set("auto_start_turns", false)
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var visual_root := scene.get_node("MapRoot/DepthSorted/EnemyActors") as Node2D
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha precisa iniciar.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(3, 2)
	var grid := gerencia.campaign.current_map
	var occupied: Dictionary = {}
	for playable in gerencia.campaign.active_entity_states:
		occupied[playable.position] = true
	var forced_distant_occupancy := occupied.duplicate()
	for coord in grid.cells:
		if HexGrid.distance(actor.position, coord) in [2, 3]:
			forced_distant_occupancy[coord] = true
	var distant_candidate: Vector2i = combat.call("_choose_spawn", grid, actor,
		forced_distant_occupancy)
	check(distant_candidate != EntityState.UNPLACED
		and HexGrid.distance(actor.position, distant_candidate) >= 4,
		"Com as faixas 2 e 3 ocupadas, spawn se afasta para 4+ sem usar distância 1.")
	var plant := load("res://resources/entities/entities_general/planta_carnivora.tres") as EntityData
	var roots := load("res://resources/entities/entities_general/raizes_mutantes.tres") as EntityData
	var dynamic_stamina := load("res://resources/entities/entities_general/homem_de_preto.tres") as EntityData
	check(combat.call("_is_immobile_enemy", plant)
		and combat.call("_is_immobile_enemy", roots)
		and not combat.call("_is_immobile_enemy", dynamic_stamina),
		"Spawn imóvel reconhece PREVENT_MOVEMENT, não apenas Stamina base zero.")
	var only_interior_free: Dictionary = {}
	for coord in grid.cells:
		if coord != Vector2i(3, 2):
			only_interior_free[coord] = true
	check(combat.call("_choose_immobile_spawn", grid, only_interior_free) == Vector2i(3, 2),
		"Hostil imóvel pode nascer até em hex interior adjacente, ignorando distância mínima.")
	var men := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.ENCOUNTER, men)
	check(block.begin_activation(actor.position, actor), "Encontro abre antes do Combate.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT
		and combat.get("enemies").size() == 1 and visual_root.get_child_count() == 1
		and combat.get("initiative_order").size() == 4 and not popup.overlay.visible,
		"Homem de Preto aparece e iniciativa é montada antes da fala.")
	var enemy := combat.get("enemies")[0] as EntityState
	check(enemy.attack == 0 and enemy.max_stamina == 0,
		"Sem Informação, Homem de Preto fica com Ataque e Stamina zero.")
	check(HexGrid.distance(actor.position, enemy.position) >= 2,
		"Inimigo nasce a pelo menos 2 hexes do ativador quando há espaço.")
	for other in gerencia.campaign.active_entity_states:
		if other != actor:
			check(HexGrid.distance(actor.position, enemy.position)
				< HexGrid.distance(other.position, enemy.position),
				"Inimigo aparece mais perto do ativador que dos demais.")
	await create_timer(0.44).timeout
	check(popup.overlay.visible and popup.narrative_label.text
		== "Vocês percebem o desdêm naqueles olhos. Eles vão embora..."
		and block.is_busy(), "A saída especial espera confirmação após o preparo.")
	check(popup.frame_rect.texture.resource_path.ends_with("uielementx_00005.png")
		and (popup.frame_rect.material as ShaderMaterial).shader.resource_path
		.ends_with("ui_cyan_to_white_80.gdshader")
		and not popup.title_banner.visible,
		"A fala usa a moldura branca uielementx_00005 com título interno.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION
		and not block.is_busy() and visual_root.get_child_count() == 0,
		"OK encerra o encontro especial e volta à Exploração.")
	var beetle := load("res://resources/encounters/enc_barata_voadora.tres") as EncounterData
	var next_coord := Vector2i(4, 2)
	actor.position = next_coord
	grid.set_ppp_block(next_coord, HexGrid.PPPBlockType.ENCOUNTER, beetle)
	check(block.begin_activation(next_coord, actor), "Segundo Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT
		and not combat.get("enemies").is_empty(),
		"Combate normal monta seus inimigos e permanece pendente.")
	var positions: Array[Vector2i] = []
	for playable in gerencia.campaign.active_entity_states:
		positions.append(playable.position)
	gerencia.campaign.active_entity_states[0].position = Vector2i(0, 0)
	gerencia.campaign.active_entity_states[1].position = Vector2i(1, 0)
	gerencia.campaign.active_entity_states[2].position = Vector2i(2, 0)
	var right_spawn: Vector2i = combat.call("choose_summon_spawn")
	check(right_spawn.x >= 6, "Grupo à esquerda faz invocação surgir nas duas colunas direitas.")
	gerencia.campaign.active_entity_states[0].position = Vector2i(0, 0)
	gerencia.campaign.active_entity_states[1].position = Vector2i(6, 0)
	gerencia.campaign.active_entity_states[2].position = Vector2i(7, 0)
	var left_spawn: Vector2i = combat.call("choose_summon_spawn")
	check(left_spawn.x <= 1,
		"Se dois de três jogáveis estão à direita, a invocação prefere as colunas esquerdas.")
	for index in gerencia.campaign.active_entity_states.size():
		gerencia.campaign.active_entity_states[index].position = positions[index]
	var summon_data := load("res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var original_enemy_count: int = combat.get("enemies").size()
	var summoned: EntityState = combat.call("spawn_summoned_enemy", summon_data,
		combat.get("enemies")[0])
	check(summoned != null and summoned.position.x in [0, 1, 6, 7]
		and visual_root.get_child_count() == original_enemy_count + 1
		and summoned.summoned_by_instance_id != &"",
		"Invocação cria instância e silhueta apenas nas duas colunas externas.")
	var enemy_list: Array[EntityState] = combat.get("enemies")
	var temporary_occupants: Array[EntityState] = []
	for coord in grid.cells:
		if coord.x not in [0, 1, 6, 7]:
			continue
		var already_occupied := false
		for playable in gerencia.campaign.active_entity_states:
			already_occupied = already_occupied or playable.position == coord
		for existing in enemy_list:
			already_occupied = already_occupied or existing.position == coord
		if already_occupied:
			continue
		var occupant := EntityState.new()
		occupant.position = coord
		occupant.current_health = 1
		enemy_list.append(occupant)
		temporary_occupants.append(occupant)
	check(combat.call("choose_summon_spawn") == EntityState.UNPLACED,
		"Invocação móvel sem colunas externas livres não encontra destino.")
	var immobile_summon: EntityState = combat.call("spawn_summoned_enemy", plant, summoned)
	check(immobile_summon != null and immobile_summon.position.x in [2, 3, 4, 5],
		"Invocação imóvel ignora colunas externas lotadas e nasce em hex livre interior.")
	for occupant in temporary_occupants:
		enemy_list.erase(occupant)
	var chocolate := load("res://resources/itens/consumables/chocolate.tres") as ItemData
	var prizes: Array[Resource] = [chocolate]
	check(combat.call("request_victory", prizes), "Executor pode pedir a janela de vitória.")
	await create_timer(0.44).timeout
	check(popup.overlay.visible and popup.conclusion_title.text == "Vocês venceram"
		and popup.rewards_container.get_child_count() == 1
		and grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT,
		"Vitória mostra recompensa e mantém Combate até confirmação.")
	var safe_area := popup.frame_rect.get_global_rect().grow(-26.0)
	check(safe_area.encloses(popup.conclusion_title.get_global_rect())
		and safe_area.encloses(popup.buttons.get_global_rect())
		and safe_area.encloses(popup.rewards_container.get_global_rect()),
		"Título, recompensa e botão ficam afastados da moldura branca.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION
		and not block.is_busy() and not popup.overlay.visible,
		"Prosseguir fecha vitória e restaura a Exploração.")
	gerencia.campaign.obtained_information_ids[&"info_test_1"] = true
	var third_coord := Vector2i(5, 2)
	actor.position = third_coord
	grid.set_ppp_block(third_coord, HexGrid.PPPBlockType.ENCOUNTER, men)
	check(block.begin_activation(third_coord, actor),
		"Homem de Preto pode reaparecer com Informação.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(combat.get("enemies").size() == 1
		and (combat.get("enemies")[0] as EntityState).attack == 2
		and (combat.get("enemies")[0] as EntityState).max_stamina == 2
		and (combat.get("pending_conclusion") as Dictionary).is_empty(),
		"Com Informação, passiva define Ataque/Stamina e não encerra o Combate.")
	var no_prizes: Array[Resource] = []
	check(combat.call("request_victory", no_prizes), "Vitória sem loot também pode ser apresentada.")
	await create_timer(0.44).timeout
	check(popup.overlay.visible and popup.rewards_container.get_child_count() == 0,
		"Janela de vitória sem recompensas não exibe itens fictícios.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	popup._input(escape)
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION
		and not block.is_busy() and not popup.overlay.visible,
		"ESC confirma o desfecho e devolve a Exploração.")
	print("PPP combat entry: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
