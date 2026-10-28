class_name GroupInventoryPanel
extends Control

signal death_cleanup_completed

## Janela de consulta dos três inventários reais da campanha. Não duplica
## itens: cada célula lê InventoryItemState do seu Playable_1/2/3.
## Equipados vêm de espaços separados no EntityState; não contam nos 12.

const BASE_SLOTS := 12
const GRID_COLUMNS := 3
const SLOT_SIZE := Vector2(58, 52)
const SLOT_FRAME := preload("res://sprites/ui/uielementx_00002.png")
const DETAILS_SCENE := preload("res://scenes/ui/item_details_panel.tscn")
const ITEM_MENU_SCRIPT := preload("res://scripts/ui/inventory_item_menu.gd")
const INACTIVE_SHADER := preload("res://shaders/ui_inactive_grayscale.gdshader")
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const SLOT_BUTTON_SCRIPT := preload("res://scripts/ui/inventory_slot_button.gd")
const EQUIPMENT_SLOT_BUTTON_SCRIPT := preload("res://scripts/ui/group_equipment_slot_button.gd")
const CRAFT_PANEL_SCRIPT := preload("res://scripts/ui/epic_craft_panel.gd")
const CRAFT_HINT_SCRIPT := preload("res://scripts/ui/craft_hint_popup.gd")
const BLUE := Color(0.13, 0.74, 0.94)
const PINK := Color(0.996, 0.169, 0.592)
const TEXT := Color(0.9, 0.93, 0.95)
const VIEWPORT_MARGIN := 15.0

var gerencia: GerenciaJogo
var skill_manager: SkillManager
var combat_manager: CombatManager
var exploration: ExplorationManager
var window: PanelContainer
var columns: Array[Dictionary] = []
var _death_column: Dictionary = {}
var expanded_by_slot := [false, false, false, false]
var details: ItemDetailsPanel
var details_link: Line2D
var item_menu: InventoryItemMenu
var _chance_result_dialog: Control
var _refresh_elapsed := 0.0
var _window_dragging := false
var _window_user_positioned := false
var _window_resizing := false
var _resize_start_mouse := Vector2.ZERO
var _resize_start_factor := 1.0
var _window_scale_factor := 1.0
var _exchange_owner: EntityState
var _death_owner: EntityState
var _death_queue: Array[EntityState] = []
var _death_backdrop: ColorRect
var _exchange_item: ItemData
var _exchange_selected: Array[InventoryItemState] = []
var _exchange_inventory_snapshot: Array[Dictionary] = []
var _exchange_confirm_action: Callable
var _exchange_decline_action: Callable
var _exchange_allow_decline := true
var _exchange_bar: PanelContainer
var _exchange_message: Label
var _exchange_status: Label
var _exchange_accept_button: Button
var _exchange_decline_button: Button
var _exchange_cancel_button: Button
var _exchange_confirmation: Control
var _exchange_question: Label
var _close_button: Button
var _title_label: Label
var _equipment_manager := EquipmentManager.new()
var craft_panel: EpicCraftPanel
var craft_hint: CraftHintPopup


func _ready() -> void:
	_build_interface()
	craft_panel = CRAFT_PANEL_SCRIPT.new() as EpicCraftPanel
	craft_panel.name = "EpicCraftPanel"
	add_child(craft_panel)
	craft_panel.inventory_changed.connect(refresh)
	craft_panel.closed.connect(_on_craft_closed)
	craft_hint = CRAFT_HINT_SCRIPT.new() as CraftHintPopup
	craft_hint.name = "CraftHint"
	add_child(craft_hint)
	resized.connect(_layout_window)
	_layout_window()


func open() -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	for index in columns.size():
		columns[index]["signature"] = ""
	refresh()
	show()
	_layout_window()
	window.grab_focus()


func open_craft_for(actor: EntityState = null, item: ItemData = null) -> void:
	if gerencia == null or gerencia.campaign == null or skill_manager == null \
			or _exchange_owner != null or _death_owner != null or craft_panel == null:
		return
	open()
	item_menu.close()
	details.hide()
	details_link.hide()
	craft_hint.hide()
	craft_panel.open_for(gerencia.campaign, skill_manager.inventory_manager,
		skill_manager, exploration, actor, item)
	# O craft fica centralizado sobre o mapa ofuscado; o inventário permanece
	# pronto para voltar, mas não compete visualmente com a escolha Épica.
	window.hide()


func _on_craft_closed() -> void:
	if visible and _exchange_owner == null and _death_owner == null:
		window.show()


## Recebimento pendente: transferências entre jogáveis são provisórias até
## confirmar; Voltar/Esc restaura os inventários e conserva o item pendente.
func begin_exchange(owner: EntityState, incoming: ItemData,
		on_confirm: Callable, on_decline: Callable, allow_decline: bool = true) -> bool:
	if owner == null or incoming == null or not on_confirm.is_valid() \
			or gerencia == null or gerencia.campaign == null \
			or owner not in gerencia.campaign.active_entity_states:
		return false
	_exchange_owner = owner
	_exchange_item = incoming
	_exchange_selected.clear()
	_snapshot_exchange_inventories()
	_exchange_confirm_action = on_confirm
	_exchange_decline_action = on_decline
	_exchange_allow_decline = allow_decline and on_decline.is_valid()
	_close_button.show()
	_close_button.text = "← VOLTAR"
	_close_button.custom_minimum_size.x = 100
	_close_button.tooltip_text = "Cancelar esta tentativa de troca e voltar ao item (Esc)"
	_exchange_bar.show()
	_exchange_cancel_button.show()
	_exchange_confirmation.hide()
	item_menu.close()
	open()
	_update_exchange_ui()
	return true


