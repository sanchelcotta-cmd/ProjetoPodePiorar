class_name SkillEffectExecutor
extends RefCounted

## O Resource diz O QUE acontece. Este executor aplica somente os tipos que já
## têm comportamento real. Um efeito desconhecido nunca é tratado como sucesso.


## Prepara alterações que acontecem UMA vez quando a passiva é recebida.
## Não altera o ator aqui: o SkillManager confirma todas as etapas primeiro.
func plan_on_granted(effect: SkillEffectData, actor: EntityState, bound_source: Resource = null) -> Dictionary:
	if effect == null or actor == null:
		return {"success": false}
	var stats: Dictionary = {}
	var passives: Array[PassiveSkillData] = []
	match effect.effect_type:
		SkillEffectData.EffectType.MODIFY_MASTERY:
			if effect.scaling_source != SkillEffectData.ScalingSource.NONE \
					or effect.mastery_options.is_empty() or effect.amount < 0:
				return {"success": false}
			for mastery in effect.mastery_options:
				if mastery == EntityData.Mastery.NONE:
					continue
				if effect.mastery_grant_mode == SkillEffectData.MasteryGrantMode.GRANT_IF_MISSING_ELSE_ADD_LEVEL \
						and not actor.has_mastery(mastery):
					stats["mastery_presence:%d" % mastery] = 1
				else:
					stats["mastery:%d" % mastery] = effect.amount
			return {"success": true, "stats": stats, "passives": passives}
		SkillEffectData.EffectType.COPY_BOUND_SOURCE_TRAITS:
			if bound_source is ItemData:
				var item := bound_source as ItemData
				if effect.copy_bound_bonus_attack: stats["attack"] = item.bonus_attack
				if effect.copy_bound_bonus_max_hp: stats["max_hp"] = item.bonus_life
				if effect.copy_bound_bonus_stamina: stats["stamina"] = item.bonus_stamina
				if effect.copy_bound_masteries and item.mastery_granted != EntityData.Mastery.NONE:
					stats["mastery_presence:%d" % item.mastery_granted] = 1
					stats["mastery:%d" % item.mastery_granted] = item.mastery_bonus
				if effect.copy_bound_passives:
					passives.append_array(item.granted_passives)
			elif bound_source is EntityData:
				var entity := bound_source as EntityData
				if effect.copy_bound_attack_base_as_bonus: stats["attack"] = entity.ataque_base
				if effect.copy_bound_max_hp_base_as_bonus: stats["max_hp"] = entity.vida_base
				if effect.copy_bound_masteries:
					for mastery in entity.maestrias:
						if mastery != EntityData.Mastery.NONE:
							stats["mastery_presence:%d" % mastery] = 1
				if effect.copy_bound_passives:
					passives.append_array(entity.skill_passivas)
			else:
				return {"success": false, "reason": "Falta o item ou inimigo escolhido para copiar."}
			return {"success": true, "stats": stats, "passives": passives}
	return {"success": false, "reason": "Efeito de concessão ainda não executável."}


## Efeito contínuo não é somado a cada turno. Quem precisa da regra consulta
## o Resource enquanto a concessão estiver presente; removê-la encerra a regra.
func supports_continuous(effect: SkillEffectData) -> bool:
	if effect == null:
		return false
	match effect.effect_type:
		SkillEffectData.EffectType.IGNORE_ATTACK_RANGE, SkillEffectData.EffectType.FORCE_TARGET_PRIORITY, SkillEffectData.EffectType.RESTRICT_EQUIPMENT, SkillEffectData.EffectType.GRANT_STATUS_IMMUNITY:
			return true
		SkillEffectData.EffectType.SET_CRITICAL_ROLL_THRESHOLD:
			return effect.minimum_value >= 1 and effect.minimum_value <= 6
		SkillEffectData.EffectType.MODIFY_EQUIPMENT_SLOT_CAPACITY:
			return effect.amount > 0 and effect.equipment_slot_id != &""
		SkillEffectData.EffectType.MODIFY_INVENTORY_CAPACITY:
			return effect.amount > 0
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT:
			return effect.recalculate_bonus_instead_of_stacking \
				and not effect.attribute_ids.is_empty()
	return false


