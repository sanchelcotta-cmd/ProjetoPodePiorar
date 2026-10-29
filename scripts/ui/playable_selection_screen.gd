class_name PlayableSelectionScreen
extends Control

## Esta é a entrada da campanha: o jogador escolhe de um a três EntityData.
## O jogo sorteia vagas restantes sem repetição; a campanha sempre recebe
## três personagens diferentes em Playable_1, 2 e 3.
const CARD_SCENE := preload("res://scenes/ui/playable_selection_card.tscn")
const GAME_SCENE_PATH := "res://scenes/game/campaign_game.tscn"
const LOADING_OVERLAY_SCRIPT := preload("res://scripts/ui/scene_loading_overlay.gd")
const PREGAME_SCENE := preload("res://scenes/ui/campaign_pregame_summary.tscn")
const LOAD_PANEL_SCRIPT := preload("res://scripts/ui/campaign_load_panel.gd")
const DETAIL_PANEL_SCRIPT := preload("res://scripts/ui/playable_selection_detail_panel.gd")
const DIALOG_STYLE := preload("res://scripts/ui/game_dialog_style.gd")
const NARRATIVE_FONT := preload("res://scripts/ui/ui_narrative_font.gd")
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const KEYBOARD_NAV := preload("res://scripts/ui/keyboard_button_navigation.gd")
const CARD_HEIGHT := 320.0
const CARD_MIN_WIDTH := 166.0
const CARD_GAP := 8.0
const CARDS_PER_PAGE := 8
const ENDING_NAMES := {
	&"khainokata": "Khainokata", &"orchestra": "Orchestra",
	&"homens_de_preto": "Homens de Preto", &"controle_da_mente": "Controle da Mente",
}

@onready var _body_scroll: ScrollContainer = $Content/Stack/BodyScroll
@onready var _carousel: HBoxContainer = $Content/Stack/BodyScroll/Body/Carousel
@onready var _grid: GridContainer = $Content/Stack/BodyScroll/Body/Carousel/CardsCenter/CardsGrid
@onready var _previous: Button = $Content/Stack/BodyScroll/Body/Carousel/Previous
@onready var _next: Button = $Content/Stack/BodyScroll/Body/Carousel/Next
@onready var _carousel_line: HSlider = $Content/Stack/BodyScroll/Body/CarouselLine
@onready var _summary: Label = $Content/Stack/Footer/FooterMargin/FooterRow/FooterText/Summary
@onready var _status: Label = $Content/Stack/Footer/FooterMargin/FooterRow/FooterText/Status
@onready var _confirm: Button = $Content/Stack/Footer/FooterMargin/FooterRow/ConfirmSelection
@onready var _difficulty_panel: PanelContainer = $Content/Stack/Footer/FooterMargin/FooterRow/DifficultyPanel
@onready var _difficulty_title: Label = $Content/Stack/Footer/FooterMargin/FooterRow/DifficultyPanel/DifficultyMargin/DifficultyStack/DifficultyHeading/Title
@onready var _difficulty_info_button: Button = $Content/Stack/Footer/FooterMargin/FooterRow/DifficultyPanel/DifficultyMargin/DifficultyStack/DifficultyHeading/Info
@onready var _difficulty_easy: Button = $Content/Stack/Footer/FooterMargin/FooterRow/DifficultyPanel/DifficultyMargin/DifficultyStack/DifficultyChoices/Easy
@onready var _difficulty_standard: Button = $Content/Stack/Footer/FooterMargin/FooterRow/DifficultyPanel/DifficultyMargin/DifficultyStack/DifficultyChoices/Standard
@onready var _difficulty_chaotic: Button = $Content/Stack/Footer/FooterMargin/FooterRow/DifficultyPanel/DifficultyMargin/DifficultyStack/DifficultyChoices/Chaotic
@onready var _load_button: Button = $Content/Stack/Header/HeaderMargin/HeaderRow/LoadCampaign
@onready var _back_button: Button = $Content/Stack/Header/HeaderMargin/HeaderRow/Back
@onready var _mode_short: Button = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/ModeBlock/CampaignModes/Short
@onready var _mode_medium: Button = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/ModeBlock/CampaignModes/Medium
@onready var _mode_complete: Button = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/ModeBlock/CampaignModes/Complete
@onready var _ending_setup: VBoxContainer = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/EndingSetup
@onready var _ending_hint: Label = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/EndingSetup/Hint
@onready var _ending_choices: GridContainer = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/EndingSetup/EndingRow/Choices
@onready var _ending_random: Button = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/EndingSetup/EndingRow/Random
@onready var _branch: ColorRect = $Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/Branch

