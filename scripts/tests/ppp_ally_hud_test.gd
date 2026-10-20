extends SceneTree

## HUD do aliado, equipamento contextual e clique no corpo em Combate.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var combat := scene.get_node("CombatManager") as CombatManager
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/professora.tres"),
		load("res://resources/entities/entities_playable/universitario.tres"),
	]
	_check(game.start_new_game(selected) and rounds.start_first_map(),
		"Partida e mapa iniciam.")
	var campaign := game.campaign
	var owner := campaign.active_entity_states[0]
	var cook := load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData
	var ally := EntityState.from_playable_selection(cook, &"AllyCook", EntityState.UNPLACED)
	ally.playable_slot_id = &""
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	_check(campaign.register_companion(owner, ally, rng, skills),
		"Aliado humano recrutado com seus itens iniciais.")
	hud._on_action_toggle_requested(hud.cards[0])
	hud._on_ally_pressed()
	await process_frame
	_check(hud.ally_drawer.size.y <=
		hud.ally_drawer.get_combined_minimum_size().y + 2.0,
		"Ficha do aliado encolhe até caber seu conteúdo, sem faixa vazia.")
	_check(hud.ally_drawer.visible and hud._ally_summary.text == cook.display_name
		and not hud._ally_summary.text.contains("ALIADO HUMANO"),
		"Nome do aliado aparece sozinho sob o retrato.")
	_check(hud._ally_equipment.visible and hud._ally_equipment.get_child_count() == 3,
		"Três slots equipados aparecem abaixo das Ativas.")
	for slot in hud._ally_equipment.get_children():
		_check((slot.get_node("ItemIcon") as TextureRect).texture != null,
			"Item inicial usa ícone no slot equipado.")
	hud._ally_info_button.pressed.emit()
	_check(hud.character_sheet.visible and hud.character_sheet.actor == ally,
		"ⓘ abre a ficha completa com descrição e Skills.")
	hud.character_sheet.close_sheet()
	var weapon_button := hud._ally_equipment.get_child(0) as Button
	weapon_button.pressed.emit()
	_check(hud.item_menu.visible and hud.item_menu.companion_mode,
		"Slot equipado abre menu rosa do aliado.")
	var captions: Array[String] = []
	for child in hud.item_menu.rows.get_children():
		if child is Button:
			captions.append((child as Button).text)
	_check("Transferir para" in captions and "Detalhes" in captions
		and "Desequipar" in captions,
		"Equipado oferece transferir, detalhes e desequipar.")
	var output_dir := "res://docs/ally_hud_preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	await process_frame
	_check(root.get_texture().get_image().save_png("%s/aliado.png" % output_dir) == OK,
		"Captura do HUD do aliado gerada.")
	var unequip := _find_button(hud.item_menu.rows, "Desequipar")
	var old_weapon := ally.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	_check(unequip != null and not unequip.disabled, "Desequipar está disponível.")
	if unequip != null and not unequip.disabled:
		unequip.pressed.emit()
	_check(old_weapon in owner.inventory_items
		and ally.primary_equipped(ItemData.EquipmentSlot.WEAPON) == null,
		"Desequipar devolve a mesma cópia ao inventário do dono.")
	var cultist := load("res://resources/entities/entities_general/cultista_encapuzado.tres") as EntityData
	var tamed := EntityState.from_encounter_member(cultist, &"OtherEncounter", 1,
		EntityState.UNPLACED)
	_check(campaign.register_companion(owner, tamed, rng, skills),
		"Criatura adestrada vira aliada.")
	hud._on_ally_selected(1)
	_check(hud._ally_summary.text == cultist.display_name
		and not hud._ally_equipment.visible,
		"Criatura usa seu próprio nome, não o do Encontro; não equipa.")
	owner.position = Vector2i(3, 2)
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	campaign.obtained_information_ids[&"ally_hud_test_info"] = true
	campaign.current_map.set_ppp_block(owner.position, HexGrid.PPPBlockType.ENCOUNTER,
		encounter)
	_check(block.begin_activation(owner.position, owner), "Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(combat.enemies.size() > 0, "Combate inicia com inimigo.")
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": owner})
	combat.initiative_order.append({"entity": ally})
	combat.initiative_order.append({"entity": combat.enemies[0]})
	combat._start_combat_turns()
	await process_frame
	hud._update_map_hit_targets()
	var hit := hud._companion_map_hit_buttons.get(ally.instance_id) as Button
	_check(hit != null and hit.visible, "Corpo do aliado é clicável no mapa de Combate.")
	if hit != null and hit.visible:
		hud._on_map_companion_pressed(ally)
		_check(hud.hex_choice.visible and hud._companion_action_choice_open,
			"Clique no aliado abre sua caixa sobre a cabeça.")
		_check((hud.hex_choice_buttons.get_child(0) as Button).disabled
			and (hud.hex_choice_buttons.get_child(1) as Button).disabled
			and (hud.hex_choice_buttons.get_child(2) as Button).disabled,
			"Antes do turno, rolar, reposicionar e atacar ficam cinzas.")
		_check(_find_button(hud.hex_choice_buttons, "MURO DE TIJOLO") != null,
			"Clique no aliado preserva Ativas do personagem atual que o alvejam.")
		hud._hide_hex_choice()
	combat.end_current_turn()
	await create_timer(0.15).timeout
	hud._update_map_hit_targets()
	if hit != null and hit.visible:
		hud._on_map_companion_pressed(ally)
		_check(combat.current_actor == ally
			and not (hud.hex_choice_buttons.get_child(0) as Button).disabled
			and (hud.hex_choice_buttons.get_child(1) as Button).disabled
			and not (hud.hex_choice_buttons.get_child(
				hud.hex_choice_buttons.get_child_count() - 1) as Button).disabled,
			"No turno do aliado, dado e encerrar habilitam; movimento aguarda dado.")
		_check(hud.hex_choice.position.y >= 56.0
			and hud.hex_choice.position.y + hud.hex_choice.size.y
				<= minf(hit.get_global_rect().position.y, root.size.y * 0.62),
			"Caixa fica acima do corpo, abaixo da UI e fora do chão.")
		await process_frame
		_check(root.get_texture().get_image().save_png("%s/combate.png" % output_dir) == OK,
			"Captura das ações de Combate gerada.")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = Vector2(1380, 700)
		hud._input(click)
		_check(not hud.hex_choice.visible, "Clique fora fecha a caixa do aliado.")
	print("PPP_ALLY_HUD_OK" if failures == 0 else "PPP_ALLY_HUD_FAILED:%d" % failures)
	quit(0 if failures == 0 else 1)


func _find_button(container: Node, caption: String) -> Button:
	for child in container.get_children():
		if child is Button and (child as Button).text == caption:
			return child as Button
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
