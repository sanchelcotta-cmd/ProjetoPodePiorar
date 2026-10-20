class_name InventoryItemMenu
extends Control

## Menu contextual dos itens. Recebe a cópia concreta, não altera o .tres.
## O mesmo menu atende o inventário lateral e o inventário do grupo.

signal details_requested(entry: InventoryItemState)
signal inventory_changed
signal equip_slot_requested(owner: EntityState, slot_type: int)
signal chance_result_requested(message: String)

const PINK := Color(0.996, 0.169, 0.592)
const GREEN := Color(0.11, 0.49, 0.20)
const BLUE := Color(0.08, 0.34, 0.63)
const YELLOW := Color(0.60, 0.43, 0.06)
const RED := Color(0.62, 0.10, 0.16)
const BLACK := Color(0.07, 0.08, 0.10)
const FONT := preload("res://fonts/UbuntuSans-Regular.ttf")

var actor: EntityState
var entry: InventoryItemState
var campaign: CampaignState
var skill_manager: SkillManager
var combat_manager: CombatManager
var equipped := false
var companion_mode := false
var companion_owner: EntityState
var empty_slot_type := -1
var _anchor := Rect2()
var avoid_rect := Rect2()
var linked_details_panel: Control
var details_open := false
var menu: PanelContainer
var connector: Line2D
var rows: VBoxContainer
var confirm_box: PanelContainer
var modal_blocker: ColorRect
var feedback: Label
var _question: Label
var _cancel_button: Button
var _discard_button: Button
var _inventory := InventoryManager.new()
var _equipment := EquipmentManager.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()


func open_for(owner: EntityState, item_entry: InventoryItemState, is_equipped: bool,
		anchor: Rect2, current_campaign: CampaignState, skills: SkillManager) -> void:
	if owner == null or item_entry == null or item_entry.data == null:
		return
	actor = owner
	entry = item_entry
	companion_mode = false
	companion_owner = null
	empty_slot_type = -1
	equipped = is_equipped
	campaign = current_campaign
	skill_manager = skills
	if skills != null:
		_inventory = skills.inventory_manager
	_anchor = anchor
	details_open = false
	confirm_box.hide()
	modal_blocker.hide()
	_show_main_buttons()
	show()
	menu.show()
	menu.reset_size()
	_reposition(anchor)


func open_companion_equipped(companion: EntityState, owner: EntityState,
		item_entry: InventoryItemState, anchor: Rect2,
		current_campaign: CampaignState, skills: SkillManager) -> void:
	if companion == null or item_entry == null or item_entry.data == null:
		return
	open_for(companion, item_entry, true, anchor, current_campaign, skills)
	companion_mode = true
	companion_owner = owner
	_show_main_buttons()
	menu.reset_size()
	_reposition(anchor)


func open_companion_empty_slot(companion: EntityState, slot_type: int,
		anchor: Rect2, current_campaign: CampaignState, skills: SkillManager) -> void:
	if companion == null or current_campaign == null:
		return
	actor = companion
	entry = null
	companion_mode = true
	companion_owner = null
	empty_slot_type = slot_type
	campaign = current_campaign
	skill_manager = skills
	_anchor = anchor
	confirm_box.hide()
	modal_blocker.hide()
	_clear_rows()
	var heading := Label.new()
	heading.text = "%s | VAZIO" % _slot_display_name(slot_type)
	rows.add_child(heading)
	var equip_button := _button("Equipar", GREEN, _show_companion_equip_choices)
	equip_button.disabled = not _has_companion_equipment_candidate()
	equip_button.tooltip_text = "Nenhum item compatível nos inventários do grupo." \
		if equip_button.disabled else "Escolha um item e quem irá entregá-lo."
	rows.add_child(equip_button)
	show()
	menu.show()
	menu.reset_size()
	_reposition(anchor)


