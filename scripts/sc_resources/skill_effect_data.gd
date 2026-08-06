class_name SkillEffectData
extends Resource

enum Target {
	SELF,
	ATTACK_TARGET,
	SELECTED_TARGET,
	DAMAGE_SOURCE,
	NEAREST_ALLY,
	NEAREST_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES
}

enum EffectType {
	APPLY_DEBUFF,
	REMOVE_DEBUFF,
	HEAL_FIXED,
	HEAL_PERCENT_OF_DAMAGE_DEALT,
	REDUCE_INCOMING_DAMAGE,
	ENABLE_FLYING_MOVEMENT,
	MOVE_TOWARD_TARGET,
	MOVE_AWAY_FROM_TARGET,
	REVEAL_BLOCKS,
	MODIFY_ATTRIBUTE,
	ADD_EXTRA_ATTACK,
	COUNTERATTACK,
	SUMMON_ENTITY,
	TELEPORT,
	REDIRECT_DAMAGE,
	CUSTOM_SCRIPT
}

enum ModifyMode {
	ADD,
	MULTIPLY,
	SET
}

@export_category("Efeito")
@export var effect_type: EffectType
@export var target: Target = Target.SELF

@export_category("Valores")
@export var modify_mode = ModifyMode.ADD
@export var amount: int = 0
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
@export var debuff_id: StringName
@export var attribute_id: StringName
@export_range(0, 99) var duration_turns: int = 0
