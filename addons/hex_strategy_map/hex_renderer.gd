class_name HexRenderer
extends RefCounted

## Desenha os hexágonos com hex-ref.png. O centro transparente deixa o
## ground aparecer; a cor do contorno comunica o estado do bloco.
signal cell_pressed(coord: Vector2i, event: InputEvent)

const HEX_TEXTURE = preload("res://sprites/map/hex-ref.png")
const PPP_HEX_OUTLINE_RADIUS_PIXELS := 242.0
# Tamanho de teste pedido: o PNG original mede 640 × 640 pixels.
# O tamanho visual (e a área clicável abaixo) passa a ser 92 × 82 pixels.
const REFERENCE_SPRITE_SCALE := Vector2(92.0 / 640.0, 82.0 / 640.0)

var _palette: HexPalette
var _sprite_scale: Vector2


func _init(palette: HexPalette = null, sprite_scale: Vector2 = REFERENCE_SPRITE_SCALE) -> void:
	_palette = palette if palette != null else HexPalette.new()
	_sprite_scale = sprite_scale


func create_hex_visual(container: Node2D, coord: Vector2i, pixel: Vector2) -> void:
	var area := Area2D.new()
	area.name = "Hex_%d_%d" % [coord.x, coord.y]
	area.position = pixel

	var collision := CollisionPolygon2D.new()
	var outline := HexGrid.hex_polygon_points(PPP_HEX_OUTLINE_RADIUS_PIXELS)
	for index in outline.size():
		outline[index] = outline[index] * _sprite_scale
	collision.polygon = outline
	area.add_child(collision)

	var sprite := Sprite2D.new()
	sprite.name = "Outline"
	sprite.texture = HEX_TEXTURE
	sprite.scale = _sprite_scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	area.add_child(sprite)

	area.input_event.connect(_on_hex_input.bind(coord))
	container.add_child(area)


func update_ppp_block_state_visual(container: Node2D, grid: HexGrid, coord: Vector2i) -> void:
	var area := _get_visual(container, coord)
	if area == null:
		return
	var state: int = grid.get_ppp_block_data(coord).get("state", HexGrid.PPPBlockState.HIDDEN)
	var resolved := state in [
		HexGrid.PPPBlockState.ACTIVATED,
		HexGrid.PPPBlockState.DESTROYED,
		HexGrid.PPPBlockState.CANCELLED,
	]
	if resolved and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION:
		area.modulate = _palette.inactive_color
		area.input_pickable = false
	elif state == HexGrid.PPPBlockState.REVEALED:
		area.modulate = _palette.revealed_color
		area.input_pickable = true
	else:
		area.modulate = _palette.default_color
		area.input_pickable = true


## Prioridade de cores: personagem ativo > consulta temporária > seleção > alcance.
func update_ppp_feedback(
		container: Node2D,
		grid: HexGrid,
		available_destinations: Dictionary = {},
		selected_coord: Vector2i = Vector2i(-999, -999),
		active_coord: Vector2i = Vector2i(-999, -999),
		temporary_inspection_coords: Dictionary = {},
) -> void:
	for coord in grid.cells:
		update_ppp_block_state_visual(container, grid, coord)
		var area := _get_visual(container, coord)
		if area == null:
			continue
		if available_destinations.has(coord) \
				and (grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT \
				or grid.get_cell(coord).state in [HexGrid.PPPBlockState.HIDDEN,
					HexGrid.PPPBlockState.REVEALED]):
			area.modulate = _palette.reachable_color
		if coord == selected_coord and area.input_pickable:
			area.modulate = _palette.selected_color
		if temporary_inspection_coords.has(coord) and area.input_pickable:
			area.modulate = _palette.temporary_inspection_color
		if coord == active_coord:
			area.modulate = _palette.active_color


func _get_visual(container: Node2D, coord: Vector2i) -> Area2D:
	return container.get_node_or_null("Hex_%d_%d" % [coord.x, coord.y]) as Area2D


func get_active_color() -> Color:
	return _palette.active_color


func _on_hex_input(_viewport: Node, event: InputEvent, _shape_idx: int, coord: Vector2i) -> void:
	if event is InputEventMouseButton and event.pressed:
		cell_pressed.emit(coord, event)
	elif event is InputEventScreenTouch and event.pressed:
		cell_pressed.emit(coord, event)