## Neste estágio, ataque extra vira estado de combate. Outros efeitos só
## serão aceitos quando seu executor concreto existir.
func can_execute_passive(effect: SkillEffectData, context: Dictionary) -> bool:
	if effect == null or effect.activation_chance != 1.0 \
			or context.get("actor") is not EntityState:
		return false
	if _bound_mastery_does_not_match(effect, context):
		return true
	if _attack_equipment_does_not_match(effect, context):
		return true
	if effect.requires_counterparty_entity_data_matches_bound_id \
			and not _bound_counterparty_matches(effect, context):
		return false
	match effect.effect_type:
		SkillEffectData.EffectType.MULTIPLY_OUTGOING_ATTACK_RESULT:
			return effect.multiplier > 0.0 and context.get("attack_target") is EntityState
		SkillEffectData.EffectType.MULTIPLY_INCOMING_DAMAGE:
			return effect.multiplier > 0.0 and int(context.get("incoming_damage", 0)) > 0
		SkillEffectData.EffectType.APPLY_DEBUFF, SkillEffectData.EffectType.REMOVE_DEBUFF:
			var manager := context.get("skill_manager") as SkillManager
			return manager != null and manager.can_apply_debuff_effect(effect, context)
		SkillEffectData.EffectType.REDUCE_INCOMING_DAMAGE:
			return effect.target == SkillEffectData.Target.SELF \
				and effect.percent > 0.0 and effect.percent <= 1.0 \
				and int(context.get("incoming_damage", 0)) > 0
		SkillEffectData.EffectType.DEAL_FIXED_DAMAGE:
			return effect.target == SkillEffectData.Target.ALL_ALLIES \
				and effect.value_source == SkillEffectData.ValueSource.FIXED \
				and effect.dice_count > 0 and effect.dice_sides > 0 \
				and context.get("campaign") is CampaignState \
				and context.get("skill_manager") is SkillManager
		SkillEffectData.EffectType.ADD_EXTRA_ATTACK:
			return effect.amount > 0 and context.get("mode") == HexGrid.PPPMapMode.COMBAT
		SkillEffectData.EffectType.HEAL_PERCENT_OF_DAMAGE_DEALT:
			return effect.target == SkillEffectData.Target.SELF \
				and effect.percent > 0.0 and effect.percent <= 1.0 \
				and int(context.get("damage_dealt", 0)) > 0
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			if effect.target != SkillEffectData.Target.SELF \
					or effect.attribute_id != &"attack" \
					or not context.get("combat") is CombatManager:
				return false
			return effect.multiplier > 0.0 if effect.modify_mode == SkillEffectData.ModifyMode.MULTIPLY \
				else effect.amount > 0
		SkillEffectData.EffectType.COUNTERATTACK:
			return effect.target == SkillEffectData.Target.DAMAGE_SOURCE \
				and context.get("combat") is CombatManager
		SkillEffectData.EffectType.MOVE_AWAY_FROM_TARGET:
			return context.get("combat") is CombatManager \
				and context.get("attack_target") is EntityState \
				and int(context.get("hexes_moved_this_turn", 0)) >= 2
		SkillEffectData.EffectType.DODGE_INCOMING_ATTACK:
			return context.get("combat") is CombatManager \
				and (context["combat"] as CombatManager).has_dodge_destination(
					context["actor"] as EntityState)
		SkillEffectData.EffectType.HEAL_FIXED:
			return effect.target == SkillEffectData.Target.SELF and effect.amount > 0 \
				and effect.value_source == SkillEffectData.ValueSource.FIXED \
				and effect.dice_count == 0
		SkillEffectData.EffectType.RANDOMIZE_MASTERY:
			return context.get("encounter_opening", false) \
				and context.get("mode") == HexGrid.PPPMapMode.COMBAT \
				and not effect.mastery_options.is_empty()
		SkillEffectData.EffectType.SET_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT:
			return context.get("encounter_opening", false) \
				and context.get("campaign") is CampaignState \
				and effect.attribute_id in [&"attack", &"stamina"]
		SkillEffectData.EffectType.END_COMBAT:
			return context.get("encounter_opening", false) \
				and context.get("mode") == HexGrid.PPPMapMode.COMBAT
		SkillEffectData.EffectType.CHANGE_ALLEGIANCE:
			var combat := context.get("combat") as CombatManager
			var owner := context.get("encounter_activator") as EntityState
			return context.get("encounter_opening", false) \
				and context.get("player_confirmed", false) and combat != null \
				and owner != null \
				and (context["actor"] as EntityState) in combat.enemies
	return false


