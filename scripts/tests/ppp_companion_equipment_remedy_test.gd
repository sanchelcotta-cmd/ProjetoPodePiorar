extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var skills := scene.get_node("SkillManager") as SkillManager
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
	]
	check(game.start_new_game(choices), "Grupo jogável criado.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Mapa disponível para mostrar pet.")
	var campaign := game.campaign
	var donor := campaign.active_entity_states[0]
	var inventory := skills.inventory_manager
	var equipment := EquipmentManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var professor := load("res://resources/entities/entities_playable/professora.tres") as EntityData
	var human := EntityState.from_playable_selection(professor, &"AllyProfessor",
		EntityState.UNPLACED)
	check(campaign.register_companion(donor, human, rng, skills),
		"Recrutamento de aliada humana.")
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		var equipped := human.primary_equipped(slot)
		check(equipped != null and equipped.data.rarity == ItemData.Rarity.COMMON,
			"Aliada começa com %s comum equipado." % slot)
	check(human.inventory_items.is_empty() and human.base_inventory_capacity == 0,
		"Aliada humana não carrega inventário.")
	var initial_weapon := human.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	if initial_weapon != null and professor.maestrias != [EntityData.Mastery.NONE]:
		check(initial_weapon.data.mastery_granted in professor.maestrias,
			"Arma inicial corresponde à Maestria da aliada.")
	# Cada peça épica é avaliada separadamente. Os três têm arma e armadura
	# épicas, mas não acessório épico.
	for playable in campaign.active_entity_states:
		for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR]:
			var candidates := inventory.get_equipment_by_rarity(ItemData.Rarity.EPIC, slot)
			if slot == ItemData.EquipmentSlot.WEAPON \
					and playable.data.maestrias != [EntityData.Mastery.NONE]:
				candidates = candidates.filter(func(item: ItemData) -> bool:
					return item.mastery_granted in playable.data.maestrias)
			check(not candidates.is_empty(), "Há equipamento Épico da Maestria.")
			if not candidates.is_empty():
				var equipped_array := playable.equipped_in_slot(slot)
				equipped_array.clear()
				equipped_array.append(InventoryItemState.new(candidates[0]))
	var student := load("res://resources/entities/entities_playable/universitario.tres") as EntityData
	var second_human := EntityState.from_playable_selection(student, &"AllyStudent",
		EntityState.UNPLACED)
	check(campaign.register_companion(donor, second_human, rng, skills),
		"Segundo aliado recrutado após três armas e armaduras Épicas.")
	check(second_human.primary_equipped(ItemData.EquipmentSlot.WEAPON).data.rarity \
		== ItemData.Rarity.EPIC and
		second_human.primary_equipped(ItemData.EquipmentSlot.ARMOR).data.rarity \
		== ItemData.Rarity.EPIC and
		second_human.primary_equipped(ItemData.EquipmentSlot.ACCESSORY).data.rarity \
		== ItemData.Rarity.COMMON,
		"Só os tipos universalmente Épicos são espelhados no novo aliado.")
	# Com 12/12, a peça transferida abre a vaga exata para a antiga voltar.
	donor.inventory_items.clear()
	var replacement_data := inventory.get_equipment_by_rarity(
		ItemData.Rarity.COMMON, ItemData.EquipmentSlot.WEAPON)[0]
	var replacement := InventoryItemState.new(replacement_data)
	donor.inventory_items.append(replacement)
	var filler := load("res://resources/itens/consumables/bolinho_de_chuva.tres") as ItemData
	while inventory.can_receive(donor, filler):
		inventory.add_item(donor, filler)
	var before_count := donor.inventory_items.size()
	var old_weapon := human.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	var group := (scene.get_node("CampaignTopBar") as CampaignTopBar).group_inventory
	group.open()
	group.item_menu.open_for(donor, replacement, false,
		Rect2(Vector2(200, 200), Vector2(40, 40)), campaign, skills)
	group.item_menu._show_recipients()
	var ally_transfer: Button
	for child in group.item_menu.rows.get_children():
		if child is Button and (child as Button).text.begins_with(human.data.display_name):
			ally_transfer = child as Button
			break
	check(ally_transfer != null and not ally_transfer.disabled,
		"Transferir para lista aliada humana mesmo com slot já ocupado.")
	if ally_transfer != null:
		ally_transfer.pressed.emit()
	check(human.primary_equipped(ItemData.EquipmentSlot.WEAPON) == replacement
		and old_weapon in donor.inventory_items and replacement not in donor.inventory_items
		and donor.inventory_items.size() == before_count and human.inventory_items.is_empty(),
		"Peça antiga retorna à vaga liberada no inventário do doador.")
	check(not inventory.can_receive(human, filler),
		"Mesmo que um acessório aumente capacidade, aliado não pode carregar itens.")
	var cat_data := load("res://resources/entities/entities_general/companions/gatinho_vira_lata.tres") as EntityData
	var cat := EntityState.from_playable_selection(cat_data, &"CatRemedy",
		EntityState.UNPLACED)
	check(campaign.register_companion(donor, cat, rng, skills), "Pet recrutado.")
	check(cat.primary_equipped(ItemData.EquipmentSlot.WEAPON) == null \
		and cat.primary_equipped(ItemData.EquipmentSlot.ARMOR) == null \
		and cat.primary_equipped(ItemData.EquipmentSlot.ACCESSORY) == null,
		"Pet não recebe equipamento ao ser recrutado.")
	var pet_equipment_probe := InventoryItemState.new(replacement_data)
	cat.inventory_items.append(pet_equipment_probe)
	check(not equipment.equip(cat, pet_equipment_probe, skills, campaign) \
		and not equipment.can_equip_companion_from_playable(donor, cat,
			old_weapon, skills, campaign),
		"Pet não pode equipar nem por operação interna nem por transferência.")
	cat.inventory_items.erase(pet_equipment_probe)
	var cultist_data := load("res://resources/entities/entities_general/cultista_encapuzado.tres") as EntityData
	var tamed_humanoid := EntityState.from_encounter_member(cultist_data,
		&"TamedEquipmentTest", 1, EntityState.UNPLACED)
	check(campaign.register_companion(donor, tamed_humanoid, rng, skills),
		"Inimigo humanoide adestrado entra como aliado.")
	var humanoid_probe := InventoryItemState.new(replacement_data)
	tamed_humanoid.inventory_items.append(humanoid_probe)
	check(tamed_humanoid.equipped_weapons.is_empty() \
		and tamed_humanoid.equipped_armors.is_empty() \
		and tamed_humanoid.equipped_accessories.is_empty() \
		and not equipment.equip(tamed_humanoid, humanoid_probe, skills, campaign) \
		and not equipment.can_equip_companion_from_playable(donor,
			tamed_humanoid, old_weapon, skills, campaign),
		"Inimigo adestrado, mesmo humanoide, não recebe nem equipa itens.")
	tamed_humanoid.inventory_items.erase(humanoid_probe)
	group.item_menu.open_for(donor, old_weapon, false,
		Rect2(Vector2(200, 200), Vector2(40, 40)), campaign, skills)
	group.item_menu._show_recipients()
	var tamed_is_equip_target := false
	for child in group.item_menu.rows.get_children():
		if child is Button and (child as Button).text.contains(cultist_data.display_name):
			tamed_is_equip_target = true
	check(not tamed_is_equip_target,
		"Inimigo adestrado não aparece como destino de equipamento na interface.")
	check(skills.debuff_manager.apply_by_id(cat, &"db_00003").get("success", false),
		"Pet pode receber Doença Leve.")
	await process_frame
	var pet_visual := (scene.get_node("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView).visuals_by_id.get(cat.instance_id) as CompanionActorVisual
	check(pet_visual != null and pet_visual.debuff_marker.call("has_debuffs"),
		"Ícone de debuff aparece acima da cabeça do pet.")
	var remedy := ItemData.new()
	remedy.item_type = ItemData.ItemType.CONSUMABLE
	remedy.display_name = "Remédio de teste"
	var removal := SkillEffectData.new()
	removal.effect_type = SkillEffectData.EffectType.REMOVE_DEBUFF
	removal.debuff_id = &"db_00003"
	removal.percent = 0.01
	removal.activation_chance = 0.01
	remedy.use_effects.append(removal)
	var dose := InventoryItemState.new(remedy)
	donor.inventory_items[1] = dose
	check(inventory.is_ally_debuff_remedy(remedy)
		and not inventory.is_ally_debuff_remedy(filler),
		"Somente item exclusivo de debuff oferece Dar para.")
	group.item_menu.open_for(donor, dose, false,
		Rect2(Vector2(200, 200), Vector2(40, 40)), campaign, skills)
	var give_button: Button
	for child in group.item_menu.rows.get_children():
		if child is Button and (child as Button).text == "Dar para":
			give_button = child as Button
	check(give_button != null, "Remédio puro mostra Dar para.")
	if give_button != null:
		give_button.pressed.emit()
	var cat_button: Button
	for child in group.item_menu.rows.get_children():
		if child is Button and (child as Button).text == cat.data.display_name:
			cat_button = child as Button
	check(cat_button != null and not cat_button.disabled,
		"Pet com Doença pode ser escolhido para receber o remédio.")
	if cat_button != null:
		cat_button.pressed.emit()
	check(skills.debuff_manager.get_debuff(cat, &"db_00003") == null
		and dose not in donor.inventory_items,
		"Remédio dado ao pet consome a cópia e remove debuff com 100% de chance.")
	var food_copy := InventoryItemState.new(filler)
	donor.inventory_items.append(food_copy)
	check(not inventory.use_consumable(donor, food_copy, skills, campaign,
		null, cat).get("success", false) and food_copy in donor.inventory_items,
		"Alimento com cura secundária não pode ser dado ao aliado.")
	print("COMPANION_EQUIPMENT_REMEDY_TEST_OK" if failures == 0 else
		"COMPANION_EQUIPMENT_REMEDY_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
