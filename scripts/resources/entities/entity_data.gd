class_name EntityData
extends Resource

enum Mastery {
	NONE,
	BLADE,
	IMPACT,
	RANGED
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var narrative_description: String

@export_category("Visual")
@export var portrait: Texture2D
@export var sprite: Texture2D
@export var icon: Texture2D
@export var playable_animation: PlayableAnimationData
## Aparências alternativas da MESMA entidade. O sorteio pertence ao
## EntityState, nunca a este cadastro compartilhado.
@export var animation_variants: Array[SpriteSheetAnimationData] = []

@export_category("Estatísticas fixas")
@export_range(1, 999) var vida_base: int = 1
@export_range(0, 999) var ataque_base: int = 0
@export_range(0, 999) var stamina_base: int = 0
@export var maestrias: Array[Mastery] = [Mastery.NONE]

@export_category("Kit inicial")
@export var equipamentos_iniciais: Array[Resource] = []

@export_category("Skills passivas")
@export var skill_passivas: Array[PassiveSkillData] = []

@export_category("Skills ativas")
@export var skill_ativas: Array[ActiveSkillData] = []

@export_category("Tags")
@export var tags: Array[StringName] = []
