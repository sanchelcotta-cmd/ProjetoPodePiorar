extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var phase := scene.get_node("RoundUI/NextPhaseButton") as Button
	var popup_layer := hud.get_node("HexChoiceLayer") as CanvasLayer
	_check(popup_layer.layer > phase.get_parent().layer,
		"A caixa contextual fica acima do botão Próxima fase.")
	_check(popup_layer.layer < 70,
		"A caixa contextual permanece abaixo da caixa de ativação de bloco.")
	var clicks := [0, 0]
	var action := Button.new()
	action.text = "ANDAR ATÉ"
	action.custom_minimum_size = Vector2(225, 36)
	action.pressed.connect(func() -> void: clicks[0] += 1)
	hud.hex_choice_buttons.add_child(action)
	phase.pressed.connect(func() -> void: clicks[1] += 1)
	phase.disabled = false
	phase.show()
	hud.hex_choice.show()
	hud.hex_choice.position = phase.get_global_rect().position - Vector2(20, 45)
	await process_frame
	await process_frame
	var target := action.get_global_rect().intersection(phase.get_global_rect())
	_check(target.has_area(), "A ação do hex cobre parte do botão Próxima fase no teste.")
	if target.has_area():
		var point := target.get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = point
		root.push_input(motion, true)
		await process_frame
		var down := InputEventMouseButton.new()
		down.position = point
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		root.push_input(down, true)
		var up := InputEventMouseButton.new()
		up.position = point
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		root.push_input(up, true)
		await process_frame
		_check(clicks[0] == 1 and clicks[1] == 0,
			"O clique sobreposto aciona o hex, não Próxima fase.")
	print("PPP_NEXT_PHASE_HEX_OVERLAY: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
