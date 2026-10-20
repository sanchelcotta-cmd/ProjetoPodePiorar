class_name EncounterMemberData
extends Resource

## Uma linha da composição de um encontro: qual criatura e quantas aparecem.
## Se mínimo e máximo forem iguais, a quantidade é fixa (ex.: 1 Goblin 1).

@export_category("Criatura")
@export var entity: EntityData

@export_category("Quantidade")
@export_range(1, 99) var minimum: int = 1
@export_range(1, 99) var maximum: int = 1
