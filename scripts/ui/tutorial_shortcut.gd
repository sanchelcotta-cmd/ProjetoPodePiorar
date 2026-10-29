class_name TutorialShortcut
extends Control

signal opened
signal presentation_changed(y_ratio: float, collapsed: bool)

const MIN_Y_RATIO := 0.56
const MAX_Y_RATIO := 0.90

var y_ratio := 0.66
var collapsed := false
var _open_button: Button
var _collapse_button: Button
var _dragging := false
var _dragged := false
var _press_y := 0.0
var _start_ratio := 0.66


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	_open_button = Button.new()
	_open_button.name = "OpenTutorial"
	_open_button.text = "TUTORIAL"
	_open_button.custom_minimum_size = Vector2(94, 42)
	_open_button.tooltip_text = "Abrir tutorial; arraste para mudar de altura"
	_open_button.gui_input.connect(_on_button_input)
	_open_button.pressed.connect(_on_open_pressed)
	add_child(_open_button)
	_collapse_button = Button.new()
	_collapse_button.name = "CollapseTutorial"
	_collapse_button.text = "‹"
	_collapse_button.custom_minimum_size = Vector2(26, 42)
	_collapse_button.tooltip_text = "Recolher atalho do tutorial"
	_collapse_button.gui_input.connect(_on_button_input)
	_collapse_button.pressed.connect(_on_collapse_pressed)
	add_child(_collapse_button)
	_apply_palette()
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.connect("palette_changed", func(_new_id: String) -> void:
			_apply_palette())
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()


func set_presentation(new_ratio: float, new_collapsed: bool) -> void:
	y_ratio = clampf(new_ratio, MIN_Y_RATIO, MAX_Y_RATIO)
	collapsed = new_collapsed
	if is_inside_tree():
		_apply_layout()


func _on_button_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_dragged = false
			_press_y = event.global_position.y
			_start_ratio = y_ratio
		elif _dragging:
			_dragging = false
			if _dragged:
				presentation_changed.emit(y_ratio, collapsed)
			# O sinal pressed do Button é emitido no fim deste mesmo evento.
			_clear_dragged.call_deferred()
	elif event is InputEventMouseMotion and _dragging:
		var displacement: float = (event as InputEventMouseMotion).global_position.y - _press_y
		if absf(displacement) > 5.0:
			_dragged = true
		if _dragged:
			y_ratio = clampf(_start_ratio + displacement /
				maxf(1.0, get_viewport_rect().size.y),
				MIN_Y_RATIO, MAX_Y_RATIO)
			_apply_layout()


func _clear_dragged() -> void:
	_dragged = false


func _on_open_pressed() -> void:
	if _dragged:
		return
	if collapsed:
		collapsed = false
		_apply_layout()
		presentation_changed.emit(y_ratio, collapsed)
	else:
		opened.emit()


func _on_collapse_pressed() -> void:
	if _dragged:
		return
	collapsed = true
	_apply_layout()
	presentation_changed.emit(y_ratio, collapsed)


func _apply_layout() -> void:
	if _open_button == null:
		return
	var view_height := get_viewport_rect().size.y
	offset_top = view_height * y_ratio
	offset_bottom = offset_top + 42.0
	var width := 55.0 if collapsed else 120.0
	offset_left = -width - 9.0
	offset_right = -9.0
	_open_button.text = "< T" if collapsed else "TUTORIAL"
	_open_button.tooltip_text = "Abrir tutorial (T); arraste para mudar de altura" \
		if not collapsed else "Clique para expandir; T abre o tutorial"
	_open_button.custom_minimum_size.x = 55.0 if collapsed else 94.0
	_open_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_open_button.position = Vector2.ZERO
	_open_button.size = Vector2(55.0 if collapsed else 94.0, 42.0)
	_collapse_button.visible = not collapsed
	_collapse_button.position = Vector2(94.0, 0.0)
	_collapse_button.size = Vector2(26.0, 42.0)


func _apply_palette() -> void:
	for button in [_open_button, _collapse_button]:
		button.add_theme_stylebox_override("normal", _style("button", "structure", 1))
		button.add_theme_stylebox_override("hover", _style("button_hover", "selection", 2))
		button.add_theme_stylebox_override("focus", _style("button_hover", "progress", 2))
		button.add_theme_color_override("font_color", _color("primary"))
		button.add_theme_color_override("font_hover_color", _color("primary"))


func _style(background: String, border: String, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color(background)
	style.border_color = _color(border)
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style


func _color(role: String) -> Color:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		return palette.call("color", role)
	return Color.WHITE
