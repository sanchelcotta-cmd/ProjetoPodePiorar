class_name CompanionPartyView
extends Node2D

signal companion_visual_movement_started(actor: EntityState, duration: float)
signal companion_visual_movement_stopped(actor: EntityState)
signal attack_contact_frame(actor: EntityState, target: EntityState)

## Instancia o visual dos companheiros sem colocá-los nas vagas Playable_1/2/3.
const ACTOR_SCENE := preload("res://scenes/visuals/companion_actor_visual.tscn")
const DOLL_SCRIPT := preload("res://scripts/visuals/wooden_doll_visual.gd")
const IMAGINARY_SCRIPT := preload("res://scripts/visuals/event_follower_visual.gd")
const SILHOUETTE_SCRIPT := preload("res://scripts/visuals/enemy_silhouette_visual.gd")

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var skill_manager: SkillManager
@export var combat_manager: CombatManager

var visuals_by_id: Dictionary = {}
var ground_silhouettes_by_id: Dictionary = {}
var doll_visuals_by_owner_id: Dictionary = {}
var imaginary_visuals_by_owner_id: Dictionary = {}


func _ready() -> void:
	if gerencia != null:
		gerencia.campaign.temporary_event_changed.connect(_on_temporary_event_changed)
		gerencia.campaign.companion_registered.connect(_on_companion_registered)
		gerencia.campaign.wooden_doll_changed.connect(_on_wooden_doll_changed)
	if exploration != null:
		exploration.map_entered.connect(_on_map_entered)
		exploration.actor_moved.connect(_on_exploration_actor_moved)
		exploration.actor_teleported.connect(_on_exploration_actor_teleported)
	if skill_manager != null:
		skill_manager.active_skill_used.connect(_on_active_skill_used)
		skill_manager.delayed_skill_effect_resolved.connect(_on_delayed_effect_resolved)
	if combat_manager != null:
		combat_manager.action_resolved.connect(_on_combat_action_resolved)
		combat_manager.combat_prepared.connect(func(_encounter: EncounterData,
			_enemies: Array[EntityState], _initiative: Array[Dictionary]) -> void:
			_refresh())
		combat_manager.combat_finished.connect(func(_result: Dictionary) -> void:
			_refresh.call_deferred())
	_refresh()


func _on_temporary_event_changed() -> void:
	_refresh()


func _on_combat_action_resolved(actor: EntityState, action: StringName,
		details: Dictionary) -> void:
	if actor == null:
		return
	var visual := visuals_by_id.get(actor.instance_id) as CompanionActorVisual
	if visual == null:
		return
	if action in [&"attack", &"counterattack", &"attack_missed_reach", &"ricochet"]:
		visual.play_attack(details.get("target") as EntityState)
		return
	if action != &"move":
		return
	var path: Array[Vector2i] = []
	for coord in details.get("path", []):
		if coord is Vector2i:
			path.append(coord)
	visual.animate_combat_path(details.get("origin", actor.position), path)


func _on_map_entered(_map: HexGrid) -> void:
	_refresh()
	for visual in doll_visuals_by_owner_id.values():
		(visual as Node2D).call("reset_for_map")
	for visual in imaginary_visuals_by_owner_id.values():
		(visual as Node2D).call("reset_for_map")


func _on_wooden_doll_changed(_owner_id: StringName, _present: bool) -> void:
	_refresh_dolls()


func _on_exploration_actor_moved(actor: EntityState, path: Array[Vector2i],
		_stamina_spent: int) -> void:
	if actor == null:
		return
	var visual := doll_visuals_by_owner_id.get(actor.instance_id) as Node2D
	if visual != null:
		visual.call("follow_path", path)
	var imaginary_visual := imaginary_visuals_by_owner_id.get(actor.instance_id) as Node2D
	if imaginary_visual != null:
		imaginary_visual.call("follow_path", path)


