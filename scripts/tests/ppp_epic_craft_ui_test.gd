extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/professora.tres"),
	]
	check(game.start_new_game(choices), "A campanha inicia.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"O mapa inicial abre.")
	await process_frame
	var actor := game.campaign.active_entity_states[0] as EntityState
	var second := game.campaign.active_entity_states[1] as EntityState
	var third := game.campaign.active_entity_states[2] as EntityState
	var skills := scene.get_node("SkillManager") as SkillManager
	var manager := skills.inventory_manager
	var equipment := EquipmentManager.new()
	for member in game.campaign.active_entity_states:
		for slot in [ItemData.EquipmentSlot.WEAPON,
				ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
			for entry in member.equipped_in_slot(slot).duplicate():
				equipment.unequip(member, entry, skills)
		member.inventory_items.clear()
	var broom := load("res://resources/itens/equipments/armas/cabo_de_vassoura.tres") as ItemData
	var knife := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	for index in 3:
		actor.inventory_items.append(InventoryItemState.new(broom))
	for index in 3:
		actor.inventory_items.append(InventoryItemState.new(knife))
	var equipped_knife := actor.inventory_items[-1] as InventoryItemState
	check(equipment.equip(actor, equipped_knife, skills, game.campaign),
		"Uma das três facas pode estar equipada.")
	check(CraftAvailability.status_for(actor, knife, game.campaign, manager) \
		== CraftAvailability.Status.ACTOR_READY,
		"A cópia equipada conta para o destaque amarelo.")
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	var group := top_bar.group_inventory as GroupInventoryPanel
	var craft_shortcut := InputEventKey.new()
	craft_shortcut.keycode = KEY_E
	craft_shortcut.pressed = true
	top_bar._unhandled_key_input(craft_shortcut)
	check(group.visible and group.craft_panel.visible,
		"E abre o craft quando há receita Épica disponível.")
	group.craft_panel.close()
	for index in 3:
		second.inventory_items.append(InventoryItemState.new(broom))
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	exploration.current_actor = second
	top_bar._unhandled_key_input(craft_shortcut)
	check(group.craft_panel.visible and group.craft_panel._current()["actor"] == second,
		"E prioriza o personagem da vez quando mais de um pode criar Épico.")
	group.craft_panel.close()
	for index in 3:
		third.inventory_items.append(InventoryItemState.new(broom))
	exploration.current_actor = third
	check(group.preferred_craft_actor() == third,
		"E começa pelo terceiro personagem quando é a vez dele.")
	third.inventory_items.clear()
	check(group.preferred_craft_actor() == actor,
		"Sem craft no personagem da vez, E procura o próximo no ciclo.")
	for index in 3:
		third.inventory_items.append(InventoryItemState.new(broom))
	exploration.current_actor = second
	second.inventory_items.clear()
	check(group.preferred_craft_actor() == third,
		"E escolhe o próximo personagem antes do último.")
	top_bar._unhandled_key_input(craft_shortcut)
	check(group.craft_panel.visible and group.craft_panel._current()["actor"] == third,
		"O atalho E abre de fato o craft do próximo elegível.")
	group.craft_panel.close()
	third.inventory_items.clear()
	check(group.preferred_craft_actor() == actor,
		"Sem craft nos dois primeiros, E escolhe o último do ciclo.")
	second.inventory_items.clear()
	exploration.current_actor = actor
	group.open_craft_for(actor, broom)
	await _settle()
	check(group.craft_panel.dialog.size.y <= 540.0,
		"A receita de resultado único usa uma caixa compacta.")
	check(group.craft_panel.visible and group.craft_panel._current()["ingredient"] == broom,
		"A receita clicada fica em foco.")
	await _capture("craft_01_receita_unica")
	group.open_craft_for(actor, knife)
	await _settle()
	check((group.craft_panel._current()["results"] as Array).size() == 3,
		"Faca oferece as três escolhas épicas.")
	await _capture("craft_02_duas_opcoes")
	group.craft_panel._on_create_pressed()
	await _settle()
	check(group.craft_panel._phase == &"choose_result" and
		(group.craft_panel._current()["results"] as Array).size() == 3,
		"Criar abre a seleção entre três épicos sem consumir ingredientes.")
	check(group.craft_panel.intro.text.begins_with("Junte 3 itens comuns iguais")
		and group.craft_panel.choice_hint.visible
		and group.craft_panel.choice_hint.text == "Escolha qual item épico criar",
		"A escolha mantém a regra principal e acrescenta a orientação na terceira linha.")
	check(actor.equipped_weapons.has(equipped_knife),
		"Cancelar a escolha ainda preserva o item equipado.")
	group.craft_panel.close()
	check(actor.equipped_weapons.has(equipped_knife) and
		manager._craft_matching_entries(actor, knife.id).size() == 3,
		"Esc/X antes da confirmação não consome nenhum item comum.")
	group.open_craft_for(actor, knife)
	group.craft_panel._on_create_pressed()
	await _settle()
	await _capture("craft_03_escolha_epico")
	var result := group.craft_panel._current()["results"][0] as ItemData
	group.craft_panel._on_result_clicked(result)
	await _settle()
	check(group.craft_panel._selected_result == result and
		group.craft_panel.create_button.visible and
		actor.equipped_weapons.has(equipped_knife) and
		manager._craft_matching_entries(actor, knife.id).size() == 3,
		"Selecionar destaca o épico e mostra o botão, mas não consome os comuns.")
	await _capture("craft_04_epico_selecionado")
	group.craft_panel._show_details(result)
	await _settle()
	check(group.craft_panel.details.visible,
		"O ícone de informação abre a ficha do épico ao lado do craft.")
	await _capture("craft_05_detalhes_epico")
	group.craft_panel.details.hide()
	group.craft_panel._on_create_pressed()
	await _settle()
	check(group.craft_panel._phase == &"success" and
		group.craft_panel._crafted_entry != null and
		group.craft_panel._crafted_entry in actor.inventory_items,
		"Confirmar um resultado entrega o épico no inventário.")
	check(not actor.equipped_weapons.has(equipped_knife) and
		manager._craft_matching_entries(actor, knife.id).is_empty(),
		"As três facas são consumidas, inclusive a equipada.")
	await _capture("craft_06_resultado")
	group.craft_panel.close()
	check(group.craft_panel._crafted_entry in actor.inventory_items,
		"X/Esc depois do craft conserva o épico no inventário.")
	# Branco indica que o grupo tem as cópias, mas ainda precisa transferi-las.
	actor.inventory_items.append(InventoryItemState.new(knife))
	second.inventory_items.append(InventoryItemState.new(knife))
	second.inventory_items.append(InventoryItemState.new(knife))
	check(CraftAvailability.status_for(actor, knife, game.campaign, manager) \
		== CraftAvailability.Status.GROUP_READY,
		"Três cópias distribuídas geram destaque branco, sem permitir craft.")
	group.craft_panel.open_for(game.campaign, manager, skills,
		scene.get_node("ExplorationManager") as ExplorationManager, actor, knife)
	check(bool(group.craft_panel._current().get("preview_only", false)) and
		(group.craft_panel._current()["ingredient"] as ItemData).id == knife.id,
		"O clique no item branco explica como reunir cópias, mesmo havendo outra receita.")
	group.craft_panel.close()
	group.open()
	var split_equipped := second.inventory_items[-1] as InventoryItemState
	check(equipment.equip(second, split_equipped, skills, game.campaign),
		"Uma cópia distribuída também pode ficar equipada.")
	group.refresh()
	group._on_equipped_clicked(1, 0)
	check(_has_menu_action(group.item_menu, "Desequipar")
		and _has_menu_action(group.item_menu, "Criar Épico"),
		"No inventário do grupo, Desequipar e Criar Épico são ações independentes.")
	group.item_menu._unequip()
	check(split_equipped in second.inventory_items
		and split_equipped not in second.equipped_weapons,
		"Desequipar não abre craft nem consome a cópia distribuída.")
	check(equipment.equip(second, split_equipped, skills, game.campaign),
		"A mesma cópia pode ser equipada novamente para testar o HUD.")
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	hud._on_equipped_item_selected(hud.cards[1], split_equipped,
		Rect2(Vector2(280, 180), Vector2(50, 50)))
	check(_has_menu_action(hud.item_menu, "Desequipar")
		and _has_menu_action(hud.item_menu, "Criar Épico"),
		"No HUD, item equipável de receita também oferece Desequipar.")
	hud.item_menu._unequip()
	check(split_equipped in second.inventory_items
		and split_equipped not in second.equipped_weapons,
		"O HUD desequipa sem forçar a receita épica.")
	print("PPP epic craft UI: %s" % ("0 falhas" if failures == 0 else "%d falhas" % failures))
	scene.queue_free()
	for index in 4:
		await process_frame
	quit(0 if failures == 0 else 1)


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout


func _capture(name: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	var output := "user://%s.png" % name
	var error := root.get_texture().get_image().save_png(output)
	check(error == OK, "A imagem %s é salva." % name)
	print("CRAFT_IMAGE=%s" % ProjectSettings.globalize_path(output))


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _has_menu_action(item_menu: InventoryItemMenu, label: String) -> bool:
	for child in item_menu.rows.get_children():
		if child is Button and (child as Button).text == label:
			return true
	return false
