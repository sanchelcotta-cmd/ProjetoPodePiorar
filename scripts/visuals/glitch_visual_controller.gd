class_name GlitchVisualController
extends Node

## Evento 50: pós-processamento do mundo separado da UI. O pixelate do
## cenário recebe pixelização mais forte que as entidades; Palette/CRT do
## mundo incluem todos os sprites.
## A UI recebe CRT por elemento, exceto botões, que viram terminal.

const WORLD_SHADER := preload("res://shaders/glitch_world.gdshader")
const UI_SHADER := preload("res://shaders/glitch_ui_crt.gdshader")
const PIXEL_SHADER := preload("res://shaders/glitch_scene_pixelate.gdshader")
const ACTOR_PIXEL_SHADER := preload("res://shaders/glitch_actor_pixelate.gdshader")
const TERMINAL_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const TERMINAL_GREEN := Color(0.45, 1.0, 0.60)
const TERMINAL_WHITE := Color(0.94, 1.0, 0.94)

var active := false
var _turns_until_clear := 0
var _world_layer: CanvasLayer
var _world_rect: ColorRect
var _world_material: ShaderMaterial
var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _flash_material: ShaderMaterial
var _terminal_layer: CanvasLayer
var _terminal_banner: Panel
var _ui_material: ShaderMaterial
var _ui_text_material: ShaderMaterial
var _pixel_material: ShaderMaterial
var _sky_pixel_material: ShaderMaterial
var _actor_pixel_material: ShaderMaterial
var _original_scene_materials: Dictionary = {}
var _original_ui_materials: Dictionary = {}
var _original_buttons: Dictionary = {}
var _next_distortion := 0.0
var _distortion_remaining := 0.0
var _next_gameboy := 0.0
var _gameboy_remaining := 0.0
var _scan_elapsed := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_world_material = ShaderMaterial.new()
	_world_material.shader = WORLD_SHADER
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = WORLD_SHADER
	_ui_material = ShaderMaterial.new()
	_ui_material.shader = UI_SHADER
	_ui_text_material = ShaderMaterial.new()
	_ui_text_material.shader = UI_SHADER
	_ui_text_material.set_shader_parameter("terminal_text", true)
	_pixel_material = ShaderMaterial.new()
	_pixel_material.shader = PIXEL_SHADER
	_pixel_material.set_shader_parameter("amount", 8.0)
	_sky_pixel_material = ShaderMaterial.new()
	_sky_pixel_material.shader = PIXEL_SHADER
	_sky_pixel_material.set_shader_parameter("amount", 4.0)
	_actor_pixel_material = ShaderMaterial.new()
	_actor_pixel_material.shader = ACTOR_PIXEL_SHADER
	_actor_pixel_material.set_shader_parameter("amount", 2.0)
	_world_layer = CanvasLayer.new()
	_world_layer.layer = 5 # Depois do mapa, antes de toda a UI.
	add_child(_world_layer)
	_world_rect = _screen_rect(_world_material)
	_world_layer.add_child(_world_rect)
	_world_layer.hide()
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 100 # Piscar Gameboy aplica-se a tudo, inclusive UI.
	add_child(_flash_layer)
	_flash_rect = _screen_rect(_flash_material)
	_flash_layer.add_child(_flash_rect)
	_flash_layer.hide()
	_terminal_layer = CanvasLayer.new()
	_terminal_layer.layer = 49 # A faixa superior (51) continua acima do aviso.
	add_child(_terminal_layer)
	_terminal_banner = _create_terminal_banner()
	_terminal_layer.add_child(_terminal_banner)
	_terminal_layer.hide()
	get_viewport().size_changed.connect(_resize_rects)
	var exploration := get_parent().get_node_or_null("ExplorationManager") as ExplorationManager
	if exploration != null:
		exploration.turn_finished.connect(_on_turn_finished)
	set_process(false)


