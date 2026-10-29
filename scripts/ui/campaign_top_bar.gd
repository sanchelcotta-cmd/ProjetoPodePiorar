class_name CampaignTopBar
extends CanvasLayer

signal initial_ui_prepared

## Relógio e localização da campanha. Lê o estado atual; não decide regras.
## O botão ☰ abre a pausa; a próxima fase tem seu próprio botão no mapa.
## O botão ♪ abre a minicaixa de volumes; não silencia diretamente.

@export var gerencia: GerenciaJogo
@export var round_manager: RoundManager
@export var combat_mode_style: StyleBoxFlat

@onready var day_label: Label = $Bar/Items/Day/DayText
@onready var information_button: Button = $Bar/Items/InformationButton
@onready var journal_button: Button = $Bar/Items/JournalButton
@onready var group_inventory_button: Button = $Bar/Items/GroupInventoryButton
@onready var period_label: Label = $Bar/Items/Period/PeriodText
@onready var district_label: Label = $Bar/Items/District/DistrictText
@onready var mode_label: Label = $Bar/Items/Mode/ModeText
@onready var mode_panel: PanelContainer = $Bar/Items/Mode
@onready var bar_panel: PanelContainer = $Bar
@onready var combat_border: Panel = $CombatBorder
@onready var pause_button: Button = $Bar/Items/PauseButton
@onready var sound_button: Button = $Bar/Items/SoundButton

var _last_signature := ""
var information_archive: InformationArchivePanel
var group_inventory: GroupInventoryPanel
var journal_ui: CampaignJournalUI
var _exploration_mode_style: StyleBox
var _exploration_bar_style: StyleBox
var _combat_bar_style: StyleBoxFlat
var _exploration_mode_text_color: Color
var _save_dialog: ConfirmationDialog
var _save_slot_options: OptionButton
var _overwrite_dialog: ConfirmationDialog
var _exit_dialog: ConfirmationDialog
var _save_feedback: AcceptDialog
var _terminal_dialog: AcceptDialog
var _day_transition: CanvasLayer
var _final_center_transition: CampaignFinalCenterTransition
var _pending_day_transition := 0
var _last_day_save_prompt := 0
var _terminal_notice_pending := false
var _observed_campaign: CampaignState
var _selected_save_slot := 0
var _recovery_save_prompt := false
const INFORMATION_ARCHIVE_SCENE = preload("res://scenes/ui/information_archive_panel.tscn")
const GROUP_INVENTORY_SCENE = preload("res://scenes/ui/group_inventory_panel.tscn")
const PAUSE_MENU_SCRIPT = preload("res://scripts/ui/campaign_pause_menu.gd")
const AUDIO_QUICK_PANEL_SCRIPT = preload("res://scripts/ui/audio_quick_panel.gd")
const DIALOG_STYLE = preload("res://scripts/ui/game_dialog_style.gd")
const DAY_TRANSITION_SCENE = preload("res://scenes/ui/campaign_day_transition.tscn")
const FINAL_CENTER_TRANSITION_SCENE = preload("res://scenes/ui/campaign_final_center_transition.tscn")
const KEYBOARD_BUTTON_NAVIGATION = preload("res://scripts/ui/keyboard_button_navigation.gd")
const TUTORIAL_WINDOW_SCRIPT = preload("res://scripts/ui/tutorial_window.gd")
const TUTORIAL_SHORTCUT_SCRIPT = preload("res://scripts/ui/tutorial_shortcut.gd")
const TUTORIAL_INVITATION_SCRIPT = preload("res://scripts/ui/tutorial_invitation.gd")
var pause_menu
var _audio_quick_panel
var _keyboard_region := &"none"
var _topbar_keyboard_navigation := KEYBOARD_BUTTON_NAVIGATION.new()
var _initial_ui_ready := false
var _initial_ui_preparing := false
var _tutorial_shortcut: TutorialShortcut
var _tutorial_window: TutorialWindow
var _tutorial_invitation: TutorialInvitation
var _tutorial_session_active := false
var _tutorial_was_paused := false


func is_initial_ui_ready() -> bool:
	return _initial_ui_ready


func _ready() -> void:
	_exploration_mode_style = mode_panel.get_theme_stylebox("panel").duplicate()
	_exploration_bar_style = bar_panel.get_theme_stylebox("panel").duplicate()
	_exploration_mode_text_color = mode_label.get_theme_color("font_color")
	_combat_bar_style = _exploration_bar_style.duplicate() as StyleBoxFlat
	_combat_bar_style.border_width_top = 2
	_combat_bar_style.border_color = Color(0.87, 0.09, 0.12, 1.0)
	if combat_mode_style != null:
		combat_mode_style = combat_mode_style.duplicate() as StyleBoxFlat
	_bind_palette()
	if not bool(get_parent().get_meta("defer_preview_map", false)):
		_build_initial_ui()
	information_button.pressed.connect(_toggle_information_archive)
	journal_button.pressed.connect(_toggle_journal)
	group_inventory_button.pressed.connect(_toggle_group_inventory)
	pause_button.pressed.connect(func() -> void:
		_audio_quick_panel.close()
		pause_menu.open())
	sound_button.pressed.connect(_toggle_sound)
	_create_tutorial_shortcut()
	_refresh_sound()
	_refresh_tutorial_shortcut()
	if gerencia != null:
		gerencia.map_generated.connect(func(_map: HexGrid) -> void: refresh())
		bind_campaign(gerencia.campaign)
	if round_manager != null:
		round_manager.round_advanced.connect(func(_day: int, _period: int,
			_district: StringName, _map: HexGrid) -> void: refresh())
		round_manager.new_day_started.connect(_on_new_day_started)
	refresh()