func execute_passive(effect: SkillEffectData, context: Dictionary) -> Dictionary:
	if not can_execute_passive(effect, context):
		return {"success": false, "reason": "Efeito passivo ainda não executável."}
	if _bound_mastery_does_not_match(effect, context):
		return {"success": true, "skipped": true}
	if _attack_equipment_does_not_match(effect, context):
		return {"success": true, "skipped": true}
	var actor := context["actor"] as EntityState
	match effect.effect_type:
		SkillEffectData.EffectType.MULTIPLY_OUTGOING_ATTACK_RESULT:
			return {"success": true, "damage_multiplier": effect.multiplier}
		SkillEffectData.EffectType.MULTIPLY_INCOMING_DAMAGE:
			return {"success": true, "incoming_damage_multiplier": effect.multiplier}
		SkillEffectData.EffectType.APPLY_DEBUFF, SkillEffectData.EffectType.REMOVE_DEBUFF:
			var manager := context.get("skill_manager") as SkillManager
			return manager.apply_debuff_effect(effect, context)
		SkillEffectData.EffectType.REDUCE_INCOMING_DAMAGE:
			# Cada fonte reduz o dano que restou. O arredondamento é feito uma
			# única vez, depois que todas as Proteções forem aplicadas.
			return {"success": true, "remaining_fraction": 1.0 - effect.percent}
		SkillEffectData.EffectType.DEAL_FIXED_DAMAGE:
			var campaign := context["campaign"] as CampaignState
			var manager := context["skill_manager"] as SkillManager
			var targets: Array[EntityState] = manager.get_allies_for_passive(actor, campaign, context)
			if targets.is_empty():
				return {"success": false, "reason": "Grupo da fonte não identificado."}
			var rng := context.get("rng") as RandomNumberGenerator
			var shared_roll := _roll_dice(effect.dice_count, effect.dice_sides, rng) \
				if not effect.roll_per_target else 0
			var damage_results: Array[Dictionary] = []
			for target in targets:
				if target.current_health <= 0:
					continue
				var rolled := _roll_dice(effect.dice_count, effect.dice_sides, rng) \
					if effect.roll_per_target else shared_roll
				var result := manager.apply_incoming_damage(target, rolled, campaign,
					{"mode": context.get("mode", HexGrid.PPPMapMode.EXPLORATION),
					"damage_source": actor,
					"generated_damage_can_trigger_passives": effect.generated_damage_can_trigger_passives}, rng)
				damage_results.append({"target": target, "roll": rolled, "damage": result})
			return {"success": true, "targets": damage_results}
		SkillEffectData.EffectType.ADD_EXTRA_ATTACK:
			actor.extra_attacks_this_turn += effect.amount
			return {"success": true, "extra_attacks": effect.amount}
		SkillEffectData.EffectType.HEAL_PERCENT_OF_DAMAGE_DEALT:
			var dealt := int(context.get("damage_dealt", 0))
			var recovered := floori(float(dealt) * effect.percent)
			var before := actor.current_health
			actor.current_health = mini(actor.max_health, before + recovered)
			return {"success": true, "healed": actor.current_health - before}
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			var combat := context["combat"] as CombatManager
			return combat.apply_passive_attack_bonus(actor, effect)
		SkillEffectData.EffectType.COUNTERATTACK:
			var combat := context["combat"] as CombatManager
			return combat.try_passive_counterattack(actor,
				context.get("damage_source") as EntityState)
		SkillEffectData.EffectType.MOVE_AWAY_FROM_TARGET:
			var combat := context["combat"] as CombatManager
			return combat.move_after_attack(actor, context["attack_target"] as EntityState,
				floori(float(context.get("hexes_moved_this_turn", 0)) / 2.0))
		SkillEffectData.EffectType.DODGE_INCOMING_ATTACK:
			var combat := context["combat"] as CombatManager
			return combat.dodge_to_adjacent(actor,
				context.get("damage_source") as EntityState)
		SkillEffectData.EffectType.HEAL_FIXED:
			var before := actor.current_health
			actor.current_health = mini(actor.max_health, before + effect.amount)
			return {"success": true, "healed": actor.current_health - before}
		SkillEffectData.EffectType.RANDOMIZE_MASTERY:
			var rng := context.get("rng") as RandomNumberGenerator
			var index := rng.randi_range(0, effect.mastery_options.size() - 1) \
				if rng != null else randi_range(0, effect.mastery_options.size() - 1)
			actor.encounter_mastery_override = effect.mastery_options[index]
			return {"success": true, "mastery": actor.encounter_mastery_override}
		SkillEffectData.EffectType.SET_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT:
			var campaign := context["campaign"] as CampaignState
			var count := campaign.obtained_information_ids.size()
			var cap := 999
			var district_index := effect.context_tags.find(campaign.district)
			if district_index >= 0 and district_index < effect.context_caps.size():
				cap = effect.context_caps[district_index]
			var value := mini(count, cap)
			if effect.attribute_id == &"attack":
				actor.attack = value
			else:
				actor.max_stamina = value
				actor.stamina_remaining = value
			return {"success": true, "attribute": effect.attribute_id, "value": value}
		SkillEffectData.EffectType.END_COMBAT:
			# A montagem/iniciativa e a confirmação narrativa pertencem ao
			# CombatManager; uma passiva não encerra o bloco de forma síncrona.
			return {"success": true, "end_combat_requested": true}
		SkillEffectData.EffectType.CHANGE_ALLEGIANCE:
			var combat := context["combat"] as CombatManager
			return combat.convert_enemy_to_companion(
				context["encounter_activator"] as EntityState, actor, effect, false)
	return {"success": false}


