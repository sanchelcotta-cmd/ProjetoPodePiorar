class_name Event_EffectData
extends Resource

enum EffectType {
# Vida / atributos
	MODIFY_HP,
	MODIFY_MAX_HP,
	MODIFY_STAT,
	# Status
	APPLY_STATUS,
	REMOVE_STATUS,
	# Habilidades
	APPLY_SKILL_EFFECT,
	GRANT_PASSIVE,
	REMOVE_PASSIVE,
	GRANT_ACTIVE_SKILL,
	REMOVE_ACTIVE_SKILL,
	# Inventário
	GRANT_ITEM,
	REMOVE_ITEM,
	GRANT_RANDOM_ITEM,
	TRANSFORM_INVENTORY,
	# Informações
	GRANT_INFORMATION,
	FORGET_LAST_INFORMATION,
	# Companheiros
	ADD_COMPANION,
	# Mundo
	START_COMBAT,
	REVEAL_BLOCKS,
	TELEPORT_ENTITY,
	CHANGE_MAP,
	CHANGE_DISTRICT,
	# Tempo
	ADVANCE_DAY,
	ADVANCE_ROUND,
	CHANGE_TIME_OF_DAY,
	# Estado global
	REMOVE_CURSES,
	APPLY_CATASTROPHE,
	SWAP_BODIES,
	CUSTOM,
	# Acrescentar novos tipos somente no final preserva os números dos .tres existentes.
	GRANT_STATUS_IMMUNITY,
	TRIGGER_EVENT,
	REPORT_MAP_PRESENCE,
	IGNORE_RANGED_CRITICAL_BONUS,
	APPLY_ITEM_STATE,
	SET_MOVEMENT_LIMIT,
	SUPPRESS_SKILLS,
	GRANT_MOVEMENT_OVERRIDE,
	APPLY_VISUAL_EFFECT,
	MASK_BLOCK_VISUALS,
	MODIFY_EQUIPPED_ITEM_STAT,
	REPLACE_BLOCK_CONTENT,
	REVIVE_DEAD_PLAYABLE
}

enum Target {
	ACTIVE_ENTITY,
	SELECTED_ENTITY,
	RANDOM_PLAYER,
	GROUP,
	MAP,
	BLOCK,
	NONE,
	ENTITIES_IN_BLOCK_RADIUS,
	BLOCK_LINE_HORIZONTAL,
	ADJACENT_BLOCKS,
	RANDOM_BLOCKS,
	BLOCK_LINE_VERTICAL
}

enum SelectionMode {
	FIXED,
	PLAYER_CHOOSES_FROM_CATALOG,
	RANDOM_FROM_CATALOG
}

enum MathOperation {
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	SET
}

enum Statistic {
	NONE,
	HP,
	MAX_HP,
	ATTACK,
	STAMINA
}

enum DurationUnit {
	TURN,
	ROUND,
	DAY,
	PERMANENT
}

# De onde vem o valor usado por MODIFY_HP. FIXED preserva os eventos existentes.
enum ValueSource {
	FIXED,
	CURRENT_HP,
	MISSING_HP,
	SHARED_ROLL,
	TARGET_STATISTIC
}

# Centro de efeitos espaciais, como REVEAL_BLOCKS.
enum AreaOrigin {
	TARGET,
	ACTIVE_ENTITY
}

# Arredonda o valor calculado antes de aplicar a operação matemática.
enum RoundingMode {
	FLOOR,
	CEIL,
	NEAREST
}

enum DurationSource {
	FIXED,
	DICE_ROLL
}

enum ExpirationMode {
	AFTER_DURATION,
	END_OF_CURRENT_DAY,
	END_OF_CURRENT_ROUND
}

enum RevealDetail {
	TYPE_ONLY,
	TYPE_AND_EFFECT
}

enum EncounterSelection {
	FIXED,
	NEAREST_MAP_BLOCK
}

enum EntitySelection {
	FIXED,
	RANDOM_CURRENT_DISTRICT_ENEMY,
	RANDOM_PLAYABLE_CHARACTER
}

enum DestinationMode {
	FIXED,
	RANDOM_HEX_CURRENT_MAP,
	RANDOM_MAP_RANDOM_DISTRICT
}

enum ReportScope {
	CURRENT_MAP,
	CURRENT_ROUND
}

# IMMEDIATE aplica agora; GRANT_ACTION cria uma ação temporária;
# REPEAT_ON_TRIGGER reaplica o efeito quando o gatilho ocorrer.
enum ExecutionMode {
	IMMEDIATE,
	GRANT_ACTION,
	REPEAT_ON_TRIGGER
}

enum TriggerMoment {
	ON_TURN_START,
	BEFORE_ACTION,
	ON_MOVE_DESTINATION
}

enum EffectScope {
	TARGET,
	GLOBAL
}

enum IncomingAttackRange {
	ANY,
	MELEE,
	RANGED
}

enum ItemCategoryFilter {
	ANY,
	EQUIPMENT,
	CONSUMABLE,
	CURSED
}

