extends SceneTree

## Gera três capturas reais do Evento 50; também serve como smoke test.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
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
	controller._on_turn_finished(actor)
	_check(controller.active, "Glitch permanece durante o próximo turno.")
	controller._on_turn_finished(actor)
	_check(not controller.active and controller._original_scene_materials.is_empty(),
		"Fim do turno restaura os materiais anteriores.")
	_check(not controller._terminal_layer.visible,
		"Letreiro desaparece junto com o filtro.")
	print("PPP_GLITCH_PREVIEW_OK" if failures == 0 else "PPP_GLITCH_PREVIEW_FAILED:%d" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
