class_name CampaignSettingsMenu
extends Control

## Vídeo, escala, paleta, conforto visual e áudio são preferências reais. Os
## demais controles permanecem em prévia até terem subsistemas próprios.
signal back_requested
signal contents_prepared

const CYAN := Color(0.35, 0.83, 0.94)
const PINK := Color(0.96, 0.38, 0.66)
const WHITE := Color(0.91, 0.96, 0.99)
const MUTED := Color(0.67, 0.77, 0.83)
const GOLD := Color(0.94, 0.77, 0.35)
const DISPLAY_CONFIG_PATH := "user://ppp_display_settings.cfg"
const VIDEO_CONFIRM_SECONDS := 15
const RESOLUTION_PRESETS: Array[Vector2i] = [
	Vector2i(1920, 1080), Vector2i(1600, 900),
	Vector2i(1366, 768), Vector2i(1280, 720),
]
const PALETTE_IDS := ["padrao", "azul", "rosa_branco", "acessivel"]
const PALETTE_NAMES := ["Padrão", "Azul neon", "Rosa e branco", "Acessível"]
const AUDIO_VOLUME_CONTROLS_SCRIPT := preload("res://scripts/ui/audio_volume_controls.gd")
const DIALOG_STYLE := preload("res://scripts/ui/game_dialog_style.gd")

static var _video_loaded_for_session := false

var _panel: PanelContainer
var _tabs: HBoxContainer
var _body: VBoxContainer
var _tab_buttons: Dictionary = {}
var _pages: Dictionary = {}
var _current_tab := "Gráficos e interface"
var _resolution_control: OptionButton
var _mode_controls: Array[Button] = []
var _scale_controls: Array[Button] = []
var _palette_controls: Array[Button] = []
var _reduce_control: CheckButton
var _reduce_info_button: Button
var _reduce_info_panel: PanelContainer
var _video_confirmation: ConfirmationDialog
var _video_status: Label
var _pending_video: Dictionary = {}
var _confirmation_deadline := 0
var _syncing_video_ui := false
var campaign: CampaignState
var _difficulty_controls: Array[Button] = []
var _difficulty_note: Label
var _contents_ready := false
var _contents_preparing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not bool(get_meta("defer_settings_build", false)):
		_populate_pages()
		_finish_setup()
	else:
		hide()


func _populate_pages() -> void:
	_build_graphics(_pages["Gráficos e interface"])
	_build_gameplay(_pages["Jogabilidade"])
	_build_audio(_pages["Áudio"])
	_build_streamer(_pages["Modo streamer"])


func prepare_contents(progress: Callable = Callable()) -> void:
	if _contents_ready:
		return
	if _contents_preparing:
		await contents_prepared
		return
	_contents_preparing = true
	var stages: Array[Callable] = [
		func() -> void: _build_graphics(_pages["Gráficos e interface"]),
		func() -> void: _build_gameplay(_pages["Jogabilidade"]),
		func() -> void: _build_audio(_pages["Áudio"]),
		func() -> void: _build_streamer(_pages["Modo streamer"]),
	]
	for stage in stages:
		var stage_start := Time.get_ticks_msec()
		stage.call()
		if ProjectSettings.get_setting("ppp/profile_startup", false):
			print("PPP_DETAIL settings section %d ms" % (
				Time.get_ticks_msec() - stage_start))
		if progress.is_valid():
			progress.call()
		await get_tree().process_frame
	_finish_setup()
	_contents_preparing = false
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame


func _finish_setup() -> void:
	if _contents_ready:
		return
	_load_saved_video()
	_sync_video_ui()
	_sync_scale_ui()
	_sync_palette_ui()
	_sync_reduce_ui()
	_sync_difficulty_ui()
	resized.connect(_layout)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.connect("ui_scale_changed", _on_ui_scale_changed)
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service != null:
		palette_service.connect("palette_changed", _on_palette_changed)
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(_on_comfort_changed)
	_layout()
	_show_tab(_current_tab)
	hide()
	_contents_ready = true
	contents_prepared.emit()


