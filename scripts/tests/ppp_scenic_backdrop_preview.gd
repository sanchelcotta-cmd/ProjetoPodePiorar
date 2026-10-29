extends SceneTree

const OUTPUT := "res://artifacts/"
const DAY_SKY := "res://sprites/background/fundosparalax/manha_0001"
const GREY_SKY := "res://sprites/background/fundosparalax/cinzento_0001"


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
		push_error("Não foi possível iniciar o mapa para as amostras de fundo.")
		quit(1)
		return
	await process_frame
	var cases := {
		"scenic_suburbio.png": ["cena_suburbio_0001.png", &"suburbio"],
		"scenic_baixo_centro.png": ["cena_baixocentro_0001.png", &"baixo_centro"],
		"scenic_centro.png": ["cena_centro_0001.png", &"centro"],
	}
	for filename in cases:
		var sample: Array = cases[filename]
		scene.grid.ppp_background_path = "res://sprites/background/" + sample[0]
		gerencia.campaign.district = sample[1]
		scene.grid.ppp_decoration_seed = 118
		scene.grid.ppp_parallax_path = DAY_SKY
		scene._rebuild_visuals()
		var sky := scene.get_node("ParallaxBackground") as PPPParallaxBackground
		sky.show_generated_map(scene.grid)
		(scene.get_node("CampaignTopBar") as CampaignTopBar).refresh()
		if not await _capture(filename):
			quit(1)
			return
	scene.grid.ppp_background_path = "res://sprites/background/cena_baixocentro_0001.png"
	gerencia.campaign.district = &"baixo_centro"
	scene.grid.ppp_parallax_path = GREY_SKY
	scene._rebuild_visuals()
	(scene.get_node("ParallaxBackground") as PPPParallaxBackground).show_generated_map(
		scene.grid)
	(scene.get_node("CampaignTopBar") as CampaignTopBar).refresh()
	if not await _capture("scenic_baixo_centro_cinzento.png"):
		quit(1)
		return
	quit(0)


func _capture(filename: String) -> bool:
	for _frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var path := OUTPUT + filename
	if image.save_png(path) != OK:
		return false
	print("Captura: ", path, " tamanho=", image.get_size())
	return true
