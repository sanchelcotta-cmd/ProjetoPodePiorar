extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var top_bar := scene.get_node("CampaignTopBar/Bar") as Control
	var chosen: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
	]
	check(game.start_new_game(chosen) and rounds.start_first_map(),
		"A partida começa com o Cozinheiro ativo.")
	var point := Vector2.ZERO
	for y in range(ceili(scene.get_ground_screen_top()) + 8, root.size.y - 8, 12):
		for x in range(320, root.size.x - 16, 12):
			var candidate := Vector2(x, y)
			if not scene._point_over_hex(candidate):
				point = candidate
				break
		if point != Vector2.ZERO:
			break
	check(point != Vector2.ZERO and not scene._point_over_hex(point),
		"Existe um trecho de chão fora dos hexágonos.")
	if point == Vector2.ZERO:
		quit(1)
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = point
	scene._unhandled_input(click)
	check(hud.hex_choice.visible and hud._ground_choice_open,
		"Clicar no chão abre a caixa contextual acima do clique.")
	check(hud.hex_choice.get_global_rect().end.y < point.y,
		"A caixa contextual fica inteiramente acima do ponto clicado.")
	var labels: Array[String] = []
	for child in hud.hex_choice_buttons.get_children():
		labels.append((child as Button).text)
	check(labels.size() >= 2 and labels[-1] == "PASSAR O TURNO",
		"A caixa inclui a Ativa sem hex e Passar o turno por último.")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(root.size.x - 10, 80)
	hud._input(outside)
	check(not hud.hex_choice.visible and not hud._ground_choice_open,
		"Clique fora recolhe a caixa do chão.")
	click.position = scene.get_hex_screen_position(Vector2i(2, 2))
	check(scene._point_over_hex(click.position),
		"O centro do hex selecionado é reconhecido pelo teste de geometria.")
	scene._unhandled_input(click)
	check(not hud.hex_choice.visible,
		"Clicar em um hex não abre o menu exclusivo do chão livre.")
	hud._on_ground_pressed(point)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._input(escape)
	check(not hud.hex_choice.visible, "ESC recolhe a caixa do chão.")
	for viewport_size in [Vector2i(1656, 932), Vector2i(1152, 648),
			Vector2i(1906, 932)]:
		root.size = viewport_size
		await process_frame
		for card in hud.cards:
			hud._on_action_toggle_requested(card)
			await process_frame
			for skill_button in hud.skill_buttons.get_children():
				check((skill_button as Button).tooltip_text.is_empty(),
					"Ativas usam apenas a descrição rosa, sem tooltip nativo duplicado.")
			var y := hud.action_drawer.position.y
			check(y >= top_bar.get_global_rect().end.y + 10.0,
				"A caixa respeita a margem inferior da barra superior em %s." % viewport_size)
			check(y + hud.action_drawer.size.y <= scene.get_ground_screen_top(),
				"A caixa inteira não cobre os hexes em %s." % viewport_size)
			hud._close_actions()
	root.size = Vector2i(1152, 648)
	await process_frame
	hud._on_action_toggle_requested(hud.cards[2])
	for index in 12:
		hud.skill_buttons.add_child(hud._make_choice_button(
			"ATIVA EXTRA %d" % index, Color(0.52, 0.36, 0.055)))
	hud._update_action_scroll()
	hud._position_action_drawer(false)
	await process_frame
	check(hud.scroll_arrows.visible and hud.action_scroll.vertical_scroll_mode \
		== ScrollContainer.SCROLL_MODE_AUTO,
		"Muitas Ativas ativam a rolagem sem alterar o tamanho dos botões.")
	check(hud.action_drawer.position.y + hud.action_drawer.size.y \
		<= scene.get_ground_screen_top(),
		"A caixa alta com scroll ainda respeita a margem do chão.")
	hud._close_actions()
	var actor_visuals := get_nodes_in_group("map_entity_visual")
	if not actor_visuals.is_empty():
		var feet: Vector2 = (actor_visuals[0] as Node2D).get_global_transform_with_canvas().origin
		hud._on_ground_pressed(feet + Vector2(0.0, 8.0))
		var body := Rect2(feet - Vector2(44.0, 158.0), Vector2(88.0, 168.0))
		check(not hud.hex_choice.get_global_rect().intersects(body),
			"A caixa do chão se desloca lateralmente para não cobrir uma entidade próxima.")
		hud._hide_hex_choice()
	check(exploration.current_actor == game.campaign.active_entity_states[0],
		"Inspecionar outras caixas não troca o turno.")
	print("GROUND_ACTION_UI: %d falhas" % failures)
	quit(1 if failures else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
