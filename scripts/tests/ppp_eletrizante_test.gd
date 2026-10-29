extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var combat := scene.get_node("CombatManager") as CombatManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/professora.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	check(game.start_new_game(party), "Campanha de teste inicia.")
	game.campaign.current_map = HexGrid.new()
	game.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	var actor := game.campaign.active_entity_states[0] as EntityState
	actor.position = Vector2i(0, 0)
	var sword := load("res://resources/itens/equipments/armas/arma_epica_espada_irada_eletrizante.tres") as ItemData
	check(sword != null and sword.id == &"aa_00014" and sword.mastery_bonus == 3
		and sword.bonus_attack == 7, "Espada Eletrizante tem identidade e bônus corretos.")
	for old_weapon in actor.equipped_in_slot(ItemData.EquipmentSlot.WEAPON).duplicate():
		EquipmentManager.new().unequip(actor, old_weapon, skills)
	var entry := InventoryItemState.new(sword)
	actor.inventory_items.append(entry)
	check(EquipmentManager.new().equip(actor, entry, skills, game.campaign),
		"Espada pode ser equipada.")
	var zombie := load("res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var primary := EntityState.from_encounter_member(zombie, &"electric_test", 1, Vector2i(1, 0))
	var near := EntityState.from_encounter_member(zombie, &"electric_test", 2, Vector2i(2, 0))
	var far := EntityState.from_encounter_member(zombie, &"electric_test", 3, Vector2i(5, 0))
	combat.enemies.append_array([primary, near, far])
	combat._combat_id = &"electric_test"
	combat._combat_turns_by_id[actor.instance_id] = 1
	var before_near := near.current_health
	var before_far := far.current_health
	var triggered := skills.dispatch_passive_trigger(actor,
		PassiveSkillData.Trigger.ON_AFTER_DAMAGE_DEALT, game.campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat": combat,
		"combat_id": combat._combat_id, "combat_turn_number": 1,
		"attack_item_id": sword.id, "attack_target": primary,
		"damage_dealt": 10}, combat._rng)
	check(triggered.size() == 1 and near.current_health == before_near - 5
		and far.current_health == before_far,
		"Ricochete causa metade do dano no outro inimigo mais próximo.")
	check((triggered[0]["effects"][0] as Dictionary).get("target") == near,
		"O resultado identifica o alvo secundário.")
	near.position = Vector2i(5, 0)
	far.position = Vector2i(6, 0)
	check(combat.apply_ricochet_damage(actor, primary, 10, 0.5, 3).get(
		"skipped", false), "Sem outro inimigo em até 3 hexes, não há ricochete.")
	near.position = Vector2i(2, 0)
	far.position = Vector2i(1, 1)
	near.current_health = 100
	far.current_health = 100
	combat._rng.seed = 42
	var chosen: Dictionary = {}
	for attempt in 20:
		var bounce := combat.apply_ricochet_damage(actor, primary, 4, 0.5, 3)
		chosen[(bounce.get("target") as EntityState).instance_id] = true
	check(chosen.has(near.instance_id) and chosen.has(far.instance_id),
		"Inimigos empatados na distância são sorteados, não fixados por ordem.")
	far.position = Vector2i(6, 0)
	primary.current_health = 100
	primary.max_health = 100
	near.current_health = 100
	near.max_health = 100
	combat.current_actor = actor
	combat._turn_die = 3
	var action_order: Array[StringName] = []
	combat.action_resolved.connect(func(_source: EntityState, action: StringName,
			_details: Dictionary) -> void: action_order.append(action))
	var attack := combat._resolve_attack(actor, primary)
	check(attack.get("success", false)
		and near.current_health == 100 - floori(float(attack.get("damage", 0)) * 0.5),
		"Ataque normal com a espada dispara ricochete a partir do dano real.")
	check(action_order.size() >= 2 and action_order[0] == &"attack"
		and action_order[1] == &"ricochet",
		"Livro recebe primeiro o ataque e depois seu ricochete.")
	var knife := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	check(knife.craft_result.has(sword) and knife.craft_result.size() == 3,
		"Três facas oferecem a Eletrizante e as outras duas espadas.")
	print("PPP Eletrizante: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
