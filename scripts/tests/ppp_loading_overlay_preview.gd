extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	var overlay := SceneLoadingOverlay.new()
	root.add_child(overlay)
	overlay.set_steps(7, 10)
	for frame in 3:
		await process_frame
	var footer := overlay.get_node("LoadingFooter") as CenterContainer
	var content := footer.get_node("LoadingContent") as VBoxContainer
	var track := content.get_node("LoadingTrack") as ColorRect
	var bar := track.get_node("LoadingProgress") as TextureProgressBar
	var rect := bar.get_global_rect()
	var viewport_size := root.get_visible_rect().size
	print("LOADING_RECT=", rect, " VIEWPORT=", viewport_size)
	_check(rect.size.x <= 400.0 and rect.size.x >= 300.0,
		"Barra de carregamento deve ter largura pequena e fixa.")
	_check(absf(rect.get_center().x - viewport_size.x * 0.5) < 4.0,
		"Barra de carregamento deve ficar centralizada.")
	_check(rect.end.y <= viewport_size.y - 25.0 and rect.end.y >= viewport_size.y - 100.0,
		"Barra de carregamento deve caber no rodapé.")
	_check(is_equal_approx(bar.value, 7.0) and is_equal_approx(bar.max_value, 10.0),
		"Preenchimento da barra acompanha as etapas concluídas.")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/loading_preview"))
	var capture := root.get_texture().get_image()
	_check(capture != null and capture.save_png("res://docs/loading_preview/menu.png") == OK,
		"Captura da barra no menu deve ser gravada.")
	print("PPP_LOADING_OVERLAY_OK" if failures == 0 else "PPP_LOADING_OVERLAY_FAILED:%d" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
