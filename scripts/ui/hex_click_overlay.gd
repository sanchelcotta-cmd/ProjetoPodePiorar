class_name HexClickOverlay
extends Control

## Camada invisível acima dos corpos: só captura o interior real dos
## hexágonos clicáveis. Os ícones de Debuff continuam acima dela.
signal hex_pressed(coord: Vector2i, screen_position: Vector2, event: InputEvent)

var map_view: PPPMapView
var excluded_rects: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _has_point(point: Vector2) -> bool:
	if map_view == null or not visible:
		return false
	var screen_position := get_global_transform_with_canvas() * point
	for rect in excluded_rects:
		if rect.has_point(screen_position):
			return false
	return map_view.get_clickable_hex_at_screen_position(screen_position) \
		!= EntityState.UNPLACED


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or event.double_click or map_view == null:
		return
	var mouse_event := event as InputEventMouseButton
	var screen_position: Vector2 = get_global_transform_with_canvas() * mouse_event.position
	var coord := map_view.get_clickable_hex_at_screen_position(screen_position)
	if coord == EntityState.UNPLACED:
		return
	hex_pressed.emit(coord, screen_position, event)
	accept_event()
