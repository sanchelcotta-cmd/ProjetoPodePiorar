extends Node

signal ui_scale_changed(factor: float)

## Escala tipográfica única para toda a interface, inclusive controles criados
## durante a partida. Um override posterior ainda é tratado como tamanho-base.
const FONT_FACTOR := 4.0 / 3.0
const NARRATIVE_WEIGHT_NORMAL := 0.5
const NARRATIVE_WEIGHT_SMALL := 0.3
const FONT_KEYS: Array[StringName] = [
	&"font_size", &"normal_font_size", &"bold_font_size",
	&"italics_font_size", &"bold_italics_font_size", &"mono_font_size",
]
const META_LAST_SCALED := &"_ppp_last_scaled_font_sizes"
const META_BASE_SIZES := &"_ppp_base_font_sizes"
const META_LAST_MINIMUM := &"_ppp_last_ui_minimum"
const META_BASE_MINIMUM := &"_ppp_base_ui_minimum"
const META_LAST_CONSTANTS := &"_ppp_last_ui_constants"
const META_BASE_CONSTANTS := &"_ppp_base_ui_constants"
const META_LAST_STYLES := &"_ppp_last_ui_styles"
const META_BASE_STYLES := &"_ppp_base_ui_styles"
const META_STYLE_FACTORS := &"_ppp_ui_style_factors"
const CONSTANT_KEYS: Array[StringName] = [
	&"separation", &"h_separation", &"v_separation",
	&"margin_left", &"margin_right", &"margin_top", &"margin_bottom",
]
const STYLE_KEYS: Array[StringName] = [
	&"normal", &"hover", &"pressed", &"disabled", &"focus",
	&"hover_pressed", &"panel", &"read_only",
]
const UI_CONFIG_PATH := "user://ppp_ui_scale.cfg"
var ui_factor := 1.0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(UI_CONFIG_PATH) == OK:
		var stored := float(config.get_value("interface", "scale", 1.0))
		if stored in [0.8, 1.0, 1.25, 1.5]:
			ui_factor = stored
	if ui_factor == 1.5 and not can_use_150_percent():
		ui_factor = 1.25
	_update_narrative_weight()
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)
	ThemeDB.fallback_base_scale = ui_factor


func can_use_150_percent() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var window_size := DisplayServer.window_get_size()
	return window_size.x >= 1920 and window_size.y >= 1080


func set_ui_scale(factor: float, persist: bool = true) -> bool:
	if factor not in [0.8, 1.0, 1.25, 1.5]:
		return false
	if factor == 1.5 and not can_use_150_percent():
		return false
	ui_factor = factor
	_update_narrative_weight()
	ThemeDB.fallback_base_scale = factor
	_scan(get_tree().root)
	ui_scale_changed.emit(factor)
	if not persist:
		return true
	var config := ConfigFile.new()
	config.set_value("interface", "scale", factor)
	return config.save(UI_CONFIG_PATH) == OK


func ensure_scale_fits_window() -> bool:
	if ui_factor != 1.5 or can_use_150_percent():
		return false
	set_ui_scale(1.25)
	return true


func _update_narrative_weight() -> void:
	var weight := NARRATIVE_WEIGHT_SMALL if ui_factor < 1.0 else NARRATIVE_WEIGHT_NORMAL
	UINarrativeFont.set_embolden(weight)


func _scan(node: Node) -> void:
	if node is Control:
		_watch_and_scale(node as Control)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	if node is Control:
		_watch_and_scale_ref.call_deferred(weakref(node))


