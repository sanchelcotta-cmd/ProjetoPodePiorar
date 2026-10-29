extends CanvasLayer

## Interface interna. Não é instanciada na exportação pública release.
const SERVICE := preload("res://scripts/managers/debug_command_service.gd")
const BUG_ICON := preload("res://scripts/ui/debug_bug_icon.gd")
const CATEGORIES := [
	["event", "Eventos e outcomes"], ["encounter", "Encontros"],
	["item", "Itens"], ["ally", "Aliados"],
	["active", "Ativas"], ["passive", "Passivas"],
	["debuff", "Efeitos / debuffs"], ["information", "Informações"],
	["attribute", "Atributos"], ["time", "Tempo / Rodada"],
	["anomaly", "Anomalias do mapa"],
]
const ANOMALIES := [
	{"id": &"", "name": "Aleatória"},
	{"id": &"anomalia_lixo", "name": "Saco de lixo com pés"},
	{"id": &"anomalia_lixeira", "name": "Duende na lixeira"},
	{"id": &"anomalia_arvore", "name": "Árvore de fogo"},
	{"id": &"anomalia_poste", "name": "Mão no poste"},
	{"id": &"anomalia_galo", "name": "Galo ao fundo"},
	{"id": &"anomalia_ovni", "name": "OVNI no céu"},
]
const CYAN := Color(0.19, 0.83, 0.92)
const PINK := Color(0.98, 0.17, 0.59)
const GOLD := Color(0.96, 0.75, 0.20)
const WHITE := Color(0.90, 0.94, 0.96)

var service := SERVICE.new()
var _root: Control
var _bug: Button
var _shade: ColorRect
var _frame: PanelContainer
var _kind: OptionButton
var _resource: OptionButton
var _actor: OptionButton
var _outcome: OptionButton
var _amount: SpinBox
var _district: OptionButton
var _status: Label
var _normal: Button
var _force: Button
var _undo: Button
var _rows: Array[Dictionary] = []
var _actors: Array[EntityState] = []
var _dragging := false
var _drag_moved := false
var _drag_mouse_origin := Vector2.ZERO
var _drag_button_origin := Vector2.ZERO


func _ready() -> void:
	if not SERVICE.is_enabled():
		queue_free()
		return
	layer = 190
	service.setup(get_parent())
	_build()
	get_viewport().size_changed.connect(_clamp_bug)
	call_deferred("_clamp_bug")


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bug = Button.new()
	_bug.name = "DebugBugButton"
	_bug.tooltip_text = "Depuração interna · arraste para mover"
	_bug.custom_minimum_size = Vector2(44, 44)
	_bug.size = Vector2(44, 44)
	_bug.position = Vector2(get_viewport().get_visible_rect().size.x - 62, 165)
	_bug.add_theme_stylebox_override("normal", _style(Color(0.025, 0.055, 0.075, 0.98), CYAN, 22))
	_bug.add_theme_stylebox_override("hover", _style(Color(0.055, 0.14, 0.17, 0.99), GOLD, 22))
	_bug.add_theme_stylebox_override("pressed", _style(Color(0.09, 0.19, 0.22, 1), PINK, 22))
	_bug.mouse_filter = Control.MOUSE_FILTER_STOP
	_bug.gui_input.connect(_on_bug_input)
	_root.add_child(_bug)
	var glyph := Control.new()
	glyph.set_script(BUG_ICON)
	glyph.custom_minimum_size = Vector2(42, 42)
	glyph.size = Vector2(42, 42)
	glyph.position = Vector2(1, 1)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bug.add_child(glyph)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0, 0, 0, 0.72)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.visible = false
	_root.add_child(_shade)
	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_frame.offset_left = -340
	_frame.offset_top = -290
	_frame.offset_right = 340
	_frame.offset_bottom = 290
	_frame.add_theme_stylebox_override("panel", _style(Color(0.015, 0.025, 0.035, 0.98), CYAN, 5))
	_shade.add_child(_frame)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_frame.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	var title := Label.new()
	title.text = "DEPURAÇÃO INTERNA"
	title.add_theme_color_override("font_color", CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := _button("×  FECHAR", PINK)
	close.pressed.connect(close_panel)
	heading.add_child(close)
	_label(content, "SOMENTE DESENVOLVIMENTO · comandos afetam a campanha atual", GOLD)
	_kind = _picker(content, "Categoria")
	for pair in CATEGORIES:
		_kind.add_item(pair[1])
	_kind.item_selected.connect(func(_index: int) -> void: _refresh_category())
	_resource = _picker(content, "Resource / ID")
	_resource.item_selected.connect(func(_index: int) -> void: _refresh_outcomes())
	_actor = _picker(content, "Personagem / dono / ativador")
	_actor.item_selected.connect(func(_index: int) -> void: _refresh_status())
	_outcome = _picker(content, "Outcome específico (opcional)")
	_outcome.item_selected.connect(func(_index: int) -> void: _refresh_status())
	var amount_row := HBoxContainer.new()
	content.add_child(amount_row)
	_label(amount_row, "Variação do atributo:", WHITE)
	_amount = SpinBox.new()
	_amount.min_value = -999
	_amount.max_value = 999
	_amount.value = 1
	_amount.custom_minimum_size.x = 150
	amount_row.add_child(_amount)
	_district = _picker(content, "Distrito da próxima Rodada")
	for district in [["suburbio", "Subúrbio"], ["baixo_centro", "Baixo-Centro"],
			["centro", "Centro"]]:
		_district.add_item(district[1])
	var divider := HSeparator.new()
	content.add_child(divider)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 67
	_status.add_theme_color_override("font_color", WHITE)
	content.add_child(_status)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	content.add_child(actions)
	_normal = _button("EXECUTAR NORMAL", CYAN)
	_normal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_normal.pressed.connect(func() -> void: _execute(false))
	actions.add_child(_normal)
	_force = _button("FORÇAR · DEBUG", GOLD)
	_force.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_force.pressed.connect(func() -> void: _execute(true))
	actions.add_child(_force)
	_undo = _button("DESFAZER ÚLTIMO", PINK)
	_undo.pressed.connect(func() -> void:
		_show_result(service.undo_last()))
	content.add_child(_undo)
	_refresh_category()


func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _button(title: String, color: Color) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 34
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.03, 0.055, 0.07, 0.98), color, 3))
	button.add_theme_stylebox_override("hover", _style(Color(0.065, 0.13, 0.16, 1), color.lightened(0.3), 3))
	return button


