class_name EventExecutor
extends Node

## Lê EventData → Outcome → Effects. Só conclui o bloco depois que o jogador
## vê o resultado e confirma; efeitos ainda sem executor permanecem pendentes.
## Nunca altera os .tres: todas as mudanças acontecem no estado da campanha.

signal result_ready(context: Dictionary, result: Dictionary)
signal outcome_prepared(context: Dictionary, preview: Dictionary)
signal resolution_blocked(context: Dictionary, reason: String)

@export var gerencia: GerenciaJogo
@export var block_manager: BlockManager
@export var skill_manager: SkillManager
@export var catastrophe_manager: CatastropheManager
@export var exploration: ExplorationManager

var _rng := RandomNumberGenerator.new()
var _prepared: Dictionary = {}
var _pending_result: Dictionary = {}
var _shared_rolls: Dictionary = {}
var _recent_dice_results: Array[int] = []
var _event_combat_waiting: Dictionary = {}
var _chained_event_parent: Dictionary = {}
var _random_target_groups: Dictionary = {}
var _equipment_manager := EquipmentManager.new()
var _inventory_manager := InventoryManager.new()
var _narrative_key := ""
var _narrative_bindings: Dictionary = {}
var _queued_world_transition: Dictionary = {}
var _queued_day_advance := 0


## Uma ativação conserva os sorteios da narrativa até a aplicação do Outcome.
## Assim o nome anunciado é o mesmo da entidade que entra no grupo.
func resolve_narrative(event: EventData, story: String, context: Dictionary) -> String:
	if event == null or story.is_empty():
		return story
	var bindings := _bindings_for(event, context)
	var actor := context.get("actor") as EntityState
	if actor != null and actor.data != null:
		story = story.replace("[Personagem_ativo]", actor.visible_name())
		story = story.replace("[personagem_ativo]", actor.visible_name())
	if story.contains("[fala_miss_fortuna]"):
		if not bindings.has("miss_fortuna_line"):
			var lines := [
				"— Pode escolher. Hoje a casa está generosa!",
				"— Olhar é de graça. Levar também.",
			]
			match event.id:
				&"ev_00046": lines.append("— Leva esse, combina demais com você!")
				&"ev_00047": lines.append("— Leva, tá de graça! Se quebrar, não aceito trocas.")
				&"ev_00048": lines.append("— Esse modelo saiu muito bem na última dimensão.")
			bindings["miss_fortuna_line"] = lines[_rng.randi_range(0, lines.size() - 1)]
		story = story.replace("[fala_miss_fortuna]", str(bindings["miss_fortuna_line"]))
	if story.contains("[um{a} Personagem]"):
		var ally := _chosen_playable_ally(bindings)
		if ally != null:
			story = story.replace("[um{a} Personagem]", ally.display_name)
	if story.contains("[criatura_sorteada]"):
		var creature := _chosen_district_enemy(bindings)
		if creature != null:
			story = story.replace("[criatura_sorteada]", creature.display_name)
	if event.id == &"ev_00016" and story.contains("[resposta_artesao]"):
		var item := context.get("decision", {}).get("selected_item") as InventoryItemState
		var reply := ""
		if item != null and item.data != null:
			if item.data.equipment_slot == ItemData.EquipmentSlot.ARMOR:
				reply = "“... Meio estranho martelar uma roupa. Mas ela parece... melhor.”"
			else:
				reply = "“Ela parece... melhor.”"
		story = story.replace("[resposta_artesao]", reply)
	return story


func _bindings_for(event: EventData, context: Dictionary) -> Dictionary:
	var actor := context.get("actor") as EntityState
	var actor_id := actor.get_instance_id() if actor != null else 0
	var key := "%s:%d:%s" % [event.id, actor_id, str(context.get("coord", Vector2i(-1, -1)))]
	if key != _narrative_key:
		_narrative_key = key
		_narrative_bindings = {}
	return _narrative_bindings


func _chosen_playable_ally(bindings: Dictionary) -> EntityData:
	if bindings.has("playable_ally"):
		return bindings["playable_ally"] as EntityData
	if gerencia == null or gerencia.campaign == null:
		return null
	var choices := gerencia.campaign.get_unselected_playable_allies()
	if choices.is_empty():
		return null
	var chosen := choices[_rng.randi_range(0, choices.size() - 1)]
	bindings["playable_ally"] = chosen
	return chosen


func _chosen_district_enemy(bindings: Dictionary) -> EntityData:
	if bindings.has("district_enemy"):
		return bindings["district_enemy"] as EntityData
	if gerencia == null or gerencia.campaign == null:
		return null
	var campaign := gerencia.campaign
	var candidates: Array[EntityData] = []
	for filename in DirAccess.get_files_at("res://resources/encounters"):
		if not filename.ends_with(".tres"):
			continue
		var encounter := load("res://resources/encounters".path_join(filename)) as EncounterData
		if encounter == null or not encounter.has_valid_composition() \
				or not encounter.can_appear_in(campaign.district, campaign.round_period == 2):
			continue
		for member in encounter.members:
			if member != null and member.entity != null and member.entity not in candidates:
				candidates.append(member.entity)
	if candidates.is_empty():
		return null
	var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]
	bindings["district_enemy"] = chosen
	return chosen


func _ready() -> void:
	_rng.randomize()
	if block_manager != null:
		block_manager.event_resolution_requested.connect(_on_event_requested)
		block_manager.block_finished.connect(_on_block_finished)
		block_manager.combat_returned_to_event.connect(_on_combat_returned_to_event)


func acknowledge_result() -> bool:
	if _pending_result.is_empty() or block_manager == null:
		return false
	var details := _pending_result.duplicate(true)
	if not _chained_event_parent.is_empty():
		var parent := _chained_event_parent.duplicate(true)
		_chained_event_parent.clear()
		details = parent
		details["triggered_event_result"] = _pending_result.duplicate(true)
	var transition := _queued_world_transition.duplicate()
	if not transition.is_empty():
		details["deferred_world_transition"] = true
	# Não esvaziar o mesmo Dictionary enviado pelo sinal: outros ouvintes
	# (HUD, testes, registro) ainda precisam ler o Outcome completo.
	_pending_result = {}
	var finished := block_manager.finish_event_resolution(details)
	if finished and not transition.is_empty():
		_queued_world_transition.clear()
		finished = _perform_world_transition(transition)
	if finished and gerencia != null and gerencia.campaign != null:
		gerencia.campaign.finalize_dead_playables(skill_manager, _rng)
	return finished