func _slot_display_name(slot_type: int) -> String:
	match slot_type:
		ItemData.EquipmentSlot.WEAPON: return "ARMA"
		ItemData.EquipmentSlot.ARMOR: return "ARMADURA"
		ItemData.EquipmentSlot.ACCESSORY: return "ACESSÓRIO"
	return "EQUIPAMENTO"


func _has_companion_equipment_candidate() -> bool:
	if campaign == null or skill_manager == null:
		return false
	for donor in campaign.active_entity_states:
		for candidate in donor.inventory_items:
			if candidate != null and candidate.data != null \
					and candidate.data.item_type == ItemData.ItemType.EQUIPMENT \
					and candidate.data.equipment_slot == empty_slot_type \
					and _equipment.can_equip_companion_from_playable(donor, actor,
						candidate, skill_manager, campaign):
				return true
	return false


func _show_companion_equip_choices() -> void:
	_clear_rows()
	var heading := Label.new()
	heading.text = "ESCOLHA UM ITEM:"
	rows.add_child(heading)
	for donor in campaign.active_entity_states:
		for candidate in donor.inventory_items:
			if candidate == null or candidate.data == null \
					or candidate.data.item_type != ItemData.ItemType.EQUIPMENT \
					or candidate.data.equipment_slot != empty_slot_type:
				continue
			var choice := _button(_wrap_menu_title("%s · %s" % [
				candidate.data.display_name, donor.data.display_name]), GREEN,
				_equip_companion_choice.bind(donor, candidate))
			choice.disabled = not _equipment.can_equip_companion_from_playable(
				donor, actor, candidate, skill_manager, campaign)
			rows.add_child(choice)
	rows.add_child(_button("Voltar", BLACK, _show_companion_empty_main))
	menu.reset_size()
	_reposition(_anchor)


func _show_companion_empty_main() -> void:
	open_companion_empty_slot(actor, empty_slot_type, _anchor, campaign, skill_manager)


func _equip_companion_choice(donor: EntityState,
		candidate: InventoryItemState) -> void:
	if _equipment.equip_companion_from_playable(donor, actor, candidate,
			skill_manager, campaign):
		inventory_changed.emit()
		close()
	else:
		_show_feedback("Não foi possível equipar este aliado.")


func open_empty_slot(owner: EntityState, slot_type: int, anchor: Rect2,
		current_campaign: CampaignState, skills: SkillManager) -> void:
	if owner == null:
		return
	actor = owner
	entry = null
	empty_slot_type = slot_type
	campaign = current_campaign
	skill_manager = skills
	_anchor = anchor
	confirm_box.hide()
	modal_blocker.hide()
	_clear_rows()
	var heading := Label.new()
	match slot_type:
		ItemData.EquipmentSlot.WEAPON: heading.text = "ARMA | VAZIO"
		ItemData.EquipmentSlot.ARMOR: heading.text = "ARMADURA | VAZIO"
		ItemData.EquipmentSlot.ACCESSORY: heading.text = "ACESSÓRIO | VAZIO"
		_: return
	rows.add_child(heading)
	var equip_button := _button("Equipar", GREEN, _request_equip_empty_slot)
	equip_button.disabled = not _has_eligible_equipment(owner, slot_type)
	equip_button.tooltip_text = "Nenhum item compatível neste inventário." if equip_button.disabled else ""
	rows.add_child(equip_button)
	show()
	menu.show()
	menu.reset_size()
	_reposition(anchor)


func _has_eligible_equipment(owner: EntityState, slot_type: int) -> bool:
	for candidate in owner.inventory_items:
		if candidate != null and candidate.data != null \
				and candidate.data.item_type == ItemData.ItemType.EQUIPMENT \
				and candidate.data.equipment_slot == slot_type \
				and (skill_manager == null or skill_manager.can_equip_item(owner, candidate.data)):
			return true
	return false


func _request_equip_empty_slot() -> void:
	var owner := actor
	var slot_type := empty_slot_type
	close()
	equip_slot_requested.emit(owner, slot_type)


