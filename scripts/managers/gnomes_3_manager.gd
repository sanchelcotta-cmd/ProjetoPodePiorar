class_name Gnomes3Manager
extends Node

## Regra personalizada SOMENTE do evento Gnomos do Caos 3. O EventData guarda
## quais são os cinco efeitos; este nó escolhe os hexes e embaralha as cores.
## Nenhum hex de Informação é substituído, inclusive o bloco livre que virou
## Informação. No modo visual de teste, eventos não são ativados.
const COLOR_RESOURCES := [
	preload("res://resources/events/random_events/gnomes_3/duende_cor_1.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_2.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_3.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_4.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_5.tres"),
]

@export var gerencia: GerenciaJogo
@export var block_manager: BlockManager
@export var exploration: ExplorationManager
@export var combat_manager: CombatManager

var _rng := RandomNumberGenerator.new()
var _spawned_map: HexGrid
var _generated_paths: Array[String] = []
var _activated_count: int = 0


func _ready() -> void:
	_rng.randomize()
	if block_manager != null:
		block_manager.event_resolution_requested.connect(_on_event_requested)
		block_manager.block_finished.connect(_on_block_finished)
	if exploration != null:
		exploration.actor_will_arrive.connect(_on_actor_will_arrive)
	if combat_manager != null:
		combat_manager.combat_prepared.connect(_on_combat_prepared)
		combat_manager.combat_finished.connect(_on_combat_finished)


func _on_actor_will_arrive(_actor: EntityState, destination: Vector2i) -> void:
	if _spawned_map == null or _spawned_map != gerencia.campaign.current_map:
		return
	var cell := _spawned_map.get_cell(destination)
	if cell == null or cell.resource_path not in _generated_paths \
			or cell.map_visual_path.is_empty():
		return
	var marker := gerencia.map_view._special_event_visuals.get_node_or_null(
		"Event_%d_%d" % [destination.x, destination.y])
	if marker != null and marker.get_child_count() > 0:
		var sprite := marker.get_child(0) as AnimatedSprite2D
		if sprite != null:
			var puff := create_tween().set_parallel(true)
			puff.tween_property(sprite, "modulate:a", 0.0, 0.14)
			puff.tween_property(sprite, "scale", Vector2(1.28, 1.28), 0.14)
			puff.chain().tween_callback(marker.hide)
	_spawned_map.set_ppp_map_visual(destination, null)


func _on_combat_prepared(_encounter: EncounterData, _enemies: Array[EntityState],
		_initiative: Array[Dictionary]) -> void:
	if gerencia != null and gerencia.map_view != null:
		gerencia.map_view.refresh_special_event_visuals()


func _on_combat_finished(_result: Dictionary) -> void:
	if _spawned_map == null or gerencia == null \
			or gerencia.campaign.current_map != _spawned_map:
		return
	var occupied: Dictionary = {}
	for member in gerencia.campaign.active_entity_states:
		if member != null and member.current_health > 0:
			occupied[member.position] = true
	for coord in _spawned_map.cells:
		var cell := _spawned_map.get_cell(coord)
		if cell == null or cell.resource_path not in _generated_paths \
				or cell.map_visual_path.is_empty() or not occupied.has(coord):
			continue
		var destination := _nearest_relocation(coord, occupied)
		if destination != EntityState.UNPLACED:
			_swap_blocks(coord, destination)
		else:
			# Sem um hex alternativo seguro, ao menos não deixar o sprite
			# sobreposto ao jogável que retornou do Encontro.
			_spawned_map.set_ppp_map_visual(coord, null)
	if gerencia.map_view != null:
		gerencia.map_view._refresh_feedback()
		gerencia.map_view.refresh_special_event_visuals()


func _nearest_relocation(origin: Vector2i, occupied: Dictionary) -> Vector2i:
	var nearest := 999
	var ties: Array[Vector2i] = []
	for coord in _spawned_map.cells:
		var cell := _spawned_map.get_cell(coord)
		if cell == null or cell.block_type == HexGrid.PPPBlockType.INFORMATION \
				or cell.resource_path in _generated_paths or occupied.has(coord):
			continue
		var distance := HexGrid.distance(origin, coord)
		if distance < nearest:
			nearest = distance
			ties.clear()
		if distance == nearest:
			ties.append(coord)
	return ties[_rng.randi_range(0, ties.size() - 1)] \
		if not ties.is_empty() else EntityState.UNPLACED


