class_name Event_EffectData
extends Resource

enum EffectType {
	APPLY_SKILL_EFFECT,
	GRANT_ITEM,
	REMOVE_ITEM,
	GRANT_RANDOM_ITEM,
	GRANT_INFORMATION,
	FORGET_LAST_INFORMATION,
	SPAWN_ENTITY,
	START_COMBAT,
	GRANT_PASSIVE,
	GRANT_ACTIVE_SKILL,
	ADD_COMPANION,
	REMOVE_CURSES,
	REVEAL_BLOCKS,
	TELEPORT_ENTITY,
	CHANGE_MAP,
	ADVANCE_DAY,
	APPLY_CATASPTHOPHE,
	TRANSFORM_INVENTORY,
	SWAP_BODIES,
	CUSTOM	
}

enum Target {
	ACTIVE_ENTITY,
	ALL_PLAYERS,
	SELECTED_ENTITY,
	RANDOM_PLAYER,
	GROUP,
	MAP,
	NONE
}

@export_category("Efeito")
@export var effect_type: EffectType
@export var target: Target = Target.ACTIVE_ENTITY

@export_category("Referências")
@export var skill_effect: SkillEffectData
@export var item: ItemData
@export var entity: EntityData
@export var passive: PassiveSkillData
@export var active_skill: ActiveSkillData

@export_category("Valores")
@export var amount: int = 0
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
@export_range(0,999) var duration_turns: int = 0
@export var tag: StringName

@export_category("Especial")
@export var custom_rule_id: StringName