func begin_death_cleanup(owner: EntityState) -> void:
	if owner == null or gerencia == null or gerencia.campaign == null \
			or owner not in gerencia.campaign.dead_playable_states:
		return
	var replacement := gerencia.campaign.get_playable_slot(owner.playable_slot_id)
	if owner.inventory_items.is_empty() and (replacement == null or replacement == owner):
		return
	if _death_owner != null or _exchange_owner != null:
		if owner not in _death_queue:
			_death_queue.append(owner)
		return
	_death_owner = owner
	_death_backdrop.show()
	if owner not in gerencia.campaign.active_entity_states:
		columns.append(_death_column)
		(_death_column["card"] as Control).show()
	_title_label.text = "REDISTRIBUA OS ITENS"
	for index in columns.size():
		if _actor_for_slot(index) == owner:
			expanded_by_slot[index] = true
	_close_button.hide()
	_exchange_bar.show()
	_exchange_confirmation.hide()
	_exchange_accept_button.text = "OK"
	_exchange_decline_button.text = "AINDA NÃO"
	_exchange_decline_button.show()
	_exchange_cancel_button.hide()
	item_menu.close()
	open()
	_update_death_ui()


func close(force: bool = false) -> void:
	if craft_panel != null and craft_panel.visible and not force:
		craft_panel.close()
		return
	if _death_owner != null and not force:
		if _exchange_confirmation.visible:
			_exchange_confirmation.hide()
		return
	if _exchange_owner != null and not force:
		_restore_exchange_inventories()
		refresh()
	_window_dragging = false
	_window_resizing = false
	details.hide()
	details_link.hide()
	item_menu.close()
	_exchange_owner = null
	_exchange_inventory_snapshot.clear()
	_death_owner = null
	_death_backdrop.hide()
	if columns.size() > 3:
		columns.pop_back()
	(_death_column["card"] as Control).hide()
	_title_label.text = "▣ INVENTÁRIO DO GRUPO"
	_exchange_item = null
	_exchange_selected.clear()
	_exchange_confirm_action = Callable()
	_exchange_decline_action = Callable()
	_exchange_bar.hide()
	_exchange_confirmation.hide()
	_exchange_cancel_button.hide()
	_close_button.show()
	_close_button.text = "X"
	_close_button.custom_minimum_size.x = 31
	_close_button.tooltip_text = "Fechar inventário (Esc)"
	_exchange_accept_button.text = "ACEITAR TROCA"
	_exchange_decline_button.text = "RECUSAR TROCA"
	hide()
	if not _death_queue.is_empty():
		var next_owner: EntityState = _death_queue.pop_front()
		begin_death_cleanup.call_deferred(next_owner)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed \
			or event.echo or event.keycode != KEY_ESCAPE:
		return
	if craft_panel != null and craft_panel.visible:
		craft_panel.close()
	elif _exchange_confirmation.visible:
		_exchange_confirmation.hide()
	elif details.visible:
		details.hide()
		details_link.hide()
	else:
		close()
	get_viewport().set_input_as_handled()


func _snapshot_exchange_inventories() -> void:
	_exchange_inventory_snapshot.clear()
	for actor in gerencia.campaign.active_entity_states:
		if actor == null:
			continue
		var slots := {}
		for entry in actor.inventory_items:
			if entry != null:
				slots[entry.get_instance_id()] = entry.inventory_slot_index
		_exchange_inventory_snapshot.append({"actor": actor,
			"items": actor.inventory_items.duplicate(), "slots": slots})


