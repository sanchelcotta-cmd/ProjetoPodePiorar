class_name CraftAvailability
extends RefCounted

## Verde-amarelo: o próprio jogável já pode fabricar. Branco: o grupo tem
## ingredientes suficientes, mas precisa reuni-los no mesmo inventário.
enum Status { NONE, GROUP_READY, ACTOR_READY }


static func options_for(actor: EntityState, inventory: InventoryManager,
		exploration: ExplorationManager = null) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if actor == null or inventory == null or actor.current_health <= 0:
		return options
	for option in inventory.get_craftable_options(actor, 3):
		var record := option.duplicate()
		record["required_copies"] = 3
		record["eva_grant"] = null
		options.append(record)
	# A ativa da Professora só contempla peças que ELA carrega/usa e apenas
	# quando é possível ativá-la agora. Se já há três cópias, o craft normal
	# preserva o uso diário; a ativa continua acessível pelo botão próprio.
	if exploration != null and exploration.player_skill_manager != null \
			and exploration.player_skill_manager.skill_manager != null \
			and exploration.current_actor == actor:
		for grant in exploration.player_skill_manager.skill_manager.get_active_grants(actor):
			if grant == null or not grant.skill is ActiveSkillData \
					or (grant.skill as ActiveSkillData).id != &"playable_active_005":
				continue
			for option in exploration.player_skill_manager.get_craft_options(
					actor, grant, exploration):
				var already := false
				for existing in options:
					if (existing["ingredient"] as ItemData).id == \
							(option["ingredient"] as ItemData).id:
						already = true
						break
				if not already:
					var record := option.duplicate()
					record["required_copies"] = 2
					record["eva_grant"] = grant
					options.append(record)
	return options


static func status_for(actor: EntityState, item: ItemData,
		campaign: CampaignState, inventory: InventoryManager,
		exploration: ExplorationManager = null) -> Status:
	if actor == null or item == null or campaign == null or inventory == null \
			or item.id == &"" or not _has_available_result(item, campaign):
		return Status.NONE
	for option in options_for(actor, inventory, exploration):
		if (option["ingredient"] as ItemData).id == item.id:
			return Status.ACTOR_READY
	var total := 0
	for member in campaign.active_entity_states:
		total += _count_owned(member, item.id)
	for companion in campaign.companion_states:
		total += _count_owned(companion, item.id)
	return Status.GROUP_READY if total >= 3 else Status.NONE


static func _has_available_result(item: ItemData,
		campaign: CampaignState) -> bool:
	for result in item.craft_result:
		if result != null and result.rarity == ItemData.Rarity.EPIC \
				and (not result.cannot_craft_after_consumed \
				or not campaign.consumed_uncraftable_item_ids.has(result.id)):
			return true
	return false


static func _count_owned(actor: EntityState, item_id: StringName) -> int:
	if actor == null or actor.current_health <= 0:
		return 0
	var count := 0
	for collection in [actor.inventory_items, actor.equipped_weapons,
			actor.equipped_armors, actor.equipped_accessories]:
		for entry in collection:
			if entry != null and entry.data != null and entry.data.id == item_id:
				count += 1
	return count
