class_name TutorialWindow
extends CanvasLayer

signal closed
signal day_one_dismiss_requested

const CONTENT := preload("res://scripts/ui/tutorial_content.gd")
const FACE := preload("res://scripts/ui/tutorial_face.gd")
const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")

var _pages: Array[Dictionary] = []
var _current_index := 0
var _screen: Control
var _panel: PanelContainer
var _category_list: VBoxContainer
var _page_list: VBoxContainer
var _title: Label
var _body: RichTextLabel
var _example: Label
var _controls: Label
var _counter: Label
var _face: TutorialFace
var _previous: Button
var _next: Button
var _dismiss: Button
var _confirm_dismiss: ConfirmationDialog
var _category_buttons: Dictionary = {}
var _page_buttons: Dictionary = {}
var _selected_category := ""
var _built := false
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	layer = 160
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_screen.hide()
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.connect("palette_changed", func(_new_id: String) -> void:
			_apply_palette()
			if _screen.visible:
				_show_page(_current_index))


func open(day_one_shortcut_available: bool = false) -> void:
	if not _built:
		_build()
	_apply_palette()
	_dismiss.visible = day_one_shortcut_available
	_show_page(_current_index)
	_screen.show()
	_keyboard_navigation.reset(_screen)


func close() -> void:
	if not _screen.visible:
		return
	_screen.hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _screen.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	if _confirm_dismiss.visible:
		return
	if event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_PAGEUP:
		_show_page(_current_index - 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_PAGEDOWN:
		_show_page(_current_index + 1)
		get_viewport().set_input_as_handled()
	elif _keyboard_navigation.handle(event, _screen):
		get_viewport().set_input_as_handled()


func _build() -> void:
	if _built:
		return
	_built = true
	_pages = CONTENT.load_pages()
	_screen = Control.new()
	_screen.name = "TutorialScreen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.015, 0.025, 0.035, 0.94)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(veil)
	_panel = PanelContainer.new()
	_panel.name = "TutorialPanel"
	_panel.anchor_left = 0.035
	_panel.anchor_top = 0.035
	_panel.anchor_right = 0.965
	_panel.anchor_bottom = 0.965
	_screen.add_child(_panel)
	_panel.add_theme_stylebox_override("panel", _style("surface", "structure", 2))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 19)
	margin.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var heading_label := _label("TUTORIAL  •  PROJETO PODER PIORAR", 21, "structure")
	heading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(heading_label)
	var close_button := _button("FECHAR  X")
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 23)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var category_scroll := _scroll_column(230)
	columns.add_child(category_scroll)
	_category_list = VBoxContainer.new()
	_category_list.custom_minimum_size.x = 230
	_category_list.add_theme_constant_override("separation", 5)
	category_scroll.add_child(_category_list)
	var page_scroll := _scroll_column(226)
	columns.add_child(page_scroll)
	_page_list = VBoxContainer.new()
	_page_list.custom_minimum_size.x = 226
	_page_list.add_theme_constant_override("separation", 5)
	page_scroll.add_child(_page_list)
	var reader := VBoxContainer.new()
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader.add_theme_constant_override("separation", 14)
	columns.add_child(reader)
	_title = _label("", 23, "selection")
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader.add_child(_title)
	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.add_child(content_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	content_scroll.add_child(content)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UINarrativeFont.apply_rich_text(_body)
	_body.add_theme_font_size_override("normal_font_size", 15)
	_body.add_theme_color_override("default_color", _color("primary"))
	_body.add_theme_constant_override("line_separation", 5)
	content.add_child(_body)
	_example = _label("", 15, "progress")
	_example.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_example)
	_controls = _label("", 15, "secondary")
	_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_controls)
	var divider := HSeparator.new()
	reader.add_child(divider)
	_face = FACE.new() as TutorialFace
	_face.custom_minimum_size.y = 100
	reader.add_child(_face)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	layout.add_child(footer)
	_dismiss = _button("FECHAR TUTORIAL DE VEZ")
	_dismiss.pressed.connect(_request_dismiss)
	footer.add_child(_dismiss)
	_counter = _label("", 14, "secondary")
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_counter)
	_previous = _button("← ANTERIOR")
	_previous.pressed.connect(func() -> void: _go_relative(-1))
	footer.add_child(_previous)
	_next = _button("PRÓXIMA →")
	_next.pressed.connect(func() -> void: _go_relative(1))
	footer.add_child(_next)
	_confirm_dismiss = ConfirmationDialog.new()
	_confirm_dismiss.title = "Fechar tutorial de vez?"
	_confirm_dismiss.dialog_text = "O convite e o atalho lateral do Dia 1 desaparecerão. O tutorial continuará disponível em Configurações → Jogabilidade. Tem certeza?"
	_confirm_dismiss.ok_button_text = "CONCORDO"
	_confirm_dismiss.cancel_button_text = "CANCELAR"
	_confirm_dismiss.confirmed.connect(func() -> void: day_one_dismiss_requested.emit())
	_screen.add_child(_confirm_dismiss)
	_build_categories()
	if not _pages.is_empty():
		_show_page(0)


func _build_categories() -> void:
	for page in _pages:
		var category := str(page.get("category", ""))
		if _category_buttons.has(category):
			continue
		var button := _button(category.capitalize())
		button.custom_minimum_size.x = 230
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_category.bind(category))
		_category_list.add_child(button)
		_category_buttons[category] = button