func _eligible_event_items(effect: Event_EffectData) -> Array[ItemData]:
	var result: Array[ItemData] = []
	if effect == null:
		return result
	for path in _inventory_manager._item_paths(InventoryManager.ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"":
			continue
		if effect.excluded_item_category == Event_EffectData.ItemCategoryFilter.CURSED \
				and (item.item_type == ItemData.ItemType.CURSED or &"cursed" in item.tags):
			continue
		match effect.item_category_filter:
			Event_EffectData.ItemCategoryFilter.EQUIPMENT:
				if item.item_type != ItemData.ItemType.EQUIPMENT:
					continue
			Event_EffectData.ItemCategoryFilter.CONSUMABLE:
				if item.item_type != ItemData.ItemType.CONSUMABLE:
					continue
			Event_EffectData.ItemCategoryFilter.CURSED:
				if item.item_type != ItemData.ItemType.CURSED:
					continue
		if &"epica" in effect.tags_filter and item.rarity != ItemData.Rarity.EPIC:
			continue
		var matches := effect.tags_filter.is_empty()
		for tag in effect.tags_filter:
			if tag in item.tags:
				matches = true
		if matches:
			result.append(item)
	return result


## O Gênio escolhe entre as Passivas inatas dos jogáveis cadastrados, inclusive
## futuros personagens. Skills de itens, maldições e inimigos não entram.
func get_passive_choices(actor: EntityState) -> Array[PassiveSkillData]:
	var choices: Array[PassiveSkillData] = []
	if actor == null or gerencia == null or gerencia.campaign == null \
			or skill_manager == null:
		return choices
	var owned: Dictionary = {}
	for grant in skill_manager.get_passive_grants(actor):
		var existing := grant.skill as PassiveSkillData
		if existing != null:
			owned[existing.id] = true
	var seen: Dictionary = {}
	for playable in gerencia.campaign.get_playable_catalog():
		for passive in playable.skill_passivas:
			if passive == null or passive.id == &"" or owned.has(passive.id) \
					or seen.has(passive.id):
				continue
			seen[passive.id] = true
			choices.append(passive)
	choices.sort_custom(func(a: PassiveSkillData, b: PassiveSkillData) -> bool:
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0)
	return choices


## Evento 07. Planeja todas as substituições antes de tocar em qualquer cópia.
## Cópias equipadas preservam seu slot; só jogáveis carregam inventário.
## Maldições antigas entram na transformação, mas nunca no catálogo de saída.
func _apply_gnome_chaos(effect: Event_EffectData) -> Dictionary:
	var campaign := gerencia.campaign if gerencia != null else null
	if campaign == null or skill_manager == null:
		return {"success": false, "reason": "O grupo não está disponível."}
	var entries: Array[Dictionary] = []
	var owners: Array[EntityState] = []
	owners.append_array(campaign.active_entity_states)
	owners.append_array(campaign.companion_states)
	var had_epic := false
	for owner in owners:
		if owner == null or owner.current_health <= 0:
			continue
		for slot in [ItemData.EquipmentSlot.WEAPON,
				ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
			for entry in owner.equipped_in_slot(slot):
				if entry == null or entry.data == null:
					continue
				entries.append({"owner": owner, "entry": entry, "slot": slot})
				had_epic = had_epic or entry.data.rarity == ItemData.Rarity.EPIC
		for entry in owner.inventory_items:
			if entry == null or entry.data == null:
				continue
			entries.append({"owner": owner, "entry": entry, "slot": -1})
			had_epic = had_epic or entry.data.rarity == ItemData.Rarity.EPIC
	if entries.is_empty():
		return {"success": true, "effect": effect.effect_type,
			"transformed": 0, "had_epic": false, "returned_epic": false}
	var catalog: Array[ItemData] = []
	for path in _inventory_manager._item_paths(InventoryManager.ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"" or item.inventory_space < 1 \
				or item.item_type == ItemData.ItemType.CURSED \
				or &"cursed" in item.tags:
			continue
		if item.item_type == ItemData.ItemType.EQUIPMENT \
				and item.equipment_slot == ItemData.EquipmentSlot.NONE:
			continue
		catalog.append(item)
	if catalog.is_empty():
		return {"success": false, "reason": "Não há itens não amaldiçoados para o sorteio."}
	var plan: Array[Dictionary] = []
	var backpack_index := -1
	var backpack_owner: EntityState = null
	for index in entries.size():
		if int(entries[index]["slot"]) != ItemData.EquipmentSlot.ACCESSORY:
			continue
		var original := entries[index]["entry"] as InventoryItemState
		var owner := entries[index]["owner"] as EntityState
		if owner in campaign.active_entity_states and original.data != null \
				and _equipment_manager._capacity_bonus(original.data) > 0:
			backpack_index = index
			backpack_owner = owner
			break
	var backpack_destinations: Array[EntityState] = []
	if backpack_owner != null:
		for member in campaign.active_entity_states:
			if member != null and member.current_health > 0 \
					and member != backpack_owner \
					and skill_manager.can_equip_item(member,
						(entries[backpack_index]["entry"] as InventoryItemState).data):
				backpack_destinations.append(member)
		backpack_destinations.sort_custom(func(a: EntityState, b: EntityState) -> bool:
			return a.inventory_used_space() > b.inventory_used_space())
	for attempt in 100:
		plan.clear()
		# Primeiro tenta trocar tudo. Só depois preserva a mochila e a move
		# para outro jogável; mesmo nesse último caso não perde nenhuma cópia.
		var preserve_backpack := attempt >= 60 and not backpack_destinations.is_empty()
		var backpack_destination: EntityState = backpack_destinations[
			(attempt - 60) % backpack_destinations.size()] if preserve_backpack else null
		var displaced_accessory: InventoryItemState = backpack_destination.primary_equipped(
			ItemData.EquipmentSlot.ACCESSORY) if backpack_destination != null else null
		var forced_epic_index := -1
		if had_epic:
			var possible: Array[int] = []
			for index in entries.size():
				if preserve_backpack and index == backpack_index:
					if (entries[index]["entry"] as InventoryItemState).data.rarity \
							== ItemData.Rarity.EPIC:
						possible.append(index)
					continue
				var source: Dictionary = entries[index].duplicate()
				if preserve_backpack and source["entry"] == displaced_accessory:
					source["owner"] = backpack_owner
				if not _chaos_candidates(catalog, source, true).is_empty():
					possible.append(index)
			if possible.is_empty():
				return {"success": false, "reason": "Nenhum Épico pode retornar ao grupo."}
			forced_epic_index = backpack_index if preserve_backpack \
				and backpack_index in possible else possible[
				_rng.randi_range(0, possible.size() - 1)]
		var predicted_capacity: Dictionary = {}
		var failed := false
		# Primeiro os equipamentos: eles podem alterar a capacidade da mochila.
		for index in entries.size():
			var slot := int(entries[index]["slot"])
			if slot < 0:
				continue
			var owner := entries[index]["owner"] as EntityState
			var original := entries[index]["entry"] as InventoryItemState
			var destination := owner
			var replacement: ItemData = null
			if preserve_backpack and index == backpack_index:
				replacement = original.data
				destination = backpack_destination
			else:
				var source: Dictionary = entries[index].duplicate()
				if preserve_backpack and original == displaced_accessory:
					destination = backpack_owner
					source["owner"] = destination
				var options := _chaos_candidates(catalog, source,
					index == forced_epic_index)
				if preserve_backpack and original == displaced_accessory:
					options = options.filter(func(item: ItemData) -> bool:
						return skill_manager.can_equip_item(owner, item))
				if options.is_empty():
					failed = true
					break
				replacement = options[_rng.randi_range(0, options.size() - 1)]
			plan.append({"owner": owner, "entry": original, "item": replacement,
				"equipped": true, "destination": destination})
			predicted_capacity[owner] = int(predicted_capacity.get(owner,
				owner.inventory_capacity())) \
				- _equipment_manager._capacity_bonus(original.data)
			predicted_capacity[destination] = int(predicted_capacity.get(destination,
				destination.inventory_capacity())) \
				+ _equipment_manager._capacity_bonus(replacement)
		if failed:
			continue
		var carried_plan: Array[Dictionary] = []
		for index in entries.size():
			if int(entries[index]["slot"]) >= 0:
				continue
			var owner := entries[index]["owner"] as EntityState
			var options := _chaos_candidates(catalog, entries[index],
				index == forced_epic_index)
			if options.is_empty():
				failed = true
				break
			var replacement := options[_rng.randi_range(0, options.size() - 1)]
			carried_plan.append({"owner": owner, "entry": entries[index]["entry"],
				"item": replacement, "equipped": false})
		if failed or not _chaos_distribute_inventory(carried_plan,
				campaign.active_entity_states, predicted_capacity):
			continue
		plan.append_array(carried_plan)
		if not failed:
			break
	if plan.size() != entries.size():
		return {"success": false,
			"reason": "Não há uma troca que caiba nos inventários do grupo."}
	var transformed: Array[Dictionary] = []
	var returned_epic := false
	var backpack_change: Dictionary = {}
	var accessory_change: Dictionary = {}
	for change in plan:
		var owner := change["owner"] as EntityState
		var entry := change["entry"] as InventoryItemState
		var replacement := change["item"] as ItemData
		var old_name := entry.data.display_name
		if change["equipped"]:
			var relocated: bool = change.get("destination", owner) != owner
			if change.get("destination", owner) != owner and replacement == entry.data:
				backpack_change = change
			else:
				if relocated:
					accessory_change = change
				if not _equipment_manager.transform_equipped(owner, entry, replacement,
						skill_manager, campaign):
					return {"success": false,
						"reason": "Um equipamento sorteado não pôde ser transformado."}
		else:
			if entry.data.item_type == ItemData.ItemType.CURSED \
					or &"cursed" in entry.data.tags:
				for grant in owner.skill_grants.duplicate():
					if grant != null and grant.source_kind == &"item" \
							and grant.bound_source == entry.data:
						skill_manager.remove_source(owner, grant.source_kind, grant.source_id)
			entry.data = replacement
			entry.states.clear()
			entry.improvement_attack = 0
			entry.improvement_life = 0
			entry.improvement_stamina = 0
			entry.inventory_slot_index = -1
			var recipient := change.get("destination", owner) as EntityState
			if recipient != owner:
				owner.inventory_items.erase(entry)
				recipient.inventory_items.append(entry)
		transformed.append({"owner": owner.instance_id, "from": old_name,
			"to": replacement.display_name, "equipped": change["equipped"],
			"recipient": (change.get("destination", owner) as EntityState).instance_id})
		returned_epic = returned_epic or replacement.rarity == ItemData.Rarity.EPIC
	if not backpack_change.is_empty():
		var from_owner := backpack_change["owner"] as EntityState
		var to_owner := backpack_change["destination"] as EntityState
		var backpack := backpack_change["entry"] as InventoryItemState
		var other := accessory_change.get("entry") as InventoryItemState
		if not _equipment_manager.swap_equipped_accessories(from_owner, to_owner,
				backpack, other, skill_manager, campaign):
			return {"success": false,
				"reason": "A mochila não pôde ser realocada sem perder itens."}
	for owner in owners:
		if owner != null and owner.current_health > 0 and not owner.inventory_items.is_empty():
			InventoryManager.inventory_layout(owner)
	return {"success": true, "effect": effect.effect_type,
		"transformed": transformed.size(), "changes": transformed,
		"had_epic": had_epic, "returned_epic": returned_epic}


## Mantém os donos sempre que couber; só então redistribui cópias entre os
## jogáveis. Planejamento puro: não move um único item antes de validar todos.
func _chaos_distribute_inventory(carried: Array[Dictionary],
		playables: Array[EntityState], predicted_capacity: Dictionary) -> bool:
	var remaining: Dictionary = {}
	for owner in playables:
		if owner != null and owner.current_health > 0:
			remaining[owner] = int(predicted_capacity.get(owner, owner.inventory_capacity()))
	var ordered := carried.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["item"] as ItemData).inventory_space \
			> (b["item"] as ItemData).inventory_space)
	for change in ordered:
		var owner := change["owner"] as EntityState
		var size := (change["item"] as ItemData).inventory_space
		var recipient: EntityState = owner if int(remaining.get(owner, 0)) >= size else null
		if recipient == null:
			for member in playables:
				if member != null and member.current_health > 0 \
						and int(remaining.get(member, 0)) >= size \
						and (recipient == null or int(remaining[member]) > int(remaining[recipient])):
					recipient = member
		if recipient == null:
			return false
		change["destination"] = recipient
		remaining[recipient] = int(remaining[recipient]) - size
	return true


func _chaos_candidates(catalog: Array[ItemData], source: Dictionary,
		epics_only: bool) -> Array[ItemData]:
	var owner := source["owner"] as EntityState
	var entry := source["entry"] as InventoryItemState
	var slot := int(source["slot"])
	var candidates: Array[ItemData] = []
	for item in catalog:
		if epics_only and item.rarity != ItemData.Rarity.EPIC:
			continue
		if slot >= 0 and (item.item_type != ItemData.ItemType.EQUIPMENT \
				or int(item.equipment_slot) != slot \
				or not skill_manager.can_equip_item(owner, item)):
			continue
		candidates.append(item)
	if candidates.size() > 1:
		candidates = candidates.filter(func(item: ItemData) -> bool:
			return item.id != entry.data.id)
	return candidates


## Catálogo compartilhado por qualquer Evento atual/futuro que peça escolha.
func get_catalog_choices(effect: Event_EffectData) -> Array[ItemData]:
	return _eligible_event_items(effect)


func _catalog_effect_for_outcome(outcome: EventOutcomeData) -> Event_EffectData:
	if outcome == null:
		return null
	for effect in outcome.effects:
		if effect != null and effect.effect_type == Event_EffectData.EffectType.GRANT_ITEM \
				and effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG:
			return effect
	return null


func get_prepared_item_reward() -> Dictionary:
	if _prepared.is_empty():
		return {}
	var context: Dictionary = _prepared["context"]
	for effect in _prepared["effects"]:
		if effect == null or effect.effect_type not in [
				Event_EffectData.EffectType.GRANT_ITEM,
				Event_EffectData.EffectType.GRANT_RANDOM_ITEM]:
			continue
		var key: int = effect.get_instance_id()
		if (_prepared.get("settled_item_effects", {}) as Dictionary).has(key):
			continue
		var item := effect.item as ItemData
		if effect.effect_type == Event_EffectData.EffectType.GRANT_ITEM \
				and effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG:
			item = context.get("decision", {}).get("selected_catalog_item") as ItemData
		if effect.effect_type == Event_EffectData.EffectType.GRANT_RANDOM_ITEM:
			item = (context.get("prepared_random_items", {}) as Dictionary).get(key) as ItemData
		if item != null:
			return {"actor": context.get("actor"), "item": item, "effect": effect}
	return {}


func exchange_prepared_item(outgoing: Array[InventoryItemState]) -> bool:
	var reward := get_prepared_item_reward()
	if reward.is_empty():
		return false
	var actor := reward["actor"] as EntityState
	var item := reward["item"] as ItemData
	var reward_effect := reward["effect"] as Event_EffectData
	var context: Dictionary = _prepared["context"]
	for other_effect in _prepared["effects"]:
		if other_effect == null or other_effect == reward_effect \
				or (_prepared.get("settled_item_effects", {}) as Dictionary).has(
					other_effect.get_instance_id()):
			continue
		if not _unsupported_reason(other_effect, context).is_empty():
			return false
	if not _inventory_manager.exchange_items(actor, outgoing, item):
		return false
	var settled: Dictionary = _prepared.get("settled_item_effects", {})
	settled[reward_effect.get_instance_id()] = {"success": true,
		"effect": reward_effect.effect_type, "target": actor.instance_id,
		"item": item, "item_name": item.display_name}
	_prepared["settled_item_effects"] = settled
	return apply_prepared_result()


func decline_prepared_item() -> bool:
	var reward := get_prepared_item_reward()
	if reward.is_empty():
		return false
	var item := reward["item"] as ItemData
	var effect := reward["effect"] as Event_EffectData
	if item.item_type == ItemData.ItemType.CURSED or not item.can_be_discarded \
			or effect.item_acceptance_required:
		return false
	var settled: Dictionary = _prepared.get("settled_item_effects", {})
	settled[effect.get_instance_id()] = {"success": true,
		"effect": effect.effect_type, "declined": true}
	_prepared["settled_item_effects"] = settled
	return apply_prepared_result()


func _information_candidates(effect: Event_EffectData) -> Array[Informacao]:
	var result: Array[Informacao] = []
	if gerencia == null or gerencia.campaign == null:
		return result
	for resource in gerencia.get_information_catalog():
		var info := resource as Informacao
		if info == null or gerencia.campaign.obtained_information_ids.has(info.id):
			continue
		if effect.information_id != &"" and info.id != effect.information_id:
			continue
		if not effect.tags_filter.is_empty():
			var matches := false
			for tag in effect.tags_filter:
				if tag == &"informacao" or tag in info.tags:
					matches = true
			if not matches:
				continue
		result.append(info)
	return result


## Armadilhas acionadas durante um Encontro usam a mesma execução de Effects,
## mas não substituem o bloco/Combate que já está pendente no BlockManager.
func resolve_combat_trap(event: EventData, actor: EntityState, coord: Vector2i,
		combat: CombatManager) -> Dictionary:
	if event == null or actor == null or combat == null or event.outcomes.is_empty():
		return {"success": false, "reason": "Armadilha sem resultado de Combate."}
	var outcome := event.outcomes[0]
	if outcome == null:
		return {"success": false, "reason": "Armadilha sem Outcome."}
	var context := {"actor": actor, "coord": coord,
		"origin_mode": HexGrid.PPPMapMode.COMBAT,
		"combat_enemies": combat.enemies}
	for effect in outcome.effects:
		if effect.effect_type == Event_EffectData.EffectType.START_COMBAT:
			if effect.encounter_selection != Event_EffectData.EncounterSelection.NEAREST_MAP_BLOCK:
				return {"success": false, "reason": "Seleção de Encontro não suportada nesta armadilha."}
		elif not _unsupported_reason(effect, context).is_empty():
			return {"success": false, "reason": _unsupported_reason(effect, context)}
	_shared_rolls.clear()
	_recent_dice_results.clear()
	_random_target_groups.clear()
	_queued_day_advance = 0
	_queued_world_transition.clear()
	var applied: Array[Dictionary] = []
	for effect in outcome.effects:
		if effect.activation_chance < 1.0 and _rng.randf() >= effect.activation_chance:
			continue
		if effect.effect_type == Event_EffectData.EffectType.START_COMBAT:
			var reinforcement := combat.add_alarm_reinforcements(coord)
			if not reinforcement.get("success", false):
				return reinforcement
			applied.append(reinforcement)
			continue
		for target in _targets(effect, context):
			var result := _apply_effect(effect, target, event, context,
				outcome.roll_per_target)
			if not result.get("success", false):
				return result
			applied.append(result)
	return {"success": true, "effects": applied,
		"dice_results": _recent_dice_results.duplicate()}


func _on_combat_returned_to_event(context: Dictionary,
		combat_result: Dictionary) -> void:
	if _event_combat_waiting.is_empty():
		return
	var waiting := _event_combat_waiting
	_event_combat_waiting = {}
	var result: Dictionary = waiting["result"]
	result["combat_result"] = combat_result.duplicate()
	var source := waiting.get("source_encounter_coord", EntityState.UNPLACED) as Vector2i
	var grid := context.get("map") as HexGrid
	if source != EntityState.UNPLACED and grid != null:
		var cell := grid.get_cell(source)
		if cell != null and cell.block_type == HexGrid.PPPBlockType.ENCOUNTER \
				and cell.state in [HexGrid.PPPBlockState.HIDDEN,
					HexGrid.PPPBlockState.REVEALED]:
			grid.activate_ppp_block(source)
			if gerencia != null and gerencia.map_view != null \
					and gerencia.map_view.grid == grid:
				gerencia.map_view.activate_block(source)
	_pending_result = result
	result_ready.emit(context, result)


func get_pending_event_combat_reward() -> ItemData:
	if _event_combat_waiting.is_empty():
		return null
	return _event_combat_waiting.get("epic_reward") as ItemData


## A caixa chama somente DEPOIS que o jogador leu e confirmou o resultado.
## Preparar sorteia qual Outcome sairá, mas ainda não altera nenhum personagem.
func apply_prepared_result() -> bool:
	if _prepared.is_empty() or gerencia == null or skill_manager == null:
		return false
	var context: Dictionary = _prepared["context"]
	var event := _prepared["event"] as EventData
	var outcome := _prepared["outcome"] as EventOutcomeData
	var selected: Dictionary = _prepared["selected"]
	var effects: Array[Event_EffectData] = _prepared["effects"]
	var resolved_story: String = _prepared.get("narrative", "")
	var unsupported_reason := str(_prepared.get("unsupported_reason", ""))
	# Um prêmio de item pode ficar pendente enquanto o jogador abre espaço.
	# Revalidar na tentativa seguinte, sem sortear outro Outcome.
	if unsupported_reason.begins_with("Libere espaço no inventário"):
		unsupported_reason = ""
		for effect in effects:
			if (_prepared.get("settled_item_effects", {}) as Dictionary).has(effect.get_instance_id()):
				continue
			var reason := _unsupported_reason(effect, context)
			if not reason.is_empty():
				unsupported_reason = reason
				break
		_prepared["unsupported_reason"] = unsupported_reason
	if not unsupported_reason.is_empty():
		resolution_blocked.emit(context, unsupported_reason)
		return false
	_shared_rolls.clear()
	_recent_dice_results.clear()
	_random_target_groups.clear()
	var applied: Array[Dictionary] = []
	if event.category == EventData.EventCategory.CATASTROPHE:
		var activation := catastrophe_manager.activate(event, outcome)
		if not activation.get("success", false):
			resolution_blocked.emit(context, str(activation.get("reason", "Catástrofe indisponível.")))
			return false
		applied.append(activation)
	else:
		if event.id in [&"ev_00012", &"ev_00013"]:
			for theft in _prepared.get("theft_plan", []):
				var theft_result := _apply_theft(theft)
				if not theft_result.get("success", false):
					resolution_blocked.emit(context, str(theft_result.get("reason", "Roubo indisponível.")))
					return false
				applied.append(theft_result)
		if effects.size() == 1 and effects[0] != null \
				and (effects[0].effect_type == Event_EffectData.EffectType.START_COMBAT \
					or effects[0].effect_type == Event_EffectData.EffectType.CUSTOM \
					and effects[0].custom_rule in [
						&"gnome_3_start_other_district_encounter",
						&"start_crazy_old_man_combat_scaled_to_group",
						&"start_dancing_zombie_horde_by_district",
						&"vortice_mortal"]):
			var start := _start_event_combat(effects[0], context)
			if not start.get("success", false):
				resolution_blocked.emit(context, str(start.get("reason", "Encontro indisponível.")))
				return false
			_prepared.clear()
			_event_combat_waiting = {"result": {"event_id": event.id,
				"outcome_id": outcome.id if outcome != null else &"",
				"outcome_name": outcome.display_name if outcome != null else "",
				"narrative": resolved_story,
				"accepted": true, "effects": [start]},
				"epic_reward": start.get("epic_reward"),
				"source_encounter_coord": start.get("encounter_coord",
					EntityState.UNPLACED)}
			return true
		if effects.size() == 1 and effects[0] != null \
				and effects[0].effect_type == Event_EffectData.EffectType.TRIGGER_EVENT:
			var triggered := _event_by_id(effects[0].event_id)
			if not EventCampaignEligibility.allows_event(triggered,
					gerencia.campaign.campaign_mode):
				resolution_blocked.emit(context, "O Evento encadeado não está disponível.")
				return false
			if not gerencia.record_event_activated(triggered):
				resolution_blocked.emit(context, "O Evento encadeado não pode ser ativado.")
				return false
			_chained_event_parent = {"event_id": event.id,
				"outcome_id": outcome.id if outcome != null else &"",
				"outcome_name": outcome.display_name if outcome != null else "",
				"narrative": resolved_story, "accepted": true,
				"effects": [{"effect": effects[0].effect_type,
					"triggered_event_id": triggered.id}]}
			_prepared.clear()
			var child_context := context.duplicate()
			child_context["resource"] = triggered
			_on_event_requested(child_context)
			return true
		for effect in effects:
			var settled: Dictionary = _prepared.get("settled_item_effects", {})
			if settled.has(effect.get_instance_id()):
				applied.append(settled[effect.get_instance_id()])
				continue
			if effect.activation_chance < 1.0 and _rng.randf() >= effect.activation_chance:
				applied.append({"effect": effect.effect_type, "skipped_chance": true})
				continue
			if effect.effect_type == Event_EffectData.EffectType.SWAP_BODIES:
				var swap_result := gerencia.campaign.swap_playable_visuals(
					effect.reverse_swap_on_repeat)
				if not swap_result.get("success", false):
					resolution_blocked.emit(context, str(swap_result.get("reason",
						"Não foi possível trocar as aparências.")))
					return false
				swap_result["effect"] = effect.effect_type
				applied.append(swap_result)
				continue
			if effect.effect_type == Event_EffectData.EffectType.TRANSFORM_INVENTORY:
				var chaos_result := _apply_gnome_chaos(effect)
				if not chaos_result.get("success", false):
					resolution_blocked.emit(context, str(chaos_result.get("reason",
						"Não foi possível transformar os itens.")))
					return false
				applied.append(chaos_result)
				continue
			if event.id == &"ev_00014" \
					and effect.effect_type == Event_EffectData.EffectType.REVEAL_BLOCKS:
				applied.append(_reveal_imaginary_friend(context))
				continue
			if effect.effect_type in [Event_EffectData.EffectType.ADVANCE_DAY,
					Event_EffectData.EffectType.TELEPORT_ENTITY,
					Event_EffectData.EffectType.CHANGE_MAP]:
				var world_result := _prepare_world_effect(effect, context)
				if not world_result.get("success", false):
					resolution_blocked.emit(context, str(world_result.get("reason",
						"Não foi possível preparar a mudança de mapa.")))
					return false
				applied.append(world_result)
				continue
			if effect.effect_type in [Event_EffectData.EffectType.REVEAL_BLOCKS,
					Event_EffectData.EffectType.REPORT_MAP_PRESENCE,
					Event_EffectData.EffectType.MASK_BLOCK_VISUALS,
					Event_EffectData.EffectType.REPLACE_BLOCK_CONTENT]:
				var map_result := _apply_map_effect(effect, context)
				if not map_result.get("success", false):
					resolution_blocked.emit(context, str(map_result.get("reason", "Mapa indisponível.")))
					return false
				applied.append(map_result)
				continue
			for target in _targets(effect, context):
				var usage_key := "%s:%s" % [event.id, target.instance_id]
				if effect.max_applications_per_entity_per_campaign > 0 \
						and int(gerencia.campaign.event_effects_applied_by_actor.get(usage_key, 0)) \
						>= effect.max_applications_per_entity_per_campaign:
					applied.append({"effect": effect.effect_type, "target": target.instance_id,
						"already_applied": true})
					continue
				if effect.required_shared_roll_value > 0:
					var roll_key := str(effect.shared_roll_id)
					if outcome != null and (outcome.roll_per_target or effect.roll_per_target):
						roll_key += ":" + str(target.instance_id)
					if not _shared_rolls.has(roll_key):
						resolution_blocked.emit(context, "O dado compartilhado ainda não foi lançado.")
						return false
					if int((_shared_rolls[roll_key] as Dictionary).get("source_die", 0)) \
							!= effect.required_shared_roll_value:
						applied.append({"effect": effect.effect_type, "target": target.instance_id,
							"required_roll_not_met": true})
						continue
				var effect_result := _apply_effect(effect, target, event, context,
					outcome != null and outcome.roll_per_target)
				if not effect_result.get("success", false):
					resolution_blocked.emit(context, str(effect_result.get("reason",
						"Não foi possível aplicar um efeito deste evento.")))
					return false
				applied.append(effect_result)
				if effect.max_applications_per_entity_per_campaign > 0:
					gerencia.campaign.event_effects_applied_by_actor[usage_key] = \
						int(gerencia.campaign.event_effects_applied_by_actor.get(usage_key, 0)) + 1
	var result := {
		"event_id": event.id,
		"outcome_id": outcome.id if outcome != null else &"",
		"outcome_name": outcome.display_name if outcome != null else "",
		"effect_choice_id": (_prepared.get("effect_choice") as EventEffectChoiceData).id \
			if _prepared.get("effect_choice") is EventEffectChoiceData else &"",
		"narrative": resolved_story,
		"accepted": selected.get("accepted", true),
		"guess": selected.get("guess", &""),
		"coin_result": selected.get("coin_result", &""),
		"guessed": selected.get("guessed", false),
		"effects": applied,
		"dice_results": _recent_dice_results.duplicate(),
	}
	_prepared.clear()
	_pending_result = result
	result_ready.emit(context, result)
	return true


func _start_event_combat(effect: Event_EffectData,
		context: Dictionary) -> Dictionary:
	var encounter: EncounterData
	var request: Dictionary = {}
	var reward: ItemData
	if effect.effect_type == Event_EffectData.EffectType.START_COMBAT \
			and effect.encounter_selection == Event_EffectData.EncounterSelection.NEAREST_MAP_BLOCK:
		var selection := _nearest_map_encounter_selection(context)
		encounter = selection.get("encounter") as EncounterData
		request["source_encounter_coord"] = selection.get("coord", EntityState.UNPLACED)
	elif effect.custom_rule == &"gnome_3_start_other_district_encounter":
		encounter = _other_district_encounter()
	elif effect.custom_rule == &"start_crazy_old_man_combat_scaled_to_group":
		encounter = _crazy_old_man_encounter()
	elif effect.custom_rule == &"start_dancing_zombie_horde_by_district":
		encounter = _district_zombie_encounter()
	elif effect.custom_rule == &"vortice_mortal":
		var solo := context.get("actor") as EntityState
		if solo == null or solo.current_health <= 0:
			return {"success": false, "reason": "O ativador não pode entrar no Vórtice."}
		var enemy := _chosen_district_enemy(context.get("narrative_bindings", {}))
		if enemy != null:
			encounter = _single_enemy_encounter(enemy, &"enc_event_vortice_mortal")
		reward = _weighted_epic_reward(context.get("actor") as EntityState)
		request["solo_actor"] = context.get("actor")
	if encounter == null:
		return {"success": false, "reason": "Não há Encontro elegível para este efeito."}
	if effect.custom_rule == &"vortice_mortal" and reward == null:
		return {"success": false, "reason": "Não há equipamento Épico para o prêmio."}
	request["encounter"] = encounter
	if block_manager == null or not block_manager.request_combat_from_event(
			request):
		return {"success": false, "reason": "Não foi possível iniciar o Combate deste evento."}
	var result := {"success": true, "encounter": encounter}
	if request.has("source_encounter_coord"):
		result["encounter_coord"] = request["source_encounter_coord"]
	if reward != null:
		result["epic_reward"] = reward
	return result


func _single_enemy_encounter(enemy: EntityData, encounter_id: StringName) -> EncounterData:
	var member := EncounterMemberData.new()
	member.entity = enemy
	member.minimum = 1
	member.maximum = 1
	var encounter := EncounterData.new()
	encounter.id = encounter_id
	encounter.display_name = enemy.display_name
	encounter.members.append(member)
	return encounter


func _crazy_old_man_encounter() -> EncounterData:
	if gerencia == null or gerencia.campaign == null:
		return null
	var group: Array[EntityState] = []
	for actor in gerencia.campaign.active_entity_states + gerencia.campaign.companion_states:
		if actor != null and actor.current_health > 0:
			group.append(actor)
	if group.is_empty():
		return null
	var health_sum := 0
	var attack_sum := 0
	for actor in group:
		health_sum += actor.max_health
		attack_sum += actor.attack
	var enemy := EntityData.new()
	enemy.id = &"crazy_old_man"
	enemy.display_name = "Velho Louco"
	enemy.description = "O velho que atacou o grupo na esquina."
	enemy.vida_base = maxi(1, roundi(float(health_sum) / group.size()) \
		+ _rng.randi_range(-5, 5))
	enemy.ataque_base = maxi(0, roundi(float(attack_sum) / group.size()) \
		+ _rng.randi_range(-5, 5))
	return _single_enemy_encounter(enemy, &"enc_event_crazy_old_man")


func _district_zombie_encounter() -> EncounterData:
	if gerencia == null or gerencia.campaign == null:
		return null
	var district := str(gerencia.campaign.district)
	var path := "res://resources/encounters/enc_zumbis_dancarinos_%s.tres" % district
	return load(path) as EncounterData if ResourceLoader.exists(path) else null


func _weighted_epic_reward(actor: EntityState) -> ItemData:
	if actor == null:
		return null
	var weighted: Array[ItemData] = []
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		var has_epic := false
		for entry in actor.inventory_items + actor.equipped_in_slot(slot):
			if entry != null and entry.data != null \
					and entry.data.equipment_slot == slot \
					and entry.data.rarity == ItemData.Rarity.EPIC:
				has_epic = true
				break
		for item in _inventory_manager.get_equipment_by_rarity(ItemData.Rarity.EPIC, slot):
			# Preferência, nunca exclusão: itens de tipos já possuídos continuam no sorteio.
			for weight in (1 if has_epic else 3):
				weighted.append(item)
	return weighted[_rng.randi_range(0, weighted.size() - 1)] \
		if not weighted.is_empty() else null


func _event_by_id(event_id: StringName) -> EventData:
	if event_id == &"":
		return null
	for filename in DirAccess.get_files_at("res://resources/events/random_events"):
		if not filename.ends_with(".tres"):
			continue
		var candidate := load("res://resources/events/random_events".path_join(filename)) as EventData
		if candidate != null and candidate.id == event_id:
			return candidate
	return null


func _nearest_map_encounter(context: Dictionary) -> EncounterData:
	return _nearest_map_encounter_selection(context).get("encounter") as EncounterData


func _nearest_map_encounter_selection(context: Dictionary) -> Dictionary:
	var grid := context.get("map") as HexGrid
	if grid == null:
		return {}
	var origin: Vector2i = context.get("coord", EntityState.UNPLACED)
	var nearest := 999
	var candidates: Array[Dictionary] = []
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null or cell.block_type != HexGrid.PPPBlockType.ENCOUNTER \
				or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
					HexGrid.PPPBlockState.REVEALED]:
			continue
		var encounter := grid.get_ppp_block_resource(coord) as EncounterData
		if encounter == null or not encounter.has_valid_composition():
			continue
		var distance := HexGrid.distance(origin, coord)
		if distance < nearest:
			nearest = distance
			candidates.clear()
		if distance == nearest:
			candidates.append({"encounter": encounter, "coord": coord})
	return candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else {}


