class_name CampaignArchiveLibrary
extends Control

## Biblioteca somente-leitura. Cada pasta aponta para uma campanha concluída
## (ainda com slots ativos ou arquivada); o livro projeta registros imutáveis.
signal back_requested
signal main_menu_requested
signal refreshed

const CYAN := Color(0.22, 0.85, 0.94)
const BLUE := Color(0.42, 0.68, 0.98)
const RED := Color(1.0, 0.39, 0.43)
const PINK := Color(1.0, 0.40, 0.69)
const GREEN := Color(0.45, 0.91, 0.62)
const YELLOW := Color(0.95, 0.82, 0.35)
const WHITE := Color(0.92, 0.95, 0.96)
const MUTED := Color(0.64, 0.73, 0.77)
const BACK := Color(0.018, 0.029, 0.038, 1.0)
const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")
const ERROR_TEXT := "Trecho corrompido//arquivo perdido. ERRO de registro"
const EMPTY_REFERENCE_TEXT := "Erro de registro - Fonte de referência não localizada"
const ENDING_NAMES := {
	"khainokata": "Khainokata", "orchestra": "Orchestra",
	"homens_de_preto": "Homens de Preto", "controle_da_mente": "Controle da Mente",
}

class FolderGlyph extends Control:
	var accent := Color.CYAN
	func _draw() -> void:
		var outline := PackedVector2Array([
			Vector2(2, 8), Vector2(2, 32), Vector2(40, 32),
			Vector2(40, 12), Vector2(22, 12), Vector2(18, 7), Vector2(2, 7)])
		draw_colored_polygon(outline, Color(accent.r, accent.g, accent.b, 0.14))
		draw_polyline(outline, accent, 2.0, false)
		draw_line(Vector2(2, 8), Vector2(2, 7), accent, 2.0)

var repository := CampaignSaveRepository.new()
var _grid: GridContainer
var _total: Label
var _veil: Control
var _confirm: PanelContainer
var _confirm_name: Label
var _book: PanelContainer
var _book_heading: Label
var _book_context: Label
var _book_rows: VBoxContainer
var _book_scroll: ScrollContainer
var _line_previous: Button
var _line_next: Button
var _selected_campaign: Dictionary = {}
var _selected_line_index := 0
var _refresh_serial := 0
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(func() -> void:
		if not visible:
			_refresh_serial += 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_library()
	_build_overlay()
	resized.connect(_layout)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.connect("ui_scale_changed", func(_factor: float) -> void:
			_layout.call_deferred())
	_layout()
	hide()


func open() -> void:
	_veil.hide()
	show()
	_refresh()
	_keyboard_navigation.reset(self)


func close() -> void:
	_refresh_serial += 1
	_veil.hide()
	hide()


func _build_library() -> void:
	var background := ColorRect.new()
	background.name = "BlackBackground"
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var frame := MarginContainer.new()
	frame.name = "ArchiveFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(frame, 27, 27, 22, 20)
	add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	frame.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 15)
	stack.add_child(header)
	var heading := _label("▤  REGISTROS DE HISTÓRIAS", 26, CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var back := _button("←  VOLTAR", CYAN)
	back.name = "BackButton"
	back.pressed.connect(func() -> void: back_requested.emit())
	header.add_child(back)
	var rule := ColorRect.new()
	rule.color = Color(CYAN.r, CYAN.g, CYAN.b, 0.55)
	rule.custom_minimum_size.y = 1
	stack.add_child(rule)
	var explanation := _label("Campanhas concluídas e arquivadas · abra uma pasta para consultar seu livro de registros.", 13, MUTED)
	stack.add_child(explanation)
	var scroll := ScrollContainer.new()
	scroll.name = "FoldersScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stack.add_child(scroll)
	_grid = GridContainer.new()
	_grid.name = "FoldersGrid"
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	_total = _label("", 12, MUTED)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_total)
	var menu := _button("MENU PRINCIPAL", CYAN)
	menu.name = "MainMenuButton"
	menu.pressed.connect(func() -> void: main_menu_requested.emit())
	footer.add_child(menu)


