class_name GameActionSFX
extends Node

## Ponte única entre resoluções reais e a folha de SFX. Nunca escuta hover,
## escolha de hex ou UI. Alterações de posição são adiadas um frame para que
## a ação possa informar o tamanho do caminho sem duplicar o som.
const SHEET_PATH := "res://audio/sfx/movimentos_de_acao_1.mp3"
const HURT_SHEET_PATH := "res://audio/sfx/hurt_hurt.wav"
const ATTACK_GAIN_MULTIPLIER := 1.5
@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var combat_manager: CombatManager
@export var skill_manager: SkillManager
@export var companion_view: CompanionPartyView
@export var playable_view: PlayablePartyView

var _sheet: AudioStream
var _hurt_sheet: AudioStream
var _known: Dictionary = {} # instance ID do objeto -> EntityState
var _queued_moves: Dictionary = {}
var _movement_voices: Dictionary = {}
var _attack_voices: Array[Dictionary] = []
var _hurt_voices: Array[Dictionary] = []
var _idle_players: Array[AudioStreamPlayer] = []
var _pending_hits: Dictionary = {}
var _death_echoes: Array[Dictionary] = []
var _delayed_hurts: Array[Dictionary] = []
var _last_mode := -1
var _attack_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sheet = load(SHEET_PATH) as AudioStream
	_hurt_sheet = load(HURT_SHEET_PATH) as AudioStream
	if _sheet == null:
		push_error("GameActionSFX: folha de SFX ausente: %s" % SHEET_PATH)
	if _hurt_sheet == null:
		push_error("GameActionSFX: folha de gritos ausente: %s" % HURT_SHEET_PATH)
	if gerencia != null:
		gerencia.map_generated.connect(_on_map_generated)
		gerencia.campaign.companion_registered.connect(func(_companion: EntityState) -> void:
			_sync_entities())
		gerencia.campaign.playable_slot_replaced.connect(func(_old: EntityState,
				_new: EntityState) -> void: _sync_entities())
	if exploration != null:
		exploration.actor_moved.connect(_on_exploration_move)
		exploration.actor_teleported.connect(_on_exploration_teleport)
	if combat_manager != null:
		combat_manager.action_resolved.connect(_on_combat_action)
		combat_manager.hit_prepared.connect(_on_hit_prepared)
		combat_manager.combat_prepared.connect(func(_encounter: EncounterData,
				_enemies: Array[EntityState], _initiative: Array[Dictionary]) -> void:
			_stop_all()
			_sync_entities())
		combat_manager.enemy_summoned.connect(func(_enemy: EntityState,
				_summoner: EntityState, _acts_immediately: bool) -> void:
			_sync_entities())
		combat_manager.combat_finished.connect(func(_result: Dictionary) -> void:
			_stop_all())
	if skill_manager != null:
		skill_manager.passive_triggered.connect(_on_passive_triggered)
		skill_manager.active_skill_used.connect(_on_active_skill_used)
	if companion_view != null:
		companion_view.attack_contact_frame.connect(_on_attack_contact_frame)
		companion_view.companion_visual_movement_started.connect(
			_on_companion_visual_movement_started)
		companion_view.companion_visual_movement_stopped.connect(
			_on_companion_visual_movement_stopped)
	if playable_view != null:
		playable_view.attack_contact_frame.connect(_on_attack_contact_frame)
		playable_view.projectile_arrived.connect(_on_projectile_arrived)
	_sync_entities()


func _exit_tree() -> void:
	_stop_all()
	for player in _idle_players:
		if is_instance_valid(player):
			player.queue_free()
	_idle_players.clear()
	for actor in _known.values():
		_unbind(actor as EntityState)
	_known.clear()


func _process(delta: float) -> void:
	if not _has_playable_map() or get_tree().paused:
		_stop_all()
		return
	var mode := int(gerencia.campaign.current_map.ppp_map_mode)
	if _last_mode != -1 and mode != _last_mode:
		_stop_all()
	_last_mode = mode
	for pending in _queued_moves.values():
		var actor := pending.get("actor") as EntityState
		if actor != null and actor.current_health > 0:
			_start_movement(actor, int(pending.get("steps", 1)),
				float(pending.get("duration", 0.0)))
	_queued_moves.clear()
	_update_movement(delta)
	_update_attacks()
	_update_hurts(delta)


func _has_playable_map() -> bool:
	return gerencia != null and gerencia.campaign != null \
		and gerencia.campaign.current_map != null \
		and not gerencia.campaign.is_terminal()