func _restore_exchange_inventories() -> void:
	for record in _exchange_inventory_snapshot:
		var actor := record.get("actor") as EntityState
		if actor == null:
			continue
		actor.inventory_items.clear()
		var slots: Dictionary = record.get("slots", {})
		for entry in record.get("items", []):
			if entry is InventoryItemState:
				(entry as InventoryItemState).inventory_slot_index = int(slots.get(
					entry.get_instance_id(), -1))
				actor.inventory_items.append(entry)
	_exchange_selected.clear()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if craft_panel != null and craft_panel.visible:
			craft_panel.close()
		elif _exchange_owner != null:
			close()
		elif _exchange_confirmation.visible:
			_exchange_confirmation.hide()
		elif details.visible:
			details.hide()
			details_link.hide()
		else:
			close()
		get_viewport().set_input_as_handled()
		return
	if _window_resizing:
		if event is InputEventMouseMotion:
			var base := _base_window_size()
			var delta: Vector2 = (event as InputEventMouseMotion).position - _resize_start_mouse
			var wished := _resize_start_factor + maxf(delta.x / base.x,
				delta.y / base.y)
			var viewport_size := get_viewport_rect().size
			var fit := minf((viewport_size.x - 2.0 * VIEWPORT_MARGIN) / base.x,
				(viewport_size.y - 2.0 * VIEWPORT_MARGIN) / base.y)
			_window_scale_factor = clampf(wished, 1.0, minf(1.2, fit))
			_window_user_positioned = true
			_layout_window()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and not event.pressed:
			_window_resizing = false
			get_node("/root/GameCursor").call("release_drag", self)
		return
	if not _window_dragging:
		return
	if event is InputEventMouseMotion:
		_window_user_positioned = true
		window.position = _clamp_window_position(window.position + event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_window_dragging = false


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_window_dragging = true
		# Menus avulsos não devem ficar separados da janela durante o arrasto.
		item_menu.close()
		details.hide()
		details_link.hide()
		get_viewport().set_input_as_handled()


func _clamp_window_position(candidate: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		clampf(candidate.x, VIEWPORT_MARGIN,
			maxf(VIEWPORT_MARGIN, viewport_size.x - window.size.x - VIEWPORT_MARGIN)),
		clampf(candidate.y, VIEWPORT_MARGIN,
			maxf(VIEWPORT_MARGIN, viewport_size.y - window.size.y - VIEWPORT_MARGIN))
	)


func _on_resize_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_window_dragging = false
		_window_resizing = true
		get_node("/root/GameCursor").call("capture_drag", self, "diagonal_nwse")
		_resize_start_mouse = get_viewport().get_mouse_position()
		_resize_start_factor = _window_scale_factor
		item_menu.close()
		details.hide()
		details_link.hide()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if details.visible:
		_update_details_link()
	_refresh_elapsed += delta
	if _refresh_elapsed >= 0.2:
		_refresh_elapsed = 0.0
		refresh()
		if _exchange_owner != null:
			_update_exchange_ui()
		if _death_owner != null:
			_update_death_ui()
		if details.visible and details.entry != null and not _entry_still_owned(details.entry):
			details.hide()
			details_link.hide()


func refresh() -> void:
	for index in columns.size():
		_refresh_column(index)


func _layout_window() -> void:
	if window == null:
		return
	var viewport_size := get_viewport_rect().size
	window.size = _base_window_size() * _window_scale_factor
	var centered := (viewport_size - window.size) * 0.5
	# Em tela estreita, centralizar consumiria o espaço lateral de ambos os
	# lados. Encostamos a janela à esquerda e reservamos o lado direito para
	# o menu contextual, sem cobrir os 12 espaços dos personagens.
	if centered.x < 530.0:
		centered.x = VIEWPORT_MARGIN
	window.position = _clamp_window_position(
		window.position if _window_user_positioned else centered)
	if details != null and details.visible:
		_position_details()
	# A confirmação usa CenterContainer para nunca crescer além da tela.


func _base_window_size() -> Vector2:
	var viewport_size := get_viewport_rect().size
	var four_columns := _death_owner != null \
		and _death_owner not in gerencia.campaign.active_entity_states
	return Vector2(minf(viewport_size.x * (0.87 if four_columns else 0.56),
		1400.0 if four_columns else 1020.0),
		minf(viewport_size.y * (0.91 if _exchange_owner != null else 0.81),
			690.0 if _exchange_owner != null else 570.0))


func _build_interface() -> void:
	_death_backdrop = ColorRect.new()
	_death_backdrop.color = Color(0.0, 0.0, 0.0, 0.54)
	_death_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_death_backdrop)
	_death_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_death_backdrop.hide()
	window = PanelContainer.new()
	window.name = "GroupInventoryWindow"
	window.focus_mode = Control.FOCUS_ALL
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	window.add_theme_stylebox_override("panel", _box(Color(0.025, 0.043, 0.052, 0.96), BLUE, 2))
	add_child(window)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 9)
	window.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.name = "DragHeader"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.gui_input.connect(_on_header_gui_input)
	content.add_child(header)
	var title := _label("▣ INVENTÁRIO DO GRUPO", 18, BLUE)
	_title_label = title
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "X"
	close_button.tooltip_text = "Fechar inventário (Esc)"
	close_button.custom_minimum_size = Vector2(31, 28)
	close_button.pressed.connect(func() -> void: close())
	header.add_child(close_button)
	_close_button = close_button
	_exchange_bar = PanelContainer.new()
	_exchange_bar.name = "ExchangeBar"
	_exchange_bar.add_theme_stylebox_override("panel",
		_box(Color(0.075, 0.08, 0.095, 0.96), PINK, 1))
	content.add_child(_exchange_bar)
	var exchange_margin := MarginContainer.new()
	exchange_margin.add_theme_constant_override("margin_left", 12)
	exchange_margin.add_theme_constant_override("margin_right", 12)
	exchange_margin.add_theme_constant_override("margin_top", 9)
	exchange_margin.add_theme_constant_override("margin_bottom", 9)
	_exchange_bar.add_child(exchange_margin)
	var exchange_stack := VBoxContainer.new()
	exchange_stack.add_theme_constant_override("separation", 5)
	exchange_margin.add_child(exchange_stack)
	_exchange_message = _label("", 13, TEXT)
	_exchange_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exchange_stack.add_child(_exchange_message)
	_exchange_status = _label("", 11, BLUE)
	_exchange_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exchange_stack.add_child(_exchange_status)
	var exchange_actions := HBoxContainer.new()
	exchange_actions.add_theme_constant_override("separation", 10)
	exchange_stack.add_child(exchange_actions)
	_exchange_accept_button = Button.new()
	_exchange_accept_button.text = "ACEITAR TROCA"
	_exchange_accept_button.custom_minimum_size = Vector2(140, 34)
	_exchange_accept_button.pressed.connect(_ask_exchange_confirmation)
	exchange_actions.add_child(_exchange_accept_button)
	_exchange_decline_button = Button.new()
	_exchange_decline_button.text = "RECUSAR TROCA"
	_exchange_decline_button.custom_minimum_size = Vector2(140, 34)
	_exchange_decline_button.pressed.connect(_decline_exchange)
	exchange_actions.add_child(_exchange_decline_button)
	_exchange_cancel_button = Button.new()
	_exchange_cancel_button.text = "← VOLTAR / CANCELAR TROCA"
	_exchange_cancel_button.custom_minimum_size = Vector2(210, 34)
	_exchange_cancel_button.tooltip_text = "Desfaz o remanejamento e volta ao item pendente (Esc)"
	_exchange_cancel_button.pressed.connect(func() -> void: close())
	exchange_actions.add_child(_exchange_cancel_button)
	_exchange_bar.hide()
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content.add_child(body)
	for index in 3:
		columns.append(_create_character_column(body, index))
	_death_column = _create_character_column(body, 3)
	(_death_column["card"] as Control).hide()
	var resize_row := HBoxContainer.new()
	resize_row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(resize_row)
	var resize_handle := Button.new()
	resize_handle.name = "ResizeHandle"
	resize_handle.text = "◢"
	resize_handle.tooltip_text = "Arraste para ampliar até 20%; proporção fixa"
	resize_handle.custom_minimum_size = Vector2(26, 18)
	resize_handle.set_meta("ppp_cursor_context", "diagonal_nwse")
	resize_handle.gui_input.connect(_on_resize_handle_input)
	resize_row.add_child(resize_handle)
	details = DETAILS_SCENE.instantiate() as ItemDetailsPanel
	add_child(details)
	details.hide()
	details_link = Line2D.new()
	details_link.width = 2.0
	details_link.default_color = BLUE
	add_child(details_link)
	details_link.hide()
	details.close_requested.connect(func() -> void:
		details.hide()
		details_link.hide())
	item_menu = ITEM_MENU_SCRIPT.new() as InventoryItemMenu
	item_menu.name = "ItemMenu"
	add_child(item_menu)
	item_menu.combat_manager = combat_manager
	item_menu.craft_exploration = exploration
	item_menu.linked_details_panel = details
	item_menu.details_requested.connect(_show_item_details)
	item_menu.inventory_changed.connect(refresh)
	item_menu.chance_result_requested.connect(_show_chance_result)
	item_menu.craft_requested.connect(open_craft_for)
	_chance_result_dialog = preload("res://scripts/ui/item_chance_result_popup.gd").new()
	add_child(_chance_result_dialog)
	_exchange_confirmation = Control.new()
	_exchange_confirmation.name = "ExchangeConfirmation"
	_exchange_confirmation.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_exchange_confirmation)
	_exchange_confirmation.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.54)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_exchange_confirmation.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.name = "ConfirmationCenter"
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	_exchange_confirmation.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialog := PanelContainer.new()
	dialog.name = "Dialog"
	dialog.custom_minimum_size = Vector2(440, 175)
	dialog.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dialog.add_theme_stylebox_override("panel",
		_box(Color(0.075, 0.075, 0.085, 0.98), PINK, 2))
	center.add_child(dialog)
	var confirm_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		confirm_margin.add_theme_constant_override("margin_%s" % side, 16)
	dialog.add_child(confirm_margin)
	var confirm_stack := VBoxContainer.new()
	confirm_stack.add_theme_constant_override("separation", 12)
	confirm_margin.add_child(confirm_stack)
	_exchange_question = _label("", 16, TEXT)
	_exchange_question.add_theme_font_override("font", BOLD_FONT)
	_exchange_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_exchange_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exchange_question.size_flags_vertical = Control.SIZE_EXPAND_FILL
	confirm_stack.add_child(_exchange_question)
	var confirm_actions := HBoxContainer.new()
	confirm_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_actions.add_theme_constant_override("separation", 14)
	confirm_stack.add_child(confirm_actions)
	var yes_button := Button.new()
	yes_button.name = "YesButton"
	yes_button.text = "SIM"
	yes_button.custom_minimum_size = Vector2(105, 36)
	yes_button.pressed.connect(_confirm_exchange)
	confirm_actions.add_child(yes_button)
	var not_yet_button := Button.new()
	not_yet_button.name = "NotYetButton"
	not_yet_button.text = "AINDA NÃO"
	not_yet_button.custom_minimum_size = Vector2(130, 36)
	not_yet_button.pressed.connect(func() -> void: _exchange_confirmation.hide())
	confirm_actions.add_child(not_yet_button)
	_exchange_confirmation.hide()
	_exchange_cancel_button.hide()