func _roll_dice(count: int, sides: int, rng: RandomNumberGenerator) -> int:
	var total := 0
	for die in count:
		total += rng.randi_range(1, sides) if rng != null else randi_range(1, sides)
	return total


func _bound_mastery_does_not_match(effect: SkillEffectData, context: Dictionary) -> bool:
	if effect.required_bound_source_mastery == EntityData.Mastery.NONE:
		return false
	var grant := context.get("grant") as SkillGrantState
	var item := grant.bound_source as ItemData if grant != null else null
	return item == null or item.mastery_granted != effect.required_bound_source_mastery


func _attack_equipment_does_not_match(effect: SkillEffectData,
		context: Dictionary) -> bool:
	if effect.effect_type != SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
		return false
	var has_weapon := bool(context.get("has_weapon_for_attack", false))
	return (effect.requires_melee_weapon_equipped \
		and (not context.get("is_melee_attack", false) or not has_weapon)) \
		or (effect.requires_no_weapon_equipped and has_weapon)


func _bound_counterparty_matches(effect: SkillEffectData,
		context: Dictionary) -> bool:
	var grant := context.get("grant") as SkillGrantState
	var bound_type := grant.bound_source as EntityData if grant != null else null
	if bound_type == null:
		return false
	var counterparty := context.get("attack_target") as EntityState \
		if effect.effect_type == SkillEffectData.EffectType.MULTIPLY_OUTGOING_ATTACK_RESULT \
		else context.get("damage_source") as EntityState
	return counterparty != null and counterparty.data != null \
		and counterparty.data.id == bound_type.id


