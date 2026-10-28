class_name GameDialogStyle
extends RefCounted

## Confirmações usam a mesma linguagem das caixas do jogo: superfície quase
## preta, margem simples e cores semânticas da paleta ativa. O fundo do diálogo
## permanece escuro inclusive na paleta rosa/branco para preservar o contraste.
const BACKGROUND := Color("#05090C")
const TEXT := Color("#EBF2F5")
const MUTED := Color("#B8C9D0")
const BLUR_SHADER := preload("res://shaders/ui_dialog_backdrop.gdshader")


static func apply(dialog: AcceptDialog, action_role: String = "structure",
		body_width: float = 500.0, body_height: float = 72.0) -> void:
	var border := _palette_color(dialog, "structure", Color("#38D9F0"))
	var action := _palette_color(dialog, action_role, border)
	var panel := _box(BACKGROUND, border)
	panel.content_margin_left = 24.0
	panel.content_margin_right = 24.0
	panel.content_margin_top = 16.0
	panel.content_margin_bottom = 20.0
	dialog.transparent = true
	dialog.unresizable = true
	dialog.add_theme_stylebox_override("panel", panel)
	var frame := _box(BACKGROUND, border)
	frame.expand_margin_top = 36.0
	dialog.add_theme_stylebox_override("embedded_border", frame)
	dialog.add_theme_stylebox_override("embedded_unfocused_border", frame)
	dialog.add_theme_color_override("title_color", TEXT)
	dialog.add_theme_font_size_override("title_font_size", 17)
	dialog.add_theme_constant_override("title_height", 36)
	dialog.add_theme_constant_override("buttons_min_width", 170)
	dialog.add_theme_constant_override("buttons_min_height", 40)
	dialog.add_theme_constant_override("buttons_separation", 14)
	dialog.min_size = Vector2i(ceili(body_width + 48.0), ceili(body_height + 118.0))
	var label := dialog.get_label()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(body_width, body_height)
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_font_size_override("font_size", 14)
	style_button(dialog.get_ok_button(), action)
	if dialog is ConfirmationDialog:
		style_button((dialog as ConfirmationDialog).get_cancel_button(), border)
	if not dialog.has_meta("game_dialog_palette_binding"):
		dialog.set_meta("game_dialog_palette_binding", true)
		var palette := dialog.get_node_or_null("/root/UIColorManager")
		if palette != null:
			var weak_dialog: WeakRef = weakref(dialog)
			palette.palette_changed.connect(func(_palette_id: String) -> void:
				var live_dialog := weak_dialog.get_ref() as AcceptDialog
				if live_dialog != null:
					GameDialogStyle.apply(live_dialog, action_role, body_width, body_height))


static func make_backdrop(parent: Control, dialogs: Array[AcceptDialog]) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.name = "ConfirmationBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color.WHITE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var material := ShaderMaterial.new()
	material.shader = BLUR_SHADER
	backdrop.material = material
	parent.add_child(backdrop)
	backdrop.hide()
	for dialog in dialogs:
		dialog.visibility_changed.connect(func() -> void:
			var any_open := false
			for candidate in dialogs:
				if is_instance_valid(candidate) and candidate.visible:
					any_open = true
					break
			backdrop.visible = any_open
			if any_open:
				backdrop.move_to_front())
	return backdrop


static func make_layer_backdrop(owner: Node, dialogs: Array[AcceptDialog]) -> ColorRect:
	# HUDs vivem em CanvasLayers diferentes. Esta camada fica acima deles,
	# abaixo da tela de pausa (120), e é descartada junto com a cena dona.
	var layer_node := CanvasLayer.new()
	layer_node.name = "DialogBackdropLayer"
	layer_node.layer = 110
	layer_node.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.get_tree().root.add_child(layer_node)
	owner.tree_exited.connect(func() -> void:
		if is_instance_valid(layer_node):
			layer_node.queue_free())
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A raiz da camada não deve capturar cliques quando o backdrop está oculto.
	# O ColorRect visível continua bloqueando o mapa durante confirmações.
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_node.add_child(root)
	return make_backdrop(root, dialogs)


static func _palette_color(dialog: AcceptDialog, role: String, fallback: Color) -> Color:
	var palette := dialog.get_node_or_null("/root/UIColorManager")
	return palette.color(role) if palette != null else fallback


static func _box(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


static func style_button(button: Button, border: Color) -> void:
	button.custom_minimum_size.y = 40.0
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_focus_color", TEXT)
	var normal := _box(Color("#091820"), border)
	normal.content_margin_left = 15.0
	normal.content_margin_right = 15.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#102630")
	hover.border_color = border.lightened(0.16)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#17323B")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", _box(Color.TRANSPARENT, border))
