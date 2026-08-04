class_name EventData
extends Resource

enum EventCategory {
	RANDOM_EVENT,
	PERMANENT_EFFECT,
	CATASTROPHE
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
	PLAYER_ACCEPTS_THEN_RANDOM,
	CUSTOM	
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

@export_flags(
	"Event block",
	"Random block",
	"Other event"
)
var event_sources: int = EventSource.EVENT_BLOCK

@export_category("Resolução")
@export var resolution_mode: ResolutionMode = ResolutionMode.AUTOMATIC
@export_range(1, 999) var selection_weight: int = 1
@export var can_repeat: bool = true
@export_range(0, 99) var max_times_per_campaign: int = 0

@export_category("Resultados")
@export var outcomes: Array[EventOutcomeData] = []

@export_category("Regra Especial")
@export var custom_rule_id: StringName
