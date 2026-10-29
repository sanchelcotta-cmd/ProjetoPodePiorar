extends SceneTree


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1656, 932)
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(game)
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	if not gerencia.start_new_game(selected) \
			or not (game.get_node("RoundManager") as RoundManager).start_first_map():
		push_error("Não foi possível preparar o mapa do atalho do tutorial.")
		quit(1)
		return
	var bar := game.get_node("CampaignTopBar") as CampaignTopBar
	var shortcut := bar._tutorial_shortcut
	shortcut.set_presentation(0.66, false)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var expanded := root.get_texture().get_image()
	if expanded.save_png("res://artifacts/tutorial_shortcut_expandido.png") != OK:
		quit(1)
		return
	shortcut.set_presentation(0.66, true)
	bar.journal_ui._set_summary_expanded(false)
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var collapsed_image := root.get_texture().get_image()
	if collapsed_image.save_png("res://artifacts/tutorial_shortcut_recolhido.png") != OK:
		quit(1)
		return
	bar.journal_ui._set_summary_expanded(true)
	shortcut.set_presentation(0.66, false)
	bar._ensure_tutorial_invitation()
	bar._tutorial_invitation.open_invitation()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if root.get_texture().get_image().save_png(
			"res://artifacts/tutorial_convite_preview.png") != OK:
		quit(1)
		return
	print("TUTORIAL_SHORTCUT_PREVIEW ok")
	quit(0)
