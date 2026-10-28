class_name ExplorationManager
extends Node

## Coordena apenas a Exploração: vaga do turno, caminho e Stamina. O
## BlockManager resolve o conteúdo do hex; Combate e Effects ficam fora daqui.

signal map_entered(new_map: HexGrid)
signal cycle_started(cycle_number: int)
signal turn_started(actor: EntityState)
signal turn_finished(actor: EntityState)
signal actor_moved(actor: EntityState, path: Array[Vector2i], stamina_spent: int)
signal actor_teleported(actor: EntityState, destination: Vector2i)
signal actor_will_arrive(actor: EntityState, destination: Vector2i)
signal movement_rejected(reason: String)

@export var gerencia: GerenciaJogo
@export var block_manager: BlockManager
@export var player_skill_manager: PlayerSkillManager
@export var catastrophe_manager: CatastropheManager

var current_actor: EntityState
var cycle_number: int = 0

var _turn_committed: bool = false
var _has_moved_this_turn: bool = false
var _awaiting_block: bool = false
var _reopened_extra_movement: bool = false


func _ready() -> void:
	if block_manager != null:
		block_manager.block_finished.connect(_on_block_finished)
	if player_skill_manager != null:
		player_skill_manager.normal_activation_requested.connect(_on_normal_activation_requested)
	if catastrophe_manager != null:
		catastrophe_manager.catastrophe_started.connect(_on_catastrophe_changed)
		catastrophe_manager.catastrophe_ended.connect(_on_catastrophe_changed)
	if gerencia != null and gerencia.map_view != null:
		gerencia.map_view.destination_requested.connect(try_move)
		gerencia.map_view.destination_validator = Callable(self, "_can_preview_destination")
		gerencia.map_view.selection_validator = Callable(self, "_can_select_hex_for_ui")


## Chamar DEPOIS de gerar o mapa. Em nova Rodada, reset_turn_cycle = true.
## Para um Portal na mesma Rodada, passar false: todos voltam à StartZone,
## mas a Stamina e a disponibilidade dos turnos são preservadas.
## Não chamar enquanto um Evento/Combate ainda estiver sendo resolvido.
func enter_map(reset_turn_cycle: bool, preferred_actor: EntityState = null) -> bool:
	if gerencia == null or gerencia.campaign.current_map == null \
			or gerencia.campaign.is_terminal() \
			or block_manager == null or player_skill_manager == null:
		return false
	if block_manager.is_busy() or player_skill_manager.has_pending_choice():
		return false
	var states := gerencia.campaign.active_entity_states
	if states.size() != 3:
		return false
	var starts := gerencia.campaign.current_map.get_ppp_start_positions()
	for index in states.size():
		states[index].position = starts[index]
	# Companheiros não ocupam um hex lógico no mapa novo. O Gatinho pode
	# passear VISUALMENTE sobre o ground, sem bloquear nem revelar; só a Skill
	# Sexto-Sentido fixa sua posição num hex e revela os encontros vizinhos.
	for companion in gerencia.campaign.companion_states:
		companion.position = EntityState.UNPLACED
	if reset_turn_cycle or cycle_number == 0:
		cycle_number = 1
		current_actor = null
		_turn_committed = false
		_has_moved_this_turn = false
		_reopened_extra_movement = false
		for state in states:
			state.clear_round_stamina_penalty()
			state.extra_movement_sources.clear()
			state.turn_state = EntityState.TurnState.AVAILABLE
			state.stamina_remaining = state.max_stamina
		cycle_started.emit(cycle_number)
		if preferred_actor != null and preferred_actor in states \
				and preferred_actor.current_health > 0:
			select_actor(preferred_actor.playable_slot_id)
		else:
			_select_default_actor()
	else:
		# A troca de mapa não concede outro turno ao personagem do Portal.
		if current_actor == null:
			_select_default_actor()
	_sync_view()
	map_entered.emit(gerencia.campaign.current_map)
	return true


