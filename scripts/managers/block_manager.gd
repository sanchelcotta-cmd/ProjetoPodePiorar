class_name BlockManager
extends Node

## Resolve UM bloco por vez. Movimento e turnos pertencem à Exploração;
## escolhas, inventário, efeitos e combate pertencem aos seus executores.
## Até esses executores existirem, o bloco fica pendente e não é consumido.

enum Phase {
	IDLE,
	WAITING_ITEM,
	WAITING_EVENT,
	WAITING_COMBAT,
	RESOLVING_INFORMATION,
	WAITING_WOODEN_DOLL,
	WAITING_SOLO_CRICKET,
}

enum CompletionKind {
	INFORMATION_OBTAINED,
	ITEM_COLLECTED,
	ITEM_LEFT,
	EVENT_RESOLVED,
	EVENT_PREVENTED,
	ENCOUNTER_RESOLVED,
}

signal block_started(context: Dictionary)
signal item_decision_requested(context: Dictionary)
signal information_confirmation_requested(context: Dictionary)
signal event_confirmation_requested(context: Dictionary)
signal wooden_doll_cancel_requested(context: Dictionary)
signal event_resolution_requested(context: Dictionary)
signal encounter_confirmation_requested(context: Dictionary)
signal solo_cricket_requested(context: Dictionary)
signal combat_requested(context: Dictionary)
signal combat_returned_to_event(context: Dictionary, combat_result: Dictionary)
signal block_finished(result: Dictionary)

# Vincular ao nó GerenciaJogo quando a cena de jogo for montada.
@export var gerencia: GerenciaJogo
# Na cena com a caixa narrativa, esperar o botão do jogador. Nos testes e
# controladores sem UI, o comportamento antigo continua disponível.
@export var require_event_confirmation: bool = false
@export var require_encounter_confirmation: bool = false
@export var require_information_confirmation: bool = false

var _phase: Phase = Phase.IDLE
var _grid: HexGrid
var _coord: Vector2i
var _content: Resource
var _original_block_type: int = HexGrid.PPPBlockType.NONE
var _actor: Variant = null
var _origin_mode: int = HexGrid.PPPMapMode.EXPLORATION
var _combat_from_event: bool = false
var _combat_encounter: EncounterData
var _combat_announced: bool = false
var _event_announced: bool = false
var last_information_grant_result: Dictionary = {}
var _debug_virtual := false
var _debug_force := false


func is_busy() -> bool:
	return _phase != Phase.IDLE


func get_phase() -> Phase:
	return _phase


func get_pending_context() -> Dictionary:
	return _context() if is_busy() else {}


## A Exploração chama ao chegar ao destino, ou ao clicar no próprio hex.
## No Combate, só Armadilhas podem entrar por aqui: andar sobre um Evento
## comum não o ativa.
func begin_activation(coord: Vector2i, actor: Variant = null) -> bool:
	if not _can_begin(coord):
		return false
	var grid := gerencia.campaign.current_map
	var block_type := grid.get_ppp_block_type(coord)
	var content := grid.get_ppp_block_resource(coord)
	if content is Informacao and block_type == HexGrid.PPPBlockType.INFORMATION:
		_set_pending(grid, coord, content, actor, Phase.RESOLVING_INFORMATION)
		block_started.emit(_context())
		if require_information_confirmation:
			information_confirmation_requested.emit(_context())
		else:
			confirm_information()
		return true
	if content is ItemData and block_type in [
		HexGrid.PPPBlockType.CONSUMABLE,
		HexGrid.PPPBlockType.EQUIPMENT,
		HexGrid.PPPBlockType.CURSE,
	]:
		_set_pending(grid, coord, content, actor, Phase.WAITING_ITEM)
		block_started.emit(_context())
		var context := _context()
		context["can_decline"] = block_type != HexGrid.PPPBlockType.CURSE
		item_decision_requested.emit(context)
		return true
	if content is EncounterData and block_type == HexGrid.PPPBlockType.ENCOUNTER:
		if gerencia.campaign.solo_turns_remaining > 0:
			# Uma troca de mapa ou outro efeito pode criar Encontro durante o solo.
			# Sem conversão prévia, ele ainda oferece só o silêncio dos grilos.
			_set_pending(grid, coord, content, actor, Phase.WAITING_SOLO_CRICKET)
			block_started.emit(_context())
			solo_cricket_requested.emit(_context())
			return true
		_set_pending(grid, coord, content, actor, Phase.WAITING_COMBAT)
		_combat_encounter = content
		block_started.emit(_context())
		if require_encounter_confirmation:
			encounter_confirmation_requested.emit(_context())
		else:
			_emit_combat_request({"encounter": content})
		return true
	if content is EventData and block_type in [
		HexGrid.PPPBlockType.EVENT,
		HexGrid.PPPBlockType.CATASTROPHE,
		HexGrid.PPPBlockType.TRAP,
	]:
		var owner := actor as EntityState
		if owner != null and block_type in [HexGrid.PPPBlockType.TRAP,
				HexGrid.PPPBlockType.CATASTROPHE] \
				and (content as EventData).valence == EventData.Valence.BAD \
				and gerencia.campaign.has_wooden_doll(owner):
			_set_pending(grid, coord, content, actor, Phase.WAITING_WOODEN_DOLL)
			block_started.emit(_context())
			wooden_doll_cancel_requested.emit(_context())
			return true
		if not gerencia.record_event_activated(content):
			return false
		_set_pending(grid, coord, content, actor, Phase.WAITING_EVENT)
		block_started.emit(_context())
		# O controlador pode oferecer escolhas ou usar uma Skill antes de pedir
		# ao futuro executor que aplique os Outcomes/Effects do EventData.
		if require_event_confirmation:
			event_confirmation_requested.emit(_context())
		else:
			_event_announced = true
			event_resolution_requested.emit(_context())
		return true
	return false


