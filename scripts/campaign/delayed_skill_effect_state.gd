class_name DelayedSkillEffectState
extends RefCounted

## Efeito que aguarda turnos do dono, como o retorno do Doguinho.
var skill_owner: EntityState
var turn_owner_id: StringName
var effect: SkillEffectData
var due_owner_turn_serial: int


func _init(
		new_skill_owner: EntityState = null,
		new_turn_owner_id: StringName = &"",
		new_effect: SkillEffectData = null,
		new_due_serial: int = 0,
) -> void:
	skill_owner = new_skill_owner
	turn_owner_id = new_turn_owner_id
	effect = new_effect
	due_owner_turn_serial = new_due_serial