func _create_character_column(parent: HBoxContainer, index: int) -> Dictionary:
	var card := Control.new()
	card.name = "Playable%d" % (index + 1)
	card.custom_minimum_size.x = 225
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var fill := ColorRect.new()
	fill.color = Color(0.08, 0.095, 0.11, 0.91)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 8.0
	fill.offset_top = 6.0
	fill.offset_right = -8.0
	fill.offset_bottom = -6.0
	var frame := Panel.new()
	frame.name = "BlockActivationFrame"
	frame.add_theme_stylebox_override("panel",
		_box(Color.TRANSPARENT, PINK, 2))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inner := MarginContainer.new()
	card.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("margin_left", 21)
	inner.add_theme_constant_override("margin_right", 21)
	inner.add_theme_constant_override("margin_top", 17)
	inner.add_theme_constant_override("margin_bottom", 17)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	inner.add_child(stack)
	var name := _label("PLAYABLE %d" % (index + 1), 14, TEXT)
	name.add_theme_font_override("font", BOLD_FONT)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(name)
	stack.add_child(_label("EQUIPADOS", 10, PINK))
	var equipment := HBoxContainer.new()
	equipment.alignment = BoxContainer.ALIGNMENT_CENTER
	equipment.add_theme_constant_override("separation", 4)
	stack.add_child(equipment)
	var equipment_views: Array[Dictionary] = []
	for slot_name in ["ARMA", "ARMADURA", "ACESSÓRIO"]:
		var view := _equipment_slot(slot_name, index, equipment_views.size())
		equipment.add_child(view["cell"])
		(view["cell"] as Button).pressed.connect(_on_equipped_clicked.bind(index,
			equipment_views.size()))
		equipment_views.append(view)
	var separator := ColorRect.new()
	separator.color = BLUE
	separator.custom_minimum_size.y = 2
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(separator)
	var inventory_row := HBoxContainer.new()
	stack.add_child(inventory_row)
	var capacity := _label("INVENTÁRIO  0 / 12", 10, BLUE)
	capacity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_row.add_child(capacity)
	var expand := Button.new()
	expand.name = "ExpandButton"
	expand.visible = false
	expand.custom_minimum_size.x = 57
	expand.add_theme_font_size_override("font_size", 10)
	expand.pressed.connect(_toggle_expansion.bind(index))
	inventory_row.add_child(expand)
	var sort_button := Button.new()
	sort_button.text = "ORGANIZAR ▾"
	sort_button.tooltip_text = "Organizar apenas os itens deste personagem"
	sort_button.add_theme_font_size_override("font_size", 10)
	stack.add_child(sort_button)
	var sort_menu := PopupMenu.new()
	card.add_child(sort_menu)
	for option in ["Por tipo", "Nome A–Z", "Aquisição: primeiros", "Aquisição: últimos"]:
		sort_menu.add_item(option)
	sort_button.pressed.connect(func() -> void:
		sort_menu.position = Vector2i(sort_button.global_position +
			Vector2(0.0, sort_button.size.y))
		sort_menu.popup())
	sort_menu.id_pressed.connect(_on_sort_requested.bind(index))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	var craft_button := Button.new()
	craft_button.name = "CraftEpicButton"
	craft_button.text = "✦ CRIAR EQUIPAMENTO ÉPICO"
	craft_button.custom_minimum_size.y = 31
	craft_button.add_theme_font_size_override("font_size", 11)
	craft_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34))
	craft_button.add_theme_stylebox_override("normal",
		_box(Color(0.18, 0.15, 0.045, 0.95), Color(1.0, 0.80, 0.20), 1))
	craft_button.pressed.connect(func() -> void:
		open_craft_for(_actor_for_slot(index)))
	stack.add_child(craft_button)
	return {"card": card, "name": name, "capacity": capacity,
		"equipment_views": equipment_views,
		"expand": expand, "grid": grid,
		"craft_button": craft_button,
		"signature": ""}


func _on_sort_requested(mode: int, owner_index: int) -> void:
	var owner := _actor_for_slot(owner_index)
	if InventoryManager.sort_inventory(owner, mode):
		item_menu.close()
		details.hide()
		details_link.hide()
		columns[owner_index]["signature"] = ""
		_refresh_column(owner_index)


