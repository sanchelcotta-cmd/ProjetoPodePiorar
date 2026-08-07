class_name EventOutcomeData
extends Resource

## Um possível resultado de um EventData, vários outcomes dentro do mesmo evento formam a tabela de sorteio ou as opções selecionáveis.
@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var narrative_description: String

@export_category("Elegibilidade")
@export var condition: EventConditionData

@export_category("Sorteio")
@export_range(0,999) var weight: int = 1
@export var roll_per_target: bool = false

@export_category("Efeitos")
@export var effects: Array[Event_EffectData] = []