func open_equipped_collection(owner: EntityState,
		items: Array[InventoryItemState], anchor: Rect2,
		current_campaign: CampaignState, skills: SkillManager) -> void:
	if owner == null or items.is_empty():
		return
	open_for(owner, items[0], true, anchor, current_campaign, skills)
	_clear_rows()
	var heading := Label.new()
	heading.text = "Escolha o equipamento:"
	rows.add_child(heading)
	for candidate in items:
		if candidate != null and candidate.data != null:
			rows.add_child(_button(candidate.data.display_name, BLUE,
				open_for.bind(owner, candidate, true, anchor, current_campaign, skills)))
	menu.reset_size()
	_reposition(anchor)


func close() -> void:
	actor = null
	entry = null
	companion_mode = false
	companion_owner = null
	empty_slot_type = -1
	confirm_box.hide()
	modal_blocker.hide()
	hide()
	details_open = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if confirm_box.visible:
			_cancel_discard()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if confirm_box.visible:
			return
		if not menu.get_global_rect().has_point(event.position) \
				and not (details_open and linked_details_panel != null \
				and linked_details_panel.visible \
				and linked_details_panel.get_global_rect().has_point(event.position)):
			close()


func _build() -> void:
	connector = Line2D.new()
	connector.width = 2.0
	connector.default_color = Color(0.12, 0.76, 1.0)
	connector.z_index = 10
	add_child(connector)
	menu = PanelContainer.new()
	menu.name = "ItemActions"
	menu.custom_minimum_size = Vector2(166, 0)
	menu.z_index = 11
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_theme_stylebox_override("panel", _style(Color(0.10, 0.12, 0.15, 0.75), PINK, 1))
	add_child(menu)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	menu.add_child(margin)
	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)
	# Bloqueia cliques no jogo enquanto a confirmação estiver aberta.
	modal_blocker = ColorRect.new()
	modal_blocker.color = Color.TRANSPARENT
	modal_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_blocker.z_index = 20
	add_child(modal_blocker)
	modal_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_blocker.hide()
	confirm_box = PanelContainer.new()
	confirm_box.name = "DiscardConfirmation"
	confirm_box.z_index = 21
	confirm_box.custom_minimum_size = Vector2(280, 135)
	confirm_box.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_box.add_theme_stylebox_override("panel", _style(Color(0.09, 0.10, 0.12, 1.0), RED, 1))
	add_child(confirm_box)
	confirm_box.hide()
	var confirm_margin := MarginContainer.new()
	confirm_margin.add_theme_constant_override("margin_left", 15)
	confirm_margin.add_theme_constant_override("margin_right", 15)
	confirm_margin.add_theme_constant_override("margin_top", 13)
	confirm_margin.add_theme_constant_override("margin_bottom", 13)
	confirm_box.add_child(confirm_margin)
	var confirm_rows := VBoxContainer.new()
	confirm_rows.add_theme_constant_override("separation", 9)
	confirm_margin.add_child(confirm_rows)
	_question = Label.new()
	_question.name = "Question"
	_question.text = "CONFIRMA?"
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.add_theme_font_override("font", FONT)
	_question.add_theme_font_size_override("font_size", 17)
	confirm_rows.add_child(_question)
	var confirm_buttons := HBoxContainer.new()
	confirm_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	confirm_buttons.add_theme_constant_override("separation", 9)
	confirm_rows.add_child(confirm_buttons)
	_cancel_button = _button("CANCELAR", Color(0.25, 0.28, 0.31), _cancel_discard)
	confirm_buttons.add_child(_cancel_button)
	_discard_button = _button("DESCARTAR", BLACK, _confirm_discard)
	confirm_buttons.add_child(_discard_button)
	feedback = Label.new()
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 11)
	feedback.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75))
	confirm_rows.add_child(feedback)


