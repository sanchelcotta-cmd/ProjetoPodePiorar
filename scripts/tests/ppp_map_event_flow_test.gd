extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var gnomes := scene.get_node("Gnomes2Manager") as Gnomes2Manager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha inicia com mapa completo.")
	var source := Vector2i(0, 1)
	var gnome_event := load(
		"res://resources/events/random_events/08-gnomos_do_caos_2.tres") as EventData
	_check(_activate(scene, source, gnome_event, {}),
		"08: hex, decisão, Outcome e OK concluídos.")
	_check(gnomes.active and gnomes.positions.size() == 3,
		"08: três gnomos estão presentes no mapa após OK.")
	gnomes.stop_effect()
	var grid := gerencia.campaign.current_map
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	grid.set_ppp_block(Vector2i(2, 1), HexGrid.PPPBlockType.INFORMATION, info)
	grid.reveal_ppp_block(Vector2i(2, 1))
	var saci := load(
		"res://resources/events/random_events/41-traquinagens_do_saci.tres") as EventData
	_check(_activate(scene, source, saci, {}),
		"41: redemoinho conclui o fluxo real do Evento.")
	_check(grid.get_cell(source).state == HexGrid.PPPBlockState.HIDDEN
		and grid.get_cell(source).resource_path != saci.resource_path,
		"41: o hex original vira outro conteúdo oculto, sem ativá-lo por engano.")
	_check(grid.get_cell(Vector2i(2, 1)).resource_path == info.resource_path
		and grid.get_cell(Vector2i(2, 1)).state == HexGrid.PPPBlockState.REVEALED,
		"41: Informação conserva Resource e estado.")
	for coord in grid.cells:
		grid.activate_ppp_block(coord)
	var teleport_destination := Vector2i(1, 1)
	grid.set_ppp_block(teleport_destination, HexGrid.PPPBlockType.INFORMATION, info)
	var teleport := load(
		"res://resources/events/random_events/30-voce_foi_teletransportado.tres") as EventData
	_check(_activate(scene, source, teleport, {}),
		"30: teleporte conclui o fluxo real do Evento.")
	_check(gerencia.campaign.active_entity_states[0].position == teleport_destination
		and (scene.get_node("BlockManager") as BlockManager).is_busy(),
		"30: o teleporte inicia a leitura do novo bloco, sem pulá-la.")
	popup._confirm_information()
	_check(gerencia.campaign.active_entity_states[0].position == teleport_destination
		and grid.get_cell(teleport_destination).state == HexGrid.PPPBlockState.ACTIVATED,
		"30: o ativador chega sem gastar alcance e resolve o novo bloco.")
	var portal := load(
		"res://resources/events/random_events/31-portal_magico.tres") as EventData
	var before_portal := gerencia.campaign.current_map
	var old_day := gerencia.campaign.day
	var old_period := gerencia.campaign.round_period
	_check(_activate(scene, source, portal,
		{"outcome": portal.outcomes[1], "outcome_id": portal.outcomes[1].id}),
		"31: recusa do Portal também conclui o Outcome.")
	_check(gerencia.campaign.current_map == before_portal
		and gerencia.campaign.day == old_day,
		"31: recusar preserva mapa e relógio.")
	_check(_activate(scene, source, portal,
		{"outcome": portal.outcomes[0], "outcome_id": portal.outcomes[0].id}),
		"31: Portal aceito conclui o fluxo real do Evento.")
	_check(gerencia.campaign.current_map != before_portal
		and gerencia.campaign.day == old_day
		and gerencia.campaign.round_period == old_period,
		"31: novo mapa sem avançar Dia/Rodada.")
	var abduction := load(
		"res://resources/events/random_events/29-voces_foram_abduzidos.tres") as EventData
	var before_abduction := gerencia.campaign.current_map
	var abducted_actor := gerencia.campaign.active_entity_states[0]
	_check(_activate(scene, source, abduction, {}),
		"29: Abdução conclui o fluxo real do Evento.")
	_check(gerencia.campaign.current_map != before_abduction
		and gerencia.campaign.day == old_day + 1
		and gerencia.campaign.round_period == old_period
		and gerencia.campaign.current_map.is_valid(abducted_actor.position),
		"29: novo mapa após um Dia, mantendo a fase.")
	print("PPP map event flow: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _activate(scene: PPPMapView, source: Vector2i,
		event: EventData, decision: Dictionary) -> bool:
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var grid := gerencia.campaign.current_map
	grid.set_ppp_block(source, HexGrid.PPPBlockType.EVENT, event)
	if not exploration.enter_map(true):
		push_warning("%s: enter_map recusou (bloco ocupado=%s)." % [event.id,
			str((scene.get_node("BlockManager") as BlockManager).is_busy())])
		return false
	if not exploration.try_move(source):
		push_warning("%s: try_move recusou; ator=%s." % [event.id,
			str(exploration.current_actor)])
		return false
	popup._confirm_event(decision)
	if not popup._outcome_reading:
		push_warning("%s: Outcome não abriu; feedback=%s." % [event.id,
			popup.feedback_label.text])
		return false
	popup._execute_prepared_event()
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