func reorder_inventory_entry(owner: EntityState, entry: InventoryItemState,
		slot_index: int) -> void:
	if owner == null or owner not in gerencia.campaign.active_entity_states:
		return
	if InventoryManager.reorder_item_to_slot(owner, entry, slot_index):
		item_menu.close()
		details.hide()
		details_link.hide()
		refresh()


func can_drop_inventory_entry(source: EntityState, recipient: EntityState,
		entry: InventoryItemState) -> bool:
	if source == null or recipient == null or entry == null or entry.data == null \
			or gerencia == null or gerencia.campaign == null \
			or entry not in source.inventory_items:
		return false
	if source == recipient:
		return true
	if recipient.current_health <= 0:
		return false
	return (source in gerencia.campaign.active_entity_states or source == _death_owner) \
		and recipient in gerencia.campaign.active_entity_states \
		and entry.data.item_type != ItemData.ItemType.CURSED \
		and skill_manager != null \
		and skill_manager.inventory_manager.can_receive(recipient, entry.data)


func drop_inventory_entry(source: EntityState, recipient: EntityState,
		entry: InventoryItemState, slot_index: int) -> void:
	if not can_drop_inventory_entry(source, recipient, entry):
		return
	if source == recipient:
		reorder_inventory_entry(recipient, entry, slot_index)
		return
	if skill_manager.inventory_manager.transfer_item(source, recipient, entry,
			gerencia.campaign, source == _death_owner):
		InventoryManager.reorder_item_to_slot(recipient, entry, slot_index)
		if _exchange_owner != null:
			_exchange_selected.erase(entry)
		item_menu.close()
		details.hide()
		details_link.hide()
		refresh()
		_update_exchange_ui()


func can_drop_equipment_entry(source: EntityState, recipient: EntityState,
		entry: InventoryItemState, slot_type: ItemData.EquipmentSlot) -> bool:
	if source == null or recipient == null or entry == null \
			or gerencia == null or gerencia.campaign == null \
			or source not in gerencia.campaign.active_entity_states \
			or recipient not in gerencia.campaign.active_entity_states \
			or entry not in source.inventory_items:
		return false
	if recipient.current_health <= 0 or (source.current_health <= 0 \
			and source != _death_owner):
		return false
	if _exchange_owner != null or skill_manager == null or entry.data == null \
			or entry.data.item_type != ItemData.ItemType.EQUIPMENT \
			or entry.data.equipment_slot != slot_type \
			or not skill_manager.can_equip_item(recipient, entry.data):
		return false
	if source == recipient:
		return true
	return _equipment_manager.can_equip_playable_from_playable(source,
		recipient, entry, skill_manager, gerencia.campaign)


func drop_equipment_entry(source: EntityState, recipient: EntityState,
		entry: InventoryItemState, slot_type: ItemData.EquipmentSlot) -> void:
	if not can_drop_equipment_entry(source, recipient, entry, slot_type):
		return
	var equipped := _equipment_manager.equip(recipient, entry, skill_manager,
		gerencia.campaign) if source == recipient else \
		_equipment_manager.equip_playable_from_playable(source, recipient,
			entry, skill_manager, gerencia.campaign)
	if equipped:
		get_node("/root/UISFX").call("play", &"equip")
		item_menu.close()
		details.hide()
		details_link.hide()
		refresh()


func _equipment_slot(slot_name: String, owner_index: int,
		slot_index: int) -> Dictionary:
	var cell: GroupEquipmentSlotButton = EQUIPMENT_SLOT_BUTTON_SCRIPT.new()
	cell.owner_panel = self
	cell.equipment_slot = [ItemData.EquipmentSlot.WEAPON,
		ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY][slot_index]
	cell.set_meta("owner_index", owner_index)
	cell.custom_minimum_size = SLOT_SIZE
	cell.tooltip_text = "%s: espaço vazio" % slot_name
	cell.add_theme_stylebox_override("normal", _box(Color(0.05, 0.055, 0.07, 0.9), PINK, 1))
	cell.add_theme_stylebox_override("hover", _box(Color(0.10, 0.11, 0.14, 0.95), PINK, 1))
	cell.add_theme_stylebox_override("disabled", _box(Color(0.05, 0.055, 0.07, 0.9), PINK, 1))
	cell.disabled = false
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6.0
	icon.offset_top = 6.0
	icon.offset_right = -6.0
	icon.offset_bottom = -6.0
	# O nome completo fica no tooltip; abreviar evita cruzar as molduras após
	# a ampliação universal da fonte.
	var short_name := "ARMAD." if slot_name == "ARMADURA" else \
		("ACESS." if slot_name == "ACESSÓRIO" else slot_name)
	var label := _label(short_name, 8, Color(0.64, 0.69, 0.72))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(label)
	return {"cell": cell, "icon": icon, "label": label, "slot_name": slot_name}


