extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var repository := CampaignSaveRepository.new("user://ppp_pool5_load_confirmation_test")
	var game := load("res://teste.tscn").instantiate() as PPPMapView
	(game.get_node("GerenciaJogo") as GerenciaJogo).save_repository = repository
	root.add_child(game)
	current_scene = game
	await process_frame
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4215
	check(gerencia.start_new_game(selected) and
		(game.get_node("RoundManager") as RoundManager).start_first_map(rng),
		"A campanha de teste inicia com mapa jogável.")
	var campaign_id := gerencia.campaign.campaign_id
	check(repository.save_campaign(gerencia.campaign, 1, game).get("success", false),
		"O slot 1 guarda o estado anterior.")
	gerencia.campaign.append_journal_entry(&"test_unsaved", [
		{"text": "Progresso ainda não salvo", "tone": "text"}])
	var pause = (game.get_node("CampaignTopBar") as CampaignTopBar).pause_menu
	pause.open()
	pause._load_panel.open()
	pause._on_load_requested(campaign_id, 1, false)
	check(pause._load_confirmation.visible and current_scene == game
		and not pause._pending_load.is_empty(),
		"Pedir carga não substitui a campanha antes da confirmação.")
	pause._load_confirmation.hide()
	pause._confirm_pending_load()
	pause._on_load_requested(campaign_id, 1, false)
	var loading_overlays := 0
	for child in root.get_children():
		if child is SceneLoadingOverlay:
			loading_overlays += 1
	check(loading_overlays == 1,
		"Cliques repetidos durante a carga não criam duas transições.")
	for attempt in 180:
		if current_scene != game:
			break
		await process_frame
	var loaded := current_scene as PPPMapView
	check(loaded != null and loaded != game,
		"Confirmar carrega a cena do slot escolhido.")
	if loaded != null:
		var restored := (loaded.get_node("GerenciaJogo") as GerenciaJogo).campaign
		check(restored.campaign_id == campaign_id and
			restored.journal_entries.is_empty(),
			"Somente após confirmar, o progresso não salvo deixa a memória.")
	check(not paused, "A nova campanha não permanece pausada após carregar.")
	repository.abandon_campaign(campaign_id, true)
	print("PPP_POOL5_LOAD_CONFIRMATION_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
