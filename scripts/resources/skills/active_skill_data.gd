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
	AREA,
	ITEM
}

# Define de onde vem o alcance. FIXED preserva o comportamento dos Resources antigos.
enum RangeMode {
	FIXED,
	CURRENT_STAMINA,
	CURRENT_STAMINA_PLUS_AMOUNT,
	HALF_CURRENT_STAMINA
}

enum AutomaticTrigger {
	ON_COMBAT_START,
	ON_TURN_START,
	ON_COMBAT_TURN_START,
	ON_ATTACK_SELECTION,
	ON_ALLY_DEATH
}

enum TargetPriority {
	DEFAULT,
	NEAREST,
	SECOND_NEAREST,
	THIRD_NEAREST,
	LOWEST_HEALTH,
	HAS_DEBUFF,
	RANDOM
}

# O limite pode vir de um contador persistente, sem gastar esse contador.
enum UsageAllowanceSource {
	FIXED,
	MAP_INFORMATION_BLOCKS_ACTIVATED
}

enum UsageResetMoment {
	NEVER,
	DAY_START
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Uso")
@export var use_context: UseContext = UseContext.COMBAT
@export var target_mode: TargetMode = TargetMode.NONE
# Em FIXED, este é o alcance. Em CURRENT_STAMINA_PLUS_AMOUNT, é o bônus somado à Estamina.
@export_range(-1, 999) var range_limit: int = -1
@export var range_mode: RangeMode = RangeMode.FIXED
@export var ends_turn: bool = false
@export var allow_dead_targets: bool = false
## Ativas de companheiros que o dono pode comandar na Exploração mesmo fora
## do turno dele; não gastam nem encerram o turno de outro personagem.
@export var usable_while_owner_inactive: bool = false
@export var requires_player_confirmation: bool = false
# Remove do personagem esta Skill após um uso que produza seu efeito com sucesso.
@export var consume_skill_on_success: bool = false
# Exige um Encontro Indesejado em andamento, não qualquer combate.
@export var requires_undesired_encounter: bool = false

@export_category("Ativação automática")
# Lista vazia significa que a habilidade é escolhida manualmente.
@export var automatic_triggers: Array[AutomaticTrigger] = []
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99) var first_activation_turn: int = 0
@export_range(0, 99) var repeat_every_turns: int = 0
@export var activate_only_once: bool = false
## Para ações coletivas de um Encontro: uma execução compartilhada entre
## todas as instâncias com esta mesma Skill, não uma execução por membro.
@export var activate_once_per_encounter: bool = false
@export_range(0, 99) var minimum_owner_survived_combat_turns: int = 0
# Habilidades com o mesmo grupo participam do mesmo sorteio.
@export var random_choice_group: StringName
@export_range(1, 99) var random_choice_weight: int = 1

@export_category("Seleção automática de alvo")
@export var target_priority: TargetPriority = TargetPriority.DEFAULT
@export var required_target_debuff_id: StringName
@export var avoid_previous_target: bool = false
@export var mastery_override: EntityData.Mastery = EntityData.Mastery.NONE

@export_category("Limites")
@export_range(0, 99) var cooldown_turns: int = 0
@export_range(0, 99) var max_uses_per_turn: int = 0
@export_range(0, 99) var max_uses_per_round: int = 0
# Com uma fonte dinâmica, este valor é o teto diário: usa o menor entre
# o limite acumulado da fonte e este teto. Zero continua significando sem teto.
@export_range(0, 99) var max_uses_per_day: int = 0
@export_range(0, 99) var max_uses_per_combat: int = 0
@export var usage_allowance_source: UsageAllowanceSource = UsageAllowanceSource.FIXED
# Cada unidade acumulada na fonte concede esta quantidade de usos por período.
@export_range(1, 99) var uses_per_source_unit: int = 1
@export var usage_reset_moment: UsageResetMoment = UsageResetMoment.NEVER

@export_category("Efeitos")
@export var effects: Array[SkillEffectData] = []
# Aplicados somente quando um movimento EXTRA concedido por esta Ativa
# realmente acontecer. Ativar a Skill e desistir de andar não aplica custo.
@export var on_extra_movement_used_effects: Array[SkillEffectData] = []

@export_category("Tags")
@export var tags: Array[StringName] = []

# Texto opcional do botão quando a Ativa aparece entre as escolhas de uma
# consequência (por exemplo, cancelar o Evento antes que ele seja ativado).
@export var consequence_button_label: String = ""