func open() -> void:
	if not _contents_ready:
		_populate_pages()
		_finish_setup()
	_sync_difficulty_ui()
	show()
	_show_tab(_current_tab)


func close() -> void:
	if not _pending_video.is_empty():
		_revert_video()
	hide()
	back_requested.emit()


func _exit_tree() -> void:
	if not _pending_video.is_empty():
		_revert_video()


func _process(_delta: float) -> void:
	if _pending_video.is_empty():
		return
	var seconds_left := maxi(0, ceili(float(_confirmation_deadline - Time.get_ticks_msec()) / 1000.0))
	_video_confirmation.dialog_text = "Manter esta resolução e modo de tela?\nRevertendo em %d segundos." % seconds_left
	if seconds_left <= 0:
		_revert_video()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var veil := ColorRect.new()
	veil.name = "BlackVeil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.008, 0.014, 0.021, 0.985)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	_palette_call("bind_rect", [veil, "canvas"])
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.add_theme_stylebox_override("panel", _box(Color(0.025, 0.041, 0.055), CYAN,
		2, "surface", "structure"))
	center.add_child(_panel)
	_palette_call("bind_control_style", [_panel, "panel", "surface", "structure"])
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 11)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var icon := _label("⚙", 25, CYAN)
	icon.custom_minimum_size.x = 35
	header.add_child(icon)
	var title := _label("CONFIGURAÇÕES", 26, WHITE)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var back_top := _button("← VOLTAR", CYAN)
	back_top.custom_minimum_size = Vector2(110, 36)
	back_top.pressed.connect(close)
	header.add_child(back_top)
	_add_rule(stack)
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.add_theme_constant_override("separation", 8)
	stack.add_child(_tabs)
	for tab_name in ["Gráficos e interface", "Jogabilidade", "Áudio", "Modo streamer"]:
		var tab := _button(tab_name, CYAN)
		tab.set_meta("ui_sfx_kind", &"menu_page")
		tab.custom_minimum_size.y = 34
		tab.pressed.connect(_show_tab.bind(tab_name))
		_tabs.add_child(tab)
		_tab_buttons[tab_name] = tab
	_add_rule(stack)
	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	_body = VBoxContainer.new()
	_body.name = "Pages"
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_body)
	for tab_name in ["Gráficos e interface", "Jogabilidade", "Áudio", "Modo streamer"]:
		var page := VBoxContainer.new()
		page.name = tab_name.replace(" ", "").replace("á", "a").replace("e", "e")
		page.add_theme_constant_override("separation", 10)
		page.size_flags_horizontal = SIZE_EXPAND_FILL
		_body.add_child(page)
		_pages[tab_name] = page
	_add_rule(stack)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	stack.add_child(footer)
	var restore := _button("↶ RESTAURAR PADRÕES", CYAN)
	restore.custom_minimum_size = Vector2(190, 36)
	restore.tooltip_text = "Disponível quando as configurações forem implementadas."
	restore.disabled = true
	footer.add_child(restore)
	var notice := _label("VÍDEO, ESCALA, PALETA, REDUÇÃO E ÁUDIO: ATIVOS · DEMAIS: PRÉVIA", 12, MUTED)
	_video_status = notice
	notice.size_flags_horizontal = SIZE_EXPAND_FILL
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(notice)
	_video_confirmation = ConfirmationDialog.new()
	_video_confirmation.title = "Confirmar vídeo"
	_video_confirmation.get_ok_button().text = "MANTER"
	_video_confirmation.get_cancel_button().text = "REVERTER"
	_video_confirmation.confirmed.connect(_confirm_video)
	_video_confirmation.canceled.connect(_revert_video)
	_video_confirmation.close_requested.connect(_revert_video)
	_video_confirmation.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_video_confirmation)
	DIALOG_STYLE.apply(_video_confirmation, "warning", 470.0, 78.0)
	DIALOG_STYLE.make_backdrop(self, [_video_confirmation])
	set_process(false)


