class_name PPPMainMenu
extends Control

signal playable_catalog_ready

## A imagem de fundo fica vazia até recebermos os futuros slides. Os botões
## usam uma única paleta para não competir com as cores do cenário brasileiro.
const SELECTION_SCENE := "res://scenes/ui/playable_selection.tscn"
const GAME_SCENE_PATH := "res://teste.tscn"
const LOAD_PANEL_SCRIPT := preload("res://scripts/ui/campaign_load_panel.gd")
const ARCHIVE_LIBRARY_SCRIPT := preload("res://scripts/ui/campaign_archive_library.gd")
const SETTINGS_MENU_SCRIPT := preload("res://scripts/ui/campaign_settings_menu.gd")
const LOADING_OVERLAY_SCRIPT := preload("res://scripts/ui/scene_loading_overlay.gd")

@onready var menu_area: VBoxContainer = $MenuArea
@onready var background_image: TextureRect = $BackgroundImage
@onready var menu_logo: TextureRect = $MenuLogo

var _load_panel: Control
var _archive_library: Control
var _settings_menu: Control
var _archive_from_load := false
var _repository := CampaignSaveRepository.new()
var _placeholder: Control
var _busy := false
var _hover_tweens: Dictionary = {}
var _playable_catalog: Array[EntityData] = []
var _catalog_prepared := false
var _catalog_files := PackedStringArray()
var _catalog_next_index := 0
var _selection_loading: CanvasLayer


func _ready() -> void:
	# Este TextureRect é o ponto de inserção para um futuro carrossel de imagens.
	background_image.texture = null
	resized.connect(_layout_menu)
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.connect("ui_scale_changed", func(_factor: float) -> void:
			_layout_menu.call_deferred())
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(_on_comfort_changed)
	_layout_menu()
	(menu_area.get_node("Heading") as Label).add_theme_color_override(
		"font_color", Color(0.80, 0.88, 0.93))
	_palette_call("bind_color", [menu_area.get_node("Heading"), "font_color", "on_button"])
	_prewarm_playable_catalog.call_deferred()
	for name in ["NewGame", "LoadGame", "CampaignRecords", "Settings", "Credits", "Quit"]:
		var button := menu_area.get_node(name) as Button
		if name != "Quit":
			button.set_meta("ui_sfx_kind", &"menu_page")
		_style_button(button)
		button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
		button.mouse_entered.connect(_hover_button.bind(button, true))
		button.mouse_exited.connect(_hover_button.bind(button, false))
		button.pressed.connect(_press_button.bind(button, name))
	_load_panel = LOAD_PANEL_SCRIPT.new() as Control
	_load_panel.set("repository", _repository)
	add_child(_load_panel)
	_load_panel.connect("load_requested", _on_load_requested)
	_load_panel.connect("archives_requested", _open_archive_library.bind(true))
	_load_panel.hide()
	_archive_library = ARCHIVE_LIBRARY_SCRIPT.new() as Control
	_archive_library.set("repository", _repository)
	add_child(_archive_library)
	_archive_library.connect("back_requested", _back_from_archive)
	_archive_library.connect("main_menu_requested", _main_from_archive)
	_settings_menu = SETTINGS_MENU_SCRIPT.new() as Control
	add_child(_settings_menu)
	_build_placeholder()


func _layout_menu() -> void:
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	var factor := float(scale_service.get("ui_factor")) if scale_service != null else 1.0
	var logo_width := minf(387.0 * factor, maxf(252.0, size.x * 0.279))
	logo_width = minf(logo_width, size.x - 32.0)
	var logo_height := logo_width * 941.0 / 1671.0
	menu_logo.position = Vector2((size.x - logo_width) * 0.5, maxf(0.0, size.y * 0.018))
	menu_logo.size = Vector2(logo_width, logo_height)
	var width := minf(288.0 * factor, maxf(235.0, size.x - 36.0))
	var height := minf(310.0 * factor, maxf(265.0, size.y - 36.0))
	menu_area.position = Vector2(clampf(size.x * 0.10, 18.0,
		maxf(18.0, size.x - width - 18.0)),
		clampf(size.y * 0.35, 18.0, maxf(18.0, size.y - height - 18.0)))
	menu_area.size = Vector2(width, height)


func _style_button(button: Button) -> void:
	var role := "progress" if button.name == "NewGame" else \
		"danger" if button.name == "Quit" else "structure"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.045, 0.065, 0.92)
	normal.border_color = Color(0.35, 0.60, 0.70, 0.90)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 15
	button.add_theme_stylebox_override("normal", normal)
	_palette_call("bind_style", [normal, "button", role])
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.04, 0.10, 0.13, 0.97)
	hover.border_color = Color(0.48, 0.92, 1.0)
	hover.set_border_width_all(2)
	hover.shadow_color = Color(0.12, 0.80, 1.0, 0.45)
	hover.shadow_size = 10
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	_palette_call("bind_style", [hover, "button_hover", role, role])
	_palette_call("bind_control_style", [button, "normal", "button", role])
	_palette_call("bind_control_style", [button, "hover", "button_hover", role, role])
	_palette_call("bind_control_style", [button, "pressed", "button_hover", role, role])
	button.add_theme_color_override("font_color", Color(0.89, 0.95, 0.99))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for key in ["font_color", "font_hover_color", "font_pressed_color"]:
		_palette_call("bind_color", [button, key, "on_button"])
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _hover_button(button: Button, entering: bool) -> void:
	_stop_hover_tween(button)
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and bool(comfort.get("enabled")):
		button.scale = Vector2.ONE
		return
	var tween := create_tween()
	_hover_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2.ONE * (1.025 if entering else 1.0),
		0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _stop_hover_tween(button: Button) -> void:
	var old := _hover_tweens.get(button) as Tween
	if old != null and old.is_running():
		old.kill()
	_hover_tweens.erase(button)


