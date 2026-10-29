class_name DebuffManager
extends RefCounted

## Resolve os Debuffs de qualquer entidade. O Resource é uma receita;
## cada alvo guarda sua própria aplicação em EntityState. Não há regra de
## "inimigo" ou "jogável" aqui.

signal debuff_applied(target: EntityState, instance: DebuffInstanceState)
signal debuff_renewed(target: EntityState, instance: DebuffInstanceState)
signal debuff_removed(target: EntityState, debuff_id: StringName)
signal contagion_triggered(source: EntityState, target: EntityState, debuff_id: StringName)

const CATALOG_DIRECTORY := "res://resources/skills/effects/debuffs"
const DISEASE_STAGES: Array[StringName] = [&"db_00003", &"db_00004", &"db_00005"]
const CLEARED_ON_ROUND_CHANGE: Array[StringName] = [&"db_00007", &"db_00008"]
const DURATION_ROUND := 5

var _catalog: Dictionary = {}
var _catalog_loaded := false
var campaign: CampaignState


## Novos .tres nesta pasta entram no catálogo automaticamente. Também é
## possível registrar um Resource criado em teste ou concedido por evento.
func find_debuff(debuff_id: StringName) -> DebuffData:
	_load_catalog()
	return _catalog.get(debuff_id) as DebuffData


func register_debuff(data: DebuffData) -> bool:
	if data == null or data.id == &"":
		return false
	_catalog[data.id] = data
	return true


func _load_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	for filename in ResourceLoader.list_directory(CATALOG_DIRECTORY):
		if not filename.ends_with(".tres"):
			continue
		var data := ResourceLoader.load(CATALOG_DIRECTORY.path_join(filename)) as DebuffData
		if data != null:
			register_debuff(data)


func get_debuff(target: EntityState, debuff_id: StringName) -> DebuffInstanceState:
	if target == null:
		return null
	for instance in target.debuffs:
		if instance != null and instance.data != null and instance.data.id == debuff_id:
			return instance
	return null


func get_debuff_ids(target: EntityState) -> Array[StringName]:
	var ids: Array[StringName] = []
	if target != null:
		for instance in target.debuffs:
			if instance != null and instance.data != null:
				ids.append(instance.data.id)
	return ids


## Reaplicar o MESMO Debuff renova sua duração e usa a nova fonte/força,
## sem duplicar os modificadores. Uma Doença não volta a um estágio menor.
func apply_debuff(target: EntityState, data: DebuffData,
		source: EntityState = null, initial_tick_damage: int = 0,
		current_day: int = 1, duration_override: int = -1,
		source_key: StringName = &"", resistance_chance_override: float = -1.0,
		source_die_result: int = 0) -> Dictionary:
	if target == null or data == null or data.id == &"" or target.current_health <= 0:
		return {"success": false, "reason": "Alvo ou Debuff inválido."}
	if target.is_innately_immune_to_status(data.id):
		return {"success": false, "immune": true}
	# A imunidade concedida por Eventos mora no personagem. Conferir aqui também
	# impede que contágio e outras aplicações diretas ignorem essa proteção.
	if data.id in target.permanent_status_immunities \
			or data.id in target.temporary_status_immunities \
			or target.has_divine_amulet_status_immunity(data.id):
		return {"success": false, "immune": true}
	if data.duration_from_die_result and source_die_result <= 0:
		return {"success": false, "reason": "Falta o resultado do dado da fonte."}
	if data.ends_when_tick_damage_reaches_zero and initial_tick_damage <= 0:
		return {"success": false, "reason": "Falta o dano inicial causado pela fonte."}
	var incoming_stage := DISEASE_STAGES.find(data.id)
	if incoming_stage >= 0:
		for stage_index in DISEASE_STAGES.size():
			var old := get_debuff(target, DISEASE_STAGES[stage_index])
			if old == null:
				continue
			if stage_index > incoming_stage:
				return {"success": true, "instance": old, "ignored_weaker_stage": true}
			if stage_index < incoming_stage:
				remove_debuff(target, old.data.id)
			break
	var existing := get_debuff(target, data.id)
	var identity := source_key
	if identity == &"" and source != null and source.data != null:
		identity = source.data.id
	if existing != null:
		existing.source = source
		existing.exploration_event_control = false
		existing.source_instance_id = source.instance_id if source != null else &""
		existing.source_key = identity
		existing.resistance_chance_base = resistance_chance_override if resistance_chance_override >= 0.0 else data.percent
		existing.current_tick_damage = data.fixed_damage_per_tick if data.fixed_damage_per_tick > 0 else maxi(0, initial_tick_damage)
		_set_duration(existing, target, current_day,
			source_die_result if data.duration_from_die_result else duration_override)
		if data.duration_type == DebuffData.DurationType.UNTIL_RESIST:
			existing.active_controls.clear()
		debuff_renewed.emit(target, existing)
		return {"success": true, "instance": existing, "renewed": true}
	var instance := DebuffInstanceState.new(data, source)
	instance.duration_kind = data.duration_type
	instance.source_key = identity
	instance.resistance_chance_base = resistance_chance_override if resistance_chance_override >= 0.0 else data.percent
	instance.current_tick_damage = data.fixed_damage_per_tick if data.fixed_damage_per_tick > 0 else maxi(0, initial_tick_damage)
	_set_duration(instance, target, current_day,
		source_die_result if data.duration_from_die_result else duration_override)
	_apply_modifiers(target, instance)
	target.debuffs.append(instance)
	if data.duration_type != DebuffData.DurationType.UNTIL_RESIST:
		_activate_controls(instance)
	debuff_applied.emit(target, instance)
	return {"success": true, "instance": instance, "renewed": false}


