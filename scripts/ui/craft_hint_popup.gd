class_name CraftHintPopup
extends PanelContainer

## Aviso discreto, sem capturar o clique que pertence ao item/hex.
var message: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.05, 0.94)
	style.border_color = Color(1.0, 0.80, 0.16, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 9)
	add_child(margin)
	message = Label.new()
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.text = "Você pode criar itens épicos\nAbra o inventário"
	message.add_theme_font_size_override("font_size", 11)
	message.add_theme_color_override("font_color", Color(1.0, 0.91, 0.55))
	margin.add_child(message)
	hide()


func show_near(point: Vector2) -> void:
	reset_size()
	var viewport := get_viewport_rect().size
	position = Vector2(clampf(point.x + 12.0, 8.0,
		maxf(8.0, viewport.x - size.x - 8.0)),
		clampf(point.y - size.y - 8.0, 52.0,
			maxf(52.0, viewport.y - size.y - 8.0)))
	show()
