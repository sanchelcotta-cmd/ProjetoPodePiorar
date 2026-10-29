class_name GnomeHoverHint
extends Node

## Hover compartilhado pelos gnomos 08 e 09. Nenhum sprite ou caixa captura
## clique: o hex subjacente continua sendo o único alvo válido.

const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")

var _view: PPPMapView
var _gnomes2
var _layer: CanvasLayer
var _hint: PanelContainer
var _outside_clicks := 0
var _hovered_visual_id := 0
var _suppressed_visual_id := 0


func _ready() -> void:
	_view = get_parent() as PPPMapView
	_gnomes2 = get_parent().get_node_or_null("Gnomes2Manager")
	_layer = CanvasLayer.new()
	_layer.layer = 65
	add_child(_layer)
	_hint = PanelContainer.new()
	_hint.name = "GnomosDoCaosHover"
	_hint.custom_minimum_size = Vector2(165, 44)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.055, 0.91)
	style.border_color = Color(0.23, 0.82, 0.87, 0.80)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_hint.add_theme_stylebox_override("panel", style)
	_layer.add_child(_hint)
	var label := Label.new()
	label.text = "Gnomos do Caos"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", BOLD_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	_hint.add_child(label)
	_hint.hide()


func _process(_delta: float) -> void:
	if _view == null:
		return
	if _view.grid != null and _view.grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
		_hint.hide()
		return
	var mouse := get_viewport().get_mouse_position()
	var visual := _visual_under_mouse(mouse)
	var visual_id := visual.get_instance_id() if visual != null else 0
	if visual_id == 0:
		_hovered_visual_id = 0
		_suppressed_visual_id = 0
		return
	if visual_id == _suppressed_visual_id:
		return
	if visual_id != _hovered_visual_id or not _hint.visible:
		_hovered_visual_id = visual_id
		_outside_clicks = 0
		var bounds := get_viewport().get_visible_rect().size
		_hint.position = Vector2(
			clampf(mouse.x + 24.0, 10.0, bounds.x - 175.0),
			clampf(mouse.y - 62.0, 61.0, bounds.y - 54.0))
		_hint.show()


func _visual_under_mouse(mouse: Vector2) -> AnimatedSprite2D:
	if _gnomes2 != null and _gnomes2.visual_root != null:
		for visual in _gnomes2.visual_root.get_children():
			if visual is AnimatedSprite2D and _on_sprite(mouse, visual):
				return visual
	if _view.grid == null or _view._special_event_visuals == null:
		return null
	for coord in _view.grid.cells:
		var cell := _view.grid.get_cell(coord)
		if cell == null or not cell.map_visual_path.contains("duende_cor_"):
			continue
		var marker := _view._special_event_visuals.get_node_or_null(
			"Event_%d_%d" % [coord.x, coord.y])
		if marker != null and marker.get_child_count() > 0:
			var sprite := marker.get_child(0) as AnimatedSprite2D
			if sprite != null and _on_sprite(mouse, sprite):
				return sprite
	return null


func _on_sprite(mouse: Vector2, sprite: AnimatedSprite2D) -> bool:
	if not sprite.is_visible_in_tree():
		return false
	var center := sprite.get_global_transform_with_canvas() * Vector2.ZERO
	return absf(mouse.x - center.x) <= 23.0 and absf(mouse.y - center.y) <= 27.0


func _input(event: InputEvent) -> void:
	if not _hint.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and _visual_under_mouse(event.position) == null:
		_outside_clicks += 1
		if _outside_clicks >= 2:
			_hint.hide()