func _other_district_encounter() -> EncounterData:
	if gerencia == null or gerencia.campaign == null:
		return null
	var campaign := gerencia.campaign
	var night := campaign.round_period == 2
	var candidates: Array[EncounterData] = []
	for path in DirAccess.get_files_at("res://resources/encounters"):
		if not path.ends_with(".tres"):
			continue
		var encounter := load("res://resources/encounters".path_join(path)) as EncounterData
		if encounter == null or not encounter.has_valid_composition() \
				or (encounter.unique_encounter \
				and encounter.id in campaign.occurred_unique_encounter_ids):
			continue
		if campaign.district in encounter.districts or encounter.districts.is_empty() \
				or encounter.night_only and not night:
			continue
		if night:
			var infernal := false
			for member in encounter.members:
				if member != null and member.entity != null \
						and &"coisa_do_capeta" in member.entity.tags:
					infernal = true
			if not infernal:
				continue
		candidates.append(encounter)
	return candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else null


func _on_event_requested(context: Dictionary) -> void:
	var event := context.get("resource") as EventData
	if event == null or block_manager == null or gerencia == null or skill_manager == null:
		return
	# Também impede ativações programáticas fora do sorteio normal.
	if not EventCampaignEligibility.allows_event(event, gerencia.campaign.campaign_mode):
		resolution_blocked.emit(context, "Este Evento não está disponível.")
		return
	# Este caso já tem seu próprio controlador de geração de duendes.
	if event.custom_rule == &"spawn_gnomes_3":
		return
	context = context.duplicate()
	context["narrative_bindings"] = _bindings_for(event, context)
	var selected := _select_outcome(event, context.get("decision", {}))
	if not selected.get("success", false):
		resolution_blocked.emit(context, str(selected.get("reason", "Resultado indisponível.")))
		return
	var outcome := selected.get("outcome") as EventOutcomeData
	var resolved_story := resolve_narrative(event,
		outcome.narrative_description if outcome != null else "", context)
	var effects: Array[Event_EffectData] = []
	var unsupported_reason := ""
	var selected_choice: EventEffectChoiceData
	if outcome != null:
		effects.append_array(outcome.effects)
		if not outcome.effect_choices.is_empty():
			selected_choice = context.get("decision", {}).get("effect_choice") as EventEffectChoiceData
			if selected_choice not in outcome.effect_choices:
				unsupported_reason = "Escolha uma das opções deste desejo."
			else:
				effects.append_array(selected_choice.effects)
				if not selected_choice.description.is_empty():
					resolved_story += "\n\n" + selected_choice.description
	if event.id == &"ev_00049":
		var selected_passive := context.get("decision", {}).get("selected_passive") as PassiveSkillData
		var selected_item := context.get("decision", {}).get("selected_catalog_item") as ItemData
		var deceased := context.get("decision", {}).get("selected_dead_actor") as EntityState
		if selected_passive != null:
			resolved_story += "\n\nPassiva escolhida: %s. %s" % [
				selected_passive.display_name, selected_passive.description]
		elif selected_item != null:
			resolved_story += "\n\nItem escolhido: %s." % selected_item.display_name
		elif deceased != null:
			resolved_story += "\n\nPersonagem escolhido: %s." % deceased.visible_name()
	if context.get("decision", {}).get("forfeit_catalog_reward", false) \
			and outcome != null and _catalog_effect_for_outcome(outcome) != null:
		effects = []
		unsupported_reason = ""
		resolved_story = "Você decidiu não receber a recompensa."
	if event.id == &"ev_00016" and context.get("decision", {}).get("no_item", false):
		effects = []
		resolved_story = "Sem melhorias hoje... Quem sabe depois, né?!"
	var theft_plan: Array[Dictionary] = []
	if event.id in [&"ev_00012", &"ev_00013"]:
		theft_plan = _prepare_theft_plan(event, outcome, context)
		effects = []
		var stolen_names: Array[String] = []
		for theft in theft_plan:
			var stolen := theft.get("entry") as InventoryItemState
			if stolen != null and stolen.data != null:
				stolen_names.append(stolen.data.display_name)
		if stolen_names.is_empty():
			resolved_story = "Aff - Dia de sorte, hm?!"
		elif event.id == &"ev_00012":
			resolved_story = event.narrative_description.replace(
				"[item perdido]", stolen_names[0])
		else:
			resolved_story = event.narrative_description + "\n\nItens perdidos: " + \
				", ".join(stolen_names) + "."
	var prepared_random_items: Dictionary = {}
	for effect in effects:
		if effect != null and effect.effect_type == Event_EffectData.EffectType.GRANT_RANDOM_ITEM:
			var choices := _eligible_event_items(effect)
			if not choices.is_empty():
				prepared_random_items[effect.get_instance_id()] = choices[_rng.randi_range(0, choices.size() - 1)]
	context["prepared_random_items"] = prepared_random_items
	for effect in effects:
		if event.category != EventData.EventCategory.CATASTROPHE:
			var reason := _unsupported_reason(effect, context)
			if not reason.is_empty() and unsupported_reason.is_empty():
				unsupported_reason = reason
	if event.category == EventData.EventCategory.CATASTROPHE \
			and (catastrophe_manager == null or not catastrophe_manager.supports(event, outcome)):
		unsupported_reason = "Os efeitos desta catástrofe não estão executáveis."
	_prepared = {"context": context.duplicate(), "event": event, "outcome": outcome,
		"effect_choice": selected_choice,
		"selected": selected.duplicate(), "effects": effects,
		"narrative": resolved_story,
		"theft_plan": theft_plan,
		"unsupported_reason": unsupported_reason}
	var requires_die_roll := false
	if event.category != EventData.EventCategory.CATASTROPHE:
		for effect in effects:
			if effect != null and effect.execution_mode == Event_EffectData.ExecutionMode.IMMEDIATE \
					and effect.dice_count > 0:
				requires_die_roll = true
				break
	outcome_prepared.emit(context, {"outcome_name": selected_choice.display_name if selected_choice != null \
		else outcome.display_name if outcome != null else "",
		"narrative": resolved_story,
		"accepted": selected.get("accepted", true),
		"guess": selected.get("guess", &""),
		"coin_result": selected.get("coin_result", &""),
		"coin_side": selected.get("coin_side", -1),
		"guessed": selected.get("guessed", false),
		"requires_die_roll": requires_die_roll,
		"requires_second_ack": selected.get("accepted", true) and outcome != null \
			and not context.get("decision", {}).get("forfeit_catalog_reward", false)})