func _build_initial_ui() -> void:
	if _initial_ui_ready:
		return
	_create_information_archive()
	_create_journal()
	_create_group_inventory()
	_create_pause_menu()
	_create_audio_quick_panel()
	_build_save_dialogs()
	_initial_ui_ready = true
	initial_ui_prepared.emit()


## Chamado pela transição antes do mapa ser revelado. Cada fase termina e
## cede um quadro; nós e controles continuam criados na thread principal.
func prepare_initial_ui(progress: Callable = Callable()) -> void:
	if _initial_ui_ready:
		return
	if _initial_ui_preparing:
		await initial_ui_prepared
		return
	_initial_ui_preparing = true
	var stages: Array[Callable] = [
		_create_information_archive, _create_journal,
		_create_group_inventory, _create_pause_menu,
	]
	for stage in stages:
		var stage_start := Time.get_ticks_msec()
		stage.call()
		if ProjectSettings.get_setting("ppp/profile_startup", false):
			print("PPP_DETAIL ui %-30s %d ms" % [stage.get_method(),
				Time.get_ticks_msec() - stage_start])
		if progress.is_valid():
			progress.call()
		await get_tree().process_frame
	await pause_menu.prepare_panels(progress)
	var stage_start := Time.get_ticks_msec()
	_create_audio_quick_panel()
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL ui audio quick %d ms" % (Time.get_ticks_msec() - stage_start))
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame
	stage_start = Time.get_ticks_msec()
	_build_save_dialogs()
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL ui save dialogs %d ms" % (Time.get_ticks_msec() - stage_start))
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame
	_initial_ui_preparing = false
	_initial_ui_ready = true
	initial_ui_prepared.emit()


func _create_information_archive() -> void:
	information_archive = INFORMATION_ARCHIVE_SCENE.instantiate() as InformationArchivePanel
	add_child(information_archive)
	information_archive.gerencia = gerencia


func _create_journal() -> void:
	journal_ui = CampaignJournalUI.new()
	add_child(journal_ui)
	journal_ui.bind_campaign(gerencia.campaign if gerencia != null else null)
	journal_ui.set_tutorial_shortcut_visible(
		_tutorial_shortcut != null and _tutorial_shortcut.visible)


func _create_group_inventory() -> void:
	group_inventory = GROUP_INVENTORY_SCENE.instantiate() as GroupInventoryPanel
	group_inventory.gerencia = gerencia
	group_inventory.skill_manager = get_parent().get_node_or_null("SkillManager") as SkillManager
	group_inventory.combat_manager = get_parent().get_node_or_null("CombatManager") as CombatManager
	group_inventory.exploration = get_parent().get_node_or_null("ExplorationManager") as ExplorationManager
	# _ready() cria o menu de itens e copia essas referências. Elas precisam
	# existir antes de o painel entrar na árvore, inclusive durante o loading.
	add_child(group_inventory)
	var hud := get_parent().get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	if hud != null:
		# A rolagem extra deve surgir no card assim que o item for consumido,
		# sem esperar a próxima atualização periódica da HUD.
		group_inventory.item_menu.inventory_changed.connect(
			hud._on_item_inventory_changed)
	if group_inventory.combat_manager != null:
		group_inventory.death_cleanup_completed.connect(
			group_inventory.combat_manager.on_promotion_cleanup_confirmed)


func _create_pause_menu() -> void:
	pause_menu = PAUSE_MENU_SCRIPT.new()
	pause_menu.top_bar = self
	add_child(pause_menu)


func _create_audio_quick_panel() -> void:
	_audio_quick_panel = AUDIO_QUICK_PANEL_SCRIPT.new()
	add_child(_audio_quick_panel)


func bind_campaign(campaign: CampaignState) -> void:
	if _observed_campaign == campaign:
		return
	if _observed_campaign != null:
		if _observed_campaign.playable_death_finalized.is_connected(
				_on_playable_death_finalized):
			_observed_campaign.playable_death_finalized.disconnect(
				_on_playable_death_finalized)
		if _observed_campaign.campaign_terminal_changed.is_connected(
				_on_campaign_terminal_changed):
			_observed_campaign.campaign_terminal_changed.disconnect(
				_on_campaign_terminal_changed)
	_observed_campaign = campaign
	_terminal_notice_pending = false
	if campaign == null:
		return
	campaign.playable_death_finalized.connect(_on_playable_death_finalized)
	campaign.campaign_terminal_changed.connect(_on_campaign_terminal_changed)
	if campaign.is_terminal() and _terminal_dialog != null:
		_on_campaign_terminal_changed.call_deferred(campaign.campaign_status,
			campaign.obtained_information_order.size())
	_refresh_sound()


