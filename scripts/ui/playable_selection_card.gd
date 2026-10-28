class_name PlayableSelectionCard
extends Button

signal chosen(card: PlayableSelectionCard)
signal details_requested(card: PlayableSelectionCard)

@onready var character_visual: PlayableActorVisual = $CharacterVisual
@onready var character_name: Label = $CharacterName
@onready var stats_label: Label = $Stats
@onready var masteries_label: Label = $Masteries
@onready var details_button: Button = $Details

var character: EntityData
var pick_number := 0


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(self))
	details_button.pressed.connect(func() -> void: details_requested.emit(self))
	resized.connect(_layout_contents)
	_layout_contents()
	_update_style()


func setup(data: EntityData) -> void:
	character = data
	character_name.text = data.display_name
	stats_label.text = "VIDA: %d\nATAQUE: %d\nSTAMINA: %d" % [
		data.vida_base, data.ataque_base, data.stamina_base]
	var mastery_names: Array[String] = []
	for mastery in data.maestrias:
		match mastery:
			EntityData.Mastery.BLADE: mastery_names.append("Lâmina")
			EntityData.Mastery.IMPACT: mastery_names.append("Impacto")
			EntityData.Mastery.RANGED: mastery_names.append("Distância")
	masteries_label.text = "MAESTRIA: %s" % (
		", ".join(mastery_names) if not mastery_names.is_empty() else "SEM MAESTRIA")
	masteries_label.add_theme_font_size_override("font_size", 9)
	masteries_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	character_visual.bind_data(data)
	character_visual.set_visual_scale(1.10)
	_layout_contents()


func set_pick_number(number: int) -> void:
	pick_number = number
	_update_style()


func _layout_contents() -> void:
	if not is_node_ready():
		return
	var inset := 11.0
	character_name.position = Vector2(inset, 6.0)
	character_name.size = Vector2(size.x - inset * 2.0, 34.0)
	character_visual.position = Vector2(size.x * 0.5, 149.0)
	stats_label.position = Vector2(inset, 167.0)
	stats_label.size = Vector2(size.x - inset * 2.0, 72.0)
	masteries_label.position = Vector2(inset, 231.0)
	masteries_label.size = Vector2(size.x - inset * 2.0, 24.0)
	details_button.position = Vector2(inset, size.y - 38.0)
	details_button.size = Vector2(size.x - inset * 2.0, 24.0)


func _update_style() -> void:
	var picked := pick_number > 0
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.030, 0.065, 0.049, 0.97)
	normal.border_color = Color(1.0, 0.23, 0.62) if picked else Color(0.20, 0.78, 0.42)
	normal.set_border_width_all(3 if picked else 1)
	normal.set_corner_radius_all(5)
	normal.shadow_color = Color(1.0, 0.10, 0.58, 0.40) if picked else Color(0.05, 0.72, 0.30, 0.19)
	normal.shadow_size = 9 if picked else 3
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("pressed", normal)
	add_theme_stylebox_override("focus", normal)
	_palette_call("bind_style", [normal, "surface",
		"selection" if picked else "structure",
		"selection" if picked else "structure"])
	for key in ["normal", "pressed", "focus"]:
		_palette_call("bind_control_style", [self, key, "surface",
			"selection" if picked else "structure"])
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.49, 0.78)
	hover.shadow_color = Color(1.0, 0.2, 0.63, 0.30)
	hover.shadow_size = 6
	add_theme_stylebox_override("hover", hover)
	_palette_call("bind_style", [hover, "surface_hover", "selection", "selection"])
	_palette_call("bind_control_style", [self, "hover", "surface_hover", "selection"])
	add_theme_color_override("font_color", Color.TRANSPARENT)
	character_name.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	stats_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	masteries_label.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	for label in [character_name, stats_label, masteries_label]:
		_palette_call("bind_color", [label, "font_color", "primary"])
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.025, 0.090, 0.115, 0.96)
	detail_style.border_color = Color(0.28, 0.82, 0.94)
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(3)
	details_button.add_theme_stylebox_override("normal", detail_style)
	_palette_call("bind_style", [detail_style, "button", "structure"])
	_palette_call("bind_control_style", [details_button, "normal", "button", "structure"])
	var detail_highlight := detail_style.duplicate() as StyleBoxFlat
	detail_highlight.bg_color = Color(0.17, 0.045, 0.11, 0.98)
	detail_highlight.border_color = Color(1.0, 0.36, 0.70)
	detail_highlight.set_border_width_all(2)
	detail_highlight.shadow_color = Color(1.0, 0.16, 0.60, 0.30)
	detail_highlight.shadow_size = 4
	details_button.add_theme_stylebox_override("hover", detail_highlight)
	details_button.add_theme_stylebox_override("pressed", detail_highlight)
	details_button.add_theme_stylebox_override("focus", detail_highlight)
	_palette_call("bind_style", [detail_highlight, "button_hover", "selection",
		"selection"])
	for key in ["hover", "pressed", "focus"]:
		_palette_call("bind_control_style", [details_button, key,
			"button_hover", "selection", "selection"])
	details_button.add_theme_color_override("font_color", Color(0.94, 0.98, 1.0))
	details_button.add_theme_color_override("font_hover_color", Color.WHITE)
	details_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_palette_call("bind_color", [details_button, key, "on_button"])


func _palette_call(method: String, args: Array) -> void:
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service != null:
		palette_service.callv(method, args)