func _on_exploration_actor_teleported(actor: EntityState, _destination: Vector2i) -> void:
	if actor == null:
		return
	var visual := doll_visuals_by_owner_id.get(actor.instance_id) as Node2D
	if visual != null:
		visual.call("reset_for_map")
	var imaginary_visual := imaginary_visuals_by_owner_id.get(actor.instance_id) as Node2D
	if imaginary_visual != null:
		imaginary_visual.call("reset_for_map")


func _on_companion_registered(companion: EntityState) -> void:
	if gerencia != null and gerencia.campaign.current_map != null:
		_refresh()


func _on_active_skill_used(actor: EntityState, grant: SkillGrantState,
		result: Dictionary) -> void:
	# Um ataque da ativa sem alcance não emite "attack"; ainda houve tentativa.
	var visual := visuals_by_id.get(actor.instance_id) as CompanionActorVisual \
		if actor != null else null
	if visual != null:
		for effect in result.get("effects", []):
			if effect is Dictionary and effect.get("missed_reach", false):
				visual.play_attack()
				break
	if actor == null or grant == null or grant.skill == null \
			or grant.skill.id != &"companion_active_002":
		return
	if visual != null:
		visual.start_fetching()


func _on_delayed_effect_resolved(_owner: EntityState, result: Dictionary) -> void:
	var visual := visuals_by_id.get(result.get("source_actor_id", -1)) as CompanionActorVisual
	if visual != null:
		visual.return_walking()


func _refresh() -> void:
	if gerencia == null or gerencia.campaign.current_map == null:
		return
	var still_present: Dictionary = {}
	for companion in gerencia.campaign.companion_states:
		still_present[companion.instance_id] = true
		_show_companion(companion)
	_refresh_ground_silhouettes(still_present)
	for id in visuals_by_id.keys():
		if not still_present.has(id):
			var old := visuals_by_id[id] as CompanionActorVisual
			if old != null:
				old.queue_free()
			visuals_by_id.erase(id)
	_refresh_dolls()
	_refresh_imaginary_friends()


func _refresh_dolls() -> void:
	if gerencia == null or gerencia.campaign.current_map == null:
		return
	var present: Dictionary = {}
	for owner in gerencia.campaign.active_entity_states:
		if not gerencia.campaign.has_wooden_doll(owner):
			continue
		present[owner.instance_id] = true
		var visual := doll_visuals_by_owner_id.get(owner.instance_id) as EventFollowerVisual
		if visual == null:
			visual = DOLL_SCRIPT.new() as EventFollowerVisual
			visual.name = "WoodenDoll_%s" % owner.instance_id
			add_child(visual)
			doll_visuals_by_owner_id[owner.instance_id] = visual
			visual.bind_owner(owner)
	for owner_id in doll_visuals_by_owner_id.keys():
		if not present.has(owner_id):
			var old := doll_visuals_by_owner_id[owner_id] as EventFollowerVisual
			doll_visuals_by_owner_id.erase(owner_id)
			if old != null:
				old.queue_free()


func _refresh_imaginary_friends() -> void:
	if gerencia == null or gerencia.campaign.current_map == null:
		return
	var present: Dictionary = {}
	for owner in gerencia.campaign.active_entity_states:
		if not gerencia.campaign.has_imaginary_friend(owner):
			continue
		present[owner.instance_id] = true
		var visual := imaginary_visuals_by_owner_id.get(owner.instance_id) \
			as EventFollowerVisual
		if visual == null:
			visual = IMAGINARY_SCRIPT.new() as EventFollowerVisual
			visual.name = "ImaginaryFriend_%s" % owner.instance_id
			add_child(visual)
			imaginary_visuals_by_owner_id[owner.instance_id] = visual
			visual.bind_owner(owner, true)
	for owner_id in imaginary_visuals_by_owner_id.keys():
		if not present.has(owner_id):
			var old := imaginary_visuals_by_owner_id[owner_id] as EventFollowerVisual
			imaginary_visuals_by_owner_id.erase(owner_id)
			if old != null:
				old.queue_free()