func _select_outcome(event: EventData, decision: Dictionary) -> Dictionary:
	if (event.custom_rule != &"" \
			and event.custom_rule not in [&"gnome_3_start_other_district_encounter",
				&"start_crazy_old_man_combat_scaled_to_group",
				&"start_dancing_zombie_horde_by_district",
				&"vortice_mortal",
				&"add_wooden_doll_companion", &"florzinha_misteriosa",
				&"solo_active_entity_for_three_turns"]) \
			or event.resolution_mode == EventData.ResolutionMode.CUSTOM:
		return {"success": false, "reason": "A regra especial deste evento ainda precisa de um executor próprio."}
	var eligible: Array[EventOutcomeData] = []
	if event.resolution_mode == EventData.ResolutionMode.CONDITIONAL_OUTCOME:
		var fallback: EventOutcomeData
		for outcome in event.outcomes:
			if not _outcome_is_campaign_eligible(outcome):
				continue
			if outcome.condition == null:
				fallback = outcome
			elif _condition_matches(outcome.condition):
				return {"success": true, "outcome": outcome}
		return {"success": true, "outcome": fallback} if fallback != null else \
			{"success": false, "reason": "Nenhum resultado corresponde à condição atual."}
	for outcome in event.outcomes:
		if outcome != null and outcome.condition == null \
				and _outcome_is_campaign_eligible(outcome):
			eligible.append(outcome)
	match event.resolution_mode:
		EventData.ResolutionMode.AUTOMATIC, EventData.ResolutionMode.RANDOM_OUTCOME:
			if eligible.is_empty():
				return {"success": false, "reason": "Este evento não possui resultado automático válido."}
			return {"success": true, "outcome": _draw_weighted(eligible)}
		EventData.ResolutionMode.PLAYER_ACCEPTS_THEN_OUTCOME:
			if not decision.has("accepted"):
				return {"success": false, "reason": "Falta aceitar ou recusar este evento."}
			if not decision["accepted"]:
				return {"success": true, "outcome": null, "accepted": false}
			if eligible.is_empty():
				return {"success": false, "reason": "Este evento não possui resultado para a aceitação."}
			return {"success": true, "outcome": _draw_weighted(eligible), "accepted": true}
		EventData.ResolutionMode.PLAYER_CHOOSES_OUTCOME:
			for outcome in eligible:
				if outcome == decision.get("outcome") or \
					(outcome.id != &"" and outcome.id == decision.get("outcome_id")):
					return {"success": true, "outcome": outcome}
			return {"success": false, "reason": "A opção selecionada não pertence a este evento."}
		EventData.ResolutionMode.PLAYER_GUESSES_RANDOM_OPTION:
			if decision.get("refused", false):
				return {"success": true, "outcome": event.guess_refusal_outcome} \
					if _outcome_is_campaign_eligible(event.guess_refusal_outcome) else \
					{"success": false, "reason": "Este palpite não permite recusa."}
			var guess := StringName(str(decision.get("guess", "")))
			var flip_result := CoinFlip.resolve_guess(event.guess_options, guess, _rng)
			if not flip_result.get("success", false):
				return flip_result
			var guessed_outcome := event.guess_match_outcome if flip_result["guessed"] \
				else event.guess_miss_outcome
			if not _outcome_is_campaign_eligible(guessed_outcome):
				return {"success": false, "reason": "O acerto ou erro da moeda não tem Outcome."}
			flip_result["outcome"] = guessed_outcome
			return flip_result
	return {"success": false,
		"reason": "A seleção condicional ou por palpite deste evento ainda não está executável."}


func _outcome_is_campaign_eligible(outcome: EventOutcomeData) -> bool:
	if not EventCampaignEligibility.allows_outcome(outcome,
			gerencia.campaign.campaign_mode):
		return false
	# Antes do sorteio, retire ramos que disparariam um Evento inelegível.
	# Isso protege encadeamentos futuros sem alterar a narrativa dos outcomes.
	for effect in outcome.effects:
		if effect != null and effect.effect_type == Event_EffectData.EffectType.TRIGGER_EVENT \
				and not EventCampaignEligibility.allows_event(_event_by_id(effect.event_id),
					gerencia.campaign.campaign_mode):
			return false
	return true


func _condition_matches(condition: EventConditionData) -> bool:
	if condition == null or gerencia == null or gerencia.campaign == null:
		return false
	var matched := false
	match condition.condition_type:
		EventConditionData.ConditionType.HAS_INFORMATION:
			for resource in gerencia.get_information_catalog():
				var information := resource as Informacao
				if information != null and gerencia.campaign.obtained_information_ids.has(information.id) \
						and condition.tag in information.tags:
					matched = true
					break
		EventConditionData.ConditionType.IS_NIGHT:
			matched = gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.NIGHT
		EventConditionData.ConditionType.IS_DAY:
			matched = gerencia.campaign.round_period != PPPMapGenerator.RoundPeriod.NIGHT
		EventConditionData.ConditionType.HAS_TAG:
			matched = condition.tag in gerencia.campaign.obtained_information_ids
	return not matched if condition.negate else matched


func _draw_weighted(options: Array[EventOutcomeData]) -> EventOutcomeData:
	var total := 0
	for option in options:
		total += maxi(0, option.weight)
	if total <= 0:
		return options[0]
	var roll := _rng.randi_range(1, total)
	for option in options:
		roll -= maxi(0, option.weight)
		if roll <= 0:
			return option
	return options.back()


func _prepare_theft_plan(event: EventData, selected_outcome: EventOutcomeData,
		context: Dictionary) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var targets: Array[EntityState] = []
	if event.id == &"ev_00012":
		var actor := context.get("actor") as EntityState
		if actor != null:
			targets.append(actor)
	elif gerencia != null and gerencia.campaign != null:
		targets.append_array(gerencia.campaign.active_entity_states)
		targets.append_array(gerencia.campaign.companion_states)
	var outcomes: Array[EventOutcomeData] = []
	for candidate in event.outcomes:
		if candidate != null:
			outcomes.append(candidate)
	for target in targets:
		if target == null or target.current_health <= 0:
			continue
		var chosen := selected_outcome if event.id == &"ev_00012" \
			else _draw_weighted(outcomes)
		if chosen == null or chosen.effects.is_empty():
			continue
		var candidates := _theft_candidates(target, chosen.effects[0].item_filter)
		plan.append({"target": target, "entry": candidates.pick_random() \
			if not candidates.is_empty() else null})
	return plan


func _theft_candidates(target: EntityState,
		filters: Array[StringName]) -> Array[InventoryItemState]:
	var candidates: Array[InventoryItemState] = []
	if target == null:
		return candidates
	if &"unequipped" in filters:
		candidates.append_array(target.inventory_items)
	else:
		var slot := ItemData.EquipmentSlot.NONE
		if &"arma" in filters:
			slot = ItemData.EquipmentSlot.WEAPON
		elif &"armadura" in filters:
			slot = ItemData.EquipmentSlot.ARMOR
		elif &"acessorio" in filters:
			slot = ItemData.EquipmentSlot.ACCESSORY
		if slot != ItemData.EquipmentSlot.NONE:
			candidates.append_array(target.equipped_in_slot(slot))
	return candidates.filter(func(entry: InventoryItemState) -> bool:
		return entry != null and entry.data != null)


func _matching_item_copies(target: EntityState,
		filters: Array[StringName]) -> Array[InventoryItemState]:
	var result: Array[InventoryItemState] = []
	if target == null:
		return result
	if &"unequipped" in filters or &"equipped" not in filters:
		result.append_array(target.inventory_items)
	if &"equipped" in filters or &"unequipped" not in filters:
		result.append_array(target.equipped_weapons)
		result.append_array(target.equipped_armors)
		result.append_array(target.equipped_accessories)
	return result.filter(func(copy: InventoryItemState) -> bool:
		if copy == null or copy.data == null:
			return false
		if &"cursed" in filters:
			return copy.data.item_type == ItemData.ItemType.CURSED \
				or &"cursed" in copy.data.tags
		if &"arma" in filters:
			return copy.data.equipment_slot == ItemData.EquipmentSlot.WEAPON
		if &"armadura" in filters:
			return copy.data.equipment_slot == ItemData.EquipmentSlot.ARMOR
		if &"acessorio" in filters:
			return copy.data.equipment_slot == ItemData.EquipmentSlot.ACCESSORY
		return true)


func _apply_theft(theft: Dictionary) -> Dictionary:
	var target := theft.get("target") as EntityState
	var entry := theft.get("entry") as InventoryItemState
	if target == null:
		return {"success": false, "reason": "Alvo do roubo indisponível."}
	if entry == null:
		return {"success": true, "target": target.instance_id, "stolen": false}
	if entry in target.inventory_items:
		target.inventory_items.erase(entry)
	else:
		if not _equipment_manager.consume_equipped_item(target, entry, skill_manager):
			return {"success": false, "reason": "O equipamento sorteado não está mais disponível."}
	return {"success": true, "target": target.instance_id, "stolen": true,
		"item_name": entry.data.display_name, "item": entry.data}