func _build_overlay() -> void:
	_veil = Control.new()
	_veil.name = "ArchiveOverlay"
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_veil)
	# Uma cópia fosca do que ficou atrás; não altera os cartões nem o livro.
	var blur := ColorRect.new()
	blur.name = "FrostedBackground"
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_STOP
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap; void fragment() { COLOR = textureLod(screen_texture, SCREEN_UV, 2.5); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	blur.material = material
	_veil.add_child(blur)
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.015, 0.022, 0.68)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_close_overlay())
	_veil.add_child(dim)
	_confirm = PanelContainer.new()
	_confirm.name = "OpenConfirmation"
	_confirm.add_theme_stylebox_override("panel", _box(BACK, CYAN, 2))
	_veil.add_child(_confirm)
	var confirm_margin := MarginContainer.new()
	_margins(confirm_margin, 20, 20, 18, 18)
	_confirm.add_child(confirm_margin)
	var prompt := VBoxContainer.new()
	prompt.add_theme_constant_override("separation", 14)
	confirm_margin.add_child(prompt)
	_confirm_name = _label("", 15, CYAN)
	_confirm_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(_confirm_name)
	var question := _label("Abrir histórico de registros?", 17, WHITE)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_child(question)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 12)
	prompt.add_child(choices)
	var open_button := _button("ABRIR HISTÓRICO", GREEN)
	open_button.name = "OpenHistoryButton"
	open_button.pressed.connect(_open_book)
	choices.add_child(open_button)
	var cancel := _button("VOLTAR", CYAN)
	cancel.name = "CancelOpenButton"
	cancel.pressed.connect(_close_overlay)
	choices.add_child(cancel)
	_book = PanelContainer.new()
	_book.name = "ArchiveBook"
	_book.add_theme_stylebox_override("panel", _box(Color(0.018, 0.027, 0.033, 0.99), CYAN, 2))
	_veil.add_child(_book)
	var book_margin := MarginContainer.new()
	_margins(book_margin, 20, 20, 16, 16)
	_book.add_child(book_margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	book_margin.add_child(body)
	var book_header := HBoxContainer.new()
	body.add_child(book_header)
	_book_heading = _label("LIVRO DE REGISTROS", 23, CYAN)
	_book_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_header.add_child(_book_heading)
	var close_button := _button("X", RED)
	close_button.name = "CloseBookButton"
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.pressed.connect(_close_overlay)
	book_header.add_child(close_button)
	var divider := ColorRect.new()
	divider.color = Color(CYAN.r, CYAN.g, CYAN.b, 0.45)
	divider.custom_minimum_size.y = 1
	body.add_child(divider)
	var line_nav := HBoxContainer.new()
	line_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	line_nav.add_theme_constant_override("separation", 14)
	body.add_child(line_nav)
	_line_previous = _button("◀", CYAN)
	_line_previous.name = "PreviousHistory"
	_line_previous.pressed.connect(_change_line.bind(-1))
	line_nav.add_child(_line_previous)
	_book_context = _label("", 13, MUTED)
	_book_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_book_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_nav.add_child(_book_context)
	_line_next = _button("▶", CYAN)
	_line_next.name = "NextHistory"
	_line_next.pressed.connect(_change_line.bind(1))
	line_nav.add_child(_line_next)
	_book_scroll = ScrollContainer.new()
	_book_scroll.name = "BookScroll"
	_book_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_book_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_book_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(_book_scroll)
	_book_rows = VBoxContainer.new()
	_book_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_book_rows.add_theme_constant_override("separation", 10)
	_book_scroll.add_child(_book_rows)
	_confirm.hide()
	_book.hide()
	_veil.hide()


func _layout() -> void:
	if _grid == null:
		return
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	var factor := float(scale_service.get("ui_factor")) if scale_service != null else 1.0
	var available := maxf(320.0, size.x - 54.0 * factor)
	var virtual_available := available / factor
	_grid.columns = 5 if virtual_available >= 1150.0 else 4 if virtual_available >= 920.0 else 3 if virtual_available >= 680.0 else 2
	var card_width := (available - 12.0 * factor * float(_grid.columns - 1)) \
		/ float(_grid.columns) / factor
	for child in _grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size.x = card_width
	_confirm.size = Vector2(minf(440.0, size.x - 32.0), 158.0)
	_confirm.position = (size - _confirm.size) * 0.5
	_book.size = Vector2(minf(1000.0, size.x - 36.0), minf(690.0, size.y - 38.0))
	_book.position = (size - _book.size) * 0.5


func _refresh() -> void:
	_refresh_serial += 1
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_total.text = "Carregando…"
	_refresh_async(_refresh_serial)


func _refresh_async(serial: int) -> void:
	await get_tree().process_frame
	if serial != _refresh_serial:
		return
	var folders: Array[Dictionary] = []
	for campaign_id in repository.list_all_campaign_ids():
		var lines: Array[Dictionary] = []
		for line_id in repository.list_terminal_line_ids(campaign_id):
			var line := repository.inspect_terminal_line_header(campaign_id, line_id)
			if not line.is_empty():
				lines.append(line)
			await get_tree().process_frame
			if serial != _refresh_serial:
				return
		if not lines.is_empty():
			lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("created_at", "")) < str(b.get("created_at", "")))
			var archived := repository.inspect_archive_marker(campaign_id)
			var folder := {"campaign_id": campaign_id, "lines": lines}
			if not archived.is_empty():
				folder["archived_at"] = str(archived.get("archived_at", ""))
			else:
				folder["archived"] = false
				folder["completed_at"] = str(lines[-1].get("created_at", ""))
			folders.append(folder)
		await get_tree().process_frame
		if serial != _refresh_serial:
			return
	folders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("archived_at", a.get("completed_at", ""))) > \
			str(b.get("archived_at", b.get("completed_at", ""))))
	_total.text = "%d %s" % [folders.size(), "história" if folders.size() == 1 else "histórias"]
	if folders.is_empty():
		var empty := _label("Ainda não há campanhas concluídas ou arquivadas.", 16, MUTED)
		_grid.add_child(empty)
	else:
		for index in folders.size():
			_add_folder(folders[index], index)
			await get_tree().process_frame
			if serial != _refresh_serial:
				return
	_layout()
	refreshed.emit()


