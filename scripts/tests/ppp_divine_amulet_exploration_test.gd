extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	_check(campaign.start_new_game(selected), "Campanha de teste iniciada.")
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	campaign.current_map = grid
	var owner := campaign.active_entity_states[0]
	var dead := campaign.active_entity_states[1]
	owner.turn_state = EntityState.TurnState.TURNING
	owner.position = Vector2i(3, 2)
	dead.position = Vector2i(3, 3)
	var skills := SkillManager.new()
	root.add_child(skills)
	var amulet := load(
		"res://resources/itens/equipments/acessorios/acessorio_epico_amuleto_divino.tres") as ItemData
	var inventory := InventoryManager.new()
	_check(inventory.add_item(owner, amulet), "Amuleto no inventário do portador.")
	var entry := owner.inventory_items[-1]
	_check(EquipmentManager.new().equip(owner, entry, skills, campaign),
		"Amuleto equipado concede Sacrifício Divino.")
	var grant: SkillGrantState = null
	for candidate in skills.get_active_grants(owner):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			grant = candidate
	dead.current_health = 0
	campaign.finalize_dead_playables(skills)
	var replacement := campaign.replace_dead_playable(
		campaign.get_unselected_playable_allies()[0], owner, skills)
	_check(replacement != null and dead in campaign.dead_playable_states
		and dead not in campaign.active_entity_states,
		"Jogável morto de combate anterior está fora da equipe ativa.")
	_check(grant != null and skills.can_use_exploration_divine_amulet(
		owner, grant, campaign, dead),
		"Sacrifício Divino aceita o morto histórico na exploração.")
	_check(owner.equipped_accessories.has(entry) and dead.current_health == 0,
		"Abrir a seleção e escolher alvo ainda não altera item nem morto.")
	var revived := skills.use_exploration_divine_amulet(owner, grant, campaign, dead)
	_check(revived.get("success", false) and dead.current_health == dead.max_health
		and dead in campaign.companion_states and dead.owner_instance_id == owner.instance_id,
		"Confirmar ressuscita o antigo jogável como aliado do portador.")
	_check(entry not in owner.equipped_accessories and
		campaign.consumed_uncraftable_item_ids.has(amulet.id),
		"Confirmação destrói a cópia equipada e bloqueia a fabricação posterior.")
	for id in [&"db_00003", &"db_00004", &"db_00005", &"db_00009", &"db_00010"]:
		_check(id in dead.permanent_status_immunities,
			"Ressuscitado histórico recebe imunidade permanente a %s." % id)
	var enemy_data := load(
		"res://resources/entities/entities_general/cultista_encapuzado.tres") as EntityData
	var companion := EntityState.from_encounter_member(enemy_data,
		&"amulet_companion", 1, Vector2i(4, 2))
	_check(campaign.register_companion(owner, companion, null, skills),
		"Entidade recrutada integra o grupo.")
	companion.current_health = 0
	_check(inventory.add_item(owner, amulet), "Segunda cópia existente recebida.")
	var second_entry := owner.inventory_items[-1]
	_check(EquipmentManager.new().equip(owner, second_entry, skills, campaign),
		"Segunda cópia equipada.")
	var second_grant: SkillGrantState = null
	for candidate in skills.get_active_grants(owner):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			second_grant = candidate
	_check(second_grant != null and skills.can_use_exploration_divine_amulet(
		owner, second_grant, campaign, companion),
		"Entidade recrutada morta também é alvo na exploração.")
	var companion_result := skills.use_exploration_divine_amulet(owner,
		second_grant, campaign, companion)
	_check(companion_result.get("success", false)
		and companion.current_health == companion.max_health
		and second_entry not in owner.equipped_accessories,
		"Aliado não jogável revive e a segunda cópia é destruída.")
	var ally_amulet := InventoryItemState.new(amulet)
	dead.inventory_items.append(ally_amulet)
	_check(EquipmentManager.new().equip(dead, ally_amulet, skills, campaign),
		"Aliado humano também pode portar o Amuleto.")
	var ally_grant: SkillGrantState = null
	for candidate in skills.get_active_grants(dead):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			ally_grant = candidate
	companion.current_health = 0
	_check(ally_grant != null and skills.can_use_exploration_divine_amulet(
		dead, ally_grant, campaign, companion),
		"Amuleto equipado em aliado humano aceita um morto do grupo.")
	var ally_revive := skills.use_exploration_divine_amulet(dead,
		ally_grant, campaign, companion)
	_check(ally_revive.get("success", false)
		and companion.current_health == companion.max_health
		and ally_amulet not in dead.equipped_accessories,
		"Amuleto do aliado é destruído ao ressuscitar outro companheiro.")
	await _test_exploration_ui(selected, amulet)
	print("DIVINE_AMULET_EXPLORATION_TEST: %s" % (
		"PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _test_exploration_ui(selected: Array[EntityData], amulet: ItemData) -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Cena real de exploração inicia para testar a seleção do Amuleto.")
	var owner := gerencia.campaign.active_entity_states[0]
	var target := gerencia.campaign.active_entity_states[1]
	exploration.current_actor = owner
	owner.turn_state = EntityState.TurnState.TURNING
	_check(skill_manager.inventory_manager.add_item(owner, amulet),
		"Portador da cena recebe Amuleto.")
	var entry := owner.inventory_items[-1]
	_check(EquipmentManager.new().equip(owner, entry, skill_manager,
		gerencia.campaign), "Portador da cena equipa Amuleto.")
	var attune_grant: SkillGrantState = null
	for candidate in skill_manager.get_active_grants(owner):
		if candidate.skill != null and candidate.skill.id == &"item_active_003":
			attune_grant = candidate
	_check(attune_grant != null and hud._skill_is_available(owner, attune_grant),
		"A sintonização aparece disponível no HUD antes do vínculo.")
	hud._on_skill_pressed(owner, attune_grant)
	_check(hud._attune_dialog.visible
		and "IRREVERSÍVEL" in hud._attune_dialog.dialog_text
		and "uma única vez" in hud._attune_dialog.dialog_text
		and "não destrói" in hud._attune_dialog.dialog_text,
		"O aviso esclarece vínculo único e irreversível sem destruir o item.")
	hud._attune_dialog.hide()
	hud._cancel_amulet_attunement()
	_check(entry.attuned_owner_instance_id == &"" and not owner.is_curse_immune(),
		"Cancelar não sintoniza nem concede imunidade.")
	hud._on_skill_pressed(owner, attune_grant)
	hud._attune_dialog.hide()
	hud._confirm_amulet_attunement()
	_check(entry in owner.equipped_accessories
		and entry.attuned_owner_instance_id == owner.instance_id
		and owner.is_curse_immune()
		and not hud._skill_is_available(owner, attune_grant),
		"Confirmar vincula sem consumir e desativa novo uso da Ativa.")
	var grant: SkillGrantState = null
	for candidate in skill_manager.get_active_grants(owner):
		if candidate.skill != null and candidate.skill.id == &"item_active_002":
			grant = candidate
	target.current_health = 0
	_check(grant != null and hud._skill_is_available(owner, grant),
		"A ativa aparece disponível no HUD de Exploração com um morto.")
	hud._on_skill_pressed(owner, grant)
	_check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() > 0,
		"A ativa abre lista de personagens mortos na Exploração.")
	(hud.hex_choice_buttons.get_child(0) as Button).pressed.emit()
	_check(hud._revive_dialog.visible and owner.equipped_accessories.has(entry)
		and target.current_health == 0,
		"A confirmação ainda não consumiu o item na Exploração.")
	hud._revive_dialog.hide()
	hud._confirm_amulet_revive()
	_check(target.current_health == target.max_health
		and entry not in owner.equipped_accessories,
		"Confirmar no HUD da Exploração ressuscita e destrói o Amuleto.")
	scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
