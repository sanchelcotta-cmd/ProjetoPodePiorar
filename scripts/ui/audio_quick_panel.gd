class_name AudioQuickPanel
extends Control

## Minicaixa do botão ♪: não altera a campanha nem pausa o mundo.
const AUDIO_VOLUME_CONTROLS_SCRIPT := preload("res://scripts/ui/audio_volume_controls.gd")
var _panel: PanelContainer
var _station_button: Button
var _station_label: Label
var _audio: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio = get_node_or_null("/root/GameAudio")
	var backdrop := ColorRect.new()
	backdrop.name = "ClickOutside"
	backdrop.color = Color.TRANSPARENT
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)
	_panel = PanelContainer.new()
	_panel.name = "SoundQuickPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.041, 0.055, 0.98)
	panel_style.border_color = Color(0.35, 0.83, 0.94)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(10)
	_palette_call("bind_style", [panel_style, "surface", "structure"])
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	_panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label("ÁUDIO", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _button("× FECHAR")
	close_button.custom_minimum_size = Vector2(68, 30)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var controls := AUDIO_VOLUME_CONTROLS_SCRIPT.new() as VBoxContainer
	controls.name = "AudioVolumeControls"
	controls.set("compact", true)
	content.add_child(controls)
	var station_row := HBoxContainer.new()
	station_row.add_theme_constant_override("separation", 8)
	content.add_child(station_row)
	_station_button = _button("↻ MUDAR ESTAÇÃO")
	_station_button.name = "ChangeStation"
	_station_button.custom_minimum_size.y = 32
	_station_button.pressed.connect(_change_station)
	station_row.add_child(_station_button)
	_station_label = _label("", 12)
	_station_label.name = "StationName"
	_station_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_station_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	station_row.add_child(_station_label)
	if _audio != null:
		_audio.station_changed.connect(_on_station_changed)
		_audio.station_catalog_changed.connect(_sync_station)
	_sync_station()
	_panel.minimum_size_changed.connect(_place_panel_deferred)
	get_viewport().size_changed.connect(_place_panel_deferred)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.ui_scale_changed.connect(func(_factor: float) -> void:
			_place_panel_deferred())
	hide()


func open() -> void:
	_sync_station()
	show()
	_place_panel_deferred()


func close() -> void:
	hide()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
		accept_event()


func _change_station() -> void:
	if _audio != null:
		_audio.call("next_station")
	_sync_station()


func _on_station_changed(_station_id: StringName, _title: String) -> void:
	_sync_station()


func _sync_station() -> void:
	if _station_button == null or _station_label == null:
		return
	var count := int(_audio.call("get_station_count")) if _audio != null else 0
	var exploring: bool = _audio != null and \
		_audio.call("get_music_context") == &"exploration"
	_station_button.disabled = count < 2 or not exploring
	_station_button.tooltip_text = "Troca de rádio disponível durante a Exploração." \
		if count >= 2 and not exploring else \
		"Adicione ao menos duas músicas para alternar a estação." \
		if count < 2 else "Tocar a próxima rádio em loop."
	_station_label.text = str(_audio.call("get_current_station_title")) \
		if _audio != null else "Nenhuma música cadastrada"


func _place_panel_deferred() -> void:
	_place_panel.call_deferred()


func _place_panel() -> void:
	if _panel == null or not is_inside_tree():
		return
	var viewport_size := get_viewport_rect().size
	var minimum := _panel.get_combined_minimum_size()
	var width := minf(maxf(360.0, minimum.x), viewport_size.x - 20.0)
	_panel.size = Vector2(width, minimum.y)
	_panel.position = Vector2(viewport_size.x - width - 10.0, 55.0)


func _label(caption: String, size_px: int) -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", Color(0.91, 0.96, 0.99))
	_palette_call("bind_color", [label, "font_color", "primary"])
	return label


func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color(0.91, 0.96, 0.99))
	button.add_theme_color_override("font_hover_color", Color(0.91, 0.96, 0.99))
	button.add_theme_color_override("font_disabled_color", Color(0.67, 0.77, 0.83))
	_palette_call("bind_color", [button, "font_color", "on_button"])
	_palette_call("bind_color", [button, "font_hover_color", "on_button"])
	_palette_call("bind_color", [button, "font_disabled_color", "on_button_disabled"])
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.072, 0.96)
	style.border_color = Color(0.35, 0.83, 0.94)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(4)
	_palette_call("bind_style", [style, "button", "structure"])
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.96, 0.38, 0.66)
	_palette_call("bind_style", [hover, "button_hover", "selection"])
	button.add_theme_stylebox_override("hover", hover)
	return button


func _palette_call(method: String, args: Array) -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.callv(method, args)
