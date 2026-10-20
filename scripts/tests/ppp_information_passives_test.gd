extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "Campanha inicia.")
	var journalist := campaign.active_entity_states[0]
	var manager := SkillManager.new()
	root.add_child(manager)
	check(journalist.has_mastery(EntityData.Mastery.RANGED), "Jornalista conhece Distância.")
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 0,
		"Maestria presente no cadastro começa em nível zero.")
	var base_hp := journalist.max_health
	var base_attack := journalist.attack
	_set_information_count(campaign, 1)
	manager.on_information_obtained(campaign)
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 2,
		"Primeira Informação concede +2.")
	_set_information_count(campaign, 3)
	manager.on_information_obtained(campaign)
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 3,
		"No total 3, bônus vira +3.")
	_set_information_count(campaign, 6)
	manager.on_information_obtained(campaign)
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 4,
		"No total 6, bônus vira +4.")
	manager.on_information_obtained(campaign)
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 4,
		"Recalcular sem nova Informação não duplica.")
	_set_information_count(campaign, 12)
	manager.on_information_obtained(campaign)
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 6,
		"No total 12, Farol chega ao teto +6.")
	_set_information_count(campaign, 20)
	manager.on_information_obtained(campaign)
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 6,
		"Informações além do teto não aumentam Farol.")
	var information_power := load("res://resources/skills/passives/permanent_effects/informacao_e_poder.tres") as PassiveSkillData
	check(manager.grant_skill(journalist, information_power, &"event", &"one", campaign) != null,
		"Evento concede passiva pela mesma estrutura.")
	check(journalist.max_health == base_hp + 40 and journalist.attack == base_attack + 40,
		"Passiva concedida após 20 Informações recalcula imediatamente.")
	check(manager.grant_skill(journalist, information_power, &"item", &"two", campaign) != null,
		"Segunda origem independente pode conceder a mesma passiva.")
	check(journalist.max_health == base_hp + 80 and journalist.attack == base_attack + 80,
		"Duas origens acumulam.")
	check(manager.remove_source(journalist, &"event", &"one") == 1,
		"Origem de Evento pode ser removida.")
	check(journalist.max_health == base_hp + 40 and journalist.attack == base_attack + 40,
		"Remover uma origem deixa a outra intacta.")
	check(manager.remove_source(journalist, &"item", &"two") == 1,
		"Origem de Item pode ser removida.")
	check(journalist.max_health == base_hp and journalist.attack == base_attack,
		"Remover todas as origens restaura os atributos-base.")

	print("INFORMATION_PASSIVES_TEST_OK" if failures == 0 else "INFORMATION_PASSIVES_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _set_information_count(campaign: CampaignState, amount: int) -> void:
	campaign.obtained_information_ids.clear()
	for index in amount:
		campaign.obtained_information_ids[StringName("info_%d" % index)] = true


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