func _on_map_generated(_map: HexGrid) -> void:
	_stop_all()
	_sync_entities()


func _sync_entities() -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	var current: Dictionary = {}
	for actor in gerencia.campaign.active_entity_states + gerencia.campaign.companion_states:
		if actor != null:
			current[actor.get_instance_id()] = actor
	if combat_manager != null:
		for actor in combat_manager.enemies:
			if actor != null:
				current[actor.get_instance_id()] = actor
	for key in _known.keys():
		if current.has(key):
			continue
		_unbind(_known[key] as EntityState)
		_stop_movement(int(key))
		_known.erase(key)
	for key in current:
		if _known.has(key):
			continue
		var actor := current[key] as EntityState
		_known[key] = actor
		actor.position_changed.connect(_on_position_changed.bind(actor))
		actor.health_changed.connect(_on_health_changed.bind(actor))


func _unbind(actor: EntityState) -> void:
	if actor == null:
		return
	var position_callback := Callable(self, "_on_position_changed").bind(actor)
	var health_callback := Callable(self, "_on_health_changed").bind(actor)
	if actor.position_changed.is_connected(position_callback):
		actor.position_changed.disconnect(position_callback)
	if actor.health_changed.is_connected(health_callback):
		actor.health_changed.disconnect(health_callback)


func _on_position_changed(previous: Vector2i, current: Vector2i,
		actor: EntityState) -> void:
	if not _has_playable_map() or previous == EntityState.UNPLACED \
			or current == EntityState.UNPLACED or actor.current_health <= 0:
		return
	var grid := gerencia.campaign.current_map
	if grid.is_valid(previous) and grid.is_valid(current):
		_queue_movement(actor, maxi(1, HexGrid.distance(previous, current)))


func _on_health_changed(_old: int, current: int, actor: EntityState) -> void:
	if current <= 0:
		_stop_movement(actor.get_instance_id())
		_queued_moves.erase(actor.get_instance_id())


func _queue_movement(actor: EntityState, steps: int,
		duration: float = 0.0) -> void:
	if actor == null or steps <= 0:
		return
	var key := actor.get_instance_id()
	var previous: Dictionary = _queued_moves.get(key, {})
	_queued_moves[key] = {"actor": actor,
		"steps": maxi(steps, int(previous.get("steps", 0))),
		"duration": maxf(duration, float(previous.get("duration", 0.0)))}


func _on_companion_visual_movement_started(actor: EntityState,
		duration: float) -> void:
	_queue_movement(actor, 1, duration)


func _on_companion_visual_movement_stopped(actor: EntityState) -> void:
	if actor == null:
		return
	var key := actor.get_instance_id()
	_queued_moves.erase(key)
	_stop_movement(key)


func _on_exploration_move(actor: EntityState, path: Array[Vector2i],
		_cost: int) -> void:
	_queue_movement(actor, maxi(1, path.size()))


func _on_exploration_teleport(actor: EntityState, _destination: Vector2i) -> void:
	# Teleporte também altera posição de mapa. Som genérico curto se nenhum
	# caminho foi emitido; a mesma ação não dispara duas vezes.
	_queue_movement(actor, 1)


func _on_combat_action(actor: EntityState, action: StringName,
		details: Dictionary) -> void:
	_sync_entities()
	if action == &"move":
		_queue_movement(actor, maxi(1, (details.get("path", []) as Array).size()))
	elif action in [&"attack", &"counterattack", &"attack_missed_reach",
			&"ricochet"]:
		var target := details.get("target") as EntityState
		var damaged := target != null and (int(details.get("damage", 0)) > 0
			or bool(details.get("survived_lethal_hit", false)))
		var ranged := bool(details.get("ranged", false))
		if action == &"ricochet":
			ranged = true
		_play_attack(actor, target if damaged else null, ranged)
		var pending: Dictionary = _pending_hits.get(target.get_instance_id(), {}) \
			if damaged else {}
		if not pending.is_empty():
			pending["actor"] = actor
			pending["details"] = details
			pending["generic_projectile"] = ranged \
				and (not _has_playable_projectile(actor, action)
					or not _has_attack_animation(actor))
			pending["projectile_launched"] = false
		var actor_visual := _visual_for(actor)
		if actor_visual is EnemySilhouetteVisual and action != &"ricochet":
			var silhouette := actor_visual as EnemySilhouetteVisual
			if not silhouette.attack_contact_frame.is_connected(_on_attack_contact_frame):
				silhouette.attack_contact_frame.connect(_on_attack_contact_frame)
			silhouette.play_attack(target)
		if target != null and not damaged:
			_cancel_hit(target)
		elif damaged and action == &"ricochet":
			_launch_generic_projectile(actor, target, details)
		elif damaged and not _has_attack_animation(actor):
			# Defensivo para entidades sem visual vinculado ao mapa.
			# O agendamento pertence a esta cena: encerrar a partida cancela
			# o callback e libera as referências ao atacante e ao alvo.
			var fallback := create_tween()
			fallback.tween_interval(0.16)
			fallback.tween_callback(func() -> void:
				if is_inside_tree():
					_on_attack_contact_frame(actor, target))