func supports(effect: SkillEffectData) -> bool:
	if effect == null:
		return false
	match effect.effect_type:
		SkillEffectData.EffectType.APPLY_DEBUFF, SkillEffectData.EffectType.REMOVE_DEBUFF:
			return effect.debuff_id != &"" or not effect.status_ids.is_empty()
		SkillEffectData.EffectType.REVEAL_BLOCKS:
			return effect.target in [SkillEffectData.Target.SELF, SkillEffectData.Target.SELECTED_TILE] \
				and effect.reveal_detail == SkillEffectData.RevealDetail.TYPE_ONLY
		SkillEffectData.EffectType.DESTROY_TILE:
			return effect.target == SkillEffectData.Target.CURRENT_TILE
		SkillEffectData.EffectType.POSITION_COMPANION:
			return effect.target == SkillEffectData.Target.SELECTED_TILE
		SkillEffectData.EffectType.GRANT_EXTRA_MOVEMENT:
			return effect.target == SkillEffectData.Target.SELF and effect.amount > 0
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			return effect.target == SkillEffectData.Target.SELF \
				and effect.attribute_id == &"stamina_base" \
				and effect.modify_mode == SkillEffectData.ModifyMode.SUBTRACT \
				and effect.amount > 0 and effect.has_duration \
				and effect.duration_unit == SkillEffectData.DurationUnit.ROUND
		SkillEffectData.EffectType.GRANT_RANDOM_ITEM:
			return effect.target in [SkillEffectData.Target.SELF, SkillEffectData.Target.OWNER] \
				and effect.amount == 1
		SkillEffectData.EffectType.SET_COMPANION_UNAVAILABLE:
			return effect.target == SkillEffectData.Target.SELF \
				and effect.has_duration and effect.duration_turns > 0
		SkillEffectData.EffectType.MODIFY_CRAFT_COST:
			return effect.target == SkillEffectData.Target.SELF and effect.amount < 0
		SkillEffectData.EffectType.TELEPORT:
			return effect.target == SkillEffectData.Target.SELECTED_TILE
		SkillEffectData.EffectType.TRANSFORM_INVENTORY_ITEM:
			return effect.target == SkillEffectData.Target.SELECTED_ITEM \
				and effect.required_item_rarity == SkillEffectData.ItemRarityFilter.COMMON
	return false


