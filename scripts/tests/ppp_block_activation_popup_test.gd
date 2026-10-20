extends SceneTree

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"A campanha e o mapa precisam iniciar.")
	var actor := gerencia.campaign.active_entity_states[0]
	var grid := gerencia.campaign.current_map
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	grid.set_ppp_block(Vector2i(6, 2), HexGrid.PPPBlockType.INFORMATION, information)
	check(block.begin_activation(Vector2i(6, 2), actor),
		"Informação abre sua janela antes da obtenção.")
	check(popup.overlay.visible and popup.title_label.text == information.titulo.to_upper() \
		and popup.narrative_label.text == information.descricao \
		and not gerencia.campaign.obtained_information_ids.has(information.id),
		"Título e texto da Informação aparecem sem antecipar o registro.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not block.is_busy() and not popup.overlay.visible \
		and gerencia.campaign.obtained_information_ids.has(information.id),
		"Confirmar registra a Informação e fecha a janela.")
	var item := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	grid.set_ppp_block(Vector2i(7, 4), HexGrid.PPPBlockType.EQUIPMENT, item)
	check(block.begin_activation(Vector2i(7, 4), actor), "Um item abre a resolução.")
	check(popup.overlay.visible and popup.buttons.get_child_count() == 3 \
		and popup.narrative_label.text == item.description,
		"Item mostra descrição e os três botões.")
	await process_frame
	var item_preview := popup.get_node("Overlay/Center/FrameArea/Content/Body/ItemPreview") as CenterContainer
	var item_icon := item_preview.get_node("PreviewRow/ItemIcon") as TextureRect
	var item_info := item_preview.get_node("PreviewRow/InfoButton") as Button
	check(item_preview.visible and item_icon.visible and item_icon.texture == item.icon \
		and item_icon.custom_minimum_size == Vector2(78, 82) \
		and item_preview.get_global_rect().encloses(item_icon.get_global_rect()),
		"O item encontrado mostra seu próprio ícone ampliado, dentro da caixa.")
	var carried_before_info := actor.inventory_items.size()
	item_info.pressed.emit()
	var reward_details := popup.get_node("Overlay/RewardItemDetails") as EventRewardDetailsPanel
	check(reward_details.visible and reward_details.name_label.text == item.display_name \
		and reward_details.effect_label.text == item.description \
		and reward_details.stats_label.text.contains("Tipo: Equipamento"),
		"ⓘ junto ao ícone abre descrição e estatísticas sem receber o item.")
	check(reward_details.get_global_rect().position.x \
		>= popup.frame_area.get_global_rect().end.x + 10.0 \
		and reward_details.size.y < 470.0 and reward_details.close_button.text == "X",
		"Ficha de recompensa abre compacta na lateral com fechamento visível.")
	check(block.is_busy() and actor.inventory_items.size() == carried_before_info,
		"Consultar a ficha não aceita nem descarta a recompensa.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.12).timeout
		RenderingServer.force_draw(false)
		var details_path := "user://ppp_event_item_details_preview.png"
		root.get_texture().get_image().save_png(details_path)
		print("ITEM_DETAILS_PREVIEW=" + ProjectSettings.globalize_path(details_path))
	reward_details.close_button.pressed.emit()
	var frame_area := popup.get_node("Overlay/Center/FrameArea") as Control
	var title_banner := frame_area.get_node("TitleBanner") as TextureRect
	var frame := frame_area.get_node("Frame") as TextureRect
	var content := frame_area.get_node("Content") as MarginContainer
	check(title_banner.texture.resource_path.ends_with("uielementx_00006.png") \
		and frame.texture.resource_path.ends_with("uielementx_00005.png") \
		and title_banner.get_global_rect().end.y < frame.get_global_rect().end.y \
		and content.get_global_rect().encloses(item_preview.get_global_rect()) \
		and content.get_global_rect().encloses(popup.buttons.get_global_rect()) \
		and item_preview.get_global_rect().end.y <= popup.narrative_label.get_global_rect().position.y,
		"Ícone, descrição e botões ficam inteiramente dentro da caixa, sem sobreposição.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.23).timeout
		var preview_path := "user://ppp_block_activation_popup_preview.png"
		root.get_texture().get_image().save_png(preview_path)
		print("BLOCK_POPUP_PREVIEW=" + ProjectSettings.globalize_path(preview_path))
	var before := actor.inventory_items.size()
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(actor.inventory_items.size() == before + 1 and not block.is_busy() \
		and not popup.overlay.visible, "Aceitar adiciona o item e conclui o bloco.")
	grid.set_ppp_block(Vector2i(7, 3), HexGrid.PPPBlockType.EQUIPMENT, item)
	check(block.begin_activation(Vector2i(7, 3), actor), "Outro item abre a escolha.")
	(popup.buttons.get_child(1) as Button).pressed.emit()
	check(popup.buttons.get_child_count() == 3,
		"Transferir mostra dois colegas e Voltar.")
	var teammate := gerencia.campaign.active_entity_states[1]
	var teammate_items_before := teammate.inventory_items.size()
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(teammate.inventory_items.size() == teammate_items_before + 1 \
		and not block.is_busy(),
		"A transferência entrega o item ao colega escolhido.")
	var encounter := load("res://resources/encounters/enc_barata_voadora.tres") as EncounterData
	var combat_signals := [0]
	block.combat_requested.connect(func(_context: Dictionary) -> void: combat_signals[0] += 1)
	grid.set_ppp_block(Vector2i(7, 2), HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(Vector2i(7, 2), actor), "Encontro abre a narrativa.")
	check(popup.overlay.visible and popup.buttons.get_child_count() == 1 \
		and popup.title_label.text == "ENCONTRO INDESEJADO" \
		and popup.encounter_name.text == encounter.display_name \
		and not item_preview.visible \
		and not popup.narrative_label.text.contains("1 a 4") \
		and combat_signals[0] == 0 and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"Combate não inicia antes da confirmação.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(combat_signals[0] == 1 and grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT \
		and not popup.overlay.visible, "O clique único solicita Combate e troca o modo.")
	check(block.finish_combat() and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"Fim do Combate devolve o modo Exploração.")
	var event := load("res://resources/events/random_events/33-tropeco_perigoso.tres") as EventData
	var event_signals := [0]
	block.event_resolution_requested.connect(func(_context: Dictionary) -> void: event_signals[0] += 1)
	grid.set_ppp_block(Vector2i(7, 1), HexGrid.PPPBlockType.EVENT, event)
	check(block.begin_activation(Vector2i(7, 1), actor), "Evento abre a narrativa.")
	check(event_signals[0] == 0 and popup.overlay.visible,
		"Evento não executa antes do botão.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(event_signals[0] == 1 and block.is_busy(),
		"O clique envia a decisão, sem fingir que os efeitos terminaram.")
	check(block.finish_event_resolution() and not popup.overlay.visible,
		"O futuro executor poderá concluir e fechar a caixa.")
	# Maldição com inventário cheio obriga uma escolha explícita de descarte.
	var inventory := (scene.get_node("SkillManager") as SkillManager).inventory_manager
	while inventory.can_receive(actor, item):
		inventory.add_item(actor, item)
	var curse := load("res://resources/itens/curseds/agulha_de_costura.tres") as ItemData
	grid.set_ppp_block(Vector2i(6, 4), HexGrid.PPPBlockType.CURSE, curse)
	check(block.begin_activation(Vector2i(6, 4), actor),
		"Maldição pode ser ativada mesmo com inventário cheio.")
	check(not (popup.buttons.get_child(0) as Button).disabled \
		and (popup.buttons.get_child(1) as Button).disabled \
		and (popup.buttons.get_child(2) as Button).disabled,
		"Maldição não permite transferir/descartar; Aceitar abre liberação de espaço.")
	check((popup.buttons.get_child(1) as Button).get_theme_stylebox("disabled") is StyleBoxFlat \
		and ((popup.buttons.get_child(1) as Button).get_theme_stylebox("disabled") as StyleBoxFlat).bg_color.r < 0.3,
		"Opções indisponíveis da caixa de itens aparecem cinza.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	var group_inventory := (scene.get_node("CampaignTopBar") as CampaignTopBar).group_inventory
	check(group_inventory.visible and block.is_busy(),
		"Inventário do grupo abre para escolher a troca obrigatória.")
	var outgoing: InventoryItemState
	for entry in actor.inventory_items:
		if entry.data.can_be_discarded and entry.data.item_type != ItemData.ItemType.CURSED:
			outgoing = entry
			break
	check(outgoing != null, "Existe item descartável para a troca.")
	if outgoing != null:
		group_inventory._exchange_selected.append(outgoing)
		group_inventory._update_exchange_ui()
		group_inventory._ask_exchange_confirmation()
		check(group_inventory._exchange_confirmation.visible and outgoing in actor.inventory_items,
			"A confirmação nomeia a troca antes de remover o item.")
		group_inventory._confirm_exchange()
		check(outgoing not in actor.inventory_items,
			"Só o item explicitamente escolhido foi descartado.")
	check(actor.inventory_items.any(func(entry: InventoryItemState) -> bool:
		return entry.data == curse) and not block.is_busy(),
		"Depois de abrir espaço, a maldição entra no inventário.")
	var dish := load("res://resources/itens/consumables/prato_feito_perfeito.tres") as ItemData
	popup.show_block({"resource": dish})
	await process_frame
	var title_font := popup.title_label.get_theme_font("font")
	var title_font_size := popup.title_label.get_theme_font_size("font_size")
	var title_width := title_font.get_string_size(popup.title_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size).x
	check(title_width <= popup.title_label.size.x - 10.0
		and popup.title_banner.size.x <= popup.frame_area.size.x - 20.0,
		"Título longo cabe na moldura estreita sem tocar a borda.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		RenderingServer.force_draw(false)
		var dish_path := "user://ppp_event_dish_popup_preview.png"
		root.get_texture().get_image().save_png(dish_path)
		print("DISH_POPUP_PREVIEW=" + ProjectSettings.globalize_path(dish_path))
	print("PPP block popup: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