## A ordem sugerida é Playable_1, 2, 3. Antes de agir, o jogador pode trocar
## para qualquer outra vaga AVAILABLE; a anterior volta a ficar disponível.
func select_actor(slot_id: StringName) -> bool:
	if not _can_choose_turn():
		return false
	var chosen := gerencia.campaign.get_playable_slot(slot_id)
	if chosen == null or chosen.current_health <= 0:
		return false
	if not gerencia.campaign.can_act_during_solo(chosen):
		return false
	if chosen == current_actor:
		return true
	if chosen.turn_state != EntityState.TurnState.AVAILABLE or _turn_committed:
		return false
	if current_actor != null:
		current_actor.turn_state = EntityState.TurnState.AVAILABLE
	current_actor = chosen
	chosen.turn_state = EntityState.TurnState.TURNING
	var turn_key := StringName("%d:%d" % [gerencia.campaign.get_round_index(), cycle_number])
	var is_new_turn := chosen.last_exploration_cycle_key != turn_key
	if is_new_turn:
		chosen.last_exploration_cycle_key = turn_key
		chosen.turn_serial += 1
		chosen.extra_movement_sources.clear()
		gerencia.campaign.on_temporary_event_turn_started(chosen)
		# Voltar a selecionar o mesmo personagem antes de agir NÃO inicia outro
		# turno: passivas e efeitos atrasados só disparam na primeira seleção.
		player_skill_manager.on_owner_turn_started(chosen, gerencia.campaign)
	if chosen.current_health <= 0 or player_skill_manager.skill_manager.debuff_manager.has_control(
			chosen, DebuffData.ControlEffect.LOSE_TURN):
		# Atordoado realmente perde o turno: a interface não precisa pedir
		# que o jogador aperte "passar" em um personagem sem ações possíveis.
		_finish_current_turn()
		return true
	_sync_view()
	turn_started.emit(chosen)
	return true


func select_next_available_actor() -> bool:
	if not _can_choose_turn() or _turn_committed:
		return false
	var states := gerencia.campaign.active_entity_states
	if states.is_empty():
		return false
	var current_index := states.find(current_actor)
	for offset in range(1, states.size() + 1):
		var candidate := states[(current_index + offset) % states.size()]
		if candidate != current_actor and candidate.current_health > 0 \
				and candidate.turn_state == EntityState.TurnState.AVAILABLE:
			return select_actor(candidate.playable_slot_id)
	return false


## Outras ações de Exploração podem avisar que o turno já começou. Isso
## impede trocar de personagem depois de usar um item/Skill e antes de andar.
func commit_current_turn_action() -> bool:
	if current_actor == null or _awaiting_block or gerencia.campaign.is_terminal():
		return false
	_turn_committed = true
	return true


func get_available_destinations() -> Dictionary:
	if current_actor == null or not _can_move_now():
		return {}
	var grid := gerencia.campaign.current_map
	if current_actor.unlimited_exploration_movement:
		var destinations := {}
		for coord in grid.cells:
			if grid.can_choose_ppp_destination(coord, current_actor.position,
					_occupied_coords()) and grid.get_ppp_block_resource(coord) != null:
				destinations[coord] = 0
		return destinations
	var range_limit := current_actor.stamina_remaining
	if catastrophe_manager != null:
		range_limit = catastrophe_manager.allowed_movement_distance(current_actor, range_limit)
	if _can_fly(current_actor):
		var flying_destinations := {}
		for coord in grid.cells:
			var distance := HexGrid.distance(current_actor.position, coord)
			if distance <= range_limit and grid.can_choose_ppp_destination(
					coord, current_actor.position, _occupied_coords()) \
					and grid.get_ppp_block_resource(coord) != null:
				flying_destinations[coord] = distance
		var flying_emergency := _find_emergency_destination(current_actor)
		if flying_emergency != EntityState.UNPLACED:
			flying_destinations[flying_emergency] = HexGrid.distance(
				current_actor.position, flying_emergency)
		return flying_destinations
	var reachable := grid.get_ppp_reachable_hexes(current_actor.position, range_limit)
	var available := grid.get_ppp_available_destinations(reachable, current_actor.position, _occupied_coords())
	for coord in available.keys():
		var path := grid.get_ppp_movement_path(current_actor.position, coord, range_limit)
		if not player_skill_manager.skill_manager.debuff_manager.can_follow_path(current_actor, path):
			available.erase(coord)
	var emergency := _find_emergency_destination(current_actor)
	if emergency != EntityState.UNPLACED:
		var long_path := grid.get_ppp_movement_path(current_actor.position,
			emergency, HexGrid.PPP_MAP_WIDTH * HexGrid.PPP_MAP_HEIGHT + 1)
		available[emergency] = long_path.size()
	return available


func get_emergency_destination() -> Vector2i:
	return _find_emergency_destination(current_actor) if _can_move_now() \
		else EntityState.UNPLACED


