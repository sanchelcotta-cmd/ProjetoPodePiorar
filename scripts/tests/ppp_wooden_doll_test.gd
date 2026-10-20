extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var player_skills := scene.get_node("PlayerSkillManager") as PlayerSkillManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var companions := scene.get_node("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	var data: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	_check(gerencia.start_new_game(data) and round_manager.start_first_map(),
		"A campanha do Bonequinho inicia.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.turn_state = EntityState.TurnState.TURNING
	var origin := Vector2i(0, 0)
	actor.position = origin
	var doll_event := load("res://resources/events/random_events/43-boneco_de_madeira.tres") as EventData
	var grid := gerencia.campaign.current_map
	grid.set_ppp_block(origin, HexGrid.PPPBlockType.EVENT, doll_event)
	_check(block.begin_activation(origin, actor), "Recrutar o Bonequinho abre a caixa.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(gerencia.campaign.has_wooden_doll(actor) and not block.is_busy(),
		"O Outcome registra a proteção e libera o bloco.")
	var visual := companions.doll_visuals_by_owner_id.get(actor.instance_id) as EnemySilhouetteVisual
	_check(visual != null and visual.is_ally and visual.visible,
		"A silhueta azul provisória aparece junto do dono.")
	var destination := Vector2i(1, 0)
	actor.position = destination
	await create_timer(0.55).timeout
	if visual != null:
		_check(visual.position.distance_to(PPPMapView.reference_hex_position(destination)
			+ Vector2(-41.0, 3.0)) < 2.0,
			"O Bonequinho caminha atrás do dono quando ele muda de hex.")
	var trap := load("res://resources/events/traps/77-minas_explosivas.tres") as EventData
	grid.set_ppp_block(destination, HexGrid.PPPBlockType.TRAP, trap)
	var hp_before := actor.current_health
	_check(not player_skills.offer_before_block_activation(actor, destination),
		"O Bonequinho age antes da escolha preventiva do Pedreiro.")
	_check(block.begin_activation(destination, actor), "A armadilha aciona a proteção.")
	_check(popup.overlay.visible and popup.title_label.text ==
		"Bonequinho cancelou %s" % trap.display_name and
		popup.narrative_label.text == "Ufa?",
		"A caixa substitui a descrição ruim pelo texto pedido.")
	_check(gerencia.campaign.has_wooden_doll(actor) and
		grid.get_cell(destination).state == HexGrid.PPPBlockState.HIDDEN,
		"Antes do OK, nem Bonequinho nem bloco são removidos.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	await process_frame
	_check(not block.is_busy() and not gerencia.campaign.has_wooden_doll(actor)
		and not companions.doll_visuals_by_owner_id.has(actor.instance_id),
		"O OK consome o Bonequinho e retira seu visual.")
	_check(grid.get_cell(destination).state == HexGrid.PPPBlockState.DESTROYED
		and actor.current_health == hp_before,
		"A armadilha é destruída sem aplicar dano.")
	_check(gerencia.campaign.grant_wooden_doll(actor),
		"Uma segunda concessão permite testar Catástrofe.")
	var catastrophe := load("res://resources/events/catastrophes/72-nevasca.tres") as EventData
	var catastrophe_coord := Vector2i(2, 0)
	actor.position = catastrophe_coord
	grid.set_ppp_block(catastrophe_coord, HexGrid.PPPBlockType.CATASTROPHE, catastrophe)
	_check(block.begin_activation(catastrophe_coord, actor),
		"A mesma proteção intercepta Catástrofe ruim.")
	_check(popup.title_label.text == "Bonequinho cancelou %s" % catastrophe.display_name
		and popup.narrative_label.text == "Ufa?",
		"A Catástrofe também recebe apenas o aviso do Bonequinho.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(grid.get_cell(catastrophe_coord).state == HexGrid.PPPBlockState.DESTROYED
		and gerencia.campaign.active_catastrophes.is_empty(),
		"Confirmar a proteção não inicia a Catástrofe.")
	print("Bonequinho de Madeira: %d falhas." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
