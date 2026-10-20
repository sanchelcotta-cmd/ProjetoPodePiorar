class_name SkillGrantState
extends RefCounted

## Uma concessão DURANTE a partida. Duas fontes podem conceder a mesma Skill;
## ambas continuam registradas e podem ser retiradas separadamente.

var skill: Resource
var source_kind: StringName
var source_id: StringName
var last_used_turn_serial: int = -1
var uses_in_last_turn: int = 0
var last_used_round_index: int = -1
var uses_in_last_round: int = 0
var last_used_day: int = -1
var uses_in_last_day: int = 0
# Um companheiro usa a habilidade no turno de seu dono, não ganha turno próprio.
var last_used_owner_turn_serial: int = -1
var last_used_combat_id: StringName = &""
var uses_in_last_combat: int = 0
var activated_combat_id: StringName = &""
# Quanto ESTA origem já acrescentou a cada estatística. Recalcular troca
# apenas a diferença; remover a origem desfaz somente sua contribuição.
var applied_stat_contributions: Dictionary = {}
var on_granted_applied: bool = false
var bound_source: Resource
var copied_passive_source_ids: Array[StringName] = []
var last_passive_turn_serial: int = -1
var last_passive_turn_key: StringName = &""
var passive_uses_in_turn: int = 0
var last_passive_combat_id: StringName = &""
var passive_uses_in_combat: int = 0
var last_passive_activation_turn_serial: int = -1
var last_passive_activation_combat_id: StringName = &""


func _init(
		granted_skill: Resource = null,
		granted_source_kind: StringName = &"",
		granted_source_id: StringName = &"",
) -> void:
	skill = granted_skill
	source_kind = granted_source_kind
	source_id = granted_source_id


func source_key() -> StringName:
	return StringName("%s:%s" % [source_kind, source_id])
