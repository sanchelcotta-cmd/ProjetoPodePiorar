class_name CampaignFinalCenterTransition
extends CanvasLayer

## Cena intermediária provisória. A arte/cutscene definitiva entra em Artwork.
signal continue_requested

@export var artwork: Texture2D

@onready var _screen: Control = $Screen
@onready var _artwork: TextureRect = $Screen/Content/Artwork
@onready var _continue: Button = $Screen/Content/Continue

var _was_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_artwork.texture = artwork
	_continue.pressed.connect(func() -> void: continue_requested.emit())
	_screen.hide()


func open() -> void:
	if is_open():
		return
	_was_paused = get_tree().paused
	_screen.show()
	get_tree().paused = true
	_continue.grab_focus.call_deferred()


func close() -> void:
	if not is_open():
		return
	_screen.hide()
	get_tree().paused = _was_paused


func is_open() -> bool:
	return _screen != null and _screen.visible


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		continue_requested.emit()