func _layout() -> void:
	if _panel == null:
		return
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	var factor := float(scale_service.get("ui_factor")) if scale_service != null else 1.0
	_panel.custom_minimum_size = Vector2(
		minf(1110.0 * factor, maxf(500.0, size.x - 54.0)) / factor,
		minf(760.0 * factor, maxf(430.0, size.y - 50.0)) / factor)


func _on_ui_scale_changed(_factor: float) -> void:
	_layout.call_deferred()


func _show_tab(tab_name: String) -> void:
	_current_tab = tab_name
	for name in _pages:
		(_pages[name] as Control).visible = name == tab_name
		var tab := _tab_buttons[name] as Button
		tab.add_theme_stylebox_override("normal", _box(
			Color(0.13, 0.045, 0.105) if name == tab_name else Color(0.045, 0.07, 0.085),
			PINK if name == tab_name else Color(0.31, 0.49, 0.57),
			2 if name == tab_name else 1,
			"button_selected" if name == tab_name else "button",
			"selection" if name == tab_name else "neutral"))
		_palette_call("bind_control_style", [tab, "normal",
			"button_selected" if name == tab_name else "button",
			"selection" if name == tab_name else "neutral"])
		tab.add_theme_color_override("font_color", WHITE if name == tab_name else MUTED)
		_palette_call("bind_color", [tab, "font_color", "on_button"])
	var scroll := _body.get_parent() as ScrollContainer
	scroll.scroll_vertical = 0


func _build_graphics(page: VBoxContainer) -> void:
	_section(page, "TELA E INTERFACE")
	_resolution_control = OptionButton.new()
	for preset in RESOLUTION_PRESETS:
		_resolution_control.add_item("%d × %d" % [preset.x, preset.y])
	_resolution_control.custom_minimum_size = Vector2(280, 33)
	_resolution_control.add_theme_stylebox_override("normal", _box(
		Color(0.045, 0.07, 0.085), CYAN, 1, "button", "structure"))
	_palette_call("bind_control_style", [_resolution_control, "normal", "button", "structure"])
	_palette_call("bind_color", [_resolution_control, "font_color", "on_button"])
	_resolution_control.item_selected.connect(_on_resolution_selected)
	_field(page, "Resolução", _resolution_control)
	var mode_row := _choices(page, "Modo de tela", ["Janela", "Tela cheia", "Janela sem bordas"], 0)
	for child in mode_row.get_children():
		_mode_controls.append(child as Button)
	for index in _mode_controls.size():
		_mode_controls[index].pressed.connect(_on_mode_selected.bind(index))
	var video_hint := _label("Tela cheia usa a resolução nativa do monitor. A lista mostra tamanhos para janela.", 12, MUTED)
	page.add_child(video_hint)
	_slider(page, "Intensidade de contraste", 100)
	var scale_row := _choices(page, "Escala da interface e fonte",
		["80% · Compacta", "100% · Padrão inicial",
		"125% · Ampliada", "150% · Acessibilidade"], 1)
	for child in scale_row.get_children():
		_scale_controls.append(child as Button)
	for index in _scale_controls.size():
		_scale_controls[index].pressed.connect(_on_ui_scale_selected.bind(index))
	var reduce_row := HBoxContainer.new()
	reduce_row.add_theme_constant_override("separation", 8)
	page.add_child(reduce_row)
	var reduce := CheckButton.new()
	reduce.text = "Reduzir flashes e movimento"
	_reduce_control = reduce
	reduce.add_theme_color_override("font_color", WHITE)
	_palette_call("bind_color", [reduce, "font_color", "primary"])
	reduce.toggled.connect(_on_reduce_toggled)
	reduce_row.add_child(reduce)
	var reduce_info := _button("ⓘ", CYAN)
	reduce_info.name = "VisualComfortInfoButton"
	reduce_info.custom_minimum_size = Vector2(34, 34)
	reduce_info.tooltip_text = "O que muda ao reduzir flashes e movimento?"
	reduce_info.pressed.connect(_toggle_reduce_info)
	reduce_row.add_child(reduce_info)
	_reduce_info_button = reduce_info
	var info_panel := PanelContainer.new()
	info_panel.name = "VisualComfortInfoPanel"
	info_panel.add_theme_stylebox_override("panel", _box(
		Color(0.035, 0.055, 0.072, 0.94), CYAN, 1, "surface", "structure"))
	page.add_child(info_panel)
	_palette_call("bind_control_style", [info_panel, "panel", "surface", "structure"])
	var info_text := _label("Diminui estímulos visuais intensos: substitui piscadas e movimentos bruscos de efeitos adaptados por imagens estáticas ou transições suaves, e atenua luzes e partículas. Na chuva, usa cerca de 35% das gotas e 60% da velocidade normal, com opacidade máxima de 22%; não há um percentual único para todos os efeitos. As regras e os resultados do jogo não mudam. Referência: W3C/WCAG 2.2 (critérios 2.3.1 e 2.3.3). Esta opção busca reduzir gatilhos visuais, mas não garante segurança médica para fotossensibilidade.", 13, WHITE)
	info_text.name = "VisualComfortInfoText"
	info_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UINarrativeFont.apply_label(info_text)
	info_panel.add_child(info_text)
	info_panel.hide()
	_reduce_info_panel = info_panel
	var palette_row := _choices(page, "Paleta de cores da UI",
		["Padrão", "Azul neon", "Rosa e branco", "Acessível"], 0)
	for child in palette_row.get_children():
		_palette_controls.append(child as Button)
	for index in _palette_controls.size():
		_palette_controls[index].pressed.connect(_on_palette_selected.bind(index))
	var note := _label("Paletas alteram a UI e os contornos dos hexes; sprites e cenário não mudam.", 12, MUTED)
	page.add_child(note)