func _find_emergency_destination(actor: EntityState) -> Vector2i:
	# A saída de emergência é individual: outro jogável alcançar um bloco não
	# resolve o personagem ilhado (especialmente se ele for o último vivo).
	if actor == null or _actor_can_reach_block(actor):
		return EntityState.UNPLACED
	var grid := gerencia.campaign.current_map
	var nearest := 999
	var chosen := EntityState.UNPLACED
	var occupied := _occupied_coords()
	var flying := _can_fly(actor)
	for coord in grid.cells:
		if not grid.can_choose_ppp_destination(coord, actor.position, occupied) \
				or grid.get_ppp_block_resource(coord) == null:
			continue
		var distance := HexGrid.distance(actor.position, coord)
		if not flying:
			var path := grid.get_ppp_movement_path(actor.position, coord,
				HexGrid.PPP_MAP_WIDTH * HexGrid.PPP_MAP_HEIGHT + 1)
			if path.is_empty() or not player_skill_manager.skill_manager.debuff_manager.can_follow_path(
					actor, path):
				continue
			distance = path.size()
		if distance >= nearest:
			continue
		nearest = distance
		chosen = coord
	return chosen


func _actor_can_reach_block(actor: EntityState) -> bool:
	var grid := gerencia.campaign.current_map
	var debuffs := player_skill_manager.skill_manager.debuff_manager
	var occupied := _occupied_coords()
	if actor.unlimited_exploration_movement:
		for coord in grid.cells:
			if grid.can_choose_ppp_destination(coord, actor.position, occupied) \
					and grid.get_ppp_block_resource(coord) != null:
				return true
		return false
	var range_limit := actor.stamina_remaining
	if catastrophe_manager != null:
		range_limit = catastrophe_manager.allowed_movement_distance(actor, range_limit)
	if _can_fly(actor):
		for coord in grid.cells:
			if HexGrid.distance(actor.position, coord) <= range_limit \
					and grid.can_choose_ppp_destination(coord, actor.position, occupied) \
					and grid.get_ppp_block_resource(coord) != null:
				return true
		return false
	var reachable := grid.get_ppp_reachable_hexes(actor.position, range_limit)
	for coord in grid.get_ppp_available_destinations(reachable, actor.position, occupied):
		if grid.get_ppp_block_resource(coord) == null:
			continue
		var path := grid.get_ppp_movement_path(actor.position, coord, range_limit)
		if debuffs.can_follow_path(actor, path):
			return true
	return false


func refresh_map_feedback() -> void:
	_sync_view()


func _on_catastrophe_changed(_event_id: StringName) -> void:
	_sync_view.call_deferred()


## A Informação libera o botão, mas a troca de mapa só é segura quando não
## existe bloco, combate ou escolha esperando resposta. O turno de outro
## personagem pode estar aberto: ele será encerrado pela nova Rodada.
func can_leave_map_now() -> bool:
	if not _can_choose_turn() or gerencia.campaign.active_entity_states.size() != 3:
		return false
	if gerencia.campaign.solo_turns_remaining > 0:
		return false
	for state in gerencia.campaign.active_entity_states:
		if state.current_health > 0:
			return true
	return false


