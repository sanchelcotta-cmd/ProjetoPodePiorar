extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PPP_UI_SCALE_150_TEST: SKIP (requires display)")
		quit()
		return
	var previous_mode := DisplayServer.window_get_mode()
	var previous_size := DisplayServer.window_get_size()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await process_frame
	var scaler := root.get_node("UniversalFontScale")
	if not scaler.call("can_use_150_percent"):
		print("PPP_UI_SCALE_150_TEST: SKIP (display below 1920 × 1080)")
		DisplayServer.window_set_mode(previous_mode)
		DisplayServer.window_set_size(previous_size)
		quit()
		return
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() as Control
	root.add_child(selection)
	await process_frame
	_check(scaler.call("set_ui_scale", 1.5, false), "150% é aceito em 1920 × 1080.")
	for frame in 4:
		await process_frame
	var content := selection.get_node("Content") as Control
	_check(content.size.x <= selection.size.x + 1.0,
		"Conteúdo da seleção ampliada não expande além da tela.")
	for card in selection.get("cards"):
		if card.visible:
			_check(card.get_global_rect().position.x >= 0.0
				and card.get_global_rect().end.x <= selection.size.x,
				"Card visível em 150% não é cortado lateralmente.")
	root.get_texture().get_image().save_png(
		"C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_scale_150_preview.png")
	selection.queue_free()
	await process_frame
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	await process_frame
	var settings := menu.get("_settings_menu") as Control
	settings.call("open")
	await process_frame
	await process_frame
	var settings_rect := (settings.get("_panel") as PanelContainer).get_global_rect()
	_check(settings_rect.position.x >= 0.0 and settings_rect.end.x <= menu.size.x,
		"Configurações em 150% não cortam nas laterais.")
	root.get_texture().get_image().save_png(
		"C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/settings_scale_150_preview.png")
	settings.call("close")
	var load_panel := menu.get("_load_panel") as Control
	load_panel.call("open")
	await process_frame
	await process_frame
	var load_rect := (load_panel.get("_panel") as PanelContainer).get_global_rect()
	_check(load_rect.position.x >= 0.0 and load_rect.end.x <= menu.size.x,
		"Catálogo de saves em 150% não corta nas laterais.")
	scaler.call("set_ui_scale", 1.0, false)
	DisplayServer.window_set_mode(previous_mode)
	DisplayServer.window_set_size(previous_size)
	print("PPP_UI_SCALE_150_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
