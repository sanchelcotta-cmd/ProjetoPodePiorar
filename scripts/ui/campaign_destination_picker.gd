class_name CampaignDestinationPicker
extends CanvasLayer

const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")

## Seletor de próxima Rodada: usa arte fixa da primeira cena de cada distrito.
## As imagens são escaladas pela altura visual média das portas, não por largura.
signal destination_confirmed(district: StringName)
signal canceled

const DISTRICTS: Array[StringName] = [&"suburbio", &"baixo_centro", &"centro"]
const ART := {
	&"suburbio": preload("res://sprites/background/cena_suburbio_0001.png"),
	&"baixo_centro": preload("res://sprites/background/cena_baixocentro_0001.png"),
	&"centro": preload("res://sprites/background/cena_centro_0001.png"),
}
# Altura aproximada média das portas visíveis nos PNGs de 2172×724.
const DOOR_HEIGHT_PX := {&"suburbio": 211.0, &"baixo_centro": 218.0, &"centro": 205.0}
const GRAY_SHADER := preload("res://shaders/ui_destination_grayscale.gdshader")
const BACK := Color("#05090C")
const TEXT := Color("#EBF2F5")

var _root: Control
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _title_line: ColorRect
var _rows: VBoxContainer
var _footer_line: ColorRect
var _confirm: Button
var _cancel: Button
var _row_controls: Dictionary = {}
var _dividers: Array[ColorRect] = []
var _available: Array[StringName] = []
var _selected: StringName = &""
var _forced_center := false
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.palette_changed.connect(func(_id: String) -> void: _refresh_style())
	_root.hide()


func is_open() -> bool:
	return _root != null and _root.visible


func open_picker(options: Array[StringName], _current_district: StringName,
		final_center: bool = false) -> void:
	_available = options.duplicate()
	_forced_center = final_center
	_selected = &""
	_rebuild_rows()
	_fit_panel()
	_root.show()
	_refresh_style()
	_keyboard_navigation.reset(_root)


func close_picker() -> void:
	if _root != null:
		_root.hide()


func select_district(district: StringName) -> bool:
	if not is_open() or district not in _available:
		return false
	_selected = district
	_refresh_style()
	return true


func selected_district() -> StringName:
	return _selected


func row_for(district: StringName) -> Button:
	return _row_controls.get(district, {}).get("button") as Button


func displayed_districts() -> Array[StringName]:
	if _forced_center:
		var only_center: Array[StringName] = [&"centro"]
		return only_center
	return DISTRICTS.duplicate()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_on_cancel()
		get_viewport().set_input_as_handled()
	elif _keyboard_navigation.handle(event, _root):
		get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.name = "DestinationScreen"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var black := ColorRect.new()
	black.name = "BlackBackground"
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(black)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "DestinationPanel"
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 22)
	_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	_title = Label.new()
	_title.text = "SELECIONE O PRÓXIMO LOCAL"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	content.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 13)
	content.add_child(_subtitle)
	var title_line := ColorRect.new()
	title_line.name = "TitleLine"
	_title_line = title_line
	title_line.custom_minimum_size.y = 1
	title_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_line)
	var scroll := ScrollContainer.new()
	scroll.name = "DistrictScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "DistrictRows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_rows.add_theme_constant_override("separation", 5)
	scroll.add_child(_rows)
	_footer_line = ColorRect.new()
	_footer_line.custom_minimum_size.y = 1
	_footer_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_footer_line)
	var buttons := HBoxContainer.new()
	buttons.name = "Actions"
	buttons.add_theme_constant_override("separation", 18)
	content.add_child(buttons)
	_confirm = Button.new()
	_confirm.name = "Confirm"
	_confirm.text = "CONFIRMAR DESTINO"
	_confirm.custom_minimum_size = Vector2(225, 44)
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)
	_cancel = Button.new()
	_cancel.name = "StayHere"
	_cancel.text = "CONTINUAR NO MAPA ATUAL"
	_cancel.custom_minimum_size = Vector2(225, 44)
	_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel.pressed.connect(_on_cancel)
	buttons.add_child(_cancel)
	_root.resized.connect(_fit_panel)
	_fit_panel()


func _fit_panel() -> void:
	if _panel == null or _root == null:
		return
	_panel.custom_minimum_size = Vector2(
		minf(900.0, maxf(320.0, _root.size.x - 24.0)),
		minf(760.0, maxf(340.0, _root.size.y - 24.0)))
	if is_open():
		_refresh_style()


