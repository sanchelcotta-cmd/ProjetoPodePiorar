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
	var block := scene.get_node("BlockManager") as BlockManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var equipment := EquipmentManager.new()
	var playable: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(game.start_new_game(playable) and round_manager.start_first_map(),
		"Campanha de teste inicia.")
	var actor := game.campaign.active_entity_states[0]
	for member in game.campaign.active_entity_states:
		member.inventory_items.clear()
		member.equipped_weapons.clear()
		member.equipped_armors.clear()
		member.equipped_accessories.clear()
	var thieves_one := _event(12)
	check(_activate(game, block, actor, thieves_one, Vector2i(1, 1)),
		"Ladrão solitário abre sem itens.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup.narrative_label.text == "Aff - Dia de sorte, hm?!",
		"Ladrão solitário sem item mostra a fala exigida.")
	popup._execute_prepared_event()
	check(popup.narrative_label.text.contains(actor.visible_name()),
		"Ladrão mostra o resultado individual mesmo sem item elegível.")
	popup._show_next_theft_outcome()
	check(not block.is_busy(), "Ladrão sem item conclui sem retirar nada.")
	var thieves_group := _event(13)
	check(_activate(game, block, actor, thieves_group, Vector2i(2, 1)),
		"Ladrões do grupo abrem sem itens.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup.narrative_label.text == "Aff - Dia de sorte, hm?!",
		"Ladrões do grupo sem itens mostram a fala exigida.")
	popup._execute_prepared_event()
	check(popup.narrative_label.text.contains(game.campaign.active_entity_states[0].visible_name())
		and popup._theft_outcome_pages.size() == game.campaign.active_entity_states.size() - 1,
		"Ladrões preparam uma caixa por alvo com nome próprio.")
	for _index in game.campaign.active_entity_states.size():
		popup._show_next_theft_outcome()
	check(not block.is_busy(), "Roubo coletivo sem item conclui.")
	var artisan := _event(16)
	check(_activate(game, block, actor, artisan, Vector2i(3, 1)),
		"Artesão abre mesmo sem arma ou armadura.")
	check(popup.narrative_label.text == "Sem melhorias hoje... Quem sabe depois, né?!",
		"Artesão sem item mostra a fala exigida.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	popup._execute_prepared_event()
	check(not block.is_busy(), "Artesão sem item conclui sem melhoria.")
	var knife := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	var copy := InventoryItemState.new(knife)
	actor.inventory_items.append(copy)
	check(_activate(game, block, actor, artisan, Vector2i(4, 1)),
		"Artesão aceita arma carregada, sem exigir que esteja equipada.")
	check(popup.buttons.get_child_count() > 0, "Artesão lista a faca para aprimorar.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(copy.improvement_attack == 0 and executor.get_prepared_item_reward().is_empty(),
		"Escolha ainda não altera a cópia antes da confirmação.")
	check(executor.apply_prepared_result(), "Artesão aplica um resultado de 1d6.")
	check(copy.improvement_attack >= 1 and copy.improvement_attack <= 6,
		"Bônus de Ataque do Artesão fica na cópia, não no Resource.")
	await create_timer(1.0).timeout
	check(not block.is_busy(), "Artesão conclui após mostrar o dado.")
	actor.inventory_items.clear()
	actor.inventory_items.append(copy)
	actor.inventory_items.append(InventoryItemState.new(knife))
	actor.inventory_items.append(InventoryItemState.new(knife))
	var epic := knife.craft_result[0]
	var crafted := InventoryManager.new().craft(actor, knife.id, epic.id, 3)
	var crafted_copy := crafted.get("crafted_copy") as InventoryItemState
	check(crafted.get("success", false) and crafted_copy != null \
		and crafted_copy.data == epic \
		and crafted_copy.improvement_attack == copy.improvement_attack \
		and knife.bonus_attack == 3,
		"Ao evoluir três facas, a épica herda a melhoria sem alterar o catálogo.")
	var epic_base_attack := epic.bonus_attack
	var attack_before_equip := actor.attack
	check(equipment.equip(actor, crafted_copy, skill_manager, game.campaign),
		"Épica melhorada pode ser equipada normalmente.")
	check(actor.attack == attack_before_equip + epic_base_attack \
		+ crafted_copy.improvement_attack,
		"Épica soma seu bônus próprio e toda a melhoria herdada.")
	check(equipment.unequip(actor, crafted_copy, skill_manager) \
		and actor.attack == attack_before_equip,
		"Desequipar remove os dois bônus sem apagar a melhoria da cópia.")
	var cardboard := load("res://resources/itens/equipments/armaduras/armadura_de_papelao.tres") as ItemData
	var cardboard_copy := InventoryItemState.new(cardboard)
	actor.inventory_items.append(cardboard_copy)
	check(equipment.equip(actor, cardboard_copy, skill_manager, game.campaign),
		"Armadura é equipada para testar a melhoria do Artesão.")
	var hp_before_armor_upgrade := actor.max_health
	var current_before_armor_upgrade := actor.current_health
	var armor_result := executor._apply_effect(artisan.outcomes[0].effects[0], actor,
		artisan, {"decision": {"selected_item": cardboard_copy}}, false)
	check(armor_result.get("success", false) and cardboard_copy.improvement_life > 0 \
		and actor.max_health == hp_before_armor_upgrade + cardboard_copy.improvement_life \
		and actor.current_health == current_before_armor_upgrade + cardboard_copy.improvement_life,
		"Armadura equipada recebe bônus de Vida máxima e atual na mesma cópia.")
	var armor_removed := equipment.unequip(actor, cardboard_copy, skill_manager)
	check(armor_removed \
		and actor.max_health == hp_before_armor_upgrade - cardboard.bonus_life \
		and actor.current_health <= actor.max_health,
		"Desequipar armadura melhorada remove o bônus máximo sem apagar a cópia.")
	var pact := _event(25)
	check(_activate(game, block, actor, pact, Vector2i(5, 1)), "Pacto de Sangue abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	var picker := popup.get_node("Overlay/EventItemPicker") as Control
	var grid := picker.get("_grid") as GridContainer
	check(picker.visible and grid.columns == 5 and grid.get_child_count() > 0,
		"Catálogo do Pacto usa cinco colunas e itens clicáveis.")
	var chosen := executor.get_catalog_choices(pact.outcomes[0].effects[1])[0]
	var details := popup.get_node("Overlay/RewardItemDetails") as EventRewardDetailsPanel
	var info_tile := (grid.get_child(0) as Button).get_node("ItemInfo") as Button
	var item_count_before_info := actor.inventory_items.size()
	info_tile.pressed.emit()
	check(details.visible and picker.visible and details.name_label.text == chosen.display_name \
		and actor.inventory_items.size() == item_count_before_info,
		"ⓘ na grade mostra a ficha sem escolher nem conceder o item.")
	details.close_button.pressed.emit()
	picker.call("_select", chosen)
	check((picker.get("_choice_panel") as Control).visible \
		and (picker.get("_choice_icon") as TextureRect).texture == chosen.icon,
		"Confirmação mostra nome e ícone da recompensa.")
	var choice_info := (picker.get("_choice_panel") as Control).find_child("ChoiceInfo", true, false) as Button
	choice_info.pressed.emit()
	check(details.visible and picker.visible and (picker.get("_choice_panel") as Control).visible,
		"ⓘ na confirmação abre detalhes sem confirmar a escolha.")
	details.close_button.pressed.emit()
	picker.call("_go_back")
	check(not (picker.get("_choice_panel") as Control).visible and picker.visible,
		"AINDA NÃO retorna à seleção sem aplicar recompensa.")
	picker.call("_select", chosen)
	var hp_before_pact := actor.max_health
	picker.call("_confirm")
	check(actor.max_health == hp_before_pact,
		"Confirmar item ainda aguarda leitura do Outcome do Pacto.")
	check(popup.item_preview.visible and popup.item_icon.texture == chosen.icon,
		"Outcome de item já determinado mostra ícone e ⓘ antes de aplicar o efeito.")
	popup._execute_prepared_event()
	check(actor.max_health == hp_before_pact - 2 \
		and actor.inventory_items.any(func(entry: InventoryItemState) -> bool:
			return entry.data == chosen),
		"Pacto retira 2 Vida máxima e concede exatamente o Épico escolhido.")
	check(_activate(game, block, actor, pact, Vector2i(3, 2)),
		"Pacto reabre para testar o ramo de recusa.")
	var hp_before_refusal := actor.max_health
	var items_before_refusal := actor.inventory_items.size()
	(popup.buttons.get_child(1) as Button).pressed.emit()
	popup._execute_prepared_event()
	check(not block.is_busy() and actor.max_health == hp_before_refusal \
		and actor.inventory_items.size() == items_before_refusal,
		"Recusar o Pacto não custa Vida nem entrega item.")
	var declined_shop := _event(46)
	check(_activate(game, block, actor, declined_shop, Vector2i(4, 2)),
		"Miss Fortuna abre para testar desistência consciente.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	var carried_before_decline := actor.inventory_items.size()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	picker.call("_input", escape)
	check(picker.visible and (picker.get("_forfeit_panel") as Control).visible \
		and actor.inventory_items.size() == carried_before_decline and block.is_busy(),
		"ESC apenas pergunta se quer renunciar, sem perder a recompensa.")
	picker.call("_cancel_forfeit")
	check(picker.visible and not (picker.get("_forfeit_panel") as Control).visible,
		"Continuar escolhendo mantém o catálogo disponível.")
	picker.call("_ask_forfeit")
	picker.call("_confirm_forfeit")
	check(not block.is_busy() and actor.inventory_items.size() == carried_before_decline,
		"Somente a confirmação explícita conclui o evento sem item.")
	for event_number in [46, 47, 48]:
		var shop := _event(event_number)
		check(_activate(game, block, actor, shop,
			Vector2i(event_number - 41, 2)), "Miss Fortuna %d abre." % event_number)
		(popup.buttons.get_child(0) as Button).pressed.emit()
		var offered := executor.get_catalog_choices(shop.outcomes[0].effects[0])[0]
		check(picker.visible and grid.columns == 5,
			"Miss Fortuna %d abre catálogo em cinco colunas." % event_number)
		picker.call("_select", offered)
		picker.call("_confirm")
		popup._execute_prepared_event()
		check(actor.inventory_items.any(func(entry: InventoryItemState) -> bool:
			return entry.data == offered),
			"Miss Fortuna %d concede o item escolhido." % event_number)
	var carried_before_theft := actor.inventory_items.size()
	var theft_plan: Array[Dictionary] = executor._prepare_theft_plan(thieves_one,
		thieves_one.outcomes[3], {"actor": actor})
	check(theft_plan.size() == 1 and theft_plan[0].get("entry") in actor.inventory_items,
		"Roubo prepara uma cópia concreta, sem removê-la durante a leitura.")
	check(executor._apply_theft(theft_plan[0]).get("success", false) \
		and actor.inventory_items.size() == carried_before_theft - 1,
		"Roubo tira somente a cópia preparada após a confirmação.")
	var carried_weapon := InventoryItemState.new(knife)
	actor.inventory_items.append(carried_weapon)
	check(equipment.equip(actor, carried_weapon, skill_manager, game.campaign),
		"Arma preparada para verificar roubo de equipamento.")
	var equipped_attack := actor.attack
	var equipped_plan: Array[Dictionary] = executor._prepare_theft_plan(thieves_one,
		thieves_one.outcomes[0], {"actor": actor})
	check(equipped_plan.size() == 1 and equipped_plan[0].get("entry") == carried_weapon,
		"Roubo de arma seleciona a cópia equipada, não uma do inventário.")
	check(executor._apply_theft(equipped_plan[0]).get("success", false) \
		and actor.primary_equipped(ItemData.EquipmentSlot.WEAPON) == null \
		and actor.attack < equipped_attack,
		"Roubo de arma remove seus bônus e esvazia o slot.")
	var cursed := load("res://resources/itens/curseds/agulha_de_costura.tres") as ItemData
	for member in game.campaign.active_entity_states:
		member.inventory_items.append(InventoryItemState.new(cursed))
	var temple := _event(32)
	check(_activate(game, block, actor, temple, Vector2i(7, 3)),
		"Templo Sagrado abre com maldições no grupo.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	popup._execute_prepared_event()
	check(game.campaign.active_entity_states.all(func(member: EntityState) -> bool:
		return member.inventory_items.all(func(entry: InventoryItemState) -> bool:
			return entry.data.item_type != ItemData.ItemType.CURSED)),
		"Templo remove todas as cópias amaldiçoadas do grupo.")
	print("EVENT_INVENTORY_GROUP: %d falhas" % failures)
	quit(1 if failures else 0)


func _event(number: int) -> EventData:
	for filename in DirAccess.get_files_at("res://resources/events/random_events"):
		if filename.begins_with("%02d-" % number) and filename.ends_with(".tres"):
			return load("res://resources/events/random_events".path_join(filename)) as EventData
	return null


func _activate(game: GerenciaJogo, block: BlockManager, actor: EntityState,
		event: EventData, coord: Vector2i) -> bool:
	if event == null:
		return false
	actor.position = coord
	game.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	return block.begin_activation(coord, actor)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
