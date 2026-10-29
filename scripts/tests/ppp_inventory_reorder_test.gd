extends SceneTree

## Arraste, organização, limite proporcional de ampliação e última linha visível.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(gerencia.start_new_game(party), "Campanha inicia para testar a grade.")
	for member in gerencia.campaign.active_entity_states:
		member.inventory_items.clear() # A grade começa vazia neste teste.
	var actor := gerencia.campaign.active_entity_states[0]
	var other := gerencia.campaign.active_entity_states[1]
	var items: Array[InventoryItemState] = []
	items.append(_make_item("Armadura", ItemData.ItemType.EQUIPMENT,
		ItemData.EquipmentSlot.ARMOR))
	items.append(_make_item("Remédio raro", ItemData.ItemType.CONSUMABLE,
		ItemData.EquipmentSlot.NONE, ItemData.Rarity.RARE))
	items.append(_make_item("Espada", ItemData.ItemType.EQUIPMENT,
		ItemData.EquipmentSlot.WEAPON))
	items.append(_make_item("Maldição", ItemData.ItemType.CURSED))
	items.append(_make_item("Banana", ItemData.ItemType.CONSUMABLE,
		ItemData.EquipmentSlot.NONE, ItemData.Rarity.COMMON))
	items.append(_make_item("Anel", ItemData.ItemType.EQUIPMENT,
		ItemData.EquipmentSlot.ACCESSORY))
	for entry in items:
		actor.inventory_items.append(entry)
	check(InventoryManager.sort_inventory(actor, 0) and
		_names(actor) == "Maldição,Banana,Remédio raro,Espada,Armadura,Anel",
		"Tipo segue Maldição, Consumível por raridade, Arma, Armadura, Acessório.")
	check(InventoryManager.sort_inventory(actor, 1) and
		_names(actor) == "Anel,Armadura,Banana,Espada,Maldição,Remédio raro",
		"Organização alfabética usa o nome do ItemData.")
	check(InventoryManager.sort_inventory(actor, 2) and actor.inventory_items == items,
		"Aquisição: primeiros repõe a cronologia original após outras ordenações.")
	check(InventoryManager.sort_inventory(actor, 3) and
		actor.inventory_items[0] == items[-1],
		"Aquisição: últimos mostra os mais recentes primeiro.")
	InventoryManager.sort_inventory(actor, 2)
	check(InventoryManager.reorder_item_to_slot(actor, items[2], 0) and
		actor.inventory_items[0] == items[2] and actor.inventory_items[1] == items[0]
		and items[0].inventory_slot_index == 1 and items[1].inventory_slot_index == 2,
		"Arrastar para slot ocupado desloca os seguintes em ordem de leitura.")
	check(InventoryManager.reorder_item_to_slot(actor, items[2], 8) and
		actor.inventory_items[-1] == items[2]
		and InventoryManager.inventory_layout(actor)[0].is_empty()
		and InventoryManager.inventory_layout(actor)[8].get("entry") == items[2],
		"Arrastar para slot vazio final reposiciona a mesma cópia.")
	check(not InventoryManager.reorder_item_to_slot(other, items[2], 0),
		"Arrastar não transfere um item para outro personagem.")
	other.base_inventory_capacity = 3
	var full_entries := [
		_make_item("Primeiro", ItemData.ItemType.CONSUMABLE),
		_make_item("Segundo", ItemData.ItemType.CONSUMABLE),
		_make_item("Terceiro", ItemData.ItemType.CONSUMABLE)]
	for entry in full_entries:
		other.inventory_items.append(entry)
	check(InventoryManager.reorder_item_to_slot(other, full_entries[0], 1) and
		other.inventory_items == [full_entries[1], full_entries[0], full_entries[2]]
		and other.inventory_used_space() == 3,
		"Inventário cheio reorganiza usando o espaço da origem, sem exceder capacidade.")
	var top := scene.get_node("CampaignTopBar") as CampaignTopBar
	var group := top.group_inventory
	group.open()
	var cells := group.columns[0]["grid"] as GridContainer
	var target := cells.get_child(0) as Button
	var drag_data := {"panel": group, "actor": actor, "entry": items[2]}
	check(target.call("_can_drop_data", Vector2.ZERO, drag_data),
		"Slot do inventário aceita arraste interno.")
	var other_target := (group.columns[1]["grid"] as GridContainer).get_child(0) as Button
	check(not other_target.call("_can_drop_data", Vector2.ZERO, drag_data),
		"Slot de outro personagem recusa arraste entre inventários.")
	var original_size := group.window.size
	group._resize_start_mouse = Vector2.ZERO
	group._resize_start_factor = 1.0
	group._window_resizing = true
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(9999, 9999)
	group._input(motion)
	check(group._window_scale_factor <= 1.2 and
		group.window.size.x <= original_size.x * 1.2 + 1.0 and
		is_equal_approx(group.window.size.x / original_size.x,
			group.window.size.y / original_size.y),
		"Ampliar limita a 20% e preserva a proporção da janela.")
	Input.warp_mouse(Vector2i(1500, 800))
	await process_frame
	var double_click := InputEventMouseButton.new()
	double_click.button_index = MOUSE_BUTTON_LEFT
	double_click.pressed = true
	double_click.double_click = true
	double_click.position = Vector2(1500, 800)
	scene._input(double_click)
	check(not group.visible,
		"Clique duplo na área livre do mapa recolhe o inventário do grupo.")
	var personal := load("res://scenes/ui/character_inventory_panel.tscn").instantiate() \
		as CharacterInventoryPanel
	root.add_child(personal)
	personal.bind_state(actor)
	personal.show()
	await process_frame
	check(personal.scroll.custom_minimum_size.y >= 348.0 \
		and not personal.scroll.get_v_scroll_bar().visible,
		"As quatro linhas da grade cabem sem cortar a última por 8 px.")
	var personal_target := personal.grid.get_child(1) as Button
	check(personal_target.call("_can_drop_data", Vector2.ZERO,
		{"panel": personal, "actor": actor, "entry": items[2]}),
		"O inventário individual também aceita reordenação interna.")
	personal._resize_start_mouse = Vector2.ZERO
	personal._resize_start_scale = 1.0
	personal._resizing = true
	personal._input(motion)
	check(personal.scale.x <= 1.20001 and is_equal_approx(personal.scale.x, personal.scale.y),
		"A caixa individual também mantém proporção e limite de ampliação de 20%.")
	print("PPP inventory reorder: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func _make_item(name: String, type: ItemData.ItemType,
		slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE,
		rarity: ItemData.Rarity = ItemData.Rarity.COMMON) -> InventoryItemState:
	var data := ItemData.new()
	data.display_name = name
	data.id = StringName(name)
	data.item_type = type
	data.equipment_slot = slot
	data.rarity = rarity
	return InventoryItemState.new(data)


func _names(owner: EntityState) -> String:
	var values: PackedStringArray = []
	for entry in owner.inventory_items:
		values.append(entry.data.display_name)
	return ",".join(values)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
