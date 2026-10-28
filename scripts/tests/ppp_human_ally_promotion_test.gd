extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	var student := load("res://resources/entities/entities_playable/universitario.tres") as EntityData
	var teacher := load("res://resources/entities/entities_playable/professora.tres") as EntityData
	var pet_data := load(
		"res://resources/entities/entities_general/companions/gatinho_vira_lata.tres") as EntityData
	var enemy_data := load(
		"res://resources/entities/entities_general/barata_voadora.tres") as EntityData
	var item := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	var campaign := CampaignState.new()
	_check(campaign.start_new_game(selected), "Campanha de promoção inicia.")
	var dead := campaign.active_entity_states[0]
	var oldest := EntityState.from_playable_selection(student, &"Companion_1", dead.position)
	oldest.current_health = 7
	_check(campaign.register_companion(dead, oldest, null, null, false),
		"Universitário entra como aliado humano sem novo equipamento automático.")
	var newer := EntityState.from_playable_selection(teacher, &"Companion_2", dead.position)
	_check(campaign.register_companion(dead, newer, null, null, false),
		"Professora entra depois do Universitário.")
	var pet := EntityState.from_encounter_member(pet_data, &"test_pet", 1, dead.position)
	_check(campaign.register_companion(dead, pet, null, null, false),
		"Pet entra no grupo, mas não concorre à vaga.")
	var loot := InventoryItemState.new(item)
	dead.inventory_items.append(loot)
	dead.current_health = 0
	campaign.finalize_dead_playables(null)
	_check(campaign.active_entity_states[0] == oldest
		and oldest.current_health == 7 and oldest.playable_slot_id == &"Playable_1"
		and oldest.instance_id == &"Playable_1" and oldest.owner_instance_id == &"",
		"Aliado humano mais antigo ocupa a vaga sem recriar sua instância ou Vida.")
	_check(oldest in campaign.active_entity_states and oldest not in campaign.companion_states
		and newer in campaign.companion_states and pet in campaign.companion_states,
		"Apenas um humano jogável é promovido; os demais continuam aliados.")
	_check(loot in oldest.inventory_items and loot not in dead.inventory_items,
		"Espólio transferível prioriza o jogável recém-promovido.")
	_check(campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE
		and dead in campaign.dead_playable_states,
		"Morte com promoção não encerra a campanha nem ressuscita o morto.")

	var no_human := CampaignState.new()
	_check(no_human.start_new_game(selected), "Campanha sem aliado humano inicia.")
	var owner := no_human.active_entity_states[0]
	var animal := EntityState.from_encounter_member(pet_data, &"test_pet_2", 1, owner.position)
	var recruited_enemy := EntityState.from_encounter_member(enemy_data,
		&"test_enemy_ally", 1, owner.position)
	_check(no_human.register_companion(owner, animal, null, null, false)
		and no_human.register_companion(owner, recruited_enemy, null, null, false),
		"Pet e inimigo recrutado estão vivos no grupo.")
	for actor in no_human.active_entity_states:
		actor.current_health = 0
	no_human.finalize_dead_playables(null)
	_check(no_human.campaign_status == CampaignState.CampaignStatus.DEFEAT
		and no_human.active_entity_states.all(func(actor: EntityState) -> bool:
			return actor.current_health <= 0),
		"Três jogáveis mortos causam Game Over apesar de pet/inimigo aliado vivos.")
	var last_human := CampaignState.new()
	_check(last_human.start_new_game(selected), "Campanha do último aliado humano inicia.")
	var human_owner := last_human.active_entity_states[0]
	var sole_human := EntityState.from_playable_selection(student,
		&"Companion_last_human", human_owner.position)
	_check(last_human.register_companion(human_owner, sole_human, null, null, false),
		"Único aliado humano jogável permanece vivo.")
	for actor in last_human.active_entity_states:
		actor.current_health = 0
	last_human.finalize_dead_playables(null)
	_check(last_human.campaign_status == CampaignState.CampaignStatus.ACTIVE
		and last_human.active_entity_states[0] == sole_human
		and last_human.dead_playable_states.size() == 3,
		"Três originais mortos não causam Game Over enquanto um aliado humano assume.")

	await _test_combat_pause_and_inventory(selected, student, item)
	print("HUMAN_ALLY_PROMOTION_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _test_combat_pause_and_inventory(selected: Array[EntityData],
		student: EntityData, item: ItemData) -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var combat := scene.get_node("CombatManager") as CombatManager
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	_check(gerencia.start_new_game(selected), "Cena de promoção inicia campanha real.")
	var dead := gerencia.campaign.active_entity_states[0]
	var companion := EntityState.from_playable_selection(student,
		&"Companion_promotion_test", dead.position)
	_check(gerencia.campaign.register_companion(dead, companion, null, null, false),
		"Aliado humano é registrado na cena real.")
	var loot := InventoryItemState.new(item)
	dead.inventory_items.append(loot)
	# Forçar uma sobra transferível para verificar a quarta coluna e o arrasto.
	for actor in gerencia.campaign.active_entity_states:
		if actor == dead:
			continue
		while actor.inventory_used_space() < actor.inventory_capacity():
			actor.inventory_items.append(InventoryItemState.new(item))
	while companion.inventory_used_space() < 12:
		companion.inventory_items.append(InventoryItemState.new(item))
	combat.current_encounter = EncounterData.new()
	combat.current_encounter.id = &"test_encounter_promotion"
	var enemy_data := load(
		"res://resources/entities/entities_general/barata_voadora.tres") as EntityData
	combat.enemies.append(EntityState.from_encounter_member(enemy_data,
		&"test_encounter_promotion", 1, dead.position))
	var former_companion_id := companion.instance_id
	combat._combat_turns_by_id[former_companion_id] = 2
	dead.current_health = 0
	_check(combat._check_combat_end() and combat._promotion_cleanup_pending
		and gerencia.campaign.active_entity_states[0] == companion
		and combat._combat_turns_by_id.get(companion.instance_id, 0) == 2
		and not combat._combat_turns_by_id.has(former_companion_id)
		and gerencia.campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE,
		"Combate promove antes do Game Over sem reiniciar usos de turno, e aguarda a redistribuição.")
	await create_timer(2.65).timeout
	var panel := top_bar.group_inventory
	_check(panel.visible and panel.columns.size() == 4
		and panel._death_owner == dead
		and panel._title_label.text == "REDISTRIBUA OS ITENS"
		and companion.visible_name() in panel._exchange_message.text,
		"Após a animação, caixa mostra morto, três jogáveis e explicação da promoção.")
	_check(loot in dead.inventory_items, "Item sem espaço continua no espólio para escolha manual.")
	companion.inventory_items.pop_back()
	panel.drop_inventory_entry(dead, companion, loot, 0)
	_check(loot in companion.inventory_items and loot not in dead.inventory_items,
		"Arrastar da quarta coluna entrega o item ao jogável promovido.")
	panel._ask_exchange_confirmation()
	if panel._exchange_confirmation.visible:
		panel._confirm_exchange()
	_check(not panel.visible and not combat._promotion_cleanup_pending
		and gerencia.campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE,
		"OK conclui redistribuição e libera o combate sem derrota indevida.")
	scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
