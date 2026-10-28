extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/universitario.tres"),
	]
	for mode in [EventCampaignEligibility.Mode.SHORT,
			EventCampaignEligibility.Mode.MEDIUM,
			EventCampaignEligibility.Mode.COMPLETE]:
		var endings: Array[StringName] = []
		match mode:
			EventCampaignEligibility.Mode.SHORT:
				endings = [&"khainokata"]
			EventCampaignEligibility.Mode.MEDIUM:
				endings = [&"khainokata", &"orchestra"]
		for seed_value in [3, 13, 29, 41]:
			var campaign := CampaignState.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			_check(campaign.start_new_game(selected, 12, rng, mode, endings),
				"Campanha inicia no modo %d." % mode)
			for actor in campaign.active_entity_states:
				var equipment: Array[InventoryItemState] = []
				equipment.append_array(actor.equipped_weapons)
				equipment.append_array(actor.equipped_armors)
				equipment.append_array(actor.equipped_accessories)
				var consumables := actor.inventory_items.size()
				var expected_total := 3 if mode == EventCampaignEligibility.Mode.COMPLETE else 4
				_check(equipment.size() + consumables == expected_total
					and consumables >= 1 and consumables <= 2,
					"%s recebe %d itens e 1–2 consumíveis no modo %d." % [
						actor.visible_name(), expected_total, mode])
				var used_slots: Dictionary = {}
				for copy in equipment:
					_check(copy.data != null and copy.data.rarity == ItemData.Rarity.COMMON
						and not used_slots.has(copy.data.equipment_slot),
						"Equipáveis iniciais são comuns e de slots distintos.")
					used_slots[copy.data.equipment_slot] = true
				for copy in actor.inventory_items:
					_check(copy.data != null and copy.data.item_type == ItemData.ItemType.CONSUMABLE,
						"Somente consumíveis ficam carregados no kit inicial.")
	print("PPP_STARTING_ITEMS_BY_MODE_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
