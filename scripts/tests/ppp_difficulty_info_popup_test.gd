extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() as Control
	root.add_child(selection)
	await process_frame
	var info_button := selection.get("_difficulty_info_button") as Button
	var info := selection.get("_difficulty_info") as AcceptDialog
	info_button.pressed.emit()
	await process_frame
	_check(info.visible and info.title == "MODOS DE JOGO",
		"O (i) da dificuldade abre o texto informativo padrão.")
	_check(info.dialog_text.contains("ÁGUA COM AÇÚCAR") \
		and info.dialog_text.contains("PADRÃO") \
		and info.dialog_text.contains("CAÓTICO") \
		and not info.dialog_text.contains("2 itens"),
		"O texto explica os três modos sem números ou estatísticas.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		_check(root.get_texture().get_image().save_png(
			"res://artifacts/difficulty_info_popup_preview.png") == OK,
			"A janela informativa pode ser renderizada para conferência visual.")
	info.get_ok_button().pressed.emit()
	await process_frame
	_check(not info.visible, "OK fecha a explicação sem mudar a seleção.")
	info_button.pressed.emit()
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	info.window_input.emit(escape)
	await process_frame
	_check(not info.visible, "Esc fecha a explicação sem mudar a seleção.")
	info_button.pressed.emit()
	await process_frame
	info.close_requested.emit()
	await process_frame
	_check(not info.visible, "X fecha a explicação sem mudar a seleção.")
	print("PPP_DIFFICULTY_INFO_POPUP: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
