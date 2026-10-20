extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "Campanha inicia.")
	var manager := SkillManager.new()
	root.add_child(manager)
	var target := campaign.active_entity_states[0]
	var protection := load("res://resources/skills/passives/protecao_50.tres") as PassiveSkillData
	check(manager.grant_skill(target, protection, &"item", &"armor_a") != null,
		"Primeira fonte de Proteção concedida.")
	check(manager.grant_skill(target, protection, &"item", &"armor_b") != null,
		"Segunda fonte idêntica é independente.")
	var first_hit := manager.apply_incoming_damage(target, 10, campaign)
	check(first_hit.get("damage") == 2 and first_hit.get("passives", []).size() == 2,
		"10 com 50% e 50% vira 2: cada fonte age em sequência, arredondando no fim.")
	var tiny_hit := manager.apply_incoming_damage(target, 1, campaign)
	check(tiny_hit.get("damage") == 1, "Dano positivo sempre causa pelo menos 1.")
	manager.remove_source(target, &"item", &"armor_a")
	var one_source := manager.apply_incoming_damage(target, 10, campaign)
	check(one_source.get("damage") == 5, "Remover uma fonte deixa só uma Proteção 50%.")
	manager.remove_source(target, &"item", &"armor_b")
	var no_source := manager.apply_incoming_damage(target, 3, campaign)
	check(no_source.get("damage") == 3, "Remover ambas restaura o dano bruto.")

	var doll := load("res://resources/skills/passives/curses/bonequinha_de_pano.tres") as PassiveSkillData
	check(manager.grant_skill(target, doll, &"item", &"doll") != null,
		"Bonequinha de Pano pode ser concedida.")
	for member in campaign.active_entity_states:
		member.current_health = member.max_health
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 12345
	var actual_rng := RandomNumberGenerator.new()
	actual_rng.seed = 12345
	var expected: Array[int] = []
	for member in campaign.active_entity_states:
		expected.append(expected_rng.randi_range(1, 6) + expected_rng.randi_range(1, 6))
	var day_results := manager.on_day_started(campaign, actual_rng)
	check(day_results.size() == 1, "Bonequinha dispara uma vez na virada do Dia.")
	for index in campaign.active_entity_states.size():
		var member := campaign.active_entity_states[index]
		check(member.current_health == member.max_health - expected[index],
			"Cada integrante recebe sua própria rolagem 2d6.")
	var hp_after_first: Array[int] = []
	for member in campaign.active_entity_states:
		hp_after_first.append(member.current_health)
	check(manager.on_day_started(campaign, actual_rng).is_empty(),
		"Repetir a chamada no mesmo Dia não aplica dano novamente.")
	for index in campaign.active_entity_states.size():
		check(campaign.active_entity_states[index].current_health == hp_after_first[index],
			"Vida permanece igual após chamada duplicada.")
	campaign.day += 1
	check(manager.on_day_started(campaign, actual_rng).size() == 1,
		"Virada seguinte volta a disparar a Bonequinha.")

	print("DAMAGE_PASSIVES_TEST_OK" if failures == 0 else "DAMAGE_PASSIVES_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