func can_execute(effect: SkillEffectData, context: Dictionary) -> bool:
	if not supports(effect):
		return false
	if effect.effect_type in [SkillEffectData.EffectType.APPLY_DEBUFF,
			SkillEffectData.EffectType.REMOVE_DEBUFF]:
		var manager := context.get("skill_manager") as SkillManager
		return manager != null and manager.can_apply_debuff_effect(effect, context)
	var grid := context.get("grid") as HexGrid
	var actor := context.get("actor") as EntityState
	if grid == null or actor == null:
		return false
	var selected: Vector2i = context.get("selected_tile", EntityState.UNPLACED)
	match effect.effect_type:
		SkillEffectData.EffectType.REVEAL_BLOCKS:
			if effect.target == SkillEffectData.Target.SELECTED_TILE:
				var cell := grid.get_cell(selected)
				# O Gatinho revela a vizinhança; o centro pode já estar revelado.
				return cell != null and (effect.area_radius > 0 or cell.state == HexGrid.PPPBlockState.HIDDEN)
			return effect.target == SkillEffectData.Target.SELF \
				and context.get("skill") is ActiveSkillData \
				and (effect.scaling_source != SkillEffectData.ScalingSource.GROUP_INFORMATION_COUNT \
				or not _reveal_candidates(effect, context).is_empty())
		SkillEffectData.EffectType.DESTROY_TILE:
			if effect.target != SkillEffectData.Target.CURRENT_TILE or selected != actor.position:
				return false
			var block := context.get("block_manager") as BlockManager
			if block == null or not block.can_destroy_landed_event(selected):
				return false
			var event := grid.get_ppp_block_resource(selected) as EventData
			return event != null \
				and (effect.allowed_event_categories.is_empty() or event.category in effect.allowed_event_categories) \
				and (effect.allowed_event_valences.is_empty() or event.valence in effect.allowed_event_valences)
		SkillEffectData.EffectType.POSITION_COMPANION:
			if effect.target != SkillEffectData.Target.SELECTED_TILE \
					or actor.owner_instance_id == &"" or not grid.is_valid(selected):
				return false
			for entity in context.get("entities", []):
				if entity != actor and entity.position == selected and entity.current_health > 0:
					return false
			return true
		SkillEffectData.EffectType.GRANT_EXTRA_MOVEMENT:
			return effect.target == SkillEffectData.Target.SELF and effect.amount > 0 \
				and actor == context.get("turn_owner") and context.get("grant") is SkillGrantState
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			return effect.target == SkillEffectData.Target.SELF \
				and effect.attribute_id == &"stamina_base" \
				and effect.modify_mode == SkillEffectData.ModifyMode.SUBTRACT \
				and effect.amount > 0 and effect.has_duration \
				and effect.duration_unit == SkillEffectData.DurationUnit.ROUND \
				and context.get("campaign") is CampaignState
		SkillEffectData.EffectType.GRANT_RANDOM_ITEM:
			var inventory := context.get("inventory_manager") as InventoryManager
			return inventory != null and context.get("campaign") is CampaignState \
				and not inventory.get_eligible_items(effect).is_empty()
		SkillEffectData.EffectType.SET_COMPANION_UNAVAILABLE:
			var owner := context.get("turn_owner") as EntityState
			return owner != null and actor.owner_instance_id != &"" \
				and actor.owner_instance_id == owner.instance_id
		SkillEffectData.EffectType.MODIFY_CRAFT_COST:
			var inventory := context.get("inventory_manager") as InventoryManager
			var selection: Dictionary = context.get("selection", {})
			return inventory != null and inventory.can_craft(
				actor, selection.get("ingredient_id", &""),
				selection.get("result_id", &""), 3 + effect.amount
			)
		SkillEffectData.EffectType.TELEPORT:
			if not grid.is_valid(selected) or actor.position == selected:
				return false
			var occupied: Dictionary = {}
			for entity in context.get("entities", []):
				if entity != actor and entity != null and entity.current_health > 0 \
						and grid.is_valid(entity.position):
					occupied[entity.position] = true
			return grid.can_choose_ppp_destination(selected, actor.position, occupied) \
				and grid.get_ppp_block_resource(selected) != null
		SkillEffectData.EffectType.TRANSFORM_INVENTORY_ITEM:
			var inventory := context.get("inventory_manager") as InventoryManager
			var selection: Dictionary = context.get("selection", {})
			return inventory != null and inventory.can_transform_single_item(actor,
				selection.get("selected_item") as InventoryItemState,
				selection.get("result_item") as ItemData)
	return false


