class_name SkillManager
extends Node

## Todas as entidades consultam as mesmas habilidades. Jogador e IA só
## escolhem a ação; origem, limites e efeitos são iguais para ambos.

signal skill_granted(actor: EntityState, grant: SkillGrantState)
signal skill_source_removed(actor: EntityState, source_key: StringName)
signal active_skill_used(actor: EntityState, grant: SkillGrantState, result: Dictionary)
signal delayed_skill_effect_resolved(owner: EntityState, result: Dictionary)
signal passive_triggered(actor: EntityState, grant: SkillGrantState, result: Dictionary)
signal incoming_damage_applied(target: EntityState, damage: int)

var effect_executor := SkillEffectExecutor.new()
var combat_effect_executor = preload("res://scripts/combat/combat_skill_effect_executor.gd").new()
var inventory_manager := InventoryManager.new()
var debuff_manager := DebuffManager.new()
@export var catastrophe_manager: CatastropheManager
@export var gerencia: GerenciaJogo
var _status_triggers_in_progress: Dictionary = {}
var last_exploration_result: Dictionary = {} # Somente feedback do último uso já resolvido.


func _ready() -> void:
	if gerencia != null and not gerencia.information_granted.is_connected(
			_on_information_granted):
		gerencia.information_granted.connect(_on_information_granted)
	if gerencia != null:
		debuff_manager.campaign = gerencia.campaign
		inventory_manager.campaign = gerencia.campaign


func _on_information_granted(_information: Informacao, _result: Dictionary) -> void:
	on_information_obtained(gerencia.campaign)


func equipped_source_item(actor: EntityState,
		grant: SkillGrantState) -> InventoryItemState:
	if actor == null or grant == null or grant.source_kind != &"equipment":
		return null
	for slot in [actor.equipped_weapons, actor.equipped_armors,
			actor.equipped_accessories]:
		for entry in slot:
			if entry != null and entry.equipment_source_id \
					== grant.source_id:
				return entry
	return null


func consume_equipment_source_item(actor: EntityState, grant: SkillGrantState,
		campaign: CampaignState) -> bool:
	var entry := equipped_source_item(actor, grant)
	if entry == null or entry.data == null or campaign == null \
			or not EquipmentManager.new().consume_equipped_item(actor, entry, self):
		return false
	if entry.data.cannot_craft_after_consumed:
		campaign.consumed_uncraftable_item_ids[entry.data.id] = true
	return true


## A sintonização é da cópia e só pode ser feita uma vez. Equipar de novo
## reativa a proteção do mesmo personagem sem repetir esta Ativa.
func can_attune_divine_amulet(actor: EntityState, grant: SkillGrantState) -> bool:
	if actor == null or grant == null or grant.skill == null \
			or grant.skill.id != &"item_active_003" or actor.current_health <= 0 \
			or actor.instance_id == &"" or grant not in get_active_grants(actor):
		return false
	var entry := equipped_source_item(actor, grant)
	return entry != null and entry.data != null and entry.data.id == &"ac_00001" \
		and entry.attuned_owner_instance_id == &""


func attune_divine_amulet(actor: EntityState, grant: SkillGrantState,
		campaign: CampaignState = null) -> Dictionary:
	if not can_attune_divine_amulet(actor, grant):
		return {"success": false, "reason": "Este Amuleto Divino já foi sintonizado ou não está equipado."}
	var entry := equipped_source_item(actor, grant)
	entry.attuned_owner_instance_id = actor.instance_id
	entry.attuned_owner_name = actor.visible_name()
	var protected_ids: Array[StringName] = [&"db_00003", &"db_00004",
		&"db_00005", &"db_00009", &"db_00010"]
	var removed := debuff_manager.remove_debuffs(actor, protected_ids)
	actor.equipment_changed.emit()
	if campaign != null:
		campaign.append_journal_entry(&"attune_divine_amulet", [
			{"text": actor.visible_name(), "tone": "actor"},
			{"text": " sintonizou o Amuleto Divino. O vínculo é permanente.", "tone": "text"},
		], actor.instance_id, {"item_id": str(entry.data.id)})
	var result := {"success": true, "skill": grant.skill, "target": actor,
		"removed_debuffs": removed, "effects": []}
	active_skill_used.emit(actor, grant, result)
	return result


## A escolha e a confirmação são da UI; esta operação só altera o estado
## depois que o jogador confirma qual morto deseja ressuscitar.
func can_use_exploration_divine_amulet(actor: EntityState,
		grant: SkillGrantState, campaign: CampaignState,
		target: EntityState = null) -> bool:
	var turn_owner := campaign.resurrection_playable_owner(actor) \
		if campaign != null else null
	if actor == null or grant == null or campaign == null \
			or campaign.current_map == null or grant not in get_active_grants(actor) \
			or grant.skill == null or grant.skill.id != &"item_active_002" \
			or turn_owner == null or turn_owner.turn_state != EntityState.TurnState.TURNING \
			or actor.current_health <= 0 \
			or campaign.current_map.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION \
			or equipped_source_item(actor, grant) == null:
		return false
	if catastrophe_manager != null and catastrophe_manager.skills_suppressed(
			HexGrid.PPPMapMode.EXPLORATION, false):
		return false
	if target != null:
		return campaign.can_resurrect_group_member(target, actor)
	return not campaign.get_dead_group_members().is_empty()


func use_exploration_divine_amulet(actor: EntityState,
		grant: SkillGrantState, campaign: CampaignState,
		target: EntityState) -> Dictionary:
	if not can_use_exploration_divine_amulet(actor, grant, campaign, target) \
			or not consume_equipment_source_item(actor, grant, campaign):
		return {"success": false, "reason": "Sacrifício Divino indisponível."}
	var revived := campaign.resurrect_group_member(target, actor, self)
	if not revived.get("success", false):
		return revived
	var result := {"success": true, "skill": grant.skill, "target": target,
		"effects": [{"success": true, "revived": target}]}
	active_skill_used.emit(actor, grant, result)
	return result


## Um SkillEffectData informa qual status e qual alvo. O mesmo motor serve
## para passivas, ativas e, futuramente, os outcomes dos Eventos.
func get_effect_targets(effect: SkillEffectData, context: Dictionary) -> Array[EntityState]:
	var targets: Array[EntityState] = []
	if effect == null:
		return targets
	var candidate: Variant = null
	match effect.target:
		SkillEffectData.Target.SELF:
			candidate = context.get("actor")
		SkillEffectData.Target.ATTACK_TARGET:
			candidate = context.get("attack_target")
		SkillEffectData.Target.SELECTED_TARGET:
			candidate = context.get("selected_target")
		SkillEffectData.Target.DAMAGE_SOURCE:
			candidate = context.get("damage_source")
		SkillEffectData.Target.OWNER:
			candidate = context.get("turn_owner", context.get("actor"))
		SkillEffectData.Target.ENCOUNTER_ACTIVATOR:
			candidate = context.get("encounter_activator")
		SkillEffectData.Target.NEAREST_ALLY, SkillEffectData.Target.NEAREST_ENEMY:
			var pool: Array = context.get("allies", []) if effect.target == SkillEffectData.Target.NEAREST_ALLY else context.get("enemies", [])
			var actor := context.get("actor") as EntityState
			if actor == null:
				return targets
			var best_distance := 999999
			for member in pool:
				if not member is EntityState or member == actor or member.current_health <= 0:
					continue
				var distance := HexGrid.distance(actor.position, member.position)
				if distance < best_distance:
					best_distance = distance
					candidate = member
		SkillEffectData.Target.ALL_ALLIES, SkillEffectData.Target.ALL_ENEMIES:
			var pool: Array = context.get("allies", []) if effect.target == SkillEffectData.Target.ALL_ALLIES else context.get("enemies", [])
			for member in pool:
				if member is EntityState and member.current_health > 0 and member not in targets:
					targets.append(member)
	if candidate is EntityState and candidate.current_health > 0 and candidate not in targets:
		targets.append(candidate)
	return targets


