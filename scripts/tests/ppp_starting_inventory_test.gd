extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var catalog := CampaignState.new().get_playable_catalog()
	_check(catalog.size() == 7, "Catálogo dos sete jogáveis disponível.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 71042
	for first in catalog.size():
		var selected: Array[EntityData] = []
		for offset in 3:
			selected.append(catalog[(first + offset) % catalog.size()])
		var campaign := CampaignState.new()
		_check(campaign.start_new_game(selected, 12, rng), "Campanha inicia com trio válido.")
		for actor in campaign.active_entity_states:
			_check(actor.inventory_items.size() in [1, 2],
				"%s carrega um ou dois consumíveis iniciais." % actor.data.display_name)
			var equipment_count := 0
			var consumable_count := 0
			var used_slots: Dictionary = {}
			var starting_items: Array[InventoryItemState] = actor.inventory_items.duplicate()
			for slot in [ItemData.EquipmentSlot.WEAPON,
					ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
				starting_items.append_array(actor.equipped_in_slot(slot))
			for entry in starting_items:
				var item := entry.data
				_check(item.rarity == ItemData.Rarity.COMMON,
					"Item inicial sempre é Comum.")
				_check(item.item_type != ItemData.ItemType.CURSED \
						and &"cursed" not in item.tags,
						"Item inicial não é amaldiçoado.")
				if item.item_type == ItemData.ItemType.EQUIPMENT:
					equipment_count += 1
					_check(not used_slots.has(item.equipment_slot),
						"Não há dois equipáveis iniciais do mesmo tipo.")
					used_slots[item.equipment_slot] = true
					_check(entry not in actor.inventory_items,
						"O equipável inicial está equipado, sem ocupar a mochila.")
					if item.equipment_slot == ItemData.EquipmentSlot.WEAPON \
							and not actor.data.maestrias.is_empty() \
							and actor.data.maestrias != [EntityData.Mastery.NONE]:
							_check(item.mastery_granted in actor.data.maestrias,
								"Arma inicial respeita a Maestria própria.")
				elif item.item_type == ItemData.ItemType.CONSUMABLE:
					consumable_count += 1
			_check(equipment_count + consumable_count == 3
				and consumable_count in [1, 2],
				"%s recebe três itens na Completa, com 1–2 consumíveis." % actor.data.display_name)
	for mode in [EventCampaignEligibility.Mode.SHORT,
			EventCampaignEligibility.Mode.MEDIUM,
			EventCampaignEligibility.Mode.COMPLETE]:
		for first in catalog.size():
			var selected: Array[EntityData] = []
			for offset in 3:
				selected.append(catalog[(first + offset) % catalog.size()])
			var campaign := CampaignState.new()
			_check(campaign.start_new_game(selected, 12, rng, mode, [],
				GameDifficulty.Mode.CHAOTIC),
				"Caótico inicia campanha de tamanho %d." % mode)
			for actor in campaign.active_entity_states:
				var equipment_count := 0
				var consumable_count := 0
				for entry in actor.inventory_items:
					if entry.data.item_type == ItemData.ItemType.CONSUMABLE:
						consumable_count += 1
				for slot in [ItemData.EquipmentSlot.WEAPON,
						ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
					for entry in actor.equipped_in_slot(slot):
						if entry.data.item_type == ItemData.ItemType.EQUIPMENT:
							equipment_count += 1
				_check(consumable_count == 1 and equipment_count == 1,
					"%s recebe exatamente 2 itens (1 consumível e 1 equipável) no Caótico %d." % [
						actor.data.display_name, mode])
	print("STARTING_INVENTORY_TEST_OK" if failures == 0 else \
		"STARTING_INVENTORY_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