var selected: Array[EntityData] = []
var preloaded_catalog: Array[EntityData] = []
var cards: Array[PlayableSelectionCard] = []
var _rng := RandomNumberGenerator.new()
var _selected_mode: int = EventCampaignEligibility.Mode.COMPLETE
var _selected_difficulty: int = GameDifficulty.Mode.STANDARD
var _selected_endings: Array[StringName] = []
var _random_endings := false
var _ending_buttons: Dictionary = {}
var _load_panel: Control
var _detail_panel: Control
var _load_repository := CampaignSaveRepository.new()
var _card_page := 0
var _cards_per_page := CARDS_PER_PAGE
var _difficulty_info: AcceptDialog
var _loading_save := false
var _keyboard_navigation := KEYBOARD_NAV.new()


func _ready() -> void:
	var profile_start := Time.get_ticks_msec()
	_rng.randomize()
	for navigation_button in [_previous, _next, _load_button, _back_button]:
		navigation_button.set_meta("ui_sfx_kind", &"menu_page")
	var catalog := preloaded_catalog if not preloaded_catalog.is_empty() else \
		CampaignState.new().get_playable_catalog()
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL selection catalog %d ms" % (Time.get_ticks_msec() - profile_start))
	catalog.sort_custom(func(a: EntityData, b: EntityData) -> bool: return String(a.id) < String(b.id))
	for character in catalog:
		var card := CARD_SCENE.instantiate() as PlayableSelectionCard
		_grid.add_child(card)
		card.setup(character)
		card.chosen.connect(_on_card_chosen)
		card.details_requested.connect(_on_card_details)
		cards.append(card)
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL selection cards %d ms" % (Time.get_ticks_msec() - profile_start))
	_mode_short.pressed.connect(_on_mode_pressed.bind(EventCampaignEligibility.Mode.SHORT))
	_mode_medium.pressed.connect(_on_mode_pressed.bind(EventCampaignEligibility.Mode.MEDIUM))
	_mode_complete.pressed.connect(_on_mode_pressed.bind(EventCampaignEligibility.Mode.COMPLETE))
	for ending_id in CampaignState.ALL_ENDING_IDS:
		var choice := Button.new()
		choice.name = String(ending_id).to_pascal_case().replace(" ", "")
		choice.text = str(ENDING_NAMES.get(ending_id,
			String(ending_id).replace("_", " ").capitalize()))
		choice.custom_minimum_size = Vector2(155, 30)
		choice.toggle_mode = true
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_ending_choices.add_child(choice)
		_ending_buttons[ending_id] = choice
		choice.pressed.connect(_on_ending_pressed.bind(ending_id))
	_ending_random.pressed.connect(_on_random_pressed)
	_previous.pressed.connect(_change_card_page.bind(-1))
	_next.pressed.connect(_change_card_page.bind(1))
	_carousel_line.value_changed.connect(_set_card_page)
	_confirm.pressed.connect(_confirm_selection)
	_difficulty_easy.disabled = false
	_difficulty_chaotic.disabled = false
	_difficulty_easy.pressed.connect(_on_difficulty_pressed.bind(GameDifficulty.Mode.SUGAR))
	_difficulty_standard.pressed.connect(_on_difficulty_pressed.bind(GameDifficulty.Mode.STANDARD))
	_difficulty_chaotic.pressed.connect(_on_difficulty_pressed.bind(GameDifficulty.Mode.CHAOTIC))
	_difficulty_info_button.pressed.connect(func() -> void:
		_difficulty_info.popup_centered(Vector2i(650, 465)))
	_difficulty_info = AcceptDialog.new()
	_difficulty_info.title = "MODOS DE JOGO"
	_difficulty_info.dialog_text = ""
	_difficulty_info.get_ok_button().text = "OK"
	add_child(_difficulty_info)
	_difficulty_info.close_requested.connect(_difficulty_info.hide)
	_difficulty_info.window_input.connect(func(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel"):
			_difficulty_info.hide()
			_difficulty_info.set_input_as_handled())
	DIALOG_STYLE.apply(_difficulty_info, "structure", 580.0, 310.0)
	_difficulty_info.get_label().hide()
	var info_body := VBoxContainer.new()
	info_body.add_theme_constant_override("separation", 9)
	_difficulty_info.get_label().get_parent().add_child(info_body)
	for section in [
		["ÁGUA COM AÇÚCAR", "Uma jornada mais casual, com mais chances de se recuperar. Os perigos tendem a se acumular menos, e um golpe fatal pode dar uma última oportunidade; coisas ruins ainda acontecem."],
		["PADRÃO", "A experiência equilibrada de Belacidade. Descobertas boas, ruins e ambíguas seguem uma distribuição planejada; qualquer resultado pode aparecer, sem proteções extras."],
		["CAÓTICO", "Bem-vindo ao caos. A preparação começa mais enxuta e os mapas podem concentrar tanto sorte quanto desgraça. Os inimigos não ficam mais fortes; a imprevisibilidade das descobertas é o desafio."],
	]:
		var heading := Label.new()
		heading.text = section[0]
		heading.add_theme_font_override("font", BOLD_FONT)
		heading.add_theme_font_size_override("font_size", 14)
		heading.add_theme_color_override("font_color", DIALOG_STYLE.TEXT)
		info_body.add_child(heading)
		var body := Label.new()
		body.text = section[1]
		body.custom_minimum_size.x = 580.0
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 12)
		body.add_theme_color_override("font_color", DIALOG_STYLE.TEXT)
		NARRATIVE_FONT.apply_label(body)
		info_body.add_child(body)
	DIALOG_STYLE.make_backdrop(self, [_difficulty_info])
	_load_button.pressed.connect(_open_load_panel)
	_back_button.pressed.connect(_go_back)
	_load_panel = LOAD_PANEL_SCRIPT.new() as Control
	_load_panel.set("repository", _load_repository)
	add_child(_load_panel)
	_load_panel.connect("load_requested", _on_load_requested)
	_load_panel.hide()
	_detail_panel = DETAIL_PANEL_SCRIPT.new() as Control
	add_child(_detail_panel)
	_detail_panel.hide()
	resized.connect(_update_layout)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.connect("ui_scale_changed", _on_ui_scale_changed)
	_style_menu()
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL selection style %d ms" % (Time.get_ticks_msec() - profile_start))
	_update_layout.call_deferred()
	_refresh_campaign_setup()
	_refresh_selection()
	if catalog.size() < 3:
		_status.text = "São necessários ao menos três personagens cadastrados."
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL selection total %d ms" % (Time.get_ticks_msec() - profile_start))
	_keyboard_navigation.reset(self)