func can_apply_debuff_effect(effect: SkillEffectData, context: Dictionary) -> bool:
	if effect == null or (effect.debuff_id == &"" and effect.status_ids.is_empty()):
		return false
	var targets := get_effect_targets(effect, context)
	if targets.is_empty():
		return false
	if effect.effect_type == SkillEffectData.EffectType.REMOVE_DEBUFF:
		var ids: Array[StringName] = effect.status_ids.duplicate()
		if effect.debuff_id != &"":
			ids.append(effect.debuff_id)
		for target in targets:
			for id in ids:
				if debuff_manager.get_debuff(target, id) != null:
					return true
		return false
	var debuff := debuff_manager.find_debuff(effect.debuff_id)
	if debuff == null:
		return false
	if debuff.duration_from_die_result and int(context.get("damage_die_result", 0)) <= 0:
		return false
	if debuff.ends_when_tick_damage_reaches_zero \
			and int(context.get("initial_tick_damage", context.get("damage_dealt", 0))) <= 0:
		return false
	for target in targets:
		if not is_status_immune(target, debuff.id):
			return true
	return false


func apply_debuff_effect(effect: SkillEffectData, context: Dictionary) -> Dictionary:
	if not can_apply_debuff_effect(effect, context):
		return {"success": false, "reason": "Debuff, alvo ou dano inicial ausente."}
	var applied: Array[Dictionary] = []
	var source := context.get("actor") as EntityState
	var campaign := context.get("campaign") as CampaignState
	var day := campaign.day if campaign != null else 1
	for target in get_effect_targets(effect, context):
		if effect.effect_type == SkillEffectData.EffectType.REMOVE_DEBUFF:
			var removed: Array[StringName] = []
			var ids: Array[StringName] = effect.status_ids.duplicate()
			if effect.debuff_id != &"":
				ids.append(effect.debuff_id)
			for id in ids:
				if debuff_manager.remove_debuff(target, id):
					removed.append(id)
			if not removed.is_empty():
				applied.append({"target": target, "removed": removed})
			continue
		if is_status_immune(target, effect.debuff_id):
			continue
		var result := debuff_manager.apply_by_id(target, effect.debuff_id, source,
			int(context.get("initial_tick_damage", context.get("damage_dealt", 0))),
			day, effect.duration_turns if effect.has_duration else -1,
			context.get("status_source_id", &""),
			float(context.get("status_resistance_chance", -1.0)),
			int(context.get("damage_die_result", 0)))
		if result.get("success", false):
			applied.append({"target": target, "result": result})
			if not result.get("ignored_weaker_stage", false):
				_dispatch_status_applied(target, effect.debuff_id, source, campaign, context)
	return {"success": not applied.is_empty(), "targets": applied}


func _dispatch_status_applied(target: EntityState, status_id: StringName,
		source: EntityState, campaign: CampaignState, context: Dictionary = {}) -> void:
	if campaign == null or target == null:
		return
	var key := "%d:%s" % [target.get_instance_id(), status_id]
	if _status_triggers_in_progress.has(key):
		return
	_status_triggers_in_progress[key] = true
	dispatch_passive_trigger(target, PassiveSkillData.Trigger.ON_STATUS_APPLIED,
		campaign, {"status_id": status_id, "status_source": source,
			"mode": context.get("mode", HexGrid.PPPMapMode.EXPLORATION)})
	_status_triggers_in_progress.erase(key)


func is_status_immune(target: EntityState, debuff_id: StringName) -> bool:
	if target == null:
		return false
	if debuff_id in target.permanent_status_immunities \
			or debuff_id in target.temporary_status_immunities \
			or target.has_divine_amulet_status_immunity(debuff_id):
		return true
	for grant in get_passive_grants(target):
		var passive := grant.skill as PassiveSkillData
		for effect in passive.continuous_effects:
			if effect.effect_type == SkillEffectData.EffectType.GRANT_STATUS_IMMUNITY \
					and debuff_id in effect.status_ids:
				return true
	return false


func on_entity_turn_started(actor: EntityState, campaign: CampaignState,
		rng: RandomNumberGenerator = null,
		allies: Array[EntityState] = []) -> Array[Dictionary]:
	inventory_manager.expire_timed_consumables(actor)
	return debuff_manager.on_turn_started(actor, campaign, self, rng, allies)