func apply_by_id(target: EntityState, debuff_id: StringName,
		source: EntityState = null, initial_tick_damage: int = 0,
		current_day: int = 1, duration_override: int = -1,
		source_key: StringName = &"", resistance_chance_override: float = -1.0,
		source_die_result: int = 0) -> Dictionary:
	return apply_debuff(target, find_debuff(debuff_id), source,
		initial_tick_damage, current_day, duration_override,
		source_key, resistance_chance_override, source_die_result)


## Ponte para outcomes de Eventos. O futuro EventExecutor decide QUEM é o
## alvo e calcula o dado; esta função só aplica/retira o status resultante.
func apply_event_effect(effect: Event_EffectData, target: EntityState,
		source: EntityState, campaign: CampaignState,
		calculated_value: int = 0, event_id: StringName = &"",
		skill_manager: Variant = null, source_die_result: int = 0) -> Dictionary:
	if effect == null or target == null or campaign == null:
		return {"success": false}
	if effect.effect_type == Event_EffectData.EffectType.REMOVE_STATUS:
		var ids: Array[StringName] = []
		ids.assign(effect.status_ids)
		if effect.debuff != null and effect.debuff.id not in ids:
			ids.append(effect.debuff.id)
		return {"success": true, "removed": remove_debuffs(target, ids)}
	if effect.effect_type != Event_EffectData.EffectType.APPLY_STATUS or effect.debuff == null:
		return {"success": false}
	if skill_manager != null and skill_manager.is_status_immune(target, effect.debuff.id):
		return {"success": false, "immune": true}
	var initial_damage := calculated_value if effect.status_initial_tick_damage_from_value else 0
	var duration := effect.duration_amount
	if effect.has_duration and effect.duration_source == Event_EffectData.DurationSource.DICE_ROLL:
		if source_die_result <= 0:
			return {"success": false, "reason": "Falta o resultado do dado de duração."}
		duration = source_die_result
	var result := apply_debuff(target, effect.debuff, source, initial_damage,
		campaign.day, duration if effect.has_duration else -1, event_id,
		-1.0, source_die_result)
	if not result.get("success", false) or not effect.has_duration:
		return result
	var instance := result["instance"] as DebuffInstanceState
	match effect.duration_unit:
		Event_EffectData.DurationUnit.TURN:
			instance.duration_kind = DebuffData.DurationType.TURNS
			instance.remaining_turns = maxi(1, duration)
		Event_EffectData.DurationUnit.ROUND:
			instance.duration_kind = DURATION_ROUND
			instance.expiration_round_index = campaign.get_round_index() + maxi(1, duration)
		Event_EffectData.DurationUnit.DAY:
			instance.duration_kind = DebuffData.DurationType.DAYS
			instance.remaining_days = maxi(1, duration)
		Event_EffectData.DurationUnit.PERMANENT:
			instance.duration_kind = DebuffData.DurationType.PERMANENT
	return result


