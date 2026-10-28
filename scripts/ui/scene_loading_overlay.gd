class_name SceneLoadingOverlay
extends CanvasLayer

## Indicador simples para transições fora do resumo de campanha. A barra
## representa etapas concluídas; não há porcentagem nem avanço por cronômetro.
const BAR_TEXTURE := preload("res://sprites/ui/uielementx_00003.png")

var _progress: TextureProgressBar
var _completed_steps := 0
var _total_steps := 1


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_node("/root/GameCursor").call("begin_loading", self)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.0, 0.0, 0.0, 0.56)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	var footer := CenterContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -80.0
	footer.offset_bottom = -18.0
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x = 440.0
	content.add_theme_constant_override("separation", 9)
	footer.add_child(content)
	var caption := Label.new()
	caption.text = "Carregando…"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color(0.78, 0.88, 0.92))
	content.add_child(caption)
	var track := ColorRect.new()
	track.custom_minimum_size.y = 9.0
	track.color = Color(0.06, 0.15, 0.19, 0.85)
	content.add_child(track)
	_progress = TextureProgressBar.new()
	_progress.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_progress.texture_progress = BAR_TEXTURE
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_progress)


func _exit_tree() -> void:
	var cursor := get_node_or_null("/root/GameCursor")
	if cursor != null:
		cursor.call("end_loading", self)


func set_steps(completed: int, total: int) -> void:
	if _progress == null:
		return
	_total_steps = maxi(1, total)
	_completed_steps = clampi(completed, 0, _total_steps)
	_progress.max_value = _total_steps
	_progress.value = _completed_steps


func advance_step() -> void:
	set_steps(_completed_steps + 1, _total_steps)
