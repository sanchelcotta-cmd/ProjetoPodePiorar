class_name CompanionPartyView
extends Node2D

## Instancia o visual dos companheiros sem colocá-los nas vagas Playable_1/2/3.
const ACTOR_SCENE := preload("res://scenes/visuals/companion_actor_visual.tscn")
const DOLL_SCRIPT := preload("res://scripts/visuals/wooden_doll_visual.gd")

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var skill_manager: SkillManager
@export var combat_manager: CombatManager

var visuals_by_id: Dictionary = {}
var doll_visuals_by_owner_id: Dictionary = {}


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
	_refresh()


func _on_temporary_event_changed() -> void:
	for companion in gerencia.campaign.companion_states:
		var visual := visuals_by_id.get(companion.instance_id) as CompanionActorVisual
		if visual == null:
			continue
		if companion.temporarily_absent_from_map:
			visual.hide()
		else:
			_show_companion(companion)


func _on_combat_action_resolved(actor: EntityState, action: StringName,
		details: Dictionary) -> void:
	if action != &"move" or actor == null:
		return
	var visual := visuals_by_id.get(actor.instance_id) as CompanionActorVisual
	if visual == null:
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


func _on_wooden_doll_changed(_owner_id: StringName, _present: bool) -> void:
	_refresh_dolls()


func _on_exploration_actor_moved(actor: EntityState, path: Array[Vector2i],
		_stamina_spent: int) -> void:
	if actor == null:
		return
	var visual := doll_visuals_by_owner_id.get(actor.instance_id) as Node2D
	if visual != null:
		visual.call("follow_path", path)


func _on_exploration_actor_teleported(actor: EntityState, _destination: Vector2i) -> void:
	if actor == null:
		return
	var visual := doll_visuals_by_owner_id.get(actor.instance_id) as Node2D
	if visual != null:
		visual.call("reset_for_map")


func _on_companion_registered(companion: EntityState) -> void:
	if gerencia != null and gerencia.campaign.current_map != null:
		_show_companion(companion)


func _on_active_skill_used(actor: EntityState, grant: SkillGrantState,
		_result: Dictionary) -> void:
	if actor == null or grant == null or grant.skill == null \
			or grant.skill.id != &"companion_active_002":
		return
	var visual := visuals_by_id.get(actor.instance_id) as CompanionActorVisual
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
	for id in visuals_by_id.keys():
		if not still_present.has(id):
			var old := visuals_by_id[id] as CompanionActorVisual
			if old != null:
				old.queue_free()
			visuals_by_id.erase(id)
	_refresh_dolls()


func _refresh_dolls() -> void:
	if gerencia == null or gerencia.campaign.current_map == null:
		return
	var present: Dictionary = {}
	for owner in gerencia.campaign.active_entity_states:
		if not gerencia.campaign.has_wooden_doll(owner):
			continue
		present[owner.instance_id] = true
		var visual := doll_visuals_by_owner_id.get(owner.instance_id) as EnemySilhouetteVisual
		if visual == null:
			visual = DOLL_SCRIPT.new() as EnemySilhouetteVisual
			visual.name = "WoodenDoll_%s" % owner.instance_id
			add_child(visual)
			doll_visuals_by_owner_id[owner.instance_id] = visual
			visual.call("bind_owner", owner)
	for owner_id in doll_visuals_by_owner_id.keys():
		if not present.has(owner_id):
			var old := doll_visuals_by_owner_id[owner_id] as EnemySilhouetteVisual
			doll_visuals_by_owner_id.erase(owner_id)
			if old != null:
				old.queue_free()


func _show_companion(companion: EntityState) -> void:
	if companion == null or companion.current_health <= 0:
		return
	# Humanos aliados participam da party, mas na Exploração não ocupam nem
	# desenham um hex. Só Gatinho e Doguinho passeiam sobre o ground.
	if companion.data == null or (not companion.data.tags.has(&"gatinho_vira_lata")
			and not companion.data.tags.has(&"doguinho_caramelo")):
		return
	var owner := gerencia.campaign.get_playable_slot(companion.owner_instance_id)
	if owner == null:
		return
	var visual := visuals_by_id.get(companion.instance_id) as CompanionActorVisual
	if visual == null:
		visual = ACTOR_SCENE.instantiate() as CompanionActorVisual
		visual.name = String(companion.instance_id)
		add_child(visual)
		visuals_by_id[companion.instance_id] = visual
	visual.bind_companion(companion, owner, gerencia.campaign.current_map)
	if companion.temporarily_absent_from_map:
		visual.hide()
