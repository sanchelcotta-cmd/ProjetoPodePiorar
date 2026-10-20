class_name HexTitlePopup
extends PanelContainer

## Mostra o título e a classificação de um hex consultado, sem entregar
## descrição nem efeitos. Fecha ao clicar fora ou após 8 s.
const FONT := preload("res://fonts/UbuntuSans-Regular.ttf")
const PINK := Color(0.996, 0.169, 0.592)

var _title: Label
var _classification: Label
var _effect_description: Label
var _timeout: Timer
var _layout_request := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.06, 0.08, 0.88)
	style.border_color = PINK
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	var eye := Label.new()
	eye.text = "◎"
	eye.add_theme_font_override("font", FONT)
	eye.add_theme_font_size_override("font_size", 20)
	eye.add_theme_color_override("font_color", Color(0.30, 0.87, 1.0))
	row.add_child(eye)
	var text_stack := VBoxContainer.new()
	text_stack.add_theme_constant_override("separation", 2)
	row.add_child(text_stack)
	_title = Label.new()
	_title.name = "Title"
	_title.custom_minimum_size.x = 160
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_override("font", FONT)
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Color.WHITE)
	text_stack.add_child(_title)
	_classification = Label.new()
	_classification.name = "Classification"
	_classification.add_theme_font_override("font", FONT)
	_classification.add_theme_font_size_override("font_size", 11)
	_classification.add_theme_color_override("font_color", Color(0.72, 0.80, 0.85))
	text_stack.add_child(_classification)
	_effect_description = Label.new()
	_effect_description.name = "EffectDescription"
	_effect_description.custom_minimum_size.x = 230.0
	_effect_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_description.add_theme_font_override("font", FONT)
	_effect_description.add_theme_font_size_override("font_size", 12)
	_effect_description.add_theme_color_override("font_color", Color(0.91, 0.94, 0.97))
	text_stack.add_child(_effect_description)
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.timeout.connect(hide)
	add_child(_timeout)
	hide()


func show_title(value: String, classification: String, anchor: Vector2,
		temporary: bool, effect_description: String = "") -> void:
	_title.text = value if not value.is_empty() else "Bloco desconhecido"
	_classification.text = classification
	_effect_description.text = effect_description
	_effect_description.visible = not effect_description.is_empty()
	var style := get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color(1.0, 0.19, 0.22) if temporary else PINK
	_layout_request += 1
	var request := _layout_request
	modulate.a = 0.0
	show()
	get_tree().create_timer(0.035).timeout.connect(
		_finish_show_title.bind(request, anchor), CONNECT_ONE_SHOT)
	_timeout.start(8.0)


func _finish_show_title(request: int, anchor: Vector2) -> void:
	if request != _layout_request or not visible:
		return
	reset_size()
	var screen := get_viewport_rect().size
	position = Vector2(clampf(anchor.x + 14.0, 8.0, maxf(8.0, screen.x - size.x - 8.0)),
		clampf(anchor.y - size.y * 0.5, 56.0, maxf(56.0, screen.y - size.y - 8.0)))
	modulate.a = 1.0


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not get_global_rect().has_point(event.position):
		hide()
