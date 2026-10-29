class_name CampaignPauseMenu
extends CanvasLayer

signal panels_prepared

## Tela opaca: o mapa e todas as outras camadas de UI continuam intactos,
## mas nunca aparecem durante a pausa. BackgroundAnimationSlot fica reservado
## para a futura animação especial, atrás dos controles.

const LOAD_PANEL_SCRIPT := preload("res://scripts/ui/campaign_load_panel.gd")
const ARCHIVE_LIBRARY_SCRIPT := preload("res://scripts/ui/campaign_archive_library.gd")
const SETTINGS_MENU_SCRIPT := preload("res://scripts/ui/campaign_settings_menu.gd")
const DIALOG_STYLE := preload("res://scripts/ui/game_dialog_style.gd")
const GAME_SCENE_PATH := "res://scenes/game/campaign_game.tscn"
const LOADING_OVERLAY_SCRIPT := preload("res://scripts/ui/scene_loading_overlay.gd")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const PAUSE_LOGO := preload("res://sprites/ui/logo/logo_outline.png")
const PAUSE_LOGO_SHADER := preload("res://shaders/pause_logo_outline.gdshader")
const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")
const CYAN := Color(0.27, 0.83, 0.94)
const PINK := Color(0.97, 0.34, 0.68)
const GREEN := Color(0.30, 0.89, 0.52)
const WHITE := Color(0.91, 0.96, 0.98)

var top_bar
var _screen: Control
var _menu: VBoxContainer
var _pause_logo: TextureRect
var _load_panel: Control
var _save_panel: Control
var _journal: CampaignJournalUI
var _archive_library: Control
var _settings_menu: Control
var _overwrite: ConfirmationDialog
var _load_confirmation: ConfirmationDialog
var _exit: ConfirmationDialog
var _abandon: ConfirmationDialog
var _notice: AcceptDialog
var _selected_slot := 0
var _busy := false
var _save_from_new_day := false
var _pending_load: Dictionary = {}
var _debug_was_visible := false
var _button_tweens: Dictionary = {}
var _panels_ready := false
var _panels_preparing := false
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	var profile_start := Time.get_ticks_msec()
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_screen()
	if not bool(top_bar.get_parent().get_meta("defer_preview_map", false)):
		_build_panels()
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL pause panels %d ms" % (Time.get_ticks_msec() - profile_start))
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(_on_comfort_changed)
	_screen.hide()


func _on_comfort_changed(enabled: bool) -> void:
	if not enabled:
		return
	for button in _button_tweens:
		var tween := _button_tweens[button] as Tween
		if tween != null and tween.is_running():
			tween.kill()
		if is_instance_valid(button):
			(button as Button).scale = Vector2.ONE
	_button_tweens.clear()


func is_open() -> bool:
	return _screen != null and _screen.visible


func open() -> void:
	if is_open():
		return
	if not _panels_ready:
		_build_panels()
	if top_bar != null:
		top_bar.close_expandable_boxes()
	_screen.show()
	_keyboard_navigation.reset(_menu)
	var debug_panel := top_bar.get_parent().get_node_or_null("CampaignDebugPanel") as CanvasLayer
	_debug_was_visible = debug_panel != null and debug_panel.visible
	if debug_panel != null:
		debug_panel.hide()
	get_tree().paused = true
	var controller := _autosave_controller()
	if controller != null:
		controller.set_save_panel_open(true)


func close() -> void:
	if not is_open():
		return
	_save_from_new_day = false
	_load_panel.call("close")
	_save_panel.call("close")
	_journal.close_book()
	_journal.hide()
	_archive_library.call("close")
	_settings_menu.hide()
	_notice.hide()
	_overwrite.hide()
	_load_confirmation.hide()
	_pending_load.clear()
	_exit.hide()
	_abandon.hide()
	_screen.hide()
	_keyboard_navigation.reset(_menu)
	var debug_panel := top_bar.get_parent().get_node_or_null("CampaignDebugPanel") as CanvasLayer
	if debug_panel != null and _debug_was_visible:
		debug_panel.show()
	_debug_was_visible = false
	get_tree().paused = false
	var controller := _autosave_controller()
	if controller != null:
		controller.set_save_panel_open(false)


func open_save() -> void:
	_save_from_new_day = false
	_open_save_panel()


func open_save_from_new_day() -> void:
	_save_from_new_day = true
	_open_save_panel()


