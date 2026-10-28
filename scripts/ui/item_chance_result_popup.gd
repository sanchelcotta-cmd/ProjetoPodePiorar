class_name ItemChanceResultPopup
extends Control

## Aviso compacto para resultados percentuais de itens e habilidades.
## Uma única ação de confirmação, com margem simples e clara.

var _message: Label
var _ok: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 300
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := PanelContainer.new()
	box.name = "MessageBox"
	box.custom_minimum_size = Vector2(430, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.052, 0.063, 0.97)
	style.border_color = Color(0.94, 0.97, 0.98)
	style.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	for side in [&"left", &"right", &"top", &"bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 17)
	box.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)
	_message = Label.new()
	_message.custom_minimum_size.x = 396
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UINarrativeFont.apply_label(_message)
	_message.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98))
	content.add_child(_message)
	_ok = Button.new()
	_ok.name = "OK"
	_ok.text = "OK"
	_ok.custom_minimum_size = Vector2(112, 34)
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok.pressed.connect(hide)
	content.add_child(_ok)
	hide()


func show_message(message: String) -> void:
	if message.is_empty():
		return
	_message.text = message
	show()
	_ok.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
