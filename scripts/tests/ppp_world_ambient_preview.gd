extends SceneTree

## Gera comparativos reais do cenário sem modificar um save do jogador.
## Uso: --script res://scripts/tests/ppp_world_ambient_preview.gd -- <pasta>
func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData,
	]
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	if not gerencia.start_new_game(selected):
		push_error("Não foi possível criar a campanha de prévia.")
		quit(1)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 17719
	if not (scene.get_node("RoundManager") as RoundManager).start_first_map(rng):
		push_error("Não foi possível gerar o mapa de prévia.")
		quit(1)
		return
	var sky := scene.get_node("ParallaxBackground") as PPPParallaxBackground
	var ambient := scene.get_node("WorldAmbientLighting") as WorldAmbientLighting
	var shadows := scene.get_node("MapRoot/ActorGroundShadows") as ActorGroundShadows
	ambient.transition_seconds = 0.0
	var output := "user://ambient_previews"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var variants := [
		{"name": "tarde", "period": PPPMapGenerator.RoundPeriod.AFTERNOON,
			"sky": "tarde_0001"},
		{"name": "noite", "period": PPPMapGenerator.RoundPeriod.NIGHT,
			"sky": "noite_0001"},
		{"name": "cinzento_chuva", "period": PPPMapGenerator.RoundPeriod.AFTERNOON,
			"sky": "cinzento_0001"},
	]
	for variant in variants:
		gerencia.campaign.round_period = variant.period
		gerencia.campaign.current_map.ppp_parallax_path = \
			"res://sprites/background/fundosparalax/%s" % variant.sky
		sky.show_generated_map(gerencia.campaign.current_map)
		ambient._refresh(true)
		for frame in 12:
			await process_frame
		var image := root.get_texture().get_image()
		if image == null:
			push_error("O renderizador atual não oferece imagem de prévia.")
			quit(1)
			return
		var path := ProjectSettings.globalize_path(
			output.path_join("%s.png" % variant.name))
		var error := image.save_png(path)
		if error != OK:
			push_error("Falha ao salvar prévia %s: %d" % [path, error])
		else:
			print("PREVIEW_SAVED ", path)
		if variant.name == "tarde":
			var detail := image.get_region(Rect2i(210, 315, 590, 315))
			var detail_path := ProjectSettings.globalize_path(
				output.path_join("sombras_detalhe.png"))
			if detail.save_png(detail_path) == OK:
				print("PREVIEW_SAVED ", detail_path)
			shadows.hide()
			await process_frame
			var without := root.get_texture().get_image().get_region(
				Rect2i(210, 315, 590, 315))
			var without_path := ProjectSettings.globalize_path(
				output.path_join("sombras_comparativo_sem.png"))
			if without.save_png(without_path) == OK:
				print("PREVIEW_SAVED ", without_path)
			shadows.show()
	quit()