## Conteúdo de debug usa o mesmo executor e combate, mas nenhum hex real.
## Não escreve no grid nem consome Encontros já sorteados.
func begin_debug_content(content: Resource, actor: EntityState,
		force: bool = false, outcome_id: StringName = &"") -> Dictionary:
	if not OS.has_feature("debug") \
			or not bool(ProjectSettings.get_setting("ppp/debug/enabled", false)):
		return {"success": false, "reason": "Debug indisponível nesta versão."}
	if is_busy() or gerencia == null or gerencia.campaign == null \
			or gerencia.campaign.current_map == null or gerencia.campaign.is_terminal():
		return {"success": false, "reason": "Conclua a ação atual antes de abrir conteúdo de debug."}
	if actor == null or actor.current_health <= 0 \
			or actor not in gerencia.campaign.active_entity_states:
		return {"success": false, "reason": "Selecione um jogável vivo."}
	if gerencia.campaign.current_map.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION:
		return {"success": false, "reason": "Eventos e Encontros virtuais exigem Exploração."}
	if content is EventData:
		var event := content as EventData
		if not force and not EventCampaignEligibility.allows_event(
				event, gerencia.campaign.campaign_mode):
			return {"success": false, "reason": "Evento excluído deste modo. Use Forçar (debug)."}
		if not gerencia.record_event_activated(event):
			return {"success": false, "reason": "O Evento não pôde ser registrado."}
		_set_pending(gerencia.campaign.current_map, EntityState.UNPLACED,
			event, actor, Phase.WAITING_EVENT)
		_debug_virtual = true
		_debug_force = force
		block_started.emit(_context())
		if outcome_id != &"":
			_event_announced = true
			var context := _context()
			context["decision"] = {"outcome_id": outcome_id, "accepted": true}
			event_resolution_requested.emit(context)
		else:
			event_confirmation_requested.emit(_context())
		return {"success": true, "virtual": true}
	if content is EncounterData:
		var encounter := content as EncounterData
		if not encounter.has_valid_composition():
			return {"success": false, "reason": "Encontro sem composição válida."}
		_set_pending(gerencia.campaign.current_map, EntityState.UNPLACED,
			encounter, actor, Phase.WAITING_COMBAT)
		_debug_virtual = true
		_debug_force = force
		_combat_encounter = encounter
		block_started.emit(_context())
		encounter_confirmation_requested.emit(_context())
		return {"success": true, "virtual": true}
	return {"success": false, "reason": "O Resource não é Evento nem Encontro."}


func confirm_solo_cricket() -> bool:
	if _phase != Phase.WAITING_SOLO_CRICKET:
		return false
	_finish(CompletionKind.ENCOUNTER_RESOLVED,
		{"suppressed_by_event": &"ev_00054", "cricket": true})
	return true


