extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var gerencia := GerenciaJogo.new()
	var block := BlockManager.new()
	var player := PlayerSkillManager.new()
	var skills := SkillManager.new()
	var exploration := ExplorationManager.new()
	block.gerencia = gerencia
	player.block_manager = block
	player.skill_manager = skills
	exploration.gerencia = gerencia
	exploration.block_manager = block
	exploration.player_skill_manager = player
	for node in [gerencia, block, player, skills, exploration]:
		root.add_child(node)
	var chosen: Array[EntityData] = [
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(chosen), "Campanha deve iniciar.")
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	gerencia.campaign.current_map = _grid_with_information(info)
	check(exploration.enter_map(true), "Primeiro mapa deve abrir.")
	var actor := exploration.current_actor
	var grant := skills.get_active_grants(actor)[0]
	check(player.use_exploration_active(actor, grant, EntityState.UNPLACED, exploration), "Multitarefa Nervosa deve conceder um movimento extra.")
	check(actor.extra_movement_sources.size() == 1, "O movimento extra guarda sua origem.")
	check(actor.max_stamina == 5, "Ativar sem se mover não cobra penalidade.")
	check(exploration.try_move(Vector2i(0, 1)), "Primeiro percurso deve funcionar.")
	check(exploration.current_actor == actor, "Após o primeiro bloco, o turno continua.")
	check(actor.max_stamina == 5, "Primeiro movimento não cobra penalidade.")
	check(exploration.try_move(Vector2i(1, 1)), "Segundo percurso deve funcionar.")
	check(actor.max_stamina == 4 and actor.round_stamina_penalty == 1, "Segundo percurso reduz a Estamina máxima em 1.")
	check(exploration.current_actor != actor, "Após o segundo bloco, o turno acaba.")
	gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.AFTERNOON
	gerencia.campaign.current_map = _grid_with_information(info)
	check(exploration.enter_map(true), "Nova Rodada deve abrir outro mapa.")
	check(actor.max_stamina == 5 and actor.round_stamina_penalty == 0, "Penalidade expira na nova Rodada.")
	# Também pode escolher a Ativa só DEPOIS do primeiro deslocamento.
	check(exploration.try_move(Vector2i(0, 1)),
		"Primeiro movimento sem pré-ativar a habilidade funciona.")
	check(actor.turn_state == EntityState.TurnState.INACTIVE \
		and exploration.current_actor != actor,
		"Depois do primeiro movimento, o Universitário fica inativo.")
	check(exploration.can_reactivate_extra_movement(actor, grant) \
		and exploration.reactivate_extra_movement(actor, grant),
		"Multitarefa Nervosa reabre o mesmo turno entre ações.")
	check(exploration.current_actor == actor and actor.extra_movement_sources.size() == 1,
		"Reativação concede exatamente o movimento extra.")
	check(exploration.try_move(Vector2i(1, 1)) \
		and actor.round_stamina_penalty == 1,
		"O segundo movimento reativado cobra a penalidade prevista.")
	print("EXTRA_MOVEMENT_TEST_OK" if failures == 0 else "EXTRA_MOVEMENT_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _grid_with_information(info: Informacao) -> HexGrid:
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	for coord in grid.cells:
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.INFORMATION, info)
	return grid


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
