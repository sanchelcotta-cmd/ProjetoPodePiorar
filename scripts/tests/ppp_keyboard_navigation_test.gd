extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var panel := Control.new()
	panel.size = Vector2(400, 140)
	root.add_child(panel)
	var left := Button.new()
	left.position = Vector2(20, 40)
	left.size = Vector2(120, 42)
	panel.add_child(left)
	var right := Button.new()
	right.position = Vector2(220, 40)
	right.size = Vector2(120, 42)
	panel.add_child(right)
	var activations := [0]
	left.pressed.connect(func() -> void: activations[0] += 1)
	var navigation := KeyboardButtonNavigation.new()
	navigation.reset(panel)
	_check(navigation.selected_button() == null,
		"Uma caixa nova começa sem botão destacado.")
	var enter := _key(KEY_ENTER)
	navigation.handle(enter, panel)
	_check(navigation.selected_button() == left and activations[0] == 0,
		"O primeiro Enter só destaca o botão à esquerda.")
	var focus := left.get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus != null and focus.shadow_size >= 10
		and focus.border_color.s > 0.8,
		"O destaque por teclado usa borda viva e brilho discreto.")
	navigation.handle(enter, panel)
	_check(activations[0] == 1, "O segundo Enter aciona o botão destacado.")
	navigation.reset(panel)
	navigation.handle(_key(KEY_RIGHT), panel)
	_check(navigation.selected_button() == right,
		"Direita destaca inicialmente o botão à direita.")
	navigation.handle(_key(KEY_TAB), panel)
	_check(navigation.selected_button() == left,
		"Tab percorre os botões e retorna ao primeiro.")
	navigation.clear()
	panel.queue_free()
	await process_frame
	await process_frame
	print("PPP keyboard navigation: %d falhas" % failures)
	quit(1 if failures > 0 else 0)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