func _select_category(category: String) -> void:
	for index in _pages.size():
		if str(_pages[index].get("category", "")) == category:
			_show_page(index)
			return


func _show_page(index: int) -> void:
	if _pages.is_empty():
		return
	_current_index = clampi(index, 0, _pages.size() - 1)
	var page := _pages[_current_index]
	var category := str(page.get("category", ""))
	if category != _selected_category:
		_selected_category = category
		_rebuild_page_list(category)
	_title.text = str(page.get("title", ""))
	_body.text = _format_body(str(page.get("body", "")))
	var example_text := str(page.get("example", ""))
	_example.text = "EXEMPLO\n" + example_text
	_example.visible = not example_text.is_empty()
	var controls_text := str(page.get("controls", ""))
	_controls.text = "CONTROLES\n" + controls_text
	_controls.visible = not controls_text.is_empty()
	_face.show_page(str(page.get("expression", "")), str(page.get("face_line", "")))
	var local_indices := _indices_for_category(category)
	var local_position := local_indices.find(_current_index)
	_counter.text = "%d / %d" % [local_position + 1, local_indices.size()]
	_previous.disabled = local_position <= 0
	_next.disabled = local_position >= local_indices.size() - 1
	for key in _category_buttons:
		(_category_buttons[key] as Button).add_theme_stylebox_override("normal",
			_style("button_hover", "selection", 2) if key == category
			else _style("button", "structure", 1))
	for key in _page_buttons:
		(_page_buttons[key] as Button).add_theme_stylebox_override("normal",
			_style("button_hover", "progress", 2) if key == _current_index
			else _style("button", "structure", 1))


func _rebuild_page_list(category: String) -> void:
	for child in _page_list.get_children():
		child.queue_free()
	_page_buttons.clear()
	for index in _pages.size():
		if str(_pages[index].get("category", "")) != category:
			continue
		var button := _button(str(_pages[index].get("title", "")))
		button.custom_minimum_size.x = 226
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_page.bind(index))
		_page_list.add_child(button)
		_page_buttons[index] = button


func _indices_for_category(category: String) -> Array[int]:
	var indices: Array[int] = []
	for index in _pages.size():
		if str(_pages[index].get("category", "")) == category:
			indices.append(index)
	return indices


func _go_relative(direction: int) -> void:
	var indices := _indices_for_category(_selected_category)
	var current := indices.find(_current_index)
	var next := current + direction
	if next >= 0 and next < indices.size():
		_show_page(indices[next])


func _format_body(value: String) -> String:
	var paragraphs := value.strip_edges().split("\n\n", false)
	var result := ""
	for index in paragraphs.size():
		var paragraph := paragraphs[index].strip_edges().replace("[", "[lb]")
		var colon := paragraph.find(":")
		if colon > 0 and colon < 46 and paragraph.find(".") > colon:
			var heading := paragraph.substr(0, colon + 1)
			paragraph = "[b][color=#%s]%s[/color][/b]%s" % [
				_color("structure").to_html(), heading,
				_highlight_terms(paragraph.substr(colon + 1))]
		else:
			paragraph = _highlight_terms(paragraph)
		if index > 0:
			result += "\n\n[color=#%s]-[/color]  " % _color("selection").to_html()
		result += paragraph
	return result


func _highlight_terms(value: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("(?i)\\b(Exploração|Combate|Rodada|Dia|Vida|Ataque|Estamina|Informações|Informação|Inventário|Evento|Habilidades|Dado)\\b")
	return pattern.sub(value, "[b]$1[/b]", true)


func _request_dismiss() -> void:
	_confirm_dismiss.popup_centered(Vector2i(490, 180))


func _scroll_column(width: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = width
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll


func _label(value: String, size: int, role: String) -> Label:
	var label := Label.new()
	label.text = value
	label.set_meta("tutorial_color_role", role)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", _color(role))
	return label


func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.toggle_mode = false
	button.custom_minimum_size.y = 33
	button.custom_minimum_size.x = maxf(88.0,
		float(value.length()) * 11.0 + 26.0)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", _color("primary"))
	button.add_theme_color_override("font_hover_color", _color("primary"))
	button.add_theme_stylebox_override("normal", _style("button", "structure", 1))
	button.add_theme_stylebox_override("hover", _style("button_hover", "selection", 2))
	button.add_theme_stylebox_override("focus", _style("button_hover", "progress", 2))
	return button


func _apply_palette() -> void:
	if _screen == null:
		return
	_panel.add_theme_stylebox_override("panel", _style("surface", "structure", 2))
	_body.add_theme_color_override("default_color", _color("primary"))
	for node in _screen.find_children("*", "Label", true, false):
		var label := node as Label
		if label.has_meta("tutorial_color_role"):
			label.add_theme_color_override("font_color",
				_color(str(label.get_meta("tutorial_color_role"))))
	for node in _screen.find_children("*", "Button", true, false):
		var button := node as Button
		button.add_theme_stylebox_override("normal", _style("button", "structure", 1))
		button.add_theme_stylebox_override("hover",
			_style("button_hover", "selection", 2))
		button.add_theme_stylebox_override("focus",
			_style("button_hover", "progress", 2))
		button.add_theme_color_override("font_color", _color("primary"))
		button.add_theme_color_override("font_hover_color", _color("primary"))


func _style(background: String, border: String, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color(background)
	style.border_color = _color(border)
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(7)
	return style


func _color(role: String) -> Color:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		return palette.call("color", role)
	return Color.WHITE
