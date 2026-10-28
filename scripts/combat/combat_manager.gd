class_name CombatManager
extends Node

## Monta o início de qualquer Encontro: cria instâncias hostis, escolhe hexes,
## desenha silhuetas provisórias, dispara passivas de início, calcula iniciativa
## e executa o ciclo básico de movimento e ataque. Skills especiais de Combate
## continuam delegadas ao SkillManager/SkillEffectExecutor.
## O retorno à Exploração só ocorre após confirmar a janela de desfecho.

signal combat_prepared(encounter: EncounterData, enemies: Array[EntityState], initiative: Array[Dictionary])
signal enemy_summoned(enemy: EntityState, summoner: EntityState, acts_immediately: bool)
signal ally_revived(ally: EntityState)
signal conclusion_requested(title: String, narrative: String, rewards: Array[Resource])
signal combat_finished(result: Dictionary)
signal turn_started(actor: EntityState, cycle_number: int)
signal turn_finished(actor: EntityState)
signal action_resolved(actor: EntityState, action: StringName, details: Dictionary)
signal hit_prepared(target: EntityState)
signal die_rolled(actor: EntityState, result: int)
signal combat_trap_requested(event: EventData, actor: EntityState, coord: Vector2i)
signal recruitment_choice_requested(enemy: EntityState, chance: float,
	information_names: String)
signal enemy_inspected(enemy: EntityState)
signal loot_item_delivered(recipient: EntityState, item: ItemData)

const ENEMY_SILHOUETTE_SCRIPT = preload("res://scripts/visuals/enemy_silhouette_visual.gd")
const ENEMY_AI_SCRIPT = preload("res://scripts/combat/enemy_combat_ai.gd")
const LOOT_RESOLVER = preload("res://scripts/combat/combat_loot_resolver.gd")

@export var gerencia: GerenciaJogo
@export var block_manager: BlockManager
@export var skill_manager: SkillManager
@export var map_view: PPPMapView
@export var enemy_visual_root: Node2D
@export var event_executor: EventExecutor
@export var auto_start_turns: bool = true

var enemies: Array[EntityState] = []
var initiative_order: Array[Dictionary] = []
var current_encounter: EncounterData
var pending_conclusion: Dictionary = {}
var current_actor: EntityState
var combat_cycle: int = 0
var action_mode: StringName = &""
var _combat_serial: int = 0
var _rng := RandomNumberGenerator.new()
var _ai = ENEMY_AI_SCRIPT.new()
var _combat_id: StringName = &""
var _turn_index: int = -1
var _turn_die: int = 0
var _steps_moved: int = 0
var _attacks_used: int = 0
var _turn_moved: bool = false
var _retaliation_by_enemy: Dictionary = {}
var _exploration_snapshot: Dictionary = {}
var _combat_turns_by_id: Dictionary = {}
var _encounter_automatic_skill_uses: Dictionary = {} # ActiveSkillData.id -> usado pela horda
var _saved_selection_validator: Callable
var _saved_destination_validator: Callable
var _combat_interaction_enabled: bool = false
var _promotion_cleanup_pending: bool = false
var _pending_trap: Dictionary = {}
var _pending_attack_coord := EntityState.UNPLACED
var _timed_attack_penalties: Array[Dictionary] = []
var _damage_guards: Dictionary = {}
var _guard_reductions: Dictionary = {}
var _guard_expiry_turn_by_id: Dictionary = {}
var _next_attack_bonuses: Dictionary = {} # instance_id -> {actor, amount}
var _mother_attack_bonuses: Dictionary = {} # instance_id -> {actor, amount, expires_turn}
var _encounter_reveal_sources: Array[StringName] = []
var _selected_skill_grant: SkillGrantState
var _previous_skill_targets: Dictionary = {}
var _pending_recruitment: Dictionary = {}
var _recruitment_feedback_pending := false
var _attack_animation_pending := false
var _last_enemy_click_position := Vector2.INF
var _last_enemy_click_index := 0
var _solo_actor: EntityState
var _solo_restored := false
var _pending_event_reward: ItemData
var _event_reward_claimed := false
var _loot_participant_ids: Dictionary = {}
var _loot_entry_max_health := 0
var _loot_damage_taken := 0
var _loot_rolled := false
var _loot_items: Array[ItemData] = []
var _loot_resolved_count := 0
var _loot_resolutions: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	if skill_manager != null:
		skill_manager.incoming_damage_applied.connect(_on_incoming_damage_applied)
	if block_manager != null:
		block_manager.combat_requested.connect(_on_combat_requested)
	if gerencia != null:
		gerencia.map_generated.connect(func(_map: HexGrid) -> void: _clear_session())
	# A HUD recebe o clique e oferece a escolha contextual; esta classe expõe
	# player_move/player_attack, sem antecipar a escolha do jogador.


func _on_combat_requested(context: Dictionary) -> void:
	_clear_session()
	if gerencia == null or gerencia.campaign == null:
		return
	var campaign := gerencia.campaign
	var request: Dictionary = context.get("combat_request", {})
	current_encounter = request.get("encounter") as EncounterData
	if current_encounter == null:
		current_encounter = context.get("resource") as EncounterData
	_encounter_reveal_sources.clear()
	var grid := campaign.current_map
	var source_coord: Vector2i = context.get("coord", EntityState.UNPLACED)
	if grid != null and grid.revealed_by_skill_ids.has(source_coord):
		_encounter_reveal_sources.assign(grid.revealed_by_skill_ids[source_coord])
	_combat_serial += 1
	var combat_id := StringName("combat:%d:%d" % [campaign.get_round_index(), _combat_serial])
	_combat_id = combat_id
	_snapshot_exploration_turns(campaign)
	var activator := context.get("actor") as EntityState
	_solo_actor = request.get("solo_actor") as EntityState
	_solo_restored = false
	if _solo_actor != null and (_solo_actor not in campaign.active_entity_states \
			or _solo_actor.current_health <= 0):
		_solo_actor = null
	if _solo_actor != null:
		for member in campaign.active_entity_states + campaign.companion_states:
			if member != null and member != _solo_actor:
				member.temporarily_absent_from_map = true
		campaign.temporary_event_changed.emit()
	# O limiar é fotografado ANTES das passivas de abertura causarem dano.
	_capture_loot_participants()
	var occupied: Dictionary = {}
	for playable in _combat_playables():
		if playable != null and playable.position != EntityState.UNPLACED:
			occupied[playable.position] = true
	if _solo_actor == null:
		# Reserva primeiro os hexes dos aliados: hostis não podem tomar todas as
		# vagas até dois passos do dono e empurrá-los para fora do combate.
		_place_companions_for_combat(campaign)
		for companion in campaign.companion_states:
			if companion != null and companion.current_health > 0 \
					and companion.position != EntityState.UNPLACED:
				occupied[companion.position] = true
	var exit_narrative := ""
	var exit_requested := false
	if current_encounter != null:
		for member in current_encounter.members:
			if member == null or member.entity == null:
				continue
			var count := _rng.randi_range(member.minimum, member.maximum)
			for index in count:
				# Imobilidade do Resource sobrepõe distância/proximidade do Encontro.
				var spawn := _choose_immobile_spawn(campaign.current_map, occupied) \
					if _is_immobile_enemy(member.entity) else \
					_choose_spawn(campaign.current_map, activator, occupied)
				if spawn == EntityState.UNPLACED:
					push_warning("CombatManager: sem hex livre para %s." % member.entity.display_name)
					break
				occupied[spawn] = true
				var enemy := EntityState.from_encounter_member(member.entity,
					current_encounter.id, enemies.size() + 1, spawn)
				enemies.append(enemy)
				_draw_enemy(enemy)
				if skill_manager != null:
					var results := skill_manager.dispatch_passive_trigger(enemy,
						PassiveSkillData.Trigger.ON_ENCOUNTER_START, campaign,
						{"mode": HexGrid.PPPMapMode.COMBAT, "combat_id": combat_id,
						"combat_turn_number": 0, "encounter_opening": true,
						"encounter_activator": activator}, _rng)
					for result in results:
						for effect_result in result.get("effects", []):
							if effect_result.get("end_combat_requested", false):
								exit_requested = true
								var passive := (result["grant"] as SkillGrantState).skill as PassiveSkillData
								if passive != null and exit_narrative.is_empty():
									exit_narrative = passive.completion_narrative
				_apply_easy_enemy_attack_adjustment(enemy)
	if _solo_actor == null:
		_draw_silhouette_companions(campaign)
	_build_initiative(campaign)
	# Disparos de abertura usam os Resources das próprias entidades. Uma cópia
	# evita que invocações recém-criadas sejam processadas recursivamente.
	for enemy in enemies.duplicate():
		_run_automatic_actives(enemy, ActiveSkillData.AutomaticTrigger.ON_COMBAT_START)
	combat_prepared.emit(current_encounter, enemies, initiative_order)
	if exit_requested:
		if exit_narrative.is_empty():
			exit_narrative = "O Encontro terminou."
		pending_conclusion = {"title": "ENCONTRO ENCERRADO",
			"narrative": exit_narrative, "rewards": [],
			"result": {"reason": "encounter_passive_end_combat"}}
		# O popup inicial deve fechar, e os inimigos devem aparecer, antes da fala.
		call_deferred("_show_pending_conclusion")
	elif _offer_encounter_recruitment(activator, campaign):
		pass # A escolha do jogador antecede o primeiro turno do Combate.
	elif auto_start_turns:
		call_deferred("_start_combat_turns")


func _offer_encounter_recruitment(activator: EntityState,
		campaign: CampaignState) -> bool:
	if skill_manager == null or not recruitment_choice_requested.has_connections():
		return false
	var owner := activator
	if owner == null or owner not in campaign.active_entity_states:
		var playables := _combat_playables()
		owner = playables[0] if not playables.is_empty() else null
	if owner == null:
		return false
	var orchestra_active := campaign.has_active_ending(&"orchestra")
	var global_threshold := 2 if campaign.campaign_mode \
		== EventCampaignEligibility.Mode.SHORT else 4
	var global_rule: bool = not orchestra_active and campaign.campaign_mode in [
		EventCampaignEligibility.Mode.SHORT, EventCampaignEligibility.Mode.MEDIUM] \
		and current_encounter != null and current_encounter.id \
		== EventCampaignDependencies.EXPERIENCE_ENCOUNTER_ID
	for enemy in enemies:
		for grant in skill_manager.get_passive_grants(enemy):
			var passive := grant.skill as PassiveSkillData
			if passive == null or passive.trigger != PassiveSkillData.Trigger.ON_ENCOUNTER_START \
					or not passive.requires_player_confirmation \
					or passive.effects.is_empty() \
					or passive.effects[0].effect_type != SkillEffectData.EffectType.CHANGE_ALLEGIANCE:
				continue
			if global_rule and (passive.id \
					!= EventCampaignDependencies.EXPERIENCE_ONE_CLUE_PASSIVE_ID \
					or campaign.obtained_information_ids.size() < global_threshold):
				continue
			var matching := 0
			for id in passive.required_information_ids:
				if campaign.obtained_information_ids.has(id):
					matching += 1
			if not global_rule and (matching < maxi(1, passive.minimum_matching_information) \
					or passive.maximum_matching_information > 0 \
					and matching > passive.maximum_matching_information):
				continue
			_pending_recruitment = {"enemy": enemy, "owner": owner, "grant": grant,
				"global_rule": global_rule}
			var information_names: Array[String] = []
			if global_rule:
				information_names.append("contagem global de %d Informações " % \
					campaign.obtained_information_ids.size()
					+ "(mínimo %d nesta campanha)" % global_threshold)
			else:
				if campaign.obtained_information_ids.has(
						EventCampaignDependencies.EXPERIENCE_CLUE_IDS[0]):
					information_names.append("pista Orchestra 2/5")
				if campaign.obtained_information_ids.has(
						EventCampaignDependencies.EXPERIENCE_CLUE_IDS[1]):
					information_names.append("pista Orchestra 3/5")
			recruitment_choice_requested.emit(enemy, passive.activation_chance,
				" e ".join(information_names))
			return true
	return false


func confirm_encounter_recruitment(accept: bool) -> Dictionary:
	if _pending_recruitment.is_empty() or gerencia == null or skill_manager == null:
		return {"success": false}
	var request := _pending_recruitment
	_pending_recruitment = {}
	if not accept:
		if auto_start_turns:
			call_deferred("_start_combat_turns")
		return {"success": true, "accepted": false}
	var enemy := request["enemy"] as EntityState
	var owner := request["owner"] as EntityState
	var results := skill_manager.dispatch_passive_trigger(enemy,
		PassiveSkillData.Trigger.ON_ENCOUNTER_START, gerencia.campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat_id": _combat_id,
		"combat_turn_number": 0, "encounter_opening": true,
		"encounter_activator": owner, "combat": self,
		"global_experience_recruitment": request.get("global_rule", false),
		"recruitment_encounter_id": current_encounter.id,
		"player_confirmed": true}, _rng)
	var recruited := results.any(func(entry: Dictionary) -> bool:
		return entry.get("grant") == request["grant"]) \
		and enemy in gerencia.campaign.companion_states
	_recruitment_feedback_pending = true
	var grant := request["grant"] as SkillGrantState
	return {"success": true, "accepted": true, "recruited": recruited,
		"enemy": enemy, "chance": (grant.skill as PassiveSkillData).activation_chance}


func finish_recruitment_feedback() -> bool:
	if not _recruitment_feedback_pending:
		return false
	_recruitment_feedback_pending = false
	if enemies.is_empty():
		_check_combat_end()
		return true
	initiative_order.clear()
	_build_initiative(gerencia.campaign)
	combat_prepared.emit(current_encounter, enemies, initiative_order)
	if auto_start_turns:
		call_deferred("_start_combat_turns")
	return true


