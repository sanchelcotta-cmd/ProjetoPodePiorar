class_name PPPMapView
extends Node2D

signal destination_requested(coord: Vector2i)
signal hex_choice_requested(coord: Vector2i)
signal hex_inspection_requested(coord: Vector2i)
signal hex_revealed(coord: Vector2i)
signal future_vision_hex_requested(coord: Vector2i)
signal ground_pressed(screen_position: Vector2)

## Desenha o mapa PPP usando as medidas da cena modelo_de_referencia.tscn.
## PontoZero continua sendo o CENTRO do hex (0, 0). As distâncias abaixo são
## apenas visuais: o caminho lógico ainda custa 1 Stamina por vizinho.
const GROUND_TEXTURE = preload("res://sprites/map/ground.png")
const HEX_TEXTURE = preload("res://sprites/map/hex-ref.png")
const ORIENTATION_SCALE = preload("res://scripts/visuals/sprite_orientation_reference.gd")
const PREVIEW_BACKGROUND = preload("res://sprites/background/cena_baixocentro_0001.png")
const GLOW_RADIUS_FACTOR := 1.24
const REFERENCE_VIEWPORT := Vector2(1152.0, 648.0)
const MAP_VERTICAL_NUDGE := 22.0 # Mesmo a primeira linha fica inteira sobre o asfalto.
const REFERENCE_COLUMN_STEP := 93.0 # média 92,96; arredondada para cima
const REFERENCE_ROW_STEP := 55.0 # média 54,82; arredondada para cima
const REFERENCE_ODD_ROW_OFFSET := 47.0
const GROUND_SCALE := Vector2(0.30751634, 0.30040884)
const GROUND_REPEAT_STEP := 440.0 # média 439,05 entre os 3 centros do modelo
const GROUND_BOTTOM_MARGIN := -2.0 # 2 px além da tela: nunca mostra a faixa cinza.
const GROUND_BACKGROUND_OVERLAP := 2.0 # O asfalto cobre a base dos prédios por 2 px.
const BACKGROUND_SCALE := Vector2(0.65061156, 0.61110663)
const BACKGROUND_SIDE_BLEED := 32.0 # A arte central preserva a escala original.
const CAMERA_ZOOM_LEVELS := [0.85, 1.0, 1.15, 1.30]
const CAMERA_PAN_STEP := 140.0
const CAMERA_SAFE_HEX_MARGIN := 2.0

@export_range(0, 999) var preview_stamina: int = 3
@export var hex_palette: HexPalette

@onready var _ponto_zero: Node2D = get_node_or_null("PontoZero") as Node2D
@onready var _parallax: PPPParallaxBackground = get_node_or_null("ParallaxBackground") as PPPParallaxBackground
@onready var _map_root: Node2D = $MapRoot
@onready var _background: Sprite2D = $MapRoot/Background
@onready var _background_copies: Node2D = $MapRoot/BackgroundCopies
@onready var _ground: Node2D = $MapRoot/Ground
@onready var _start_zone: Node2D = $MapRoot/StartZone
@onready var _hexes: Node2D = $MapRoot/Hexes
@onready var depth_layer: PPPDepthLayer = $MapRoot/DepthSorted
@onready var _special_event_visuals: Node2D = $MapRoot/DepthSorted/SpecialEventVisuals

var grid := HexGrid.new()
var _renderer: HexRenderer
var _actor_coord := Vector2i(-1, 2)
var _unlimited_destinations := false
var _flying_destinations := false
var _selected_coord := Vector2i(-999, -999)
var _occupied_coords: Dictionary = {}
var _retired_start_coords: Dictionary = {}
var _temporary_inspection_coords: Dictionary = {}
var _temporary_inspection_owner_id: StringName = &""
var _future_vision_actor: EntityState
var _emergency_destination := Vector2i(-999, -999)
var _active_hex_pulse := 0.0
var _enemy_link_glow: Sprite2D
var _enemy_link_coord := EntityState.UNPLACED
var _background_bottom_row_cache: Dictionary = {}
var _background_horizontal_bounds_cache: Dictionary = {}
var _gnome_reference_height := -1.0
var _base_map_position := Vector2.ZERO
var _camera_level := 1
var _camera_pan_x := 0.0
var _camera_pan_target_x := 0.0
var _camera_dragging := false
var _camera_drag_last_x := 0.0
var _camera_layer: CanvasLayer
var _camera_buttons: Dictionary = {}
var _zoom_slider: HSlider
var _zoom_frame: PanelContainer
var _pending_initial_visuals := false
var _initial_visuals_prepared := false
var _visual_build_serial := 0
# A regra de destino pertence à Exploração (inclusive Debuffs), não à arte.
# Sem validador, a cena de prévia continua funcionando sozinha no editor.
var destination_validator: Callable = Callable()
var selection_validator: Callable = Callable()


