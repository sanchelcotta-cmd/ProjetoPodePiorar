extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var gerencia := GerenciaJogo.new()
	var block := BlockManager.new()
	var skills := PlayerSkillManager.new()
	var skill_manager := SkillManager.new()
	var exploration := ExplorationManager.new()
	block.gerencia = gerencia
	skills.block_manager = block
	skills.skill_manager = skill_manager
	exploration.gerencia = gerencia
	exploration.block_manager = block
	exploration.player_skill_manager = skills
	root.add_child(gerencia)
	root.add_child(block)
	root.add_child(skills)
	root.add_child(skill_manager)
	root.add_child(exploration)
	var selected: Array[EntityData] = []
	selected.append(load("res://resources/entities/entities_playable/universitario.tres") as EntityData)
	selected.append(load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData)
	selected.append(load("res://resources/entities/entities_playable/mae.tres") as EntityData)
	check(gerencia.start_new_game(selected), "A seleção inicial deve funcionar.")
	var first_actor := gerencia.campaign.active_entity_states[0]
	first_actor.current_health -= 3
	var start_heal := SkillEffectData.new()
	start_heal.effect_type = SkillEffectData.EffectType.HEAL_FIXED
	start_heal.target = SkillEffectData.Target.SELF
	start_heal.amount = 1
	var start_passive := PassiveSkillData.new()
	start_passive.trigger = PassiveSkillData.Trigger.ON_TURN_START
	start_passive.activation_context = PassiveSkillData.ActivationContext.EXPLORATION
	start_passive.effects.append(start_heal)
	check(skill_manager.grant_skill(first_actor, start_passive, &"test", &"one_turn_start") != null,
		"Passiva de início de turno para detectar disparo duplicado.")
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	var bad_event := load("res://resources/events/random_events/33-tropeco_perigoso.tres") as EventData
	check(information != null and bad_event != null, "Resources de teste precisam carregar.")
	var grid := _make_grid(information, bad_event)
	gerencia.campaign.current_map = grid
	check(exploration.enter_map(true), "Deve posicionar os três na StartZone.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1", "Ordem inicial deve começar na vaga 1.")
	var health_after_turn_start := first_actor.current_health
	check(health_after_turn_start == first_actor.max_health - 2,
		"A passiva deve disparar no primeiro início de turno.")
	check(exploration.select_next_available_actor(),
		"O jogador pode escolher a próxima vaga disponível pelo controle normal.")
	check(exploration.current_actor.playable_slot_id == &"Playable_2",
		"A próxima vaga disponível é Playable_2.")
	check(exploration.select_next_available_actor(), "A escolha percorre as vagas.")
	check(exploration.current_actor.playable_slot_id == &"Playable_3",
		"A terceira vaga pode ser selecionada.")
	check(exploration.select_next_available_actor(), "Pode voltar à primeira vaga.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1",
		"Voltar à primeira vaga não inicia outro ciclo.")
	skills.on_owner_turn_started(first_actor, gerencia.campaign)
	check(first_actor.current_health == health_after_turn_start,
		"Uma notificação duplicada ao PlayerSkillManager não reaplica a passiva.")
	check(exploration.select_actor(&"Playable_3"), "É permitido antecipar uma vaga disponível.")
	check(exploration.select_actor(&"Playable_1"), "Pode voltar à vaga 1 antes de agir.")
	check(first_actor.current_health == health_after_turn_start,
		"Voltar à mesma vaga não reaplica efeito de início de turno.")
	check(exploration.select_actor(&"Playable_3"), "Pode escolher novamente a vaga 3.")
	check(exploration.current_actor.position == Vector2i(-1, 3), "Vaga 3 deve estar na StartZone.")
	var stamina_before_entry := gerencia.campaign.active_entity_states[2].stamina_remaining
	check(exploration.try_move(Vector2i(0, 3)), "Vaga 3 deve entrar no mapa.")
	check(gerencia.campaign.active_entity_states[2].stamina_remaining == stamina_before_entry - 1,
		"Entrada deve custar 1 Stamina, independentemente do equipamento inicial.")
	check(gerencia.campaign.active_entity_states[2].turn_state == EntityState.TurnState.INACTIVE, "Ativar Informação encerra o turno.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1", "Deve sugerir a próxima vaga disponível.")
	check(exploration.select_next_available_actor() \
		and exploration.current_actor.playable_slot_id == &"Playable_2",
		"A seleção pula a vaga 3, cujo turno já terminou.")
	check(exploration.select_actor(&"Playable_1"),
		"Pode voltar à vaga 1 antes de agir.")
	check(not exploration.try_move(Vector2i(7, 1)), "Não pode chegar além da Stamina.")
	var stamina_before_long_walk := gerencia.campaign.active_entity_states[0].stamina_remaining
	check(exploration.try_move(Vector2i(2, 1)), "Deve percorrer três hexes em um movimento.")
	check(gerencia.campaign.active_entity_states[0].stamina_remaining == stamina_before_long_walk - 3,
		"Três passos custam 3, sem resetar Stamina.")
	check(grid.get_cell(Vector2i(0, 1)).state == HexGrid.PPPBlockState.HIDDEN, "Hexes atravessados não ativam.")
	check(exploration.current_actor.playable_slot_id == &"Playable_2", "Pedreiro deve receber o próximo turno.")
	check(not exploration.try_move(Vector2i(2, 1)), "Não pode terminar no hex ocupado.")
	check(exploration.try_move(Vector2i(0, 2)), "Pedreiro deve chegar ao Evento Ruim.")
	check(not block.is_busy(), "Escolha preventiva vem antes da ativação do Evento.")
	check(skills.has_pending_choice(), "A escolha deve pertencer ao gerenciador de Skills.")
	check(not exploration.try_move(Vector2i(1, 2)), "Não pode andar durante escolha pendente.")
	check(skills.answer_pre_activation_choice(skills.get_pending_options()[0]), "Pedreiro deve poder destruir o Evento.")
	check(grid.get_cell(Vector2i(0, 2)).state == HexGrid.PPPBlockState.DESTROYED, "Evento deve ser destruído.")
	check(gerencia.campaign.get_events_on_standby().has(bad_event.resource_path), "Evento impedido entra em standby.")
	check(exploration.cycle_number == 2, "Após três turnos começa novo ciclo, sem avançar Rodada.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1", "Novo ciclo começa sugerindo vaga 1.")
	check(gerencia.campaign.active_entity_states[0].stamina_remaining == first_actor.max_stamina,
		"Novo ciclo repõe Stamina até o máximo atual.")
	# Um Portal cria mapa na mesma Rodada: posições reiniciam, turnos e Stamina não.
	exploration.current_actor.stamina_remaining = 2
	var same_round_grid := _make_grid(information, bad_event)
	gerencia.campaign.current_map = same_round_grid
	check(exploration.enter_map(false), "Novo mapa da mesma Rodada deve ser aceito.")
	check(exploration.current_actor.position == Vector2i(-1, 1), "Portal reposiciona na StartZone.")
	check(exploration.current_actor.stamina_remaining == 2, "Portal preserva Stamina.")
	check(exploration.cycle_number == 2, "Portal não reinicia ciclo de Exploração.")
	same_round_grid.set_ppp_block(Vector2i(0, 1), HexGrid.PPPBlockType.EVENT, bad_event)
	check(exploration.try_move(Vector2i(0, 1)), "Jogável comum deve ativar Evento ao chegar.")
	check(block.is_busy(), "Exploração espera o executor do Evento.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1", "Turno não acaba antes do Evento.")
	check(not exploration.select_actor(&"Playable_2"), "Não pode trocar enquanto o bloco está pendente.")
	check(not exploration.select_next_available_actor(),
		"Não troca de personagem com resolução pendente.")
	check(block.finish_event_resolution(), "Evento de teste deve ser concluído.")
	check(exploration.current_actor.playable_slot_id == &"Playable_2", "Turno acaba após os efeitos.")
	var next_round_grid := _make_grid(information, bad_event)
	gerencia.campaign.current_map = next_round_grid
	check(exploration.enter_map(true), "Nova Rodada deve iniciar mapa e ciclo novos.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1", "Nova Rodada retoma ordem padrão.")
	check(gerencia.campaign.active_entity_states[0].stamina_remaining == first_actor.max_stamina,
		"Nova Rodada repõe Stamina até o máximo atual.")
	gerencia.campaign.day = 2 # A Skill diária do Pedreiro está disponível de novo.
	check(exploration.select_actor(&"Playable_2"), "Pedreiro pode ser escolhido antes da ação.")
	check(exploration.try_move(Vector2i(0, 2)), "Pedreiro deve receber nova oferta de Skill.")
	check(skills.has_pending_choice(), "A oferta fica no gerenciador de Skills.")
	check(skills.answer_pre_activation_choice(), "Recusar Skill deve ativar o Evento normalmente.")
	check(block.is_busy(), "Evento recusado deve aguardar seu executor.")
	check(block.finish_event_resolution(), "Executor deve concluir o Evento recusado.")
	check(exploration.current_actor.playable_slot_id == &"Playable_1", "Depois dos efeitos, o turno termina.")
	# A exceção pertence ao jogável ilhado, mesmo quando outro ainda consegue
	# alcançar um bloco. Ela não altera permanentemente sua Estamina.
	var stranded_grid := _make_grid(information, bad_event)
	for coord in stranded_grid.cells:
		stranded_grid.activate_ppp_block(coord)
	stranded_grid.set_ppp_block(Vector2i(7, 1), HexGrid.PPPBlockType.INFORMATION, information)
	stranded_grid.set_ppp_block(Vector2i(0, 2), HexGrid.PPPBlockType.INFORMATION, information)
	gerencia.campaign.current_map = stranded_grid
	check(exploration.enter_map(true), "Mapa isolado deve iniciar a Exploração.")
	var stranded_actor := exploration.current_actor
	stranded_actor.stamina_remaining = 1
	var far_destination := Vector2i(7, 1)
	check(exploration.get_available_destinations().has(Vector2i(0, 2))
		and not exploration.get_available_destinations().has(far_destination),
		"O jogável ilhado pode ir ao bloco mais próximo mesmo se outro puder avançar.")
	stranded_grid.activate_ppp_block(Vector2i(0, 2))
	stranded_grid.set_ppp_block(Vector2i(6, 1), HexGrid.PPPBlockType.INFORMATION, information)
	check(exploration.get_available_destinations().has(Vector2i(6, 1))
		and not exploration.get_available_destinations().has(far_destination),
		"A exceção oferece só o destino disponível mais próximo.")
	stranded_grid.activate_ppp_block(Vector2i(6, 1))
	check(exploration.get_available_destinations().has(far_destination),
		"Se ninguém alcança um bloco disponível, o mais próximo fica selecionável.")
	check(exploration.try_move(far_destination),
		"O personagem deve conseguir andar até o bloco excepcional.")
	check(stranded_actor.position == far_destination and stranded_actor.stamina_remaining == 0,
		"O movimento excepcional chega ao destino sem deixar Stamina negativa.")
	print("EXPLORATION_MANAGER_TEST_OK" if failures == 0 else "EXPLORATION_MANAGER_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)

func _make_grid(information: Informacao, bad_event: EventData) -> HexGrid:
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	for coord in grid.cells:
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.INFORMATION, information)
	grid.set_ppp_block(Vector2i(0, 2), HexGrid.PPPBlockType.EVENT, bad_event)
	return grid

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
