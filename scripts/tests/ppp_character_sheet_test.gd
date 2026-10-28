extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var manager := scene.get_node("SkillManager") as SkillManager
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
	]
	check(gerencia.start_new_game(choices), "O grupo inicia com três personagens.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"O mapa inicia para testar cliques nos sprites.")
	await process_frame
	var first := hud.cards[0]
	var third := hud.cards[2]
	var actor := first.state
	# Isola a ficha das habilidades do kit aleatório recebido no início.
	var equipment := EquipmentManager.new()
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		for equipped in actor.equipped_in_slot(slot).duplicate():
			check(equipment.unequip(actor, equipped, manager),
				"Kit inicial removido do cenário da ficha.")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	first._gui_input(click)
	check(hud.inspect_bubble.visible and not hud.action_drawer.visible,
		"Clicar no quadro mostra ! sem ativar ações.")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(1000, 600)
	hud._input(outside)
	check(not hud.inspect_bubble.visible,
		"O balão ! desaparece ao clicar fora dele.")
	first._gui_input(click)
	hud.inspect_bubble.mouse_entered.emit()
	check(hud.bubble_hint.visible and hud.bubble_hint.get_node("Text").text \
		.contains("ABRIR FICHA"), "O balão mostra Abrir ficha no hover.")
	hud.inspect_bubble.pressed.emit()
	var sheet := hud.character_sheet
	check(sheet.visible and sheet.actor == actor and sheet.page_index == 0 \
		and sheet.skill_list.get_child_count() == 2,
		"Página inicial mostra as Ativas e Passivas nativas.")
	check(sheet.name_label.text == "JORNALISTA" and sheet.portrait.texture != null \
		and sheet.health_label.text == "VIDA: %d / %d" % [actor.current_health, actor.max_health],
		"A ficha mostra nome, imagem e atributos do estado atual.")
	await create_timer(0.22).timeout
	check(not sheet.has_node("Frame") \
		and (sheet.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left == 2,
		"A ficha usa borda rosa simples, sem a moldura decorativa.")
	var sheet_margin := sheet.get_node("Margin") as MarginContainer
	check(sheet.name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
		and sheet_margin.get_theme_constant("margin_left") >= 18
		and sheet_margin.get_theme_constant("margin_right") >= 18,
		"Nome centralizado e textos afastados da borda da ficha.")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = sheet.drag_header.get_global_rect().position + Vector2(45, 12)
	sheet._input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(-500, -500)
	sheet._input(drag)
	check(sheet.user_positioned and sheet.position.x >= 15.0 and sheet.position.y >= 15.0,
		"A ficha pode ser arrastada sem sair da tela (margem de 15 px).")
	press.pressed = false
	sheet._input(press)
	var learned := load("res://resources/skills/actives/playables/jornalista/faro_jornalistico.tres") \
		as ActiveSkillData
	for index in 5:
		manager.grant_skill(actor, learned, &"event", StringName("ficha_%d" % index))
	sheet.refresh_live()
	check(sheet._page_count() == 3 and sheet.next_button.disabled == false,
		"Cinco habilidades adquiridas geram páginas 2 e 3.")
	sheet.next_button.pressed.emit()
	check(sheet.page_index == 1 and sheet.skill_list.get_child_count() == 4 \
		and sheet.page_heading.text == "HABILIDADES ADQUIRIDAS",
		"A segunda página lista as primeiras quatro habilidades adquiridas.")
	sheet.next_button.pressed.emit()
	check(sheet.page_index == 2 and sheet.skill_list.get_child_count() == 1 \
		and sheet.next_button.disabled,
		"A terceira página contém o restante sem esconder descrições.")
	sheet.previous_button.pressed.emit()
	check(sheet.page_index == 1, "A seta anterior retorna uma página.")
	for index in 5:
		manager.remove_source(actor, &"event", StringName("ficha_%d" % index))
	sheet.refresh_live()
	check(sheet._page_count() == 1 and sheet.page_index == 0,
		"Ao perder a origem, páginas adquiridas desaparecem.")
	var armor := ItemData.new()
	armor.display_name = "Armadura"
	var item_grant := SkillGrantState.new(learned, &"item", &"armadura_teste")
	item_grant.bound_source = armor
	item_grant.applied_stat_contributions["max_hp"] = 5
	actor.skill_grants.append(item_grant)
	actor.max_health += 5
	actor.max_health += 7
	var penalty := DebuffData.new()
	penalty.display_name = "Fraqueza"
	var debuff := DebuffInstanceState.new(penalty)
	debuff.applied_max_health_delta = -3
	debuff.duration_kind = DebuffData.DurationType.TURNS
	actor.debuffs.append(debuff)
	actor.max_health -= 3
	sheet.refresh_live()
	first.health_label.mouse_entered.emit()
	var breakdown := hud.stat_tooltip_text.text
	check(hud.stat_tooltip.visible and "28 base" in breakdown \
		and "+ 5 Armadura (bônus temporário)" in breakdown \
		and "+ 7 bônus permanente" in breakdown \
		and "- 3 Fraqueza (penalidade temporária)" in breakdown \
		and "#65df86" in breakdown and "#ff6678" in breakdown,
		"O hover de Vida mostra base, item, bônus e debuff com duração e cores.")
	first.health_label.mouse_exited.emit()
	check(not hud.stat_tooltip.visible, "A decomposição some ao sair do atributo.")
	sheet.health_label.mouse_entered.emit()
	check(hud.stat_tooltip.visible and hud.stat_tooltip_text.text == breakdown,
		"A ficha usa a mesma decomposição de Vida que o HUD.")
	sheet.health_label.mouse_exited.emit()
	actor.attack += 2
	first.attack_label.mouse_entered.emit()
	check("4 base" in hud.stat_tooltip_text.text \
		and "+ 2 bônus permanente" in hud.stat_tooltip_text.text,
		"Ataque também detalha as parcelas.")
	first.attack_label.mouse_exited.emit()
	actor.max_stamina -= 1
	actor.round_stamina_penalty = 1
	first.stamina_label.mouse_entered.emit()
	check("4 base" in hud.stat_tooltip_text.text \
		and "- 1 Rodada (penalidade temporária)" \
			in hud.stat_tooltip_text.text,
		"Estamina identifica a penalidade temporária da Rodada.")
	first.stamina_label.mouse_exited.emit()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	sheet._input(esc)
	check(not sheet.visible, "Esc fecha a janela.")
	third.state.turn_state = EntityState.TurnState.INACTIVE
	hud._process(0.2)
	third._gui_input(click)
	check(hud.inspect_bubble.visible and not hud.action_drawer.visible,
		"Personagem indisponível ainda pode ser consultado.")
	third.info_button.pressed.emit()
	check(sheet.visible and sheet.actor == third.state,
		"O botão ⓘ abre a ficha mesmo quando o personagem está inativo.")
	hud._close_character_sheet()
	hud._update_map_hit_targets()
	var map_hit := hud.map_hit_targets.get_node("MapCharacter_1") as Button
	check(map_hit.visible and map_hit.size.x > 20.0,
		"O sprite do mapa possui uma área clicável sobre o personagem.")
	map_hit.pressed.emit()
	check(hud.inspect_bubble.visible and hud._inspection_actor == actor,
		"Clicar no personagem do mapa mostra o mesmo balão !.")
	hud.inspect_bubble.hide()
	var map_down := InputEventMouseButton.new()
	map_down.button_index = MOUSE_BUTTON_LEFT
	map_down.position = map_hit.get_global_rect().get_center()
	map_down.global_position = map_down.position
	map_down.pressed = true
	root.push_input(map_down, true)
	var map_up := InputEventMouseButton.new()
	map_up.button_index = MOUSE_BUTTON_LEFT
	map_up.position = map_down.position
	map_up.global_position = map_down.global_position
	map_up.pressed = false
	root.push_input(map_up, true)
	await process_frame
	check(hud.inspect_bubble.visible and not hud.hex_choice.visible,
		"Um clique real no sprite abre a consulta sem selecionar o hex atrás dele.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		hud.inspect_bubble.pressed.emit()
		await create_timer(0.25).timeout
		await process_frame
		check(sheet.get_global_rect().end.y <= sheet.get_viewport_rect().size.y,
			"A ficha compacta cabe inteira na área visível atual.")
		var path := "user://ppp_character_sheet_preview.png"
		root.get_texture().get_image().save_png(path)
		print("SHEET_PREVIEW=" + ProjectSettings.globalize_path(path))
		sheet.health_label.mouse_entered.emit()
		await process_frame
		await process_frame
		var stats_path := "user://ppp_character_stats_preview.png"
		root.get_texture().get_image().save_png(stats_path)
		print("STATS_PREVIEW=" + ProjectSettings.globalize_path(stats_path))
	print("PPP character sheet: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
