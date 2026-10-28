extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var audio := root.get_node("GameAudio")
	var menu_player := audio.get("_menu_player") as AudioStreamPlayer
	_check(menu_player != null and menu_player.bus == &"Music"
		and menu_player.stream != null
		and menu_player.stream.resource_path == "res://audio/music/pre_game_menu.mp3"
		and (menu_player.stream as AudioStreamMP3).loop,
		"Faixa nova de pré-jogo está no bus Music e em loop.")
	var main := load("res://scenes/ui/main_menu.tscn").instantiate() as PPPMainMenu
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	_check(audio.call("get_music_context") == &"menu" and menu_player.playing,
		"Menu principal inicia a música.")
	var settings := main.get("_settings_menu") as Control
	settings.call("open")
	await process_frame
	_check(settings.visible and audio.call("get_music_context") == &"menu"
		and menu_player.playing,
		"Configurações abertas do menu principal mantêm a música.")
	settings.call("close")
	var load_panel := main.get("_load_panel") as Control
	load_panel.call("open")
	await process_frame
	_check(load_panel.visible and audio.call("get_music_context") == &"menu"
		and menu_player.playing,
		"Carregar jogo aberto antes da partida mantém a música.")
	load_panel.call("close")
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() \
		as PlayableSelectionScreen
	root.add_child(selection)
	current_scene = selection
	main.queue_free()
	await process_frame
	_check(audio.call("get_music_context") == &"menu" and menu_player.playing,
		"Seleção mantém a mesma música sem trocar de contexto.")
	var summary := load("res://scenes/ui/campaign_pregame_summary.tscn").instantiate() \
		as CampaignPreGameSummary
	root.add_child(summary)
	current_scene = summary
	selection.queue_free()
	await process_frame
	_check(audio.call("get_music_context") == &"menu" and menu_player.playing,
		"Confirmação de campanha mantém a música do pré-jogo.")
	var game := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(game)
	current_scene = game
	summary.queue_free()
	await process_frame
	_check(audio.call("get_music_context") != &"menu" and not menu_player.playing,
		"Ao entrar na cena do jogo, a música do pré-jogo para.")
	audio.call("set_game_context", &"paused")
	await process_frame
	_check(audio.call("get_music_context") != &"menu" and not menu_player.playing,
		"Pausa e painéis dentro do jogo não ativam a música do menu principal.")
	game.queue_free()
	await process_frame
	print("PPP_PRE_GAME_MENU_MUSIC_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