## Um clique escolhe UM destino. O caminho pode atravessar hexes resolvidos,
## mas só termina em hex ativável e desocupado. A Stamina gasta é guardada no
## EntityState; não volta a cada clique. O turno termina após resolver o hex.
func try_move(destination: Vector2i) -> bool:
	if not _can_move_now():
		return _reject("Não é possível mover agora: há uma resolução pendente ou não há turno ativo.")
	var actor := current_actor
	var grid := gerencia.campaign.current_map
	if not grid.can_choose_ppp_destination(destination, actor.position, _occupied_coords()):
		return _reject("O destino não é um hexágono ativável e desocupado.")
	var unlimited := actor.unlimited_exploration_movement
	var flying := not unlimited and _can_fly(actor)
	var range_limit := actor.stamina_remaining
	if not unlimited and catastrophe_manager != null:
		range_limit = catastrophe_manager.allowed_movement_distance(actor, range_limit)
	var reachable := grid.get_ppp_reachable_hexes(actor.position, range_limit) \
		if not unlimited else {}
	var emergency := destination == _find_emergency_destination(actor)
	if not unlimited and not flying and not reachable.has(destination) and not emergency:
		return _reject("O destino está além da Stamina restante.")
	if flying and HexGrid.distance(actor.position, destination) > range_limit and not emergency:
		return _reject("O destino está além da Stamina restante.")
	if grid.get_ppp_block_resource(destination) == null:
		return _reject("O destino ainda não tem um Resource para ativar.")
	var path: Array[Vector2i] = []
	if emergency and flying:
		path.append(destination)
	elif emergency:
		path = grid.get_ppp_movement_path(actor.position, destination,
			HexGrid.PPP_MAP_WIDTH * HexGrid.PPP_MAP_HEIGHT + 1)
	elif unlimited or flying:
		path.append(destination)
	else:
		path = grid.get_ppp_movement_path(actor.position, destination, range_limit)
	if not unlimited and not player_skill_manager.skill_manager.debuff_manager.can_follow_path(actor, path):
		return _reject("Um Debuff impede este percurso.")
	if path.is_empty():
		return _reject("Não há caminho disponível para esse bloco.")
	var cost: int = 0 if unlimited else (actor.stamina_remaining if emergency \
		else HexGrid.distance(actor.position, destination) if flying \
		else int(reachable[destination]))
	if not unlimited and not flying and not emergency and path.size() != cost:
		return _reject("O caminho e seu custo não coincidem.")
	if catastrophe_manager != null and not catastrophe_manager.before_action(actor):
		_finish_current_turn()
		return true
	var origin := actor.position
	actor.stamina_remaining -= cost
	if _has_moved_this_turn and not player_skill_manager.consume_extra_movement(actor, gerencia.campaign):
		actor.stamina_remaining += cost
		return _reject("O movimento extra não pôde aplicar seus efeitos.")
	actor_will_arrive.emit(actor, destination)
	actor.position = destination
	# As três marcas da StartZone só existem até o respectivo personagem sair.
	if grid.is_ppp_start_zone(origin) and gerencia.map_view != null:
		gerencia.map_view.retire_start_marker(origin)
	_turn_committed = true
	_has_moved_this_turn = true
	_sync_view()
	if unlimited:
		actor_teleported.emit(actor, destination)
	else:
		actor_moved.emit(actor, path, cost)
	if catastrophe_manager != null:
		catastrophe_manager.on_movement_finished(actor, cost)
	player_skill_manager.skill_manager.on_entity_moved(actor, gerencia.campaign)
	if actor.current_health <= 0:
		_finish_current_turn()
		return true
	player_skill_manager.on_exploration_destination_reached(actor, gerencia.campaign, destination)
	_awaiting_block = true
	if player_skill_manager.offer_before_block_activation(actor, destination):
		return true
	if not block_manager.begin_activation(destination, actor):
		_awaiting_block = false
		return _reject("O bloco não pôde iniciar sua resolução.")
	return true


## Quando o gerenciador de Skills recebe "não usar", a consequência normal
## do bloco começa. Aceitar a Skill é resolvido por ele, sem regra de
## personagem embutida nesta máquina de turnos.
func _on_normal_activation_requested(actor: EntityState, coord: Vector2i) -> void:
	if not _awaiting_block or actor != current_actor:
		return
	if not block_manager.begin_activation(coord, actor):
		_awaiting_block = false
		_reject("O bloco não pôde iniciar sua resolução após a escolha de Skill.")


## Passar sem mover é explícito; zerar Stamina sozinho não encerra o turno,
## pois o personagem pode ter outras ações antes de passar.
func pass_turn() -> bool:
	if current_actor == null or _awaiting_block or gerencia.campaign.is_terminal():
		return false
	_finish_current_turn()
	return true


## Usado pelo teleporte de Evento depois do OK do Outcome. Não gasta Stamina;
## o bloco de chegada entra pelo mesmo BlockManager de qualquer movimento.
func arrive_from_event(destination: Vector2i, actor: EntityState) -> bool:
	if actor == null or actor != current_actor or not _can_choose_turn():
		return false
	var grid := gerencia.campaign.current_map
	if not grid.can_choose_ppp_destination(destination, actor.position,
			_occupied_coords()) or grid.get_ppp_block_resource(destination) == null:
		return false
	actor_will_arrive.emit(actor, destination)
	actor.position = destination
	_turn_committed = true
	_has_moved_this_turn = true
	_sync_view()
	actor_teleported.emit(actor, destination)
	_awaiting_block = true
	if player_skill_manager.offer_before_block_activation(actor, destination):
		return true
	if not block_manager.begin_activation(destination, actor):
		_awaiting_block = false
		return false
	return true


