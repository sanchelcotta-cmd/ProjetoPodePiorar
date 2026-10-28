extends SceneTree

## Prévia reproduzível da confirmação real sobre a pausa, sem salvar campanha.


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	root.size = Vector2i(1440, 810)
	var game := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(game)
	current_scene = game
	await process_frame
	var pause: CampaignPauseMenu = (game.get_node("CampaignTopBar") as CampaignTopBar).pause_menu
	pause.open()
	pause._exit.dialog_text = "O progresso não salvo e o backup automático desta sessão serão descartados. Os três slots manuais permanecem."
	pause._exit.popup_centered(Vector2i(520, 190))
	await process_frame
	await process_frame
	var path := "res://artifacts/dialog_style_preview.png"
	var result := root.get_texture().get_image().save_png(path)
	pause._exit.hide()
	pause.open_save()
	pause._overwrite.dialog_text = "O slot 1 já contém um save. Substituir apaga apenas o ponto antigo deste slot; os outros dois permanecem. Deseja continuar?"
	pause._overwrite.popup_centered(Vector2i(450, 175))
	await process_frame
	await process_frame
	var save_result := root.get_texture().get_image().save_png(
		"res://artifacts/dialog_style_save_preview.png")
	if save_result != OK:
		result = save_result
	pause._overwrite.hide()
	pause._save_panel.close()
	root.size = Vector2i(800, 600)
	pause._abandon.popup_centered(Vector2i(555, 225))
	await process_frame
	await process_frame
	var abandon_result := root.get_texture().get_image().save_png(
		"res://artifacts/dialog_style_abandon_800_preview.png")
	if abandon_result != OK:
		result = abandon_result
	print("PPP_DIALOG_STYLE_PREVIEW: %s" % ("PASS" if result == OK else "FAIL"))
	quit(0 if result == OK else 1)
