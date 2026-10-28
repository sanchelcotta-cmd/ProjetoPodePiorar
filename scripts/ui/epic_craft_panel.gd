class_name EpicCraftPanel
extends Control

## Janela única para craft comum e Artesanato com EVA. O consumo acontece
## somente ao confirmar uma saída Épica; ESC antes disso não muda inventário.
signal inventory_changed
signal closed

const GOLD := Color(1.0, 0.81, 0.20)
const PINK := Color(0.996, 0.169, 0.592)
const CYAN := Color(0.10, 0.85, 0.96)
const WHITE := Color(0.94, 0.96, 0.97)
const BOLD := preload("res://fonts/UbuntuSans-Bold.ttf")
const DETAILS_SCENE := preload("res://scenes/ui/item_details_panel.tscn")

var campaign: CampaignState
var inventory: InventoryManager
var skill_manager: SkillManager
var exploration: ExplorationManager
var dialog: PanelContainer
var header: HBoxContainer
var title: Label
var intro: Label
var owner_label: Label
var previous_button: Button
var next_button: Button
var ingredient_row: HBoxContainer
var consumption_note: Label
var choice_hint: Label
var results_row: HBoxContainer
var create_button: Button
var status_label: Label
var success_box: VBoxContainer
var success_title: Label
var success_icon: TextureRect
var success_buttons: HBoxContainer
var another_box: HBoxContainer
var details: ItemDetailsPanel
var _options: Array[Dictionary] = []
var _index := 0
var _phase := &"preview"
var _selected_result: ItemData
var _crafted_entry: InventoryItemState
var _crafted_actor: EntityState
var _dragging := false


func _ready() -> void:
	_build()
	hide()


func _process(_delta: float) -> void:
	# O Container pode recuperar temporariamente o tamanho máximo calculado
	# antes de ocultar uma fase. Mantenha a janela justa ao conteúdo visível.
	if visible and dialog != null:
		var target_height := _target_height()
		if dialog.size.y > target_height + 1.0:
			_fit_dialog()


func open_for(game_campaign: CampaignState, items: InventoryManager,
		skills: SkillManager, map_exploration: ExplorationManager,
		preferred_actor: EntityState = null, preferred_item: ItemData = null) -> void:
	campaign = game_campaign
	inventory = items
	skill_manager = skills
	exploration = map_exploration
	_crafted_entry = null
	_crafted_actor = null
	_selected_result = null
	_phase = &"preview"
	_rebuild_options()
	_index = 0
	var found_preferred := preferred_item == null
	for index in _options.size():
		var option := _options[index]
		if option["actor"] == preferred_actor and (preferred_item == null \
				or (option["ingredient"] as ItemData).id == preferred_item.id):
			_index = index
			found_preferred = true
			break
	if not found_preferred and preferred_actor != null and preferred_item != null \
			and not preferred_item.craft_result.is_empty():
		var results: Array[ItemData] = []
		for raw_result in preferred_item.craft_result:
			var result := raw_result as ItemData
			if result != null and result.rarity == ItemData.Rarity.EPIC:
				results.append(result)
		if not results.is_empty():
			_options.append({"actor": preferred_actor, "ingredient": preferred_item,
				"results": results, "required_copies": 3,
				"eva_grant": null, "preview_only": true})
			_index = _options.size() - 1
	_render()
	show()
	dialog.position = (get_viewport_rect().size - dialog.size) * 0.5
	dialog.position = _clamp(dialog.position)
	dialog.grab_focus()


func close() -> void:
	if not visible:
		return
	_dragging = false
	if details != null:
		details.hide()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if details.visible:
			details.hide()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif _dragging and event is InputEventMouseMotion:
		dialog.position = _clamp(dialog.position + event.relative)
		get_viewport().set_input_as_handled()
	elif _dragging and event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging = false


func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_dragging = true
		get_viewport().set_input_as_handled()


func _clamp(candidate: Vector2) -> Vector2:
	var viewport := get_viewport_rect().size
	return Vector2(clampf(candidate.x, 12.0,
		maxf(12.0, viewport.x - dialog.size.x - 12.0)),
		clampf(candidate.y, 12.0,
			maxf(12.0, viewport.y - dialog.size.y - 12.0)))


