extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var combat := scene.get_node("CombatManager") as CombatManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/universitario.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres")]
	_check(gerencia.start_new_game(selected), "Campanha com as três passivas de regressão.")
	var campaign := gerencia.campaign
	campaign.current_map = HexGrid.new()
	campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	var student := campaign.active_entity_states[0]
	var chef := campaign.active_entity_states[1]
	var builder := campaign.active_entity_states[2]
	for actor in campaign.active_entity_states:
		actor.inventory_items.clear()
	combat._combat_id = &"native_passives"
	combat.current_actor = student
	combat._combat_turns_by_id[student.instance_id] = 1
	student.position = Vector2i(0, 0)
	var target_data := load("res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var attack_target := EntityState.from_encounter_member(target_data, &"native", 9, Vector2i(1, 0))
	# O alvo precisa sobreviver às duas investidas para testar o segundo ciclo,
	# não encerrar o combate após o primeiro golpe.
	attack_target.max_health = 1000
	attack_target.current_health = 1000
	combat.enemies.append(attack_target)
	combat._turn_die = 3
	_check(combat._resolve_attack(student, attack_target).get("success", false) \
		and combat._attacks_used == 1 and combat._turn_die == 0 \
		and not combat.can_roll_player_turn_die(),
		"O primeiro ataque consome o dado, sem permitir nova rolagem gratuita.")
	hud._sync_slots()
	hud._open_card = hud.cards[0]
	hud._rebuild_action_buttons()
	_check(hud.walk_button.disabled,
		"Antes do consumo, o botão de jogar dado permanece indisponível.")
	var food := load("res://resources/itens/consumables/bolinho_de_chuva.tres") as ItemData
	var inventory := InventoryManager.new()
	_check(inventory.add_item(student, food), "Universitário recebe consumível.")
	var first := student.inventory_items[0]
	_check(not inventory.use_consumable(student, first, skills, campaign).get(
		"success", false) and first in student.inventory_items,
		"Sem contexto de combate, o item não é gasto nem a passiva perdida.")
	var group_menu := top_bar.group_inventory.item_menu
	_check(top_bar.group_inventory.combat_manager == combat \
		and group_menu.combat_manager == combat,
		"Inventário do grupo entrega o combate ao menu de itens antes da abertura.")
	group_menu.open_for(student, first, false, Rect2(100, 100, 1, 1), campaign, skills)
	group_menu._consume()
	_check(first not in student.inventory_items,
		"Consumo pelo menu real do inventário do grupo é executado.")
	_check(student.extra_attacks_this_turn == 1 \
		and combat.can_roll_player_turn_die(),
		"Após o primeiro ataque e o consumo, surge uma nova rolagem.")
	_check(not hud.walk_button.disabled and hud.skill_buttons.get_child_count() >= 2 \
		and (hud.skill_buttons.get_child(1) as Button).disabled,
		"A interface oferece Jogar Dado e segura Atacar até a nova rolagem.")
	student.stamina_remaining = 0
	combat._steps_moved = 2
	combat._turn_moved = true
	_check(combat.roll_player_turn_die() in range(1, 7) \
		and student.stamina_remaining == student.max_stamina \
		and combat._steps_moved == 0 and not combat._turn_moved,
		"Nova rolagem restaura Estamina e inicia outro ciclo de movimento.")
	hud._rebuild_action_buttons()
	_check(not (hud.skill_buttons.get_child(1) as Button).disabled,
		"Atacar torna-se clicável depois do segundo dado.")
	combat._resolve_attack(student, attack_target)
	_check(combat._attacks_used == 2 and combat._turn_die == 0 \
		and not combat.can_roll_player_turn_die(),
		"O segundo ataque também consome o dado.")
	_check(inventory.add_item(student, food), "Segundo consumível disponível.")
	inventory.use_consumable(student, student.inventory_items[0], skills, campaign,
		null, null, combat)
	_check(student.extra_attacks_this_turn == 1,
		"Múltiplos consumos não criam terceiro ataque no mesmo turno.")
	var extra_effect := SkillEffectData.new()
	extra_effect.effect_type = SkillEffectData.EffectType.ADD_EXTRA_ATTACK
	extra_effect.amount = 2
	_check(skills.effect_executor.execute_passive(extra_effect,
		{"actor": student, "mode": HexGrid.PPPMapMode.COMBAT}).get("success", false) \
		and student.extra_attacks_this_turn == 3 and combat.can_roll_player_turn_die(),
		"Outra fonte de ataques extras acumula duas rolagens adicionais.")
	_check(combat.roll_player_turn_die() in range(1, 7), "Terceiro dado pode ser lançado.")
	combat._attacks_used = 3
	combat._turn_die = 0
	_check(combat.roll_player_turn_die() in range(1, 7), "Quarto dado pode ser lançado.")
	combat.current_actor = chef
	combat._combat_turns_by_id[chef.instance_id] = 1
	chef.current_health -= 10
	var before := chef.current_health
	var triggered := skills.dispatch_passive_trigger(chef,
		PassiveSkillData.Trigger.ON_AFTER_DAMAGE_DEALT, campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat_id": combat._combat_id,
		"combat_turn_number": 1, "damage_dealt": 10, "is_melee_attack": true})
	_check(triggered.size() == 1 and chef.current_health == before + 3,
		"Tempero do Chef recupera 30% do dano corpo a corpo causado.")
	before = chef.current_health
	skills.dispatch_passive_trigger(chef, PassiveSkillData.Trigger.ON_AFTER_DAMAGE_DEALT,
		campaign, {"mode": HexGrid.PPPMapMode.COMBAT,
		"combat_id": combat._combat_id, "combat_turn_number": 1,
		"damage_dealt": 10, "is_melee_attack": false})
	_check(chef.current_health == before, "Ataque à distância não ativa o vampirismo.")
	var blade_target := EntityState.from_encounter_member(target_data, &"native", 1, Vector2i(1, 1))
	var impact_target := EntityState.from_encounter_member(target_data, &"native", 2, Vector2i(2, 1))
	var equipment := EquipmentManager.new()
	var blade := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	var impact := load("res://resources/itens/equipments/armas/cabo_de_vassoura.tres") as ItemData
	inventory.add_item(chef, blade)
	inventory.add_item(builder, impact)
	_check(equipment.equip(chef, chef.inventory_items[-1], skills, campaign)
		and equipment.equip(builder, builder.inventory_items[-1], skills, campaign),
		"Armas correspondentes às Maestrias são equipadas.")
	combat._turn_die = 6
	combat._apply_mastery_critical(chef, blade_target, combat._attack_mastery(chef))
	combat._apply_mastery_critical(builder, impact_target, combat._attack_mastery(builder))
	_check(&"db_00008" in skills.debuff_manager.get_debuff_ids(blade_target),
		"Crítico de Lâmina causa Sangramento.")
	_check(&"db_00002" in skills.debuff_manager.get_debuff_ids(impact_target),
		"Crítico de Impacto causa Atordoamento.")
	var builder_attack := builder.attack
	var wall_results := skills.dispatch_passive_trigger(builder,
		PassiveSkillData.Trigger.ON_AFTER_DAMAGE_RECEIVED, campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat": combat,
		"combat_id": combat._combat_id, "combat_turn_number": 1,
		"damage_dealt": 3})
	_check(wall_results.size() == 1 and builder.attack == builder_attack + 2,
		"Paredão Vivo soma +2 de Ataque após sofrer dano.")
	combat._consume_next_attack_bonus(builder)
	_check(builder.attack == builder_attack,
		"Paredão Vivo termina após o próximo ataque.")
	var mother_data := load("res://resources/entities/entities_playable/mae.tres") as EntityData
	var mother := EntityState.from_playable_selection(mother_data, &"MotherTest", Vector2i(0, 0))
	chef.position = Vector2i(1, 0)
	campaign.active_entity_states.append(mother)
	var mother_attack := mother.attack
	var mother_results := skills.dispatch_passive_trigger(mother,
		PassiveSkillData.Trigger.ON_AFTER_ALLY_DAMAGE_RECEIVED, campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat": combat,
		"combat_id": combat._combat_id, "combat_turn_number": 1,
		"damage_dealt": 3, "damaged_ally": chef, "damage_source": impact_target})
	_check(mother_results.size() == 1 and mother.attack == mother_attack + 4,
		"Mãe recebe +4 ao ver aliado próximo sofrer dano.")
	mother.turn_serial += 1
	combat._expire_mother_bonus(mother)
	_check(mother.attack == mother_attack,
		"Bônus da Mãe expira ao fim do próximo turno dela.")
	var old_lady_data := load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData
	var old_lady := EntityState.from_playable_selection(old_lady_data, &"OldLadyTest", Vector2i(0, 1))
	var old_attack := old_lady.attack
	var familiarity := skills.dispatch_passive_trigger(old_lady,
		PassiveSkillData.Trigger.ON_BEFORE_ATTACK, campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat": combat,
		"combat_id": combat._combat_id, "combat_turn_number": 1,
		"previous_encounters_same_entity_data": 1, "attack_target": impact_target})
	_check(familiarity.size() == 1 and old_lady.attack == old_attack \
		and int(familiarity[0]["effects"][0].get("current_attack_bonus", 0)) == 3,
		"Velha recebe +3 somente no ataque ao tipo de inimigo já enfrentado.")
	root.remove_child(scene)
	scene.free()
	print("NATIVE_PASSIVE_COMBAT_TEST_OK" if failures == 0 else \
		"NATIVE_PASSIVE_COMBAT_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