func _ready() -> void:
	var profile_start := Time.get_ticks_msec()
	var defer_preview := bool(get_meta("defer_preview_map", false))
	if not defer_preview:
		_ensure_debug_panel()
	if grid.cells.is_empty() and not defer_preview:
		grid.generate_ppp_exploration_map()
	get_viewport().size_changed.connect(_rebuild_visuals)
	var palette_service := get_node_or_null("/root/UIColorManager")
	if palette_service != null:
		palette_service.connect("palette_changed", _on_ui_palette_changed)
	if not defer_preview:
		_rebuild_visuals()
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL map visuals %d ms" % (Time.get_ticks_msec() - profile_start))
	_build_camera_controls()
	var exploration := get_node_or_null("ExplorationManager") as ExplorationManager
	if exploration != null:
		exploration.turn_started.connect(func(_actor: EntityState) -> void:
			_ensure_active_visible.call_deferred())
		exploration.actor_moved.connect(func(_actor: EntityState,
				_path: Array[Vector2i], _spent: int) -> void:
			_ensure_active_visible.call_deferred())
		exploration.actor_teleported.connect(func(_actor: EntityState,
				_destination: Vector2i) -> void:
			_ensure_active_visible.call_deferred())
	var combat := get_node_or_null("CombatManager") as CombatManager
	if combat != null:
		combat.turn_started.connect(func(_actor: EntityState, _cycle: int) -> void:
			_ensure_active_visible.call_deferred())
		combat.action_resolved.connect(func(_actor: EntityState, _action: StringName,
				_result: Dictionary) -> void:
			_ensure_active_visible.call_deferred())
	if _parallax != null and not defer_preview:
		_parallax.show_generated_map(grid)
	if ProjectSettings.get_setting("ppp/profile_startup", false):
		print("PPP_DETAIL map root total %d ms" % (Time.get_ticks_msec() - profile_start))


func _ensure_debug_panel() -> void:
	if get_node_or_null("CampaignDebugPanel") != null or not OS.has_feature("debug") \
			or not bool(ProjectSettings.get_setting("ppp/debug/enabled", false)):
		return
	# A exportação pública exclui o script; não o pré-carregar.
	var panel_script := load("res://scripts/ui/campaign_debug_panel.gd") as Script
	if panel_script != null:
		var debug_panel := panel_script.new() as CanvasLayer
		debug_panel.name = "CampaignDebugPanel"
		add_child(debug_panel)


func prepare_initial_interface(progress: Callable = Callable()) -> bool:
	var bar := get_node_or_null("CampaignTopBar") as CampaignTopBar
	if bar == null:
		return false
	await bar.prepare_initial_ui(progress)
	if not bar.is_initial_ui_ready():
		return false
	_ensure_debug_panel()
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame
	return true


func _rebuild_visuals() -> void:
	_visual_build_serial += 1
	_begin_visual_rebuild()
	for coord in grid.cells:
		_renderer.create_hex_visual(_hexes, coord, reference_hex_position(coord))
	_finish_visual_rebuild()


## Apenas na primeira entrada de uma campanha carregada: a lógica do mapa já
## está instalada, mas os nós visuais são construídos em lotes. A barra recebe
## um passo somente quando um lote terminou; não há timer simulando progresso.
func prepare_initial_visuals(progress: Callable = Callable()) -> bool:
	if _initial_visuals_prepared:
		return true
	if not _pending_initial_visuals or grid.cells.is_empty():
		return false
	_visual_build_serial += 1
	var serial := _visual_build_serial
	_begin_visual_rebuild()
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame
	var created := 0
	for coord in grid.cells:
		if serial != _visual_build_serial:
			return _initial_visuals_prepared
		_renderer.create_hex_visual(_hexes, coord, reference_hex_position(coord))
		created += 1
		if created % 8 == 0:
			if progress.is_valid():
				progress.call()
			await get_tree().process_frame
	if created % 8 != 0:
		if progress.is_valid():
			progress.call()
		await get_tree().process_frame
	if serial != _visual_build_serial:
		return _initial_visuals_prepared
	_finish_visual_rebuild()
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame
	if serial != _visual_build_serial:
		return _initial_visuals_prepared
	if _parallax != null:
		_parallax.show_generated_map(grid)
	_pending_initial_visuals = false
	_initial_visuals_prepared = true
	if progress.is_valid():
		progress.call()
	await get_tree().process_frame
	return true


func _begin_visual_rebuild() -> void:
	_map_root.scale = Vector2.ONE
	_clear_nodes(_background_copies)
	_clear_nodes(_ground)
	_clear_nodes(_start_zone)
	_clear_nodes(_hexes)
	var screen_size := get_viewport_rect().size
	if _ponto_zero != null:
		# PontoZero vem da cena modelo. A janela proporcional amplia todas as
		# camadas juntas; aqui só centralizamos o grid e mantemos seu pé no chão.
		_map_root.position = _ponto_zero.position + Vector2(
			(screen_size.x - REFERENCE_VIEWPORT.x) * 0.5,
			screen_size.y - REFERENCE_VIEWPORT.y + MAP_VERTICAL_NUDGE
		)
	else:
		var bounds := _reference_map_bounds()
		_map_root.position = Vector2(
			(screen_size.x - bounds.size.x) * 0.5 - bounds.position.x,
			screen_size.y - GROUND_BOTTOM_MARGIN - bounds.end.y + MAP_VERTICAL_NUDGE
		)
	_base_map_position = _map_root.position
	_layout_background(screen_size)
	_layout_background_copies()
	_layout_ground(screen_size)
	_renderer = HexRenderer.new(hex_palette if hex_palette != null else HexPalette.new())
	var palette_service := get_node_or_null("/root/UIColorManager")
	_renderer.set_ui_palette(str(palette_service.get("palette_id")) if palette_service != null \
		else "padrao")
	_renderer.cell_pressed.connect(_on_cell_pressed)


func _finish_visual_rebuild() -> void:
	_enemy_link_glow = Sprite2D.new()
	_enemy_link_glow.name = "EnemyInitiativeGlow"
	_enemy_link_glow.texture = HEX_TEXTURE
	_enemy_link_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_enemy_link_glow.scale = HexRenderer.REFERENCE_SPRITE_SCALE * 1.26
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_enemy_link_glow.material = glow_material
	_enemy_link_glow.visible = false
	_hexes.add_child(_enemy_link_glow)
	for start_coord in grid.get_ppp_start_positions():
		if _retired_start_coords.has(start_coord):
			continue
		var marker := Sprite2D.new()
		marker.name = "Start_%d" % start_coord.y
		marker.texture = HEX_TEXTURE
		marker.scale = HexRenderer.REFERENCE_SPRITE_SCALE
		marker.position = reference_hex_position(start_coord)
		marker.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_start_zone.add_child(marker)
	_refresh_feedback()
	refresh_special_event_visuals()
	_apply_camera_transform()
	_refresh_camera_controls()


