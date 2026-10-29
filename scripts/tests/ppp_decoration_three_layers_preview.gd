extends SceneTree

## Captura reproduzível do cenário com elementos A, B e C para inspeção visual.
const OUTPUT_THREE := "res://artifacts/decoration_three_posts.png"
const OUTPUT_FOUR := "res://artifacts/decoration_four_posts.png"


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
		push_error("Não foi possível iniciar o mapa para captura.")
		quit(1)
		return
	await process_frame
	var decoration := scene.get_node("MapRoot/DepthSorted/Decorations") \
		as PPPDecorationView
	var map_root := scene.get_node("MapRoot") as Node2D
	var background := scene.get_node("MapRoot/Background") as Sprite2D
	var copies := scene.get_node("MapRoot/BackgroundCopies") as Node2D
	var grid := scene.grid
	# Prévia das sombras sem a chuva encobrir o contraste do contato no chão.
	grid.ppp_parallax_path = PPPParallaxBackground.PREVIEW_SKY
	(scene.get_node("ParallaxBackground") as PPPParallaxBackground).show_generated_map(grid)
	grid.ppp_anomaly_planned = false
	grid.ppp_anomaly_kind = &""
	var captured := {}
	for seed in 200:
		grid.ppp_decoration_seed = seed + 1
		decoration.rebuild(grid, background, copies,
			decoration._ground_top, decoration._screen_size)
		var groups := {}
		var post_count := 0
		for child in decoration.get_children():
			if child is Node2D and child.has_meta("decoration_group"):
				var group := str(child.get_meta("decoration_group"))
				groups[group] = true
				if group == "C":
					post_count += 1
		if not groups.has_all(["A", "B", "C"]) \
				or post_count not in [3, 4] or captured.has(post_count):
			continue
		for _frame in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			push_error("Renderizador não retornou imagem de captura.")
			quit(1)
			return
		var output := OUTPUT_THREE if post_count == 3 else OUTPUT_FOUR
		var result := image.save_png(output)
		if result != OK:
			push_error("Não foi possível salvar: %s" % output)
			quit(1)
			return
		captured[post_count] = true
		print("Captura: ", output, " seed=", seed + 1,
			" ground=", decoration._ground_top,
			" tamanho=", image.get_size())
		if captured.size() == 2:
			break
	if captured.size() != 2:
		push_error("Não houve composição com 3 e 4 postes e três camadas.")
		quit(1)
		return
	quit(0)
