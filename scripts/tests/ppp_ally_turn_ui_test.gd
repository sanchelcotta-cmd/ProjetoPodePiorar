extends SceneTree

## Regressão: aliados na exploração e ações ligadas à iniciativa no combate.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var combat := scene.get_node("CombatManager") as CombatManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var bar := scene.get_node("InitiativeTurnBar") as InitiativeTurnBar
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var view := scene.get_node("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(game.start_new_game(selected) and rounds.start_first_map(),
		"Partida inicia.")
	var owner := game.campaign.active_entity_states[0]
	owner.position = Vector2i(3, 2)
	var goblin := EntityState.from_encounter_member(load(
		"res://resources/entities/entities_general/goblin_1.tres"),
		&"ally_ui_test", 1, EntityState.UNPLACED)
	check(game.campaign.register_companion(owner, goblin),
		"Aliado simples é registrado.")
	var black := EntityState.from_encounter_member(load(
		"res://resources/entities/entities_general/homem_de_preto.tres"),
		&"ally_ui_test", 1, EntityState.UNPLACED)
	if black.data != null:
		check(game.campaign.register_companion(owner, black),
			"Homem de Preto é recrutado.")
		check(black.attack == 2 and black.max_stamina == 2,
			"Homem de Preto sem Informação tem atributos mínimos jogáveis.")
	var dog := EntityState.from_playable_selection(load(
		"res://resources/entities/entities_general/companions/doguinho_caramelo.tres"),
		&"ally_ui_dog", EntityState.UNPLACED)
	check(game.campaign.register_companion(owner, dog),
		"Aliado móvel é registrado.")
	check(view.visuals_by_id.has(dog.instance_id) \
		and not view.ground_silhouettes_by_id.has(dog.instance_id),
		"Aliado móvel preserva sprite próprio e não vira silhueta estática.")
	var ground := view.ground_silhouettes_by_id.get(goblin.instance_id) \
		as EnemySilhouetteVisual
	check(ground != null and ground.visible and ground.is_ally,
		"Aliado sem sprite aparece como silhueta azul no chão da exploração.")
	hud._update_map_hit_targets()
	hud._on_map_companion_pressed(goblin)
	check(hud.character_sheet.visible and hud.character_sheet.actor == goblin,
		"Aliado sem ativa abre diretamente a ficha.")
	hud.character_sheet.close_sheet()
	var next_actor := game.campaign.active_entity_states[1]
	exploration.current_actor = next_actor
	owner.turn_state = EntityState.TurnState.INACTIVE
	next_actor.turn_state = EntityState.TurnState.TURNING
	hud._update_map_hit_targets()
	hud._on_map_companion_pressed(dog)
	var dog_grant := hud._pet_skill(dog, &"companion_active_002")
	check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() >= 2 \
		and dog_grant != null and hud._skill_is_available(dog, dog_grant),
		"Aliado móvel abre ações utilizáveis fora do turno do dono.")
	hud._hide_hex_choice()
	hud._on_action_toggle_requested(hud.cards[0])
	hud._on_ally_pressed()
	check(hud._ally_roster.visible and hud._ally_roster.get_child_count() >= 1 \
		and hud.ally_skill_buttons.get_child_count() == 0,
		"Botão Aliado lista nomes e fichas sem duplicar ações do dono.")
	var encounter := load(
		"res://resources/encounters/enc_zumbis_dancarinos_suburbio.tres") as EncounterData
	game.campaign.current_map.set_ppp_block(owner.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(owner.position, owner), "Combate abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": goblin})
	combat.initiative_order.append({"entity": owner})
	combat.initiative_order.append({"entity": combat.enemies[0]})
	bar._reload_participants()
	combat._start_combat_turns()
	await process_frame
	await process_frame
	check(combat.current_actor == goblin and hud.hex_choice.visible \
		and hud._companion_actions_from_initiative \
		and hud._initiative_action_link.visible,
		"Turno do aliado abre ações abaixo da iniciativa com linha de ligação.")
	var active_button: Button
	for info in bar._cards:
		if info["actor"] == goblin:
			active_button = info["button"] as Button
			break
	check(active_button != null, "Aliado tem caixa clicável na iniciativa.")
	if active_button != null:
		active_button.pressed.emit()
		check(not hud.hex_choice.visible, "Clique na iniciativa fecha ações abertas.")
		active_button.pressed.emit()
		check(hud.hex_choice.visible and hud._companion_actions_from_initiative,
			"Outro clique na iniciativa reabre ações.")
	combat._turn_die = 4
	combat._attacks_used = 1
	combat._turn_moved = true
	hud._refresh_companion_action_choice()
	var pass_button := hud.hex_choice_buttons.get_child(
		hud.hex_choice_buttons.get_child_count() - 1) as Button
	var pass_style := pass_button.get_theme_stylebox("normal") as StyleBoxFlat
	check(pass_button.text == "PASSAR O TURNO" and pass_style.bg_color.r > 0.6,
		"Após dado, movimento e ataque esgotados, passar turno fica vermelho.")
	hud._on_ground_pressed(Vector2(1500.0, 890.0))
	check(hud.hex_choice_buttons.get_child_count() == 1 \
		and (hud.hex_choice_buttons.get_child(0) as Button).text == "PASSAR O TURNO",
		"Chão livre mostra somente passar turno quando não há ações básicas.")
	print("PPP ally turn UI: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
