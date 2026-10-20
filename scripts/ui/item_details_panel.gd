class_name ItemDetailsPanel
extends PanelContainer

## Lê uma cópia do inventário sem modificar o ItemData nem aplicar efeitos.
## O nome e as regras vêm dos Resources; nada é adivinhado pela interface.

signal close_requested

const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const TRACE_WIDE := preload("res://sprites/ui/uielementx_00007.png")

@onready var close_button: Button = $Margin/Content/Header/CloseButton
@onready var drag_header: Control = $Margin/Content/Header
@onready var item_icon: TextureRect = $Margin/Content/ItemTop/Icon
@onready var name_label: Label = $Margin/Content/ItemTop/Name
@onready var effect_label: Label = $Margin/Content/EffectScroll/Effect
@onready var stats_label: Label = $Margin/Content/StatsScroll/Stats
@onready var effect_scroll: ScrollContainer = $Margin/Content/EffectScroll
@onready var stats_scroll: ScrollContainer = $Margin/Content/StatsScroll

var entry: InventoryItemState
var user_positioned := false
var _dragging := false
var _drag_offset := Vector2.ZERO
var _show_free_space_trace := false


func _draw() -> void:
	if _show_free_space_trace and size.y >= 340.0:
		# Só nos itens curtos: aproveita o canto inferior direito sem cobrir texto.
		draw_texture_rect(TRACE_WIDE,
			Rect2(size - Vector2(156.0, 98.0), Vector2(140.0, 78.0)),
			false, Color(1, 1, 1, 0.15))


func _ready() -> void:
	drag_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	name_label.add_theme_font_override("font", BOLD_FONT)
	close_button.add_theme_font_override("font", BOLD_FONT)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Color(0.92, 0.20, 0.25))
	close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.40, 0.44))
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var close_style := StyleBoxFlat.new()
		close_style.bg_color = Color(0.05, 0.05, 0.06, 0.98)
		close_style.border_color = Color(0.72, 0.15, 0.20) if state == "normal" else Color(1.0, 0.35, 0.40)
		close_style.set_border_width_all(1)
		close_style.set_corner_radius_all(3)
		close_button.add_theme_stylebox_override(state, close_style)
	close_button.pressed.connect(func() -> void: close_requested.emit())


func bind_entry(value: InventoryItemState) -> void:
	if entry != value:
		user_positioned = false
	entry = value
	if entry == null or entry.data == null:
		return
	_bind_item(entry.data, entry)


## Prévia de recompensa: lê apenas o Resource, sem criar uma cópia de
## inventário nem avançar a ordem de aquisição dos itens da campanha.
func bind_catalog_item(item: ItemData) -> void:
	entry = null
	user_positioned = false
	if item != null:
		_bind_item(item, null)


func _bind_item(item: ItemData, copy: InventoryItemState) -> void:
	item_icon.texture = item.icon
	name_label.text = item.display_name
	effect_label.text = _effect_text(item, copy)
	stats_label.text = _stats_text(item, copy)
	_show_free_space_trace = effect_label.text.length() < 80 \
		and stats_label.text.count("\n") <= 2
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		_dragging = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and drag_header.get_global_rect().has_point(event.position) \
				and not close_button.get_global_rect().has_point(event.position):
			_dragging = true
			_drag_offset = event.position - global_position
		elif not event.pressed:
			_dragging = false
	if _dragging and event is InputEventMouseMotion:
		var screen := get_viewport_rect().size
		global_position = Vector2(
			clampf(event.position.x - _drag_offset.x, 15.0,
				maxf(15.0, screen.x - size.x - 15.0)),
			clampf(event.position.y - _drag_offset.y, 15.0,
				maxf(15.0, screen.y - size.y - 15.0)))
		user_positioned = true


func fit_height(max_height: float) -> void:
	# As descrições continuam inteiras e roláveis quando outra caixa ocupa a tela.
	effect_scroll.custom_minimum_size.y = 100.0
	stats_scroll.custom_minimum_size.y = 140.0
	var overflow := maxf(0.0, get_combined_minimum_size().y - max_height)
	if overflow <= 0.0:
		size = get_combined_minimum_size()
		return
	var effect_shrink := minf(45.0, overflow * 0.45)
	effect_scroll.custom_minimum_size.y -= effect_shrink
	overflow -= effect_shrink
	stats_scroll.custom_minimum_size.y = maxf(60.0, 140.0 - overflow)
	size = get_combined_minimum_size()


