class_name CatastropheManager
extends Node

## Executa os Event_EffectData globais das catástrofes. Uma catástrofe é
## confirmada uma vez, mas suas regras vivem no CampaignState até expirar.
## Combate futuro deve chamar register_actor(), before_action() e
## on_movement_finished() para que inimigos sigam as mesmas regras.

signal catastrophe_started(event_id: StringName)
signal catastrophe_ended(event_id: StringName)
signal catastrophe_triggered(event_id: StringName, actor: EntityState, result: Dictionary)

@export var gerencia: GerenciaJogo
@export var skill_manager: SkillManager

var _rng := RandomNumberGenerator.new()
var _extra_actors: Array[EntityState] = []
var _observed: Array[EntityState] = []
var _expiring := false


func _ready() -> void:
	_rng.randomize()
	if gerencia != null:
		gerencia.campaign.companion_registered.connect(register_actor)
	if skill_manager != null:
		skill_manager.inventory_manager.item_delivered.connect(_on_item_delivered)
		skill_manager.debuff_manager.debuff_removed.connect(_on_debuff_removed)


func supports(event: EventData, outcome: EventOutcomeData) -> bool:
	if event == null or event.category != EventData.EventCategory.CATASTROPHE \
			or outcome == null or outcome.effects.is_empty():
		return false
	for effect in outcome.effects:
		if effect == null or not effect.has_duration:
			return false
		if effect.expiration_mode not in [Event_EffectData.ExpirationMode.END_OF_CURRENT_DAY,
				Event_EffectData.ExpirationMode.END_OF_CURRENT_ROUND]:
			return false
		match effect.effect_type:
			Event_EffectData.EffectType.APPLY_ITEM_STATE:
				if effect.item_state == null or effect.item_category_filter != Event_EffectData.ItemCategoryFilter.CONSUMABLE:
					return false
			Event_EffectData.EffectType.SET_MOVEMENT_LIMIT:
				if effect.amount < 1:
					return false
			Event_EffectData.EffectType.MODIFY_STAT:
				if effect.statistic not in [Event_EffectData.Statistic.MAX_HP,
						Event_EffectData.Statistic.ATTACK]:
					return false
			Event_EffectData.EffectType.MODIFY_HP:
				if effect.execution_mode != Event_EffectData.ExecutionMode.REPEAT_ON_TRIGGER:
					return false
			Event_EffectData.EffectType.SUPPRESS_SKILLS:
				pass
			Event_EffectData.EffectType.APPLY_STATUS:
				if effect.debuff == null:
					return false
			_:
				return false
	return true


## Chamado após o jogador fechar/confirmar a consequência. Nunca no sorteio
## do mapa, nem ao abrir a janela do evento.
func activate(event: EventData, outcome: EventOutcomeData) -> Dictionary:
	if gerencia == null or skill_manager == null or not supports(event, outcome):
		return {"success": false, "reason": "Catástrofe sem regra executável."}
	var campaign := gerencia.campaign
	for previous in campaign.active_catastrophes:
		if previous["event_id"] == event.id:
			return {"success": true, "already_active": true, "event_id": event.id}
	var record := {"event_id": event.id, "day": campaign.day,
		"round_index": campaign.get_round_index(), "effects": outcome.effects,
		"actor_effects": {}, "movement_used": {}}
	campaign.active_catastrophes.append(record)
	refresh_actors()
	if campaign.activate_visual_catastrophe(event.id) and gerencia.map_view != null:
		gerencia.map_view.set_visual_effects(campaign.get_active_visual_weather(),
			campaign.are_infernal_portals_visuals_active())
	catastrophe_started.emit(event.id)
	return {"success": true, "event_id": event.id}