func on_entity_turn_finished(actor: EntityState, campaign: CampaignState,
		rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	return debuff_manager.on_turn_finished(actor, campaign, self, rng)


func on_entity_moved(actor: EntityState, campaign: CampaignState,
		rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	return debuff_manager.on_moved(actor, campaign, self, rng)


func apply_event_status(effect: Event_EffectData, target: EntityState,
		source: EntityState, campaign: CampaignState,
		calculated_value: int = 0, event_id: StringName = &"",
		source_die_result: int = 0) -> Dictionary:
	var result := debuff_manager.apply_event_effect(effect, target, source,
		campaign, calculated_value, event_id, self, source_die_result)
	if result.get("success", false) \
			and effect.effect_type == Event_EffectData.EffectType.APPLY_STATUS \
			and not result.get("ignored_weaker_stage", false):
		_dispatch_status_applied(target, effect.debuff.id, source, campaign)
	return result


func ensure_innate_skills(actor: EntityState) -> void:
	if actor == null or actor.data == null:
		return
	for index in actor.data.skill_ativas.size():
		var skill := actor.data.skill_ativas[index]
		if skill != null:
			var key := skill.resource_path if not skill.resource_path.is_empty() else str(index)
			_add_if_missing(actor, skill, &"innate", StringName("active:%s" % key))
	for index in actor.data.skill_passivas.size():
		var skill := actor.data.skill_passivas[index]
		if skill != null:
			var key := skill.resource_path if not skill.resource_path.is_empty() else str(index)
			_add_if_missing(actor, skill, &"innate", StringName("passive:%s" % key))


func grant_skill(actor: EntityState, skill: Resource, source_kind: StringName, source_id: StringName,
		campaign: CampaignState = null, bound_source: Resource = null,
		bound_item_improvements: Dictionary = {}) -> SkillGrantState:
	if actor == null or not (skill is ActiveSkillData or skill is PassiveSkillData) \
			or source_kind == &"" or source_id == &"":
		return null
	var grant := _add_if_missing(actor, skill, source_kind, source_id, campaign,
		bound_source, bound_item_improvements)
	if campaign != null:
		refresh_information_passives(actor, campaign)
	return grant


func remove_source(actor: EntityState, source_kind: StringName, source_id: StringName) -> int:
	if actor == null or source_kind == &"" or source_id == &"":
		return 0
	var matching: Array[SkillGrantState] = []
	for grant in actor.skill_grants:
		if grant.source_kind == source_kind and grant.source_id == source_id:
			matching.append(grant)
	for grant in matching:
		for child_id in grant.copied_passive_source_ids:
			remove_source(actor, &"copied_trait", child_id)
		if grant in actor.skill_grants:
			_remove_grant_contributions(actor, grant)
			actor.skill_grants.erase(grant)
	var removed := matching.size()
	if removed > 0:
		skill_source_removed.emit(actor, StringName("%s:%s" % [source_kind, source_id]))
	return removed


func get_active_grants(actor: EntityState) -> Array[SkillGrantState]:
	var result: Array[SkillGrantState] = []
	if actor == null:
		return result
	ensure_innate_skills(actor)
	for grant in actor.skill_grants:
		if grant.skill is ActiveSkillData:
			result.append(grant)
	return result


## A mesma concessão/limite vale para jogável, aliado e hostil. O controlador
## apenas escolhe QUANDO e QUEM; os Effects são executados em outra classe.
func can_use_combat_active(actor: EntityState, grant: SkillGrantState,
		campaign: CampaignState, combat: CombatManager,
		selected_target: EntityState = null, automatic: bool = false) -> bool:
	if actor == null or grant == null or campaign == null or combat == null \
			or grant not in get_active_grants(actor) or actor.current_health <= 0 \
			or combat.current_encounter == null or not combat.pending_conclusion.is_empty():
		return false
	var skill := grant.skill as ActiveSkillData
	if skill == null or skill.use_context == ActiveSkillData.UseContext.EXPLORATION \
			or skill.effects.is_empty() \
			or (not automatic and not skill.automatic_triggers.is_empty()) \
			or (automatic and skill.automatic_triggers.is_empty()):
		return false
	if not automatic and combat.current_actor != actor:
		return false
	if combat.is_charm_forced_turn(actor):
		return false
	# Charme bloqueia imediatamente ataques, dano e ações contra hostis.
	# Ativas de apoio sem dano continuam válidas até o turno compulsório.
	if debuff_manager.has_control(actor, DebuffData.ControlEffect.CANT_ATTACK):
		if selected_target in combat._opponents_of(actor) \
				or skill.target_mode == ActiveSkillData.TargetMode.ONE_ENEMY:
			return false
		for effect in skill.effects:
			if effect.effect_type in [SkillEffectData.EffectType.DEAL_FIXED_DAMAGE,
					SkillEffectData.EffectType.PERFORM_ATTACK,
					SkillEffectData.EffectType.COUNTERATTACK] \
					or effect.target in [SkillEffectData.Target.ATTACK_TARGET,
					SkillEffectData.Target.NEAREST_ENEMY,
					SkillEffectData.Target.ALL_ENEMIES,
					SkillEffectData.Target.DAMAGE_SOURCE]:
				return false
	if catastrophe_manager != null and catastrophe_manager.skills_suppressed(
			HexGrid.PPPMapMode.COMBAT, false):
		return false
	if skill.requires_undesired_encounter and combat.current_encounter == null:
		return false
	if skill.activate_only_once and grant.activated_combat_id == combat._combat_id:
		return false
	if skill.max_uses_per_combat > 0 and grant.last_used_combat_id == combat._combat_id \
			and grant.uses_in_last_combat >= skill.max_uses_per_combat:
		return false
	if not _has_usage_available(grant, skill, actor, campaign):
		return false
	match skill.target_mode:
		ActiveSkillData.TargetMode.ONE_ENEMY:
			if selected_target == null or selected_target not in combat._opponents_of(actor):
				return false
		ActiveSkillData.TargetMode.ONE_ALLY:
			if selected_target == null or selected_target == actor \
					or (selected_target not in combat._allies_of(actor, skill.allow_dead_targets) \
					and not (skill.id == &"item_active_002" \
					and campaign.can_resurrect_group_member(selected_target, actor))):
				return false
		ActiveSkillData.TargetMode.ONE_ENTITY:
			if selected_target == null or (selected_target not in combat._allies_of(
					actor, skill.allow_dead_targets) \
					and selected_target not in combat._opponents_of(actor)):
				return false
		ActiveSkillData.TargetMode.SELF, ActiveSkillData.TargetMode.NONE:
			pass
		_:
			return false
	if selected_target != null:
		if selected_target.current_health <= 0 and not skill.allow_dead_targets:
			return false
		if selected_target.current_health > 0 and skill.allow_dead_targets:
			return false
		if skill.range_limit >= 0 and HexGrid.distance(actor.position,
				selected_target.position) > skill.range_limit:
			return false
	var context := {"actor": actor, "selected_target": selected_target,
		"turn_owner": actor, "campaign": campaign, "combat": combat,
		"skill_manager": self, "grant": grant, "skill": skill,
		"allies": combat._allies_of(actor), "enemies": combat._opponents_of(actor)}
	for effect in skill.effects:
		if not combat_effect_executor.can_execute(effect, context):
			return false
	return true


func use_combat_active(actor: EntityState, grant: SkillGrantState,
		campaign: CampaignState, combat: CombatManager,
		selected_target: EntityState = null, automatic: bool = false) -> Dictionary:
	inventory_manager.campaign = campaign
	if not can_use_combat_active(actor, grant, campaign, combat,
			selected_target, automatic):
		return {"success": false, "reason": "Ativa indisponível neste turno ou alvo."}
	var skill := grant.skill as ActiveSkillData
	var context := {"actor": actor, "selected_target": selected_target,
		"turn_owner": actor, "campaign": campaign, "combat": combat,
		"skill_manager": self, "grant": grant, "skill": skill,
		"allies": combat._allies_of(actor), "enemies": combat._opponents_of(actor)}
	var results: Array[Dictionary] = []
	for effect in skill.effects:
		var applied := combat_effect_executor.execute(effect, context)
		if not applied.get("success", false):
			return applied
		results.append(applied)
	_record_use(grant, actor, campaign)
	if grant.last_used_combat_id != combat._combat_id:
		grant.uses_in_last_combat = 0
	grant.last_used_combat_id = combat._combat_id
	grant.uses_in_last_combat += 1
	grant.activated_combat_id = combat._combat_id
	var result := {"success": true, "effects": results, "skill": skill,
		"target": selected_target}
	active_skill_used.emit(actor, grant, result)
	if skill.consume_skill_on_success and not results.any(func(entry: Dictionary) -> bool:
		return entry.get("chance_failed", false)):
		remove_source(actor, grant.source_kind, grant.source_id)
	return result


func get_passive_grants(actor: EntityState) -> Array[SkillGrantState]:
	var result: Array[SkillGrantState] = []
	if actor == null:
		return result
	ensure_innate_skills(actor)
	for grant in actor.skill_grants:
		if grant.skill is PassiveSkillData:
			if grant.skill.id == &"item_passive_004":
				var entry := equipped_source_item(actor, grant)
				if entry == null or entry.attuned_owner_instance_id != actor.instance_id \
						or actor.instance_id == &"":
					continue
			result.append(grant)
	return result


## A regra contínua existe enquanto a fonte existir. Equipamento, alvo e
## alcance consultam esta lista; não recebem um bônus novo a cada turno.
func get_continuous_effects(actor: EntityState, effect_type: SkillEffectData.EffectType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for grant in get_passive_grants(actor):
		var passive := grant.skill as PassiveSkillData
		for effect in passive.continuous_effects:
			if effect.effect_type == effect_type and effect_executor.supports_continuous(effect):
				result.append({"grant": grant, "effect": effect})
	return result


func ignores_attack_range(actor: EntityState, mastery: EntityData.Mastery) -> bool:
	for entry in get_continuous_effects(actor, SkillEffectData.EffectType.IGNORE_ATTACK_RANGE):
		var effect := entry["effect"] as SkillEffectData
		var grant := entry["grant"] as SkillGrantState
		if not effect.mastery_options.is_empty() and mastery not in effect.mastery_options:
			continue
		if effect.required_bound_source_mastery != EntityData.Mastery.NONE:
			var item := grant.bound_source as ItemData
			if item == null or item.mastery_granted != effect.required_bound_source_mastery:
				continue
		return true
	return false


func can_equip_item(actor: EntityState, item: ItemData) -> bool:
	if actor == null or item == null or actor.data == null \
			or &"jogavel" not in actor.data.tags:
		return false
	# A arma da Simbiose ocupa o slot para sempre; não pode ser substituída.
	if item.equipment_slot == ItemData.EquipmentSlot.WEAPON:
		for grant in get_passive_grants(actor):
			if grant.skill != null and grant.skill.id == &"permanent_passive_058":
				return false
	for entry in get_continuous_effects(actor, SkillEffectData.EffectType.RESTRICT_EQUIPMENT):
		var effect := entry["effect"] as SkillEffectData
		if effect.restricted_equipment_rarity != SkillEffectData.ItemRarityFilter.NONE \
				and int(item.rarity) == int(effect.restricted_equipment_rarity):
			return false
	return true


## Consulta pura. O disparo de fato passa por dispatch_passive_trigger abaixo.
func get_passive_candidates(actor: EntityState, trigger: PassiveSkillData.Trigger, mode: int) -> Array[SkillGrantState]:
	var result: Array[SkillGrantState] = []
	for grant in get_passive_grants(actor):
		var skill := grant.skill as PassiveSkillData
		if skill.trigger != trigger and trigger not in skill.additional_triggers:
			continue
		if mode == HexGrid.PPPMapMode.EXPLORATION and skill.activation_context == PassiveSkillData.ActivationContext.COMBAT:
			continue
		if mode == HexGrid.PPPMapMode.COMBAT and skill.activation_context == PassiveSkillData.ActivationContext.EXPLORATION:
			continue
		result.append(grant)
	return result


## Um acontecimento tem um CONTEXTO (alvo, item, posição, combate etc.).
## A passiva só gasta uso depois de confirmar condições, chance e executor.
## Efeitos sem executor concreto permanecem pendentes, nunca viram sucesso.
func dispatch_passive_trigger(actor: EntityState, trigger: PassiveSkillData.Trigger,
		campaign: CampaignState, event_context: Dictionary = {},
		rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if actor == null or campaign == null:
		return results
	var context := event_context.duplicate()
	context["actor"] = actor
	context["campaign"] = campaign
	context["skill_manager"] = self
	context["rng"] = rng
	if not context.has("mode"):
		context["mode"] = campaign.current_map.ppp_map_mode if campaign.current_map != null \
			else HexGrid.PPPMapMode.EXPLORATION
	if catastrophe_manager != null and catastrophe_manager.skills_suppressed(int(context["mode"]), true):
		return results
	if not context.has("target_debuff_ids"):
		var affected := context.get("attack_target") as EntityState
		if affected == null:
			affected = context.get("selected_target") as EntityState
		if affected != null:
			context["target_debuff_ids"] = debuff_manager.get_debuff_ids(affected)
	var eligible: Array[SkillGrantState] = []
	for grant in get_passive_candidates(actor, trigger, int(context["mode"])):
		context["grant"] = grant
		var passive := grant.skill as PassiveSkillData
		if passive.effects.is_empty() or not _passive_schedule_and_limits_allow(actor, grant, passive, context):
			continue
		if not _passive_conditions_met(actor, passive, campaign, context):
			continue
		var executable := true
		for effect in passive.effects:
			if not effect_executor.can_execute_passive(effect, context):
				executable = false
				break
		if executable:
			eligible.append(grant)
	var selected := _select_passive_groups(eligible, rng)
	var hostile_dodge := _preferred_hostile_dodge(actor, trigger, selected)
	for grant in selected:
		context["grant"] = grant
		var passive := grant.skill as PassiveSkillData
		var chance := _effective_passive_chance(actor, trigger, grant, hostile_dodge,
			campaign)
		if _roll_passive_chance(chance, rng) == false:
			continue
		var effect_results: Array[Dictionary] = []
		var success := true
		for effect in passive.effects:
			var applied := effect_executor.execute_passive(effect, context)
			if not applied.get("success", false):
				success = false
				break
			effect_results.append(applied)
		if not success:
			continue
		_record_passive_use(actor, grant, context)
		var result := {"grant": grant, "effects": effect_results,
			"damage_source": context.get("damage_source")}
		results.append(result)
		passive_triggered.emit(actor, grant, result)
	return results


func _preferred_hostile_dodge(actor: EntityState, trigger: PassiveSkillData.Trigger,
		grants: Array[SkillGrantState]) -> SkillGrantState:
	if actor.controller != EntityState.Controller.AI \
			or trigger != PassiveSkillData.Trigger.ON_BEFORE_DAMAGE_RECEIVED:
		return null
	# Uma única tentativa de Esquiva por golpe, mesmo com múltiplas fontes.
	var preferred: SkillGrantState = null
	for grant in grants:
		var candidate := grant.skill as PassiveSkillData
		if not _passive_has_dodge(candidate):
			continue
		if preferred == null or candidate.activation_chance > \
				(preferred.skill as PassiveSkillData).activation_chance:
			preferred = grant
	return preferred


func _effective_passive_chance(actor: EntityState, trigger: PassiveSkillData.Trigger,
		grant: SkillGrantState, preferred_hostile_dodge: SkillGrantState,
		campaign: CampaignState = null) -> float:
	var passive := grant.skill as PassiveSkillData
	if actor.controller == EntityState.Controller.AI \
			and trigger == PassiveSkillData.Trigger.ON_BEFORE_DAMAGE_RECEIVED \
			and _passive_has_dodge(passive):
		if grant != preferred_hostile_dodge:
			return 0.0
		# A limitação é aplicada à instância; o Resource de 60% dos jogáveis
		# permanece intacto para itens e habilidades próprios.
		var cap := 0.10 if campaign != null \
			and campaign.difficulty == GameDifficulty.Mode.SUGAR else 0.30
		return minf(passive.activation_chance, cap)
	return passive.activation_chance


func _passive_has_dodge(passive: PassiveSkillData) -> bool:
	if passive == null:
		return false
	for effect in passive.effects:
		if effect != null and effect.effect_type == \
				SkillEffectData.EffectType.DODGE_INCOMING_ATTACK:
			return true
	return false


func on_item_consumed(actor: EntityState, item: ItemData, campaign: CampaignState,
		mode: int, combat_id: StringName = &"", combat_turn_number: int = 0) -> Array[Dictionary]:
	if item == null or item.item_type != ItemData.ItemType.CONSUMABLE:
		return []
	return dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_ITEM_CONSUMED,
		campaign, {"item": item, "mode": mode, "combat_id": combat_id,
			"combat_turn_number": combat_turn_number})


func on_day_started(campaign: CampaignState, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if campaign == null or campaign.last_processed_day_start == campaign.day:
		return results
	# A mesma virada de Dia nunca aplica a Bonequinha duas vezes.
	campaign.last_processed_day_start = campaign.day
	for actor in campaign.active_entity_states:
		debuff_manager.on_day_started(actor, campaign, self, rng)
		results.append_array(dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_DAY_START,
			campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION}, rng))
	for actor in campaign.companion_states:
		debuff_manager.on_day_started(actor, campaign, self, rng)
		results.append_array(dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_DAY_START,
			campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION}, rng))
	return results