func _effect_text(item: ItemData, copy: InventoryItemState) -> String:
	var result := item.description.strip_edges()
	if result.is_empty():
		result = "Sem descrição cadastrada para este item."
	if copy != null:
		for state in copy.states:
			if state != null:
				result += "\n\n%s: %s" % [state.display_name, state.description]
	return result


func _stats_text(item: ItemData, copy: InventoryItemState) -> String:
	var lines: Array[String] = []
	# Os bônus de jogo vêm primeiro: a ficha compacta pode rolar, mas nunca
	# deve esconder o Ataque ou a Vida atrás dos metadados do inventário.
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		if item.mastery_granted != EntityData.Mastery.NONE:
			lines.append("Maestria: %s" % _mastery_name(item.mastery_granted))
		if item.mastery_bonus > 0:
			lines.append("Bônus de Maestria: +%d%s" % [item.mastery_bonus,
				" (se corresponder)" if item.mastery_granted != EntityData.Mastery.NONE else ""])
		if item.bonus_attack > 0:
			lines.append("Bônus de Ataque: +%d" % item.bonus_attack)
		if item.bonus_life > 0:
			lines.append("Bônus de Vida máxima: +%d" % item.bonus_life)
		if item.bonus_stamina > 0:
			lines.append("Bônus de Estamina: +%d" % item.bonus_stamina)
		if copy != null and copy.improvement_attack > 0:
			lines.append("Melhoria do Artesão — Ataque: +%d" % copy.improvement_attack)
		if copy != null and copy.improvement_life > 0:
			lines.append("Melhoria do Artesão — Vida máxima: +%d" % copy.improvement_life)
		if copy != null and copy.improvement_stamina > 0:
			lines.append("Melhoria do Artesão — Estamina: +%d" % copy.improvement_stamina)
	match item.item_type:
		ItemData.ItemType.EQUIPMENT:
			lines.append("Tipo: Equipamento")
		ItemData.ItemType.CONSUMABLE:
			lines.append("Tipo: Consumível")
		ItemData.ItemType.CURSED:
			lines.append("Tipo: Amaldiçoado")
	if item.rarity != ItemData.Rarity.NONE and item.item_type != ItemData.ItemType.CURSED:
		lines.append("Raridade: %s" % _rarity_name(item.rarity))
	lines.append("Espaço ocupado: %d" % item.inventory_space)
	if item.item_type == ItemData.ItemType.EQUIPMENT:
		if item.equipment_slot != ItemData.EquipmentSlot.NONE:
			lines.append("Slot: %s" % _slot_name(item.equipment_slot))
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		lines.append("Consumido após uso: %s" % ("Sim" if item.consumed_on_use else "Não"))
	if not item.can_be_discarded:
		lines.append("Pode descartar: Não")
	var passives: Array[String] = []
	for passive in item.granted_passives:
		if passive != null:
			passives.append(passive.display_name)
	if not passives.is_empty():
		lines.append("Passivas: %s" % ", ".join(passives))
	var actives: Array[String] = []
	for active in item.granted_active_skills:
		if active != null:
			actives.append(active.display_name)
	if not actives.is_empty():
		lines.append("Ativas: %s" % ", ".join(actives))
	if copy != null:
		for state in copy.states:
			if state != null:
				lines.append("Estado: %s" % state.display_name)
	return "\n".join(lines)


func _rarity_name(rarity: ItemData.Rarity) -> String:
	match rarity:
		ItemData.Rarity.COMMON: return "Comum"
		ItemData.Rarity.UNCOMMON: return "Incomum"
		ItemData.Rarity.RARE: return "Raro"
		ItemData.Rarity.EPIC: return "Épico"
	return "Nenhuma"


func _slot_name(slot: ItemData.EquipmentSlot) -> String:
	match slot:
		ItemData.EquipmentSlot.WEAPON: return "Arma"
		ItemData.EquipmentSlot.ARMOR: return "Armadura"
		ItemData.EquipmentSlot.ACCESSORY: return "Acessório"
	return "Nenhum"


func _mastery_name(mastery: EntityData.Mastery) -> String:
	match mastery:
		EntityData.Mastery.BLADE: return "Lâmina"
		EntityData.Mastery.IMPACT: return "Impacto"
		EntityData.Mastery.RANGED: return "Distância"
	return "Nenhuma"
