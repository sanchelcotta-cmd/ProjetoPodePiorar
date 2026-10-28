extends Node

## Um único resolvedor para o cursor do sistema. Componentes informam apenas
## contexto (meta/captura); a textura final nunca é disputada entre cenas.
const POINTER_ATLAS := preload("res://sprites/ui/cursor_bico_pena/atlas_64.png")
const LOADING_ATLAS := preload("res://sprites/ui/cursor_bico_pena/carregando_atlas_64.png")
const CELL := 64
const POINTER_HOTSPOT := Vector2(6, 6)
const LOADING_HOTSPOT := Vector2(32, 32)
const FRAME_MS := 80
const LOADING_DELAY_MS := 150
const DRAG_THRESHOLD := 6.0
const POINTER_NAMES := ["normal", "clique_pressionado", "clique_retorno",
	"pressao_sem_movimento", "arrastar_horizontal", "arrastar_vertical",
	"bloqueado", "diagonal_nwse"]

var _textures: Dictionary = {}
var _loading_frames: Array[Texture2D] = []
var _loading_glitch: Dictionary = {}
var _loading_owner: WeakRef
var _loading_started := 0
var _drag_owner: WeakRef
var _drag_context := ""
var _held := false
var _press_started := 0
var _press_point := Vector2.ZERO
var _released := -1
var _drag_cancelled := false
var _shown := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pointer_image := POINTER_ATLAS.get_image()
	for index in POINTER_NAMES.size():
		_textures[POINTER_NAMES[index]] = _cell_texture(pointer_image, index)
	var loading_image := LOADING_ATLAS.get_image()
	for index in 12:
		_loading_frames.append(_cell_texture(loading_image, index))
	_loading_glitch[8] = _chromatic_glitch(loading_image, 8)
	_loading_glitch[9] = _chromatic_glitch(loading_image, 9)
	_textures["carregando_estatico"] = _cell_texture(loading_image, 14)
	# Controles que já usam formas nativas recebem os mesmos desenhos. O estado
	# dinâmico é aplicado a Arrow/PointingHand no processamento abaixo.
	Input.set_custom_mouse_cursor(_textures["bloqueado"], Input.CURSOR_FORBIDDEN,
		POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_textures["arrastar_horizontal"], Input.CURSOR_HSIZE,
		POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_textures["arrastar_vertical"], Input.CURSOR_VSIZE,
		POINTER_HOTSPOT)
	Input.set_custom_mouse_cursor(_textures["diagonal_nwse"], Input.CURSOR_BDIAGSIZE,
		POINTER_HOTSPOT)
	_apply("normal")


func _exit_tree() -> void:
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND,
			Input.CURSOR_FORBIDDEN, Input.CURSOR_HSIZE, Input.CURSOR_VSIZE,
			Input.CURSOR_BDIAGSIZE]:
		Input.set_custom_mouse_cursor(null, shape)


func begin_loading(owner: Object) -> void:
	if owner == null:
		return
	_loading_owner = weakref(owner)
	_loading_started = Time.get_ticks_msec()
	_released = -1
	_held = false


func end_loading(owner: Object) -> void:
	if _loading_owner != null and _loading_owner.get_ref() == owner:
		_loading_owner = null
		_apply("normal")


func capture_drag(owner: Object, context: String) -> void:
	if owner == null or context not in ["arrastar_horizontal", "arrastar_vertical",
			"diagonal_nwse"]:
		return
	_drag_owner = weakref(owner)
	_drag_context = context
	_drag_cancelled = true
	_released = -1


