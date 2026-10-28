extends Control

const DIALOG_STYLE := preload("res://scripts/ui/game_dialog_style.gd")

signal load_requested(campaign_id: String, slot_number: int, autosave: bool)
signal save_requested(slot_number: int, occupied: bool)
signal campaign_abandoned(campaign_id: String)
signal archives_requested
signal refreshed

const CYAN := Color(0.25, 0.80, 0.93)
const PINK := Color(1.0, 0.32, 0.68)
const GREEN := Color(0.18, 0.90, 0.39)
const YELLOW := Color(0.95, 0.82, 0.35)
const RED := Color(0.94, 0.28, 0.34)
const WHITE := Color(0.93, 0.97, 1.0)
const MUTED := Color(0.68, 0.79, 0.85)
const BACK := Color(0.025, 0.045, 0.065, 0.99)
const ENDING_NAMES := {
	"khainokata": "Khainokata", "orchestra": "Orchestra",
	"homens_de_preto": "Homens de Preto", "controle_da_mente": "Controle da Mente",
}

var repository := CampaignSaveRepository.new()
var save_mode := false
var save_campaign_id := ""
var records_only := false
var _heading: Label
var _archives_button: Button
var _rows: VBoxContainer
var _status: Label
var _panel: PanelContainer
var _archive_dialog: ConfirmationDialog
var _delete_dialog: ConfirmationDialog
var _abandon_dialog: ConfirmationDialog
var _summary_dialog: AcceptDialog
var _summary_text: RichTextLabel
var _selected_campaign_id := ""
var _refresh_serial := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visibility_changed.connect(func() -> void:
		if not visible:
			_refresh_serial += 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(BACK, CYAN, 2))
	center.add_child(_panel)
	_palette_style(_panel, "panel", "surface", "structure")
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var heading := Label.new()
	heading.text = "SALVAR CAMPANHA" if save_mode else "CAMPANHAS"
	_heading = heading
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", WHITE)
	header.add_child(heading)
	_palette_color(heading, "font_color", "primary")
	var archives_button := Button.new()
	archives_button.name = "ArchivesButton"
	archives_button.text = "CONCLUÍDAS / ARQUIVADAS"
	archives_button.custom_minimum_size = Vector2(195, 34)
	_style_button(archives_button, CYAN)
	archives_button.pressed.connect(func() -> void: archives_requested.emit())
	header.add_child(archives_button)
	_archives_button = archives_button
	var close_icon := Button.new()
	close_icon.text = "✕"
	close_icon.custom_minimum_size = Vector2(38, 34)
	_style_button(close_icon, CYAN)
	close_icon.pressed.connect(close)
	header.add_child(close_icon)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 2
	divider.color = CYAN.darkened(0.23)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)
	_palette_rect(divider, "structure")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)
	var footer_line := ColorRect.new()
	footer_line.custom_minimum_size.y = 1
	footer_line.color = CYAN.darkened(0.30)
	footer_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer_line)
	_palette_rect(footer_line, "structure")
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(1, 0.65, 0.65))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)
	_palette_color(_status, "font_color", "danger")
	var close_button := Button.new()
	close_button.text = "←  VOLTAR"
	close_button.custom_minimum_size = Vector2(180, 40)
	_style_button(close_button, CYAN)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	resized.connect(_fit_panel)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.connect("ui_scale_changed", _on_ui_scale_changed)
	_fit_panel()
	_archive_dialog = ConfirmationDialog.new()
	_archive_dialog.title = "Arquivar campanha concluída?"
	_archive_dialog.dialog_text = "Os três slots e todos os desfechos ficarão congelados para consulta. A campanha sairá da lista ativa."
	_archive_dialog.get_ok_button().text = "ARQUIVAR DE VEZ"
	_style_priority_button(_archive_dialog.get_ok_button(), YELLOW)
	_archive_dialog.get_cancel_button().text = "VOLTAR"
	_style_priority_button(_archive_dialog.get_cancel_button(), CYAN)
	_archive_dialog.confirmed.connect(_confirm_archive)
	add_child(_archive_dialog)
	DIALOG_STYLE.apply(_archive_dialog, "warning", 510.0, 78.0)
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Excluir arquivo permanentemente?"
	_delete_dialog.dialog_text = "Esta ação apaga slots, backups e livros desta campanha. Não poderá ser desfeita."
	_delete_dialog.get_ok_button().text = "EXCLUIR PERMANENTEMENTE"
	_style_priority_button(_delete_dialog.get_ok_button(), RED)
	_delete_dialog.get_cancel_button().text = "PRESERVAR ARQUIVO"
	_style_priority_button(_delete_dialog.get_cancel_button(), CYAN)
	_delete_dialog.confirmed.connect(_confirm_delete)
	add_child(_delete_dialog)
	DIALOG_STYLE.apply(_delete_dialog, "danger", 510.0, 82.0)
	_abandon_dialog = ConfirmationDialog.new()
	_abandon_dialog.title = "Abandonar campanha permanentemente?"
	_abandon_dialog.dialog_text = "Esta ação excluirá os TRÊS SLOTS manuais, os AUTOSAVES e o LIVRO DE REGISTROS da campanha, incluindo seus desfechos. Não poderá ser desfeita. Se quiser preservar a história, use ARQUIVAR DE VEZ depois de concluir a campanha."
	_abandon_dialog.get_ok_button().text = "SIM, EXCLUIR TUDO"
	_style_priority_button(_abandon_dialog.get_ok_button(), RED)
	_abandon_dialog.get_cancel_button().text = "CANCELAR"
	_style_priority_button(_abandon_dialog.get_cancel_button(), CYAN)
	_abandon_dialog.confirmed.connect(_confirm_abandon)
	add_child(_abandon_dialog)
	DIALOG_STYLE.apply(_abandon_dialog, "danger", 560.0, 112.0)
	_summary_dialog = AcceptDialog.new()
	_summary_dialog.title = "Resumo de registros por Rodada"
	_summary_dialog.get_ok_button().text = "FECHAR"
	add_child(_summary_dialog)
	DIALOG_STYLE.apply(_summary_dialog, "structure", 670.0, 400.0)
	_summary_text = RichTextLabel.new()
	_summary_text.custom_minimum_size = Vector2(670, 400)
	_summary_text.position = Vector2(20, 52)
	_summary_text.size = Vector2(670, 400)
	_summary_text.bbcode_enabled = false
	_summary_text.scroll_active = true
	_summary_text.add_theme_color_override("default_color", Color(0.86, 0.94, 0.96))
	_summary_dialog.add_child(_summary_text)
	_palette_color(_summary_text, "default_color", "primary")
	DIALOG_STYLE.make_backdrop(self, [
		_archive_dialog, _delete_dialog, _abandon_dialog, _summary_dialog,
	])
	# O painel nasce oculto no menu, na seleção e duas vezes na pausa.
	# Validar todos os saves aqui bloqueava a entrada em cada uma dessas telas.
	# open() já atualiza a lista quando o jogador realmente a solicita.


