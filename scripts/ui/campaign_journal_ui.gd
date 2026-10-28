class_name CampaignJournalUI
extends Control

## Duas leituras do mesmo histórico factual: livro completo e resumo lateral.
## A seleção 2/4/5 representa entradas registradas, não linhas de pixel.

const CYAN := Color(0.22, 0.85, 0.94)
const BLUE := Color(0.42, 0.68, 0.98)
const HOSTILE := Color(1.0, 0.39, 0.43)
const PINK := Color(1.0, 0.40, 0.69)
const GREEN := Color(0.45, 0.91, 0.62)
const GOLD := Color(1.0, 0.83, 0.35)
const WHITE := Color(0.92, 0.95, 0.96)
const MUTED := Color(0.64, 0.73, 0.77)
const PANEL_BG := Color(0.025, 0.045, 0.057, 0.96)
const ROW_BG := Color(0.05, 0.075, 0.09, 0.96)

var campaign: CampaignState
var summary_count := 2
var summary_expanded := true
var summary_frame: PanelContainer
var summary_rows: VBoxContainer
var expand_tab: Button
var info_hint: PanelContainer
var backdrop: ColorRect
var book_window: PanelContainer
var book_rows: VBoxContainer
var book_count: Label
var book_scroll: ScrollContainer
var book_previous: Button
var book_next: Button
var book_context: Label
var book_pages: Array[Dictionary] = []
var book_page_index := -1
var _summary_dragging := false
var _summary_user_y := -1.0
var _tab_dragging := false
var _tab_was_dragged := false
var _tab_drag_distance := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_summary()
	_build_book()
	resized.connect(_layout)
	_layout()
	_refresh()


func bind_campaign(value: CampaignState) -> void:
	if campaign != null and campaign.journal_entry_added.is_connected(_on_entry_added):
		campaign.journal_entry_added.disconnect(_on_entry_added)
	campaign = value
	if campaign != null:
		campaign.journal_entry_added.connect(_on_entry_added)
	_refresh()


func open_book() -> void:
	book_page_index = -1
	_rebuild_book()
	summary_frame.hide()
	expand_tab.hide()
	info_hint.hide()
	backdrop.show()
	book_window.show()
	_layout()
	book_window.grab_focus()


func close_book() -> void:
	book_window.hide()
	backdrop.hide()
	summary_frame.visible = summary_expanded
	expand_tab.visible = not summary_expanded


func is_book_open() -> bool:
	return book_window != null and book_window.visible


func _on_entry_added(_entry: Dictionary) -> void:
	_refresh_summary()
	if is_book_open():
		_rebuild_book()


func _refresh() -> void:
	if summary_rows == null:
		return
	_refresh_summary()
	if is_book_open():
		_rebuild_book()


