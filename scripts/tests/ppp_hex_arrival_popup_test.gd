extends SceneTree

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var block := scene.get_node("BlockManager") as BlockManager
	var party := scene.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha de teste inicia.")
	if gerencia.campaign.current_map == null:
		quit(1)
		return
	var actor := exploration.current_actor
	var destination := Vector2i(0, actor.position.y)
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	gerencia.campaign.current_map.set_ppp_block(destination,
		HexGrid.PPPBlockType.INFORMATION, information)
	_check(exploration.arrive_from_event(destination, actor),
		"Teleporte ao hex inicia sua resolução.")
	var visual := party.visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	_check(visual != null and visual.position == PPPMapView.reference_hex_position(destination),
		"O personagem aparece no destino antes da caixa.")
	_check(block.is_busy() and not popup.overlay.visible,
		"A resolução fica reservada sem abrir a caixa imediatamente.")
	await create_timer(0.35).timeout
	_check(not popup.overlay.visible,
		"A caixa continua fechada durante a pausa de chegada.")
	await create_timer(0.25).timeout
	_check(popup.overlay.visible,
		"A caixa abre após a pausa de meio segundo.")
	popup._confirm_information()
	_check(not popup.overlay.visible and not block.is_busy(),
		"Confirmar encerra a resolução normalmente.")
	print("PPP_HEX_ARRIVAL_POPUP: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failures += 1
	push_error(description)
