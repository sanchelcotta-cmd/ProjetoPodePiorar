extends SceneTree

## Confere os três quadros iguais e a folga entre a barra e a StartZone.
var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var viewport_size := scene.get_viewport_rect().size
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var first := hud.cards[0]
	var second := hud.cards[1]
	var third := hud.cards[2]
	check(hud.cards.size() == 3 and first.size.is_equal_approx(second.size) \
		and second.size.is_equal_approx(third.size),
		"As três vagas têm quadros de tamanho idêntico.")
	var sidebar := hud.get_node("Root") as Control
	var first_start := scene.get_node("MapRoot/StartZone/Start_1") as Sprite2D
	var start_left := first_start.global_position.x \
		- first_start.texture.get_width() * first_start.scale.x * 0.5
	check(sidebar.get_global_rect().end.x < start_left,
		"O painel esquerdo não cobre os personagens da StartZone.")

	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
	]
	check(gerencia.start_new_game(choices), "Três personagens podem ser selecionados.")
	# Este teste isola a HUD; a distribuição inicial é verificada em teste próprio.
	var starting_equipment := EquipmentManager.new()
	var starting_skill_manager := scene.get_node("SkillManager") as SkillManager
	for state in gerencia.campaign.active_entity_states:
		for slot in [ItemData.EquipmentSlot.WEAPON,
				ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
			for entry in state.equipped_in_slot(slot).duplicate():
				starting_equipment.unequip(state, entry, starting_skill_manager)
		state.inventory_items.clear()
	var rounds := scene.get_node("RoundManager") as RoundManager
	check(rounds.start_first_map(), "A cena gera o mapa com os escolhidos.")
	await process_frame
	check(first.name_label.text == choices[0].display_name \
		and second.name_label.text == choices[1].display_name \
		and third.name_label.text == choices[2].display_name,
		"Cada quadro acompanha sua vaga Playable, não um personagem fixo.")
	var card_rect := first.get_global_rect()
	var portrait_rect := first.portrait.get_global_rect()
	var stats_rect := (first.get_node("Margin/Content/TopRow/Stats") as Control).get_global_rect()
	check(portrait_rect.end.x + 4.0 <= stats_rect.position.x \
		and stats_rect.end.x <= card_rect.end.x - 8.0 \
		and first.name_label.get_global_rect().position.y >= portrait_rect.end.y + 4.0 \
		and first.health_label.get_theme_font_size("font_size") >= 13,
		"Retrato, estatísticas ampliadas e faixa do nome cabem sem tocar as margens.")
	check(first.name_label.get_theme_color("font_color") == PartyCharacterCard.ACTIVE_BORDER \
		and first.name_label.get_theme_font("font") == PartyCharacterCard.BOLD_FONT \
		and second.name_label.get_theme_color("font_color") == PartyCharacterCard.EMPTY_BORDER,
		"Nome ativo ciano e negrito; personagens disponíveis em rosa.")
	check(first.portrait.texture is AtlasTexture \
		and (first.portrait.texture as AtlasTexture).region.position == Vector2.ZERO,
		"O retrato mostra o primeiro quadro do Idle.")
	var portrait_frame := first.get_node("Margin/Content/TopRow/PortraitFrame/FrameArt") as TextureRect
	var card_trace := first.get_node("CardTrace") as TextureRect
	check(portrait_frame.texture.resource_path.ends_with("uielementx_00004.png") \
		and first.portrait.custom_minimum_size.y >= 74.0 \
		and is_equal_approx(portrait_frame.modulate.a, 0.1) \
		and card_trace.texture.resource_path.ends_with("uielementx_00008.png") \
		and is_equal_approx(card_trace.modulate.a, 0.1) \
		and card_trace.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Retrato maior usa sua moldura; circuito discreto não intercepta cliques.")
	check((first.portrait.texture as AtlasTexture).region.size.y \
		== choices[0].playable_animation.frame_size.y / 2.0,
		"O retrato enquadra só a metade superior do personagem.")
	check(first.health_label.text == "VIDA: 28/28" \
		and first.attack_label.text == "ATK: 4" \
		and first.stamina_label.text == "STAMINA: 4",
		"Vida atual/máxima, Ataque e Estamina aparecem lado a lado.")
	check("DISTÂNCIA" in first.mastery_label.text,
		"A Maestria acompanha o Resource selecionado.")
	check(first.weapon_icon.texture == null and first.armor_icon.texture == null \
		and first.accessory_icon.texture == null,
		"Os três quadros de equipamento começam vazios, sem inventar itens equipados.")
	check(first.debuff_row.get_child_count() == 0 and not first.debuff_row.visible,
		"Sem Debuffs, não há bolinhas vazias nem área clicável reservada.")
	var sample_debuff := DebuffData.new()
	sample_debuff.id = &"hud_debuff_test"
	sample_debuff.display_name = "Condição de teste"
	sample_debuff.description = "Esta condição altera o personagem enquanto durar. " \
		+ "O texto precisa quebrar em várias linhas, continuar legível e permanecer " \
		+ "inteiramente dentro da margem decorativa, sem encostar nos cantos da janela."
	sample_debuff.icon = (load("res://resources/skills/effects/debuffs/doenca_1.tres") \
		as DebuffData).icon
	var applied := DebuffInstanceState.new(sample_debuff)
	applied.remaining_turns = 3
	first.state.debuffs.append(applied)
	first.refresh()
	await process_frame
	await process_frame
	check(first.debuff_row.visible and first.debuff_row.get_child_count() == 1,
		"Apenas condições aplicadas criam bolinhas clicáveis.")
	var affected_visual := (scene.get_node("MapRoot/DepthSorted/PlayableActors") \
		as PlayablePartyView).visuals_by_slot[&"Playable_1"] as PlayableActorVisual
	check((first.debuff_row.get_child(0) as Control).size.x >= 36.0 \
		and affected_visual.debuff_marker.visible \
		and affected_visual.active_arrow.position.y < affected_visual.debuff_marker.position.y \
		and is_equal_approx(affected_visual.debuff_marker.position.y,
			-float(affected_visual.data.playable_animation.frame_size.y) * 1.7 - 13.0),
		"Debuff ampliado no HUD também aparece junto à cabeça, abaixo da seta.")
	var map_debuff_hit := hud._map_debuff_hit_buttons.get(applied.get_instance_id()) as Button
	check(map_debuff_hit != null and map_debuff_hit.visible,
		"O ícone de Debuff no mapa possui área própria de interação.")
	if map_debuff_hit != null:
		map_debuff_hit.mouse_entered.emit()
		check(hud.debuff_popup.visible \
			and (hud.debuff_popup.get("title_label") as Label).text == sample_debuff.display_name,
			"Pairar sobre o ícone no mapa abre a mesma ficha do HUD.")
		map_debuff_hit.mouse_exited.emit()
		check(not hud.debuff_popup.visible,
			"Retirar o mouse do ícone do mapa fecha a ficha não fixada.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var marker_preview := "user://ppp_debuff_marker_preview.png"
		root.get_texture().get_image().save_png(marker_preview)
		print("DEBUFF_MARKER_PREVIEW=" + ProjectSettings.globalize_path(marker_preview))
	var equipment_row := first.get_node("Margin/Content/Equipment") as Control
	check(first.debuff_row.get_global_rect().position.y \
		>= equipment_row.get_global_rect().end.y + 3.0 \
		and is_equal_approx(first.portrait.get_global_rect().get_center().x,
			(first.get_node("Margin/Content/TopRow/PortraitFrame") as Control).get_global_rect().get_center().x),
		"Debuffs ficam separados dos equipamentos e o retrato fica centralizado.")
	(first.debuff_row.get_child(0) as Control).mouse_entered.emit()
	check(hud.debuff_popup.visible \
		and hud.debuff_popup.get_node("Frame").texture.resource_path.ends_with("uielementx_00002.png") \
		and (hud.debuff_popup.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.79,
		"Debuff mostra ficha cinza translúcida com moldura vermelha ao passar o mouse.")
	var duration_label := hud.debuff_popup.get("duration_label") as Label
	check(duration_label.text == "Turnos restantes: 3" \
		and duration_label.get_theme_font_size("font_size") \
			< (hud.debuff_popup.get("description_label") as Label).get_theme_font_size("font_size"),
		"A linha final mostra o contador de turnos em fonte menor.")
	await process_frame
	var popup_rect := hud.debuff_popup.get_global_rect()
	var popup_labels: Array[Label] = [hud.debuff_popup.get("title_label"),
		hud.debuff_popup.get("type_label"),
		hud.debuff_popup.get("description_label"), duration_label]
	check(popup_rect.size.x <= 360.0,
		"Ficha de Debuff compacta.")
	for label in popup_labels:
		var label_rect := label.get_global_rect()
		check(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER \
			and label_rect.position.x >= popup_rect.position.x + 24.0 \
			and label_rect.end.x <= popup_rect.end.x - 24.0 \
			and label_rect.position.y >= popup_rect.position.y + 16.0 \
			and label_rect.end.y <= popup_rect.end.y - 16.0,
			"Texto do Debuff centralizado e longe da moldura.")
	applied.remaining_turns = 2
	await process_frame
	check(duration_label.text == "Turnos restantes: 2",
		"O contador visível acompanha os turnos restantes da instância.")
	applied.duration_kind = DebuffManager.DURATION_ROUND
	applied.expiration_round_index = gerencia.campaign.get_round_index() + 2
	await process_frame
	check(duration_label.text == "Rodadas restantes: 2",
		"Duração por Rodada usa a virada real da campanha.")
	applied.duration_kind = DebuffData.DurationType.DAYS
	applied.remaining_days = 4
	await process_frame
	check(duration_label.text == "Dias restantes: 4",
		"Duração por Dia mostra os dias restantes da instância.")
	applied.duration_kind = DebuffData.DurationType.UNTIL_CURE
	await process_frame
	check(duration_label.text == "Até curar",
		"Duração aberta mostra o critério de cura em vez de contador fictício.")
	var debuff_click := InputEventMouseButton.new()
	debuff_click.button_index = MOUSE_BUTTON_LEFT
	debuff_click.pressed = true
	(first.debuff_row.get_child(0) as Control).gui_input.emit(debuff_click)
	(first.debuff_row.get_child(0) as Control).mouse_exited.emit()
	check(hud.debuff_popup.visible and bool(hud.debuff_popup.get("pinned")),
		"Clicar fixa a ficha do Debuff, mesmo depois de tirar o mouse da bolinha.")
	first.state.debuffs.erase(applied)
	first.refresh()
	await process_frame
	check(not affected_visual.debuff_marker.visible,
		"O marcador sobre a cabeça desaparece quando a condição é removida.")
	hud.debuff_popup.hide()
	var icon_cases := [
		["doenca_1", Rect2(4, 15, 35, 34)],
		["doenca_2", Rect2(42, 15, 35, 31)],
		["doenca_3", Rect2(80, 14, 38, 35)],
		["terror", Rect2(118, 10, 39, 36)],
		["tristeza", Rect2(157, 14, 36, 32)],
		["atordoado", Rect2(4, 49, 35, 40)],
		["enraizado", Rect2(42, 56, 35, 33)],
		["impedido_de_consumir", Rect2(42, 56, 35, 33)],
		["queimadura", Rect2(80, 49, 38, 41)],
		["charme", Rect2(119, 52, 38, 38)],
		["sangramento", Rect2(157, 57, 36, 32)],
	]
	for icon_case in icon_cases:
		var debuff := load("res://resources/skills/effects/debuffs/%s.tres" % icon_case[0]) as DebuffData
		check(debuff != null and debuff.icon is AtlasTexture \
			and (debuff.icon as AtlasTexture).region == icon_case[1],
			"Ícone de %s usa o recorte correto da folha." % icon_case[0])
	var real_debuff := load("res://resources/skills/effects/debuffs/atordoado.tres") as DebuffData
	var real_instance := DebuffInstanceState.new(real_debuff)
	first.state.debuffs.append(real_instance)
	first.refresh()
	await process_frame
	var real_dot := first.debuff_row.get_child(0) as PanelContainer
	var real_icon := real_dot.get_child(0) as TextureRect
	check(real_icon.texture == real_debuff.icon \
		and real_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST \
		and real_icon.get_global_rect().size.x <= real_dot.get_global_rect().size.x,
		"O HUD mostra o ícone correto, nítido e contido na bolinha clicável.")
	first.state.debuffs.erase(real_instance)
	first.refresh()
	var shirt := load("res://resources/itens/equipments/armaduras/camisa_furada.tres") as ItemData
	var home_clothes := load("res://resources/itens/equipments/armaduras/roupa_de_ficar_em_casa.tres") as ItemData
	check((shirt.icon as AtlasTexture).region.position == Vector2(258, 129) \
		and (home_clothes.icon as AtlasTexture).region.position == Vector2(45, 20),
		"Camisa Furada é a sexta arte; Roupa de Ficar em Casa é a primeira.")
	var armor_slot := first.get_node("Margin/Content/Equipment/Armor") as Control
	var slot_click := InputEventMouseButton.new()
	slot_click.button_index = MOUSE_BUTTON_LEFT
	slot_click.pressed = true
	first._on_equipment_slot_input(slot_click, armor_slot, ItemData.EquipmentSlot.ARMOR)
	check(hud.item_menu.visible and (hud.item_menu.rows.get_child(1) as Button).disabled,
		"Sem armadura carregada, Equipar aparece cinza e bloqueado.")
	var shirt_copy := InventoryItemState.new(shirt)
	first.state.inventory_items.append(shirt_copy)
	first._on_equipment_slot_input(slot_click, armor_slot, ItemData.EquipmentSlot.ARMOR)
	check(not (hud.item_menu.rows.get_child(1) as Button).disabled,
		"Com armadura compatível, Equipar fica habilitado.")
	(hud.item_menu.rows.get_child(1) as Button).pressed.emit()
	var armor_cell := hud.inventory_panel.grid.get_child(0) as Button
	check(hud.inventory_panel.visible and hud.inventory_panel.equip_filter_slot \
		== ItemData.EquipmentSlot.ARMOR and not armor_cell.disabled \
		and armor_cell.get_theme_stylebox("normal") is StyleBoxFlat,
		"Inventário abre com destaque rosa somente nos itens compatíveis.")
	armor_cell.pressed.emit()
	check(first.state.primary_equipped(ItemData.EquipmentSlot.ARMOR) == shirt_copy \
		and first.state.max_health == 31 and first.state.current_health == 31,
		"Selecionar a armadura equipa direto, somando Vida máxima e atual.")
	first.state.current_health = 27
	first._on_equipment_slot_input(slot_click, armor_slot, ItemData.EquipmentSlot.ARMOR)
	check((hud.item_menu.rows.get_child(2) as Button).text == "Desequipar" \
		and (hud.item_menu.rows.get_child(3) as Button).text == "Informações",
		"Slot ocupado oferece Desequipar e Informações.")
	(hud.item_menu.rows.get_child(2) as Button).pressed.emit()
	check(first.state.max_health == 28 and first.state.current_health == 27,
		"Desequipar reduz somente o máximo, sem causar dano na Vida atual.")
	first.state.current_health = first.state.max_health
	var equipment_manager := EquipmentManager.new()
	var equipment_skills := scene.get_node("SkillManager") as SkillManager
	check(equipment_manager.equip(first.state, shirt_copy, equipment_skills,
		gerencia.campaign) and first.state.max_health == 31 \
		and first.state.current_health == 31,
		"Reequipar repete o aumento equivalente de Vida máxima e atual.")
	check(equipment_manager.unequip(first.state, shirt_copy, equipment_skills) \
		and first.state.max_health == 28 and first.state.current_health == 28,
		"Ao tirar a armadura com Vida cheia, a atual é limitada ao novo máximo.")
	first.state.inventory_items.erase(shirt_copy)
	first.state.current_health = first.state.max_health
	first.refresh()
	hud._close_actions()
	scene.reveal_block(Vector2i(0, 2))
	check(hud.hex_title_popup.visible,
		"Revelar um hex mostra o título e o tipo imediatamente.")
	var reveal_click := InputEventMouseButton.new()
	reveal_click.button_index = MOUSE_BUTTON_LEFT
	reveal_click.pressed = true
	scene._on_cell_pressed(Vector2i(0, 2), reveal_click)
	check(hud.hex_choice.visible and (hud.hex_choice_buttons.get_child(0) as Button).text \
		== "ANDAR ATÉ", "Hex revelado ainda oferece Andar até.")
	hud._hide_hex_choice()
	check(hud.dividers[0].visible and hud.dividers[1].visible \
		and hud.dividers[0].texture.resource_path.ends_with("uielementx_00003.png"),
		"A arte ciano separa as três fichas.")
	var visual_party := scene.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
	var selected_visual := visual_party.visuals_by_slot[&"Playable_1"] as PlayableActorVisual
	check(selected_visual.active_arrow.visible \
		and selected_visual.active_arrow.color.a >= 0.3 \
		and selected_visual.active_arrow.color.a <= 0.9 \
		and selected_visual.active_arrow.color.r > 0.9 \
		and selected_visual.active_arrow.color.g > 0.8 \
		and selected_visual.active_arrow.color.b < 0.3 \
		and selected_visual.active_arrow.position.y < selected_visual.animated_sprite.position.y,
		"A seta amarela fica acima da cabeça e pisca sem sumir.")
	first.action_button.emit_signal("pressed")
	check(hud.action_drawer.get_global_rect().end.y <= viewport_size.y,
		"A caixa de ações cabe verticalmente na tela.")
	check(hud.action_drawer.visible and first.action_button.text == "◀",
		"A seta abre a caixa de ações do personagem correspondente.")
	check(hud.action_drawer.size.x >= 292.0 and hud.action_drawer.size.x <= 310.0 \
		and is_equal_approx((hud.action_drawer.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, 0.8),
		"A caixa de ações tem folga horizontal e mantém fundo com 80% de opacidade.")
	check(hud.walk_button.get_theme_font_size("font_size") == roundi(10.0 * 4.0 / 3.0),
		"Botões de ação usam a mesma fonte compacta das Ativas longas.")
	check(hud.action_link.visible and hud.action_link.points.size() == 6 \
		and hud.action_link.default_color.is_equal_approx(Color(0, 0.972549, 0.909804)),
		"Uma linha azul intensa em degrau liga a ficha à caixa de ações.")
	check(hud.walk_button.text == "ANDAR ATÉ" and not hud.walk_button.disabled,
		"A ação de movimento está disponível na Exploração normal.")
	check(hud.inventory_button.text == "INVENTÁRIO" \
		and hud.get_node_or_null("ActionDrawer/Margin/Actions/ActionButton") == null \
		and hud.get_node_or_null("ActionDrawer/Margin/Actions/BackButton") == null,
		"A caixa não tem mais os botões genéricos AÇÃO e VOLTAR.")
	check(hud.passive_buttons.get_child_count() == 1 \
		and hud._action_buttons()[-1] == hud.passive_buttons.get_child(0),
		"A passiva nativa fica por último na lista de ações.")
	var passive_consult := hud.passive_buttons.get_child(0) as Button
	check("INATO: FAROL DE NOTÍCIAS" in passive_consult.text.replace("\n", " "),
		"O botão cinza identifica a passiva nativa pelo título.")
	passive_consult.pressed.emit()
	check(hud.passive_info_popup.visible \
		and "Informação" in (hud.passive_info_popup.get_node(
			"MarginContainer/VBoxContainer/Description") as Label).text,
		"Clicar na passiva abre sua descrição e contexto sem executar efeito.")
	hud.passive_info_popup.hide()
	var journalist_skill_button := hud.skill_buttons.get_child(0) as Button
	check(journalist_skill_button.text.replace("\n", " ") == "FARO JORNALÍSTICO" \
		and not hud.ally_button.visible,
		"A Ativa aparece pelo nome e Aliado só existe com companheiro vinculado.")
	journalist_skill_button.mouse_entered.emit()
	check(hud.skill_info.visible and "revel" in hud.skill_info_description.text.to_lower() \
		and (hud.skill_info.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a > 0.8,
		"Passar o mouse mostra uma caixa informativa mais opaca.")
	journalist_skill_button.mouse_exited.emit()
	check(not hud.skill_info.visible, "A descrição se recolhe ao retirar o mouse.")
	var owner_for_ally := gerencia.campaign.active_entity_states[0]
	var cat_data := load("res://resources/entities/entities_general/companions/gatinho_vira_lata.tres") as EntityData
	var cat := EntityState.from_playable_selection(cat_data, &"Companion_HUD_Test", EntityState.UNPLACED)
	check(gerencia.campaign.register_companion(owner_for_ally, cat),
		"O Gatinho pode ser vinculado ao personagem.")
	hud._process(0.2)
	check(hud.ally_button.visible and hud.ally_skill_buttons.get_child_count() > 0,
		"A caixa do dono ganha Aliado e a Ativa do Gatinho.")
	hud.ally_button.emit_signal("pressed")
	check(hud.ally_drawer.visible \
		and "SEXTO-SENTIDO" in (hud.ally_skill_buttons.get_child(0) as Button).text,
		"O botão Aliado abre a caixa-filha das Ativas do companheiro.")
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var cat_skill := load("res://resources/skills/actives/companions/gatinho_vira_lata/sexto_sentido.tres") as ActiveSkillData
	var cat_extra_sources: Array[StringName] = []
	for index in 6:
		var source_id := StringName("ally_scroll_%d" % index)
		cat_extra_sources.append(source_id)
		skill_manager.grant_skill(cat, cat_skill, &"test", source_id)
	hud._process(0.2)
	await process_frame
	check(hud.ally_skill_buttons.get_child_count() == 7 \
		and hud.ally_scroll_arrows.visible and hud.ally_scroll.get_v_scroll_bar().visible,
		"A caixa-filha do Aliado também limita a seis ações visíveis.")
	hud.ally_scroll_down_button.emit_signal("pressed")
	check(hud._ally_scroll_first_index == 1,
		"A seta do Aliado avança uma habilidade por clique.")
	for source_id in cat_extra_sources:
		skill_manager.remove_source(cat, &"test", source_id)
	gerencia.campaign.companion_states.erase(cat)
	hud._process(0.2)
	check(not hud.ally_button.visible and not hud.ally_drawer.visible,
		"Sem companheiro, Aliado desaparece de novo.")
	var overflow_skill := load("res://resources/skills/actives/playables/jornalista/faro_jornalistico.tres") as ActiveSkillData
	var extra_sources: Array[StringName] = []
	for index in 5:
		var source_id := StringName("hud_scroll_%d" % index)
		extra_sources.append(source_id)
		skill_manager.grant_skill(owner_for_ally, overflow_skill, &"test", source_id)
	hud._process(0.2)
	await process_frame
	check(hud._action_buttons().size() == 9 and hud.scroll_arrows.visible \
		and hud.action_scroll.get_v_scroll_bar().visible,
		"Mais de seis ações mostram rolagem e as duas setas.")
	var visible_actions := 0
	for button in hud._action_buttons():
		if button.get_global_rect().intersects(hud.action_scroll.get_global_rect()):
			visible_actions += 1
	check(visible_actions <= 6, "A caixa não exibe mais de seis ações ao mesmo tempo.")
	var scroll_before := hud.action_scroll.scroll_vertical
	hud.scroll_down_button.emit_signal("pressed")
	check(hud._scroll_first_index == 1 and hud.action_scroll.scroll_vertical > scroll_before,
		"A seta para baixo avança uma ação por clique.")
	visible_actions = 0
	for button in hud._action_buttons():
		if button.get_global_rect().intersects(hud.action_scroll.get_global_rect()):
			visible_actions += 1
	check(visible_actions <= 6, "Após rolar, a caixa continua mostrando no máximo seis ações.")
	hud.scroll_up_button.emit_signal("pressed")
	check(hud._scroll_first_index == 0 and hud.action_scroll.scroll_vertical == 0,
		"A seta para cima retorna uma ação por clique.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var scroll_preview_path := "user://ppp_party_status_hud_scroll_preview.png"
		root.get_texture().get_image().save_png(scroll_preview_path)
		print("HUD_SCROLL_PREVIEW=" + ProjectSettings.globalize_path(scroll_preview_path))
	for source_id in extra_sources:
		skill_manager.remove_source(owner_for_ally, &"test", source_id)
	hud._process(0.2)
	await process_frame
	check(not hud.scroll_arrows.visible and not hud.action_scroll.get_v_scroll_bar().visible,
		"Sem excedentes, setas e barra de rolagem desaparecem.")
	var position_before_choice := owner_for_ally.position
	var map_click := InputEventMouseButton.new()
	map_click.button_index = MOUSE_BUTTON_LEFT
	map_click.pressed = true
	scene._on_cell_pressed(Vector2i(0, 2), map_click)
	check(owner_for_ally.position == position_before_choice and hud.hex_choice.visible \
		and (hud.hex_choice_buttons.get_child(0) as Button).text == "ANDAR ATÉ",
		"Clicar num hex alcançável oferece Andar até sem movimentar automaticamente.")
	hud._hide_hex_choice()
	third.action_button.emit_signal("pressed")
	check(hud.action_drawer.visible and first.action_button.text == "▶" \
		and third.action_button.text == "◀",
		"Só uma caixa de ações fica aberta por vez.")
	check(hud.action_drawer.get_global_rect().end.y <= viewport_size.y,
		"A caixa do terceiro personagem também cabe na tela.")
	third.action_button.emit_signal("pressed")
	check(not hud.action_drawer.visible,
		"A seta fecha a caixa de ações.")
	second.action_button.emit_signal("pressed")
	check(hud.skill_buttons.get_child_count() == 2 \
		and "MURO DE TIJOLO" in (hud.skill_buttons.get_child(0) as Button).text \
		and "QUEBRA DA" in (hud.skill_buttons.get_child(1) as Button).text,
		"As Ativas nativas condicionais e de Combate também aparecem pelo nome.")
	second.action_button.emit_signal("pressed")
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	check(top_bar.day_label.text == "▣ DIA 1" \
		and "MANHÃ" in top_bar.period_label.text \
		and "SUBÚRBIO" in top_bar.district_label.text \
		and "EXPLORAÇÃO" in top_bar.mode_label.text,
		"A faixa superior lê Dia, período, distrito e modo da campanha.")
	check(not scene.get_node("RoundUI/NextPhaseButton").visible,
		"O botão antigo não duplica a nova barra superior.")
	gerencia.campaign.day = 4
	gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	gerencia.campaign.district = &"centro"
	gerencia.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	top_bar.refresh()
	check("DIA 4" in top_bar.day_label.text and "NOITE" in top_bar.period_label.text \
		and "CENTRO" in top_bar.district_label.text \
		and "COMBATE" in top_bar.mode_label.text,
		"A faixa superior acompanha as mudanças reais do estado da campanha.")
	gerencia.campaign.day = 1
	gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
	gerencia.campaign.district = &"suburbio"
	gerencia.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.EXPLORATION
	top_bar.refresh()
	var journalist := gerencia.campaign.active_entity_states[0]
	journalist.current_health -= 3
	journalist.attack += 2
	journalist.stamina_remaining -= 1
	hud._process(0.2)
	check(first.health_label.text == "VIDA: 25/28" \
		and first.attack_label.text == "ATK: 6" \
		and first.stamina_label.text == "STAMINA: 3",
		"Os valores mudam junto com o estado durante a partida.")
	var backpack := load("res://resources/itens/equipments/acessorios/mochila_cor_de_rosa.tres") as ItemData
	var large_name := load("res://resources/itens/equipments/acessorios/acessorio_epico_mochila_do_mochileiro_das_galaxias.tres") as ItemData
	journalist.inventory_items.append(InventoryItemState.new(backpack))
	journalist.inventory_items.append(InventoryItemState.new(large_name))
	journalist.inventory_capacity_bonus = 3
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	first._gui_input(click)
	check(hud.inspect_bubble.visible and hud.character_sheet.visible == false,
		"Clicar no quadro abre o balão !, sem disparar ações.")
	hud.inspect_bubble.mouse_entered.emit()
	check(hud.bubble_hint.visible,
		"Pairar sobre o balão mostra Abrir ficha.")
	hud.inspect_bubble.pressed.emit()
	check(hud.character_sheet.visible and hud.character_sheet.actor == journalist,
		"O balão abre a ficha do personagem.")
	hud.character_sheet.close_button.pressed.emit()
	first.action_button.pressed.emit()
	check(hud.action_drawer.visible,
		"A seta continua sendo o comando para abrir ações.")
	hud.inventory_button.emit_signal("pressed")
	var inventory := hud.inventory_panel
	check(inventory.visible and inventory.grid.get_child_count() == 12,
		"O inventário abre em outra caixa com 12 espaços iniciais.")
	check(inventory.size.x <= 340.0 and inventory.grid.columns == 3 \
		and is_equal_approx((inventory.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, 0.8),
		"O inventário acomoda os itens e a fonte maior, com fundo translúcido.")
	await create_timer(0.23).timeout
	check(inventory.get_global_rect().position.x \
		>= hud.action_drawer.get_global_rect().end.x + 10.0,
		"As duas caixas expansivas mantêm um vão para a linha ciano.")
	check(inventory.get_global_rect().position.y >= 56.0,
		"O inventário não esconde a faixa superior da campanha.")
	check(inventory.expand_button.visible and inventory.capacity_label.text == "ESPAÇOS: 2 / 15",
		"A seta de expansão segue os bônus reais do EntityState.")
	var filled_cell := inventory.grid.get_child(0) as Button
	check((filled_cell.get_child(0) as TextureRect).texture.resource_path.ends_with("uielementx_00002.png") \
		and (filled_cell.get_node("Icon") as TextureRect).texture == backpack.icon,
		"A arte rosa é a moldura e o ícone do item fica dentro dela.")
	check(filled_cell.get_node_or_null("ItemName") == null and filled_cell.text.is_empty(),
		"Cada casa mostra apenas o ícone, sem nome ou número.")
	filled_cell.pressed.emit()
	check(hud.item_menu.visible and hud.item_menu.entry.data == backpack,
		"O clique no item abre o menu com as ações disponíveis.")
	hud.item_menu._details()
	var details := hud.item_details_panel
	await create_timer(0.23).timeout
	check(details.visible and details.entry.data == backpack \
		and details.get_global_rect().position.x >= inventory.get_global_rect().end.x + 8.0,
		"O botão Detalhes abre a ficha ao lado do inventário.")
	# Dado e moeda são provisórios: caixas expansivas podem cobri-los.
	check(details.get_global_rect().position.y >= 56.0 \
		and details.get_global_rect().end.y <= viewport_size.y,
		"Os detalhes preservam a faixa superior e não saem da tela.")
	check(is_equal_approx((details.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a, 0.8) \
		and (details.get_theme_stylebox("panel") as StyleBoxFlat).border_color.r > 0.9,
		"Detalhes têm fundo a 80% e borda rosa.")
	check(details.name_label.text == backpack.display_name \
		and details.name_label.get_theme_font("font") == ItemDetailsPanel.BOLD_FONT \
		and details.name_label.get_theme_color("font_color") == Color.WHITE \
		and backpack.description in details.effect_label.text,
		"Nome completo aparece em negrito branco, com a descrição abaixo.")
	var details_frame := details.get_node("Frame") as TextureRect
	check(details_frame.texture.resource_path.ends_with("uielementx_00001.png") \
		and details_frame.material is ShaderMaterial,
		"Os detalhes do item usam a moldura rosa clara translúcida.")
	check(details.visible and details.get_global_rect().end.y <= viewport_size.y,
		"Os detalhes permanecem dentro da área visível.")
	hud._process(0.2)
	var next_phase_button := scene.get_node("RoundUI/NextPhaseButton") as Button
	next_phase_button.show()
	hud._process(0.2)
	check(details.get_global_rect().end.y <= next_phase_button.get_global_rect().position.y - 6.0,
		"A caixa de detalhes também preserva o botão Próxima fase quando ele aparece.")
	next_phase_button.hide()
	hud._process(0.2)
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	drag_press.position = details.drag_header.get_global_rect().position + Vector2(40, 10)
	details._input(drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = Vector2(3000, 3000)
	details._input(drag_motion)
	check(details.user_positioned and details.get_global_rect().end.x <= viewport_size.x - 15.0 \
		and details.get_global_rect().end.y <= viewport_size.y - 15.0,
		"Detalhes podem ser arrastados e param a 15 px da borda.")
	drag_press.pressed = false
	details._input(drag_press)
	var long_name_cell := inventory.grid.get_child(1) as Button
	long_name_cell.pressed.emit()
	hud.item_menu._details()
	await process_frame
	check(details.name_label.text == large_name.display_name \
		and "Espaço ocupado: 1" in details.stats_label.text \
		and "Passivas:" in details.stats_label.text,
		"Outro item atualiza título e estatísticas diretamente do Resource.")
	var snack := load("res://resources/itens/consumables/pipoca_de_rua.tres") as ItemData
	var rotten := load("res://resources/itens/states/apodrecido.tres") as ItemStateData
	var rotten_copy := InventoryItemState.new(snack)
	rotten_copy.states.append(rotten)
	journalist.inventory_items.append(rotten_copy)
	inventory.refresh()
	var rotten_cell := inventory.grid.get_child(2) as Button
	check((rotten_cell.get_node("Icon") as TextureRect).material is ShaderMaterial \
		and (rotten_cell.get_node("RottenX") as Label).text == "X" \
		and (rotten_cell.get_node("RottenX") as Label).get_theme_color("font_color").r > 0.9,
		"Consumível apodrecido recebe ícone cinza com X vermelho.")
	rotten_cell.pressed.emit()
	hud.item_menu._details()
	await process_frame
	check("Apodrecido" in details.effect_label.text \
		and "Este item não pode recuperar Vida" in details.effect_label.text,
		"Os detalhes mostram o estado da cópia apodrecida.")
	inventory.expand_button.emit_signal("pressed")
	check(inventory.grid.get_child_count() == 15 and inventory.expanded,
		"A seta expande o inventário quando há espaços extras.")
	check(inventory.get_global_rect().end.y <= viewport_size.y,
		"O inventário expandido continua dentro da tela.")
	first.action_button.emit_signal("pressed")
	check(not hud.action_drawer.visible and not inventory.visible,
		"A seta da ficha minimiza ações e inventário.")
	third.state.turn_state = EntityState.TurnState.INACTIVE
	hud._process(0.2)
	visual_party._on_turn_started(scene.get_node("ExplorationManager").current_actor)
	var inactive_visual := visual_party.visuals_by_slot[&"Playable_3"] as PlayableActorVisual
	inactive_visual._process(0.0)
	check(not third.action_button.disabled and third.portrait.material is ShaderMaterial \
		and (third.get_theme_stylebox("panel") as StyleBoxFlat).border_color \
		== PartyCharacterCard.INACTIVE_BORDER \
		and third.name_label.get_theme_color("font_color") == Color(0.55, 0.57, 0.59),
		"Retrato, nome e margem ficam cinza; a seta ainda pode abrir ações limitadas.")
	check(inactive_visual.animated_sprite.material == null \
		and inactive_visual.modulate == Color.WHITE \
		and not inactive_visual.active_arrow.visible,
		"O personagem no mapa mantém suas cores, mas não recebe a seta quando inativo.")
	third._gui_input(click)
	third.action_button.emit_signal("pressed")
	check(hud.action_drawer.visible and hud.walk_button.disabled \
		and not hud.inventory_button.disabled,
		"A ficha inativa abre, mas só o inventário permanece disponível.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		first.action_button.emit_signal("pressed")
		hud.inventory_button.emit_signal("pressed")
		(hud.inventory_panel.grid.get_child(1) as Button).pressed.emit()
		await create_timer(0.23).timeout
		var preview_path := "user://ppp_party_status_hud_preview.png"
		root.get_texture().get_image().save_png(preview_path)
		print("HUD_PREVIEW=" + ProjectSettings.globalize_path(preview_path))
	print("PPP party HUD: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
