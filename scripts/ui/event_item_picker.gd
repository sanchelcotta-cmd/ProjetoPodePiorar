class_name EventItemPicker
extends Control

## Seleção reutilizável para recompensas escolhidas no catálogo de EventData.
## A escolha só é enviada ao executor após SIM; AINDA NÃO volta à grade.
signal item_confirmed(item: ItemData)
signal reward_forfeited
signal details_requested(item: ItemData)

const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")
const BORDER := Color(0.996, 0.169, 0.592)

var _grid: GridContainer
var _title: Label
var _choice_panel: PanelContainer
var _forfeit_panel: PanelContainer
var _choice_name: Label
var _choice_icon: TextureRect
var _selected: ItemData
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 460)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.065, 0.075, 0.09, 0.97)))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var heading := HBoxContainer.new()
	body.add_child(heading)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_override("font", BOLD_FONT)
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", BORDER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(_title)
	var close_hint := Label.new()
	close_hint.text = "Pressione Esc ou:"
	close_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	close_hint.add_theme_font_size_override("font_size", 11)
	close_hint.add_theme_color_override("font_color", Color(0.86, 0.89, 0.90))
	heading.add_child(close_hint)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Fechar seleção sem escolher"
	close_button.custom_minimum_size = Vector2(32, 32)
	close_button.add_theme_font_override("font", BOLD_FONT)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Color(0.95, 0.26, 0.30))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.44, 0.48))
	for state in ["normal", "hover", "pressed", "focus"]:
		var close_style := StyleBoxFlat.new()
		close_style.bg_color = Color(0.045, 0.055, 0.065, 1.0)
		close_style.border_color = Color(0.75, 0.18, 0.22) if state == "normal" else Color(1.0, 0.44, 0.48)
		close_style.set_border_width_all(1)
		close_style.set_corner_radius_all(3)
		close_button.add_theme_stylebox_override(state, close_style)
	close_button.pressed.connect(_ask_forfeit)
	heading.add_child(close_button)
	var hint := Label.new()
	hint.text = "Escolha um item. A seleção só é concluída após confirmar."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	body.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 366)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)
	_choice_panel = PanelContainer.new()
	_choice_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.1, 0.12, 0.15, 0.99)))
	_choice_panel.visible = false
	center.add_child(_choice_panel)
	var choice_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		choice_margin.add_theme_constant_override(side, 20)
	_choice_panel.add_child(choice_margin)
	var choice_body := VBoxContainer.new()
	choice_body.custom_minimum_size.x = 400
	choice_body.add_theme_constant_override("separation", 14)
	choice_margin.add_child(choice_body)
	_choice_name = Label.new()
	_choice_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_choice_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_choice_name.add_theme_font_override("font", BOLD_FONT)
	_choice_name.add_theme_font_size_override("font_size", 19)
	choice_body.add_child(_choice_name)
	_choice_icon = TextureRect.new()
	_choice_icon.custom_minimum_size = Vector2(100, 100)
	_choice_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_choice_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_choice_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var choice_preview := HBoxContainer.new()
	choice_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_preview.add_theme_constant_override("separation", 12)
	choice_body.add_child(choice_preview)
	choice_preview.add_child(_choice_icon)
	var choice_info := _info_button()
	choice_info.name = "ChoiceInfo"
	choice_info.pressed.connect(func() -> void:
		if _selected != null:
			details_requested.emit(_selected))
	choice_preview.add_child(choice_info)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 15)
	choice_body.add_child(actions)
	for caption in ["SIM", "AINDA NÃO"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(135, 40)
		button.add_theme_font_override("font", BOLD_FONT)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_confirm if caption == "SIM" else _go_back)
		actions.add_child(button)
	_forfeit_panel = PanelContainer.new()
	_forfeit_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.1, 0.12, 0.15, 0.99)))
	_forfeit_panel.hide()
	center.add_child(_forfeit_panel)
	var forfeit_margin := MarginContainer.new()
	forfeit_margin.add_theme_constant_override("margin_left", 20)
	forfeit_margin.add_theme_constant_override("margin_top", 20)
	forfeit_margin.add_theme_constant_override("margin_right", 20)
	forfeit_margin.add_theme_constant_override("margin_bottom", 20)
	_forfeit_panel.add_child(forfeit_margin)
	var forfeit_body := VBoxContainer.new()
	forfeit_body.custom_minimum_size.x = 430
	forfeit_body.add_theme_constant_override("separation", 14)
	forfeit_margin.add_child(forfeit_body)
	var forfeit_title := Label.new()
	forfeit_title.text = "DESISTIR DA RECOMPENSA?"
	forfeit_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forfeit_title.add_theme_font_override("font", BOLD_FONT)
	forfeit_title.add_theme_font_size_override("font_size", 19)
	forfeit_body.add_child(forfeit_title)
	var forfeit_explanation := Label.new()
	forfeit_explanation.text = "O evento será encerrado sem o item nem os efeitos desta escolha. Esta decisão não pode ser refeita."
	forfeit_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UINarrativeFont.apply_label(forfeit_explanation)
	forfeit_explanation.add_theme_font_size_override("font_size", 16)
	forfeit_body.add_child(forfeit_explanation)
	var forfeit_actions := HBoxContainer.new()
	forfeit_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	forfeit_actions.add_theme_constant_override("separation", 12)
	forfeit_body.add_child(forfeit_actions)
	var keep_button := Button.new()
	keep_button.text = "CONTINUAR ESCOLHENDO"
	keep_button.custom_minimum_size = Vector2(190, 42)
	keep_button.pressed.connect(_cancel_forfeit)
	forfeit_actions.add_child(keep_button)
	var forfeit_button := Button.new()
	forfeit_button.text = "CONCORDO, DESISTIR"
	forfeit_button.custom_minimum_size = Vector2(205, 42)
	forfeit_button.pressed.connect(_confirm_forfeit)
	forfeit_actions.add_child(forfeit_button)
	hide()