## A caixa envia a escolha; o executor recebe a decisão no contexto. Não
## marcamos o evento como resolvido até seus efeitos terminarem de verdade.
func confirm_event_action(decision: Dictionary = {}) -> bool:
	if _phase != Phase.WAITING_EVENT or not _content is EventData or _event_announced:
		return false
	_event_announced = true
	var context := _context()
	context["decision"] = decision.duplicate()
	event_resolution_requested.emit(context)
	return true


## O bloqueio e o Bonequinho permanecem visíveis até o OK da caixa.
func confirm_wooden_doll_cancellation() -> bool:
	if _phase != Phase.WAITING_WOODEN_DOLL or not _content is EventData:
		return false
	var owner := _actor as EntityState
	if owner == null or not gerencia.campaign.has_wooden_doll(owner):
		return false
	var event := _content as EventData
	if not gerencia.record_event_prevented(event):
		return false
	if gerencia.map_view != null and gerencia.map_view.grid == _grid:
		gerencia.map_view.destroy_block(_coord)
	else:
		_grid.destroy_ppp_block(_coord)
	if not gerencia.campaign.consume_wooden_doll(owner):
		return false
	_finish(CompletionKind.EVENT_PREVENTED,
		{"wooden_doll": true, "event_id": event.id})
	return true


## Encontro só entra em Combate quando o jogador confirma esta chamada.
func confirm_encounter() -> bool:
	if _phase != Phase.WAITING_COMBAT or not _content is EncounterData \
			or _combat_announced:
		return false
	_emit_combat_request({"encounter": _combat_encounter})
	return true


func confirm_information() -> bool:
	if _phase != Phase.RESOLVING_INFORMATION or not _content is Informacao:
		return false
	last_information_grant_result = gerencia.grant_information(
		_content as Informacao, &"hex")
	if not last_information_grant_result.get("success", false):
		return false
	_finish(CompletionKind.INFORMATION_OBTAINED)
	return true


## O inventário confirma isto DEPOIS de adicionar o item, ou após o jogador
## decidir deixá-lo. Maldições não podem ser recusadas nesta etapa.
func finish_item_resolution(collected: bool) -> bool:
	if _phase != Phase.WAITING_ITEM:
		return false
	if not collected and _grid.get_ppp_block_type(_coord) == HexGrid.PPPBlockType.CURSE \
			and not (_actor is EntityState and _actor.is_curse_immune()) \
			and not (gerencia != null and gerencia.campaign != null \
				and gerencia.campaign.has_sacred_temple_blessing()):
		return false
	_finish(CompletionKind.ITEM_COLLECTED if collected else CompletionKind.ITEM_LEFT)
	return true


## O executor chama somente após concluir escolhas, efeitos e possíveis
## combates iniciados pelo Evento. O BlockManager não finge aplicar efeitos.
func finish_event_resolution(details: Dictionary = {}) -> bool:
	if _phase != Phase.WAITING_EVENT:
		return false
	_finish(CompletionKind.EVENT_RESOLVED, details)
	return true


## Um efeito START_COMBAT de Evento/Armadilha pode chamar isto. O bloco
## continuará pendente até o Combate terminar E o executor finalizar o Evento.
func request_combat_from_event(combat_request: Dictionary) -> bool:
	if _phase != Phase.WAITING_EVENT:
		return false
	_combat_from_event = true
	_combat_encounter = combat_request.get("encounter") as EncounterData
	_phase = Phase.WAITING_COMBAT
	_emit_combat_request(combat_request)
	return true


## Recebe a resposta do futuro CombatManager. Encontro direto termina o
## bloco; combate disparado por Evento devolve o controle ao executor dele.
func finish_combat(combat_result: Dictionary = {}) -> bool:
	if _phase != Phase.WAITING_COMBAT or not _combat_announced:
		return false
	if _grid != null:
		if gerencia.map_view != null and gerencia.map_view.grid == _grid:
			gerencia.map_view.set_map_mode(_origin_mode)
		else:
			_grid.ppp_map_mode = _origin_mode
	if _combat_encounter != null:
		gerencia.record_encounter_occurred(_combat_encounter)
		gerencia.campaign.record_completed_encounter(_combat_encounter)
	_combat_encounter = null
	if _combat_from_event:
		_combat_from_event = false
		_phase = Phase.WAITING_EVENT
		combat_returned_to_event.emit(_context(), combat_result.duplicate())
	else:
		_finish(CompletionKind.ENCOUNTER_RESOLVED, combat_result)
	return true