func _build_gameplay(page: VBoxContainer) -> void:
	_section(page, "MODO DE JOGO")
	var explanation := _label("A dificuldade pertence à campanha, não às preferências globais.", 15, WHITE)
	page.add_child(explanation)
	var choices := _choices(page, "Dificuldade", ["Água com Açúcar", "Padrão", "Caótico"], 1)
	for index in 3:
		var option := choices.get_child(index) as Button
		_difficulty_controls.append(option)
		option.disabled = campaign == null
		option.tooltip_text = "Caótico varia o mapa sem cotas de valência; não altera inimigos. A troca vale na próxima Rodada e não refaz o kit inicial." \
			if index == GameDifficulty.Mode.CHAOTIC else \
			"A troca será aplicada na próxima Rodada; o kit inicial não muda."
		option.pressed.connect(_on_difficulty_selected.bind(index))
	_refresh_radio_group(choices)
	_difficulty_note = _label("", 13, CYAN)
	_difficulty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_difficulty_note)
	_sync_difficulty_ui()


func _on_difficulty_selected(mode: int) -> void:
	if campaign != null:
		campaign.request_difficulty(mode)
	_sync_difficulty_ui()


func _sync_difficulty_ui() -> void:
	if _difficulty_controls.size() != 3 or _difficulty_note == null:
		return
	var selected := campaign.difficulty_for_next_round() \
		if campaign != null else GameDifficulty.Mode.STANDARD
	for index in _difficulty_controls.size():
		var button := _difficulty_controls[index]
		button.disabled = campaign == null
		button.set_pressed_no_signal(index == selected)
	_refresh_radio_group(_difficulty_controls[0].get_parent() as HBoxContainer)
	if campaign == null:
		_difficulty_note.text = "ⓘ Escolha a dificuldade ao iniciar um Novo Jogo."
	elif campaign.pending_difficulty >= 0:
		_difficulty_note.text = "ⓘ Atual: %s. Próxima Rodada: %s. Salve a campanha para preservar a escolha." % [
			GameDifficulty.label(campaign.difficulty), GameDifficulty.label(selected)]
	else:
		_difficulty_note.text = "ⓘ Atual: %s. Uma troca durante a partida entra em vigor na próxima Rodada." % \
			GameDifficulty.label(campaign.difficulty)


