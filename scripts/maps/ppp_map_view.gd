class_name PPPMapView
extends Node2D

signal destination_requested(coord: Vector2i)
signal hex_choice_requested(coord: Vector2i)
signal hex_inspection_requested(coord: Vector2i)
signal hex_revealed(coord: Vector2i)
signal future_vision_hex_requested(coord: Vector2i)
signal ground_pressed(screen_position: Vector2)

## Desenha o mapa PPP usando as medidas da cena modelo_de_referencia.tscn.
## PontoZero continua sendo o CENTRO do hex (0, 0). As distâncias abaixo são
## apenas visuais: o caminho lógico ainda custa 1 Stamina por vizinho.
const GROUND_TEXTURE = preload("res://sprites/map/ground.png")
const HEX_TEXTURE = preload("res://sprites/map/hex-ref.png")
const PREVIEW_BACKGROUND = preload("res://sprites/background/cena_baixocentro_0001.png")
const GLOW_RADIUS_FACTOR := 1.24
const REFERENCE_VIEWPORT := Vector2(1152.0, 648.0)
const MAP_VERTICAL_NUDGE := 22.0 # Mesmo a primeira linha fica inteira sobre o asfalto.
const REFERENCE_COLUMN_STEP := 93.0 # média 92,96; arredondada para cima
const REFERENCE_ROW_STEP := 55.0 # média 54,82; arredondada para cima
const REFERENCE_ODD_ROW_OFFSET := 47.0
const GROUND_SCALE := Vector2(0.30751634, 0.30040884)
const GROUND_REPEAT_STEP := 440.0 # média 439,05 entre os 3 centros do modelo
const GROUND_BOTTOM_MARGIN := -2.0 # 2 px além da tela: nunca mostra a faixa cinza.
const GROUND_BACKGROUND_OVERLAP := 2.0 # O asfalto cobre a base dos prédios por 2 px.
const BACKGROUND_SCALE := Vector2(0.65061156, 0.61110663)
const BACKGROUND_SIDE_BLEED := 32.0 # Fachadas começam/terminam fora da câmera.

@export_range(0, 999) var preview_stamina: int = 3
@export var hex_palette: HexPalette

@onready var _ponto_zero: Node2D = get_node_or_null("PontoZero") as Node2D
@onready var _parallax: PPPParallaxBackground = get_node_or_null("ParallaxBackground") as PPPParallaxBackground
@onready var _map_root: Node2D = $MapRoot
@onready var _background: Sprite2D = $MapRoot/Background
@onready var _ground: Node2D = $MapRoot/Ground
@onready var _start_zone: Node2D = $MapRoot/StartZone
@onready var _hexes: Node2D = $MapRoot/Hexes
@onready var depth_layer: PPPDepthLayer = $MapRoot/DepthSorted
@onready var _special_event_visuals: Node2D = $MapRoot/DepthSorted/SpecialEventVisuals

var grid := HexGrid.new()
var _renderer: HexRenderer
var _actor_coord := Vector2i(-1, 2)
var _unlimited_destinations := false
var _flying_destinations := false
var _selected_coord := Vector2i(-999, -999)
var _occupied_coords: Dictionary = {}
var _retired_start_coords: Dictionary = {}
var _temporary_inspection_coords: Dictionary = {}
var _temporary_inspection_owner_id: StringName = &""
var _future_vision_actor: EntityState
var _emergency_destination := Vector2i(-999, -999)
var _active_hex_pulse := 0.0
var _background_bottom_row_cache: Dictionary = {}
var _background_horizontal_bounds_cache: Dictionary = {}
# A regra de destino pertence à Exploração (inclusive Debuffs), não à arte.
# Sem validador, a cena de prévia continua funcionando sozinha no editor.
var destination_validator: Callable = Callable()
var selection_validator: Callable = Callable()


func _ready() -> void:
	if grid.cells.is_empty():
		grid.generate_ppp_exploration_map()
	get_viewport().size_changed.connect(_rebuild_visuals)
	_rebuild_visuals()
	if _parallax != null:
		_parallax.show_generated_map(grid)


