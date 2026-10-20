class_name InformationArchivePanel
extends Control

## Consulta as Informações já obtidas. Este painel nunca altera a campanha:
## títulos e textos vêm dos Informacao.tres; bloqueios vêm de CampaignState.

const COLOR_BLUE := Color(0.16, 0.66, 0.86)
const COLOR_GREEN := Color(0.35, 0.93, 0.61)
const COLOR_GRAY := Color(0.44, 0.48, 0.51)
const COLOR_TEXT := Color(0.88, 0.91, 0.91)
const TRACE_CORNER := preload("res://sprites/ui/uielementx_00008.png")
const VIEWPORT_MARGIN := 15.0

var gerencia: GerenciaJogo
var catalog: Array[Resource] = []
var folder_keys: Array[String] = []
var selected_folder := ""
var selected_document_id: StringName = &""
var _last_obtained_signature := ""

var window: PanelContainer
var free_space_trace: TextureRect
var total_label: Label
var folder_list: VBoxContainer
var folder_buttons: Array[Button] = []
var folder_counts: Array[Label] = []
var folder_progress: Array[ProgressBar] = []
var folder_title: Label
var document_count: Label
var document_list: VBoxContainer
var document_buttons: Array[Button] = []
var notebook: PanelContainer
var notebook_title: Label
var notebook_text: RichTextLabel
var _window_dragging := false
var _window_user_positioned := false


func _ready() -> void:
	_build_interface()
	resized.connect(_layout_window)
	_layout_window()


func open() -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	catalog = gerencia.get_information_catalog()
	_collect_folders()
	if selected_folder not in folder_keys:
		selected_folder = folder_keys[0] if not folder_keys.is_empty() else ""
	selected_document_id = &""
	_rebuild_folder_list()
	_refresh()
	_last_obtained_signature = _obtained_signature()
	show()
	_layout_window()
	window.grab_focus()


func close() -> void:
	_window_dragging = false
	hide()


func _input(event: InputEvent) -> void:
	if not visible or not _window_dragging:
		return
	if event is InputEventMouseMotion:
		_window_user_positioned = true
		window.position = _clamp_window_position(window.position + event.relative)
		_position_free_space_trace()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_window_dragging = false


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_window_dragging = true
		get_viewport().set_input_as_handled()


func _clamp_window_position(candidate: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		clampf(candidate.x, VIEWPORT_MARGIN,
			maxf(VIEWPORT_MARGIN, viewport_size.x - window.size.x - VIEWPORT_MARGIN)),
		clampf(candidate.y, VIEWPORT_MARGIN,
			maxf(VIEWPORT_MARGIN, viewport_size.y - window.size.y - VIEWPORT_MARGIN))
	)


func _position_free_space_trace() -> void:
	if free_space_trace != null:
		free_space_trace.position = window.position + Vector2(24.0,
			window.size.y - free_space_trace.size.y - 20.0)


func _process(_delta: float) -> void:
	if not visible or gerencia == null or gerencia.campaign == null:
		return
	var signature := _obtained_signature()
	if signature != _last_obtained_signature:
		_last_obtained_signature = signature
		_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _layout_window() -> void:
	if window == null:
		return
	var viewport_size := get_viewport_rect().size
	window.size = Vector2(minf(viewport_size.x * 0.75, 1000.0),
		minf(viewport_size.y * 0.77, 570.0))
	window.position = _clamp_window_position(window.position if _window_user_positioned
		else (viewport_size - window.size) * 0.5)
	if free_space_trace != null:
		# Só cabe quando a coluna de pastas é curta; nunca por cima dos docs.
		free_space_trace.visible = visible and folder_keys.size() <= 4 \
			and window.size.y >= 480.0
		_position_free_space_trace()