func _label(parent: Node, title: String, color: Color) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _picker(parent: Node, title: String) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 210
	label.add_theme_color_override("font_color", CYAN)
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 32
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_stylebox_override("normal", _style(Color(0.035, 0.06, 0.075, 0.98), CYAN, 3))
	row.add_child(option)
	return option


func _kind_id() -> String:
	return str(CATEGORIES[_kind.selected][0]) if _kind.selected >= 0 else ""


func _selected_id() -> StringName:
	return _rows[_resource.selected]["id"] if _resource.selected >= 0 \
		and _resource.selected < _rows.size() else &""


func _selected_actor() -> EntityState:
	return _actors[_actor.selected] if _actor.selected >= 0 \
		and _actor.selected < _actors.size() else null


func _selected_outcome() -> StringName:
	return StringName(str(_outcome.get_item_metadata(_outcome.selected))) \
		if _outcome.selected > 0 else &""


func _refresh_category() -> void:
	var kind := _kind_id()
	_rows.clear()
	if kind == "anomaly":
		for row in ANOMALIES:
			_rows.append(row.duplicate(true))
	elif kind != "time":
		_rows.assign(service.catalog(kind))
	_resource.clear()
	for row in _rows:
		_resource.add_item("%s  [%s]" % [row["name"], row["id"]])
		_resource.set_item_tooltip(_resource.item_count - 1,
			"%s\nID: %s" % [row["name"], row["id"]])
	_resource.get_parent().visible = kind != "time"
	_actor.get_parent().visible = kind not in ["time", "information", "anomaly"]
	_outcome.get_parent().visible = kind == "event"
	_amount.get_parent().visible = kind == "attribute"
	_district.get_parent().visible = kind == "time"
	_refresh_actors()
	_refresh_outcomes()


func _refresh_actors() -> void:
	_actors = service.actors()
	_actor.clear()
	for actor in _actors:
		_actor.add_item("%s  [%s]" % [actor.visible_name(), actor.instance_id])


