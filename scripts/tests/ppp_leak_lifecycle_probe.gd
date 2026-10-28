extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if "scene" in args:
		var scene := load("res://teste.tscn").instantiate() as PPPMapView
		root.add_child(scene)
		await process_frame
		if "campaign" in args:
			var game := scene.get_node("GerenciaJogo") as GerenciaJogo
			var rounds := scene.get_node("RoundManager") as RoundManager
			var data: Array[EntityData] = [
				load("res://resources/entities/entities_playable/mae.tres"),
				load("res://resources/entities/entities_playable/pedreiro.tres"),
				load("res://resources/entities/entities_playable/jornalista.tres"),
			]
			game.start_new_game(data)
			rounds.start_first_map()
			await process_frame
		if "free" in args:
			scene.queue_free()
			for index in 4:
				await process_frame
	print("LEAK_LIFECYCLE_PROBE_OK")
	quit()
