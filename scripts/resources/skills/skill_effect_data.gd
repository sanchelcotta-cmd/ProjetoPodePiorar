class_name SkillEffectData
extends Resource

enum Target {
	SELF,
	ATTACK_TARGET,
	SELECTED_TARGET,
	DAMAGE_SOURCE,
	NEAREST_ALLY,
	NEAREST_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	SELECTED_TILE,
	OWNER,
	# Personagem que ativou o bloco que iniciou o Encontro.
	ENCOUNTER_ACTIVATOR,
	# Hexágono atualmente ocupado por quem produz o efeito.
	CURRENT_TILE,
	SELECTED_ITEM
}

enum EffectType {
	APPLY_DEBUFF,
	REMOVE_DEBUFF,
	HEAL_FIXED,
	HEAL_PERCENT_OF_DAMAGE_DEALT,
	REDUCE_INCOMING_DAMAGE,
	ENABLE_FLYING_MOVEMENT,
	MOVE_TOWARD_TARGET,
	MOVE_AWAY_FROM_TARGET,
	REVEAL_BLOCKS,
	MODIFY_ATTRIBUTE,
	ADD_EXTRA_ATTACK,
	COUNTERATTACK,
	SUMMON_ENTITY,
	TELEPORT,
	REDIRECT_DAMAGE,
	CUSTOM_SCRIPT,
	MODIFY_MASTERY,
	MODIFY_CRAFT_COST,
	GRANT_EXTRA_MOVEMENT,
	POSITION_COMPANION,
	GRANT_RANDOM_ITEM,
	SET_COMPANION_UNAVAILABLE,
	CONFIGURE_MASTERY_PROTECTION,
	# Os tipos abaixo são genéricos. Eles substituem scripts personalizados
	# de inimigos sem alterar a numeração dos tipos que já existiam.
	DODGE_INCOMING_ATTACK,
	PREVENT_MOVEMENT,
	DEAL_FIXED_DAMAGE,
	DESTROY_RANDOM_ITEM,
	MULTIPLY_INCOMING_DAMAGE,
	COPY_ATTRIBUTES_FROM_TARGET,
	RANDOMIZE_MASTERY,
	END_COMBAT,
	DESTROY_TILE,
	APPLY_TILE_STATE,
	CHANGE_ALLEGIANCE,
	PERFORM_ATTACK,
	SET_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT,
	# Bônus de espaço existe somente enquanto o equipamento estiver em uso.
	MODIFY_INVENTORY_CAPACITY,
	# Concede um turno imediatamente quando a passiva que o contém dispara.
	GRANT_EXTRA_TURN,
	REMOVE_INVENTORY_ITEMS,
	RESTRICT_EQUIPMENT,
	MODIFY_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT,
	ADD_CONSECUTIVE_ATTACK_BONUS,
	GRANT_STATUS_IMMUNITY,
	# Prioridade Forçada: amount é o bônus de ameaça do alvo (ex.: +5000 da Bonequinha de Pano).
	FORCE_TARGET_PRIORITY,
	SET_CRITICAL_ROLL_THRESHOLD,
	TRANSFORM_INVENTORY_ITEM,
	REVIVE_ENTITY,
	START_ENCOUNTER,
	MODIFY_DESTINATION_ENCOUNTER_SIZE,
	MULTIPLY_OUTGOING_ATTACK_RESULT,
	GRANT_STEALTH,
	# Efeitos permanentes concedidos por eventos.
	IGNORE_ATTACK_RANGE,
	MODIFY_EQUIPMENT_SLOT_CAPACITY,
	COPY_BOUND_SOURCE_TRAITS,
	DECLARE_RIVAL
}

enum ModifyMode {
	ADD,
	MULTIPLY,
	SET,
	SUBTRACT
}

# Indica se o número vem do próprio Resource ou de uma estatística de quem usa a habilidade.
enum ValueSource {
	FIXED,
	OWNER_BASE_ATTRIBUTE,
	LAST_DAMAGE_DEALT
}

enum ScalingSource {
	NONE,
	GROUP_INFORMATION_COUNT
}

enum RoundingMode {
	FLOOR,
	CEIL,
	NEAREST
}

enum EffectLifetime {
	INSTANT,
	WHILE_EQUIPPED,
	WHILE_CARRIED
}

# Usa os mesmos números de ItemData.Rarity sem criar uma dependência circular entre scripts.
enum ItemRarityFilter {
	NONE,
	COMMON,
	UNCOMMON,
	RARE,
	EPIC
}