func _input(event: InputEvent) -> void:
	if _loading_save or (_load_panel != null and _load_panel.visible) \
			or (_detail_panel != null and _detail_panel.visible) \
			or (_difficulty_info != null and _difficulty_info.visible):
		return
	if _keyboard_navigation.handle(event, self):
		get_viewport().set_input_as_handled()


func _update_layout() -> void:
	var factor := _ui_scale_factor()
	var safe_width := size.x - (48.0 + 68.0 + 32.0) * factor
	var usable := maxf(minf(_carousel.size.x - 90.0 * factor, safe_width),
		CARD_MIN_WIDTH * factor)
	var scaled_gap := CARD_GAP * factor
	_cards_per_page = clampi(floori((usable + scaled_gap) /
		(CARD_MIN_WIDTH * factor + scaled_gap)), 2, CARDS_PER_PAGE)
	var columns := mini(_cards_per_page, maxi(cards.size(), 2))
	_grid.columns = columns
	var width := minf(252.0, floorf((usable - scaled_gap * float(columns - 1))
		/ float(columns) / factor))
	width = maxf(width, CARD_MIN_WIDTH)
	for card in cards:
		card.custom_minimum_size = Vector2(width, CARD_HEIGHT)
		card.size = card.custom_minimum_size
	for button in [_mode_short, _mode_medium, _mode_complete]:
		var title := button.get_node("Title") as Label
		var subtitle := button.get_node("Subtitle") as Label
		title.position.y = 3.0 * factor
		subtitle.position.y = 25.0 * factor + 5.0 * (factor - 1.0)
		for label in [title, subtitle]:
			label.size.x = maxf(60.0, button.size.x - label.position.x - 10.0)
	var page_count := maxi(1, ceili(float(cards.size()) / float(_cards_per_page)))
	_carousel_line.max_value = page_count - 1
	_carousel_line.editable = page_count > 1
	_carousel_line.visible = page_count > 1
	_set_card_page(float(_card_page))


