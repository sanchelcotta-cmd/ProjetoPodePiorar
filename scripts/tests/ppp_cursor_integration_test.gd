extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cursor := root.get_node("GameCursor")
	_check((cursor.get("_textures") as Dictionary)["normal"].get_size() == Vector2(64, 64),
		"O cursor principal usa o atlas de 64 px.")
	_check((cursor.get("_loading_frames") as Array).size() == 12,
		"O carregamento tem 12 quadros.")
	cursor.call("capture_drag", self, "diagonal_nwse")
	cursor.call("_process", 0.0)
	_check(cursor.get("_shown") == "diagonal_nwse", "A captura preserva o cursor diagonal.")
	cursor.call("release_drag", self)
	cursor.call("begin_loading", self)
	cursor.set("_loading_started", Time.get_ticks_msec() - 151)
	cursor.call("_process", 0.0)
	_check(str(cursor.get("_shown")).begins_with("carregando_"),
		"Espera real exibe o cursor de carregamento após o atraso curto.")
	cursor.set("_loading_started", Time.get_ticks_msec() - 150 - 2 * 12 * 80 - 8 * 80)
	cursor.call("_process", 0.0)
	_check(str(cursor.get("_shown")).begins_with("carregando_2_8"),
		"O glitch só entra na terceira volta.")
	var comfort := root.get_node("VisualComfort")
	comfort.call("set_enabled", true, false)
	cursor.call("_process", 0.0)
	_check(cursor.get("_shown") == "carregando_estatico",
		"Redução de movimento remove giro e glitch.")
	comfort.call("set_enabled", false, false)
	cursor.call("end_loading", self)
	cursor.call("_process", 0.0)
	_check(cursor.get("_shown") == "normal", "Fim da espera restaura o bico.")
	print("PPP_CURSOR_INTEGRATION: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