func _rebuild_visuals() -> void:
	_clear_nodes(_ground)
	_clear_nodes(_start_zone)
	_clear_nodes(_hexes)
	var screen_size := get_viewport_rect().size
	if _ponto_zero != null:
		# PontoZero vem da cena modelo. A janela proporcional amplia todas as
		# camadas juntas; aqui só centralizamos o grid e mantemos seu pé no chão.
		_map_root.position = _ponto_zero.position + Vector2(
			(screen_size.x - REFERENCE_VIEWPORT.x) * 0.5,
			screen_size.y - REFERENCE_VIEWPORT.y + MAP_VERTICAL_NUDGE
		)
	else:
		var bounds := _reference_map_bounds()
		_map_root.position = Vector2(
			(screen_size.x - bounds.size.x) * 0.5 - bounds.position.x,
			screen_size.y - GROUND_BOTTOM_MARGIN - bounds.end.y + MAP_VERTICAL_NUDGE
		)
	_layout_background(screen_size)
	_layout_ground(screen_size)
	_renderer = HexRenderer.new(hex_palette if hex_palette != null else HexPalette.new())
	_renderer.cell_pressed.connect(_on_cell_pressed)
	for coord in grid.cells:
		_renderer.create_hex_visual(_hexes, coord, reference_hex_position(coord))
	for start_coord in grid.get_ppp_start_positions():
		if _retired_start_coords.has(start_coord):
			continue
		var marker := Sprite2D.new()
		marker.name = "Start_%d" % start_coord.y
		marker.texture = HEX_TEXTURE
		marker.scale = HexRenderer.REFERENCE_SPRITE_SCALE
		marker.position = reference_hex_position(start_coord)
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_start_zone.add_child(marker)
	_refresh_feedback()
	refresh_special_event_visuals()


func _process(delta: float) -> void:
	# Realce lento do chão sob o personagem ativo, sem apagar o hex.
	_active_hex_pulse += delta
	var brightness := (sin(_active_hex_pulse * 1.8) + 1.0) * 0.5
	var color := Color(1.0, lerpf(0.85, 0.96, brightness),
		lerpf(0.34, 0.59, brightness), 1.0)
	if grid.is_valid(_actor_coord):
		var area := _hexes.get_node_or_null("Hex_%d_%d" % [_actor_coord.x,
			_actor_coord.y]) as Area2D
		if area != null:
			area.modulate = color
	elif grid.is_ppp_start_zone(_actor_coord):
		var marker := _start_zone.get_node_or_null("Start_%d" % _actor_coord.y) as Sprite2D
		if marker != null:
			marker.modulate = color


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or not event.double_click:
		return
	# O segundo clique na área livre do mapa apenas recolhe janelas; não
	# seleciona outro hex nem confirma uma ação de combate.
	if get_viewport().gui_get_hovered_control() != null:
		return
	var activation := get_node_or_null("BlockActivationPopup")
	if activation != null and activation.overlay.visible:
		return
	var hud := get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	if hud != null:
		hud.close_expandable_boxes()
	var top_bar := get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar != null:
		top_bar.close_expandable_boxes()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or event.double_click \
			or grid.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION:
		return
	var point: Vector2 = (event as InputEventMouseButton).position
	if get_viewport().gui_get_hovered_control() != null \
			or point.y < get_ground_screen_top() or _point_over_hex(point):
		return
	# Entidades com Area2D (inclusive inimigos futuros) têm prioridade sobre o chão.
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_viewport().get_canvas_transform().affine_inverse() * point
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_point(query, 32):
		var collider := hit.get("collider") as Area2D
		if collider != null and collider.name == "BodyClickArea":
			return
	ground_pressed.emit(point)


func get_ground_screen_top() -> float:
	return get_viewport_rect().size.y - GROUND_BOTTOM_MARGIN \
		- float(GROUND_TEXTURE.get_height()) * GROUND_SCALE.y