func _change_card_page(offset: int) -> void:
	_set_card_page(float(_card_page + offset))


func _set_card_page(value: float) -> void:
	var page_count := maxi(1, ceili(float(cards.size()) / float(_cards_per_page)))
	_card_page = clampi(roundi(value), 0, page_count - 1)
	for index in cards.size():
		cards[index].visible = index >= _card_page * _cards_per_page \
			and index < (_card_page + 1) * _cards_per_page
	_previous.disabled = _card_page == 0
	_next.disabled = _card_page >= page_count - 1
	_carousel_line.set_value_no_signal(_card_page)


func _ui_scale_factor() -> float:
	var scaler := get_node_or_null("/root/UniversalFontScale")
	return float(scaler.get("ui_factor")) if scaler != null else 1.0


func _on_ui_scale_changed(_factor: float) -> void:
	_update_layout.call_deferred()


func _on_card_details(card: PlayableSelectionCard) -> void:
	_detail_panel.call("open_for", card.character)


func _style_menu() -> void:
	for panel in [$Content/Stack/Header, $Content/Stack/Footer]:
		(panel as PanelContainer).add_theme_stylebox_override("panel",
			_panel_style(Color(0.025, 0.048, 0.070, 0.98), Color(0.24, 0.76, 0.90),
				"surface", "structure"))
		_palette_call("bind_control_style", [panel, "panel", "surface", "structure"])
	($Content/Stack/BodyScroll/Body/CampaignPanel as PanelContainer).add_theme_stylebox_override(
		"panel", _panel_style(Color(0.043, 0.031, 0.060, 0.98), Color(0.83, 0.25, 0.56),
			"surface", "selection"))
	_palette_call("bind_control_style", [$Content/Stack/BodyScroll/Body/CampaignPanel,
		"panel", "surface", "selection"])
	var soft_white := Color(0.91, 0.96, 1.0)
	var pink := Color(0.98, 0.42, 0.69)
	var cyan := Color(0.48, 0.88, 0.97)
	($Content/Stack/Header/HeaderMargin/HeaderRow/Title as Label).add_theme_color_override(
		"font_color", soft_white)
	_palette_call("bind_color", [$Content/Stack/Header/HeaderMargin/HeaderRow/Title,
		"font_color", "primary"])
	($Content/Stack/BodyScroll/Body/CharacterHeading as Label).add_theme_color_override(
		"font_color", soft_white)
	_palette_call("bind_color", [$Content/Stack/BodyScroll/Body/CharacterHeading,
		"font_color", "primary"])
	for label in [$Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/ModeBlock/ModeHeading,
			$Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/EndingSetup/EndingHeading]:
		(label as Label).add_theme_color_override("font_color", pink)
		_palette_call("bind_color", [label, "font_color", "selection"])
	($Content/Stack/BodyScroll/Body/SectionDivider as ColorRect).color = Color(0.24, 0.76, 0.90, 0.83)
	_palette_call("bind_rect", [$Content/Stack/BodyScroll/Body/SectionDivider, "structure"])
	_summary.add_theme_color_override("font_color", soft_white)
	_palette_call("bind_color", [_summary, "font_color", "primary"])
	_status.add_theme_color_override("font_color", cyan)
	_palette_call("bind_color", [_status, "font_color", "structure"])
	_difficulty_panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.047, 0.042, 0.063, 0.98), Color(0.68, 0.31, 0.55),
			"surface", "selection"))
	_palette_call("bind_control_style", [_difficulty_panel, "panel", "surface", "selection"])
	_difficulty_title.add_theme_color_override("font_color", pink)
	_palette_call("bind_color", [_difficulty_title, "font_color", "selection"])
	_style_plain_button(_difficulty_info_button, Color(0.24, 0.76, 0.90))
	for button in [_difficulty_easy, _difficulty_standard, _difficulty_chaotic]:
		_style_plain_button(button, Color(0.36, 0.44, 0.50))
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_disabled_color", Color(0.62, 0.68, 0.73))
		_palette_call("bind_color", [button, "font_disabled_color", "on_button_disabled"])
	_refresh_difficulty_choices()
	_difficulty_standard.tooltip_text = "Regras originais da campanha."
	_difficulty_easy.tooltip_text = "Mais recursos, menos perigos e uma sobrevivência por aliado a cada combate."
	_difficulty_chaotic.tooltip_text = "Dois itens iniciais por personagem; mapas imprevisíveis, sem cotas de valência."
	_ending_hint.add_theme_color_override("font_color", Color(0.73, 0.84, 0.91))
	_palette_call("bind_color", [_ending_hint, "font_color", "secondary"])
	for button in [_previous, _next, _load_button, _back_button]:
		_style_plain_button(button, Color(0.24, 0.76, 0.90))
	for button in [_mode_short, _mode_medium, _mode_complete]:
		for label_name in ["Title", "Subtitle"]:
			(button.get_node(label_name) as Label).add_theme_color_override(
				"font_color", soft_white if label_name == "Title" else Color(0.72, 0.82, 0.90))
			_palette_call("bind_color", [button.get_node(label_name), "font_color",
				"on_button"])
	for button in _ending_buttons.values():
		(button as Button).add_theme_color_override("font_color", soft_white)
		_palette_call("bind_color", [button, "font_color", "on_button"])
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(0.13, 0.43, 0.51, 0.75)
	rail.set_corner_radius_all(2)
	_carousel_line.add_theme_stylebox_override("slider", rail)
	_carousel_line.add_theme_stylebox_override("grabber_area", rail)
	_palette_call("bind_style", [rail, "structure"])