## O BlockManager só confirma e encerra a mudança do hex. Saber se uma
## habilidade PODE destruí-lo, quais valências aceita e quantos usos restam
## pertence ao SkillManager e ao SkillEffectExecutor.
func can_destroy_landed_event(coord: Vector2i) -> bool:
	return _can_begin(coord) \
		and gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION \
		and gerencia.campaign.current_map.get_ppp_block_resource(coord) is EventData


func destroy_event_before_activation(coord: Vector2i, actor: EntityState, skill_id: StringName) -> bool:
	if not can_destroy_landed_event(coord):
		return false
	var grid := gerencia.campaign.current_map
	var event := grid.get_ppp_block_resource(coord) as EventData
	if not gerencia.record_event_prevented(event):
		return false
	_set_pending(grid, coord, event, actor, Phase.WAITING_EVENT)
	block_started.emit(_context())
	grid.destroy_ppp_block(coord)
	if gerencia.map_view != null and gerencia.map_view.grid == grid:
		gerencia.map_view.destroy_block(coord)
	_finish(CompletionKind.EVENT_PREVENTED, {"skill_id": skill_id})
	return true


func _can_begin(coord: Vector2i) -> bool:
	if is_busy() or gerencia == null or gerencia.campaign.current_map == null:
		return false
	if gerencia.campaign.is_terminal():
		return false
	var grid := gerencia.campaign.current_map
	var cell := grid.get_cell(coord)
	if cell == null or cell.state not in [HexGrid.PPPBlockState.HIDDEN, HexGrid.PPPBlockState.REVEALED]:
		return false
	if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT and cell.block_type != HexGrid.PPPBlockType.TRAP:
		return false
	return grid.get_ppp_block_resource(coord) != null


func _set_pending(grid: HexGrid, coord: Vector2i, content: Resource, actor: Variant, phase: Phase) -> void:
	_debug_virtual = false
	_debug_force = false
	_grid = grid
	_coord = coord
	_content = content
	_original_block_type = grid.get_ppp_block_type(coord)
	_actor = actor
	_origin_mode = grid.ppp_map_mode
	_phase = phase
	_combat_from_event = false
	_combat_encounter = null
	_combat_announced = false
	_event_announced = false


func _emit_combat_request(request: Dictionary) -> void:
	if _combat_announced:
		return
	_combat_announced = true
	if _grid != null:
		if gerencia.map_view != null and gerencia.map_view.grid == _grid:
			gerencia.map_view.set_map_mode(HexGrid.PPPMapMode.COMBAT)
		else:
			_grid.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	var context := _context()
	context["combat_request"] = request.duplicate()
	combat_requested.emit(context)


func _context() -> Dictionary:
	return {
		"map": _grid,
		"coord": _coord,
		"resource": _content,
		"actor": _actor,
		"block_type": _original_block_type,
		"origin_mode": _origin_mode,
		"debug_virtual": _debug_virtual,
		"debug_force": _debug_force,
	}


func _finish(kind: CompletionKind, details: Dictionary = {}) -> void:
	var cell := _grid.get_cell(_coord)
	# Um efeito pode ter destruído, cancelado ou SUBSTITUÍDO o hex enquanto
	# resolvia o bloco. Nunca ativar por engano o novo conteúdo do Saci.
	if cell != null and cell.resource_path == _content.resource_path and cell.state in [
		HexGrid.PPPBlockState.HIDDEN,
		HexGrid.PPPBlockState.REVEALED,
	]:
		_grid.activate_ppp_block(_coord)
		if gerencia.map_view != null and gerencia.map_view.grid == _grid:
			gerencia.map_view.activate_block(_coord)
	var result := _context()
	result["completion_kind"] = kind
	result["details"] = details.duplicate()
	result["final_block_state"] = cell.state if cell != null else HexGrid.PPPBlockState.DESTROYED
	_clear_pending()
	block_finished.emit(result)


func _clear_pending() -> void:
	_debug_virtual = false
	_debug_force = false
	_phase = Phase.IDLE
	_grid = null
	_content = null
	_original_block_type = HexGrid.PPPBlockType.NONE
	_actor = null
	_combat_from_event = false
	_combat_encounter = null
	_combat_announced = false
	_event_announced = false
