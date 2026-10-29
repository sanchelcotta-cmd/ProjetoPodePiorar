extends SceneTree

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
	]
	check(gerencia.start_new_game(choices), "Campanha inicia com três jogáveis.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Mapa da primeira Rodada é gerado.")
	await process_frame
	var actor := exploration.current_actor
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var coord := Vector2i(0, 2)
	var preview_item := load("res://resources/itens/consumables/prato_feito_perfeito.tres") as ItemData
	gerencia.campaign.current_map.set_ppp_block(coord,
		HexGrid.PPPBlockType.CONSUMABLE, preview_item)
	var area := scene.get_node("MapRoot/Hexes/Hex_0_2") as Area2D
	var center := area.get_global_transform_with_canvas().origin
	check(scene.get_clickable_hex_at_screen_position(center) == coord,
		"A camada superior identifica o hex inteiro para o clique.")
	hud._update_map_hit_targets()
	check(hud._hex_click_overlay.get_index() ==
		hud.map_hit_targets.get_child_count() - 1,
		"Na Exploração, o hex recebe o clique antes do corpo sobreposto.")
	var before := actor.position
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	actor.stamina_remaining = 0
	scene.set_active_actor(actor.position, 0)
	scene._on_cell_pressed(coord, click)
	check(scene._selected_coord == coord and hud.hex_choice.visible,
		"Sem Estamina, o hex de emergência mais próximo ainda oferece movimento.")
	hud._hide_hex_choice()
	actor.stamina_remaining = actor.max_stamina
	scene.set_active_actor(actor.position, actor.stamina_remaining)
	scene._on_cell_pressed(coord, click)
	check(actor.position == before and hud.hex_choice.visible,
		"O clique no hex não começa o movimento.")
	check(hud.hex_choice_buttons.get_child_count() >= 2,
		"O hex oferece movimento e Olhar Afiado quando ambos são válidos.")
	check(hud.hex_choice_title.text == "◎ ◎ ◎ ◎",
		"A caixa contextual não mostra mais coordenadas do hex.")
	var reveal_button := hud.hex_choice_buttons.get_child(1) as Button
	check("REVELAR" in reveal_button.text,
		"A caixa contextual oferece o botão temporário Revelar.")
	reveal_button.emit_signal("pressed")
	check(actor.position == before \
		and gerencia.campaign.current_map.get_cell(coord).state == HexGrid.PPPBlockState.REVEALED,
		"Selecionar a Ativa revela sem mover nem ativar o bloco.")
	check(area.modulate == scene._renderer._palette.revealed_color,
		"Hex revelado permanece rosa mesmo estando ao alcance da Estamina.")
	check(not hud.hex_choice.visible, "A caixa fecha após a ação.")
	scene._on_cell_pressed(coord, click)
	check(not hud.hex_title_popup.visible and hud.hex_choice.visible \
		and (hud.hex_choice_buttons.get_child(0) as Button).text == "ANDAR ATÉ",
		"Hex rosa mostra uma única caixa com informações e Andar até.")
	check(hud.hex_choice_title.text.contains(hud._hex_classification(
		gerencia.campaign.current_map.get_ppp_block_resource(coord))),
		"A linha de título identifica o tipo do hex revelado.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.3).timeout
		var hex_preview := "user://ppp_hex_revelado_contexto.png"
		check(root.get_texture().get_image().save_png(hex_preview) == OK,
			"A prévia da caixa combinada é capturada.")
		print("HEX_REVEALED_PREVIEW=" + ProjectSettings.globalize_path(hex_preview))
	check(hud.hex_choice_close.text == "×", "A caixa oferece um X discreto para fechar.")
	hud.hex_choice_close.pressed.emit()
	check(not hud.hex_choice.visible, "O X fecha a caixa sem ativar o hex.")
	scene._on_cell_pressed(coord, click)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	hud._input(escape)
	check(not hud.hex_choice.visible, "ESC fecha a caixa de um hex revelado.")
	scene._on_cell_pressed(coord, click)
	var outside_click := InputEventMouseButton.new()
	outside_click.button_index = MOUSE_BUTTON_LEFT
	outside_click.pressed = true
	outside_click.position = Vector2(-20.0, -20.0)
	hud._input(outside_click)
	check(not hud.hex_choice.visible and actor.position == before,
		"Clique fora fecha a caixa sem movimentar o personagem.")
	scene._on_cell_pressed(coord, click)
	var sample_event := EventData.new()
	sample_event.valence = EventData.Valence.AMBIGUOUS
	check(hud._hex_classification(sample_event) == "Evento | Ambíguo",
		"Eventos revelados mostram a valência.")
	var sample_item := ItemData.new()
	sample_item.item_type = ItemData.ItemType.CONSUMABLE
	check(hud._hex_classification(sample_item) == "Item | Consumível",
		"Itens revelados mostram a categoria de uso.")
	var sample_encounter := EncounterData.new()
	sample_encounter.districts.append(&"suburbio")
	check(hud._hex_classification(sample_encounter) == "Encontro | Subúrbio",
		"Encontros revelados mostram seu distrito.")
	hud.cards[0].action_button.emit_signal("pressed")
	hud.walk_button.emit_signal("pressed")
	scene._on_cell_pressed(coord, click)
	check(actor.position == coord and not hud.hex_choice.visible,
		"Andar até armado ainda pode ativar o hex revelado.")
	var resolved_grid := HexGrid.new()
	resolved_grid.generate_ppp_exploration_map()
	resolved_grid.set_ppp_block(coord, HexGrid.PPPBlockType.CONSUMABLE, preview_item)
	resolved_grid.activate_ppp_block(coord)
	var resolved_hexes := Node2D.new()
	scene._renderer.create_hex_visual(resolved_hexes, coord, Vector2.ZERO)
	scene._renderer.update_ppp_feedback(resolved_hexes, resolved_grid,
		{coord: true}, Vector2i(-999, -999), Vector2i(-999, -999))
	var resolved_area := resolved_hexes.get_node("Hex_0_2") as Area2D
	check(resolved_area.modulate == scene._renderer._palette.inactive_color,
		"Hex ativado sem o destaque do personagem ativo fica cinza.")
	resolved_hexes.free()

	# Verifica também o outro caminho: botão da ficha antes do clique no hex.
	var walk_scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(walk_scene)
	await process_frame
	var walk_gerencia := walk_scene.get_node("GerenciaJogo") as GerenciaJogo
	check(walk_gerencia.start_new_game(choices), "Outra campanha inicia para testar o botão da ficha.")
	check((walk_scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Outro mapa é gerado para o segundo caminho.")
	await process_frame
	var walk_hud := walk_scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var walk_exploration := walk_scene.get_node("ExplorationManager") as ExplorationManager
	walk_hud.cards[0].action_button.emit_signal("pressed")
	walk_hud.walk_button.emit_signal("pressed")
	check(walk_hud._walk_target_actor == walk_exploration.current_actor \
		and not walk_hud.action_drawer.visible,
		"Andar até na ficha prepara o próximo clique no mapa.")
	walk_scene._on_cell_pressed(coord, click)
	check(walk_exploration.current_actor.position == coord and not walk_hud.hex_choice.visible,
		"Depois de escolher Andar até na ficha, clicar no hex move diretamente.")

	var pedreiro_scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(pedreiro_scene)
	await process_frame
	var pedreiro_exploration := pedreiro_scene.get_node("ExplorationManager") as ExplorationManager
	var pedreiro_gerencia := pedreiro_scene.get_node("GerenciaJogo") as GerenciaJogo
	var pedreiro_choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
	]
	check(pedreiro_gerencia.start_new_game(pedreiro_choices), "Pedreiro pode iniciar como Playable_1.")
	check((pedreiro_scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Mapa do Pedreiro é gerado.")
	await process_frame
	var bad_event := load("res://resources/events/random_events/33-tropeco_perigoso.tres") as EventData
	var pedreiro_grid := pedreiro_gerencia.campaign.current_map
	pedreiro_grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, bad_event)
	var pedreiro_hud := pedreiro_scene.get_node("PartyStatusHUD") as PartyStatusHUD
	pedreiro_scene._on_cell_pressed(coord, click)
	(pedreiro_hud.hex_choice_buttons.get_child(0) as Button).emit_signal("pressed")
	var popup := pedreiro_scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var cancel_button: Button = null
	for candidate in popup.buttons.get_children():
		if candidate is Button and "Quebra 4ª Parede" in candidate.text:
			cancel_button = candidate
	check(popup.overlay.visible and popup.buttons.get_child_count() >= 2 \
		and cancel_button != null and popup.narrative_label.text == bad_event.narrative_description,
		"A narrativa e as opções normais incluem CANCELAR / Quebra 4ª Parede.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.23).timeout
		var preview_path := "user://ppp_pedreiro_consequence_preview.png"
		root.get_texture().get_image().save_png(preview_path)
		print("PEDREIRO_CONSEQUENCE_PREVIEW=" + ProjectSettings.globalize_path(preview_path))
	if cancel_button != null:
		cancel_button.mouse_entered.emit()
		check(popup.skill_info.visible and "destru" in popup.skill_info_description.text.to_lower(),
			"O hover do botão do Pedreiro mostra a descrição da habilidade.")
		cancel_button.pressed.emit()
	check(pedreiro_grid.get_cell(coord).state == HexGrid.PPPBlockState.DESTROYED \
		and not popup.overlay.visible,
		"A escolha executa Quebra da Parede e destrói o Evento.")

	var normal_scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(normal_scene)
	await process_frame
	var normal_exploration := normal_scene.get_node("ExplorationManager") as ExplorationManager
	var normal_gerencia := normal_scene.get_node("GerenciaJogo") as GerenciaJogo
	check(normal_gerencia.start_new_game(pedreiro_choices),
		"Outra campanha do Pedreiro inicia para aceitar o Evento.")
	check((normal_scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Outro mapa do Pedreiro é gerado.")
	await process_frame
	normal_gerencia.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, bad_event)
	var normal_hud := normal_scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var normal_popup := normal_scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var normal_block := normal_scene.get_node("BlockManager") as BlockManager
	normal_scene._on_cell_pressed(coord, click)
	(normal_hud.hex_choice_buttons.get_child(0) as Button).pressed.emit()
	check(normal_popup.buttons.get_child_count() >= 2,
		"A consequência oferece escolha normal e opção do Pedreiro juntas.")
	(normal_popup.buttons.get_child(0) as Button).pressed.emit()
	check(normal_block.is_busy() and not normal_popup._pre_activation_pending,
		"Escolher o botão normal inicia a resolução do Evento sem usar a Ativa.")
	check(normal_block.finish_event_resolution() and not normal_popup.overlay.visible,
		"A resolução normal conclui e fecha a caixa narrativa.")
	print("PPP hex action choice: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