func _swap_blocks(a: Vector2i, b: Vector2i) -> void:
	var first := _spawned_map.get_ppp_block_data(a)
	var second := _spawned_map.get_ppp_block_data(b)
	var first_reveal: Array = _spawned_map.revealed_by_skill_ids.get(a, []).duplicate()
	var second_reveal: Array = _spawned_map.revealed_by_skill_ids.get(b, []).duplicate()
	_set_block_data(a, second, second_reveal)
	_set_block_data(b, first, first_reveal)


func _set_block_data(coord: Vector2i, data: Dictionary, revealers: Array) -> void:
	var cell := _spawned_map.get_cell(coord)
	cell.block_type = data["block_type"]
	cell.resource_path = data["resource_path"]
	cell.map_visual_path = data["map_visual_path"]
	cell.generated_from_random_block = data["generated_from_random_block"]
	cell.state = data["state"]
	cell.movement_blocked = data["movement_blocked"]
	if revealers.is_empty():
		_spawned_map.revealed_by_skill_ids.erase(coord)
	else:
		_spawned_map.revealed_by_skill_ids[coord] = revealers


func _on_event_requested(context: Dictionary) -> void:
	var event := context.get("resource") as EventData
	if event == null or event.custom_rule != &"spawn_gnomes_3" \
			or gerencia == null or not EventCampaignEligibility.allows_event(event,
				gerencia.campaign.campaign_mode):
		return
	var grid := context.get("map") as HexGrid
	if grid == null or block_manager == null:
		return
	var source: Vector2i = context.get("coord", Vector2i(-1, -1))
	var available: Array[Vector2i] = []
	for coord in grid.cells:
		if coord == source:
			continue
		var cell := grid.get_cell(coord)
		if cell == null or cell.state != HexGrid.PPPBlockState.HIDDEN \
				or cell.block_type == HexGrid.PPPBlockType.INFORMATION \
				or grid.get_ppp_block_resource(coord) is Informacao \
				or _occupied_by_entity(coord):
			continue
		available.append(coord)
	_shuffle(available)
	var generated: Array[EventData] = []
	# Recursos colocados por outro Evento seguem a política da campanha.
	for child in event.generated_events:
		if EventCampaignEligibility.allows_event(child,
				gerencia.campaign.campaign_mode):
			generated.append(child)
	_shuffle(generated)
	var colors: Array = COLOR_RESOURCES.duplicate()
	_shuffle(colors)
	_spawned_map = grid
	_generated_paths.clear()
	_activated_count = 0
	var count := mini(available.size(), mini(generated.size(), colors.size()))
	for index in count:
		var produced := generated[index]
		var coord := available[index]
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, produced)
		grid.set_ppp_map_visual(coord, colors[index] as SpriteSheetAnimationData)
		_generated_paths.append(produced.resource_path)
	if gerencia != null and gerencia.map_view != null \
			and gerencia.map_view.grid == grid:
		gerencia.map_view.refresh_special_event_visuals()
	block_manager.finish_event_resolution({"gnomes_spawned": count})


func _on_block_finished(result: Dictionary) -> void:
	if result.get("map") != _spawned_map or _activated_count >= 3:
		return
	var event := result.get("resource") as EventData
	if event == null or event.resource_path not in _generated_paths:
		return
	if result.get("completion_kind") != BlockManager.CompletionKind.EVENT_RESOLVED:
		return
	_activated_count += 1
	if _activated_count < 3:
		return
	# Ao terceiro duende resolvido, os outros somem sem ativar seus efeitos.
	for coord in _spawned_map.cells:
		var cell := _spawned_map.get_cell(coord)
		if cell != null and cell.resource_path in _generated_paths \
				and cell.state in [HexGrid.PPPBlockState.HIDDEN,
					HexGrid.PPPBlockState.REVEALED]:
			_spawned_map.destroy_ppp_block(coord)
			_spawned_map.set_ppp_map_visual(coord, null)
	if gerencia != null and gerencia.map_view != null \
			and gerencia.map_view.grid == _spawned_map:
		gerencia.map_view.refresh_special_event_visuals()


func _occupied_by_entity(coord: Vector2i) -> bool:
	if gerencia == null:
		return false
	for entity in gerencia.campaign.active_entity_states:
		if entity.current_health > 0 and entity.position == coord:
			return true
	for companion in gerencia.campaign.companion_states:
		if companion.current_health > 0 and companion.position == coord:
			return true
	return false


func _shuffle(values: Array) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var stored = values[index]
		values[index] = values[other]
		values[other] = stored
