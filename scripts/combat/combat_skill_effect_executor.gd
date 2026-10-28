class_name CombatSkillEffectExecutor
extends RefCounted

## Executa os SkillEffectData de Ativas no Combate. Não conhece nomes de
## personagens: SkillManager valida a concessão, o alvo e os limites antes.

var _entity_by_id: Dictionary = {}


func can_execute(effect: SkillEffectData, context: Dictionary) -> bool:
	if effect == null or context.get("actor") is not EntityState \
			or context.get("combat") is not CombatManager:
		return false
	var actor := context["actor"] as EntityState
	var target := context.get("selected_target") as EntityState
	var combat := context["combat"] as CombatManager
	match effect.effect_type:
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			return target != null and target.current_health > 0 \
				and effect.attribute_id == &"attack" and effect.has_duration \
				and effect.duration_turns > 0 \
				and effect.modify_mode == SkillEffectData.ModifyMode.SUBTRACT
		SkillEffectData.EffectType.REDIRECT_DAMAGE:
			return target != null and target.current_health > 0 and actor != target \
				and effect.has_duration and effect.duration_unit in [
					SkillEffectData.DurationUnit.COMBAT,
					SkillEffectData.DurationUnit.UNTIL_NEXT_OWNER_TURN_START]
		SkillEffectData.EffectType.REDUCE_INCOMING_DAMAGE:
			return effect.target == SkillEffectData.Target.SELF \
				and effect.percent > 0.0 and effect.percent < 1.0 \
				and effect.has_duration and effect.duration_unit in [
					SkillEffectData.DurationUnit.COMBAT,
					SkillEffectData.DurationUnit.UNTIL_NEXT_OWNER_TURN_START]
		SkillEffectData.EffectType.APPLY_DEBUFF, SkillEffectData.EffectType.REMOVE_DEBUFF:
			var manager := context.get("skill_manager") as SkillManager
			return manager != null and manager.can_apply_debuff_effect(effect, context)
		SkillEffectData.EffectType.SUMMON_ENTITY:
			if actor.controller != EntityState.Controller.AI \
					or (actor.summoned_by_instance_id != &"" \
					and not actor.summoned_can_summon):
				return false
			for id in _summon_ids(effect):
				if _find_entity(id) != null:
					if effect.maximum_active_instances <= 0 or \
							combat.count_living_summons(actor, id) < effect.maximum_active_instances:
						return true
			return false
		SkillEffectData.EffectType.PERFORM_ATTACK:
			return target != null and target.current_health > 0
		SkillEffectData.EffectType.CHANGE_ALLEGIANCE:
			return target != null and target in combat.enemies and target.current_health > 0 \
				and actor.controller == EntityState.Controller.PLAYER
		SkillEffectData.EffectType.DECLARE_RIVAL:
			return target != null and target.data != null \
				and not effect.passives_granted_on_success.is_empty()
		SkillEffectData.EffectType.REVIVE_ENTITY:
			var campaign := context.get("campaign") as CampaignState
			return target != null and target.current_health <= 0 \
				and campaign != null \
				and campaign.can_resurrect_group_member(target, actor) \
				and (not effect.consume_source_item_on_success \
				or combat.can_consume_skill_source_item(actor,
					context.get("grant") as SkillGrantState))
	return false


