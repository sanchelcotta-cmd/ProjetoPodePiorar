class_name DebuffData
extends Resource

enum DurationType {
	TURNS,
	DAYS,
	PERMANENT,
	UNTIL_CURE,
	UNTIL_RESIST
}

enum TickMoment {
	NONE,
	ON_TURN_START,
	ON_TURN_END,
	ON_DAY_START
}

enum ControlEffect {
	CANT_MOVE,
	TOWARD_SOURCE,
	AWAY_FROM_SOURCE,
	CANT_ATTACK,
	LOSE_TURN
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Duração")
@export var duration_type: DurationType = DurationType.TURNS
@export_range(0, 999) var duration_amount: int = 0

@export_category("Modificadores")
@export_range(-999, 0) var max_health_modifier: int = 0
@export_range(-999, 0) var attack_modifier: int = 0
@export_range(-999, 0) var stamina_modifier: int = 0
@export_range(-999, 0) var consumable_modifier: int = 0

@export_category("Dano recorrente")
@export var tick_moment: TickMoment = TickMoment.NONE
@export_range(-999, 999) var damage_change_per_tick: int = 0
@export_range(0, 999) var damage_on_move: int = 0

@export_category("Controle")
@export var control_effects: Array[ControlEffect] = []
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
