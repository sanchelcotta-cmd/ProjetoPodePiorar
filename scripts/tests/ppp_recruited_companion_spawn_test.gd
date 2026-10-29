extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
		load("res://resources/entities/entities_playable/mae.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha de teste iniciada.")
	var owner := gerencia.campaign.active_entity_states[0]
	owner.position = Vector2i(3, 2)
	var goblin_data := load("res://resources/entities/entities_general/goblin_1.tres") as EntityData
	var goblin := EntityState.from_encounter_member(goblin_data, &"ally_spawn_test",
		1, EntityState.UNPLACED)
	_check(gerencia.campaign.register_companion(owner, goblin),
		"Inimigo recrutado entra no grupo.")
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	var grid := gerencia.campaign.current_map
	grid.set_ppp_block(owner.position, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	_check(block.begin_activation(owner.position, owner), "Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT,
		"Combate iniciou.")
	_check(grid.is_valid(goblin.position) and HexGrid.distance(
		goblin.position, owner.position) in [1, 2],
		"Aliado recrutado surge até dois hexes do dono.")
	var visual := combat._visual_for_actor(goblin)
	_check(visual != null and visual.is_ally and visual.visible,
		"Aliado recrutado aparece como silhueta azul no combate.")
	if not combat.enemies.is_empty():
		var enemy := combat.enemies[0]
		var converted := combat.convert_enemy_to_companion(owner, enemy,
			SkillEffectData.new(), false)
		var converted_visual := combat._visual_for_actor(enemy)
		_check(converted.get("success", false) and converted_visual != null \
			and converted_visual.is_ally,
			"Recrutamento em combate transforma a silhueta hostil em azul.")
	print("PPP recruited companion spawn: %d falha(s)" % failures)
	# A conversão agenda a remoção visual do aliado em 2,5 s; deixe-a terminar.
	await create_timer(2.6).timeout
	scene.queue_free()
	for index in 4:
		await process_frame
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