func _process(delta: float) -> void:
	if absf(_camera_pan_x - _camera_pan_target_x) > 0.25:
		_camera_pan_x = lerpf(_camera_pan_x, _camera_pan_target_x,
			1.0 - exp(-12.0 * delta))
		_apply_camera_transform()
		_refresh_camera_controls()
	elif _camera_pan_x != _camera_pan_target_x:
		_camera_pan_x = _camera_pan_target_x
		_apply_camera_transform()
	# Realce lento do chão sob o personagem ativo, sem apagar o hex.
	_active_hex_pulse += delta
	if _enemy_link_glow != null and _enemy_link_glow.visible:
		_enemy_link_glow.modulate = Color(0.20, 0.93, 1.0,
			0.32 + 0.22 * (0.5 + 0.5 * sin(_active_hex_pulse * 5.0)))
	var brightness := (sin(_active_hex_pulse * 1.8) + 1.0) * 0.5
	var color := Color(1.0, lerpf(0.85, 0.96, brightness),
		lerpf(0.34, 0.59, brightness), 1.0)
	if grid.is_valid(_actor_coord):
		var area := _hexes.get_node_or_null("Hex_%d_%d" % [_actor_coord.x,
			_actor_coord.y]) as Area2D
		if area != null:
			area.modulate = color
	elif grid.is_ppp_start_zone(_actor_coord):
		var marker := _start_zone.get_node_or_null("Start_%d" % _actor_coord.y) as Sprite2D
		if marker != null:
			marker.modulate = color


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_camera_dragging = false
		get_node("/root/GameCursor").call("release_drag", self)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and event.double_click and _camera_level > 1:
		var click := event as InputEventMouseButton
		var hud := get_node_or_null("PartyStatusHUD") as PartyStatusHUD
		var on_active_card := false
		var actor := _active_camera_actor()
		if hud != null and actor != null:
			for card in hud.cards:
				if card.state == actor and card.get_global_rect().has_point(click.position):
					on_active_card = true
					break
		if not _camera_input_blocked() and (on_active_card or (click.position.y < get_ground_screen_top() \
				and get_viewport().gui_get_hovered_control() == null)):
			_reframe_active_actor()
			if not on_active_card:
				if hud != null:
					hud.close_expandable_boxes()
				var top := get_node_or_null("CampaignTopBar") as CampaignTopBar
				if top != null:
					top.close_expandable_boxes()
			get_viewport().set_input_as_handled()
			return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or not event.double_click:
		return
	# O segundo clique na área livre do mapa apenas recolhe janelas; não
	# seleciona outro hex nem confirma uma ação de combate.
	if get_viewport().gui_get_hovered_control() != null:
		return
	var activation := get_node_or_null("BlockActivationPopup")
	if activation != null and activation.overlay.visible:
		return
	var hud := get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	if hud != null:
		hud.close_expandable_boxes()
	var top_bar := get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar != null:
		top_bar.close_expandable_boxes()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _camera_input_blocked():
		_camera_dragging = false
		get_node("/root/GameCursor").call("release_drag", self)
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] \
				and mouse.pressed and get_viewport().gui_get_hovered_control() == null:
			_set_camera_level(_camera_level + (1 if mouse.button_index \
				== MOUSE_BUTTON_WHEEL_UP else -1))
			get_viewport().set_input_as_handled()
			return
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if not mouse.pressed:
				_camera_dragging = false
				get_node("/root/GameCursor").call("release_drag", self)
				return
			if _camera_level > 1 and mouse.position.y < get_ground_screen_top() \
					and get_viewport().gui_get_hovered_control() == null \
					and not _point_over_hex(mouse.position):
				_camera_dragging = true
				if cursor_can_pan_at(mouse.position):
					get_node("/root/GameCursor").call("capture_drag", self,
						"arrastar_horizontal")
				_camera_drag_last_x = mouse.position.x
				get_viewport().set_input_as_handled()
				return
	if event is InputEventMouseMotion and _camera_dragging:
		_camera_pan_target_x += ((event as InputEventMouseMotion).position.x \
			- _camera_drag_last_x) * 0.7
		_camera_drag_last_x = (event as InputEventMouseMotion).position.x
		_camera_pan_target_x = clampf(_camera_pan_target_x,
			-_camera_pan_limit(), _camera_pan_limit())
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or event.double_click \
			or grid.ppp_map_mode not in [HexGrid.PPPMapMode.EXPLORATION,
				HexGrid.PPPMapMode.COMBAT]:
		return
	var point: Vector2 = (event as InputEventMouseButton).position
	if get_viewport().gui_get_hovered_control() != null \
			or point.y < get_ground_screen_top() or _point_over_hex(point):
		return
	# Hexes, entidades e controles têm prioridade sobre o chão em ambos os modos.
	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_viewport().get_canvas_transform().affine_inverse() * point
	query.collide_with_areas = true
	for hit in get_world_2d().direct_space_state.intersect_point(query, 32):
		var collider := hit.get("collider") as Area2D
		if collider != null and collider.name == "BodyClickArea":
			return
	ground_pressed.emit(point)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo \
			or _camera_level <= 1 or _camera_input_blocked():
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		_pan_camera(CAMERA_PAN_STEP * (-1.0 if event.keycode == KEY_RIGHT else 1.0))
		get_viewport().set_input_as_handled()


