extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var combat := scene.get_node("CombatManager") as CombatManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var chef_data := load(
		"res://resources/entities/entities_playable/cozinheiro.tres") as EntityData
	var journalist_data := load(
		"res://resources/entities/entities_playable/jornalista.tres") as EntityData
	var builder_data := load(
		"res://resources/entities/entities_playable/pedreiro.tres") as EntityData
	_check(gerencia.start_new_game([chef_data, journalist_data, builder_data]),
		"Campanha criada para teste da adaga.")
	var campaign := gerencia.campaign
	campaign.current_map = HexGrid.new()
	campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	var chef := campaign.active_entity_states[0]
	chef.inventory_items.clear()
	var dagger := load("res://resources/itens/equipments/armas/arma_epica_adaga_de_sombra_e_luz.tres") as ItemData
	var inventory := InventoryManager.new()
	var equipment := EquipmentManager.new()
	_check(inventory.add_item(chef, dagger), "Adaga adicionada.")
	_check(equipment.equip(chef, chef.inventory_items[0], skills, campaign),
		"Adaga equipada.")
	chef.position = Vector2i(0, 0)
	chef.current_health = maxi(1, chef.max_health - 10)
	var enemy_data := load(
		"res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var enemy := EntityState.from_encounter_member(enemy_data, &"dagger_test", 0,
		Vector2i(1, 0))
	enemy.max_health = 1000
	enemy.current_health = 1000
	combat.enemies.append(enemy)
	combat.current_actor = chef
	combat._combat_id = &"dagger_alternation"
	var expected_base := chef.attack + 3
	combat._turn_die = 3
	var light := combat._resolve_attack(chef, enemy)
	_check(int(light.get("raw_damage", -1)) == expected_base * 2
		and chef.dagger_next_aspect == &"shadow",
		"Primeiro ataque é Luz, dobra dano e anuncia Sombra como próxima.")
	var health_before_shadow := chef.current_health
	combat._turn_die = 3
	var shadow := combat._resolve_attack(chef, enemy)
	_check(int(shadow.get("raw_damage", -1)) == expected_base
		and chef.dagger_next_aspect == &"light",
		"Segundo ataque é Sombra, sem bônus de Luz; próxima é Luz.")
	_check(chef.current_health - health_before_shadow == mini(
		chef.max_health - health_before_shadow,
		floori(float(int(shadow.get("damage", 0))) * 0.6)),
		"Sombra recupera 60% do dano real causado.")
	combat._turn_die = 3
	var third := combat._resolve_attack(chef, enemy)
	_check(int(third.get("raw_damage", -1)) == expected_base * 2
		and chef.dagger_next_aspect == &"shadow",
		"Terceiro ataque retorna à Luz de forma determinística.")
	chef.current_health = maxi(1, chef.max_health - 20)
	var before_counter := chef.current_health
	var counter := combat.try_passive_counterattack(chef, enemy)
	_check(counter.get("counterattack", false)
		and chef.dagger_next_aspect == &"light",
		"Contra-ataque também consome a próxima face Sombra.")
	_check(chef.current_health - before_counter == mini(
		chef.max_health - before_counter,
		floori(float(int(counter.get("damage", 0))) * 0.6)),
		"Sombra em contra-ataque cura pela mesma regra do ataque básico.")
	var codec := CampaignSaveCodec.new()
	var packed := codec.encode(chef)
	_check(codec.error.is_empty(), "Estado da adaga pode ser salvo.")
	if codec.error.is_empty():
		var restored := codec.decode(packed) as EntityState
		_check(restored != null and restored.dagger_next_aspect == &"light",
			"Próxima cor da adaga persiste após carregar.")
	print("PPP_DAGGER_ALTERNATION: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
