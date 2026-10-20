class_name NeonNextPhaseButton
extends Button

## Botão da próxima fase: verde com brilho neon e leve degradê metálico.
## A regra de QUANDO aparece pertence ao RoundManager, não à aparência.

var _glow: Panel


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal", _gradient_style(false))
	add_theme_stylebox_override("hover", _gradient_style(true))
	add_theme_stylebox_override("pressed", _gradient_style(false))
	add_theme_stylebox_override("disabled", _disabled_style())
	add_theme_color_override("font_color", Color(0.96, 1.0, 0.95))
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_disabled_color", Color(0.72, 0.74, 0.76))
	add_theme_font_size_override("font_size", 14)
	_glow = Panel.new()
	_glow.name = "NeonEdge"
	_glow.show_behind_parent = true
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.offset_left = -2.0
	_glow.offset_top = -2.0
	_glow.offset_right = 2.0
	_glow.offset_bottom = 2.0
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color(0.03, 0.2, 0.095, 0.95)
	edge.border_color = Color(0.18, 1.0, 0.42)
	edge.set_border_width_all(2)
	edge.set_corner_radius_all(5)
	edge.shadow_color = Color(0.05, 0.95, 0.32, 0.48)
	edge.shadow_size = 9
	_glow.add_theme_stylebox_override("panel", edge)
	add_child(_glow)
	_sync_glow()


func _process(_delta: float) -> void:
	_sync_glow()


func _gradient_style(bright: bool) -> StyleBoxTexture:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.17, 0.49, 0.26) if not bright else Color(0.22, 0.67, 0.35))
	gradient.set_color(1, Color(0.035, 0.21, 0.105) if not bright else Color(0.05, 0.34, 0.16))
	gradient.add_point(0.29, Color(0.26, 0.72, 0.38) if not bright else Color(0.38, 0.91, 0.5))
	gradient.add_point(0.46, Color(0.13, 0.49, 0.25) if not bright else Color(0.2, 0.66, 0.33))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 2
	texture.height = 64
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.set_content_margin_all(10.0)
	return style


func _disabled_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.20, 0.22, 0.8)
	style.border_color = Color(0.42, 0.45, 0.48)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10.0)
	return style


func _sync_glow() -> void:
	if _glow != null:
		# Só o botão disponível recebe o brilho verde de convite ao clique.
		_glow.visible = not disabled
