class_name CharacterInventoryPanel
extends PanelContainer

## Apenas mostra o inventário de UMA instância da campanha. A capacidade
## vem do EntityState: 12 iniciais, mais os bônus realmente aplicados.
## A seta revela os espaços extras sem inventar um limite para mochilas futuras.

signal close_requested
signal expansion_changed
signal item_selected(entry: InventoryItemState)
signal inventory_reordered
signal craft_requested(actor: EntityState, item: ItemData)
signal craft_hover_requested(point: Vector2)
signal craft_hover_ended

const BASE_VISIBLE_SLOTS := 12
const SLOT_WIDTH := 80.0
const SLOT_HEIGHT := 84.0
const GRID_GAP := 4.0
const GRID_COLUMNS := 3
const SLOT_FRAME := preload("res://sprites/ui/uielementx_00002.png")
const INACTIVE_SHADER := preload("res://shaders/ui_inactive_grayscale.gdshader")
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const SLOT_BUTTON_SCRIPT := preload("res://scripts/ui/inventory_slot_button.gd")

@onready var title_label: Label = $Margin/Content/Header/Title
@onready var expand_button: Button = $Margin/Content/Header/ExpandButton
@onready var close_button: Button = $Margin/Content/Header/CloseButton
@onready var capacity_label: Label = $Margin/Content/Capacity
@onready var scroll: ScrollContainer = $Margin/Content/Scroll
@onready var grid: GridContainer = $Margin/Content/Scroll/Grid

var actor: EntityState
var expanded := false
var selected_anchor := Rect2()
var _last_signature := ""
var equip_filter_slot := -1
var equip_filter_skills: SkillManager
var craft_campaign: CampaignState
var craft_inventory: InventoryManager
var craft_exploration: ExplorationManager
var _craft_button: Button
var _sort_button: Button
var _sort_menu: PopupMenu
var _resize_handle: Button
var _resizing := false
var _resize_start_mouse := Vector2.ZERO
var _resize_start_scale := 1.0


func _ready() -> void:
	expand_button.pressed.connect(_toggle_expansion)
	close_button.pressed.connect(func() -> void: close_requested.emit())
	var content := $Margin/Content as VBoxContainer
	_sort_button = Button.new()
	_sort_button.text = "ORGANIZAR ▾"
	_sort_button.tooltip_text = "Organizar os itens deste personagem"
	_sort_button.add_theme_font_size_override("font_size", 10)
	content.add_child(_sort_button)
	content.move_child(_sort_button, capacity_label.get_index() + 1)
	_craft_button = Button.new()
	_craft_button.name = "CraftEpicButton"
	_craft_button.text = "✦ CRIAR EQUIPAMENTO ÉPICO"
	_craft_button.custom_minimum_size.y = 31
	_craft_button.add_theme_font_size_override("font_size", 11)
	_craft_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.34))
	var craft_style := StyleBoxFlat.new()
	craft_style.bg_color = Color(0.18, 0.15, 0.045, 0.95)
	craft_style.border_color = Color(1.0, 0.80, 0.20)
	craft_style.set_border_width_all(1)
	craft_style.set_corner_radius_all(4)
	_craft_button.add_theme_stylebox_override("normal", craft_style)
	_craft_button.pressed.connect(func() -> void:
		craft_requested.emit(actor, null))
	content.add_child(_craft_button)
	_sort_menu = PopupMenu.new()
	add_child(_sort_menu)
	for name in ["Por tipo", "Nome A–Z", "Aquisição: primeiros", "Aquisição: últimos"]:
		_sort_menu.add_item(name)
	_sort_button.pressed.connect(func() -> void:
		_sort_menu.position = Vector2i(_sort_button.global_position +
			Vector2(0.0, _sort_button.size.y))
		_sort_menu.popup())
	_sort_menu.id_pressed.connect(_on_sort_requested)
	var resize_row := HBoxContainer.new()
	resize_row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(resize_row)
	_resize_handle = Button.new()
	_resize_handle.text = "◢"
	_resize_handle.tooltip_text = "Arraste para ampliar até 20%; proporção fixa"
	_resize_handle.custom_minimum_size = Vector2(24, 18)
	_resize_handle.gui_input.connect(_on_resize_handle_input)
	resize_row.add_child(_resize_handle)