func _refresh_column(index: int) -> void:
	var parts := columns[index]
	var actor := _actor_for_slot(index)
	var capacity := actor.inventory_capacity() if actor != null else BASE_SLOTS
	if capacity <= BASE_SLOTS:
		expanded_by_slot[index] = false
	var visible_slots := capacity if expanded_by_slot[index] else mini(BASE_SLOTS, capacity)
	var layout: Array[Dictionary] = []
	if actor != null:
		layout = InventoryManager.inventory_layout(actor)
	var signature := "%s|%d|%d|%s" % [actor.instance_id if actor != null else "empty",
		capacity, visible_slots, actor.visible_name() if actor != null else ""]
	if actor != null:
		if actor == _exchange_owner:
			for selected_entry in _exchange_selected:
				signature += "|exchange:%d" % selected_entry.get_instance_id()
		for entry in actor.inventory_items:
			if entry != null and entry.data != null:
				signature += "|%d:%s:%d:%d" % [entry.get_instance_id(), entry.data.id,
					entry.data.inventory_space, entry.inventory_slot_index]
				for state in entry.states:
					if state != null:
						signature += ":%s" % state.id
				signature += ":craft%d" % CraftAvailability.status_for(actor,
					entry.data, gerencia.campaign, skill_manager.inventory_manager,
					exploration)
		for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
				ItemData.EquipmentSlot.ACCESSORY]:
			for equipped_entry in actor.equipped_in_slot(slot):
				if equipped_entry != null and equipped_entry.data != null:
					signature += "|equipped:%d:%s" % [equipped_entry.get_instance_id(),
						equipped_entry.data.id]
					signature += ":craft%d" % CraftAvailability.status_for(actor,
						equipped_entry.data, gerencia.campaign,
						skill_manager.inventory_manager, exploration)
		var absorbed := _absorbed_weapon(actor)
		if absorbed != null:
			signature += "|absorbed:%s" % absorbed.id
	if parts["signature"] == signature:
		return
	parts["signature"] = signature
	var name := parts["name"] as Label
	name.text = actor.visible_name().to_upper() if actor != null and actor.data != null \
		else "PLAYABLE %d" % (index + 1)
	var equipment_views: Array = parts["equipment_views"]
	var slots := [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
		ItemData.EquipmentSlot.ACCESSORY]
	for slot_index in slots.size():
		var view: Dictionary = equipment_views[slot_index]
		var equipped_entry := actor.primary_equipped(slots[slot_index]) if actor != null else null
		var item: ItemData = equipped_entry.data if equipped_entry != null else null
		var absorbed := _absorbed_weapon(actor) if slot_index == 0 else null
		var icon := view["icon"] as TextureRect
		icon.texture = item.icon if item != null else absorbed.icon if absorbed != null else null
		icon.modulate = Color(0.40, 0.20, 0.50, 0.72) if item == null \
			and absorbed != null else Color.WHITE
		(view["label"] as Label).visible = item == null and absorbed == null
		(view["cell"] as Button).disabled = actor == null or absorbed != null
		(view["cell"] as GroupEquipmentSlotButton).owner_actor = actor
		(view["cell"] as Control).tooltip_text = item.display_name if item != null \
			else "Simbiose Elemental: %s absorvida. Slot bloqueado." % absorbed.display_name \
			if absorbed != null else "%s: espaço vazio" % view["slot_name"]
		if item != null:
			_apply_craft_border(view["cell"] as Button,
				CraftAvailability.status_for(actor, item, gerencia.campaign,
					skill_manager.inventory_manager, exploration), true)
	var capacity_label := parts["capacity"] as Label
	capacity_label.text = "INVENTÁRIO  %d / %d" % [actor.inventory_used_space() if actor != null else 0,
		capacity]
	var expand := parts["expand"] as Button
	expand.visible = capacity > BASE_SLOTS
	expand.text = "▲" if expanded_by_slot[index] else "▼ +%d" % (capacity - BASE_SLOTS)
	expand.tooltip_text = "Recolher espaços extras" if expanded_by_slot[index] \
		else "Mostrar espaços extras da mochila ou de outro bônus"
	var grid := parts["grid"] as GridContainer
	(parts["craft_button"] as Button).visible = actor != null and actor != _death_owner \
		and _exchange_owner == null and not \
		CraftAvailability.options_for(actor, skill_manager.inventory_manager,
			exploration).is_empty()
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	for slot_index in visible_slots:
		var record: Dictionary = layout[slot_index] if slot_index < layout.size() else {}
		grid.add_child(_inventory_slot(record, index, slot_index))


func _inventory_slot(record: Dictionary, owner_index: int, slot_index: int) -> Button:
	var entry := record.get("entry") as InventoryItemState
	var item: ItemData = entry.data if entry != null else null
	var first := bool(record.get("first", false))
	var cell: Button = SLOT_BUTTON_SCRIPT.new()
	cell.set("owner_panel", self)
	cell.set("owner_actor", _actor_for_slot(owner_index))
	cell.set("entry", entry if first else null)
	cell.set("slot_index", slot_index)
	cell.set("can_drag", true)
	cell.custom_minimum_size = SLOT_SIZE
	cell.tooltip_text = "%s\n%s" % [item.display_name, item.description] \
		if item != null else "Espaço vazio"
	cell.focus_mode = Control.FOCUS_ALL if item != null and first else Control.FOCUS_NONE
	if item != null and first:
		cell.pressed.connect(_on_carried_clicked.bind(owner_index, entry, cell))
		cell.gui_input.connect(_on_inventory_cell_input.bind(owner_index, entry, cell))
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		cell.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	var frame := TextureRect.new()
	frame.texture = SLOT_FRAME
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 1.0 if item != null and first else 0.58
	if first and entry in _exchange_selected:
		frame.modulate = Color(1.0, 0.83, 0.38, 1.0)
		cell.add_theme_stylebox_override("normal",
			_box(Color(0.40, 0.23, 0.06, 0.35), Color(1.0, 0.82, 0.28), 2))
	cell.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := TextureRect.new()
	icon.texture = item.icon if item != null and first else null
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 7.0
	icon.offset_top = 7.0
	icon.offset_right = -7.0
	icon.offset_bottom = -7.0
	if first and _is_rotten_consumable(entry):
		var gray := ShaderMaterial.new()
		gray.shader = INACTIVE_SHADER
		icon.material = gray
		var red_x := _label("X", 35, Color(1.0, 0.13, 0.17))
		red_x.add_theme_font_override("font", BOLD_FONT)
		red_x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		red_x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		red_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(red_x)
		red_x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if first and item != null and _exchange_owner == null and _death_owner == null:
		_apply_craft_border(cell, CraftAvailability.status_for(
			_actor_for_slot(owner_index), item, gerencia.campaign,
			skill_manager.inventory_manager, exploration))
	return cell


func _apply_craft_border(cell: Button, status: CraftAvailability.Status,
		equipped: bool = false) -> void:
	var previous := cell.get_node_or_null("CraftBorder")
	if previous != null:
		cell.remove_child(previous)
		previous.queue_free()
	if status == CraftAvailability.Status.NONE:
		cell.set_meta("craft_status", CraftAvailability.Status.NONE)
		return
	cell.set_meta("craft_status", status)
	if not cell.has_meta("craft_hint_connected"):
		cell.set_meta("craft_hint_connected", true)
		cell.mouse_entered.connect(func() -> void:
			if craft_hint != null and not craft_panel.visible \
					and int(cell.get_meta("craft_status", 0)) != CraftAvailability.Status.NONE:
				craft_hint.show_near(get_viewport().get_mouse_position()))
		cell.mouse_exited.connect(func() -> void:
			if craft_hint != null:
				craft_hint.hide())
	var border := Panel.new()
	border.name = "CraftBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color(1.0, 0.80, 0.12) \
		if status == CraftAvailability.Status.ACTOR_READY else Color.WHITE
	var style := _box(Color.TRANSPARENT, color, 3)
	if equipped:
		style.shadow_color = Color(color.r, color.g, color.b, 0.34)
		style.shadow_size = 5
	border.add_theme_stylebox_override("panel", style)
	cell.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cell.tooltip_text = ""


