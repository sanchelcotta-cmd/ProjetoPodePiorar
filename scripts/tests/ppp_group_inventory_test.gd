extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
	]
	check(gerencia.start_new_game(choices), "A campanha cria três Playables.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"O mapa inicia com os três escolhidos.")
	await process_frame
	var actor := gerencia.campaign.active_entity_states[0]
	# Este teste mede apenas transferências/equipamento adicionados abaixo;
	# o novo kit sorteado de início é verificado em teste próprio.
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var equipment := EquipmentManager.new()
	for member in gerencia.campaign.active_entity_states:
		for slot in [ItemData.EquipmentSlot.WEAPON,
				ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
			for entry in member.equipped_in_slot(slot).duplicate():
				equipment.unequip(member, entry, skill_manager)
		member.inventory_items.clear()
	var weapon := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	var weapon_copy := InventoryItemState.new(weapon)
	actor.inventory_items.append(weapon_copy)
	var attack_before := actor.attack
	check(equipment.equip(actor, weapon_copy, skill_manager, gerencia.campaign),
		"Um item carregado pode ocupar o slot de arma.")
	check(actor.primary_equipped(ItemData.EquipmentSlot.WEAPON) == weapon_copy
		and weapon_copy not in actor.inventory_items and actor.inventory_used_space() == 0,
		"Equipado deixa de ocupar os 12 espaços carregados, sem criar cópia.")
	check(actor.attack == attack_before + weapon.bonus_attack + weapon.mastery_bonus
		and actor.get_mastery_level(weapon.mastery_granted) == weapon.mastery_bonus,
		"Arma correspondente soma Ataque e bônus de Maestria uma vez.")
	check("Maestria correspondente" in EntityStatBreakdown.colored_text(actor, "attack"),
		"O detalhamento do Ataque identifica o bônus de Maestria da arma.")
	var mismatched := gerencia.campaign.active_entity_states[1]
	var mismatched_attack := mismatched.attack
	var mismatched_copy := InventoryItemState.new(weapon)
	mismatched.inventory_items.append(mismatched_copy)
	check(equipment.equip(mismatched, mismatched_copy, skill_manager, gerencia.campaign),
		"Personagem de Impacto também pode equipar arma de Distância.")
	check(not mismatched.has_mastery(EntityData.Mastery.RANGED)
		and mismatched.get_mastery_level(EntityData.Mastery.RANGED) == 0
		and mismatched.attack == mismatched_attack + weapon.bonus_attack,
		"Arma incompatível soma só Ataque; não concede Maestria nem seu bônus.")
	check(equipment.unequip(mismatched, mismatched_copy, skill_manager)
		and mismatched.attack == mismatched_attack,
		"Desequipar a arma incompatível restaura o Ataque.")
	var student_data := load("res://resources/entities/entities_playable/universitario.tres") as EntityData
	var student := EntityState.from_playable_selection(student_data, &"StudentTest",
		EntityState.UNPLACED)
	var student_copy := InventoryItemState.new(weapon)
	student.inventory_items.append(student_copy)
	check(equipment.equip(student, student_copy, skill_manager),
		"Universitário sem Maestria também consegue equipar a arma.")
	check(not student.has_mastery(EntityData.Mastery.RANGED)
		and student.attack == student_data.ataque_base + weapon.bonus_attack,
		"Equipamento não ensina Maestria ao Universitário.")
	var sniper := load("res://resources/itens/equipments/armaduras/armadura_epica_traje_do_sniper.tres") as ItemData
	var sniper_actor := EntityState.from_playable_selection(choices[0], &"SniperTest",
		EntityState.UNPLACED)
	var sniper_copy := InventoryItemState.new(sniper)
	sniper_actor.inventory_items.append(sniper_copy)
	var sniper_attack := sniper_actor.attack
	check(equipment.equip(sniper_actor, sniper_copy, skill_manager),
		"Traje do Sniper pode ser equipado por quem tem Distância.")
	check(sniper_actor.attack == sniper_attack + sniper.bonus_attack + sniper.mastery_bonus
		and sniper_actor.get_mastery_level(EntityData.Mastery.RANGED) == sniper.mastery_bonus,
		"O bônus de Maestria da armadura vale se a Maestria própria corresponder.")
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	hud.cards[0].refresh()
	check(hud.cards[0].weapon_icon.texture == weapon.icon,
		"O HUD mostra a arma realmente equipada.")
	var backpack := load("res://resources/itens/equipments/acessorios/mochila_cor_de_rosa.tres") as ItemData
	var backpack_copy := InventoryItemState.new(backpack)
	actor.inventory_items.append(backpack_copy)
	check(equipment.equip(actor, backpack_copy, skill_manager, gerencia.campaign),
		"A mochila equipa como acessório.")
	check(actor.inventory_capacity() == 15 and actor.inventory_used_space() == 0,
		"A mochila acrescenta 3 espaços; ela própria não ocupa inventário.")
	var armor := load("res://resources/itens/equipments/armaduras/armadura_de_papelao.tres") as ItemData
	var armor_copy := InventoryItemState.new(armor)
	actor.inventory_items.append(armor_copy)
	check(equipment.equip(actor, armor_copy, skill_manager, gerencia.campaign),
		"O terceiro espaço pode receber uma armadura.")
	check(actor.equipped_weapons.size() == 1 and actor.equipped_armors.size() == 1
		and actor.equipped_accessories.size() == 1,
		"Arma, armadura e acessório permanecem em três espaços equipados distintos.")
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	top_bar.group_inventory_button.pressed.emit()
	await process_frame
	var group := top_bar.group_inventory
	check(group.visible and group.columns.size() == 3,
		"O botão abre três colunas lado a lado.")
	var inventory_before_drag := group.window.position
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	group._on_header_gui_input(drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(35.0, 18.0)
	group._input(drag_motion)
	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	group._input(drag_release)
	check(group.window.position.is_equal_approx(inventory_before_drag + drag_motion.relative),
		"Arrastar a faixa superior move o Inventário do Grupo.")
	group._layout_window()
	check(group.window.position.is_equal_approx(inventory_before_drag + drag_motion.relative),
		"Atualizar o layout não desfaz a posição escolhida pelo jogador.")
	var clamped_inventory := group._clamp_window_position(Vector2(9999.0, -9999.0))
	check(clamped_inventory.x <= group.get_viewport_rect().size.x - group.window.size.x - 15.0 \
		and clamped_inventory.y >= 15.0,
		"O arrasto do Inventário respeita a margem de 15 px da câmera.")
	for index in 3:
		var card := group.columns[index]["card"] as Control
		var frame := card.get_node("BlockActivationFrame") as Panel
		check(frame != null and frame.mouse_filter == Control.MOUSE_FILTER_IGNORE \
			and (frame.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 2,
			"Cada personagem usa margem rosa simples sem decoração de canto.")
	check((group.columns[0]["name"] as Label).text == "JORNALISTA"
		and (group.columns[1]["name"] as Label).text == "PEDREIRO",
		"Cada coluna lê o personagem da vaga correspondente.")
	var views: Array = group.columns[0]["equipment_views"]
	check((views[0]["icon"] as TextureRect).texture == weapon.icon
		and (views[1]["icon"] as TextureRect).texture == armor.icon
		and (views[2]["icon"] as TextureRect).texture == backpack.icon,
		"A janela mostra os três equipamentos nos slots corretos.")
	check((group.columns[0]["expand"] as Button).visible,
		"A expansão fica disponível para quem equipou a mochila.")
	(group.columns[0]["expand"] as Button).pressed.emit()
	check((group.columns[0]["grid"] as GridContainer).get_child_count() == 15,
		"Expandir mostra todos os 15 espaços carregados possíveis.")
	var carried_to_other := InventoryItemState.new(weapon)
	actor.inventory_items.append(carried_to_other)
	group.drop_inventory_entry(actor, mismatched, carried_to_other, 2)
	check(carried_to_other not in actor.inventory_items \
		and carried_to_other in mismatched.inventory_items,
		"Arrastar entre colunas transfere a mesma cópia ao outro inventário.")
	var equipped_to_other := InventoryItemState.new(weapon)
	actor.inventory_items.append(equipped_to_other)
	group.drop_equipment_entry(actor, mismatched, equipped_to_other,
		ItemData.EquipmentSlot.WEAPON)
	check(mismatched.primary_equipped(ItemData.EquipmentSlot.WEAPON) == equipped_to_other \
		and equipped_to_other not in actor.inventory_items,
		"Soltar no slot de Equipados veste a cópia diretamente no outro jogável.")
	var replacement_to_other := InventoryItemState.new(weapon)
	actor.inventory_items.append(replacement_to_other)
	group.drop_equipment_entry(actor, mismatched, replacement_to_other,
		ItemData.EquipmentSlot.WEAPON)
	check(mismatched.primary_equipped(ItemData.EquipmentSlot.WEAPON) == replacement_to_other \
		and equipped_to_other in actor.inventory_items,
		"Substituir equipamento devolve a peça antiga ao inventário de origem.")
	actor.inventory_items.clear()
	for index in 12:
		actor.inventory_items.append(InventoryItemState.new(weapon))
	check(actor.inventory_used_space() == 12 and actor.equipped_weapons.size()
		+ actor.equipped_armors.size() + actor.equipped_accessories.size() == 3,
		"Três equipados e doze carregados são quinze itens separados.")
	group.refresh()
	var first_cell := (group.columns[0]["grid"] as GridContainer).get_child(0) as Button
	first_cell.pressed.emit()
	check(group.craft_panel.visible,
		"Clicar num item com três cópias do mesmo dono abre o craft automaticamente.")
	group.craft_panel.close()
	var inspect_click := InputEventMouseButton.new()
	inspect_click.button_index = MOUSE_BUTTON_RIGHT
	inspect_click.pressed = true
	group._on_inventory_cell_input(inspect_click, 0, actor.inventory_items[0], first_cell)
	check(group.item_menu.visible and group.item_menu.entry == actor.inventory_items[0]
		and not group.details.visible,
		"Clique direito preserva o menu de ações do item craftável.")
	check(group.item_menu.menu.get_global_rect().position.x \
		>= group.window.get_global_rect().end.x,
		"O menu compacto abre ao lado da janela do grupo, sem cobrir os itens.")
	group.item_menu._details()
	check(group.details.visible and group.details.entry == actor.inventory_items[0],
		"O botão Detalhes abre a descrição do item.")
	await create_timer(0.06).timeout
	check(group.details.get_global_rect().position.x \
		>= group.window.get_global_rect().end.x and group.details_link.visible,
		"A ficha fica fora da janela do grupo e recebe uma linha azul.")
	check(not equipment.unequip(actor, backpack_copy, skill_manager),
		"Não desequipa a mochila se isso estouraria os 12 espaços restantes.")
	actor.inventory_items.remove_at(actor.inventory_items.size() - 1)
	actor.inventory_items.remove_at(actor.inventory_items.size() - 1)
	check(equipment.unequip(actor, backpack_copy, skill_manager),
		"Com espaço livre, a mochila volta ao inventário.")
	check(actor.inventory_capacity() == 12 and backpack_copy in actor.inventory_items,
		"Desequipar retira apenas o bônus da mochila e devolve a mesma cópia.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	group._input(escape)
	check(not group.details.visible and group.visible,
		"O primeiro Esc fecha os detalhes, mantendo o inventário aberto.")
	group._input(escape)
	check(not group.visible, "O segundo Esc fecha o inventário do grupo.")
	group.close()
	check(not group.visible, "O X/fechar oculta a janela.")
	print("Inventário do grupo/equipamentos: %s" % ("OK" if failures == 0 else "%d FALHAS" % failures))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