## Manhã, Tarde e Noite são Rodadas diferentes. Outro mapa criado na mesma
## Rodada não reaplica as passivas ON_ROUND_START.
func on_round_started(campaign: CampaignState, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if campaign == null or campaign.last_processed_round_start == campaign.get_round_index():
		return results
	campaign.last_processed_round_start = campaign.get_round_index()
	# O contágio é simultâneo: alguém infectado AGORA não transmite de novo
	# nesta mesma virada só por aparecer depois na lista de personagens.
	var contagious_at_start: Dictionary = {}
	for member in campaign.active_entity_states:
		for status in member.debuffs:
			contagious_at_start[status.get_instance_id()] = true
	for member in campaign.companion_states:
		for status in member.debuffs:
			contagious_at_start[status.get_instance_id()] = true
	for actor in campaign.active_entity_states:
		debuff_manager.on_round_started(actor, campaign, self, rng,
			[], contagious_at_start, true)
		results.append_array(dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_ROUND_START,
			campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION}, rng))
	for actor in campaign.companion_states:
		debuff_manager.on_round_started(actor, campaign, self, rng,
			[], contagious_at_start, true)
		results.append_array(dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_ROUND_START,
			campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION}, rng))
	return results


## Recebe o dano bruto e aplica todas as Proteções elegíveis em sequência.
## Ex.: 10 com duas fontes de 50% => 10 × 0,5 × 0,5 = 2,5 => 2.
## O mínimo de 1 vale para qualquer dano positivo, mesmo perto de zero.
func apply_incoming_damage(target: EntityState, raw_damage: int, campaign: CampaignState,
		event_context: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if target == null or campaign == null or raw_damage <= 0 or target.current_health <= 0:
		return {"success": false, "damage": 0}
	var damage_source := event_context.get("damage_source") as EntityState
	if damage_source != null and damage_source.controller == EntityState.Controller.AI \
			and event_context.get("mode", -1) == HexGrid.PPPMapMode.COMBAT \
			and debuff_manager.has_exploration_event_control(target):
		return {"success": true, "damage": 0, "protected_by_exploration_event": true,
			"remaining_health": target.current_health}
	var context := event_context.duplicate()
	context["incoming_damage"] = raw_damage
	var triggered := dispatch_passive_trigger(target,
		PassiveSkillData.Trigger.ON_BEFORE_DAMAGE_RECEIVED, campaign, context, rng)
	for passive_result in triggered:
		for effect_result in passive_result["effects"]:
			if effect_result.get("dodged", false):
				return {"success": true, "raw_damage": raw_damage,
					"calculated_damage": 0, "damage": 0, "dodged": true,
					"remaining_health": target.current_health, "passives": triggered}
	var remaining := float(raw_damage)
	for passive_result in triggered:
		for effect_result in passive_result["effects"]:
			if effect_result.has("remaining_fraction"):
				remaining *= float(effect_result["remaining_fraction"])
			if effect_result.has("incoming_damage_multiplier"):
				remaining *= float(effect_result["incoming_damage_multiplier"])
	var final_damage := maxi(1, floori(remaining))
	if campaign.difficulty == GameDifficulty.Mode.SUGAR \
			and target.controller == EntityState.Controller.AI:
		# Teto da Proteção TOTAL hostil por golpe. Ceil evita que o
		# arredondamento produza redução efetiva acima de 25%.
		var protection_basis := maxi(raw_damage,
			int(context.get("protection_basis", raw_damage)))
		final_damage = maxi(final_damage, ceili(float(protection_basis) * 0.75))
	var actual_damage := mini(target.current_health, final_damage)
	var combat_id: StringName = context.get("combat_id", &"")
	var survived_lethal_hit := campaign.difficulty == GameDifficulty.Mode.SUGAR \
		and bool(context.get("direct_attack", false)) and combat_id != &"" \
		and target.controller == EntityState.Controller.PLAYER \
		and (target in campaign.active_entity_states or target in campaign.companion_states) \
		and actual_damage >= target.current_health \
		and target.sugar_lethal_guard_combat_id != combat_id
	if survived_lethal_hit:
		actual_damage = target.current_health - 1
		target.sugar_lethal_guard_combat_id = combat_id
	target.current_health -= actual_damage
	incoming_damage_applied.emit(target, actual_damage)
	return {"success": true, "raw_damage": raw_damage,
		"calculated_damage": final_damage, "damage": actual_damage,
		"remaining_health": target.current_health, "passives": triggered,
		"survived_lethal_hit": survived_lethal_hit}


## Em grupos jogáveis, companheiros também são aliados. Outros grupos (como
## inimigos) devem vir explicitamente no contexto do futuro CombateManager.
func get_allies_for_passive(actor: EntityState, campaign: CampaignState,
		context: Dictionary = {}) -> Array[EntityState]:
	var allies: Array[EntityState] = []
	if context.has("allies"):
		for member in context["allies"]:
			if member is EntityState and member not in allies:
				allies.append(member)
		return allies
	if campaign == null or (actor not in campaign.active_entity_states
			and actor not in campaign.companion_states):
		return allies
	for member in campaign.active_entity_states:
		if member not in allies:
			allies.append(member)
	for member in campaign.companion_states:
		if member not in allies:
			allies.append(member)
	return allies


func _passive_schedule_and_limits_allow(actor: EntityState, grant: SkillGrantState,
		passive: PassiveSkillData, context: Dictionary) -> bool:
	var turn_number := int(context.get("combat_turn_number", actor.turn_serial))
	var combat_id: StringName = context.get("combat_id", &"")
	var turn_key := _passive_turn_key(actor, context)
	if turn_key == &"":
		return false
	if passive.first_activation_turn > 0:
		if turn_number < passive.first_activation_turn:
			return false
		if passive.repeat_every_turns > 0 \
				and (turn_number - passive.first_activation_turn) % passive.repeat_every_turns != 0:
			return false
	if passive.cooldown_turns > 0 and grant.last_passive_activation_turn_serial >= 0 \
			and grant.last_passive_activation_combat_id == combat_id \
			and turn_number <= grant.last_passive_activation_turn_serial + passive.cooldown_turns:
		return false
	if passive.max_activations_per_turn > 0 and grant.last_passive_turn_key == turn_key \
			and grant.passive_uses_in_turn >= passive.max_activations_per_turn:
		return false
	if passive.max_activations_per_combat > 0:
		if combat_id == &"":
			return false
		if grant.last_passive_combat_id == combat_id \
				and grant.passive_uses_in_combat >= passive.max_activations_per_combat:
			return false
	return true


func _record_passive_use(actor: EntityState, grant: SkillGrantState, context: Dictionary) -> void:
	var turn_key := _passive_turn_key(actor, context)
	if grant.last_passive_turn_key != turn_key:
		grant.passive_uses_in_turn = 0
	grant.last_passive_turn_key = turn_key
	grant.last_passive_turn_serial = actor.turn_serial
	grant.passive_uses_in_turn += 1
	grant.last_passive_activation_turn_serial = int(context.get("combat_turn_number", actor.turn_serial))
	var combat_id: StringName = context.get("combat_id", &"")
	grant.last_passive_activation_combat_id = combat_id
	if combat_id != &"":
		if grant.last_passive_combat_id != combat_id:
			grant.passive_uses_in_combat = 0
		grant.last_passive_combat_id = combat_id
		grant.passive_uses_in_combat += 1


func _passive_turn_key(actor: EntityState, context: Dictionary) -> StringName:
	if context.get("mode") == HexGrid.PPPMapMode.COMBAT:
		var combat_id: StringName = context.get("combat_id", &"")
		if combat_id == &"" or not context.has("combat_turn_number"):
			return &""
		return StringName("combat:%s:%d" % [combat_id, int(context["combat_turn_number"])])
	return StringName("exploration:%d" % actor.turn_serial)


func _roll_passive_chance(chance: float, rng: RandomNumberGenerator) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	var source := rng if rng != null else gerencia.campaign.world_rng \
		if gerencia != null else null
	return (source.randf() if source != null else randf()) < chance


func _select_passive_groups(grants: Array[SkillGrantState], rng: RandomNumberGenerator) -> Array[SkillGrantState]:
	var selected: Array[SkillGrantState] = []
	var groups: Dictionary = {}
	for grant in grants:
		var passive := grant.skill as PassiveSkillData
		if passive.random_choice_group == &"":
			selected.append(grant)
		else:
			if not groups.has(passive.random_choice_group):
				groups[passive.random_choice_group] = []
			groups[passive.random_choice_group].append(grant)
	for group_id in groups:
		var choices: Array = groups[group_id]
		var total := 0
		for grant in choices:
			total += (grant.skill as PassiveSkillData).random_choice_weight
		var source := rng if rng != null else gerencia.campaign.world_rng \
			if gerencia != null else null
		var roll := source.randi_range(1, total) if source != null \
			else randi_range(1, total)
		for grant in choices:
			roll -= (grant.skill as PassiveSkillData).random_choice_weight
			if roll <= 0:
				selected.append(grant)
				break
	return selected


func _passive_conditions_met(actor: EntityState, passive: PassiveSkillData,
		campaign: CampaignState, context: Dictionary) -> bool:
	if passive.requires_player_confirmation and not context.get("player_confirmed", false):
		return false
	var checks: Array[bool] = []
	var info_count := campaign.obtained_information_ids.size()
	if passive.minimum_group_information_count >= 0:
		checks.append(info_count >= passive.minimum_group_information_count)
	if passive.maximum_group_information_count >= 0:
		checks.append(info_count <= passive.maximum_group_information_count)
	if not passive.required_information_ids.is_empty():
		var global_experience_rule: bool = bool(context.get(
			"global_experience_recruitment", false)) \
			and context.get("recruitment_encounter_id", &"") \
			== EventCampaignDependencies.EXPERIENCE_ENCOUNTER_ID \
			and passive.id == EventCampaignDependencies.EXPERIENCE_ONE_CLUE_PASSIVE_ID \
			and not campaign.has_active_ending(&"orchestra") \
			and campaign.campaign_mode in [EventCampaignEligibility.Mode.SHORT,
				EventCampaignEligibility.Mode.MEDIUM] \
			and info_count >= (2 if campaign.campaign_mode \
				== EventCampaignEligibility.Mode.SHORT else 4)
		var matching := 0
		for info_id in passive.required_information_ids:
			if campaign.obtained_information_ids.has(info_id):
				matching += 1
		checks.append(global_experience_rule or matching >= maxi(1,
			passive.minimum_matching_information))
		if passive.maximum_matching_information > 0 and not global_experience_rule:
			checks.append(matching <= passive.maximum_matching_information)
	if passive.minimum_adjacent_enemies > 0:
		checks.append(int(context.get("adjacent_enemies", -1)) >= passive.minimum_adjacent_enemies)
	if passive.maximum_adjacent_enemies > 0:
		var adjacent := int(context.get("adjacent_enemies", -1))
		checks.append(adjacent >= 0 and adjacent <= passive.maximum_adjacent_enemies)
	if passive.incoming_attack_type != PassiveSkillData.IncomingAttackType.ANY:
		checks.append(context.get("incoming_attack_type", -1) == passive.incoming_attack_type)
	if passive.requires_melee_attack:
		checks.append(context.get("is_melee_attack", false))
	if passive.damage_source_must_be_adjacent:
		checks.append(context.get("damage_source_adjacent", false))
	if passive.required_target_debuff_id != &"":
		checks.append(passive.required_target_debuff_id in context.get("target_debuff_ids", []))
	if not passive.required_opposing_companion_tags.is_empty():
		var opposing: Array = context.get("opposing_companion_tags", [])
		var count := 0
		for tag in passive.required_opposing_companion_tags:
			if tag in opposing:
				count += 1
		checks.append(count == passive.required_opposing_companion_tags.size() \
			if passive.opposing_companion_match_all else count > 0)
	if not passive.required_damage_source_item_ids.is_empty():
		checks.append(context.get("damage_source_item_id", &"") in passive.required_damage_source_item_ids)
	if passive.required_attack_item_id != &"":
		checks.append(context.get("attack_item_id", &"") == passive.required_attack_item_id)
	if passive.required_attack_aspect != &"":
		checks.append(context.get("attack_aspect", &"") == passive.required_attack_aspect)
	if passive.requires_attack_to_deal_damage:
		checks.append(int(context.get("damage_dealt", 0)) > 0)
	if passive.minimum_previous_encounters_same_entity_data > 0:
		checks.append(int(context.get("previous_encounters_same_entity_data", -1)) \
			>= passive.minimum_previous_encounters_same_entity_data)
	if passive.target_revealed_by_skill_id != &"":
		checks.append(passive.target_revealed_by_skill_id in context.get("target_revealed_by_skill_ids", []))
	if passive.max_distance_to_damaged_ally > 0:
		var ally := context.get("damaged_ally") as EntityState
		checks.append(ally != null and actor.position != EntityState.UNPLACED \
			and ally.position != EntityState.UNPLACED \
			and HexGrid.distance(actor.position, ally.position) <= passive.max_distance_to_damaged_ally \
			and (passive.include_companions_in_ally_damage_trigger \
				or ally.owner_instance_id == &""))
	if checks.is_empty():
		return true
	if passive.condition_combination == PassiveSkillData.ConditionCombination.ANY:
		return true in checks
	return false not in checks


## Um bloco de Informação só conta depois de ser ATIVADO. Esta atualização
## recalcula os bônus por origem: revelar o mesmo hex não aumenta nada.
func on_information_obtained(campaign: CampaignState) -> void:
	if campaign == null:
		return
	for actor in campaign.active_entity_states:
		refresh_information_passives(actor, campaign)
		dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_INFORMATION_OBTAINED,
			campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION})
	for companion in campaign.companion_states:
		refresh_information_passives(companion, campaign)
		dispatch_passive_trigger(companion, PassiveSkillData.Trigger.ON_INFORMATION_OBTAINED,
			campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION})