func remove_debuff(target: EntityState, debuff_id: StringName) -> bool:
	var instance := get_debuff(target, debuff_id)
	if instance == null:
		return false
	target.debuffs.erase(instance)
	target.max_health -= instance.applied_max_health_delta
	target.max_health += instance.accrued_max_health_loss
	target.attack -= instance.applied_attack_delta
	target.max_stamina -= instance.applied_stamina_delta
	# Restaurar a Vida máxima não cura os pontos que já foram perdidos.
	target.current_health = mini(target.current_health, target.max_health)
	target.stamina_remaining = mini(target.stamina_remaining, target.max_stamina)
	debuff_removed.emit(target, debuff_id)
	return true


func remove_debuffs(target: EntityState, ids: Array[StringName]) -> int:
	var removed := 0
	for debuff_id in ids:
		if remove_debuff(target, debuff_id):
			removed += 1
	return removed


func _set_duration(instance: DebuffInstanceState, target: EntityState,
		current_day: int, duration_override: int) -> void:
	var amount := duration_override if duration_override >= 0 else instance.data.duration_amount
	instance.duration_kind = instance.data.duration_type
	instance.expiration_round_index = -1
	instance.applied_turn_serial = target.turn_serial
	instance.applied_day = current_day
	match instance.duration_kind:
		DebuffData.DurationType.TURNS:
			instance.remaining_turns = amount
		DebuffData.DurationType.DAYS:
			# Zero em um Resource diário significa "até a próxima virada".
			instance.remaining_days = maxi(1, amount)


func _apply_modifiers(target: EntityState, instance: DebuffInstanceState) -> void:
	var data := instance.data
	var new_max := maxi(1, target.max_health + data.max_health_modifier)
	instance.applied_max_health_delta = new_max - target.max_health
	target.max_health = new_max
	target.current_health = mini(target.current_health, target.max_health)
	var new_attack := maxi(0, target.attack + data.attack_modifier)
	instance.applied_attack_delta = new_attack - target.attack
	target.attack = new_attack
	var new_stamina := maxi(0, target.max_stamina + data.stamina_modifier)
	instance.applied_stamina_delta = new_stamina - target.max_stamina
	target.max_stamina = new_stamina
	target.stamina_remaining = mini(target.stamina_remaining, target.max_stamina)


## O mesmo campo percent dos .tres governa o controle condicional. Sem
## percentual, um controle listado é garantido (como Impedido de Consumir).
func _activate_controls(instance: DebuffInstanceState,
		rng: RandomNumberGenerator = null) -> void:
	instance.active_controls.clear()
	var chance := instance.data.percent if instance.data.percent > 0.0 else 1.0
	for control in instance.data.control_effects:
		var source := rng if rng != null else campaign.world_rng if campaign != null else null
		if chance >= 1.0 or (source.randf() if source != null else randf()) < chance:
			instance.active_controls.append(control)


func has_control(target: EntityState, control: DebuffData.ControlEffect) -> bool:
	if target == null:
		return false
	for instance in target.debuffs:
		if instance != null and int(control) in instance.active_controls:
			return true
	return false


func can_take_action(target: EntityState) -> bool:
	return not has_control(target, DebuffData.ControlEffect.LOSE_TURN)


func has_exploration_event_control(target: EntityState) -> bool:
	if target == null:
		return false
	for instance in target.debuffs:
		if instance != null and instance.exploration_event_control \
				and int(DebuffData.ControlEffect.LOSE_TURN) in instance.active_controls:
			return true
	return false


func release_exploration_event_turn_controls(target: EntityState) -> bool:
	if target == null:
		return false
	var released := false
	for instance in target.debuffs.duplicate():
		if instance != null and instance.exploration_event_control \
				and instance.duration_kind == DebuffData.DurationType.TURNS \
				and int(DebuffData.ControlEffect.LOSE_TURN) in instance.active_controls:
			released = remove_debuff(target, instance.data.id) or released
	return released


func can_attack(target: EntityState) -> bool:
	return can_take_action(target) and not has_control(target, DebuffData.ControlEffect.CANT_ATTACK)


func can_use_consumable(target: EntityState) -> bool:
	return can_take_action(target) and not has_control(target, DebuffData.ControlEffect.CANT_USE_CONSUMABLES)


func can_move_to(target: EntityState, destination: Vector2i) -> bool:
	if target == null:
		return false
	return _can_move_step(target, target.position, destination)


func _can_move_step(target: EntityState, origin: Vector2i,
		destination: Vector2i) -> bool:
	if not can_take_action(target) or has_control(target, DebuffData.ControlEffect.CANT_MOVE):
		return false
	for instance in target.debuffs:
		if instance == null or instance.source == null \
				or instance.source.position == EntityState.UNPLACED:
			continue
		var before := HexGrid.distance(origin, instance.source.position)
		var after := HexGrid.distance(destination, instance.source.position)
		if DebuffData.ControlEffect.TOWARD_SOURCE in instance.active_controls and after >= before:
			return false
		if DebuffData.ControlEffect.AWAY_FROM_SOURCE in instance.active_controls and after <= before:
			return false
	return true