func _on_comfort_changed(enabled: bool) -> void:
	if not enabled:
		return
	for button in _hover_tweens:
		var tween := _hover_tweens[button] as Tween
		if tween != null and tween.is_running():
			tween.kill()
		if is_instance_valid(button):
			(button as Button).scale = Vector2.ONE
	_hover_tweens.clear()


func _press_button(button: Button, action: String) -> void:
	if _busy:
		return
	_busy = true
	_stop_hover_tween(button)
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort == null or not bool(comfort.get("enabled")):
		var tween := create_tween()
		tween.tween_property(button, "scale", Vector2.ONE * 0.94, 0.07)
		tween.tween_property(button, "scale", Vector2.ONE * 1.055, 0.09) \
			.set_trans(Tween.TRANS_BACK)
		tween.tween_property(button, "scale", Vector2.ONE, 0.09)
		await tween.finished
	else:
		button.scale = Vector2.ONE
	_busy = false
	match action:
		"NewGame":
			_busy = true
			_open_selection()
		"LoadGame": _load_panel.call("open")
		"CampaignRecords": _open_archive_library(false)
		"Settings": _settings_menu.call("open")
		"Credits": _show_placeholder("CRÉDITOS")
		"Quit": get_tree().quit()


func _prewarm_playable_catalog() -> void:
	_catalog_files = DirAccess.get_files_at(CampaignState.PLAYABLE_DIRECTORY)
	_catalog_files.sort()
	_catalog_next_index = 0
	_load_next_playable()


func _load_next_playable() -> void:
	if not is_inside_tree():
		return
	while _catalog_next_index < _catalog_files.size():
		var filename := _catalog_files[_catalog_next_index]
		_catalog_next_index += 1
		if not filename.ends_with(".tres"):
			continue
		var character := load(CampaignState.PLAYABLE_DIRECTORY.path_join(filename)) as EntityData
		if character != null and character.id != &"" and &"jogavel" in character.tags:
			_playable_catalog.append(character)
		if _selection_loading != null:
			_selection_loading.call("set_steps", _playable_catalog.size(),
				_catalog_files.size() + 2)
		get_tree().process_frame.connect(_load_next_playable, CONNECT_ONE_SHOT)
		return
	_catalog_prepared = true
	playable_catalog_ready.emit()


func _open_selection() -> void:
	_selection_loading = LOADING_OVERLAY_SCRIPT.new() as CanvasLayer
	get_tree().root.add_child(_selection_loading)
	_selection_loading.call("set_steps", _playable_catalog.size(),
		maxi(1, _playable_catalog.size() + 2))
	await get_tree().process_frame
	await get_tree().process_frame
	if not _catalog_prepared:
		await playable_catalog_ready
	_selection_loading.call("set_steps", _playable_catalog.size() + 1,
		_playable_catalog.size() + 2)
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := load(SELECTION_SCENE) as PackedScene
	var selection := scene.instantiate() as PlayableSelectionScreen if scene != null else null
	if selection == null:
		_selection_loading.queue_free()
		_selection_loading = null
		_busy = false
		return
	selection.preloaded_catalog = _playable_catalog
	get_tree().root.add_child(selection)
	get_tree().current_scene = selection
	_selection_loading.call("set_steps", _playable_catalog.size() + 2,
		_playable_catalog.size() + 2)
	_selection_loading.queue_free()
	_selection_loading = null
	queue_free()


func _build_placeholder() -> void:
	_placeholder = Control.new()
	_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_placeholder)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.80)
	_placeholder.add_child(dim)
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_placeholder.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(330, 160)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.055, 0.075, 0.99)
	style.border_color = Color(0.48, 0.86, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	_palette_call("bind_style", [style, "surface", "structure"])
	_palette_call("bind_control_style", [panel, "panel", "surface", "structure"])
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.90, 0.96, 1.0))
	_palette_call("bind_color", [title, "font_color", "primary"])
	content.add_child(title)
	var explanation := Label.new()
	explanation.text = "Este menu será implementado em uma próxima etapa."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(explanation)
	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size.y = 36
	back.pressed.connect(_placeholder.hide)
	content.add_child(back)
	_placeholder.hide()


func _palette_call(method: String, args: Array) -> void:
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service != null:
		palette_service.callv(method, args)


func _show_placeholder(title: String) -> void:
	(_placeholder.get_node("Center/Panel/Content/Title") as Label).text = title
	_placeholder.show()


func _open_archive_library(from_load: bool) -> void:
	_archive_from_load = from_load
	_load_panel.hide()
	_archive_library.call("open")


func _back_from_archive() -> void:
	_archive_library.call("close")
	if _archive_from_load:
		_load_panel.call("open")


func _main_from_archive() -> void:
	_archive_library.call("close")
	_load_panel.hide()


func _on_load_requested(campaign_id: String, slot_number: int,
		autosave: bool) -> void:
	if _busy:
		return
	_busy = true
	var loading := LOADING_OVERLAY_SCRIPT.new() as CanvasLayer
	get_tree().root.add_child(loading)
	loading.call("set_steps", 0, 31)
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
	(game.get_node("GerenciaJogo") as GerenciaJogo).save_repository = _repository
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
	var result := _repository.load_autosave(campaign_id, game) if autosave else \
		_repository.load_campaign(campaign_id, slot_number, game)
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
	get_tree().current_scene = game
	game.visible = true
	loading.call("advance_step")
	if autosave:
		var bar := game.get_node_or_null("CampaignTopBar") as CampaignTopBar
		if bar != null:
			bar.show_recovery_save_prompt.call_deferred()
	loading.queue_free()
	queue_free()
