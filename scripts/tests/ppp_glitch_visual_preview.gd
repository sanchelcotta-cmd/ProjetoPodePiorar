extends SceneTree

## Gera três capturas reais do Evento 50; também serve como smoke test.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var comfort := root.get_node("VisualComfort")
	var comfort_before := bool(comfort.get("enabled"))
	comfort.call("set_enabled", false, false)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var controller := scene.get_node("GlitchVisualController") as GlitchVisualController
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	_check(gerencia.start_new_game(selected) and round_manager.start_first_map(),
		"Campanha e mapa devem iniciar.")
	var event := load("res://resources/events/random_events/50-glitch_atemporal.tres") as EventData
	var effect := event.outcomes[0].effects[0]
	var actor := gerencia.campaign.active_entity_states[0]
	var coord := Vector2i(0, 0)
	var grid := gerencia.campaign.current_map
	var context := {"actor": actor, "map": gerencia.campaign.current_map,
		"resource": event, "decision": {}}
	_check(executor._unsupported_reason(effect, context).is_empty(),
		"Glitch Atemporal deve ser executável.")
	actor.position = coord
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	_check(block.begin_activation(coord, actor) and popup.overlay.visible,
		"Hex abre a narrativa sem aplicar o filtro.")
	_check(not controller.active, "Narrativa não aplica o efeito antes do OK.")
	_check(not controller._terminal_layer.visible,
		"Letreiro terminal fica oculto antes da aplicação do Outcome.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(block.is_busy() and popup._outcome_reading and not controller.active,
		"Primeiro OK apresenta o Outcome sem aplicar o filtro.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(controller.active and not block.is_busy() and not popup.overlay.visible,
		"Segundo OK aplica o filtro e libera o bloco.")
	_check(controller._terminal_layer.visible
		and controller._terminal_banner.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and controller._terminal_banner.get_node("Title").mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Letreiro fica visível sem interceptar cliques.")
	_check(controller.active and controller._original_scene_materials.has(scene.get_node("MapRoot/Background")),
		"Cenário recebe pixelização intensificada.")
	var actor_sprites := 0
	for item in controller._original_scene_materials:
		if item is AnimatedSprite2D:
			actor_sprites += 1
	_check(actor_sprites >= 3, "Entidades também recebem pixelização e bordas cromáticas.")
	var decoration_sprites := 0
	for item in controller._original_scene_materials:
		if item is Sprite2D and item.name == "DecorationSprite":
			decoration_sprites += 1
	_check(decoration_sprites >= 3,
		"Objetos decorativos também recebem o filtro do Glitch Atemporal.")
	var decoration := scene.get_node("MapRoot/DepthSorted/Decorations") as PPPDecorationView
	var decoration_rng := RandomNumberGenerator.new()
	for fixture in [
		{"kind": "lixeira_latao", "group": "A", "x": -1000.0, "y": 0.0},
		{"kind": "quaresmeira", "group": "B", "x": -1100.0, "y": 0.0},
		{"kind": "poste_tradicional", "group": "C", "x": -1200.0, "y": 0.0},
		{"kind": "lixeira_brasileira", "group": "A", "x": -1300.0,
			"y": 0.0, "anomaly": "anomalia_lixeira"},
	]:
		decoration._render_entry(fixture, decoration_rng)
		var root_item := decoration.get_child(decoration.get_child_count() - 1)
		controller._scan_visuals()
		var art := root_item.get_child(0) as CanvasItem
		_check(art != null and art.material == controller._pixel_material,
			"Glitch altera a decoração %s." % fixture["kind"])
	_check(controller._actor_pixel_material.get_shader_parameter("amount") == 2.0
		and controller._sky_pixel_material.get_shader_parameter("amount") == 4.0
		and controller._pixel_material.get_shader_parameter("amount") == 8.0,
		"Personagens e céu devem ser mais nítidos que as casas e o chão.")
	var output_dir := "res://docs/glitch_preview"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	for index in 3:
		controller.show_preview_mode(index)
		await process_frame
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var name: String = ["normal", "distorcao", "gameboy"][index]
		var path := "%s/%s.png" % [output_dir, name]
		_check(image != null and image.save_png(path) == OK,
			"Captura %s deve ser gravada." % name)
	var carreta := scene.get_node("CarretaVisualController") as CarretaVisualController
	var rainbow_veil := carreta._veil
	var rainbow_material := rainbow_veil.material
	var weather_grade := scene.get_node("GreyWeatherGrade/ColorRect") as ColorRect
	var weather_material := weather_grade.material
	carreta.start_effect()
	controller._scan_visuals()
	_check(rainbow_veil.material == rainbow_material
		and weather_grade.material == weather_material,
		"Glitch não substitui os shaders de outros filtros do cenário.")
	for frame in 3:
		await process_frame
	_check(_map_is_visible(root.get_texture().get_image()),
		"Glitch e Carreta juntos não podem deixar o mapa branco.")
	grid.ppp_parallax_path = "res://sprites/background/fundosparalax/cinzento_0001"
	var sky := scene.get_node("ParallaxBackground") as PPPParallaxBackground
	sky.show_generated_map(grid)
	controller.show_preview_mode(0)
	for frame in 5:
		await process_frame
	var rain := scene.get_node("GreySkyRain") as GreySkyRain
	_check(rain._raining, "Céu cinzento ativa a chuva no teste de Glitch.")
	_check(_map_is_visible(root.get_texture().get_image()),
		"Chuva, Glitch e Carreta juntos não podem deixar o mapa branco.")
	carreta.stop_effect()
	for rainy_mode in 3:
		controller.show_preview_mode(rainy_mode)
		for frame in 3:
			await process_frame
		var rainy_image := root.get_texture().get_image()
		if rainy_mode == 0:
			_check(rainy_image != null and rainy_image.save_png(
				"%s/chuva.png" % output_dir) == OK,
				"Captura de Glitch com chuva deve ser gravada.")
		if rainy_image != null:
			var white_samples := 0
			var total_samples := 0
			for y in range(180, 730, 55):
				for x in range(380, 1320, 55):
					var color := rainy_image.get_pixel(x, y)
					total_samples += 1
					if color.r > 0.96 and color.g > 0.96 and color.b > 0.96:
						white_samples += 1
			_check(white_samples < total_samples / 2,
				"Glitch com chuva não pode tornar o mapa branco no modo %d." % rainy_mode)
	controller._on_turn_finished(actor)
	_check(controller.active, "Glitch permanece durante o próximo turno.")
	controller._on_turn_finished(actor)
	_check(not controller.active and controller._original_scene_materials.is_empty(),
		"Fim do turno restaura os materiais anteriores.")
	await process_frame
	_check((scene.get_node("GreyWeatherGrade/ColorRect") as ColorRect).visible,
		"Película cinzenta retorna depois que o Glitch termina.")
	await process_frame
	var restored_image := root.get_texture().get_image()
	if restored_image != null:
		var white_after := 0
		var sampled_after := 0
		for y in range(180, 730, 55):
			for x in range(380, 1320, 55):
				var color := restored_image.get_pixel(x, y)
				sampled_after += 1
				if color.r > 0.96 and color.g > 0.96 and color.b > 0.96:
					white_after += 1
		_check(white_after < sampled_after / 2,
			"Mapa com chuva também deve permanecer visível após o Glitch.")
	_check(not controller._terminal_layer.visible,
		"Letreiro desaparece junto com o filtro.")
	print("PPP_GLITCH_PREVIEW_OK" if failures == 0 else "PPP_GLITCH_PREVIEW_FAILED:%d" % failures)
	comfort.call("set_enabled", comfort_before, false)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _map_is_visible(image: Image) -> bool:
	if image == null:
		return false
	var white := 0
	var total := 0
	for y in range(180, 730, 55):
		for x in range(380, 1320, 55):
			var color := image.get_pixel(x, y)
			total += 1
			if color.r > 0.96 and color.g > 0.96 and color.b > 0.96:
				white += 1
	return white < total / 2
