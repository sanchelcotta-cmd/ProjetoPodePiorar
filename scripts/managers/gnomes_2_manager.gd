class_name Gnomes2Manager
extends Node

## Evento 08: três máscaras visuais. Nunca substituem o conteúdo do hex,
## não recebem clique e desaparecem na virada de Manhã/Tarde/Noite.

const GNOME_COUNT := 3
const COLORS := [
	preload("res://resources/events/random_events/gnomes_3/duende_cor_1.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_2.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_3.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_4.tres"),
	preload("res://resources/events/random_events/gnomes_3/duende_cor_5.tres"),
]

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var combat_manager: CombatManager
@export var visual_root: Node2D

var active := false
var _round_index := -1
var _information_chance := 60
var _rng := RandomNumberGenerator.new()
var positions: Array[Vector2i] = []
# A cor visual também é um resultado sorteado e deve sobreviver ao carregamento.
var color_paths: Array[String] = []


func _ready() -> void:
	_rng.randomize()
	if exploration != null:
		exploration.cycle_started.connect(_on_cycle_started)
		exploration.actor_will_arrive.connect(_on_actor_will_arrive)
	if gerencia != null:
		gerencia.map_generated.connect(_on_map_generated)
	if combat_manager != null:
		combat_manager.combat_prepared.connect(_on_combat_prepared)
		combat_manager.combat_finished.connect(_on_combat_finished)


func start_effect() -> Dictionary:
	if gerencia == null or gerencia.campaign.current_map == null:
		return {"success": false, "reason": "Mapa indisponível para os gnomos."}
	active = true
	_round_index = gerencia.campaign.get_round_index()
	_information_chance = 60
	_reposition()
	return {"success": true, "gnomes_spawned": positions.size(),
		"information_chance_next": _information_chance}


func stop_effect() -> void:
	active = false
	_round_index = -1
	positions.clear()
	color_paths.clear()
	_clear_visuals()


func _on_cycle_started(_cycle: int) -> void:
	if not active:
		return
	if gerencia.campaign.get_round_index() != _round_index:
		stop_effect()
	else:
		_reposition()


func _on_map_generated(_map: HexGrid) -> void:
	if not active:
		return
	if gerencia.campaign.get_round_index() != _round_index:
		stop_effect()
	else:
		_reposition()


func _on_actor_will_arrive(_actor: EntityState, destination: Vector2i) -> void:
	if not active or destination not in positions or visual_root == null:
		return
	positions.erase(destination)
	var sprite: AnimatedSprite2D = null
	for candidate in visual_root.get_children():
		if candidate is AnimatedSprite2D and candidate.get_meta("gnome_hex", EntityState.UNPLACED) == destination:
			sprite = candidate as AnimatedSprite2D
			break
	if sprite != null:
		var vanish := create_tween().set_parallel(true)
		var comfort := get_node_or_null("/root/VisualComfort")
		var reduced := comfort != null and bool(comfort.get("enabled"))
		vanish.tween_property(sprite, "modulate:a", 0.0, 0.35 if reduced else 0.14)
		if not reduced:
			vanish.tween_property(sprite, "scale", Vector2(1.28, 1.28), 0.14)
		vanish.chain().tween_callback(sprite.queue_free)


func _on_combat_prepared(_encounter: EncounterData, _enemies: Array[EntityState],
		_initiative: Array[Dictionary]) -> void:
	if visual_root != null:
		visual_root.hide()


func _on_combat_finished(_result: Dictionary) -> void:
	if visual_root == null:
		return
	if not active or gerencia.campaign.get_round_index() != _round_index:
		stop_effect()
		visual_root.show()
		return
	var occupied: Dictionary = {}
	for member in gerencia.campaign.active_entity_states:
		if member != null and member.current_health > 0:
			occupied[member.position] = true
	for index in range(positions.size() - 1, -1, -1):
		if occupied.has(positions[index]):
			var replacement := _nearest_available(positions[index], occupied)
			if replacement == EntityState.UNPLACED:
				positions.remove_at(index)
				if index < color_paths.size():
					color_paths.remove_at(index)
			else:
				positions[index] = replacement
	_clear_visuals()
	_draw_visuals()
	visual_root.show()


