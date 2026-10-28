extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var block := scene.get_node("BlockManager") as BlockManager
	var rounds := scene.get_node("RoundManager") as RoundManager
	var auto := scene.get_node("CampaignAutosaveController")
	var repository := CampaignSaveRepository.new("user://ppp_pool4_terminal_queue_tests")
	gerencia.save_repository = repository
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(rng),
		"Campanha iniciou.")
	auto.set("enabled", true)
	var campaign := gerencia.campaign
	block._phase = BlockManager.Phase.WAITING_EVENT
	_check(campaign.mark_terminal(CampaignState.CampaignStatus.VICTORY),
		"Desfecho marcado durante Outcome pendente.")
	_check(gerencia.request_terminal_record().get("queued", false),
		"Livro terminal entrou na fila.")
	auto.call("_process", 0.1)
	_check(repository.list_terminal_lines(campaign.campaign_id).is_empty(),
		"A fila não captura um Outcome incompleto.")
	campaign.append_journal_entry(&"event_outcome", [
		{"text": "O resultado final foi confirmado.", "tone": "positive"}])
	block._phase = BlockManager.Phase.IDLE
	auto.call("_process", 0.1)
	var lines := repository.list_terminal_lines(campaign.campaign_id)
	_check(lines.size() == 1 and lines[0]["entries"][-1]["text"] \
		== "O resultado final foi confirmado.",
		"Livro imutável inclui o Outcome ao primeiro limite estável.")
	auto.call("request_terminal_record")
	auto.call("_process", 0.1)
	_check(repository.list_terminal_lines(campaign.campaign_id).size() == 1,
		"Pedido repetido não duplica o desfecho.")
	scene.queue_free()
	await process_frame
	print("PPP_TERMINAL_QUEUE_OK" if failures == 0 else
		"PPP_TERMINAL_QUEUE_FAIL:%d" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