func _unsupported_reason(effect: Event_EffectData, context: Dictionary) -> String:
	if effect == null:
		return "O resultado contém um efeito vazio."
	if effect.effect_type == Event_EffectData.EffectType.TRANSFORM_INVENTORY:
		return "" if gerencia != null and gerencia.campaign != null \
			and skill_manager != null and effect.target == Event_EffectData.Target.GROUP \
			else "A transformação de itens do grupo não está disponível."
	if effect.effect_type == Event_EffectData.EffectType.SWAP_BODIES:
		if gerencia == null or gerencia.campaign == null:
			return "A campanha não está disponível para a troca de aparências."
		return "" if effect.swap_mode == Event_EffectData.SwapMode.CYCLIC \
			and effect.swap_only_active_playables else \
			"O evento 26 exige a troca cíclica dos jogáveis ativos."
	if effect.effect_type == Event_EffectData.EffectType.MASK_BLOCK_VISUALS:
		var gnomes := gerencia.map_view.get_node_or_null("Gnomes2Manager") \
			if gerencia != null and gerencia.map_view != null else null
		return "" if gnomes != null and gnomes.has_method("start_effect") \
			else "Os gnomos visuais não estão disponíveis."
	if effect.effect_type == Event_EffectData.EffectType.REPLACE_BLOCK_CONTENT:
		return "" if context.get("map") is HexGrid \
			and context.get("coord", EntityState.UNPLACED) != EntityState.UNPLACED \
			else "A linha de hexes a substituir não está disponível."
	if effect.effect_type in [Event_EffectData.EffectType.ADVANCE_DAY,
			Event_EffectData.EffectType.TELEPORT_ENTITY,
			Event_EffectData.EffectType.CHANGE_MAP]:
		return "" if gerencia != null and gerencia.campaign != null \
			and exploration != null and context.get("actor") is EntityState \
			else "A Exploração não está disponível para a mudança de mapa."
	if effect.effect_type == Event_EffectData.EffectType.APPLY_VISUAL_EFFECT:
		if effect.visual_effect_id == &"chicken_form":
			return "" if gerencia != null and gerencia.campaign != null \
				else "A campanha não está disponível para a transformação."
		return "" if effect.visual_effect_id == &"pixelated_glitch" \
			and gerencia != null and gerencia.map_view != null \
			and gerencia.map_view.get_node_or_null("GlitchVisualController") != null \
			and gerencia.map_view.get_node("GlitchVisualController").has_method("start_effect") \
			else "O filtro visual deste evento não está disponível."
	var narrative_event := context.get("resource") as EventData
	if narrative_event != null and narrative_event.id == &"ev_00014" \
			and effect.effect_type == Event_EffectData.EffectType.REVEAL_BLOCKS:
		return "" if context.get("map") is HexGrid \
			and context.get("actor") is EntityState else "O mapa do Amigo Imaginário não está disponível."
	if effect.effect_type == Event_EffectData.EffectType.START_COMBAT:
		return "" if effect.encounter_selection == Event_EffectData.EncounterSelection.NEAREST_MAP_BLOCK \
			and _nearest_map_encounter(context) != null else "Não há Encontro próximo elegível."
	if effect.effect_type == Event_EffectData.EffectType.TRIGGER_EVENT:
		var child := _event_by_id(effect.event_id)
		var parent := context.get("resource") as EventData
		if not EventCampaignEligibility.allows_event(child,
				gerencia.campaign.campaign_mode) \
				or parent != null and child.id == parent.id:
			return "O Evento encadeado não foi encontrado ou aponta para si mesmo."
		if child.resolution_mode not in [EventData.ResolutionMode.AUTOMATIC,
				EventData.ResolutionMode.CONDITIONAL_OUTCOME] or child.outcomes.is_empty():
			return "O Evento encadeado exige uma decisão que este fluxo ainda não oferece."
		var child_context := context.duplicate()
		child_context["resource"] = child
		child_context["narrative_bindings"] = _bindings_for(child, child_context)
		for child_outcome in child.outcomes:
			if child_outcome == null:
				continue
			for child_effect in child_outcome.effects:
				if child_effect != null and child_effect.effect_type \
						== Event_EffectData.EffectType.TRIGGER_EVENT:
					return "Um Evento encadeado não pode disparar outro Evento nesta etapa."
				var child_reason := _unsupported_reason(child_effect, child_context)
				if not child_reason.is_empty():
					return "Evento %s: %s" % [child.display_name, child_reason]
		return ""
	if effect.effect_type == Event_EffectData.EffectType.CUSTOM \
			and effect.custom_rule == &"start_crazy_old_man_combat_scaled_to_group":
		return "" if gerencia != null and gerencia.campaign != null \
			else "O grupo não está disponível para o Velho Louco."
	if effect.effect_type == Event_EffectData.EffectType.CUSTOM \
			and effect.custom_rule == &"start_dancing_zombie_horde_by_district":
		return "" if _district_zombie_encounter() != null \
			else "Não há Encontro de Zumbis Dançarinos neste Distrito."
	if effect.effect_type == Event_EffectData.EffectType.CUSTOM \
			and effect.custom_rule == &"vortice_mortal":
		var solo := context.get("actor") as EntityState
		return "" if solo != null and solo.current_health > 0 \
			and _chosen_district_enemy(context.get("narrative_bindings", {})) != null \
			and _weighted_epic_reward(solo) != null \
			else "Não há inimigo ou equipamento Épico elegível para o Vórtice."
	if effect.effect_type == Event_EffectData.EffectType.CUSTOM \
			and effect.custom_rule == &"gnome_3_start_other_district_encounter":
		return "" if _other_district_encounter() != null else \
			"Não há Encontro de outro Distrito elegível."
	if effect.effect_type == Event_EffectData.EffectType.CUSTOM \
			and effect.custom_rule == &"add_wooden_doll_companion":
		var owner := context.get("actor") as EntityState
		return "" if gerencia != null and gerencia.campaign != null \
			and owner in gerencia.campaign.active_entity_states else \
			"O Bonequinho precisa de um jogável para seguir."
	if effect.effect_type == Event_EffectData.EffectType.CUSTOM \
			and effect.custom_rule in [&"florzinha_blessing", &"florzinha_spores",
				&"solo_active_entity_for_three_turns"]:
		if gerencia == null or gerencia.campaign == null or skill_manager == null:
			return "A campanha não está disponível para este efeito."
		if effect.custom_rule == &"solo_active_entity_for_three_turns" \
				and gerencia.campaign.solo_turns_remaining > 0:
			return "O grupo já está temporariamente ausente."
		return ""
	if effect.execution_mode == Event_EffectData.ExecutionMode.REPEAT_ON_TRIGGER \
			and context.get("resource") is EventData \
			and (context["resource"] as EventData).id == &"ev_00022":
		return "" if gerencia != null and gerencia.campaign != null \
			else "A campanha não está disponível para a Perseguição."
	if effect.effect_type in [Event_EffectData.EffectType.REVEAL_BLOCKS,
			Event_EffectData.EffectType.REPORT_MAP_PRESENCE]:
		if not context.get("map") is HexGrid:
			return "O mapa deste evento não está disponível."
		if effect.execution_mode != Event_EffectData.ExecutionMode.IMMEDIATE \
				and (narrative_event == null or narrative_event.id != &"ev_00038"):
			return "Esta revelação futura ainda não possui ativa associada."
		return ""
	if effect.effect_type == Event_EffectData.EffectType.GRANT_INFORMATION:
		if narrative_event != null and narrative_event.id == &"ev_00044":
			return ""
		return "" if not _information_candidates(effect).is_empty() else \
			"Nenhuma Informação elegível permanece no catálogo."
	if effect.effect_type == Event_EffectData.EffectType.FORGET_LAST_INFORMATION:
		return "" if gerencia != null and gerencia.campaign != null else \
			"A campanha não está disponível para esquecer Informação."
	# Uma ação futura precisa ser representada por ActiveSkillData antes de
	# ser oferecida no HUD. Não consumimos o evento silenciosamente.
	if effect.execution_mode != Event_EffectData.ExecutionMode.IMMEDIATE:
		return "Este evento cria uma ação ou efeito futuro ainda não ligado ao executor."
	if effect.effect != null and effect.effect_type != Event_EffectData.EffectType.APPLY_SKILL_EFFECT:
		return "Este efeito exige uma regra adicional de Skill."
	if effect.required_shared_roll_value > 0 and effect.shared_roll_id == &"":
		return "O resultado exigido não identifica o dado compartilhado."
	if effect.target not in [Event_EffectData.Target.ACTIVE_ENTITY,
			Event_EffectData.Target.RANDOM_PLAYER,
			Event_EffectData.Target.GROUP,
			Event_EffectData.Target.ENTITIES_IN_BLOCK_RADIUS]:
		return "A seleção de alvo deste efeito ainda não está ligada."
	if _targets(effect, context).is_empty():
		return "Não há personagem elegível para receber este efeito."
	if effect.dice_count > 0 and effect.dice_sides <= 0:
		return "O dado do efeito está sem número de lados."
	if effect.value_source == Event_EffectData.ValueSource.SHARED_ROLL \
			and effect.shared_roll_id == &"":
		return "O efeito não identifica qual dado deve compartilhar."
	match effect.effect_type:
		Event_EffectData.EffectType.REVIVE_DEAD_PLAYABLE:
			var deceased := context.get("decision", {}).get("selected_dead_actor") as EntityState
			return "" if deceased != null and gerencia != null \
				and deceased in gerencia.campaign.dead_playable_states else \
				"Escolha um personagem morto para ressuscitar."
		Event_EffectData.EffectType.APPLY_SKILL_EFFECT:
			if effect.effect == null:
				return "Este SkillEffect ainda não pode ser aplicado por Evento."
			if effect.effect.effect_type == SkillEffectData.EffectType.MODIFY_MASTERY:
				if effect.effect.selection_mode != SkillEffectData.SelectionMode.PLAYER_CHOOSES_FROM_OPTIONS:
					return "A escolha de Maestria não está definida."
				if int(context.get("decision", {}).get("selected_mastery", 0)) not in effect.effect.mastery_options:
					return "Escolha uma Maestria para continuar."
			elif effect.effect.effect_type != SkillEffectData.EffectType.MODIFY_ATTRIBUTE \
					or effect.effect.attribute_id != &"stamina" \
					or effect.effect.modify_mode != SkillEffectData.ModifyMode.ADD \
					or effect.effect.amount <= 0:
				return "Este SkillEffect ainda não pode ser aplicado por Evento."
		Event_EffectData.EffectType.GRANT_ACTIVE_SKILL:
			if effect.active_skill == null:
				return "A Ativa concedida não foi definida no Resource."
		Event_EffectData.EffectType.GRANT_ITEM:
			var chosen_item := effect.item
			if effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG:
				chosen_item = context.get("decision", {}).get("selected_catalog_item") as ItemData
				if chosen_item not in _eligible_event_items(effect):
					return "Escolha um item válido no catálogo."
			if chosen_item == null:
				return "O item concedido não foi definido."
			if not _inventory_manager.can_receive(context.get("actor") as EntityState,
					chosen_item):
				return "Libere espaço no inventário antes de receber este item."
		Event_EffectData.EffectType.MODIFY_EQUIPPED_ITEM_STAT:
			var selected_copy := context.get("decision", {}).get("selected_item") as InventoryItemState
			var owner := context.get("actor") as EntityState
			if selected_copy == null or selected_copy.data == null or owner == null \
					or (selected_copy not in owner.inventory_items \
					and selected_copy not in owner.equipped_weapons \
					and selected_copy not in owner.equipped_armors):
				return "Escolha uma arma ou armadura que possui."
			if int(selected_copy.data.equipment_slot) not in effect.required_item_equipment_slots:
				return "O Artesão só aprimora armas ou armaduras."
		Event_EffectData.EffectType.REMOVE_ITEM, \
		Event_EffectData.EffectType.REMOVE_CURSES:
			pass
		Event_EffectData.EffectType.GRANT_RANDOM_ITEM:
			var choices := _eligible_event_items(effect)
			if choices.is_empty():
				return "Não há item elegível no catálogo."
			var actor := context.get("actor") as EntityState
			var selected := (context.get("prepared_random_items", {}) as Dictionary).get(
				effect.get_instance_id()) as ItemData
			if selected != null and not _inventory_manager.can_receive(actor, selected):
				return "Libere espaço no inventário antes de receber este item."
			if selected == null and not choices.any(func(item: ItemData) -> bool:
				return _inventory_manager.can_receive(actor, item)):
				return "Libere espaço no inventário antes de receber este item."
		Event_EffectData.EffectType.GRANT_MOVEMENT_OVERRIDE:
			if not effect.ignore_stamina_cost or not effect.ignore_stamina_range:
				return "A concessão de movimento está incompleta no Resource."
		Event_EffectData.EffectType.GRANT_PASSIVE:
			if effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG \
					and effect.grant_binding_source == Event_EffectData.GrantBindingSource.NONE:
				var selected_passive := context.get("decision", {}).get("selected_passive") as PassiveSkillData
				if selected_passive not in get_passive_choices(context.get("actor") as EntityState):
					return "Escolha uma Passiva nova do catálogo de jogáveis."
			elif effect.passive == null:
				return "A Passiva concedida não foi definida no Resource."
			if effect.grant_binding_source == Event_EffectData.GrantBindingSource.SELECTED_OWNED_ITEM:
				var selected := context.get("decision", {}).get("selected_item") as InventoryItemState
				var actor := context.get("actor") as EntityState
				if selected == null or selected.data == null or actor == null \
						or (selected not in actor.inventory_items and selected not in actor.equipped_weapons):
					return "Escolha uma arma que o personagem possui."
				var source_event := context.get("resource") as EventData
				var can_evolve: bool = source_event != null and source_event.id == &"ev_00058" and \
						selected.data.rarity != ItemData.Rarity.EPIC and \
						_has_epic_evolution(selected.data)
				if selected.data.equipment_slot != effect.required_bound_item_slot \
						or (selected.data.rarity != effect.required_bound_item_rarity and not can_evolve):
					return "A arma selecionada não atende aos requisitos."
				if source_event != null and source_event.id == &"ev_00058":
					var used_after := actor.inventory_used_space()
					if selected in actor.inventory_items:
						used_after -= selected.data.inventory_space
					for equipped_entry in actor.equipped_weapons:
						if equipped_entry != selected and equipped_entry.data != null:
							used_after += equipped_entry.data.inventory_space
					if used_after > actor.inventory_capacity():
						return "Libere espaço na mochila para guardar as outras armas antes da Simbiose."
			elif effect.grant_binding_source == Event_EffectData.GrantBindingSource.SELECTED_ENEMY_FROM_LAST_ENCOUNTER:
				var chosen_enemy := context.get("decision", {}).get("selected_enemy") as EntityData
				if chosen_enemy == null or chosen_enemy not in gerencia.campaign.last_encounter_entity_types:
					return "Escolha um tipo de inimigo do último Encontro concluído."
		Event_EffectData.EffectType.ADD_COMPANION:
			if effect.entity_selection == Event_EffectData.EntitySelection.RANDOM_PLAYABLE_CHARACTER:
				if _chosen_playable_ally(context.get("narrative_bindings", {})) == null:
					return "Não há outro personagem jogável para entrar no grupo."
			elif effect.entity_selection == Event_EffectData.EntitySelection.RANDOM_CURRENT_DISTRICT_ENEMY:
				if _chosen_district_enemy(context.get("narrative_bindings", {})) == null:
					return "Não há criatura elegível neste Distrito."
			elif effect.entity == null:
				return "O companheiro não foi definido no Resource."
		Event_EffectData.EffectType.GRANT_STATUS_IMMUNITY:
			if effect.status_ids.is_empty() and effect.immunity_item_tags.is_empty():
				return "A imunidade não indica o que protege."
		Event_EffectData.EffectType.IGNORE_RANGED_CRITICAL_BONUS:
			pass
		Event_EffectData.EffectType.MODIFY_HP, \
		Event_EffectData.EffectType.MODIFY_MAX_HP, \
		Event_EffectData.EffectType.MODIFY_STAT:
			if effect.has_duration and (narrative_event == null \
					or narrative_event.id != &"ev_00019"):
				return "O modificador temporário deste evento ainda não tem estado de expiração."
			if effect.effect_type == Event_EffectData.EffectType.MODIFY_STAT \
					and effect.statistic == Event_EffectData.Statistic.NONE:
				return "O atributo modificado não foi definido no Resource."
		Event_EffectData.EffectType.APPLY_STATUS:
			if effect.debuff == null:
				return "O Debuff deste efeito não foi definido no Resource."
			if effect.has_duration and effect.expiration_mode not in [
					Event_EffectData.ExpirationMode.AFTER_DURATION,
					Event_EffectData.ExpirationMode.END_OF_CURRENT_ROUND]:
				return "A duração até o fim do Dia ainda não está ligada."
			if effect.has_duration and effect.duration_source == Event_EffectData.DurationSource.DICE_ROLL \
					and effect.dice_count <= 0:
				return "Falta o dado que define a duração deste Debuff."
		Event_EffectData.EffectType.REMOVE_STATUS:
			pass
		_:
			return "O efeito %s ainda não possui execução real." % \
				Event_EffectData.EffectType.keys()[effect.effect_type]
	return ""