func execute(effect: SkillEffectData, context: Dictionary) -> Dictionary:
	if not can_execute(effect, context):
		return {"success": false, "reason": "Efeito indisponível neste contexto."}
	if effect.activation_chance < 1.0 and randf() >= effect.activation_chance:
		return {"success": true, "chance_failed": true}
	if effect.effect_type in [SkillEffectData.EffectType.APPLY_DEBUFF,
			SkillEffectData.EffectType.REMOVE_DEBUFF]:
		var manager := context.get("skill_manager") as SkillManager
		return manager.apply_debuff_effect(effect, context)
	var grid := context.get("grid") as HexGrid
	var actor := context.get("actor") as EntityState
	var selected: Vector2i = context.get("selected_tile", EntityState.UNPLACED)
	var view := context.get("view") as PPPMapView
	match effect.effect_type:
		SkillEffectData.EffectType.REVEAL_BLOCKS:
			var revealed: Array[Vector2i] = []
			var revealed_types: Dictionary = {}
			for coord in _reveal_candidates(effect, context):
				revealed_types[coord] = grid.get_ppp_block_type(coord)
				if effect.reveal_presentation == SkillEffectData.RevealPresentation.PERSISTENT:
					var skill := context.get("skill") as ActiveSkillData
					if skill != null:
						var sources: Array = grid.revealed_by_skill_ids.get(coord, [])
						if skill.id not in sources:
							sources.append(skill.id)
						grid.revealed_by_skill_ids[coord] = sources
					if view != null and view.grid == grid:
						view.reveal_block(coord)
					else:
						grid.reveal_ppp_block(coord)
				revealed.append(coord)
			if effect.reveal_presentation == SkillEffectData.RevealPresentation.TEMPORARY_TITLE_INSPECTION \
					and view != null and view.grid == grid:
				view.set_temporary_inspection(actor, revealed)
			return {"success": true, "revealed_tiles": revealed, "block_types": revealed_types}
		SkillEffectData.EffectType.DESTROY_TILE:
			var block := context.get("block_manager") as BlockManager
			var skill := context.get("skill") as ActiveSkillData
			return {"success": block.destroy_event_before_activation(selected, actor, skill.id), "destroyed_tile": selected}
		SkillEffectData.EffectType.POSITION_COMPANION:
			actor.position = selected
			return {"success": true, "positioned_tile": selected}
		SkillEffectData.EffectType.GRANT_EXTRA_MOVEMENT:
			var grant := context.get("grant") as SkillGrantState
			for index in effect.amount:
				actor.extra_movement_sources.append(grant)
			return {"success": true, "extra_movements": effect.amount}
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			var campaign := context.get("campaign") as CampaignState
			return {"success": actor.apply_round_stamina_penalty(effect.amount, campaign.get_round_index())}
		SkillEffectData.EffectType.SET_COMPANION_UNAVAILABLE:
			var owner := context.get("turn_owner") as EntityState
			actor.unavailable_until_owner_turn_serial = maxi(
				actor.unavailable_until_owner_turn_serial,
				owner.turn_serial + effect.duration_turns
			)
			return {"success": true, "returns_on_owner_turn": actor.unavailable_until_owner_turn_serial}
		SkillEffectData.EffectType.GRANT_RANDOM_ITEM:
			var campaign := context.get("campaign") as CampaignState
			var owner := context.get("turn_owner") as EntityState
			var recipient := actor if effect.target == SkillEffectData.Target.SELF else owner
			if effect.delay_turns > 0 and not context.get("resolving_delay", false):
				campaign.delayed_skill_effects.append(DelayedSkillEffectState.new(
					actor, owner.instance_id, effect, owner.turn_serial + effect.delay_turns
				))
				return {"success": true, "delayed_until_owner_turn": owner.turn_serial + effect.delay_turns}
			var inventory := context.get("inventory_manager") as InventoryManager
			var item := inventory.draw_random_item(effect)
			return inventory.deliver_created_item(recipient, item, campaign)
		SkillEffectData.EffectType.MODIFY_CRAFT_COST:
			var inventory := context.get("inventory_manager") as InventoryManager
			var selection: Dictionary = context.get("selection", {})
			return inventory.craft(actor, selection["ingredient_id"], selection["result_id"],
				3 + effect.amount, context.get("skill_manager") as SkillManager)
		SkillEffectData.EffectType.TELEPORT:
			return {"success": true, "teleport_to": selected}
		SkillEffectData.EffectType.TRANSFORM_INVENTORY_ITEM:
			var inventory := context.get("inventory_manager") as InventoryManager
			var selection: Dictionary = context.get("selection", {})
			return inventory.transform_single_item(actor,
				selection["selected_item"], selection["result_item"])
	return {"success": false, "reason": "Efeito ainda não implementado."}


