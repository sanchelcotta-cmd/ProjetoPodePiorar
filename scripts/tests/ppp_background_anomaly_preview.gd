extends SceneTree

## Capturas opcionais para conferir a profundidade do galo e do OVNI.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	if not gerencia.start_new_game(selected) or not rounds.start_first_map():
		push_error("Não foi possível criar o mapa de prévia.")
		quit(1)
		return
	var decoration := scene.get_node("MapRoot/DepthSorted/Decorations") \
		as PPPDecorationView
	var map_root := scene.get_node("MapRoot") as Node2D
	if not scene.force_decoration_anomaly(&"anomalia_galo"):
		push_error("Não foi possível forçar o galo.")
		quit(1)
		return
	decoration._anomaly_visual.position.x = root.size.x * 0.37 - map_root.position.x
	if not await _capture("ppp_galo_ao_fundo_preview.png"):
		quit(1)
		return
	if not scene.force_decoration_anomaly(&"anomalia_ovni"):
		push_error("Não foi possível forçar o OVNI.")
		quit(1)
		return
	decoration._anomaly_visual.position.x = root.size.x * 0.55 - map_root.position.x
	if not await _capture("ppp_ovni_entre_camadas_preview.png"):
		quit(1)
		return
	scene.queue_free()
	await process_frame
	quit(0)


func _capture(filename: String) -> bool:
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture == null or picture.is_empty():
		push_error("Renderizador não retornou a imagem de %s." % filename)
		return false
	var path := "user://" + filename
	if picture.save_png(path) != OK:
		push_error("Não foi possível salvar %s." % path)
		return false
	print("PREVIEW_IMAGE=", ProjectSettings.globalize_path(path))
	return true
