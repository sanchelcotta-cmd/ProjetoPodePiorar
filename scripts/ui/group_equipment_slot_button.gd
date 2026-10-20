class_name GroupEquipmentSlotButton
extends Button

var owner_panel: GroupInventoryPanel
var owner_actor: EntityState
var equipment_slot: ItemData.EquipmentSlot


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and owner_panel != null and owner_actor != null \
		and data.get("panel") == owner_panel \
		and owner_panel.can_drop_equipment_entry(data.get("actor") as EntityState,
			owner_actor, data.get("entry") as InventoryItemState, equipment_slot)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(_at_position, data):
		owner_panel.drop_equipment_entry(data.get("actor") as EntityState,
			owner_actor, data.get("entry") as InventoryItemState, equipment_slot)
