class_name InventoryItemState
extends RefCounted

## Uma cópia concreta no inventário. O ItemData continua sendo o catálogo;
## estados como "apodrecido" pertencem apenas a esta cópia.
var data: ItemData
var states: Array[ItemStateData] = []
## Ordem de obtenção da cópia, preservada ao transferir ou equipar.
## Ordenar visualmente o inventário nunca reescreve esta informação.
static var _next_acquisition_order := 0
var acquisition_order: int
## Posição escolhida pelo jogador na grade; -1 recebe o primeiro espaço livre.
var inventory_slot_index := -1
## Identidade da origem das habilidades do equipamento. Diferente do ID de
## objeto em memória, sobrevive ao carregamento e permite retirar seus bônus.
var equipment_source_id: StringName = &""
## Sintonização do Amuleto Divino pertence à cópia, não ao catálogo.
## Nunca é apagada ao desequipar ou transferir; só o dono recebe proteção.
var attuned_owner_instance_id: StringName = &""
var attuned_owner_name: String = ""
## Melhorias pertencem à cópia, não ao ItemData compartilhado do catálogo.
var improvement_attack := 0
var improvement_life := 0
var improvement_stamina := 0


func _init(item_data: ItemData = null) -> void:
	data = item_data
	acquisition_order = _next_acquisition_order
	_next_acquisition_order += 1