func _open_save_panel() -> void:
	open()
	_save_panel.set("save_campaign_id", top_bar.gerencia.campaign.campaign_id)
	_save_panel.call("open")


func _on_save_panel_visibility_changed() -> void:
	if _save_from_new_day and not _save_panel.visible and is_open():
		_save_from_new_day = false
		close.call_deferred()


func _build_screen() -> void:
	_screen = Control.new()
	_screen.name = "PauseScreen"
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_screen)
	var black := ColorRect.new()
	black.name = "BlackBackground"
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen.add_child(black)
	var animation_slot := Control.new()
	animation_slot.name = "BackgroundAnimationSlot"
	animation_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	animation_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(animation_slot)
	_pause_logo = TextureRect.new()
	_pause_logo.name = "PauseLogo"
	_pause_logo.texture = PAUSE_LOGO
	_pause_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pause_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pause_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline_material := ShaderMaterial.new()
	outline_material.shader = PAUSE_LOGO_SHADER
	_pause_logo.material = outline_material
	_screen.add_child(_pause_logo)
	var center := Control.new()
	center.name = "MenuCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(center)
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.custom_minimum_size.x = 312
	_menu.add_theme_constant_override("separation", 8)
	center.add_child(_menu)
	_screen.resized.connect(_layout_pause_menu)
	_menu.minimum_size_changed.connect(_layout_pause_menu.call_deferred)
	var title := Label.new()
	title.name = "Title"
	title.text = "JOGO PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", CYAN)
	_menu.add_child(title)
	_palette_color(title, "font_color", "on_dark_accent")
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "— pausa para um cafezinho —"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(0.63, 0.75, 0.80))
	_menu.add_child(subtitle)
	_palette_color(subtitle, "font_color", "on_dark_muted")
	var gap := Control.new()
	gap.name = "Gap"
	gap.custom_minimum_size.y = 16
	_menu.add_child(gap)
	_add_button("Resume", "▸   VOLTAR AO JOGO", PINK, close)
	_add_button("Save", "▣   SALVAR JOGO", CYAN, open_save)
	_add_button("Load", "▤   CARREGAR JOGO", CYAN, func() -> void:
		_load_panel.call("open"))
	_add_button("Settings", "⚙   OPÇÕES", CYAN, _open_settings)
	_add_button("Records", "▤   REGISTROS DE HISTÓRIAS", CYAN, _open_journal)
	var small_gap := Control.new()
	small_gap.custom_minimum_size.y = 4
	_menu.add_child(small_gap)
	_add_button("MainMenu", "←   VOLTAR AO MENU PRINCIPAL", WHITE, _open_exit_confirmation)
	_add_button("Abandon", "✕   ABANDONAR CAMPANHA", Color(0.91, 0.35, 0.43), func() -> void:
		_abandon.popup_centered(Vector2i(555, 225)))
	_layout_pause_menu.call_deferred()


func _layout_pause_menu() -> void:
	if _pause_logo == null or _screen == null or _menu == null:
		return
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	var factor := float(scale_service.get("ui_factor")) if scale_service != null else 1.0
	var logo_width := minf(240.0 * factor,
		maxf(150.0, _screen.size.x * 0.19))
	var logo_height := logo_width * 941.0 / 1671.0
	# Posiciona a outline na área indicada, com folga discreta à direita e acima.
	var right_inset := minf(logo_width * 0.36, _screen.size.x * 0.07)
	var top_inset := minf(logo_height * 0.78, _screen.size.y * 0.15)
	_pause_logo.position = Vector2(_screen.size.x - logo_width - right_inset, top_inset)
	_pause_logo.size = Vector2(logo_width, logo_height)
	var width := minf(312.0 * factor, maxf(235.0, _screen.size.x - 36.0))
	var height := _menu.get_combined_minimum_size().y
	_menu.position = Vector2((_screen.size.x - width) * 0.5,
		maxf(12.0, (_screen.size.y - height) * 0.5))
	_menu.size = Vector2(width, height)