func _point_over_hex(screen_point: Vector2) -> bool:
	for area in _hexes.get_children():
		if not area is Area2D:
			continue
		var collision := area.get_child(0) as CollisionPolygon2D
		if collision != null and Geometry2D.is_point_in_polygon(
				area.get_global_transform_with_canvas().affine_inverse() * screen_point,
				collision.polygon):
			return true
	return false


func get_clickable_hex_at_screen_position(screen_point: Vector2) -> Vector2i:
	var nearest := EntityState.UNPLACED
	var nearest_distance := INF
	for area in _hexes.get_children():
		if not area is Area2D or not area.input_pickable:
			continue
		var collision := area.get_child(0) as CollisionPolygon2D
		if collision != null and Geometry2D.is_point_in_polygon(
				area.get_global_transform_with_canvas().affine_inverse() * screen_point,
				collision.polygon):
			var coord_text := area.name.trim_prefix("Hex_")
			var coord := Vector2i(int(coord_text.get_slice("_", 0)),
				int(coord_text.get_slice("_", 1)))
			var distance: float = area.get_global_transform_with_canvas().origin.distance_squared_to(
				screen_point)
			if distance < nearest_distance:
				nearest = coord
				nearest_distance = distance
	return nearest


static func reference_hex_position(coord: Vector2i) -> Vector2:
	return Vector2(
		coord.x * REFERENCE_COLUMN_STEP + (coord.y & 1) * REFERENCE_ODD_ROW_OFFSET,
		coord.y * REFERENCE_ROW_STEP
	)


func get_hex_screen_position(coord: Vector2i) -> Vector2:
	var area := _hexes.get_node_or_null("Hex_%d_%d" % [coord.x, coord.y]) as Node2D
	return area.get_global_transform_with_canvas().origin if area != null else Vector2.ZERO


func _reference_map_bounds() -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for coord in grid.cells:
		var point := reference_hex_position(coord)
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	for coord in grid.get_ppp_start_positions():
		var point := reference_hex_position(coord)
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	var margin := Vector2(HEX_TEXTURE.get_size()) * HexRenderer.REFERENCE_SPRITE_SCALE \
		* 0.5 * GLOW_RADIUS_FACTOR
	return Rect2(min_point - margin, max_point - min_point + margin * 2.0)


func _layout_background(screen_size: Vector2) -> void:
	var path := grid.ppp_background_path
	if path.is_empty():
		_background.texture = PREVIEW_BACKGROUND
	else:
		_background.texture = load(path) as Texture2D
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _background.texture == null:
		return
	# O PNG suburbio_0003 é mais estreito que os demais. Medir o trecho
	# VISÍVEL perto da base evita deixar céu aberto nas bordas, inclusive
	# quando outro distrito ou tamanho de janela for sorteado.
	var horizontal := _visible_facade_horizontal_bounds(_background.texture)
	var visible_width := float(horizontal.y - horizontal.x + 1)
	var scale_x := maxf(BACKGROUND_SCALE.x,
		(screen_size.x + BACKGROUND_SIDE_BLEED * 2.0) / visible_width)
	_background.scale = Vector2(scale_x, BACKGROUND_SCALE.y)
	var visible_center := (float(horizontal.x + horizontal.y + 1) * 0.5) \
		- float(_background.texture.get_width()) * 0.5
	_background.position.x = screen_size.x * 0.5 - _map_root.position.x \
		- visible_center * scale_x
	# Cada PNG deixa uma margem transparente diferente sob as casas. Alinhar
	# a borda do arquivo criaria uma fresta; alinhamos a base VISÍVEL da arte.
	var bottom_row := _visible_background_bottom_row(_background.texture)
	if bottom_row < 0:
		return
	var ground_top := screen_size.y - GROUND_BOTTOM_MARGIN \
		- float(GROUND_TEXTURE.get_height()) * GROUND_SCALE.y
	var visible_bottom_from_center := (float(bottom_row + 1) \
		- float(_background.texture.get_height()) * 0.5) * BACKGROUND_SCALE.y
	_background.position.y = ground_top + GROUND_BACKGROUND_OVERLAP \
		- _map_root.position.y - visible_bottom_from_center


