class_name PlayablePartyView
extends Node2D

## Mostra as três VAGAS da campanha. Os personagens escolhidos vêm dos
## EntityState; esta cena não grava nem escolhe EntityData por conta própria.
const ACTOR_SCENE := preload("res://scenes/visuals/playable_actor_visual.tscn")
const MAP_CHARACTER_SCALE := 1.70 # Pedreiro ~155 px; porta do cenário ~145 px.

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var combat_manager: CombatManager

var visuals_by_slot: Dictionary = {}


func _ready() -> void:
	if exploration == null:
		return
	if gerencia != null:
		gerencia.campaign.temporary_event_changed.connect(_refresh_temporary_events)
		gerencia.campaign.playable_slot_replaced.connect(func(_previous: EntityState,
				_replacement: EntityState) -> void:
			_on_map_entered(gerencia.campaign.current_map))
	exploration.map_entered.connect(_on_map_entered)
	exploration.actor_moved.connect(_on_actor_moved)
	exploration.actor_teleported.connect(_on_actor_teleported)
	exploration.turn_started.connect(_on_turn_started)
	exploration.turn_finished.connect(_on_turn_finished)
	if combat_manager != null:
		combat_manager.action_resolved.connect(_on_combat_action_resolved)


func _on_map_entered(_map: HexGrid) -> void:
	if gerencia == null:
		return
	for state in gerencia.campaign.active_entity_states:
		var actor := visuals_by_slot.get(state.playable_slot_id) as PlayableActorVisual
		if actor == null:
			actor = ACTOR_SCENE.instantiate() as PlayableActorVisual
			actor.name = String(state.playable_slot_id)
			add_child(actor)
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
	if action != &"move" or actor == null:
		return
	var visual := visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	if visual == null:
		return
	var path: Array[Vector2i] = []
	path.assign(details.get("path", []))
	visual.reset_at(details.get("origin", actor.position))
	visual.animate_path(path)


func _on_turn_started(actor: EntityState) -> void:
	for slot in visuals_by_slot:
		var visual := visuals_by_slot[slot] as PlayableActorVisual
		var inactive := visual.state != null and (visual.state.turn_state \
			== EntityState.TurnState.INACTIVE or visual.state.current_health <= 0)
		visual.modulate = Color.WHITE
		visual.set_active_marker(not inactive and actor != null and visual.state == actor)


func _on_turn_finished(_actor: EntityState) -> void:
	_on_turn_started(exploration.current_actor)