func _input(event: InputEvent) -> void:
	if not _resizing:
		return
	if event is InputEventMouseMotion:
		var delta: Vector2 = (event as InputEventMouseMotion).position - _resize_start_mouse
		var next_scale := clampf(_resize_start_scale + maxf(
			delta.x / maxf(1.0, size.x), delta.y / maxf(1.0, size.y)), 1.0, 1.2)
		scale = Vector2.ONE * next_scale
		expansion_changed.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		_resizing = false


func _on_resize_handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_resizing = true
		_resize_start_mouse = get_viewport().get_mouse_position()
		_resize_start_scale = scale.x
		get_viewport().set_input_as_handled()


func _on_sort_requested(mode: int) -> void:
	if InventoryManager.sort_inventory(actor, mode):
		_last_signature = ""
		refresh()
		inventory_reordered.emit()


func reorder_inventory_entry(owner: EntityState, entry: InventoryItemState,
		slot_index: int) -> void:
	if owner != actor or equip_filter_slot >= 0:
		return
	if InventoryManager.reorder_item_to_slot(owner, entry, slot_index):
		_last_signature = ""
		refresh()
		inventory_reordered.emit()


func bind_state(value: EntityState) -> void:
	actor = value
	expanded = false
	equip_filter_slot = -1
	equip_filter_skills = null
	_last_signature = ""
	refresh()


func set_equip_filter(slot_type: int, skills: SkillManager) -> void:
	equip_filter_slot = slot_type
	equip_filter_skills = skills
	_last_signature = ""
	refresh()


func is_equip_candidate(entry: InventoryItemState) -> bool:
	return actor != null and entry != null and entry.data != null \
		and entry in actor.inventory_items \
		and entry.data.item_type == ItemData.ItemType.EQUIPMENT \
		and entry.data.equipment_slot == equip_filter_slot \
		and (equip_filter_skills == null \
			or equip_filter_skills.can_equip_item(actor, entry.data))


func refresh() -> void:
	if actor == null:
		return
	var capacity := actor.inventory_capacity()
	if capacity <= BASE_VISIBLE_SLOTS:
		expanded = false
	var visible_slots := capacity if expanded else mini(BASE_VISIBLE_SLOTS, capacity)
	var layout := InventoryManager.inventory_layout(actor)
	var signature := "%d|%d|%d|%d|%s" % [capacity, visible_slots,
		actor.inventory_used_space(), equip_filter_slot, actor.visible_name()]
	for entry in actor.inventory_items:
		if entry != null and entry.data != null:
			signature += "|%d:%s:%d" % [entry.get_instance_id(), entry.data.id,
				entry.inventory_slot_index]
			for state in entry.states:
				if state != null:
					signature += ":%s" % state.id
			if craft_campaign != null and craft_inventory != null:
				signature += ":craft%d" % CraftAvailability.status_for(actor,
					entry.data, craft_campaign, craft_inventory, craft_exploration)
	if signature == _last_signature:
		return
	_last_signature = signature
	title_label.text = "INVENTÁRIO · %s" % actor.visible_name().to_upper()
	capacity_label.text = "ESPAÇOS: %d / %d" % [actor.inventory_used_space(), capacity]
	expand_button.visible = capacity > BASE_VISIBLE_SLOTS
	expand_button.text = "▲ RECOLHER" if expanded else "▼ +%d" % (capacity - BASE_VISIBLE_SLOTS)
	expand_button.tooltip_text = "Recolher espaços extras" if expanded \
		else "Mostrar espaços extras da mochila ou de outros bônus"
	_rebuild_cells(visible_slots, layout)
	_craft_button.visible = equip_filter_slot < 0 and craft_inventory != null \
		and not CraftAvailability.options_for(actor, craft_inventory,
			craft_exploration).is_empty()
	var rows := ceili(float(visible_slots) / float(GRID_COLUMNS))
	# Quatro linhas ocupam 348 px: 340 cortava a última linha e criava
	# uma barra de rolagem apenas para mostrar seus 8 px finais.
	scroll.custom_minimum_size.y = minf(rows * SLOT_HEIGHT + maxi(0, rows - 1) * GRID_GAP, 348.0)
	reset_size()


func _toggle_expansion() -> void:
	if actor == null or actor.inventory_capacity() <= BASE_VISIBLE_SLOTS:
		return
	expanded = not expanded
	_last_signature = ""
	refresh()
	# O HUD reposiciona a caixa após a mudança de altura.
	expansion_changed.emit()


