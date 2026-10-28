extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1288, 716)
	var comfort := root.get_node("VisualComfort")
	var previous_comfort := bool(comfort.get("enabled"))
	comfort.call("set_enabled", false, false)
	var menu := load("res://scenes/ui/main_menu.tscn").instantiate() as PPPMainMenu
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var logo := menu.get_node("MenuLogo") as TextureRect
	_check(logo != null and logo.texture.resource_path.ends_with("logo_previa.png"),
		"A abertura inicia com a logo prévia.")
	_check(int(logo.get("_phase")) == 0, "Primeiro estágio revela só PPP e i.")
	_check(absf((logo.position.x + logo.size.x * 0.5) - menu.size.x * 0.5) < 1.0,
		"Logo fica centralizada horizontalmente.")
	await _capture_if_visible("primeiras_letras")
	await create_timer(1.08).timeout
	_check(int(logo.get("_phase")) == 1, "Prévia completa aparece após um segundo.")
	await _capture_if_visible("interrogacao")
	await create_timer(3.05).timeout
	_check(int(logo.get("_phase")) == 2, "Glitch localizado começa após três segundos.")
	await create_timer(0.40).timeout
	_check(int(logo.get("_phase")) == 3 and
		logo.texture.resource_path.ends_with("logo_oficial.png"),
		"Logo oficial com exclamação substitui a prévia.")
	await _capture_if_visible("oficial")
	logo.set("_until_glitch", 0.0)
	await create_timer(0.04).timeout
	_check(int(logo.get("_phase")) == 4, "Logo oficial tem glitch ocasional separado.")
	await _capture_if_visible("glitch_ocasional")
	await create_timer(0.55).timeout
	_check(int(logo.get("_phase")) == 3, "Glitch ocasional termina em meio segundo.")
	var fake_game := Control.new()
	fake_game.set_meta("defer_preview_map", true)
	root.add_child(fake_game)
	var fake_top_bar := Control.new()
	fake_game.add_child(fake_top_bar)
	var pause := CampaignPauseMenu.new()
	pause.top_bar = fake_top_bar
	fake_top_bar.add_child(pause)
	var pause_logo := pause._screen.get_node("PauseLogo") as TextureRect
	_check(pause_logo != null and
		pause_logo.texture.resource_path.ends_with("logo_outline.png") and
		pause_logo.material is ShaderMaterial,
		"Pausa usa a outline com shader branco e mint.")
	await process_frame
	_check(absf((pause._menu.position.x + pause._menu.size.x * 0.5)
		- pause._screen.size.x * 0.5) < 1.0,
		"Botões da pausa voltam ao centro horizontal.")
	_check(pause_logo.position.x > pause._screen.size.x * 0.5,
		"Outline da pausa ocupa o canto superior direito.")
	_check(pause._screen.size.x - pause_logo.position.x - pause_logo.size.x
		>= pause_logo.size.x * 0.3 and
		pause._screen.size.x - pause_logo.position.x - pause_logo.size.x
		<= pause_logo.size.x * 0.4 and
		pause_logo.position.y >= pause_logo.size.y * 0.6,
		"Outline ocupa a área superior direita indicada, com folga nas bordas.")
	pause._screen.show()
	await _capture_if_visible("pausa")
	fake_game.queue_free()
	comfort.call("set_enabled", previous_comfort, false)
	print("PPP_MENU_LOGO_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _capture_if_visible(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("user://ppp_logo_%s.png" % label)
	if root.get_texture().get_image().save_png(path) == OK:
		print("PPP_MENU_LOGO_CAPTURE: %s" % path)
