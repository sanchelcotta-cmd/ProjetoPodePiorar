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
	ON_STATUS_APPLIED,
		# Equipamento
	ON_EQUIPPED,
	# Antes da iniciativa. Útil para efeitos que pertencem ao Encontro,
	# mas precisam acontecer antes do combate começar de verdade.
	ON_ENCOUNTER_START,
	ON_ITEM_ACQUIRED,
	ON_DAY_START,
	# Depois do movimento de Exploração e antes de ativar o bloco de destino.
	ON_EXPLORATION_DESTINATION_REACHED
}

# Impede que uma passiva de combate dispare fora dele, mantendo ANY como padrão antigo.
enum ActivationContext {
	ANY,
	COMBAT,
	EXPLORATION
}

enum IncomingAttackType {
	ANY,
	MELEE,
	RANGED
}

enum ConditionCombination {
	ALL,
	ANY
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Ativação")
@export var trigger: Trigger = Trigger.ON_AFTER_DAMAGE_DEALT
@export var additional_triggers: Array[Trigger] = []
@export var activation_context: ActivationContext = ActivationContext.ANY
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99) var cooldown_turns: int = 0
@export_range(0, 99) var max_activations_per_turn: int = 0
@export_range(0, 99) var max_activations_per_combat: int = 0
# Passivas do mesmo grupo disputam uma única escolha; peso 1 + 1 = 50% para cada.
@export var random_choice_group: StringName
@export_range(1, 99) var random_choice_weight: int = 1

@export_category("Agenda")
# Zero significa que a passiva não depende do número do turno.
@export_range(0, 99) var first_activation_turn: int = 0
# Zero significa que não há repetição programada.
@export_range(0, 99) var repeat_every_turns: int = 0

@export_category("Condições")
@export var condition_combination: ConditionCombination = ConditionCombination.ALL
# Zero desliga a condição; qualquer outro valor exige esta quantidade de inimigos nos hexágonos adjacentes.
@export_range(0, 6) var minimum_adjacent_enemies: int = 0
# Zero desliga o teto; qualquer outro valor exige no máximo esta quantidade de inimigos adjacentes.
@export_range(0, 6) var maximum_adjacent_enemies: int = 0
@export var incoming_attack_type: IncomingAttackType = IncomingAttackType.ANY
# Para ataques realizados pelo portador. Inclui corpo a corpo desarmado.
@export var requires_melee_attack: bool = false
@export var damage_source_must_be_adjacent: bool = false
@export var required_target_debuff_id: StringName
# -1 desliga estes limites. Eles contam as Informações do grupo inteiro.
@export_range(-1, 999) var minimum_group_information_count: int = -1
@export_range(-1, 999) var maximum_group_information_count: int = -1
@export var required_information_ids: Array[StringName] = []
@export_range(0, 99) var minimum_matching_information: int = 0
@export_range(0, 99) var maximum_matching_information: int = 0
@export var requires_player_confirmation: bool = false
# Basta uma das tags estar presente, a menos que match_all seja marcado.
@export var required_opposing_companion_tags: Array[StringName] = []
@export var opposing_companion_match_all: bool = false
# Filtra o item/arma que originou o dano recebido.
@export var required_damage_source_item_ids: Array[StringName] = []
# Filtra a arma usada pelo portador no ataque que está começando.
@export var required_attack_item_id: StringName
# Em ON_AFTER_ATTACK, não dispara em um ataque que errou ou causou zero dano.
@export var requires_attack_to_deal_damage: bool = false
# Uma criatura do mesmo EntityData já enfrentada ao menos N vezes antes deste encontro.
@export_range(0, 999) var minimum_previous_encounters_same_entity_data: int = 0
# O bloco de Encontro que contém o alvo foi revelado por esta habilidade.
@export var target_revealed_by_skill_id: StringName
# Para ON_AFTER_ALLY_DAMAGE_RECEIVED: zero não limita a distância.
@export_range(0, 99) var max_distance_to_damaged_ally: int = 0
@export var include_companions_in_ally_damage_trigger: bool = false

@export_category("Efeitos")
@export var effects: Array[SkillEffectData] = []
# Narração exibida depois de preparar o Combate quando um END_COMBAT pede
# confirmação do jogador. Vazio mantém o encerramento sem uma fala especial.
@export_multiline var completion_narrative: String
# Executados uma vez quando esta passiva é concedida à instância do personagem.
# O estado resultante deve ser salvo; recarregar o jogo não executa de novo.
@export var on_granted_effects: Array[SkillEffectData] = []
# Aplicados enquanto a passiva existir; não esperam pelo gatilho acima.
@export var continuous_effects: Array[SkillEffectData] = []

@export_category("Tags")
@export var tags: Array[StringName] = []