func _camera_input_blocked() -> bool:
	if get_tree().paused:
		return true
	var activation := get_node_or_null("BlockActivationPopup")
	if activation != null and activation.overlay.visible:
		return true
	var rounds := get_node_or_null("RoundManager") as RoundManager
	if rounds != null and rounds.is_destination_choice_open():
		return true
	var bar := get_node_or_null("CampaignTopBar") as CampaignTopBar
	return bar != null and bar.pause_menu != null and bar.pause_menu.is_open()


func cursor_can_pan_at(point: Vector2) -> bool:
	# Céu e fachadas aceitam o gesto lateral; ground e hexes não.
	return _camera_level > 1 and not _camera_input_blocked() \
		and point.y < get_ground_screen_top()


func _camera_zoom() -> float:
	return float(CAMERA_ZOOM_LEVELS[_camera_level])


func _set_camera_level(level: int) -> void:
	var next := clampi(level, 0, CAMERA_ZOOM_LEVELS.size() - 1)
	if next == _camera_level:
		return
	_camera_level = next
	_camera_dragging = false
	get_node("/root/GameCursor").call("release_drag", self)
	if _camera_level <= 1:
		_camera_pan_x = 0.0
		_camera_pan_target_x = 0.0
	_apply_camera_transform()
	_ensure_active_visible()
	_refresh_camera_controls()


func _pan_camera(delta_x: float) -> void:
	if _camera_level <= 1:
		return
	_camera_pan_target_x = clampf(_camera_pan_target_x + delta_x,
		-_camera_pan_limit(), _camera_pan_limit())
	_refresh_camera_controls()


func _camera_pan_limit() -> float:
	if _camera_level <= 1:
		return 0.0
	return (_camera_zoom() - 1.0) * get_viewport_rect().size.x * 0.5 \
		+ REFERENCE_COLUMN_STEP * 0.5


func _apply_camera_transform() -> void:
	if _map_root == null:
		return
	_camera_pan_x = clampf(_camera_pan_x, -_camera_pan_limit(), _camera_pan_limit())
	_camera_pan_target_x = clampf(_camera_pan_target_x,
		-_camera_pan_limit(), _camera_pan_limit())
	var screen := get_viewport_rect().size
	var pivot := Vector2(screen.x * 0.5, screen.y)
	var zoom := _camera_zoom()
	_map_root.scale = Vector2.ONE * zoom
	_map_root.position = pivot + (_base_map_position - pivot) * zoom \
		+ Vector2(_camera_pan_x, 0.0)


func _active_camera_actor() -> EntityState:
	if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
		var combat := get_node_or_null("CombatManager") as CombatManager
		return combat.current_actor if combat != null else null
	var exploration := get_node_or_null("ExplorationManager") as ExplorationManager
	return exploration.current_actor if exploration != null else null


func _ensure_active_visible() -> void:
	if _camera_level <= 1:
		return
	var actor := _active_camera_actor()
	if actor == null or actor.position == EntityState.UNPLACED:
		return
	var screen := get_viewport_rect().size
	var hud_right := _camera_hud_right()
	var margin := CAMERA_SAFE_HEX_MARGIN * REFERENCE_COLUMN_STEP * _camera_zoom()
	var left := hud_right + margin
	var right := screen.x - margin
	if right <= left:
		return
	var current_x := _map_root.to_global(reference_hex_position(actor.position)).x
	if current_x < left:
		_camera_pan_target_x += left - current_x
	elif current_x > right:
		_camera_pan_target_x -= current_x - right
	_camera_pan_target_x = clampf(_camera_pan_target_x,
		-_camera_pan_limit(), _camera_pan_limit())
	_refresh_camera_controls()


func _reframe_active_actor() -> void:
	var actor := _active_camera_actor()
	if actor == null or actor.position == EntityState.UNPLACED:
		return
	var screen := get_viewport_rect().size
	var center := (_camera_hud_right() + screen.x) * 0.5
	var current_x := _map_root.to_global(reference_hex_position(actor.position)).x
	_camera_pan_target_x = clampf(_camera_pan_x + center - current_x,
		-_camera_pan_limit(), _camera_pan_limit())


func _camera_hud_right() -> float:
	var hud := get_node_or_null("PartyStatusHUD/Root") as Control
	return hud.get_global_rect().end.x if hud != null else 0.0


