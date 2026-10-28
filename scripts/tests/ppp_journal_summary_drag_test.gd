extends SceneTree

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1656, 932)
	var journal := CampaignJournalUI.new()
	root.add_child(journal)
	await process_frame
	var campaign := CampaignState.new()
	campaign.campaign_status = CampaignState.CampaignStatus.ACTIVE
	for index in 2:
		campaign.append_journal_entry(&"event_outcome", [{"text":
			"Pedreiro ativou um Evento e encontrou uma consequência interessante no mapa, registrada de forma legível sem expandir o painel até o chão.",
			"tone": "text"}])
	journal.bind_campaign(campaign)
	await process_frame
	await process_frame
	check(journal.summary_frame.size.y < 300.0,
		"Resumo nasce próximo da altura das duas entradas, sem ir até o chão.")
	var start_y := journal.summary_frame.position.y
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	journal._on_summary_header_input(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(0, 90)
	journal._input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	journal._input(release)
	check(is_equal_approx(journal.summary_frame.position.y, start_y + 90.0),
		"Arrastar o cabeçalho move o resumo para baixo.")
	journal._layout()
	check(is_equal_approx(journal.summary_frame.position.y, start_y + 90.0),
		"O layout mantém a altura escolhida.")
	journal._set_summary_expanded(false)
	check(is_equal_approx(journal.expand_tab.position.y,
		journal.summary_frame.position.y),
		"A seta minimizada acompanha a posição vertical escolhida.")
	var minimized_start := journal.expand_tab.position.y
	journal._on_expand_tab_input(press)
	var tab_motion := InputEventMouseMotion.new()
	tab_motion.relative = Vector2(0, 65)
	journal._input(tab_motion)
	journal._input(release)
	journal._on_expand_tab_pressed()
	check(is_equal_approx(journal.expand_tab.position.y, minimized_start + 65.0),
		"Segurar e arrastar a seta minimizada move o resumo na vertical.")
	check(not journal.summary_expanded,
		"Arrastar a seta não abre o resumo por engano.")
	journal._on_expand_tab_input(press)
	journal._input(release)
	journal._on_expand_tab_pressed()
	check(journal.summary_expanded,
		"Clique simples na seta ainda abre o resumo.")
	journal._set_summary_expanded(true)
	journal._summary_user_y = 1.0
	journal._layout()
	check(journal.summary_frame.position.y >= 60.0,
		"O resumo não sai pelo topo da tela.")
	journal._summary_user_y = 9999.0
	journal._layout()
	check(journal.summary_frame.position.y + journal.summary_frame.size.y \
		<= root.size.y - 7.0,
		"O resumo não sai pela borda inferior.")
	print("PPP_JOURNAL_SUMMARY_DRAG: %s" % \
		("PASS" if failures == 0 else "%d falhas" % failures))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