func _visible_facade_horizontal_bounds(texture: Texture2D) -> Vector2i:
	var key := texture.resource_path
	if _background_horizontal_bounds_cache.has(key):
		return _background_horizontal_bounds_cache[key]
	var picture := texture.get_image()
	if picture == null:
		return Vector2i(0, texture.get_width() - 1)
	var bottom := _visible_background_bottom_row(texture)
	if bottom < 0:
		return Vector2i(0, texture.get_width() - 1)
	var top := maxi(0, bottom - maxi(12, int(picture.get_height() / 8)))
	var left := picture.get_width()
	var right := -1
	for x in picture.get_width():
		for y in range(bottom, top - 1, -2):
			if picture.get_pixel(x, y).a >= 0.8:
				left = mini(left, x)
				right = maxi(right, x)
				break
	var result := Vector2i(left, right) if right >= left else \
		Vector2i(0, picture.get_width() - 1)
	_background_horizontal_bounds_cache[key] = result
	return result


func _visible_background_bottom_row(texture: Texture2D) -> int:
	var key := texture.resource_path
	if _background_bottom_row_cache.has(key):
		return int(_background_bottom_row_cache[key])
	var picture := texture.get_image()
	if picture == null:
		return -1
	# Amostras ao longo de toda a largura evitam que um pontinho isolado ou
	# uma casa mais baixa esconda uma fresta sob as outras casas.
	var lowest_common_row := picture.get_height()
	for sample in range(1, 20):
		var x := roundi(float(sample) * float(picture.get_width() - 1) / 20.0)
		for y in range(picture.get_height() - 1, -1, -1):
			if picture.get_pixel(x, y).a >= 0.8:
				lowest_common_row = mini(lowest_common_row, y)
				break
	var result := lowest_common_row if lowest_common_row < picture.get_height() else -1
	_background_bottom_row_cache[key] = result
	return result


func _layout_ground(screen_size: Vector2) -> void:
	# Três cópias bastam na tela de referência. Em telas mais largas, cria
	# quantas forem necessárias. O chão ocupa só a faixa inferior: não vira
	# um fundo esticado sobre a cidade ou sobre o futuro céu.
	_ground.position = -_map_root.position
	var tile_width := float(GROUND_TEXTURE.get_width()) * GROUND_SCALE.x
	var tile_height := float(GROUND_TEXTURE.get_height()) * GROUND_SCALE.y
	var center_y := screen_size.y - GROUND_BOTTOM_MARGIN - tile_height * 0.5
	var center_x := tile_width * 0.5
	var index := 0
	while center_x - tile_width * 0.5 < screen_size.x:
		var tile := Sprite2D.new()
		tile.name = "Ground_%d" % index
		tile.texture = GROUND_TEXTURE
		tile.scale = GROUND_SCALE
		tile.position = Vector2(center_x, center_y)
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_ground.add_child(tile)
		center_x += GROUND_REPEAT_STEP
		index += 1


func _refresh_feedback() -> void:
	if not _renderer:
		return
	var reachable := grid.get_ppp_reachable_hexes(_actor_coord, preview_stamina)
	if grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION \
			and grid.is_valid(_emergency_destination):
		reachable[_emergency_destination] = HexGrid.distance(
			_actor_coord, _emergency_destination)
	if _unlimited_destinations and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION:
		for coord in grid.cells:
			if grid.can_choose_ppp_destination(coord, _actor_coord, _occupied_coords):
				reachable[coord] = 0
	elif _flying_destinations and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION:
		for coord in grid.cells:
			var distance := HexGrid.distance(_actor_coord, coord)
			if distance <= preview_stamina and grid.can_choose_ppp_destination(
					coord, _actor_coord, _occupied_coords):
				reachable[coord] = distance
	var destinations := grid.get_ppp_available_destinations(reachable, _actor_coord, _occupied_coords)
	_filter_destinations(destinations)
	var inspection_coords := _temporary_inspection_coords.duplicate()
	if _future_vision_actor != null:
		for coord in grid.cells:
			var cell := grid.get_cell(coord)
			if cell != null and cell.state == HexGrid.PPPBlockState.HIDDEN \
					and cell.block_type != HexGrid.PPPBlockType.NONE:
				inspection_coords[coord] = true
	_renderer.update_ppp_feedback(_hexes, grid, destinations, _selected_coord,
		_actor_coord, inspection_coords)
	for start_coord in grid.get_ppp_start_positions():
		var marker := _start_zone.get_node_or_null("Start_%d" % start_coord.y) as Sprite2D
		if marker != null:
			marker.modulate = _renderer.get_active_color() if start_coord == _actor_coord \
				else Color.WHITE