func _build_camera_controls() -> void:
	_camera_layer = CanvasLayer.new()
	_camera_layer.name = "MapCameraControls"
	_camera_layer.layer = 49 # Abaixo dos menus e caixas do HUD (50+).
	add_child(_camera_layer)
	var overlay := Control.new()
	_overlay_camera_full_rect(overlay)
	_camera_layer.add_child(overlay)
	var frame := PanelContainer.new()
	frame.name = "ZoomLevels"
	_zoom_frame = frame
	frame.custom_minimum_size = Vector2(88.0, 36.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.035, 0.05, 0.94)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2.0)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_camera_place(frame, overlay)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 0)
	frame.add_child(contents)
	var track_slot := Control.new()
	track_slot.custom_minimum_size = Vector2(76.0, 15.0)
	track_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.add_child(track_slot)
	var segments := HBoxContainer.new()
	segments.position = Vector2(0.0, 3.0)
	segments.add_theme_constant_override("separation", 0)
	segments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_slot.add_child(segments)
	for number in 4:
		var segment := Panel.new()
		segment.name = "Level%d" % (number + 1)
		segment.custom_minimum_size = Vector2(19.0, 9.0)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var segment_style := StyleBoxFlat.new()
		segment_style.bg_color = Color(1.0, 1.0, 1.0, 0.06)
		segment_style.border_color = Color.WHITE
		segment_style.set_border_width_all(1)
		segment.add_theme_stylebox_override("panel", segment_style)
		segments.add_child(segment)
	_zoom_slider = HSlider.new()
	_zoom_slider.min_value = 0
	_zoom_slider.max_value = 3
	_zoom_slider.step = 1
	_zoom_slider.tick_count = 4
	_zoom_slider.ticks_on_borders = true
	_zoom_slider.focus_mode = Control.FOCUS_NONE # Setas sempre deslocam o mapa.
	_zoom_slider.value = _camera_level
	_zoom_slider.custom_minimum_size = Vector2(76.0, 15.0)
	_zoom_slider.tooltip_text = "Zoom da cena: 1 afasta, 2 padrão, 3 aproxima, 4 aproxima mais. Rolinhos do mouse também mudam o zoom."
	var track := StyleBoxEmpty.new()
	_zoom_slider.add_theme_stylebox_override("slider", track)
	_zoom_slider.add_theme_stylebox_override("grabber_area", track)
	_zoom_slider.add_theme_stylebox_override("grabber_area_highlight", track)
	var handle_image := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	handle_image.fill(Color.TRANSPARENT)
	for y in 11:
		for x in 11:
			if Vector2(x - 5, y - 5).length_squared() <= 23.0:
				handle_image.set_pixel(x, y, Color("f4ca52"))
	var handle := ImageTexture.create_from_image(handle_image)
	_zoom_slider.add_theme_icon_override("grabber", handle)
	_zoom_slider.add_theme_icon_override("grabber_highlight", handle)
	track_slot.add_child(_zoom_slider)
	_zoom_slider.value_changed.connect(func(value: float) -> void:
		_set_camera_level(roundi(value)))
	var caption := Label.new()
	caption.text = "zoom"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 9)
	caption.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.72))
	contents.add_child(caption)
	for side in [-1, 1]:
		var button := Button.new()
		button.text = "◀" if side < 0 else "▶"
		button.name = "PanLeft" if side < 0 else "PanRight"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(28.0, 44.0)
		button.tooltip_text = "Deslocar a cena para %s" % ("esquerda" if side < 0 else "direita")
		button.pressed.connect(_pan_camera.bind(CAMERA_PAN_STEP * \
			(1.0 if side < 0 else -1.0)))
		_overlay_camera_place(button, overlay)
		_camera_buttons[side] = button
	_refresh_camera_controls()


func _overlay_camera_full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _overlay_camera_place(control: Control, parent: Control) -> void:
	parent.add_child(control)
	control.mouse_filter = Control.MOUSE_FILTER_STOP


func _refresh_camera_controls() -> void:
	if _camera_layer == null or _zoom_slider == null:
		return
	_zoom_slider.set_value_no_signal(_camera_level)
	var screen := get_viewport_rect().size
	var bar := get_node_or_null("CampaignTopBar/Bar") as Control
	var x := _camera_hud_right() + 8.0
	var top_bar_left := bar.get_global_rect().position.x if bar != null else screen.x
	_zoom_frame.position = Vector2(x, 7.0 if top_bar_left - x >= 96.0 else 55.0)
	for side in [-1, 1]:
		var button := _camera_buttons.get(side) as Button
		button.visible = _camera_level > 1
		button.position = Vector2(_camera_hud_right() + 6.0 if side < 0 \
			else screen.x - 35.0, screen.y * 0.5 - 22.0)
		button.disabled = _camera_pan_target_x >= _camera_pan_limit() - 1.0 \
			if side < 0 else _camera_pan_target_x <= -_camera_pan_limit() + 1.0


func get_ground_screen_top() -> float:
	if _ground.get_child_count() > 0:
		var tile := _ground.get_child(0) as Sprite2D
		if tile != null:
			return tile.to_global(Vector2(0.0,
				-float(GROUND_TEXTURE.get_height()) * 0.5)).y
	return get_viewport_rect().size.y - GROUND_BOTTOM_MARGIN \
		- float(GROUND_TEXTURE.get_height()) * GROUND_SCALE.y


func _point_over_hex(screen_point: Vector2) -> bool:
	for area in _hexes.get_children():
		if not area is Area2D:
			continue
		var collision := area.get_child(0) as CollisionPolygon2D
		if collision != null and Geometry2D.is_point_in_polygon(
				area.get_global_transform_with_canvas().affine_inverse() * screen_point,
				collision.polygon):
			return true
	return false


func get_clickable_hex_at_screen_position(screen_point: Vector2) -> Vector2i:
	var nearest := EntityState.UNPLACED
	var nearest_distance := INF
	for area in _hexes.get_children():
		if not area is Area2D or not area.input_pickable:
			continue
		var collision := area.get_child(0) as CollisionPolygon2D
		if collision != null and Geometry2D.is_point_in_polygon(
				area.get_global_transform_with_canvas().affine_inverse() * screen_point,
				collision.polygon):
			var coord_text := area.name.trim_prefix("Hex_")
			var coord := Vector2i(int(coord_text.get_slice("_", 0)),
				int(coord_text.get_slice("_", 1)))
			var distance: float = area.get_global_transform_with_canvas().origin.distance_squared_to(
				screen_point)
			if distance < nearest_distance:
				nearest = coord
				nearest_distance = distance
	return nearest


static func reference_hex_position(coord: Vector2i) -> Vector2:
	return Vector2(
		coord.x * REFERENCE_COLUMN_STEP + (coord.y & 1) * REFERENCE_ODD_ROW_OFFSET,
		coord.y * REFERENCE_ROW_STEP
	)