func _build_interface() -> void:
	window = PanelContainer.new()
	window.name = "ArchiveWindow"
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.focus_mode = Control.FOCUS_ALL
	window.add_theme_stylebox_override("panel", _box(Color(0.025, 0.041, 0.045, 0.97), COLOR_BLUE, 2))
	add_child(window)
	free_space_trace = TextureRect.new()
	free_space_trace.name = "FreeSpaceTrace"
	free_space_trace.texture = TRACE_CORNER
	free_space_trace.modulate.a = 0.18
	free_space_trace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	free_space_trace.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	free_space_trace.stretch_mode = TextureRect.STRETCH_SCALE
	free_space_trace.size = Vector2(110.0, 85.0)
	add_child(free_space_trace)
	var outer := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_%s" % side, 12)
	window.add_child(outer)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	outer.add_child(content)
	var header := HBoxContainer.new()
	header.name = "DragHeader"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	content.add_child(header)
	var heading := _label("▤ ARQUIVO DE INFORMAÇÕES", 18, COLOR_BLUE)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	total_label = _label("0 COLETADAS", 12, COLOR_GREEN)
	total_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(total_label)
	var close_button := Button.new()
	close_button.text = "X"
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.custom_minimum_size = Vector2(30, 28)
	_style_button(close_button, COLOR_GRAY, false)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	var rule := HSeparator.new()
	content.add_child(rule)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	content.add_child(body)
	var folders := VBoxContainer.new()
	folders.custom_minimum_size.x = 238
	folders.add_theme_constant_override("separation", 7)
	body.add_child(folders)
	folders.add_child(_label("PASTAS  /  DESFECHOS", 11, COLOR_GRAY))
	var folder_scroll := ScrollContainer.new()
	folder_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	folder_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	folders.add_child(folder_scroll)
	folder_list = VBoxContainer.new()
	folder_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_list.add_theme_constant_override("separation", 7)
	folder_scroll.add_child(folder_list)
	var documents := VBoxContainer.new()
	documents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	documents.add_theme_constant_override("separation", 5)
	body.add_child(documents)
	var document_header := HBoxContainer.new()
	documents.add_child(document_header)
	folder_title = _label("", 15, COLOR_TEXT)
	folder_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	document_header.add_child(folder_title)
	document_count = _label("", 11, COLOR_GREEN)
	document_header.add_child(document_count)
	var document_scroll := ScrollContainer.new()
	document_scroll.custom_minimum_size.y = 202
	document_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	documents.add_child(document_scroll)
	document_list = VBoxContainer.new()
	document_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	document_list.add_theme_constant_override("separation", 4)
	document_scroll.add_child(document_list)
	notebook = PanelContainer.new()
	notebook.visible = false
	notebook.custom_minimum_size.y = 174
	notebook.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook.add_theme_stylebox_override("panel", _box(Color(0.035, 0.078, 0.083, 0.94), COLOR_GREEN, 1))
	documents.add_child(notebook)
	var note_margin := MarginContainer.new()
	note_margin.add_theme_constant_override("margin_left", 10)
	note_margin.add_theme_constant_override("margin_right", 10)
	note_margin.add_theme_constant_override("margin_top", 10)
	note_margin.add_theme_constant_override("margin_bottom", 10)
	notebook.add_child(note_margin)
	var note_stack := VBoxContainer.new()
	note_margin.add_child(note_stack)
	notebook_title = _label("", 13, COLOR_GREEN)
	note_stack.add_child(notebook_title)
	notebook_text = RichTextLabel.new()
	notebook_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_text.scroll_active = true
	notebook_text.selection_enabled = true
	notebook_text.add_theme_color_override("default_color", COLOR_TEXT)
	notebook_text.add_theme_font_size_override("normal_font_size", 12)
	note_stack.add_child(notebook_text)


func _collect_folders() -> void:
	folder_keys.clear()
	for resource in catalog:
		var information := resource as Informacao
		if information == null:
			continue
		var folder := information.resource_path.get_base_dir().get_file()
		if folder != "" and folder not in folder_keys:
			folder_keys.append(folder)
	folder_keys.sort()
	if free_space_trace != null:
		free_space_trace.visible = visible and folder_keys.size() <= 4 \
			and window.size.y >= 480.0


func _rebuild_folder_list() -> void:
	_clear_children(folder_list)
	folder_buttons.clear()
	folder_counts.clear()
	folder_progress.clear()
	for folder in folder_keys:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _box(Color(0.055, 0.09, 0.12, 0.9), COLOR_BLUE, 1))
		folder_list.add_child(card)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		margin.add_child(stack)
		var folder_button := Button.new()
		folder_button.text = "▣  %s" % _folder_label(folder)
		folder_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		folder_button.custom_minimum_size.y = 36
		_style_button(folder_button, COLOR_BLUE, folder == selected_folder)
		folder_button.pressed.connect(_select_folder.bind(folder))
		stack.add_child(folder_button)
		folder_buttons.append(folder_button)
		var progress_row := HBoxContainer.new()
		stack.add_child(progress_row)
		var bar := ProgressBar.new()
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size.y = 8
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", _box(Color(0.06, 0.11, 0.12), Color.TRANSPARENT, 0))
		bar.add_theme_stylebox_override("fill", _box(COLOR_GREEN, Color.TRANSPARENT, 0))
		progress_row.add_child(bar)
		folder_progress.append(bar)
		var count := _label("", 10, COLOR_GREEN)
		progress_row.add_child(count)
		folder_counts.append(count)