func _watch_and_scale_ref(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if control != null:
		_watch_and_scale(control)


func _watch_and_scale(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	if not control.theme_changed.is_connected(_on_theme_changed.bind(control)):
		control.theme_changed.connect(_on_theme_changed.bind(control))
	if not control.minimum_size_changed.is_connected(_on_theme_changed.bind(control)):
		control.minimum_size_changed.connect(_on_theme_changed.bind(control))
	_scale(control)


func _on_theme_changed(control: Control) -> void:
	if is_instance_valid(control):
		_scale_ref.call_deferred(weakref(control))


func _scale_ref(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if control != null:
		_scale(control)


func _scale(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var last: Dictionary = control.get_meta(META_LAST_SCALED, {})
	var base_sizes: Dictionary = control.get_meta(META_BASE_SIZES, {})
	for key in FONT_KEYS:
		if not control.has_theme_font_size_override(key):
			last.erase(key)
			base_sizes.erase(key)
			continue
		var current := control.get_theme_font_size(key)
		if last.get(key, -1) != current:
			base_sizes[key] = current
		var scaled := maxi(10, roundi(float(base_sizes.get(key, current))
			* FONT_FACTOR * ui_factor))
		if scaled == current:
			continue
		last[key] = scaled
		# Marcar antes de alterar o Theme evita reescalar o próprio sinal.
		control.set_meta(META_LAST_SCALED, last)
		control.set_meta(META_BASE_SIZES, base_sizes)
		control.add_theme_font_size_override(key, scaled)
	control.set_meta(META_LAST_SCALED, last)
	control.set_meta(META_BASE_SIZES, base_sizes)
	var current_minimum := control.custom_minimum_size
	var last_minimum: Vector2 = control.get_meta(META_LAST_MINIMUM, Vector2(-1, -1))
	if current_minimum != last_minimum:
		control.set_meta(META_BASE_MINIMUM, current_minimum)
	var base_minimum: Vector2 = control.get_meta(META_BASE_MINIMUM, current_minimum)
	var scaled_minimum := base_minimum * ui_factor
	control.set_meta(META_LAST_MINIMUM, scaled_minimum)
	if current_minimum != scaled_minimum:
		control.custom_minimum_size = scaled_minimum
	var last_constants: Dictionary = control.get_meta(META_LAST_CONSTANTS, {})
	var base_constants: Dictionary = control.get_meta(META_BASE_CONSTANTS, {})
	for key in CONSTANT_KEYS:
		if not control.has_theme_constant_override(key):
			last_constants.erase(key)
			base_constants.erase(key)
			continue
		var current_constant := control.get_theme_constant(key)
		if last_constants.get(key, -1) != current_constant:
			base_constants[key] = current_constant
		var scaled_constant := roundi(float(base_constants.get(key, current_constant)) * ui_factor)
		last_constants[key] = scaled_constant
		if current_constant != scaled_constant:
			control.set_meta(META_LAST_CONSTANTS, last_constants)
			control.set_meta(META_BASE_CONSTANTS, base_constants)
			control.add_theme_constant_override(key, scaled_constant)
	control.set_meta(META_LAST_CONSTANTS, last_constants)
	control.set_meta(META_BASE_CONSTANTS, base_constants)
	var last_styles: Dictionary = control.get_meta(META_LAST_STYLES, {})
	var base_styles: Dictionary = control.get_meta(META_BASE_STYLES, {})
	var style_factors: Dictionary = control.get_meta(META_STYLE_FACTORS, {})
	for key in STYLE_KEYS:
		if not control.has_theme_stylebox_override(key):
			last_styles.erase(key)
			base_styles.erase(key)
			style_factors.erase(key)
			continue
		var current_style := control.get_theme_stylebox(key)
		if last_styles.get(key) == current_style \
				and style_factors.get(key, -1.0) == ui_factor:
			continue
		if last_styles.get(key) != current_style:
			base_styles[key] = current_style.duplicate(true)
		var base_style := base_styles.get(key) as StyleBox
		if base_style == null:
			continue
		var scaled_style := base_style.duplicate(true) as StyleBox
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			scaled_style.set_content_margin(side,
				base_style.get_content_margin(side) * ui_factor)
		if scaled_style is StyleBoxFlat and base_style is StyleBoxFlat:
			var flat := scaled_style as StyleBoxFlat
			var original := base_style as StyleBoxFlat
			flat.border_width_left = roundi(original.border_width_left * ui_factor)
			flat.border_width_right = roundi(original.border_width_right * ui_factor)
			flat.border_width_top = roundi(original.border_width_top * ui_factor)
			flat.border_width_bottom = roundi(original.border_width_bottom * ui_factor)
		last_styles[key] = scaled_style
		style_factors[key] = ui_factor
		control.set_meta(META_LAST_STYLES, last_styles)
		control.set_meta(META_BASE_STYLES, base_styles)
		control.set_meta(META_STYLE_FACTORS, style_factors)
		control.add_theme_stylebox_override(key, scaled_style)
	control.set_meta(META_LAST_STYLES, last_styles)
	control.set_meta(META_BASE_STYLES, base_styles)
	control.set_meta(META_STYLE_FACTORS, style_factors)
