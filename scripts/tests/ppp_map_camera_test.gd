extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	await process_frame
	var map_root := scene.get_node("MapRoot") as Node2D
	var copies := scene.get_node("MapRoot/BackgroundCopies") as Node2D
	var hexes := scene.get_node("MapRoot/Hexes") as Node2D
	var clickable_hexes := 0
	for child in hexes.get_children():
		if child is Area2D:
			clickable_hexes += 1
	_check(clickable_hexes == 40,
		"O zoom não altera os 40 hexágonos do mapa.")
	_check(scene._zoom_slider != null and scene._zoom_slider.tick_count == 4,
		"O seletor de zoom deve ter quatro posições.")
	var zoom_labels := scene._zoom_frame.find_children("*", "Label", true, false)
	_check(zoom_labels.size() == 1 and (zoom_labels[0] as Label).text == "zoom",
		"A barra mostra apenas a legenda zoom, sem números ilustrativos.")
	_check(scene._zoom_slider.get_global_rect().size.x >= 76.0 \
		and scene._zoom_slider.get_global_rect().size.y >= 15.0,
		"O seletor deve ter área clicável real na interface.")
	_check(scene._zoom_slider.focus_mode == Control.FOCUS_NONE,
		"O seletor não captura as setas reservadas ao pan.")
	_check(copies.get_child_count() == 4,
		"A fachada deve continuar dos dois lados sem expor bordas ao afastar.")
	_check(is_equal_approx(map_root.scale.x, 1.0),
		"A cena inicia na escala padrão.")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(800.0, 130.0)
	scene._unhandled_input(wheel)
	_check(scene._camera_level == 2,
		"Rolinhos para cima elevam exatamente um nível de zoom.")
	scene._zoom_slider.value = 3
	_check(scene._camera_level == 3,
		"Arrastar o seletor alcança o quarto nível.")
	scene._set_camera_level(1)
	for index in 4:
		scene._set_camera_level(index)
		_check(is_equal_approx(map_root.scale.x, PPPMapView.CAMERA_ZOOM_LEVELS[index]),
			"O nível %d tem escala fixa." % (index + 1))
		var ground := scene.get_node("MapRoot/Ground") as Node2D
		var tile := ground.get_child(0) as Sprite2D
		var bottom := tile.to_global(Vector2(0.0,
			float(tile.texture.get_height()) * 0.5)).y
		_check(bottom >= scene.get_viewport_rect().size.y,
			"Nível %d não revela a margem inferior do chão." % (index + 1))
		for pan in [-scene._camera_pan_limit(), 0.0, scene._camera_pan_limit()]:
			scene._camera_pan_x = pan
			scene._camera_pan_target_x = pan
			scene._apply_camera_transform()
			var leftmost := INF
			var rightmost := -INF
			for facade in copies.get_children() + [scene.get_node("MapRoot/Background")]:
				var art := facade as Sprite2D
				var range_x := scene._visible_facade_horizontal_bounds(art.texture)
				leftmost = minf(leftmost, art.to_global(Vector2(
					float(range_x.x) - float(art.texture.get_width()) * 0.5, 0.0)).x)
				rightmost = maxf(rightmost, art.to_global(Vector2(
					float(range_x.y + 1) - float(art.texture.get_width()) * 0.5, 0.0)).x)
			_check(leftmost <= 0.0 and rightmost >= scene.get_viewport_rect().size.x,
				"Nível %d não revela margens horizontais mesmo no limite lateral." % (index + 1))
		scene._camera_pan_x = 0.0
		scene._camera_pan_target_x = 0.0
		scene._apply_camera_transform()
	scene._set_camera_level(3)
	_check(scene.cursor_can_pan_at(Vector2(800.0, 120.0)),
		"O céu acima das casas indica arrasto lateral no zoom.")
	_check(not scene.cursor_can_pan_at(Vector2(800.0,
		scene.get_ground_screen_top() + 8.0)),
		"O chão não indica arrasto lateral no zoom.")
	var sample_hex := Vector2i(3, 2)
	_check(scene.get_clickable_hex_at_screen_position(
		scene.get_hex_screen_position(sample_hex)) == sample_hex,
		"O clique do hex acompanha a transformação do mapa.")
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	scene._unhandled_key_input(right)
	_check(scene._camera_pan_target_x < 0.0,
		"Seta direita desloca a visão para a direita.")
	_check(scene._camera_pan_target_x >= -scene._camera_pan_limit(),
		"O deslocamento lateral fica dentro de limites.")
	var held := InputEventMouseButton.new()
	held.button_index = MOUSE_BUTTON_LEFT
	held.pressed = true
	held.position = Vector2(800.0, 120.0)
	scene._unhandled_input(held)
	_check(scene._camera_dragging, "Segurar o céu inicia o arrasto lateral.")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(850.0, 120.0)
	scene._unhandled_input(motion)
	_check(scene._camera_pan_target_x > -PPPMapView.CAMERA_PAN_STEP,
		"O arrasto responde com sensibilidade reduzida.")
	held.pressed = false
	scene._input(held)
	_check(not scene._camera_dragging, "Soltar o mouse encerra o arrasto.")
	scene._set_camera_level(1)
	_check(is_zero_approx(scene._camera_pan_target_x),
		"Voltar à escala padrão zera o deslocamento lateral.")
	for window_size in [Vector2i(1152, 648), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = window_size
		root.add_child(viewport)
		var resized := load("res://teste.tscn").instantiate() as PPPMapView
		viewport.add_child(resized)
		await process_frame
		await process_frame
		resized._set_camera_level(0)
		var tile := (resized.get_node("MapRoot/Ground") as Node2D).get_child(0) \
			as Sprite2D
		var bottom := tile.to_global(Vector2(0.0,
			float(tile.texture.get_height()) * 0.5)).y
		_check(bottom >= window_size.y,
			"A escala afastada não mostra a base do chão em %s." % window_size)
		var facades := resized.get_node("MapRoot/BackgroundCopies") as Node2D
		var leftmost := INF
		var rightmost := -INF
		for facade in facades.get_children() + [resized.get_node("MapRoot/Background")]:
			var art := facade as Sprite2D
			var range_x := resized._visible_facade_horizontal_bounds(art.texture)
			leftmost = minf(leftmost, art.to_global(Vector2(
				float(range_x.x) - float(art.texture.get_width()) * 0.5, 0.0)).x)
			rightmost = maxf(rightmost, art.to_global(Vector2(
				float(range_x.y + 1) - float(art.texture.get_width()) * 0.5, 0.0)).x)
		_check(leftmost <= 0.0 and rightmost >= window_size.x,
			"A escala afastada não revela laterais da fachada em %s." % window_size)
		viewport.queue_free()
	for file in DirAccess.get_files_at("res://sprites/background"):
		if not file.begins_with("cena_") or not file.ends_with(".png"):
			continue
		scene.grid.ppp_background_path = "res://sprites/background/" + file
		scene._rebuild_visuals()
		scene._set_camera_level(0)
		var all_facades := (scene.get_node("MapRoot/BackgroundCopies") as Node2D) \
			.get_children() + [scene.get_node("MapRoot/Background")]
		var leftmost := INF
		var rightmost := -INF
		for facade in all_facades:
			var art := facade as Sprite2D
			var horizontal := scene._visible_facade_horizontal_bounds(art.texture)
			leftmost = minf(leftmost, art.to_global(Vector2(
				float(horizontal.x) - float(art.texture.get_width()) * 0.5, 0.0)).x)
			rightmost = maxf(rightmost, art.to_global(Vector2(
				float(horizontal.y + 1) - float(art.texture.get_width()) * 0.5, 0.0)).x)
		_check(leftmost <= 0.0 and rightmost >= scene.get_viewport_rect().size.x,
			"A fachada %s deve cobrir as bordas em 85%%." % file)
	print("PPP_MAP_CAMERA: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