func _reveal_imaginary_friend(context: Dictionary) -> Dictionary:
	var grid := context.get("map") as HexGrid
	var actor := context.get("actor") as EntityState
	if grid == null or actor == null:
		return {"success": false, "reason": "Mapa ou personagem indisponível."}
	var revealed: Array[Vector2i] = []
	var view := gerencia.map_view if gerencia != null else null
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null or cell.block_type != HexGrid.PPPBlockType.ENCOUNTER \
				or cell.state != HexGrid.PPPBlockState.HIDDEN \
				or HexGrid.distance(actor.position, coord) > actor.max_stamina:
			continue
		if view != null and view.grid == grid:
			view.reveal_block(coord)
		else:
			grid.reveal_ppp_block(coord)
		revealed.append(coord)
	return {"success": true, "effect": Event_EffectData.EffectType.REVEAL_BLOCKS,
		"revealed_tiles": revealed, "revealed_count": revealed.size()}


func _apply_map_effect(effect: Event_EffectData, context: Dictionary) -> Dictionary:
	var grid := context.get("map") as HexGrid
	if grid == null:
		return {"success": false, "reason": "Mapa indisponível."}
	if effect.effect_type == Event_EffectData.EffectType.MASK_BLOCK_VISUALS:
		var gnomes := gerencia.map_view.get_node_or_null("Gnomes2Manager")
		var started: Dictionary = gnomes.call("start_effect")
		started["effect"] = effect.effect_type
		return started
	if effect.effect_type == Event_EffectData.EffectType.REPLACE_BLOCK_CONTENT:
		return _replace_map_row(effect, context, grid)
	if effect.effect_type == Event_EffectData.EffectType.REPORT_MAP_PRESENCE:
		var present: Dictionary = {}
		for tag in effect.tags_filter:
			present[tag] = false
		for coord in grid.cells:
			var cell := grid.get_cell(coord)
			if cell == null or cell.block_type == HexGrid.PPPBlockType.NONE:
				continue
			for tag in effect.tags_filter:
				if _map_cell_matches_report_tag(cell, tag):
					present[tag] = true
		return {"success": true, "effect": effect.effect_type, "presence": present}
	var actor := context.get("actor") as EntityState
	if actor == null:
		return {"success": false, "reason": "Personagem indisponível."}
	if effect.execution_mode == Event_EffectData.ExecutionMode.GRANT_ACTION:
		actor.premonition_round_index = gerencia.campaign.get_round_index()
		actor.premonition_used_turn_serial = -1
		return {"success": true, "effect": effect.effect_type,
			"premonition_round_index": actor.premonition_round_index}
	if effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG:
		actor.future_vision_uses += maxi(0, effect.amount)
		return {"success": true, "effect": effect.effect_type,
			"future_vision_uses": actor.future_vision_uses}
	var choices: Array[Vector2i] = []
	for coord in grid.cells:
		if coord == context.get("coord", Vector2i(-999, -999)):
			continue
		var cell := grid.get_cell(coord)
		if cell == null or cell.state != HexGrid.PPPBlockState.HIDDEN \
				or cell.block_type == HexGrid.PPPBlockType.NONE:
			continue
		if effect.area_radius > 0 and HexGrid.distance(actor.position, coord) > effect.area_radius:
			continue
		if effect.tags_filter.has(&"encounter") \
				and cell.block_type != HexGrid.PPPBlockType.ENCOUNTER:
			continue
		choices.append(coord)
	if effect.selection_mode == Event_EffectData.SelectionMode.RANDOM_FROM_CATALOG:
		for index in range(choices.size() - 1, 0, -1):
			var swap_index := _rng.randi_range(0, index)
			var previous := choices[index]
			choices[index] = choices[swap_index]
			choices[swap_index] = previous
		choices.resize(mini(choices.size(), maxi(0, effect.amount)))
	elif not effect.reveal_all_blocks and effect.area_radius == 0 and effect.amount > 0:
		choices.resize(mini(choices.size(), effect.amount))
	var view := gerencia.map_view if gerencia != null else null
	for coord in choices:
		if effect.reveal_detail == Event_EffectData.RevealDetail.TYPE_AND_EFFECT:
			var sources: Array = grid.revealed_by_skill_ids.get(coord, [])
			if &"event_type_and_effect" not in sources:
				sources.append(&"event_type_and_effect")
			grid.revealed_by_skill_ids[coord] = sources
		if view != null and view.grid == grid:
			view.reveal_block(coord)
		else:
			grid.reveal_ppp_block(coord)
	return {"success": true, "effect": effect.effect_type,
		"revealed_tiles": choices, "revealed_count": choices.size(),
		"reveal_detail": effect.reveal_detail}


func _map_cell_matches_report_tag(cell: HexCell, tag: StringName) -> bool:
	match tag:
		&"catastrophe": return cell.block_type == HexGrid.PPPBlockType.CATASTROPHE
		&"trap": return cell.block_type == HexGrid.PPPBlockType.TRAP
		&"cursed": return cell.block_type == HexGrid.PPPBlockType.CURSE
	return false


## Evento 41: a linha é refeita inteira, inclusive o hex que disparou o
## redemoinho. Informação é intocável; novos Resources não podem existir em
## nenhum lugar do mapa ANTES da troca, e o sorteio não repete Resources.
## A mudança real espera o jogador confirmar o Outcome. Assim a narrativa
## permanece no mapa de origem e a transição não atropela o BlockManager.
func _prepare_world_effect(effect: Event_EffectData,
		context: Dictionary) -> Dictionary:
	var actor := context.get("actor") as EntityState
	if actor == null or exploration == null or gerencia == null:
		return {"success": false, "reason": "Exploração indisponível."}
	match effect.effect_type:
		Event_EffectData.EffectType.ADVANCE_DAY:
			_queued_day_advance += maxi(0, effect.amount)
			return {"success": true, "effect": effect.effect_type,
				"days_queued": _queued_day_advance}
		Event_EffectData.EffectType.TELEPORT_ENTITY:
			var grid := gerencia.campaign.current_map
			if grid == null:
				return {"success": false, "reason": "Mapa atual indisponível."}
			var occupied: Dictionary = {}
			for member in gerencia.campaign.active_entity_states:
				if member != actor and member != null and member.current_health > 0:
					occupied[member.position] = true
			for companion in gerencia.campaign.companion_states:
				if companion != null and companion.current_health > 0:
					occupied[companion.position] = true
			var destinations: Array[Vector2i] = []
			for coord in grid.cells:
				if coord == actor.position or not grid.can_choose_ppp_destination(
						coord, actor.position, occupied) \
						or grid.get_ppp_block_resource(coord) == null:
					continue
				destinations.append(coord)
			if destinations.is_empty():
				return {"success": false, "reason":
					"Não há outro bloco ainda disponível para o teleporte."}
			var destination := destinations[_rng.randi_range(0, destinations.size() - 1)]
			_queued_world_transition = {"kind": &"teleport", "actor": actor,
				"destination": destination}
			return {"success": true, "effect": effect.effect_type,
				"destination": destination}
		Event_EffectData.EffectType.CHANGE_MAP:
			var districts: Array[StringName] = RoundManager.DISTRICT_ORDER.duplicate()
			var district := districts[_rng.randi_range(0, districts.size() - 1)]
			var campaign := gerencia.campaign
			var next_day: int = campaign.day + _queued_day_advance
			var target_round: int = (next_day - 1) * 3 + campaign.round_period
			var new_map := gerencia.prepare_map(gerencia.get_information_catalog(),
				district, campaign.round_period, target_round, _rng)
			if new_map == null:
				return {"success": false, "reason":
					"Não foi possível gerar o mapa de destino; o grupo permanece aqui."}
			_queued_world_transition = {"kind": &"new_map", "actor": actor,
				"map": new_map, "district": district, "next_day": next_day,
				"activate_arrival": effect.activate_destination_event}
			return {"success": true, "effect": effect.effect_type,
				"district": district, "day": next_day,
				"arrival_activates": effect.activate_destination_event}
	return {"success": false, "reason": "Efeito de mundo desconhecido."}


func _perform_world_transition(transition: Dictionary) -> bool:
	var actor := transition.get("actor") as EntityState
	if actor == null or exploration == null or gerencia == null:
		return false
	if transition.get("kind") == &"teleport":
		return exploration.arrive_from_event(transition["destination"], actor)
	if transition.get("kind") != &"new_map":
		return false
	var campaign := gerencia.campaign
	var new_map := transition.get("map") as HexGrid
	if new_map == null:
		return false
	var new_day := int(transition.get("next_day", campaign.day)) > campaign.day
	campaign.day = int(transition.get("next_day", campaign.day))
	campaign.district = transition.get("district", campaign.district)
	campaign.expire_temporary_events_for_clock()
	if catastrophe_manager != null:
		catastrophe_manager.expire_for_current_time()
	if not gerencia.install_map(new_map):
		return false
	if new_day:
		var external: Array[EntityState] = []
		if catastrophe_manager != null:
			external = catastrophe_manager.get_external_actors()
		skill_manager.inventory_manager.discard_spoiled_consumables(campaign, external)
		skill_manager.on_day_started(campaign, _rng)
		skill_manager.on_round_started(campaign, _rng)
	if not exploration.enter_map(new_day, actor if new_day else null):
		return false
	if not transition.get("activate_arrival", false):
		return exploration.pass_turn()
	var arrival: Array[Vector2i] = []
	for coord in new_map.cells:
		if new_map.can_choose_ppp_destination(coord, actor.position) \
				and new_map.get_ppp_block_resource(coord) != null:
			arrival.append(coord)
	if arrival.is_empty():
		return false
	return exploration.arrive_from_event(
		arrival[_rng.randi_range(0, arrival.size() - 1)], actor)


