extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("PPP_SETTINGS_VIDEO_TEST: SKIP (requires display)")
		quit()
		return
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	await process_frame
	var settings := menu.get("_settings_menu") as Control
	settings.call("open")
	var before: Dictionary = settings.call("_capture_video")
	settings.call("_request_video", 0, 3)
	await process_frame
	_check(not settings.get("_pending_video").is_empty()
		and (settings.get("_video_confirmation") as ConfirmationDialog).visible,
		"Nova resolução só fica pendente até confirmação.")
	_check(DisplayServer.window_get_size() == Vector2i(1280, 720),
		"Janela muda para 1280 × 720.")
	settings.call("_revert_video")
	await process_frame
	_check(DisplayServer.window_get_mode() == int(before["mode"])
		and DisplayServer.window_get_size() == before["size"],
		"Cancelar restaura modo e tamanho anteriores.")
	settings.call("_request_video", 2, 3)
	await process_frame
	_check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),
		"Janela sem bordas aplica a flag real.")
	settings.set("_confirmation_deadline", Time.get_ticks_msec() - 1)
	settings.call("_process", 0.0)
	await process_frame
	_check(settings.get("_pending_video").is_empty()
		and DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) == before["borderless"],
		"Fim do prazo reverte automaticamente.")
	settings.call("_request_video", 1, 3)
	await process_frame
	_check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"Tela cheia usa o modo nativo do monitor.")
	settings.call("_revert_video")
	await process_frame
	_check(DisplayServer.window_get_mode() == int(before["mode"]),
		"Cancelar tela cheia devolve o modo anterior.")
	settings.call("close")
	print("PPP_SETTINGS_VIDEO_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
