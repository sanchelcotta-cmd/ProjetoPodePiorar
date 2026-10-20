class_name EventData
extends Resource

enum EventCategory {
	RANDOM_EVENT,
	PERMANENT_EFFECT,
	CATASTROPHE,
	TRAP
}

enum Valence {
	GOOD,
	AMBIGUOUS,
	BAD
}

enum ResolutionMode {
	AUTOMATIC,
	RANDOM_OUTCOME,
	PLAYER_CHOOSES_OUTCOME,
	PLAYER_ACCEPTS_THEN_OUTCOME,
	CONDITIONAL_OUTCOME,
	CUSTOM,
	PLAYER_GUESSES_RANDOM_OPTION
}

enum EventSource {
	NONE = 0,
	EVENT_BLOCK = 1,
	RANDOM_BLOCK = 2,
	OTHER_EVENT = 4
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var narrative_description: String
@export var icon: Texture2D

@export_category("Classificação")
@export var category: EventCategory = EventCategory.RANDOM_EVENT
@export var valence: Valence = Valence.AMBIGUOUS

@export_category("Resolução")
@export var resolution_mode: ResolutionMode = ResolutionMode.AUTOMATIC
@export_range(1, 999) var selection_weight: int = 1
@export var can_repeat: bool = true
@export_range(0, 99) var max_times_per_campaign: int = 0
# Um encontro apenas gerado no mapa não conta: precisa ter sido concluído.
@export var requires_completed_encounter: bool = false

@export_category("Resultados")
@export var outcomes: Array[EventOutcomeData] = []
# Cara/coroa reutilizável: qualquer Evento pode cadastrar duas opções distintas.
# A UI exibe A/B apenas como placeholder visual (substituível por ícones de
# moeda); o executor sorteia uma das duas com peso igual depois da confirmação.
# Igualdade usa guess_match_outcome; diferença usa guess_miss_outcome.
# Recusar é independente do sorteio.
@export var guess_options: Array[StringName] = []
@export var guess_match_outcome: EventOutcomeData
@export var guess_miss_outcome: EventOutcomeData
@export var guess_refusal_outcome: EventOutcomeData

@export_category("Eventos gerados")
## Usado quando este evento cria outros eventos no mapa, como os cinco Gnomos Misteriosos.
@export var generated_events: Array[EventData] = []

@export_category("Regra Especial")
@export var custom_rule: StringName

@export var tags: Array[StringName] = []
