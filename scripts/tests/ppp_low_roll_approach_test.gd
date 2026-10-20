extends SceneTree

## Rolagem baixa não reduz a Estamina nem bloqueia a aproximação de um alvo.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	combat.auto_start_turns = false
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(gerencia.start_new_game(party) and rounds.start_first_map(),
		"Campanha inicia para testar dado 1.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(1, 2)
	gerencia.campaign.obtained_information_ids[&"low_roll_info"] = true
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	var grid := gerencia.campaign.current_map
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(actor.position, actor), "Encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	var enemy := combat.enemies[0]
	enemy.position = Vector2i(6, 2)
	for coord in grid.cells:
		grid.get_cell(coord).movement_blocked = false
	var ranged := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	actor.equipped_weapons.append(InventoryItemState.new(ranged))
	# Ataque baixo representa penalidades de evento/debuff mesmo com arma equipada.
	actor.attack = 1
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": actor})
	combat.initiative_order.append({"entity": enemy})
	combat._start_combat_turns()
	combat._turn_die = 1
	check(combat._uses_ranged_attack(actor) and actor.attack + combat._turn_die == 2,
		"O resultado 1 soma ao Ataque atual, inclusive quando há penalidade.")
	check(not combat.can_player_attack(enemy.position) and
		combat.can_player_approach(enemy.position),
		"Alvo fora de alcance não impede caminhar em direção a ele.")
	var preview := combat.get_player_attack_preview(enemy.position)
	check(preview.get("base_attack") == 1 and preview.get("die") == 1 \
		and preview.get("damage") == 0 \
		and str(preview.get("text", "")).contains("ATK 1 + dado 1"),
		"Apontar o alvo explica que o dado soma ao Ataque e mostra dano bruto zero.")
	combat._turn_die = 6
	preview = combat.get_player_attack_preview(enemy.position)
	check(preview.get("base_attack") == 1 and preview.get("die") == 6 \
		and preview.get("movement") == 0 and preview.get("distance") == 0 \
		and preview.get("damage") == 7,
		"Crítico de Distância ignora a penalidade de distância na prévia.")
	combat._turn_die = 1
	var nearby := EntityState.UNPLACED
	for coord in HexGrid.get_neighbors(actor.position):
		if combat.can_player_move(coord):
			nearby = coord
			break
	check(nearby != EntityState.UNPLACED, "Dado 1 mantém destinos pela Estamina.")
	check(combat.select_player_action(&"attack") and combat._can_select_hex(nearby),
		"Mesmo após escolher Atacar, o hex amarelo pode ser selecionado para andar.")
	scene.request_combat_selection(enemy.position)
	var attack_button: Button
	var approach_button: Button
	for child in hud.hex_choice_buttons.get_children():
		if child is Button and child.text == "ATACAR":
			attack_button = child
		if child is Button and child.text == "APROXIMAR":
			approach_button = child
	check(attack_button != null and attack_button.disabled and
		approach_button != null and not approach_button.disabled,
		"A caixa explica o bloqueio do ataque e oferece Aproximar.")
	if approach_button != null:
		approach_button.pressed.emit()
	check(HexGrid.distance(actor.position, enemy.position) < 5 and
		combat._steps_moved <= actor.max_stamina and combat._attacks_used == 0,
		"Aproximar usa até a Estamina, sem gastar o ataque nem depender do dado.")
	await create_timer(1.1).timeout
	check(not combat._attack_animation_pending,
		"A interação reabre após a caminhada visual terminar.")
	var second := EntityState.from_encounter_member(enemy.data, encounter.id,
		2, Vector2i(6, 3))
	combat.enemies.append(second)
	combat._draw_enemy(second)
	var overlap_pointer := scene.get_hex_screen_position(enemy.position) + Vector2(20, -60)
	var overlap := combat.get_enemies_under_pointer(overlap_pointer)
	check(overlap.size() == 2,
		"Dois corpos próximos são reconhecidos como alvos sob o mesmo ponto.")
	if overlap.size() == 2:
		var overlap_click := InputEventMouseButton.new()
		overlap_click.button_index = MOUSE_BUTTON_LEFT
		overlap_click.pressed = true
		hud._on_hex_overlay_pressed(enemy.position, overlap_pointer, overlap_click)
		check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() == 3 \
			and (hud.hex_choice_buttons.get_child(0) as Button).text == "REPOSICIONAR" \
			and (hud.hex_choice_buttons.get_child(1) as Button).text.begins_with("ATACAR"),
			"Sem modo prévio, a sobreposição oferece ações diretas sem expor coordenadas.")
		hud._hide_hex_choice()
		check(combat.select_player_action(&"move"),
			"O HUD arma Reposicionar antes de um clique sobreposto.")
		hud._on_hex_overlay_pressed(enemy.position, overlap_pointer, overlap_click)
		check(not hud.hex_choice.visible,
			"Reposicionar prioriza o hex, sem abrir escolha entre entidade e coordenada.")
		check(combat.select_player_action(&"attack"),
			"O HUD arma Atacar antes de um clique sobreposto.")
		hud._on_hex_overlay_pressed(enemy.position, overlap_pointer, overlap_click)
		check(not hud.hex_choice.visible or hud.hex_choice_title.text != "ESCOLHA UMA AÇÃO",
			"Atacar prioriza o corpo do inimigo, sem caixa de desambiguação.")
		hud._hide_hex_choice()
		combat.action_mode = &""
		combat._on_enemy_body_clicked(enemy, overlap_pointer)
		check(scene._selected_coord == overlap[0].position,
			"Primeiro clique seleciona o alvo 1 de 2.")
		combat._on_enemy_body_clicked(enemy, overlap_pointer)
		check(scene._selected_coord == overlap[1].position,
			"Segundo clique alterna para o alvo 2 de 2.")
	combat.enemies.erase(second)
	# Corpo a corpo: escolher Atacar continua fazendo o percurso possível,
	# mesmo quando os hexes do turno não bastam para chegar adjacente.
	actor.equipped_weapons.clear()
	actor.attack = 4
	actor.position = Vector2i(0, 2)
	enemy.position = Vector2i(7, 2)
	actor.stamina_remaining = 4
	combat._turn_moved = false
	combat._steps_moved = 0
	combat._attacks_used = 0
	combat._turn_die = 1
	preview = combat.get_player_attack_preview(enemy.position)
	check(preview.get("damage") == 0 and
		str(preview.get("status", "")).contains("Estamina"),
		"A prévia avisa quando o corpo a corpo anda mas não alcança adjacência.")
	var missed: Array[Dictionary] = []
	combat.action_resolved.connect(func(source: EntityState, action: StringName,
			details: Dictionary) -> void:
		if source == actor and action == &"attack_missed_reach":
			missed.append(details))
	check(combat.can_player_attack(enemy.position) and
		combat.player_attack(enemy.position),
		"Desarmado com dado 1 pode escolher Atacar contra alvo distante.")
	check(actor.position.x > 0 and combat._steps_moved <= actor.max_stamina,
		"Ataque distante desloca o personagem no limite da Estamina.")
	await create_timer(1.6).timeout
	check(not missed.is_empty() and combat._attacks_used == 1,
		"Se não alcançou adjacência, não causa dano e gasta só o ataque.")
	print("PPP low roll approach: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