func _build_audio(page: VBoxContainer) -> void:
	_section(page, "ÁUDIO")
	var controls := AUDIO_VOLUME_CONTROLS_SCRIPT.new() as VBoxContainer
	controls.name = "AudioVolumeControls"
	controls.size_flags_horizontal = SIZE_EXPAND_FILL
	page.add_child(controls)
	var note := _label("Volumes e mudo funcionam e são preservados entre sessões. As faixas e efeitos sonoros serão adicionados depois.", 13, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)


func _build_streamer(page: VBoxContainer) -> void:
	var note := _label("EM BREVE", 22, WHITE)
	note.name = "StreamerComingSoon"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.y = 200
	page.add_child(note)


func _section(parent: VBoxContainer, title: String) -> void:
	var label := _label(title, 17, CYAN)
	parent.add_child(label)
	_add_rule(parent)


func _field(parent: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := _label(title, 14, WHITE)
	label.custom_minimum_size.x = 250
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	row.add_child(control)


func _choices(parent: VBoxContainer, title: String,
		options: Array[String], selected: int) -> HBoxContainer:
	var label := _label(title, 14, WHITE)
	parent.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for index in options.size():
		var radio := Button.new()
		radio.set_meta(&"caption", options[index])
		radio.toggle_mode = true
		radio.button_group = group
		radio.button_pressed = index == selected
		radio.add_theme_color_override("font_disabled_color", MUTED)
		radio.tooltip_text = "Prévia visual: esta escolha ainda não é aplicada."
		row.add_child(radio)
		radio.toggled.connect(func(_pressed: bool) -> void:
			_refresh_radio_group(row))
	_refresh_radio_group(row)
	return row


func _refresh_radio_group(row: HBoxContainer) -> void:
	for child in row.get_children():
		var choice := child as Button
		var picked := choice.button_pressed
		choice.text = "%s  %s" % ["●" if picked else "○", choice.get_meta(&"caption", "")]
		var normal := _box(Color(0.09, 0.055, 0.10) if picked else Color(0.033, 0.052, 0.067),
			PINK if picked else Color(0.29, 0.45, 0.53), 2 if picked else 1,
			"button_selected" if picked else "button",
			"selection" if picked else "neutral")
		choice.add_theme_stylebox_override("normal", normal)
		choice.add_theme_stylebox_override("pressed", normal)
		choice.add_theme_stylebox_override("disabled", _box(Color(0.027, 0.042, 0.052),
			Color(0.24, 0.35, 0.40), 1, "button", "disabled"))
		choice.add_theme_stylebox_override("hover", _box(Color(0.08, 0.09, 0.12),
			CYAN, 2, "button_hover", "structure"))
		for key in ["normal", "pressed"]:
			_palette_call("bind_control_style", [choice, key,
				"button_selected" if picked else "button",
				"selection" if picked else "neutral"])
		_palette_call("bind_control_style", [choice, "hover", "button_hover", "structure"])
		_palette_call("bind_control_style", [choice, "disabled", "button", "disabled"])
		choice.add_theme_color_override("font_color", WHITE)
		choice.add_theme_color_override("font_pressed_color", WHITE)
		choice.add_theme_color_override("font_disabled_color", MUTED)
		_palette_call("bind_color", [choice, "font_color", "on_button"])
		_palette_call("bind_color", [choice, "font_pressed_color", "on_button"])
		_palette_call("bind_color", [choice, "font_disabled_color", "on_button_disabled"])


func _slider(parent: VBoxContainer, title: String, value: int) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(title, 14, WHITE)
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(label)
	var percentage := _label("%d%%" % value, 13, CYAN)
	row.add_child(percentage)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(0, 22)
	slider.max_value = 100
	slider.value = value
	slider.tooltip_text = "Prévia visual: o valor ainda não altera o jogo."
	slider.value_changed.connect(func(new_value: float) -> void:
		percentage.text = "%d%%" % roundi(new_value))
	parent.add_child(slider)


func _on_resolution_selected(index: int) -> void:
	if _syncing_video_ui or _video_confirmation.visible:
		return
	_request_video(_current_mode_index(), index)


func _on_mode_selected(index: int) -> void:
	if _syncing_video_ui or _video_confirmation.visible:
		return
	var resolution_index := _resolution_control.selected
	if index != 1 and not _preset_fits(resolution_index):
		for candidate in RESOLUTION_PRESETS.size():
			if _preset_fits(candidate):
				resolution_index = candidate
				break
	_request_video(index, resolution_index)


func _request_video(mode_index: int, resolution_index: int) -> void:
	if DisplayServer.get_name() == "headless":
		_sync_video_ui()
		return
	if mode_index != 1 and not _preset_fits(resolution_index):
		_sync_video_ui()
		return
	var previous := _capture_video()
	var selected_resolution := RESOLUTION_PRESETS[clampi(resolution_index, 0,
		RESOLUTION_PRESETS.size() - 1)]
	if mode_index == _current_mode_index() and (
			mode_index == 1 or DisplayServer.window_get_size() == selected_resolution):
		_sync_video_ui()
		return
	_pending_video = previous
	_apply_video(mode_index, selected_resolution)
	_sync_video_ui()
	_confirmation_deadline = Time.get_ticks_msec() + VIDEO_CONFIRM_SECONDS * 1000
	set_process(true)
	_video_confirmation.popup_centered(Vector2i(475, 170))


func _capture_video() -> Dictionary:
	return {
		"mode": DisplayServer.window_get_mode(),
		"size": DisplayServer.window_get_size(),
		"position": DisplayServer.window_get_position(),
		"borderless": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
	}


func _current_mode_index() -> int:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
			or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return 1
	return 2 if DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) else 0