func _show_main_buttons() -> void:
	if companion_mode:
		_show_companion_equipped_buttons()
		return
	_clear_rows()
	var item := entry.data
	var category := "Consumível" if item.item_type == ItemData.ItemType.CONSUMABLE else \
		("Maldição" if item.item_type == ItemData.ItemType.CURSED else _equipment_label(item))
	var heading := Label.new()
	var full_title := "%s | %s" % [item.display_name, category]
	heading.text = _wrap_menu_title(full_title)
	heading.tooltip_text = full_title
	heading.add_theme_font_override("font", FONT)
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color(1, 1, 1))
	rows.add_child(heading)
	var separator := ColorRect.new()
	separator.color = PINK
	separator.custom_minimum_size.y = 1
	rows.add_child(separator)
	if equipped:
		rows.add_child(_button("Desequipar", RED, _unequip))
	else:
		match item.item_type:
			ItemData.ItemType.EQUIPMENT:
				rows.add_child(_button("Equipar", GREEN, _equip))
				rows.add_child(_button("Transferir para", PINK, _show_recipients))
			ItemData.ItemType.CONSUMABLE:
				rows.add_child(_button("Consumir", BLUE, _consume))
				if campaign != null and _inventory.is_ally_debuff_remedy(item) \
						and not campaign.companion_states.is_empty():
					rows.add_child(_button("Dar para", BLUE, _show_ally_recipients))
				rows.add_child(_button("Transferir para", PINK, _show_recipients))
			ItemData.ItemType.CURSED:
				# Maldições não são transferíveis nem descartáveis por ação comum.
				pass
	rows.add_child(_button("Informações" if equipped else "Detalhes", YELLOW, _details))
	if not equipped and item.item_type != ItemData.ItemType.CURSED:
		var discard := _button("Descartar", BLACK, _ask_discard)
		discard.disabled = not item.can_be_discarded
		rows.add_child(discard)
	menu.reset_size()


func _show_companion_equipped_buttons() -> void:
	_clear_rows()
	if entry == null or entry.data == null:
		return
	var heading := Label.new()
	heading.text = _wrap_menu_title("%s | %s" % [entry.data.display_name,
		_slot_display_name(entry.data.equipment_slot)])
	heading.add_theme_font_override("font", FONT)
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(heading)
	var separator := ColorRect.new()
	separator.color = PINK
	separator.custom_minimum_size.y = 1.0
	rows.add_child(separator)
	rows.add_child(_button("Transferir para", PINK, _show_companion_recipients))
	rows.add_child(_button("Detalhes", YELLOW, _details))
	var unequip := _button("Desequipar", RED, _unequip_companion_to_owner)
	unequip.disabled = companion_owner == null or not _companion_recipient_has_space(
		companion_owner)
	unequip.tooltip_text = "Sem espaço no inventário do dono." if unequip.disabled \
		else "Volta ao inventário de %s." % companion_owner.data.display_name
	rows.add_child(unequip)
	menu.reset_size()


func _companion_recipient_has_space(recipient: EntityState) -> bool:
	return recipient != null and entry != null and entry.data != null \
		and recipient.inventory_used_space() + entry.data.inventory_space \
		<= recipient.inventory_capacity()


func _show_companion_recipients() -> void:
	_clear_rows()
	var heading := Label.new()
	heading.text = _wrap_menu_title("Transferir %s para:" % entry.data.display_name)
	rows.add_child(heading)
	var found := false
	for recipient in campaign.active_entity_states:
		if recipient == null or recipient == companion_owner:
			continue
		var choice := _button(recipient.data.display_name, PINK,
			_transfer_companion_to.bind(recipient))
		choice.disabled = not _companion_recipient_has_space(recipient)
		choice.tooltip_text = "Inventário cheio." if choice.disabled else ""
		rows.add_child(choice)
		found = true
	if not found:
		var empty := Label.new()
		empty.text = "Nenhum outro jogável disponível."
		rows.add_child(empty)
	rows.add_child(_button("Voltar", BLACK, _show_main_buttons))
	menu.reset_size()
	_reposition(_anchor)


