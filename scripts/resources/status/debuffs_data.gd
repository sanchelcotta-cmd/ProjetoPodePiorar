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
	LOSE_TURN,
	CANT_USE_CONSUMABLES
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
@export var change_tick_damage_before_applying: bool = false
@export_range(0, 999) var damage_on_move: int = 0
@export var ends_when_tick_damage_reaches_zero: bool = false
# Em efeitos como Sangramento, cada turno causa valor fixo, mas a QUANTIDADE
# de turnos vem do resultado bruto do dado, não do dano final do ataque.
# Zero mantém o comportamento dos outros efeitos: o dano inicial da fonte
# é o próprio dano por turno.
@export_range(0, 999) var fixed_damage_per_tick: int = 0
@export var duration_from_die_result: bool = false

@export_category("Contágio")
# Uma tentativa na virada de cada Rodada (Manhã, Tarde, Noite), contra o
# aliado mais próximo. Zero significa que este Debuff não é contagioso.
@export_range(0.0, 1.0, 0.01) var contagion_chance_per_round: float = 0.0
@export var contagion_result_id: StringName

@export_category("Perda de Vida máxima por Dia")
# A perda só começa na virada de Dia seguinte à aplicação e é devolvida ao
# remover o Debuff. Não é dano recorrente na Vida atual.
@export_range(0, 999) var max_health_loss_per_day: int = 0

@export_category("Controle")
@export var control_effects: Array[ControlEffect] = []
# Em UNTIL_RESIST, percent é a chance base de RESISTIR no início do turno;
# se falhar, os controles listados valem naquele turno. Nos outros tipos,
# percent é a chance de o controle ocorrer (0 = sempre).
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