func _screen_rect(material: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color.WHITE
	rect.material = material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _create_terminal_banner() -> Panel:
	var banner := Panel.new()
	banner.name = "GlitchAtemporalBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -205.0
	banner.offset_right = 205.0
	banner.offset_top = 61.0 # Dez pixels abaixo da faixa superior (termina em 51).
	banner.offset_bottom = 123.0
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.006, 0.015, 0.010, 0.91)
	border.border_color = Color(0.34, 0.91, 0.50, 0.86)
	border.set_border_width_all(1)
	banner.add_theme_stylebox_override("panel", border)
	banner.material = _ui_material
	var signal_line := Label.new()
	signal_line.name = "SignalLine"
	signal_line.text = "───  · · ·  _ _ _  · · ·  ───"
	signal_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	signal_line.position = Vector2(12.0, 8.0)
	signal_line.size = Vector2(386.0, 16.0)
	signal_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signal_line.add_theme_color_override("font_color", TERMINAL_GREEN)
	signal_line.add_theme_font_size_override("font_size", 11)
	signal_line.material = _ui_text_material
	banner.add_child(signal_line)
	var title := Label.new()
	title.name = "Title"
	title.text = "G L I T C H   A T E M P O R A L"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(12.0, 26.0)
	title.size = Vector2(386.0, 25.0)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", TERMINAL_FONT)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", TERMINAL_WHITE)
	title.material = _ui_text_material
	banner.add_child(title)
	return banner


func _resize_rects() -> void:
	for rect in [_world_rect, _flash_rect]:
		if rect != null:
			rect.size = get_viewport().get_visible_rect().size


func start_effect() -> void:
	active = true
	_turns_until_clear = 2 # Primeiro fim é o do próprio hex que ativou.
	_next_distortion = _rng.randf_range(10.0, 40.0)
	_next_gameboy = _rng.randf_range(20.0, 55.0)
	_distortion_remaining = 0.0
	_gameboy_remaining = 0.0
	_scan_elapsed = 0.0
	_world_layer.show()
	_terminal_layer.show()
	_resize_rects()
	_set_mode(0)
	_scan_visuals()
	set_process(true)


func stop_effect() -> void:
	active = false
	_world_layer.hide()
	_flash_layer.hide()
	_terminal_layer.hide()
	for item in _original_scene_materials:
		if is_instance_valid(item):
			(item as CanvasItem).material = _original_scene_materials[item]
	_original_scene_materials.clear()
	for item in _original_ui_materials:
		if is_instance_valid(item):
			(item as CanvasItem).material = _original_ui_materials[item]
	_original_ui_materials.clear()
	for button in _original_buttons:
		if not is_instance_valid(button):
			continue
		var saved: Dictionary = _original_buttons[button]
		for key in saved:
			var name: StringName = StringName(str(key).trim_prefix("style:").trim_prefix("color:"))
			if str(key).begins_with("style:"):
				if saved[key] == null:
					(button as Button).remove_theme_stylebox_override(name)
				else:
					(button as Button).add_theme_stylebox_override(name, saved[key])
			elif saved[key] == null:
				(button as Button).remove_theme_color_override(name)
			else:
				(button as Button).add_theme_color_override(name, saved[key])
	_original_buttons.clear()
	set_process(false)


func _on_turn_finished(_actor: EntityState) -> void:
	if not active:
		return
	_turns_until_clear -= 1
	if _turns_until_clear <= 0:
		stop_effect()


func _process(delta: float) -> void:
	if not active:
		return
	_scan_elapsed += delta
	if _scan_elapsed >= 0.3:
		_scan_elapsed = 0.0
		_scan_visuals()
	if _gameboy_remaining > 0.0:
		_gameboy_remaining -= delta
		if _gameboy_remaining <= 0.0:
			_flash_layer.hide()
			_set_mode(1 if _distortion_remaining > 0.0 else 0)
	else:
		_next_gameboy -= delta
		if _next_gameboy <= 0.0:
			_next_gameboy = _rng.randf_range(20.0, 55.0)
			_gameboy_remaining = 0.5
			_show_gameboy(_rng.randi_range(0, 2))
	if _distortion_remaining > 0.0:
		_distortion_remaining -= delta
		if _distortion_remaining <= 0.0 and _gameboy_remaining <= 0.0:
			_set_mode(0)
	else:
		_next_distortion -= delta
		if _next_distortion <= 0.0:
			_next_distortion = _rng.randf_range(10.0, 40.0)
			_distortion_remaining = _rng.randf_range(1.0, 2.0)
			if _gameboy_remaining <= 0.0:
				_set_mode(1)


## QA e capturas: força os três estados sem esperar temporizadores.
func show_preview_mode(mode: int) -> void:
	if not active:
		start_effect()
	if mode == 2:
		_set_mode(0)
		_show_gameboy(0)
	else:
		_flash_layer.hide()
		_gameboy_remaining = 0.0
		_set_mode(clampi(mode, 0, 1))


