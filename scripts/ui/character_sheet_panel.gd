class_name CharacterSheetPanel
extends PanelContainer

## Janela somente de leitura. A página 1 mostra as habilidades de origem
## inata; cada página seguinte comporta até quatro concessões da campanha.
signal close_requested
signal stat_hover_requested(actor: EntityState, stat_key: String, anchor: Rect2)
signal stat_hover_ended

const ACQUIRED_PER_PAGE := 4
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const PORTRAIT_PROVIDER := preload("res://scripts/ui/entity_portrait_provider.gd")

@onready var name_label: Label = $Margin/Content/Header/Name
@onready var drag_header: Control = $Margin/Content/Header
@onready var close_button: Button = $Margin/Content/Header/Close
@onready var portrait: TextureRect = $Margin/Content/Summary/Portrait
@onready var health_label: Label = $Margin/Content/Summary/Stats/Health
@onready var attack_label: Label = $Margin/Content/Summary/Stats/Attack
@onready var stamina_label: Label = $Margin/Content/Summary/Stats/Stamina
@onready var conditions_label: Label = $Margin/Content/Summary/Stats/Conditions
@onready var description_label: Label = $Margin/Content/Description
@onready var page_heading: Label = $Margin/Content/PageHeading
@onready var skill_scroll: ScrollContainer = $Margin/Content/SkillScroll
@onready var skill_list: VBoxContainer = $Margin/Content/SkillScroll/SkillList
@onready var previous_button: Button = $Margin/Content/Pagination/Previous
@onready var next_button: Button = $Margin/Content/Pagination/Next
@onready var page_count_label: Label = $Margin/Content/Pagination/PageCount

var actor: EntityState
var skill_manager: SkillManager
var page_index := 0
var _grant_signature := ""
var _open_tween: Tween
var _open_generation := 0
var _dragging := false
var _drag_offset := Vector2.ZERO
var user_positioned := false


func _ready() -> void:
	drag_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	name_label.add_theme_font_override("font", BOLD_FONT)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	previous_button.pressed.connect(_previous_page)
	next_button.pressed.connect(_next_page)
	for pair in [[health_label, "max_hp"], [attack_label, "attack"],
			[stamina_label, "stamina"]]:
		var label := pair[0] as Label
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_entered.connect(_on_stat_entered.bind(pair[1], label))
		label.mouse_exited.connect(func() -> void: stat_hover_ended.emit())


func open_for(target: EntityState, manager: SkillManager, anchor: Vector2) -> void:
	if target == null or target.data == null:
		return
	if actor != null and actor.appearance_changed.is_connected(_refresh_identity):
		actor.appearance_changed.disconnect(_refresh_identity)
	actor = target
	actor.appearance_changed.connect(_refresh_identity)
	user_positioned = false
	skill_manager = manager
	page_index = 0
	_grant_signature = ""
	_refresh_identity()
	refresh_live()
	_render_page()
	show()
	_open_generation += 1
	modulate.a = 0.0
	_place_after_layout(anchor, _open_generation)


func _place_after_layout(anchor: Vector2, generation: int) -> void:
	# O Godot mede textos longos antes de saber a largura da janela. Esperar
	# um frame permite fixar 420×480 sem a janela crescer fora da tela.
	await get_tree().process_frame
	if not visible or generation != _open_generation:
		return
	size = custom_minimum_size
	# A ficha salta para o lado do balão, mas permanece dentro da tela.
	var screen := get_viewport_rect().size
	var panel_size := Vector2(maxf(size.x, custom_minimum_size.x),
		maxf(size.y, custom_minimum_size.y))
	var target_x := anchor.x + 30.0
	if target_x + panel_size.x > screen.x - 8.0:
		target_x = anchor.x - panel_size.x - 30.0
	var destination := Vector2(clampf(target_x, 8.0,
		maxf(8.0, screen.x - panel_size.x - 8.0)),
		clampf(anchor.y - panel_size.y * 0.32, 56.0,
			maxf(56.0, screen.y - panel_size.y - 8.0)))
	if _open_tween != null and _open_tween.is_running():
		_open_tween.kill()
	position = destination - Vector2(14.0, 0.0)
	_open_tween = create_tween().set_parallel(true)
	_open_tween.tween_property(self, "position", destination, 0.17) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "modulate:a", 1.0, 0.17)


func close_sheet() -> void:
	_dragging = false
	_open_generation += 1
	if _open_tween != null and _open_tween.is_running():
		_open_tween.kill()
	hide()
	if actor != null and actor.appearance_changed.is_connected(_refresh_identity):
		actor.appearance_changed.disconnect(_refresh_identity)
	actor = null
	skill_manager = null
	_grant_signature = ""


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and drag_header.get_global_rect().has_point(event.position) \
				and not close_button.get_global_rect().has_point(event.position):
			_dragging = true
			_drag_offset = event.position - global_position
		elif not event.pressed:
			_dragging = false
	if visible and _dragging and event is InputEventMouseMotion:
		var screen := get_viewport_rect().size
		global_position = Vector2(
			clampf(event.position.x - _drag_offset.x, 15.0,
				maxf(15.0, screen.x - size.x - 15.0)),
			clampf(event.position.y - _drag_offset.y, 15.0,
				maxf(15.0, screen.y - size.y - 15.0)))
		user_positioned = true
	if visible and event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func refresh_live() -> void:
	if actor == null or actor.data == null:
		return
	health_label.text = "VIDA: %d / %d" % [actor.current_health, actor.max_health]
	attack_label.text = "ATAQUE: %d" % actor.attack
	stamina_label.text = "ESTAMINA: %d / %d" % [actor.stamina_remaining,
		actor.max_stamina]
	var names: Array[String] = []
	for instance in actor.debuffs:
		if instance != null and instance.data != null:
			names.append(instance.data.display_name)
	conditions_label.text = "CONDIÇÕES: %s" % (
		", ".join(names) if not names.is_empty() else "Nenhuma")
	var signature := _current_grant_signature()
	if signature != _grant_signature:
		_grant_signature = signature
		page_index = mini(page_index, _page_count() - 1)
		_render_page()


