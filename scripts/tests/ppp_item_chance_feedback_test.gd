extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var campaign := CampaignState.new()
	var actor := EntityState.from_playable_selection(
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		&"Playable_1", Vector2i.ZERO)
	campaign.active_entity_states.append(actor)
	var skills := SkillManager.new()
	root.add_child(skills)
	var inventory := InventoryManager.new()
	var feijoada := load("res://resources/itens/consumables/feijoada_completa.tres") as ItemData
	actor.current_health = actor.max_health - 16
	var first_stamina := actor.max_stamina
	campaign.world_rng.seed = _seed_for_chance(0.3, false)
	var failed_copy := InventoryItemState.new(feijoada)
	actor.inventory_items.append(failed_copy)
	var failed := inventory.use_consumable(actor, failed_copy, skills, campaign)
	_check(failed.get("success", false) and failed.get("chance_results", []).is_empty()
		and actor.max_stamina == first_stamina,
		"Feijoada sem penalidade não abre aviso de falha.")
	campaign.world_rng.seed = _seed_for_chance(0.3, true)
	var applied_copy := InventoryItemState.new(feijoada)
	actor.inventory_items.append(applied_copy)
	var applied := inventory.use_consumable(actor, applied_copy, skills, campaign)
	var lines: Array = applied.get("chance_results", [])
	_check(applied.get("success", false) and lines.size() == 1
		and str(lines[0]).contains("Algo não caiu bem")
		and str(lines[0]).contains("Estamina")
		and str(lines[0]).contains("2 turnos")
		and actor.max_stamina == first_stamina - 2,
		"Feijoada aplicada explica a perda e a duração.")
	var positive := ItemData.new()
	positive.id = &"test_positive_chance"
	positive.display_name = "Teste positivo"
	positive.item_type = ItemData.ItemType.CONSUMABLE
	var effect := SkillEffectData.new()
	effect.effect_type = SkillEffectData.EffectType.MODIFY_ATTRIBUTE
	effect.attribute_id = &"attack"
	effect.amount = 2
	effect.activation_chance = 0.5
	positive.use_effects.append(effect)
	campaign.world_rng.seed = _seed_for_chance(0.5, false)
	var positive_fail := InventoryItemState.new(positive)
	actor.inventory_items.append(positive_fail)
	var failed_positive := inventory.use_consumable(actor, positive_fail, skills, campaign)
	_check(failed_positive.get("chance_results", []) == ["Não foi dessa vez."],
		"Falha de chance positiva informa a tentativa.")
	campaign.world_rng.seed = _seed_for_chance(0.5, true)
	var positive_success := InventoryItemState.new(positive)
	actor.inventory_items.append(positive_success)
	var succeeded_positive := inventory.use_consumable(actor, positive_success, skills, campaign)
	_check(str(succeeded_positive.get("chance_results", [""])[0]).contains("Ataque aumentado em 2"),
		"Sucesso de chance positiva descreve o bônus aplicado.")
	var fruit := load("res://resources/itens/consumables/frutinha_magica.tres") as ItemData
	campaign.world_rng.seed = _seed_for_choice(2)
	var sour_fruit := InventoryItemState.new(fruit)
	actor.inventory_items.append(sour_fruit)
	var sour_result := inventory.use_consumable(actor, sour_fruit, skills, campaign)
	_check(str(sour_result.get("chance_results", [""])[0]).contains("Algo não caiu bem")
		and str(sour_result.get("chance_results", [""])[0]).contains("Ataque"),
		"Resultado negativo da Frutinha Mágica também é avisado.")
	campaign.world_rng.seed = _seed_for_choice(1)
	var sweet_fruit := InventoryItemState.new(fruit)
	actor.inventory_items.append(sweet_fruit)
	var sweet_result := inventory.use_consumable(actor, sweet_fruit, skills, campaign)
	_check(str(sweet_result.get("chance_results", [""])[0]).contains("Ataque aumentado"),
		"Resultado positivo da Frutinha Mágica informa o bônus.")
	var popup := load("res://scripts/ui/item_chance_result_popup.gd").new() as Control
	root.add_child(popup)
	popup.call("show_message", str(sour_result.get("chance_results", [""])[0]))
	var box := popup.get_node("CenterContainer/MessageBox") as PanelContainer
	var ok := popup.get_node("CenterContainer/MessageBox/MarginContainer/VBoxContainer/OK") as Button
	var border := box.get_theme_stylebox("panel") as StyleBoxFlat
	_check(popup.visible and ok.text == "OK" and border.border_color == Color(0.94, 0.97, 0.98)
		and border.border_width_left == 1,
		"Aviso possui uma única confirmação e margem simples branca.")
	print("PPP_ITEM_CHANCE_FEEDBACK_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _seed_for_chance(chance: float, should_apply: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 1000):
		rng.seed = seed_value
		if (rng.randf() < chance) == should_apply:
			return seed_value
	return 1


func _seed_for_choice(choice: int) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 1000):
		rng.seed = seed_value
		if rng.randi_range(1, 2) == choice:
			return seed_value
	return 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