func _panel_style(background: Color, border: Color,
		background_role: String = "surface", border_role: String = "structure") -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_palette_call("bind_style", [style, background_role, border_role])
	return style


func _style_plain_button(button: Button, border: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.055, 0.075, 0.10, 0.97)
	normal.border_color = border
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", normal)
	_palette_call("bind_style", [normal, "button", "structure"])
	_palette_call("bind_control_style", [button, "normal", "button", "structure"])
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.15, 0.19, 0.99)
	hover.border_color = border.lightened(0.25)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	_palette_call("bind_style", [hover, "button_hover", "structure"])
	for key in ["hover", "pressed"]:
		_palette_call("bind_control_style", [button, key, "button_hover", "structure"])
	button.add_theme_color_override("font_color", Color(0.87, 0.95, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.36, 0.44, 0.49))
	_palette_call("bind_color", [button, "font_color", "on_button"])
	_palette_call("bind_color", [button, "font_disabled_color", "on_button_disabled"])


func _style_choice(button: Button, picked: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.04, 0.10, 0.97) if picked else \
		Color(0.055, 0.07, 0.09, 0.97)
	normal.border_color = Color(1.0, 0.42, 0.71) if picked else \
		Color(0.34, 0.44, 0.50)
	normal.set_border_width_all(2 if picked else 1)
	normal.set_corner_radius_all(4)
	normal.shadow_color = Color(1.0, 0.20, 0.61, 0.25) if picked else Color.TRANSPARENT
	normal.shadow_size = 5 if picked else 0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", normal)
	_palette_call("bind_style", [normal,
		"button_selected" if picked else "button",
		"selection" if picked else "neutral",
		"selection" if picked else ""])
	for key in ["normal", "pressed"]:
		_palette_call("bind_control_style", [button, key,
			"button_selected" if picked else "button",
			"selection" if picked else "neutral"])
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(1.0, 0.55, 0.78)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	_palette_call("bind_style", [hover,
		"button_selected" if picked else "button_hover", "selection"])
	for key in ["hover", "hover_pressed"]:
		_palette_call("bind_control_style", [button, key,
			"button_selected" if picked else "button_hover", "selection"])
	button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.94, 0.97, 1.0))
	_palette_call("bind_color", [button, "font_color", "on_button"])
	_palette_call("bind_color", [button, "font_pressed_color", "on_button"])