func _on_hit_prepared(target: EntityState) -> void:
	for visual in _visuals_for(target):
		if visual.has_method("hold_combat_hit"):
			visual.call("hold_combat_hit")


func _on_attack_contact_frame(_attacker: EntityState,
		target: EntityState) -> void:
	var pending: Dictionary = _pending_hits.get(target.get_instance_id(), {}) \
		if target != null else {}
	if pending.is_empty():
		return
	if bool(pending.get("ranged", false)):
		if bool(pending.get("generic_projectile", false)) \
				and not bool(pending.get("projectile_launched", false)):
			pending["projectile_launched"] = true
			_launch_generic_projectile(pending.get("actor") as EntityState,
				target, pending.get("details", {}) as Dictionary)
	else:
		_present_hit(target)


func _on_projectile_arrived(_attacker: EntityState,
		target: EntityState) -> void:
	_present_hit(target)


func _visual_for(target: EntityState) -> Node:
	var visuals := _visuals_for(target)
	for visual in visuals:
		if visual is PlayableActorVisual or visual is CompanionActorVisual:
			return visual
	return visuals[0] if not visuals.is_empty() else null


func _visuals_for(target: EntityState) -> Array[Node]:
	var result: Array[Node] = []
	if target == null:
		return result
	for candidate in get_tree().get_nodes_in_group("map_entity_visual"):
		if candidate.get("state") == target:
			result.append(candidate)
	return result


func _cancel_hit(target: EntityState) -> void:
	if target == null:
		return
	_pending_hits.erase(target.get_instance_id())
	for visual in _visuals_for(target):
		if visual.has_method("cancel_combat_hit"):
			visual.call("cancel_combat_hit")


func _present_hit(target: EntityState) -> void:
	if target == null or not _pending_hits.has(target.get_instance_id()):
		return
	var pending: Dictionary = _pending_hits[target.get_instance_id()]
	if bool(pending.get("presented", false)):
		return
	pending["presented"] = true
	for visual in _visuals_for(target):
		if visual.has_method("present_combat_hit"):
			visual.call("present_combat_hit")
	if bool(pending.get("ranged", false)):
		_play_hurt(target)
		_pending_hits.erase(target.get_instance_id())
	elif bool(pending.get("attack_sound_finished", false)):
		_play_hurt(target)
		_pending_hits.erase(target.get_instance_id())


func _on_passive_triggered(actor: EntityState, grant: SkillGrantState,
		result: Dictionary) -> void:
	if actor == null or grant == null or not _has_playable_map():
		return
	var source := grant.bound_source as ItemData
	if source != null and source.id == &"aa_00004":
		for effect in result.get("effects", []):
			if effect is Dictionary and effect.get("dodged", false):
				_play_attack(actor) # Bumerangue interceptou de fato.
				return
	if grant.skill is PassiveSkillData:
		for effect in (grant.skill as PassiveSkillData).effects:
			if effect.effect_type != SkillEffectData.EffectType.DEAL_FIXED_DAMAGE:
				continue
			for applied in result.get("effects", []):
				if applied is Dictionary and not applied.get("targets", []).is_empty():
					_play_attack(actor) # Uma vez por resolução, não por alvo.
					if not _attack_voices.is_empty():
						var hurt_targets: Array[EntityState] = []
						for hit in applied.get("targets", []):
							if not hit is Dictionary:
								continue
							var victim := hit.get("target") as EntityState
							var outcome: Dictionary = hit.get("damage", {}) \
								if hit.get("damage", {}) is Dictionary else {}
							if victim != null and (int(outcome.get("damage", 0)) > 0
									or bool(outcome.get("survived_lethal_hit", false))) \
									and victim not in hurt_targets:
								hurt_targets.append(victim)
						_attack_voices[-1]["hurt_targets"] = hurt_targets
					return


