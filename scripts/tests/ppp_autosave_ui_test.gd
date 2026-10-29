extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var repository := CampaignSaveRepository.new("user://ppp_pool4_ui_tests")
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(game)
	await process_frame
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	gerencia.save_repository = repository
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5983
	_check(gerencia.start_new_game(selected) and
		(game.get_node("RoundManager") as RoundManager).start_first_map(rng),
		"Campanha da interface inicia.")
	var campaign_id := gerencia.campaign.campaign_id
	var auto := game.get_node("CampaignAutosaveController")
	auto.enabled = true
	await process_frame
	auto.request_autosave(&"informacao")
	await process_frame
	_check(repository.list_recoverable_autosaves().any(func(entry: Dictionary) -> bool:
		return entry["campaign_id"] == campaign_id),
		"Backup aparece com sessão aberta.")
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() as PlayableSelectionScreen
	root.add_child(selection)
	await process_frame
	selection._load_repository = repository
	selection._load_panel.set("repository", repository)
	selection._open_load_panel()
	await selection._load_panel.refreshed
	var recovery_button: Button
	var rows := selection._load_panel.get("_rows") as VBoxContainer
	for row in rows.get_children():
		var belongs_to_campaign := false
		for child in row.get_children():
			if child is Label and child.text.contains(campaign_id.substr(0, 8)):
				belongs_to_campaign = true
		for child in row.get_children():
			if belongs_to_campaign and child is Button and child.text == "RECUPERAR":
				recovery_button = child
				break
	_check(recovery_button != null and selection._load_panel.visible,
		"Tela de carregamento mostra recuperação separada.")
	if recovery_button != null:
		recovery_button.pressed.emit()
	for _frame in 40:
		if current_scene is PPPMapView:
			break
		await process_frame
	await process_frame
	await process_frame
	var restored := current_scene as PPPMapView
	_check(restored != null and (restored.get_node("GerenciaJogo") as GerenciaJogo)
		.campaign.campaign_id == campaign_id,
		"Recuperação pela interface carrega campanha em memória.")
	if restored != null:
		var bar := restored.get_node("CampaignTopBar") as CampaignTopBar
		var occupied_before_choice := false
		for entry in repository.list_campaigns():
			occupied_before_choice = occupied_before_choice or entry["campaign_id"] == campaign_id
		_check(bar._save_dialog.visible and not occupied_before_choice,
			"Janela pede escolha de slot, sem salvar por conta própria.")
		bar._save_slot_options.select(0)
		bar._save_dialog.confirmed.emit()
		var saved := false
		for entry in repository.list_campaigns():
			if entry["campaign_id"] == campaign_id:
				saved = entry["slots"].size() == 1 and entry["slots"][0]["slot_number"] == 1
		_check(saved, "Escolher explicitamente o slot grava o save manual.")
	print("PPP_AUTOSAVE_UI_OK" if failures == 0 else "PPP_AUTOSAVE_UI_FAILED")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