## O executor de Combate chamará isto ao vencer; não inventamos recompensas.
## Cada Resource de recompensa fornece título/ícone para a janela.
func request_victory(rewards: Array[Resource] = []) -> bool:
	if current_encounter == null or not pending_conclusion.is_empty():
		return false
	if not _loot_rolled:
		_loot_rolled = true
		if enemies.any(func(enemy: EntityState) -> bool:
			return enemy != null and enemy.current_health <= 0):
			var loot: Dictionary = LOOT_RESOLVER.roll(gerencia.campaign.district,
				_loot_damage_taken, _loot_entry_max_health, _rng)
			if not loot.get("success", false):
				_loot_rolled = false
				push_error("CombatManager: %s" % loot.get("reason", "Saque inválido."))
				return false
			_loot_items.assign(loot["items"])
	if event_executor != null:
		_pending_event_reward = event_executor.get_pending_event_combat_reward()
	if _pending_event_reward != null and _pending_event_reward not in rewards:
		rewards.append(_pending_event_reward)
	for item in _loot_items:
		rewards.append(item)
	pending_conclusion = {"title": "Vocês venceram",
		"narrative": "", "rewards": rewards.duplicate(),
		"result": {"reason": "victory"}}
	call_deferred("_show_pending_conclusion")
	return true


func request_defeat() -> bool:
	if current_encounter == null or not pending_conclusion.is_empty():
		return false
	pending_conclusion = {"title": "Vocês foram derrotados",
		"narrative": "A campanha terminou.", "rewards": [],
		"result": {"reason": "defeat"}}
	call_deferred("_show_pending_conclusion")
	return true


func request_solo_defeat() -> bool:
	if _solo_actor == null or current_encounter == null \
			or not pending_conclusion.is_empty():
		return false
	pending_conclusion = {"title": "O Vórtice venceu",
		"narrative": "O personagem não voltou. O restante do grupo prossegue.",
		"rewards": [], "result": {"reason": "solo_defeat"}}
	call_deferred("_show_pending_conclusion")
	return true


func _show_pending_conclusion() -> void:
	# Deixar as silhuetas visíveis por um instante ANTES de cobrir o mapa.
	await get_tree().create_timer(0.35).timeout
	if not pending_conclusion.is_empty() and current_encounter != null:
		var rewards: Array[Resource] = []
		rewards.assign(pending_conclusion.get("rewards", []))
		conclusion_requested.emit(str(pending_conclusion["title"]),
			str(pending_conclusion["narrative"]), rewards)


func confirm_conclusion() -> bool:
	if pending_conclusion.is_empty() or block_manager == null:
		return false
	var result: Dictionary = pending_conclusion.get("result", {})
	if result.get("reason") == "victory" and not get_pending_loot_item().is_empty():
		return false
	if result.get("reason") == "defeat":
		# A janela de ressurreição já foi resolvida. Confirmar as mortes reais
		# antes de sair da cena registra derrota uma vez; ausentes não contam.
		if gerencia != null and gerencia.campaign != null:
			gerencia.campaign.finalize_dead_playables(skill_manager, _rng)
			if gerencia.campaign.is_terminal():
				gerencia.save_repository.record_terminal_line(gerencia.campaign)
			# Confirmar a derrota é uma saída normal, não uma interrupção
			# recuperável. Os slots manuais anteriores permanecem intactos.
			gerencia.save_repository.mark_session_closed(gerencia.campaign.campaign_id)
		_clear_session()
		get_tree().change_scene_to_file("res://scenes/ui/playable_selection.tscn")
		return true
	if result.get("reason") == "victory" and _pending_event_reward != null \
			and not _event_reward_claimed:
		var inventory := InventoryManager.new()
		if not inventory.add_item(_solo_actor, _pending_event_reward):
			return false
		_event_reward_claimed = true
	_restore_exploration_turns()
	if not block_manager.finish_combat(result):
		return false
	# Companheiros sobreviventes (Vida >= 1) se recuperam. Vida 0 é morte:
	# preservá-la para uma ressurreição posterior, inclusive na Exploração.
	# Os três jogáveis conservam sua Vida de fim de Encontro.
	if gerencia != null and gerencia.campaign != null:
		for companion in gerencia.campaign.companion_states:
			if companion != null and companion.current_health > 0:
				companion.current_health = companion.max_health
		gerencia.campaign.finalize_dead_playables(skill_manager, _rng)
	_clear_session()
	combat_finished.emit(result)
	return true


func get_pending_reward_exchange() -> Dictionary:
	if _pending_event_reward == null or _event_reward_claimed \
			or _solo_actor == null or pending_conclusion.is_empty():
		return {}
	return {"actor": _solo_actor, "item": _pending_event_reward}


func exchange_pending_reward(outgoing: Array[InventoryItemState]) -> bool:
	if get_pending_reward_exchange().is_empty():
		return false
	if not InventoryManager.new().exchange_items(_solo_actor, outgoing,
			_pending_event_reward):
		return false
	_event_reward_claimed = true
	return true


func get_pending_loot_item() -> Dictionary:
	if pending_conclusion.get("result", {}).get("reason") != "victory" \
			or _loot_resolved_count >= _loot_items.size():
		return {}
	return {"item": _loot_items[_loot_resolved_count],
		"index": _loot_resolved_count + 1, "count": _loot_items.size()}


func claim_pending_loot(recipient: EntityState) -> bool:
	var pending := get_pending_loot_item()
	if pending.is_empty() or gerencia == null or gerencia.campaign == null \
			or recipient not in gerencia.campaign.active_entity_states:
		return false
	var item := pending["item"] as ItemData
	if not skill_manager.inventory_manager.add_item(recipient, item):
		return false
	_loot_resolved_count += 1
	_loot_resolutions.append({"kind": &"claimed", "recipient": recipient.visible_name()})
	loot_item_delivered.emit(recipient, item)
	return true


func exchange_pending_loot(recipient: EntityState,
		outgoing: Array[InventoryItemState]) -> bool:
	var pending := get_pending_loot_item()
	if pending.is_empty() or gerencia == null or gerencia.campaign == null \
			or recipient not in gerencia.campaign.active_entity_states:
		return false
	var item := pending["item"] as ItemData
	if not skill_manager.inventory_manager.exchange_items(recipient, outgoing, item):
		return false
	_loot_resolved_count += 1
	_loot_resolutions.append({"kind": &"claimed", "recipient": recipient.visible_name()})
	loot_item_delivered.emit(recipient, item)
	return true


func decline_pending_loot() -> bool:
	if get_pending_loot_item().is_empty():
		return false
	_loot_resolved_count += 1
	_loot_resolutions.append({"kind": &"declined"})
	return true


func _capture_loot_participants() -> void:
	_loot_participant_ids.clear()
	_loot_entry_max_health = 0
	_loot_damage_taken = 0
	for member in _combat_playables() + _combat_companions():
		if member == null or member.current_health <= 0 \
				or member.temporarily_absent_from_map:
			continue
		_loot_participant_ids[member.instance_id] = true
		_loot_entry_max_health += member.max_health


func _on_incoming_damage_applied(target: EntityState, damage: int) -> void:
	if current_encounter != null and pending_conclusion.is_empty() \
			and target != null and _loot_participant_ids.has(target.instance_id):
		_loot_damage_taken += maxi(0, damage)


## Ponto de entrada das Skills SUMMON_ENTITY quando seu executor de Combate
## estiver ligado. O agendamento de turno (imediato ou não) fica com ele.
func spawn_summoned_enemy(enemy_data: EntityData, summoner: EntityState,
		effect: SkillEffectData = null) -> EntityState:
	if enemy_data == null or summoner == null or gerencia == null \
			or gerencia.campaign.current_map == null \
			or gerencia.campaign.current_map.ppp_map_mode != HexGrid.PPPMapMode.COMBAT:
		return null
	var coord := choose_summon_spawn(enemy_data)
	if coord == EntityState.UNPLACED:
		return null
	var encounter_id := current_encounter.id if current_encounter != null else &"event_combat"
	var enemy := EntityState.from_encounter_member(enemy_data, encounter_id,
		enemies.size() + 1, coord)
	_apply_easy_enemy_attack_adjustment(enemy)
	enemy.summoned_by_instance_id = summoner.instance_id
	enemy.summoned_can_summon = false
	if effect != null:
		enemy.summoned_can_summon = effect.summoned_can_summon
		enemy.summoned_acts_immediately = effect.summoned_acts_immediately
	enemies.append(enemy)
	_draw_enemy(enemy)
	var initiative_entry := _roll_initiative_entry(enemy)
	if enemy.summoned_acts_immediately and _turn_index >= 0:
		initiative_order.insert(_turn_index + 1, initiative_entry)
	else:
		initiative_order.append(initiative_entry)
	_sync_combat_view()
	enemy_summoned.emit(enemy, summoner, enemy.summoned_acts_immediately)
	return enemy


func _apply_easy_enemy_attack_adjustment(enemy: EntityState) -> void:
	if enemy != null and gerencia != null and gerencia.campaign != null \
			and gerencia.campaign.difficulty == GameDifficulty.Mode.SUGAR \
			and enemy.controller == EntityState.Controller.AI \
			and not enemy.sugar_attack_adjusted:
		# Após os atributos de abertura (ex.: Homens de Preto), uma vez por
		# instância. Não alterar EntityData nem reaplicar ao carregar um save.
		if enemy.attack > 3:
			enemy.attack -= 1
			enemy.sugar_enemy_attack_penalty = 1
		enemy.sugar_attack_adjusted = true


func count_living_summons(summoner: EntityState, entity_id: StringName) -> int:
	var count := 0
	for enemy in enemies:
		if enemy.current_health > 0 and enemy.data != null \
				and enemy.data.id == entity_id \
				and enemy.summoned_by_instance_id == summoner.instance_id:
			count += 1
	return count


func apply_timed_attack_penalty(target: EntityState, basis: int,
		duration_turns: int) -> Dictionary:
	if target == null or basis <= 0 or duration_turns <= 0:
		return {"success": false}
	var reduction := mini(maxi(0, target.attack - 1), basis)
	target.attack -= reduction
	_timed_attack_penalties.append({"target": target, "amount": reduction,
		"turns_remaining": duration_turns})
	return {"success": true, "reduction": reduction,
		"turns_remaining": duration_turns}


func set_damage_guard(guard: EntityState, protected: EntityState,
		duration_unit: int = SkillEffectData.DurationUnit.COMBAT) -> Dictionary:
	if guard == null or protected == null or guard == protected:
		return {"success": false}
	_damage_guards[protected.instance_id] = guard
	if duration_unit == SkillEffectData.DurationUnit.UNTIL_NEXT_OWNER_TURN_START:
		_guard_expiry_turn_by_id[guard.instance_id] = guard.turn_serial + 1
	return {"success": true, "guard": guard, "protected": protected}


func add_guard_reduction(actor: EntityState, percent: float,
		duration_unit: int = SkillEffectData.DurationUnit.COMBAT) -> Dictionary:
	if actor == null or percent <= 0.0 or percent >= 1.0:
		return {"success": false}
	_guard_reductions[actor.instance_id] = float(_guard_reductions.get(
		actor.instance_id, 1.0)) * (1.0 - percent)
	if duration_unit == SkillEffectData.DurationUnit.UNTIL_NEXT_OWNER_TURN_START:
		_guard_expiry_turn_by_id[actor.instance_id] = actor.turn_serial + 1
	return {"success": true, "remaining_fraction": _guard_reductions[actor.instance_id]}


func _expire_damage_guards_for(actor: EntityState) -> void:
	if actor == null or actor.turn_serial < int(_guard_expiry_turn_by_id.get(
			actor.instance_id, 2147483647)):
		return
	for protected_id in _damage_guards.keys():
		if _damage_guards[protected_id] == actor:
			_damage_guards.erase(protected_id)
	_guard_reductions.erase(actor.instance_id)
	_guard_expiry_turn_by_id.erase(actor.instance_id)


func perform_skill_attack(actor: EntityState, target: EntityState,
		skill: ActiveSkillData) -> Dictionary:
	if actor == null or target == null or skill == null or actor != current_actor:
		return {"success": false}
	var ranged := skill.mastery_override == EntityData.Mastery.RANGED
	var attack_range := actor.attack + _turn_die if ranged else 1
	var opponents := _opponents_of(actor)
	var paths := {actor.position: []}
	if not _is_immobile_enemy(actor.data):
		paths = _ai.reachable_paths(gerencia.campaign.current_map, actor.position,
			actor.stamina_remaining, _occupied_positions(actor))
	var destination: Vector2i = _ai.choose_ranged_position(actor, target,
		opponents, paths, attack_range, _rng) if ranged else \
		_ai.choose_melee_position(actor, target, paths, _rng)
	if destination != actor.position and paths.has(destination):
		var path: Array[Vector2i] = []
		path.assign(paths[destination])
		if skill_manager == null or skill_manager.debuff_manager.can_follow_path(actor, path):
			_apply_move(actor, path)
	var distance := HexGrid.distance(actor.position, target.position)
	if distance <= 0 or distance > attack_range:
		return {"success": true, "missed_reach": true, "target": target}
	return _resolve_attack(actor, target, 1 if ranged else 0)


func convert_enemy_to_companion(owner: EntityState, target: EntityState,
		_effect: SkillEffectData, check_combat_end: bool = true) -> Dictionary:
	if gerencia == null or target not in enemies:
		return {"success": false}
	var playable_owner := owner
	if owner in gerencia.campaign.companion_states:
		playable_owner = gerencia.campaign.get_playable_slot(owner.owner_instance_id)
	if playable_owner == null or not gerencia.campaign.register_companion(
			playable_owner, target, _rng):
		return {"success": false}
	enemies.erase(target)
	var silhouette := _visual_for_actor(target)
	if silhouette != null:
		silhouette.name = "Ally_%s" % target.instance_id
		silhouette.call("bind_state", target, true)
		if silhouette.body_clicked.is_connected(_on_enemy_body_clicked):
			silhouette.body_clicked.disconnect(_on_enemy_body_clicked)
	if check_combat_end:
		_check_combat_end()
	return {"success": true, "companion": target}


func can_consume_skill_source_item(actor: EntityState, grant: SkillGrantState) -> bool:
	return skill_manager != null \
		and skill_manager.equipped_source_item(actor, grant) != null


