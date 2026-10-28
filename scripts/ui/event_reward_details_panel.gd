class_name EventRewardDetailsPanel
extends Control

## Consulta compacta de ItemData em diálogos de recompensa. Não recebe nem usa o item.
signal close_requested

const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const NARRATIVE_FONT := preload("res://scripts/ui/ui_narrative_font.gd")
const BORDER := Color(0.996, 0.169, 0.592)
const TEXT := Color(0.92, 0.94, 0.95)

var name_label: Label
var effect_label: Label
var stats_label: Label
var effect_scroll: ScrollContainer
var stats_scroll: ScrollContainer
var close_button: Button
var _icon: TextureRect
var _header: HBoxContainer
var _effect_caption: Label
var _stats_caption: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_header = HBoxContainer.new()
	add_child(_header)
	_header.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	var hint := Label.new()
	hint.text = "Pressione Esc ou:"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT)
	_header.add_child(hint)
	var close := Button.new()
	close_button = close
	close.text = "X"
	close.tooltip_text = "Fechar detalhes"
	close.custom_minimum_size = Vector2(30, 28)
	close.add_theme_font_override("font", BOLD_FONT)
	close.add_theme_font_size_override("font_size", 16)
	close.add_theme_color_override("font_color", Color(0.95, 0.26, 0.30))
	close.add_theme_color_override("font_hover_color", Color(1.0, 0.44, 0.48))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.045, 0.055, 0.065, 1.0)
		style.border_color = Color(0.75, 0.18, 0.22) if state == "normal" else Color(1.0, 0.44, 0.48)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		close.add_theme_stylebox_override(state, style)
	close.pressed.connect(func() -> void: close_requested.emit())
	_header.add_child(close)
	_icon = TextureRect.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	name_label = _label("", 16, Color.WHITE, true)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_caption = _label("EFEITO", 11, BORDER)
	effect_scroll = ScrollContainer.new()
	effect_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(effect_scroll)
	effect_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	effect_label = _label("", 13, TEXT, false, effect_scroll)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NARRATIVE_FONT.apply_label(effect_label)
	_stats_caption = _label("ESTATÍSTICAS", 11, BORDER)
	stats_scroll = ScrollContainer.new()
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(stats_scroll)
	stats_scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	stats_label = _label("", 12, TEXT, false, stats_scroll)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(caption: String, font_size: int, color: Color,
		bold := false, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", BOLD_FONT)
	(parent if parent != null else self).add_child(label)
	if parent == null:
		label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	return label


func bind_catalog_item(item: ItemData) -> void:
	if item == null:
		return
	var formatter := ItemDetailsPanel.new()
	_icon.texture = item.icon
	name_label.text = item.display_name
	effect_label.text = formatter._effect_text(item, null)
	stats_label.text = formatter._stats_text(item, null)
	formatter.free()


func layout_compact(width: float) -> void:
	var inner_width := width - 32.0
	var text_width := inner_width - 6.0
	_header.position = Vector2(16, 10)
	_header.size = Vector2(inner_width, 28)
	_icon.position = Vector2(16, 45)
	_icon.size = Vector2(62, 62)
	name_label.position = Vector2(84, 45)
	name_label.size = Vector2(width - 100.0, 62)
	_effect_caption.position = Vector2(16, 116)
	_effect_caption.size = Vector2(inner_width, 18)
	effect_label.custom_minimum_size.x = text_width
	effect_label.size.x = text_width
	var effect_height := clampf(effect_label.get_line_count() * 23.0 + 12.0, 32.0, 122.0)
	effect_label.custom_minimum_size.y = maxf(effect_height, effect_label.get_line_count() * 23.0 + 12.0)
	effect_scroll.position = Vector2(16, 138)
	effect_scroll.size = Vector2(inner_width, effect_height)
	var stats_y := 138.0 + effect_height + 9.0
	_stats_caption.position = Vector2(16, stats_y)
	_stats_caption.size = Vector2(inner_width, 18)
	stats_label.custom_minimum_size.x = text_width
	stats_label.size.x = text_width
	var stats_height := clampf(stats_label.get_line_count() * 23.0 + 18.0, 32.0, 230.0)
	stats_label.custom_minimum_size.y = maxf(stats_height, stats_label.get_line_count() * 23.0 + 18.0)
	stats_scroll.position = Vector2(16, stats_y + 22.0)
	stats_scroll.size = Vector2(inner_width, stats_height)
	size = Vector2(width, stats_y + 22.0 + stats_height + 16.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.022, 0.033, 0.985), true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 2.0)