enum ItemStatistic {
	NONE,
	BONUS_ATTACK,
	BONUS_LIFE,
	BONUS_STAMINA
}

enum BlockSelectionOrigin {
	TRIGGER_BLOCK,
	ACTIVE_ENTITY
}

enum SkillContext {
	ANY,
	COMBAT,
	EXPLORATION
}

# Quando um evento concede uma Skill, indica qual escolha fica vinculada à cópia
# recebida pelo personagem. O Resource original da Skill nunca é alterado.
enum GrantBindingSource {
	NONE,
	SELECTED_EQUIPPED_ITEM,
	SELECTED_ENEMY_FROM_LAST_ENCOUNTER,
	SELECTED_OWNED_ITEM
}

enum SwapMode {
	RANDOM,
	CYCLIC
}

@export_category("Efeito")
@export var effect_type: EffectType
@export var target: Target = Target.ACTIVE_ENTITY
@export var execution_mode: ExecutionMode = ExecutionMode.IMMEDIATE
@export var trigger_moment: TriggerMoment = TriggerMoment.ON_TURN_START
@export var effect_scope: EffectScope = EffectScope.TARGET
@export_range(0.0, 1.0, 0.01) var activation_chance: float = 1.0
@export_range(0, 99) var max_uses_per_turn: int = 0
# Para uma ação concedida, zero não limita; ao chegar ao limite, a ação desaparece.
@export_range(0, 999) var max_uses_total: int = 0

@export_category("Seleção")
@export var selection_mode: SelectionMode = SelectionMode.FIXED
@export var tags_filter: Array[StringName] = []
# Efeitos do mesmo resultado com o mesmo grupo escolhem uma única vez o alvo aleatório.
@export var target_selection_group: StringName
@export var encounter_selection: EncounterSelection = EncounterSelection.FIXED
@export var randomize_equal_distance: bool = false
@export var entity_selection: EntitySelection = EntitySelection.FIXED
@export var exclude_entities_already_in_group: bool = false
	
@export_category("Referências")
@export var effect: SkillEffectData
@export var item: ItemData
# Para recompensas que precisam ser recebidas mesmo quando o item em si é descartável.
@export var item_acceptance_required: bool = false
@export var item_filter: Array[StringName] = []
@export var item_category_filter: ItemCategoryFilter = ItemCategoryFilter.ANY
@export var excluded_item_category: ItemCategoryFilter = ItemCategoryFilter.ANY
@export var exclude_passives_already_owned: bool = false
# Seleção e modificação de uma instância possuída, nunca do ItemData compartilhado.
@export var selected_item_must_be_equipped: bool = false
@export var required_item_equipment_slots: Array[int] = []
@export var modify_selected_item_instance: bool = false
@export var item_statistic_for_weapon: ItemStatistic = ItemStatistic.NONE
@export var item_statistic_for_armor: ItemStatistic = ItemStatistic.NONE
@export var item_statistic_for_accessory: ItemStatistic = ItemStatistic.NONE
@export var item_state: ItemStateData
@export var apply_item_state_to_existing: bool = false
@export var apply_item_state_to_future_acquisitions: bool = false
# A regra de aquisição expira, mas os itens já marcados podem continuar nesse estado.
@export var item_state_persists_after_rule: bool = false
# Na virada do Dia, remove do inventário as instâncias que esta regra marcou.
@export var discard_affected_items_on_expiration: bool = false
# Em REMOVE_ITEM, retira todos os itens que correspondem ao filtro, inclusive de cada membro do GROUP.
@export var remove_all_matching_items: bool = false
# Purificação pode retirar uma maldição mesmo quando o item não pode ser descartado manualmente.
@export var ignore_discard_restriction: bool = false
# Em REMOVE_CURSES, elimina todas as maldições do alvo, não só uma.
@export var remove_all_curses: bool = false
@export var entity_filter: Array[StringName] = []
@export var entity: EntityData
@export var bind_companion_to_active_entity: bool = false
# ID de outro EventData, para reutilizar um evento já cadastrado como resultado.
@export var event_id: StringName
@export var information_id: StringName
@export var passive: PassiveSkillData
@export var active_skill: ActiveSkillData
@export var grant_binding_source: GrantBindingSource = GrantBindingSource.NONE
@export var required_bound_item_slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE
@export var required_bound_item_rarity: ItemData.Rarity = ItemData.Rarity.NONE
@export var remove_bound_item_on_grant: bool = false
@export var debuff: DebuffData
@export var status_ids: Array[StringName] = []
@export var visual_effect_id: StringName
# Blocos filtrados por tags_filter recebem a mesma aparência temporária.
@export var visual_mask_id: StringName
@export var immunity_item_tags: Array[StringName] = []
@export var incoming_attack_range: IncomingAttackRange = IncomingAttackRange.ANY
@export var skill_context_filter: SkillContext = SkillContext.ANY
@export var suppress_passives: bool = false
@export var suppress_actives: bool = false