func _rebuild_options() -> void:
	_options.clear()
	if campaign == null or inventory == null:
		return
	for actor in campaign.active_entity_states:
		for option in CraftAvailability.options_for(actor, inventory, exploration):
			var record := option.duplicate()
			record["actor"] = actor
			_options.append(record)


func _current() -> Dictionary:
	return _options[_index] if _index >= 0 and _index < _options.size() else {}


func _render() -> void:
	details.hide()
	var option := _current()
	var has_option := not option.is_empty()
	var choice := _phase == &"choose_result"
	var success := _phase == &"success" or _phase == &"after_success"
	intro.visible = not success
	owner_label.visible = not success
	ingredient_row.visible = not success
	consumption_note.visible = not success
	choice_hint.visible = not success
	results_row.visible = not success
	create_button.visible = not success and (not choice or _selected_result != null)
	previous_button.visible = not success and not choice and _options.size() > 1
	next_button.visible = previous_button.visible
	success_box.visible = success
	another_box.visible = _phase == &"after_success"
	success_buttons.visible = _phase == &"success"
	status_label.text = ""
	if success:
		_fit_dialog()
		return
	if not has_option:
		owner_label.text = "Nenhuma receita Épica disponível agora."
		create_button.disabled = true
		_fit_dialog()
		return
	var ingredient := option["ingredient"] as ItemData
	var count := int(option["required_copies"])
	owner_label.visible = count == 2
	owner_label.text = "ARTESANATO COM EVA · 2 ITENS" if count == 2 else ""
	intro.text = "Use 2 itens comuns iguais com Artesanato com EVA para criar um Épico" \
		if count == 2 else "Junte 3 itens comuns iguais para criar um equipamento Épico"
	_clear(ingredient_row)
	for index in 3:
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(105, 105)
		box.add_theme_stylebox_override("panel", _style(Color(0.08, 0.09, 0.10, 0.94), GOLD, 2))
		ingredient_row.add_child(box)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(column)
		if index < count:
			var icon := TextureRect.new()
			icon.custom_minimum_size = Vector2(72, 70)
			icon.texture = ingredient.icon
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			column.add_child(icon)
			var label := _label(ingredient.display_name, 10, WHITE)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			column.add_child(label)
		else:
			var eva := _label("EVA", 20, GOLD)
			eva.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(eva)
	consumption_note.text = "ⓘ Os %d itens serão consumidos%s." % [count,
		"; a ativa da Professora será gasta" if count == 2 else ""]
	choice_hint.visible = (option["results"] as Array).size() > 1
	choice_hint.text = "Escolha qual item épico criar" if choice_hint.visible else ""
	_clear(results_row)
	for result in option["results"]:
		_add_result(result as ItemData, choice)
	create_button.disabled = bool(option.get("preview_only", false)) \
		or (choice and _selected_result == null)
	if bool(option.get("preview_only", false)):
		status_label.text = "Reúna três cópias com o mesmo jogável para criar este item.\nFeche esta janela e transfira os itens no Inventário do grupo."
	elif count == 2:
		status_label.text = "A Professora usará Artesanato com EVA (uma vez por Dia)."
	create_button.text = "CRIAR ÉPICO"
	_fit_dialog()


func _fit_dialog() -> void:
	# PanelContainer conserva o maior tamanho já calculado quando filhos ficam
	# invisíveis; reduzi-lo explicitamente evita a enorme área vazia inicial.
	var center := dialog.position + dialog.size * 0.5
	dialog.custom_minimum_size = Vector2(560, _target_height())
	dialog.size = dialog.custom_minimum_size
	dialog.position = _clamp(center - dialog.size * 0.5)


func _target_height() -> float:
	if _phase in [&"success", &"after_success"]:
		return 430.0
	if _phase == &"choose_result":
		return 500.0
	var option := _current()
	return 545.0 if not option.is_empty() and \
		(option["results"] as Array).size() > 1 else 520.0


