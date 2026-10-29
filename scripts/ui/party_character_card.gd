class_name PartyCharacterCard
extends PanelContainer

signal action_toggle_requested(card: PartyCharacterCard)
signal inspect_requested(card: PartyCharacterCard)
signal sheet_requested(card: PartyCharacterCard)
signal stat_hover_requested(actor: EntityState, stat_key: String, anchor: Rect2)
signal stat_hover_ended
signal equipped_item_selected(card: PartyCharacterCard, entry: InventoryItemState,
	anchor: Rect2)
signal equipment_slot_selected(card: PartyCharacterCard, slot_type: int, anchor: Rect2)
signal craft_hover_requested(card: PartyCharacterCard, entry: InventoryItemState,
	anchor: Rect2)
signal craft_hover_ended
signal debuff_inspection_requested(instance: DebuffInstanceState, anchor: Rect2, pinned: bool)
signal debuff_hover_ended

## Um quadro da barra esquerda. Recebe um EntityState, nunca altera o
## EntityData nem supõe qual personagem foi escolhido para esta vaga.

const EMPTY_BORDER := Color(0.996078, 0.168627, 0.592157, 0.9)
const ACTIVE_BORDER := Color(0.27, 0.82, 0.79, 1.0)
const INACTIVE_BORDER := Color(0.48, 0.51, 0.54, 1.0)
const INACTIVE_SHADER := preload("res://shaders/ui_inactive_grayscale.gdshader")
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const DEBUFF_BORDER := Color(0.82, 0.32, 0.37, 1.0)
const DEBUFF_FILL := Color(0.48, 0.12, 0.18, 0.9)

@export_range(1, 3) var slot_number: int = 1

@onready var portrait: TextureRect = $Margin/Content/TopRow/PortraitFrame/Portrait
@onready var name_label: Label = $Margin/Content/NameRow/Name
@onready var action_button: Button = $Margin/Content/NameRow/ActionButton
@onready var info_button: Button = $Margin/Content/NameRow/InfoButton
@onready var health_label: Label = $Margin/Content/TopRow/Stats/Health
@onready var attack_label: Label = $Margin/Content/TopRow/Stats/Attack
@onready var stamina_label: Label = $Margin/Content/TopRow/Stats/Stamina
@onready var mastery_label: Label = $Margin/Content/Mastery
@onready var weapon_icon: TextureRect = $Margin/Content/Equipment/Weapon/SlotContent/Icon
@onready var armor_icon: TextureRect = $Margin/Content/Equipment/Armor/SlotContent/Icon
@onready var accessory_icon: TextureRect = $Margin/Content/Equipment/Accessory/SlotContent/Icon
@onready var debuff_row: HBoxContainer = $Margin/Content/Debuffs
@onready var content_root: Control = $Margin/Content

var state: EntityState
var _empty_style: StyleBoxFlat
var _active_style: StyleBoxFlat
var _inactive_style: StyleBoxFlat
var _dead_style: StyleBoxFlat
var _inactive_material: ShaderMaterial
var _current_turn := false
var _keyboard_highlighted := false
var _debuff_signature := ""
var _is_dead_slot := false


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	info_button.pressed.connect(func() -> void: sheet_requested.emit(self))
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_empty_style = (get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_active_style = _empty_style.duplicate()
	_active_style.border_color = ACTIVE_BORDER
	_active_style.bg_color = Color(0.065, 0.09, 0.105, 0.96)
	_inactive_style = _empty_style.duplicate()
	_inactive_style.border_color = INACTIVE_BORDER
	_inactive_style.bg_color = Color(0.06, 0.065, 0.07, 0.94)
	_dead_style = _empty_style.duplicate()
	_dead_style.border_color = Color(0.12, 0.13, 0.14, 0.95)
	_dead_style.bg_color = Color(0.008, 0.009, 0.012, 0.98)
	_bind_palette()
	_inactive_material = ShaderMaterial.new()
	_inactive_material.shader = INACTIVE_SHADER
	var disabled_button := StyleBoxFlat.new()
	disabled_button.bg_color = Color(0.18, 0.19, 0.2, 0.9)
	disabled_button.border_color = INACTIVE_BORDER
	disabled_button.set_border_width_all(1)
	disabled_button.set_corner_radius_all(3)
	action_button.add_theme_stylebox_override("disabled", disabled_button)
	action_button.add_theme_color_override("font_disabled_color", Color(0.68, 0.7, 0.72))
	_make_decoration_click_through(self)
	for pair in [[$Margin/Content/Equipment/Weapon, ItemData.EquipmentSlot.WEAPON],
			[$Margin/Content/Equipment/Armor, ItemData.EquipmentSlot.ARMOR],
			[$Margin/Content/Equipment/Accessory, ItemData.EquipmentSlot.ACCESSORY]]:
		var slot := pair[0] as Control
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_equipment_slot_input.bind(slot, int(pair[1])))
		slot.mouse_entered.connect(_on_equipment_slot_hover.bind(slot, int(pair[1])))
		slot.mouse_exited.connect(func() -> void: craft_hover_ended.emit())
	for pair in [[health_label, "max_hp"], [attack_label, "attack"],
			[stamina_label, "stamina"]]:
		var label := pair[0] as Label
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.mouse_entered.connect(_on_stat_entered.bind(pair[1], label))
		label.mouse_exited.connect(func() -> void: stat_hover_ended.emit())
	_show_empty_slot()


