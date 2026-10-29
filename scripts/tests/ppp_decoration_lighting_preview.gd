extends SceneTree

## Capturas reais da iluminação no mesmo mapa e com a mesma composição.
const NIGHT_SKY := "res://sprites/background/fundosparalax/noite_0001"
const AFTERNOON_SKY := "res://sprites/background/fundosparalax/tarde_0001"
const OUTPUT := "res://artifacts/"


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
		push_error("Não foi possível iniciar o mapa para as capturas de luz.")
		quit(1)
		return
	await process_frame
	var grid := scene.grid
	grid.ppp_anomaly_planned = false
	grid.ppp_anomaly_kind = &""
	var decoration := scene.get_node("MapRoot/DepthSorted/Decorations") \
		as PPPDecorationView
	var background := scene.get_node("MapRoot/Background") as Sprite2D
	var copies := scene.get_node("MapRoot/BackgroundCopies") as Node2D
	var found_three_trees := false
	for seed in 240:
		grid.ppp_decoration_seed = seed + 1
		decoration.rebuild(grid, background, copies,
			decoration._ground_top, decoration._screen_size)
		var tree_count := 0
		var center_quaresmeira := false
		for entry in decoration.get_children():
			if entry.has_meta("decoration_kind") \
					and str(entry.get_meta("decoration_kind")) in PPPDecorationView.TREE_TYPES:
				tree_count += 1
				if str(entry.get_meta("decoration_kind")) == "quaresmeira" \
						and entry.global_position.x > 730.0 \
						and entry.global_position.x < 1050.0:
					center_quaresmeira = true
		if tree_count >= 3 and center_quaresmeira:
			found_three_trees = true
			print("Amostra com ", tree_count, " árvores; seed=", seed + 1)
			break
	if not found_three_trees:
		push_error("Não foi possível compor a amostra com árvore central.")
		quit(1)
		return
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	_set_period(scene, gerencia, top_bar, PPPMapGenerator.RoundPeriod.NIGHT, NIGHT_SKY)
	_set_post_colors(decoration)
	if not await _capture("post_light_normal_night.png"):
		quit(1)
		return
	if decoration._post_lights.size() < 2:
		push_error("São necessários pelo menos dois postes para a comparação.")
		quit(1)
		return
	# Só o poste central usa a variante verde: no jogo ela tem chance de 5% por poste.
	decoration.set_post_light_color(1, Color("#44f779"))
	if not await _capture("post_light_green_night.png"):
		quit(1)
		return
	if not scene.force_decoration_anomaly(&"anomalia_poste"):
		push_error("Não foi possível mostrar o poste com olho.")
		quit(1)
		return
	decoration._on_actor_moved(gerencia.campaign.active_entity_states[0],
		[Vector2i.ZERO], 1)
	if not await _capture("post_eye_red_night.png"):
		quit(1)
		return
	if not scene.force_decoration_anomaly(&"anomalia_arvore"):
		push_error("Não foi possível mostrar a árvore de fogo.")
		quit(1)
		return
	_set_post_colors(decoration)
	if not await _capture("fire_tree_night.png"):
		quit(1)
		return
	_set_period(scene, gerencia, top_bar,
		PPPMapGenerator.RoundPeriod.AFTERNOON, AFTERNOON_SKY)
	_set_post_colors(decoration)
	if not await _capture("fire_tree_afternoon.png"):
		quit(1)
		return
	_set_period(scene, gerencia, top_bar, PPPMapGenerator.RoundPeriod.NIGHT, NIGHT_SKY)
	if not scene.force_decoration_anomaly(&"anomalia_ovni"):
		push_error("Não foi possível mostrar o OVNI.")
		quit(1)
		return
	_set_post_colors(decoration)
	var flyer := decoration._anomaly_visual
	if flyer == null:
		push_error("O sprite do OVNI não foi criado.")
		quit(1)
		return
	var elapsed := 0.0
	while flyer.global_position.x > decoration._screen_size.x * 0.62 and elapsed < 10.0:
		await create_timer(0.1).timeout
		elapsed += 0.1
	if not await _capture("ufo_light_night.png"):
		quit(1)
		return
	grid.ppp_anomaly_planned = false
	grid.ppp_anomaly_kind = &""
	var found_clipped_fourth := false
	for seed in 240:
		grid.ppp_decoration_seed = seed + 1
		decoration.rebuild(grid, background, copies,
			decoration._ground_top, decoration._screen_size)
		var trees := 0
		var clipped := false
		for entry in decoration.get_children():
			if entry.has_meta("decoration_kind") \
					and str(entry.get_meta("decoration_kind")) in PPPDecorationView.TREE_TYPES:
				trees += 1
				if entry.global_position.x >= decoration._screen_size.x - 40.0:
					clipped = true
		if trees == 4 and clipped:
			found_clipped_fourth = true
			print("Amostra com quarta árvore cortada; seed=", seed + 1)
			break
	if not found_clipped_fourth:
		push_error("Não foi possível compor a amostra com quarta árvore na borda.")
		quit(1)
		return
	_set_period(scene, gerencia, top_bar,
		PPPMapGenerator.RoundPeriod.AFTERNOON, AFTERNOON_SKY)
	if not await _capture("four_trees_edge.png"):
		quit(1)
		return
	quit(0)


func _set_period(scene: PPPMapView, gerencia: GerenciaJogo,
		top_bar: CampaignTopBar, period: int, sky_path: String) -> void:
	gerencia.campaign.round_period = period
	scene.grid.ppp_parallax_path = sky_path
	scene.grid.ppp_parallax_filter = PPPParallaxBackground.SkyFilter.NONE
	scene.show_generated_map(scene.grid)
	top_bar.refresh()


func _set_post_colors(decoration: PPPDecorationView) -> void:
	for index in decoration._post_lights.size():
		decoration.set_post_light_color(index, Color("#ffdc9c"))


func _capture(filename: String) -> bool:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Renderizador não retornou a captura: %s" % filename)
		return false
	var path := OUTPUT + filename
	if image.save_png(path) != OK:
		push_error("Não foi possível salvar: %s" % path)
		return false
	print("Captura: ", path, " tamanho=", image.get_size())
	return true