func _add_button(node_name: String, label: String, accent: Color,
		action: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = label
	if node_name in ["Save", "Load", "Settings", "Records", "MainMenu"]:
		button.set_meta("ui_sfx_kind", &"menu_page")
	button.custom_minimum_size = Vector2(312, 38)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.018, 0.028, 0.035, 1)
	normal.border_color = accent.darkened(0.24)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 20
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.045, 0.073, 0.082, 1)
	hover.border_color = accent
	hover.set_border_width_all(2)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.42)
	hover.shadow_size = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var role := "selection" if accent == PINK else "progress" if accent == GREEN \
		else "danger" if accent.r > 0.8 and accent.g < 0.5 else "structure"
	_palette_style(button, "normal", "button_danger" if role == "danger" else "button", role)
	_palette_style(button, "hover", "button_danger" if role == "danger" else "button_hover", role, role)
	_palette_style(button, "pressed", "button_danger" if role == "danger" else "button_hover", role, role)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_palette_color(button, key, "on_button")
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.mouse_entered.connect(func() -> void:
		_create_button_tween(button, Vector2.ONE * 1.025))
	button.mouse_exited.connect(func() -> void:
		_create_button_tween(button, Vector2.ONE))
	button.pressed.connect(func() -> void:
		if _busy:
			return
		_busy = true
		var comfort := get_node_or_null("/root/VisualComfort")
		if comfort == null or not bool(comfort.get("enabled")):
			_stop_button_tween(button)
			var tween := create_tween()
			tween.tween_property(button, "scale", Vector2.ONE * 0.95, 0.06)
			tween.tween_property(button, "scale", Vector2.ONE * 1.04, 0.08)
			tween.tween_property(button, "scale", Vector2.ONE, 0.08)
			await tween.finished
		else:
			button.scale = Vector2.ONE
		_busy = false
		action.call())
	_menu.add_child(button)