func _show_companion(companion: EntityState) -> void:
	if companion == null or companion.current_health <= 0:
		return
	if companion.data == null:
		return
	var mobile := _is_mobile_companion(companion)
	if not mobile and companion.get_animation_variant() == null \
			and companion.data.playable_animation == null:
		return
	var owner := gerencia.campaign.get_playable_slot(companion.owner_instance_id)
	if owner == null:
		return
	var visual := visuals_by_id.get(companion.instance_id) as CompanionActorVisual
	if visual == null:
		visual = ACTOR_SCENE.instantiate() as CompanionActorVisual
		visual.name = String(companion.instance_id)
		add_child(visual)
		visual.attack_contact_frame.connect(func(attacker: EntityState,
				target: EntityState) -> void:
			attack_contact_frame.emit(attacker, target))
		visual.visual_movement_started.connect(func(actor: EntityState,
				duration: float) -> void:
			companion_visual_movement_started.emit(actor, duration))
		visual.visual_movement_stopped.connect(func(actor: EntityState) -> void:
			companion_visual_movement_stopped.emit(actor))
		visuals_by_id[companion.instance_id] = visual
	var ground_position := Vector2.INF if mobile else \
		_ground_position_for(companion)
	visual.bind_companion(companion, owner, gerencia.campaign.current_map,
		ground_position)
	visual.visible = gerencia.campaign.current_map.ppp_map_mode == \
		HexGrid.PPPMapMode.EXPLORATION if not mobile else visual.visible
	if companion.temporarily_absent_from_map:
		visual.hide()


func _is_mobile_companion(companion: EntityState) -> bool:
	return companion.data != null and (companion.data.tags.has(&"gatinho_vira_lata") \
		or companion.data.tags.has(&"doguinho_caramelo"))


func _ground_position_for(companion: EntityState) -> Vector2:
	var index := 0
	for candidate in gerencia.campaign.companion_states:
		if candidate == companion:
			break
		if candidate != null and candidate.current_health > 0 \
				and not _is_mobile_companion(candidate):
			index += 1
	# Faixa livre à esquerda da primeira coluna de hexes, apenas visual.
	return Vector2(-150.0 + float(index % 2) * 76.0,
		PPPMapView.reference_hex_position(Vector2i(0, 4)).y + 24.0 \
		- float(index / 2) * 132.0)


func _refresh_ground_silhouettes(still_present: Dictionary) -> void:
	var exploration_mode := gerencia.campaign.current_map.ppp_map_mode == \
		HexGrid.PPPMapMode.EXPLORATION
	for companion in gerencia.campaign.companion_states:
		if companion == null or companion.current_health <= 0 or companion.data == null \
				or _is_mobile_companion(companion) \
				or companion.get_animation_variant() != null \
				or companion.data.playable_animation != null:
			continue
		var visual := ground_silhouettes_by_id.get(companion.instance_id) \
			as EnemySilhouetteVisual
		if visual == null:
			visual = SILHOUETTE_SCRIPT.new() as EnemySilhouetteVisual
			visual.name = "GroundAlly_%s" % companion.instance_id
			add_child(visual)
			ground_silhouettes_by_id[companion.instance_id] = visual
		visual.bind_state(companion, true)
		visual.position = _ground_position_for(companion)
		visual.visible = exploration_mode and not companion.temporarily_absent_from_map
	for id in ground_silhouettes_by_id.keys():
		var old := ground_silhouettes_by_id[id] as EnemySilhouetteVisual
		if not still_present.has(id):
			ground_silhouettes_by_id.erase(id)
			if old != null:
				old.queue_free()
		elif old != null:
			var actor := old.state as EntityState
			if actor == null or actor.current_health <= 0:
				old.hide()
