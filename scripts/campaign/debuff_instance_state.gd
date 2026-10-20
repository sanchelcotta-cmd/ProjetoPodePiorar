class_name DebuffInstanceState
extends RefCounted

## Uma aplicação de Debuff DURANTE a partida. O .tres descreve a regra;
## duração, causador e dano atual pertencem só a esta instância.

var data: DebuffData
var source: EntityState
var source_instance_id: StringName = &""
var source_key: StringName = &""
var resistance_chance_base: float = 0.0
var duration_kind: int = DebuffData.DurationType.TURNS
var remaining_turns: int = 0
var remaining_days: int = 0
var expiration_round_index: int = -1
var applied_turn_serial: int = 0
var applied_day: int = 0
var current_tick_damage: int = 0
var applied_max_health_delta: int = 0
var applied_attack_delta: int = 0
var applied_stamina_delta: int = 0
var accrued_max_health_loss: int = 0
var active_controls: Array[int] = []
var last_turn_start_serial: int = -1
var last_turn_end_serial: int = -1
var last_day_start: int = -1


func _init(debuff: DebuffData = null, inflictor: EntityState = null) -> void:
	data = debuff
	source = inflictor
	if inflictor != null:
		source_instance_id = inflictor.instance_id
