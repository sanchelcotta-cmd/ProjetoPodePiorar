class_name AudioVolumeControls
extends VBoxContainer

## Os mesmos controles são usados em Configurações e na caixa compacta do HUD.
const CHANNELS: Array[StringName] = [&"master", &"effects", &"music"]
const TITLES := {
	&"master": "GERAL",
	&"effects": "EFEITOS / UI",
	&"music": "MÚSICA",
}
const CYAN := Color(0.35, 0.83, 0.94)
const WHITE := Color(0.91, 0.96, 0.99)

var compact := false
var _sliders: Dictionary = {}
var _percent_labels: Dictionary = {}
var _mute_buttons: Dictionary = {}
var _audio: Node


func _ready() -> void:
	_audio = get_node_or_null("/root/GameAudio")
	add_theme_constant_override("separation", 12 if not compact else 7)
	for channel in CHANNELS:
		_add_channel(channel)
	if _audio != null:
		_audio.volume_changed.connect(_on_volume_changed)
		for channel in CHANNELS:
			_sync_channel(channel)


func _add_channel(channel: StringName) -> void:
	var row := HBoxContainer.new()
	row.name = "AudioRow_%s" % channel
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var title := _label(TITLES[channel], 13, WHITE, "primary")
	title.custom_minimum_size.x = 105 if compact else 150
	row.add_child(title)
	var slider := HSlider.new()
	slider.name = "VolumeSlider_%s" % channel
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(95 if compact else 160, 30)
	slider.tooltip_text = "Volume de %s, de 0%% a 100%%." % str(TITLES[channel]).to_lower()
	slider.value_changed.connect(_on_slider_changed.bind(channel))
	row.add_child(slider)
	_sliders[channel] = slider
	var percentage := _label("0%", 13, CYAN, "structure")
	percentage.name = "VolumePercent_%s" % channel
	percentage.custom_minimum_size.x = 42
	percentage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percentage)
	_percent_labels[channel] = percentage
	var mute := Button.new()
	mute.name = "MuteButton_%s" % channel
	mute.custom_minimum_size = Vector2(61, 30)
	mute.add_theme_font_size_override("font_size", 12)
	mute.add_theme_color_override("font_color", WHITE)
	mute.add_theme_color_override("font_hover_color", WHITE)
	_palette_call("bind_color", [mute, "font_color", "on_button"])
	_palette_call("bind_color", [mute, "font_hover_color", "on_button"])
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.055, 0.072, 0.96)
	normal.border_color = CYAN
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(4)
	_palette_call("bind_style", [normal, "button", "structure"])
	mute.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.1, 0.13, 0.98)
	hover.border_color = Color(0.96, 0.38, 0.66)
	_palette_call("bind_style", [hover, "button_hover", "selection"])
	mute.add_theme_stylebox_override("hover", hover)
	mute.pressed.connect(_on_mute_pressed.bind(channel))
	row.add_child(mute)
	_mute_buttons[channel] = mute


func _label(caption: String, size_px: int, color: Color, role: String) -> Label:
	var label := Label.new()
	label.text = caption
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	_palette_call("bind_color", [label, "font_color", role])
	return label


func _on_slider_changed(value: float, channel: StringName) -> void:
	if _audio != null:
		_audio.call("set_volume", channel, roundi(value))


func _on_mute_pressed(channel: StringName) -> void:
	if _audio != null:
		_audio.call("toggle_mute", channel)


func _on_volume_changed(channel: StringName, _percent: int) -> void:
	_sync_channel(channel)


func _sync_channel(channel: StringName) -> void:
	if _audio == null or not _sliders.has(channel):
		return
	var percent := int(_audio.call("get_volume", channel))
	(_sliders[channel] as HSlider).set_value_no_signal(percent)
	(_percent_labels[channel] as Label).text = "%d%%" % percent
	var mute := _mute_buttons[channel] as Button
	mute.text = "MUDO" if percent > 0 else "ATIVAR"
	mute.tooltip_text = "Definir %s em 0%%; clicar de novo restaura o volume anterior." \
		% str(TITLES[channel]).to_lower() if percent > 0 \
		else "Restaurar o último volume de %s." % str(TITLES[channel]).to_lower()


func _palette_call(method: String, args: Array) -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.callv(method, args)