## Também é chamado quando um Evento concede uma passiva depois de o grupo
## já ter Informações. Assim ela nasce com o bônus correto, sem esperar outra.
func refresh_information_passives(actor: EntityState, campaign: CampaignState) -> void:
	if actor == null or campaign == null:
		return
	var information_count := campaign.obtained_information_ids.size()
	for grant in get_passive_candidates(actor, PassiveSkillData.Trigger.ON_INFORMATION_OBTAINED,
			HexGrid.PPPMapMode.EXPLORATION):
		var passive := grant.skill as PassiveSkillData
		for effect in passive.effects:
			_recalculate_information_effect(actor, grant, effect, information_count)
		for effect in passive.continuous_effects:
			_recalculate_information_effect(actor, grant, effect, information_count)


func _recalculate_information_effect(actor: EntityState, grant: SkillGrantState,
		effect: SkillEffectData, information_count: int) -> void:
	if effect == null or not effect.recalculate_bonus_instead_of_stacking:
		return
	match effect.effect_type:
		SkillEffectData.EffectType.MODIFY_MASTERY:
			if effect.scaling_source != SkillEffectData.ScalingSource.GROUP_INFORMATION_COUNT:
				return
			var desired := 0
			if information_count >= effect.first_threshold:
				desired = effect.initial_bonus
				if effect.step_interval > 0:
						desired += floori(float(information_count) / effect.step_interval) * effect.step_bonus
				if effect.max_total_bonus > 0:
					desired = mini(desired, effect.max_total_bonus)
			for mastery in effect.mastery_options:
				_replace_contribution(actor, grant, "mastery:%d" % mastery, desired)
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT:
			var desired := _rounded_information_bonus(information_count * effect.multiplier,
				effect.rounding_mode)
			for attribute_id in effect.attribute_ids:
				if attribute_id in [&"max_hp", &"attack"]:
					_replace_contribution(actor, grant, str(attribute_id), desired)