func _transfer_companion_to(recipient: EntityState) -> void:
	if _equipment.unequip_companion_to_playable(actor, recipient, entry,
			skill_manager, campaign):
		inventory_changed.emit()
		close()
	else:
		_show_feedback("Não foi possível transferir. Verifique o espaço.")


func _unequip_companion_to_owner() -> void:
	if companion_owner != null and _equipment.unequip_companion_to_playable(
			actor, companion_owner, entry, skill_manager, campaign):
		inventory_changed.emit()
		close()
	else:
		_show_feedback("Não foi possível desequipar para o dono.")



func _equipment_label(item: ItemData) -> String:
	match item.equipment_slot:
		ItemData.EquipmentSlot.WEAPON: return "Arma"
		ItemData.EquipmentSlot.ARMOR:
			return "Roupa simples" if item.rarity == ItemData.Rarity.COMMON \
				and item.display_name.to_lower().contains("roupa") else "Armadura"
		ItemData.EquipmentSlot.ACCESSORY: return "Acessório"
	return "Item"


func _show_recipients() -> void:
	_clear_rows()
	var label := Label.new()
	label.text = _wrap_menu_title("Transferir %s para:" % entry.data.display_name)
	rows.add_child(label)
	var found := false
	if campaign != null:
		for candidate in campaign.active_entity_states:
			if candidate == actor or candidate == null:
				continue
			var button := _button(candidate.data.display_name, PINK,
				_transfer.bind(candidate))
			button.disabled = not _inventory.can_receive(candidate, entry.data)
			button.tooltip_text = "Inventário cheio ou personagem indisponível" if button.disabled else ""
			rows.add_child(button)
			found = true
		if entry.data.item_type == ItemData.ItemType.EQUIPMENT:
			for companion in campaign.companion_states:
				if companion == null or companion.data == null \
						or &"jogavel" not in companion.data.tags:
					continue
				var button := _button("%s (equipar)" % companion.data.display_name,
					PINK, _transfer.bind(companion))
				button.disabled = not _equipment.can_equip_companion_from_playable(
					actor, companion, entry, skill_manager, campaign)
				button.tooltip_text = "Troca indisponível: verifique espaço e restrições." \
					if button.disabled else "O item antigo volta ao seu inventário."
				rows.add_child(button)
				found = true
	if not found:
		var empty := Label.new()
		empty.text = "Nenhum colega disponível."
		rows.add_child(empty)
	rows.add_child(_button("Voltar", BLACK, _show_main_buttons))
	menu.reset_size()
	menu.position.y = clampf(menu.position.y, 8.0,
		maxf(8.0, get_viewport_rect().size.y - menu.size.y - 8.0))


func _equip() -> void:
	var occupied := actor.equipped_in_slot(entry.data.equipment_slot)
	var slot_key := _slot_key(entry.data.equipment_slot)
	if occupied.size() > 1 and occupied.size() >= actor.equipment_slot_capacity(slot_key):
		_clear_rows()
		var heading := Label.new()
		heading.text = "Qual item deseja substituir?"
		heading.text = _wrap_menu_title(heading.text)
		rows.add_child(heading)
		for candidate in occupied:
			rows.add_child(_button(candidate.data.display_name, GREEN,
				_equip_with_replacement.bind(candidate)))
		rows.add_child(_button("Voltar", BLACK, _show_main_buttons))
		menu.reset_size()
		_reposition(_anchor)
		return
	_equip_with_replacement(null)


func _equip_with_replacement(replacement: InventoryItemState) -> void:
	if skill_manager != null and _equipment.equip(actor, entry, skill_manager, campaign,
			replacement):
		inventory_changed.emit()
		close()
	else:
		_show_feedback("Não foi possível equipar. Verifique espaço e restrições.")


