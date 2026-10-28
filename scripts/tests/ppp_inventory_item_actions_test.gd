extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres")]
	check(gerencia.start_new_game(choices), "Cria o grupo.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Inicia o mapa.")
	var actor := gerencia.campaign.active_entity_states[0]
	var recipient := gerencia.campaign.active_entity_states[1]
	# Isola as cópias adicionadas pelo teste do kit inicial aleatório.
	for member in gerencia.campaign.active_entity_states:
		member.inventory_items.clear()
	var top := scene.get_node("CampaignTopBar") as CampaignTopBar
	top.group_inventory.open()
	var panel := top.group_inventory
	var weapon := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	var copy := InventoryItemState.new(weapon)
	actor.inventory_items.append(copy)
	panel.refresh()
	var cell := (panel.columns[0]["grid"] as GridContainer).get_child(0) as Button
	cell.pressed.emit()
	check(panel.item_menu.visible and panel.item_menu.entry == copy,
		"Clique abre menu da cópia selecionada.")
	check(panel.item_menu.menu.size.y <= 260.0,
		"O menu contextual deve caber só os botões: %s" % panel.item_menu.menu.size)
	check(_has_button(panel.item_menu.rows, "Equipar")
		and _has_button(panel.item_menu.rows, "Transferir para")
		and _has_button(panel.item_menu.rows, "Detalhes")
		and _has_button(panel.item_menu.rows, "Descartar"),
		"Equipamento mostra as quatro ações solicitadas.")
	check((panel.item_menu.rows.get_child(0) as Label).text.begins_with(weapon.display_name),
		"O nome do item aparece acima dos botões.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await process_frame
		var preview_path := "user://ppp_inventory_item_menu_preview.png"
		root.get_texture().get_image().save_png(preview_path)
		print("ITEM_MENU_PREVIEW=" + ProjectSettings.globalize_path(preview_path))
	_find_button(panel.item_menu.rows, "Equipar").pressed.emit()
	check(actor.primary_equipped(ItemData.EquipmentSlot.WEAPON) == copy
		and copy not in actor.inventory_items,
		"Equipar move a mesma cópia para o slot, sem ocupar a mochila.")
	var views: Array = panel.columns[0]["equipment_views"]
	(views[0]["cell"] as Button).pressed.emit()
	check(panel.item_menu.equipped and _has_button(panel.item_menu.rows, "Desequipar")
		and _has_button(panel.item_menu.rows, "Informações")
		and not _has_button(panel.item_menu.rows, "Descartar"),
		"Equipado oferece somente Desequipar e Informações.")
	_find_button(panel.item_menu.rows, "Desequipar").pressed.emit()
	check(copy in actor.inventory_items and actor.primary_equipped(ItemData.EquipmentSlot.WEAPON) == null,
		"Desequipar devolve a cópia ao inventário.")
	panel.refresh()
	cell = (panel.columns[0]["grid"] as GridContainer).get_child(0) as Button
	cell.pressed.emit()
	_find_button(panel.item_menu.rows, "Transferir para").pressed.emit()
	check(_has_button(panel.item_menu.rows, recipient.data.display_name),
		"Transferir para oferece os outros personagens do grupo.")
	_find_button(panel.item_menu.rows, recipient.data.display_name).pressed.emit()
	check(copy in recipient.inventory_items and copy not in actor.inventory_items,
		"Transferência preserva a mesma cópia no outro personagem.")
	check(not gerencia.campaign.journal_entries.any(func(entry: Dictionary) -> bool:
		return str(entry.get("action_id", "")) == "transfer_item"),
		"Transferência não ocupa linha no livro de registros.")
	var food := load("res://resources/itens/consumables/arroz_com_feijao.tres") as ItemData
	var food_copy := InventoryItemState.new(food)
	actor.inventory_items.append(food_copy)
	actor.current_health = actor.max_health - 5
	panel.refresh()
	cell = (panel.columns[0]["grid"] as GridContainer).get_child(0) as Button
	cell.pressed.emit()
	check(_has_button(panel.item_menu.rows, "Consumir")
		and _has_button(panel.item_menu.rows, "Transferir para")
		and not _has_button(panel.item_menu.rows, "Equipar"),
		"Consumível mostra Consumir, Transferir, Detalhes e Descartar.")
	_find_button(panel.item_menu.rows, "Consumir").pressed.emit()
	check(actor.current_health == actor.max_health and food_copy not in actor.inventory_items,
		"Consumir aplica a cura do Resource antes de retirar o item.")
	check(str(gerencia.campaign.journal_entries.back().get("text", "")).contains(
		"recuperou 5 de Vida"), "Livro registra a cura efetiva do consumível.")
	var coffee := load("res://resources/itens/consumables/cafezin.tres") as ItemData
	var coffee_copy := InventoryItemState.new(coffee)
	actor.inventory_items.append(coffee_copy)
	var base_stamina := actor.max_stamina
	panel.refresh()
	cell = (panel.columns[0]["grid"] as GridContainer).get_child(0) as Button
	cell.pressed.emit()
	_find_button(panel.item_menu.rows, "Consumir").pressed.emit()
	check(actor.max_stamina == base_stamina + 2 and coffee_copy not in actor.inventory_items
		and actor.consumable_timed_modifiers.size() == 1,
		"Consumível temporário aumenta a Estamina e registra a duração.")
	check(str(gerencia.campaign.journal_entries.back().get("text", "")).contains(
		"Estamina aumentou em 2 por 2 turnos"),
		"Livro registra o bônus concreto e a duração do consumível.")
	check("temporário" in EntityStatBreakdown.colored_text(actor, "stamina"),
		"A origem temporária aparece na explicação da Estamina.")
	actor.turn_serial += 1
	(scene.get_node("SkillManager") as SkillManager).inventory_manager.expire_timed_consumables(actor)
	check(actor.max_stamina == base_stamina + 2,
		"Bônus de dois turnos permanece no turno seguinte.")
	actor.turn_serial += 1
	(scene.get_node("SkillManager") as SkillManager).inventory_manager.expire_timed_consumables(actor)
	check(actor.max_stamina == base_stamina and actor.consumable_timed_modifiers.is_empty(),
		"Bônus temporário é removido quando o prazo termina.")
	var another := InventoryItemState.new(food)
	actor.inventory_items.append(another)
	panel.refresh()
	cell = (panel.columns[0]["grid"] as GridContainer).get_child(0) as Button
	cell.pressed.emit()
	_find_button(panel.item_menu.rows, "Descartar").pressed.emit()
	var confirm_style := panel.item_menu.confirm_box.get_theme_stylebox("panel") as StyleBoxFlat
	check(panel.item_menu.confirm_box.visible and confirm_style.bg_color.a == 1.0
		and confirm_style.border_color.r > 0.5
		and another in actor.inventory_items,
		"Descartar pede confirmação opaca com margem vermelha, sem descartar ainda.")
	panel.item_menu._cancel_discard()
	check(another in actor.inventory_items, "Cancelar preserva o item.")
	_find_button(panel.item_menu.rows, "Descartar").pressed.emit()
	panel.item_menu._confirm_discard()
	check(another not in actor.inventory_items, "Confirmar descarta a cópia escolhida.")
	var curse := load("res://resources/itens/curseds/espelho_quebrado.tres") as ItemData
	var curse_copy := InventoryItemState.new(curse)
	actor.inventory_items.append(curse_copy)
	panel.refresh()
	cell = (panel.columns[0]["grid"] as GridContainer).get_child(0) as Button
	cell.pressed.emit()
	check(not _has_button(panel.item_menu.rows, "Descartar")
		and not _has_button(panel.item_menu.rows, "Transferir para"),
		"Maldição não oferece descarte nem transferência comuns.")
	var holy := load("res://resources/itens/consumables/agua_benta.tres") as ItemData
	var holy_copy := InventoryItemState.new(holy)
	actor.inventory_items.append(holy_copy)
	panel.refresh()
	cell = (panel.columns[0]["grid"] as GridContainer).get_child(1) as Button
	cell.pressed.emit()
	_find_button(panel.item_menu.rows, "Consumir").pressed.emit()
	check(_has_button(panel.item_menu.rows, curse.display_name),
		"Água Benta pede a escolha da maldição.")
	panel.item_menu._consume_with_curse(curse_copy)
	check(curse_copy not in actor.inventory_items and holy_copy not in actor.inventory_items,
		"Água Benta retira a maldição escolhida e é consumida.")
	actor.inventory_items.append(curse_copy)
	var inventory := InventoryManager.new()
	for filename in DirAccess.get_files_at("res://resources/itens/consumables"):
		if not filename.ends_with(".tres"):
			continue
		var consumable := load("res://resources/itens/consumables/" + filename) as ItemData
		for effect in consumable.use_effects:
			check(inventory._supports_use_effect(effect, actor, curse_copy),
				"Efeito de %s pode ser consumido: %s" % [filename, effect.effect_type])
	var feijoada := load("res://resources/itens/consumables/feijoada_completa.tres") as ItemData
	check(is_equal_approx(feijoada.use_effects[2].activation_chance, 0.3),
		"A penalidade da Feijoada respeita os 30% confirmados.")
	print("Ações de itens: %s" % ("OK" if failures == 0 else "%d FALHAS" % failures))
	quit(0 if failures == 0 else 1)


func _has_button(container: VBoxContainer, caption: String) -> bool:
	for child in container.get_children():
		if child is Button and (child as Button).text == caption:
			return true
	return false


func _find_button(container: VBoxContainer, caption: String) -> Button:
	for child in container.get_children():
		if child is Button and (child as Button).text == caption:
			return child as Button
	return null


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
