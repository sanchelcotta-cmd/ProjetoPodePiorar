extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var palette := root.get_node("UIColorManager")
	var original := str(palette.get("palette_id"))
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var skill := hud._make_choice_button("HABILIDADE", Color(0.52, 0.36, 0.055),
		"skill")
	var core := hud._make_choice_button("ATACAR", Color(0.55, 0.10, 0.12),
		"core")
	var passed := hud._make_choice_button("PASSAR O TURNO", Color(0.68, 0.10, 0.16),
		"pass")
	var pass_only := hud._make_choice_button("PASSAR O TURNO", Color(0.68, 0.10, 0.16),
		"pass_only")
	for button in [skill, core, passed, pass_only]:
		hud.add_child(button)
	palette.call("set_palette", "padrao", false)
	await process_frame
	await process_frame
	check(_background(skill) == Color("#FFD459")
		and _background(core) == Color("#4DE385")
		and _background(passed) == Color("#741F2F"),
		"Padrão: ativa amarela, combate verde, passar turno vermelho escuro.")
	for button in [skill, core, passed, pass_only]:
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			var text_key := "font_color" if state == "normal" else \
				"font_hover_color" if state == "hover" else "font_pressed_color"
			check(_contrast(style.bg_color, button.get_theme_color(text_key)) >= 4.5,
				"Padrão: texto legível em %s/%s." % [button.text, state])
	for other in ["azul", "rosa_branco", "acessivel"]:
		palette.call("set_palette", other, false)
		await process_frame
		await process_frame
		check(_background(skill) == palette.call("color", "button")
			and _background(core) == palette.call("color", "button")
			and _background(pass_only) == palette.call("color", "button")
			and _background(passed) == palette.call("color", "button_danger"),
			"%s conserva as cores anteriores." % other)
	palette.call("set_palette", original, false)
	scene.queue_free()
	await process_frame
	print("ACTION_BUTTON_PALETTE_TEST_OK" if failures == 0 else
		"ACTION_BUTTON_PALETTE_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _background(button: Button) -> Color:
	return (button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color


func _contrast(first: Color, second: Color) -> float:
	var high: float = maxf(_luminance(first), _luminance(second))
	var low: float = minf(_luminance(first), _luminance(second))
	return (high + 0.05) / (low + 0.05)


func _luminance(color: Color) -> float:
	var red := color.r / 12.92 if color.r <= 0.04045 else \
		pow((color.r + 0.055) / 1.055, 2.4)
	var green := color.g / 12.92 if color.g <= 0.04045 else \
		pow((color.g + 0.055) / 1.055, 2.4)
	var blue := color.b / 12.92 if color.b <= 0.04045 else \
		pow((color.b + 0.055) / 1.055, 2.4)
	return 0.2126 * red + 0.7152 * green + 0.0722 * blue


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
