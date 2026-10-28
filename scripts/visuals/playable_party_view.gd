class_name PlayablePartyView
extends Node2D

signal attack_contact_frame(actor: EntityState, target: EntityState)
signal projectile_arrived(actor: EntityState, target: EntityState)

## Mostra as três VAGAS da campanha. Os personagens escolhidos vêm dos
## EntityState; esta cena não grava nem escolhe EntityData por conta própria.
const ACTOR_SCENE := preload("res://scenes/visuals/playable_actor_visual.tscn")
const MAP_CHARACTER_SCALE := 1.70 # Pedreiro ~155 px; porta do cenário ~145 px.

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var combat_manager: CombatManager
@export var skill_manager: SkillManager

var visuals_by_slot: Dictionary = {}


func _ready() -> void:
	if exploration == null:
		return
	if gerencia != null:
		gerencia.campaign.temporary_event_changed.connect(_refresh_temporary_events)
		gerencia.campaign.playable_slot_replaced.connect(_on_slot_replaced)
	exploration.map_entered.connect(_on_map_entered)
	exploration.actor_moved.connect(_on_actor_moved)
	exploration.actor_teleported.connect(_on_actor_teleported)
	exploration.turn_started.connect(_on_turn_started)
	exploration.turn_finished.connect(_on_turn_finished)
	if combat_manager != null:
		combat_manager.action_resolved.connect(_on_combat_action_resolved)
	if skill_manager != null:
		skill_manager.passive_triggered.connect(_on_passive_triggered)


func _on_slot_replaced(previous: EntityState, replacement: EntityState) -> void:
	if previous != null and previous != replacement and previous.current_health <= 0 \
			and combat_manager != null and combat_manager.current_encounter != null:
		_finish_death_before_rebind.call_deferred()
		return
	_on_map_entered(gerencia.campaign.current_map)


func _finish_death_before_rebind() -> void:
	# Não interromper DeathBlink ao vincular a nova instância à vaga visual.
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree() and gerencia != null:
		_on_map_entered(gerencia.campaign.current_map)


func _on_map_entered(_map: HexGrid) -> void:
	if gerencia == null:
		return
	for state in gerencia.campaign.active_entity_states:
		var actor := visuals_by_slot.get(state.playable_slot_id) as PlayableActorVisual
		if actor == null:
			actor = ACTOR_SCENE.instantiate() as PlayableActorVisual
			actor.name = String(state.playable_slot_id)
			add_child(actor)
			actor.attack_contact_frame.connect(func(attacker: EntityState,
					target: EntityState) -> void:
				attack_contact_frame.emit(attacker, target))
			actor.projectile_arrived.connect(func(attacker: EntityState,
					target: EntityState) -> void:
				projectile_arrived.emit(attacker, target))
			actor.bind_state(state)
			actor.set_visual_scale(MAP_CHARACTER_SCALE)
			visuals_by_slot[state.playable_slot_id] = actor
		elif actor.state != state:
			actor.bind_state(state)
		actor.reset_at(state.position)
	_on_turn_started(exploration.current_actor)
	_refresh_temporary_events()


func _refresh_temporary_events() -> void:
	for visual in visuals_by_slot.values():
		if visual is PlayableActorVisual:
			(visual as PlayableActorVisual).refresh_temporary_visual()


func _on_actor_moved(actor: EntityState, path: Array[Vector2i], _cost: int) -> void:
	var visual := visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	if visual != null:
		visual.animate_path(path)


func _on_actor_teleported(actor: EntityState, destination: Vector2i) -> void:
	var visual := visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	if visual != null:
		visual.reset_at(destination)


func _on_combat_action_resolved(actor: EntityState, action: StringName,
		details: Dictionary) -> void:
	if actor == null:
		return
	var visual := visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	if visual == null:
		return
	if action in [&"attack", &"counterattack", &"attack_missed_reach"]:
		var equipped := actor.primary_equipped(ItemData.EquipmentSlot.WEAPON)
		var weapon: ItemData = equipped.data if equipped != null else null
		visual.play_attack(weapon, details.get("target") as EntityState,
			action != &"attack_missed_reach",
			StringName(details.get("dagger_aspect", &"")))
		return
	if action != &"move":
		return
	var path: Array[Vector2i] = []
	path.assign(details.get("path", []))
	visual.reset_at(details.get("origin", actor.position))
	visual.animate_path(path)


func _on_passive_triggered(actor: EntityState, grant: SkillGrantState,
		result: Dictionary) -> void:
	if actor == null or grant == null:
		return
	var source := grant.bound_source as ItemData
	if source == null or source.id != &"aa_00004":
		return
	var intercepted := false
	for effect in result.get("effects", []):
		if effect is Dictionary and effect.get("dodged", false):
			intercepted = true
			break
	if not intercepted:
		return
	var visual := visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	if visual != null:
		visual.play_boomerang_interception(source,
			result.get("damage_source") as EntityState)


func _on_turn_started(actor: EntityState) -> void:
	for slot in visuals_by_slot:
		var visual := visuals_by_slot[slot] as PlayableActorVisual
		var inactive := visual.state != null and (visual.state.turn_state \
			== EntityState.TurnState.INACTIVE or visual.state.current_health <= 0)
		visual.modulate = Color.WHITE
		visual.set_active_marker(not inactive and actor != null and visual.state == actor)


func _on_turn_finished(_actor: EntityState) -> void:
	_on_turn_started(exploration.current_actor)