enum EncounterSource {
	RANDOM_CURRENT_DISTRICT,
	DESTINATION_BLOCK
}

# A duração explícita evita criar uma habilidade nova só para mudar o momento em que o efeito termina.
enum DurationUnit {
	TURNS,
	ROUND,
	COMBAT,
	DAY,
	UNTIL_NEXT_ATTACK,
	UNTIL_END_OF_NEXT_OWNER_TURN,
	# Protege durante o restante do turno atual e todos os turnos seguintes,
	# expirando quando o dono volta a receber a vez no Combate.
	UNTIL_NEXT_OWNER_TURN_START
}

enum SelectionMode {
	FIXED,
	RANDOM_FROM_OPTIONS,
	PLAYER_CHOOSES_FROM_OPTIONS
}

enum DistanceMode {
	FIXED,
	HALF_DISTANCE_TRAVELED
}

enum RevealDetail {
	TYPE_ONLY,
	TYPE_AND_EFFECT
}

# A consulta da Mãe não muda o estado do bloco. Outras revelações seguem
# persistentes; os valores antigos dos Resources continuam iguais.
enum RevealPresentation {
	PERSISTENT,
	TEMPORARY_TITLE_INSPECTION
}

enum MasteryGrantMode {
	ADD_LEVEL,
	GRANT_IF_MISSING_ELSE_ADD_LEVEL
}

@export_category("Efeito")
@export var effect_type: EffectType
@export var target: Target = Target.SELF
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0