func can_follow_path(target: EntityState, path: Array[Vector2i]) -> bool:
	if target == null or path.is_empty():
		return false
	var previous := target.position
	for step in path:
		# Um controle direcional vale em CADA passo, não só no destino final.
		if not _can_move_step(target, previous, step):
			return false
		previous = step
	return true


func consumable_modifier(target: EntityState) -> int:
	var amount := 0
	if target != null:
		for instance in target.debuffs:
			if instance != null:
				amount += instance.data.consumable_modifier
	return amount


## Chame no começo do turno do AFETADO. Cada instância só processa uma vez
## por serial, mesmo que o jogador alterne a seleção antes de agir.
func on_turn_started(target: EntityState, campaign: CampaignState,
		skill_manager: Variant, rng: RandomNumberGenerator = null,
		allies: Array[EntityState] = []) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or campaign == null or skill_manager == null:
		return results
	for instance in target.debuffs.duplicate():
		if instance.last_turn_start_serial == target.turn_serial:
			continue
		instance.last_turn_start_serial = target.turn_serial
		if instance.duration_kind == DebuffData.DurationType.UNTIL_RESIST:
			var bonus := float(target.terror_resistance_bonus_by_source.get(instance.source_key, 0.0)) \
				if instance.data.id == &"db_00009" else 0.0
			var chance := clampf(instance.resistance_chance_base + bonus, 0.0, 1.0)
			var source := rng if rng != null else campaign.world_rng if campaign != null else null
			if (source.randf() if source != null else randf()) < chance:
				remove_debuff(target, instance.data.id)
				if instance.data.id == &"db_00009" and instance.source_key != &"":
					target.terror_resistance_bonus_by_source[instance.source_key] = minf(1.0, bonus + 0.05)
				results.append({"debuff_id": instance.data.id, "resisted": true,
					"resistance_chance_next_time": minf(1.0, chance + 0.05)})
				continue
			# Falhou em resistir: este turno aplica o controle da fonte.
			instance.active_controls.clear()
			for control in instance.data.control_effects:
				instance.active_controls.append(control)
		else:
			_activate_controls(instance, rng)
		if instance.data.tick_moment == DebuffData.TickMoment.ON_TURN_START:
			results.append(_tick_damage(target, instance, campaign, skill_manager, rng))
	return results