func _set_mode(mode: int) -> void:
	_world_material.set_shader_parameter("mode", mode)
	_world_material.set_shader_parameter("distortion_strength", 1.0 if mode == 1 else 0.0)
	_ui_material.set_shader_parameter("aberration", 0.006 if mode == 1 else 0.001)
	_ui_material.set_shader_parameter("scan_line_fac", 2.1 if mode == 1 else 1.2)
	_ui_text_material.set_shader_parameter("aberration", 0.006 if mode == 1 else 0.001)
	_ui_text_material.set_shader_parameter("scan_line_fac", 2.1 if mode == 1 else 1.2)


func _show_gameboy(color_index: int) -> void:
	var lights := [Color("b6e75a"), Color("ff9ad5"), Color("7be5ed")]
	var darks := [Color("102816"), Color("2c1026"), Color("092c35")]
	_flash_material.set_shader_parameter("mode", 2)
	_flash_material.set_shader_parameter("gameboy_light", lights[color_index])
	_flash_material.set_shader_parameter("gameboy_dark", darks[color_index])
	_flash_material.set_shader_parameter("distortion_strength", 0.0)
	_flash_layer.show()


func _scan_visuals() -> void:
	var scene := get_parent()
	var map_root := scene.get_node_or_null("MapRoot")
	var sky := scene.get_node_or_null("ParallaxBackground")
	if map_root != null:
		_pixelate_tree(map_root, _pixel_material)
		var actors := map_root.get_node_or_null("DepthSorted")
		if actors != null:
			for group_name in ["PlayableActors", "CompanionActors", "EnemyActors"]:
				var group := actors.get_node_or_null(group_name)
				if group != null:
					_pixelate_actor_tree(group)
	if sky != null:
		_pixelate_tree(sky, _sky_pixel_material)
	for child in scene.get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer >= 10 \
				and child != _flash_layer:
			_style_ui_tree(child, false)


func _pixelate_tree(node: Node, pixel_material: ShaderMaterial) -> void:
	if node.name == "DepthSorted":
		return # Entidades recebem um passe próprio, menos intenso.
	if node is Sprite2D or node is TextureRect:
		var item := node as CanvasItem
		if not _original_scene_materials.has(item):
			_original_scene_materials[item] = item.material
			item.material = pixel_material
	for child in node.get_children():
		_pixelate_tree(child, pixel_material)


func _pixelate_actor_tree(node: Node) -> void:
	if node is Sprite2D or node is AnimatedSprite2D:
		var item := node as CanvasItem
		if not _original_scene_materials.has(item):
			_original_scene_materials[item] = item.material
			item.material = _actor_pixel_material
	for child in node.get_children():
		_pixelate_actor_tree(child)


func _style_ui_tree(node: Node, inside_button: bool) -> void:
	if node is Button:
		_style_button(node as Button)
		inside_button = true
	elif not inside_button and (node is Label or node is RichTextLabel \
			or node is TextureRect or node is Panel or node is PanelContainer \
			or node is ColorRect or node is NinePatchRect):
		var item := node as CanvasItem
		if not _original_ui_materials.has(item):
			_original_ui_materials[item] = item.material
			item.material = _ui_text_material if node is Label or node is RichTextLabel else _ui_material
	for child in node.get_children():
		_style_ui_tree(child, inside_button)


func _style_button(button: Button) -> void:
	if _original_buttons.has(button):
		return
	var saved := {}
	for name in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		saved["style:%s" % name] = button.get_theme_stylebox(name) \
			if button.has_theme_stylebox_override(name) else null
		var border := TERMINAL_GREEN if name != &"disabled" else Color(0.28, 0.39, 0.31)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.01, 0.015, 0.012, 1.0)
		style.border_color = border
		style.set_border_width_all(2 if name == &"focus" else 1)
		style.set_content_margin_all(8.0)
		button.add_theme_stylebox_override(name, style)
	for name in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_disabled_color", &"font_focus_color"]:
		saved["color:%s" % name] = button.get_theme_color(name) \
			if button.has_theme_color_override(name) else null
		button.add_theme_color_override(name, TERMINAL_GREEN \
			if name != &"font_disabled_color" else Color(0.46, 0.53, 0.48))
	_original_buttons[button] = saved