func _replace_map_row(effect: Event_EffectData, context: Dictionary,
		grid: HexGrid) -> Dictionary:
	if effect.target != Event_EffectData.Target.BLOCK_LINE_HORIZONTAL:
		return {"success": false, "reason": "O Saci exige uma linha horizontal."}
	var origin: Vector2i = context.get("coord", EntityState.UNPLACED)
	if not grid.is_valid(origin):
		return {"success": false, "reason": "O bloco de origem não está no mapa."}
	var targets: Array[Vector2i] = []
	var original_paths: Dictionary = {}
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null:
			continue
		if not cell.resource_path.is_empty():
			original_paths[cell.resource_path] = true
		if coord.y == origin.y and cell.block_type not in effect.preserved_map_block_types:
			targets.append(coord)
	var generator := PPPMapGenerator.new()
	var pools := generator._build_pools([], gerencia.campaign.district,
		gerencia.campaign.round_period)
	var candidates: Array[Dictionary] = []
	var standby := gerencia.campaign.get_events_on_standby()
	for block_type in [HexGrid.PPPBlockType.ENCOUNTER,
			HexGrid.PPPBlockType.CONSUMABLE, HexGrid.PPPBlockType.EQUIPMENT,
			HexGrid.PPPBlockType.CURSE, HexGrid.PPPBlockType.EVENT,
			HexGrid.PPPBlockType.TRAP, HexGrid.PPPBlockType.CATASTROPHE]:
		if block_type == HexGrid.PPPBlockType.TRAP and (
				gerencia.campaign.generated_map_count <= 1 \
				or gerencia.campaign.obtained_information_ids.is_empty()):
			continue
		if block_type == HexGrid.PPPBlockType.CATASTROPHE \
				and gerencia.campaign.day <= 1:
			continue
		for resource in pools.get(block_type, []):
			if resource == null or resource.resource_path.is_empty() \
					or original_paths.has(resource.resource_path):
				continue
			if resource is EventData:
				var event := resource as EventData
				# O Saci usa o catálogo cru, fora do sorteio normal do gerador.
				if not EventCampaignEligibility.allows_event(event,
						gerencia.campaign.campaign_mode):
					continue
				var previous := int(gerencia.campaign.event_campaign_counts.get(
					event.resource_path, 0))
				if event.resource_path in standby \
						or event.requires_completed_encounter \
						and gerencia.campaign.last_encounter_entity_types.is_empty() \
						or not event.can_repeat and previous > 0 \
						or event.max_times_per_campaign > 0 \
						and previous >= event.max_times_per_campaign:
					continue
			if resource is EncounterData:
				var encounter := resource as EncounterData
				if encounter.unique_encounter and encounter.id in \
						gerencia.campaign.occurred_unique_encounter_ids:
					continue
			candidates.append({"type": block_type, "resource": resource})
	if candidates.size() < targets.size():
		return {"success": false, "reason":
			"Não há Resources inéditos suficientes para refazer a linha do Saci."}
	# Não altera nenhum hex antes de verificar capacidade. Shuffle sem peso nem
	# cota da geração normal; cada Resource é retirado da lista uma vez.
	for index in range(candidates.size() - 1, 0, -1):
		var swap_index := _rng.randi_range(0, index)
		var swap: Dictionary = candidates[index]
		candidates[index] = candidates[swap_index]
		candidates[swap_index] = swap
	targets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var replaced: Array[Dictionary] = []
	for index in targets.size():
		var candidate: Dictionary = candidates[index]
		grid.set_ppp_block(targets[index], int(candidate["type"]),
			candidate["resource"] as Resource)
		if candidate["resource"] is EventData:
			var path: String = (candidate["resource"] as EventData).resource_path
			gerencia.campaign.event_campaign_counts[path] = int(
				gerencia.campaign.event_campaign_counts.get(path, 0)) + 1
		replaced.append({"coord": targets[index], "resource_path":
			(candidate["resource"] as Resource).resource_path})
	if gerencia.map_view != null and gerencia.map_view.grid == grid:
		gerencia.map_view._refresh_feedback()
		gerencia.map_view.refresh_special_event_visuals()
	return {"success": true, "effect": effect.effect_type,
		"replaced": replaced, "preserved_information": HexGrid.PPP_MAP_WIDTH - targets.size()}


func _targets(effect: Event_EffectData, context: Dictionary) -> Array[EntityState]:
	var result: Array[EntityState] = []
	var actor := context.get("actor") as EntityState
	if actor == null:
		return result
	if effect.target == Event_EffectData.Target.ACTIVE_ENTITY:
		result.append(actor)
		return result
	var campaign := gerencia.campaign if gerencia != null else null
	if campaign == null:
		return result
	var candidates: Array[EntityState] = []
	candidates.append_array(campaign.active_entity_states)
	if effect.target == Event_EffectData.Target.RANDOM_PLAYER:
		var players: Array[EntityState] = []
		for candidate in candidates:
			if candidate != null and candidate.current_health > 0:
				players.append(candidate)
		if players.is_empty():
			return result
		var key := String(effect.target_selection_group)
		if not key.is_empty() and _random_target_groups.has(key):
			result.append(_random_target_groups[key] as EntityState)
		else:
			var chosen := players[_rng.randi_range(0, players.size() - 1)]
			if not key.is_empty():
				_random_target_groups[key] = chosen
			result.append(chosen)
		return result
	candidates.append_array(campaign.companion_states)
	if int(context.get("origin_mode", -1)) == HexGrid.PPPMapMode.COMBAT \
			and effect.target == Event_EffectData.Target.ENTITIES_IN_BLOCK_RADIUS:
		for hostile in context.get("combat_enemies", []):
			if hostile is EntityState:
				candidates.append(hostile)
	var center: Vector2i = context.get("coord", actor.position)
	for candidate in candidates:
		if candidate == null or candidate.current_health <= 0:
			continue
		if effect.target == Event_EffectData.Target.GROUP or \
			HexGrid.distance(candidate.position, center) <= effect.area_radius:
			result.append(candidate)
	return result


func _has_epic_evolution(item: ItemData) -> bool:
	if item == null:
		return false
	for candidate in item.craft_result:
		if candidate != null and candidate.rarity == ItemData.Rarity.EPIC:
			return true
	return false


