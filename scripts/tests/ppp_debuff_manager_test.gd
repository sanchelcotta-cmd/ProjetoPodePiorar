extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := SkillManager.new()
	root.add_child(manager)
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "Campanha de teste criada.")
	var actor := campaign.active_entity_states[0]
	var other := campaign.active_entity_states[1]
	var source := campaign.active_entity_states[2]
	var statuses := manager.debuff_manager
	check(statuses.find_debuff(&"db_00008") != null, "Catálogo carrega Sangramento.")

	var bleed_effect := SkillEffectData.new()
	bleed_effect.effect_type = SkillEffectData.EffectType.APPLY_DEBUFF
	bleed_effect.target = SkillEffectData.Target.ATTACK_TARGET
	bleed_effect.debuff_id = &"db_00008"
	var attack_context := {"actor": source, "attack_target": actor,
		"campaign": campaign, "damage_dealt": 9}
	check(not manager.can_apply_debuff_effect(bleed_effect, attack_context),
		"Dano final sozinho não pode definir a duração do Sangramento.")
	attack_context["damage_die_result"] = 3
	check(manager.can_apply_debuff_effect(bleed_effect, attack_context),
		"Resultado do dado permite aplicar Sangramento.")
	var bleed := manager.apply_debuff_effect(bleed_effect, attack_context)
	check(bleed.get("success", false), "Sangramento recebe resultado do dado.")
	var bleed_instance := statuses.get_debuff(actor, &"db_00008")
	check(bleed_instance != null and bleed_instance.remaining_turns == 3
		and bleed_instance.current_tick_damage == 1,
		"Dado 3 define 3 turnos de 1 dano, mesmo com dano final 9.")
	var before := actor.current_health
	actor.turn_serial = 1
	manager.on_entity_turn_started(actor, campaign)
	manager.on_entity_turn_started(actor, campaign)
	check(actor.current_health == before - 1, "Início repetido não duplica dano recorrente.")
	manager.on_entity_moved(actor, campaign)
	check(actor.current_health == before - 3, "Mover causa 2 de dano adicionais.")
	manager.on_entity_turn_finished(actor, campaign)
	for serial in [2, 3]:
		actor.turn_serial = serial
		manager.on_entity_turn_started(actor, campaign)
		manager.on_entity_turn_finished(actor, campaign)
	check(statuses.get_debuff(actor, &"db_00008") == null,
		"Sangramento termina após os turnos definidos pelo dado.")
	check(is_equal_approx(statuses.find_debuff(&"db_00003").contagion_chance_per_round, 0.20)
		and is_equal_approx(statuses.find_debuff(&"db_00004").contagion_chance_per_round, 0.25)
		and is_equal_approx(statuses.find_debuff(&"db_00005").contagion_chance_per_round, 0.40),
		"Chances dos três estágios são editáveis nos Resources.")

	var original_max := actor.max_health
	statuses.apply_by_id(actor, &"db_00003", source, 0, campaign.day)
	check(actor.max_health == original_max - 2, "Doença Leve reduz Vida máxima.")
	campaign.day = 2
	statuses.on_day_started(actor, campaign, manager)
	check(statuses.get_debuff(actor, &"db_00004") != null and actor.max_health == original_max - 3,
		"Na primeira virada, Doença Leve evolui para Doença.")
	campaign.day = 3
	statuses.on_day_started(actor, campaign, manager)
	check(statuses.get_debuff(actor, &"db_00005") != null and actor.max_health == original_max - 5,
		"Doença Grave começa sem perda diária adicional.")
	campaign.day = 4
	statuses.on_day_started(actor, campaign, manager)
	check(actor.max_health == original_max - 7,
		"Só na virada seguinte a Doença Grave perde mais 2 de Vida máxima.")
	statuses.remove_debuff(actor, &"db_00005")
	check(actor.max_health == original_max and actor.current_health <= actor.max_health,
		"Cura restaura Vida máxima, mas não cura automaticamente a Vida atual.")

	var burn := statuses.apply_by_id(actor, &"db_00007", source, 4, campaign.day)
	check(burn.get("success", false), "Queimadura recebe dano inicial da fonte.")
	var health_before_burn := actor.current_health
	for serial in [4, 5, 6, 7]:
		actor.turn_serial = serial
		manager.on_entity_turn_started(actor, campaign)
	check(actor.current_health == health_before_burn - 6,
		"Queimadura 4 causa 3, 2, 1 e então termina.")
	check(statuses.get_debuff(actor, &"db_00007") == null,
		"Queimadura some ao chegar a zero.")

	var terror_source := EntityState.new()
	terror_source.data = load("res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	terror_source.instance_id = &"zumbi_a"
	statuses.apply_by_id(other, &"db_00009", terror_source, 0, campaign.day,
		-1, &"", 1.0)
	other.turn_serial = 1
	manager.on_entity_turn_started(other, campaign)
	check(statuses.get_debuff(other, &"db_00009") == null,
		"Terror desaparece quando o alvo resiste no início do turno.")
	check(is_equal_approx(float(other.terror_resistance_bonus_by_source.get(terror_source.data.id, 0.0)), 0.05),
		"Resistir acrescenta 5% contra o mesmo tipo de inimigo.")
	var terror_source_2 := EntityState.new()
	terror_source_2.data = terror_source.data
	terror_source_2.instance_id = &"zumbi_b"
	statuses.apply_by_id(other, &"db_00009", terror_source_2, 0, campaign.day,
		-1, &"", 1.0)
	other.turn_serial = 2
	manager.on_entity_turn_started(other, campaign)
	check(is_equal_approx(float(other.terror_resistance_bonus_by_source.get(terror_source.data.id, 0.0)), 0.10),
		"Outro indivíduo do mesmo EntityData usa a mesma memória de resistência.")
	statuses.apply_by_id(actor, &"db_00009", terror_source, 0, campaign.day,
		-1, &"", 0.0)
	check(not statuses.has_control(actor, DebuffData.ControlEffect.AWAY_FROM_SOURCE),
		"Terror só decide fuga ou resistência no início do turno afetado.")
	actor.turn_serial = 8
	manager.on_entity_turn_started(actor, campaign)
	check(statuses.has_control(actor, DebuffData.ControlEffect.AWAY_FROM_SOURCE),
		"Falhar na resistência obriga fugir do causador neste turno.")
	statuses.remove_debuff(actor, &"db_00009")

	var rooted := SkillEffectData.new()
	rooted.effect_type = SkillEffectData.EffectType.APPLY_DEBUFF
	rooted.target = SkillEffectData.Target.ATTACK_TARGET
	rooted.debuff_id = &"db_00006"
	var passive := PassiveSkillData.new()
	passive.id = &"test_root"
	passive.trigger = PassiveSkillData.Trigger.ON_AFTER_ATTACK
	passive.effects.append(rooted)
	manager.grant_skill(source, passive, &"test", &"root")
	check(manager.dispatch_passive_trigger(source, PassiveSkillData.Trigger.ON_AFTER_ATTACK,
		campaign, {"attack_target": other, "mode": HexGrid.PPPMapMode.COMBAT,
			"combat_id": &"fight_test", "combat_turn_number": 1}).size() == 1,
		"SkillEffect APPLY_DEBUFF usa o gerenciador de status.")
	check(not statuses.can_move_to(other, Vector2i(0, 0)),
		"Enraizado impede movimento.")

	var round_status := Event_EffectData.new()
	round_status.effect_type = Event_EffectData.EffectType.APPLY_STATUS
	round_status.debuff = statuses.find_debuff(&"db_00002")
	round_status.has_duration = true
	round_status.duration_amount = 1
	round_status.duration_unit = Event_EffectData.DurationUnit.ROUND
	check(manager.apply_event_status(round_status, actor, source, campaign).get("success", false),
		"Outcome de Evento pode aplicar Debuff pelo mesmo motor.")
	check(statuses.get_debuff(actor, &"db_00002") != null,
		"Atordoamento do Evento está ativo.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.AFTERNOON
	statuses.on_round_started(actor, campaign, manager)
	check(statuses.get_debuff(actor, &"db_00002") == null,
		"Duração de uma Rodada encerra na fase seguinte.")
	check(statuses.apply_by_id(actor, &"db_00007", source, 4, campaign.day).get("success", false),
		"Queimadura pode ser reaplicada antes de mudar de Rodada.")
	check(statuses.apply_by_id(actor, &"db_00008", source, 0, campaign.day,
		-1, &"", -1.0, 3).get("success", false),
		"Sangramento pode ser reaplicado antes de mudar de Rodada.")
	check(statuses.get_debuff(actor, &"db_00007") != null and \
		statuses.get_debuff(actor, &"db_00008") != null,
		"Queimadura e Sangramento permanecem durante a Rodada atual.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	statuses.on_round_started(actor, campaign, manager)
	check(statuses.get_debuff(actor, &"db_00007") == null and \
		statuses.get_debuff(actor, &"db_00008") == null,
		"Queimadura e Sangramento são limpos na troca de Rodada.")

	var contagious := DebuffData.new()
	contagious.id = &"test_contagious"
	contagious.duration_type = DebuffData.DurationType.UNTIL_CURE
	contagious.contagion_chance_per_round = 1.0
	contagious.contagion_result_id = &"db_00003"
	statuses.register_debuff(contagious)
	statuses.apply_debuff(actor, contagious, source, 0, campaign.day)
	check(statuses.get_debuff(other, &"db_00003") == null,
		"Contágio não acontece no turno individual.")
	statuses.on_round_started(actor, campaign, manager)
	check(statuses.get_debuff(other, &"db_00003") != null,
		"Contágio é avaliado na virada de Rodada.")
	contagious.contagion_result_id = contagious.id
	manager.on_round_started(campaign)
	check(statuses.get_debuff(other, contagious.id) != null \
		and statuses.get_debuff(source, contagious.id) == null,
		"Infecção nova não causa contágio em cascata na mesma virada.")

	print("DEBUFF_MANAGER_TEST_OK" if failures == 0 else "DEBUFF_MANAGER_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