func open_catalog(items: Array[ItemData], title: String) -> void:
	_selected = null
	_title.text = title
	_choice_panel.hide()
	_forfeit_panel.hide()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for item in items:
		if item == null:
			continue
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(126, 158)
		tile.add_theme_stylebox_override("normal", _panel_style(Color(0.11, 0.13, 0.16, 0.94)))
		tile.add_theme_stylebox_override("hover", _panel_style(Color(0.18, 0.23, 0.28, 1.0)))
		tile.add_theme_stylebox_override("pressed", _panel_style(Color(0.18, 0.3, 0.25, 1.0)))
		tile.tooltip_text = item.display_name
		tile.pressed.connect(_select.bind(item))
		_grid.add_child(tile)
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 7
		content.offset_top = 7
		content.offset_right = -7
		content.offset_bottom = -7
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(content)
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size.y = 64
		icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		var name := Label.new()
		name.text = item.display_name
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name.add_theme_font_size_override("font_size", 14)
		name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(name)
		var info := _info_button()
		info.name = "ItemInfo"
		info.anchor_left = 1.0
		info.anchor_right = 1.0
		info.offset_left = -37.0
		info.offset_right = -7.0
		info.offset_top = 7.0
		info.offset_bottom = 37.0
		info.pressed.connect(_request_item_details.bind(item))
		tile.add_child(info)
	show()
	_keyboard_navigation.reset(_grid)


func _select(item: ItemData) -> void:
	if _choice_panel.visible or _forfeit_panel.visible:
		return
	_selected = item
	_choice_name.text = "Deseja escolher %s?" % item.display_name
	_choice_icon.texture = item.icon
	_choice_panel.show()
	_keyboard_navigation.reset(_choice_panel)


func _go_back() -> void:
	_selected = null
	_choice_panel.hide()
	_keyboard_navigation.reset(_grid)


func _ask_forfeit() -> void:
	if not visible:
		return
	_selected = null
	_choice_panel.hide()
	_forfeit_panel.show()
	_keyboard_navigation.reset(_forfeit_panel)


func _cancel_forfeit() -> void:
	_forfeit_panel.hide()
	_keyboard_navigation.reset(_grid)


func _confirm_forfeit() -> void:
	_forfeit_panel.hide()
	hide()
	reward_forfeited.emit()


func _confirm() -> void:
	if _selected == null:
		return
	var item := _selected
	hide()
	item_confirmed.emit(item)


func _request_item_details(item: ItemData) -> void:
	details_requested.emit(item)


func _input(event: InputEvent) -> void:
	if get_viewport().is_input_handled():
		return
	var popup := get_parent().get_parent()
	var details := popup.get_node_or_null("Overlay/RewardItemDetails") as Control
	if details != null and details.visible:
		return
	if visible and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if not _forfeit_panel.visible:
			_ask_forfeit()
		get_viewport().set_input_as_handled()
		return
	if visible:
		var active_root: Control = _forfeit_panel if _forfeit_panel.visible else \
			_choice_panel if _choice_panel.visible else _grid
		if _keyboard_navigation.handle(event, active_root):
			get_viewport().set_input_as_handled()


func _info_button() -> Button:
	var button := Button.new()
	button.text = "ⓘ"
	button.tooltip_text = "Ver descrição e estatísticas do item"
	button.custom_minimum_size = Vector2(28, 28)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", Color(0.82, 0.72, 0.34))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.51))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	return button


func _panel_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