func _create_button_tween(button: Button, target_scale: Vector2) -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and bool(comfort.get("enabled")):
		_stop_button_tween(button)
		button.scale = Vector2.ONE
		return
	_stop_button_tween(button)
	var tween := create_tween()
	_button_tweens[button] = tween
	tween.tween_property(button, "scale", target_scale, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_button_tween(button: Button) -> void:
	var existing := _button_tweens.get(button) as Tween
	if existing != null and existing.is_running():
		existing.kill()
	_button_tweens.erase(button)


func _palette_color(control: Control, key: String, role: String) -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.bind_color(control, key, role)


func _palette_style(control: Control, key: String, background: String,
		border: String, shadow: String = "") -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.bind_control_style(control, key, background, border, shadow)


func _open_settings() -> void:
	# A pausa congela a partida; não empilhar Configurações sobre uma decisão,
	# transição, confirmação de save/load ou outro painel exclusivo.
	if not is_open() or not get_tree().paused or _save_from_new_day \
			or not _pending_load.is_empty() or _save_panel.visible \
			or _load_panel.visible or _archive_library.visible \
			or _journal.is_book_open() or _overwrite.visible \
			or _load_confirmation.visible or _exit.visible or _abandon.visible:
		return
	_settings_menu.open()


func _build_panels() -> void:
	if _panels_ready:
		return
	_build_load_panel()
	_build_archive_library()
	_build_save_panel()
	_build_journal()
	_build_dialogs()
	_build_settings_panel()
	_panels_ready = true
	panels_prepared.emit()


## Campanha real: as caixas ocultas são preparadas enquanto a tela de
## carregamento ainda está visível, com no máximo um bloco de UI por quadro.
func prepare_panels(progress: Callable = Callable()) -> void:
	if _panels_ready:
		return
	if _panels_preparing:
		await panels_prepared
		return
	_panels_preparing = true
	var stages: Array[Callable] = [
		_build_load_panel, _build_archive_library, _build_save_panel,
		_build_journal, _build_dialogs, _build_settings_panel,
	]
	for stage in stages:
		var stage_start := Time.get_ticks_msec()
		stage.call()
		if ProjectSettings.get_setting("ppp/profile_startup", false):
			print("PPP_DETAIL pause %-27s %d ms" % [stage.get_method(),
				Time.get_ticks_msec() - stage_start])
		if progress.is_valid():
			progress.call()
		await get_tree().process_frame
	await _settings_menu.prepare_contents(progress)
	_panels_preparing = false
	_panels_ready = true
	panels_prepared.emit()


func _build_load_panel() -> void:
	var repository: CampaignSaveRepository = top_bar.gerencia.save_repository
	_load_panel = LOAD_PANEL_SCRIPT.new() as Control
	_load_panel.set("repository", repository)
	_screen.add_child(_load_panel)
	_load_panel.connect("load_requested", _on_load_requested)
	_load_panel.connect("campaign_abandoned", _on_campaign_abandoned)
	_load_panel.connect("archives_requested", _open_archive_library)
	_load_panel.hide()


func _build_archive_library() -> void:
	var repository: CampaignSaveRepository = top_bar.gerencia.save_repository
	_archive_library = ARCHIVE_LIBRARY_SCRIPT.new() as Control
	_archive_library.set("repository", repository)
	_screen.add_child(_archive_library)
	_archive_library.connect("back_requested", _back_from_archive)
	_archive_library.connect("main_menu_requested", func() -> void:
		_exit.popup_centered(Vector2i(510, 190)))


func _build_save_panel() -> void:
	var repository: CampaignSaveRepository = top_bar.gerencia.save_repository
	_save_panel = LOAD_PANEL_SCRIPT.new() as Control
	_save_panel.set("repository", repository)
	_save_panel.set("save_mode", true)
	_screen.add_child(_save_panel)
	_save_panel.connect("save_requested", _on_save_requested)
	_save_panel.visibility_changed.connect(_on_save_panel_visibility_changed)
	_save_panel.hide()


func _build_journal() -> void:
	_journal = CampaignJournalUI.new()
	_screen.add_child(_journal)
	_journal.bind_campaign(top_bar.gerencia.campaign)
	_journal.summary_frame.hide()
	_journal.expand_tab.hide()
	_journal.book_window.visibility_changed.connect(func() -> void:
		if not _journal.book_window.visible:
			_journal.hide())
	_journal.hide()


func _build_dialogs() -> void:
	_overwrite = ConfirmationDialog.new()
	_overwrite.title = "Substituir save?"
	_overwrite.get_ok_button().text = "SIM, SUBSTITUIR"
	_overwrite.get_cancel_button().text = "VOLTAR"
	top_bar.style_confirmation_button(_overwrite.get_ok_button(), Color(0.96, 0.75, 0.27))
	top_bar.style_confirmation_button(_overwrite.get_cancel_button(), CYAN)
	_overwrite.confirmed.connect(_commit_overwrite)
	_screen.add_child(_overwrite)
	DIALOG_STYLE.apply(_overwrite, "warning")
	_load_confirmation = ConfirmationDialog.new()
	_load_confirmation.title = "Carregar e substituir o progresso atual?"
	_load_confirmation.get_ok_button().text = "SIM, CARREGAR"
	_load_confirmation.get_cancel_button().text = "CANCELAR"
	top_bar.style_confirmation_button(_load_confirmation.get_ok_button(), Color(0.96, 0.75, 0.27))
	top_bar.style_confirmation_button(_load_confirmation.get_cancel_button(), CYAN)
	_load_confirmation.confirmed.connect(_confirm_pending_load)
	_load_confirmation.canceled.connect(_cancel_pending_load)
	_load_confirmation.close_requested.connect(_cancel_pending_load)
	_screen.add_child(_load_confirmation)
	DIALOG_STYLE.apply(_load_confirmation, "warning", 515.0, 82.0)
	_exit = ConfirmationDialog.new()
	_exit.title = "Voltar ao menu principal?"
	_exit.dialog_text = "O progresso não salvo e o backup automático desta sessão serão descartados. Os três slots manuais permanecem."
	_exit.get_ok_button().text = "SAIR SEM SALVAR"
	_exit.get_cancel_button().text = "CONTINUAR JOGANDO"
	top_bar.style_confirmation_button(_exit.get_ok_button(), Color(0.96, 0.75, 0.27))
	top_bar.style_confirmation_button(_exit.get_cancel_button(), CYAN)
	_exit.confirmed.connect(_confirm_exit)
	_screen.add_child(_exit)
	DIALOG_STYLE.apply(_exit, "warning", 515.0, 82.0)
	_abandon = ConfirmationDialog.new()
	_abandon.title = "Abandonar campanha permanentemente?"
	_abandon.dialog_text = "Esta ação excluirá permanentemente os TRÊS SLOTS manuais, os AUTOSAVES e o LIVRO DE REGISTROS desta campanha, incluindo seus desfechos. Não poderá ser desfeita. Para preservar a história, use ARQUIVAR DE VEZ após concluir a campanha."
	_abandon.get_ok_button().text = "SIM, EXCLUIR TUDO"
	_abandon.get_cancel_button().text = "CANCELAR"
	top_bar.style_confirmation_button(_abandon.get_ok_button(), Color(0.95, 0.30, 0.35))
	top_bar.style_confirmation_button(_abandon.get_cancel_button(), CYAN)
	_abandon.confirmed.connect(_confirm_abandon)
	_screen.add_child(_abandon)
	DIALOG_STYLE.apply(_abandon, "danger", 560.0, 112.0)
	_notice = AcceptDialog.new()
	_notice.title = "Aviso"
	_screen.add_child(_notice)
	DIALOG_STYLE.apply(_notice, "structure", 440.0, 68.0)
	DIALOG_STYLE.make_backdrop(_screen, [
		_overwrite, _load_confirmation, _exit, _abandon, _notice,
	])


func _build_settings_panel() -> void:
	_settings_menu = SETTINGS_MENU_SCRIPT.new() as Control
	_settings_menu.set("campaign", top_bar.gerencia.campaign)
	_settings_menu.set_meta("defer_settings_build",
		bool(top_bar.get_parent().get_meta("defer_preview_map", false)))
	_screen.add_child(_settings_menu)
	_settings_menu.tutorial_requested.connect(func() -> void:
		top_bar.open_tutorial_from_settings())


func _on_save_requested(slot_number: int, occupied: bool) -> void:
	_selected_slot = slot_number
	if occupied:
		_overwrite.dialog_text = "O slot %d já contém um save. Substituir apaga apenas o ponto antigo deste slot; os outros dois permanecem. Deseja continuar?" % slot_number
		_overwrite.popup_centered(Vector2i(450, 175))
	else:
		_commit_save(false)


func _open_journal() -> void:
	_journal.show()
	_journal.open_book()


func _open_exit_confirmation() -> void:
	_exit.dialog_text = top_bar.exit_progress_warning()
	_exit.popup_centered(Vector2i(520, 190))


func _open_archive_library() -> void:
	_load_panel.hide()
	_archive_library.call("open")


func _back_from_archive() -> void:
	_archive_library.call("close")
	_load_panel.call("open")


func _commit_overwrite() -> void:
	_commit_save(true)


func _commit_save(overwrite_confirmed: bool) -> void:
	var result: Dictionary = top_bar.gerencia.save_manual_slot(_selected_slot, overwrite_confirmed)
	if result.get("queued", false):
		_save_panel.call("show_error", "Salvamento agendado para o fim da ação.")
	elif result.get("success", false):
		_save_panel.call("refresh")
		_save_panel.call("show_success", "Salvo no slot %d." % _selected_slot)
	else:
		_save_panel.call("show_error", str(result.get("reason", "Não foi possível salvar.")))


func on_manual_save_completed(result: Dictionary) -> void:
	if not is_open():
		return
	_save_panel.call("refresh")
	if result.get("success", false):
		_save_panel.call("show_success", "Salvo no slot %d." % int(result.get("slot_number", 0)))
	else:
		_save_panel.call("show_error", str(result.get("reason", "Não foi possível salvar.")))


func _on_load_requested(campaign_id: String, slot_number: int,
		autosave: bool) -> void:
	if _busy or top_bar == null or top_bar.gerencia == null \
			or top_bar.gerencia.campaign == null:
		return
	var comparison: Dictionary = top_bar.gerencia.save_repository.compare_latest_manual_save(
		top_bar.gerencia.campaign, top_bar.get_parent())
	if not comparison.get("has_manual_save", false) or comparison.get("has_changes", true):
		_pending_load = {"campaign_id": campaign_id, "slot_number": slot_number,
			"autosave": autosave}
		var target := "o backup de recuperação" if autosave else "o slot %d" % slot_number
		_load_confirmation.dialog_text = ("Esta campanha ainda não tem save manual. " \
			if not comparison.get("has_manual_save", false) else \
			"Há alterações desde o último save manual. ") + \
			"Carregar %s descartará o progresso atual em memória. " % target + \
			"Os três slots manuais não serão alterados. Deseja continuar?"
		_load_confirmation.popup_centered(Vector2i(560, 210))
		return
	_perform_load(campaign_id, slot_number, autosave)


func _confirm_pending_load() -> void:
	if _pending_load.is_empty():
		return
	var request := _pending_load.duplicate()
	_pending_load.clear()
	_perform_load(str(request["campaign_id"]), int(request["slot_number"]),
		bool(request["autosave"]))


func _cancel_pending_load() -> void:
	_pending_load.clear()


func _perform_load(campaign_id: String, slot_number: int,
		autosave: bool) -> void:
	if _busy:
		return
	_busy = true
	var previous := get_tree().current_scene
	var loading := LOADING_OVERLAY_SCRIPT.new() as CanvasLayer
	get_tree().root.add_child(loading)
	loading.call("set_steps", 0, 42)
	await get_tree().process_frame
	await get_tree().process_frame
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		loading.queue_free()
		_busy = false
		_load_panel.call("show_error", "Não foi possível abrir a campanha.")
		return
	loading.call("advance_step")
	await get_tree().process_frame
	await get_tree().process_frame
	var game := packed.instantiate() as PPPMapView
	if game == null:
		loading.queue_free()
		_busy = false
		_load_panel.call("show_error", "Não foi possível abrir a campanha.")
		return
	game.set_meta("defer_preview_map", true)
	loading.call("advance_step")
	await get_tree().process_frame
	await get_tree().process_frame
	game.visible = false
	get_tree().root.add_child(game)
	(game.get_node("GerenciaJogo") as GerenciaJogo).save_repository = top_bar.gerencia.save_repository
	loading.call("advance_step")
	await get_tree().process_frame
	await get_tree().process_frame
	var interface_ready := await game.prepare_initial_interface(
		Callable(loading, "advance_step"))
	if not interface_ready:
		game.queue_free()
		loading.queue_free()
		_busy = false
		_load_panel.call("show_error", "Não foi possível preparar a interface do jogo.")
		return
	var result: Dictionary = top_bar.gerencia.save_repository.load_autosave(campaign_id, game) \
		if autosave else top_bar.gerencia.save_repository.load_campaign(
			campaign_id, slot_number, game)
	if not result.get("success", false):
		game.queue_free()
		loading.queue_free()
		_busy = false
		_load_panel.call("show_error", str(result.get("reason", "Save inválido.")))
		return
	loading.call("advance_step")
	await get_tree().process_frame
	var visuals_ready := await game.prepare_initial_visuals(
		Callable(loading, "advance_step"))
	if not visuals_ready:
		game.queue_free()
		loading.queue_free()
		_busy = false
		_load_panel.call("show_error", "Não foi possível desenhar o mapa.")
		return
	get_tree().paused = false
	get_tree().current_scene = game
	game.visible = true
	loading.call("advance_step")
	if autosave:
		var bar := game.get_node_or_null("CampaignTopBar") as CampaignTopBar
		if bar != null:
			bar.show_recovery_save_prompt.call_deferred()
	loading.queue_free()
	previous.queue_free()


func _confirm_exit() -> void:
	var controller := _autosave_controller()
	if controller == null or not controller.confirm_exit_without_saving():
		_notice.dialog_text = "Não foi possível descartar o backup. A campanha permanece aberta."
		_notice.popup_centered(Vector2i(490, 145))
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _confirm_abandon() -> void:
	var campaign_id: String = top_bar.gerencia.campaign.campaign_id
	var controller := _autosave_controller()
	if controller != null and not controller.confirm_exit_without_saving():
		_notice.dialog_text = "Não foi possível cancelar o backup pendente. A campanha permanece aberta."
		_notice.popup_centered(Vector2i(500, 145))
		return
	var result: Dictionary = top_bar.gerencia.save_repository.abandon_campaign(
		campaign_id, true)
	if not result.get("success", false):
		_notice.dialog_text = str(result.get("reason", "Não foi possível abandonar a campanha."))
		_notice.popup_centered(Vector2i(500, 145))
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_campaign_abandoned(campaign_id: String) -> void:
	if top_bar.gerencia.campaign.campaign_id != campaign_id:
		return
	var controller := _autosave_controller()
	if controller != null:
		controller.confirm_exit_without_saving()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _autosave_controller() -> CampaignAutosaveController:
	return top_bar.get_parent().get_node_or_null("CampaignAutosaveController") as CampaignAutosaveController


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.pressed \
			or event.echo:
		return
	if event.keycode == KEY_P:
		close()
		get_viewport().set_input_as_handled()
		return
	if _exit.visible or _abandon.visible or _overwrite.visible \
			or _load_confirmation.visible or _notice.visible \
			or _archive_library.visible or _settings_menu.visible \
			or _journal.is_book_open() or _save_panel.visible or _load_panel.visible:
		return
	if _keyboard_navigation.handle(event, _menu):
		get_viewport().set_input_as_handled()
