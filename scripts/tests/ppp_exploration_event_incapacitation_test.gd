extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var skills := scene.get_node("SkillManager") as SkillManager
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	check(game.start_new_game(selected) and rounds.start_first_map(), "Campanha inicia.")
	var playables := game.campaign.active_entity_states
	var actor := playables[0] as EntityState
	actor.position = Vector2i(3, 2)
	var encounter := load("res://resources/encounters/enc_goblins.tres") as EncounterData
	game.campaign.current_map.set_ppp_block(actor.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(actor.position, actor), "Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not combat.enemies.is_empty(), "Combate inicia.")
	if combat.enemies.is_empty():
		quit(1)
		return
	var enemy := combat.enemies[0] as EntityState
	var applied := skills.debuff_manager.apply_by_id(actor, &"db_00002")
	var stun := applied.get("instance") as DebuffInstanceState
	check(stun != null, "Atordoamento de teste é aplicado.")
	if stun == null:
		quit(1)
		return
	stun.exploration_event_control = true
	stun.duration_kind = DebuffData.DurationType.TURNS
	stun.remaining_turns = 3
	check(actor not in combat._opponents_of(enemy),
		"IA não seleciona alvo protegido por evento de exploração.")
	var health_before := actor.current_health
	var incoming := skills.apply_incoming_damage(actor, 6, game.campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "damage_source": enemy,
			"direct_attack": true, "combat_id": &"test_incapacitation"})
	check(incoming.get("protected_by_exploration_event", false)
		and actor.current_health == health_before,
		"Ataque hostil não danifica o alvo protegido.")
	# O mesmo debuff reaplicado por um inimigo perde a origem protegida.
	var enemy_stun := skills.debuff_manager.apply_by_id(actor, &"db_00002", enemy)
	check(enemy_stun.get("success", false) and not stun.exploration_event_control
		and actor in combat._opponents_of(enemy),
		"Incapacitação causada por inimigo continua alvejada normalmente.")
	stun.exploration_event_control = true
	stun.duration_kind = DebuffData.DurationType.TURNS
	stun.remaining_turns = 3
	for index in range(1, playables.size()):
		(playables[index] as EntityState).current_health = 0
	check(not combat._check_combat_end() and not skills.debuff_manager.has_exploration_event_control(actor)
		and combat.pending_conclusion.is_empty(),
		"Último sobrevivente acorda imediatamente do controle por turnos.")
	var round_stun := skills.debuff_manager.apply_by_id(actor, &"db_00002")
	stun = round_stun.get("instance") as DebuffInstanceState
	stun.exploration_event_control = true
	stun.duration_kind = DebuffManager.DURATION_ROUND
	stun.expiration_round_index = game.campaign.get_round_index() + 1
	check(combat._check_combat_end() and combat.pending_conclusion.get("result", {}).get("reason") == "defeat",
		"Último sobrevivente congelado até a Rodada seguinte perde o combate.")
	print("EXPLORATION_EVENT_INCAPACITATION: %d falhas" % failures)
	await create_timer(2.6).timeout
	scene.queue_free()
	for _frame in 4:
		await process_frame
	quit(1 if failures else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