func can_reactivate_extra_movement(actor: EntityState,
		grant: SkillGrantState) -> bool:
	if actor == null or grant == null or actor.turn_state != EntityState.TurnState.INACTIVE \
			or actor.current_health <= 0 or not _can_choose_turn() \
			or _turn_committed or _has_moved_this_turn:
		return false
	var turn_key := StringName("%d:%d" % [gerencia.campaign.get_round_index(), cycle_number])
	return actor.last_exploration_cycle_key == turn_key \
		and player_skill_manager.skill_manager.can_reactivate_extra_movement(
			actor, grant, gerencia.campaign)


func reactivate_extra_movement(actor: EntityState, grant: SkillGrantState) -> bool:
	if not can_reactivate_extra_movement(actor, grant):
		return false
	var previous := current_actor
	if previous != null:
		previous.turn_state = EntityState.TurnState.AVAILABLE
	current_actor = actor
	actor.turn_state = EntityState.TurnState.TURNING
	# A mesma instância de turno continua: não repetir gatilhos de início.
	if not player_skill_manager.skill_manager.use_exploration_active(
			actor, actor, grant, gerencia.campaign, EntityState.UNPLACED,
			block_manager, gerencia.map_view):
		actor.turn_state = EntityState.TurnState.INACTIVE
		current_actor = previous
		if previous != null:
			previous.turn_state = EntityState.TurnState.TURNING
		return false
	_reopened_extra_movement = true
	_has_moved_this_turn = true
	_turn_committed = true
	_sync_view()
	player_skill_manager.exploration_active_resolved.emit(actor,
		grant.skill as ActiveSkillData, EntityState.UNPLACED)
	turn_started.emit(actor)
	return true


func _on_block_finished(result: Dictionary) -> void:
	if not _awaiting_block or result.get("actor") != current_actor:
		return
	_awaiting_block = false
	if (result.get("details", {}) as Dictionary).get("deferred_world_transition", false):
		# EventExecutor terminará o teleporte/troca de mapa após o jogador ler
		# e confirmar o Outcome. Não selecionar outro turno neste mapa antigo.
		return
	# GerenciaJogo já notificou as passivas pela concessão central; não duplicar.
	if gerencia.campaign.is_terminal():
		return
	if current_actor.current_health > 0 and not current_actor.extra_movement_sources.is_empty():
		_sync_view()
		return
	_finish_current_turn()


func _finish_current_turn() -> void:
	if gerencia != null and gerencia.campaign.is_terminal():
		return
	var finished := current_actor
	if gerencia != null and gerencia.map_view != null:
		gerencia.map_view.clear_temporary_inspection(finished)
	if not _reopened_extra_movement:
		player_skill_manager.skill_manager.on_entity_turn_finished(finished, gerencia.campaign)
	gerencia.campaign.on_temporary_event_turn_finished(finished)
	_reopened_extra_movement = false
	finished.extra_movement_sources.clear()
	finished.turn_state = EntityState.TurnState.INACTIVE
	current_actor = null
	_turn_committed = false
	_has_moved_this_turn = false
	# Catástrofe/Debuff podem matar antes mesmo de um bloco ser ativado.
	# Resultados de Evento passam aqui somente após o jogador confirmá-los.
	if finished.current_health <= 0 and gerencia != null \
			and player_skill_manager != null:
		gerencia.campaign.finalize_dead_playables(
			player_skill_manager.skill_manager)
		if gerencia.campaign.is_terminal():
			gerencia.request_terminal_record()
	turn_finished.emit(finished)
	# Um efeito no fim do turno pode ter matado o último jogável. Não iniciar
	# outro ciclo nem escolher personagem depois da derrota definitiva.
	if gerencia.campaign.is_terminal():
		_sync_view()
		return
	if gerencia.campaign.solo_turns_remaining > 0:
		# Só o dono recebe as três próximas vezes. Cada vez precisa de um
		# ciclo novo para avançar turn_serial e disparar os gatilhos novamente.
		cycle_number += 1
		for state in gerencia.campaign.active_entity_states:
			if state.current_health <= 0:
				continue
			state.turn_state = EntityState.TurnState.AVAILABLE \
				if gerencia.campaign.is_solo_owner(state) else EntityState.TurnState.INACTIVE
			if gerencia.campaign.is_solo_owner(state):
				state.stamina_remaining = state.max_stamina
		cycle_started.emit(cycle_number)
		_select_default_actor()
		return
	var eligible := 0
	var still_available := 0
	for state in gerencia.campaign.active_entity_states:
		if state.current_health <= 0:
			continue
		eligible += 1
		if state.turn_state == EntityState.TurnState.AVAILABLE:
			still_available += 1
	if eligible > 0 and still_available == 0:
		cycle_number += 1
		for state in gerencia.campaign.active_entity_states:
			if state.current_health > 0:
				state.turn_state = EntityState.TurnState.AVAILABLE
				state.stamina_remaining = state.max_stamina
		cycle_started.emit(cycle_number)
	_select_default_actor()


