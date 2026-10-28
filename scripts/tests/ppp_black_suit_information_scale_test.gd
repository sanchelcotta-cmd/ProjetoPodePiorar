extends SceneTree

## Escala única do Homem de Preto: 1/2 pistas = 2; depois conta normal.
var failures := 0


func _initialize() -> void:
	var data := load("res://resources/entities/entities_general/homem_de_preto.tres") \
		as EntityData
	var passive := data.skill_passivas[1] as PassiveSkillData
	var executor := SkillEffectExecutor.new()
	var campaign := CampaignState.new()
	var enemy := EntityState.from_encounter_member(data, &"scale_test", 1,
		Vector2i(2, 2))
	var samples := [
		{"count": 1, "district": &"suburbio", "expected": 2},
		{"count": 2, "district": &"suburbio", "expected": 2},
		{"count": 3, "district": &"suburbio", "expected": 3},
		{"count": 6, "district": &"suburbio", "expected": 5},
		{"count": 11, "district": &"baixo_centro", "expected": 10},
		{"count": 16, "district": &"centro", "expected": 15}]
	for sample in samples:
		campaign.district = sample["district"]
		campaign.obtained_information_ids.clear()
		for index in sample["count"]:
			campaign.obtained_information_ids[StringName("test_%d" % index)] = true
		for effect in passive.effects:
			var result := executor.execute_passive(effect, {
				"actor": enemy, "campaign": campaign,
				"encounter_opening": true, "mode": HexGrid.PPPMapMode.COMBAT})
			check(result.get("success", false), "Efeito passivo executa.")
		check(enemy.attack == sample["expected"] \
			and enemy.max_stamina == sample["expected"],
			"Escala correta para %d pistas no distrito %s." % [
				sample["count"], sample["district"]])
	campaign.obtained_information_ids.clear()
	campaign.district = &"suburbio"
	var owner := EntityState.from_playable_selection(load(
		"res://resources/entities/entities_playable/jornalista.tres"),
		&"scale_owner", Vector2i(3, 2))
	campaign.active_entity_states.append(owner)
	var ally := EntityState.from_encounter_member(data, &"scale_ally", 1,
		EntityState.UNPLACED)
	check(campaign.register_companion(owner, ally) and ally.attack == 2 \
		and ally.max_stamina == 2,
		"Aliado vindo de outra fonte sem pistas usa o primeiro patamar jogável.")
	print("PPP black suit information scale: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