func _fit_panel() -> void:
	if _panel != null:
		var scale_service := get_node_or_null("/root/UniversalFontScale")
		var factor := float(scale_service.get("ui_factor")) if scale_service != null else 1.0
		_panel.custom_minimum_size = Vector2(
			minf(1380.0 * factor, maxf(520.0, size.x - 48.0)) / factor,
			minf(790.0 * factor, maxf(420.0, size.y - 48.0)) / factor)


func _on_ui_scale_changed(_factor: float) -> void:
	_fit_panel.call_deferred()


func _box(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(5)
	return style


func _palette_color(control: Control, key: String, role: String) -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.bind_color(control, key, role)


func _palette_style(control: Control, key: String, background: String,
		border: String = "", shadow: String = "") -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.bind_control_style(control, key, background, border, shadow)


func _palette_rect(rect: ColorRect, role: String) -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.bind_rect(rect, role)


func _style_button(button: Button, border: Color, disabled: bool = false) -> void:
	var role := "progress" if border == GREEN else "structure"
	var normal := _box(Color(0.035, 0.075, 0.095, 0.98), border)
	button.add_theme_stylebox_override("normal", normal)
	var hover := _box(Color(0.15, 0.045, 0.10, 0.99), PINK, 2)
	hover.shadow_color = Color(1.0, 0.12, 0.58, 0.30)
	hover.shadow_size = 5
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled",
		_box(Color(0.055, 0.065, 0.075, 0.95), Color(0.27, 0.34, 0.38)))
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.43, 0.51, 0.55))
	button.disabled = disabled
	_palette_style(button, "normal", "button", role)
	for key in ["hover", "pressed", "focus"]:
		_palette_style(button, key, "button_hover", "selection", "selection")
	_palette_style(button, "disabled", "button", "disabled")
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_palette_color(button, key, "on_button")
	_palette_color(button, "font_disabled_color", "on_button_disabled")