func _build_summary() -> void:
	summary_frame = PanelContainer.new()
	summary_frame.name = "JournalSummary"
	summary_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	summary_frame.add_theme_stylebox_override("panel", _box(PANEL_BG, CYAN, 1, 0))
	add_child(summary_frame)
	var outer := MarginContainer.new()
	_set_margins(outer, 11, 11, 9, 10)
	summary_frame.add_child(outer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	outer.add_child(stack)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	header.gui_input.connect(_on_summary_header_input)
	header.add_theme_constant_override("separation", 6)
	stack.add_child(header)
	var title := _label("RESUMO DE REGISTRO", 12, CYAN)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	var count_selector := OptionButton.new()
	count_selector.name = "VisibleLines"
	count_selector.tooltip_text = "Quantidade de registros recentes"
	count_selector.custom_minimum_size = Vector2(46, 29)
	for amount in [2, 4, 5]:
		count_selector.add_item(str(amount))
	count_selector.selected = 0
	count_selector.add_theme_font_size_override("font_size", 12)
	count_selector.add_theme_color_override("font_color", WHITE)
	count_selector.add_theme_stylebox_override("normal", _box(ROW_BG, CYAN, 1, 4))
	count_selector.add_theme_stylebox_override("hover", _box(Color(0.07, 0.17, 0.21, 1), CYAN, 1, 4))
	count_selector.item_selected.connect(func(index: int) -> void:
		summary_count = [2, 4, 5][index]
		_refresh_summary())
	header.add_child(count_selector)
	var info_button := Button.new()
	info_button.text = "ⓘ"
	info_button.tooltip_text = "Abra Registros na barra superior para ler o livro completo."
	info_button.custom_minimum_size = Vector2(25, 29)
	info_button.flat = true
	info_button.add_theme_color_override("font_color", CYAN)
	info_button.add_theme_color_override("font_hover_color", WHITE)
	info_button.add_theme_font_size_override("font_size", 17)
	info_button.mouse_entered.connect(func() -> void: info_hint.show())
	info_button.mouse_exited.connect(func() -> void: info_hint.hide())
	info_button.pressed.connect(func() -> void: info_hint.visible = not info_hint.visible)
	header.add_child(info_button)
	var minimize := Button.new()
	minimize.text = "›"
	minimize.tooltip_text = "Recolher o resumo para a lateral"
	minimize.custom_minimum_size = Vector2(24, 29)
	minimize.flat = true
	minimize.add_theme_color_override("font_color", CYAN)
	minimize.add_theme_color_override("font_hover_color", WHITE)
	minimize.add_theme_font_size_override("font_size", 21)
	minimize.pressed.connect(_set_summary_expanded.bind(false))
	header.add_child(minimize)
	var separator := HSeparator.new()
	stack.add_child(separator)
	summary_rows = VBoxContainer.new()
	summary_rows.add_theme_constant_override("separation", 5)
	stack.add_child(summary_rows)
	expand_tab = Button.new()
	expand_tab.name = "ExpandJournalSummary"
	expand_tab.text = "‹"
	expand_tab.tooltip_text = "Clique para mostrar; segure e arraste para mover"
	expand_tab.mouse_default_cursor_shape = Control.CURSOR_MOVE
	expand_tab.custom_minimum_size = Vector2(29, 40)
	expand_tab.add_theme_font_size_override("font_size", 23)
	expand_tab.add_theme_color_override("font_color", CYAN)
	expand_tab.add_theme_stylebox_override("normal", _box(PANEL_BG, CYAN, 1, 5))
	expand_tab.add_theme_stylebox_override("hover", _box(Color(0.05, 0.17, 0.21, 0.98), WHITE, 1, 5))
	expand_tab.gui_input.connect(_on_expand_tab_input)
	expand_tab.pressed.connect(_on_expand_tab_pressed)
	add_child(expand_tab)
	expand_tab.hide()
	info_hint = PanelContainer.new()
	info_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_hint.add_theme_stylebox_override("panel", _box(PANEL_BG, CYAN, 1, 7))
	add_child(info_hint)
	var hint := _label("Aqui aparecem apenas as últimas ações.\nAbra REGISTROS na barra superior para ler o livro completo.", 11, WHITE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UINarrativeFont.apply_label(hint)
	hint.custom_minimum_size = Vector2(280, 0)
	info_hint.add_child(hint)
	info_hint.hide()


func _build_book() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0, 0, 0, 0.65)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and event.pressed:
			close_book())
	add_child(backdrop)
	backdrop.hide()
	book_window = PanelContainer.new()
	book_window.name = "JournalBook"
	book_window.focus_mode = Control.FOCUS_ALL
	book_window.mouse_filter = Control.MOUSE_FILTER_STOP
	book_window.add_theme_stylebox_override("panel", _box(PANEL_BG, CYAN, 2, 3))
	add_child(book_window)
	var outer := MarginContainer.new()
	_set_margins(outer, 18, 18, 14, 15)
	book_window.add_child(outer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	outer.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var heading := _label("▤ LIVRO DE REGISTROS", 18, CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	book_count = _label("", 11, MUTED)
	book_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(book_count)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.custom_minimum_size = Vector2(30, 28)
	close_button.add_theme_color_override("font_color", HOSTILE)
	close_button.add_theme_color_override("font_hover_color", WHITE)
	close_button.add_theme_stylebox_override("normal", _box(ROW_BG, HOSTILE, 1, 4))
	close_button.add_theme_stylebox_override("hover", _box(Color(0.27, 0.06, 0.08, 1), HOSTILE, 1, 4))
	close_button.pressed.connect(close_book)
	header.add_child(close_button)
	stack.add_child(HSeparator.new())
	var intro := _label("AÇÕES, DECISÕES E RESULTADOS DA CAMPANHA", 11, MUTED)
	stack.add_child(intro)
	book_scroll = ScrollContainer.new()
	book_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	book_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stack.add_child(book_scroll)
	book_rows = VBoxContainer.new()
	book_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_rows.add_theme_constant_override("separation", 4)
	book_scroll.add_child(book_rows)
	var navigation := HBoxContainer.new()
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 15)
	stack.add_child(navigation)
	book_previous = _navigation_button("◀", "Período anterior registrado")
	book_previous.pressed.connect(_change_book_page.bind(-1))
	navigation.add_child(book_previous)
	book_context = _label("", 12, CYAN)
	book_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book_context.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	book_context.custom_minimum_size.x = 250
	navigation.add_child(book_context)
	book_next = _navigation_button("▶", "Próximo período registrado")
	book_next.pressed.connect(_change_book_page.bind(1))
	navigation.add_child(book_next)
	book_window.hide()


func _set_summary_expanded(expanded: bool) -> void:
	summary_expanded = expanded
	summary_frame.visible = expanded
	expand_tab.visible = not expanded
	info_hint.hide()
	_layout()


func _refresh_summary() -> void:
	_clear(summary_rows)
	var entries := _visible_entries()
	if entries.is_empty():
		var empty := _label("Nenhuma ação registrada ainda.", 11, MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_rows.add_child(empty)
	else:
		for index in range(entries.size() - 1,
				maxi(-1, entries.size() - summary_count - 1), -1):
			var entry: Dictionary = entries[index]
			var row := _entry_text(entry, true)
			row.custom_minimum_size.y = 24
			summary_rows.add_child(row)
	# RichTextLabel só estabiliza a altura após receber a largura do painel.
	# Recalcular uma vez no quadro seguinte evita a primeira abertura gigante.
	_settle_summary_layout.call_deferred()


func _settle_summary_layout() -> void:
	_layout()
	await get_tree().process_frame
	if is_inside_tree() and summary_frame != null:
		_layout()


func _rebuild_book() -> void:
	_clear(book_rows)
	var entries := _visible_entries()
	book_count.text = "%d REGISTROS" % entries.size()
	book_pages.clear()
	for entry in entries:
		var context_key := "%d|%d|%s" % [int(entry.get("day", 1)),
			int(entry.get("period", 0)), str(entry.get("district", "suburbio"))]
		if book_pages.is_empty() or book_pages.back().get("key", "") != context_key:
			book_pages.append({"key": context_key, "entries": []})
		(book_pages.back()["entries"] as Array).append(entry)
	if entries.is_empty():
		book_rows.add_child(_label("Nenhuma ação registrada ainda.", 13, MUTED))
		book_context.text = "SEM REGISTROS"
		book_previous.disabled = true
		book_next.disabled = true
		return
	if book_page_index < 0 or book_page_index >= book_pages.size():
		book_page_index = book_pages.size() - 1
	var page_entries: Array = book_pages[book_page_index]["entries"]
	var context_entry: Dictionary = page_entries.back()
	book_context.text = "DIA %d · %s · %s" % [
		int(context_entry.get("day", 1)),
		_period_name(int(context_entry.get("period", 0))),
		_district_name(str(context_entry.get("district", "suburbio")))]
	book_previous.disabled = book_page_index <= 0
	book_next.disabled = book_page_index >= book_pages.size() - 1
	for index in range(page_entries.size() - 1, -1, -1):
		var entry: Dictionary = page_entries[index]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(ROW_BG, Color(0.15, 0.35, 0.41), 1, 3))
		book_rows.add_child(card)
		var inner := MarginContainer.new()
		_set_margins(inner, 10, 10, 6, 6)
		card.add_child(inner)
		inner.add_child(_entry_text(entry, false, true))
	book_scroll.set_v_scroll(0)


func _visible_entries() -> Array[Dictionary]:
	var visible: Array[Dictionary] = []
	if campaign == null:
		return visible
	for entry in campaign.journal_entries:
		if str(entry.get("action_id", "")) in ["exploration_move", "move", "movement",
				"transfer_item", "discard_item", "roll", "round_advanced"]:
			continue
		var presentation := entry.duplicate(false)
		presentation["visible_serial"] = visible.size() + 1
		visible.append(presentation)
	return visible


func _entry_text(entry: Dictionary, short: bool, numbered: bool = false) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = false
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = not short
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE if short else Control.MOUSE_FILTER_PASS
	rich.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rich.add_theme_font_size_override("normal_font_size", 10 if short else 12)
	rich.add_theme_color_override("default_color", WHITE)
	if not short:
		UINarrativeFont.apply_rich_text(rich)
		rich.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)
	if numbered:
		rich.push_color(CYAN)
		rich.add_text("#%d — " % int(entry.get("visible_serial", entry.get("serial", 0))))
		rich.pop()
	var segments: Array = entry.get("segments", [])
	for value in segments:
		if not value is Dictionary:
			continue
		var segment := value as Dictionary
		var tone := str(segment.get("tone", "text"))
		if tone in ["critical", "information"]:
			rich.push_outline_color(Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
				if tone == "critical" else Color(GREEN.r, GREEN.g, GREEN.b, 0.35))
			rich.push_outline_size(2)
		rich.push_color(_tone_color(tone))
		rich.add_text(str(segment.get("text", "")))
		rich.pop()
		if tone in ["critical", "information"]:
			rich.pop()
			rich.pop()
	if segments.is_empty():
		rich.add_text(str(entry.get("text", "")))
	if not short:
		rich.pop()
	return rich