func _apply_effect(effect: Event_EffectData, target: EntityState, event: EventData,
		context: Dictionary, per_target: bool) -> Dictionary:
	match effect.effect_type:
		Event_EffectData.EffectType.APPLY_VISUAL_EFFECT:
			if effect.visual_effect_id == &"chicken_form":
				gerencia.campaign.add_temporary_appearance(target, &"chicken_form")
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id, "appearance": &"chicken_form",
					"expires_round": gerencia.campaign.get_round_index() + 1}
			var controller: Node = gerencia.map_view.get_node_or_null("GlitchVisualController")
			if controller == null or effect.visual_effect_id != &"pixelated_glitch":
				return {"success": false, "reason": "Filtro visual indisponível."}
			controller.call("start_effect")
			return {"success": true, "effect": effect.effect_type,
				"visual_effect_id": effect.visual_effect_id}
		Event_EffectData.EffectType.GRANT_INFORMATION:
			var choices := _information_candidates(effect)
			if choices.is_empty():
				if event.id == &"ev_00044":
					return {"success": true, "effect": effect.effect_type,
						"no_eligible_information": true}
				return {"success": false, "reason": "Nenhuma Informação nova está disponível."}
			var info := choices[_rng.randi_range(0, choices.size() - 1)] \
				if effect.selection_mode == Event_EffectData.SelectionMode.RANDOM_FROM_CATALOG \
				else choices[0]
			if not gerencia.record_information_obtained(info):
				return {"success": false, "reason": "A Informação não pôde ser registrada."}
			skill_manager.on_information_obtained(gerencia.campaign)
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "information": info,
				"information_id": info.id, "information_title": info.titulo}
		Event_EffectData.EffectType.FORGET_LAST_INFORMATION:
			var forgotten_id := gerencia.campaign.forget_last_information()
			var forgotten_title := ""
			if forgotten_id != &"":
				for resource in gerencia.get_information_catalog():
					var information := resource as Informacao
					if information != null and information.id == forgotten_id:
						forgotten_title = information.titulo
						break
				for actor in gerencia.campaign.active_entity_states:
					skill_manager.refresh_information_passives(actor, gerencia.campaign)
				for companion in gerencia.campaign.companion_states:
					skill_manager.refresh_information_passives(companion, gerencia.campaign)
			return {"success": true, "effect": effect.effect_type,
				"forgotten_information_id": forgotten_id,
				"forgotten_information_title": forgotten_title}
		Event_EffectData.EffectType.CUSTOM:
			if effect.custom_rule == &"florzinha_blessing":
				var statistic: StringName = &"attack" if _rng.randi_range(0, 1) == 0 else &"life"
				var immunity: StringName = &"disease" if _rng.randi_range(0, 1) == 0 else &"terror"
				gerencia.campaign.add_day_attribute_blessing(target, statistic, 5)
				var protected_ids: Array[StringName] = []
				if immunity == &"disease":
					protected_ids.assign([&"db_00003", &"db_00004", &"db_00005"])
				else:
					protected_ids.append(&"db_00009")
				for status_id in protected_ids:
					gerencia.campaign.add_day_status_immunity(target, status_id)
					skill_manager.debuff_manager.remove_debuff(target, status_id)
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id, "bonus": 5,
					"statistic": statistic, "immunity": immunity,
					"expires_day": gerencia.campaign.day + 1}
			if effect.custom_rule == &"florzinha_spores":
				var center: Vector2i = context.get("coord", target.position)
				var affected: Array[StringName] = []
				for member in gerencia.campaign.active_entity_states + gerencia.campaign.companion_states:
					if member == null or member.current_health <= 0 \
							or member.position == EntityState.UNPLACED \
							or HexGrid.distance(center, member.position) > 3:
						continue
					var applied := skill_manager.debuff_manager.apply_by_id(member,
						&"db_00003", target, 0, gerencia.campaign.day)
					if applied.get("success", false):
						affected.append(member.instance_id)
				return {"success": true, "effect": effect.effect_type,
					"affected": affected, "radius": 3}
			if effect.custom_rule == &"solo_active_entity_for_three_turns":
				if not gerencia.campaign.start_solo_exploration(target, 3):
					return {"success": false, "reason": "O isolamento não pôde começar."}
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id, "turns": 3}
			if effect.custom_rule == &"add_wooden_doll_companion":
				if not gerencia.campaign.grant_wooden_doll(target):
					return {"success": false, "reason": "O Bonequinho não encontrou um dono jogável."}
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id, "wooden_doll": true}
		Event_EffectData.EffectType.GRANT_ITEM, \
		Event_EffectData.EffectType.GRANT_RANDOM_ITEM:
			var item := effect.item
			if effect.effect_type == Event_EffectData.EffectType.GRANT_ITEM \
					and effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG:
				item = context.get("decision", {}).get("selected_catalog_item") as ItemData
			if effect.effect_type == Event_EffectData.EffectType.GRANT_RANDOM_ITEM:
				item = (context.get("prepared_random_items", {}) as Dictionary).get(
					effect.get_instance_id()) as ItemData
				if item == null:
					var choices := _eligible_event_items(effect).filter(
						func(candidate: ItemData) -> bool:
							return _inventory_manager.can_receive(target, candidate))
					if choices.is_empty():
						return {"success": false,
							"reason": "Libere espaço no inventário para receber o item."}
					item = choices[_rng.randi_range(0, choices.size() - 1)]
			if not _inventory_manager.add_item(target, item):
				return {"success": false,
					"reason": "Libere espaço no inventário para receber o item."}
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "item": item, "item_name": item.display_name}
		Event_EffectData.EffectType.REMOVE_ITEM:
			var matching := _matching_item_copies(target, effect.item_filter)
			if not effect.remove_all_matching_items and not matching.is_empty():
				matching = [matching.pick_random()]
			var lost: Array[String] = []
			for copy in matching:
				if copy in target.inventory_items:
					target.inventory_items.erase(copy)
				elif not _equipment_manager.consume_equipped_item(target, copy, skill_manager):
					return {"success": false, "reason": "Não foi possível retirar um item equipado."}
				lost.append(copy.data.display_name)
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "items_removed": lost}
		Event_EffectData.EffectType.REMOVE_CURSES:
			var removed_grants := 0
			for grant in target.skill_grants.duplicate():
				if grant == null or grant.source_kind != &"item" \
						or not grant.bound_source is ItemData:
					continue
				var source_item := grant.bound_source as ItemData
				if source_item.item_type == ItemData.ItemType.CURSED \
						or &"cursed" in source_item.tags:
					removed_grants += skill_manager.remove_source(target,
						grant.source_kind, grant.source_id)
			var removed_items: Array[String] = []
			for copy in target.inventory_items.duplicate():
				if copy != null and copy.data != null \
						and (copy.data.item_type == ItemData.ItemType.CURSED \
						or &"cursed" in copy.data.tags):
					target.inventory_items.erase(copy)
					removed_items.append(copy.data.display_name)
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "curses_removed": removed_grants,
				"cursed_items_removed": removed_items}
		Event_EffectData.EffectType.MODIFY_EQUIPPED_ITEM_STAT:
			var selected_copy := context.get("decision", {}).get("selected_item") as InventoryItemState
			if selected_copy == null or selected_copy.data == null:
				return {"success": false, "reason": "Item para aprimorar indisponível."}
			var rolled_item := _roll_value(effect, target, per_target or effect.roll_per_target)
			if not rolled_item.get("success", false):
				return rolled_item
			var amount := _calculated_value(effect, target, int(rolled_item.get("roll", 0)))
			var equipped_now := selected_copy in target.equipped_in_slot(
				selected_copy.data.equipment_slot)
			match selected_copy.data.equipment_slot:
				ItemData.EquipmentSlot.WEAPON:
					if effect.item_statistic_for_weapon != Event_EffectData.ItemStatistic.BONUS_ATTACK:
						return {"success": false, "reason": "Arma sem atributo para aprimorar."}
					selected_copy.improvement_attack += amount
					if equipped_now:
						target.attack += amount
				ItemData.EquipmentSlot.ARMOR:
					if effect.item_statistic_for_armor != Event_EffectData.ItemStatistic.BONUS_LIFE:
						return {"success": false, "reason": "Armadura sem atributo para aprimorar."}
					selected_copy.improvement_life += amount
					if equipped_now:
						target.max_health += amount
						target.current_health += amount
				_:
					return {"success": false, "reason": "O Artesão só aprimora arma ou armadura."}
			if equipped_now:
				target.equipment_changed.emit()
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "item_name": selected_copy.data.display_name,
				"improvement": amount, "roll": int(rolled_item.get("source_die", 0))}
		Event_EffectData.EffectType.GRANT_MOVEMENT_OVERRIDE:
			target.unlimited_exploration_movement = true
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id}
		Event_EffectData.EffectType.APPLY_SKILL_EFFECT:
			if effect.effect.effect_type == SkillEffectData.EffectType.MODIFY_ATTRIBUTE \
					and effect.effect.attribute_id == &"stamina":
				var previous := target.max_stamina
				target.max_stamina += effect.effect.amount
				target.stamina_remaining += effect.effect.amount
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id, "before": previous,
					"after": target.max_stamina}
			var mastery := int(context.get("decision", {}).get("selected_mastery", 0))
			if mastery == EntityData.Mastery.NONE or mastery not in effect.effect.mastery_options:
				return {"success": false, "reason": "Maestria escolhida inválida."}
			if target.has_mastery(mastery):
				target.mastery_bonuses[mastery] = int(target.mastery_bonuses.get(mastery, 0)) + effect.effect.amount
			else:
				target.granted_mastery_types[mastery] = int(target.granted_mastery_types.get(mastery, 0)) + 1
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "mastery": mastery}
		Event_EffectData.EffectType.GRANT_ACTIVE_SKILL, \
		Event_EffectData.EffectType.GRANT_PASSIVE:
			var skill: Resource = effect.active_skill if effect.effect_type == Event_EffectData.EffectType.GRANT_ACTIVE_SKILL else effect.passive
			if effect.effect_type == Event_EffectData.EffectType.GRANT_PASSIVE \
					and effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG \
					and effect.grant_binding_source == Event_EffectData.GrantBindingSource.NONE:
				skill = context.get("decision", {}).get("selected_passive") as PassiveSkillData
			var bound_item := context.get("decision", {}).get("selected_item") as InventoryItemState
			var bound_source: Resource = bound_item.data if bound_item != null else null
			if event.id == &"ev_00058" and bound_item != null \
					and bound_item.data.rarity != ItemData.Rarity.EPIC:
				var evolutions: Array[ItemData] = []
				for candidate in bound_item.data.craft_result:
					if candidate != null and candidate.rarity == ItemData.Rarity.EPIC:
						evolutions.append(candidate)
				if evolutions.is_empty():
					return {"success": false, "reason": "Esta arma não possui evolução Épica."}
				bound_source = evolutions[_rng.randi_range(0, evolutions.size() - 1)]
			if event.id == &"ev_00058" and bound_item != null \
					and bound_source is ItemData:
				# A Simbiose lê atributos de um Resource. Copiamos a receita antes
				# de somar melhorias da instância, sem alterar o catálogo global.
				var evolved := (bound_source as ItemData).duplicate(true) as ItemData
				evolved.bonus_attack += bound_item.improvement_attack
				evolved.bonus_life += bound_item.improvement_life
				evolved.bonus_stamina += bound_item.improvement_stamina
				bound_source = evolved
			if effect.grant_binding_source == Event_EffectData.GrantBindingSource.SELECTED_ENEMY_FROM_LAST_ENCOUNTER:
				bound_source = context.get("decision", {}).get("selected_enemy") as EntityData
			var serial := gerencia.campaign.next_event_grant_serial
			gerencia.campaign.next_event_grant_serial += 1
			var source_id := StringName("%s:%d" % [event.id, serial])
			var grant := skill_manager.grant_skill(target, skill, &"event", source_id,
				gerencia.campaign, bound_source)
			if grant == null:
				return {"success": false, "reason": "A habilidade concedida não pôde ser aplicada."}
			if effect.remove_bound_item_on_grant and bound_item != null:
				if bound_item in target.inventory_items:
					target.inventory_items.erase(bound_item)
				elif not _equipment_manager.consume_equipped_item(target, bound_item, skill_manager):
					skill_manager.remove_source(target, &"event", source_id)
					return {"success": false, "reason": "A arma escolhida não pôde ser absorvida."}
			if event.id == &"ev_00058":
				for other_weapon in target.equipped_weapons.duplicate():
					if not _equipment_manager.unequip(target, other_weapon, skill_manager):
						return {"success": false,
							"reason": "Não foi possível guardar uma arma anterior à Simbiose."}
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "skill_id": skill.id,
				"absorbed_weapon": (bound_source as ItemData).display_name \
				if event.id == &"ev_00058" and bound_source is ItemData else ""}
		Event_EffectData.EffectType.ADD_COMPANION:
			var companion_data := effect.entity
			var bindings: Dictionary = context.get("narrative_bindings", {})
			if effect.entity_selection == Event_EffectData.EntitySelection.RANDOM_PLAYABLE_CHARACTER:
				companion_data = _chosen_playable_ally(bindings)
			elif effect.entity_selection == Event_EffectData.EntitySelection.RANDOM_CURRENT_DISTRICT_ENEMY:
				companion_data = _chosen_district_enemy(bindings)
			if companion_data == null:
				return {"success": false, "reason": "Companheiro sem EntityData."}
			if event.id == &"ev_00065" and gerencia.campaign.has_dead_playable_slot():
				var replacement := gerencia.campaign.replace_dead_playable(
					companion_data, target, skill_manager, _rng)
				if replacement == null:
					return {"success": false,
						"reason": "Não foi possível preencher a vaga do personagem morto."}
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id, "replacement_id": replacement.instance_id,
					"name": companion_data.display_name}
			var companion := EntityState.from_playable_selection(companion_data,
				StringName("Companion_%d" % gerencia.campaign.next_companion_serial),
				EntityState.UNPLACED)
			gerencia.campaign.next_companion_serial += 1
			companion.playable_slot_id = &""
			# Aliado humano equipa, mas só os três jogáveis carregam itens.
			companion.base_inventory_capacity = 0
			skill_manager.ensure_innate_skills(companion)
			if not gerencia.campaign.register_companion(target, companion, _rng,
				skill_manager):
				return {"success": false, "reason": "Não foi possível adicionar o aliado."}
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "companion_id": companion.instance_id,
				"name": companion_data.display_name}
		Event_EffectData.EffectType.REVIVE_DEAD_PLAYABLE:
			var deceased := context.get("decision", {}).get("selected_dead_actor") as EntityState
			var revived := gerencia.campaign.revive_dead_playable(deceased, target,
				skill_manager, _rng)
			if not revived.get("success", false):
				return {"success": false, "reason": "Personagem morto indisponível para ressuscitar."}
			return {"success": true, "effect": effect.effect_type,
				"revived": deceased, "name": deceased.data.display_name,
				"as_companion": revived.get("as_companion", false)}
		Event_EffectData.EffectType.GRANT_STATUS_IMMUNITY:
			for status_id in effect.status_ids:
				if effect.has_duration and effect.expiration_mode \
						== Event_EffectData.ExpirationMode.END_OF_CURRENT_DAY:
					gerencia.campaign.add_day_status_immunity(target, status_id)
				elif status_id not in target.permanent_status_immunities:
					target.permanent_status_immunities.append(status_id)
				# Imunidade também limpa um Debuff antigo do mesmo tipo.
				skill_manager.debuff_manager.remove_debuff(target, status_id)
			if &"cursed" in effect.immunity_item_tags:
				target.permanent_curse_immunity = true
				for entry in target.inventory_items.duplicate():
					if entry != null and entry.data != null \
							and entry.data.item_type == ItemData.ItemType.CURSED:
						target.inventory_items.erase(entry)
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id,
				"expires_day": gerencia.campaign.day + 1 if effect.has_duration else 0}
		Event_EffectData.EffectType.IGNORE_RANGED_CRITICAL_BONUS:
			if effect.incoming_attack_range == Event_EffectData.IncomingAttackRange.RANGED:
				target.ignore_ranged_critical_bonus = true
				return {"success": true, "effect": effect.effect_type,
					"target": target.instance_id}
			return {"success": false, "reason": "A proteção contra crítico não identifica alcance."}
	if event.id == &"ev_00019" and effect.effect_type == Event_EffectData.EffectType.MODIFY_STAT \
			and effect.statistic == Event_EffectData.Statistic.STAMINA and effect.has_duration:
		var old_stamina := target.max_stamina
		gerencia.campaign.add_temporary_stamina_loss(target, effect.amount,
			effect.duration_amount)
		return {"success": true, "effect": effect.effect_type,
			"target": target.instance_id, "before": old_stamina,
			"after": target.max_stamina, "turns": effect.duration_amount}
	if event.id == &"ev_00022" and effect.execution_mode \
			== Event_EffectData.ExecutionMode.REPEAT_ON_TRIGGER:
		gerencia.campaign.add_ghost_pursuit(target, effect.amount)
		return {"success": true, "effect": effect.effect_type,
			"target": target.instance_id, "damage_per_turn": effect.amount,
			"expires_day": gerencia.campaign.day + 1}
	var rolled := _roll_value(effect, target, per_target or effect.roll_per_target)
	if not rolled.get("success", false):
		return rolled
	var value := _calculated_value(effect, target, int(rolled.get("roll", 0)))
	var before := 0
	match effect.effect_type:
		Event_EffectData.EffectType.MODIFY_HP:
			before = target.current_health
			target.current_health = clampi(_operate(before, value, effect.math_operation),
				0, target.max_health)
		Event_EffectData.EffectType.MODIFY_MAX_HP:
			before = target.max_health
			target.max_health = maxi(1, _operate(before, value, effect.math_operation))
			target.current_health = mini(target.current_health, target.max_health)
		Event_EffectData.EffectType.MODIFY_STAT:
			match effect.statistic:
				Event_EffectData.Statistic.HP:
					before = target.current_health
					target.current_health = clampi(_operate(before, value, effect.math_operation),
						0, target.max_health)
				Event_EffectData.Statistic.MAX_HP:
					before = target.max_health
					target.max_health = maxi(1, _operate(before, value, effect.math_operation))
					target.current_health = mini(target.current_health, target.max_health)
				Event_EffectData.Statistic.ATTACK:
					before = target.attack
					target.attack = maxi(effect.stat_minimum if effect.clamp_stat_minimum else 0,
						_operate(before, value, effect.math_operation))
				Event_EffectData.Statistic.STAMINA:
					before = target.max_stamina
					target.max_stamina = maxi(effect.stat_minimum if effect.clamp_stat_minimum else 0,
						_operate(before, value, effect.math_operation))
					target.stamina_remaining = mini(target.stamina_remaining, target.max_stamina)
		Event_EffectData.EffectType.APPLY_STATUS:
			var applied := skill_manager.apply_event_status(effect, target, null,
				gerencia.campaign, value, event.id, int(rolled.get("source_die", 0)))
			if not applied.get("success", false) and not applied.get("immune", false) \
					and target.current_health > 0:
				return {"success": false, "reason": applied.get("reason", "Debuff não aplicado.")}
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "status_id": effect.debuff.id,
				"duration": int(rolled.get("source_die", effect.duration_amount)),
				"immune": applied.get("immune", false)}
		Event_EffectData.EffectType.REMOVE_STATUS:
			var ids: Array[StringName] = effect.status_ids.duplicate()
			if effect.debuff != null and effect.debuff.id not in ids:
				ids.append(effect.debuff.id)
			if ids.is_empty():
				ids = skill_manager.debuff_manager.get_debuff_ids(target)
			var removed := skill_manager.debuff_manager.remove_debuffs(target, ids)
			return {"success": true, "effect": effect.effect_type,
				"target": target.instance_id, "removed": removed}
	var after := _stat_after(effect, target)
	return {"success": true, "effect": effect.effect_type,
		"target": target.instance_id, "before": before, "after": after,
		"roll": int(rolled.get("roll", 0))}


func _stat_after(effect: Event_EffectData, target: EntityState) -> int:
	if effect.effect_type == Event_EffectData.EffectType.MODIFY_HP or \
			(effect.effect_type == Event_EffectData.EffectType.MODIFY_STAT \
			and effect.statistic == Event_EffectData.Statistic.HP):
		return target.current_health
	if effect.effect_type == Event_EffectData.EffectType.MODIFY_MAX_HP or \
			(effect.effect_type == Event_EffectData.EffectType.MODIFY_STAT \
			and effect.statistic == Event_EffectData.Statistic.MAX_HP):
		return target.max_health
	return target.attack if effect.statistic == Event_EffectData.Statistic.ATTACK \
		else target.max_stamina


func _roll_value(effect: Event_EffectData, target: EntityState, per_target: bool) -> Dictionary:
	var key := str(effect.shared_roll_id)
	if per_target:
		key += ":" + str(target.instance_id)
	if effect.value_source == Event_EffectData.ValueSource.SHARED_ROLL:
		if key not in _shared_rolls:
			return {"success": false, "reason": "O dado compartilhado deste resultado não foi lançado."}
		return (_shared_rolls[key] as Dictionary).duplicate()
	# Todos os alvos do mesmo efeito usam a mesma rolagem, salvo quando o
	# próprio Outcome/Effect pede explicitamente uma rolagem por alvo.
	if effect.shared_roll_id != &"" and key in _shared_rolls:
		return (_shared_rolls[key] as Dictionary).duplicate()
	var total := 0
	var die_result := 0
	for index in effect.dice_count:
		var die := gerencia.campaign.player_dice_luck.roll_for_player(_rng) \
			if effect.dice_sides == 6 else _rng.randi_range(1, effect.dice_sides)
		total += die
		die_result = die
		_recent_dice_results.append(die)
	var rolled := roundi(float(total) * effect.dice_result_multiplier)
	var result := {"success": true, "roll": rolled, "source_die": die_result}
	if effect.shared_roll_id != &"":
		_shared_rolls[key] = result.duplicate()
	return result


func _calculated_value(effect: Event_EffectData, target: EntityState, rolled: int) -> int:
	var basis := float(effect.amount + rolled)
	match effect.value_source:
		Event_EffectData.ValueSource.CURRENT_HP:
			basis = float(target.current_health)
		Event_EffectData.ValueSource.MISSING_HP:
			basis = float(target.max_health - target.current_health)
		Event_EffectData.ValueSource.SHARED_ROLL:
			basis = float(rolled)
		Event_EffectData.ValueSource.TARGET_STATISTIC:
			basis = float(_stat_after(effect, target))
	if effect.percent > 0.0:
		basis *= effect.percent
	match effect.rounding_mode:
		Event_EffectData.RoundingMode.CEIL: return ceili(basis)
		Event_EffectData.RoundingMode.NEAREST: return roundi(basis)
	return floori(basis)


func _operate(before: int, value: int, operation: int) -> int:
	match operation:
		Event_EffectData.MathOperation.ADD: return before + value
		Event_EffectData.MathOperation.SUBTRACT: return before - value
		Event_EffectData.MathOperation.MULTIPLY: return before * value
		Event_EffectData.MathOperation.DIVIDE: return floori(float(before) / float(maxi(1, value)))
	return value


func _on_block_finished(_result: Dictionary) -> void:
	_prepared.clear()
	_pending_result.clear()
	_event_combat_waiting.clear()
	_chained_event_parent.clear()
	_shared_rolls.clear()
	_random_target_groups.clear()
	_narrative_key = ""
	_narrative_bindings.clear()
