extends SceneTree

## Armadilha só dispara ao parar no Combate e não substitui o Encontro pendente.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha inicia.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(3, 2)
	var trap_coord := Vector2i(3, 3)
	var grid := gerencia.campaign.current_map
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	var trap := load("res://resources/events/traps/79-prego_enferrujado.tres") as EventData
	gerencia.campaign.obtained_information_ids[&"trap_test_info"] = true
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	grid.set_ppp_block(trap_coord, HexGrid.PPPBlockType.TRAP, trap)
	_check(block.begin_activation(actor.position, actor), "Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": actor})
	combat._start_combat_turns()
	_check(combat.roll_player_turn_die() > 0, "Rolagem manual abre as ações.")
	_check(combat.can_player_move(trap_coord),
		"Armadilha é destino válido, independente do conteúdo.")
	_check(combat.player_move(trap_coord), "Jogável para na Armadilha.")
	_check(not combat._pending_trap.is_empty() and block.is_busy(),
		"A armadilha aguarda leitura sem apagar o Encontro pendente.")
	_check(grid.get_cell(trap_coord).state == HexGrid.PPPBlockState.HIDDEN,
		"Antes do OK, a armadilha não é aplicada.")
	_check(popup.overlay.visible, "A narração da Armadilha é exibida.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(combat._pending_trap.is_empty() and block.is_busy(),
		"OK aplica a Armadilha e conserva o Combate original.")
	_check(grid.get_cell(trap_coord).state == HexGrid.PPPBlockState.ACTIVATED,
		"A Armadilha passa a ativada somente após resolução.")
	var enemy := combat.enemies[0]
	var open_neighbor := Vector2i(4, 3)
	enemy.position = open_neighbor
	var mines := load("res://resources/events/traps/77-minas_explosivas.tres") as EventData
	var health_before := enemy.current_health
	var mine_result := (scene.get_node("EventExecutor") as EventExecutor).resolve_combat_trap(
		mines, actor, trap_coord, combat)
	_check(mine_result.get("success", false) and enemy.current_health < health_before,
		"Mina pode atingir hostil no raio, embora ele não a tenha acionado.")
	var alarm_coord := Vector2i(5, 3)
	grid.set_ppp_block(alarm_coord, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	var alarm := load("res://resources/events/traps/80-fio_de_alarme.tres") as EventData
	var enemy_count := combat.enemies.size()
	var alarm_result := (scene.get_node("EventExecutor") as EventExecutor).resolve_combat_trap(
		alarm, actor, trap_coord, combat)
	_check(alarm_result.get("success", false) and combat.enemies.size() > enemy_count \
		and not alarm_result.get("effects", []).is_empty() \
		and int(alarm_result["effects"][0].get("reinforcements", 0)) > 0,
		"Fio de Alarme incorpora o Encontro mais próximo como reforço.")
	_check(combat.request_victory() and combat.confirm_conclusion(),
		"Combate de teste encerra após conferir as armadilhas.")
	print("PPP combat trap: %d falhas" % failures)
	# Aguarda as animações assíncronas do combate soltarem suas referências.
	await create_timer(2.6).timeout
	scene.queue_free()
	for _frame in 4:
		await process_frame
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
