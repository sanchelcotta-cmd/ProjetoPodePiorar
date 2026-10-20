extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "A campanha começa com três jogáveis.")
	var dead := campaign.active_entity_states[0]
	var survivor := campaign.active_entity_states[1]
	var other := campaign.active_entity_states[2]
	var skills := SkillManager.new()
	var inventory := InventoryManager.new()
	var item := load("res://resources/itens/equipments/armas/martelo.tres") as ItemData
	check(inventory.add_item(dead, item), "O futuro morto recebe uma cópia extra.")
	survivor.inventory_items.clear()
	other.inventory_items.clear()
	survivor.base_inventory_capacity = 0
	other.base_inventory_capacity = 0
	# O item inicial pode ser mochila e aumentar a capacidade por bônus.
	survivor.inventory_capacity_bonus = -100
	other.inventory_capacity_bonus = -100
	for status_id in [&"db_00003", &"db_00009", &"db_00010"]:
		check(skills.debuff_manager.apply_by_id(dead, status_id).get("success", false),
			"Debuff anterior à morte pode ser aplicado: %s." % status_id)
	dead.current_health = 0
	var finalized := campaign.finalize_dead_playables(skills)
	check(finalized.size() == 1 and finalized[0] == dead \
		and dead in campaign.dead_playable_states,
		"Morte definitiva registra a instância sem apagar sua identidade.")
	check(campaign.has_dead_playable_slot() and campaign.needs_replacement_ally(),
		"Vaga morta força reposição enquanto existe jogável não usado.")
	check(not dead.inventory_items.is_empty(),
		"Sem espaço nos sobreviventes, o espólio aguarda remanejamento.")
	var recovered_weapon: InventoryItemState
	for entry in dead.inventory_items:
		if entry != null and entry.data == item:
			recovered_weapon = entry
			break
	check(recovered_weapon != null and EquipmentManager.new()
		.equip_playable_from_playable(dead, survivor, recovered_weapon, skills, campaign),
		"Espólio pode ser equipado diretamente em um sobrevivente durante o remanejamento.")
	check(skills.debuff_manager.get_debuff(survivor, &"db_00010") != null \
		and skills.debuff_manager.get_debuff(other, &"db_00010") != null,
		"Sobreviventes recebem Tristeza.")
	check(dead.data not in campaign.get_unselected_playable_allies(),
		"Morto nunca é candidato ao Evento Aliado.")
	var info: Array[Resource] = [
		load("res://resources/informacoes/orchestra/orchestra_1.tres") as Resource,
	]
	var ally_event := load("res://resources/events/permanent_effects/65-um_aliado.tres") as EventData
	var rng := RandomNumberGenerator.new()
	rng.seed = 8492
	var generated := PPPMapGenerator.new().generate_new_map(info, &"suburbio",
		PPPMapGenerator.RoundPeriod.MORNING,
		{ally_event.resource_path: 10}, [], rng, [ally_event.resource_path],
		2, false, 1, true, campaign.needs_replacement_ally())
	check(generated != null, "Mapa com reposição obrigatória é gerado.")
	if generated != null:
		var ally_count := 0
		for coord in generated.cells:
			var event := generated.get_ppp_block_resource(coord) as EventData
			if event != null and event.id == &"ev_00065":
				ally_count += 1
		check(ally_count == 1,
			"Mesmo em standby/único, próximo mapa inclui exatamente um Aliado.")
	var candidate := campaign.get_unselected_playable_allies()[0]
	var replacement := campaign.replace_dead_playable(candidate, survivor, skills)
	check(replacement != null and campaign.active_entity_states[0] == replacement \
		and replacement.playable_slot_id == &"Playable_1",
		"Aliado descoberto ocupa a vaga do morto como jogável.")
	check(replacement != null and not replacement.equipped_weapons.is_empty() \
		and not replacement.equipped_armors.is_empty() \
		and not replacement.equipped_accessories.is_empty(),
		"Recrutado mantém seus três itens comuns iniciais, ao contrário do ressuscitado.")
	check(not campaign.needs_replacement_ally(),
		"Após preencher a vaga, o evento deixa de ser forçado.")
	var genie := load("res://resources/events/random_events/49-genio_da_lampada.tres") as EventData
	var genie_outcome: EventOutcomeData
	for candidate_outcome in genie.outcomes:
		if candidate_outcome != null and candidate_outcome.id == &"revive_dead_playable":
			genie_outcome = candidate_outcome
			break
	check(genie_outcome != null, "Gênio oferece desejo de ressuscitar morto.")
	var gerencia := GerenciaJogo.new()
	gerencia.campaign = campaign
	var executor := EventExecutor.new()
	executor.gerencia = gerencia
	executor.skill_manager = skills
	var revived := executor._apply_effect(genie_outcome.effects[0], survivor, genie,
		{"actor": survivor, "decision": {"selected_dead_actor": dead}}, false)
	check(revived.get("success", false) and revived.get("as_companion", false) \
		and dead in campaign.companion_states \
		and dead.owner_instance_id == survivor.instance_id,
		"Gênio ressuscita como aliado do desejante após ocupação da vaga.")
	check(dead.inventory_items.is_empty() and dead.equipped_weapons.is_empty() \
		and dead.equipped_armors.is_empty() and dead.equipped_accessories.is_empty() \
		and dead.current_health == dead.max_health,
		"Ressuscitado não recupera espólio, Maldições nem equipamento novo.")
	for id in [&"db_00003", &"db_00004", &"db_00005", &"db_00009", &"db_00010"]:
		check(id in dead.permanent_status_immunities,
			"Ressuscitado recebe imunidade permanente a %s." % id)
		check(skills.debuff_manager.get_debuff(dead, id) == null,
			"Ressurreição remove o debuff anterior %s." % id)
		check(not skills.debuff_manager.apply_by_id(dead, id).get("success", false),
			"Imunidade impede reaplicar %s depois da ressurreição." % id)
	var vacant_campaign := CampaignState.new()
	check(vacant_campaign.start_new_game(selected),
		"Outra campanha permite testar ressurreição antes da reposição.")
	var vacant_dead := vacant_campaign.active_entity_states[0]
	var vacant_wisher := vacant_campaign.active_entity_states[1]
	vacant_dead.current_health = 0
	vacant_campaign.finalize_dead_playables(skills)
	var restored := vacant_campaign.revive_dead_playable(vacant_dead, vacant_wisher,
		skills)
	check(restored.get("success", false) and not restored.get("as_companion", true) \
		and vacant_campaign.active_entity_states[0] == vacant_dead \
		and vacant_dead.inventory_items.is_empty() \
		and vacant_dead.equipped_weapons.is_empty() \
		and vacant_dead.equipped_armors.is_empty() \
		and vacant_dead.equipped_accessories.is_empty(),
		"Sem substituto, ressuscitado recupera a vaga, mas nenhum item.")
	print("DEATH_REPLACEMENT_TEST_OK" if failures == 0 else \
		"DEATH_REPLACEMENT_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
