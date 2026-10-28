extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var palette := root.get_node("UIColorManager")
	var scale_service := root.get_node("UniversalFontScale")
	var old_palette := str(palette.get("palette_id"))
	var old_scale := float(scale_service.get("ui_factor"))
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	palette.call("set_palette", "rosa_branco", false)
	await process_frame
	await process_frame
	_check(_background(bar.bar_panel, "panel") == "ffffff"
		and _background(hud.action_drawer, "panel") == "ffffff"
		and _background(hud.cards[0], "panel") == "ffffff",
		"Barra superior, caixa de ações e ficha lateral usam fundo branco.")
	_check(_background(bar.information_button, "normal") == "9d1d61"
		and _background(hud.walk_button, "normal") == "9d1d61",
		"Botões do HUD usam rosa, não branco.")
	_check(hud.cards[0].health_label.get_theme_color("font_color") ==
		palette.call("color", "danger"),
		"Texto de estatística mantém contraste sem mudar o sprite.")
	scale_service.call("set_ui_scale", 1.25, false)
	await process_frame
	await process_frame
	_check(_background(bar.bar_panel, "panel") == "ffffff"
		and _background(hud.action_drawer, "panel") == "ffffff"
		and _background(bar.information_button, "normal") == "9d1d61",
		"Escala não reverte cores da barra e HUD.")
	scale_service.call("set_ui_scale", old_scale, false)
	palette.call("set_palette", old_palette, false)
	scene.queue_free()
	await process_frame
	print("PPP_GAME_HUD_PALETTE_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _background(control: Control, key: String) -> String:
	var style := control.get_theme_stylebox(key) as StyleBoxFlat
	return style.bg_color.to_html(false) if style != null else "missing"


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
