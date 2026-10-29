extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	await process_frame
	var scenic := scene.get_node("MapRoot/ScenicBackdrop") as PPPScenicBackdrop
	var sky := scene.get_node("ParallaxBackground") as PPPParallaxBackground
	var backgrounds: Array[String] = []
	for file in DirAccess.get_files_at("res://sprites/background"):
		if file.begins_with("cena_") and file.ends_with(".png"):
			backgrounds.append(file)
	backgrounds.sort()
	_check(not backgrounds.is_empty(), "Deve existir ao menos uma fachada.")
	for filename in backgrounds:
		var background_path: String = "res://sprites/background/" + filename
		var candidates := PPPScenicBackdrop.candidates_for_background(background_path)
		_check(not candidates.is_empty(),
			"O distrito de %s precisa ter ao menos um fundo elegível." % filename)
		for candidate in candidates:
			var allowed := candidate.contains("baixo-centro") \
				if filename.contains("baixocentro") else \
				candidate.contains("suburbio") if filename.contains("suburbio") else \
				(candidate.contains("centro") and not candidate.contains("baixo-centro"))
			_check(allowed, "Fundo de outro distrito em %s: %s" % [filename, candidate])
		scene.grid.ppp_background_path = background_path
		scene.grid.ppp_decoration_seed = 119
		scene._rebuild_visuals()
		_check(scenic.get_child_count() > 0,
			"O cenário distante deve aparecer em %s." % filename)
		_check(scenic.remaining_sky_fraction >= 0.40,
			"Ao menos 40%% do céu livre deve continuar visível em %s." % filename)
		_check(scenic.visible_bottom_screen_y < scene.get_ground_screen_top(),
			"A margem inferior do cenário deve ficar sob as fachadas em %s." % filename)
		_check(_facades_cover_line(scene, scenic.visible_bottom_screen_y),
			"As fachadas devem esconder toda a margem inferior em %s." % filename)
		var selected := scenic.active_asset_path
		scene._rebuild_visuals()
		_check(scenic.active_asset_path == selected,
			"Redesenhar o mapa não deve trocar o fundo sorteado em %s." % filename)
		for level in 4:
			scene._set_camera_level(level)
			for pan in [-scene._camera_pan_limit(), 0.0, scene._camera_pan_limit()]:
				scene._camera_pan_x = pan
				scene._camera_pan_target_x = pan
				scene._apply_camera_transform()
				var left := INF
				var right := -INF
				for child in scenic.get_children():
					var sprite := child as Sprite2D
					var half_width := float(sprite.texture.get_width()) * 0.5
					left = minf(left, sprite.to_global(Vector2(-half_width, 0.0)).x)
					right = maxf(right, sprite.to_global(Vector2(half_width, 0.0)).x)
				_check(left <= 0.0 and right >= scene.get_viewport_rect().size.x,
					"O cenário deve cobrir as laterais em %s, zoom %d." % [filename, level])
		scene._set_camera_level(1)
	sky.visuals_changed.emit("res://sprites/background/fundosparalax/cinzento_0001")
	_check(is_equal_approx(float(scenic._shared_material.get_shader_parameter(
		"grey_strength")), 1.0), "Céu cinzento deve intensificar o cinza do fundo.")
	sky.visuals_changed.emit("res://sprites/background/fundosparalax/manha_0001")
	_check(is_zero_approx(float(scenic._shared_material.get_shader_parameter(
		"grey_strength"))), "Céu normal deve restaurar as cores do fundo.")
	print("PPP_SCENIC_BACKDROP: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func _facades_cover_line(scene: PPPMapView, line_y: float) -> bool:
	var sprites: Array[Sprite2D] = [scene.get_node("MapRoot/Background") as Sprite2D]
	for child in (scene.get_node("MapRoot/BackgroundCopies") as Node2D).get_children():
		sprites.append(child as Sprite2D)
	var picture := sprites[0].texture.get_image()
	for column in 64:
		var point := Vector2((float(column) + 0.5) \
			* scene.get_viewport_rect().size.x / 64.0, line_y)
		var covered := false
		for sprite in sprites:
			var source := sprite.to_local(point) + Vector2(picture.get_size()) * 0.5
			var x := floori(source.x)
			var y := floori(source.y)
			if x >= 0 and x < picture.get_width() and y >= 0 \
					and y < picture.get_height() \
					and picture.get_pixel(x, y).a >= 0.70:
				covered = true
				break
		if not covered:
			return false
	return true
