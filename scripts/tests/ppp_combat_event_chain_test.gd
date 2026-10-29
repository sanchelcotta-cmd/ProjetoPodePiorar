extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var combat := scene.get_node("CombatManager") as CombatManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha para os eventos de combate inicia.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	var source := Vector2i(0, 1)
	actor.position = source
	campaign.active_entity_states[1].position = Vector2i(1, 2)
	campaign.active_entity_states[2].position = Vector2i(2, 2)
	var old_man := load("res://resources/events/random_events/03-o_velho_louco.tres") as EventData
	_check(_start_event(scene, source, old_man), "03: Outcome inicia o Encontro.")
	_check(combat.current_encounter != null and combat.enemies.size() == 1
		and combat.initiative_order.size() == 4
		and combat.enemies[0].data.display_name == "Velho Louco"
		and campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT,
		"03: Velho Louco entra no combate/iniciativa real.")
	var mean_hp := 0.0
	var mean_attack := 0.0
	for playable in campaign.active_entity_states:
		mean_hp += playable.max_health
		mean_attack += playable.attack
	mean_hp /= 3.0
	mean_attack /= 3.0
	_check(abs(combat.enemies[0].max_health - roundi(mean_hp)) <= 5
		and abs(combat.enemies[0].attack - roundi(mean_attack)) <= 5,
		"03: Vida e Ataque usam desvios inteiros independentes entre -5 e +5.")
	await _finish_victory(combat, popup)
	_check(not block.is_busy() and campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"03: depois do desfecho, o Evento original termina.")
	var ally := EntityState.from_playable_selection(selected[1], &"Test_Ally",
		EntityState.UNPLACED)
	ally.max_health = 80
	ally.current_health = 80
	ally.attack = 20
	campaign.companion_states.append(ally)
	var with_ally := executor._crazy_old_man_encounter()
	var expected_ally_health := roundi((mean_hp * 3.0 + 80.0) / 4.0)
	var expected_ally_attack := roundi((mean_attack * 3.0 + 20.0) / 4.0)
	_check(with_ally != null and abs(with_ally.members[0].entity.vida_base
		- expected_ally_health) <= 5 and abs(with_ally.members[0].entity.ataque_base
		- expected_ally_attack) <= 5,
		"03: um aliado vivo entra nas duas médias antes do desvio.")
	campaign.companion_states.erase(ally)
	var men_info := load("res://resources/informacoes/homens_de_preto/homens_de_preto_1.tres") as Informacao
	campaign.obtained_information_ids[men_info.id] = true
	_check(_start_event(scene, source, old_man), "03: ramo com Informação abre Outcome.")
	_check(combat.current_encounter == null and not block.is_busy(),
		"03: com Informação, o velho vai embora sem combate.")
	var zombie_event := load("res://resources/events/random_events/04-termos_de_uso.tres") as EventData
	_check(_start_event(scene, source, zombie_event), "04: horda inicia Encontro.")
	var district_encounter := load("res://resources/encounters/enc_zumbis_dancarinos_%s.tres" % campaign.district) as EncounterData
	var member := district_encounter.members[0]
	_check(combat.current_encounter == district_encounter
		and combat.enemies.size() >= member.minimum
		and combat.enemies.size() <= member.maximum,
		"04: composição e faixa numérica vêm do Resource do Distrito.")
	await _finish_victory(combat, popup)
	var mind_info := load("res://resources/informacoes/controle_da_mente/controle_da_mente_1.tres") as Informacao
	campaign.obtained_information_ids[mind_info.id] = true
	_check(_start_event(scene, source, zombie_event), "04: ramo com Informação abre Outcome.")
	_check(combat.current_encounter == null and not block.is_busy(),
		"04: com Controle da Mente, não surge horda.")
	var near := Vector2i(2, 1)
	var far := Vector2i(7, 3)
	var near_encounter := load("res://resources/encounters/enc_barata_voadora.tres") as EncounterData
	var far_encounter := load("res://resources/encounters/enc_cao_infernal.tres") as EncounterData
	for coord in campaign.current_map.cells:
		if campaign.current_map.get_ppp_block_type(coord) == HexGrid.PPPBlockType.ENCOUNTER:
			campaign.current_map.activate_ppp_block(coord)
	campaign.current_map.set_ppp_block(near, HexGrid.PPPBlockType.ENCOUNTER, near_encounter)
	campaign.current_map.set_ppp_block(far, HexGrid.PPPBlockType.ENCOUNTER, far_encounter)
	var stumble := load("res://resources/events/random_events/33-tropeco_perigoso.tres") as EventData
	_check(_start_event(scene, source, stumble), "33: tropeço inicia o Encontro mais próximo.")
	_check(combat.current_encounter == near_encounter,
		"33: o Encontro escolhido é o mais próximo do hex ativado.")
	await _finish_victory(combat, popup)
	_check(campaign.current_map.get_cell(near).state == HexGrid.PPPBlockState.ACTIVATED
		and campaign.current_map.get_cell(far).state == HexGrid.PPPBlockState.HIDDEN,
		"33: consome só o bloco de Encontro que veio ao combate.")
	var artifact := load("res://resources/events/random_events/20-um_artefato_magico.tres") as EventData
	var original_outcomes := artifact.outcomes.duplicate()
	for branch in [0, 1, 2]:
		var chosen := original_outcomes[branch] as EventOutcomeData
		var health_before := actor.max_health
		var effects_before := campaign.temporary_event_effects.size()
		var allies_before := campaign.companion_states.size()
		artifact.outcomes.clear()
		artifact.outcomes.append(chosen)
		_check(_start_event(scene, source, artifact, false),
			"20: o ramo %d apresenta a narrativa do Evento filho." % branch)
		_check(popup._outcome_reading and popup._context.get("resource") is EventData
			and (popup._context["resource"] as EventData).id == StringName("ev_%05d" % (21 + branch)),
			"20: a segunda leitura pertence ao evento 21/22/23 escolhido.")
		popup._execute_prepared_event()
		_check(not block.is_busy(), "20: filho %d conclui o bloco pai após OK." % branch)
		match branch:
			0:
				_check(actor.max_health == health_before - 5,
					"20→21: ataque sobrenatural reduz 5 de Vida máxima.")
			1:
				_check(campaign.temporary_event_effects.size() == effects_before + 1,
					"20→22: perseguição registra dano futuro até o fim do Dia.")
			2:
				_check(campaign.companion_states.size() == allies_before + 1,
					"20→23: criatura sorteada realmente entra como aliada.")
	artifact.outcomes.assign(original_outcomes)
	var vortex := load("res://resources/events/random_events/28-vortice_mortal.tres") as EventData
	_check(_start_event(scene, source, vortex), "28: Vórtice inicia combate solo.")
	_check(combat.current_encounter != null and combat.enemies.size() == 1
		and combat.initiative_order.size() == 2
		and combat.initiative_order.any(func(entry: Dictionary) -> bool:
			return entry["entity"] == actor)
		and campaign.active_entity_states[1].temporarily_absent_from_map,
		"28: somente ativador e um hostil entram na iniciativa/mapa.")
	var reward := executor.get_pending_event_combat_reward()
	_check(reward != null and reward.rarity == ItemData.Rarity.EPIC
		and reward.item_type == ItemData.ItemType.EQUIPMENT,
		"28: prêmio é equipável Épico real, escolhido antes do desfecho.")
	await _finish_victory(combat, popup)
	_check(actor.inventory_items.any(func(entry: InventoryItemState) -> bool:
		return entry.data == reward)
		and not campaign.active_entity_states[1].temporarily_absent_from_map
		and not block.is_busy(),
		"28: vitória entrega o prêmio e reintegra o grupo.")
	var inventory := InventoryManager.new()
	var chocolate := load("res://resources/itens/consumables/chocolate.tres") as ItemData
	while actor.inventory_used_space() < actor.inventory_capacity():
		inventory.add_item(actor, chocolate)
	_check(_start_event(scene, source, vortex),
		"28: Vórtice abre mesmo com o inventário cheio.")
	var full_reward := executor.get_pending_event_combat_reward()
	_check(combat.request_victory(), "28: vitória prepara recompensa obrigatória.")
	await create_timer(0.44).timeout
	popup._confirm_combat_conclusion()
	var group_inventory := (scene.get_node("CampaignTopBar") as CampaignTopBar).group_inventory
	_check(group_inventory != null and group_inventory.visible and block.is_busy(),
		"28: inventário cheio abre troca antes de encerrar o Evento.")
	if group_inventory != null:
		var outgoing: Array[InventoryItemState] = []
		for entry in actor.inventory_items:
			if entry.data.can_be_discarded and entry.data.item_type != ItemData.ItemType.CURSED:
				outgoing.append(entry)
				if inventory.can_exchange_items(actor, outgoing, full_reward):
					break
		group_inventory.set("_exchange_selected", outgoing)
		group_inventory._ask_exchange_confirmation()
		group_inventory._confirm_exchange()
	_check(not block.is_busy() and actor.inventory_items.any(
		func(entry: InventoryItemState) -> bool: return entry.data == full_reward),
		"28: troca confirmada entrega o Épico sem duplicar nem perder o prêmio.")
	_check(_start_event(scene, source, vortex), "28: um segundo Vórtice testa derrota isolada.")
	actor.current_health = 0
	combat._check_combat_end()
	await create_timer(0.44).timeout
	_check(combat.pending_conclusion.get("result", {}).get("reason") == "solo_defeat",
		"28: morte do isolado não gera derrota total da campanha.")
	popup._confirm_combat_conclusion()
	_check(not block.is_busy() and actor in campaign.dead_playable_states
		and actor.turn_state == EntityState.TurnState.INACTIVE
		and campaign.active_entity_states[1].current_health > 0
		and not campaign.active_entity_states[1].temporarily_absent_from_map,
		"28: o grupo sobrevivente continua após a morte definitiva.")
	print("PPP combat event chain: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _start_event(scene: PPPMapView, coord: Vector2i, event: EventData,
		execute_child: bool = true) -> bool:
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	gerencia.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	if not block.begin_activation(coord, gerencia.campaign.active_entity_states[0]):
		return false
	popup._confirm_event({})
	if not popup._outcome_reading:
		return false
	popup._execute_prepared_event()
	if execute_child and popup._outcome_reading:
		popup._execute_prepared_event()
	return true


func _finish_victory(combat: CombatManager, popup: BlockActivationPopup) -> void:
	_check(combat.request_victory(), "Vitória pode ser solicitada.")
	await create_timer(0.44).timeout
	popup._confirm_combat_conclusion()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