func _style_priority_button(button: Button, accent: Color) -> void:
	var role := "danger" if accent == RED else "warning" if accent == YELLOW else "structure"
	var background_role := "button_danger" if accent == RED else "button"
	var normal := _box(Color(accent.r * 0.12, accent.g * 0.12,
		accent.b * 0.12, 0.99), accent, 2)
	var hover := _box(Color(accent.r * 0.22, accent.g * 0.22,
		accent.b * 0.22, 1.0), accent.lightened(0.18), 2)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.42)
	hover.shadow_size = 7
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", accent.lightened(0.12))
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	_palette_style(button, "normal", background_role, role)
	for key in ["hover", "pressed", "focus"]:
		_palette_style(button, key, "button_danger" if accent == RED else "button_hover", role, role)
	_palette_color(button, "font_color", "on_button")
	_palette_color(button, "font_hover_color", "on_button")
	_palette_color(button, "font_pressed_color", "on_button")


func open() -> void:
	show()
	refresh()


func close() -> void:
	_refresh_serial += 1
	_archive_dialog.hide()
	_delete_dialog.hide()
	_abandon_dialog.hide()
	_summary_dialog.hide()
	hide()


func show_error(message: String) -> void:
	_status.text = message
	_palette_color(_status, "font_color", "danger")


func show_success(message: String) -> void:
	_status.text = message
	_palette_color(_status, "font_color", "progress")


func refresh() -> void:
	if _rows == null:
		return
	_refresh_serial += 1
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_status.text = "Carregando…"
	_heading.text = "SALVAR CAMPANHA" if save_mode else ("REGISTROS DE CAMPANHAS" if records_only else "CAMPANHAS")
	_archives_button.visible = not save_mode and not records_only
	_refresh_async(_refresh_serial)