func _style_sort_button() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.21, 0.17, 0.035, 0.98) if _random_endings else \
		Color(0.08, 0.075, 0.04, 0.98)
	style.border_color = Color(1.0, 0.84, 0.27)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	_ending_random.add_theme_stylebox_override("normal", style)
	_ending_random.add_theme_stylebox_override("pressed", style)
	_ending_random.add_theme_stylebox_override("hover", style)
	_ending_random.add_theme_color_override("font_color", Color(1.0, 0.91, 0.52))
	_palette_call("bind_style", [style, "button", "warning"])
	for key in ["normal", "pressed", "hover"]:
		_palette_call("bind_control_style", [_ending_random, key, "button", "warning"])
	_palette_call("bind_color", [_ending_random, "font_color", "on_button"])


func _palette_call(method: String, args: Array) -> void:
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service != null:
		palette_service.callv(method, args)


func _on_card_chosen(card: PlayableSelectionCard) -> void:
	if card.character in selected:
		selected.erase(card.character)
	elif selected.size() < 3:
		selected.append(card.character)
	else:
		_status.text = "Já há três escolhidos. Desmarque um para trocar."
		return
	_status.text = ""
	_refresh_selection()


func _on_mode_pressed(mode: int) -> void:
	_selected_mode = mode
	_selected_endings.clear()
	_random_endings = mode != EventCampaignEligibility.Mode.COMPLETE
	_status.text = ""
	_refresh_campaign_setup()


func _on_difficulty_pressed(mode: int) -> void:
	if not GameDifficulty.is_available(mode):
		return
	_selected_difficulty = mode
	_refresh_difficulty_choices()


func _refresh_difficulty_choices() -> void:
	for button in [_difficulty_easy, _difficulty_standard, _difficulty_chaotic]:
		var mode := GameDifficulty.Mode.SUGAR if button == _difficulty_easy else \
			GameDifficulty.Mode.STANDARD if button == _difficulty_standard else \
			GameDifficulty.Mode.CHAOTIC
		var selected_mode := mode == _selected_difficulty
		button.text = ("● " if selected_mode else "○ ") \
			+ GameDifficulty.label(mode).to_upper()
		_style_choice(button, selected_mode)