func _on_playable_death_finalized(actor: EntityState,
		leftover: Array[InventoryItemState]) -> void:
	if group_inventory == null or gerencia == null or gerencia.campaign == null:
		return
	var replacement := gerencia.campaign.get_playable_slot(actor.playable_slot_id)
	if leftover.is_empty() and (replacement == null or replacement == actor):
		return
	_show_death_cleanup_after_animation.call_deferred(actor)


func _show_death_cleanup_after_animation(actor: EntityState) -> void:
	# DeathBlink dura 2,5 s. A vaga muda imediatamente no estado, mas a
	# redistribuição só cobre o mapa depois das três piscadas.
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree() and group_inventory != null:
		group_inventory.begin_death_cleanup(actor)


func _toggle_information_archive() -> void:
	if group_inventory != null and group_inventory.get("_death_owner") != null:
		return
	if information_archive.visible:
		information_archive.close()
	else:
		journal_ui.close_book()
		group_inventory.close()
		information_archive.open()


func _toggle_journal() -> void:
	if group_inventory != null and group_inventory.get("_death_owner") != null:
		return
	if journal_ui.is_book_open():
		journal_ui.close_book()
	else:
		information_archive.close()
		group_inventory.close()
		journal_ui.open_book()


func _toggle_group_inventory() -> void:
	if group_inventory != null and group_inventory.get("_death_owner") != null:
		return
	if group_inventory.visible:
		group_inventory.close()
	else:
		journal_ui.close_book()
		information_archive.close()
		group_inventory.open()


func close_expandable_boxes() -> void:
	if _audio_quick_panel != null and _audio_quick_panel.visible:
		_audio_quick_panel.close()
	if information_archive != null and information_archive.visible:
		information_archive.close()
	if group_inventory != null and group_inventory.visible:
		group_inventory.close()
	if journal_ui != null and journal_ui.is_book_open():
		journal_ui.close_book()


func _process(_delta: float) -> void:
	# A troca Exploração/Combate ainda não emite sinal próprio.
	refresh()
	_try_open_final_center_intro()
	_try_resume_final_center_arrival()
	_try_show_terminal_notice()


func refresh() -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	var campaign := gerencia.campaign
	var mode := HexGrid.PPPMapMode.EXPLORATION
	if campaign.current_map != null:
		@warning_ignore("int_as_enum_without_cast")
		mode = campaign.current_map.ppp_map_mode
	var signature := "%d|%d|%s|%d" % [campaign.day, campaign.round_period,
		campaign.district, mode]
	if signature == _last_signature:
		return
	_last_signature = signature
	day_label.text = "▣ DIA %d" % campaign.day
	match campaign.round_period:
		PPPMapGenerator.RoundPeriod.MORNING:
			period_label.text = "☀ MANHÃ"
		PPPMapGenerator.RoundPeriod.AFTERNOON:
			period_label.text = "☀ TARDE"
		PPPMapGenerator.RoundPeriod.NIGHT:
			period_label.text = "☾ NOITE"
	match campaign.district:
		&"suburbio": district_label.text = "◆ SUBÚRBIO"
		&"baixo_centro": district_label.text = "◆ BAIXO-CENTRO"
		&"centro": district_label.text = "◆ CENTRO"
		_: district_label.text = "◆ %s" % str(campaign.district).to_upper()
	mode_label.text = "MODO:\nCOMBATE" if mode == HexGrid.PPPMapMode.COMBAT \
		else "MODO:\nEXPLORAÇÃO"
	var in_combat := mode == HexGrid.PPPMapMode.COMBAT
	mode_panel.add_theme_stylebox_override("panel", combat_mode_style if in_combat \
		else _exploration_mode_style)
	bar_panel.add_theme_stylebox_override("panel", _combat_bar_style if in_combat \
		else _exploration_bar_style)
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.call("bind_control_style", mode_panel, "panel",
			"button_danger" if in_combat else "button",
			"danger" if in_combat else "warning")
		palette.call("bind_control_style", bar_panel, "panel", "surface",
			"danger" if in_combat else "structure")
	mode_label.add_theme_color_override("font_color",
		palette.call("color", "on_button") if palette != null \
		else Color(1.0, 0.38, 0.39) if in_combat else _exploration_mode_text_color)
	combat_border.visible = in_combat
	_refresh_tutorial_shortcut()


func _create_tutorial_shortcut() -> void:
	_tutorial_shortcut = TUTORIAL_SHORTCUT_SCRIPT.new() as TutorialShortcut
	_tutorial_shortcut.name = "DayOneTutorialShortcut"
	_tutorial_shortcut.opened.connect(open_tutorial)
	_tutorial_shortcut.presentation_changed.connect(_on_tutorial_shortcut_changed)
	add_child(_tutorial_shortcut)
	_refresh_tutorial_shortcut()