func _apply_video(mode_index: int, selected_resolution: Vector2i) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, mode_index == 2)
	if mode_index == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_size(selected_resolution)
		var usable := _usable_screen()
		DisplayServer.window_set_position(usable.position +
			(usable.size - selected_resolution) / 2)


func _restore_video(state: Dictionary) -> void:
	if DisplayServer.get_name() == "headless" or state.is_empty():
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,
		bool(state.get("borderless", false)))
	DisplayServer.window_set_size(state.get("size", Vector2i(1600, 900)))
	DisplayServer.window_set_position(state.get("position", Vector2i.ZERO))
	DisplayServer.window_set_mode(int(state.get("mode", DisplayServer.WINDOW_MODE_WINDOWED)))


func _confirm_video() -> void:
	if _pending_video.is_empty():
		return
	_pending_video.clear()
	set_process(false)
	var config := ConfigFile.new()
	config.set_value("video", "mode", _current_mode_index())
	config.set_value("video", "resolution", _selected_resolution())
	var result := config.save(DISPLAY_CONFIG_PATH)
	_video_status.text = "VÍDEO CONFIRMADO E SALVO" if result == OK else \
		"VÍDEO APLICADO, MAS NÃO FOI POSSÍVEL SALVAR A PREFERÊNCIA"
	_video_status.add_theme_color_override("font_color", CYAN if result == OK else GOLD)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null and scale_service.call("ensure_scale_fits_window"):
		_video_status.text = "VÍDEO SALVO · ESCALA AJUSTADA PARA 125% POR SEGURANÇA"
	_sync_video_ui()
	_sync_scale_ui()


func _revert_video() -> void:
	if _pending_video.is_empty():
		return
	var old_state := _pending_video.duplicate()
	_pending_video.clear()
	set_process(false)
	_video_confirmation.hide()
	_restore_video(old_state)
	_video_status.text = "ALTERAÇÃO DE VÍDEO REVERTIDA"
	_video_status.add_theme_color_override("font_color", GOLD)
	_sync_video_ui()
	_sync_scale_ui()