func get_hex_screen_position(coord: Vector2i) -> Vector2:
	var area := _hexes.get_node_or_null("Hex_%d_%d" % [coord.x, coord.y]) as Node2D
	return area.get_global_transform_with_canvas().origin if area != null else Vector2.ZERO


func _reference_map_bounds() -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for coord in grid.cells:
		var point := reference_hex_position(coord)
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	for coord in grid.get_ppp_start_positions():
		var point := reference_hex_position(coord)
		min_point = min_point.min(point)
		max_point = max_point.max(point)
	var margin := Vector2(HEX_TEXTURE.get_size()) * HexRenderer.REFERENCE_SPRITE_SCALE \
		* 0.5 * GLOW_RADIUS_FACTOR
	return Rect2(min_point - margin, max_point - min_point + margin * 2.0)


func _layout_background(screen_size: Vector2) -> void:
	var path := grid.ppp_background_path
	if path.is_empty():
		_background.texture = PREVIEW_BACKGROUND
	else:
		_background.texture = load(path) as Texture2D
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _background.texture == null:
		return
	# O PNG suburbio_0003 é mais estreito que os demais. Medir o trecho
	# VISÍVEL perto da base evita deixar céu aberto nas bordas, inclusive
	# quando outro distrito ou tamanho de janela for sorteado.
	var horizontal := _visible_facade_horizontal_bounds(_background.texture)
	var visible_width := float(horizontal.y - horizontal.x + 1)
	var scale_x := maxf(BACKGROUND_SCALE.x,
		(screen_size.x + BACKGROUND_SIDE_BLEED * 2.0) / visible_width)
	_background.scale = Vector2(scale_x, BACKGROUND_SCALE.y)
	var visible_center := (float(horizontal.x + horizontal.y + 1) * 0.5) \
		- float(_background.texture.get_width()) * 0.5
	_background.position.x = screen_size.x * 0.5 - _map_root.position.x \
		- visible_center * scale_x
	# Cada PNG deixa uma margem transparente diferente sob as casas. Alinhar
	# a borda do arquivo criaria uma fresta; alinhamos a base VISÍVEL da arte.
	var bottom_row := _visible_background_bottom_row(_background.texture)
	if bottom_row < 0:
		return
	var ground_top := screen_size.y - GROUND_BOTTOM_MARGIN \
		- float(GROUND_TEXTURE.get_height()) * GROUND_SCALE.y
	var visible_bottom_from_center := (float(bottom_row + 1) \
		- float(_background.texture.get_height()) * 0.5) * BACKGROUND_SCALE.y
	_background.position.y = ground_top + GROUND_BACKGROUND_OVERLAP \
		- _map_root.position.y - visible_bottom_from_center


func _layout_background_copies() -> void:
	if _background.texture == null:
		return
	var horizontal := _visible_facade_horizontal_bounds(_background.texture)
	var step := float(horizontal.y - horizontal.x + 1) * _background.scale.x
	for side in [-1, 1]:
		for number in [1, 2]:
			var copy := Sprite2D.new()
			copy.name = "Facade_%d_%d" % [side, number]
			copy.texture = _background.texture
			copy.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			copy.scale = _background.scale
			copy.position = _background.position + Vector2(side * number * step, 0.0)
			_background_copies.add_child(copy)


func _visible_facade_horizontal_bounds(texture: Texture2D) -> Vector2i:
	var key := texture.resource_path
	if _background_horizontal_bounds_cache.has(key):
		return _background_horizontal_bounds_cache[key]
	var picture := texture.get_image()
	if picture == null:
		return Vector2i(0, texture.get_width() - 1)
	var bottom := _visible_background_bottom_row(texture)
	if bottom < 0:
		return Vector2i(0, texture.get_width() - 1)
	var top := maxi(0, bottom - maxi(12, int(picture.get_height() / 8)))
	var left := picture.get_width()
	var right := -1
	for x in picture.get_width():
		for y in range(bottom, top - 1, -2):
			if picture.get_pixel(x, y).a >= 0.8:
				left = mini(left, x)
				right = maxi(right, x)
				break
	var result := Vector2i(left, right) if right >= left else \
		Vector2i(0, picture.get_width() - 1)
	_background_horizontal_bounds_cache[key] = result
	return result


func _visible_background_bottom_row(texture: Texture2D) -> int:
	var key := texture.resource_path
	if _background_bottom_row_cache.has(key):
		return int(_background_bottom_row_cache[key])
	var picture := texture.get_image()
	if picture == null:
		return -1
	# Amostras ao longo de toda a largura evitam que um pontinho isolado ou
	# uma casa mais baixa esconda uma fresta sob as outras casas.
	var lowest_common_row := picture.get_height()
	for sample in range(1, 20):
		var x := roundi(float(sample) * float(picture.get_width() - 1) / 20.0)
		for y in range(picture.get_height() - 1, -1, -1):
			if picture.get_pixel(x, y).a >= 0.8:
				lowest_common_row = mini(lowest_common_row, y)
				break
	var result := lowest_common_row if lowest_common_row < picture.get_height() else -1
	_background_bottom_row_cache[key] = result
	return result


