class_name DebuffData
extends Resource

enum DurationType {
	TURNS,
	ROUNDS,
	DAYS,
	PERMANENT,
	UNTIL_CURE
}

enum MovementControl {
	NONE,
	CANT_MOVE,
	MOVE_FORWARD,
	MOVE_AWAY
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
@export var health_modifier: int = 0
@export var attack_modifier: int = 0
@export var stamina_modifier: int = 0
@export var consumable_modifier: int = 0

@export_category("Controle de movimento")
@export var movement_control: MovementControl = MovementControl.NONE