func _refresh_tutorial_shortcut() -> void:
	if _tutorial_shortcut == null:
		return
	var campaign := gerencia.campaign if gerencia != null else null
	_tutorial_shortcut.visible = campaign != null and campaign.day == 1 \
		and not campaign.tutorial_day_one_shortcut_dismissed
	if campaign != null:
		_tutorial_shortcut.set_presentation(campaign.tutorial_shortcut_y_ratio,
			campaign.tutorial_shortcut_collapsed)
	if journal_ui != null:
		journal_ui.set_tutorial_shortcut_visible(_tutorial_shortcut.visible)


func _on_tutorial_shortcut_changed(y_ratio: float, collapsed: bool) -> void:
	var campaign := gerencia.campaign if gerencia != null else null
	if campaign == null:
		return
	campaign.tutorial_shortcut_y_ratio = y_ratio
	campaign.tutorial_shortcut_collapsed = collapsed
	_request_tutorial_autosave()


func maybe_show_initial_tutorial() -> void:
	# A chamada ocorre depois que a tela de carregamento sai da árvore.
	await get_tree().process_frame
	if not is_instance_valid(self) or gerencia == null or gerencia.campaign == null:
		return
	var campaign := gerencia.campaign
	if campaign.day != 1 or campaign.tutorial_invitation_seen \
			or campaign.tutorial_day_one_shortcut_dismissed:
		return
	campaign.tutorial_invitation_seen = true
	_request_tutorial_autosave()
	_begin_tutorial_session()
	_ensure_tutorial_invitation()
	_tutorial_invitation.open_invitation()


func _ensure_tutorial_invitation() -> void:
	if _tutorial_invitation != null:
		return
	_tutorial_invitation = TUTORIAL_INVITATION_SCRIPT.new() as TutorialInvitation
	_tutorial_invitation.confirmed.connect(open_tutorial)
	_tutorial_invitation.canceled.connect(_end_tutorial_session)
	add_child(_tutorial_invitation)


func _ensure_tutorial_window() -> void:
	if _tutorial_window != null:
		return
	_tutorial_window = TUTORIAL_WINDOW_SCRIPT.new() as TutorialWindow
	add_child(_tutorial_window)
	_tutorial_window.closed.connect(_end_tutorial_session)
	_tutorial_window.day_one_dismiss_requested.connect(
		_on_tutorial_day_one_dismiss_requested)


func open_tutorial() -> void:
	_begin_tutorial_session()
	_ensure_tutorial_window()
	var campaign := gerencia.campaign if gerencia != null else null
	_tutorial_window.open(campaign != null and campaign.day == 1 \
		and not campaign.tutorial_day_one_shortcut_dismissed)


func open_tutorial_from_settings() -> void:
	open_tutorial()


func _on_tutorial_day_one_dismiss_requested() -> void:
	var campaign := gerencia.campaign if gerencia != null else null
	if campaign != null:
		campaign.tutorial_day_one_shortcut_dismissed = true
		_request_tutorial_autosave()
	_refresh_tutorial_shortcut()
	if _tutorial_window != null:
		_tutorial_window.close()


func _begin_tutorial_session() -> void:
	if _tutorial_session_active:
		return
	_tutorial_was_paused = get_tree().paused
	_tutorial_session_active = true
	get_tree().paused = true


func _end_tutorial_session() -> void:
	if not _tutorial_session_active:
		return
	get_tree().paused = _tutorial_was_paused
	_tutorial_session_active = false


func _request_tutorial_autosave() -> void:
	var autosave := get_parent().get_node_or_null("CampaignAutosaveController")
	if autosave != null:
		autosave.call("request_autosave", &"tutorial")