@export_category("Valores")
@export var modify_mode = ModifyMode.ADD
@export var amount: int = 0
@export_range(0, 99) var dice_count: int = 0
@export_range(0, 999) var dice_sides: int = 0
@export var roll_per_target: bool = false
@export var value_source: ValueSource = ValueSource.FIXED
@export var scaling_source: ScalingSource = ScalingSource.NONE
@export var rounding_mode: RoundingMode = RoundingMode.FLOOR
@export var effect_lifetime: EffectLifetime = EffectLifetime.INSTANT
@export var permanent_attribute_change: bool = false
# Efeitos de uso com o mesmo grupo: sorteia exatamente um, por peso.
@export var random_choice_group: StringName
@export_range(1, 999) var random_choice_weight: int = 1
@export var value_source_attribute_id: StringName
@export var minimum_value: int = 0
@export var maximum_value: int = 0
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
@export_range(0.0, 1.0, 0.01) var secondary_percent: float = 0.0
# Multiplicadores podem ser maiores que 1; por exemplo, 2.0 significa dano dobrado.
@export_range(0.0, 10.0, 0.01) var multiplier: float = 1.0
@export var debuff_id: StringName
@export var attribute_id: StringName
@export var reveal_detail: RevealDetail = RevealDetail.TYPE_ONLY
@export var reveal_presentation: RevealPresentation = RevealPresentation.PERSISTENT
@export var mastery_grant_mode: MasteryGrantMode = MasteryGrantMode.ADD_LEVEL
# Restrições opcionais do equipamento usado neste ataque.
@export var requires_melee_weapon_equipped: bool = false
@export var requires_no_weapon_equipped: bool = false
# Zero significa que a Maestria da fonte vinculada não é filtrada.
@export var required_bound_source_mastery: EntityData.Mastery = EntityData.Mastery.NONE
@export var equipment_slot_id: StringName
@export var tags_filter: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []
@export var status_ids: Array[StringName] = []
@export var immunity_item_tags: Array[StringName] = []
@export var restricted_equipment_rarity: ItemRarityFilter = ItemRarityFilter.NONE
# Ao receber uma restrição, itens já equipados que a violam voltam ao inventário.
@export var auto_unequip_restricted_equipment: bool = false
@export var required_item_rarity: ItemRarityFilter = ItemRarityFilter.NONE
@export var require_item_craft_result: bool = false
@export var player_chooses_craft_result: bool = false
@export var consume_transformed_item: bool = false
@export_range(0, 99) var max_items_affected: int = 0
@export var ignore_discard_restriction: bool = false
@export var recalculate_bonus_instead_of_stacking: bool = false
# Bônus progressivo: no primeiro marco recebe initial_bonus; a cada step_interval
# unidades da fonte recebe step_bonus, sem ultrapassar max_total_bonus.
@export_range(0, 999) var first_threshold: int = 0
@export var initial_bonus: int = 0
@export_range(0, 999) var step_interval: int = 0
@export var step_bonus: int = 0
@export_range(0, 999) var max_total_bonus: int = 0
@export var apply_to_current_attack_only: bool = false
# Quando o mesmo efeito dispara outra vez, cada instância soma seu próprio bônus.
@export var stack_with_existing_effects: bool = false
# Só aplica este efeito se a origem do dano estiver no alcance da arma equipada.
@export var requires_damage_source_in_equipped_weapon_range: bool = false
@export var reset_consecutive_bonus_on_miss: bool = true
@export var reset_consecutive_bonus_on_target_change: bool = true
# Dano refletido não deve disparar a mesma passiva novamente em cadeia.
@export var generated_damage_can_trigger_passives: bool = true
@export var requires_destination_encounter_block: bool = false
@export var excludes_destination_encounter_block: bool = false
@export var encounter_source: EncounterSource = EncounterSource.RANDOM_CURRENT_DISTRICT
@export var revive_with_full_hp: bool = false
@export var consume_source_item_on_success: bool = false
# Em CHANGE_ALLEGIANCE, conserva a instância escolhida, seu equipamento e suas Skills.
@export var preserve_target_state_on_allegiance_change: bool = true
@export var attach_converted_entity_as_companion: bool = false
@export var converted_companion_moves_in_exploration: bool = true
# Em DECLARE_RIVAL, concede estas passivas vinculadas ao EntityData.id do alvo.
@export var passives_granted_on_success: Array[Resource] = []
# Efeitos de dano usam a mesma identidade de tipo gravada na Skill concedida.
@export var requires_counterparty_entity_data_matches_bound_id: bool = false
# Em COPY_BOUND_SOURCE_TRAITS, congela os valores na concessão (não segue mudanças futuras da fonte).
@export var snapshot_bound_source_on_grant: bool = true
@export var copy_bound_masteries: bool = false
@export var copy_bound_passives: bool = false
@export var copy_bound_bonus_attack: bool = false
@export var copy_bound_bonus_max_hp: bool = false
@export var copy_bound_bonus_stamina: bool = false
# Para EntityData: somar as estatísticas base da fonte como bônus do portador.
@export var copy_bound_attack_base_as_bonus: bool = false
@export var copy_bound_max_hp_base_as_bonus: bool = false
# Escolhe a variação antes de atacar, mas só cura depois de conhecer o dano desse ataque.
@export var apply_after_damage_dealt_on_same_attack: bool = false
@export var stealth_breaks_on_attack: bool = false
@export var stealth_restores_on_next_owner_turn: bool = false
@export var stealth_prevents_attack_targeting: bool = false
@export var stealth_prevents_trap_activation: bool = false
@export_range(0, 99) var area_radius: int = 0
# Em buscas ao redor (ex.: Gatinho), o hex central não entra na revelação.
@export var include_center_tile: bool = true

@export_category("Seleção e referências")
# IDs evitam dependências circulares, como Dama invocando Planta e Planta invocando Dama.
@export var selection_mode: SelectionMode = SelectionMode.FIXED
@export var entity_id: StringName
@export var entity_ids: Array[StringName] = []
@export var attribute_ids: Array[StringName] = []
@export var mastery_options: Array[int] = []
@export var tile_state_id: StringName
@export var distance_mode: DistanceMode = DistanceMode.FIXED

@export_category("Regras especiais genéricas")
@export var ignore_resistance: bool = false
@export_range(0, 99) var minimum_amount: int = 0
@export_range(0, 99) var maximum_amount: int = 0
@export_range(0, 99) var maximum_active_instances: int = 0
@export var summoned_can_summon: bool = true
@export var summoned_acts_immediately: bool = false
# Duas listas paralelas: a tag na posição N usa o limite na posição N.
@export var context_tags: Array[StringName] = []
@export var context_caps: Array[int] = []

@export_category("Duração")
@export var has_duration: bool = false
@export_range(0, 99) var duration_turns: int = 0
@export var duration_unit: DurationUnit = DurationUnit.TURNS
@export_range(0, 99) var delay_turns: int = 0

@export_category("Filtro de eventos")
# Para DESTROY_TILE: listas vazias não filtram. As duas listas preenchidas
# são verificadas juntas, evitando destruir tipos de Evento não autorizados.
@export var allowed_event_categories: Array[int] = []
@export var allowed_event_valences: Array[int] = []
