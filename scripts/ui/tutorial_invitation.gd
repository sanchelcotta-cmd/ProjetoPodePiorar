class_name TutorialInvitation
extends CanvasLayer

signal confirmed
signal canceled

const FACE := preload("res://scripts/ui/tutorial_face.gd")
const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")

var _screen: Control
var _panel: PanelContainer
var _heading: Label
var _message: RichTextLabel
var _caption: Label
var _open_button: Button
var _later_button: Button
var _face: TutorialFace
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	layer = 170
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_screen.hide()
	get_viewport().size_changed.connect(_layout)
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.connect("palette_changed", func(_new_id: String) -> void:
			_apply_palette())


func open_invitation() -> void:
	_apply_palette()
	_layout()
	_face.show_page("sorriso discreto", "")
	_screen.show()
	_keyboard_navigation.reset(_screen)


func is_open() -> bool:
	return _screen != null and _screen.visible


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed or event.echo:
		return
	# O convite pede uma escolha explícita: Esc não equivale a "Agora não".
	if event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
	elif _keyboard_navigation.handle_buttons(event, [_open_button, _later_button]):
		get_viewport().set_input_as_handled()


func _build() -> void:
	_screen = Control.new()
	_screen.name = "TutorialInvitationScreen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)
	var veil := ColorRect.new()
	veil.name = "InvitationVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.012, 0.022, 0.033, 0.84)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(veil)
	_panel = PanelContainer.new()
	_panel.name = "InvitationPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	_face = FACE.new() as TutorialFace
	_face.custom_minimum_size = Vector2(170, 110)
	_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_face)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 11)
	row.add_child(content)
	_caption = Label.new()
	_caption.text = "DIA 1  •  GUIA DO JOGO"
	_caption.add_theme_font_size_override("font_size", 12)
	content.add_child(_caption)
	_heading = Label.new()
	_heading.text = "PRIMEIRA VEZ POR AQUI?"
	_heading.add_theme_font_size_override("font_size", 23)
	content.add_child(_heading)
	_message = RichTextLabel.new()
	_message.text = "Antes de explorar, quer conhecer as regras? Veja o tutorial agora ou abra depois pelo T."
	_message.bbcode_enabled = false
	_message.fit_content = false
	_message.scroll_active = false
	_message.custom_minimum_size.y = 76.0
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("normal_font_size", 16)
	UINarrativeFont.apply_rich_text(_message)
	content.add_child(_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 11)
	content.add_child(actions)
	_later_button = Button.new()
	_later_button.text = "AGORA NÃO"
	_later_button.custom_minimum_size = Vector2(140, 38)
	_later_button.pressed.connect(_choose_later)
	actions.add_child(_later_button)
	_open_button = Button.new()
	_open_button.text = "VER TUTORIAL"
	_open_button.custom_minimum_size = Vector2(155, 38)
	_open_button.pressed.connect(_choose_open)
	actions.add_child(_open_button)
	_layout()
	_apply_palette()


func _choose_open() -> void:
	_screen.hide()
	confirmed.emit()


func _choose_later() -> void:
	_screen.hide()
	canceled.emit()


func _layout() -> void:
	if _panel == null:
		return
	var view := get_viewport().get_visible_rect().size
	_panel.size = Vector2(minf(730.0, view.x - 36.0), 260.0)
	_panel.position = (view - _panel.size) * 0.5


func _apply_palette() -> void:
	if _panel == null:
		return
	_panel.add_theme_stylebox_override("panel", _style("surface", "structure", 2))
	_caption.add_theme_color_override("font_color", _color("progress"))
	_heading.add_theme_color_override("font_color", _color("selection"))
	_message.add_theme_color_override("default_color", _color("selection"))
	for button in [_open_button, _later_button]:
		button.add_theme_color_override("font_color", _color("primary"))
		button.add_theme_color_override("font_hover_color", _color("primary"))
		button.add_theme_stylebox_override("normal", _style("button", "structure", 1))
		button.add_theme_stylebox_override("hover", _style("button_hover", "selection", 2))
		button.add_theme_stylebox_override("focus", _style("button_hover", "progress", 2))


func _style(background: String, border: String, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color(background)
	style.border_color = _color(border)
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(7)
	return style


func _color(role: String) -> Color:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		return palette.call("color", role)
	return Color.WHITE
