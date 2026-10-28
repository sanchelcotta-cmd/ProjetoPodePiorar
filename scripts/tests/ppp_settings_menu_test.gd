extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	root.add_child(menu)
	await process_frame
	var settings := menu.get("_settings_menu") as Control
	_check(settings != null and not settings.visible,
		"Configurações existe e começa fechado.")
	settings.call("open")
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(
			"C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/settings_menu_preview.png")
	_check(settings.visible and settings.get("_pages").size() == 4,
		"As quatro abas de referência aparecem no painel.")
	var comfort_info := settings.get("_reduce_info_button") as Button
	var comfort_panel := settings.get("_reduce_info_panel") as PanelContainer
	_check(comfort_info != null and comfort_panel != null and not comfort_panel.visible,
		"A redução visual tem um botão informativo discreto, inicialmente fechado.")
	comfort_info.pressed.emit()
	var comfort_text := comfort_panel.get_node("VisualComfortInfoText") as Label
	_check(comfort_panel.visible and comfort_text.text.contains("35% das gotas")
		and comfort_text.text.contains("W3C/WCAG")
		and comfort_text.text.contains("regras e os resultados do jogo não mudam"),
		"A explicação informa efeito perceptível, medida e referência sem prometer segurança absoluta.")
	comfort_info.pressed.emit()
	_check(not comfort_panel.visible,
		"O mesmo botão informativo recolhe a explicação.")
	settings.call("_show_tab", "Modo streamer")
	var streamer_note := settings.find_child("StreamerComingSoon", true, false) as Label
	_check(streamer_note != null and streamer_note.text == "EM BREVE",
		"Modo streamer exibe apenas a mensagem provisória pedida.")
	settings.call("_show_tab", "Gráficos e interface")
	var resolution := settings.get("_resolution_control") as OptionButton
	_check(resolution.item_count == 4,
		"Quatro resoluções de desktop aparecem no seletor.")
	var modes: Array = settings.get("_mode_controls")
	_check(modes.size() == 3,
		"Janela, tela cheia e janela sem bordas estão disponíveis.")
	var scale_controls: Array = settings.get("_scale_controls")
	_check(scale_controls.size() == 4 and scale_controls[3].disabled,
		"Escala 150% fica bloqueada abaixo de 1920 × 1080.")
	var ui_scale := root.get_node("UniversalFontScale")
	var world := Node2D.new()
	world.scale = Vector2(2, 3)
	root.add_child(world)
	var button := menu.get_node("MenuArea/NewGame") as Button
	var base_min := button.custom_minimum_size
	_check(ui_scale.call("set_ui_scale", 0.8, false),
		"Escala compacta é aplicável sem gravar preferência no teste.")
	await process_frame
	_check(button.custom_minimum_size.y < base_min.y and world.scale == Vector2(2, 3),
		"Área clicável da UI muda e o nó do mundo não é escalado.")
	_check(ui_scale.call("set_ui_scale", 1.25, false),
		"Escala ampliada é aplicável.")
	await process_frame
	_check(button.custom_minimum_size.y > base_min.y and world.scale == Vector2(2, 3),
		"A UI cresce; o mundo permanece intacto.")
	settings.call("open")
	await process_frame
	await process_frame
	var settings_rect := (settings.get("_panel") as PanelContainer).get_global_rect()
	_check(settings_rect.position.x >= 0.0 and settings_rect.end.x <= menu.size.x,
		"Configurações ampliadas cabem horizontalmente.")
	settings.call("close")
	var load_panel := menu.get("_load_panel") as Control
	load_panel.call("open")
	await process_frame
	await process_frame
	var load_rect := (load_panel.get("_panel") as PanelContainer).get_global_rect()
	_check(load_rect.position.x >= 0.0 and load_rect.end.x <= menu.size.x,
		"Carregamento ampliado cabe horizontalmente.")
	load_panel.call("close")
	ui_scale.call("set_ui_scale", 1.0, false)
	settings.call("close")
	_check(not settings.visible, "Voltar fecha apenas as Configurações.")
	menu.queue_free()
	await process_frame
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() as Control
	root.add_child(selection)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(
			"C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_with_difficulty_preview.png")
	var easy := selection.get("_difficulty_easy") as Button
	var standard := selection.get("_difficulty_standard") as Button
	var chaotic := selection.get("_difficulty_chaotic") as Button
	_check(not easy.disabled and not chaotic.disabled and not standard.disabled
		and standard.text.contains("●"),
		"As três dificuldades estão disponíveis; Padrão vem marcado.")
	chaotic.pressed.emit()
	_check(chaotic.text.contains("●") and standard.text.contains("○")
		and selection.get("_selected_difficulty") == GameDifficulty.Mode.CHAOTIC,
		"Seleção permite marcar Caótico sem mudar o Padrão global.")
	easy.pressed.emit()
	_check(easy.text.contains("●") and standard.text.contains("○")
		and selection.get("_selected_difficulty") == GameDifficulty.Mode.SUGAR,
		"Seleção permite Água com Açúcar sem mudar o Padrão global.")
	_check(selection.get("cards").size() == 7,
		"Os sete cards continuam na seleção.")
	ui_scale.call("set_ui_scale", 1.25, false)
	await process_frame
	await process_frame
	await process_frame
	var visible_cards := 0
	for card in selection.get("cards"):
		if not card.visible:
			continue
		visible_cards += 1
		_check(card.get_global_rect().position.x >= 0.0
			and card.get_global_rect().end.x <= selection.size.x,
			"Card ampliado permanece dentro da largura visível.")
	_check(visible_cards >= 1 and (selection.get("_previous") as Button).disabled,
		"A navegação ampliada mantém ao menos uma página inicial acessível.")
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png(
			"C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_scale_125_preview.png")
	ui_scale.call("set_ui_scale", 1.0, false)
	print("PPP_SETTINGS_MENU_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