func _layout_ground(screen_size: Vector2) -> void:
	# Três cópias bastam na tela de referência. Em telas mais largas, cria
	# quantas forem necessárias. O chão ocupa só a faixa inferior: não vira
	# um fundo esticado sobre a cidade ou sobre o futuro céu.
	_ground.position = -_map_root.position
	var tile_width := float(GROUND_TEXTURE.get_width()) * GROUND_SCALE.x
	var tile_height := float(GROUND_TEXTURE.get_height()) * GROUND_SCALE.y
	var center_y := screen_size.y - GROUND_BOTTOM_MARGIN - tile_height * 0.5
	var center_x := tile_width * 0.5 - ceilf(screen_size.x / GROUND_REPEAT_STEP) \
		* GROUND_REPEAT_STEP
	var index := 0
	while center_x - tile_width * 0.5 < screen_size.x * 2.0:
		var tile := Sprite2D.new()
		tile.name = "Ground_%d" % index
		tile.texture = GROUND_TEXTURE
		tile.scale = GROUND_SCALE
		tile.position = Vector2(center_x, center_y)
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_ground.add_child(tile)
		center_x += GROUND_REPEAT_STEP
		index += 1


func _refresh_feedback() -> void:
	if not _renderer:
		return
	var reachable := grid.get_ppp_reachable_hexes(_actor_coord, preview_stamina)
	if grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION \
			and grid.is_valid(_emergency_destination):
		reachable[_emergency_destination] = HexGrid.distance(
			_actor_coord, _emergency_destination)
	if _unlimited_destinations and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION:
		for coord in grid.cells:
			if grid.can_choose_ppp_destination(coord, _actor_coord, _occupied_coords):
				reachable[coord] = 0
	elif _flying_destinations and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION:
		for coord in grid.cells:
			var distance := HexGrid.distance(_actor_coord, coord)
			if distance <= preview_stamina and grid.can_choose_ppp_destination(
					coord, _actor_coord, _occupied_coords):
				reachable[coord] = distance
	var destinations := grid.get_ppp_available_destinations(reachable, _actor_coord, _occupied_coords)
	_filter_destinations(destinations)
	var inspection_coords := _temporary_inspection_coords.duplicate()
	if _future_vision_actor != null:
		for coord in grid.cells:
			var cell := grid.get_cell(coord)
			if cell != null and cell.state == HexGrid.PPPBlockState.HIDDEN \
					and cell.block_type != HexGrid.PPPBlockType.NONE:
				inspection_coords[coord] = true
	_renderer.update_ppp_feedback(_hexes, grid, destinations, _selected_coord,
		_actor_coord, inspection_coords)
	for start_coord in grid.get_ppp_start_positions():
		var marker := _start_zone.get_node_or_null("Start_%d" % start_coord.y) as Sprite2D
		if marker != null:
			marker.modulate = _renderer.get_active_color() if start_coord == _actor_coord \
				else Color.WHITE


func _on_ui_palette_changed(palette_id: String) -> void:
	if _renderer != null:
		_renderer.set_ui_palette(palette_id)
		_refresh_feedback()


## Mesmo fluxo para clicar no hex ou no corpo visual do inimigo.
func preview_combat_destination(coord: Vector2i) -> void:
	if grid.ppp_map_mode != HexGrid.PPPMapMode.COMBAT or not grid.is_valid(coord) \
			or _selected_coord == coord:
		return
	_selected_coord = coord
	_refresh_feedback()


func highlight_enemy_hex(coord: Vector2i) -> void:
	if grid.ppp_map_mode != HexGrid.PPPMapMode.COMBAT or not grid.is_valid(coord):
		return
	_enemy_link_coord = coord
	if _enemy_link_glow != null:
		_enemy_link_glow.position = reference_hex_position(coord)
		_enemy_link_glow.show()
	preview_combat_destination(coord)


func clear_enemy_hex_highlight() -> void:
	_enemy_link_coord = EntityState.UNPLACED
	if _enemy_link_glow != null:
		_enemy_link_glow.hide()


func request_combat_selection(coord: Vector2i) -> void:
	if grid.ppp_map_mode != HexGrid.PPPMapMode.COMBAT or not grid.is_valid(coord):
		return
	if selection_validator.is_valid() and not selection_validator.call(coord):
		return
	_selected_coord = coord
	_refresh_feedback()
	hex_choice_requested.emit(coord)