func consume_skill_source_item(actor: EntityState, grant: SkillGrantState) -> bool:
	return skill_manager != null and gerencia != null \
		and skill_manager.consume_equipment_source_item(actor, grant,
			gerencia.campaign)


## Hostis com PREVENT_MOVEMENT são exceção: sorteio em qualquer hex livre.
## Os demais usam SOMENTE as duas colunas externas de um dos lados do mapa.
## Votação: qual lado está mais longe da maioria dos jogáveis vivos? Empate:
## maior soma de distâncias. Se um lado estiver cheio, usa o outro.
func choose_summon_spawn(enemy_data: EntityData = null) -> Vector2i:
	if gerencia == null or gerencia.campaign.current_map == null:
		return EntityState.UNPLACED
	var grid := gerencia.campaign.current_map
	var occupied: Dictionary = {}
	var playables: Array[EntityState] = []
	for playable in _combat_playables():
		if playable != null and playable.current_health > 0 \
				and playable.position != EntityState.UNPLACED:
			playables.append(playable)
			occupied[playable.position] = true
	for companion in _combat_companions():
		if companion != null and companion.current_health > 0 \
				and companion.position != EntityState.UNPLACED:
			occupied[companion.position] = true
	for enemy in enemies:
		if enemy != null and enemy.current_health > 0 \
				and enemy.position != EntityState.UNPLACED:
			occupied[enemy.position] = true
	if _is_immobile_enemy(enemy_data):
		return _choose_immobile_spawn(grid, occupied)
	var left: Array[Vector2i] = []
	var right: Array[Vector2i] = []
	for coord in grid.cells:
		if occupied.has(coord):
			continue
		if coord.x < 2:
			left.append(coord)
		elif coord.x >= HexGrid.PPP_MAP_WIDTH - 2:
			right.append(coord)
	if left.is_empty() and right.is_empty():
		return EntityState.UNPLACED
	if left.is_empty():
		return _choose_edge_cell(right, playables)
	if right.is_empty():
		return _choose_edge_cell(left, playables)
	var left_votes := 0
	var right_votes := 0
	var left_total := 0
	var right_total := 0
	for playable in playables:
		var left_distance := _nearest_distance_to_side(playable.position, left)
		var right_distance := _nearest_distance_to_side(playable.position, right)
		left_total += left_distance
		right_total += right_distance
		if left_distance > right_distance:
			left_votes += 1
		elif right_distance > left_distance:
			right_votes += 1
	var choose_left := left_votes > right_votes
	if left_votes == right_votes:
		choose_left = left_total > right_total
		if left_total == right_total:
			choose_left = _rng.randi_range(0, 1) == 0
	return _choose_edge_cell(left if choose_left else right, playables)


func _nearest_distance_to_side(origin: Vector2i, cells: Array[Vector2i]) -> int:
	var nearest := 999
	for coord in cells:
		nearest = mini(nearest, HexGrid.distance(origin, coord))
	return nearest


func _choose_edge_cell(cells: Array[Vector2i], playables: Array[EntityState]) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var best_safety := -1
	var best_total := -1
	for coord in cells:
		var nearest := 999
		var total := 0
		for playable in playables:
			var distance := HexGrid.distance(playable.position, coord)
			nearest = mini(nearest, distance)
			total += distance
		if nearest > best_safety or (nearest == best_safety and total > best_total):
			best_safety = nearest
			best_total = total
			candidates.clear()
		if nearest == best_safety and total == best_total:
			candidates.append(coord)
	return candidates[_rng.randi_range(0, candidates.size() - 1)] \
		if not candidates.is_empty() else EntityState.UNPLACED


func _snapshot_exploration_turns(campaign: CampaignState) -> void:
	_exploration_snapshot.clear()
	for actor in campaign.active_entity_states + campaign.companion_states:
		if actor != null:
			_exploration_snapshot[actor.instance_id] = {
				"actor": actor, "turn_state": actor.turn_state,
				"stamina": actor.stamina_remaining, "position": actor.position,
				"absent": actor.temporarily_absent_from_map,
			}


func _restore_exploration_turns() -> void:
	for entry in _exploration_snapshot.values():
		var actor := entry["actor"] as EntityState
		if actor == null:
			continue
		actor.turn_state = entry["turn_state"]
		actor.stamina_remaining = entry["stamina"]
		actor.temporarily_absent_from_map = entry["absent"]
		# Os jogáveis permanecem onde terminaram o Combate. Companheiros que
		# passeavam sem hex lógico voltam a esse estado na Exploração.
		if actor.owner_instance_id != &"":
			actor.position = entry["position"]
	if gerencia != null and gerencia.campaign != null:
		gerencia.campaign.temporary_event_changed.emit()
	if _solo_actor != null:
		_solo_restored = true
	if map_view != null and _combat_interaction_enabled:
		map_view.selection_validator = _saved_selection_validator
		map_view.destination_validator = _saved_destination_validator
		_combat_interaction_enabled = false


func _place_companions_for_combat(campaign: CampaignState) -> void:
	var grid := campaign.current_map
	if grid == null:
		return
	var occupied: Dictionary = {}
	for playable in campaign.active_entity_states:
		if playable != null and playable.position != EntityState.UNPLACED:
			occupied[playable.position] = true
	for companion in campaign.companion_states:
		if companion == null or companion.current_health <= 0:
			continue
		var owner := campaign.get_playable_slot(companion.owner_instance_id)
		if owner == null:
			companion.position = EntityState.UNPLACED
			continue
		if owner.turn_serial < companion.unavailable_until_owner_turn_serial:
			companion.position = EntityState.UNPLACED
			continue
		# Um ou dois passos do dono, incluindo a segunda coroa quando os vizinhos
		# imediatos estão ocupados. A vaga já fica reservada antes dos hostis.
		var nearest := 999
		var candidates: Array[Vector2i] = []
		for coord in grid.cells:
			if occupied.has(coord) or not grid.can_traverse_ppp(coord):
				continue
			var distance := HexGrid.distance(owner.position, coord)
			if distance < 1 or distance > 2:
				continue
			if distance < nearest:
				nearest = distance
				candidates.clear()
			if distance == nearest:
				candidates.append(coord)
		if candidates.is_empty():
			companion.position = EntityState.UNPLACED
			push_warning("CombatManager: sem hex a até dois passos do dono para %s." % companion.visible_name())
			continue
		companion.position = candidates[_rng.randi_range(0, candidates.size() - 1)]
		occupied[companion.position] = true


func _place_returning_companions_for_owner(owner: EntityState) -> void:
	if owner == null or gerencia == null or gerencia.campaign.current_map == null:
		return
	var grid := gerencia.campaign.current_map
	for companion in _combat_companions():
		if companion == null or companion.current_health <= 0 \
				or companion.owner_instance_id != owner.instance_id \
				or companion.position != EntityState.UNPLACED \
				or companion.unavailable_until_owner_turn_serial <= 0 \
				or owner.turn_serial < companion.unavailable_until_owner_turn_serial:
			continue
		var occupied := _occupied_positions(companion)
		var nearest := 999
		var candidates: Array[Vector2i] = []
		for coord in grid.cells:
			if occupied.has(coord):
				continue
			var distance := HexGrid.distance(owner.position, coord)
			if distance < nearest:
				nearest = distance
				candidates.clear()
			if distance == nearest:
				candidates.append(coord)
		if not candidates.is_empty():
			companion.position = candidates[_rng.randi_range(0, candidates.size() - 1)]


func _combat_playables() -> Array[EntityState]:
	var roster: Array[EntityState] = []
	if _solo_actor != null:
		roster.append(_solo_actor)
	elif gerencia != null and gerencia.campaign != null:
		roster.append_array(gerencia.campaign.active_entity_states)
	return roster


func _combat_companions() -> Array[EntityState]:
	var roster: Array[EntityState] = []
	if _solo_actor == null and gerencia != null and gerencia.campaign != null:
		roster.append_array(gerencia.campaign.companion_states)
	return roster


func _start_combat_turns() -> void:
	if current_encounter == null or not pending_conclusion.is_empty() \
			or not _pending_recruitment.is_empty() or _recruitment_feedback_pending \
			or gerencia == null or gerencia.campaign.current_map == null:
		return
	_turn_index = -1
	combat_cycle = 1
	if map_view != null:
		_saved_selection_validator = map_view.selection_validator
		_saved_destination_validator = map_view.destination_validator
		map_view.selection_validator = Callable(self, "_can_select_hex")
		map_view.destination_validator = Callable(self, "can_preview_move")
		_combat_interaction_enabled = true
	for entry in initiative_order:
		var actor := entry["entity"] as EntityState
		if actor != null and actor.current_health > 0:
			actor.turn_state = EntityState.TurnState.AVAILABLE
	_advance_turn()


func _advance_turn() -> void:
	if _promotion_cleanup_pending or not pending_conclusion.is_empty() or initiative_order.is_empty() \
			or gerencia == null:
		return
	if _check_combat_end():
		return
	for attempt in initiative_order.size():
		_turn_index += 1
		if _turn_index >= initiative_order.size():
			_turn_index = 0
			combat_cycle += 1
			for entry in initiative_order:
				var participant := entry["entity"] as EntityState
				if participant != null and participant.current_health > 0:
					participant.turn_state = EntityState.TurnState.AVAILABLE
		var candidate := initiative_order[_turn_index]["entity"] as EntityState
		if candidate == null or candidate.current_health <= 0:
			continue
		# Vai Pegar! deixa o companheiro fora de cena até o turno agendado do
		# dono. Ele permanece na fila para poder voltar neste mesmo combate,
		# mas jamais recebe um turno impossível de comandar enquanto ausente.
		if gerencia.campaign.companion_states.has(candidate):
			var owner := gerencia.campaign.get_playable_slot(candidate.owner_instance_id)
			if owner != null and owner.turn_serial < candidate.unavailable_until_owner_turn_serial:
				candidate.turn_state = EntityState.TurnState.INACTIVE
				continue
		if candidate.position == EntityState.UNPLACED:
			continue
		current_actor = candidate
		candidate.turn_state = EntityState.TurnState.TURNING
		candidate.turn_serial += 1
		if candidate in gerencia.campaign.active_entity_states:
			_place_returning_companions_for_owner(candidate)
		gerencia.campaign.on_temporary_event_turn_started(candidate)
		_expire_damage_guards_for(candidate)
		_combat_turns_by_id[candidate.instance_id] = int(_combat_turns_by_id.get(
			candidate.instance_id, 0)) + 1
		# Hostis rolam automaticamente para a IA. Jogáveis e aliados aguardam
		# o clique explícito em Jogar dado antes de mover ou atacar.
		_turn_die = gerencia.campaign.enemy_dice_luck.roll_for_enemy(_rng) \
			if candidate.controller == EntityState.Controller.AI else 0
		_steps_moved = 0
		_attacks_used = 0
		candidate.extra_attacks_this_turn = candidate.extra_attacks_next_turn
		candidate.extra_attacks_next_turn = 0
		_turn_moved = false
		action_mode = &""
		var allies := _allies_of(candidate)
		if skill_manager != null:
			skill_manager.on_entity_turn_started(candidate, gerencia.campaign, _rng, allies)
			if candidate in gerencia.campaign.active_entity_states and candidate.current_health > 0:
				skill_manager.resolve_delayed_effects_for_owner(candidate, gerencia.campaign)
			_dispatch_combat_passive(candidate, PassiveSkillData.Trigger.ON_TURN_START, {})
		# Para hostis comuns, a mesma rolagem determina a movimentação deste
		# turno. As fichas que fixam/copiam Stamina e os imóveis são exceções.
		if candidate in enemies:
			if _is_immobile_enemy(candidate.data):
				candidate.max_stamina = 0
			elif not _has_encounter_stamina_rule(candidate.data):
				candidate.max_stamina = maxi(0, candidate.attack + _turn_die)
		candidate.stamina_remaining = candidate.max_stamina
		_sync_combat_view()
		turn_started.emit(candidate, combat_cycle)
		if candidate.current_health <= 0 or (skill_manager != null \
				and not skill_manager.debuff_manager.can_take_action(candidate)):
			call_deferred("end_current_turn")
		elif _charm_due_this_turn(candidate):
			call_deferred("_run_charmed_turn", candidate)
		elif candidate.controller == EntityState.Controller.AI:
			call_deferred("_run_automatic_turn", candidate)
		return
	_check_combat_end()


func end_current_turn(completed_forced_charm: bool = false) -> bool:
	if _attack_animation_pending or _promotion_cleanup_pending:
		return false
	if current_actor == null or not pending_conclusion.is_empty() \
			or not _pending_trap.is_empty():
		return false
	if _charm_due_this_turn(current_actor) and not completed_forced_charm \
			and skill_manager.debuff_manager.can_take_action(current_actor):
		return false
	var finished := current_actor
	if skill_manager != null:
		_dispatch_combat_passive(finished, PassiveSkillData.Trigger.ON_TURN_END, {})
		skill_manager.on_entity_turn_finished(finished, gerencia.campaign, _rng)
	gerencia.campaign.on_temporary_event_turn_finished(finished)
	_expire_mother_bonus(finished)
	for index in range(_timed_attack_penalties.size() - 1, -1, -1):
		var penalty := _timed_attack_penalties[index]
		if penalty["target"] != finished:
			continue
		penalty["turns_remaining"] = int(penalty["turns_remaining"]) - 1
		if int(penalty["turns_remaining"]) <= 0:
			finished.attack += int(penalty["amount"])
			_timed_attack_penalties.remove_at(index)
	finished.turn_state = EntityState.TurnState.INACTIVE
	current_actor = null
	action_mode = &""
	_selected_skill_grant = null
	turn_finished.emit(finished)
	call_deferred("_advance_turn")
	return true


func is_player_turn() -> bool:
	return not _promotion_cleanup_pending and current_actor != null and gerencia != null \
		and (current_actor in gerencia.campaign.active_entity_states \
		or current_actor in gerencia.campaign.companion_states) \
		and current_actor.controller == EntityState.Controller.PLAYER \
		and pending_conclusion.is_empty()


func has_rolled_turn_die() -> bool:
	return _turn_die > 0


