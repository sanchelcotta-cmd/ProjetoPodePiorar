class_name KeyboardButtonNavigation
extends RefCounted

## A seleção pelo teclado é deliberada: a primeira tecla apenas destaca.
## Uma janela nova deve chamar reset() para não herdar o botão anterior.
var _selected: Button
var _old_focus_mode := Control.FOCUS_ALL
var _old_focus_style: StyleBox
var _had_focus_override := false


func reset(root: Control) -> void:
	_clear_selection()
	if root != null and root.is_inside_tree():
		root.get_viewport().gui_release_focus()


func selected_button() -> Button:
	return _selected if is_instance_valid(_selected) else null


func clear() -> void:
	_clear_selection()


func highlight(button: Button) -> void:
	if button != null and not button.disabled and button.is_visible_in_tree():
		_select(button)


func handle(event: InputEvent, root: Control, allow_space: bool = true) -> bool:
	if root == null or not root.is_visible_in_tree() \
			or not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key := (event as InputEventKey).keycode
	if root.get_viewport().gui_get_focus_owner() is LineEdit \
			or root.get_viewport().gui_get_focus_owner() is TextEdit:
		return false
	if key not in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
			KEY_A, KEY_D, KEY_W, KEY_S,
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return false
	if key == KEY_SPACE and not allow_space:
		return true
	var available: Array[Button] = []
	_collect_buttons(root, available)
	return _handle_available(event, available)


func handle_buttons(event: InputEvent, buttons: Array[Button]) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key := (event as InputEventKey).keycode
	if key not in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
			KEY_A, KEY_D, KEY_W, KEY_S,
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		return false
	var available: Array[Button] = []
	for button in buttons:
		if is_instance_valid(button) and not button.disabled \
				and button.is_visible_in_tree():
			available.append(button)
	if not available.is_empty() and (available[0].get_viewport().gui_get_focus_owner() \
			is LineEdit or available[0].get_viewport().gui_get_focus_owner() is TextEdit):
		return false
	return _handle_available(event, available)


func _handle_available(event: InputEvent, available: Array[Button]) -> bool:
	var key := (event as InputEventKey).keycode
	if available.is_empty():
		_clear_selection()
		return true
	if not is_instance_valid(_selected) or _selected not in available:
		_select(_rightmost(available) if key in [KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S] \
			else _leftmost(available))
		return true
	if key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		if _selected.toggle_mode:
			_selected.button_pressed = not _selected.button_pressed
		_selected.pressed.emit()
		return true
	if key == KEY_TAB:
		available.sort_custom(_reading_order)
		var step := -1 if (event as InputEventKey).shift_pressed else 1
		_select(available[posmod(available.find(_selected) + step,
			available.size())])
		return true
	var direction := Vector2.LEFT if key in [KEY_LEFT, KEY_A] else \
		Vector2.RIGHT if key in [KEY_RIGHT, KEY_D] else \
		Vector2.UP if key in [KEY_UP, KEY_W] else Vector2.DOWN
	var nearest := _nearest_in_direction(available, direction)
	if nearest != null:
		_select(nearest)
	return true


func _collect_buttons(node: Node, result: Array[Button]) -> void:
	for child in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Button and not (child as Button).disabled \
				and not child is OptionButton:
			result.append(child as Button)
		_collect_buttons(child, result)


func _leftmost(buttons: Array[Button]) -> Button:
	var chosen := buttons[0]
	for button in buttons:
		if button.global_position.x < chosen.global_position.x \
				or (is_equal_approx(button.global_position.x, chosen.global_position.x) \
				and button.global_position.y < chosen.global_position.y):
			chosen = button
	return chosen


func _rightmost(buttons: Array[Button]) -> Button:
	var chosen := buttons[0]
	for button in buttons:
		if button.global_position.x > chosen.global_position.x \
				or (is_equal_approx(button.global_position.x, chosen.global_position.x) \
				and button.global_position.y > chosen.global_position.y):
			chosen = button
	return chosen


func _reading_order(a: Button, b: Button) -> bool:
	if absf(a.global_position.y - b.global_position.y) > 12.0:
		return a.global_position.y < b.global_position.y
	return a.global_position.x < b.global_position.x


func _nearest_in_direction(buttons: Array[Button], direction: Vector2) -> Button:
	var origin := _selected.get_global_rect().get_center()
	var chosen: Button
	var best := INF
	for button in buttons:
		if button == _selected:
			continue
		var delta := button.get_global_rect().get_center() - origin
		var forward := delta.dot(direction)
		if forward <= 1.0:
			continue
		var sideways := absf(delta.cross(direction))
		var score := forward + sideways * 2.0
		if score < best:
			best = score
			chosen = button
	return chosen


func _select(button: Button) -> void:
	if button == _selected:
		return
	_clear_selection()
	_selected = button
	_old_focus_mode = button.focus_mode
	_had_focus_override = button.has_theme_stylebox_override("focus")
	_old_focus_style = button.get_theme_stylebox("focus") if _had_focus_override else null
	var glow := StyleBoxFlat.new()
	glow.bg_color = Color(0.02, 0.39, 0.38, 0.46)
	glow.border_color = Color(0.0, 0.97, 0.85)
	glow.set_border_width_all(3)
	glow.set_corner_radius_all(4)
	glow.shadow_color = Color(0.0, 0.96, 0.84, 0.68)
	glow.shadow_size = 10
	button.add_theme_stylebox_override("focus", glow)
	button.focus_mode = Control.FOCUS_ALL
	button.grab_focus()


func _clear_selection() -> void:
	if is_instance_valid(_selected):
		if _had_focus_override and _old_focus_style != null:
			_selected.add_theme_stylebox_override("focus", _old_focus_style)
		else:
			_selected.remove_theme_stylebox_override("focus")
		_selected.focus_mode = _old_focus_mode
		_selected.release_focus()
	_selected = null
	_old_focus_style = null
	_had_focus_override = false