func _bind_palette() -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette == null:
		return
	palette.call("bind_style", _exploration_bar_style, "surface", "structure")
	palette.call("bind_style", _combat_bar_style, "surface", "danger")
	palette.call("bind_style", _exploration_mode_style, "button", "warning")
	if combat_mode_style != null:
		palette.call("bind_style", combat_mode_style, "button_danger", "danger")
	palette.call("bind_control_style", bar_panel, "panel", "surface", "structure")
	palette.call("bind_control_style", mode_panel, "panel", "button", "warning")
	for panel in [$Bar/Items/Day, $Bar/Items/Period, $Bar/Items/District]:
		var local_style := (panel as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if local_style != null:
			var unique_style := local_style.duplicate() as StyleBoxFlat
			(panel as Control).add_theme_stylebox_override("panel", unique_style)
			palette.call("bind_style", unique_style, "surface", "neutral")
			palette.call("bind_control_style", panel, "panel", "surface", "neutral")
	for pair in [[day_label, "primary"], [period_label, "warning"],
			[district_label, "selection"], [mode_label, "on_button"]]:
		palette.call("bind_color", pair[0], "font_color", pair[1])
	for button in [information_button, journal_button, group_inventory_button,
			pause_button, sound_button]:
		for key in ["normal", "hover", "pressed"]:
			var existing := button.get_theme_stylebox(key) as StyleBoxFlat
			if existing != null:
				var unique_style := existing.duplicate() as StyleBoxFlat
				button.add_theme_stylebox_override(key, unique_style)
				palette.call("bind_style", unique_style,
					"button_hover" if key != "normal" else "button", "structure")
				palette.call("bind_control_style", button, key,
					"button_hover" if key != "normal" else "button", "structure")
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			palette.call("bind_color", button, key, "on_button")
	palette.connect("palette_changed", func(_new_id: String) -> void:
		_last_signature = ""
		refresh())


func _unhandled_key_input(event: InputEvent) -> void:
	if not _initial_ui_ready:
		return
	if event.is_action_pressed("ui_cancel") and _audio_quick_panel.visible:
		_audio_quick_panel.close()
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey and event.pressed and not event.echo) \
			or pause_menu.is_open():
		return
	var key := (event as InputEventKey).keycode
	var block_popup := get_parent().get_node_or_null("BlockActivationPopup") as BlockActivationPopup
	if get_tree().paused or (block_popup != null and block_popup.overlay.visible) \
			or (round_manager != null and round_manager.is_destination_choice_open()):
		return
	if key == KEY_P:
		_keyboard_region = &"none"
		_topbar_keyboard_navigation.clear()
		var hud := get_parent().get_node_or_null("PartyStatusHUD") as PartyStatusHUD
		if hud != null:
			hud.keyboard_clear_card_focus()
		_audio_quick_panel.close()
		pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_E and _craft_shortcut_available():
		var hud := get_parent().get_node_or_null("PartyStatusHUD") as PartyStatusHUD
		if hud != null:
			hud.close_expandable_boxes()
		close_expandable_boxes()
		group_inventory.open_craft_for(group_inventory.preferred_craft_actor())
		get_viewport().set_input_as_handled()
		return
	if not _map_shortcuts_available():
		return
	var audio := get_node_or_null("/root/GameAudio")
	if key in [KEY_M, KEY_N] and audio != null:
		audio.call("toggle_mute", &"master")
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_HOME, KEY_END] and gerencia != null \
			and gerencia.map_view != null:
		gerencia.map_view.keyboard_zoom(1 if key == KEY_HOME else -1)
		get_viewport().set_input_as_handled()
		return
	var station_number := 0
	if key >= KEY_1 and key <= KEY_9:
		station_number = key - KEY_1 + 1
	elif key >= KEY_KP_1 and key <= KEY_KP_9:
		station_number = key - KEY_KP_1 + 1
	if station_number > 0 and audio != null \
			and bool(audio.call("select_station_number", station_number)):
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _initial_ui_ready or not event is InputEventKey \
			or not event.pressed or event.echo or get_tree().paused \
			or not _map_shortcuts_available():
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return
	var activation := get_parent().get_node_or_null("BlockActivationPopup") as BlockActivationPopup
	if activation != null and activation.overlay.visible:
		return
	if round_manager != null and round_manager.is_destination_choice_open():
		return
	var key := (event as InputEventKey).keycode
	var hud := get_parent().get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	if key == KEY_T and _tutorial_shortcut != null and _tutorial_shortcut.visible:
		open_tutorial()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_TAB:
		_keyboard_region = &"hud" if _keyboard_region != &"hud" else &"topbar"
		if _keyboard_region == &"hud":
			_topbar_keyboard_navigation.clear()
			if hud != null:
				hud.keyboard_focus_active_card()
		else:
			if hud != null:
				hud.keyboard_clear_card_focus()
			_topbar_keyboard_navigation.highlight(information_button)
		get_viewport().set_input_as_handled()
		return
	if key == KEY_I:
		_toggle_group_inventory()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_R:
		_toggle_journal()
		get_viewport().set_input_as_handled()
		return
	if key == KEY_Q:
		if _keyboard_region == &"hud" and hud != null:
			hud.keyboard_open_highlighted_sheet()
		else:
			_toggle_information_archive()
		get_viewport().set_input_as_handled()
		return
	if _keyboard_region == &"hud" and hud != null:
		if key in [KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			hud.keyboard_focus_card_delta(-1 if key in [KEY_UP, KEY_W] else 1)
			get_viewport().set_input_as_handled()
			return
		if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			hud.keyboard_toggle_active_actions()
			get_viewport().set_input_as_handled()
			return
	if _keyboard_region == &"topbar":
		if _topbar_keyboard_navigation.handle_buttons(event,
				[information_button, group_inventory_button, journal_button]):
			get_viewport().set_input_as_handled()
			return
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and hud != null:
		hud.keyboard_toggle_active_actions()
		get_viewport().set_input_as_handled()


func _map_shortcuts_available() -> bool:
	if _audio_quick_panel.visible or information_archive.visible \
			or group_inventory.visible or journal_ui.is_book_open():
		return false
	if _day_transition != null and _day_transition.is_open():
		return false
	if _final_center_transition != null and _final_center_transition.is_open():
		return false
	for dialog in [_save_dialog, _overwrite_dialog, _exit_dialog,
			_save_feedback, _terminal_dialog]:
		if dialog != null and dialog.visible:
			return false
	var hud := get_parent().get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	if hud != null and (hud.action_drawer.visible or hud.character_sheet.visible \
			or hud.hex_choice.visible or hud.inventory_panel.visible):
		return false
	return true


func _craft_shortcut_available() -> bool:
	if group_inventory == null or not group_inventory.can_open_craft():
		return false
	if _day_transition != null and _day_transition.is_open():
		return false
	if _final_center_transition != null and _final_center_transition.is_open():
		return false
	for dialog in [_save_dialog, _overwrite_dialog, _exit_dialog,
			_save_feedback, _terminal_dialog]:
		if dialog != null and dialog.visible:
			return false
	return true


func show_recovery_save_prompt() -> void:
	# Recuperar só carrega na memória; nenhum slot é escolhido automaticamente.
	_open_save_dialog(true)


func _build_save_dialogs() -> void:
	_day_transition = DAY_TRANSITION_SCENE.instantiate() as CanvasLayer
	# Cena própria, irmã da barra/HUD no mapa; só o fluxo é coordenado aqui.
	get_parent().add_child.call_deferred(_day_transition)
	_day_transition.save_requested.connect(_on_new_day_save_confirmed)
	_day_transition.continue_requested.connect(_on_new_day_continue)
	_final_center_transition = FINAL_CENTER_TRANSITION_SCENE.instantiate() as CampaignFinalCenterTransition
	get_parent().add_child.call_deferred(_final_center_transition)
	_final_center_transition.continue_requested.connect(_on_final_center_continue)
	_save_dialog = ConfirmationDialog.new()
	_save_dialog.title = "Salvar campanha"
	_save_dialog.dialog_text = "Escolha um dos três slots manuais:"
	_save_dialog.get_ok_button().text = "SALVAR NESTE SLOT"
	_save_dialog.get_cancel_button().text = "MAIS TARDE"
	style_confirmation_button(_save_dialog.get_ok_button(), Color(0.33, 0.84, 0.58))
	style_confirmation_button(_save_dialog.get_cancel_button(), Color(0.31, 0.78, 0.91))
	add_child(_save_dialog)
	DIALOG_STYLE.apply(_save_dialog, "progress", 430.0, 100.0)
	_save_slot_options = OptionButton.new()
	_save_slot_options.position = Vector2(20, 74)
	_save_slot_options.size = Vector2(430, 38)
	style_confirmation_button(_save_slot_options, Color(0.31, 0.78, 0.91))
	_save_dialog.add_child(_save_slot_options)
	_save_dialog.confirmed.connect(_on_save_slot_selected)
	_save_dialog.visibility_changed.connect(_sync_save_panel_pause)
	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = "Substituir save?"
	_overwrite_dialog.get_ok_button().text = "SIM, SUBSTITUIR"
	_overwrite_dialog.get_cancel_button().text = "VOLTAR"
	style_confirmation_button(_overwrite_dialog.get_ok_button(), Color(0.96, 0.75, 0.27))
	style_confirmation_button(_overwrite_dialog.get_cancel_button(), Color(0.31, 0.78, 0.91))
	add_child(_overwrite_dialog)
	DIALOG_STYLE.apply(_overwrite_dialog, "warning")
	_overwrite_dialog.confirmed.connect(_on_overwrite_confirmed)
	_overwrite_dialog.visibility_changed.connect(_sync_save_panel_pause)
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "Sair sem salvar?"
	_exit_dialog.dialog_text = "O progresso não salvo e o backup automático desta sessão serão descartados. Os três slots manuais permanecem."
	_exit_dialog.get_ok_button().text = "SIM, SAIR SEM SALVAR"
	_exit_dialog.get_cancel_button().text = "CONTINUAR JOGANDO"
	style_confirmation_button(_exit_dialog.get_ok_button(), Color(0.96, 0.75, 0.27))
	style_confirmation_button(_exit_dialog.get_cancel_button(), Color(0.31, 0.78, 0.91))
	add_child(_exit_dialog)
	DIALOG_STYLE.apply(_exit_dialog, "warning", 515.0, 82.0)
	_exit_dialog.confirmed.connect(_on_exit_without_saving_confirmed)
	_exit_dialog.visibility_changed.connect(_sync_save_panel_pause)
	_save_feedback = AcceptDialog.new()
	_save_feedback.title = "Salvamento"
	add_child(_save_feedback)
	DIALOG_STYLE.apply(_save_feedback, "progress", 440.0, 72.0)
	_save_feedback.visibility_changed.connect(_sync_save_panel_pause)
	_terminal_dialog = AcceptDialog.new()
	_terminal_dialog.title = "Campanha concluída"
	_terminal_dialog.get_ok_button().text = "OK"
	add_child(_terminal_dialog)
	DIALOG_STYLE.apply(_terminal_dialog, "structure", 500.0, 82.0)
	DIALOG_STYLE.make_layer_backdrop(self, [
		_save_dialog, _overwrite_dialog, _exit_dialog,
		_save_feedback, _terminal_dialog,
	])
	var controller := get_parent().get_node_or_null("CampaignAutosaveController")
	if controller != null:
		controller.connect("manual_save_completed", _on_manual_save_completed)


func _open_save_dialog(recovery: bool) -> void:
	if gerencia == null or gerencia.campaign == null \
			or gerencia.campaign.current_map == null:
		return
	_recovery_save_prompt = recovery
	_save_dialog.title = "Guardar campanha recuperada" if recovery else "Salvar campanha"
	_save_dialog.dialog_text = ("A recuperação está apenas na memória. Escolha um slot para guardá-la ou continue jogando e salve depois." \
		if recovery else "Escolha um dos três slots manuais:")
	_save_slot_options.clear()
	var occupied := {}
	for entry in gerencia.list_saved_campaigns():
		if entry["campaign_id"] == gerencia.campaign.campaign_id:
			for slot in entry["slots"]:
				occupied[int(slot["slot_number"])] = slot
	for slot_number in range(1, CampaignSaveRepository.SLOT_COUNT + 1):
		var label := "SLOT %d · vazio" % slot_number
		if occupied.has(slot_number):
			var slot: Dictionary = occupied[slot_number]
			label = "SLOT %d · %s%s" % [slot_number,
				str(slot.get("saved_at", "data indisponível")),
				" · recuperação" if slot.get("backup_only", false) else ""]
		_save_slot_options.add_item(label)
		_save_slot_options.set_item_metadata(slot_number - 1, slot_number)
	_save_dialog.popup_centered(Vector2i(470, 210))


func _on_new_day_started(day: int) -> void:
	if day <= _last_day_save_prompt or gerencia == null \
			or gerencia.campaign == null or gerencia.campaign.is_terminal():
		return
	_last_day_save_prompt = day
	if gerencia.campaign.final_center_intro_pending:
		_pending_day_transition = day
		return
	_open_day_transition.call_deferred(day)


func _open_day_transition(day: int) -> void:
	if not is_inside_tree() or _day_transition == null:
		return
	if gerencia != null and gerencia.campaign.final_center_intro_pending:
		_pending_day_transition = day
		return
	_day_transition.open(day)
	_sync_save_panel_pause()


func _try_open_final_center_intro() -> void:
	if gerencia == null or gerencia.campaign == null \
			or not gerencia.campaign.final_center_intro_pending \
			or _final_center_transition == null \
			or not _final_center_transition.is_inside_tree() \
			or _final_center_transition.is_open():
		return
	if pause_menu != null and pause_menu.is_open():
		return
	var block_manager := get_parent().get_node_or_null("BlockManager") as BlockManager
	if block_manager != null and block_manager.is_busy():
		return
	for window in get_tree().root.find_children("*", "Window", true, false):
		if (window as Window).visible:
			return
	_final_center_transition.open()
	_sync_save_panel_pause()


func _on_final_center_continue() -> void:
	_final_center_transition.close()
	if gerencia != null and gerencia.campaign != null:
		gerencia.campaign.final_center_intro_pending = false
		gerencia.campaign.final_center_intro_seen = true
	if _pending_day_transition > 0:
		var day := _pending_day_transition
		_pending_day_transition = 0
		_open_day_transition.call_deferred(day)
	_sync_save_panel_pause()


func _try_resume_final_center_arrival() -> void:
	if gerencia == null or gerencia.campaign == null \
			or gerencia.campaign.final_center_intro_pending \
			or (_day_transition != null and _day_transition.is_open()) \
			or (pause_menu != null and pause_menu.is_open()):
		return
	var executor := get_parent().get_node_or_null("EventExecutor") as EventExecutor
	if executor == null or executor._final_center_arrival.is_empty():
		return
	executor.resume_final_center_arrival()


func _on_new_day_save_confirmed() -> void:
	# A virada já ocorreu: fechar o seletor nunca refaz a fase ou gera mapa.
	_day_transition.close()
	pause_menu.open_save_from_new_day()


func _on_new_day_continue() -> void:
	_day_transition.close()
	_sync_save_panel_pause()


func _on_save_slot_selected() -> void:
	if _save_slot_options.selected < 0:
		return
	_save_dialog.hide()
	_selected_save_slot = int(_save_slot_options.get_item_metadata(
		_save_slot_options.selected))
	var occupied := false
	for entry in gerencia.list_saved_campaigns():
		if entry["campaign_id"] != gerencia.campaign.campaign_id:
			continue
		for slot in entry["slots"]:
			occupied = occupied or int(slot["slot_number"]) == _selected_save_slot
	if occupied:
		_overwrite_dialog.dialog_text = "O slot %d já contém um save. Substituir apaga apenas o ponto antigo deste slot; os outros dois permanecem. Deseja continuar?" % _selected_save_slot
		_overwrite_dialog.popup_centered(Vector2i(450, 180))
	else:
		_submit_manual_save(false)


func _on_overwrite_confirmed() -> void:
	_overwrite_dialog.hide()
	_submit_manual_save(true)


func _submit_manual_save(overwrite_confirmed: bool) -> void:
	var result := gerencia.save_manual_slot(_selected_save_slot, overwrite_confirmed)
	if result.get("queued", false):
		_show_save_feedback("Salvamento agendado; será concluído ao fim da ação.")
	elif not result.get("success", false) and not _has_autosave_controller():
		_show_save_feedback(str(result.get("reason", "Não foi possível salvar.")))
	elif result.get("success", false) and not _has_autosave_controller():
		_show_save_feedback("Campanha salva no slot %d." % _selected_save_slot)


func _on_manual_save_completed(result: Dictionary) -> void:
	if pause_menu != null and pause_menu.is_open():
		pause_menu.on_manual_save_completed(result)
		return
	if result.get("success", false):
		_show_save_feedback("Campanha salva no slot %d." % int(result.get("slot_number", 0)))
	else:
		_show_save_feedback(str(result.get("reason", "Não foi possível salvar.")))


func _show_save_feedback(message: String) -> void:
	_save_feedback.title = "Salvamento"
	_save_feedback.dialog_text = message
	_save_feedback.popup_centered.call_deferred(Vector2i(420, 150))


func exit_progress_warning() -> String:
	if gerencia == null or gerencia.campaign == null:
		return "Sairá para o menu principal. Os slots manuais permanecem."
	var comparison := gerencia.save_repository.compare_latest_manual_save(
		gerencia.campaign, get_parent())
	if not comparison.get("has_manual_save", false):
		return "Esta campanha ainda não tem save manual. Sair agora descarta o progresso da sessão e o backup automático."
	if comparison.get("has_changes", true):
		return "Há alterações desde o último save manual. Sair agora descarta esse progresso e o backup automático; os três slots manuais permanecem."
	return "O estado atual corresponde ao último save manual. Sair descarta apenas o backup automático desta sessão; os slots manuais permanecem."


func style_confirmation_button(button: Button, accent: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r * 0.1, accent.g * 0.1, accent.b * 0.1, 0.99)
	normal.border_color = accent
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = accent.lightened(0.2)
	hover.bg_color = Color(accent.r * 0.2, accent.g * 0.2, accent.b * 0.2, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", accent.lightened(0.12))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _on_campaign_terminal_changed(status: int, information_count: int) -> void:
	if _terminal_dialog == null:
		return
	_terminal_dialog.title = "Campanha concluída" if status == CampaignState.CampaignStatus.VICTORY \
		else "Fim de campanha"
	_terminal_dialog.dialog_text = ("Você encontrou %d Informações e concluiu esta campanha." % information_count \
		if status == CampaignState.CampaignStatus.VICTORY else \
		"Todos os personagens jogáveis morreram. A campanha terminou.") \
		+ "\nEste estado é terminal: não é possível continuar agindo. Consulte os Registros ou salve em um slot para guardar este ponto."
	# O desfecho pode ocorrer dentro de um outcome ou outro modal exclusivo.
	# Mostrar somente no primeiro frame em que a leitura atual foi concluída.
	_terminal_notice_pending = true


func _try_show_terminal_notice() -> void:
	if not _terminal_notice_pending or _terminal_dialog == null \
			or _terminal_dialog.visible or not is_inside_tree():
		return
	if pause_menu != null and pause_menu.is_open():
		return
	if _day_transition != null and _day_transition.is_open():
		return
	if _final_center_transition != null and _final_center_transition.is_open():
		return
	var block_manager := get_parent().get_node_or_null("BlockManager") as BlockManager
	if block_manager != null and block_manager.is_busy():
		return
	for window in get_tree().root.find_children("*", "Window", true, false):
		if window != _terminal_dialog and (window as Window).visible:
			return
	_terminal_notice_pending = false
	_terminal_dialog.popup_centered(Vector2i(500, 190))


func _has_autosave_controller() -> bool:
	var controller := get_parent().get_node_or_null("CampaignAutosaveController")
	return controller != null and controller.get("enabled")


func _sync_save_panel_pause() -> void:
	var controller := get_parent().get_node_or_null("CampaignAutosaveController")
	if controller != null:
		controller.call("set_save_panel_open", _day_transition.is_open() \
			or (_final_center_transition != null and _final_center_transition.is_open()) \
			or _save_dialog.visible \
			or _overwrite_dialog.visible or _exit_dialog.visible \
			or _save_feedback.visible)


func _on_exit_without_saving_confirmed() -> void:
	var controller := get_parent().get_node_or_null("CampaignAutosaveController")
	if controller == null or not controller.call("confirm_exit_without_saving"):
		_show_save_feedback("Não foi possível descartar o backup. A campanha permanece aberta.")
		return
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _toggle_sound() -> void:
	_audio_quick_panel.toggle()


func _refresh_sound() -> void:
	sound_button.text = "♪"
	sound_button.tooltip_text = "Abrir controles de áudio"
