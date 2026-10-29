extends SceneTree

## Regressão: Vai Pegar! não pode deixar o combate parado no turno do cão invisível.

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var skills := scene.get_node("SkillManager") as SkillManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha inicia para a regressão de Vai Pegar!.")
	var owner := gerencia.campaign.active_entity_states[0]
	owner.position = Vector2i(3, 2)
	var dog_data := load("res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	var dog := EntityState.from_playable_selection(dog_data,
		&"Dog_Fetch_Combat_Test", EntityState.UNPLACED)
	check(gerencia.campaign.register_companion(owner, dog),
		"Doguinho pertence ao jogável.")
	owner.turn_serial = 1
	owner.turn_state = EntityState.TurnState.TURNING
	var dog_grant := skills.get_active_grants(dog)[0]
	check(skills.use_exploration_active(dog, owner, dog_grant, gerencia.campaign),
		"Vai Pegar! inicia antes do combate.")
	check(dog.unavailable_until_owner_turn_serial == 3,
		"Doguinho volta apenas no turno agendado do dono.")
	var encounter := load("res://resources/encounters/enc_zumbis_dancarinos_suburbio.tres") as EncounterData
	gerencia.campaign.current_map.set_ppp_block(owner.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(owner.position, owner), "Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(dog.position == EntityState.UNPLACED and dog in \
		combat.initiative_order.map(func(entry: Dictionary) -> EntityState:
			return entry["entity"] as EntityState),
		"Doguinho fica fora dos hexes, mas permanece na fila para voltar neste combate.")
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": dog})
	combat.initiative_order.append({"entity": owner})
	combat._start_combat_turns()
	check(combat.current_actor == owner and combat.is_player_turn(),
		"O primeiro lugar invisível é pulado e o jogável pode agir.")
	check(dog.turn_state != EntityState.TurnState.TURNING,
		"O Doguinho ausente nunca segura o turno.")
	var free_ground := Vector2(1600.0, 920.0)
	check(not scene._point_over_hex(free_ground),
		"O ponto de teste é chão livre, sem hex.")
	var ground_click := InputEventMouseButton.new()
	ground_click.button_index = MOUSE_BUTTON_LEFT
	ground_click.pressed = true
	ground_click.position = free_ground
	scene._unhandled_input(ground_click)
	check(hud.action_drawer.visible and hud._open_card != null \
		and hud._open_card.state == owner,
		"Clicar no chão livre durante combate abre as ações do turno ativo.")
	check(combat.end_current_turn(), "Jogável pode encerrar normalmente.")
	await create_timer(0.1).timeout
	check(combat.current_actor == owner and owner.turn_serial == 3,
		"O ciclo seguinte pula novamente o Doguinho e avança.")
	check(gerencia.campaign.delayed_skill_effects.is_empty(),
		"O item é resolvido no turno devido, mesmo dentro do combate.")
	check(dog.position != EntityState.UNPLACED,
		"No turno devido, o Doguinho volta a ocupar um hex livre.")
	print("PPP_DOG_FETCH_COMBAT: %s" % ("PASS" if failures == 0 else "%d falhas" % failures))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