func _on_cell_pressed(coord: Vector2i, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event is InputEventMouseButton and event.double_click:
		return
	# Clicar escolhe um hex; a interface oferece movimento e habilidades.
	# O personagem só anda depois de confirmar "Andar até".
	if not grid.is_valid(coord):
		return
	if _future_vision_actor != null:
		var future_cell := grid.get_cell(coord)
		if future_cell != null and future_cell.state == HexGrid.PPPBlockState.HIDDEN \
				and future_cell.block_type != HexGrid.PPPBlockType.NONE:
			future_vision_hex_requested.emit(coord)
		return
	if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
		request_combat_selection(coord)
		return
	# A Mãe só consulta estes blocos: não muda o estado permanente do hex.
	if _temporary_inspection_coords.has(coord):
		hex_inspection_requested.emit(coord)
		return
	# Uma revelação rosa abre uma única caixa com detalhes e ações.
	var cell := grid.get_cell(coord)
	if cell != null and cell.state == HexGrid.PPPBlockState.REVEALED:
		if selection_validator.is_valid() and not selection_validator.call(coord):
			return
		_selected_coord = coord
		_refresh_feedback()
		hex_choice_requested.emit(coord)
		return
	if selection_validator.is_valid() and not selection_validator.call(coord):
		return
	_selected_coord = coord
	_refresh_feedback()
	hex_choice_requested.emit(coord)


func _filter_destinations(destinations: Dictionary) -> void:
	if not destination_validator.is_valid():
		return
	for coord in destinations.keys():
		if not destination_validator.call(coord):
			destinations.erase(coord)


## Pontos de integração para o futuro ExplorationManager/BlockManager.
func show_generated_map(new_grid: HexGrid) -> void:
	if new_grid == null:
		return
	grid = new_grid
	clear_enemy_hex_highlight()
	_retired_start_coords.clear()
	_temporary_inspection_coords.clear()
	_temporary_inspection_owner_id = &""
	_future_vision_actor = null
	_selected_coord = Vector2i(-999, -999)
	if is_node_ready():
		if bool(get_meta("defer_preview_map", false)) and not _initial_visuals_prepared:
			_pending_initial_visuals = true
		else:
			_rebuild_visuals()
			if _parallax != null:
				_parallax.show_generated_map(new_grid)


func set_visual_effects(weather_event_id: StringName, infernal_portals_active: bool) -> void:
	if _parallax != null:
		_parallax.set_visual_effects(weather_event_id, infernal_portals_active)


func set_active_actor(coord: Vector2i, stamina: int,
		unlimited_destinations: bool = false,
		flying_destinations: bool = false) -> void:
	_actor_coord = coord
	preview_stamina = stamina
	_unlimited_destinations = unlimited_destinations
	_flying_destinations = flying_destinations
	_selected_coord = Vector2i(-999, -999)
	clear_enemy_hex_highlight()
	_refresh_feedback()


func set_emergency_destination(coord: Vector2i) -> void:
	_emergency_destination = coord
	_refresh_feedback()


func retire_start_marker(coord: Vector2i) -> void:
	if not grid.is_ppp_start_zone(coord):
		return
	_retired_start_coords[coord] = true
	var marker := _start_zone.get_node_or_null("Start_%d" % coord.y)
	if marker != null:
		marker.hide()


func set_occupied_coords(coords: Dictionary) -> void:
	_occupied_coords = coords.duplicate()
	_refresh_feedback()


func reveal_block(coord: Vector2i) -> void:
	var cell := grid.get_cell(coord)
	var was_revealed := cell != null and cell.state == HexGrid.PPPBlockState.REVEALED
	grid.reveal_ppp_block(coord)
	if _selected_coord == coord:
		_selected_coord = Vector2i(-999, -999)
	_refresh_feedback()
	if not was_revealed and grid.get_cell(coord).state == HexGrid.PPPBlockState.REVEALED:
		hex_revealed.emit(coord)


func set_temporary_inspection(owner: EntityState, coords: Array[Vector2i]) -> void:
	_temporary_inspection_coords.clear()
	_temporary_inspection_owner_id = owner.instance_id if owner != null else &""
	for coord in coords:
		var cell := grid.get_cell(coord)
		if cell != null and cell.state in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			_temporary_inspection_coords[coord] = true
	_refresh_feedback()


func clear_temporary_inspection(owner: EntityState = null) -> void:
	if owner != null and owner.instance_id != _temporary_inspection_owner_id:
		return
	_temporary_inspection_coords.clear()
	_temporary_inspection_owner_id = &""
	_refresh_feedback()


func is_temporary_inspection(coord: Vector2i) -> bool:
	return _temporary_inspection_coords.has(coord)


func begin_future_vision(actor: EntityState) -> void:
	_future_vision_actor = actor
	_refresh_feedback()


func end_future_vision() -> void:
	_future_vision_actor = null
	_refresh_feedback()


func is_future_vision_active() -> bool:
	return _future_vision_actor != null


func activate_block(coord: Vector2i) -> void:
	grid.activate_ppp_block(coord)
	_temporary_inspection_coords.erase(coord)
	_refresh_feedback()
	refresh_special_event_visuals()


func cancel_block(coord: Vector2i) -> void:
	grid.cancel_ppp_block(coord)
	_temporary_inspection_coords.erase(coord)
	_refresh_feedback()
	refresh_special_event_visuals()


func destroy_block(coord: Vector2i) -> void:
	grid.destroy_ppp_block(coord)
	_temporary_inspection_coords.erase(coord)
	_refresh_feedback()
	refresh_special_event_visuals()


## Só desenha conteúdos que receberam uma aparência visível própria.
## Os demais hexes continuam ocultando seu Resource até a ativação.
func refresh_special_event_visuals() -> void:
	if _special_event_visuals == null:
		return
	_clear_nodes(_special_event_visuals)
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell == null or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
				HexGrid.PPPBlockState.REVEALED]:
			continue
		if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT \
				and cell.map_visual_path.contains("duende_cor_"):
			continue # Gnomos do Caos somem durante Encontro Indesejado.
		var animation := grid.get_ppp_map_visual(coord)
		if animation == null:
			continue
		var marker := Node2D.new()
		marker.name = "Event_%d_%d" % [coord.x, coord.y]
		marker.position = reference_hex_position(coord)
		_special_event_visuals.add_child(marker)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = animation.create_sprite_frames()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var visual_scale := 1.0
		if cell.map_visual_path.contains("duende_cor_"):
			if _gnome_reference_height < 0.0:
				_gnome_reference_height = ORIENTATION_SCALE.gnome_reference_height()
			if _gnome_reference_height > 0.0:
				visual_scale = _gnome_reference_height / float(animation.subject_height)
		sprite.scale = Vector2.ONE * visual_scale
		# Mantém os pés na linha do hex mesmo quando o Duende 1 cresce.
		sprite.position = Vector2(0.0,
			-float(animation.canvas_size.y) * 0.5 * visual_scale)
		marker.add_child(sprite)
		if sprite.sprite_frames.has_animation(&"idle"):
			sprite.play(&"idle")


func set_map_mode(mode: HexGrid.PPPMapMode) -> void:
	grid.ppp_map_mode = mode
	_refresh_feedback()


func _clear_nodes(layer: Node2D) -> void:
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()
