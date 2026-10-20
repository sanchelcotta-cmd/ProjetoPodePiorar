extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gerencia := GerenciaJogo.new()
	var block := BlockManager.new()
	var skills := PlayerSkillManager.new()
	var skill_manager := SkillManager.new()
	var exploration := ExplorationManager.new()
	var executor := EventExecutor.new()
	block.gerencia = gerencia
	skills.block_manager = block
	skills.skill_manager = skill_manager
	exploration.gerencia = gerencia
	exploration.block_manager = block
	exploration.player_skill_manager = skills
	executor.gerencia = gerencia
	executor.block_manager = block
	executor.skill_manager = skill_manager
	executor.exploration = exploration
	for node in [gerencia, block, skills, skill_manager, exploration, executor]:
		root.add_child(node)
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected), "Campanha dos eventos de mundo inicia.")
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	for coord in grid.cells:
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.INFORMATION, info)
		grid.activate_ppp_block(coord)
	var destination := Vector2i(1, 1)
	grid.set_ppp_block(destination, HexGrid.PPPBlockType.INFORMATION, info)
	var teleport_event := load(
		"res://resources/events/random_events/30-voce_foi_teletransportado.tres") as EventData
	grid.set_ppp_block(Vector2i(0, 1), HexGrid.PPPBlockType.EVENT, teleport_event)
	_check(gerencia.install_map(grid) and exploration.enter_map(true),
		"Mapa controlado inicia a Exploração.")
	var teleported := exploration.current_actor
	_check(exploration.try_move(Vector2i(0, 1)) and block.is_busy(),
		"Ativação real do hex inicia o Evento 30.")
	_check(executor.apply_prepared_result()
		and executor._queued_world_transition.get("destination") == destination,
		"Outcome agenda teleporte para o único outro bloco disponível.")
	_check(executor.acknowledge_result(),
		"Após o OK, teleporte ativa o bloco de chegada.")
	_check(teleported.position == destination
		and grid.get_cell(destination).state == HexGrid.PPPBlockState.ACTIVATED,
		"O personagem chega e resolve o bloco sorteado.")
	var portal_actor := exploration.current_actor
	var portal_event := load(
		"res://resources/events/random_events/31-portal_magico.tres") as EventData
	var portal_effect := portal_event.outcomes[0].effects[0] as Event_EffectData
	var original_day := gerencia.campaign.day
	var original_period := gerencia.campaign.round_period
	var prepared := executor._prepare_world_effect(portal_effect,
		{"actor": portal_actor, "coord": portal_actor.position,
			"map": gerencia.campaign.current_map})
	_check(prepared.get("success", false), "Portal prepara mapa de distrito aleatório.")
	var portal_map := executor._queued_world_transition.get("map") as HexGrid
	_check(executor._perform_world_transition(executor._queued_world_transition),
		"Portal instala novo mapa e encerra o turno, sem ativar a chegada.")
	_check(gerencia.campaign.current_map == portal_map
		and gerencia.campaign.day == original_day
		and gerencia.campaign.round_period == original_period,
		"Portal preserva Dia e Rodada.")
	var abducted := exploration.current_actor
	var abduction := load(
		"res://resources/events/random_events/29-voces_foram_abduzidos.tres") as EventData
	var day_effect := abduction.outcomes[0].effects[0] as Event_EffectData
	var map_effect := abduction.outcomes[0].effects[1] as Event_EffectData
	executor._queued_day_advance = 0
	_check(executor._prepare_world_effect(day_effect,
		{"actor": abducted}).get("success", false),
		"Abdução agenda o avanço de um Dia.")
	prepared = executor._prepare_world_effect(map_effect,
		{"actor": abducted, "coord": abducted.position,
			"map": gerencia.campaign.current_map})
	_check(prepared.get("success", false)
		and prepared.get("arrival_activates", false),
		"Abdução prepara mapa e ativação do bloco de chegada.")
	var abducted_map := executor._queued_world_transition.get("map") as HexGrid
	_check(executor._perform_world_transition(executor._queued_world_transition),
		"Abdução instala o novo mapa e inicia a chegada.")
	_check(gerencia.campaign.day == original_day + 1
		and gerencia.campaign.round_period == original_period
		and gerencia.campaign.current_map == abducted_map
		and abducted_map.is_valid(abducted.position),
		"Abdução avança um Dia, mantém a fase e coloca o ativador no novo mapa.")
	print("PPP world transitions: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
