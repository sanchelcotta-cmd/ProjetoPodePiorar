extends SceneTree

## Contrato de Ativas em Combate: inata, adquirida e disparo hostil.

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"A campanha inicia para testar Ativas de Combate.")
	var professora := gerencia.campaign.active_entity_states[0]
	var pedreiro := gerencia.campaign.active_entity_states[1]
	var companion_data := load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData
	var companion := EntityState.from_playable_selection(companion_data,
		&"Muro_Companion_Test", EntityState.UNPLACED)
	companion.playable_slot_id = &""
	check(gerencia.campaign.register_companion(pedreiro, companion),
		"Um aliado recrutado pode ser escolhido pelo Pedreiro.")
	professora.position = Vector2i(3, 2)
	pedreiro.position = Vector2i(3, 3)
	var encounter := load("res://resources/encounters/enc_cobaia_mutante.tres") as EncounterData
	gerencia.campaign.current_map.set_ppp_block(professora.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(professora.position, professora),
		"O Encontro abre a apresentação.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(combat.enemies.size() == 1, "A Cobaia Mutante entra no Combate.")
	var enemy := combat.enemies[0]
	combat.current_actor = professora
	combat._combat_turns_by_id[professora.instance_id] = 1
	var silencio := skill_manager.get_active_grants(professora)[0]
	check(hud._skill_is_available(professora, silencio),
		"Silêncio, Turma! está disponível ao jogável no Combate.")
	var old_attack := enemy.attack
	var silence_result := skill_manager.use_combat_active(professora, silencio,
		gerencia.campaign, combat, enemy)
	check(silence_result.get("success", false) and enemy.attack < old_attack,
		"A Ativa inata reduz o Ataque do alvo.")
	var silence_button_holder := VBoxContainer.new()
	hud._add_skill_button(silence_button_holder, professora, silencio)
	check((silence_button_holder.get_child(0) as Button).get_meta(
		"combat_uses_text", "") == "1 de 3 gastos",
		"O botão de Silêncio mostra o primeiro uso gasto abaixo do nome.")
	silence_button_holder.free()
	check(skill_manager.can_use_combat_active(professora, silencio,
		gerencia.campaign, combat, enemy),
		"Silêncio continua disponível depois do primeiro uso.")
	var silence_second := skill_manager.use_combat_active(professora, silencio,
		gerencia.campaign, combat, enemy)
	var silence_third := skill_manager.use_combat_active(professora, silencio,
		gerencia.campaign, combat, enemy)
	check(silence_second.get("success", false) and silence_third.get("success", false)
		and silencio.uses_in_last_combat == 3 and not skill_manager.can_use_combat_active(
			professora, silencio, gerencia.campaign, combat, enemy),
		"Silêncio aceita três usos por combate e bloqueia o quarto.")
	var silence_exhausted_holder := VBoxContainer.new()
	hud._add_skill_button(silence_exhausted_holder, professora, silencio)
	check((silence_exhausted_holder.get_child(0) as Button).get_meta(
		"combat_uses_text", "") == "3 de 3 gastos",
		"O botão de Silêncio mostra o limite esgotado.")
	silence_exhausted_holder.free()
	combat.current_actor = pedreiro
	combat._combat_turns_by_id[pedreiro.instance_id] = 1
	var muro := skill_manager.get_active_grants(pedreiro)[0]
	hud._on_action_toggle_requested(hud.cards[1])
	hud._on_skill_pressed(pedreiro, muro)
	check(hud.hex_choice.visible and hud.hex_choice_title.text == "ESCOLHA O ALIADO" \
		and hud.hex_choice_buttons.get_child_count() >= 3,
		"Muro de Tijolo abre a caixa expansiva de escolha do aliado.")
	var protect_professora: Button = null
	for candidate in hud.hex_choice_buttons.get_children():
		if (candidate as Button).text == professora.data.display_name.to_upper():
			protect_professora = candidate as Button
	check(protect_professora != null and not protect_professora.disabled,
		"A Professora aparece como alvo disponível na caixa.")
	if protect_professora != null:
		protect_professora.pressed.emit()
	check(combat._damage_guards.get(professora.instance_id) == pedreiro \
		and is_equal_approx(float(combat._guard_reductions.get(pedreiro.instance_id, 1.0)), 0.75),
		"Muro de Tijolo redireciona dano e reduz 25% enquanto protege.")
	var wall_button_holder := VBoxContainer.new()
	hud._add_skill_button(wall_button_holder, pedreiro, muro)
	check((wall_button_holder.get_child(0) as Button).get_meta(
		"combat_uses_text", "") == "1 de 3 gastos",
		"O botão de Muro de Tijolo mostra o primeiro uso gasto.")
	wall_button_holder.free()
	hud._on_map_actor_pressed(0)
	check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() == 1 \
		and not (hud.hex_choice_buttons.get_child(0) as Button).disabled,
		"Clicar na aliada mantém Muro de Tijolo disponível após o primeiro uso.")
	var wall_second := skill_manager.use_combat_active(pedreiro, muro,
		gerencia.campaign, combat, professora)
	var wall_third := skill_manager.use_combat_active(pedreiro, muro,
		gerencia.campaign, combat, professora)
	check(wall_second.get("success", false) and wall_third.get("success", false)
		and muro.uses_in_last_combat == 3 and not skill_manager.can_use_combat_active(
			pedreiro, muro, gerencia.campaign, combat, professora),
		"Muro de Tijolo aceita três usos por combate e bloqueia o quarto.")
	hud._on_map_actor_pressed(0)
	check(hud.hex_choice.visible and (hud.hex_choice_buttons.get_child(0) as Button).disabled,
		"Muro de Tijolo fica cinza quando os três usos terminam.")
	check(combat._can_select_hex(companion.position),
		"O hex ocupado por aliado recrutado pode abrir suas Ativas direcionadas.")
	hud._on_combat_hex_choice(companion.position)
	check(hud.hex_choice.visible and hud.hex_choice_title.text == companion.data.display_name.to_upper() \
		and (hud.hex_choice_buttons.get_child(0) as Button).disabled,
		"Clicar no hex do aliado recrutado exibe a Ativa indisponível sem aplicá-la.")
	hud._update_map_hit_targets()
	var companion_hit := hud._companion_map_hit_buttons.get(companion.instance_id) as Button
	check(companion_hit != null and companion_hit.visible,
		"O corpo do aliado recrutado recebe uma área de clique no mapa.")
	if companion_hit != null:
		companion_hit.pressed.emit()
		check(hud.hex_choice.visible \
			and hud.hex_choice_title.text == companion.data.display_name.to_upper() \
			and (hud.hex_choice_buttons.get_child(0) as Button).disabled,
			"Clicar no corpo do aliado recrutado abre a mesma caixa contextual.")
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(1, 1)
	hud._input(outside_click)
	check(not hud.hex_choice.visible,
		"Clicar fora fecha a escolha de habilidade no aliado.")
	combat._expire_damage_guards_for(pedreiro)
	check(combat._damage_guards.has(professora.instance_id),
		"A proteção não termina durante o turno em que foi ativada.")
	pedreiro.turn_serial += 1
	combat._expire_damage_guards_for(pedreiro)
	check(not combat._damage_guards.has(professora.instance_id) \
		and not combat._guard_reductions.has(pedreiro.instance_id),
		"Ao voltar a vez do Pedreiro, redirecionamento e redução expiram juntos.")
	var acquired := load("res://resources/skills/actives/permanent_effects/declarar_arqui_inimigo.tres") as ActiveSkillData
	var acquired_grant := skill_manager.grant_skill(pedreiro, acquired, &"event", &"event_test",
		gerencia.campaign)
	check(acquired_grant != null and hud._skill_is_available(pedreiro, acquired_grant),
		"Ativa recebida de Evento entra na consulta universal e no botão do HUD.")
	var acquired_result := skill_manager.use_combat_active(pedreiro, acquired_grant,
		gerencia.campaign, combat, enemy)
	check(acquired_result.get("success", false) and
		acquired_grant not in skill_manager.get_active_grants(pedreiro),
		"Declarar Arqui-Inimigo concede as Passivas e consome a Ativa adquirida.")
	var rivalry_context := {"mode": HexGrid.PPPMapMode.COMBAT,
		"combat": combat, "combat_id": combat._combat_id,
		"combat_turn_number": 1, "attack_target": enemy}
	var rivalry_attack := skill_manager.dispatch_passive_trigger(pedreiro,
		PassiveSkillData.Trigger.ON_BEFORE_ATTACK, gerencia.campaign, rivalry_context)
	check(rivalry_attack.size() == 1 and is_equal_approx(float(
		rivalry_attack[0]["effects"][0].get("damage_multiplier", 1.0)), 2.0),
		"Arqui-Inimigo dobra dano causado ao EntityData declarado.")
	var rival_damage := skill_manager.apply_incoming_damage(pedreiro, 3,
		gerencia.campaign, {"mode": HexGrid.PPPMapMode.COMBAT,
			"combat_id": combat._combat_id, "combat_turn_number": 1,
			"damage_source": enemy})
	check(int(rival_damage.get("calculated_damage", 0)) == 6,
		"Arqui-Inimigo dobra dano recebido do EntityData declarado.")
	var other_type := load(
		"res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var other_source := EntityState.from_encounter_member(other_type,
		&"other_type", 0, Vector2i(0, 0))
	var other_damage := skill_manager.apply_incoming_damage(pedreiro, 3,
		gerencia.campaign, {"mode": HexGrid.PPPMapMode.COMBAT,
			"combat_id": combat._combat_id, "combat_turn_number": 1,
			"damage_source": other_source})
	check(int(other_damage.get("calculated_damage", 0)) == 3,
		"Outro EntityData não recebe o multiplicador do Arqui-Inimigo.")
	combat.current_actor = enemy
	combat._combat_turns_by_id[enemy.instance_id] = 1
	combat._turn_die = 4
	combat._steps_moved = 0
	combat._attacks_used = 0
	combat._run_automatic_actives(enemy, ActiveSkillData.AutomaticTrigger.ON_TURN_START)
	check(combat._attacks_used > 0,
		"A Ativa programada da Cobaia executa o ataque do seu primeiro turno.")
	var dama_data := load("res://resources/entities/entities_general/dama_elemental.tres") as EntityData
	var dama := EntityState.from_encounter_member(dama_data, encounter.id, 2,
		Vector2i(7, 3))
	combat.enemies.append(dama)
	var before_summon := combat.enemies.size()
	combat._run_automatic_actives(dama, ActiveSkillData.AutomaticTrigger.ON_COMBAT_START)
	check(combat.enemies.size() in [before_summon, before_summon + 1],
		"Dama Elemental tem 50% de chance de gerar no máximo uma entidade.")
	var aranha_data := load("res://resources/entities/entities_general/aranha_interdimensional.tres") as EntityData
	var aranha := EntityState.from_encounter_member(aranha_data, encounter.id, 3,
		Vector2i(4, 2))
	combat.enemies.append(aranha)
	combat.current_actor = aranha
	combat._turn_die = 4
	combat._attacks_used = 0
	var web_or_attack := combat._run_automatic_actives(aranha,
		ActiveSkillData.AutomaticTrigger.ON_ATTACK_SELECTION, professora)
	check(web_or_attack,
		"A Aranha seleciona uma de suas duas Ativas automáticas de ataque.")
	var amulet := load("res://resources/itens/equipments/acessorios/acessorio_epico_amuleto_divino.tres") as ItemData
	check(skill_manager.inventory_manager.add_item(pedreiro, amulet),
		"O Amuleto Divino pode entrar no inventário do portador.")
	var amulet_entry := pedreiro.inventory_items[-1]
	check(EquipmentManager.new().equip(pedreiro, amulet_entry,
		skill_manager, gerencia.campaign),
		"Equipar o Amuleto concede a Ativa reativa pela origem do item.")
	check(skill_manager.debuff_manager.apply_by_id(professora, &"db_00010")
		.get("success", false), "Tristeza antecede o Sacrifício Divino.")
	professora.current_health = 0
	check((amulet.granted_active_skills[0] as ActiveSkillData).automatic_triggers.is_empty(),
		"A morte não abre escolha automática: Sacrifício Divino é manual.")
	var amulet_grant: SkillGrantState = null
	for candidate in skill_manager.get_active_grants(pedreiro):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			amulet_grant = candidate
	combat.current_actor = pedreiro
	check(amulet_grant != null and skill_manager.can_use_combat_active(pedreiro,
		amulet_grant, gerencia.campaign, combat, professora),
		"A Ativa manual aceita jogável morto como alvo.")
	hud._on_skill_pressed(pedreiro, amulet_grant)
	check(hud.hex_choice.visible and hud.hex_choice_title.text ==
		"ESCOLHA QUEM RESSUSCITAR" and
		hud.hex_choice_buttons.get_child_count() > 0,
		"Clicar na Ativa abre a seleção de mortos, sem consumir o item.")
	(hud.hex_choice_buttons.get_child(0) as Button).pressed.emit()
	check(hud._revive_dialog.visible and professora.current_health == 0
		and not pedreiro.equipped_accessories.is_empty()
		and "será consumido" in hud._revive_dialog.dialog_text,
		"Selecionar abre confirmação com aviso explícito de destruição.")
	hud._revive_dialog.hide()
	hud._cancel_amulet_revive()
	check(professora.current_health == 0 and not pedreiro.equipped_accessories.is_empty(),
		"Cancelar a confirmação não consome o Amuleto nem ressuscita.")
	(hud.hex_choice_buttons.get_child(0) as Button).pressed.emit()
	hud._revive_dialog.hide()
	hud._confirm_amulet_revive()
	check(professora.current_health == professora.max_health,
		"Confirmar ressuscita o aliado com Vida máxima.")
	for id in [&"db_00003", &"db_00004", &"db_00005", &"db_00009", &"db_00010"]:
		check(id in professora.permanent_status_immunities \
			and skill_manager.debuff_manager.get_debuff(professora, id) == null,
			"Sacrifício Divino remove e imuniza contra %s." % id)
	check(pedreiro.equipped_accessories.is_empty() and
		gerencia.campaign.consumed_uncraftable_item_ids.has(amulet.id),
		"O Amuleto é destruído e não pode ser fabricado novamente na campanha.")
	var recruited_enemy := EntityState.from_encounter_member(other_type,
		&"recruited_amulet_target", 1, Vector2i(5, 3))
	check(gerencia.campaign.register_companion(pedreiro, recruited_enemy),
		"Uma entidade de origem hostil pode integrar o lado aliado.")
	check(skill_manager.inventory_manager.add_item(pedreiro, amulet),
		"Uma segunda cópia existente do Amuleto pode ser usada por outro aliado.")
	var second_amulet := pedreiro.inventory_items[-1]
	check(EquipmentManager.new().equip(pedreiro, second_amulet,
		skill_manager, gerencia.campaign),
		"O portador equipa a segunda cópia do Amuleto.")
	recruited_enemy.current_health = 0
	var second_grant: SkillGrantState = null
	for candidate in skill_manager.get_active_grants(pedreiro):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			second_grant = candidate
	var companion_revive := skill_manager.use_combat_active(pedreiro, second_grant,
		gerencia.campaign, combat, recruited_enemy)
	check(companion_revive.get("success", false)
		and recruited_enemy.current_health == recruited_enemy.max_health
		and pedreiro.equipped_accessories.is_empty(),
		"A entidade recrutada revive e a segunda cópia é consumida.")
	var historical_data := load(
		"res://resources/entities/entities_playable/jornalista.tres") as EntityData
	var historical_dead := EntityState.from_playable_selection(historical_data,
		&"former_playable_amulet_test", Vector2i(3, 3))
	historical_dead.current_health = 0
	gerencia.campaign.dead_playable_states.append(historical_dead)
	check(skill_manager.inventory_manager.add_item(pedreiro, amulet),
		"Terceira cópia preexistente do Amuleto entra no inventário.")
	var third_amulet := pedreiro.inventory_items[-1]
	check(EquipmentManager.new().equip(pedreiro, third_amulet,
		skill_manager, gerencia.campaign),
		"O portador equipa a terceira cópia.")
	var third_grant: SkillGrantState = null
	for candidate in skill_manager.get_active_grants(pedreiro):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			third_grant = candidate
	var historical_result := skill_manager.use_combat_active(pedreiro,
		third_grant, gerencia.campaign, combat, historical_dead)
	check(historical_result.get("success", false)
		and historical_dead in gerencia.campaign.companion_states
		and historical_dead.current_health == historical_dead.max_health
		and combat.initiative_order.any(func(initiative: Dictionary) -> bool:
			return initiative.get("entity") == historical_dead)
		and pedreiro.equipped_accessories.is_empty(),
		"Morto de encontro anterior ressuscita durante Combate e entra na iniciativa.")
	print("PPP combat actives: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