func _refresh_async(serial: int) -> void:
	# Deixa a janela aparecer antes da primeira leitura. O catálogo confere
	# envelopes/metadados, uma campanha por quadro; o estado jogável completo
	# só é decodificado quando um slot específico é escolhido.
	await get_tree().process_frame
	if serial != _refresh_serial or not is_instance_valid(self):
		return
	if save_mode:
		var entry := repository.inspect_campaign(save_campaign_id)
		if serial != _refresh_serial:
			return
		_add_campaign(entry if not entry.is_empty() else
			{"campaign_id": save_campaign_id, "slots": []}, 1)
		_status.text = ""
		refreshed.emit()
		return
	if records_only:
		var completed_count := 0
		for campaign_id in repository.list_campaign_ids():
			if repository.list_terminal_line_ids(campaign_id).is_empty():
				continue
			var lines: Array[Dictionary] = []
			for line_id in repository.list_terminal_line_ids(campaign_id):
				var line := repository.inspect_terminal_line(campaign_id, line_id)
				if not line.is_empty():
					lines.append(line)
				await get_tree().process_frame
				if serial != _refresh_serial:
					return
			if lines.is_empty():
				continue
			if completed_count == 0:
				_add_section("CONCLUÍDAS · slots ainda disponíveis")
			_add_archived_campaign(campaign_id, lines, false)
			completed_count += 1
		var archived_count := 0
		for campaign_id in repository.list_all_campaign_ids():
			if not repository.is_archived(campaign_id):
				continue
			var lines: Array[Dictionary] = []
			for line_id in repository.list_terminal_line_ids(campaign_id):
				var line := repository.inspect_terminal_line(campaign_id, line_id)
				if not line.is_empty():
					lines.append(line)
				await get_tree().process_frame
				if serial != _refresh_serial:
					return
			if lines.is_empty():
				continue
			if archived_count == 0:
				_add_section("ARQUIVADAS · consulta apenas")
			_add_archived_campaign(campaign_id, lines)
			archived_count += 1
			await get_tree().process_frame
			if serial != _refresh_serial:
				return
		if completed_count == 0 and archived_count == 0:
			_add_section("Ainda não há campanhas concluídas ou arquivadas.")
		_status.text = ""
		refreshed.emit()
		return
	var recoveries: Array[Dictionary] = []
	var campaigns: Array[Dictionary] = []
	for campaign_id in repository.list_campaign_ids():
		var recovery := repository.inspect_recoverable_autosave(campaign_id)
		if not recovery.is_empty():
			recoveries.append(recovery)
		var campaign := repository.inspect_campaign(campaign_id)
		if not campaign.is_empty():
			campaigns.append(campaign)
		await get_tree().process_frame
		if serial != _refresh_serial:
			return
	recoveries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["saved_at"]) > str(b["saved_at"]))
	if not recoveries.is_empty():
		_add_section("RECUPERAÇÕES APÓS INTERRUPÇÃO")
		for recovery in recoveries:
			_add_entry("Backup • %s • campanha %s" % [
					_display_time(str(recovery["saved_at"])),
					str(recovery["campaign_id"]).substr(0, 8)],
				"RECUPERAR", str(recovery["campaign_id"]), 0, true, true)
	if not campaigns.is_empty():
		campaigns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return _campaign_latest_time(a) > _campaign_latest_time(b))
		for index in campaigns.size():
			_add_campaign(campaigns[index], index + 1)
			await get_tree().process_frame
			if serial != _refresh_serial:
				return
	var archive_count := 0
	for campaign_id in repository.list_all_campaign_ids():
		if not repository.is_archived(campaign_id):
			continue
		var lines: Array[Dictionary] = []
		for line_id in repository.list_terminal_line_ids(campaign_id):
			var line := repository.inspect_terminal_line(campaign_id, line_id)
			if not line.is_empty():
				lines.append(line)
			await get_tree().process_frame
			if serial != _refresh_serial:
				return
		if lines.is_empty():
			continue
		if archive_count == 0:
			_add_section("CONCLUÍDAS / ARQUIVADAS · consulta apenas")
		_add_archived_campaign(campaign_id, lines)
		archive_count += 1
		await get_tree().process_frame
		if serial != _refresh_serial:
			return
	if recoveries.is_empty() and campaigns.is_empty() and archive_count == 0:
		_add_section("Ainda não há saves ou recuperações disponíveis.")
	_status.text = ""
	refreshed.emit()


func _campaign_latest_time(campaign: Dictionary) -> String:
	var latest := ""
	for slot in campaign.get("slots", []):
		var saved_at := str(slot.get("saved_at", ""))
		if saved_at > latest:
			latest = saved_at
	return latest


func _campaign_preview(campaign: Dictionary) -> Dictionary:
	for slot in campaign.get("slots", []):
		if bool(slot.get("valid", false)) and not (slot.get("preview", {}) as Dictionary).is_empty():
			return slot["preview"]
	return {}


func _campaign_heading(index: int, preview: Dictionary) -> String:
	var label := "CAMPANHA %02d" % index
	if bool(preview.get("legacy", false)):
		return label + " · SAVE ANTERIOR"
	match int(preview.get("mode", -1)):
		EventCampaignEligibility.Mode.SHORT:
			var endings: Array = preview.get("ending_ids", [])
			return "%s · CURTA · %s" % [label,
				str(ENDING_NAMES.get(str(endings[0]), str(endings[0])))
				if not endings.is_empty() else "Desfecho não identificado"]
		EventCampaignEligibility.Mode.MEDIUM:
			var names: Array[String] = []
			for ending_id in preview.get("ending_ids", []):
				names.append(str(ENDING_NAMES.get(str(ending_id), str(ending_id))))
			return "%s · MÉDIA · %s" % [label, " + ".join(names)]
		EventCampaignEligibility.Mode.COMPLETE:
			return label + " · COMPLETA"
	return label + " · SEM ARQUIVOS"