func _slot_key(slot: ItemData.EquipmentSlot) -> StringName:
	match slot:
		ItemData.EquipmentSlot.WEAPON: return &"weapon"
		ItemData.EquipmentSlot.ARMOR: return &"armor"
		ItemData.EquipmentSlot.ACCESSORY: return &"accessory"
	return &""


func _unequip() -> void:
	if skill_manager != null and _equipment.unequip(actor, entry, skill_manager):
		inventory_changed.emit()
		close()
	else:
		_show_feedback("Não há espaço para desequipar este item.")


func _transfer(recipient: EntityState) -> void:
	var completed := false
	if recipient != null and campaign != null and recipient in campaign.companion_states:
		completed = _equipment.equip_companion_from_playable(actor, recipient,
			entry, skill_manager, campaign)
	else:
		completed = _inventory.transfer_item(actor, recipient, entry, campaign)
	if completed:
		inventory_changed.emit()
		close()
	else:
		_show_feedback("Não foi possível transferir este item.")


func _consume() -> void:
	for effect in entry.data.use_effects:
		if effect != null and effect.effect_type == SkillEffectData.EffectType.REMOVE_INVENTORY_ITEMS \
				and effect.selection_mode == SkillEffectData.SelectionMode.PLAYER_CHOOSES_FROM_OPTIONS:
			_show_curse_choices()
			return
	_consume_with_curse(null)


func _show_ally_recipients() -> void:
	if not _inventory.is_ally_debuff_remedy(entry.data):
		return
	_clear_rows()
	var heading := Label.new()
	heading.text = "Dar %s para:" % entry.data.display_name
	rows.add_child(heading)
	var found := false
	for companion in campaign.companion_states:
		if companion == null or companion.data == null:
			continue
		var choice := _button(companion.data.display_name, BLUE,
			_offer_to_ally.bind(companion))
		choice.disabled = not _inventory.can_remedy_ally(entry.data, companion) \
			or not skill_manager.debuff_manager.can_use_consumable(actor)
		choice.tooltip_text = "Este aliado não tem um debuff que o remédio cure." \
			if choice.disabled else "Consome agora; remoção garantida para aliados."
		rows.add_child(choice)
		found = true
	if not found:
		var empty := Label.new()
		empty.text = "Nenhum aliado disponível."
		rows.add_child(empty)
	rows.add_child(_button("Voltar", BLACK, _show_main_buttons))
	menu.reset_size()
	_reposition(_anchor)


func _offer_to_ally(companion: EntityState) -> void:
	if not _inventory.is_ally_debuff_remedy(entry.data):
		return
	var result := _inventory.use_consumable(actor, entry, skill_manager, campaign,
		null, companion, combat_manager)
	if result.get("success", false):
		inventory_changed.emit()
		close()
		_emit_chance_result(result)
	else:
		_show_feedback(str(result.get("reason", "Não foi possível oferecer este item.")))


func _show_curse_choices() -> void:
	_clear_rows()
	var heading := Label.new()
	heading.text = "Escolha a maldição para retirar:"
	heading.text = _wrap_menu_title(heading.text)
	rows.add_child(heading)
	var found := false
	for candidate in actor.inventory_items:
		if candidate == null or candidate.data == null \
				or candidate.data.item_type != ItemData.ItemType.CURSED:
			continue
		rows.add_child(_button(candidate.data.display_name, BLUE,
			_consume_with_curse.bind(candidate)))
		found = true
	if not found:
		var empty := Label.new()
		empty.text = "Nenhuma maldição neste inventário."
		rows.add_child(empty)
	rows.add_child(_button("Voltar", BLACK, _show_main_buttons))
	menu.reset_size()
	menu.position.y = clampf(menu.position.y, 8.0,
		maxf(8.0, get_viewport_rect().size.y - menu.size.y - 8.0))


