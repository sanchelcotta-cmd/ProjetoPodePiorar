class_name ItemStateData
extends Resource

# Estado de uma cópia do item no inventário. O ItemData original não é alterado.
@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_category("Restrições")
@export var blocks_hp_recovery: bool = false
@export var blocks_stamina_recovery: bool = false
