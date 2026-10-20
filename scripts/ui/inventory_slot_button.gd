class_name InventorySlotButton
extends Button

## O painel do grupo aceita reordenação local e transferência entre jogáveis.
## O estado real continua no EntityState; o slot só envia a intenção.
var owner_panel: Control
var owner_actor: EntityState
var entry: InventoryItemState
var slot_index := -1
var can_drag := false


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag or owner_actor == null or entry == null \
			or entry not in owner_actor.inventory_items:
		return null
	var preview := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36, 36)
	icon.texture = entry.data.icon if entry.data != null else null
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.add_child(icon)
	var label := Label.new()
	label.text = entry.data.display_name if entry.data != null else "Item"
	preview.add_child(label)
	set_drag_preview(preview)
	return {"panel": owner_panel, "actor": owner_actor, "entry": entry}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (can_drag and data is Dictionary and owner_panel != null \
		and owner_actor != null \
		and data.get("panel") == owner_panel \
		and data.get("entry") is InventoryItemState):
		return false
	if owner_panel.has_method("can_drop_inventory_entry"):
		return bool(owner_panel.call("can_drop_inventory_entry", data.get("actor"),
			owner_actor, data.get("entry")))
	return data.get("actor") == owner_actor \
		and data.get("entry") in owner_actor.inventory_items


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		if owner_panel.has_method("drop_inventory_entry"):
			owner_panel.call("drop_inventory_entry", data.get("actor"), owner_actor,
				data.get("entry"), slot_index)
		else:
			owner_panel.call("reorder_inventory_entry", owner_actor,
				data.get("entry"), slot_index)
