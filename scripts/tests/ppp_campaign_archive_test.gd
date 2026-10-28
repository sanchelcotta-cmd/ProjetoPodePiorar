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
	# O catálogo é persistente entre execuções; isolar esta rodada evita que
	# campanhas de testes antigos alterem a contagem esperada de pastas.
	var repository := CampaignSaveRepository.new(
		"user://ppp_pool4_archive_tests_%d" % Time.get_ticks_usec())
	gerencia.save_repository = repository
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 860
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(rng),
		"Campanha de teste iniciou.")
	var campaign := gerencia.campaign
	var campaign_id := campaign.campaign_id
	_check(not repository.archive_campaign(campaign_id).get("success", false),
		"Campanha sem desfecho não arquiva.")
	campaign.append_journal_entry(&"event_outcome", [
		{"text": "Primeira decisão.", "tone": "text"}], &"actor_a",
		{"event_id": "ev_test_a"})
	_check(repository.save_campaign(campaign, 1, scene).get("success", false),
		"Slot anterior ao final salvo.")
	campaign.append_journal_entry(&"information", [
		{"text": "Informação do futuro A.", "tone": "information"}])
	_check(campaign.mark_terminal(CampaignState.CampaignStatus.VICTORY),
		"Primeiro desfecho concluído.")
	var first := repository.record_terminal_line(campaign)
	_check(first.get("success", false) and repository.record_terminal_line(campaign)
		.get("already_recorded", false), "Registro terminal é imutável e único por conclusão.")
	var first_header := repository.inspect_terminal_line_header(
		campaign_id, str(first.get("line_id", "")))
	_check(first.get("index_written", false) and first_header.get("mode", -1) \
		== campaign.campaign_mode and not first_header.has("entries"),
		"Catálogo de livros usa só metadados; não decodifica entries.")
	var meta_path := repository.call("_terminal_meta_path", campaign_id,
		str(first.get("line_id", ""))) as String
	var broken_meta := FileAccess.open(meta_path, FileAccess.WRITE)
	if broken_meta != null:
		broken_meta.store_string("{indice corrompido")
		broken_meta.close()
	var fallback_header := repository.inspect_terminal_line_header(
		campaign_id, str(first.get("line_id", "")))
	_check(fallback_header.get("legacy", false) and not fallback_header.has("entries")
		and not repository.inspect_terminal_line(campaign_id,
			str(first.get("line_id", ""))).get("entries", []).is_empty(),
		"Índice corrompido não decodifica a lista nem impede abrir o livro por ID.")
	_check(repository.list_terminal_lines(campaign_id).size() == 1,
		"Primeiro livro terminal preservado.")
	var loaded := repository.load_campaign(campaign_id, 1, scene)
	_check(loaded.get("success", false) and not gerencia.campaign.is_terminal(),
		"Slot anterior retorna a campanha ativa.")
	_check(gerencia.campaign.journal_entries.size() == 1,
		"Carregar slot antigo não traz o futuro da primeira linha.")
	gerencia.campaign.append_journal_entry(&"craft_item", [
		{"text": "Item do futuro B.", "tone": "item"}])
	_check(gerencia.campaign.mark_terminal(CampaignState.CampaignStatus.DEFEAT),
		"Segundo desfecho concluído a partir do mesmo slot.")
	var second := repository.record_terminal_line(gerencia.campaign)
	var lines := repository.list_terminal_lines(campaign_id)
	_check(second.get("success", false) and lines.size() == 2 \
		and first.get("line_id") != second.get("line_id"),
		"Finais alternativos têm IDs e arquivos separados.")
	var first_text := str(lines[0]["entries"][-2]["text"])
	var second_text := str(lines[1]["entries"][-2]["text"])
	_check(first_text != second_text,
		"Cada livro mantém apenas a própria sequência de acontecimentos.")
	# O mapa de teste pode abrir um diálogo narrativo exclusivo no início;
	# ele não faz parte da biblioteca que será exercitada abaixo.
	for window in scene.find_children("*", "Window", true, false):
		(window as Window).hide()
	var library := load("res://scripts/ui/campaign_archive_library.gd").new() as Control
	library.set("repository", repository)
	root.add_child(library)
	library.call("open")
	await library.refreshed
	var folders := (library.get("_grid") as GridContainer).find_children(
		"ArchiveFolder_*", "Button", false, false)
	_check(folders.size() == 1 and _folder_has_label(folders[0], "Concluída em:"),
		"Registros inclui campanha concluída ainda não arquivada.")
	library.call("_select_folder", {"campaign_id": campaign_id,
		"lines": [first_header]})
	library.call("_open_book")
	_check((library.get("_selected_campaign") as Dictionary)["lines"][0].has("entries"),
		"Livro escolhido é decodificado somente após abrir.")
	library.call("_close_overlay")
	var load_panel: Control = load("res://scripts/ui/campaign_load_panel.gd").new()
	load_panel.set("repository", repository)
	root.add_child(load_panel)
	load_panel.call("open")
	await load_panel.refreshed
	var archive_button: Button
	for candidate in load_panel.find_children("*", "Button", true, false):
		if (candidate as Button).text == "ARQUIVAR DE VEZ":
			archive_button = candidate as Button
			break
	_check(archive_button != null, "Campanha concluída oferece Arquivar de vez na UI.")
	var abandon_button: Button
	for candidate in load_panel.find_children("*", "Button", true, false):
		if (candidate as Button).text == "EXCLUIR DE VEZ":
			abandon_button = candidate as Button
			break
	var palette := root.get_node("UIColorManager")
	_check(abandon_button != null and \
		(abandon_button.get_theme_stylebox("normal") as StyleBoxFlat).border_color \
		== palette.call("color", "danger"), "Excluir campanha usa cor de perigo do tema.")
	if archive_button != null:
		_check(abandon_button != null and archive_button.get_parent() == abandon_button.get_parent() \
			and archive_button.get_index() < abandon_button.get_index() \
			and archive_button.get_parent().get_child(0) is Label,
			"Título, Arquivar de vez e Excluir de vez dividem a mesma linha nessa ordem.")
		_check((archive_button.get_theme_stylebox("normal") as StyleBoxFlat).border_color \
			== palette.call("color", "warning"), "Arquivar de vez usa cor de aviso do tema.")
		# A partida de teste pode reabrir o aviso narrativo enquanto a biblioteca
		# está sendo montada; ele não pertence ao fluxo sob teste.
		for window in scene.find_children("*", "Window", true, false):
			(window as Window).hide()
		archive_button.pressed.emit()
		_check((load_panel.get("_archive_dialog") as ConfirmationDialog).visible,
			"Arquivamento exige confirmação visível.")
		(load_panel.get("_archive_dialog") as ConfirmationDialog).confirmed.emit()
		await load_panel.refreshed
	_check(repository.is_archived(campaign_id),
		"Confirmar pela UI arquiva sem apagar o histórico.")
	library.call("open")
	await library.refreshed
	folders = (library.get("_grid") as GridContainer).find_children(
		"ArchiveFolder_*", "Button", false, false)
	_check(folders.size() == 1 and _folder_has_label(folders[0], "Arquivada em:"),
		"A mesma pasta continua consultável depois de arquivar, sem duplicata.")
	_check(repository.list_campaigns().all(func(entry: Dictionary) -> bool:
		return entry["campaign_id"] != campaign_id) \
		and repository.list_archived_campaigns().any(func(entry: Dictionary) -> bool:
		return entry["campaign_id"] == campaign_id),
		"Arquivo sai dos slots ativos e fica consultável.")
	_check(not repository.load_campaign(campaign_id, 1).get("success", false) \
		and not repository.save_campaign(gerencia.campaign, 2, scene).get("success", false),
		"Arquivo congelado não pode ser carregado para jogar nem salvo.")
	_check(not repository.summarize_terminal_line(lines[0]).is_empty(),
		"Resumo por Rodada deriva do livro terminal.")
	_check(not repository.delete_archived_campaign(campaign_id).get("success", false),
		"Exclusão exige confirmação explícita.")
	_check(repository.delete_archived_campaign(campaign_id, true).get("success", false),
		"Exclusão confirmada remove somente esta campanha de teste.")
	_check(not repository.is_archived(campaign_id) and
		repository.list_terminal_lines(campaign_id).is_empty(),
		"Livro e slots do arquivo excluído não ficam recuperáveis.")
	load_panel.queue_free()
	library.queue_free()
	scene.queue_free()
	await process_frame
	print("PPP_CAMPAIGN_ARCHIVE_OK" if failures == 0 else
		"PPP_CAMPAIGN_ARCHIVE_FAIL:%d" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _folder_has_label(folder: Button, prefix: String) -> bool:
	for label in folder.find_children("*", "Label", true, false):
		if (label as Label).text.begins_with(prefix):
			return true
	return false