func can_roll_player_turn_die() -> bool:
	return is_player_turn() and _turn_die == 0 and not _attack_animation_pending \
		and _pending_trap.is_empty() \
		and not _charm_due_this_turn(current_actor) \
		and _attacks_used < 1 + current_actor.extra_attacks_this_turn


func select_player_skill(grant: SkillGrantState) -> bool:
	if not is_player_turn() or grant == null or skill_manager == null \
			or _charm_due_this_turn(current_actor):
		return false
	var skill := grant.skill as ActiveSkillData
	if skill == null or skill.use_context == ActiveSkillData.UseContext.EXPLORATION \
			or not skill.automatic_triggers.is_empty():
		return false
	_selected_skill_grant = grant
	action_mode = &"skill"
	_sync_combat_view()
	return true


func can_player_use_skill_at(coord: Vector2i) -> bool:
	if not is_player_turn() or _selected_skill_grant == null or skill_manager == null:
		return false
	for target in _allies_of(current_actor) + _opponents_of(current_actor):
		if target.position == coord and skill_manager.can_use_combat_active(
				current_actor, _selected_skill_grant, gerencia.campaign, self, target):
			return true
	return false


func use_player_skill_at(coord: Vector2i) -> Dictionary:
	if not can_player_use_skill_at(coord):
		return {"success": false}
	for target in _allies_of(current_actor) + _opponents_of(current_actor):
		if target.position != coord:
			continue
		var result := skill_manager.use_combat_active(current_actor,
			_selected_skill_grant, gerencia.campaign, self, target)
		if result.get("success", false):
			action_resolved.emit(current_actor, &"skill", result)
			var ends_turn := (_selected_skill_grant.skill as ActiveSkillData).ends_turn
			_selected_skill_grant = null
			action_mode = &""
			_sync_combat_view()
			if ends_turn:
				end_current_turn()
		return result
	return {"success": false}


func roll_player_turn_die() -> int:
	if not can_roll_player_turn_die():
		return 0
	# Cada ataque extra inaugura outro ciclo de ação dentro do mesmo turno.
	# A nova rolagem restaura a Estamina e zera somente o percurso deste ciclo.
	current_actor.stamina_remaining = current_actor.max_stamina
	_steps_moved = 0
	_turn_moved = false
	_turn_die = gerencia.campaign.player_dice_luck.roll_for_player(_rng)
	_sync_combat_view()
	die_rolled.emit(current_actor, _turn_die)
	action_resolved.emit(current_actor, &"roll", {"die": _turn_die})
	return _turn_die


func select_player_action(mode: StringName) -> bool:
	if not is_player_turn() or _attack_animation_pending or _turn_die <= 0 or not _pending_trap.is_empty() \
			or _charm_due_this_turn(current_actor) or mode not in [&"move", &"attack"]:
		return false
	if mode == &"attack" and skill_manager != null \
			and not skill_manager.debuff_manager.can_attack(current_actor):
		return false
	action_mode = mode
	return true


func can_player_move(coord: Vector2i) -> bool:
	if not is_player_turn() or _turn_die <= 0 or not can_preview_move(coord):
		return false
	return true


## O dado altera o potencial de ataque, nunca o número de hexes caminháveis.
## Se um alvo ainda não pode ser atingido, a Estamina continua permitindo
## avançar pelo melhor caminho disponível sem gastar o ataque.
func can_player_approach(coord: Vector2i) -> bool:
	if not is_player_turn() or _turn_die <= 0 or _attack_animation_pending \
			or not _pending_trap.is_empty() or _turn_moved \
			or current_actor.stamina_remaining <= 0 or skill_manager == null \
			or not skill_manager.debuff_manager.can_take_action(current_actor):
		return false
	var target := _opponent_at(current_actor, coord)
	if target == null:
		return false
	var path_variant: Variant = _melee_approach_path(current_actor, target)
	if path_variant == null:
		return false
	var path: Array[Vector2i] = []
	path.assign(path_variant)
	return not path.is_empty() and skill_manager.debuff_manager.can_follow_path(
		current_actor, path) and can_player_move(path[-1])


func player_approach(coord: Vector2i) -> bool:
	if not can_player_approach(coord):
		return false
	var target := _opponent_at(current_actor, coord)
	var path: Array[Vector2i] = []
	path.assign(_melee_approach_path(current_actor, target))
	return player_move(path[-1])


## O alcance amarelo mostra a Estamina antes da rolagem. A rolagem continua
## obrigatória para executar o deslocamento, mas não para planejar o caminho.
func can_preview_move(coord: Vector2i) -> bool:
	if current_actor == null or current_actor.current_health <= 0 \
			or _attack_animation_pending or not _pending_trap.is_empty() \
			or _turn_moved \
			or _attacks_used >= 1 + current_actor.extra_attacks_this_turn \
			or not gerencia.campaign.current_map.is_valid(coord) \
			or _occupied_positions(current_actor).has(coord) \
			or skill_manager == null \
			or not skill_manager.debuff_manager.can_take_action(current_actor):
		return false
	var paths: Dictionary = _ai.reachable_paths(gerencia.campaign.current_map,
		current_actor.position, current_actor.stamina_remaining,
		_occupied_positions(current_actor))
	if not paths.has(coord) or (paths[coord] as Array).is_empty():
		return false
	var typed_path: Array[Vector2i] = []
	typed_path.assign(paths[coord])
	return skill_manager.debuff_manager.can_follow_path(current_actor, typed_path)


func player_move(coord: Vector2i) -> bool:
	if not can_player_move(coord):
		return false
	var paths: Dictionary = _ai.reachable_paths(gerencia.campaign.current_map,
		current_actor.position, current_actor.stamina_remaining,
		_occupied_positions(current_actor))
	var path: Array[Vector2i] = []
	path.assign(paths[coord])
	_apply_move(current_actor, path)
	_attack_animation_pending = true
	_finish_player_move(current_actor, _visual_move_wait(current_actor, path.size()))
	action_mode = &""
	return true