func _add_result(item: ItemData, selectable: bool) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 165
	column.add_theme_constant_override("separation", 3)
	results_row.add_child(column)
	var card := Button.new()
	card.custom_minimum_size = Vector2(155, 108)
	var selected := selectable and item == _selected_result
	var card_style := _style(Color(0.10, 0.11, 0.13, 0.98), GOLD,
		3 if selected else 2)
	if selected:
		card_style.shadow_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.55)
		card_style.shadow_size = 7
	card.add_theme_stylebox_override("normal", card_style)
	card.scale = Vector2(1.06, 1.06) if selected else Vector2.ONE
	card.pivot_offset = Vector2(77.5, 54.0)
	card.tooltip_text = "Selecionar %s" % item.display_name if selectable \
		else "Prévia de %s" % item.display_name
	card.pressed.connect(_on_result_clicked.bind(item))
	card.disabled = not selectable
	column.add_child(card)
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 16
	icon.offset_top = 6
	icon.offset_right = -16
	icon.offset_bottom = -6
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	var name := _label(item.display_name, 12, WHITE)
	name.add_theme_font_override("font", BOLD)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(name)
	var details_button := Button.new()
	details_button.text = "ⓘ"
	details_button.tooltip_text = "Clique para expandir detalhes"
	details_button.custom_minimum_size = Vector2(25, 25)
	details_button.add_theme_font_size_override("font_size", 18)
	details_button.add_theme_color_override("font_color", Color(0.88, 0.74, 0.32))
	details_button.add_theme_color_override("font_hover_color", GOLD)
	details_button.add_theme_color_override("font_pressed_color", WHITE)
	details_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	details_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	details_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	details_button.pressed.connect(_show_details.bind(item))
	bottom.add_child(details_button)


func _on_create_pressed() -> void:
	var option := _current()
	if option.is_empty() or bool(option.get("preview_only", false)):
		return
	if (option["results"] as Array).size() > 1 and _phase != &"choose_result":
		_phase = &"choose_result"
		_selected_result = null
		_render()
	elif _phase == &"choose_result":
		if _selected_result != null:
			_choose_result(_selected_result)
	else:
		_choose_result(option["results"][0])


func _on_result_clicked(item: ItemData) -> void:
	if _phase != &"choose_result" or item == null:
		return
	_selected_result = item
	_render()


func _choose_result(item: ItemData) -> void:
	var option := _current()
	if option.is_empty() or item not in option["results"] \
			or bool(option.get("preview_only", false)):
		return
	var actor := option["actor"] as EntityState
	var ingredient := option["ingredient"] as ItemData
	var result: Dictionary = {}
	if int(option["required_copies"]) == 2:
		var grant := option["eva_grant"] as SkillGrantState
		var existing: Array[InventoryItemState] = []
		for entry in actor.inventory_items:
			if entry != null:
				existing.append(entry)
		if exploration != null and exploration.player_skill_manager.use_craft_active(
				actor, grant, ingredient.id, item.id, exploration):
			for entry in actor.inventory_items:
				if entry != null and entry.data == item and entry not in existing:
					result = {"success": true, "crafted_copy": entry}
		else:
			result = {"success": false}
	else:
		result = inventory.craft(actor, ingredient.id, item.id, 3, skill_manager)
	if not result.get("success", false):
		get_node("/root/UISFX").call("play", &"blocked_button")
		status_label.text = "Não foi possível criar agora. Confira espaço, itens e habilidade disponível."
		_rebuild_options()
		return
	_crafted_entry = result.get("crafted_copy") as InventoryItemState
	get_node("/root/UISFX").call("play", &"epic_craft")
	_crafted_actor = actor
	if campaign != null:
		campaign.append_journal_entry(&"craft_item", [
			{"text": actor.visible_name(), "tone": "actor"},
			{"text": " criou ", "tone": "text"},
			{"text": item.display_name, "tone": "item"},
			{"text": " usando %d %s." % [int(option["required_copies"]),
				ingredient.display_name], "tone": "positive"},
		], actor.instance_id, {"item_id": str(item.id),
			"ingredient_id": str(ingredient.id),
			"ingredient_count": int(option["required_copies"])})
	_phase = &"success"
	success_title.text = "VOCÊ CRIOU %s" % item.display_name.to_upper()
	success_icon.texture = item.icon
	success_icon.scale = Vector2.ONE
	_render()
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort == null or not bool(comfort.get("enabled")):
		var flash := create_tween()
		flash.tween_property(success_icon, "scale", Vector2(1.30, 1.30), 0.28)
		flash.tween_property(success_icon, "scale", Vector2.ONE, 0.23)
	inventory_changed.emit()


