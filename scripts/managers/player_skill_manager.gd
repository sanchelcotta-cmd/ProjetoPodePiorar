class_name PlayerSkillManager
extends Node

## Ponte entre as decisões do jogador e o SkillManager universal. A entidade
## pode ser jogável, aliada ou um inimigo que passou ao controle do jogador.
## A caixa do companheiro pode ser filha da caixa do dono; a Skill continua
## guardada no EntityState do companheiro. Nenhuma regra cita nome de herói.

signal pre_activation_choice_requested(
	actor: EntityState,
	coord: Vector2i,
	options: Array[SkillGrantState],
)
signal normal_activation_requested(actor: EntityState, coord: Vector2i)
signal exploration_active_resolved(actor: EntityState, skill: ActiveSkillData,
	coord: Vector2i)
signal item_recipient_choice_requested(item: ItemData, options: Array[EntityState])

@export var block_manager: BlockManager
@export var skill_manager: SkillManager

var _pending_actor: EntityState
var _pending_coord := EntityState.UNPLACED
var _pending_options: Array[SkillGrantState] = []
# Defesa adicional: mesmo se outro controlador repetir a notificação, um
# turno da mesma instância só resolve seus efeitos de início uma vez.
var _last_started_serial_by_instance: Dictionary = {}


func _ready() -> void:
	if skill_manager != null:
		skill_manager.inventory_manager.recipient_choice_requested.connect(
			_on_item_recipient_choice_requested
		)


func has_pending_choice() -> bool:
	return _pending_actor != null or (skill_manager != null \
		and skill_manager.inventory_manager.has_pending_recipient_choice())


func get_pending_options() -> Array[SkillGrantState]:
	var options: Array[SkillGrantState] = []
	options.assign(_pending_options)
	return options


## Chamar depois de chegar, mas ANTES de iniciar o BlockManager.
func offer_before_block_activation(actor: EntityState, coord: Vector2i) -> bool:
	if has_pending_choice() or block_manager == null or skill_manager == null \
			or block_manager.gerencia == null or actor == null:
		return false
	# A proteção automática do Bonequinho acontece antes de gastar uma Ativa
	# preventiva, como a Quebra 4ª Parede do Pedreiro.
	var campaign := block_manager.gerencia.campaign
	if campaign != null and campaign.current_map != null \
			and campaign.has_wooden_doll(actor):
		var block_type := campaign.current_map.get_ppp_block_type(coord)
		var event := campaign.current_map.get_ppp_block_resource(coord) as EventData
		if event != null and event.valence == EventData.Valence.BAD \
				and block_type in [HexGrid.PPPBlockType.TRAP,
					HexGrid.PPPBlockType.CATASTROPHE]:
			return false
	var options: Array[SkillGrantState] = []
	for grant in skill_manager.get_active_grants(actor):
		if skill_manager.can_use_exploration_active(
			actor, actor, grant, block_manager.gerencia.campaign, coord,
			block_manager, block_manager.gerencia.map_view, true
		):
			options.append(grant)
	if options.is_empty():
		return false
	_pending_actor = actor
	_pending_coord = coord
	_pending_options.assign(options)
	pre_activation_choice_requested.emit(actor, coord, get_pending_options())
	return true


## null = não usar Skill e ativar o bloco normalmente. Uma Skill escolhida
## precisa ter sido oferecida; o Resource define seu efeito e seu limite.
func answer_pre_activation_choice(selected_grant: SkillGrantState = null) -> bool:
	if _pending_actor == null:
		return false
	if selected_grant != null and selected_grant not in _pending_options:
		return false
	var actor := _pending_actor
	var coord := _pending_coord
	var options := get_pending_options()
	_clear_pending()
	if selected_grant == null:
		normal_activation_requested.emit(actor, coord)
		return true
	if skill_manager.use_exploration_active(
		actor, actor, selected_grant, block_manager.gerencia.campaign, coord,
		block_manager, block_manager.gerencia.map_view, true
	):
		exploration_active_resolved.emit(actor,
			selected_grant.skill as ActiveSkillData, coord)
		return true
	# Se o mapa mudou antes da resposta, a Skill não foi gasta. Mantemos a
	# escolha pendente para que o controlador trate a situação explicitamente.
	_pending_actor = actor
	_pending_coord = coord
	_pending_options.assign(options)
	return false


## A caixa chama isto com a entidade DONA da Skill. Para companheiros com
## usable_while_owner_inactive, o dono é resolvido pelo vínculo mesmo sem
## turno aberto; usar a Skill não compromete o turno de outro jogável.
func use_exploration_active(actor: EntityState, grant: SkillGrantState, coord: Vector2i, exploration: Variant, selection: Dictionary = {}) -> bool:
	if skill_manager == null or exploration == null or block_manager == null \
			or block_manager.is_busy() or has_pending_choice():
		return false
	var gerencia: GerenciaJogo = exploration.gerencia
	if gerencia == null or gerencia.campaign.current_map == null:
		return false
	var skill := grant.skill as ActiveSkillData if grant != null else null
	var owner := gerencia.campaign.get_playable_slot(actor.owner_instance_id) \
		if actor != null and actor in gerencia.campaign.companion_states else null
	var off_turn_pet: bool = skill != null and skill.usable_while_owner_inactive \
		and owner != null
	var turn_owner: EntityState = owner if off_turn_pet else exploration.current_actor
	if turn_owner == null or (not off_turn_pet \
			and not skill_manager.debuff_manager.can_take_action(turn_owner)):
		return false
	if not skill_manager.use_exploration_active(
		actor, turn_owner, grant, gerencia.campaign, coord,
		block_manager, gerencia.map_view, false, selection
	):
		return false
	if skill.effects.any(func(effect: SkillEffectData) -> bool:
		return effect.effect_type == SkillEffectData.EffectType.TELEPORT):
		if not exploration.arrive_from_event(coord, actor):
			return false
		exploration.refresh_map_feedback()
		exploration_active_resolved.emit(actor, skill, coord)
		return true
	exploration.refresh_map_feedback()
	var committed: bool = true if off_turn_pet else exploration.commit_current_turn_action()
	if committed:
		exploration_active_resolved.emit(actor, skill, coord)
	return committed


