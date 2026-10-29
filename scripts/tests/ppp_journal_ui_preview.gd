extends SceneTree

## Capturas de aceite visual do livro e do resumo de Registros.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 340917
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(rng),
		"A campanha de prévia deve iniciar.")
	var campaign := gerencia.campaign
	campaign.append_journal_entry(&"event_outcome", [
		{"text": "Pedreiro", "tone": "actor"},
		{"text": " ativou um Evento no Subúrbio.", "tone": "text"},
	])
	campaign.day = 2
	campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
	campaign.district = &"baixo_centro"
	campaign.append_journal_entry(&"skill", [
		{"text": "Pedreiro", "tone": "actor"},
		{"text": " usou ", "tone": "text"},
		{"text": "Muro de Tijolo", "tone": "skill"},
		{"text": " e protegeu a Velha Fofoqueira.", "tone": "positive"},
	])
	campaign.append_journal_entry(&"attack", [
		{"text": "Velha Fofoqueira", "tone": "actor"},
		{"text": " atacou ", "tone": "text"},
		{"text": "Zumbi Dançarino", "tone": "hostile"},
		{"text": " e causou 7 de dano.", "tone": "positive"},
	])
	campaign.append_journal_entry(&"consume_item", [
		{"text": "Jornalista", "tone": "actor"},
		{"text": " consumiu ", "tone": "text"},
		{"text": "Café", "tone": "item"},
		{"text": " e recuperou 4 de Vida.", "tone": "positive"},
	])
	campaign.append_journal_entry(&"information", [
		{"text": "Pedreiro", "tone": "actor"},
		{"text": " localizou uma ", "tone": "text"},
		{"text": "Informação", "tone": "information"},
		{"text": " no mapa.", "tone": "text"},
	])
	var ui := bar.journal_ui
	_check(ui != null and ui.summary_frame.visible,
		"Resumo deve estar expandido ao iniciar.")
	var selector := ui.summary_frame.find_child("VisibleLines", true, false) as OptionButton
	selector.select(1)
	selector.item_selected.emit(1)
	await process_frame
	await process_frame
	_save("res://docs/journal_preview/resumo.png")
	ui.open_book()
	await process_frame
	await process_frame
	_check(ui.book_previous.visible and not ui.book_previous.disabled
		and ui.book_next.disabled, "A página mais recente permite voltar, mas não avançar.")
	_check(ui.book_context.text == "DIA 2 · MANHÃ · BAIXO-CENTRO",
		"Rodapé deve mostrar o contexto das ações exibidas.")
	_save("res://docs/journal_preview/livro.png")
	ui._change_book_page(-1)
	_check(ui.book_previous.disabled and not ui.book_next.disabled,
		"A página mais antiga permite avançar, mas não voltar.")
	ui._change_book_page(1)
	ui.close_book()
	ui._set_summary_expanded(false)
	await process_frame
	_save("res://docs/journal_preview/recolhido.png")
	_check(ui.expand_tab.visible and not ui.summary_frame.visible,
		"Resumo recolhido deve deixar a pequena seta azul.")
	for index in range(24):
		campaign.append_journal_entry(&"event_outcome", [
			{"text": "Pedreiro", "tone": "actor"},
			{"text": " concluiu uma ação e examinou o resultado do Evento %d." % index,
				"tone": "text"},
		])
	ui.open_book()
	await process_frame
	await process_frame
	var vertical_bar := ui.book_scroll.get_v_scroll_bar()
	_check(vertical_bar.max_value > vertical_bar.page,
		"O livro deve permitir rolagem vertical quando houver muitos registros.")
	ui.book_scroll.set_v_scroll(120)
	await process_frame
	_save("res://docs/journal_preview/livro_com_scroll.png")
	ui.close_book()
	print("PPP_JOURNAL_UI_OK" if failures == 0 else
		"PPP_JOURNAL_UI_FAILED:%d" % failures)
	quit(0 if failures == 0 else 1)


func _save(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var image := root.get_texture().get_image()
	_check(image != null and image.save_png(path) == OK,
		"Captura deve ser gravada: " + path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
