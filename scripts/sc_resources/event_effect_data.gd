class_name Event_EffectData
extends Resource

enum EffectType {
# Vida / atributos
	MODIFY_HP,
	MODIFY_MAX_HP,
	MODIFY_STAT,
	# Status
	APPLY_STATUS,
	REMOVE_STATUS,
	# Habilidades
	APPLY_SKILL_EFFECT,
	GRANT_PASSIVE,
	REMOVE_PASSIVE,
	GRANT_ACTIVE_SKILL,
	REMOVE_ACTIVE_SKILL,
	# Inventário
	GRANT_ITEM,
	REMOVE_ITEM,
	GRANT_RANDOM_ITEM,
	TRANSFORM_INVENTORY,
	# Informações
	GRANT_INFORMATION,
	FORGET_LAST_INFORMATION,
	# Companheiros
	ADD_COMPANION,
	# Mundo
	START_COMBAT,
	REVEAL_BLOCKS,
	TELEPORT_ENTITY,
	CHANGE_MAP,
	CHANGE_DISTRICT,
	# Tempo
	ADVANCE_DAY,
	ADVANCE_ROUND,
	CHANGE_TIME_OF_DAY,
	# Estado global
	REMOVE_CURSES,
	APPLY_CATASTROPHE,
	SWAP_BODIES,
	CUSTOM,
	#add
	

}

enum Target {
	ACTIVE_ENTITY,
	SELECTED_ENTITY,
	RANDOM_PLAYER,
	GROUP,
	MAP,
	BLOCK,
	NONE
}

enum SelectionMode {
	FIXED,
	PLAYER_CHOOSES_FROM_CATALOG,
	RANDOM_FROM_CATALOG
}

enum MathOperation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	SET
}

enum Statistic {
	NONE,
	HP,
	MAX_HP,
	ATTACK,
	STAMINA
}

enum DurationUnit {
	TURN,
	ROUND,
	DAY,
	PERMANENT
}

@export_category("Efeito")
@export var effect_type: EffectType
@export var target: Target = Target.ACTIVE_ENTITY

@export_category("Seleção")
@export var selection_mode: SelectionMode = SelectionMode.FIXED
@export var tags_filter: Array[StringName] = []
	
@export_category("Referências")
@export var effect: SkillEffectData
@export var item_filter: Array[StringName] = []
@export var entity_filter: Array[StringName] = []
@export var passive: PassiveSkillData
@export var active_skill: ActiveSkillData
@export var debuff: DebuffData

@export var statistic: Statistic = Statistic.NONE

@export_category("Valores")
@export var amount: int = 0
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
@export var dice_count: int = 0
@export var dice_sides: int = 0
@export var math_operation = MathOperation.SET

@export var has_duration := false
@export_range(0,999) var duration_amount: int = 0
@export var duration_unit: DurationUnit = DurationUnit.TURN

@export_category("Especial")
@export var custom_rule: StringName