func _on_ending_pressed(ending_id: StringName) -> void:
	if _selected_mode == EventCampaignEligibility.Mode.COMPLETE:
		return
	if _random_endings:
		_random_endings = false
		_selected_endings.clear()
	if ending_id in _selected_endings:
		_selected_endings.erase(ending_id)
	elif _selected_endings.size() < _required_endings():
		_selected_endings.append(ending_id)
	else:
		_status.text = "Desmarque um desfecho para escolher outro."
		_refresh_campaign_setup()
		return
	_status.text = ""
	_refresh_campaign_setup()


func _on_random_pressed() -> void:
	_random_endings = true
	_selected_endings.clear()
	_status.text = ""
	_refresh_campaign_setup()


func _required_endings() -> int:
	return 1 if _selected_mode == EventCampaignEligibility.Mode.SHORT else 2


func _refresh_campaign_setup() -> void:
	_mode_short.button_pressed = _selected_mode == EventCampaignEligibility.Mode.SHORT
	_mode_medium.button_pressed = _selected_mode == EventCampaignEligibility.Mode.MEDIUM
	_mode_complete.button_pressed = _selected_mode == EventCampaignEligibility.Mode.COMPLETE
	for pair in [[_mode_short, "CAMPANHA CURTA"],
			[_mode_medium, "CAMPANHA MÉDIA"],
			[_mode_complete, "CAMPANHA COMPLETA"]]:
		var button := pair[0] as Button
		(button.get_node("Title") as Label).text = "%s  %s" % [
			"●" if button.button_pressed else "○", pair[1]]
		_style_choice(button, button.button_pressed)
	(_mode_complete.get_node("Subtitle") as Label).text = \
		"%d desfechos | Investigue e descubra todos os mistérios." % \
		CampaignState.ALL_ENDING_IDS.size()
	_ending_setup.visible = _selected_mode != EventCampaignEligibility.Mode.COMPLETE
	_branch.visible = _ending_setup.visible
	if _ending_setup.visible:
		_ending_hint.text = "Escolha %d desfecho%s ou use Sortear (%d/%d)." % [
			_required_endings(), "s" if _required_endings() > 1 else "",
			_selected_endings.size(), _required_endings()]
		_ending_random.button_pressed = _random_endings
		for ending_id in _ending_buttons:
			var button := _ending_buttons[ending_id] as Button
			button.button_pressed = ending_id in _selected_endings
			_style_choice(button, button.button_pressed)
		_style_sort_button()
	_update_layout.call_deferred()
	_refresh_selection()


func _refresh_selection() -> void:
	for card in cards:
		card.set_pick_number(selected.find(card.character) + 1)
	var names: Array[String] = []
	for character in selected:
		names.append(character.display_name)
	_summary.text = "Personagens escolhidos [%d de 3]" % selected.size()
	var missing := 3 - selected.size()
	_status.text = "%s%s" % [
		"Necessário para prosseguir: 1." if selected.is_empty() else
			"Escolhidos: %s." % ", ".join(names),
		" %d vaga(s) serão sorteadas." % missing if selected.size() > 0 and missing > 0 else ""]
	_confirm.disabled = selected.is_empty() or (
		_ending_setup.visible and not _random_endings
		and _selected_endings.size() != _required_endings())


func _complete_party() -> Array[EntityData]:
	var party: Array[EntityData] = []
	party.append_array(selected)
	var candidates: Array[EntityData] = []
	for card in cards:
		if card.character not in selected:
			candidates.append(card.character)
	while party.size() < 3 and not candidates.is_empty():
		party.append(candidates.pop_at(_rng.randi_range(0, candidates.size() - 1)))
	return party


