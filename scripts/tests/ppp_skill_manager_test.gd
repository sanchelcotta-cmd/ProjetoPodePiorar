extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var gerencia := GerenciaJogo.new()
	var block := BlockManager.new()
	var universal := SkillManager.new()
	var player := PlayerSkillManager.new()
	var exploration := ExplorationManager.new()
	block.gerencia = gerencia
	player.block_manager = block
	player.skill_manager = universal
	exploration.gerencia = gerencia
	exploration.block_manager = block
	exploration.player_skill_manager = player
	root.add_child(gerencia)
	root.add_child(block)
	root.add_child(universal)
	root.add_child(player)
	root.add_child(exploration)
	var chosen: Array[EntityData] = [
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(chosen), "A seleção deve criar a campanha.")
	var actor := gerencia.campaign.active_entity_states[0]
	var grants := universal.get_active_grants(actor)
	check(grants.size() == 1, "A Velha deve começar com sua Ativa inata.")
	var olhar := grants[0].skill as ActiveSkillData
	check(olhar.target_mode == ActiveSkillData.TargetMode.TILE, "Olhar Afiado deve escolher um hex.")
	check(olhar.effects[0].target == SkillEffectData.Target.SELECTED_TILE, "O efeito deve atingir o hex escolhido.")
	check(universal.get_passive_candidates(actor, PassiveSkillData.Trigger.ON_BEFORE_ATTACK, HexGrid.PPPMapMode.COMBAT).size() == 1, "A passiva inata deve ser encontrada pelo gatilho.")
	var event_grant := universal.grant_skill(actor, olhar, &"event", &"ev_900")
	var item_grant := universal.grant_skill(actor, olhar, &"item", &"item_instance_1")
	check(event_grant != null and item_grant != null, "Duas fontes podem conceder a mesma Skill.")
	check(universal.get_active_grants(actor).size() == 3, "Habilidades iguais acumulam por fonte.")
	check(universal.remove_source(actor, &"item", &"item_instance_1") == 1, "Desequipar retira só a concessão do item.")
	check(universal.get_active_grants(actor).size() == 2, "A inata e a recebida por evento permanecem.")
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	for coord in grid.cells:
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.INFORMATION, info)
	gerencia.campaign.current_map = grid
	check(exploration.enter_map(true), "O mapa deve iniciar na StartZone.")
	var target := Vector2i(0, 1)
	check(player.use_tile_active(actor, grants[0], target, exploration), "Olhar Afiado deve revelar o hex escolhido.")
	check(grid.get_cell(target).state == HexGrid.PPPBlockState.REVEALED, "Revelar não ativa o bloco.")
	check(not player.use_tile_active(actor, grants[0], Vector2i(0, 2), exploration), "A mesma fonte não revela duas vezes no turno.")
	check(player.use_tile_active(actor, event_grant, Vector2i(0, 2), exploration), "Uma segunda fonte tem seu próprio uso neste turno.")
	check(grid.get_cell(Vector2i(0, 2)).state == HexGrid.PPPBlockState.REVEALED, "O uso adicional também só revela.")
	var faro := load("res://resources/skills/actives/playables/jornalista/faro_jornalistico.tres") as ActiveSkillData
	var faro_grant := universal.grant_skill(actor, faro, &"event", &"ev_901")
	check(not player.use_tile_active(actor, faro_grant, Vector2i(1, 1), exploration), "Uso diário dinâmico não deve ser ignorado antes de implementar seu contador.")
	check(not gerencia.campaign.information_allows_round_advance(), "Revelar Informação não permite avançar.")
	check(exploration.current_actor == actor, "A Ativa não deve encerrar o turno da Velha.")
	check(exploration.try_move(target), "Depois da Ativa, a Velha ainda pode andar.")
	check(grid.get_cell(target).state == HexGrid.PPPBlockState.ACTIVATED, "Ao chegar, o bloco é ativado.")
	check(gerencia.campaign.information_allows_round_advance(), "Só a ativação concede Informação.")
	var unsupported := SkillEffectData.new()
	unsupported.effect_type = SkillEffectData.EffectType.APPLY_DEBUFF
	check(not universal.effect_executor.supports(unsupported), "Um enum sem executor não pode parecer implementado.")
	print("SKILL_MANAGER_TEST_OK" if failures == 0 else "SKILL_MANAGER_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
