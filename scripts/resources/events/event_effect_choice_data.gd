class_name EventEffectChoiceData
extends Resource

## Uma opção dentro de um resultado: o jogador escolhe uma, e só seus efeitos ocorrem.
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effects: Array[Event_EffectData] = []
