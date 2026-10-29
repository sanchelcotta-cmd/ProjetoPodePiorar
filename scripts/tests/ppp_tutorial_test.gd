extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pages := TutorialContent.load_pages()
	_check(ResourceLoader.exists("res://resources/tutorial_pages.json"),
		"Catálogo é reconhecido como recurso exportável.")
	_check(pages.size() == 93, "Catálogo preserva 92 páginas revisadas e acrescenta o resumo de atalhos.")
	var ids := {}
	var silent_count := 0
	for page in pages:
		ids[str(page["id"])] = true
		if str(page.get("face_line", "")).is_empty():
			silent_count += 1
	_check(ids.size() == pages.size(), "IDs de página são únicos.")
	_check(silent_count > 0, "Páginas sem fala permanecem silenciosas.")
	var tutorial := TutorialWindow.new()
	root.add_child(tutorial)
	await process_frame
	tutorial.open(true)
	_check(tutorial._screen.visible, "Tutorial abre.")
	_check(tutorial._dismiss.visible, "A opção de dispensar aparece no Dia 1.")
	_check(tutorial._counter.text == "1 / 3",
		"Primeiros Passos conta somente suas três páginas.")
	tutorial._select_category("ALIADOS EM COMBATE")
	_check(tutorial._counter.text == "1 / 5",
		"Outra guia reinicia em página 1 de 5.")
	tutorial._go_relative(1)
	_check(tutorial._counter.text == "2 / 5",
		"Próxima página permanece na mesma guia.")
	tutorial._select_category("ATALHOS DE TECLADO")
	_check(tutorial._counter.text == "1 / 1",
		"Guia de atalhos tem uma única página.")
	_check(not tutorial._face._speech.visible,
		"Na guia de atalhos, o rosto sorri sem fala.")
	var silent_index := -1
	for index in pages.size():
		if str(pages[index].get("face_line", "")).is_empty():
			silent_index = index
			break
	tutorial._show_page(silent_index)
	_check(not tutorial._face._speech.visible, "Rosto aparece sem caixa de fala vazia.")
	tutorial.close()
	_check(not tutorial._screen.visible, "Tutorial fecha.")
	tutorial.queue_free()
	await process_frame
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(game)
	await process_frame
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	_check(gerencia.start_new_game(selected), "Campanha nova inicia.")
	var bar := game.get_node("CampaignTopBar") as CampaignTopBar
	bar.bind_campaign(gerencia.campaign)
	_check(bar._tutorial_shortcut.visible, "Atalho aparece no Dia 1.")
	_check(bar.journal_ui._tutorial_shortcut_visible
		and bar.journal_ui.summary_frame.position.y
			+ bar.journal_ui.summary_frame.size.y
			< bar._tutorial_shortcut.offset_top,
		"Registro e tutorial ocupam faixas laterais separadas.")
	_check(bar.journal_ui.expand_tab.text == "< R",
		"Registro recolhido apresenta o atalho < R.")
	bar._tutorial_shortcut.set_presentation(0.62, true)
	_check(bar._tutorial_shortcut._open_button.text == "< T",
		"Atalho recolhido mostra < T.")
	bar._tutorial_shortcut._on_open_pressed()
	_check(not bar._tutorial_shortcut.collapsed
		and (bar._tutorial_window == null or not bar._tutorial_window._screen.visible),
		"Primeiro clique no atalho recolhido apenas expande.")
	bar._tutorial_shortcut._on_open_pressed()
	_check(bar._tutorial_window != null and bar._tutorial_window._screen.visible,
		"Segundo clique abre o tutorial.")
	bar._tutorial_window.close()
	bar._tutorial_shortcut.set_presentation(0.62, true)
	var shortcut_press := InputEventMouseButton.new()
	shortcut_press.button_index = MOUSE_BUTTON_LEFT
	shortcut_press.pressed = true
	shortcut_press.global_position = Vector2(1550, 400)
	bar._tutorial_shortcut._on_button_input(shortcut_press)
	var shortcut_drag := InputEventMouseMotion.new()
	shortcut_drag.global_position = Vector2(1550, 455)
	bar._tutorial_shortcut._on_button_input(shortcut_drag)
	var shortcut_release := InputEventMouseButton.new()
	shortcut_release.button_index = MOUSE_BUTTON_LEFT
	shortcut_release.pressed = false
	shortcut_release.global_position = Vector2(1550, 455)
	bar._tutorial_shortcut._on_button_input(shortcut_release)
	_check(bar._tutorial_shortcut.y_ratio > 0.62,
		"Arrastar para baixo move o atalho verticalmente.")
	bar._tutorial_shortcut.set_presentation(0.62, true)
	bar._on_tutorial_shortcut_changed(0.62, true)
	_check(is_equal_approx(gerencia.campaign.tutorial_shortcut_y_ratio, 0.62)
		and gerencia.campaign.tutorial_shortcut_collapsed,
		"Altura e recolhimento pertencem à campanha.")
	bar.maybe_show_initial_tutorial()
	await process_frame
	await process_frame
	_check(gerencia.campaign.tutorial_invitation_seen and paused
		and bar._tutorial_invitation is TutorialInvitation
		and bar._tutorial_invitation.is_open(),
		"Convite personalizado aparece uma vez e pausa o mapa.")
	_check(not bar._tutorial_invitation._face._speech.visible,
		"Rosto do convite sorri sem uma fala solta.")
	var escape_key := InputEventKey.new()
	escape_key.keycode = KEY_ESCAPE
	escape_key.pressed = true
	bar._tutorial_invitation._input(escape_key)
	_check(bar._tutorial_invitation.is_open(),
		"Esc não dispensa o convite sem escolha explícita.")
	var invitation_enter := InputEventKey.new()
	invitation_enter.keycode = KEY_ENTER
	invitation_enter.pressed = true
	bar._tutorial_invitation._input(invitation_enter)
	_check(bar._tutorial_invitation.is_open()
		and bar._tutorial_invitation._keyboard_navigation.selected_button()
			== bar._tutorial_invitation._later_button,
		"Primeiro Enter apenas destaca o botão mais à esquerda.")
	bar._tutorial_invitation._input(invitation_enter)
	_check(not paused, "Recusar convite devolve o controle ao jogo.")
	bar._begin_tutorial_session()
	bar._tutorial_invitation.open_invitation()
	bar._tutorial_invitation._choose_open()
	_check(bar._tutorial_window != null and bar._tutorial_window._screen.visible
		and paused and not bar._tutorial_invitation.is_open(),
		"Ver Tutorial troca o convite pela janela sem liberar o mapa.")
	bar._tutorial_window.close()
	_check(not paused, "Fechar o tutorial depois do convite devolve o controle.")
	var t_key := InputEventKey.new()
	t_key.keycode = KEY_T
	t_key.pressed = true
	bar._input(t_key)
	_check(bar._tutorial_window != null and bar._tutorial_window._screen.visible,
		"T abre o tutorial no mapa durante o Dia 1.")
	bar._tutorial_window.close()
	bar.open_tutorial()
	_check(paused and bar._tutorial_window._screen.visible,
		"Atalho abre tutorial e pausa o mapa.")
	bar._tutorial_window.close()
	_check(not paused, "Fechar tutorial devolve o controle.")
	paused = true
	bar.open_tutorial_from_settings()
	bar._tutorial_window.close()
	_check(paused, "Abrir pelas Configurações preserva a pausa anterior.")
	paused = false
	bar.open_tutorial()
	bar._on_tutorial_day_one_dismiss_requested()
	_check(gerencia.campaign.tutorial_day_one_shortcut_dismissed
		and not bar._tutorial_shortcut.visible,
		"Dispensar remove somente o atalho do Dia 1.")
	_check(not bar.journal_ui._tutorial_shortcut_visible,
		"Sem o T, o Registro pode usar toda a lateral direita.")
	bar.open_tutorial_from_settings()
	_check(bar._tutorial_window._screen.visible
		and not bar._tutorial_window._dismiss.visible,
		"Configurações continuam dando acesso sem opção de dispensar.")
	bar._tutorial_window.close()
	var codec := CampaignSaveCodec.new()
	var saved := codec.encode(gerencia.campaign)
	var restored := CampaignSaveCodec.new().decode(saved) as CampaignState
	_check(restored != null and restored.tutorial_invitation_seen
		and restored.tutorial_day_one_shortcut_dismissed
		and restored.tutorial_shortcut_collapsed
	and is_equal_approx(restored.tutorial_shortcut_y_ratio, 0.62),
		"Convite, dispensa e posição do atalho persistem no save.")
	game.queue_free()
	await process_frame
	print("PPP_TUTORIAL_TEST failures=%d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)