func _add_campaign(campaign: Dictionary, index: int) -> void:
	var campaign_id := str(campaign["campaign_id"])
	var group := PanelContainer.new()
	group.add_theme_stylebox_override("panel",
		_box(Color(0.028, 0.050, 0.069, 0.98), Color(0.21, 0.48, 0.56)))
	_rows.add_child(group)
	_palette_style(group, "panel", "surface", "neutral")
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % side, 10)
	group.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	padding.add_child(stack)
	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	stack.add_child(heading_row)
	var heading := Label.new()
	heading.text = "CAMPANHA ATUAL · TRÊS SLOTS MANUAIS" if save_mode else _campaign_heading(index, _campaign_preview(campaign))
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", WHITE)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.tooltip_text = heading.text
	heading_row.add_child(heading)
	_palette_color(heading, "font_color", "primary")
	if not save_mode:
		if int(campaign.get("terminal_count", 0)) > 0:
			var archive := Button.new()
			archive.text = "ARQUIVAR DE VEZ"
			archive.tooltip_text = "Preserva slots e livros para consulta; sai da lista de campanhas ativas."
			archive.custom_minimum_size = Vector2(174, 32)
			archive.add_theme_font_size_override("font_size", 11)
			_style_priority_button(archive, YELLOW)
			archive.pressed.connect(func() -> void:
				_selected_campaign_id = campaign_id
				_archive_dialog.popup_centered(Vector2i(540, 190)))
			heading_row.add_child(archive)
		var abandon := Button.new()
		abandon.text = "EXCLUIR DE VEZ"
		abandon.tooltip_text = "Abandona a campanha e exclui permanentemente slots, autosaves e livros."
		abandon.custom_minimum_size = Vector2(174, 32)
		abandon.add_theme_font_size_override("font_size", 11)
		_style_priority_button(abandon, RED)
		abandon.pressed.connect(func() -> void:
			_selected_campaign_id = campaign_id
			_abandon_dialog.popup_centered(Vector2i(560, 245)))
		heading_row.add_child(abandon)
	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 10)
	stack.add_child(slots_row)
	for number in range(1, CampaignSaveRepository.SLOT_COUNT + 1):
		var slot: Dictionary = {}
		for saved_slot in campaign.get("slots", []):
			if int(saved_slot.get("slot_number", 0)) == number:
				slot = saved_slot
				break
		_add_slot_card(slots_row, campaign_id, number, slot)