## Mesmo fluxo para clicar no hex ou no corpo visual do inimigo.
func preview_combat_destination(coord: Vector2i) -> void:
	if grid.ppp_map_mode != HexGrid.PPPMapMode.COMBAT or not grid.is_valid(coord) \
			or _selected_coord == coord:
		return
	_selected_coord = coord
	_refresh_feedback()


func request_combat_selection(coord: Vector2i) -> void:
	if grid.ppp_map_mode != HexGrid.PPPMapMode.COMBAT or not grid.is_valid(coord):
		return
	if selection_validator.is_valid() and not selection_validator.call(coord):
		return
	_selected_coord = coord
	_refresh_feedback()
	hex_choice_requested.emit(coord)


func _on_cell_pressed(coord: Vector2i, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event is InputEventMouseButton and event.double_click:
		return
	# Clicar escolhe um hex; a interface oferece movimento e habilidades.
	# O personagem só anda depois de confirmar "Andar até".
	if not grid.is_valid(coord):
		return
	if _future_vision_actor != null:
		var future_cell := grid.get_cell(coord)
		if future_cell != null and future_cell.state == HexGrid.PPPBlockState.HIDDEN \
				and future_cell.block_type != HexGrid.PPPBlockType.NONE:
			future_vision_hex_requested.emit(coord)
		return
	if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
		request_combat_selection(coord)
		return
	# A Mãe só consulta estes blocos: não muda o estado permanente do hex.
	if _temporary_inspection_coords.has(coord):
		hex_inspection_requested.emit(coord)
		return
	# Uma revelação rosa abre uma única caixa com detalhes e ações.
	var cell := grid.get_cell(coord)
	if cell != null and cell.state == HexGrid.PPPBlockState.REVEALED:
		if selection_validator.is_valid() and not selection_validator.call(coord):
			return
		_selected_coord = coord
		_refresh_feedback()
		hex_choice_requested.emit(coord)
		return
	if selection_validator.is_valid() and not selection_validator.call(coord):
		return
	_selected_coord = coord
	_refresh_feedback()
	hex_choice_requested.emit(coord)


func _filter_destinations(destinations: Dictionary) -> void:
	if not destination_validator.is_valid():
		return
	for coord in destinations.keys():
		if not destination_validator.call(coord):
			destinations.erase(coord)


## Pontos de integração para o futuro ExplorationManager/BlockManager.
func show_generated_map(new_grid: HexGrid) -> void:
	if new_grid == null:
		return
	grid = new_grid
	_retired_start_coords.clear()
	_temporary_inspection_coords.clear()
	_temporary_inspection_owner_id = &""
	_future_vision_actor = null
	_selected_coord = Vector2i(-999, -999)
	if is_node_ready():
		_rebuild_visuals()
		if _parallax != null:
			_parallax.show_generated_map(new_grid)


func set_visual_effects(weather_event_id: StringName, infernal_portals_active: bool) -> void:
	if _parallax != null:
		_parallax.set_visual_effects(weather_event_id, infernal_portals_active)


func set_active_actor(coord: Vector2i, stamina: int,
		unlimited_destinations: bool = false,
		flying_destinations: bool = false) -> void:
	_actor_coord = coord
	preview_stamina = stamina
	_unlimited_destinations = unlimited_destinations
	_flying_destinations = flying_destinations
	_selected_coord = Vector2i(-999, -999)
	_refresh_feedback()


func set_emergency_destination(coord: Vector2i) -> void:
	_emergency_destination = coord
	_refresh_feedback()


func retire_start_marker(coord: Vector2i) -> void:
	if not grid.is_ppp_start_zone(coord):
		return
	_retired_start_coords[coord] = true
	var marker := _start_zone.get_node_or_null("Start_%d" % coord.y)
	if marker != null:
		marker.hide()


func set_occupied_coords(coords: Dictionary) -> void:
	_occupied_coords = coords.duplicate()
	_refresh_feedback()


func reveal_block(coord: Vector2i) -> void:
	var cell := grid.get_cell(coord)
	var was_revealed := cell != null and cell.state == HexGrid.PPPBlockState.REVEALED
	grid.reveal_ppp_block(coord)
	if _selected_coord == coord:
		_selected_coord = Vector2i(-999, -999)
	_refresh_feedback()
	if not was_revealed and grid.get_cell(coord).state == HexGrid.PPPBlockState.REVEALED:
		hex_revealed.emit(coord)


func set_temporary_inspection(owner: EntityState, coords: Array[Vector2i]) -> void:
	_temporary_inspection_coords.clear()
	_temporary_inspection_owner_id = owner.instance_id if owner != null else &""
	for coord in coords:
		var cell := grid.get_cell(coord)
		if cell != null and cell.state in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			_temporary_inspection_coords[coord] = true
	_refresh_feedback()


func clear_temporary_inspection(owner: EntityState = null) -> void:
	if owner != null and owner.instance_id != _temporary_inspection_owner_id:
		return
	_temporary_inspection_coords.clear()
	_temporary_inspection_owner_id = &""
	_refresh_feedback()


func is_temporary_inspection(coord: Vector2i) -> bool:
	return _temporary_inspection_coords.has(coord)


func begin_future_vision(actor: EntityState) -> void:
	_future_vision_actor = actor
	_refresh_feedback()


func end_future_vision() -> void:
	_future_vision_actor = null
	_refresh_feedback()


func is_future_vision_active() -> bool:
	return _future_vision_actor != null


func activate_block(coord: Vector2i) -> void:
	grid.activate_ppp_block(coord)
	_temporary_inspection_coords.erase(coord)
	_refresh_feedback()
	refresh_special_event_visuals()


func cancel_block(coord: Vector2i) -> void:
	grid.cancel_ppp_block(coord)
	_temporary_inspection_coords.erase(coord)
	_refresh_feedback()
	refresh_special_event_visuals()


func destroy_block(coord: Vector2i) -> void:
	grid.destroy_ppp_block(coord)
	_temporary_inspection_coords.erase(coord)
	_refresh_feedback()
	refresh_special_event_visuals()


## Só desenha conteúdos que receberam uma aparência visível própria.
## Os demais hexes continuam ocultando seu Resource até a ativação.
func refresh_special_event_visuals() -> void:
	if _special_event_visuals == null:
		return
	_clear_nodes(_special_event_visuals)
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			continue
		if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT \
				and cell.map_visual_path.contains("duende_cor_"):
			continue # Gnomos do Caos somem durante Encontro Indesejado.
		var animation := grid.get_ppp_map_visual(coord)
		if animation == null:
			continue
		var marker := Node2D.new()
		marker.name = "Event_%d_%d" % [coord.x, coord.y]
		marker.position = reference_hex_position(coord)
		_special_event_visuals.add_child(marker)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = animation.create_sprite_frames()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(0.0, -float(animation.canvas_size.y) * 0.5)
		marker.add_child(sprite)
		if sprite.sprite_frames.has_animation(&"idle"):
			sprite.play(&"idle")


func set_map_mode(mode: HexGrid.PPPMapMode) -> void:
	grid.ppp_map_mode = mode
	_refresh_feedback()


func _clear_nodes(layer: Node2D) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()
