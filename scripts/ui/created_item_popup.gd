class_name CreatedItemPopup
extends Control

## Janela curta para o item criado por uma habilidade, sem duplicar o item.
const FONT := preload("res://fonts/UbuntuSans-Regular.ttf")
const BOLD := preload("res://fonts/UbuntuSans-Bold.ttf")

var _panel: PanelContainer
var _icon: TextureRect
var _name: Label
var _status: Label
var _exchange_button: Button
var _decline_button: Button
var _okay_button: Button
var _pending_owner: EntityState
var _pending_item: ItemData
var _waiting_exchange_close := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.36)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(330, 224)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.08, 0.96)
	style.border_color = Color(0.996, 0.169, 0.592)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 15)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "ITEM CRIADO"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_override("font", BOLD)
	heading.add_theme_font_size_override("font_size", 17)
	heading.add_theme_color_override("font_color", Color(0.30, 0.88, 1.0))
	column.add_child(heading)
	var icon_center := CenterContainer.new()
	column.add_child(icon_center)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(72, 72)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_center.add_child(_icon)
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_override("font", BOLD)
	_name.add_theme_font_size_override("font_size", 16)
	column.add_child(_name)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", FONT)
	_status.add_theme_font_size_override("font_size", 11)
	column.add_child(_status)
	_exchange_button = Button.new()
	_exchange_button.text = "ABRIR INVENTÁRIO PARA TROCA"
	_exchange_button.custom_minimum_size.y = 30
	_exchange_button.pressed.connect(_open_exchange)
	column.add_child(_exchange_button)
	_decline_button = Button.new()
	_decline_button.text = "RECUSAR ITEM"
	_decline_button.custom_minimum_size.y = 30
	_decline_button.pressed.connect(_decline_created_item)
	column.add_child(_decline_button)
	_okay_button = Button.new()
	_okay_button.text = "OKAY"
	_okay_button.custom_minimum_size.y = 30
	_okay_button.pressed.connect(hide)
	column.add_child(_okay_button)
	get_viewport().size_changed.connect(_center)
	hide()


func show_item(item: ItemData, result: Dictionary) -> void:
	if item == null:
		return
	_icon.texture = item.icon
	_name.text = item.display_name
	_pending_owner = result.get("recipient") as EntityState if result.get("pending_exchange", false) else null
	_pending_item = item if result.get("pending_exchange", false) else null
	_exchange_button.visible = _pending_item != null
	_decline_button.visible = _pending_item != null
	_okay_button.visible = _pending_item == null
	_status.text = "Inventários cheios. Escolha um item para trocar." if _pending_item != null else \
		("Escolha quem vai recebê-lo" if result.get("pending_recipient", false) else "Guardado no inventário")
	show()
	_center()


func _group_inventory() -> GroupInventoryPanel:
	var top_bar := get_parent().get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	return top_bar.group_inventory if top_bar != null else null


func _open_exchange() -> void:
	var panel := _group_inventory()
	if panel == null or _pending_owner == null or _pending_item == null:
		_status.text = "Inventário do grupo indisponível."
		return
	if panel.begin_exchange(_pending_owner, _pending_item,
			_complete_exchange, _decline_created_item, true):
		_waiting_exchange_close = true
		hide()


func _complete_exchange(outgoing: Array[InventoryItemState]) -> bool:
	var hud := get_parent() as PartyStatusHUD
	if hud == null or hud.skill_manager == null or _pending_owner == null \
			or _pending_item == null or not hud.skill_manager.inventory_manager.exchange_items(
				_pending_owner, outgoing, _pending_item):
		return false
	_pending_owner = null
	_pending_item = null
	_waiting_exchange_close = false
	return true


func _decline_created_item() -> bool:
	if _pending_item == null:
		return false
	var hud := get_parent() as PartyStatusHUD
	if hud != null and hud.skill_manager != null:
		hud.skill_manager.inventory_manager.item_lost.emit(_pending_item)
	_pending_owner = null
	_pending_item = null
	_waiting_exchange_close = false
	hide()
	return true


func _process(_delta: float) -> void:
	if _waiting_exchange_close:
		var panel := _group_inventory()
		if panel != null and not panel.visible:
			_waiting_exchange_close = false
			show()
			_center()


func _center() -> void:
	if _panel != null:
		_panel.reset_size()
		_panel.position = (get_viewport_rect().size - _panel.size) * 0.5


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		if _pending_item == null:
			hide()
		get_viewport().set_input_as_handled()