func on_turn_finished(target: EntityState, campaign: CampaignState,
		skill_manager: Variant, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or campaign == null or skill_manager == null:
		return results
	for instance in target.debuffs.duplicate():
		if instance.last_turn_end_serial == target.turn_serial:
			continue
		instance.last_turn_end_serial = target.turn_serial
		if instance.data.tick_moment == DebuffData.TickMoment.ON_TURN_END:
			results.append(_tick_damage(target, instance, campaign, skill_manager, rng))
		if instance in target.debuffs and instance.duration_kind == DebuffData.DurationType.TURNS \
				and instance.remaining_turns > 0 and instance.applied_turn_serial != target.turn_serial:
			instance.remaining_turns -= 1
			if instance.remaining_turns <= 0:
				remove_debuff(target, instance.data.id)
	return results


func on_day_started(target: EntityState, campaign: CampaignState,
		skill_manager: Variant, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or campaign == null or skill_manager == null:
		return results
	for instance in target.debuffs.duplicate():
		if instance.last_day_start == campaign.day:
			continue
		instance.last_day_start = campaign.day
		if instance.applied_day == campaign.day:
			continue
		var stage := DISEASE_STAGES.find(instance.data.id)
		if stage >= 0 and stage < DISEASE_STAGES.size() - 1:
			var next_stage := find_debuff(DISEASE_STAGES[stage + 1])
			if next_stage != null:
				results.append(apply_debuff(target, next_stage, instance.source,
					0, campaign.day, -1, instance.source_key))
			continue
		if instance.data.max_health_loss_per_day > 0:
			# Só a virada SEGUINTE à aplicação perde Vida máxima.
			var actual := mini(instance.data.max_health_loss_per_day,
				target.max_health - 1)
			target.max_health -= actual
			target.current_health = mini(target.current_health, target.max_health)
			instance.accrued_max_health_loss += actual
			results.append({"debuff_id": instance.data.id,
				"max_health_lost": actual})
		if instance.duration_kind == DebuffData.DurationType.DAYS:
			instance.remaining_days -= 1
			if instance.remaining_days <= 0:
				remove_debuff(target, instance.data.id)
				continue
		if instance.data.tick_moment == DebuffData.TickMoment.ON_DAY_START:
			results.append(_tick_damage(target, instance, campaign, skill_manager, rng))
	return results


func _try_spread_status(target: EntityState, instance: DebuffInstanceState,
		campaign: CampaignState, skill_manager: Variant,
		rng: RandomNumberGenerator, allies: Array[EntityState]) -> Dictionary:
	var source := rng if rng != null else campaign.world_rng if campaign != null else null
	if instance.data.contagion_result_id == &"" \
			or (source.randf() if source != null else randf()) >= instance.data.contagion_chance_per_round:
		return {}
	var pool := allies
	if pool.is_empty():
		pool = skill_manager.get_allies_for_passive(target, campaign)
	var nearest: EntityState = null
	var best_distance := 999999
	for ally in pool:
		if ally == null or ally == target or ally.current_health <= 0:
			continue
		var distance := HexGrid.distance(target.position, ally.position)
		if distance < best_distance:
			best_distance = distance
			nearest = ally
	if nearest == null:
		return {}
	var result := apply_by_id(nearest, instance.data.contagion_result_id,
		target, 0, campaign.day)
	if result.get("success", false) and not result.get("ignored_weaker_stage", false) \
			and not result.get("renewed", false):
		contagion_triggered.emit(target, nearest, instance.data.contagion_result_id)
	return {"debuff_id": instance.data.id, "spread_to": nearest,
		"result": result}


func on_round_started(target: EntityState, campaign: CampaignState,
		skill_manager: Variant, rng: RandomNumberGenerator = null,
		allies: Array[EntityState] = [],
		eligible_instance_ids: Dictionary = {},
		restrict_to_snapshot: bool = false) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or campaign == null or skill_manager == null:
		return results
	for instance in target.debuffs.duplicate():
		if instance.data.id in CLEARED_ON_ROUND_CHANGE:
			if remove_debuff(target, instance.data.id):
				results.append({"debuff_id": instance.data.id, "expired": true})
			continue
		if instance.duration_kind == DURATION_ROUND \
				and instance.expiration_round_index >= 0 \
				and campaign.get_round_index() >= instance.expiration_round_index:
			if remove_debuff(target, instance.data.id):
				results.append({"debuff_id": instance.data.id, "expired": true})
			continue
		if instance.data.contagion_chance_per_round > 0.0 \
				and (not restrict_to_snapshot or eligible_instance_ids.has(instance.get_instance_id())):
			var spread := _try_spread_status(target, instance, campaign,
				skill_manager, rng, allies)
			if not spread.is_empty():
				results.append(spread)
	return results


## Chamado UMA vez por ação de movimento concluída, não por hex atravessado.
func on_moved(target: EntityState, campaign: CampaignState,
		skill_manager: Variant, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if target == null or campaign == null or skill_manager == null:
		return results
	for instance in target.debuffs:
		if instance.data.damage_on_move <= 0:
			continue
		var damage: Dictionary = skill_manager.apply_incoming_damage(target,
			instance.data.damage_on_move, campaign,
			{"damage_source": instance.source, "status_id": instance.data.id}, rng)
		results.append({"debuff_id": instance.data.id, "damage": damage})
	return results


func _tick_damage(target: EntityState, instance: DebuffInstanceState,
		campaign: CampaignState, skill_manager: Variant,
		rng: RandomNumberGenerator) -> Dictionary:
	var data := instance.data
	if data.change_tick_damage_before_applying:
		instance.current_tick_damage = maxi(0, instance.current_tick_damage + data.damage_change_per_tick)
	var amount := instance.current_tick_damage
	var damage: Dictionary = {}
	if amount > 0:
		damage = skill_manager.apply_incoming_damage(target, amount, campaign,
			{"damage_source": instance.source, "status_id": data.id}, rng)
	if not data.change_tick_damage_before_applying:
		instance.current_tick_damage = maxi(0, instance.current_tick_damage + data.damage_change_per_tick)
	if data.ends_when_tick_damage_reaches_zero and instance.current_tick_damage <= 0:
		remove_debuff(target, data.id)
	return {"debuff_id": data.id, "damage": damage, "tick_value": amount}
