class_name ActiveSkillData
extends Resource

enum UseContext {
	COMBAT,
	EXPLORATION,
	BOTH
}

enum TargetMode {
	NONE,
	SELF,
	ONE_ALLY,
	ONE_ENEMY,
	ONE_ENTITY,
	TILE,
	AREA
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Uso")
@export var use_context: UseContext = UseContext.COMBAT
@export var target_mode: TargetMode = TargetMode.NONE
@export_range(-1, 999) var range_limit: int = -1
@export var ends_turn: bool = false

@export_category("Limites")
@export_range(0, 99) var cooldown_turns: int = 0
@export_range(0, 99) var max_uses_per_turn: int = 0
@export_range(0, 99) var max_uses_per_round: int = 0
@export_range(0, 99) var max_uses_per_day: int = 0

@export_category("Efeitos")
@export var effects: Array[SkillEffectData] = []
