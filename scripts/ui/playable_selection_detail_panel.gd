extends Control

const NARRATIVE_FONT := preload("res://scripts/ui/ui_narrative_font.gd")

## Ficha pré-jogo: lê os mesmos Resources que alimentam a ficha em campanha,
## sem inventar equipamento, Vida atual ou Skills ainda não adquiridas.
var _name: Label
var _stats: Label
var _description: Label
var _skills: VBoxContainer
var _panel: PanelContainer
var _scroll: ScrollContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.76)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			hide())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.065, 0.99)
	style.border_color = Color(0.28, 0.82, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	_name = Label.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	header.add_child(_name)
	var close := Button.new()
	close.text = "Esc ou  ✕"
	close.custom_minimum_size = Vector2(90, 34)
	close.pressed.connect(hide)
	header.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_scroll)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(body)
	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 14)
	_stats.add_theme_color_override("font_color", Color(0.72, 0.89, 0.95))
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_stats)
	_description = Label.new()
	_description.add_theme_font_size_override("font_size", 13)
	_description.add_theme_color_override("font_color", Color(0.87, 0.90, 0.95))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NARRATIVE_FONT.apply_label(_description)
	body.add_child(_description)
	_skills = VBoxContainer.new()
	_skills.add_theme_constant_override("separation", 6)
	body.add_child(_skills)
	resized.connect(_fit_panel)
	_fit_panel()
	hide()


func _fit_panel() -> void:
	if _panel != null:
		_panel.custom_minimum_size = Vector2(
			minf(600.0, maxf(280.0, size.x - 28.0)),
			minf(540.0, maxf(240.0, size.y - 28.0)))


func open_for(data: EntityData) -> void:
	if data == null:
		return
	_name.text = data.display_name.to_upper()
	var masteries: Array[String] = []
	for mastery in data.maestrias:
		match mastery:
			EntityData.Mastery.BLADE: masteries.append("Lâmina")
			EntityData.Mastery.IMPACT: masteries.append("Impacto")
			EntityData.Mastery.RANGED: masteries.append("Distância")
	_stats.text = "VIDA: %d     ATAQUE: %d     ESTAMINA: %d\nMAESTRIAS: %s" % [
		data.vida_base, data.ataque_base, data.stamina_base,
		", ".join(masteries) if not masteries.is_empty() else "SEM MAESTRIA"]
	var description := data.description.strip_edges()
	if description.is_empty():
		description = data.narrative_description.strip_edges()
	_description.text = description if not description.is_empty() else "Sem descrição cadastrada."
	for child in _skills.get_children():
		_skills.remove_child(child)
		child.queue_free()
	for skill in data.skill_ativas:
		if skill != null:
			_add_skill("ATIVA", skill.display_name, skill.description)
	for skill in data.skill_passivas:
		if skill != null:
			_add_skill("PASSIVA", skill.display_name, skill.description)
	_scroll.scroll_vertical = 0
	show()


func _add_skill(kind: String, title: String, description: String) -> void:
	var heading := Label.new()
	heading.text = "%s · %s" % [kind, title]
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.52, 0.83, 0.96)
		if kind == "ATIVA" else Color(1.0, 0.68, 0.84))
	_skills.add_child(heading)
	var explanation := Label.new()
	explanation.text = description.strip_edges() if not description.strip_edges().is_empty() \
		else "Sem descrição cadastrada."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NARRATIVE_FONT.apply_label(explanation)
	explanation.add_theme_font_size_override("font_size", 12)
	explanation.add_theme_color_override("font_color", Color(0.87, 0.90, 0.95))
	_skills.add_child(explanation)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()
