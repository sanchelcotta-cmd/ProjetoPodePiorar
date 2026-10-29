extends SceneTree

const PREVIEW_PATH := "C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/main_menu_preview.png"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_check((menu.get_node("BlackBackground") as ColorRect).color == Color.BLACK
		and (menu.get_node("BackgroundImage") as TextureRect).texture == null,
		"Fundo começa preto e possui espaço vazio para os slides futuros.")
	var expected := ["NewGame", "LoadGame", "CampaignRecords", "Settings", "Credits", "Quit"]
	for name in expected:
		_check(menu.get_node_or_null("MenuArea/" + name) is Button,
			"Botão %s existe no menu inicial." % name)
	if DisplayServer.get_name() != "headless":
		var image := root.get_texture().get_image()
		if image != null and not image.is_empty():
			_check(image.save_png(PREVIEW_PATH) == OK,
				"Prévia do menu inicial é gravada.")
	menu.call("_show_placeholder", "CRÉDITOS")
	_check((menu.get("_placeholder") as Control).visible,
		"Destino futuro informa claramente que ainda não está pronto.")
	(menu.get("_placeholder") as Control).hide()
	(menu.get_node("MenuArea/LoadGame") as Button).pressed.emit()
	await create_timer(0.3).timeout
	_check((menu.get("_load_panel") as Control).visible,
		"Carregar jogo abre o carregamento existente.")
	(menu.get("_load_panel") as Control).call("close")
	(menu.get_node("MenuArea/NewGame") as Button).pressed.emit()
	# Novo Jogo aguarda a animação do botão e o pré-carregamento do catálogo;
	# o tempo varia conforme a máquina, então esperamos a troca de cena real.
	for attempt in 100:
		if current_scene is PlayableSelectionScreen:
			break
		await create_timer(0.05).timeout
	var selection := current_scene as PlayableSelectionScreen
	_check(selection != null, "Novo Jogo abre a seleção.")
	if selection != null:
		(selection.get_node("Content/Stack/Header/HeaderMargin/HeaderRow/Back") as Button).pressed.emit()
		await process_frame
		await process_frame
		_check(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/main_menu.tscn",
			"Voltar da seleção retorna ao menu principal.")
	print("PPP_MAIN_MENU_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
