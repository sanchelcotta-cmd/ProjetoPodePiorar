class_name EventOutcomeData
extends Resource

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var narrative_description: String

@export_category("Sorteio")
@export_range(0,999) var weight: int = 1

@export_category("Efeitos")
@export var effects: Array[Event_EffectData] = []