func _confirm_selection() -> void:
	if selected.is_empty() or _confirm.disabled:
		return
	if _ending_setup.visible and not _random_endings and (
			_selected_endings.size() != _required_endings()):
		_status.text = "Escolha %d desfecho(s) ou use Sortear." % _required_endings()
		return
	var party := _complete_party()
	if party.size() != 3:
		_status.text = "Não há personagens suficientes para completar a equipe."
		return
	_confirm.disabled = true
	var loading := LOADING_OVERLAY_SCRIPT.new() as CanvasLayer
	get_tree().root.add_child(loading)
	loading.call("set_steps", 0, 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var campaign := CampaignState.new()
	var endings: Array[StringName] = []
	if not _random_endings:
		endings.assign(_selected_endings)
	if not campaign.start_new_game(party, 12, null, _selected_mode, endings,
			_selected_difficulty):
		loading.queue_free()
		_status.text = "Não foi possível preparar a campanha; a seleção foi preservada."
		_confirm.disabled = false
		return
	loading.call("set_steps", 1, 3)
	await get_tree().process_frame
	await get_tree().process_frame
	var summary: Control = PREGAME_SCENE.instantiate() as Control
	loading.call("set_steps", 2, 3)
	await get_tree().process_frame
	await get_tree().process_frame
	summary.set("prepared_campaign", campaign)
	get_tree().root.add_child(summary)
	get_tree().current_scene = summary
	loading.call("set_steps", 3, 3)
	loading.queue_free()
	queue_free()


func _open_load_panel() -> void:
	_load_panel.call("open")


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_load_requested(campaign_id: String, slot_number: int,
		autosave: bool) -> void:
	if _loading_save:
		return
	_loading_save = true
	var loading := LOADING_OVERLAY_SCRIPT.new() as CanvasLayer
	get_tree().root.add_child(loading)
	loading.call("set_steps", 0, 31)
	await get_tree().process_frame
	await get_tree().process_frame
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		loading.queue_free()
		_loading_save = false
		_load_panel.call("show_error", "Não foi possível abrir a cena da campanha.")
		return
	loading.call("advance_step")
	await get_tree().process_frame
	await get_tree().process_frame
	var game := packed.instantiate() as PPPMapView
	if game == null:
		loading.queue_free()
		_loading_save = false
		_load_panel.call("show_error", "Não foi possível abrir a cena da campanha.")
		return
	game.set_meta("defer_preview_map", true)
	loading.call("advance_step")
	await get_tree().process_frame
	await get_tree().process_frame
	game.visible = false
	get_tree().root.add_child(game)
	(game.get_node("GerenciaJogo") as GerenciaJogo).save_repository = _load_repository
	loading.call("advance_step")
	await get_tree().process_frame
	await get_tree().process_frame
	var interface_ready := await game.prepare_initial_interface(
		Callable(loading, "advance_step"))
	if not interface_ready:
		game.queue_free()
		loading.queue_free()
		_loading_save = false
		_load_panel.call("show_error", "Não foi possível preparar a interface do jogo.")
		return
	var result := _load_repository.load_autosave(campaign_id, game) if autosave \
		else _load_repository.load_campaign(campaign_id, slot_number, game)
	if not result.get("success", false):
		game.queue_free()
		loading.queue_free()
		_loading_save = false
		_load_panel.call("show_error", str(result.get("reason", "Save inválido.")))
		return
	loading.call("advance_step")
	await get_tree().process_frame
	var visuals_ready := await game.prepare_initial_visuals(
		Callable(loading, "advance_step"))
	if not visuals_ready:
		game.queue_free()
		loading.queue_free()
		_loading_save = false
		_load_panel.call("show_error", "Não foi possível desenhar o mapa.")
		return
	get_tree().current_scene = game
	game.visible = true
	loading.call("advance_step")
	if autosave:
		var bar := game.get_node_or_null("CampaignTopBar") as CampaignTopBar
		if bar != null:
			bar.show_recovery_save_prompt.call_deferred()
	loading.queue_free()
	queue_free()