func _finish_success(equip_item: bool) -> void:
	if equip_item and _crafted_entry != null and _crafted_actor != null:
		if not EquipmentManager.new().equip(_crafted_actor, _crafted_entry,
				skill_manager, campaign):
			get_node("/root/UISFX").call("play", &"blocked_button")
			status_label.text = "Não há espaço/condição para equipar. O item permanece no inventário."
			return
		inventory_changed.emit()
		get_node("/root/UISFX").call("play", &"equip")
	_rebuild_options()
	if _options.is_empty():
		close()
	else:
		_phase = &"after_success"
		_render()


func _create_another() -> void:
	_index = 0
	_phase = &"preview"
	_selected_result = null
	_crafted_entry = null
	_crafted_actor = null
	_render()


func _change_recipe(direction: int) -> void:
	if _options.size() < 2:
		return
	_index = posmod(_index + direction, _options.size())
	_phase = &"preview"
	_selected_result = null
	_render()


func _show_details(item: ItemData) -> void:
	if item == null:
		return
	details.bind_entry(InventoryItemState.new(item))
	details.show()
	await get_tree().process_frame
	if not is_inside_tree() or not details.visible:
		return
	details.fit_height(minf(460.0, get_viewport_rect().size.y - 40.0))
	var viewport := get_viewport_rect().size
	details.position = Vector2(
		clampf(dialog.position.x + dialog.size.x + 12.0, 12.0,
			maxf(12.0, viewport.x - details.size.x - 12.0)),
		clampf(dialog.position.y + 60.0, 12.0,
			maxf(12.0, viewport.y - details.size.y - 12.0)))


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.70)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog = PanelContainer.new()
	dialog.name = "CraftWindow"
	dialog.focus_mode = Control.FOCUS_ALL
	dialog.custom_minimum_size = Vector2(560, 520)
	dialog.size = dialog.custom_minimum_size
	dialog.add_theme_stylebox_override("panel", _style(
		Color(0.035, 0.045, 0.055, 0.97), GOLD, 2))
	add_child(dialog)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	dialog.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	header = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_input)
	stack.add_child(header)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	title = _label("Esc ou", 11, Color(0.75, 0.77, 0.78))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.tooltip_text = "Fechar (Esc)"
	close_button.custom_minimum_size = Vector2(32, 30)
	close_button.pressed.connect(close)
	header.add_child(close_button)
	intro = _label("Junte 3 itens comuns iguais para criar um equipamento Épico", 14, WHITE)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(intro)
	owner_label = _label("", 12, GOLD)
	owner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(owner_label)
	var recipe_row := HBoxContainer.new()
	recipe_row.alignment = BoxContainer.ALIGNMENT_CENTER
	recipe_row.add_theme_constant_override("separation", 12)
	stack.add_child(recipe_row)
	previous_button = Button.new()
	previous_button.text = "◀"
	previous_button.add_theme_font_size_override("font_size", 12)
	previous_button.custom_minimum_size = Vector2(20, 20)
	previous_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	previous_button.tooltip_text = "Receita anterior"
	previous_button.pressed.connect(_change_recipe.bind(-1))
	recipe_row.add_child(previous_button)
	ingredient_row = HBoxContainer.new()
	ingredient_row.add_theme_constant_override("separation", 9)
	recipe_row.add_child(ingredient_row)
	next_button = Button.new()
	next_button.text = "▶"
	next_button.add_theme_font_size_override("font_size", 12)
	next_button.custom_minimum_size = Vector2(20, 20)
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.tooltip_text = "Próxima receita"
	next_button.pressed.connect(_change_recipe.bind(1))
	recipe_row.add_child(next_button)
	consumption_note = _label("ⓘ Os três itens serão consumidos.", 11, Color(0.78, 0.82, 0.85))
	consumption_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(consumption_note)
	choice_hint = _label("", 13, GOLD)
	choice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_hint.add_theme_font_override("font", BOLD)
	stack.add_child(choice_hint)
	results_row = HBoxContainer.new()
	results_row.alignment = BoxContainer.ALIGNMENT_CENTER
	results_row.add_theme_constant_override("separation", 12)
	stack.add_child(results_row)
	create_button = Button.new()
	create_button.text = "CRIAR ÉPICO"
	create_button.custom_minimum_size = Vector2(210, 43)
	create_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	create_button.add_theme_stylebox_override("normal", _style(
		Color(0.27, 0.21, 0.03), GOLD, 2))
	create_button.pressed.connect(_on_create_pressed)
	stack.add_child(create_button)
	status_label = _label("", 12, GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(status_label)
	success_box = VBoxContainer.new()
	success_box.alignment = BoxContainer.ALIGNMENT_CENTER
	success_box.add_theme_constant_override("separation", 10)
	stack.add_child(success_box)
	success_title = _label("VOCÊ CRIOU UM ITEM ÉPICO", 16, GOLD)
	success_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	success_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	success_title.add_theme_font_override("font", BOLD)
	success_box.add_child(success_title)
	var icon_frame := CenterContainer.new()
	icon_frame.custom_minimum_size.y = 200
	success_box.add_child(icon_frame)
	success_icon = TextureRect.new()
	success_icon.custom_minimum_size = Vector2(140, 140)
	success_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	success_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	success_icon.pivot_offset = Vector2(70, 70)
	icon_frame.add_child(success_icon)
	success_buttons = HBoxContainer.new()
	success_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	success_buttons.add_theme_constant_override("separation", 10)
	success_box.add_child(success_buttons)
	var okay := Button.new()
	okay.text = "OK · GUARDAR"
	okay.custom_minimum_size = Vector2(145, 40)
	_accent_button(okay, Color(0.06, 0.24, 0.42), CYAN, false)
	okay.pressed.connect(_finish_success.bind(false))
	success_buttons.add_child(okay)
	var equip := Button.new()
	equip.text = "EQUIPAR ITEM"
	equip.custom_minimum_size = Vector2(145, 40)
	_accent_button(equip, Color(0.04, 0.35, 0.51), Color(0.25, 1.0, 1.0), true)
	equip.pressed.connect(_finish_success.bind(true))
	success_buttons.add_child(equip)
	another_box = HBoxContainer.new()
	another_box.alignment = BoxContainer.ALIGNMENT_CENTER
	another_box.add_theme_constant_override("separation", 12)
	success_box.add_child(another_box)
	var another := Button.new()
	another.text = "CRIAR OUTRO ITEM"
	another.custom_minimum_size = Vector2(170, 40)
	another.pressed.connect(_create_another)
	another_box.add_child(another)
	var finish := Button.new()
	finish.text = "FECHAR"
	finish.custom_minimum_size = Vector2(110, 40)
	finish.pressed.connect(close)
	another_box.add_child(finish)
	details = DETAILS_SCENE.instantiate() as ItemDetailsPanel
	add_child(details)
	var detail_style := _style(Color(0.027, 0.044, 0.058, 0.94), GOLD, 2)
	details.add_theme_stylebox_override("panel", detail_style)
	details.z_index = 2
	details.close_requested.connect(func() -> void: details.hide())
	details.hide()
	success_box.hide()
	another_box.hide()


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(7)
	return style


func _accent_button(button: Button, background: Color, border: Color,
		glow: bool) -> void:
	var normal := _style(background, border, 2)
	if glow:
		normal.shadow_color = Color(border.r, border.g, border.b, 0.38)
		normal.shadow_size = 5
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _style(
		background.lightened(0.18), border.lightened(0.12), 2))
	button.add_theme_stylebox_override("pressed", _style(
		background.darkened(0.14), border, 2))
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