## O quadro abre o balão de consulta. Só a seta abre ações; o ⓘ vai direto
## à ficha. Assim consultar um personagem inativo nunca dispara uma ação.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and state != null:
		inspect_requested.emit(self)
		accept_event()


func _make_decoration_click_through(parent: Node) -> void:
	for child in parent.get_children():
		if child is Control and child != action_button and child != info_button:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_decoration_click_through(child)


func _on_equipment_slot_input(event: InputEvent, slot_control: Control,
		slot_type: int) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or state == null:
		return
	var selected := state.primary_equipped(slot_type)
	if selected != null:
		equipped_item_selected.emit(self, selected, slot_control.get_global_rect())
	elif slot_type == ItemData.EquipmentSlot.WEAPON and _absorbed_weapon() != null:
		# A arma absorvida é inseparável: não oferece a troca do slot.
		pass
	else:
		equipment_slot_selected.emit(self, slot_type, slot_control.get_global_rect())
	slot_control.accept_event()


func _on_equipment_slot_hover(slot_control: Control, slot_type: int) -> void:
	if state == null:
		return
	var entry := state.primary_equipped(slot_type)
	if entry != null:
		craft_hover_requested.emit(self, entry, slot_control.get_global_rect())


func set_craft_status(slot_type: int, status: int) -> void:
	var path := "Margin/Content/Equipment/"
	match slot_type:
		ItemData.EquipmentSlot.WEAPON: path += "Weapon"
		ItemData.EquipmentSlot.ARMOR: path += "Armor"
		ItemData.EquipmentSlot.ACCESSORY: path += "Accessory"
		_: return
	var slot := get_node_or_null(path) as Control
	if slot == null or int(slot.get_meta("craft_status", -1)) == status:
		return
	slot.set_meta("craft_status", status)
	var previous := slot.get_node_or_null("CraftBorder")
	if previous != null:
		slot.remove_child(previous)
		previous.queue_free()
	if status == 0:
		return
	var border := Panel.new()
	border.name = "CraftBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(1.0, 0.80, 0.12) if status == 2 else Color.WHITE
	style.set_border_width_all(3)
	style.shadow_color = Color(style.border_color.r, style.border_color.g,
		style.border_color.b, 0.35)
	style.shadow_size = 4
	border.add_theme_stylebox_override("panel", style)
	slot.add_child(border)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func bind_state(actor: EntityState) -> void:
	if state != null and state.health_changed.is_connected(_on_health_changed):
		state.health_changed.disconnect(_on_health_changed)
	if state != null and state.equipment_changed.is_connected(_on_equipment_changed):
		state.equipment_changed.disconnect(_on_equipment_changed)
	if state != null and state.appearance_changed.is_connected(_on_appearance_changed):
		state.appearance_changed.disconnect(_on_appearance_changed)
	_is_dead_slot = actor != null and actor.current_health <= 0
	state = actor if not _is_dead_slot else null
	content_root.visible = not _is_dead_slot
	if state == null:
		_show_empty_slot()
		return
	state.health_changed.connect(_on_health_changed)
	state.equipment_changed.connect(_on_equipment_changed)
	state.appearance_changed.connect(_on_appearance_changed)
	_on_appearance_changed()
	refresh()


func _on_appearance_changed() -> void:
	if state == null:
		return
	name_label.text = state.visible_name() if state.data != null else "PERSONAGEM"
	name_label.add_theme_font_size_override("font_size",
		11 if name_label.text.length() > 18 else 13)
	portrait.texture = _first_idle_frame(state.visual_data())


func is_available() -> bool:
	return state != null and state.current_health > 0 \
		and state.turn_state != EntityState.TurnState.INACTIVE


func _on_action_button_pressed() -> void:
	if state != null and state.current_health > 0:
		action_toggle_requested.emit(self)