func _select_folder(folder: String) -> void:
	selected_folder = folder
	selected_document_id = &""
	_refresh()


func _select_document(id: StringName) -> void:
	var information := _find_by_id(id)
	if information == null or not _is_obtained(information):
		return
	selected_document_id = id
	_refresh()


func _refresh() -> void:
	var total := 0
	for index in folder_keys.size():
		var documents := _documents_in(folder_keys[index])
		var obtained := 0
		for information in documents:
			if _is_obtained(information):
				obtained += 1
		total += obtained
		folder_counts[index].text = "%d / %d" % [obtained, documents.size()]
		folder_progress[index].max_value = maxi(1, documents.size())
		folder_progress[index].value = obtained
		_style_button(folder_buttons[index], COLOR_BLUE, folder_keys[index] == selected_folder)
	total_label.text = "%d / %d COLETADAS" % [total, catalog.size()]
	folder_title.text = "▣ %s" % _folder_label(selected_folder)
	var current_documents := _documents_in(selected_folder)
	var selected_count := 0
	for information in current_documents:
		if _is_obtained(information):
			selected_count += 1
	document_count.text = "%d / %d DOCUMENTOS" % [selected_count, current_documents.size()]
	_clear_children(document_list)
	document_buttons.clear()
	for information in current_documents:
		var obtained := _is_obtained(information)
		var button := Button.new()
		button.custom_minimum_size.y = 42
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not obtained
		button.text = "  ▤  %02d   %s" % [information.numero,
			information.titulo if obtained else "DOCUMENTO DESCONHECIDO"]
		_style_button(button, COLOR_GREEN if selected_document_id == information.id else
			(COLOR_BLUE if obtained else COLOR_GRAY), selected_document_id == information.id)
		button.pressed.connect(_select_document.bind(information.id))
		document_list.add_child(button)
		document_buttons.append(button)
	var selected := _find_by_id(selected_document_id)
	notebook.visible = selected != null and _is_obtained(selected)
	if notebook.visible:
		notebook_title.text = "▤ %s" % selected.titulo
		notebook_text.text = selected.descricao
		notebook_text.scroll_to_line(0)
	_layout_window()


func _documents_in(folder: String) -> Array[Informacao]:
	var documents: Array[Informacao] = []
	for resource in catalog:
		var information := resource as Informacao
		if information != null and information.resource_path.get_base_dir().get_file() == folder:
			documents.append(information)
	documents.sort_custom(func(a: Informacao, b: Informacao) -> bool:
		return a.numero < b.numero if a.numero != b.numero else str(a.id) < str(b.id))
	return documents


func _find_by_id(id: StringName) -> Informacao:
	for resource in catalog:
		var information := resource as Informacao
		if information != null and information.id == id:
			return information
	return null


func _folder_label(folder: String) -> String:
	return folder.replace("_", " ").to_upper()


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _obtained_signature() -> String:
	var ids: Array[String] = []
	for id in gerencia.campaign.obtained_information_ids:
		ids.append(str(id))
	ids.sort()
	return "|".join(ids)


func _is_obtained(information: Informacao) -> bool:
	return information != null and gerencia != null and gerencia.campaign != null \
		and gerencia.campaign.obtained_information_ids.has(information.id)


func _label(value: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result


func _box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(3)
	return result


func _style_button(button: Button, color: Color, selected: bool) -> void:
	var background := color.darkened(0.78 if selected else 0.89)
	button.add_theme_stylebox_override("normal", _box(background, color, 1))
	button.add_theme_stylebox_override("hover", _box(color.darkened(0.68), color, 1))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.55), color, 1))
	button.add_theme_stylebox_override("disabled", _box(Color(0.07, 0.08, 0.09, 0.7), COLOR_GRAY.darkened(0.4), 1))
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_GRAY.darkened(0.28))
	button.add_theme_font_size_override("font_size", 11)