## O combate registra cada inimigo que surge. Companheiros são registrados
## automaticamente; protagonistas são encontrados no CampaignState.
func register_actor(actor: EntityState) -> void:
	if actor == null or gerencia == null:
		return
	if actor not in _extra_actors and actor not in gerencia.campaign.active_entity_states \
			and actor not in gerencia.campaign.companion_states:
		_extra_actors.append(actor)
	_observe(actor)
	for record in gerencia.campaign.active_catastrophes:
		_apply_actor_effects(record, actor)
		_apply_item_rules_to_actor(record, actor)


func unregister_actor(actor: EntityState) -> void:
	_extra_actors.erase(actor)


func get_external_actors() -> Array[EntityState]:
	return _extra_actors.duplicate()


func refresh_actors() -> void:
	for actor in _all_actors():
		_observe(actor)
		for record in gerencia.campaign.active_catastrophes:
			_apply_actor_effects(record, actor)
			_apply_item_rules_to_actor(record, actor)


## Limite por turno, não só por clique. Vale também para movimento extra.
func allowed_movement_distance(actor: EntityState, normal_distance: int) -> int:
	var allowance := normal_distance
	if actor == null or gerencia == null:
		return allowance
	for record in gerencia.campaign.active_catastrophes:
		for effect in record["effects"]:
			if effect.effect_type != Event_EffectData.EffectType.SET_MOVEMENT_LIMIT:
				continue
			var usage: Dictionary = record["movement_used"].get(actor.get_instance_id(), {})
			var spent := int(usage.get("spent", 0)) if int(usage.get("serial", -1)) == actor.turn_serial else 0
			allowance = mini(allowance, maxi(0, effect.amount - spent))
	return allowance


## Retorna false se o dano antes da ação matou o personagem. Tentativa
## inválida não deve chamar esta função, para não cobrar dano por clique.
func before_action(actor: EntityState, rng: RandomNumberGenerator = null) -> bool:
	if actor == null or actor.current_health <= 0 or gerencia == null:
		return false
	for record in gerencia.campaign.active_catastrophes:
		for effect in record["effects"]:
			if effect.execution_mode != Event_EffectData.ExecutionMode.REPEAT_ON_TRIGGER \
					or effect.trigger_moment != Event_EffectData.TriggerMoment.BEFORE_ACTION:
				continue
			var damage: int = effect.night_amount_override if effect.use_night_amount_override \
				and gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.NIGHT else effect.amount
			var result := skill_manager.apply_incoming_damage(actor, damage, gerencia.campaign,
				{"catastrophe_id": record["event_id"]}, rng)
			catastrophe_triggered.emit(record["event_id"], actor, result)
			if actor.current_health <= 0:
				return false
	return true


## Só uma chegada por ação de movimento; hexes atravessados não disparam.
func on_movement_finished(actor: EntityState, distance: int,
		rng: RandomNumberGenerator = null) -> void:
	if actor == null or gerencia == null:
		return
	var source := rng if rng != null else _rng
	for record in gerencia.campaign.active_catastrophes:
		for effect in record["effects"]:
			if effect.effect_type == Event_EffectData.EffectType.SET_MOVEMENT_LIMIT:
				var usage: Dictionary = record["movement_used"].get(actor.get_instance_id(), {})
				var spent := int(usage.get("spent", 0)) if int(usage.get("serial", -1)) == actor.turn_serial else 0
				record["movement_used"][actor.get_instance_id()] = {"serial": actor.turn_serial,
					"spent": spent + distance}
			if effect.execution_mode != Event_EffectData.ExecutionMode.REPEAT_ON_TRIGGER \
					or effect.trigger_moment != Event_EffectData.TriggerMoment.ON_MOVE_DESTINATION \
					or actor.current_health <= 0:
				continue
			if source.randf() >= effect.activation_chance:
				continue
			var roll := 0
			for index in effect.dice_count:
				roll += source.randi_range(1, effect.dice_sides)
			var damage: int = effect.amount + roundi(float(roll) * effect.dice_result_multiplier)
			var result := skill_manager.apply_incoming_damage(actor, damage, gerencia.campaign,
				{"catastrophe_id": record["event_id"]}, source)
			catastrophe_triggered.emit(record["event_id"], actor, result)


