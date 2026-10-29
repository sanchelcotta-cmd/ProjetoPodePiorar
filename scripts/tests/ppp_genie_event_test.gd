extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var block := scene.get_node("BlockManager") as BlockManager
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(party) and round_manager.start_first_map(),
		"Campanha inicia para o Gênio.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	var grid := campaign.current_map
	var genie := load("res://resources/events/random_events/49-genio_da_lampada.tres") as EventData
	check(genie != null and genie.outcomes.size() == 8, "O Gênio mantém oito desejos no Resource.")
	if genie == null:
		quit(1)
		return
	var results: Array[Dictionary] = []
	executor.result_ready.connect(func(_context: Dictionary, result: Dictionary) -> void:
		results.append(result.duplicate()))
	var coord := Vector2i(0, 1)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, genie)
	check(block.begin_activation(coord, actor), "Hex do Gênio abre narrativa e desejos.")
	check(popup.buttons.get_child_count() == 7,
		"Antes de uma morte, a ressurreição não aparece; sete desejos permanecem.")
	var first_row := popup.buttons.get_child(0) as HBoxContainer
	check(first_row != null and first_row.get_child_count() == 2,
		"Cada desejo tem botão e ⓘ em grade uniforme.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.35).timeout
		var preview := "user://ppp_genio_desejos.png"
		check(root.get_texture().get_image().save_png(preview) == OK,
			"A grade visual dos desejos é capturada.")
		print("GENIE_WISH_PREVIEW=" + ProjectSettings.globalize_path(preview))
	(first_row.get_child(1) as Button).pressed.emit()
	check(popup._genie_info_panel.visible and popup._genie_info_description.text.length() > 20,
		"O ⓘ explica o efeito do desejo.")
	popup._hide_reward_item_details()
	(first_row.get_child(0) as Button).pressed.emit()
	check(popup._genie_pending_outcome.id == &"new_passive" and results.is_empty(),
		"Escolher um desejo só abre a confirmação.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup.title_label.text == "ESCOLHA A PASSIVA" and results.is_empty(),
		"Confirmar e prosseguir abre a seleção de Passivas.")
	var passive_choices := executor.get_passive_choices(actor)
	check(not passive_choices.is_empty(), "Há Passivas inatas elegíveis que o desejante não possui.")
	var passive_row := popup.buttons.get_child(0) as HBoxContainer
	(passive_row.get_child(1) as Button).pressed.emit()
	check(popup._genie_info_panel.visible and popup._genie_info_description.text.length() > 0,
		"O ⓘ da Passiva mostra sua descrição real.")
	popup._hide_reward_item_details()
	(passive_row.get_child(0) as Button).pressed.emit()
	check(popup._outcome_reading and results.is_empty(),
		"A Passiva aguarda a leitura do Outcome antes de ser concedida.")
	popup._execute_prepared_event()
	check(results.size() == 1 and not block.is_busy() and
		actor.skill_grants.any(func(grant: SkillGrantState) -> bool:
			return grant.source_kind == &"event" and grant.skill is PassiveSkillData),
		"Desejo de Passiva concede uma habilidade de fato e libera o bloco.")

	# Todos os subramos passam pela mesma escolha → leitura → OK → aplicação.
	for entry in [
		{"outcome": &"status_immunity", "choice": &"disease", "status": &"db_00003"},
		{"outcome": &"status_immunity", "choice": &"sadness", "status": &"db_00010"},
		{"outcome": &"status_immunity", "choice": &"terror", "status": &"db_00009"},
		{"outcome": &"combat_protection", "choice": &"ranged_critical"},
		{"outcome": &"combat_protection", "choice": &"stun", "status": &"db_00002"},
		{"outcome": &"combat_protection", "choice": &"bleeding", "status": &"db_00008"},
		{"outcome": &"double_stat", "choice": &"attack"},
		{"outcome": &"double_stat", "choice": &"life"},
		{"outcome": &"double_stat", "choice": &"stamina"},
	]:
		coord.x += 1
		if coord.x >= HexGrid.PPP_MAP_WIDTH:
			coord = Vector2i(0, coord.y + 1)
		_open_wish(campaign, grid, block, popup, genie, actor, coord, entry["outcome"])
		check(popup._genie_pending_outcome != null and not popup._outcome_reading,
			"Desejo %s aguarda confirmação da primeira escolha." % entry["outcome"])
		popup._continue_genie_wish()
		var target_choice: EventEffectChoiceData
		for choice in popup._genie_pending_outcome.effect_choices:
			if choice.id == entry["choice"]:
				target_choice = choice
		check(target_choice != null and not target_choice.description.is_empty(),
			"Subescolha %s possui descrição para ⓘ." % entry["choice"])
		popup._confirm_event({"outcome": popup._genie_pending_outcome,
			"effect_choice": target_choice})
		check(popup._outcome_reading and popup.narrative_label.text.contains(target_choice.description),
			"Subescolha %s aparece na leitura antes da aplicação." % entry["choice"])
		var before_attack := actor.attack
		var before_max_hp := actor.max_health
		var before_hp := actor.current_health
		var before_stamina := actor.max_stamina
		popup._execute_prepared_event()
		check(not block.is_busy() and results.back().get("effect_choice_id") == entry["choice"],
			"Subescolha %s conclui o Evento real." % entry["choice"])
		if entry.has("status"):
			check(entry["status"] in actor.permanent_status_immunities,
				"Subescolha %s concede imunidade permanente." % entry["choice"])
		match entry["choice"]:
			&"ranged_critical": check(actor.ignore_ranged_critical_bonus,
				"Crítico de Distância mantém penalidade pela distância.")
			&"attack": check(actor.attack == before_attack * 2, "Ataque dobra.")
			&"life": check(actor.max_health == before_max_hp * 2 \
				and actor.current_health == before_hp * 2, "Vida máxima e atual dobram.")
			&"stamina": check(actor.max_stamina == before_stamina * 2,
				"Estamina máxima dobra.")

	coord = Vector2i(0, 3)
	var curse := load("res://resources/itens/curseds/agulha_de_costura.tres") as ItemData
	actor.inventory_items.append(InventoryItemState.new(curse))
	_open_wish(campaign, grid, block, popup, genie, actor, coord, &"remove_curses")
	popup._continue_genie_wish()
	check(popup._outcome_reading and actor.inventory_items.any(
		func(copy: InventoryItemState) -> bool: return copy.data == curse),
		"Purificação não remove a Maldição antes do OK.")
	popup._execute_prepared_event()
	check(not actor.inventory_items.any(
		func(copy: InventoryItemState) -> bool: return copy.data == curse),
		"Purificação remove a cópia amaldiçoada do inventário.")

	coord = Vector2i(1, 3)
	_open_wish(campaign, grid, block, popup, genie, actor, coord, &"choose_item")
	popup._continue_genie_wish()
	check(popup._catalog_picker.visible, "O catálogo visual da Miss Fortuna abre para o item.")
	var item_effect := popup._catalog_effect_for_outcome(popup._genie_pending_outcome)
	var items := executor.get_catalog_choices(item_effect)
	check(not items.is_empty() and items.all(func(item: ItemData) -> bool:
		return item.item_type != ItemData.ItemType.CURSED and &"cursed" not in item.tags),
		"Nenhum item amaldiçoado aparece no desejo.")
	var item := items[0]
	var previous_item_count := actor.inventory_items.size()
	popup._catalog_picker._select(item)
	check(popup._catalog_picker._choice_panel.visible,
		"Item pede confirmação SIM/AINDA NÃO antes da leitura do Outcome.")
	popup._catalog_picker._confirm()
	check(popup._outcome_reading and actor.inventory_items.size() == previous_item_count,
		"Item escolhido não entra antes do OK do Outcome.")
	popup._execute_prepared_event()
	check(not block.is_busy() and actor.inventory_items.size() == previous_item_count + 1,
		"Item não amaldiçoado é entregue e o bloco encerra.")

	coord = Vector2i(2, 3)
	_open_wish(campaign, grid, block, popup, genie, actor, coord, &"random_information")
	var before_information := campaign.obtained_information_ids.size()
	popup._continue_genie_wish()
	check(popup._outcome_reading and campaign.obtained_information_ids.size() == before_information,
		"Informação sorteada espera OK.")
	popup._execute_prepared_event()
	check(campaign.obtained_information_ids.size() == before_information + 1,
		"Uma Informação nova foi registrada.")
	popup._acknowledge_event_result()
	check(not block.is_busy(), "Após ler a Informação, o Gênio libera o bloco.")

	# A morte e o retorno como aliado já têm regressão própria; aqui validamos a
	# oferta condicional e o ⓘ da ficha na interface do Evento.
	var dead := campaign.active_entity_states[1]
	campaign.dead_playable_states.append(dead)
	coord = Vector2i(3, 3)
	_open_wish(campaign, grid, block, popup, genie, actor, coord, &"revive_dead_playable")
	check(popup.buttons.get_child_count() <= 2,
		"Ressurreição aguarda Confirmar e Prosseguir antes de listar mortos.")
	popup._continue_genie_wish()
	var dead_row := popup.buttons.get_child(0) as HBoxContainer
	check(dead_row != null and dead_row.get_child_count() == 2,
		"Ressurreição apresenta seleção e ⓘ da ficha.")
	(dead_row.get_child(1) as Button).pressed.emit()
	check(popup._genie_sheet.visible and popup._genie_sheet.actor == dead,
		"O ⓘ do falecido abre sua ficha real.")
	popup._hide_reward_item_details()
	popup._confirm_event({"outcome": popup._genie_pending_outcome,
		"selected_dead_actor": dead})
	check(popup._outcome_reading, "Ressurreição ainda exige a leitura do Outcome.")
	popup._execute_prepared_event()
	check(not block.is_busy() and dead not in campaign.dead_playable_states,
		"O último desejo ressuscita o personagem e encerra o bloco.")
	print("GENIE_EVENT_TEST: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func _open_wish(campaign: CampaignState, grid: HexGrid, block: BlockManager,
		popup: BlockActivationPopup, genie: EventData, actor: EntityState,
		coord: Vector2i, outcome_id: StringName) -> void:
	campaign.event_last_handled_round.erase(genie.resource_path)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, genie)
	check(block.begin_activation(coord, actor), "Gênio abre em %s." % coord)
	var outcome: EventOutcomeData
	for candidate in genie.outcomes:
		if candidate.id == outcome_id:
			outcome = candidate
			break
	check(outcome != null, "Desejo %s está no Resource." % outcome_id)
	if outcome != null:
		popup._preview_genie_wish(outcome)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