func _rebuild_cells(visible_slots: int, layout: Array[Dictionary]) -> void:
	for old_cell in grid.get_children():
		grid.remove_child(old_cell)
		old_cell.queue_free()
	for index in visible_slots:
		var record: Dictionary = layout[index] if index < layout.size() else {}
		grid.add_child(_create_cell(record, index))


func _create_cell(record: Dictionary, index: int) -> Control:
	var entry := record.get("entry") as InventoryItemState
	var item: ItemData = entry.data if entry != null else null
	var first := bool(record.get("first", false))
	var candidate := first and is_equip_candidate(entry)
	var cell: Button = SLOT_BUTTON_SCRIPT.new()
	cell.set("owner_panel", self)
	cell.set("owner_actor", actor)
	cell.set("entry", entry if first else null)
	cell.set("slot_index", index)
	cell.set("can_drag", equip_filter_slot < 0)
	cell.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
	cell.tooltip_text = "%s\n%s" % [item.display_name, item.description] if item != null else "Espaço vazio"
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if item != null else Control.CURSOR_ARROW
	cell.focus_mode = Control.FOCUS_ALL if item != null else Control.FOCUS_NONE
	cell.disabled = equip_filter_slot >= 0 and not candidate
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		cell.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	if candidate:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0.25, 0.07, 0.18, 0.28)
		glow.border_color = Color(1.0, 0.24, 0.65, 0.95)
		glow.set_border_width_all(2)
		glow.shadow_color = Color(1.0, 0.16, 0.55, 0.5)
		glow.shadow_size = 5
		cell.add_theme_stylebox_override("normal", glow)
		cell.add_theme_stylebox_override("hover", glow)
	if item != null:
		cell.pressed.connect(func() -> void:
			selected_anchor = cell.get_global_rect()
			if equip_filter_slot < 0 and craft_campaign != null \
					and craft_inventory != null and CraftAvailability.status_for(
						actor, item, craft_campaign, craft_inventory,
						craft_exploration) != CraftAvailability.Status.NONE:
				craft_requested.emit(actor, item)
			else:
				item_selected.emit(entry))
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.texture = SLOT_FRAME
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.modulate.a = 1.0 if item != null and first else 0.58
	cell.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var icon := TextureRect.new()
	icon.name = "Icon"
	cell.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12.0
	icon.offset_top = 12.0
	icon.offset_right = -12.0
	icon.offset_bottom = -12.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = item.icon if item != null and first else null
	if first and _is_rotten_consumable(entry):
		var gray := ShaderMaterial.new()
		gray.shader = INACTIVE_SHADER
		icon.material = gray
		var red_x := Label.new()
		red_x.name = "RottenX"
		red_x.mouse_filter = Control.MOUSE_FILTER_IGNORE
		red_x.add_theme_font_override("font", BOLD_FONT)
		red_x.add_theme_font_size_override("font_size", 43)
		red_x.add_theme_color_override("font_color", Color(1.0, 0.13, 0.17))
		red_x.add_theme_color_override("font_outline_color", Color(0.08, 0.01, 0.02))
		red_x.add_theme_constant_override("outline_size", 2)
		red_x.text = "X"
		red_x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		red_x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(red_x)
		red_x.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if first and item != null and craft_campaign != null and craft_inventory != null \
			and equip_filter_slot < 0:
		var craft_status := CraftAvailability.status_for(actor, item,
			craft_campaign, craft_inventory, craft_exploration)
		if craft_status != CraftAvailability.Status.NONE:
			var border := Panel.new()
			border.name = "CraftBorder"
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style := StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color(1.0, 0.80, 0.12) \
				if craft_status == CraftAvailability.Status.ACTOR_READY else Color.WHITE
			style.set_border_width_all(3)
			style.set_corner_radius_all(3)
			border.add_theme_stylebox_override("panel", style)
			cell.add_child(border)
			border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			cell.tooltip_text = ""
			cell.mouse_entered.connect(func() -> void:
				craft_hover_requested.emit(get_viewport().get_mouse_position()))
			cell.mouse_exited.connect(func() -> void:
				craft_hover_ended.emit())
	return cell


func _is_rotten_consumable(entry: InventoryItemState) -> bool:
	if entry == null or entry.data == null \
			or entry.data.item_type != ItemData.ItemType.CONSUMABLE:
		return false
	for state in entry.states:
		if state != null and state.id == &"apodrecido":
			return true
	return false