func skills_suppressed(mode: int, passive: bool) -> bool:
	if gerencia == null:
		return false
	for record in gerencia.campaign.active_catastrophes:
		for effect in record["effects"]:
			if effect.effect_type != Event_EffectData.EffectType.SUPPRESS_SKILLS:
				continue
			if effect.skill_context_filter == Event_EffectData.SkillContext.EXPLORATION \
					and mode != HexGrid.PPPMapMode.EXPLORATION:
				continue
			if effect.skill_context_filter == Event_EffectData.SkillContext.COMBAT \
					and mode != HexGrid.PPPMapMode.COMBAT:
				continue
			if (passive and effect.suppress_passives) or (not passive and effect.suppress_actives):
				return true
	return false


## Chamar DEPOIS de trocar Dia/Rodada, ANTES de desenhar o próximo mapa.
func expire_for_current_time() -> void:
	if gerencia == null:
		return
	var campaign := gerencia.campaign
	_expiring = true
	for index in range(campaign.active_catastrophes.size() - 1, -1, -1):
		var record: Dictionary = campaign.active_catastrophes[index]
		var expired := false
		for effect in record["effects"]:
			if effect.expiration_mode == Event_EffectData.ExpirationMode.END_OF_CURRENT_DAY \
					and campaign.day != int(record["day"]):
				expired = true
			if effect.expiration_mode == Event_EffectData.ExpirationMode.END_OF_CURRENT_ROUND \
					and campaign.get_round_index() != int(record["round_index"]):
				expired = true
		if not expired:
			continue
		for actor in _all_actors():
			_remove_actor_effects(record, actor)
		campaign.active_catastrophes.remove_at(index)
		catastrophe_ended.emit(record["event_id"])
	_expiring = false
	if gerencia.map_view != null:
		gerencia.map_view.set_visual_effects(campaign.get_active_visual_weather(),
			campaign.are_infernal_portals_visuals_active())


func _all_actors() -> Array[EntityState]:
	var actors: Array[EntityState] = []
	if gerencia == null:
		return actors
	actors.append_array(gerencia.campaign.active_entity_states)
	actors.append_array(gerencia.campaign.companion_states)
	for actor in _extra_actors:
		if actor not in actors:
			actors.append(actor)
	return actors


func _observe(actor: EntityState) -> void:
	if actor == null or actor in _observed:
		return
	_observed.append(actor)
	actor.equipment_changed.connect(_on_equipment_changed.bind(actor))


func _on_equipment_changed(actor: EntityState) -> void:
	if gerencia == null:
		return
	for record in gerencia.campaign.active_catastrophes:
		if record["event_id"] != CampaignState.NEVASCA_EVENT_ID:
			continue
		_remove_actor_effects(record, actor)
		_apply_actor_effects(record, actor)


func _apply_actor_effects(record: Dictionary, actor: EntityState) -> void:
	if actor == null or actor.current_health <= 0 or record["actor_effects"].has(actor.get_instance_id()):
		return
	var applied := {"max_hp_delta": 0, "attack_delta": 0, "status": null}
	for effect in record["effects"]:
		if effect.effect_type == Event_EffectData.EffectType.MODIFY_STAT:
			if _immune_by_equipment(actor, effect):
				continue
			var basis := actor.max_health if effect.statistic == Event_EffectData.Statistic.MAX_HP else actor.attack
			var value: float = float(basis) * effect.percent if effect.percent > 0.0 else float(effect.amount)
			var amount := ceili(value) if effect.rounding_mode == Event_EffectData.RoundingMode.CEIL else floori(value)
			if effect.statistic == Event_EffectData.Statistic.MAX_HP:
				var delta := maxi(1, actor.max_health - amount) - actor.max_health
				actor.max_health += delta
				actor.current_health = mini(actor.current_health, actor.max_health)
				applied["max_hp_delta"] = delta
			else:
				var delta := maxi(effect.stat_minimum, actor.attack - amount) - actor.attack
				actor.attack += delta
				applied["attack_delta"] = delta
		elif effect.effect_type == Event_EffectData.EffectType.APPLY_STATUS:
			# Se já existia Tristeza de outra origem, não a confiscamos na virada.
			if not skill_manager.is_status_immune(actor, effect.debuff.id) \
					and skill_manager.debuff_manager.get_debuff(actor, effect.debuff.id) == null:
				var result := skill_manager.debuff_manager.apply_debuff(actor, effect.debuff,
					null, 0, gerencia.campaign.day, -1, record["event_id"])
				if result.get("success", false):
					applied["status"] = result["instance"]
	record["actor_effects"][actor.get_instance_id()] = applied


