extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
		load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "Campanha deve iniciar com três jogáveis.")
	for member in campaign.active_entity_states:
		member.inventory_items.clear() # Isola os ingredientes adicionados abaixo.
	var teacher := campaign.active_entity_states[0]
	var cook := campaign.active_entity_states[1]
	teacher.turn_state = EntityState.TurnState.TURNING
	teacher.turn_serial = 1
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	campaign.current_map = grid
	var manager := SkillManager.new()
	root.add_child(manager)
	var inventory := manager.inventory_manager
	var knife := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	var epic := knife.craft_result[0]
	var curse := load("res://resources/itens/curseds/bonequinha_de_pano.tres") as ItemData
	var grant: SkillGrantState
	for candidate in manager.get_active_grants(teacher):
		if candidate.skill.id == &"playable_active_005":
			grant = candidate
	check(grant != null, "Professora deve ter Artesanato com EVA.")
	var choice := {"ingredient_id": knife.id, "result_id": epic.id}
	check(not manager.can_use_exploration_active(teacher, teacher, grant, campaign,
		EntityState.UNPLACED, null, null, false, choice), "Sem ingredientes, não pode fabricar.")
	check(inventory.add_item(teacher, knife) and inventory.add_item(cook, knife),
		"Ingredientes separados entre pessoas não servem para a Professora.")
	check(not manager.can_use_exploration_active(teacher, teacher, grant, campaign,
		EntityState.UNPLACED, null, null, false, choice), "Ambas cópias precisam estar com a Professora.")
	check(inventory.add_item(teacher, knife), "Segunda cópia deve caber.")
	var gerencia := GerenciaJogo.new()
	gerencia.campaign = campaign
	var blocks := BlockManager.new()
	blocks.gerencia = gerencia
	var player := PlayerSkillManager.new()
	player.block_manager = blocks
	player.skill_manager = manager
	var exploration := ExplorationManager.new()
	exploration.gerencia = gerencia
	exploration.player_skill_manager = player
	exploration.current_actor = teacher
	root.add_child(gerencia)
	root.add_child(blocks)
	root.add_child(player)
	root.add_child(exploration)
	# EVA é craft de inventário: a Professora já agiu, e o Cozinheiro está na vez.
	teacher.turn_state = EntityState.TurnState.INACTIVE
	cook.turn_state = EntityState.TurnState.TURNING
	cook.turn_serial = 1
	exploration.current_actor = cook
	var craft_options := player.get_craft_options(teacher, grant, exploration)
	check(craft_options.size() == 1 and craft_options[0]["results"].size() == 3,
		"A caixa oferece EVA fora da vez da Professora.")
	check(CraftAvailability.options_for(teacher, inventory, exploration).size() == 1,
		"O inventário também oferece EVA fora da vez.")
	check(not manager.use_exploration_active(teacher, teacher, grant, campaign,
		EntityState.UNPLACED, null, null, false,
		{"ingredient_id": knife.id, "result_id": &"nao_existe"}), "Resultado inválido não consome itens.")
	check(teacher.inventory_items.size() == 2, "Falha não deve remover ingredientes.")
	check(player.use_craft_active(teacher, grant, knife.id, epic.id, exploration),
		"Artesanato fabrica o Épico escolhido fora da vez.")
	check(exploration.current_actor == cook and cook.turn_state == EntityState.TurnState.TURNING,
		"O craft não consome nem encerra a vez do Cozinheiro.")
	check(teacher.inventory_items.size() == 1 and teacher.inventory_items[0].data == epic,
		"Consome as duas cópias e entrega o Épico à Professora.")
	check(player.get_craft_options(teacher, grant, exploration).is_empty(),
		"A caixa não oferece nova fabricação após o uso diário.")
	check(not manager.use_exploration_active(teacher, teacher, grant, campaign,
		EntityState.UNPLACED, null, null, false, choice), "Uma fabricação por Dia.")
	var crafted_copy := teacher.inventory_items[0]
	check(inventory.transfer_item(teacher, cook, crafted_copy, campaign),
		"Épico pode ser transferido depois para outro jogável.")
	check(crafted_copy in cook.inventory_items and crafted_copy not in teacher.inventory_items,
		"Transferência preserva a própria cópia.")
	check(inventory.add_item(teacher, curse), "Teste recebe maldição.")
	check(not inventory.transfer_item(teacher, cook, teacher.inventory_items[0], campaign),
		"Maldição não pode mudar de portador.")

	print("CRAFT_TRANSFER_TEST_OK" if failures == 0 else "CRAFT_TRANSFER_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
