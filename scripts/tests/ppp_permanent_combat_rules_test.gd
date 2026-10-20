extends SceneTree

## Regressão em combate das concessões permanentes 55, 56 e 57. O fluxo
## de concessão pela caixa de Evento é coberto por ppp_permanent_events_test.

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var combat := scene.get_node("CombatManager") as CombatManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres")]
	_check(gerencia.start_new_game(selected), "Campanha criada.")
	var campaign := gerencia.campaign
	campaign.current_map = HexGrid.new()
	campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	var journalist := campaign.active_entity_states[0]
	var chef := campaign.active_entity_states[1]
	var builder := campaign.active_entity_states[2]
	for actor in campaign.active_entity_states:
		actor.inventory_items.clear()
	var inventory := InventoryManager.new()
	var equipment := EquipmentManager.new()
	var sling := load(
		"res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	_check(inventory.add_item(journalist, sling) \
		and equipment.equip(journalist, journalist.inventory_items[0], skills, campaign),
		"Jornalista equipa arma de Distância.")
	var vision := load(
		"res://resources/skills/passives/permanent_effects/olhos_bionicos.tres") as PassiveSkillData
	_check(skills.grant_skill(journalist, vision, &"event", &"test_55", campaign) != null,
		"Olhos Biônicos são concedidos.")
	journalist.position = Vector2i(0, 0)
	var enemy_data := load(
		"res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var distant := EntityState.from_encounter_member(enemy_data, &"test_55", 0,
		Vector2i(20, 0))
	distant.max_health = 1000
	distant.current_health = 1000
	combat.enemies.append(distant)
	combat.current_actor = journalist
	combat._combat_id = &"permanent_combat"
	combat._turn_die = 1
	_check(combat.can_player_attack(distant.position),
		"Olhos Biônicos ignoram o limite de alcance com arma de Distância.")
	var hit := combat._resolve_attack(journalist, distant)
	_check(hit.get("success", false) and int(hit.get("raw_damage", 0)) == 1,
		"Ataque muito distante mantém queda de dano e mínimo 1 ao acertar.")
	var third_arm := load(
		"res://resources/skills/passives/permanent_effects/protese_do_terceiro_braco.tres") as PassiveSkillData
	_check(skills.grant_skill(builder, third_arm, &"event", &"test_56", campaign) != null \
		and builder.equipment_slot_capacity(&"weapon") == 2,
		"Prótese permite segundo slot de arma.")
	skills.dispatch_passive_trigger(builder, PassiveSkillData.Trigger.ON_TURN_START,
		campaign, {"mode": HexGrid.PPPMapMode.COMBAT, "combat": combat,
			"combat_id": combat._combat_id, "combat_turn_number": 1})
	_check(builder.extra_attacks_this_turn == 1,
		"Prótese concede um ataque extra no turno de combate.")
	var gene := load(
		"res://resources/skills/passives/permanent_effects/gene_da_furia_bestial.tres") as PassiveSkillData
	_check(skills.grant_skill(chef, gene, &"event", &"test_57", campaign) != null,
		"Gene da Fúria Bestial é concedido.")
	chef.position = Vector2i(0, 1)
	var near := EntityState.from_encounter_member(enemy_data, &"test_57", 1,
		Vector2i(1, 1))
	near.max_health = 1000
	near.current_health = 1000
	combat.enemies.append(near)
	combat.current_actor = chef
	combat._turn_die = 3
	combat._steps_moved = 0
	var unarmed_expected := (chef.attack + 3) * 3
	hit = combat._resolve_attack(chef, near)
	_check(int(hit.get("raw_damage", 0)) == unarmed_expected,
		"Gene triplica o dano final desarmado.")
	var blade := load(
		"res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	_check(inventory.add_item(chef, blade) \
		and equipment.equip(chef, chef.inventory_items[-1], skills, campaign),
		"Cozinheiro equipa Lâmina para a segunda variante do Gene.")
	near.current_health = 1000
	combat._turn_die = 3
	var armed_expected := chef.attack + ceili(float(chef.attack) * 0.5) + 3
	hit = combat._resolve_attack(chef, near)
	_check(int(hit.get("raw_damage", 0)) == armed_expected,
		"Gene acrescenta 50% do Ataque, arredondado para cima, com arma corpo a corpo.")
	var symbiosis := load(
		"res://resources/skills/passives/permanent_effects/simbiose_elemental.tres") as PassiveSkillData
	var sword := load("res://resources/itens/equipments/armas/arma_epica_espada_irada_flamejante.tres") as ItemData
	_check(skills.grant_skill(chef, symbiosis, &"event", &"test_58_blade",
		campaign, sword) != null, "Simbiose de Lâmina é concedida.")
	near.current_health = 1000
	combat._turn_die = 3
	hit = combat._resolve_attack(chef, near)
	_check(int(hit.get("damage", 0)) > 0 \
		and &"db_00008" in skills.debuff_manager.get_debuff_ids(near),
		"Simbiose de Lâmina aplica Sangramento em ataque que causa dano.")
	var staff := load("res://resources/itens/equipments/armas/arma_epica_bastao_do_guardiao.tres") as ItemData
	_check(skills.grant_skill(builder, symbiosis, &"event", &"test_58_impact",
		campaign, staff) != null, "Simbiose de Impacto é concedida.")
	builder.position = Vector2i(0, 2)
	var impact_target := EntityState.from_encounter_member(enemy_data, &"test_58", 2,
		Vector2i(1, 2))
	impact_target.max_health = 1000
	impact_target.current_health = 1000
	combat.enemies.append(impact_target)
	combat.current_actor = builder
	combat._turn_die = 3
	hit = combat._resolve_attack(builder, impact_target)
	_check(int(hit.get("damage", 0)) > 0 \
		and &"db_00002" in skills.debuff_manager.get_debuff_ids(impact_target),
		"Simbiose de Impacto aplica Atordoamento em ataque que causa dano.")
	var bow := load("res://resources/itens/equipments/armas/arma_epica_arco_da_precisao.tres") as ItemData
	_check(skills.grant_skill(journalist, symbiosis, &"event", &"test_58_range",
		campaign, bow) != null \
		and skills.ignores_attack_range(journalist, EntityData.Mastery.RANGED),
		"Simbiose de Distância remove o limite de alcance.")
	combat.current_actor = journalist
	combat._turn_die = 3
	combat._steps_moved = 1
	distant.position = Vector2i(3, 0)
	distant.current_health = 1000
	var ranged_preview := combat.get_player_attack_preview(distant.position)
	var ranged_expected := journalist.attack + 3 - 1
	_check(int(ranged_preview.get("distance", -1)) == 0 \
		and int(ranged_preview.get("damage", -1)) == ranged_expected,
		"Simbiose de Distância remove a redução por hex, mas mantém o custo do movimento.")
	hit = combat._resolve_attack(journalist, distant)
	_check(int(hit.get("raw_damage", -1)) == ranged_expected,
		"Dano real da Simbiose de Distância bate com a prévia.")
	print("PPP permanent combat rules: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
