extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var playables: Array[EntityData] = [
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
	]
	check(game.start_new_game(playables) and round_manager.start_first_map(),
		"Partida inicia com a Velha ativa.")
	var velha := game.campaign.active_entity_states[0]
	check(exploration.current_actor == velha, "A Velha tem o turno aberto.")
	var spy_armor := load(
		"res://resources/itens/equipments/armaduras/armadura_epica_traje_colado_de_espiao.tres") as ItemData
	var armor_copy := InventoryItemState.new(spy_armor)
	velha.inventory_items.append(armor_copy)
	check(EquipmentManager.new().equip(velha, armor_copy, skills, game.campaign),
		"Velha equipa o Traje Colado de Espião.")
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	check(game.campaign.record_information_obtained(info),
		"Uma Informação dá uma revelação automática ao traje.")
	var spy_grant: SkillGrantState
	var sharp_grant: SkillGrantState
	for grant in skills.get_active_grants(velha):
		var active := grant.skill as ActiveSkillData
		if active.id == &"item_active_traje_espiao":
			spy_grant = grant
		elif active.id == &"playable_active_002":
			sharp_grant = grant
	check(spy_grant != null and sharp_grant != null and spy_grant != sharp_grant,
		"As revelações têm concessões e contadores distintos.")
	if spy_grant == null or sharp_grant == null:
		quit(1)
		return
	var sharp_before := sharp_grant.uses_in_last_turn
	hud._on_action_toggle_requested(hud.cards[0])
	check(hud._skill_is_available(velha, spy_grant),
		"Botão da Revelação de Espião começa disponível.")
	hud._on_skill_pressed(velha, spy_grant)
	check(spy_grant.uses_in_last_round == 1,
		"Clique real no botão da Revelação de Espião é aplicado.")
	check(spy_grant.uses_in_last_round == 1 and sharp_grant.uses_in_last_turn == sharp_before,
		"Usar o traje não gasta Olhar Afiado.")
	var target := EntityState.UNPLACED
	for coord in game.campaign.current_map.cells:
		if HexGrid.distance(velha.position, coord) <= velha.stamina_remaining + 1 \
				and skills.can_use_exploration_active(velha, velha, sharp_grant,
					game.campaign, coord, exploration.block_manager, scene):
			target = coord
			break
	check(target != EntityState.UNPLACED and hud._skill_is_available(velha, sharp_grant),
		"Olhar Afiado continua clicável após usar o traje, havendo alvo oculto.")
	if target != EntityState.UNPLACED:
		hud._on_action_toggle_requested(hud.cards[0])
		hud._on_skill_pressed(velha, sharp_grant)
		check(hud._targeting_grant == sharp_grant,
			"O HUD arma o Olhar Afiado depois de usar o traje.")
		hud._on_hex_choice_requested(target)
		check(sharp_grant.uses_in_last_turn == 1,
			"Olhar Afiado revela outro hex no mesmo turno.")
		check(game.campaign.current_map.get_cell(target).state == HexGrid.PPPBlockState.REVEALED,
			"A segunda revelação altera o hex escolhido.")
	velha.turn_serial += 1
	for coord in game.campaign.current_map.cells:
		if HexGrid.distance(velha.position, coord) <= velha.stamina_remaining + 1 \
				and game.campaign.current_map.get_cell(coord).state == HexGrid.PPPBlockState.HIDDEN:
			game.campaign.current_map.reveal_ppp_block(coord)
	check("não foi gasto" in hud._reveal_unavailability_note(velha, sharp_grant),
		"Sem alvo oculto, o HUD explica que Espião não consumiu Olhar Afiado.")
	print("REVEAL_SKILLS_INDEPENDENCE: %d falhas" % failures)
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