@export var statistic: Statistic = Statistic.NONE

@export_category("Valores")
@export var amount: int = 0
@export var use_night_amount_override: bool = false
@export var night_amount_override: int = 0
@export_range(0.0, 1.0, 0.01) var percent: float = 0.0
# FIXED usa amount; CURRENT_HP e MISSING_HP usam o valor de cada alvo.
# Quando percent for maior que zero, multiplica a origem por percent.
@export var value_source: ValueSource = ValueSource.FIXED
@export var rounding_mode: RoundingMode = RoundingMode.FLOOR
@export var clamp_stat_minimum: bool = false
@export var stat_minimum: int = 0
@export var clamp_current_hp_to_max: bool = false
# Ao terminar um redutor temporário de Vida máxima, o máximo volta; a Vida atual não é reembolsada.
@export var restore_clamped_hp_on_expiration: bool = false
@export var excluded_equipped_slot: ItemData.EquipmentSlot = ItemData.EquipmentSlot.NONE
@export var excluded_equipped_rarity: ItemData.Rarity = ItemData.Rarity.NONE
@export var area_origin: AreaOrigin = AreaOrigin.TARGET
@export_range(0, 99) var area_radius: int = 0
@export var reveal_detail: RevealDetail = RevealDetail.TYPE_ONLY
@export var reveal_all_blocks: bool = false
@export var report_scope: ReportScope = ReportScope.CURRENT_MAP
@export var report_each_tag: bool = false
@export var dice_count: int = 0
@export var dice_sides: int = 0
@export_range(0.0, 10.0, 0.01) var dice_result_multiplier: float = 1.0
# Efeitos do mesmo resultado com o mesmo ID reutilizam um único lançamento de dado.
@export var shared_roll_id: StringName
# Com GROUP, cada personagem lança seu próprio dado; o ID compartilhado é separado por personagem.
@export var roll_per_target: bool = false
# Zero não impõe condição; outro valor exige que o dado compartilhado tenha esse resultado.
@export_range(0, 999) var required_shared_roll_value: int = 0
# Em APPLY_STATUS, usa o valor calculado como dano inicial de cada instância do status.
@export var status_initial_tick_damage_from_value: bool = false
@export var math_operation = MathOperation.SET

@export var has_duration := false
# Imunidades e modificadores concedidos sem duração permanecem até serem removidos.
@export_range(0,999) var duration_amount: int = 0
@export var duration_unit: DurationUnit = DurationUnit.TURN
@export var duration_source: DurationSource = DurationSource.FIXED
@export var expiration_mode: ExpirationMode = ExpirationMode.AFTER_DURATION
# Limite por personagem e ID do evento; zero não limita.
@export_range(0, 99) var max_applications_per_entity_per_campaign: int = 0

@export_category("Destino")
@export var destination_mode: DestinationMode = DestinationMode.FIXED
# Ao mudar de mapa, apenas o personagem ativo ativa o hexágono de chegada.
@export var activate_destination_event: bool = false
@export var destination_must_be_unactivated: bool = false
@export var destination_must_differ_from_origin: bool = false

@export_category("Movimento e troca")
@export var ignore_stamina_cost: bool = false
@export var ignore_stamina_range: bool = false
@export var allow_activated_exploration_destinations: bool = false
@export var swap_mode: SwapMode = SwapMode.RANDOM
@export var swap_only_active_playables: bool = false
@export var reverse_swap_on_repeat: bool = false

@export_category("Substituição de conteúdo dos blocos")
# REPLACE_BLOCK_CONTENT usa target para escolher um bloco, linha horizontal,
# linha vertical, hexágonos adjacentes ou hexágonos aleatórios.
# TRIGGER_BLOCK é o hex que disparou o evento, não a posição atual do personagem.
@export var block_selection_origin: BlockSelectionOrigin = BlockSelectionOrigin.TRIGGER_BLOCK
# Em BLOCK_LINE_HORIZONTAL, BLOCK_LINE_VERTICAL e ADJACENT_BLOCKS, inclui a origem.
@export var include_origin_block: bool = true
# Só é usado quando target == RANDOM_BLOCKS. Sorteia este número de hexágonos.
@export_range(1, 999) var random_block_count: int = 1
# Números de HexGrid.PPPBlockType. Blocos preservados mantêm Resource, posição e estado.
@export var preserved_map_block_types: Array[int] = []
# O sorteio considera só conteúdos que não estavam em nenhum bloco do mapa atual.
@export var replacement_pool_excludes_current_map: bool = false
# Ignora as cotas, valências, percentuais e pesos usados na geração normal.
@export var replacement_ignores_generation_balance: bool = false
# Embaralha o conjunto elegível e retira um Resource por hex, sem repetir entre alvos.
@export var replacement_draw_without_replacement: bool = false
# Mesmo blocos antes ativados/destruídos/cancelados voltam como blocos novos, ocultos.
@export var reset_replaced_blocks_to_hidden: bool = false

@export_category("Especial")
@export var custom_rule: StringName