func _rebuild_rows() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_row_controls.clear()
	_dividers.clear()
	var shown := displayed_districts()
	for index in shown.size():
		var district := shown[index]
		var row := Button.new()
		row.name = str(district)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.pressed.connect(func() -> void: select_district(district))
		_rows.add_child(row)
		var inside := VBoxContainer.new()
		inside.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.alignment = BoxContainer.ALIGNMENT_CENTER
		inside.add_theme_constant_override("separation", 2)
		row.add_child(inside)
		var image_center := CenterContainer.new()
		image_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(image_center)
		var artwork := TextureRect.new()
		artwork.texture = ART[district]
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image_center.add_child(artwork)
		var name_label := Label.new()
		name_label.text = _district_label(district)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_child(name_label)
		_row_controls[district] = {"button": row, "artwork": artwork, "label": name_label}
		if index + 1 < shown.size():
			var line_center := CenterContainer.new()
			line_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_rows.add_child(line_center)
			var divider := ColorRect.new()
			divider.custom_minimum_size = Vector2(610, 2)
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line_center.add_child(divider)
			_dividers.append(divider)
	_subtitle.text = "Última rota disponível: Centro" if _forced_center else \
		"Escolha um distrito disponível ou continue neste mapa."


func _refresh_style() -> void:
	if _panel == null:
		return
	var structure := _color("structure", Color("#38D9F0"))
	var selection := _color("selection", Color("#FF66B0"))
	var progress := _color("progress", Color("#4DE385"))
	var muted := _color("on_dark_muted", Color("#A3BAC4"))
	var disabled := _color("disabled", Color("#70838B"))
	var panel_style := _box(BACK, structure, 1)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_title.add_theme_color_override("font_color", TEXT)
	_subtitle.add_theme_color_override("font_color", muted)
	_title_line.color = structure.darkened(0.22)
	_footer_line.color = structure.darkened(0.22)
	for divider in _dividers:
		divider.color = Color(structure.r, structure.g, structure.b, 0.78)
	for district in _row_controls:
		var data: Dictionary = _row_controls[district]
		var row := data["button"] as Button
		var artwork := data["artwork"] as TextureRect
		var name_label := data["label"] as Label
		var available: bool = district in _available
		var selected: bool = available and district == _selected
		row.disabled = not available
		row.custom_minimum_size.y = 198.0 if selected else 155.0
		var image: Texture2D = ART[district]
		var target_door_height := 46.0 if selected else 35.0
		var scale_factor: float = target_door_height / float(DOOR_HEIGHT_PX[district])
		var max_width := maxf(230.0, _panel.custom_minimum_size.x - 96.0)
		scale_factor = minf(scale_factor, max_width / image.get_size().x)
		artwork.custom_minimum_size = image.get_size() * scale_factor
		artwork.material = null if available else _gray_material()
		name_label.add_theme_font_size_override("font_size", 26 if selected else 19)
		name_label.add_theme_color_override("font_color",
			selection if selected else TEXT if available else disabled)
		name_label.add_theme_color_override("font_shadow_color",
			Color(selection.r, selection.g, selection.b, 0.48) if selected else Color.TRANSPARENT)
		name_label.add_theme_constant_override("shadow_outline_size", 4 if selected else 0)
		var normal := _box(Color("#0B1820") if selected else BACK,
			selection if selected else Color.TRANSPARENT, 1 if selected else 0)
		var hover := _box(Color("#102630"), structure, 1)
		row.add_theme_stylebox_override("normal", normal)
		row.add_theme_stylebox_override("hover", hover)
		row.add_theme_stylebox_override("pressed", normal)
		row.add_theme_stylebox_override("disabled", normal)
		row.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, structure, 1))
	_style_action(_confirm, progress, true)
	_style_action(_cancel, structure, false)
	_confirm.disabled = _selected == &""


func _style_action(button: Button, accent: Color, primary: bool) -> void:
	button.add_theme_font_size_override("font_size", 16)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, TEXT)
	var normal := _box(Color("#092015") if primary else Color("#091820"), accent, 1)
	var hover := _box(Color("#133A25") if primary else Color("#102E38"), accent, 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, accent, 1))


func _box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style


func _gray_material() -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = GRAY_SHADER
	return result


func _color(role: String, fallback: Color) -> Color:
	var palette := get_node_or_null("/root/UIColorManager")
	return palette.color(role) if palette != null else fallback


func _district_label(district: StringName) -> String:
	match district:
		&"suburbio": return "Subúrbio"
		&"baixo_centro": return "Baixo-Centro"
		&"centro": return "Centro"
	return str(district)


func _on_confirm() -> void:
	if _selected == &"" or _selected not in _available:
		return
	close_picker()
	destination_confirmed.emit(_selected)


func _on_cancel() -> void:
	close_picker()
	canceled.emit()