func _add_folder(archive: Dictionary, index: int) -> void:
	var lines: Array = archive.get("lines", [])
	var representative: Dictionary = lines[0] if not lines.is_empty() and lines[0] is Dictionary else {}
	var mode := int(representative.get("mode", -1))
	var color := CYAN
	if mode == EventCampaignEligibility.Mode.MEDIUM:
		color = PINK
	elif mode == EventCampaignEligibility.Mode.COMPLETE:
		color = YELLOW
	var folder := Button.new()
	folder.name = "ArchiveFolder_%d" % index
	folder.custom_minimum_size.y = 152
	folder.add_theme_stylebox_override("normal", _box(Color(0.025, 0.045, 0.055, 0.98), color.darkened(0.4)))
	var hovered := _box(Color(0.045, 0.07, 0.08, 1.0), color, 2)
	hovered.shadow_color = Color(color.r, color.g, color.b, 0.28)
	hovered.shadow_size = 6
	folder.add_theme_stylebox_override("hover", hovered)
	folder.add_theme_stylebox_override("pressed", hovered)
	folder.pressed.connect(_select_folder.bind(archive))
	_grid.add_child(folder)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margins(margin, 12, 10, 10, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	folder.add_child(margin)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var glyph := FolderGlyph.new()
	glyph.accent = color
	glyph.custom_minimum_size = Vector2(44, 36)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(glyph)
	var title := _label(_mode_name(int(representative.get("mode", -1))), 15, WHITE)
	content.add_child(title)
	var description := _label(_ending_description(representative), 11, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UINarrativeFont.apply_label(description)
	description.custom_minimum_size.y = 30
	content.add_child(description)
	var archived := bool(archive.get("archived", archive.has("archived_at")))
	var date_text := str(archive.get("archived_at", "")) if archived else \
		str(archive.get("completed_at", ""))
	var date := _label("%s em: %s" % ["Arquivada" if archived else "Concluída",
		_display_date(date_text)], 11, color)
	content.add_child(date)
	for label in [title, description, date]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _select_folder(archive: Dictionary) -> void:
	_selected_campaign = archive
	_selected_line_index = 0
	var lines: Array = archive.get("lines", [])
	var line: Dictionary = lines[0] if not lines.is_empty() and lines[0] is Dictionary else {}
	_confirm_name.text = _mode_name(int(line.get("mode", -1)))
	_book.hide()
	_confirm.show()
	_veil.show()
	_layout()
	_keyboard_navigation.reset(_confirm)


func _open_book() -> void:
	_confirm.hide()
	_book.show()
	_render_book()
	_layout()
	_keyboard_navigation.reset(_book)


func _close_overlay() -> void:
	_confirm.hide()
	_book.hide()
	_veil.hide()
	_keyboard_navigation.reset(self)


func _change_line(direction: int) -> void:
	var lines: Array = _selected_campaign.get("lines", [])
	var target := _selected_line_index + direction
	if target < 0 or target >= lines.size():
		return
	_selected_line_index = target
	_render_book()


func _render_book() -> void:
	for child in _book_rows.get_children():
		_book_rows.remove_child(child)
		child.queue_free()
	var lines: Array = _selected_campaign.get("lines", [])
	if lines.is_empty() or _selected_line_index >= lines.size():
		_book_rows.add_child(_label(ERROR_TEXT, 14, RED))
		return
	var line: Dictionary = lines[_selected_line_index]
	if not line.has("entries"):
		var loaded := repository.inspect_terminal_line(
			str(_selected_campaign.get("campaign_id", "")),
			str(line.get("line_id", "")))
		if loaded.is_empty():
			_book_rows.add_child(_label(ERROR_TEXT, 14, RED))
			return
		lines[_selected_line_index] = loaded
		_selected_campaign["lines"] = lines
		line = loaded
	_book_heading.text = "LIVRO DE REGISTROS · %s" % _mode_name(int(line.get("mode", -1))).to_upper()
	_book_context.text = "HISTÓRIA %d/%d · %s · %s" % [
		_selected_line_index + 1, lines.size(),
		"VITÓRIA" if int(line.get("status", -1)) == CampaignState.CampaignStatus.VICTORY else "DERROTA",
		_display_date(str(line.get("created_at", "")))]
	_line_previous.visible = lines.size() > 1
	_line_next.visible = lines.size() > 1
	_line_previous.disabled = _selected_line_index == 0
	_line_next.disabled = _selected_line_index >= lines.size() - 1
	var rounds := repository.summarize_archive_line(line)
	if rounds.is_empty():
		_book_rows.add_child(_label(EMPTY_REFERENCE_TEXT, 14, YELLOW))
	else:
		for summary in rounds:
			_add_round(summary, int(line.get("journal_schema_version", 1)))
	_book_scroll.set_v_scroll(0)


func _add_round(summary: Dictionary, schema_version: int) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color(0.031, 0.046, 0.054, 0.96), Color(0.17, 0.37, 0.42), 1))
	_book_rows.add_child(panel)
	var padding := MarginContainer.new()
	_margins(padding, 15, 15, 13, 13)
	panel.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	padding.add_child(stack)
	var header := _label("DIA %d · %s · %s   /   RODADA %d" % [
		int(summary.get("day", 1)), _period_name(int(summary.get("period", 0))),
		_district_name(str(summary.get("district", ""))),
		int(summary.get("round_index", 0))], 15, CYAN)
	stack.add_child(header)
	var text := RichTextLabel.new()
	text.fit_content = true
	text.scroll_active = false
	text.selection_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 13)
	text.add_theme_color_override("default_color", WHITE)
	UINarrativeFont.apply_rich_text(text)
	text.push_paragraph(HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(text)
	_line(text, "Eventos: ", _list_or_none(summary.get("events", [])), Color(0.88, 0.67, 0.97))
	var encounter: Dictionary = summary.get("encounter", {})
	if encounter.is_empty():
		_line(text, "Encontro mais desafiador: ", EMPTY_REFERENCE_TEXT, YELLOW)
	else:
		var encounter_deaths := int(encounter.get("deaths", 0))
		_line(text, "Encontro mais desafiador: ", "%s · %d de dano recebido · %d %s." % [
			str(encounter.get("name", ERROR_TEXT)), int(encounter.get("damage_taken", 0)),
			encounter_deaths, "morte" if encounter_deaths == 1 else "mortes"], RED)
	var damage_text := str(int(summary.get("group_damage", 0))) \
		if int(summary.get("group_damage", 0)) > 0 else EMPTY_REFERENCE_TEXT
	if schema_version < 2 or bool(summary.get("damaged_skill_without_amount", false)):
		damage_text = ERROR_TEXT
	_line(text, "Dano causado pelo grupo na rodada: ", damage_text,
		RED if damage_text == ERROR_TEXT else YELLOW if damage_text == EMPTY_REFERENCE_TEXT else GREEN)
	_line(text, "Itens coletados: ", _list_or_none(summary.get("collected", [])), PINK)
	_line(text, "Itens criados: ", _list_or_none(summary.get("crafted", [])), PINK)
	_line(text, "Mortes: ", _list_or_none(summary.get("deaths", [])), RED)
	_line(text, "Recrutamentos/aliados: ", ERROR_TEXT if schema_version < 2 else \
		_list_or_none(summary.get("recruits", [])), RED if schema_version < 2 else CYAN)
	text.pop()


func _line(rich: RichTextLabel, heading: String, value: String, color: Color) -> void:
	rich.push_color(MUTED)
	rich.add_text(heading)
	rich.pop()
	rich.push_color(YELLOW if value == EMPTY_REFERENCE_TEXT else color)
	rich.add_text(value)
	rich.pop()
	rich.add_text("\n")


func _list_or_none(values: Array) -> String:
	return ", ".join(values) if not values.is_empty() else EMPTY_REFERENCE_TEXT


func _mode_name(mode: int) -> String:
	match mode:
		EventCampaignEligibility.Mode.SHORT: return "Campanha Curta"
		EventCampaignEligibility.Mode.MEDIUM: return "Campanha Média"
		EventCampaignEligibility.Mode.COMPLETE: return "Campanha Completa"
	return "Campanha sem identificação"


func _ending_description(line: Dictionary) -> String:
	if int(line.get("mode", -1)) == EventCampaignEligibility.Mode.COMPLETE:
		return "Os mistérios de Belacidade"
	var names: Array[String] = []
	for ending_id in line.get("ending_ids", []):
		names.append(str(ENDING_NAMES.get(str(ending_id), str(ending_id))))
	return " / ".join(names) if not names.is_empty() else ERROR_TEXT


func _display_date(value: String) -> String:
	if value.length() < 10:
		return ERROR_TEXT
	return "%s/%s/%s" % [value.substr(8, 2), value.substr(5, 2), value.substr(0, 4)]


func _period_name(value: int) -> String:
	match value:
		PPPMapGenerator.RoundPeriod.AFTERNOON: return "TARDE"
		PPPMapGenerator.RoundPeriod.NIGHT: return "NOITE"
	return "MANHÃ"


func _district_name(value: String) -> String:
	match value:
		"suburbio": return "SUBÚRBIO"
		"baixo_centro": return "BAIXO-CENTRO"
		"centro": return "CENTRO"
	return value.replace("_", " ").to_upper() if not value.is_empty() else ERROR_TEXT


func _button(caption: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(110, 34)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.4))
	button.add_theme_stylebox_override("normal", _box(Color(0.026, 0.044, 0.052, 1), accent.darkened(0.25)))
	var hover := _box(Color(0.05, 0.10, 0.12, 1), accent, 2)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.27)
	hover.shadow_size = 6
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", _box(Color(0.02, 0.03, 0.04, 1), MUTED.darkened(0.55)))
	return button


func _box(bg: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	return style


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _veil.visible and _book.visible:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	var active_root: Control = _book if _book.visible else \
		_confirm if _confirm.visible else self
	if _keyboard_navigation.handle(event, active_root):
		get_viewport().set_input_as_handled()
