class_name CampaignDayTransition
extends CanvasLayer

## Cena intermediária da virada Noite → novo Dia. Cobre o jogo inteiro,
## inclusive HUDs e modais, sem trocar ou regenerar o mapa já preparado.
signal save_requested
signal continue_requested

@export var artwork: Texture2D

@onready var _screen: Control = $Screen
@onready var _day_label: Label = $Screen/Title/Day
@onready var _artwork: TextureRect = $Screen/ImageCenter/Artwork
@onready var _save: Button = $Screen/Actions/Save
@onready var _continue: Button = $Screen/Actions/Continue

var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_artwork.texture = artwork
	_style_button(_save, Color(0.31, 0.91, 0.55), true)
	_style_button(_continue, Color(0.28, 0.82, 0.94), false)
	_save.pressed.connect(func() -> void: save_requested.emit())
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	_screen.hide()


func open(day: int) -> void:
	if is_open():
		return
	_day_label.text = "DIA %d" % day
	_artwork.texture = artwork
	_was_paused = get_tree().paused
	_screen.show()
	get_tree().paused = true
	_save.grab_focus.call_deferred()


func close() -> void:
	if not is_open():
		return
	_screen.hide()
	get_tree().paused = _was_paused


func is_open() -> bool:
	return _screen != null and _screen.visible


func set_artwork(texture: Texture2D) -> void:
	artwork = texture
	if _artwork != null:
		_artwork.texture = texture


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		continue_requested.emit()


func _style_button(button: Button, accent: Color, prominent: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent.r * 0.10, accent.g * 0.10,
		accent.b * 0.10, 0.98)
	normal.border_color = accent.darkened(0.16)
	normal.set_border_width_all(2 if prominent else 1)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(accent.r * 0.21, accent.g * 0.21,
		accent.b * 0.21, 1.0)
	hover.border_color = accent.lightened(0.15)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.shadow_size = 7
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.93, 0.98, 0.99))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