## Mantém a chamada já usada pela tela/testes para Skills que escolhem hex.
func use_tile_active(actor: EntityState, grant: SkillGrantState, coord: Vector2i, exploration: Variant) -> bool:
	return use_exploration_active(actor, grant, coord, exploration)


## A caixa da Professora mostra apenas combinações que ela realmente pode
## fabricar agora. O jogador escolhe uma das saídas Épicas listadas.
func get_craft_options(actor: EntityState, grant: SkillGrantState, exploration: Variant) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if actor == null or grant == null or exploration == null or skill_manager == null \
			or exploration.current_actor != actor or block_manager == null:
		return options
	var skill := grant.skill as ActiveSkillData
	if skill == null:
		return options
	for effect in skill.effects:
		if effect.effect_type != SkillEffectData.EffectType.MODIFY_CRAFT_COST:
			continue
		for option in skill_manager.inventory_manager.get_craftable_options(actor, 3 + effect.amount):
			var available_results: Array[ItemData] = []
			for result in option["results"]:
				var selection := {"ingredient_id": option["ingredient"].id, "result_id": result.id}
				if skill_manager.can_use_exploration_active(
					actor, actor, grant, exploration.gerencia.campaign,
					EntityState.UNPLACED, block_manager, exploration.gerencia.map_view,
					false, selection
				):
					available_results.append(result)
			if not available_results.is_empty():
				options.append({"ingredient": option["ingredient"], "results": available_results})
	return options


func use_craft_active(actor: EntityState, grant: SkillGrantState, ingredient_id: StringName, result_id: StringName, exploration: Variant) -> bool:
	return use_exploration_active(actor, grant, EntityState.UNPLACED, exploration,
		{"ingredient_id": ingredient_id, "result_id": result_id})


func consume_extra_movement(actor: EntityState, campaign: CampaignState) -> bool:
	return skill_manager != null and skill_manager.consume_extra_movement(actor, campaign)


func on_owner_turn_started(owner: EntityState, campaign: CampaignState) -> void:
	if skill_manager == null or owner == null or campaign == null:
		return
	var instance_key := owner.get_instance_id()
	if int(_last_started_serial_by_instance.get(instance_key, -1)) == owner.turn_serial:
		return
	_last_started_serial_by_instance[instance_key] = owner.turn_serial
	skill_manager.on_entity_turn_started(owner, campaign)
	if owner.current_health <= 0:
		return
	skill_manager.resolve_delayed_effects_for_owner(owner, campaign)
	skill_manager.dispatch_passive_trigger(owner, PassiveSkillData.Trigger.ON_TURN_START,
		campaign, {"mode": HexGrid.PPPMapMode.EXPLORATION})


func on_exploration_destination_reached(actor: EntityState, campaign: CampaignState,
		coord: Vector2i) -> void:
	if skill_manager == null:
		return
	var context := {"mode": HexGrid.PPPMapMode.EXPLORATION, "destination": coord}
	skill_manager.dispatch_passive_trigger(actor, PassiveSkillData.Trigger.ON_AFTER_MOVE,
		campaign, context)
	skill_manager.dispatch_passive_trigger(actor,
		PassiveSkillData.Trigger.ON_EXPLORATION_DESTINATION_REACHED, campaign, context)


func on_information_obtained(campaign: CampaignState) -> void:
	if skill_manager != null:
		skill_manager.on_information_obtained(campaign)


func answer_created_item_recipient(recipient: EntityState) -> bool:
	return skill_manager != null and skill_manager.inventory_manager.choose_recipient(recipient)


func _on_item_recipient_choice_requested(item: ItemData, options: Array[EntityState]) -> void:
	item_recipient_choice_requested.emit(item, options)


## Lista única para montar a caixa principal e as caixas-filhas dos companheiros.
## O botão só é clicável depois que a interface pedir o alvo exigido.
func get_exploration_skill_options(exploration: Variant) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if exploration == null or exploration.current_actor == null or skill_manager == null:
		return options
	var owner: EntityState = exploration.current_actor
	var campaign: CampaignState = exploration.gerencia.campaign
	var entities: Array[EntityState] = [owner]
	entities.append_array(campaign.get_companions_for_owner(owner.instance_id))
	for entity in entities:
		for grant in skill_manager.get_active_grants(entity):
			var skill := grant.skill as ActiveSkillData
			if skill.use_context == ActiveSkillData.UseContext.COMBAT or not skill.automatic_triggers.is_empty():
				continue
			var implemented := true
			for effect in skill.effects:
				if not skill_manager.effect_executor.supports(effect):
					implemented = false
					break
			options.append({
				"skill_owner": entity,
				"grant": grant,
				"is_companion": entity != owner,
				"needs_tile": skill.target_mode == ActiveSkillData.TargetMode.TILE,
				"needs_craft_choice": skill.effects.any(func(effect: SkillEffectData) -> bool:
					return effect.effect_type == SkillEffectData.EffectType.MODIFY_CRAFT_COST),
				"implemented": implemented,
			})
	return options


func _clear_pending() -> void:
	_pending_actor = null
	_pending_coord = EntityState.UNPLACED
	_pending_options.clear()
