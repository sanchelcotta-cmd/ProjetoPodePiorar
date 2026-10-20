extends SceneTree

## Exercita o ciclo mínimo jogável: turno, clique contextual, movimento,
## ataque, desfecho e restauração da Exploração.

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"A campanha inicia antes do teste de Combate.")
	var actor := gerencia.campaign.active_entity_states[0]
	# O sorteio inicial agora equipa uma arma comum; este teste verifica
	# explicitamente o ataque desarmado e precisa remover essa arma.
	var starting_equipment := EquipmentManager.new()
	for weapon in actor.equipped_in_slot(ItemData.EquipmentSlot.WEAPON).duplicate():
		check(starting_equipment.unequip(actor, weapon,
			scene.get_node("SkillManager") as SkillManager),
			"Arma inicial removida para testar o combate desarmado.")
	actor.position = Vector2i(3, 2)
	var companion_data := load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData
	var companion := EntityState.from_playable_selection(companion_data,
		&"Companion_Test", EntityState.UNPLACED)
	companion.playable_slot_id = &""
	check(gerencia.campaign.register_companion(actor, companion),
		"O aliado entra na campanha sob controle do jogador.")
	var grid := gerencia.campaign.current_map
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	gerencia.campaign.obtained_information_ids[&"combat_test_info"] = true
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(actor.position, actor), "O bloco de Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT and combat.enemies.size() == 1,
		"O Combate cria um inimigo e muda o modo do mapa.")
	check(grid.is_valid(companion.position) \
		and HexGrid.distance(companion.position, actor.position) == 1,
		"O aliado nasce adjacente ao dono quando há vaga livre.")
	var enemy := combat.enemies[0]
	var ordinary := load("res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var mirror := load("res://resources/entities/entities_general/uma_versao_do_mal.tres") as EntityData
	check(combat._has_encounter_stamina_rule(enemy.data)
		and combat._has_encounter_stamina_rule(mirror)
		and not combat._has_encounter_stamina_rule(ordinary),
		"Stamina fixa/copiada é exceção à rolagem de movimentação dos hostis comuns.")
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": actor})
	combat.initiative_order.append({"entity": companion})
	combat.initiative_order.append({"entity": enemy})
	combat._start_combat_turns()
	check(combat.current_actor == actor and combat.is_player_turn()
		and hud.combat_manager == combat,
		"A iniciativa abre o turno do jogável e a HUD recebe o CombatManager.")
	var enemy_start := enemy.position
	var health_before_ai := actor.current_health
	var companion_health_before_ai := companion.current_health
	var enemy_actions: Array[StringName] = []
	combat.action_resolved.connect(func(source: EntityState, action: StringName,
			_details: Dictionary) -> void:
		if source == enemy:
			enemy_actions.append(action))
	check(combat.end_current_turn(), "O jogador pode passar o turno.")
	await create_timer(0.12).timeout
	check(combat.current_actor == companion and combat.is_player_turn() \
		and combat._turn_die == 0,
		"Aliado aguarda comando e rolagem manual, sem usar a IA hostil.")
	check(combat.end_current_turn(), "O aliado também pode passar o turno.")
	await create_timer(1.15).timeout
	check(enemy.position != enemy_start or actor.current_health < health_before_ai \
		or companion.current_health < companion_health_before_ai \
		or &"attack" in enemy_actions,
		"A IA se aproxima ou tenta atacar; dano zero também conta como ação.")
	check(enemy.max_stamina == 1,
		"O Homem de Preto conserva a Stamina definida pela quantidade de Informações.")
	check(combat.current_actor == actor and combat.is_player_turn(),
		"Após o turno automático do inimigo, a iniciativa retorna ao jogável.")
	var available_before_roll := EntityState.UNPLACED
	for neighbor in HexGrid.get_neighbors(actor.position):
		if combat.can_preview_move(neighbor):
			available_before_roll = neighbor
			break
	check(available_before_roll != EntityState.UNPLACED,
		"A Estamina já mostra alcance antes de jogar o dado.")
	if available_before_roll != EntityState.UNPLACED:
		var yellow_hex := scene.get_node("MapRoot/Hexes/Hex_%d_%d" % [
			available_before_roll.x, available_before_roll.y]) as Area2D
		check(yellow_hex != null and yellow_hex.modulate == scene._renderer._palette.reachable_color,
			"O alcance de movimento em Combate mantém o amarelo da Exploração.")
	var enemy_screen := scene.get_hex_screen_position(enemy.position)
	combat._on_enemy_body_clicked(enemy, enemy_screen + Vector2(0.0, -70.0))
	check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() >= 2 \
		and (hud.hex_choice_buttons.get_child(0) as Button).text == "JOGAR DADO" \
		and (hud.hex_choice_buttons.get_child(1) as Button).text == "ATACAR" \
		and (hud.hex_choice_buttons.get_child(1) as Button).disabled,
		"Clicar no corpo inteiro abre dado e Ataque visível, bloqueado antes da rolagem.")
	check(not combat.can_player_move(Vector2i(3, 3)),
		"Sem rolagem manual, o movimento do jogável continua bloqueado.")
	check(combat.roll_player_turn_die() in range(1, 7),
		"Jogar dado habilita as ações do turno do jogável.")
	# A animação do dado depende dos frames renderizados; um tempo fixo pode
	# acabar antes da última piscada em máquinas mais lentas.
	for attempt in 40:
		if not hud._combat_roll_animating:
			break
		await create_timer(0.05).timeout
	check(not hud._combat_roll_animating,
		"Animação da rolagem terminou antes de escolher o destino.")
	var destination := EntityState.UNPLACED
	for neighbor in HexGrid.get_neighbors(enemy.position):
		if combat.can_player_move(neighbor):
			destination = neighbor
			break
	check(destination != EntityState.UNPLACED, "Há caminho para aproximar do inimigo.")
	if destination != EntityState.UNPLACED:
		var destination_cell := grid.get_cell(destination)
		destination_cell.block_type = HexGrid.PPPBlockType.INFORMATION
		destination_cell.state = HexGrid.PPPBlockState.ACTIVATED
		check(combat.can_player_move(destination),
			"Informação já ativada continua destino válido no Combate.")
		destination_cell.movement_blocked = true
		check(not combat.can_player_move(destination),
			"Uma condição própria do bloco pode vedar o movimento.")
		destination_cell.movement_blocked = false
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		scene._on_cell_pressed(destination, click)
		check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() > 0,
			"O clique no hex abre a ação contextual de Combate.")
		(hud.hex_choice_buttons.get_child(0) as Button).pressed.emit()
		check(actor.position == destination and combat._steps_moved > 0,
			"Andar até na HUD usa Stamina e altera o hex lógico do jogável.")
		var visual := (scene.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView) \
			.visuals_by_slot[actor.playable_slot_id] as PlayableActorVisual
		check(visual._walking, "O sprite do jogável entra na animação de caminhada em Combate.")
		await create_timer(0.27 * combat._steps_moved + 0.08).timeout
		check(visual.position.distance_to(PPPMapView.reference_hex_position(destination)) < 1.0,
			"O sprite caminha até o hex lógico, sem ficar parado na origem.")
		check(not combat.can_player_move(destination),
			"O mesmo turno não permite um segundo movimento comum.")
	check(combat.can_player_attack(enemy.position),
		"Após mover, o ataque adjacente fica disponível.")
	check(not combat._uses_ranged_attack(actor),
		"O Jornalista desarmado é corpo a corpo apesar da Maestria Distância.")
	combat._turn_die = 6
	var attack_results: Array[Dictionary] = []
	combat.action_resolved.connect(func(_source: EntityState, action: StringName,
			details: Dictionary) -> void:
		if action == &"attack":
			attack_results.append(details))
	enemy.current_health = 1
	var attack_click := InputEventMouseButton.new()
	attack_click.button_index = MOUSE_BUTTON_LEFT
	attack_click.pressed = true
	scene._on_cell_pressed(enemy.position, attack_click)
	check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() > 0,
		"Clicar no hex hostil oferece o ataque contextual.")
	(hud.hex_choice_buttons.get_child(0) as Button).pressed.emit()
	check(enemy.current_health <= 0, "Ataque da HUD resolve dano.")
	check(not attack_results.is_empty() and
		int(attack_results[-1].get("raw_damage", -1)) ==
		actor.attack + 6 - combat._steps_moved + 2,
		"Desarmado com 6 no dado recebe crítico +2, sem Maestria da arma.")
	check((scene.get_node("MapRoot/DepthSorted/EnemyActors") as Node2D) \
		.get_node_or_null("DamagePopup") != null,
		"O dano aparece como pop vermelho acima do alvo.")
	check(enemy.current_health <= 0 and not combat.pending_conclusion.is_empty(),
		"Derrubar o último hostil solicita a janela de vitória.")
	await create_timer(0.44).timeout
	check(popup.overlay.visible and popup.conclusion_title.text == "Vocês venceram",
		"O desfecho aparece antes de retornar à Exploração.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION and not block.is_busy(),
		"Confirmar o desfecho restaura a Exploração.")
	print("PPP combat turn: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
