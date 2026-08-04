class_name PassiveSkillData
extends Resource

enum Trigger {
		# Combate
	ON_COMBAT_START,
	ON_TURN_START,
	ON_TURN_END,
		# Movimento
	ON_BEFORE_MOVE,
	ON_AFTER_MOVE,
		# Ataque
	ON_BEFORE_ATTACK,
	ON_AFTER_ATTACK,
		# Dano
	ON_AFTER_DAMAGE_DEALT,
	ON_BEFORE_DAMAGE_RECEIVED,
	ON_AFTER_DAMAGE_RECEIVED,
	ON_BEFORE_ALLY_DAMAGE_RECEIVED,
	ON_AFTER_ALLY_DAMAGE_RECEIVED,
		# Mortes
	ON_SELF_DEATH,
	ON_ALLY_DEATH,
	ON_ENEMY_DEATH,
		# Exploração
	ON_ROUND_START,
	ON_INFORMATION_OBTAINED,
	ON_BLOCK_REVEALED,
	ON_ITEM_CONSUMED,
		# Status
	ON_STATUS_APPLIED
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Ativação")
@export var trigger: Trigger = Trigger.ON_AFTER_DAMAGE_DEALT
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99) var cooldown_turns: int = 0
@export_range(0, 99) var max_activations_per_turn: int = 0

@export_category("Efeitos")
@export var effects: Array[SkillEffectData] = []
