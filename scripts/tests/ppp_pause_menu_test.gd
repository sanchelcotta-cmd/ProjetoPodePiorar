extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(game)
	current_scene = game
	await process_frame
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	var repository := CampaignSaveRepository.new("user://ppp_pause_menu_tests")
	gerencia.save_repository = repository
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 19253
	_check(gerencia.start_new_game(selected) and
		(game.get_node("RoundManager") as RoundManager).start_first_map(rng),
		"Campanha de teste inicia.")
	var bar := game.get_node("CampaignTopBar") as CampaignTopBar
	var pause = bar.pause_menu
	_check(bar.pause_button is Button and not bar.pause_button is MenuButton,
		"☰ é um botão direto, não um menu suspenso.")
	_check(not (game.get_node("RoundManager") as RoundManager).can_advance(),
		"Pausar permanece disponível sem poder avançar a fase.")
	var moving := Node2D.new()
	game.add_child(moving)
	var debug_layer := game.get_node_or_null("CampaignDebugPanel") as CanvasLayer
	if debug_layer == null:
		debug_layer = CanvasLayer.new()
		debug_layer.name = "CampaignDebugPanel"
		game.add_child(debug_layer)
	debug_layer.show()
	var motion := moving.create_tween()
	motion.tween_property(moving, "position:x", 100.0, 0.25)
	await create_timer(0.03, true).timeout
	bar.sound_button.pressed.emit()
	_check((bar.get("_audio_quick_panel") as Control).visible,
		"♪ abre controles compactos antes da pausa.")
	bar.pause_button.pressed.emit()
	_check(paused and pause.is_open(), "☰ abre imediatamente a pausa.")
	_check(not (bar.get("_audio_quick_panel") as Control).visible,
		"A minicaixa de áudio fecha antes da tela preta de pausa.")
	_check(not debug_layer.visible, "A pausa oculta a camada de depuração do fundo preto.")
	var position_before := moving.position.x
	var game_timer := Timer.new()
	game_timer.one_shot = true
	game_timer.wait_time = 0.15
	game.add_child(game_timer)
	game_timer.start()
	var time_before := game_timer.time_left
	await create_timer(0.08, true).timeout
	_check(not game_timer.is_stopped() and is_equal_approx(game_timer.time_left,
		time_before), "Relógios do jogo não avançam enquanto a pausa está aberta.")
	_check(is_equal_approx(moving.position.x, position_before),
		"Animações vinculadas ao mapa também ficam congeladas na pausa.")
	motion.kill()
	moving.queue_free()
	game_timer.queue_free()
	_check((pause._screen.get_node("BlackBackground") as ColorRect).color == Color.BLACK,
		"Fundo da pausa é totalmente preto.")
	_check(pause._screen.get_node_or_null("BackgroundAnimationSlot") != null,
		"Fundo reserva espaço para animação futura.")
	for name in ["Resume", "Save", "Load", "Settings", "Records", "MainMenu", "Abandon"]:
		_check(pause._menu.get_node_or_null(name) is Button,
			"Botão da pausa %s existe." % name)
	pause._screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	pause._screen.size = Vector2(800, 600)
	await process_frame
	var previous_bottom := 0.0
	for button in pause._menu.get_children():
		if not button is Button:
			continue
		var rect := (button as Button).get_global_rect()
		_check(rect.position.x >= 0 and rect.end.x <= 800
			and rect.position.y >= previous_bottom and rect.end.y <= 600,
			"Botão %s cabe sem sobrepor outros em 800x600." % button.name)
		previous_bottom = rect.end.y
	pause._screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	pause.open_save()
	await pause._save_panel.refreshed
	_check(pause._save_panel.visible and pause._save_panel.save_mode,
		"Salvar abre o catálogo visual de três slots.")
	_check(bar.exit_progress_warning().contains("ainda não tem save manual"),
		"Saída antes do primeiro save avisa sobre perda de progresso.")
	pause._on_save_requested(1, false)
	var saved := false
	for entry in repository.list_campaigns():
		if entry["campaign_id"] == gerencia.campaign.campaign_id:
			saved = entry["slots"].size() == 1
	_check(saved, "Save da pausa grava no slot escolhido.")
	var save_status := pause._save_panel.get("_status") as Label
	var palette := root.get_node("UIColorManager")
	_check(save_status.text == "Salvo no slot 1."
		and save_status.get_theme_color("font_color") == palette.call("color", "progress"),
		"Salvo só aparece após gravação confirmada, na cor de progresso do tema.")
	pause._commit_save(false)
	_check(not save_status.text.begins_with("Salvo")
		and save_status.get_theme_color("font_color") == palette.call("color", "danger"),
		"Falha real de sobrescrita aparece na cor de perigo do tema.")
	var comparison := repository.compare_latest_manual_save(gerencia.campaign, game)
	_check(comparison.get("has_manual_save", false)
		and not comparison.get("has_changes", true),
		"Após gravação confirmada, o estado coincide com o slot manual.")
	gerencia.campaign.append_journal_entry(&"test_change",
		[{"text": "Mudança de teste", "tone": "text"}], &"")
	comparison = repository.compare_latest_manual_save(gerencia.campaign, game)
	_check(comparison.get("has_changes", false)
		and pause._exit.dialog_text != "", "Alteração posterior é detectada.")
	pause._open_exit_confirmation()
	_check(pause._exit.dialog_text.contains("alterações desde o último save manual"),
		"Sair avisa sobre progresso ainda não salvo.")
	var exit_panel := pause._exit.get_theme_stylebox("panel") as StyleBoxFlat
	var dialog_backdrop := pause._screen.get_node("ConfirmationBackdrop") as ColorRect
	_check(exit_panel != null and exit_panel.bg_color == Color("#05090C")
		and pause._exit.get_label().autowrap_mode == TextServer.AUTOWRAP_WORD_SMART,
		"Confirmação usa fundo escuro compacto e texto com quebra de linha.")
	_check(dialog_backdrop.visible and dialog_backdrop.material is ShaderMaterial,
		"Desfoque discreto fica ativo somente atrás da confirmação.")
	var previous_palette := str(palette.get("palette_id"))
	palette.call("set_palette", "azul", false)
	var blue_panel := pause._exit.get_theme_stylebox("panel") as StyleBoxFlat
	_check(blue_panel.border_color == palette.call("color", "structure")
		and blue_panel.bg_color == Color("#05090C"),
		"A margem segue a paleta e a superfície do aviso mantém contraste escuro.")
	palette.call("set_palette", previous_palette, false)
	pause._exit.hide()
	_check(not dialog_backdrop.visible,
		"Desfoque some assim que a confirmação é fechada.")
	_check(repository.save_autosave(gerencia.campaign, game, &"test", 2.0)
		.get("success", false), "Backup de teste existe antes do abandono.")
	pause._save_panel.close()
	pause._load_panel.open()
	_check(pause._load_panel.visible and not pause._load_panel.save_mode,
		"Carregar reutiliza o catálogo do menu principal.")
	pause._on_load_requested(gerencia.campaign.campaign_id, 1, false)
	_check(pause._load_confirmation.visible
		and pause._load_confirmation.dialog_text.contains("alterações desde o último save manual")
		and not pause._pending_load.is_empty(),
		"Carregar sobre progresso não salvo exige confirmação antes de trocar a cena.")
	pause._load_confirmation.canceled.emit()
	pause._load_confirmation.hide()
	_check(pause._pending_load.is_empty() and gerencia.campaign.journal_entries.size() > 0,
		"Cancelar a carga mantém a campanha atual intacta.")
	pause._open_archive_library()
	_check(pause._archive_library.visible \
		and (pause._archive_library.get_node("BlackBackground") as ColorRect).color == Color.BLACK,
		"Consulta abre a biblioteca de campanhas arquivadas.")
	pause._back_from_archive()
	_check(pause._load_panel.visible, "Voltar da consulta retorna aos saves.")
	pause._load_panel.close()
	pause._open_journal()
	_check(pause._journal.is_book_open() and pause._journal.visible,
		"Registros na pausa abre o livro detalhado real.")
	pause.close()
	_check(not paused and not pause.is_open(), "Continuar devolve o controle ao jogo.")
	_check(debug_layer.visible, "Ao continuar, a camada de depuração é restaurada.")
	gerencia.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	bar.refresh()
	bar.pause_button.pressed.emit()
	_check(paused and pause.is_open(), "☰ também pausa diretamente em combate.")
	pause.close()
	gerencia.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.EXPLORATION
	bar.refresh()
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	bar._unhandled_key_input(escape_event)
	_check(not paused and not pause.is_open(),
		"Esc não abre a pausa durante a partida.")
	var pause_event := InputEventKey.new()
	pause_event.keycode = KEY_P
	pause_event.pressed = true
	bar._unhandled_key_input(pause_event)
	_check(paused and pause.is_open(), "P abre a pausa durante a partida.")
	pause._input(pause_event)
	_check(not paused and not pause.is_open(), "P na pausa devolve o controle ao jogo.")
	var id := gerencia.campaign.campaign_id
	var blocker := ConfirmationDialog.new()
	root.add_child(blocker)
	blocker.popup_centered(Vector2i(360, 140))
	_check(gerencia.campaign.mark_terminal(CampaignState.CampaignStatus.VICTORY)
		and repository.record_terminal_line(gerencia.campaign).get("success", false),
		"Livro terminal de teste existe antes do abandono.")
	await process_frame
	_check(bar._terminal_notice_pending and not bar._terminal_dialog.visible,
		"Aviso terminal aguarda a caixa exclusiva que já estava aberta.")
	blocker.hide()
	blocker.queue_free()
	await process_frame
	_check(bar._terminal_dialog.visible
		and bar._terminal_dialog.dialog_text.contains("estado é terminal"),
		"Conclusão mostra o estado terminal sem afirmar que um slot foi salvo.")
	bar._terminal_dialog.hide()
	_check(not repository.abandon_campaign(id).get("success", false),
		"Abandono sem confirmação não exclui dados.")
	var removed := repository.abandon_campaign(id, true)
	var remains := false
	for entry in repository.list_campaigns():
		remains = remains or entry["campaign_id"] == id
	_check(removed.get("success", false) and not remains
		and repository.list_terminal_lines(id).is_empty()
		and not repository.load_autosave(id, game).get("success", false),
		"Abandonar confirmado remove slots, backup e livro.")
	print("PPP_PAUSE_MENU_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
