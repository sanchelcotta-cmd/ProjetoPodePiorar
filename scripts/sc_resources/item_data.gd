class_name ItemData
extends Resource

enum ItemType {
	EQUIPMENT,
	CONSUMABLE,
	CURSED,
}

enum EquipmentSlot {
	NONE,
	WEAPON,
	ARMOR,
	ACCESSORY
}

enum Rarity {
	NONE,
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

enum AcquisitionSource {
	NONE = 0,
	MAP_BLOCK = 1,
	ENEMY_LOOT = 2,
	CRAFT = 4,
	STARTING_ITEM = 8
}

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

@export_category("Categoria")
@export var item_type: ItemType = ItemType.EQUIPMENT
@export var rarity: Rarity = Rarity.COMMON
@export_flags(
	"Map block",
	"Enemy loot",
	"Craft",
	"Starting item"
)
var acquisition_sources: int = AcquisitionSource.NONE
@export var tags: Array[StringName] = []

@export_category("Inventário")
@export_range(1,99) var inventory_space: int = 1
@export var can_be_discarded: bool = true

@export_category("Equipamento")
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var mastery_granted: EntityData.Mastery = EntityData.Mastery.NONE
@export_range(0, 99) var mastery_bonus: int = 0
@export_range(0, 99) var bonus_attack: int = 0
@export_range(0,99) var bonus_life: int = 0
@export_range(0,99) var bonus_stamina: int = 0
@export var granted_passives: Array[PassiveSkillData] = []
@export var granted_active_skills: Array[ActiveSkillData] = []

@export_category("Consumível")
@export var use_effects: Array[SkillEffectData] = []
@export var consumed_on_use: bool = true

@export_category("Craft")
@export var craft_result: Array[ItemData] = []