func _change_book_page(direction: int) -> void:
	var target := book_page_index + direction
	if target < 0 or target >= book_pages.size():
		return
	book_page_index = target
	_rebuild_book()


func _period_name(period: int) -> String:
	match period:
		PPPMapGenerator.RoundPeriod.AFTERNOON: return "TARDE"
		PPPMapGenerator.RoundPeriod.NIGHT: return "NOITE"
	return "MANHÃ"


func _district_name(district_id: String) -> String:
	match district_id:
		"suburbio": return "SUBÚRBIO"
		"baixo_centro": return "BAIXO-CENTRO"
		"centro": return "CENTRO"
	return district_id.replace("_", " ").to_upper()


func _navigation_button(symbol: String, hint: String) -> Button:
	var button := Button.new()
	button.text = symbol
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(36, 31)
	button.flat = true
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", CYAN)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.22, 0.32, 0.35))
	return button


func _tone_color(tone: String) -> Color:
	match tone:
		"actor": return CYAN
		"hostile", "negative": return HOSTILE
		"item": return PINK
		"skill": return BLUE
		"positive", "information": return GREEN
		"critical": return GOLD
		"event": return Color(0.88, 0.67, 0.97)
		_: return WHITE


func _layout() -> void:
	if summary_frame == null:
		return
	var viewport_size := get_viewport_rect().size
	var width := clampf(viewport_size.x * 0.225, 282.0, 380.0)
	var default_top := clampf(viewport_size.y * 0.28, 106.0, 275.0)
	summary_frame.custom_minimum_size.x = width
	summary_frame.reset_size()
	var visible_height := summary_frame.size.y if summary_expanded else 40.0
	var top := clampf(_summary_user_y if _summary_user_y >= 0.0 else default_top,
		60.0, maxf(60.0, viewport_size.y - visible_height - 8.0))
	if _summary_user_y >= 0.0:
		_summary_user_y = top
	summary_frame.position = Vector2(viewport_size.x - width - 18.0, top)
	expand_tab.position = Vector2(viewport_size.x - 32.0, top)
	info_hint.size = Vector2(minf(width, 315.0), 0)
	info_hint.reset_size()
	info_hint.position = Vector2(viewport_size.x - width - 18.0,
		top + summary_frame.size.y + 7.0)
	if backdrop != null:
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if book_window != null:
		book_window.size = Vector2(minf(860.0, viewport_size.x - 50.0),
			minf(600.0, viewport_size.y - 90.0))
		book_window.position = (viewport_size - book_window.size) * 0.5


func _on_summary_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_summary_dragging = event.pressed
		accept_event()


func _on_expand_tab_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tab_dragging = true
			_tab_was_dragged = false
			_tab_drag_distance = 0.0
		else:
			_tab_dragging = false


func _on_expand_tab_pressed() -> void:
	if not _tab_was_dragged:
		_set_summary_expanded(true)
	_tab_was_dragged = false


func _input(event: InputEvent) -> void:
	if _tab_dragging:
		if event is InputEventMouseMotion and absf(event.relative.y) > 0.0:
			_tab_drag_distance += absf(event.relative.y)
			if _tab_drag_distance > 4.0:
				_tab_was_dragged = true
				_summary_user_y = expand_tab.position.y + event.relative.y
				_layout()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and not event.pressed:
			_tab_dragging = false
	if not _summary_dragging:
		return
	if event is InputEventMouseMotion:
		_summary_user_y = summary_frame.position.y + event.relative.y
		_layout()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_summary_dragging = false


func _unhandled_key_input(event: InputEvent) -> void:
	if is_book_open() and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close_book()
		get_viewport().set_input_as_handled()


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(background: Color, border: Color, border_width: int,
		margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(margin)
	return style


func _set_margins(container: MarginContainer, left: int, right: int,
		top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