func _consume_with_curse(selected_curse: InventoryItemState) -> void:
	var result := _inventory.use_consumable(actor, entry, skill_manager, campaign,
		selected_curse, null, combat_manager)
	if result.get("success", false):
		inventory_changed.emit()
		close()
		_emit_chance_result(result)
	else:
		_show_feedback(str(result.get("reason", "Não foi possível consumir este item.")))


func _emit_chance_result(result: Dictionary) -> void:
	var lines: Array = result.get("chance_results", [])
	if not lines.is_empty():
		chance_result_requested.emit("\n".join(lines))


func _details() -> void:
	details_open = true
	details_requested.emit(entry)


func _ask_discard() -> void:
	if entry == null or entry.data == null or not entry.data.can_be_discarded \
			or entry.data.item_type == ItemData.ItemType.CURSED:
		return
	feedback.text = ""
	_question.text = "CONFIRMA?\n%s" % entry.data.display_name
	_cancel_button.text = "CANCELAR"
	_discard_button.show()
	modal_blocker.show()
	confirm_box.show()
	confirm_box.reset_size()
	confirm_box.position = (get_viewport_rect().size - confirm_box.size) * 0.5


func _cancel_discard() -> void:
	confirm_box.hide()
	modal_blocker.hide()


func _confirm_discard() -> void:
	if _inventory.discard_item(actor, entry):
		inventory_changed.emit()
		close()
	else:
		feedback.text = "Este item não pode ser descartado."


func _show_feedback(message: String) -> void:
	feedback.text = message
	_question.text = "AÇÃO INDISPONÍVEL"
	_cancel_button.text = "FECHAR"
	_discard_button.hide()
	modal_blocker.show()
	confirm_box.show()
	confirm_box.reset_size()
	confirm_box.position = (get_viewport_rect().size - confirm_box.size) * 0.5


func _reposition(anchor: Rect2) -> void:
	var screen := get_viewport_rect().size
	var x := anchor.end.x + 10.0
	if avoid_rect.size.x > 0.0:
		var right := avoid_rect.end.x + 12.0
		var left := avoid_rect.position.x - menu.size.x - 12.0
		if right + menu.size.x <= screen.x - 8.0:
			x = right
		elif left >= 8.0:
			x = left
	if x + menu.size.x > screen.x - 8.0:
		x = anchor.position.x - menu.size.x - 10.0
	menu.position = Vector2(clampf(x, 8.0, maxf(8.0, screen.x - menu.size.x - 8.0)),
		clampf(anchor.position.y, 56.0, maxf(56.0, screen.y - menu.size.y - 8.0)))
	var from := Vector2(anchor.end.x, anchor.get_center().y)
	var to := Vector2(menu.position.x, menu.position.y + menu.size.y * 0.5)
	if menu.position.x < anchor.position.x:
		from.x = anchor.position.x
		to.x = menu.position.x + menu.size.x
	var middle := (from.x + to.x) * 0.5
	connector.points = PackedVector2Array([from, Vector2(middle, from.y),
		Vector2(middle, to.y), to])


func _clear_rows() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()


func _wrap_menu_title(value: String, max_chars: int = 23) -> String:
	# Label com quebra automática e largura ainda desconhecida mede cada letra
	# numa linha. Quebras explícitas mantêm a caixa da altura dos botões.
	var lines: Array[String] = []
	var current := ""
	for word in value.split(" ", false):
		if not current.is_empty() and current.length() + word.length() + 1 > max_chars:
			lines.append(current)
			current = word
		else:
			current = word if current.is_empty() else "%s %s" % [current, word]
	if not current.is_empty():
		lines.append(current)
	return "\n".join(lines)


func _button(caption: String, background: Color, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(140, 38)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(background, background.lightened(0.25), 1))
	button.add_theme_stylebox_override("hover", _style(background.lightened(0.18), background.lightened(0.35), 1))
	button.add_theme_stylebox_override("disabled", _style(Color(0.22, 0.23, 0.24), Color(0.4, 0.4, 0.4), 1))
	button.pressed.connect(callback)
	return button


func _style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(10.0)
	return style