func _nearest_available(origin: Vector2i, occupied: Dictionary) -> Vector2i:
	var grid := gerencia.campaign.current_map
	var nearest := 999
	var ties: Array[Vector2i] = []
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED] or cell.block_type not in [
				HexGrid.PPPBlockType.INFORMATION, HexGrid.PPPBlockType.ENCOUNTER] \
				or occupied.has(coord) or coord in positions:
			continue
		var distance := HexGrid.distance(origin, coord)
		if distance < nearest:
			nearest = distance
			ties.clear()
		if distance == nearest:
			ties.append(coord)
	return ties[_rng.randi_range(0, ties.size() - 1)] \
		if not ties.is_empty() else EntityState.UNPLACED


func _reposition() -> void:
	positions.clear()
	color_paths.clear()
	_clear_visuals()
	if not active or gerencia == null or gerencia.campaign.current_map == null:
		return
	var grid := gerencia.campaign.current_map
	var information: Array[Vector2i] = []
	var encounters: Array[Vector2i] = []
	var occupied: Dictionary = {}
	for member in gerencia.campaign.active_entity_states:
		if member != null and member.current_health > 0:
			occupied[member.position] = true
	for companion in gerencia.campaign.companion_states:
		if companion != null and companion.current_health > 0 \
				and grid.is_valid(companion.position):
			occupied[companion.position] = true
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED] or occupied.has(coord):
			continue
		if cell.block_type == HexGrid.PPPBlockType.INFORMATION:
			information.append(coord)
		elif cell.block_type == HexGrid.PPPBlockType.ENCOUNTER:
			encounters.append(coord)
	for _index in GNOME_COUNT:
		if information.is_empty() and encounters.is_empty():
			break
		var choose_information := _rng.randi_range(1, 100) <= _information_chance
		var pool := information if choose_information else encounters
		if pool.is_empty():
			pool = encounters if choose_information else information
		var coord: Vector2i = pool[_rng.randi_range(0, pool.size() - 1)]
		pool.erase(coord)
		positions.append(coord)
		if grid.get_ppp_block_type(coord) == HexGrid.PPPBlockType.INFORMATION:
			_information_chance = 20
		else:
			_information_chance = mini(60, _information_chance + 10)
	_draw_visuals()


func _draw_visuals() -> void:
	if visual_root == null or gerencia == null or gerencia.map_view == null:
		return
	if color_paths.size() != positions.size():
		color_paths.clear()
		var colors: Array = COLORS.duplicate()
		for index in range(colors.size() - 1, 0, -1):
			var other := _rng.randi_range(0, index)
			var selected: Variant = colors[index]
			colors[index] = colors[other]
			colors[other] = selected
		for index in positions.size():
			color_paths.append((colors[index] as SpriteSheetAnimationData).resource_path)
	for index in positions.size():
		var animation := load(color_paths[index]) as SpriteSheetAnimationData
		if animation == null:
			continue
		var sprite := AnimatedSprite2D.new()
		sprite.name = "Gnome_%d" % index
		sprite.sprite_frames = animation.create_sprite_frames()
		sprite.set_meta("gnome_hex", positions[index])
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = gerencia.map_view.reference_hex_position(positions[index]) \
			+ Vector2(0, -float(animation.canvas_size.y) * 0.5)
		# AnimatedSprite2D não tem captura de clique. O hex sob ele continua
		# sendo a única área interativa; hover é observado separadamente.
		visual_root.add_child(sprite)
		if sprite.sprite_frames.has_animation(&"idle"):
			sprite.play(&"idle")


func _clear_visuals() -> void:
	if visual_root == null:
		return
	for child in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()
