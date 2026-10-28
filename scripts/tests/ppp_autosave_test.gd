extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var auto := scene.get_node("CampaignAutosaveController")
	var repository := CampaignSaveRepository.new("user://ppp_pool4_auto_tests")
	gerencia.save_repository = repository
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1482
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(rng),
		"Campanha deve iniciar.")
	auto.enabled = true
	await process_frame
	var campaign := gerencia.campaign
	_check(FileAccess.file_exists(repository._session_path(campaign.campaign_id)),
		"Sessão aberta tem marca de recuperação.")
	_check(_slots_for(repository, campaign.campaign_id).is_empty(),
		"Iniciar não cria slot manual.")
	block._phase = BlockManager.Phase.WAITING_EVENT
	var pending := gerencia.save_manual_slot(1)
	_check(pending.get("queued", false) and not FileAccess.file_exists(
		repository._slot_path(campaign.campaign_id, 1)),
		"Pedido manual aguarda ação incompleta sem ocupar o slot.")
	block._phase = BlockManager.Phase.IDLE
	await process_frame
	_check(FileAccess.file_exists(repository._slot_path(campaign.campaign_id, 1)),
		"Pedido manual é gravado no primeiro limite estável.")
	combat._attack_animation_pending = true
	var information := gerencia.get_information_catalog()[0] as Informacao
	var grant := gerencia.grant_information(information)
	_check(grant.get("success", false) and &"informacao" in auto._pending_auto,
		"Obter Informação aciona autosave pela origem real.")
	_check(rounds.round_advanced.is_connected(Callable(auto, "_on_round_advanced"))
		and combat.combat_finished.is_connected(Callable(auto, "_on_combat_finished")),
		"Virada de Rodada e vitória em Combate estão ligadas aos gatilhos.")
	await process_frame
	_check(not FileAccess.file_exists(repository._autosave_path(campaign.campaign_id)),
		"Autosave não captura animação de ação.")
	combat._attack_animation_pending = false
	await process_frame
	_check(FileAccess.file_exists(repository._autosave_path(campaign.campaign_id))
		and _slots_for(repository, campaign.campaign_id).size() == 1,
		"Backup oculto não é quarto slot manual.")
	var recoveries := repository.list_recoverable_autosaves()
	var own_recovery_time := ""
	for recovery in recoveries:
		if recovery["campaign_id"] == campaign.campaign_id:
			own_recovery_time = str(recovery["saved_at"])
	_check(not own_recovery_time.is_empty(),
		"Recuperação oferece data e hora após interrupção.")
	var fresh := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(fresh)
	await process_frame
	var restored := repository.load_autosave(campaign.campaign_id, fresh)
	_check(restored.get("success", false) and
		(fresh.get_node("GerenciaJogo") as GerenciaJogo).campaign.campaign_id
		== campaign.campaign_id,
		"Recuperação carrega somente em memória.")
	_check(_slots_for(repository, campaign.campaign_id).size() == 1,
		"Recuperação não sobrescreve save manual.")
	auto.set_save_panel_open(true)
	auto.seconds_since_autosave = 1200.0 - 0.1
	auto._process(0.2)
	_check(&"vinte_minutos" not in auto._pending_auto,
		"Tempo em menu não conta como jogo ativo.")
	auto.set_save_panel_open(false)
	auto._process(0.2)
	_check(auto.seconds_since_autosave < 1.0,
		"Vinte minutos ativos pedem salvaguarda e reiniciam o relógio após gravar.")
	auto.request_autosave(&"virada_rodada")
	auto._process(0.1)
	var broken := FileAccess.open(repository._autosave_path(campaign.campaign_id),
		FileAccess.WRITE)
	broken.store_string("autosave de teste corrompido")
	broken.close()
	var recovered_backup := repository.load_autosave(campaign.campaign_id)
	_check(recovered_backup.get("success", false)
		and recovered_backup.get("used_backup", false),
		"Autosave anterior válido recupera arquivo principal corrompido.")
	_check(repository.mark_session_closed(campaign.campaign_id)
		and not _has_recovery(repository, campaign.campaign_id)
		and repository.mark_session_open(campaign.campaign_id),
		"Saída normal não é oferecida como interrupção forçada.")
	_check(auto.confirm_exit_without_saving()
		and not _has_recovery(repository, campaign.campaign_id)
		and _slots_for(repository, campaign.campaign_id).size() == 1,
		"Sair sem salvar descarta somente o backup oculto.")
	print("PPP_AUTOSAVE_OK" if failures == 0 else "PPP_AUTOSAVE_FAILED")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _slots_for(repository: CampaignSaveRepository, campaign_id: String) -> Array:
	for entry in repository.list_campaigns():
		if entry["campaign_id"] == campaign_id:
			return entry["slots"]
	return []


func _has_recovery(repository: CampaignSaveRepository, campaign_id: String) -> bool:
	for entry in repository.list_recoverable_autosaves():
		if entry["campaign_id"] == campaign_id:
			return true
	return false