func _on_carried_clicked(owner_index: int, selected: InventoryItemState,
		cell: Button) -> void:
	var owner := _actor_for_slot(owner_index)
	if owner == null or selected not in owner.inventory_items:
		return
	if owner == _death_owner:
		return # Espólio só pode ser movido por arrasto; descarte exige confirmação.
	if _exchange_owner != null:
		if owner != _exchange_owner:
			_exchange_status.text = "Selecione itens no inventário de %s." % \
				_exchange_owner.data.display_name
			return
		if selected.data == null or not selected.data.can_be_discarded \
				or selected.data.item_type == ItemData.ItemType.CURSED:
			_exchange_status.text = "Este item não pode ser descartado."
			return
		if selected in _exchange_selected:
			_exchange_selected.erase(selected)
		else:
			_exchange_selected.append(selected)
		_update_exchange_ui()
		columns[owner_index]["signature"] = ""
		_refresh_column(owner_index)
		return
	if CraftAvailability.status_for(owner, selected.data, gerencia.campaign,
			skill_manager.inventory_manager, exploration) != CraftAvailability.Status.NONE:
		open_craft_for(owner, selected.data)
		return
	details.hide()
	details_link.hide()
	_open_item_menu(owner, selected, cell)


func _on_inventory_cell_input(event: InputEvent, owner_index: int,
		selected: InventoryItemState, cell: Button) -> void:
	if _exchange_owner != null:
		return
	if not event is InputEventMouseButton \
			or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	var owner := _actor_for_slot(owner_index)
	if owner != null and selected in owner.inventory_items:
		_open_item_menu(owner, selected, cell)
		get_viewport().set_input_as_handled()


func _open_item_menu(owner: EntityState, selected: InventoryItemState,
		cell: Button) -> void:
	item_menu.avoid_rect = window.get_global_rect()
	item_menu.open_for(owner, selected, false, cell.get_global_rect(),
		gerencia.campaign, skill_manager)


func _update_exchange_ui() -> void:
	if _exchange_owner == null or _exchange_item == null or skill_manager == null:
		return
	for entry in _exchange_selected.duplicate():
		if entry not in _exchange_owner.inventory_items:
			_exchange_selected.erase(entry)
	var needed := maxi(0, _exchange_owner.inventory_used_space() \
		+ maxi(1, _exchange_item.inventory_space) - _exchange_owner.inventory_capacity())
	var freed := 0
	for entry in _exchange_selected:
		freed += maxi(1, entry.data.inventory_space)
	_exchange_message.text = ("Há espaço para %s após remanejar os itens. Confirme para guardar." \
		% _exchange_item.display_name) if needed == 0 else \
		("Arraste itens entre personagens para liberar espaço ou selecione o que descartar para guardar %s." \
		% _exchange_item.display_name)
	_exchange_status.text = "%s • espaço a liberar: %d • selecionado: %d" % [
		_exchange_owner.data.display_name, needed, freed]
	_exchange_accept_button.text = "GUARDAR ITEM" if _exchange_selected.is_empty() \
		else "ACEITAR TROCA"
	_exchange_accept_button.disabled = not skill_manager.inventory_manager.can_exchange_items(
		_exchange_owner, _exchange_selected, _exchange_item)
	_exchange_decline_button.visible = _exchange_allow_decline
	_exchange_decline_button.tooltip_text = "Esta recompensa é obrigatória." \
		if not _exchange_allow_decline else "Recusar o item que seria recebido."


func _update_death_ui() -> void:
	if _death_owner == null:
		return
	var count := _death_owner.inventory_items.size()
	var replacement := gerencia.campaign.get_playable_slot(_death_owner.playable_slot_id)
	var introduction := "%s morreu. %s agora ocupa a vaga jogável. " % [
		_death_owner.data.display_name, replacement.visible_name()] \
		if replacement != null and replacement != _death_owner else \
		"%s morreu. " % _death_owner.data.display_name
	_exchange_message.text = introduction + \
		"Redistribua os itens restantes entre os jogáveis. O que ficar no espólio só será descartado após confirmação."
	_exchange_status.text = "Itens restantes no espólio: %d" % count
	_exchange_accept_button.disabled = false
	_exchange_decline_button.visible = true


func _ask_exchange_confirmation() -> void:
	if _death_owner != null:
		if _death_owner.inventory_items.is_empty():
			_confirm_exchange()
			return
		var names: Array[String] = []
		for entry in _death_owner.inventory_items:
			if entry != null and entry.data != null:
				names.append(entry.data.display_name)
		_exchange_question.text = "Descartar definitivamente %s?" % (
			", ".join(names) if not names.is_empty() else "o espólio vazio")
		_exchange_confirmation.show()
		_layout_window()
		return
	if _exchange_accept_button.disabled:
		return
	var outgoing_names: Array[String] = []
	for entry in _exchange_selected:
		outgoing_names.append(entry.data.display_name)
	_exchange_question.text = "Guardar %s com %s? Os itens remanejados ficarão com seus novos donos." % [
		_exchange_item.display_name, _exchange_owner.visible_name()] \
		if outgoing_names.is_empty() else \
		"Descartar %s e guardar %s com %s? Os itens remanejados ficarão com seus novos donos." % [
			", ".join(outgoing_names), _exchange_item.display_name,
			_exchange_owner.visible_name()]
	_exchange_confirmation.show()
	_layout_window()


