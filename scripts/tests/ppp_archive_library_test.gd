extends SceneTree

const LIBRARY_SCRIPT := preload("res://scripts/ui/campaign_archive_library.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var library = LIBRARY_SCRIPT.new()
	# Isola o catálogo do teste dos saves reais do jogador.
	library.repository = CampaignSaveRepository.new(
		"user://ppp_archive_library_test_%d" % Time.get_ticks_usec())
	root.add_child(library)
	await process_frame
	var first_line := _fixture_line()
	var second_line := _fixture_line()
	second_line["status"] = CampaignState.CampaignStatus.DEFEAT
	second_line["entries"] = [first_line["entries"][0]]
	var archive := {"campaign_id": "preview-a", "archived_at": "2026-10-21T14:30:00",
		"lines": [first_line, second_line]}
	var summary: Array[Dictionary] = library.repository.summarize_archive_line(first_line)
	_check(summary.size() == 2, "Livro separa Dia/Rodada em duas entradas.")
	_check(summary[0]["events"] == ["A Florzinha"] and summary[0]["group_damage"] == 18,
		"Evento e dano causado pelo grupo vêm dos fatos registrados.")
	_check(summary[0]["encounter"]["name"] == "Zumbis Dançarinos" \
		and summary[0]["encounter"]["damage_taken"] == 9,
		"Encontro mais desafiador contabiliza dano sofrido.")
	_check(summary[1]["crafted"] == ["Espada Flamejante"] \
		and summary[1]["deaths"] == ["Pedreiro"] \
		and summary[1]["recruits"] == ["Professora"],
		"Segundo dia exibe criação, morte e recrutamento.")
	var defeat_line := _fixture_line()
	(defeat_line["entries"] as Array).append(_entry(11, 3, 2, "centro",
		"encounter_started", [{"text": "A Experiência", "tone": "negative"}]))
	(defeat_line["entries"] as Array).append(_entry(12, 3, 2, "centro",
		"playable_death", [{"text": "Jornalista", "tone": "actor"}]))
	var defeat_summary: Array[Dictionary] = library.repository.summarize_archive_line(defeat_line)
	_check(defeat_summary[-1]["encounter"]["name"] == "A Experiência" \
		and defeat_summary[-1]["encounter"]["deaths"] == 1,
		"Encontro fatal aparece mesmo sem ação combat_finished.")
	library.open()
	library._add_folder(archive, 0)
	library._total.text = "1 arquivo"
	library._layout()
	await process_frame
	_check(library._grid.columns == 5 \
		and library._grid.find_children("ArchiveFolder_*", "Button", false, false).size() == 1,
		"Biblioteca usa cinco colunas no espaço normal.")
	library._select_folder(archive)
	_check(library._confirm.visible and not library._book.visible,
		"Pasta pede confirmação antes do livro.")
	library._open_book()
	_check(library._book.visible and not library._confirm.visible \
		and library._book_rows.get_child_count() == 2,
		"Livro sobrepõe menu e mostra as duas rodadas.")
	var first_rich := library._book_rows.get_child(0).find_children(
		"*", "RichTextLabel", true, false)[0] as RichTextLabel
	_check(first_rich.get_parsed_text().contains(
		"Erro de registro - Fonte de referência não localizada") \
		and not first_rich.get_parsed_text().contains("Nenhum registrado."),
		"Campos sem acontecimento usam o aviso de referência definido para o livro.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.25).timeout
		RenderingServer.force_draw(false)
		var preview_path := "user://ppp_archive_curated_preview.png"
		root.get_texture().get_image().save_png(preview_path)
		print("ARCHIVE_BOOK_PREVIEW=" + ProjectSettings.globalize_path(preview_path))
	_check(library._line_next.visible and not library._line_next.disabled,
		"Final alternativo tem navegação acessível.")
	library._change_line(1)
	_check(library._selected_line_index == 1 \
		and library._book_rows.get_child_count() == 1,
		"Navegação troca de história sem misturar linhas.")
	library._close_overlay()
	_check(not library._veil.visible, "Fechar retorna às pastas.")
	var legacy := _fixture_line()
	legacy["journal_schema_version"] = 1
	library._select_folder({"lines": [legacy]})
	library._open_book()
	var rich := library._book_rows.get_child(0).find_children("*", "RichTextLabel", true, false)[0] as RichTextLabel
	_check(rich.get_parsed_text().contains("Trecho corrompido//arquivo perdido. ERRO de registro"),
		"Trecho sem cobertura do esquema antigo usa mensagem literal de erro.")
	library.queue_free()
	await process_frame
	print("PPP_ARCHIVE_LIBRARY_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _fixture_line() -> Dictionary:
	var entries: Array[Dictionary] = []
	entries.append(_entry(1, 1, 0, "suburbio", "event_outcome",
		[{"text": "A Florzinha", "tone": "event"}]))
	entries.append(_entry(2, 1, 0, "suburbio", "encounter_started",
		[{"text": "Zumbis Dançarinos", "tone": "negative"}]))
	entries.append(_entry(3, 1, 0, "suburbio", "attack",
		[{"text": "Jornalista", "tone": "actor"}], {"damage": 18}))
	entries.append(_entry(4, 1, 0, "suburbio", "attack",
		[{"text": "Zumbi", "tone": "hostile"}], {"damage": 9}))
	entries.append(_entry(5, 1, 0, "suburbio", "combat_finished", []))
	entries.append(_entry(6, 1, 0, "suburbio", "item_collected",
		[{"text": "Café", "tone": "item"}]))
	entries.append(_entry(7, 2, 1, "baixo_centro", "event_outcome",
		[{"text": "Gênio da Lâmpada", "tone": "event"}]))
	entries.append(_entry(8, 2, 1, "baixo_centro", "craft_item",
		[{"text": "Espada Flamejante", "tone": "item"}]))
	entries.append(_entry(9, 2, 1, "baixo_centro", "playable_death",
		[{"text": "Pedreiro", "tone": "actor"}]))
	entries.append(_entry(10, 2, 1, "baixo_centro", "recruitment",
		[{"text": "Jornalista", "tone": "actor"},
		{"text": "Professora", "tone": "actor"}]))
	return {"mode": EventCampaignEligibility.Mode.SHORT,
		"ending_ids": ["khainokata"], "status": CampaignState.CampaignStatus.VICTORY,
		"journal_schema_version": 2, "created_at": "2026-10-21T14:20:00",
		"entries": entries}


func _entry(serial: int, day: int, period: int, district: String,
		action: String, segments: Array, references: Dictionary = {}) -> Dictionary:
	return {"serial": serial, "day": day, "period": period,
		"district": district, "round_index": day, "action_id": action,
		"segments": segments, "references": references, "text": action}


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