func _rounded_information_bonus(value: float, mode: SkillEffectData.RoundingMode) -> int:
	match mode:
		SkillEffectData.RoundingMode.CEIL: return ceili(value)
		SkillEffectData.RoundingMode.NEAREST: return roundi(value)
	return floori(value)


func _replace_contribution(actor: EntityState, grant: SkillGrantState, stat_key: String,
		desired: int) -> void:
	var previous := int(grant.applied_stat_contributions.get(stat_key, 0))
	var delta := desired - previous
	if delta == 0:
		return
	_apply_stat_delta(actor, stat_key, delta)
	grant.applied_stat_contributions[stat_key] = desired


func _remove_grant_contributions(actor: EntityState, grant: SkillGrantState) -> void:
	for stat_key in grant.applied_stat_contributions:
		_apply_stat_delta(actor, stat_key, -int(grant.applied_stat_contributions[stat_key]))
	grant.applied_stat_contributions.clear()


func _apply_stat_delta(actor: EntityState, stat_key: String, delta: int) -> void:
	if stat_key.begins_with("mastery_presence:"):
		var mastery := int(stat_key.get_slice(":", 1))
		actor.granted_mastery_types[mastery] = int(actor.granted_mastery_types.get(mastery, 0)) + delta
		if actor.granted_mastery_types[mastery] <= 0:
			actor.granted_mastery_types.erase(mastery)
	elif stat_key.begins_with("mastery:"):
		var mastery := int(stat_key.get_slice(":", 1))
		actor.mastery_bonuses[mastery] = int(actor.mastery_bonuses.get(mastery, 0)) + delta
		if actor.mastery_bonuses[mastery] == 0:
			actor.mastery_bonuses.erase(mastery)
	elif stat_key == "max_hp":
		actor.max_health = maxi(1, actor.max_health + delta)
		actor.current_health = mini(actor.current_health, actor.max_health)
	elif stat_key == "attack":
		actor.attack += delta
	elif stat_key == "stamina":
		actor.max_stamina = maxi(0, actor.max_stamina + delta)
		actor.stamina_remaining = mini(actor.stamina_remaining, actor.max_stamina)
	elif stat_key == "inventory_capacity":
		actor.inventory_capacity_bonus += delta
	elif stat_key.begins_with("slot:"):
		var slot := StringName(stat_key.get_slice(":", 1))
		actor.equipment_slot_capacity_bonus[slot] = int(actor.equipment_slot_capacity_bonus.get(slot, 0)) + delta
		if actor.equipment_slot_capacity_bonus[slot] == 0:
			actor.equipment_slot_capacity_bonus.erase(slot)