func _select_default_actor() -> void:
	for state in gerencia.campaign.active_entity_states:
		if state.current_health > 0 and state.turn_state == EntityState.TurnState.AVAILABLE \
				and gerencia.campaign.can_act_during_solo(state):
			select_actor(state.playable_slot_id)
			return
	_sync_view()


func _occupied_coords() -> Dictionary:
	var occupied: Dictionary = {}
	for state in gerencia.campaign.active_entity_states:
		if state != current_actor and state.current_health > 0:
			occupied[state.position] = true
	for companion in gerencia.campaign.companion_states:
		if companion.current_health > 0 and gerencia.campaign.current_map.is_valid(companion.position):
			occupied[companion.position] = true
	return occupied


func _can_preview_destination(coord: Vector2i) -> bool:
	if not _can_move_now() or player_skill_manager == null \
			or player_skill_manager.skill_manager == null or gerencia == null \
			or gerencia.campaign.current_map == null:
		return false
	var grid := gerencia.campaign.current_map
	if coord == _find_emergency_destination(current_actor):
		return true
	var range_limit := current_actor.stamina_remaining
	if catastrophe_manager != null:
		range_limit = catastrophe_manager.allowed_movement_distance(current_actor, range_limit)
	var path := grid.get_ppp_movement_path(current_actor.position, coord,
		range_limit)
	return player_skill_manager.skill_manager.debuff_manager.can_follow_path(current_actor, path)


func _can_select_hex_for_ui(coord: Vector2i) -> bool:
	# Só pinta ciano quando o hex oferece uma ação real para este turno.
	if not _can_move_now():
		return false
	if get_available_destinations().has(coord):
		return true
	for option in player_skill_manager.get_exploration_skill_options(self):
		if not option["needs_tile"] or not option["implemented"]:
			continue
		if player_skill_manager.skill_manager.can_use_exploration_active(
				option["skill_owner"], current_actor, option["grant"],
				gerencia.campaign, coord, block_manager, gerencia.map_view):
			return true
	return false


func _sync_view() -> void:
	if gerencia == null or gerencia.map_view == null:
		return
	var view := gerencia.map_view
	view.set_occupied_coords(_occupied_coords())
	if current_actor != null:
		var range_limit := current_actor.stamina_remaining
		if catastrophe_manager != null:
			range_limit = catastrophe_manager.allowed_movement_distance(current_actor, range_limit)
		view.set_active_actor(current_actor.position, range_limit,
			current_actor.unlimited_exploration_movement, _can_fly(current_actor))
		view.set_emergency_destination(_find_emergency_destination(current_actor))
	else:
		view.set_active_actor(EntityState.UNPLACED, 0)
		view.set_emergency_destination(EntityState.UNPLACED)


func _can_choose_turn() -> bool:
	return gerencia != null and gerencia.campaign.current_map != null \
		and not gerencia.campaign.is_terminal() \
		and gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION \
		and block_manager != null and not block_manager.is_busy() \
		and player_skill_manager != null \
		and not player_skill_manager.has_pending_choice() \
		and not _awaiting_block


func _can_move_now() -> bool:
	return current_actor != null and _can_choose_turn() \
		and current_actor.turn_state == EntityState.TurnState.TURNING \
		and player_skill_manager.skill_manager != null \
		and player_skill_manager.skill_manager.debuff_manager.can_take_action(current_actor) \
		and (not _has_moved_this_turn or not current_actor.extra_movement_sources.is_empty())


func _can_fly(actor: EntityState) -> bool:
	if actor == null or player_skill_manager == null \
			or player_skill_manager.skill_manager == null:
		return false
	for grant in player_skill_manager.skill_manager.get_passive_grants(actor):
		if grant.skill is PassiveSkillData \
				and (grant.skill as PassiveSkillData).id == &"ps_00023":
			return true
	return false


func _reject(reason: String) -> bool:
	movement_rejected.emit(reason)
	return false