func _on_active_skill_used(actor: EntityState, _grant: SkillGrantState,
		result: Dictionary) -> void:
	# Ataques bem-sucedidos já passam por CombatManager._resolve_attack. A
	# tentativa efetivamente gasta mas sem alcance não passa: cobrir aqui.
	for effect in result.get("effects", []):
		if effect is Dictionary and effect.get("missed_reach", false):
			_play_attack(actor)
			return


func _start_movement(actor: EntityState, steps: int,
		duration: float = 0.0) -> void:
	if _sheet == null:
		return
	var key := actor.get_instance_id()
	_stop_movement(key)
	var spec := ActionSFXCatalog.movement(actor)
	var player := _new_player(&"GeneralSFX", float(spec["gain"]))
	player.pitch_scale = float(spec["pitch"])
	player.play(float(spec["start"]))
	_movement_voices[key] = {"player": player, "spec": spec,
		"remaining": maxf(0.36,
			duration if duration > 0.0 else float(steps) * 0.22)}


func _has_playable_projectile(actor: EntityState,
		action: StringName) -> bool:
	if actor == null or actor.data == null or action == &"ricochet" \
			or playable_view == null or not (&"jogavel" in actor.data.tags):
		return false
	var equipped := actor.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	if equipped == null or equipped.data == null:
		return false
	if actor.temporary_appearance == &"chicken_form":
		return equipped.data.mastery_granted == EntityData.Mastery.RANGED
	return equipped.data.id in [
		&"aa_00002", &"aa_00004", &"aa_00009", &"aa_00010"]


func _has_attack_animation(actor: EntityState) -> bool:
	var visual := _visual_for(actor)
	if visual == null or not visual.has_signal("attack_contact_frame") \
			or bool(visual.get("_dying")):
		return false
	if visual is CompanionActorVisual:
		var companion := visual as CompanionActorVisual
		return companion.sprite.sprite_frames != null \
			and companion.sprite.sprite_frames.has_animation(&"attack")
	return true


func _launch_generic_projectile(actor: EntityState, target: EntityState,
		details: Dictionary) -> void:
	if combat_manager == null or combat_manager.enemy_visual_root == null:
		_present_hit(target)
		return
	var source := details.get("source_target") as EntityState
	if source == null:
		source = actor
	if source == null or source.position == EntityState.UNPLACED \
			or target.position == EntityState.UNPLACED:
		_present_hit(target)
		return
	var bolt := Line2D.new()
	bolt.name = "CombatProjectile"
	bolt.width = 4.0
	bolt.default_color = Color(0.08, 0.93, 1.0)
	bolt.points = PackedVector2Array([Vector2(-11.0, 0.0), Vector2(11.0, 0.0)])
	bolt.z_index = 8
	combat_manager.enemy_visual_root.add_child(bolt)
	var origin := PPPMapView.reference_hex_position(source.position) + Vector2(0.0, -45.0)
	var destination := PPPMapView.reference_hex_position(target.position) + Vector2(0.0, -45.0)
	bolt.position = origin
	bolt.rotation = (destination - origin).angle()
	var flight := bolt.create_tween()
	flight.tween_property(bolt, "position", destination, 0.40)
	flight.finished.connect(func() -> void:
		bolt.queue_free()
		_present_hit(target))


func _play_attack(actor: EntityState, target: EntityState = null,
		ranged: bool = false) -> void:
	if _sheet == null or not _has_playable_map() or get_tree().paused:
		_cancel_hit(target)
		return
	_attack_serial += 1
	var spec := ActionSFXCatalog.attack(actor, _attack_serial)
	var player := _new_player(&"CombatSFX",
		float(spec["gain"]) * ATTACK_GAIN_MULTIPLIER)
	player.pitch_scale = float(spec["pitch"])
	player.play(float(spec["start"]))
	_attack_voices.append({"player": player, "end": float(spec["end"]),
		"target": target, "ranged": ranged})
	if target != null:
		_pending_hits[target.get_instance_id()] = {"target": target,
			"ranged": ranged, "presented": false,
			"attack_sound_finished": false}


func _new_player(bus_name: StringName, gain: float,
		stream_override: AudioStream = null) -> AudioStreamPlayer:
	var source := stream_override if stream_override != null else _sheet
	var player: AudioStreamPlayer
	for index in range(_idle_players.size() - 1, -1, -1):
		if _idle_players[index].stream == source:
			player = _idle_players[index]
			_idle_players.remove_at(index)
			break
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = source
		add_child(player)
	player.bus = bus_name
	player.volume_linear = gain
	player.pitch_scale = 1.0
	return player