## turn_owner é quem está jogando agora. actor pode ser o próprio personagem
## ou um companheiro ligado a ele; a Skill permanece no EntityState correto.
func can_use_exploration_active(
		actor: EntityState, turn_owner: EntityState, grant: SkillGrantState,
		campaign: CampaignState, selected_tile: Vector2i = EntityState.UNPLACED,
		block_manager: BlockManager = null, view: PPPMapView = null,
		pre_activation: bool = false,
		selection: Dictionary = {},
) -> bool:
	if actor == null or turn_owner == null or grant == null or campaign == null \
			or campaign.current_map == null or grant not in get_active_grants(actor):
		return false
	if catastrophe_manager != null and catastrophe_manager.skills_suppressed(
			HexGrid.PPPMapMode.EXPLORATION, false):
		return false
	var grid := campaign.current_map
	var skill := grant.skill as ActiveSkillData
	var off_turn_companion := actor != turn_owner and skill.usable_while_owner_inactive \
		and actor in campaign.companion_states \
		and actor.owner_instance_id == turn_owner.instance_id
	if (turn_owner.turn_state != EntityState.TurnState.TURNING and not off_turn_companion) \
			or actor.current_health <= 0 \
			or grid.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION \
			or skill.use_context == ActiveSkillData.UseContext.COMBAT \
			or not skill.automatic_triggers.is_empty() or skill.effects.is_empty() \
			or skill.requires_player_confirmation != pre_activation \
			or skill.ends_turn \
			or skill.requires_undesired_encounter or skill.activation_chance != 1.0:
		return false
	if actor != turn_owner and (actor.owner_instance_id != turn_owner.instance_id \
			or actor not in campaign.companion_states):
		return false
	if actor != turn_owner and turn_owner.turn_serial < actor.unavailable_until_owner_turn_serial:
		return false
	if not _has_usage_available(grant, skill, turn_owner, campaign):
		return false
	var maximum_range := _range_for(actor, skill)
	if maximum_range == -2:
		return false
	match skill.target_mode:
		ActiveSkillData.TargetMode.TILE:
			if not grid.is_valid(selected_tile):
				return false
			if maximum_range >= 0 and HexGrid.distance(actor.position, selected_tile) > maximum_range:
				return false
		ActiveSkillData.TargetMode.AREA, ActiveSkillData.TargetMode.SELF, ActiveSkillData.TargetMode.NONE, ActiveSkillData.TargetMode.ITEM:
			pass
		_:
			return false
	var context := _effect_context(actor, skill, campaign, selected_tile, maximum_range, block_manager, view)
	context["grant"] = grant
	context["turn_owner"] = turn_owner
	context["selection"] = selection
	for effect in skill.effects:
		if not effect_executor.can_execute(effect, context):
			return false
	return true


## Uma Ativa de movimento extra ainda pode ser acionada DEPOIS do primeiro
## deslocamento. Só reabre o mesmo turno; não inventa um turno novo.
func can_reactivate_extra_movement(actor: EntityState, grant: SkillGrantState,
		campaign: CampaignState) -> bool:
	if actor == null or grant == null or campaign == null \
			or campaign.current_map == null or grant not in get_active_grants(actor):
		return false
	if catastrophe_manager != null and catastrophe_manager.skills_suppressed(
			HexGrid.PPPMapMode.EXPLORATION, false):
		return false
	var skill := grant.skill as ActiveSkillData
	if skill == null or skill.use_context == ActiveSkillData.UseContext.COMBAT \
			or skill.target_mode != ActiveSkillData.TargetMode.SELF \
			or not skill.automatic_triggers.is_empty() \
			or campaign.current_map.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION \
			or not _has_usage_available(grant, skill, actor, campaign):
		return false
	return skill.effects.any(func(effect: SkillEffectData) -> bool:
		return effect.effect_type == SkillEffectData.EffectType.GRANT_EXTRA_MOVEMENT)


func use_exploration_active(
		actor: EntityState, turn_owner: EntityState, grant: SkillGrantState,
		campaign: CampaignState, selected_tile: Vector2i = EntityState.UNPLACED,
		block_manager: BlockManager = null, view: PPPMapView = null,
		pre_activation: bool = false,
		selection: Dictionary = {},
) -> bool:
	if not can_use_exploration_active(actor, turn_owner, grant, campaign, selected_tile, block_manager, view, pre_activation, selection):
		return false
	var skill := grant.skill as ActiveSkillData
	var context := _effect_context(actor, skill, campaign, selected_tile, _range_for(actor, skill), block_manager, view)
	context["grant"] = grant
	context["turn_owner"] = turn_owner
	context["selection"] = selection
	var results: Array[Dictionary] = []
	for effect in skill.effects:
		var result := effect_executor.execute(effect, context)
		if not result.get("success", false):
			return false
		results.append(result)
	last_exploration_result = {"actor_id": actor.instance_id,
		"skill_id": skill.id, "effects": results}
	_record_use(grant, turn_owner, campaign)
	active_skill_used.emit(actor, grant, {"effects": results})
	if skill.consume_skill_on_success:
		remove_source(actor, grant.source_kind, grant.source_id)
	return true


## Só é chamado depois que o SEGUNDO percurso foi validado. Desistir de andar
## não cobra a penalidade de Estamina do Universitário.
func consume_extra_movement(actor: EntityState, campaign: CampaignState) -> bool:
	if actor == null or campaign == null or actor.extra_movement_sources.is_empty():
		return false
	var grant := actor.extra_movement_sources[0]
	var skill := grant.skill as ActiveSkillData
	if skill == null:
		return false
	var context := _effect_context(actor, skill, campaign, EntityState.UNPLACED, -1, null, null)
	context["grant"] = grant
	context["turn_owner"] = actor
	for effect in skill.on_extra_movement_used_effects:
		if not effect_executor.can_execute(effect, context):
			return false
	for effect in skill.on_extra_movement_used_effects:
		var result := effect_executor.execute(effect, context)
		if not result.get("success", false):
			return false
	actor.extra_movement_sources.remove_at(0)
	return true