func _add_slot_card(parent: HBoxContainer, campaign_id: String,
		number: int, slot: Dictionary) -> void:
	var occupied := not slot.is_empty()
	var valid := occupied and bool(slot.get("valid", false))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 192)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _box(
		Color(0.033, 0.066, 0.083, 0.98) if valid else Color(0.045, 0.053, 0.060, 0.96),
		CYAN.darkened(0.12) if valid else Color(0.26, 0.34, 0.38)))
	parent.add_child(card)
	_palette_style(card, "panel", "surface", "structure" if valid else "disabled")
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % side, 10)
	card.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	padding.add_child(stack)
	var top := HBoxContainer.new()
	stack.add_child(top)
	var badge := Label.new()
	badge.text = "%02d" % number
	badge.add_theme_font_size_override("font_size", 19)
	badge.add_theme_color_override("font_color", CYAN if valid else MUTED)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(badge)
	_palette_color(badge, "font_color", "structure" if valid else "disabled")
	var state := Label.new()
	var preview: Dictionary = slot.get("preview", {}) if valid else {}
	var legacy := bool(preview.get("legacy", false))
	state.text = "SAVE ANTERIOR" if valid and legacy else \
		("BACKUP · %d/%d INFO" if bool(slot.get("backup_only", false)) else
		"%d/%d INFO") % [int(preview.get("information_count", 0)),
		int(preview.get("information_goal", 0))] if valid else \
		("INVÁLIDO" if occupied else "VAZIO")
	state.add_theme_font_size_override("font_size", 10)
	state.add_theme_color_override("font_color",
		Color(1.0, 0.82, 0.35) if valid and bool(slot.get("backup_only", false)) else
		(CYAN if valid else MUTED))
	top.add_child(state)
	_palette_color(state, "font_color", "warning" if valid and bool(slot.get("backup_only", false)) else "structure" if valid else "disabled")
	if valid:
		if legacy:
			_add_card_label(stack,
				"Prévia indisponível; o jogo verificará este save ao carregar.", WHITE, 12)
		else:
			_add_card_label(stack, "DIA %d · %s · %s" % [
				int(preview.get("day", 1)),
				_period_name(int(preview.get("period", 0))),
				_district_name(str(preview.get("district", "")))], WHITE, 12)
		_add_card_label(stack, _display_time(str(slot.get("saved_at", ""))), MUTED, 10)
		if not legacy:
			var latest := str(preview.get("latest_entry", "Nenhuma ação registrada."))
			var latest_label := _add_card_label(stack, "ÚLTIMO REGISTRO · " + latest, WHITE, 10)
			latest_label.custom_minimum_size.y = 32
			latest_label.max_lines_visible = 2
			latest_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			latest_label.tooltip_text = "Último registro: " + latest
			var characters: Array = preview.get("characters", [])
			var character_names: Array[String] = []
			for character in characters:
				character_names.append(str(character))
			var party := _add_card_label(stack,
				"PERSONAGENS · " + (" · ".join(character_names)
				if not character_names.is_empty() else "Nenhum jogável vivo"), WHITE, 10)
			party.custom_minimum_size.y = 20
			party.max_lines_visible = 1
			party.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			party.tooltip_text = party.text
	else:
		var message := "Arquivo indisponível neste slot." if occupied else \
			"Nenhum arquivo salvo neste slot."
		var empty := _add_card_label(stack, message, MUTED, 12)
		empty.custom_minimum_size.y = 68
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(spacer)
	var load_button := Button.new()
	load_button.text = ("▸  SUBSTITUIR" if occupied else "▸  SALVAR") if save_mode else ("▸  CARREGAR" if valid else "SEM SAVE")
	load_button.custom_minimum_size.y = 32
	_style_button(load_button, GREEN, not valid and not save_mode)
	if save_mode:
		load_button.pressed.connect(func() -> void:
			save_requested.emit(number, occupied))
	elif valid:
		load_button.pressed.connect(func() -> void:
			load_requested.emit(campaign_id, number, false))
	stack.add_child(load_button)


func _add_card_label(parent: VBoxContainer, value: String,
		color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	_palette_color(label, "font_color", "secondary" if color == MUTED else "primary")
	return label


func _period_name(period: int) -> String:
	return ["MANHÃ", "TARDE", "NOITE"][clampi(period, 0, 2)]


func _district_name(value: String) -> String:
	match value:
		"suburbio": return "SUBÚRBIO"
		"baixo_centro": return "BAIXO-CENTRO"
		"centro": return "CENTRO"
	return value.replace("_", " ").to_upper() if not value.is_empty() else "DISTRITO INDISPONÍVEL"


func _add_archived_campaign(campaign_id: String, lines: Array,
		archived: bool = true) -> void:
	var group := PanelContainer.new()
	group.add_theme_stylebox_override("panel",
		_box(Color(0.035, 0.049, 0.058, 0.98), Color(0.25, 0.49, 0.55)))
	_rows.add_child(group)
	_palette_style(group, "panel", "surface", "neutral")
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % side, 13)
	group.add_child(padding)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	padding.add_child(stack)
	var row := HBoxContainer.new()
	stack.add_child(row)
	var label := Label.new()
	label.text = "Arquivo %s · %d desfecho(s)" % [campaign_id.substr(0, 8), lines.size()]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	_palette_color(label, "font_color", "primary")
	if archived:
		var delete_button := Button.new()
		delete_button.text = "EXCLUIR ARQUIVO"
		delete_button.custom_minimum_size = Vector2(150, 34)
		_style_priority_button(delete_button, RED)
		delete_button.pressed.connect(func() -> void:
			_selected_campaign_id = campaign_id
			_delete_dialog.popup_centered(Vector2i(530, 210)))
		row.add_child(delete_button)
	for index in lines.size():
		var line := lines[index] as Dictionary
		var outcome := "Vitória" if int(line.get("status", 0)) == \
			CampaignState.CampaignStatus.VICTORY else "Derrota"
		var title := "Linha %d · %s · %s" % [index + 1, outcome,
			_display_time(str(line.get("created_at", "")))]
		var line_row := HBoxContainer.new()
		stack.add_child(line_row)
		var line_label := Label.new()
		line_label.text = title
		line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line_label.add_theme_color_override("font_color", MUTED)
		line_row.add_child(line_label)
		_palette_color(line_label, "font_color", "secondary")
		var summary_button := Button.new()
		summary_button.text = "RESUMO POR RODADA"
		summary_button.custom_minimum_size = Vector2(178, 32)
		_style_button(summary_button, CYAN)
		summary_button.pressed.connect(_show_summary.bind(line))
		line_row.add_child(summary_button)


