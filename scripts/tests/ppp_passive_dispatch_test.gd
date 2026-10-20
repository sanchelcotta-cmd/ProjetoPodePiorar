extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "Campanha inicia.")
	var student := campaign.active_entity_states[0]
	student.turn_serial = 1
	var manager := SkillManager.new()
	root.add_child(manager)
	var coffee := load("res://resources/skills/passives/playables/universitario/multitarefa_de_cafeinado.tres") as PassiveSkillData
	check(coffee.trigger == PassiveSkillData.Trigger.ON_ITEM_CONSUMED,
		"Multitarefa usa item consumido, não status aplicado.")
	var food := load("res://resources/itens/consumables/bolinho_de_chuva.tres") as ItemData
	var weapon := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	check(manager.on_item_consumed(student, weapon, campaign, HexGrid.PPPMapMode.COMBAT).is_empty(),
		"Equipamento não dispara item consumido.")
	check(manager.on_item_consumed(student, food, campaign, HexGrid.PPPMapMode.EXPLORATION).is_empty(),
		"Passiva de combate não dispara na Exploração.")
	check(manager.on_item_consumed(student, food, campaign, HexGrid.PPPMapMode.COMBAT, &"fight_1").size() == 1,
		"Consumível em combate dispara a passiva.")
	check(student.extra_attacks_this_turn == 1,
		"Executor registra um ataque adicional para completar dois no turno.")

	var daily := PassiveSkillData.new()
	daily.id = &"test_daily"
	daily.trigger = PassiveSkillData.Trigger.ON_DAY_START
	var heal := SkillEffectData.new()
	heal.effect_type = SkillEffectData.EffectType.HEAL_FIXED
	heal.amount = 2
	daily.effects.append(heal)
	check(manager.grant_skill(student, daily, &"test", &"daily") != null,
		"Passiva diária sintética pode ser concedida.")
	student.current_health -= 5
	check(manager.on_day_started(campaign).size() == 1 and student.current_health == student.max_health - 3,
		"Virada de Dia encaminha efeito simples ao executor.")

	var gated := PassiveSkillData.new()
	gated.id = &"test_gated"
	gated.trigger = PassiveSkillData.Trigger.ON_ITEM_CONSUMED
	gated.activation_context = PassiveSkillData.ActivationContext.COMBAT
	gated.minimum_group_information_count = 2
	gated.max_activations_per_turn = 1
	var attack := SkillEffectData.new()
	attack.effect_type = SkillEffectData.EffectType.ADD_EXTRA_ATTACK
	attack.amount = 1
	gated.effects.append(attack)
	check(manager.grant_skill(student, gated, &"test", &"gated") != null,
		"Passiva com condição pode ser concedida.")
	manager.on_item_consumed(student, food, campaign, HexGrid.PPPMapMode.COMBAT, &"fight_1")
	check(student.extra_attacks_this_turn == 1,
		"Sem Informação, a passiva adicional não disparou.")
	campaign.obtained_information_ids[&"one"] = true
	campaign.obtained_information_ids[&"two"] = true
	manager.on_item_consumed(student, food, campaign, HexGrid.PPPMapMode.COMBAT, &"fight_1")
	check(student.extra_attacks_this_turn == 2,
		"Com 2 Informações, ambas as passivas dispararam.")
	manager.on_item_consumed(student, food, campaign, HexGrid.PPPMapMode.COMBAT, &"fight_1")
	check(student.extra_attacks_this_turn == 2,
		"Limite por turno bloqueia as duas origens limitadas.")

	var unsupported := PassiveSkillData.new()
	unsupported.id = &"test_unsupported"
	unsupported.trigger = PassiveSkillData.Trigger.ON_ITEM_CONSUMED
	unsupported.activation_context = PassiveSkillData.ActivationContext.COMBAT
	var debuff := SkillEffectData.new()
	debuff.effect_type = SkillEffectData.EffectType.APPLY_DEBUFF
	unsupported.effects.append(debuff)
	var source := manager.grant_skill(student, unsupported, &"test", &"unsupported")
	check(source != null, "Concessão não depende do executor do gatilho.")
	var before := source.passive_uses_in_turn
	manager.on_item_consumed(student, food, campaign, HexGrid.PPPMapMode.COMBAT, &"fight_1")
	check(source.passive_uses_in_turn == before,
		"Efeito ainda não executável não gasta uso nem finge sucesso.")

	print("PASSIVE_DISPATCH_TEST_OK" if failures == 0 else "PASSIVE_DISPATCH_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
