extends SceneTree


func _initialize() -> void:
	_render.call_deferred()


func _render() -> void:
	var tutorial := TutorialWindow.new()
	root.add_child(tutorial)
	tutorial.open(true)
	for frame in 8:
		await process_frame
	var image := root.get_texture().get_image()
	var path := "res://artifacts/tutorial_interface_preview.png"
	var result := image.save_png(path)
	print("TUTORIAL_PREVIEW result=%d path=%s size=%s" % [
		result, path, image.get_size()])
	tutorial._select_category("ATALHOS DE TECLADO")
	for frame in 8:
		await process_frame
	var shortcut_path := "res://artifacts/tutorial_atalhos_preview.png"
	var shortcut_result := root.get_texture().get_image().save_png(shortcut_path)
	print("SHORTCUT_PREVIEW result=%d path=%s" % [shortcut_result, shortcut_path])
	quit(0 if result == OK and shortcut_result == OK else 1)