func _load_saved_video() -> void:
	if DisplayServer.get_name() == "headless" or _video_loaded_for_session:
		return
	# O mesmo painel nasce no menu e outra vez na cena de jogo. Reaplicar o
	# modo de tela em cada instanciação provocava resize durante a transição.
	_video_loaded_for_session = true
	var config := ConfigFile.new()
	if config.load(DISPLAY_CONFIG_PATH) != OK:
		return
	var mode_index := int(config.get_value("video", "mode", -1))
	var selected_resolution: Variant = config.get_value("video", "resolution", Vector2i.ZERO)
	if mode_index < 0 or mode_index > 2 or not selected_resolution is Vector2i:
		return
	var resolution := selected_resolution as Vector2i
	if resolution not in RESOLUTION_PRESETS:
		return
	if mode_index != 1 and (resolution.x > _usable_screen().size.x
			or resolution.y > _usable_screen().size.y):
		return
	_apply_video(mode_index, resolution)


func _selected_resolution() -> Vector2i:
	return RESOLUTION_PRESETS[clampi(_resolution_control.selected, 0,
		RESOLUTION_PRESETS.size() - 1)]


func _usable_screen() -> Rect2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.SCREEN_OF_MAIN_WINDOW)
	if usable.size == Vector2i.ZERO:
		usable = Rect2i(Vector2i.ZERO, Vector2i(1920, 1080))
	return usable


func _preset_fits(index: int) -> bool:
	if index < 0 or index >= RESOLUTION_PRESETS.size():
		return false
	var usable := _usable_screen().size
	return RESOLUTION_PRESETS[index].x <= usable.x \
		and RESOLUTION_PRESETS[index].y <= usable.y


func _sync_video_ui() -> void:
	if _resolution_control == null:
		return
	_syncing_video_ui = true
	var mode_index := _current_mode_index()
	for index in _mode_controls.size():
		_mode_controls[index].button_pressed = index == mode_index
	_refresh_radio_group(_mode_controls[0].get_parent() as HBoxContainer)
	var current_size := DisplayServer.window_get_size()
	var selected_index := 0
	var best_distance := INF
	for index in RESOLUTION_PRESETS.size():
		var preset := RESOLUTION_PRESETS[index]
		var distance := (Vector2(current_size) - Vector2(preset)).length_squared()
		if distance < best_distance:
			best_distance = distance
			selected_index = index
		_resolution_control.set_item_disabled(index,
			mode_index != 1 and not _preset_fits(index))
	_resolution_control.select(selected_index)
	_resolution_control.disabled = mode_index == 1
	_resolution_control.tooltip_text = "Tela cheia usa a resolução nativa do monitor." if mode_index == 1 else \
		"Tamanhos que não cabem no monitor ficam indisponíveis."
	_syncing_video_ui = false
	_sync_scale_ui()


func _on_ui_scale_selected(index: int) -> void:
	var service := get_node_or_null("/root/UniversalFontScale")
	if service == null:
		return
	var factors := [0.8, 1.0, 1.25, 1.5]
	var chosen := float(factors[clampi(index, 0, factors.size() - 1)])
	if chosen == 1.5 and not service.call("can_use_150_percent"):
		_sync_scale_ui()
		return
	var saved := bool(service.call("set_ui_scale", chosen))
	_video_status.text = "ESCALA %d%% APLICADA" % roundi(chosen * 100.0) if saved else \
		"ESCALA APLICADA, MAS NÃO FOI POSSÍVEL SALVAR A PREFERÊNCIA"
	_video_status.add_theme_color_override("font_color", CYAN if saved else GOLD)
	_sync_scale_ui()


func _sync_scale_ui() -> void:
	if _scale_controls.is_empty():
		return
	var service := get_node_or_null("/root/UniversalFontScale")
	if service == null:
		return
	var factor := float(service.get("ui_factor"))
	var factors := [0.8, 1.0, 1.25, 1.5]
	for index in _scale_controls.size():
		_scale_controls[index].button_pressed = is_equal_approx(factor, float(factors[index]))
	_refresh_radio_group(_scale_controls[0].get_parent() as HBoxContainer)
	_scale_controls[3].disabled = not bool(service.call("can_use_150_percent"))
	_scale_controls[3].tooltip_text = "Exige resolução ativa de pelo menos 1920 × 1080." if \
		_scale_controls[3].disabled else "Escala de acessibilidade para tela grande."