func _confirm_exchange() -> void:
	if _death_owner != null:
		if gerencia.campaign.confirm_dead_inventory_discard(_death_owner):
			close(true)
			if _death_queue.is_empty():
				death_cleanup_completed.emit()
		return
	if _exchange_owner == null or _exchange_item == null \
			or not _exchange_confirm_action.is_valid():
		return
	if not skill_manager.inventory_manager.can_exchange_items(
		_exchange_owner, _exchange_selected, _exchange_item):
		_exchange_confirmation.hide()
		_update_exchange_ui()
		return
	var outgoing: Array[InventoryItemState] = []
	outgoing.append_array(_exchange_selected)
	if bool(_exchange_confirm_action.call(outgoing)):
		close(true)
	else:
		_exchange_confirmation.hide()
		_exchange_status.text = "A troca não pôde ser concluída. Nenhum item foi removido."


func _decline_exchange() -> void:
	if _death_owner != null:
		_exchange_confirmation.hide()
		return
	if not _exchange_allow_decline or not _exchange_decline_action.is_valid():
		return
	if bool(_exchange_decline_action.call()):
		close()


func _on_equipped_clicked(owner_index: int, slot_index: int) -> void:
	if _exchange_owner != null:
		return
	var owner := _actor_for_slot(owner_index)
	if owner == null:
		return
	var slots := [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
		ItemData.EquipmentSlot.ACCESSORY]
	var equipped_items := owner.equipped_in_slot(slots[slot_index])
	if equipped_items.is_empty():
		return
	details.hide()
	details_link.hide()
	item_menu.avoid_rect = window.get_global_rect()
	var views: Array = columns[owner_index]["equipment_views"]
	var anchor := (views[slot_index]["cell"] as Button).get_global_rect()
	if equipped_items.size() > 1:
		item_menu.open_equipped_collection(owner, equipped_items, anchor,
			gerencia.campaign, skill_manager)
	else:
		item_menu.open_for(owner, equipped_items[0], true, anchor,
			gerencia.campaign, skill_manager)


func _toggle_expansion(index: int) -> void:
	var actor := _actor_for_slot(index)
	if actor == null or actor.inventory_capacity() <= BASE_SLOTS:
		return
	expanded_by_slot[index] = not expanded_by_slot[index]
	columns[index]["signature"] = ""
	_refresh_column(index)


func _actor_for_slot(index: int) -> EntityState:
	if gerencia == null or gerencia.campaign == null:
		return null
	if index == 3:
		return _death_owner
	if index < 0 or index >= CampaignState.PLAYABLE_SLOTS.size():
		return null
	var slot_id: StringName = CampaignState.PLAYABLE_SLOTS[index]
	for actor in gerencia.campaign.active_entity_states:
		if actor != null and actor.playable_slot_id == slot_id:
			return actor
	return null


func _absorbed_weapon(actor: EntityState) -> ItemData:
	if actor == null:
		return null
	for grant in actor.skill_grants:
		if grant != null and grant.skill != null \
				and grant.skill.id == &"permanent_passive_058" \
				and grant.bound_source is ItemData:
			return grant.bound_source as ItemData
	return null


func _show_chance_result(message: String) -> void:
	if _chance_result_dialog == null or message.is_empty():
		return
	_chance_result_dialog.call("show_message", message)


func _show_item_details(entry: InventoryItemState) -> void:
	if details.visible and details.entry == entry:
		details.hide()
		details_link.hide()
		return
	details.bind_entry(entry)
	details.modulate.a = 0.0
	details.show()
	details_link.show()
	get_tree().create_timer(0.035).timeout.connect(
		_position_details_after_layout.bind(entry), CONNECT_ONE_SHOT)


func _position_details_after_layout(entry: InventoryItemState) -> void:
	if not details.visible or details.entry != entry:
		return
	_position_details()
	details.modulate.a = 1.0


func _position_details() -> void:
	if details.user_positioned:
		_update_details_link()
		return
	var screen := get_viewport_rect().size
	var menu_rect := item_menu.menu.get_global_rect() if item_menu.visible else window.get_global_rect()
	details.fit_height(minf(470.0, screen.y - 75.0))
	var right_x := menu_rect.end.x + 10.0
	if right_x + details.size.x <= screen.x - 8.0:
		details.position = Vector2(right_x,
			clampf(menu_rect.position.y, 56.0, maxf(56.0, screen.y - details.size.y - 8.0)))
	else:
		var x := clampf(menu_rect.position.x, 8.0, maxf(8.0, screen.x - details.size.x - 8.0))
		var below := menu_rect.end.y + 10.0
		var above := menu_rect.position.y - details.size.y - 10.0
		var y := below if below + details.size.y <= screen.y - 8.0 else above
		details.position = Vector2(x, clampf(y, 56.0,
			maxf(56.0, screen.y - details.size.y - 8.0)))
	_update_details_link()


func _update_details_link() -> void:
	if not details.visible or not item_menu.visible:
		details_link.hide()
		return
	details_link.show()
	var source := item_menu.menu.get_global_rect()
	var target := details.get_global_rect()
	var from := Vector2(source.end.x, source.get_center().y)
	var to := Vector2(target.position.x, target.get_center().y)
	if target.position.y >= source.end.y:
		from = Vector2(source.get_center().x, source.end.y)
		to = Vector2(target.get_center().x, target.position.y)
	elif target.end.y <= source.position.y:
		from = Vector2(source.get_center().x, source.position.y)
		to = Vector2(target.get_center().x, target.end.y)
	if is_equal_approx(from.x, to.x):
		details_link.points = PackedVector2Array([from, to])
	else:
		var middle := (from + to) * 0.5
		details_link.points = PackedVector2Array([from,
			Vector2(middle.x, from.y), Vector2(middle.x, to.y), to])


func _entry_still_owned(entry: InventoryItemState) -> bool:
	for index in columns.size():
		var actor := _actor_for_slot(index)
		if actor != null and (entry in actor.inventory_items
				or entry in actor.equipped_weapons or entry in actor.equipped_armors
				or entry in actor.equipped_accessories):
			return true
	return false


func _is_rotten_consumable(entry: InventoryItemState) -> bool:
	if entry == null or entry.data == null \
			or entry.data.item_type != ItemData.ItemType.CONSUMABLE:
		return false
	for state in entry.states:
		if state != null and state.id == &"apodrecido":
			return true
	return false


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style