func set_current_turn(is_current: bool) -> void:
	_current_turn = is_current
	var inactive := not is_available()
	var panel_style := _dead_style if _is_dead_slot else \
		(_inactive_style if inactive else \
		(_active_style if is_current else _empty_style))
	if _keyboard_highlighted:
		panel_style = panel_style.duplicate() as StyleBoxFlat
		panel_style.border_color = Color(0.38, 1.0, 0.94)
		panel_style.set_border_width_all(3)
		panel_style.shadow_color = Color(0.19, 0.96, 0.87, 0.45)
		panel_style.shadow_size = 7
	add_theme_stylebox_override("panel", panel_style)
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		palette.call("bind_control_style", self, "panel", "surface",
			"card_dead" if _is_dead_slot else "card_inactive" if inactive else \
			"card_active" if is_current else "card_empty")
	var name_color := Color(0.55, 0.57, 0.59) if inactive else \
		(ACTIVE_BORDER if is_current else EMPTY_BORDER)
	if palette != null and str(palette.get("palette_id")) != "padrao":
		name_color = palette.call("color", "card_inactive" if inactive else \
			"card_active" if is_current else "card_empty")
	name_label.add_theme_color_override("font_color", name_color)
	if is_current and not inactive:
		name_label.add_theme_font_override("font", BOLD_FONT)
	else:
		name_label.remove_theme_font_override("font")
	portrait.material = _inactive_material if inactive else null
	# A seta também abre a caixa do inativo: inventário continua acessível e
	# uma Ativa de movimento extra pode reabrir o turno do mesmo personagem.
	action_button.disabled = state == null or state.current_health <= 0
	action_button.modulate = Color(0.58, 0.61, 0.63) if inactive else Color.WHITE
	info_button.disabled = state == null
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if state != null \
		else Control.CURSOR_ARROW


func set_keyboard_highlight(highlighted: bool) -> void:
	if _keyboard_highlighted == highlighted:
		return
	_keyboard_highlighted = highlighted
	set_current_turn(_current_turn)