func _recycle_player(player: AudioStreamPlayer) -> void:
	if not is_instance_valid(player):
		return
	player.stop()
	if _idle_players.size() < 16 and not player in _idle_players:
		_idle_players.append(player)
	else:
		player.queue_free()


func _update_movement(delta: float) -> void:
	for key in _movement_voices.keys():
		var entry: Dictionary = _movement_voices[key]
		var player := entry["player"] as AudioStreamPlayer
		var spec: Dictionary = entry["spec"]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0 or player == null:
			_stop_movement(int(key))
		elif player.get_playback_position() >= float(spec["end"]) or not player.playing:
			player.play(float(spec["start"]))


func _update_attacks() -> void:
	for index in range(_attack_voices.size() - 1, -1, -1):
		var entry := _attack_voices[index]
		var player := entry["player"] as AudioStreamPlayer
		if player != null and player.playing \
				and player.get_playback_position() < float(entry["end"]):
			continue
		if player != null:
			_recycle_player(player)
		_attack_voices.remove_at(index)
		for victim in entry.get("hurt_targets", []):
			if victim is EntityState:
				_play_hurt(victim as EntityState)
		var target := entry.get("target") as EntityState
		if target == null or bool(entry.get("ranged", false)) \
				or not _pending_hits.has(target.get_instance_id()):
			continue
		var pending: Dictionary = _pending_hits[target.get_instance_id()]
		pending["attack_sound_finished"] = true
		if bool(pending.get("presented", false)):
			_play_hurt(target)
			_pending_hits.erase(target.get_instance_id())


func _play_hurt(target: EntityState) -> void:
	if _hurt_sheet == null or target == null:
		return
	if target.current_health <= 0:
		_delayed_hurts.append({"target": target, "remaining": 0.12})
	else:
		_start_hurt_segment(target)


func _start_hurt_segment(target: EntityState, echo: bool = false) -> void:
	var spec := HurtSFXCatalog.for_actor(target)
	if spec.is_empty():
		return
	var player := _new_player(&"CombatSFX",
		float(spec["gain"]) * (0.28 if echo else 1.0), _hurt_sheet)
	player.pitch_scale = float(spec["pitch"]) * (0.92 if echo else 1.0)
	player.play(float(spec["start"]))
	_hurt_voices.append({"player": player, "end": float(spec["end"])})
	if not echo and target.current_health <= 0:
		_death_echoes.append({"target": target, "remaining": 0.13})


func _update_hurts(delta: float) -> void:
	for index in range(_delayed_hurts.size() - 1, -1, -1):
		_delayed_hurts[index]["remaining"] = \
			float(_delayed_hurts[index]["remaining"]) - delta
		if float(_delayed_hurts[index]["remaining"]) <= 0.0:
			_start_hurt_segment(_delayed_hurts[index]["target"] as EntityState)
			_delayed_hurts.remove_at(index)
	for index in range(_death_echoes.size() - 1, -1, -1):
		_death_echoes[index]["remaining"] = \
			float(_death_echoes[index]["remaining"]) - delta
		if float(_death_echoes[index]["remaining"]) <= 0.0:
			_start_hurt_segment(_death_echoes[index]["target"] as EntityState, true)
			_death_echoes.remove_at(index)
	for index in range(_hurt_voices.size() - 1, -1, -1):
		var entry := _hurt_voices[index]
		var player := entry.get("player") as AudioStreamPlayer
		if player != null and player.playing \
				and player.get_playback_position() < float(entry["end"]):
			continue
		if player != null:
			_recycle_player(player)
		_hurt_voices.remove_at(index)


func _stop_movement(key: int) -> void:
	if not _movement_voices.has(key):
		return
	var player := _movement_voices[key].get("player") as AudioStreamPlayer
	if player != null:
		_recycle_player(player)
	_movement_voices.erase(key)


func _stop_all() -> void:
	for pending in _pending_hits.values():
		_cancel_hit(pending.get("target") as EntityState)
	_pending_hits.clear()
	_delayed_hurts.clear()
	_death_echoes.clear()
	_queued_moves.clear()
	for key in _movement_voices.keys():
		_stop_movement(int(key))
	for entry in _attack_voices:
		var player := entry.get("player") as AudioStreamPlayer
		if player != null:
			_recycle_player(player)
	_attack_voices.clear()
	for entry in _hurt_voices:
		var player := entry.get("player") as AudioStreamPlayer
		if player != null:
			_recycle_player(player)
	_hurt_voices.clear()