func execute(effect: SkillEffectData, context: Dictionary) -> Dictionary:
	if not can_execute(effect, context):
		return {"success": false, "reason": "Efeito de Combate indisponível."}
	var actor := context["actor"] as EntityState
	var target := context.get("selected_target") as EntityState
	var combat := context["combat"] as CombatManager
	var manager := context["skill_manager"] as SkillManager
	var campaign := context["campaign"] as CampaignState
	if effect.activation_chance < 1.0 and combat._rng.randf() >= effect.activation_chance:
		return {"success": true, "chance_failed": true}
	match effect.effect_type:
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			var basis := actor.data.ataque_base if effect.value_source == \
				SkillEffectData.ValueSource.OWNER_BASE_ATTRIBUTE else effect.amount
			return combat.apply_timed_attack_penalty(target, basis, effect.duration_turns)
		SkillEffectData.EffectType.REDIRECT_DAMAGE:
			return combat.set_damage_guard(actor, target, effect.duration_unit)
		SkillEffectData.EffectType.REDUCE_INCOMING_DAMAGE:
			return combat.add_guard_reduction(actor, effect.percent, effect.duration_unit)
		SkillEffectData.EffectType.APPLY_DEBUFF, SkillEffectData.EffectType.REMOVE_DEBUFF:
			return manager.apply_debuff_effect(effect, context)
		SkillEffectData.EffectType.SUMMON_ENTITY:
			var ids := _summon_ids(effect)
			var chosen: StringName = ids[combat._rng.randi_range(0, ids.size() - 1)]
			var data := _find_entity(chosen)
			if data == null:
				return {"success": false, "reason": "EntityData da invocação não encontrado."}
			var count := effect.amount
			if effect.maximum_amount > 0:
				count = combat._rng.randi_range(effect.minimum_amount, effect.maximum_amount)
			# As invocações elementais de abertura são UMA entidade, não um
			# EncounterData inteiro nem uma instância de cada ID sorteável.
			var skill := context.get("skill") as ActiveSkillData
			if skill != null and &"invocacao_inicio" in skill.tags:
				count = mini(count, 1)
			var summoned: Array[EntityState] = []
			for index in count:
				if effect.maximum_active_instances > 0 and \
						combat.count_living_summons(actor, chosen) >= effect.maximum_active_instances:
					break
				var entity := combat.spawn_summoned_enemy(data, actor, effect)
				if entity == null:
					break
				summoned.append(entity)
			return {"success": not summoned.is_empty(), "summoned": summoned}
		SkillEffectData.EffectType.PERFORM_ATTACK:
			return combat.perform_skill_attack(actor, target, context["skill"] as ActiveSkillData)
		SkillEffectData.EffectType.CHANGE_ALLEGIANCE:
			return combat.convert_enemy_to_companion(actor, target, effect)
		SkillEffectData.EffectType.DECLARE_RIVAL:
			var granted: Array[SkillGrantState] = []
			for resource in effect.passives_granted_on_success:
				if not resource is PassiveSkillData:
					continue
				var source_id := StringName("%s:%s:%s" % [
					(context["grant"] as SkillGrantState).source_id, target.data.id,
					(resource as PassiveSkillData).id])
				var grant := manager.grant_skill(actor, resource, &"archenemy",
					source_id, campaign, target.data)
				if grant != null:
					granted.append(grant)
			return {"success": not granted.is_empty(), "granted": granted,
				"enemy_type": target.data.id}
		SkillEffectData.EffectType.REVIVE_ENTITY:
			# O item precisa ser consumido antes da ressurreição: não permitir
			# devolver um aliado à vida mantendo o Amuleto por falha de remoção.
			if effect.consume_source_item_on_success and not combat.consume_skill_source_item(
					actor, context["grant"] as SkillGrantState):
				return {"success": false, "reason": "O item de sacrifício não está equipado."}
			if not campaign.resurrect_group_member(target, actor, manager).get(
					"success", false):
				return {"success": false, "reason": "O alvo não está morto."}
			combat.place_revived_ally(target, actor)
			combat._sync_combat_view()
			return {"success": true, "revived": target}
	return {"success": false, "reason": "Tipo de efeito de Combate sem executor."}


func _summon_ids(effect: SkillEffectData) -> Array[StringName]:
	var ids: Array[StringName] = []
	if effect.entity_id != &"":
		ids.append(effect.entity_id)
	for id in effect.entity_ids:
		if id != &"" and id not in ids:
			ids.append(id)
	return ids


func _find_entity(id: StringName) -> EntityData:
	if _entity_by_id.has(id):
		return _entity_by_id[id] as EntityData
	for folder in ["res://resources/entities/entities_general",
			"res://resources/entities/entities_general/companions",
			"res://resources/entities/entities_playable"]:
		for filename in DirAccess.get_files_at(folder):
			if not filename.ends_with(".tres"):
				continue
			var data := load(folder.path_join(filename)) as EntityData
			if data != null:
				_entity_by_id[data.id] = data
	return _entity_by_id.get(id) as EntityData
