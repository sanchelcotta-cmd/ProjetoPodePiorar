extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData,
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
	]
	var campaign := CampaignState.new()
	_check(campaign.start_new_game(party, 41, null,
		EventCampaignEligibility.Mode.SHORT, [&"orchestra"]),
		"Campanha de teste foi preparada.")
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	game.set_meta("defer_preview_map", true)
	var repository := CampaignSaveRepository.new(
		"user://ppp_progressive_scene_health_%d" % Time.get_ticks_usec())
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	gerencia.campaign = campaign
	gerencia.save_repository = repository
	game.visible = false
	root.add_child(game)
	var bar := game.get_node("CampaignTopBar") as CampaignTopBar
	_check(not bar.is_initial_ui_ready() and game.get("_renderer") == null,
		"A cena-base não monta painéis ocultos nem hexes na entrada.")
	_check(await game.prepare_initial_interface(),
		"Interface progressiva terminou antes de mostrar o jogo.")
	_check(bar.is_initial_ui_ready() and bar.pause_menu._panels_ready
		and bar.pause_menu._settings_menu._contents_ready,
		"Pausa e Configurações foram preparadas em etapas.")
	var rounds := game.get_node("RoundManager") as RoundManager
	_check(rounds.start_first_map() and gerencia.campaign.current_map != null,
		"Mapa lógico foi instalado sem precisar desenhar a cena no mesmo quadro.")
	_check(game.get("_pending_initial_visuals") and game.get("_renderer") == null,
		"Hexes permanecem pendentes até a preparação visual explícita.")
	_check(await game.prepare_initial_visuals(),
		"Montagem visual em lotes terminou com sucesso.")
	_check(game.get("_initial_visuals_prepared")
		and not game.get("_pending_initial_visuals")
		and game.get("_renderer") != null
		and game.get_node("MapRoot/Hexes").get_child_count() >= 41,
		"Os 40 hexes e o realce final existem antes de revelar o jogo.")
	repository.abandon_campaign(campaign.campaign_id, true)
	game.queue_free()
	await process_frame
	print("PPP_PROGRESSIVE_SCENE_HEALTH: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