func _refresh_outcomes() -> void:
	_outcome.clear()
	_outcome.add_item("Resultado normal do Evento")
	if _kind_id() == "event" and _resource.selected >= 0 \
			and _resource.selected < _rows.size():
		var event := _rows[_resource.selected]["resource"] as EventData
		for outcome in event.outcomes:
			if outcome != null and outcome.id != &"":
				_outcome.add_item("%s  [%s]" % [outcome.display_name, outcome.id])
				_outcome.set_item_metadata(_outcome.item_count - 1, str(outcome.id))
				_outcome.set_item_tooltip(_outcome.item_count - 1,
					"%s\nID: %s" % [outcome.display_name, outcome.id])
	_refresh_status()


func _refresh_status() -> void:
	if _kind_id() == "anomaly":
		_status.text = "Força uma anomalia no mapa atual, inclusive no dia 1. " \
			+ "A decoração é refeita a partir da mesma semente."
		_normal.disabled = true
		_force.disabled = not service.campaign_ready()
		return
	if _kind_id() == "time":
		_status.text = "Avanço normal exige Informação e fase livre. Forçar ignora a exigência de Informação, mas nunca interrompe uma ação."
		_normal.disabled = not service.campaign_ready() or not service.rounds.can_advance()
		_force.disabled = not service.campaign_ready()
		return
	var check := service.inspect(_kind_id(), _selected_id(),
		_selected_actor(), _selected_outcome())
	_status.text = str(check.get("reason", ""))
	if check.get("impossible_in_normal_campaign", false):
		_status.text += "\n⚠ ESTADO IMPOSSÍVEL EM CAMPANHA NORMAL"
	_status.add_theme_color_override("font_color", GOLD if check.get("forceable", false) else WHITE)
	_normal.disabled = not check.get("eligible", false)
	_force.disabled = not check.get("forceable", false) and not (
		_kind_id() == "event" and _selected_outcome() != &""
		and check.get("eligible", false))
	if _kind_id() == "event" and _selected_outcome() != &"":
		_normal.disabled = true # Outcome específico sempre exige confirmação de força.


func _execute(force: bool) -> void:
	var result: Dictionary
	if _kind_id() == "anomaly":
		var map_view := get_parent() as PPPMapView
		var exploration_map := map_view != null and map_view.grid != null \
			and map_view.grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION
		var success := force and map_view != null \
			and map_view.force_decoration_anomaly(_selected_id())
		result = {"success": success, "reason": "Anomalia forçada no mapa atual." \
			if success else "Abra um mapa de exploração para forçar a anomalia." \
			if not exploration_map else "Não foi possível colocar esta anomalia " \
			+ "sem violar os espaços seguros do mapa."}
	elif _kind_id() == "time":
		var districts := [&"suburbio", &"baixo_centro", &"centro"]
		result = service.advance_time(districts[_district.selected], force)
	else:
		result = service.execute(_kind_id(), _selected_id(), _selected_actor(),
			int(_amount.value), force, _selected_outcome())
	_show_result(result)
	if result.get("success", false):
		_refresh_actors()
		_refresh_status()
		if _kind_id() in ["event", "encounter", "time", "anomaly"]:
			close_panel()


func _show_result(result: Dictionary) -> void:
	_status.text = ("✓ " if result.get("success", false) else "✕ ") + \
		str(result.get("reason", "Comando encaminhado ao gestor real."))
	if result.get("impossible_in_normal_campaign", false):
		_status.text += "\n⚠ ESTADO IMPOSSÍVEL EM CAMPANHA NORMAL"


func open_panel() -> void:
	_refresh_actors()
	_refresh_status()
	_shade.visible = true
	_bug.visible = false


func close_panel() -> void:
	_shade.visible = false
	_bug.visible = true
	_bug.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if _shade != null and _shade.visible and event is InputEventKey \
			and event.pressed and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()


func _on_bug_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_moved = false
			_drag_mouse_origin = _bug.get_global_mouse_position()
			_drag_button_origin = _bug.position
		else:
			_finish_drag()


func _process(_delta: float) -> void:
	if not _dragging:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()
		return
	var delta := _bug.get_global_mouse_position() - _drag_mouse_origin
	if delta.length() > 4:
		_drag_moved = true
	_bug.position = _drag_button_origin + delta
	_clamp_bug()


func _finish_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if not _drag_moved:
		open_panel()


func _clamp_bug() -> void:
	if _bug == null:
		return
	var bounds := get_viewport().get_visible_rect().size
	_bug.position = _bug.position.clamp(Vector2(8, 8),
		Vector2(maxf(8, bounds.x - 52), maxf(8, bounds.y - 52)))