func _bind_palette() -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette == null:
		return
	for pair in [[_empty_style, "card_empty"], [_active_style, "card_active"],
			[_inactive_style, "card_inactive"], [_dead_style, "card_dead"]]:
		palette.call("bind_style", pair[0], "surface", pair[1])
	for pair in [[health_label, "danger"], [attack_label, "warning"],
			[stamina_label, "progress"], [mastery_label, "structure"]]:
		palette.call("bind_color", pair[0], "font_color", pair[1])
	for slot in [$Margin/Content/TopRow/PortraitFrame,
			$Margin/Content/Equipment/Weapon, $Margin/Content/Equipment/Armor,
			$Margin/Content/Equipment/Accessory]:
		var local_style := (slot as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if local_style != null:
			var unique_style := local_style.duplicate() as StyleBoxFlat
			(slot as Control).add_theme_stylebox_override("panel", unique_style)
			palette.call("bind_style", unique_style, "surface", "neutral")
			palette.call("bind_control_style", slot, "panel", "surface", "neutral")
	for caption in [$Margin/Content/Equipment/Weapon/SlotContent/Caption,
			$Margin/Content/Equipment/Armor/SlotContent/Caption,
			$Margin/Content/Equipment/Accessory/SlotContent/Caption]:
		palette.call("bind_color", caption, "font_color", "secondary")
	palette.connect("palette_changed", func(_new_id: String) -> void:
		set_current_turn(_current_turn))


func set_actions_open(is_open: bool) -> void:
	action_button.text = "◀" if is_open else "▶"
	action_button.tooltip_text = "Fechar ações" if is_open else "Abrir ações"


func refresh() -> void:
	if state == null:
		return
	if state.current_health <= 0:
		bind_state(state)
		return
	var health := "VIDA: %d/%d" % [state.current_health, state.max_health]
	var attack := "ATK: %d" % state.attack
	var stamina := "STAMINA: %d" % state.stamina_remaining
	if health_label.text != health:
		health_label.text = health
	if attack_label.text != attack:
		attack_label.text = attack
	if stamina_label.text != stamina:
		stamina_label.text = stamina
	mastery_label.text = _mastery_text()
	_refresh_equipped_icons()
	_refresh_debuff_dots()
	set_current_turn(_current_turn)


## O HUD lê as cópias realmente equipadas, nunca os itens apenas carregados.
func set_equipped_icons(weapon: ItemData, armor: ItemData,
		accessory: ItemData) -> void:
	_set_item_icon(weapon_icon, weapon)
	_set_item_icon(armor_icon, armor)
	_set_item_icon(accessory_icon, accessory)


func _refresh_equipped_icons() -> void:
	var weapon := state.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	var armor := state.primary_equipped(ItemData.EquipmentSlot.ARMOR)
	var accessory := state.primary_equipped(ItemData.EquipmentSlot.ACCESSORY)
	set_equipped_icons(weapon.data if weapon != null else null,
		armor.data if armor != null else null,
		accessory.data if accessory != null else null)
	var absorbed := _absorbed_weapon()
	if weapon == null and absorbed != null:
		weapon_icon.texture = absorbed.icon
		weapon_icon.modulate = Color(0.40, 0.20, 0.50, 0.72)
		weapon_icon.tooltip_text = "Simbiose Elemental: %s absorvida. Slot de arma bloqueado." % absorbed.display_name
	if state.equipped_weapons.size() > 1:
		weapon_icon.tooltip_text += "\n+%d arma(s) equipada(s) em slot extra" % \
			(state.equipped_weapons.size() - 1)


func _set_item_icon(target: TextureRect, item: ItemData) -> void:
	target.texture = item.icon if item != null else null
	target.modulate = Color.WHITE
	target.tooltip_text = item.display_name if item != null else "Vazio"


func _absorbed_weapon() -> ItemData:
	if state == null:
		return null
	for grant in state.skill_grants:
		if grant != null and grant.skill != null \
				and grant.skill.id == &"permanent_passive_058" \
				and grant.bound_source is ItemData:
			return grant.bound_source as ItemData
	return null


func _show_empty_slot() -> void:
	portrait.texture = null
	portrait.material = null
	name_label.text = "PLAYABLE %d" % slot_number
	health_label.text = "VIDA: --/--"
	attack_label.text = "ATK: --"
	stamina_label.text = "STAMINA: --"
	mastery_label.text = "MAESTRIA: —"
	set_equipped_icons(null, null, null)
	set_current_turn(false)
	_refresh_debuff_dots()


func _first_idle_frame(data: EntityData) -> Texture2D:
	if data == null:
		return null
	var animation := data.playable_animation
	if animation == null or animation.idle_sheet == null:
		return data.portrait if data.portrait != null else data.sprite
	var frame := AtlasTexture.new()
	frame.atlas = animation.idle_sheet
	# Só o busto do primeiro quadro Idle: cabeça e metade superior do corpo.
	# O AtlasTexture recorta sem alterar a folha original da animação.
	frame.region = Rect2(Vector2.ZERO,
		Vector2(animation.frame_size.x, animation.frame_size.y / 2.0))
	return frame


func _mastery_text() -> String:
	var found: Array[String] = []
	for mastery in [EntityData.Mastery.BLADE, EntityData.Mastery.IMPACT,
			EntityData.Mastery.RANGED]:
		if not state.has_mastery(mastery):
			continue
		var label := ""
		match mastery:
			EntityData.Mastery.BLADE:
				label = "LÂMINA"
			EntityData.Mastery.IMPACT:
				label = "IMPACTO"
			EntityData.Mastery.RANGED:
				label = "DISTÂNCIA"
		var level := state.get_mastery_level(mastery)
		found.append("%s +%d" % [label, level] if level > 0 else label)
	return "MAESTRIA: %s" % (" / ".join(found) if not found.is_empty() else "NENHUMA")


func _refresh_debuff_dots() -> void:
	var active: Array[DebuffInstanceState] = []
	if state != null:
		for instance in state.debuffs:
			if instance != null and instance.data != null:
				active.append(instance)
	var signature := ""
	for instance in active:
		signature += "%d|" % instance.get_instance_id()
	if signature == _debuff_signature:
		return
	_debuff_signature = signature
	for dot in debuff_row.get_children():
		debuff_row.remove_child(dot)
		dot.queue_free()
	debuff_row.visible = not active.is_empty()
	for instance in active:
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(36, 36)
		dot.mouse_filter = Control.MOUSE_FILTER_STOP
		dot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var style := StyleBoxFlat.new()
		style.bg_color = DEBUFF_FILL
		style.border_color = DEBUFF_BORDER
		style.set_border_width_all(1)
		style.set_corner_radius_all(18)
		dot.add_theme_stylebox_override("panel", style)
		debuff_row.add_child(dot)
		if instance.data.icon != null:
			var icon := TextureRect.new()
			icon.texture = instance.data.icon
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			dot.add_child(icon)
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 2.0
			icon.offset_top = 2.0
			icon.offset_right = -2.0
			icon.offset_bottom = -2.0
		dot.mouse_entered.connect(func() -> void:
			debuff_inspection_requested.emit(instance, dot.get_global_rect(), false))
		dot.mouse_exited.connect(func() -> void: debuff_hover_ended.emit())
		dot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
					and event.pressed:
				debuff_inspection_requested.emit(instance, dot.get_global_rect(), true)
				dot.accept_event())


func _on_health_changed(_before: int, _after: int) -> void:
	refresh()


func _on_equipment_changed() -> void:
	refresh()


func _on_stat_entered(stat_key: String, label: Label) -> void:
	if state != null:
		stat_hover_requested.emit(state, stat_key, label.get_global_rect())
