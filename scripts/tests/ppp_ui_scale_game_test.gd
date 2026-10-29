extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PPP_UI_SCALE_GAME_TEST: SKIP (requires display)")
		quit()
		return
	var old_mode := DisplayServer.window_get_mode()
	var old_size := DisplayServer.window_get_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await process_frame
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(game)
	current_scene = game
	await process_frame
	var manager := game.get_node("GerenciaJogo") as GerenciaJogo
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 39820
	_check(manager.start_new_game(party)
		and (game.get_node("RoundManager") as RoundManager).start_first_map(rng),
		"Mapa de teste iniciado.")
	var scaler := root.get_node("UniversalFontScale")
	_check(scaler.call("set_ui_scale", 1.5, false), "150% disponível em tela cheia.")
	for frame in 4:
		await process_frame
	var bar := game.get_node("CampaignTopBar") as CampaignTopBar
	var pause = bar.pause_menu
	pause.open()
	await process_frame
	var viewport_size := game.get_viewport_rect().size
	for button in pause._menu.get_children():
		if not button is Button:
			continue
		var rect := (button as Button).get_global_rect()
		_check(rect.position.x >= 0.0 and rect.end.x <= viewport_size.x
			and rect.position.y >= 0.0 and rect.end.y <= viewport_size.y,
			"Botão da pausa %s continua acessível." % button.name)
	root.get_texture().get_image().save_png(
		"C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/pause_scale_150_preview.png")
	pause.close()
	scaler.call("set_ui_scale", 1.0, false)
	DisplayServer.window_set_mode(old_mode)
	DisplayServer.window_set_size(old_size)
	print("PPP_UI_SCALE_GAME_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
