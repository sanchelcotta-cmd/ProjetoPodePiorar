extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var sfx := root.get_node("UISFX")
	var streams: Dictionary = sfx.get("_streams")
	for kind in ["start_game", "blocked_button", "hover", "menu_page",
			"confirm", "equip", "unequip", "item_reward", "inventory_click",
			"epic_craft", "outcome_click", "general_click", "world_click",
			"hex_open", "information_found", "info_records_click"]:
		_check(streams.has(StringName(kind)) and streams[StringName(kind)] is AudioStream,
			"SFX de %s está importado e disponível." % kind)
	for voice_name in ["_click_voice", "_notice_voice", "_panel_voice", "_hover_voice"]:
		var voice := sfx.get(voice_name) as AudioStreamPlayer
		_check(voice != null and voice.bus == &"ClickUI",
			"%s respeita Efeitos e interface." % voice_name)
	var button := Button.new()
	button.text = "CONFIRMAR"
	root.add_child(button)
	_check(sfx.call("_button_kind", button) == &"confirm",
		"Confirmação recebe seu som próprio.")
	button.set_meta("ui_sfx_kind", &"menu_page")
	_check(sfx.call("_button_kind", button) == &"menu_page",
		"Navegação explícita vence a classificação genérica.")
	sfx.call("play", &"inventory_click")
	sfx.call("play", &"equip")
	await process_frame
	_check(sfx.get("last_played_kind") == &"equip",
		"Equipar vence clique genérico do inventário na mesma ação.")
	sfx.call("play", &"world_click")
	await process_frame
	_check(is_equal_approx((sfx.get("_click_voice") as AudioStreamPlayer).pitch_scale,
		1.13), "Clique no mundo usa o mesmo arquivo com pitch levemente maior.")
	sfx.call("play", &"blocked_button")
	await process_frame
	_check(is_equal_approx((sfx.get("_click_voice") as AudioStreamPlayer).volume_linear,
		0.68), "Aviso de bloqueio toca mais baixo.")
	sfx.call("play", &"hover")
	_check(is_equal_approx((sfx.get("_hover_voice") as AudioStreamPlayer).volume_linear,
		0.2925), "Hover usa metade do ganho de 58,5% anterior.")
	button.free()
	print("PPP_UI_SFX_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	sfx.call("quit_game", 0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
