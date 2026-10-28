extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var palette := root.get_node("UIColorManager")
	var original_id: String = str(palette.get("palette_id"))
	var scale_service := root.get_node("UniversalFontScale")
	var original_scale := float(scale_service.get("ui_factor"))
	_check(bool(palette.call("set_palette", "padrao", false)), "Paleta Padrão disponível.")
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as PPPMainMenu
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var new_game := menu.menu_area.get_node("NewGame") as Button
	var quit_button := menu.menu_area.get_node("Quit") as Button
	_check(_same_border(new_game, "#4DE385"), "Avanço usa verde unificado no Padrão.")
	_check(_same_border(quit_button, "#FF646E"), "Sair usa vermelho unificado no Padrão.")
	_check(bool(palette.call("set_palette", "azul", false)), "Paleta Azul disponível.")
	_check(_same_border(new_game, "#39E7A1") and _same_border(quit_button, "#B17AF0"),
		"Azul combina progresso verde e perigo roxo.")
	_check(_same_background(new_game, "#183B66") and
		_same_background(quit_button, "#183B66"),
		"Botões da paleta Azul usam azuis consistentes.")
	_check(is_equal_approx(float(scale_service.get("ui_factor")), original_scale),
		"Trocar tema não altera a escala da UI.")
	var settings := menu.get("_settings_menu") as Control
	var palette_buttons: Array = settings.get("_palette_controls")
	_check(palette_buttons[1].button_pressed, "Configurações acompanha o tema ativo.")
	_check(bool(palette.call("set_palette", "rosa_branco", false)),
		"Paleta Rosa/Branco disponível.")
	_check(_same_border(new_game, "#8D1C5B") and
		_same_background(new_game, "#9D1D61") and
		new_game.get_theme_color("font_color") == Color.WHITE,
		"Rosa/Branco usa botão rosa com texto branco legível.")
	var load_panel := menu.get("_load_panel") as Control
	var save_box := load_panel.get("_panel") as PanelContainer
	var save_style := save_box.get_theme_stylebox("panel") as StyleBoxFlat
	_check(save_style != null and save_style.bg_color.to_html(false) == "ffffff",
		"Tela de saves aberta usa a superfície do tema sem alterar o repositório.")
	_check(palette.call("color", "primary") == Color("#3A1730") and
		palette.call("color", "secondary") == Color("#68445E"),
		"Texto sobre superfícies brancas usa rosa-vinho escuro, não preto puro.")
	var settings_panel := settings.get("_panel") as PanelContainer
	var settings_style := settings_panel.get_theme_stylebox("panel") as StyleBoxFlat
	_check(settings_style != null and settings_style.bg_color.to_html(false) == "ffffff",
		"Configurações usa branco nas caixas, não nos botões.")
	var selected_tab := palette_buttons[2] as Button
	_check(_same_background(selected_tab, "#86134F") and
		selected_tab.get_theme_color("font_color") == Color.WHITE,
		"Opção Rosa/Branco é botão rosa com texto branco.")
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() \
		as PlayableSelectionScreen
	root.add_child(selection)
	await process_frame
	await process_frame
	var campaign_panel := selection.get_node(
		"Content/Stack/BodyScroll/Body/CampaignPanel") as PanelContainer
	var campaign_style := campaign_panel.get_theme_stylebox("panel") as StyleBoxFlat
	var short_mode := selection.get("_mode_short") as Button
	_check(campaign_style != null and campaign_style.bg_color.to_html(false) == "ffffff" and
		_same_background(short_mode, "#9D1D61"),
		"Na seleção, branco fica na caixa e rosa no botão da campanha.")
	var details_button := selection.cards[0].details_button as Button
	_check(_same_background(details_button, "#9D1D61"),
		"Botão Detalhes fica rosa; o card mantém superfície de leitura.")
	_check(bool(scale_service.call("set_ui_scale", 1.25, false)),
		"Escala pode mudar com a paleta aplicada.")
	await process_frame
	await process_frame
	save_style = save_box.get_theme_stylebox("panel") as StyleBoxFlat
	_check(save_style != null and save_style.bg_color.to_html(false) == "ffffff" and
		_same_border(new_game, "#8D1C5B") and
		(campaign_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.to_html(false) == "ffffff" and
		_same_background(short_mode, "#9D1D61"),
		"A escala não reverte as caixas brancas nem os botões rosa.")
	scale_service.call("set_ui_scale", original_scale, false)
	_check(bool(palette.call("set_palette", "acessivel", false)),
		"Paleta Acessível disponível.")
	var hex := HexPalette.new()
	hex.apply_ui_palette("acessivel")
	_check(hex.reachable_color == Color("#51D6B1") and
		hex.revealed_color == Color("#67C6EF") and
		hex.selected_color == Color("#F3A0CB"),
		"Hexes acessíveis distinguem alcance, revelação e seleção.")
	_check(palette.call("set_palette", "id_invalido", false) == false,
		"ID inválido não altera a paleta.")
	palette.call("set_palette", original_id, false)
	selection.queue_free()
	menu.queue_free()
	await process_frame
	print("PPP_UI_PALETTE_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _same_border(button: Button, expected: String) -> bool:
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	if style == null:
		return false
	var actual := style.border_color
	var target := Color(expected)
	return is_equal_approx(actual.r, target.r) and \
		is_equal_approx(actual.g, target.g) and is_equal_approx(actual.b, target.b)


func _same_background(button: Button, expected: String) -> bool:
	var style := button.get_theme_stylebox("normal") as StyleBoxFlat
	return style != null and style.bg_color.to_html(false) == Color(expected).to_html(false)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
