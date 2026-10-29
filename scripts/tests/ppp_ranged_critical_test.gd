extends SceneTree

## Regressão: somente a Maestria Distância ignora a penalidade da distância
## em um crítico; movimento ainda custa dano, e não existe multiplicador.

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
	var journalist_data := load(
		"res://resources/entities/entities_playable/jornalista.tres") as EntityData
	var chef_data := load(
		"res://resources/entities/entities_playable/cozinheiro.tres") as EntityData
	var builder_data := load(
		"res://resources/entities/entities_playable/pedreiro.tres") as EntityData
	_check(gerencia.start_new_game([journalist_data, chef_data, builder_data]),
		"Campanha para testar crítico de Distância.")
	var campaign := gerencia.campaign
	campaign.current_map = HexGrid.new()
	campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	var journalist := campaign.active_entity_states[0]
	for actor in campaign.active_entity_states:
		actor.inventory_items.clear()
	var inventory := InventoryManager.new()
	var equipment := EquipmentManager.new()
	var sling := load(
		"res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	_check(inventory.add_item(journalist, sling), "Estilingue adicionado.")
	_check(equipment.equip(journalist, journalist.inventory_items[0], skills, campaign),
		"Estilingue equipado.")
	journalist.position = Vector2i(0, 0)
	var enemy_data := load(
		"res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var enemy := EntityState.from_encounter_member(enemy_data, &"crit_test", 0,
		Vector2i(3, 0))
	enemy.max_health = 1000
	enemy.current_health = 1000
	combat.enemies.append(enemy)
	combat.current_actor = journalist
	combat._combat_id = &"ranged_crit"
	combat._turn_die = 6
	combat._steps_moved = 2
	var expected := journalist.attack + 6 - 2
	var preview := combat.get_player_attack_preview(enemy.position)
	_check(int(preview.get("damage", -1)) == expected \
		and int(preview.get("movement", -1)) == 2 \
		and int(preview.get("distance", -1)) == 0,
		"Prévia do crítico de Distância mantém movimento e ignora distância.")
	var hit := combat._resolve_attack(journalist, enemy)
	_check(int(hit.get("raw_damage", -1)) == expected,
		"Dano real não dobra e mantém o custo dos hexes percorridos.")
	var attack_entry: Dictionary = campaign.journal_entries.back()
	_check(str(attack_entry.get("text", "")).contains("CRITOU!") \
		and bool((attack_entry.get("references", {}) as Dictionary).get("critical", false)),
		"Crítico real chega ao livro com complemento dourado e dado estruturado.")
	enemy.current_health = 1000
	enemy.ignore_ranged_critical_bonus = true
	combat._turn_die = 6
	preview = combat.get_player_attack_preview(enemy.position)
	var protected_expected := expected - 2
	_check(int(preview.get("damage", -1)) == protected_expected \
		and int(preview.get("distance", -1)) == 2,
		"Pele Endurecida mantém a penalidade de dois hexes de distância.")
	hit = combat._resolve_attack(journalist, enemy)
	_check(int(hit.get("raw_damage", -1)) == protected_expected,
		"Dano real contra Pele Endurecida bate com a prévia.")
	print("PPP ranged critical: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