func _finish_player_move(actor: EntityState, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if current_actor != actor:
		return
	_attack_animation_pending = false
	action_resolved.emit(actor, &"move_finished", {})


func _visual_move_wait(actor: EntityState, steps: int) -> float:
	var seconds_per_hex := PlayableActorVisual.MAX_HEX_MOVE_SECONDS \
		if actor != null and actor.playable_slot_id != &"" else 0.24
	return float(steps) * seconds_per_hex + 0.03


func can_player_attack(coord: Vector2i) -> bool:
	if not is_player_turn() or _attack_animation_pending or _turn_die <= 0 or not _pending_trap.is_empty() \
			or _attacks_used >= 1 + current_actor.extra_attacks_this_turn \
			or skill_manager == null \
			or not skill_manager.debuff_manager.can_attack(current_actor):
		return false
	var target := _opponent_at(current_actor, coord)
	if target == null:
		return false
	var distance := HexGrid.distance(current_actor.position, coord)
	if distance <= 0:
		return false
	if _uses_ranged_attack(current_actor):
		var unlimited_range := skill_manager.ignores_attack_range(
			current_actor, _attack_mastery(current_actor))
		return unlimited_range or (distance <= current_actor.attack + _turn_die \
			and current_actor.attack + _turn_die - _steps_moved - maxi(0, distance - 1) > 0)
	if distance == 1:
		return true
	return can_player_approach(coord)


func player_attack(coord: Vector2i) -> bool:
	if not can_player_attack(coord):
		return false
	var attacker := current_actor
	var target := _opponent_at(attacker, coord)
	if not _uses_ranged_attack(attacker) and HexGrid.distance(attacker.position, coord) > 1:
		var approach: Variant = _melee_approach_path(attacker, target)
		if approach == null:
			return false
		var path: Array[Vector2i] = []
		path.assign(approach)
		if not path.is_empty():
			_apply_move(attacker, path)
		if not _pending_trap.is_empty():
			_pending_attack_coord = coord
			return true
		_attack_animation_pending = true
		# O desvio visual entre entidades pode durar 0,30 s por hex.
		# A resolução do golpe espera o sprite parar adjacente ao alvo.
		_finish_player_melee_attack(attacker, target,
			_visual_move_wait(attacker, path.size()))
		return true
	_resolve_attack(attacker, target)
	action_mode = &""
	return true


func _finish_player_melee_attack(attacker: EntityState, target: EntityState,
		duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	_attack_animation_pending = false
	if current_actor != attacker or target.current_health <= 0 \
			or not pending_conclusion.is_empty():
		return
	if HexGrid.distance(attacker.position, target.position) == 1:
		_resolve_attack(attacker, target)
	else:
		_attacks_used += 1
		_turn_die = 0
		action_resolved.emit(attacker, &"attack_missed_reach", {"target": target})
	action_mode = &""


func _melee_approach_path(attacker: EntityState, target: EntityState) -> Variant:
	if attacker == null or target == null or gerencia == null:
		return null
	var paths := _ai.reachable_paths(gerencia.campaign.current_map,
		attacker.position, attacker.stamina_remaining, _occupied_positions(attacker))
	var best_distance := HexGrid.distance(attacker.position, target.position)
	var best_path: Variant = null
	for coord in paths:
		var distance := HexGrid.distance(coord, target.position)
		var candidate: Array = paths[coord]
		if candidate.is_empty():
			continue
		if distance < best_distance or (distance == best_distance and best_path != null \
				and candidate.size() < (best_path as Array).size()):
			best_distance = distance
			best_path = candidate
	return best_path


func _can_select_hex(coord: Vector2i) -> bool:
	if not is_player_turn() or _attack_animation_pending or not _pending_trap.is_empty():
		return false
	# O alvo pode ser examinado antes da rolagem, para abrir o dado e as
	# Ativas direcionadas. O ataque em si continua exigindo o dado.
	if _opponent_at(current_actor, coord) != null:
		return true
	# A caixa de escolha de Ativas em aliados abre mesmo sem dado e mesmo
	# quando a habilidade já foi gasta (nesse caso, seu botão fica cinza).
	for ally in _allies_of(current_actor):
		if ally != null and ally != current_actor and ally.current_health > 0 \
				and ally.position == coord:
			return true
	match action_mode:
		&"move": return can_player_move(coord)
		# Estar no modo Atacar não desativa os hexes amarelos: o jogador
		# ainda pode escolher reposicionamento, mesmo com dado baixo.
		&"attack": return can_player_attack(coord) or can_player_move(coord)
		&"skill": return can_player_use_skill_at(coord)
	return can_player_move(coord) or can_player_attack(coord)


## Estimativa ANTES de Proteção, esquiva e outras reações do alvo. O mesmo
## cálculo bruto é usado em _resolve_attack; isto não rola outro dado.
func get_player_attack_preview(coord: Vector2i) -> Dictionary:
	if not is_player_turn():
		return {}
	var target := _opponent_at(current_actor, coord)
	if target == null:
		return {}
	if _turn_die <= 0:
		return {"text": "Jogue o dado para ver a previsão do ataque."}
	var ranged := _uses_ranged_attack(current_actor)
	var unarmed := current_actor.primary_equipped(ItemData.EquipmentSlot.WEAPON) == null \
		and not _has_absorbed_weapon(current_actor)
	var base := _attack_base_for_roll(current_actor, unarmed)
	var distance := HexGrid.distance(current_actor.position, coord)
	var movement := _steps_moved
	var mastery := _attack_mastery(current_actor)
	var critical_hit := _is_critical_roll(current_actor)
	var unlimited_range := ranged and skill_manager.ignores_attack_range(
		current_actor, mastery)
	var passive_bonus := 0
	var passive_multiplier := 1.0
	for grant in skill_manager.get_passive_grants(current_actor):
		if grant.skill is PassiveSkillData \
				and (grant.skill as PassiveSkillData).id == &"permanent_passive_057":
			if unarmed:
				passive_multiplier = 3.0
			elif not ranged:
				passive_bonus = ceili(float(current_actor.attack) * 0.5)
	var ranged_critical_bonus := ranged and critical_hit \
		and mastery == EntityData.Mastery.RANGED \
		and not target.ignore_ranged_critical_bonus
	var distance_penalty := maxi(0, distance - 1) if ranged \
		and not ranged_critical_bonus else 0
	if _has_absorbed_ranged_weapon(current_actor):
		distance_penalty = 0
	var critical := 2 if unarmed and _turn_die == 6 else 0
	var status := ""
	if ranged and distance > current_actor.attack + _turn_die \
			and not unlimited_range:
		status = "Fora do alcance atual. Aproximar ainda é possível pela Estamina."
	elif not ranged and distance > 1:
		var path_variant: Variant = _melee_approach_path(current_actor, target) \
			if not _turn_moved else null
		if path_variant == null:
			status = "Sem caminho de aproximação neste turno."
		else:
			var path: Array[Vector2i] = []
			path.assign(path_variant)
			movement += path.size()
			if HexGrid.distance(path[-1], coord) > 1:
				status = "A Estamina não chega à adjacência: anda, mas não causa dano."
	var potential := floori(float(base + passive_bonus + _turn_die + critical \
		- movement - distance_penalty) * passive_multiplier)
	potential = maxi(1 if unlimited_range else 0, potential)
	var damage := 0 if not status.is_empty() else potential
	var formula := "ATK %d + dado %d" % [base, _turn_die]
	if passive_bonus > 0:
		formula += " + Gene %d" % passive_bonus
	if critical > 0:
		formula += " + crítico %d" % critical
	formula += " − movimento %d − distância %d" % [movement, distance_penalty]
	if passive_multiplier > 1.0:
		formula += " × %s" % str(passive_multiplier)
	if ranged_critical_bonus:
		formula += " (crítico de Distância: sem penalidade de distância)"
	elif ranged and critical_hit and mastery == EntityData.Mastery.RANGED \
			and target.ignore_ranged_critical_bonus:
		formula += " (Pele Endurecida: distância mantida)"
	formula += " = %d" % potential
	if unlimited_range and potential == 1:
		formula += " (alcance livre; dano mínimo)"
	return {"base_attack": base, "die": _turn_die, "movement": movement,
		"distance": distance_penalty, "critical": critical,
		"damage": damage, "status": status,
		"text": "%s%s" % [formula,
			" potencial; 0 aplicável.\n%s" % status if not status.is_empty() \
			else " dano bruto previsto."]}


func _run_automatic_turn(expected: EntityState) -> void:
	await get_tree().create_timer(0.35).timeout
	if current_actor != expected or not pending_conclusion.is_empty():
		return
	var triggered := _run_automatic_actives(expected,
		ActiveSkillData.AutomaticTrigger.ON_TURN_START)
	triggered = _run_automatic_actives(expected,
		ActiveSkillData.AutomaticTrigger.ON_COMBAT_TURN_START) or triggered
	if current_actor != expected or not pending_conclusion.is_empty():
		return
	if triggered:
		end_current_turn()
		return
	var opponents := _opponents_of(expected)
	var retaliation: Dictionary = _retaliation_by_enemy.get(expected.instance_id, {})
	var target: EntityState = _ai.choose_target(expected, opponents, skill_manager, retaliation, _rng)
	_retaliation_by_enemy.erase(expected.instance_id)
	if target == null:
		end_current_turn()
		return
	var ranged := _uses_ranged_attack(expected)
	var attack_range := expected.attack + _turn_die if ranged else 1
	var paths: Dictionary = {expected.position: []}
	if not _is_immobile_enemy(expected.data):
		paths = _ai.reachable_paths(gerencia.campaign.current_map, expected.position,
			expected.stamina_remaining, _occupied_positions(expected))
	var destination: Vector2i = _ai.choose_ranged_position(expected, target, opponents,
		paths, attack_range, _rng) if ranged else \
		_ai.choose_melee_position(expected, target, paths, _rng)
	if destination != expected.position and paths.has(destination):
		var path: Array[Vector2i] = []
		path.assign(paths[destination])
		if skill_manager == null or skill_manager.debuff_manager.can_follow_path(expected, path):
			_apply_move(expected, path)
			await get_tree().create_timer(_visual_move_wait(expected,
				path.size())).timeout
	if current_actor != expected or not pending_conclusion.is_empty():
		return
	var distance := HexGrid.distance(expected.position, target.position)
	if target.current_health > 0 and distance > 0 and distance <= attack_range:
		if not _run_automatic_actives(expected,
				ActiveSkillData.AutomaticTrigger.ON_ATTACK_SELECTION, target):
			_resolve_attack(expected, target)
	await get_tree().create_timer(0.25).timeout
	if current_actor == expected and pending_conclusion.is_empty():
		end_current_turn()


## Charme interrompe a decisão normal no PRÓXIMO turno, inclusive para IA e
## aliados. O controle CANT_ATTACK já vale imediatamente após a aplicação.
func _charm_due_this_turn(actor: EntityState) -> bool:
	if actor == null or skill_manager == null:
		return false
	var charm := skill_manager.debuff_manager.get_debuff(actor, &"db_00011")
	return charm != null and charm.applied_turn_serial < actor.turn_serial


func is_charm_forced_turn(actor: EntityState) -> bool:
	return actor == current_actor and _charm_due_this_turn(actor)


func _run_charmed_turn(expected: EntityState) -> void:
	await get_tree().create_timer(0.2).timeout
	if current_actor != expected or not pending_conclusion.is_empty() \
			or not _charm_due_this_turn(expected):
		return
	var charm := skill_manager.debuff_manager.get_debuff(expected, &"db_00011")
	var source := charm.source if charm != null else null
	var grid := gerencia.campaign.current_map
	var limit := mini(expected.stamina_remaining, ceili(float(expected.max_stamina) * 0.5))
	var best_path: Array[Vector2i] = []
	if source != null and source.current_health > 0 \
			and source.position != EntityState.UNPLACED and grid != null and limit > 0:
		var closest := HexGrid.distance(expected.position, source.position)
		var paths: Dictionary = _ai.reachable_paths(grid, expected.position,
			limit, _occupied_positions(expected))
		for destination in paths:
			var path: Array[Vector2i] = []
			path.assign(paths[destination])
			if path.is_empty() or not skill_manager.debuff_manager.can_follow_path(expected, path):
				continue
			var distance := HexGrid.distance(destination, source.position)
			if distance < closest or (distance == closest and not best_path.is_empty() \
					and path.size() < best_path.size()):
				closest = distance
				best_path = path
	if not best_path.is_empty():
		_apply_move(expected, best_path)
		await get_tree().create_timer(_visual_move_wait(expected,
			best_path.size())).timeout
	if current_actor == expected and pending_conclusion.is_empty() \
			and _pending_trap.is_empty():
		end_current_turn(true)


func _run_automatic_actives(actor: EntityState,
		trigger: ActiveSkillData.AutomaticTrigger,
		default_target: EntityState = null) -> bool:
	if actor == null or actor.current_health <= 0 or skill_manager == null \
			or gerencia == null:
		return false
	var ready: Array[SkillGrantState] = []
	var groups: Dictionary = {}
	for grant in skill_manager.get_active_grants(actor):
		var skill := grant.skill as ActiveSkillData
		if skill == null or trigger not in skill.automatic_triggers \
				or not _automatic_skill_due(actor, skill):
			continue
		if skill.activate_once_per_encounter \
				and _encounter_automatic_skill_uses.has(skill.id):
			continue
		if actor.summoned_by_instance_id != &"" and not actor.summoned_can_summon \
				and skill.effects.any(func(effect: SkillEffectData) -> bool:
					return effect.effect_type == SkillEffectData.EffectType.SUMMON_ENTITY):
			continue
		if skill.random_choice_group == &"":
			ready.append(grant)
		else:
			if not groups.has(skill.random_choice_group):
				groups[skill.random_choice_group] = []
			(groups[skill.random_choice_group] as Array).append(grant)
	for group in groups.values():
		var total := 0
		for grant in group:
			total += (grant.skill as ActiveSkillData).random_choice_weight
		var draw := _rng.randi_range(1, total)
		for grant in group:
			draw -= (grant.skill as ActiveSkillData).random_choice_weight
			if draw <= 0:
				ready.append(grant)
				break
	var replaced_main_action := false
	for grant in ready:
		var skill := grant.skill as ActiveSkillData
		var target := _automatic_skill_target(actor, skill, default_target)
		if _rng.randf() >= skill.activation_chance or not skill_manager.can_use_combat_active(
				actor, grant, gerencia.campaign, self, target, true):
			continue
		var outcome := skill_manager.use_combat_active(actor, grant,
			gerencia.campaign, self, target, true)
		if not outcome.get("success", false):
			continue
		if skill.activate_once_per_encounter:
			_encounter_automatic_skill_uses[skill.id] = true
		if target != null:
			_previous_skill_targets[actor.instance_id] = target.instance_id
		action_resolved.emit(actor, &"skill", outcome)
		if skill.ends_turn or trigger == ActiveSkillData.AutomaticTrigger.ON_ATTACK_SELECTION:
			replaced_main_action = true
	return replaced_main_action


func _automatic_skill_due(actor: EntityState, skill: ActiveSkillData) -> bool:
	var turn_number := combat_cycle if skill.activate_once_per_encounter else \
		int(_combat_turns_by_id.get(actor.instance_id, 0))
	if skill.first_activation_turn > 0 and turn_number < skill.first_activation_turn:
		return false
	if skill.repeat_every_turns > 0 and skill.first_activation_turn > 0 \
			and (turn_number - skill.first_activation_turn) % skill.repeat_every_turns != 0:
		return false
	return turn_number >= skill.minimum_owner_survived_combat_turns


func _automatic_skill_target(actor: EntityState, skill: ActiveSkillData,
		default_target: EntityState) -> EntityState:
	if skill.target_mode in [ActiveSkillData.TargetMode.SELF,
			ActiveSkillData.TargetMode.NONE]:
		return null
	var available: Array[EntityState] = _opponents_of(actor).filter(
		func(entity: EntityState) -> bool:
			return entity != null and entity.current_health > 0 \
				and entity.position != EntityState.UNPLACED)
	if available.is_empty():
		return null
	# Prioridade Forçada e Arqui-inimigo prevalecem também nos ataques
	# programados da Cobaia Mutante.
	var forced: Array[EntityState] = []
	for entity in available:
		var score := _ai.threat_score(actor, entity, -1, skill_manager, {})
		if score >= 500:
			forced.append(entity)
	if not forced.is_empty():
		return forced[_rng.randi_range(0, forced.size() - 1)]
	if skill.avoid_previous_target and available.size() > 1:
		var previous := _previous_skill_targets.get(actor.instance_id, &"") as StringName
		available = available.filter(func(entity: EntityState) -> bool:
			return entity.instance_id != previous)
	available.sort_custom(func(left: EntityState, right: EntityState) -> bool:
		return HexGrid.distance(actor.position, left.position) < \
			HexGrid.distance(actor.position, right.position))
	match skill.target_priority:
		ActiveSkillData.TargetPriority.NEAREST: return available[0]
		ActiveSkillData.TargetPriority.SECOND_NEAREST: return available[mini(1, available.size() - 1)]
		ActiveSkillData.TargetPriority.THIRD_NEAREST: return available[mini(2, available.size() - 1)]
		ActiveSkillData.TargetPriority.LOWEST_HEALTH:
			available.sort_custom(func(left: EntityState, right: EntityState) -> bool:
				return left.current_health < right.current_health)
			return available[0]
		ActiveSkillData.TargetPriority.HAS_DEBUFF:
			for entity in available:
				if skill_manager.debuff_manager.get_debuff(entity,
						skill.required_target_debuff_id) != null:
					return entity
		ActiveSkillData.TargetPriority.RANDOM:
			return available[_rng.randi_range(0, available.size() - 1)]
	return default_target if default_target in available else available[0]


func _apply_move(actor: EntityState, path: Array[Vector2i]) -> void:
	if actor == null or path.is_empty():
		return
	var origin := actor.position
	var cost := path.size()
	actor.stamina_remaining = maxi(0, actor.stamina_remaining - cost)
	actor.position = path[-1]
	_steps_moved += cost
	_turn_moved = true
	if skill_manager != null:
		skill_manager.on_entity_moved(actor, gerencia.campaign, _rng)
		_dispatch_combat_passive(actor, PassiveSkillData.Trigger.ON_AFTER_MOVE,
			{"path": path, "hexes_moved": cost})
	_sync_combat_view()
	action_resolved.emit(actor, &"move", {"position": actor.position,
		"origin": origin, "path": path.duplicate(), "cost": cost})
	_animate_non_playable_move(actor, origin, path)
	if actor.controller == EntityState.Controller.PLAYER:
		var grid := gerencia.campaign.current_map
		var cell := grid.get_cell(actor.position)
		if cell != null and cell.block_type == HexGrid.PPPBlockType.TRAP \
				and cell.state in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			var trap := grid.get_ppp_block_resource(actor.position) as EventData
			if trap != null:
				_pending_trap = {"event": trap, "actor": actor, "coord": actor.position}
				action_mode = &""
				combat_trap_requested.emit(trap, actor, actor.position)
	_check_combat_end()


func _animate_non_playable_move(actor: EntityState, origin: Vector2i,
		path: Array[Vector2i]) -> void:
	if enemy_visual_root == null or actor == null:
		return
	var visual := _visual_for_actor(actor)
	if visual != null and visual.has_method("animate_path"):
		visual.animate_path(origin, path)


func resolve_pending_trap() -> Dictionary:
	if _pending_trap.is_empty() or event_executor == null or gerencia == null:
		return {"success": false, "reason": "Não há armadilha pendente."}
	var trap := _pending_trap["event"] as EventData
	var actor := _pending_trap["actor"] as EntityState
	var coord := _pending_trap["coord"] as Vector2i
	var result := event_executor.resolve_combat_trap(trap, actor, coord, self)
	if not result.get("success", false):
		return result
	gerencia.record_event_activated(trap)
	gerencia.campaign.current_map.activate_ppp_block(coord)
	if map_view != null:
		map_view.activate_block(coord)
	_pending_trap.clear()
	action_resolved.emit(actor, &"trap", {"event": trap, "result": result})
	if _pending_attack_coord != EntityState.UNPLACED and actor == current_actor \
			and actor.current_health > 0 and skill_manager != null \
			and skill_manager.debuff_manager.can_take_action(actor):
		var target := _opponent_at(actor, _pending_attack_coord)
		if target != null and HexGrid.distance(actor.position, target.position) == 1:
			_resolve_attack(actor, target)
	_pending_attack_coord = EntityState.UNPLACED
	_check_combat_end()
	if actor == current_actor and _charm_due_this_turn(actor) \
			and pending_conclusion.is_empty():
		call_deferred("end_current_turn", true)
	return result


## O Fio de Alarme soma o Encontro mais próximo ao combate em curso.
func add_alarm_reinforcements(origin: Vector2i) -> Dictionary:
	if gerencia == null or gerencia.campaign.current_map == null:
		return {"success": false, "reason": "Mapa indisponível."}
	var grid := gerencia.campaign.current_map
	var source: Vector2i = block_manager.get_pending_context().get("coord",
		EntityState.UNPLACED) if block_manager != null else EntityState.UNPLACED
	var closest := 999
	var candidates: Array[Vector2i] = []
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if coord == source or cell == null or cell.block_type != HexGrid.PPPBlockType.ENCOUNTER \
				or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			continue
		var distance := HexGrid.distance(origin, coord)
		if distance < closest:
			closest = distance
			candidates.clear()
		if distance == closest:
			candidates.append(coord)
	if candidates.is_empty():
		return {"success": false,
			"reason": "O Fio de Alarme não encontrou Encontro disponível no mapa."}
	var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]
	var encounter := grid.get_ppp_block_resource(chosen) as EncounterData
	if encounter == null:
		return {"success": false, "reason": "Encontro do alarme inválido."}
	var added := 0
	for member in encounter.members:
		if member == null or member.entity == null:
			continue
		for index in _rng.randi_range(member.minimum, member.maximum):
			var spawned := spawn_summoned_enemy(member.entity, current_actor)
			if spawned != null:
				added += 1
	if added == 0:
		return {"success": false,
			"reason": "Sem hex livre para os reforços do Fio de Alarme."}
	grid.activate_ppp_block(chosen)
	if map_view != null:
		map_view.activate_block(chosen)
	gerencia.record_encounter_occurred(encounter)
	gerencia.campaign.record_completed_encounter(encounter)
	return {"success": true, "reinforcements": added, "encounter": encounter}


func _resolve_attack(attacker: EntityState, target: EntityState,
		ranged_override: int = -1) -> Dictionary:
	if attacker == null or target == null or target.current_health <= 0:
		return {"success": false}
	if skill_manager != null and not skill_manager.debuff_manager.can_attack(attacker):
		return {"success": false, "reason": "Charme impede o ataque."}
	var distance := HexGrid.distance(attacker.position, target.position)
	var ranged := (ranged_override == 1) if ranged_override >= 0 else \
		_uses_ranged_attack(attacker)
	if distance <= 0 or (not ranged and distance > 1) \
			or (ranged and distance > attacker.attack + _turn_die \
			and (skill_manager == null or not skill_manager.ignores_attack_range(
				attacker, _attack_mastery(attacker)))):
		return {"success": false}
	var weapon := attacker.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	var dagger_aspect: StringName = attacker.dagger_next_aspect \
		if weapon != null and weapon.data != null and weapon.data.id == &"aa_00001" \
		else &""
	var attack_context := {"attack_target": target, "selected_target": target,
		"damage_source": attacker, "damage_source_adjacent": distance == 1,
		"direct_attack": true,
		"is_melee_attack": not ranged,
		"incoming_attack_type": PassiveSkillData.IncomingAttackType.RANGED \
			if ranged else PassiveSkillData.IncomingAttackType.MELEE,
		"attack_item_id": weapon.data.id if weapon != null else &"",
		"attack_aspect": dagger_aspect,
		"has_weapon_for_attack": weapon != null or _has_absorbed_weapon(attacker),
		"damage_source_item_id": weapon.data.id if weapon != null else &"",
		"damage_die_result": _turn_die,
		"hexes_moved_this_turn": _steps_moved}
	attack_context["previous_encounters_same_entity_data"] = int(
		gerencia.campaign.completed_encounter_entity_counts.get(target.data.id, 0)) \
		if target.data != null else 0
	attack_context["target_revealed_by_skill_ids"] = _encounter_reveal_sources
	var before_results := _dispatch_combat_passive(attacker,
		PassiveSkillData.Trigger.ON_BEFORE_ATTACK, attack_context)
	var current_attack_bonus := 0
	var damage_multiplier := 1.0
	for passive_result in before_results:
		for effect_result in passive_result.get("effects", []):
			current_attack_bonus += int(effect_result.get("current_attack_bonus", 0))
			damage_multiplier *= float(effect_result.get("damage_multiplier", 1.0))
	var mastery := _attack_mastery(attacker)
	var critical_hit := _is_critical_roll(attacker)
	var guarded := _damage_guards.get(target.instance_id) as EntityState
	if guarded != null and guarded.current_health > 0:
		target = guarded
		attack_context["attack_target"] = target
		attack_context["selected_target"] = target
	var ranged_critical_bonus := ranged and critical_hit \
		and mastery == EntityData.Mastery.RANGED \
		and not target.ignore_ranged_critical_bonus
	var distance_penalty := distance if attacker.controller == EntityState.Controller.AI and ranged \
		else maxi(0, distance - 1) if ranged else 0
	if ranged_critical_bonus or _has_absorbed_ranged_weapon(attacker):
		distance_penalty = 0
	var deduction := distance_penalty if attacker.controller == EntityState.Controller.AI \
		and ranged else _steps_moved + distance_penalty
	var unarmed := attacker.controller == EntityState.Controller.PLAYER \
		and weapon == null and not _has_absorbed_weapon(attacker)
	var base_attack := _attack_base_for_roll(attacker, unarmed)
	var raw_damage := maxi(0, floori(float(base_attack + current_attack_bonus + _turn_die \
		- deduction + (2 if unarmed and _turn_die == 6 else 0)) * damage_multiplier))
	if ranged and skill_manager != null and skill_manager.ignores_attack_range(
			attacker, mastery):
		# Olhos Biônicos remove o teto de alcance; a queda por distância
		# continua, mas um disparo acertado não vira alcance "infinito" de 0 dano.
		raw_damage = maxi(1, raw_damage)
	_attacks_used += 1
	if dagger_aspect != &"":
		attacker.dagger_next_aspect = &"shadow" if dagger_aspect == &"light" else &"light"
	_consume_next_attack_bonus(attacker)
	var result := {"success": raw_damage > 0, "damage": 0,
		"raw_damage": raw_damage, "die": _turn_die, "distance": distance}
	var previous_debuff_ids: Array[StringName] = []
	for active_debuff in target.debuffs:
		if active_debuff != null and active_debuff.data != null:
			previous_debuff_ids.append(active_debuff.data.id)
	var critical_status := &""
	var ricochet_results: Array[Dictionary] = []
	if raw_damage > 0 and skill_manager != null:
		hit_prepared.emit(target)
		var guarded_fraction := float(_guard_reductions.get(target.instance_id, 1.0))
		var guarded_damage := maxi(1, floori(float(raw_damage) * guarded_fraction))
		var incoming_context := _combat_context(attacker, attack_context)
		incoming_context["protection_basis"] = raw_damage
		var applied := skill_manager.apply_incoming_damage(target, guarded_damage,
			gerencia.campaign, incoming_context, _rng)
		result["damage"] = applied.get("damage", 0)
		result["dodged"] = applied.get("dodged", false)
		result["survived_lethal_hit"] = applied.get("survived_lethal_hit", false)
		attack_context["damage_dealt"] = result["damage"]
		attack_context["attack_hit"] = result["damage"] > 0 \
			or result["survived_lethal_hit"]
		if int(result["damage"]) > 0 and critical_hit:
			critical_status = _apply_mastery_critical(attacker, target, mastery)
		_dispatch_combat_passive(attacker, PassiveSkillData.Trigger.ON_AFTER_ATTACK,
			attack_context)
		var after_damage := _dispatch_combat_passive(attacker,
			PassiveSkillData.Trigger.ON_AFTER_DAMAGE_DEALT, attack_context)
		for passive_result in after_damage:
			for effect_result in passive_result.get("effects", []):
				if effect_result.get("ricochet", false):
					ricochet_results.append(effect_result)
		_dispatch_combat_passive(target, PassiveSkillData.Trigger.ON_AFTER_DAMAGE_RECEIVED,
			attack_context)
		for ally in _allies_of(target):
			if ally != target and ally.current_health > 0:
				var ally_context := attack_context.duplicate()
				ally_context["damaged_ally"] = target
				_dispatch_combat_passive(ally,
					PassiveSkillData.Trigger.ON_AFTER_ALLY_DAMAGE_RECEIVED, ally_context)
		if target in enemies and int(result["damage"]) >= ceili(target.max_health * 0.40):
			var retaliation: Dictionary = _retaliation_by_enemy.get(target.instance_id, {})
			retaliation[attacker.instance_id] = true
			_retaliation_by_enemy[target.instance_id] = retaliation
		if target.current_health <= 0:
			_hide_dead_enemy(target)
	var resolved_die := _turn_die
	if attacker == current_actor and attacker.controller == EntityState.Controller.PLAYER:
		_turn_die = 0
	var applied_statuses: Array[String] = []
	if critical_status == &"db_00008":
		applied_statuses.append("sangramento")
	elif critical_status == &"db_00002":
		applied_statuses.append("atordoamento")
	for active_debuff in target.debuffs:
		if active_debuff == null or active_debuff.data == null \
				or active_debuff.data.id in previous_debuff_ids:
			continue
		var status_name := ""
		match active_debuff.data.id:
			&"db_00008": status_name = "sangramento"
			&"db_00002": status_name = "atordoamento"
		if not status_name.is_empty() and status_name not in applied_statuses:
			applied_statuses.append(status_name)
	_sync_combat_view()
	_show_damage_popup(target, int(result["damage"]),
		"ESQUIVA" if result.get("dodged", false) else \
		"SEM DANO", result.get("survived_lethal_hit", false))
	action_resolved.emit(attacker, &"attack", {"target": target,
		"ranged": ranged,
		"dagger_aspect": dagger_aspect,
		"damage": result["damage"], "raw_damage": raw_damage,
		"dodged": result.get("dodged", false), "die": resolved_die,
		"survived_lethal_hit": result.get("survived_lethal_hit", false),
		"critical": critical_hit and int(result["damage"]) > 0,
		"applied_statuses": applied_statuses})
	for ricochet in ricochet_results:
		action_resolved.emit(attacker, &"ricochet", ricochet)
	_check_combat_end()
	return result


func _attack_mastery(actor: EntityState) -> EntityData.Mastery:
	if actor == null:
		return EntityData.Mastery.NONE
	var weapon := actor.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	if weapon != null and weapon.data != null:
		return weapon.data.mastery_granted if actor.has_mastery(weapon.data.mastery_granted) \
			else EntityData.Mastery.NONE
	if skill_manager != null:
		for grant in skill_manager.get_passive_grants(actor):
			if grant.skill != null and grant.skill.id == &"permanent_passive_058" \
					and grant.bound_source is ItemData:
				var absorbed := grant.bound_source as ItemData
				if actor.has_mastery(absorbed.mastery_granted):
					return absorbed.mastery_granted
	if actor.controller == EntityState.Controller.PLAYER:
		# Desarmado não aplica efeitos de Maestria, mesmo se o personagem a conhece.
		return EntityData.Mastery.NONE
	if actor.encounter_mastery_override != EntityData.Mastery.NONE:
		return actor.encounter_mastery_override
	if actor.data != null:
		for candidate in actor.data.maestrias:
			if candidate != EntityData.Mastery.NONE:
				return candidate
	return EntityData.Mastery.NONE


func _is_critical_roll(actor: EntityState) -> bool:
	if _turn_die <= 0:
		return false
	var threshold := 6
	if skill_manager != null:
		for entry in skill_manager.get_continuous_effects(actor,
				SkillEffectData.EffectType.SET_CRITICAL_ROLL_THRESHOLD):
			threshold = mini(threshold, (entry["effect"] as SkillEffectData).minimum_value)
	return _turn_die >= threshold


func _apply_mastery_critical(attacker: EntityState, target: EntityState,
		mastery: EntityData.Mastery) -> StringName:
	if skill_manager == null or target.current_health <= 0:
		return &""
	var debuff_id := &""
	match mastery:
		EntityData.Mastery.BLADE: debuff_id = &"db_00008"
		EntityData.Mastery.IMPACT: debuff_id = &"db_00002"
	if debuff_id == &"" or skill_manager.is_status_immune(target, debuff_id):
		return &""
	var applied := skill_manager.debuff_manager.apply_by_id(target, debuff_id, attacker,
		0, gerencia.campaign.day, -1, attacker.data.id if attacker.data != null else &"",
		-1.0, _turn_die)
	return debuff_id if bool(applied.get("success", false)) else &""


func _attack_base_for_roll(actor: EntityState, unarmed: bool) -> int:
	var base := actor.attack
	if unarmed:
		for equipped in actor.equipped_armors + actor.equipped_accessories:
			if equipped.data != null and actor.data != null \
					and equipped.data.mastery_granted in actor.data.maestrias:
				base -= equipped.data.mastery_bonus
	return base


func apply_passive_attack_bonus(actor: EntityState, effect: SkillEffectData) -> Dictionary:
	if actor == null or effect == null or effect.attribute_id != &"attack":
		return {"success": false}
	if effect.modify_mode == SkillEffectData.ModifyMode.MULTIPLY:
		if effect.requires_no_weapon_equipped:
			return {"success": true, "damage_multiplier": effect.multiplier}
		if effect.requires_melee_weapon_equipped:
			return {"success": true, "current_attack_bonus":
				ceili(float(actor.attack) * (effect.multiplier - 1.0))}
		return {"success": false}
	if effect.amount <= 0:
		return {"success": false}
	if effect.apply_to_current_attack_only:
		return {"success": true, "current_attack_bonus": effect.amount}
	var bucket: Dictionary
	var is_mother_bonus := effect.duration_unit == SkillEffectData.DurationUnit.UNTIL_END_OF_NEXT_OWNER_TURN
	if effect.duration_unit == SkillEffectData.DurationUnit.UNTIL_NEXT_ATTACK:
		bucket = _next_attack_bonuses
	elif is_mother_bonus:
		bucket = _mother_attack_bonuses
	else:
		return {"success": false, "reason": "Duração de bônus de ataque não suportada."}
	var record: Dictionary = bucket.get(actor.instance_id, {"actor": actor, "amount": 0})
	record["amount"] = int(record["amount"]) + effect.amount
	if is_mother_bonus:
		record["expires_turn"] = maxi(int(record.get("expires_turn", 0)),
			actor.turn_serial + 1)
	bucket[actor.instance_id] = record
	actor.attack += effect.amount
	return {"success": true, "attack_bonus": effect.amount}


func _consume_next_attack_bonus(actor: EntityState) -> void:
	if actor == null or not _next_attack_bonuses.has(actor.instance_id):
		return
	var record: Dictionary = _next_attack_bonuses[actor.instance_id]
	actor.attack -= int(record["amount"])
	_next_attack_bonuses.erase(actor.instance_id)


func _expire_mother_bonus(actor: EntityState) -> void:
	if actor == null or not _mother_attack_bonuses.has(actor.instance_id):
		return
	var record: Dictionary = _mother_attack_bonuses[actor.instance_id]
	if actor.turn_serial >= int(record.get("expires_turn", 0)):
		actor.attack -= int(record["amount"])
		_mother_attack_bonuses.erase(actor.instance_id)


func try_passive_counterattack(actor: EntityState, attacker: EntityState) -> Dictionary:
	if actor == null or attacker == null or actor.current_health <= 0 \
			or attacker.current_health <= 0 or attacker not in _opponents_of(actor):
		return {"success": true, "skipped": true}
	var weapon := actor.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	if weapon == null or weapon.data == null:
		return {"success": true, "skipped": true}
	var distance := HexGrid.distance(actor.position, attacker.position)
	var ranged := weapon.data.mastery_granted == EntityData.Mastery.RANGED
	var dagger_aspect: StringName = actor.dagger_next_aspect \
		if weapon.data.id == &"aa_00001" else &""
	var roll := gerencia.campaign.player_dice_luck.roll_for_player(_rng) \
		if actor.controller == EntityState.Controller.PLAYER else \
		gerencia.campaign.enemy_dice_luck.roll_for_enemy(_rng)
	if distance <= 0 or distance > (actor.attack + roll if ranged else 1):
		return {"success": true, "skipped": true}
	var raw := maxi(0, actor.attack + roll - (maxi(0, distance - 1) if ranged else 0))
	if raw <= 0:
		return {"success": true, "skipped": true}
	if dagger_aspect == &"light":
		raw *= 2
	if dagger_aspect != &"":
		actor.dagger_next_aspect = &"shadow" if dagger_aspect == &"light" else &"light"
	hit_prepared.emit(attacker)
	var applied := skill_manager.apply_incoming_damage(attacker, raw,
		gerencia.campaign, _combat_context(actor, {"damage_source": actor,
			"is_melee_attack": not ranged, "damage_source_adjacent": distance == 1,
			"incoming_attack_type": PassiveSkillData.IncomingAttackType.RANGED \
				if ranged else PassiveSkillData.IncomingAttackType.MELEE,
			"direct_attack": true}), _rng)
	var dealt := int(applied.get("damage", 0))
	if dagger_aspect == &"shadow" and dealt > 0:
		actor.current_health = mini(actor.max_health,
			actor.current_health + floori(float(dealt) * 0.6))
	_show_damage_popup(attacker, dealt,
		"SEM DANO", applied.get("survived_lethal_hit", false))
	action_resolved.emit(actor, &"counterattack", {"target": attacker,
		"damage": dealt, "die": roll, "dagger_aspect": dagger_aspect,
		"ranged": ranged,
		"survived_lethal_hit": applied.get("survived_lethal_hit", false)})
	if attacker.current_health <= 0:
		_hide_dead_enemy(attacker)
	_check_combat_end()
	return {"success": true, "damage": dealt, "counterattack": true}


func _show_damage_popup(target: EntityState, damage: int,
		zero_label: String = "SEM DANO", survived_lethal_hit: bool = false) -> void:
	if enemy_visual_root == null or target == null:
		return
	var label := Label.new()
	label.name = "DamagePopup"
	label.z_index = 20
	label.text = ("-%d · 1 DE VIDA" % damage if damage > 0 else "1 DE VIDA") \
		if survived_lethal_hit else "-%d" % damage if damage > 0 else zero_label
	label.add_theme_color_override("font_color", Color(0.94, 0.77, 0.35)
		if survived_lethal_hit else Color(1.0, 0.10, 0.15)
		if damage > 0 else Color(0.86, 0.90, 0.94))
	label.add_theme_color_override("font_shadow_color", Color(0.05, 0.0, 0.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 25)
	label.position = PPPMapView.reference_hex_position(target.position) + Vector2(-20, -170)
	enemy_visual_root.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort == null or not bool(comfort.get("enabled")):
		tween.tween_property(label, "position:y", label.position.y - 38.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(label.queue_free)


func _dispatch_combat_passive(actor: EntityState, trigger: PassiveSkillData.Trigger,
		extra: Dictionary) -> Array[Dictionary]:
	if skill_manager == null or actor == null:
		return []
	return skill_manager.dispatch_passive_trigger(actor, trigger, gerencia.campaign,
		_combat_context(actor, extra), _rng)


func _combat_context(actor: EntityState, extra: Dictionary) -> Dictionary:
	var context := {"mode": HexGrid.PPPMapMode.COMBAT,
		"combat": self,
		"combat_id": _combat_id,
		"combat_turn_number": int(_combat_turns_by_id.get(actor.instance_id, 0)),
		"allies": _allies_of(actor), "enemies": _opponents_of(actor)}
	context.merge(extra, true)
	return context


func _uses_ranged_attack(actor: EntityState) -> bool:
	var weapon := actor.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	if weapon != null and weapon.data != null:
		return weapon.data.mastery_granted == EntityData.Mastery.RANGED
	if skill_manager != null:
		for grant in skill_manager.get_passive_grants(actor):
			if grant.skill != null and grant.skill.id == &"permanent_passive_058" \
					and grant.bound_source is ItemData \
					and (grant.bound_source as ItemData).mastery_granted == EntityData.Mastery.RANGED:
				return true
	if actor.controller == EntityState.Controller.AI and actor.data != null:
		return actor.encounter_mastery_override == EntityData.Mastery.RANGED \
			or (actor.encounter_mastery_override == EntityData.Mastery.NONE \
			and EntityData.Mastery.RANGED in actor.data.maestrias)
	return false


func _has_absorbed_weapon(actor: EntityState) -> bool:
	if actor == null or skill_manager == null:
		return false
	for grant in skill_manager.get_passive_grants(actor):
		if grant.skill != null and grant.skill.id == &"permanent_passive_058" \
				and grant.bound_source is ItemData:
			return true
	return false


func _has_absorbed_ranged_weapon(actor: EntityState) -> bool:
	if actor == null or skill_manager == null:
		return false
	for grant in skill_manager.get_passive_grants(actor):
		if grant.skill != null and grant.skill.id == &"permanent_passive_058" \
				and grant.bound_source is ItemData \
				and (grant.bound_source as ItemData).mastery_granted == EntityData.Mastery.RANGED:
			return true
	return false


## Voar após atacar usa um deslocamento adicional, sem gastar novamente a
## Estamina do percurso de aproximação. O Resource define metade do percurso.
func move_after_attack(actor: EntityState, target: EntityState,
		maximum_steps: int) -> Dictionary:
	if actor == null or target == null or maximum_steps <= 0 or gerencia == null:
		return {"success": false}
	var paths := _ai.reachable_paths(gerencia.campaign.current_map,
		actor.position, maximum_steps, _occupied_positions(actor))
	var best_distance := HexGrid.distance(actor.position, target.position)
	var best_path: Array[Vector2i] = []
	for coord in paths:
		var candidate: Array = paths[coord]
		var distance := HexGrid.distance(coord, target.position)
		if candidate.is_empty() or distance <= best_distance:
			continue
		best_distance = distance
		best_path.assign(candidate)
	if best_path.is_empty():
		return {"success": true, "moved": false}
	var origin := actor.position
	actor.position = best_path[-1]
	action_resolved.emit(actor, &"move", {"position": actor.position,
		"origin": origin, "path": best_path.duplicate(),
		"cost": 0, "post_attack": true})
	_animate_non_playable_move(actor, origin, best_path)
	return {"success": true, "moved": true, "path": best_path}


func has_dodge_destination(actor: EntityState) -> bool:
	return not _dodge_paths(actor).is_empty()


func dodge_to_adjacent(actor: EntityState, attacker: EntityState) -> Dictionary:
	var paths := _dodge_paths(actor)
	if paths.is_empty():
		return {"success": false}
	var best_distance := -1
	var candidates: Array[Vector2i] = []
	for coord in paths:
		var distance := HexGrid.distance(coord, attacker.position) if attacker != null else 0
		if distance > best_distance:
			best_distance = distance
			candidates.clear()
		if distance == best_distance:
			candidates.append(coord)
	var selected := candidates[_rng.randi_range(0, candidates.size() - 1)]
	var origin := actor.position
	actor.position = selected
	var path: Array[Vector2i] = [selected]
	action_resolved.emit(actor, &"move", {"origin": origin,
		"position": selected, "path": path, "cost": 0, "dodge": true})
	_animate_non_playable_move(actor, origin, path)
	return {"success": true, "dodged": true, "destination": selected}


func _dodge_paths(actor: EntityState) -> Dictionary:
	if actor == null or gerencia == null or gerencia.campaign.current_map == null:
		return {}
	var paths := _ai.reachable_paths(gerencia.campaign.current_map,
		actor.position, 1, _occupied_positions(actor))
	paths.erase(actor.position)
	return paths


func _occupied_positions(except_actor: EntityState = null) -> Dictionary:
	var occupied: Dictionary = {}
	for actor in _combat_playables() + _combat_companions() + enemies:
		if actor != null and actor != except_actor and actor.current_health > 0 \
				and actor.position != EntityState.UNPLACED:
			occupied[actor.position] = true
	return occupied


func _allies_of(actor: EntityState, include_dead: bool = false) -> Array[EntityState]:
	var allies: Array[EntityState] = []
	if actor in enemies:
		allies.append_array(enemies)
	else:
		allies.append_array(_combat_playables())
		allies.append_array(_combat_companions())
	for index in range(allies.size() - 1, -1, -1):
		if allies[index] == null or (not include_dead and allies[index].current_health <= 0) \
				or allies[index].position == EntityState.UNPLACED:
			allies.remove_at(index)
	return allies


func place_revived_ally(target: EntityState, owner: EntityState) -> void:
	if target == null or owner == null or gerencia == null \
			or gerencia.campaign.current_map == null:
		return
	var grid := gerencia.campaign.current_map
	var occupied := _occupied_positions(target)
	if not grid.is_valid(target.position) or occupied.has(target.position):
		var nearest := EntityState.UNPLACED
		var distance := 999999
		for coord in grid.cells:
			if occupied.has(coord):
				continue
			var candidate_distance := HexGrid.distance(owner.position, coord)
			if candidate_distance < distance:
				distance = candidate_distance
				nearest = coord
		if nearest != EntityState.UNPLACED:
			target.position = nearest
	if target.position == EntityState.UNPLACED:
		return
	_draw_silhouette_companions(gerencia.campaign)
	if not initiative_order.any(func(entry: Dictionary) -> bool:
		return entry.get("entity") == target):
		target.turn_state = EntityState.TurnState.AVAILABLE
		initiative_order.append(_roll_initiative_entry(target))
		ally_revived.emit(target)


func _opponents_of(actor: EntityState) -> Array[EntityState]:
	var opponents: Array[EntityState] = []
	if actor in enemies:
		opponents.append_array(_combat_playables())
		opponents.append_array(_combat_companions())
	else:
		opponents.append_array(enemies)
	for index in range(opponents.size() - 1, -1, -1):
		if opponents[index] == null or opponents[index].current_health <= 0 \
				or opponents[index].position == EntityState.UNPLACED \
				or actor in enemies and skill_manager != null \
					and skill_manager.debuff_manager.has_exploration_event_control(opponents[index]):
			opponents.remove_at(index)
	return opponents


## Ricochete da Espada Irada Eletrizante. O centro é o alvo atingido, não o
## atacante; nunca atinge o mesmo inimigo nem inicia outro ricochete em cadeia.
func apply_ricochet_damage(attacker: EntityState, primary: EntityState,
		primary_damage: int, fraction: float, max_hexes: int) -> Dictionary:
	if attacker == null or primary == null or skill_manager == null \
			or gerencia == null or gerencia.campaign == null or primary_damage <= 0:
		return {"success": false}
	var damage := floori(float(primary_damage) * fraction)
	if damage <= 0:
		return {"success": true, "damage": 0, "skipped": true}
	var closest := 999999
	var candidates: Array[EntityState] = []
	for enemy in _opponents_of(attacker):
		if enemy == primary:
			continue
		var distance := HexGrid.distance(primary.position, enemy.position)
		if distance > max_hexes:
			continue
		if distance < closest:
			closest = distance
			candidates.clear()
		if distance == closest:
			candidates.append(enemy)
	if candidates.is_empty():
		return {"success": true, "damage": 0, "skipped": true}
	var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]
	hit_prepared.emit(chosen)
	var applied := skill_manager.apply_incoming_damage(chosen, damage,
		gerencia.campaign, {"mode": HexGrid.PPPMapMode.COMBAT,
			"damage_source": attacker,
			"combat_id": _combat_id, "direct_attack": true,
			"generated_damage_can_trigger_passives": false}, _rng)
	var dealt := int(applied.get("damage", 0))
	_show_damage_popup(chosen, dealt,
		"ESQUIVA" if applied.get("dodged", false) else \
		"SEM DANO", applied.get("survived_lethal_hit", false))
	if chosen.current_health <= 0:
		_hide_dead_enemy(chosen)
	return {"success": true, "ricochet": true, "target": chosen,
		"damage": dealt, "source_target": primary,
		"survived_lethal_hit": applied.get("survived_lethal_hit", false)}


func _opponent_at(actor: EntityState, coord: Vector2i) -> EntityState:
	for opponent in _opponents_of(actor):
		if opponent != null and opponent.current_health > 0 and opponent.position == coord:
			return opponent
	return null


func _check_combat_end() -> bool:
	if _promotion_cleanup_pending:
		return true
	if current_encounter == null or not pending_conclusion.is_empty():
		return not pending_conclusion.is_empty()
	if _solo_actor != null and _solo_actor.current_health <= 0:
		return request_solo_defeat()
	# Fechar a morte depois da oportunidade de ressuscitar, mas antes de
	# declarar derrota: um aliado humano jogável assume imediatamente a vaga.
	if _solo_actor == null and gerencia != null and gerencia.campaign != null \
			and gerencia.campaign.has_dead_playable_slot() \
			and gerencia.campaign.first_promotable_playable_companion() != null:
		_promotion_cleanup_pending = true
		var companion_ids: Dictionary = {}
		for companion in gerencia.campaign.companion_states:
			if companion != null:
				companion_ids[companion] = companion.instance_id
		gerencia.campaign.finalize_dead_playables(skill_manager, _rng)
		for companion in companion_ids:
			if companion in gerencia.campaign.active_entity_states:
				_remap_combat_participant_id(companion_ids[companion],
					companion.instance_id)
		_remove_promoted_ally_visuals_after_animation.call_deferred()
		return true
	var living_enemy := enemies.any(func(enemy: EntityState) -> bool:
		return enemy != null and enemy.current_health > 0)
	if not living_enemy:
		return request_victory()
	var living_playable := _combat_playables().any(
		func(actor: EntityState) -> bool: return actor != null and actor.current_health > 0)
	if not living_playable:
		return request_solo_defeat() if _solo_actor != null else request_defeat()
	# Se ninguém mais puder ser alvejado, a proteção temporária não pode
	# tornar o combate interminável. Duração em turnos liberta o sobrevivente;
	# duração por rodada mantém a derrota definida pelo jogo.
	if _solo_actor == null and skill_manager != null:
		var allies := _combat_playables() + _combat_companions()
		var targetable := allies.any(func(actor: EntityState) -> bool:
			return actor != null and actor.current_health > 0 \
				and actor.position != EntityState.UNPLACED \
				and not skill_manager.debuff_manager.has_exploration_event_control(actor))
		if not targetable:
			for actor in allies:
				if actor != null and actor.current_health > 0:
					skill_manager.debuff_manager.release_exploration_event_turn_controls(actor)
			targetable = allies.any(func(actor: EntityState) -> bool:
				return actor != null and actor.current_health > 0 \
					and actor.position != EntityState.UNPLACED \
					and not skill_manager.debuff_manager.has_exploration_event_control(actor))
			if not targetable:
				return request_defeat()
	return false


## Chamado só depois do OK da redistribuição obrigatória. O combate não
## avança enquanto o jogador decide para onde vai o espólio.
func on_promotion_cleanup_confirmed() -> void:
	if not _promotion_cleanup_pending:
		return
	_promotion_cleanup_pending = false
	if _check_combat_end():
		return
	if current_actor == null or current_actor.current_health <= 0:
		call_deferred("_advance_turn")
	elif current_actor.controller == EntityState.Controller.AI:
		call_deferred("end_current_turn")


func _remove_promoted_ally_visuals_after_animation() -> void:
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree() or enemy_visual_root == null or gerencia == null:
		return
	for visual in enemy_visual_root.get_children():
		if visual is EnemySilhouetteVisual and visual.state in \
				gerencia.campaign.active_entity_states:
			visual.queue_free()


func _remap_combat_participant_id(old_id: StringName, new_id: StringName) -> void:
	if old_id == new_id:
		return
	if _loot_participant_ids.has(old_id):
		_loot_participant_ids[new_id] = _loot_participant_ids[old_id]
		_loot_participant_ids.erase(old_id)
	for bucket in [_combat_turns_by_id, _previous_skill_targets, _damage_guards,
			_guard_reductions, _guard_expiry_turn_by_id, _next_attack_bonuses,
			_mother_attack_bonuses, _retaliation_by_enemy]:
		if bucket.has(old_id):
			bucket[new_id] = bucket[old_id]
			bucket.erase(old_id)
	for owner_id in _previous_skill_targets:
		if _previous_skill_targets[owner_id] == old_id:
			_previous_skill_targets[owner_id] = new_id
	for retaliations in _retaliation_by_enemy.values():
		if retaliations is Dictionary and retaliations.has(old_id):
			retaliations[new_id] = retaliations[old_id]
			retaliations.erase(old_id)


func _hide_dead_enemy(enemy: EntityState) -> void:
	if enemy_visual_root == null:
		return
	var visual := _visual_for_actor(enemy)
	if visual != null:
		visual.call("play_death")


func _sync_combat_view() -> void:
	if map_view == null or gerencia == null or not _combat_interaction_enabled:
		return
	map_view.set_occupied_coords(_occupied_positions(current_actor))
	map_view.set_active_actor(current_actor.position if current_actor != null \
		else EntityState.UNPLACED,
		current_actor.stamina_remaining if current_actor != null else 0)


func _clear_session() -> void:
	_loot_participant_ids.clear()
	_loot_entry_max_health = 0
	_loot_damage_taken = 0
	_loot_rolled = false
	_loot_items.clear()
	_loot_resolved_count = 0
	_loot_resolutions.clear()
	_promotion_cleanup_pending = false
	_pending_recruitment.clear()
	_recruitment_feedback_pending = false
	if _solo_actor != null and not _solo_restored \
			and not _exploration_snapshot.is_empty():
		_restore_exploration_turns()
	_attack_animation_pending = false
	for record in _next_attack_bonuses.values() + _mother_attack_bonuses.values():
		var buffed := record.get("actor") as EntityState
		if buffed != null:
			buffed.attack -= int(record.get("amount", 0))
	_next_attack_bonuses.clear()
	_mother_attack_bonuses.clear()
	_encounter_reveal_sources.clear()
	for penalty in _timed_attack_penalties:
		var target := penalty["target"] as EntityState
		if target != null:
			target.attack += int(penalty["amount"])
	_timed_attack_penalties.clear()
	_damage_guards.clear()
	_guard_reductions.clear()
	_guard_expiry_turn_by_id.clear()
	_selected_skill_grant = null
	if enemy_visual_root != null:
		for visual in enemy_visual_root.get_children():
			enemy_visual_root.remove_child(visual)
			visual.queue_free()
	enemies.clear()
	initiative_order.clear()
	current_encounter = null
	pending_conclusion.clear()
	current_actor = null
	combat_cycle = 0
	action_mode = &""
	_turn_index = -1
	_turn_die = 0
	_steps_moved = 0
	_attacks_used = 0
	_turn_moved = false
	_retaliation_by_enemy.clear()
	_pending_trap.clear()
	_previous_skill_targets.clear()
	_pending_attack_coord = EntityState.UNPLACED
	_combat_turns_by_id.clear()
	_encounter_automatic_skill_uses.clear()
	_exploration_snapshot.clear()
	_solo_actor = null
	_solo_restored = false
	_pending_event_reward = null
	_event_reward_claimed = false
	if map_view != null and _combat_interaction_enabled:
		map_view.selection_validator = _saved_selection_validator
		map_view.destination_validator = _saved_destination_validator
	_combat_interaction_enabled = false


## A regra de spawn acompanha a Skill, não nomes, tags ou Stamina base:
## Homem de Preto/Versão do Mal partem de zero mas recebem Stamina na abertura.
func _is_immobile_enemy(enemy_data: EntityData) -> bool:
	if enemy_data == null:
		return false
	for passive in enemy_data.skill_passivas:
		if passive == null:
			continue
		for effect in passive.effects + passive.on_granted_effects + passive.continuous_effects:
			if effect != null and effect.effect_type == SkillEffectData.EffectType.PREVENT_MOVEMENT:
				return true
	return false


func _has_encounter_stamina_rule(enemy_data: EntityData) -> bool:
	if enemy_data == null:
		return false
	for passive in enemy_data.skill_passivas:
		if passive == null:
			continue
		for effect in passive.effects:
			if effect == null:
				continue
			if effect.effect_type == SkillEffectData.EffectType.COPY_ATTRIBUTES_FROM_TARGET \
					and effect.attribute_ids.has(&"stamina"):
				return true
			if effect.effect_type == SkillEffectData.EffectType.SET_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT \
					and effect.attribute_id == &"stamina":
				return true
	return false


## Sorteio uniforme por hex livre em todo o mapa. Não ocupa outra entidade.
## Sobrepõe tanto o spawn do Encontro quanto o das colunas de invocação.
func _choose_immobile_spawn(grid: HexGrid, occupied: Dictionary) -> Vector2i:
	if grid == null:
		return EntityState.UNPLACED
	var free_cells: Array[Vector2i] = []
	for coord in grid.cells:
		if not occupied.has(coord):
			free_cells.append(coord)
	return free_cells[_rng.randi_range(0, free_cells.size() - 1)] \
		if not free_cells.is_empty() else EntityState.UNPLACED


func _choose_spawn(grid: HexGrid, activator: EntityState, occupied: Dictionary) -> Vector2i:
	if grid == null or activator == null:
		return EntityState.UNPLACED
	var others: Array[EntityState] = []
	for playable in _combat_playables():
		if playable != null and playable != activator and playable.current_health > 0 \
				and playable.position != EntityState.UNPLACED:
			others.append(playable)
	# Dois hexes são o MÍNIMO absoluto. Se a faixa está cheia, avançamos
	# para 3, 4, 5...; nunca recuamos para um hex adjacente.
	var max_radius := 2
	for coord in grid.cells:
		max_radius = maxi(max_radius, HexGrid.distance(activator.position, coord))
	for radius in range(2, max_radius + 1):
		var candidates: Array[Vector2i] = []
		var best_preference := -999
		for coord in grid.cells:
			if occupied.has(coord):
				continue
			var distance := HexGrid.distance(activator.position, coord)
			if distance != radius:
				continue
			# Margem positiva = ativador mais perto; zero = empate. Mesmo se
			# todas forem negativas, ainda usamos um hex livre desta faixa.
			var preference := 999
			for other in others:
				preference = mini(preference,
					HexGrid.distance(other.position, coord) - distance)
			if preference > best_preference:
				best_preference = preference
				candidates.clear()
			if preference == best_preference:
				candidates.append(coord)
		if not candidates.is_empty():
			return candidates[_rng.randi_range(0, candidates.size() - 1)]
	return EntityState.UNPLACED


func _draw_enemy(enemy: EntityState) -> void:
	if enemy_visual_root == null or map_view == null:
		return
	var visual := ENEMY_SILHOUETTE_SCRIPT.new() as Node2D
	visual.name = "Enemy_%s" % enemy.instance_id
	visual.call("bind_state", enemy)
	visual.position = PPPMapView.reference_hex_position(enemy.position)
	enemy_visual_root.add_child(visual)
	visual.body_clicked.connect(_on_enemy_body_clicked)


func _visual_for_actor(actor: EntityState) -> EnemySilhouetteVisual:
	if actor == null or enemy_visual_root == null:
		return null
	for child in enemy_visual_root.get_children():
		var visual := child as EnemySilhouetteVisual
		if visual != null and visual.state == actor:
			return visual
	return null


func get_enemies_under_pointer(screen_position: Vector2) -> Array[EntityState]:
	var under_pointer: Array[EntityState] = []
	if map_view == null:
		return under_pointer
	for enemy in enemies:
		if enemy == null or enemy.current_health <= 0:
			continue
		var center := map_view.get_hex_screen_position(enemy.position)
		if Rect2(center + Vector2(-35.0, -145.0), Vector2(70.0, 145.0)).has_point(screen_position):
			under_pointer.append(enemy)
	under_pointer.sort_custom(func(a: EntityState, b: EntityState) -> bool:
		return a.position.y > b.position.y)
	return under_pointer


func get_body_target_index(screen_position: Vector2, count: int) -> int:
	if count <= 0 or screen_position.distance_to(_last_enemy_click_position) > 8.0:
		return 0
	return _last_enemy_click_index % count


func _on_enemy_body_clicked(_clicked: EntityState, screen_position: Vector2) -> void:
	if map_view == null:
		return
	var under_pointer := get_enemies_under_pointer(screen_position)
	if under_pointer.is_empty():
		return
	if screen_position.distance_to(_last_enemy_click_position) > 8.0:
		_last_enemy_click_index = 0
	else:
		_last_enemy_click_index += 1
	_last_enemy_click_position = screen_position
	var selected := under_pointer[_last_enemy_click_index % under_pointer.size()]
	enemy_inspected.emit(selected)
	if is_player_turn():
		map_view.request_combat_selection(selected.position)


func _draw_silhouette_companions(campaign: CampaignState) -> void:
	if enemy_visual_root == null or map_view == null:
		return
	for companion in campaign.companion_states:
		if companion == null or companion.current_health <= 0 \
				or companion.position == EntityState.UNPLACED or companion.data == null \
				or companion.data.tags.has(&"gatinho_vira_lata") \
				or companion.data.tags.has(&"doguinho_caramelo"):
			continue
		if _visual_for_actor(companion) != null:
			continue
		var visual := ENEMY_SILHOUETTE_SCRIPT.new() as Node2D
		visual.name = "Ally_%s" % companion.instance_id
		visual.call("bind_state", companion, true)
		visual.position = PPPMapView.reference_hex_position(companion.position)
		enemy_visual_root.add_child(visual)


func _build_initiative(campaign: CampaignState) -> void:
	var participants: Array[EntityState] = []
	for playable in _combat_playables():
		if playable != null and playable.current_health > 0:
			participants.append(playable)
	for companion in _combat_companions():
		if companion != null and companion.current_health > 0 \
				and (companion.position != EntityState.UNPLACED \
				or _companion_is_fetching(companion, campaign)):
			participants.append(companion)
	participants.append_array(enemies)
	for participant in participants:
		initiative_order.append(_roll_initiative_entry(participant))
	initiative_order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["total"] != b["total"]:
			return a["total"] > b["total"]
		if a["tiebreak_stat_sum"] != b["tiebreak_stat_sum"]:
			return a["tiebreak_stat_sum"] > b["tiebreak_stat_sum"]
		var a_player := (a["entity"] as EntityState).controller == EntityState.Controller.PLAYER
		var b_player := (b["entity"] as EntityState).controller == EntityState.Controller.PLAYER
		if a_player != b_player:
			return a_player
		return a["registration_order"] < b["registration_order"]
	)


func _companion_is_fetching(companion: EntityState, campaign: CampaignState) -> bool:
	if companion == null or campaign == null:
		return false
	var owner := campaign.get_playable_slot(companion.owner_instance_id)
	return owner != null and owner.turn_serial < companion.unavailable_until_owner_turn_serial


func _roll_initiative_entry(participant: EntityState) -> Dictionary:
	var campaign := gerencia.campaign
	var x := mini(participant.attack, 6) if participant.controller == EntityState.Controller.AI \
		else participant.max_stamina
	var dice_total := 0
	for die in maxi(0, x):
		dice_total += campaign.enemy_dice_luck.roll_for_enemy(_rng) \
			if participant.controller == EntityState.Controller.AI \
			else campaign.player_dice_luck.roll_for_player(_rng)
	return {"entity": participant, "base": x, "dice_total": dice_total,
		"total": x + dice_total,
		"tiebreak_stat_sum": participant.max_stamina + participant.attack,
		"registration_order": initiative_order.size()}
