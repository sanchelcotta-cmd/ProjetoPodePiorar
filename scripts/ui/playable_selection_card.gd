class_name PlayableSelectionCard
extends Button

signal chosen(card: PlayableSelectionCard)

@onready var character_visual: PlayableActorVisual = $CharacterVisual
@onready var character_name: Label = $CharacterName
@onready var slot_label: Label = $SlotLabel

var character: EntityData
var pick_number: int = 0


func _ready() -> void:
	pressed.connect(func() -> void: chosen.emit(self))
	resized.connect(_layout_contents)
	_layout_contents()
	_update_style()


func setup(data: EntityData) -> void:
	character = data
	character_name.text = data.display_name
	character_visual.bind_data(data)
	character_visual.set_visual_scale(1.50)
	_layout_contents()


func set_pick_number(number: int) -> void:
	pick_number = number
	slot_label.text = "%dª vaga" % number if number > 0 else ""
	_update_style()


func _layout_contents() -> void:
	if not is_node_ready():
		return
	character_visual.position = Vector2(size.x * 0.5, size.y - 62.0)
	character_name.position = Vector2(6.0, size.y - 53.0)
	character_name.size = Vector2(size.x - 12.0, 48.0)
	slot_label.position = Vector2(8.0, 8.0)
	slot_label.size = Vector2(size.x - 16.0, 24.0)


func _update_style() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#214455") if pick_number > 0 else Color("#1d2b3b")
	panel.border_color = Color("#5fdbf2") if pick_number > 0 else Color("#607689")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(10)
	add_theme_stylebox_override("normal", panel)
	add_theme_stylebox_override("hover", panel)
	add_theme_stylebox_override("pressed", panel)