func _remove_actor_effects(record: Dictionary, actor: EntityState) -> void:
	if actor == null or not record["actor_effects"].has(actor.get_instance_id()):
		return
	var applied: Dictionary = record["actor_effects"][actor.get_instance_id()]
	actor.max_health -= int(applied["max_hp_delta"])
	actor.attack -= int(applied["attack_delta"])
	# Recuperar o teto de Vida não cura automaticamente a Vida atual.
	actor.current_health = mini(actor.current_health, actor.max_health)
	var status := applied["status"] as DebuffInstanceState
	if status != null and status in actor.debuffs \
			and status.source_key == record["event_id"]:
		skill_manager.debuff_manager.remove_debuff(actor, status.data.id)
	record["actor_effects"].erase(actor.get_instance_id())


func _immune_by_equipment(actor: EntityState, effect: Event_EffectData) -> bool:
	if effect.excluded_equipped_slot != ItemData.EquipmentSlot.ARMOR:
		return false
	for entry in actor.equipped_armors:
		if entry != null and entry.data != null \
				and entry.data.rarity == effect.excluded_equipped_rarity:
			return true
	return false


func _apply_item_state(entry: InventoryItemState, effect: Event_EffectData) -> void:
	if entry == null or entry.data == null or effect.item_state == null \
			or entry.data.item_type != ItemData.ItemType.CONSUMABLE:
		return
	for state in entry.states:
		if state != null and state.id == effect.item_state.id:
			return
	entry.states.append(effect.item_state)


func _apply_item_rules_to_actor(record: Dictionary, actor: EntityState) -> void:
	if actor == null:
		return
	for effect in record["effects"]:
		if effect.effect_type != Event_EffectData.EffectType.APPLY_ITEM_STATE \
				or not effect.apply_item_state_to_existing:
			continue
		for entry in actor.inventory_items:
			_apply_item_state(entry, effect)


func _on_item_delivered(recipient: EntityState, item: ItemData) -> void:
	if gerencia == null or recipient == null or item == null:
		return
	for record in gerencia.campaign.active_catastrophes:
		for effect in record["effects"]:
			if effect.effect_type != Event_EffectData.EffectType.APPLY_ITEM_STATE \
					or not effect.apply_item_state_to_future_acquisitions:
				continue
			# add_item/craft emitem depois de inserir a nova cópia no final.
			if not recipient.inventory_items.is_empty():
				_apply_item_state(recipient.inventory_items.back(), effect)


func _on_debuff_removed(actor: EntityState, debuff_id: StringName) -> void:
	if _expiring or gerencia == null or actor == null or actor.current_health <= 0:
		return
	# A Áurea é um ambiente contínuo: curar Tristeza enquanto ela ainda
	# cobre a cidade não torna o personagem imune ao seu efeito global.
	for record in gerencia.campaign.active_catastrophes:
		if record["event_id"] != CampaignState.AURA_FUNEBRE_EVENT_ID:
			continue
		for effect in record["effects"]:
			if effect.effect_type == Event_EffectData.EffectType.APPLY_STATUS \
					and effect.debuff != null and effect.debuff.id == debuff_id:
				record["actor_effects"].erase(actor.get_instance_id())
				_apply_actor_effects(record, actor)
				return
