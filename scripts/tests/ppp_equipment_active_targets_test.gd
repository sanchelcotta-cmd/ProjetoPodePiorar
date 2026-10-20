extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres")]
	_check(gerencia.start_new_game(choices), "Campanha para testar equipáveis inicia.")
	_check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Mapa para testar equipáveis inicia.")
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var actor := exploration.current_actor
	var grid := gerencia.campaign.current_map
	var cartola := load("res://resources/itens/equipments/acessorios/acessorio_epico_cartola_do_magico.tres") as ItemData
	var grant := skills.grant_skill(actor, cartola.granted_active_skills[0],
		&"item", &"test_cartola", gerencia.campaign)
	var destination := EntityState.UNPLACED
	for coord in grid.cells:
		if HexGrid.distance(actor.position, coord) > actor.max_stamina \
				and grid.can_choose_ppp_destination(coord, actor.position,
				exploration._occupied_coords()):
			destination = coord
			break
	_check(destination != EntityState.UNPLACED,
		"Existe hex distante livre para o teleporte.")
	if destination != EntityState.UNPLACED:
		var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
		grid.set_ppp_block(destination, HexGrid.PPPBlockType.INFORMATION, information)
		_check(exploration.player_skill_manager.use_tile_active(actor, grant,
			destination, exploration), "Cartola executa o teleporte no hex escolhido.")
		_check(actor.position == destination,
			"Cartola move o personagem mesmo além da Estamina.")
	print("EQUIPMENT_ACTIVE_TARGETS_OK" if failures == 0 else
		"EQUIPMENT_ACTIVE_TARGETS_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