func _reveal_candidates(effect: SkillEffectData, context: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var grid := context.get("grid") as HexGrid
	if effect.scaling_source == SkillEffectData.ScalingSource.GROUP_INFORMATION_COUNT \
			and effect.selection_mode == SkillEffectData.SelectionMode.RANDOM_FROM_OPTIONS:
		var campaign := context.get("campaign") as CampaignState
		if campaign == null:
			return result
		var count := campaign.obtained_information_ids.size()
		if effect.max_items_affected > 0:
			count = mini(count, effect.max_items_affected)
		if count <= 0:
			return result
		for coord in grid.cells:
			var cell := grid.get_cell(coord)
			if cell != null and cell.state == HexGrid.PPPBlockState.HIDDEN:
				result.append(coord)
		result.shuffle()
		result.resize(mini(count, result.size()))
		return result
	var actor := context.get("actor") as EntityState
	var selected: Vector2i = context.get("selected_tile", EntityState.UNPLACED)
	var center := selected if effect.target == SkillEffectData.Target.SELECTED_TILE else actor.position
	var skill := context.get("skill") as ActiveSkillData
	var radius := effect.area_radius
	if effect.target == SkillEffectData.Target.SELF and skill.target_mode == ActiveSkillData.TargetMode.AREA:
		radius = int(context.get("range", 0))
	for coord in grid.cells:
		if HexGrid.distance(center, coord) > radius or (coord == center and not effect.include_center_tile):
			continue
		var cell := grid.get_cell(coord)
		if cell.state != HexGrid.PPPBlockState.HIDDEN \
				and (effect.reveal_presentation != SkillEffectData.RevealPresentation.TEMPORARY_TITLE_INSPECTION \
				or cell.state != HexGrid.PPPBlockState.REVEALED):
			continue
		if not effect.tags_filter.is_empty() and not _has_requested_tag(effect.tags_filter, grid, coord):
			continue
		result.append(coord)
	return result


func _has_requested_tag(wanted: Array[StringName], grid: HexGrid, coord: Vector2i) -> bool:
	var present: Array[StringName] = []
	match grid.get_ppp_block_type(coord):
		HexGrid.PPPBlockType.INFORMATION: present.append(&"informacao")
		HexGrid.PPPBlockType.CONSUMABLE: present.append(&"consumivel")
		HexGrid.PPPBlockType.EQUIPMENT: present.append(&"equipamento")
		HexGrid.PPPBlockType.ENCOUNTER: present.append(&"encontro_indesejado")
		HexGrid.PPPBlockType.CATASTROPHE: present.append(&"catastrophe")
		HexGrid.PPPBlockType.TRAP: present.append(&"trap")
		HexGrid.PPPBlockType.CURSE: present.append(&"cursed")
		HexGrid.PPPBlockType.EVENT: present.append(&"event")
	var content := grid.get_ppp_block_resource(coord)
	if content is EventData:
		# A tag virtual inclui qualquer categoria de Evento ruim sem precisar
		# regravar dezenas de Resources com uma tag manual.
		if content.valence == EventData.Valence.BAD:
			present.append(&"event_bad")
		present.append_array(content.tags)
	elif content is ItemData:
		present.append_array(content.tags)
	elif content is EncounterData:
		present.append_array(content.tags)
	for tag in wanted:
		if tag in present:
			return true
	return false