func _refresh_identity() -> void:
	var identity := actor.visual_data()
	name_label.text = actor.visible_name().to_upper()
	var description := identity.description.strip_edges()
	if description.is_empty():
		description = identity.narrative_description.strip_edges()
	description_label.text = description if not description.is_empty() else \
		"Sem descrição cadastrada."
	portrait.texture = PORTRAIT_PROVIDER.for_state(actor)


func _all_grants() -> Array[SkillGrantState]:
	var result: Array[SkillGrantState] = []
	if actor == null or skill_manager == null:
		return result
	result.append_array(skill_manager.get_active_grants(actor))
	result.append_array(skill_manager.get_passive_grants(actor))
	return result


func _acquired_grants() -> Array[SkillGrantState]:
	var result: Array[SkillGrantState] = []
	for grant in _all_grants():
		if grant.source_kind != &"innate":
			result.append(grant)
	return result


func _page_count() -> int:
	return 1 + ceili(float(_acquired_grants().size()) / float(ACQUIRED_PER_PAGE))


func _current_grant_signature() -> String:
	var parts: Array[String] = []
	for grant in _all_grants():
		parts.append("%s|%s|%s" % [grant.source_kind, grant.source_id,
			grant.skill.resource_path if grant.skill != null else ""])
	return ";".join(parts)


func _render_page() -> void:
	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()
	if actor == null:
		return
	var entries: Array[SkillGrantState] = []
	if page_index == 0:
		page_heading.text = "HABILIDADES INICIAIS"
		for grant in _all_grants():
			if grant.source_kind == &"innate":
				entries.append(grant)
	else:
		page_heading.text = "HABILIDADES ADQUIRIDAS"
		var acquired := _acquired_grants()
		var first := (page_index - 1) * ACQUIRED_PER_PAGE
		for index in range(first, mini(first + ACQUIRED_PER_PAGE, acquired.size())):
			entries.append(acquired[index])
	for grant in entries:
		_add_skill_entry(grant)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma habilidade nesta página."
		empty.add_theme_color_override("font_color", Color(0.7, 0.74, 0.77))
		skill_list.add_child(empty)
	skill_scroll.scroll_vertical = 0
	page_count_label.text = "%d / %d" % [page_index + 1, _page_count()]
	previous_button.disabled = page_index == 0
	next_button.disabled = page_index >= _page_count() - 1
	_shrink_after_layout()


func _shrink_after_layout() -> void:
	await get_tree().process_frame
	if visible:
		size = custom_minimum_size


func _add_skill_entry(grant: SkillGrantState) -> void:
	if grant.skill == null:
		return
	var skill := grant.skill
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.16, 0.85)
	style.border_color = Color(0.24, 0.48, 0.54, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	card.add_theme_stylebox_override("panel", style)
	skill_list.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 9)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	margin.add_child(content)
	var title := Label.new()
	title.text = "%s · %s" % ["ATIVA" if skill is ActiveSkillData else "PASSIVA",
		skill.display_name]
	title.add_theme_font_override("font", BOLD_FONT)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.35) \
		if skill is ActiveSkillData else Color(0.48, 0.88, 0.85))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	if grant.source_kind != &"innate":
		var origin := Label.new()
		origin.text = "ORIGEM: %s" % _source_name(grant.source_kind)
		origin.add_theme_font_size_override("font_size", 10)
		origin.add_theme_color_override("font_color", Color(0.7, 0.75, 0.78))
		content.add_child(origin)
	var description := Label.new()
	description.text = skill.description.strip_edges() if not skill.description.strip_edges().is_empty() \
		else "Sem descrição cadastrada."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", Color(0.9, 0.92, 0.94))
	content.add_child(description)


func _source_name(source_kind: StringName) -> String:
	match source_kind:
		&"event", &"permanent_effect": return "Evento"
		&"item", &"equipment": return "Item"
		&"copied_trait": return "Habilidade herdada"
	return String(source_kind).replace("_", " ").capitalize()


func _previous_page() -> void:
	page_index = maxi(0, page_index - 1)
	_render_page()


func _next_page() -> void:
	page_index = mini(_page_count() - 1, page_index + 1)
	_render_page()


func _on_stat_entered(stat_key: String, label: Label) -> void:
	if actor != null:
		stat_hover_requested.emit(actor, stat_key, label.get_global_rect())