## Chamado quando começa um turno do dono. O Doguinho só traz o item na
## data agendada; antes disso ele continua inacessível.
func resolve_delayed_effects_for_owner(owner: EntityState, campaign: CampaignState) -> void:
	if owner == null or campaign == null:
		return
	for index in range(campaign.delayed_skill_effects.size() - 1, -1, -1):
		var pending := campaign.delayed_skill_effects[index]
		if pending.turn_owner_id != owner.instance_id \
				or owner.turn_serial < pending.due_owner_turn_serial:
			continue
		var context := {
			"actor": pending.skill_owner,
			"turn_owner": owner,
			"campaign": campaign,
			"grid": campaign.current_map,
			"inventory_manager": inventory_manager,
			"resolving_delay": true,
		}
		var result := effect_executor.execute(pending.effect, context)
		if result.get("success", false):
			campaign.delayed_skill_effects.remove_at(index)
			# A interface precisa saber qual companheiro acabou de voltar.
			result["source_actor_id"] = pending.skill_owner.instance_id
			delayed_skill_effect_resolved.emit(owner, result)


func _has_usage_available(grant: SkillGrantState, skill: ActiveSkillData, turn_owner: EntityState, campaign: CampaignState) -> bool:
	var serial := turn_owner.turn_serial
	# Os Óculos iniciam uma única tentativa por Rodada, com dois hexes no
	# mesmo turno. Passar a vez depois do primeiro perde o uso restante.
	if skill.id == &"reading_glasses_reveal" \
			and grant.last_used_round_index == campaign.get_round_index() \
			and grant.uses_in_last_round > 0 \
			and grant.last_used_turn_serial != serial:
		return false
	if skill.cooldown_turns > 0 and grant.last_used_owner_turn_serial >= 0 \
			and serial <= grant.last_used_owner_turn_serial + skill.cooldown_turns:
		return false
	if skill.max_uses_per_turn > 0 and grant.last_used_turn_serial == serial \
			and grant.uses_in_last_turn >= skill.max_uses_per_turn:
		return false
	var round_index := campaign.get_round_index()
	if skill.max_uses_per_round > 0 and grant.last_used_round_index == round_index \
			and grant.uses_in_last_round >= skill.max_uses_per_round:
		return false
	var used_today := grant.uses_in_last_day if grant.last_used_day == campaign.day else 0
	var day_limit := skill.max_uses_per_day
	if skill.usage_allowance_source == ActiveSkillData.UsageAllowanceSource.MAP_INFORMATION_BLOCKS_ACTIVATED:
		var earned := campaign.obtained_information_ids.size() * skill.uses_per_source_unit
		day_limit = earned if day_limit == 0 else mini(day_limit, earned)
		return used_today < day_limit
	return day_limit == 0 or used_today < day_limit


func _record_use(grant: SkillGrantState, turn_owner: EntityState, campaign: CampaignState) -> void:
	var serial := turn_owner.turn_serial
	if grant.last_used_turn_serial != serial:
		grant.uses_in_last_turn = 0
	grant.last_used_turn_serial = serial
	grant.uses_in_last_turn += 1
	var round_index := campaign.get_round_index()
	if grant.last_used_round_index != round_index:
		grant.uses_in_last_round = 0
	grant.last_used_round_index = round_index
	grant.uses_in_last_round += 1
	if grant.last_used_day != campaign.day:
		grant.uses_in_last_day = 0
	grant.last_used_day = campaign.day
	grant.uses_in_last_day += 1
	grant.last_used_owner_turn_serial = serial


func _range_for(actor: EntityState, skill: ActiveSkillData) -> int:
	match skill.range_mode:
		ActiveSkillData.RangeMode.FIXED: return skill.range_limit
		ActiveSkillData.RangeMode.CURRENT_STAMINA: return actor.stamina_remaining
		ActiveSkillData.RangeMode.CURRENT_STAMINA_PLUS_AMOUNT: return actor.stamina_remaining + skill.range_limit
		ActiveSkillData.RangeMode.HALF_CURRENT_STAMINA: return floori(actor.stamina_remaining / 2.0)
	return -2


func _effect_context(
		actor: EntityState, skill: ActiveSkillData, campaign: CampaignState,
		selected_tile: Vector2i, maximum_range: int,
		block_manager: BlockManager, view: PPPMapView,
) -> Dictionary:
	var entities: Array[EntityState] = []
	entities.append_array(campaign.active_entity_states)
	entities.append_array(campaign.companion_states)
	return {
		"actor": actor, "skill": skill, "campaign": campaign,
		"grid": campaign.current_map, "selected_tile": selected_tile,
		"range": maximum_range, "block_manager": block_manager,
		"view": view, "entities": entities,
		"allies": entities,
		"inventory_manager": inventory_manager,
		"skill_manager": self,
	}


func _add_if_missing(actor: EntityState, skill: Resource, source_kind: StringName, source_id: StringName,
		campaign: CampaignState = null, bound_source: Resource = null,
		bound_item_improvements: Dictionary = {}) -> SkillGrantState:
	for existing in actor.skill_grants:
		if existing.skill == skill and existing.source_kind == source_kind and existing.source_id == source_id:
			return existing
	var grant := SkillGrantState.new(skill, source_kind, source_id)
	grant.bound_source = bound_source
	grant.bound_item_improvements = bound_item_improvements.duplicate()
	var planned_stats: Dictionary = {}
	var copied_passives: Array[PassiveSkillData] = []
	if skill is PassiveSkillData:
		var passive := skill as PassiveSkillData
		for effect in passive.on_granted_effects:
			var plan := effect_executor.plan_on_granted(effect, actor, bound_source,
				bound_item_improvements)
			if not plan.get("success", false):
				push_warning("SkillManager: %s não pôde ser concedida: %s" % [passive.display_name, plan.get("reason", "efeito indisponível")])
				return null
			for key in plan["stats"]:
				planned_stats[key] = int(planned_stats.get(key, 0)) + int(plan["stats"][key])
			copied_passives.append_array(plan["passives"])
		for effect in passive.continuous_effects:
			if not effect_executor.supports_continuous(effect):
				push_warning("SkillManager: efeito contínuo não suportado em %s" % passive.display_name)
				return null
			if effect.effect_type == SkillEffectData.EffectType.MODIFY_EQUIPMENT_SLOT_CAPACITY:
				var key := "slot:%s" % effect.equipment_slot_id
				planned_stats[key] = int(planned_stats.get(key, 0)) + effect.amount
			elif effect.effect_type == SkillEffectData.EffectType.MODIFY_INVENTORY_CAPACITY:
				planned_stats["inventory_capacity"] = int(planned_stats.get("inventory_capacity", 0)) + effect.amount
	actor.skill_grants.append(grant)
	for key in planned_stats:
		_replace_contribution(actor, grant, key, int(planned_stats[key]))
	grant.on_granted_applied = true
	for index in copied_passives.size():
		var child := copied_passives[index]
		if child == null or child == skill:
			continue
		var child_id := StringName("%s:%s:copy:%d" % [source_kind, source_id, index])
		if grant_skill(actor, child, &"copied_trait", child_id, campaign) == null:
			for old_id in grant.copied_passive_source_ids:
				remove_source(actor, &"copied_trait", old_id)
			_remove_grant_contributions(actor, grant)
			actor.skill_grants.erase(grant)
			return null
		grant.copied_passive_source_ids.append(child_id)
	skill_granted.emit(actor, grant)
	return grant