func _on_palette_selected(index: int) -> void:
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service == null:
		return
	var id: String = PALETTE_IDS[clampi(index, 0, PALETTE_IDS.size() - 1)]
	var saved: bool = bool(palette_service.call("set_palette", id))
	_video_status.text = "PALETA %s APLICADA" % PALETTE_NAMES[index].to_upper() if saved else \
		"PALETA APLICADA, MAS NÃO FOI POSSÍVEL SALVAR A PREFERÊNCIA"
	_video_status.add_theme_color_override("font_color", CYAN if saved else GOLD)
	_sync_palette_ui()


func _on_palette_changed(_palette_id: String) -> void:
	_sync_palette_ui()


func _sync_palette_ui() -> void:
	if _palette_controls.is_empty():
		return
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service == null:
		return
	for index in _palette_controls.size():
		_palette_controls[index].button_pressed = \
			str(palette_service.get("palette_id")) == PALETTE_IDS[index]
		_palette_controls[index].tooltip_text = \
			"Altera as cores da interface sem modificar sprites, mapa ou cenário."
	_refresh_radio_group(_palette_controls[0].get_parent() as HBoxContainer)


func _on_reduce_toggled(value: bool) -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort == null:
		return
	var saved: bool = bool(comfort.call("set_enabled", value))
	_video_status.text = "REDUÇÃO VISUAL %s" % ("ATIVA" if value else "DESATIVADA") \
		if saved else "REDUÇÃO ALTERADA, MAS A PREFERÊNCIA NÃO FOI SALVA"
	_palette_call("bind_color", [_video_status, "font_color",
		"structure" if saved else "warning"])


func _toggle_reduce_info() -> void:
	if _reduce_info_panel == null:
		return
	_reduce_info_panel.visible = not _reduce_info_panel.visible
	_reduce_info_button.tooltip_text = "Ocultar explicação" if _reduce_info_panel.visible \
		else "O que muda ao reduzir flashes e movimento?"


func _on_comfort_changed(_enabled: bool) -> void:
	_sync_reduce_ui()


func _sync_reduce_ui() -> void:
	if _reduce_control == null:
		return
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		_reduce_control.set_pressed_no_signal(bool(comfort.get("enabled")))


func _add_rule(parent: Control) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color(0.28, 0.67, 0.79, 0.52)
	line.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(line)
	_palette_call("bind_rect", [line, "structure"])


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_palette_call("bind_color", [label, "font_color", _role_for_accent(color)])
	return label


func _button(value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = value
	var role := _role_for_accent(accent)
	button.add_theme_stylebox_override("normal", _box(Color(0.045, 0.07, 0.085),
		accent, 1, "button", role))
	button.add_theme_stylebox_override("hover", _box(Color(0.075, 0.11, 0.13),
		accent.lightened(0.20), 2, "button_hover", role))
	_palette_call("bind_control_style", [button, "normal", "button", role])
	_palette_call("bind_control_style", [button, "hover", "button_hover", role])
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	_palette_call("bind_color", [button, "font_color", "on_button"])
	_palette_call("bind_color", [button, "font_hover_color", "on_button"])
	_palette_call("bind_color", [button, "font_disabled_color", "on_button_disabled"])
	return button


func _box(background: Color, border: Color, width: int = 1,
		background_role: String = "surface", border_role: String = "neutral") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_palette_call("bind_style", [style, background_role, border_role])
	return style


func _role_for_accent(accent: Color) -> String:
	if accent == CYAN:
		return "structure"
	if accent == PINK:
		return "selection"
	if accent == GOLD:
		return "warning"
	if accent == MUTED:
		return "secondary"
	if accent == WHITE:
		return "primary"
	return "neutral"


func _palette_call(method: String, args: Array) -> void:
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service != null:
		palette_service.callv(method, args)