func release_drag(owner: Object) -> void:
	if _drag_owner != null and _drag_owner.get_ref() == owner:
		_drag_owner = null
		_drag_context = ""
		_drag_cancelled = true
		_released = -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			_press_started = Time.get_ticks_msec()
			_press_point = event.position
			_released = -1
			_drag_cancelled = _context() != "normal"
		else:
			_held = false
			if not _drag_cancelled and _context() == "normal":
				_released = Time.get_ticks_msec()
			else:
				_released = -1
	elif event is InputEventMouseMotion and _held \
			and event.position.distance_to(_press_point) >= DRAG_THRESHOLD:
		_drag_cancelled = true
		_released = -1


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _loading_owner != null and _loading_owner.get_ref() == null:
		_loading_owner = null
	if _drag_owner != null and _drag_owner.get_ref() == null:
		_drag_owner = null
		_drag_context = ""
	var context := _context()
	if context == "loading":
		if now - _loading_started < LOADING_DELAY_MS:
			_apply("normal")
			return
		if _reduce_motion():
			_apply("carregando_estatico")
			return
		var tick: int = (now - _loading_started - LOADING_DELAY_MS) / FRAME_MS
		var frame: int = tick % 12
		var loop: int = tick / 12
		var key := "carregando_%d_%d" % [loop % 3, frame]
		if _shown == key:
			return
		_shown = key
		var texture := _loading_glitch.get(frame) as Texture2D \
			if loop % 3 == 2 and frame in [8, 9] else _loading_frames[frame]
		_set_pointer(texture, LOADING_HOTSPOT)
		return
	if context != "normal":
		_released = -1
		_apply(context)
		return
	if _held and not _drag_cancelled:
		_apply("pressao_sem_movimento" if _reduce_motion() else "clique_pressionado")
		return
	if _released >= 0 and not _reduce_motion():
		if now - _press_started < 50:
			_apply("clique_pressionado")
			return
		if now - maxi(_released, _press_started + 50) < 60:
			_apply("clique_retorno")
			return
		_released = -1
	_apply("normal")


func _context() -> String:
	# A captura prevalece mesmo que o ponteiro saia da alça.
	if _drag_owner != null and _drag_owner.get_ref() != null:
		return _drag_context
	if _loading_owner != null and _loading_owner.get_ref() != null:
		return "loading"
	var hovered := get_viewport().gui_get_hovered_control()
	var node := hovered as Node
	while node is Control:
		var control := node as Control
		if control is BaseButton and (control as BaseButton).disabled:
			return "bloqueado"
		if control.has_meta("ppp_cursor_context"):
			var marked := str(control.get_meta("ppp_cursor_context"))
			if marked in ["bloqueado", "arrastar_horizontal",
					"arrastar_vertical", "diagonal_nwse"]:
				return marked
		node = node.get_parent()
	if hovered == null and get_tree().current_scene is PPPMapView:
		var map := get_tree().current_scene as PPPMapView
		if map.has_method("cursor_can_pan_at") \
				and map.call("cursor_can_pan_at", get_viewport().get_mouse_position()):
			return "arrastar_horizontal"
	return "normal"


func _apply(name: String) -> void:
	if _shown == name:
		return
	_shown = name
	var loading := name == "carregando_estatico"
	_set_pointer(_textures[name] as Texture2D,
		LOADING_HOTSPOT if loading else POINTER_HOTSPOT)


func _set_pointer(texture: Texture2D, hotspot: Vector2) -> void:
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_POINTING_HAND, hotspot)


func _reduce_motion() -> bool:
	var comfort := get_node_or_null("/root/VisualComfort")
	return comfort != null and bool(comfort.get("enabled"))


func _cell_texture(atlas: Image, index: int) -> Texture2D:
	var cell := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	cell.blit_rect(atlas, Rect2i(index * CELL, 0, CELL, CELL), Vector2i.ZERO)
	return ImageTexture.create_from_image(cell)


func _chromatic_glitch(atlas: Image, index: int) -> Texture2D:
	var source := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	source.blit_rect(atlas, Rect2i(index * CELL, 0, CELL, CELL), Vector2i.ZERO)
	var result := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in CELL:
		for x in CELL:
			if source.get_pixel(x, y).a < 0.5:
				continue
			if x > 0 and source.get_pixel(x - 1, y).a < 0.5:
				result.set_pixel(x - 1, y, Color(0.96, 0.30, 0.67, 0.75))
			if x < CELL - 1 and source.get_pixel(x + 1, y).a < 0.5:
				result.set_pixel(x + 1, y, Color(0.16, 0.80, 1.0, 0.75))
	result.blit_rect_mask(source, source, Rect2i(0, 0, CELL, CELL), Vector2i.ZERO)
	return ImageTexture.create_from_image(result)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_held = false
		_released = -1
		_drag_owner = null
		_drag_context = ""
		_drag_cancelled = true