func _confirm_archive() -> void:
	var result := repository.archive_campaign(_selected_campaign_id)
	if not result.get("success", false):
		_status.text = str(result.get("reason", "Não foi possível arquivar."))
		return
	refresh()


func _confirm_delete() -> void:
	var result := repository.delete_archived_campaign(_selected_campaign_id, true)
	if not result.get("success", false):
		_status.text = str(result.get("reason", "Não foi possível excluir."))
		return
	refresh()


func _confirm_abandon() -> void:
	var removed_id := _selected_campaign_id
	var result := repository.abandon_campaign(removed_id, true)
	if not result.get("success", false):
		_status.text = str(result.get("reason", "Não foi possível abandonar a campanha."))
		return
	refresh()
	campaign_abandoned.emit(removed_id)


func _show_summary(line: Dictionary) -> void:
	var text_lines: Array[String] = []
	var rounds := repository.summarize_terminal_line(line)
	for round in rounds:
		var period: String = ["Manhã", "Tarde", "Noite"][clampi(int(round["period"]), 0, 2)]
		text_lines.append("DIA %d · %s · %s" % [int(round["day"]), period,
			str(round["district"]).replace("_", " ").capitalize()])
		for entry in round["entries"]:
			text_lines.append("  # %d  %s" % [int(entry["serial"]), str(entry["text"])])
		text_lines.append("")
	_summary_text.text = "\n".join(text_lines) if not text_lines.is_empty() \
		else "Não há marcos resumíveis nesta linha. O livro detalhado permanece preservado."
	_summary_dialog.popup_centered(Vector2i(730, 500))


func _add_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_color_override("font_color", WHITE)
	label.add_theme_font_size_override("font_size", 17)
	_rows.add_child(label)
	_palette_color(label, "font_color", "primary")


func _add_entry(label_text: String, button_text: String, campaign_id: String,
		slot_number: int, autosave: bool, valid: bool) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 44
	row.add_theme_constant_override("separation", 12)
	_rows.add_child(row)
	var label := Label.new()
	label.text = label_text if valid else label_text + " · inválido"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	_palette_color(label, "font_color", "primary")
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(118, 34)
	_style_button(button, GREEN, not valid)
	button.pressed.connect(func() -> void:
		load_requested.emit(campaign_id, slot_number, autosave))
	row.add_child(button)


func _display_time(value: String) -> String:
	if value.length() >= 16 and value[4] == "-" and value[7] == "-":
		return "%s/%s/%s %s" % [value.substr(8, 2), value.substr(5, 2),
			value.substr(0, 4), value.substr(11, 5)]
	return value.replace("T", " ") if not value.is_empty() else "Data indisponível"


func _unhandled_key_input(event: InputEvent) -> void:
	if _archive_dialog.visible or _delete_dialog.visible \
			or _abandon_dialog.visible or _summary_dialog.visible:
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
