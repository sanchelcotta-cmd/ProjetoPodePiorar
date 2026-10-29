class_name PartyStatusHUD
extends CanvasLayer

const DIALOG_STYLE := preload("res://scripts/ui/game_dialog_style.gd")
const NARRATIVE_FONT := preload("res://scripts/ui/ui_narrative_font.gd")
const KEYBOARD_BUTTON_NAVIGATION := preload("res://scripts/ui/keyboard_button_navigation.gd")

## Três quadros idênticos, sempre nas vagas Playable_1/2/3. A posição é de
## tela (CanvasLayer), então o painel não anda junto com o mapa.

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var skill_manager: SkillManager
@export var combat_manager: CombatManager

@onready var cards: Array[PartyCharacterCard] = [
	$Root/Cards/Playable1 as PartyCharacterCard,
	$Root/Cards/Playable2 as PartyCharacterCard,
	$Root/Cards/Playable3 as PartyCharacterCard,
]
@onready var action_drawer: PanelContainer = $ActionDrawer
@onready var action_title: Label = $ActionDrawer/Margin/Actions/Title
@onready var action_scroll: ScrollContainer = $ActionDrawer/Margin/Actions/ActionScroll
@onready var walk_button: Button = $ActionDrawer/Margin/Actions/ActionScroll/Rows/WalkButton
@onready var skill_buttons: VBoxContainer = $ActionDrawer/Margin/Actions/ActionScroll/Rows/SkillButtons
@onready var ally_button: Button = $ActionDrawer/Margin/Actions/ActionScroll/Rows/AllyButton
@onready var inventory_button: Button = $ActionDrawer/Margin/Actions/ActionScroll/Rows/InventoryButton
@onready var passive_buttons: VBoxContainer = $ActionDrawer/Margin/Actions/ActionScroll/Rows/PassiveButtons
@onready var scroll_arrows: HBoxContainer = $ActionDrawer/Margin/Actions/ScrollArrows
@onready var scroll_up_button: Button = $ActionDrawer/Margin/Actions/ScrollArrows/Up
@onready var scroll_down_button: Button = $ActionDrawer/Margin/Actions/ScrollArrows/Down
@onready var action_hint: Label = $ActionDrawer/Margin/Actions/Hint
@onready var ally_drawer: PanelContainer = $AllyDrawer
@onready var ally_scroll: ScrollContainer = $AllyDrawer/Margin/Content/AllyScroll
@onready var ally_skill_buttons: VBoxContainer = $AllyDrawer/Margin/Content/AllyScroll/Buttons
@onready var ally_scroll_arrows: HBoxContainer = $AllyDrawer/Margin/Content/ScrollArrows
@onready var ally_scroll_up_button: Button = $AllyDrawer/Margin/Content/ScrollArrows/Up
@onready var ally_scroll_down_button: Button = $AllyDrawer/Margin/Content/ScrollArrows/Down
@onready var hex_choice: PanelContainer = $HexChoiceLayer/HexChoice
@onready var hex_choice_title: Label = $HexChoiceLayer/HexChoice/Margin/Content/Header/Title
@onready var hex_choice_close: Button = $HexChoiceLayer/HexChoice/Margin/Content/Header/Close
@onready var hex_choice_buttons: VBoxContainer = $HexChoiceLayer/HexChoice/Margin/Content/Buttons
@onready var skill_info: PanelContainer = $SkillInfo
@onready var skill_info_description: Label = $SkillInfo/Margin/Content/Description
@onready var inventory_panel: CharacterInventoryPanel = $InventoryPanel
@onready var item_details_panel: ItemDetailsPanel = $ItemDetailsPanel
@onready var action_link: Line2D = $ActionLink
@onready var inventory_link: Line2D = $InventoryLink
@onready var item_details_link: Line2D = $ItemDetailsLink
@onready var dividers: Array[TextureRect] = [$Root/Divider12, $Root/Divider23]
@onready var map_hit_targets: Control = $MapHitTargets
@onready var inspect_bubble: Button = $InspectBubble
@onready var bubble_hint: PanelContainer = $BubbleHint
@onready var character_sheet: CharacterSheetPanel = $CharacterSheetPanel
@onready var stat_tooltip: PanelContainer = $StatBreakdownTooltip
@onready var stat_tooltip_text: RichTextLabel = $StatBreakdownTooltip/Margin/Text
const ITEM_MENU_SCRIPT := preload("res://scripts/ui/inventory_item_menu.gd")
const HEX_TITLE_POPUP_SCRIPT := preload("res://scripts/ui/hex_title_popup.gd")
const CREATED_ITEM_POPUP_SCRIPT := preload("res://scripts/ui/created_item_popup.gd")
const DEBUFF_POPUP_SCRIPT := preload("res://scripts/ui/debuff_info_popup.gd")
const HEX_CLICK_OVERLAY_SCRIPT := preload("res://scripts/ui/hex_click_overlay.gd")
const CRAFT_HINT_SCRIPT := preload("res://scripts/ui/craft_hint_popup.gd")

var _refresh_elapsed := 0.0
var _inspection_actor: EntityState
var _map_hit_buttons: Array[Button] = []
var _hex_click_overlay: Control
var _hex_choice_detail: Label
var _hex_choice_detail_scroll: ScrollContainer
var _hex_choice_separator: HSeparator
var _hex_choice_anchor := Vector2.ZERO
var _companion_map_hit_buttons: Dictionary = {}
var _companion_frame_bounds: Dictionary = {}
var _map_debuff_hit_buttons: Dictionary = {}
var _stat_hover_actor: EntityState
var _stat_hover_key := ""
var _future_vision_targeting_actor: EntityState
var _future_vision_is_premonition := false
var _open_card: PartyCharacterCard
var _keyboard_card_index := -1
var _action_keyboard_navigation := KEYBOARD_BUTTON_NAVIGATION.new()
var _action_tween: Tween
var _inventory_tween: Tween
var _details_tween: Tween
var _selected_item_entry: InventoryItemState
var item_menu: InventoryItemMenu
var hex_title_popup: PanelContainer
var created_item_popup: Control
var debuff_popup: Control
var passive_info_popup: PanelContainer
var _equipment_pick_actor: EntityState
var _equipment_pick_slot := -1
var _last_inspected_coord := Vector2i(-999, -999)
var _targeting_actor: EntityState
var _targeting_grant: SkillGrantState
var _ally_target_choice_open := false
var _ground_choice_open := false
var _drag_pet_visual: CompanionActorVisual
var _pending_cat_visual: CompanionActorVisual
var _pending_cat_actor: EntityState
var _pending_cat_press := Vector2.ZERO
var _drop_preview_visual: CompanionActorVisual
var _drop_actor: EntityState
var _drop_grant: SkillGrantState
var _suppress_companion_click := false
var _walk_target_actor: EntityState
var _action_signature := ""
var _scroll_first_index := 0
var _action_visible_limit := 6
var _ally_scroll_first_index := 0
var _ally_selected_index := 0
var _ally_select: OptionButton
var _ally_info: VBoxContainer
var _ally_roster: VBoxContainer
var _ally_owner_badge: PanelContainer
var _ally_owner_badge_text: Label
var _ally_portrait: TextureRect
var _ally_summary: Label
var _ally_stats: Label
var _ally_info_button: Button
var _ally_equipment: HBoxContainer
var _ally_position_queued := false
var _companion_action_choice_open := false
var _companion_action_target: EntityState
var _companion_actions_from_initiative := false
var _initiative_action_anchor := Rect2()
var _initiative_action_link: Line2D
var _combat_pass_button: Button
var _combat_ally_roll_button: Button
var _combat_roll_animating := false
var _combat_roll_tween: Tween
var _revive_dialog: ConfirmationDialog
var _attune_dialog: ConfirmationDialog
var _attune_owner: EntityState
var _attune_grant: SkillGrantState
var _amulet_owner: EntityState
var _amulet_grant: SkillGrantState
var _amulet_target: EntityState
var _tame_dialog: ConfirmationDialog
var _tame_result_dialog: AcceptDialog
var _archenemy_dialog: ConfirmationDialog
var _recruitment_dialog: ConfirmationDialog
var _recruitment_result_dialog: AcceptDialog
var _chance_result_dialog: Control
var _pending_tame_target: EntityState
var _pending_tame_grant: SkillGrantState
var _pending_archenemy_target: EntityState
var _pending_archenemy_grant: SkillGrantState
var craft_hint: CraftHintPopup
var _craft_hint_from_item := false


func _ready() -> void:
	NARRATIVE_FONT.apply_label(skill_info_description)
	for card in cards:
		card.action_toggle_requested.connect(_on_action_toggle_requested)
		card.inspect_requested.connect(_on_card_inspect_requested)
		card.sheet_requested.connect(_on_card_sheet_requested)
		card.stat_hover_requested.connect(_show_stat_breakdown)
		card.stat_hover_ended.connect(_hide_stat_breakdown)
		card.equipped_item_selected.connect(_on_equipped_item_selected)
		card.equipment_slot_selected.connect(_on_equipment_slot_selected)
		card.craft_hover_requested.connect(_on_equipped_craft_hover)
		card.craft_hover_ended.connect(_on_craft_hover_ended)
		card.debuff_inspection_requested.connect(_on_debuff_inspection_requested)
		card.debuff_hover_ended.connect(_on_debuff_hover_ended)
	_build_map_hit_targets()
	_build_hex_choice_details()
	hex_choice_close.pressed.connect(_hide_hex_choice)
	inspect_bubble.pressed.connect(_open_sheet_from_bubble)
	inspect_bubble.mouse_entered.connect(_show_bubble_hint)
	inspect_bubble.mouse_exited.connect(func() -> void: bubble_hint.hide())
	character_sheet.close_requested.connect(_close_character_sheet)
	character_sheet.stat_hover_requested.connect(_show_stat_breakdown)
	character_sheet.stat_hover_ended.connect(_hide_stat_breakdown)
	walk_button.pressed.connect(_on_walk_pressed)
	ally_button.pressed.connect(_on_ally_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	scroll_up_button.pressed.connect(_on_action_scroll_up)
	scroll_down_button.pressed.connect(_on_action_scroll_down)
	ally_scroll_up_button.pressed.connect(_on_ally_scroll_up)
	ally_scroll_down_button.pressed.connect(_on_ally_scroll_down)
	_build_ally_info()
	_build_ally_owner_badge()
	_initiative_action_link = Line2D.new()
	_initiative_action_link.name = "InitiativeAllyActionLink"
	_initiative_action_link.width = 2.0
	_initiative_action_link.default_color = Color(0.22, 0.79, 0.91, 0.92)
	add_child(_initiative_action_link)
	_initiative_action_link.hide()
	inventory_panel.close_requested.connect(_close_inventory)
	inventory_panel.expansion_changed.connect(_on_inventory_expansion_changed)
	inventory_panel.inventory_reordered.connect(func() -> void:
		item_menu.close()
		_close_item_details()
		_on_item_inventory_changed())
	inventory_panel.item_selected.connect(_on_item_selected)
	inventory_panel.craft_requested.connect(_on_craft_requested)
	inventory_panel.craft_hover_requested.connect(_on_inventory_craft_hover)
	inventory_panel.craft_hover_ended.connect(_on_craft_hover_ended)
	inventory_panel.craft_campaign = gerencia.campaign if gerencia != null else null
	inventory_panel.craft_inventory = skill_manager.inventory_manager \
		if skill_manager != null else null
	inventory_panel.craft_exploration = exploration
	item_details_panel.close_requested.connect(_close_item_details)
	item_menu = ITEM_MENU_SCRIPT.new() as InventoryItemMenu
	item_menu.name = "ItemMenu"
	add_child(item_menu)
	item_menu.combat_manager = combat_manager
	item_menu.craft_exploration = exploration
	item_menu.linked_details_panel = item_details_panel
	item_menu.details_requested.connect(_show_item_details)
	item_menu.inventory_changed.connect(_on_item_inventory_changed)
	item_menu.equip_slot_requested.connect(_on_equip_slot_requested)
	item_menu.chance_result_requested.connect(_show_chance_result)
	item_menu.craft_requested.connect(_on_craft_requested)
	_chance_result_dialog = preload("res://scripts/ui/item_chance_result_popup.gd").new()
	add_child(_chance_result_dialog)
	debuff_popup = DEBUFF_POPUP_SCRIPT.new() as Control
	debuff_popup.name = "DebuffInfoPopup"
	add_child(debuff_popup)
	craft_hint = CRAFT_HINT_SCRIPT.new() as CraftHintPopup
	craft_hint.name = "CraftHint"
	craft_hint.z_index = 210
	add_child(craft_hint)
	hex_title_popup = HEX_TITLE_POPUP_SCRIPT.new() as PanelContainer
	hex_title_popup.name = "HexTitlePopup"
	add_child(hex_title_popup)
	created_item_popup = CREATED_ITEM_POPUP_SCRIPT.new() as Control
	created_item_popup.name = "CreatedItemPopup"
	add_child(created_item_popup)
	if skill_manager != null:
		skill_manager.delayed_skill_effect_resolved.connect(_on_delayed_created_item)
	_paint_action_button(walk_button, Color(0.11, 0.43, 0.17))
	_paint_action_button(ally_button, Color(0.52, 0.36, 0.055))
	_paint_action_button(inventory_button, Color(0.075, 0.27, 0.53))
	_combat_pass_button = _make_choice_button("PASSAR O TURNO", Color(0.24, 0.25, 0.27))
	_combat_pass_button.name = "CombatPassTurn"
	_combat_pass_button.pressed.connect(_on_combat_end_pressed)
	inventory_button.get_parent().add_child(_combat_pass_button)
	inventory_button.get_parent().move_child(_combat_pass_button,
		inventory_button.get_index() + 1)
	_combat_pass_button.hide()
	_build_passive_info_popup()
	_paint_action_button(scroll_up_button, Color(0.12, 0.3, 0.34))
	_paint_action_button(scroll_down_button, Color(0.12, 0.3, 0.34))
	_paint_action_button(ally_scroll_up_button, Color(0.12, 0.3, 0.34))
	_paint_action_button(ally_scroll_down_button, Color(0.12, 0.3, 0.34))
	action_scroll.get_v_scroll_bar().value_changed.connect(_on_action_scroll_changed)
	ally_scroll.get_v_scroll_bar().value_changed.connect(_on_ally_scroll_changed)
	var info_style := (action_drawer.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	info_style.bg_color.a = 0.94
	skill_info.add_theme_stylebox_override("panel", info_style)
	_bind_palette()
	_set_mouse_ignore_recursive(skill_info)
	if gerencia != null:
		gerencia.map_generated.connect(_on_map_generated)
		gerencia.campaign.companion_registered.connect(_on_companion_added)
		gerencia.campaign.playable_slot_replaced.connect(func(_previous: EntityState,
				_replacement: EntityState) -> void:
			_sync_slots())
		if gerencia.map_view != null:
			gerencia.map_view.hex_choice_requested.connect(_on_hex_choice_requested)
			gerencia.map_view.ground_pressed.connect(_on_ground_pressed)
			gerencia.map_view.hex_inspection_requested.connect(_on_hex_inspection_requested)
			gerencia.map_view.hex_revealed.connect(_on_hex_revealed)
			gerencia.map_view.future_vision_hex_requested.connect(_on_future_vision_hex_requested)
	if exploration != null:
		exploration.map_entered.connect(_on_map_entered)
		exploration.turn_started.connect(_on_turn_changed)
		exploration.turn_finished.connect(_on_turn_changed)
	if skill_manager != null:
		skill_manager.active_skill_used.connect(_on_active_skill_used)
		skill_manager.debuff_manager.debuff_applied.connect(_on_debuff_changed)
		skill_manager.debuff_manager.debuff_renewed.connect(_on_debuff_changed)
		skill_manager.debuff_manager.debuff_removed.connect(_on_debuff_removed)
	if combat_manager != null:
		_tame_dialog = ConfirmationDialog.new()
		_tame_dialog.title = "Adestramento Bestial"
		_tame_dialog.ok_button_text = "SIM, ADESTRAR"
		_tame_dialog.cancel_button_text = "NÃO"
		_tame_dialog.exclusive = false
		_tame_dialog.confirmed.connect(_confirm_taming)
		_tame_dialog.canceled.connect(_cancel_taming)
		add_child(_tame_dialog)
		DIALOG_STYLE.apply(_tame_dialog, "warning", 470.0, 78.0)
		_tame_result_dialog = AcceptDialog.new()
		_tame_result_dialog.title = "Adestramento Bestial"
		_tame_result_dialog.ok_button_text = "OK"
		# A confirmação pode estar encerrando sua janela exclusiva no mesmo frame.
		_tame_result_dialog.exclusive = false
		_tame_result_dialog.window_input.connect(_on_tame_result_window_input)
		add_child(_tame_result_dialog)
		DIALOG_STYLE.apply(_tame_result_dialog, "structure", 470.0, 70.0)
		_archenemy_dialog = ConfirmationDialog.new()
		_archenemy_dialog.title = "Arqui-inimigo"
		_archenemy_dialog.ok_button_text = "SIM"
		_archenemy_dialog.cancel_button_text = "NÃO"
		_archenemy_dialog.exclusive = false
		_archenemy_dialog.confirmed.connect(_confirm_archenemy)
		_archenemy_dialog.canceled.connect(_cancel_archenemy)
		add_child(_archenemy_dialog)
		DIALOG_STYLE.apply(_archenemy_dialog, "warning", 470.0, 70.0)
		_recruitment_dialog = ConfirmationDialog.new()
		_recruitment_dialog.title = "A Experiência"
		_recruitment_dialog.ok_button_text = "RECRUTAR"
		_recruitment_dialog.cancel_button_text = "RECUSAR E COMBATER"
		_recruitment_dialog.exclusive = false
		_recruitment_dialog.confirmed.connect(_on_recruitment_confirmed)
		_recruitment_dialog.canceled.connect(_on_recruitment_declined)
		add_child(_recruitment_dialog)
		DIALOG_STYLE.apply(_recruitment_dialog, "warning", 500.0, 82.0)
		_recruitment_result_dialog = AcceptDialog.new()
		_recruitment_result_dialog.title = "A Experiência"
		_recruitment_result_dialog.ok_button_text = "PROSSEGUIR"
		_recruitment_result_dialog.exclusive = false
		_recruitment_result_dialog.confirmed.connect(_on_recruitment_result_closed)
		_recruitment_result_dialog.canceled.connect(_on_recruitment_result_closed)
		_recruitment_result_dialog.window_input.connect(
			_on_recruitment_result_window_input)
		add_child(_recruitment_result_dialog)
		DIALOG_STYLE.apply(_recruitment_result_dialog, "structure", 470.0, 70.0)
		_revive_dialog = ConfirmationDialog.new()
		_revive_dialog.title = "Sacrifício Divino"
		_revive_dialog.ok_button_text = "CONFIRMAR SACRIFÍCIO"
		_revive_dialog.cancel_button_text = "VOLTAR"
		_revive_dialog.confirmed.connect(_confirm_amulet_revive)
		_revive_dialog.canceled.connect(_cancel_amulet_revive)
		add_child(_revive_dialog)
		DIALOG_STYLE.apply(_revive_dialog, "danger", 560.0, 82.0)
		_attune_dialog = ConfirmationDialog.new()
		_attune_dialog.title = "Sintonizar Amuleto Divino"
		_attune_dialog.ok_button_text = "SIM, SINTONIZAR"
		_attune_dialog.cancel_button_text = "CANCELAR"
		_attune_dialog.confirmed.connect(_confirm_amulet_attunement)
		_attune_dialog.canceled.connect(_cancel_amulet_attunement)
		add_child(_attune_dialog)
		DIALOG_STYLE.apply(_attune_dialog, "warning", 590.0, 100.0)
		DIALOG_STYLE.make_layer_backdrop(self, [
			_tame_dialog, _tame_result_dialog, _archenemy_dialog,
			_recruitment_dialog, _recruitment_result_dialog, _revive_dialog,
			_attune_dialog,
		])
		combat_manager.turn_started.connect(_on_combat_turn_started)
		combat_manager.turn_finished.connect(_on_combat_turn_finished)
		combat_manager.die_rolled.connect(_on_combat_die_rolled)
		combat_manager.action_resolved.connect(_on_combat_action_resolved)
		combat_manager.recruitment_choice_requested.connect(
			_on_recruitment_choice_requested)
		combat_manager.combat_finished.connect(_on_combat_finished)
	_sync_slots()
	_position_separators.call_deferred()


func _on_combat_action_resolved(_actor: EntityState, action: StringName,
		_details: Dictionary) -> void:
	if action not in [&"move_finished", &"attack", &"attack_missed_reach"]:
		return
	if _open_card != null and _open_card.state != null:
		_rebuild_action_buttons()
	_refresh_companion_action_choice()


func _input(event: InputEvent) -> void:
	if hex_choice.visible and event is InputEventKey and event.pressed \
			and event.keycode == KEY_ESCAPE:
		_hide_hex_choice()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and action_drawer.visible and not get_tree().paused:
		var activation := get_parent().get_node_or_null("BlockActivationPopup") as BlockActivationPopup
		if activation == null or not activation.overlay.visible:
			var key := (event as InputEventKey).keycode
			if key == KEY_I:
				_on_inventory_pressed()
				get_viewport().set_input_as_handled()
				return
			if key in [KEY_LEFT, KEY_A]:
				if item_details_panel.visible:
					_close_item_details()
				elif inventory_panel.visible:
					_close_inventory()
				elif hex_choice.visible:
					_hide_hex_choice()
				elif ally_drawer.visible:
					ally_drawer.hide()
				else:
					_close_actions()
				get_viewport().set_input_as_handled()
				return
			if not inventory_panel.visible and not hex_choice.visible \
					and not ally_drawer.visible \
					and _action_keyboard_navigation.handle(event, action_scroll):
				get_viewport().set_input_as_handled()
				return
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed and _drag_pet_visual != null:
		_finish_cat_drag(event.position)
		_clear_companion_click_suppression.call_deferred()
		return
	if not event.pressed:
		_pending_cat_visual = null
		_pending_cat_actor = null
		return
	if _ally_owner_badge != null and _ally_owner_badge.visible:
		_hide_ally_owner_badge()
	if hex_choice.visible \
			and not hex_choice.get_global_rect().has_point(event.position):
		_hide_hex_choice()
		get_viewport().set_input_as_handled()
		return
	if passive_info_popup != null and passive_info_popup.visible \
			and not passive_info_popup.get_global_rect().has_point(event.position) \
			and not passive_buttons.get_global_rect().has_point(event.position):
		passive_info_popup.hide()
	if not inspect_bubble.visible:
		return
	# Outro clique não pode deixar o balão flutuando no mapa.
	if not inspect_bubble.get_global_rect().has_point(event.position):
		inspect_bubble.hide()
		bubble_hint.hide()
		_inspection_actor = null


func _process(delta: float) -> void:
	if _pending_cat_visual != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and get_viewport().get_mouse_position().distance_to(_pending_cat_press) > 12.0:
		var grant := _pet_skill(_pending_cat_actor, &"companion_active_001")
		if grant != null and _skill_is_available(_pending_cat_actor, grant) \
				and _pending_cat_visual.begin_mouse_carry():
			_drag_pet_visual = _pending_cat_visual
			_drop_actor = _pending_cat_actor
			_drop_grant = grant
			_suppress_companion_click = true
		_pending_cat_visual = null
		_pending_cat_actor = null
	if _drag_pet_visual != null:
		_drag_pet_visual.update_mouse_carry(get_viewport().get_mouse_position())
	_update_map_hit_targets()
	if _open_card != null and (_open_card.state == null \
			or _open_card.state.current_health <= 0):
		_close_actions()
	if _open_card != null:
		_update_connectors()
	# Ataque, Estamina e Maestria podem mudar por item, passiva ou evento;
	# ainda não há um sinal comum para os três. Atualização leve, 6 vezes/s.
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.16:
		return
	_refresh_elapsed = 0.0
	if character_sheet.visible:
		character_sheet.refresh_live()
	if stat_tooltip.visible and _stat_hover_actor != null:
		stat_tooltip_text.text = EntityStatBreakdown.colored_text(
			_stat_hover_actor, _stat_hover_key)
	if _open_card != null:
		var signature := _skill_list_signature(_open_card.state)
		if signature != _action_signature:
			_rebuild_action_buttons()
			_position_action_drawer(false)
	for card in cards:
		card.refresh()
	_refresh_craft_highlights()
	_update_ground_craft_hint()
	_update_turn_border()
	_position_separators()
	if inventory_panel.visible:
		var old_size := inventory_panel.size
		inventory_panel.refresh()
		if inventory_panel.size != old_size:
			_position_inventory_panel(false)
		if item_details_panel.visible:
			if _selected_item_entry == null \
					or not _entry_still_in_party(_selected_item_entry):
				_close_item_details()
			else:
				item_details_panel.bind_entry(_selected_item_entry)
				if _details_tween == null or not _details_tween.is_running():
					# Dado, cara ou coroa e Próxima fase podem abrir enquanto os
					# detalhes estão visíveis; a caixa se acomoda abaixo deles.
					_position_item_details(false)


func _on_map_generated(_map: HexGrid) -> void:
	_cancel_combat_die_animation()
	_walk_target_actor = null
	_future_vision_targeting_actor = null
	_last_inspected_coord = Vector2i(-999, -999)
	hex_title_popup.hide()
	inspect_bubble.hide()
	bubble_hint.hide()
	_sync_slots()


func _on_map_entered(_map: HexGrid) -> void:
	_cancel_combat_die_animation()
	_walk_target_actor = null
	_sync_slots()


func _on_turn_changed(_actor: EntityState) -> void:
	if _in_combat():
		return
	if _future_vision_targeting_actor != null and _future_vision_targeting_actor != exploration.current_actor:
		_end_future_vision_targeting()
	hex_title_popup.hide()
	_update_turn_border()
	if _walk_target_actor != exploration.current_actor:
		_walk_target_actor = null
	_hide_hex_choice()
	_targeting_actor = null
	_targeting_grant = null
	if _open_card != null:
		_rebuild_action_buttons()
		_position_action_drawer(false)


func _on_combat_turn_started(actor: EntityState, _cycle: int) -> void:
	_walk_target_actor = null
	_targeting_actor = null
	_targeting_grant = null
	_hide_hex_choice()
	_update_turn_border()
	if not combat_manager.is_player_turn():
		_close_actions()
		return
	if actor in gerencia.campaign.companion_states:
		# A ordem de iniciativa apresenta automaticamente as ações do aliado.
		# Não duplicar esse painel dentro da caixa do dono.
		_close_actions()
		return
	var owner := actor
	var index := gerencia.campaign.active_entity_states.find(owner)
	if index >= 0 and index < cards.size() and _open_card != cards[index]:
		_on_action_toggle_requested(cards[index])
	if _open_card != null:
		_rebuild_action_buttons()
		_position_action_drawer(false)


func _on_combat_die_rolled(actor: EntityState, result: int) -> void:
	_animate_combat_die_result(actor, result)


func _animate_combat_die_result(actor: EntityState, result: int) -> void:
	_cancel_combat_die_animation()
	_combat_roll_animating = true
	var button := _combat_ally_roll_button if gerencia != null \
		and actor in gerencia.campaign.companion_states else walk_button
	if not is_instance_valid(button):
		_combat_roll_animating = false
		return
	button.disabled = true
	# O tween pertence à HUD. Fechar a cena cancela a animação e não deixa
	# SceneTreeTimers segurando botões, personagens e recursos em memória.
	_combat_roll_tween = create_tween()
	for _index in 12:
		_combat_roll_tween.tween_callback(_preview_combat_die.bind(button))
		_combat_roll_tween.tween_interval(0.05)
	_combat_roll_tween.tween_callback(_finish_combat_die.bind(button, result))


func _cancel_combat_die_animation() -> void:
	if _combat_roll_tween != null and _combat_roll_tween.is_valid():
		_combat_roll_tween.kill()
	_combat_roll_tween = null
	_combat_roll_animating = false


func _preview_combat_die(button: Button) -> void:
	if is_instance_valid(button):
		button.text = "DADO: %d" % randi_range(1, 6)


func _finish_combat_die(button: Button, result: int) -> void:
	_combat_roll_tween = null
	_combat_roll_animating = false
	if not is_inside_tree() or not is_instance_valid(button):
		return
	button.text = "DADO: %d" % result
	if _open_card != null:
		_rebuild_action_buttons()
	_refresh_companion_action_choice()


func _on_combat_turn_finished(_actor: EntityState) -> void:
	_walk_target_actor = null
	_hide_hex_choice()
	_update_turn_border()
	if _open_card != null:
		_rebuild_action_buttons()


func _on_combat_finished(_result: Dictionary) -> void:
	_cancel_combat_die_animation()
	_close_actions()
	_update_turn_border()


func _in_combat() -> bool:
	return gerencia != null and gerencia.campaign != null \
		and gerencia.campaign.current_map != null \
		and gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT


func _on_debuff_changed(_actor: EntityState, _instance: DebuffInstanceState) -> void:
	for card in cards:
		card.refresh()


func _on_debuff_removed(_actor: EntityState, _id: StringName) -> void:
	if debuff_popup != null:
		debuff_popup.hide()
	for card in cards:
		card.refresh()


func _on_debuff_inspection_requested(instance: DebuffInstanceState,
		anchor: Rect2, pinned: bool) -> void:
	debuff_popup.call("show_debuff", instance, anchor, pinned,
		gerencia.campaign if gerencia != null else null)


func _on_debuff_hover_ended() -> void:
	if debuff_popup != null and not bool(debuff_popup.get("pinned")):
		debuff_popup.hide()


func _on_active_skill_used(_actor: EntityState, grant: SkillGrantState,
		result: Dictionary) -> void:
	var skill := grant.skill as ActiveSkillData if grant != null else null
	if skill != null:
		var lines: Array[String] = []
		var effect_results: Array = result.get("effects", [])
		for index in mini(skill.effects.size(), effect_results.size()):
			var effect := skill.effects[index]
			if effect.activation_chance >= 1.0:
				continue
			var effect_result: Dictionary = effect_results[index]
			if effect_result.get("chance_failed", false):
				lines.append("Não foi dessa vez...")
			else:
				lines.append("Você obteve sucesso: %s." % skill.description)
		if not lines.is_empty():
			_show_chance_result("\n".join(lines))
	if grant == null or grant.skill == null \
			or (grant.skill as ActiveSkillData).id != &"playable_active_009":
		return
	for effect_result in result.get("effects", []):
		if effect_result is Dictionary and effect_result.get("item") is ItemData:
			created_item_popup.call("show_item", effect_result["item"], effect_result)
			return


func _show_chance_result(message: String) -> void:
	if _chance_result_dialog == null or message.is_empty():
		return
	_chance_result_dialog.call("show_message", message)


func _on_delayed_created_item(_owner: EntityState, result: Dictionary) -> void:
	if result.get("item") is ItemData:
		created_item_popup.call("show_item", result["item"], result)


func _sync_slots() -> void:
	_close_actions()
	for index in cards.size():
		var actor: EntityState = null
		if gerencia != null and gerencia.campaign.active_entity_states.size() > index:
			actor = gerencia.campaign.active_entity_states[index]
		cards[index].bind_state(actor)
	if character_sheet.visible and character_sheet.actor not in \
			(gerencia.campaign.active_entity_states if gerencia != null else []):
		_close_character_sheet()
	_update_turn_border()


func _build_map_hit_targets() -> void:
	for index in cards.size():
		var hit := Button.new()
		hit.name = "MapCharacter_%d" % (index + 1)
		hit.flat = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.modulate.a = 0.0 # Invisível: o sprite do mapa permanece intacto.
		hit.visible = false
		hit.pressed.connect(_on_map_actor_pressed.bind(index))
		map_hit_targets.add_child(hit)
		_map_hit_buttons.append(hit)
	_hex_click_overlay = HEX_CLICK_OVERLAY_SCRIPT.new() as Control
	_hex_click_overlay.name = "HexClickPriority"
	_hex_click_overlay.map_view = gerencia.map_view if gerencia != null else null
	_hex_click_overlay.hex_pressed.connect(_on_hex_overlay_pressed)
	map_hit_targets.add_child(_hex_click_overlay)


func _build_hex_choice_details() -> void:
	var header := hex_choice_title.get_parent() as HBoxContainer
	var content := header.get_parent() as VBoxContainer
	_hex_choice_detail_scroll = ScrollContainer.new()
	_hex_choice_detail_scroll.name = "RevealedDescriptionScroll"
	_hex_choice_detail_scroll.custom_minimum_size.x = 270.0
	_hex_choice_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_hex_choice_detail_scroll)
	content.move_child(_hex_choice_detail_scroll, header.get_index() + 1)
	_hex_choice_detail = Label.new()
	_hex_choice_detail.name = "RevealedDescription"
	_hex_choice_detail.custom_minimum_size.x = 270.0
	_hex_choice_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NARRATIVE_FONT.apply_label(_hex_choice_detail)
	_hex_choice_detail.add_theme_font_size_override("font_size", 13)
	_hex_choice_detail.add_theme_color_override("font_color",
		Color(0.92, 0.96, 0.98))
	_hex_choice_detail_scroll.add_child(_hex_choice_detail)
	_hex_choice_detail_scroll.hide()
	_hex_choice_separator = HSeparator.new()
	_hex_choice_separator.modulate = Color(0.996, 0.169, 0.592, 0.7)
	content.add_child(_hex_choice_separator)
	content.move_child(_hex_choice_separator, _hex_choice_detail_scroll.get_index() + 1)
	_hex_choice_separator.hide()


func _set_hex_revelation_details(coord: Vector2i) -> bool:
	_hex_choice_detail_scroll.hide()
	_hex_choice_separator.hide()
	if gerencia == null or gerencia.campaign.current_map == null:
		return false
	var grid := gerencia.campaign.current_map
	var cell := grid.get_cell(coord)
	if cell == null or cell.state != HexGrid.PPPBlockState.REVEALED:
		return false
	var content := grid.get_ppp_block_resource(coord)
	if content == null:
		return false
	var title: String = content.titulo if content is Informacao else content.display_name
	hex_choice_title.text = "ⓘ %s · %s" % [title, _hex_classification(content)]
	hex_choice_title.add_theme_font_size_override("font_size", 13)
	hex_choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hex_choice_detail.text = _revealed_effect_description(coord, content)
	_hex_choice_detail_scroll.custom_minimum_size.y = minf(138.0,
		maxf(22.0, ceilf(float(_hex_choice_detail.text.length()) / 43.0) * 22.0))
	_hex_choice_detail_scroll.visible = not _hex_choice_detail.text.is_empty()
	_hex_choice_separator.show()
	hex_title_popup.hide()
	return true


func _on_hex_overlay_pressed(coord: Vector2i, screen_position: Vector2,
		event: InputEvent) -> void:
	if gerencia == null or gerencia.map_view == null:
		return
	if not _in_combat():
		gerencia.map_view._on_cell_pressed(coord, event)
		return
	# Uma intenção escolhida no HUD tem precedência sobre a sobreposição
	# visual entre o corpo de uma entidade e o hex sob o cursor.
	if combat_manager != null and combat_manager.action_mode == &"move":
		gerencia.map_view.request_combat_selection(coord)
		return
	if combat_manager != null and combat_manager.action_mode in [&"attack", &"skill"]:
		var pointer_enemies := combat_manager.get_enemies_under_pointer(screen_position)
		if not pointer_enemies.is_empty():
			gerencia.map_view.request_combat_selection(pointer_enemies[0].position)
			return
		gerencia.map_view.request_combat_selection(coord)
		return
	var entities: Array[EntityState] = []
	if combat_manager != null:
		entities.append_array(combat_manager.get_enemies_under_pointer(screen_position))
	for index in _map_hit_buttons.size():
		var card := cards[index]
		if _map_hit_buttons[index].visible and card.state != null \
				and card.state.current_health > 0 \
				and _map_hit_buttons[index].get_global_rect().has_point(screen_position) \
				and card.state not in entities:
			entities.append(card.state)
	for companion in gerencia.campaign.companion_states:
		var hit := _companion_map_hit_buttons.get(companion.instance_id) as Button
		if hit != null and hit.visible and companion.current_health > 0 \
				and hit.get_global_rect().has_point(screen_position) \
				and companion not in entities:
			entities.append(companion)
	if entities.is_empty():
		gerencia.map_view._on_cell_pressed(coord, event)
		return
	_hide_hex_choice()
	_clear_buttons(hex_choice_buttons)
	hex_choice_title.text = "ESCOLHA UMA AÇÃO"
	var tile_button := _make_choice_button("REPOSICIONAR", Color(0.11, 0.43, 0.17))
	tile_button.disabled = not combat_manager.can_player_move(coord)
	tile_button.tooltip_text = "Hex ocupado ou fora do alcance." if tile_button.disabled \
		else "Mover-se para o hex destacado em ciano."
	tile_button.mouse_entered.connect(
		gerencia.map_view.preview_combat_destination.bind(coord))
	tile_button.pressed.connect(_on_combat_overlap_hex.bind(coord))
	hex_choice_buttons.add_child(tile_button)
	for entity in entities:
		if entity in combat_manager.enemies:
			var attack_button := _make_choice_button(
				"ATACAR · %s" % entity.visible_name().to_upper(),
				Color(0.55, 0.10, 0.12))
			attack_button.disabled = not combat_manager.can_player_attack(entity.position)
			attack_button.tooltip_text = "Jogue o dado para atacar." \
				if not combat_manager.has_rolled_turn_die() else \
				"Alvo fora do alcance ou ataque indisponível." if attack_button.disabled \
				else "Atacar %s." % entity.visible_name()
			attack_button.pressed.connect(_on_combat_overlap_attack.bind(entity))
			hex_choice_buttons.add_child(attack_button)
		else:
			for grant in skill_manager.get_active_grants(combat_manager.current_actor):
				var skill := grant.skill as ActiveSkillData
				if not _is_ally_target_skill(skill):
					continue
				var skill_button := _make_choice_button(skill.display_name,
					Color(0.52, 0.36, 0.055), "skill")
				skill_button.disabled = not skill_manager.can_use_combat_active(
					combat_manager.current_actor, grant, gerencia.campaign,
					combat_manager, entity)
				_add_combat_use_count(skill_button, grant)
				skill_button.pressed.connect(_on_combat_ally_skill_pressed.bind(
					combat_manager.current_actor, grant, entity))
				hex_choice_buttons.add_child(skill_button)
	hex_choice.show()
	_position_hex_choice(screen_position + Vector2(16.0, -10.0))


func _on_combat_overlap_hex(coord: Vector2i) -> void:
	_on_confirm_walk(coord)


func _on_combat_overlap_attack(entity: EntityState) -> void:
	_hide_hex_choice()
	if entity != null and combat_manager != null \
			and combat_manager.can_player_attack(entity.position):
		combat_manager.player_attack(entity.position)
		if _open_card != null:
			_rebuild_action_buttons()


func _on_combat_overlap_entity(entity: EntityState) -> void:
	_hide_hex_choice()
	if entity in combat_manager.enemies:
		gerencia.map_view.request_combat_selection(entity.position)
	elif entity in gerencia.campaign.companion_states:
		_show_companion_combat_actions(entity, _companion_body_rect(entity))
	else:
		var index := gerencia.campaign.active_entity_states.find(entity)
		if index >= 0 and index < cards.size():
			_on_map_actor_pressed(index)


func _update_map_hit_targets() -> void:
	var party := get_parent().get_node_or_null("MapRoot/DepthSorted/PlayableActors") \
		as PlayablePartyView
	for index in _map_hit_buttons.size():
		var hit := _map_hit_buttons[index]
		var card := cards[index]
		var visual: PlayableActorVisual = null
		if party != null and card.state != null and card.state.current_health > 0:
			visual = party.visuals_by_slot.get(card.state.playable_slot_id) \
				as PlayableActorVisual
		if visual == null or visual.state != card.state or visual.data == null \
				or visual.data.playable_animation == null:
			hit.hide()
			continue
		var sprite := visual.animated_sprite
		var transform := sprite.get_global_transform_with_canvas()
		var frame := visual.data.playable_animation.frame_size
		# Só a silhueta central é clicável, para não roubar os hexes vizinhos.
		var bounds := Vector2(float(frame.x) * absf(transform.x.x) * 0.65,
			float(frame.y) * absf(transform.y.y) * 0.88)
		hit.position = transform.origin - bounds * 0.5
		hit.size = bounds
		hit.show()
	_update_companion_map_hit_targets()
	_update_map_debuff_hit_targets()
	if _hex_click_overlay != null:
		_hex_click_overlay.excluded_rects.clear()
		for hit in _map_debuff_hit_buttons.values():
			if hit is Button and hit.visible:
				_hex_click_overlay.excluded_rects.append(hit.get_global_rect())
		if not _in_combat():
			for hit in _companion_map_hit_buttons.values():
				if hit is Button and hit.visible:
					_hex_click_overlay.excluded_rects.append(hit.get_global_rect())
		map_hit_targets.move_child(_hex_click_overlay,
			map_hit_targets.get_child_count() - 1)


func _update_map_debuff_hit_targets() -> void:
	var active_ids: Dictionary = {}
	for visual in get_tree().get_nodes_in_group("map_entity_visual"):
		var marker := visual.get_node_or_null("DebuffMarker") as Node2D
		if marker == null:
			continue
		for target in marker.call("get_inspection_targets"):
			var instance := target.get("instance") as DebuffInstanceState
			if instance == null:
				continue
			var id := instance.get_instance_id()
			active_ids[id] = true
			var hit := _map_debuff_hit_buttons.get(id) as Button
			if hit == null:
				hit = Button.new()
				hit.name = "MapDebuff_%d" % id
				hit.flat = true
				hit.focus_mode = Control.FOCUS_NONE
				hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				hit.modulate.a = 0.0
				hit.mouse_entered.connect(_on_map_debuff_hover.bind(instance, hit))
				hit.mouse_exited.connect(_on_debuff_hover_ended)
				hit.pressed.connect(_on_map_debuff_click.bind(instance, hit))
				map_hit_targets.add_child(hit)
				_map_debuff_hit_buttons[id] = hit
			var bounds: Rect2 = target["rect"]
			hit.position = bounds.position
			hit.size = bounds.size
			hit.show()
	for id in _map_debuff_hit_buttons.keys():
		if not active_ids.has(id):
			(_map_debuff_hit_buttons[id] as Button).queue_free()
			_map_debuff_hit_buttons.erase(id)


func _on_map_debuff_hover(instance: DebuffInstanceState, hit: Button) -> void:
	_on_debuff_inspection_requested(instance, hit.get_global_rect(), false)


func _on_map_debuff_click(instance: DebuffInstanceState, hit: Button) -> void:
	_on_debuff_inspection_requested(instance, hit.get_global_rect(), true)


func _update_companion_map_hit_targets() -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	var active_ids: Dictionary = {}
	for companion in gerencia.campaign.companion_states:
		if companion == null or companion.current_health <= 0 \
				or (_in_combat() and companion.position == EntityState.UNPLACED):
			continue
		var bounds := _companion_body_rect(companion)
		if bounds.size == Vector2.ZERO:
			continue
		active_ids[companion.instance_id] = true
		var hit := _companion_map_hit_buttons.get(companion.instance_id) as Button
		if hit == null:
			hit = Button.new()
			hit.name = "MapCompanion_%s" % companion.instance_id
			hit.flat = true
			hit.focus_mode = Control.FOCUS_NONE
			hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			hit.modulate.a = 0.0
			hit.pressed.connect(_on_map_companion_pressed.bind(companion))
			hit.gui_input.connect(_on_companion_map_input.bind(companion))
			map_hit_targets.add_child(hit)
			_companion_map_hit_buttons[companion.instance_id] = hit
		hit.position = bounds.position
		hit.size = bounds.size
		hit.show()
	for id in _companion_map_hit_buttons.keys():
		if not active_ids.has(id):
			(_companion_map_hit_buttons[id] as Button).hide()


func _companion_body_rect(companion: EntityState) -> Rect2:
	var view := get_parent().get_node_or_null("MapRoot/DepthSorted/CompanionActors") \
		as CompanionPartyView
	if view != null:
		var ground := view.ground_silhouettes_by_id.get(companion.instance_id) \
			as EnemySilhouetteVisual
		if ground != null and ground.visible:
			var ground_transform := ground.get_global_transform_with_canvas()
			var ground_size := Vector2(60.0 * absf(ground_transform.x.x),
				145.0 * absf(ground_transform.y.y))
			return Rect2(ground_transform.origin - Vector2(
				ground_size.x * 0.5, ground_size.y), ground_size)
		var visual := view.visuals_by_id.get(companion.instance_id) as CompanionActorVisual
		if visual != null and visual.visible and visual.sprite != null:
			var sprite := visual.sprite
			var transform := sprite.get_global_transform_with_canvas()
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,
				sprite.frame) if sprite.sprite_frames != null else null
			if texture == null:
				return Rect2()
			var texture_id := texture.get_instance_id()
			if not _companion_frame_bounds.has(texture_id):
				_companion_frame_bounds[texture_id] = texture.get_image().get_used_rect()
			var used: Rect2i = _companion_frame_bounds[texture_id]
			if not used.has_area():
				return Rect2()
			var local_center := Vector2(used.position) + Vector2(used.size) * 0.5 \
				- texture.get_size() * 0.5
			if sprite.flip_h:
				local_center.x = -local_center.x
			var center := transform * local_center
			var size := Vector2(maxf(28.0, used.size.x * absf(transform.x.x) * 1.08),
				maxf(28.0, used.size.y * absf(transform.y.y) * 1.08))
			return Rect2(center - size * 0.5, size)
	if combat_manager != null and combat_manager.enemy_visual_root != null:
		for child in combat_manager.enemy_visual_root.get_children():
			var silhouette := child as EnemySilhouetteVisual
			if silhouette != null and silhouette.state == companion:
				var transform := silhouette.get_global_transform_with_canvas()
				var size := Vector2(56.0 * absf(transform.x.x),
					130.0 * absf(transform.y.y))
				return Rect2(transform.origin - Vector2(size.x * 0.5, size.y), size)
	return Rect2()


func _on_card_inspect_requested(card: PartyCharacterCard) -> void:
	if card.state == null or card.state.current_health <= 0:
		return
	var rect := card.portrait.get_global_rect()
	_show_inspect_bubble(card.state, Vector2(rect.end.x + 4.0, rect.position.y - 4.0))


func _on_map_actor_pressed(index: int) -> void:
	var card := cards[index]
	if card.state == null or card.state.current_health <= 0:
		return
	var rect := _map_hit_buttons[index].get_global_rect()
	if _in_combat() and _show_combat_ally_target_choices(card.state,
			rect.end + Vector2(8.0, -8.0)):
		return
	_show_inspect_bubble(card.state, Vector2(rect.end.x - 4.0, rect.position.y - 4.0))


func _on_map_companion_pressed(companion: EntityState) -> void:
	if _suppress_companion_click:
		_suppress_companion_click = false
		return
	var hit := _companion_map_hit_buttons.get(companion.instance_id) as Button
	if hit == null:
		return
	var rect := hit.get_global_rect()
	if _in_combat():
		_show_companion_combat_actions(companion, rect)
		return
	_show_ally_owner_badge(companion, rect)
	if _companion_exploration_actives(companion).is_empty():
		_open_character_sheet(companion, rect.get_center())
	else:
		_show_companion_exploration_actions(companion, rect)


func _companion_exploration_actives(companion: EntityState) -> Array[SkillGrantState]:
	var result: Array[SkillGrantState] = []
	if companion == null or skill_manager == null:
		return result
	for grant in skill_manager.get_active_grants(companion):
		var skill := grant.skill as ActiveSkillData
		if _is_displayed_skill(grant) and skill != null \
				and skill.use_context != ActiveSkillData.UseContext.COMBAT \
				and skill.automatic_triggers.is_empty():
			result.append(grant)
	return result


func _show_companion_exploration_actions(companion: EntityState,
		body_rect: Rect2) -> void:
	_hide_hex_choice()
	_clear_buttons(hex_choice_buttons)
	var sheet := _make_choice_button("ABRIR FICHA", Color(0.075, 0.27, 0.53))
	sheet.pressed.connect(func() -> void:
		_hide_hex_choice()
		_open_character_sheet(companion, body_rect.get_center()))
	hex_choice_buttons.add_child(sheet)
	for grant in _companion_exploration_actives(companion):
		var skill := grant.skill as ActiveSkillData
		var button := _make_choice_button(skill.display_name,
			Color(0.52, 0.36, 0.055))
		button.disabled = not _skill_is_available(companion, grant)
		button.tooltip_text = ""
		button.set_meta("skill_info_text", skill.description)
		button.pressed.connect(_on_companion_exploration_skill_pressed.bind(
			companion, grant, body_rect))
		button.mouse_entered.connect(_show_skill_info.bind(button, skill))
		button.mouse_exited.connect(_hide_skill_info)
		hex_choice_buttons.add_child(button)
	hex_choice_title.text = companion.visible_name().to_upper()
	hex_choice.show()
	hex_choice.reset_size()
	var x := body_rect.get_center().x - hex_choice.size.x * 0.5
	var y := body_rect.position.y - hex_choice.size.y - 68.0
	_position_hex_choice(Vector2(x, y))


func _on_companion_exploration_skill_pressed(companion: EntityState,
		grant: SkillGrantState, body_rect: Rect2) -> void:
	if not _skill_is_available(companion, grant):
		return
	var skill := grant.skill as ActiveSkillData
	if skill == null:
		return
	_hide_hex_choice()
	if skill.id == &"companion_active_001":
		_targeting_actor = companion
		_targeting_grant = grant
		_show_ally_owner_badge(companion, body_rect,
			"Escolha um hex para revelar; arrastar o Gatinho também funciona.")
		return
	if skill.target_mode == ActiveSkillData.TargetMode.TILE:
		_targeting_actor = companion
		_targeting_grant = grant
		_show_ally_owner_badge(companion, body_rect,
			"Escolha um hex para %s." % skill.display_name)
		return
	if exploration != null and exploration.player_skill_manager != null \
			and exploration.player_skill_manager.use_exploration_active(
				companion, grant, EntityState.UNPLACED, exploration):
		return
	_show_companion_exploration_actions(companion, body_rect)


func show_initiative_companion_actions(companion: EntityState, anchor: Rect2) -> void:
	if companion == null or combat_manager == null \
			or companion not in gerencia.campaign.companion_states \
			or combat_manager.current_actor != companion \
			or not combat_manager.is_player_turn():
		return
	if hex_choice.visible and _companion_actions_from_initiative \
			and _companion_action_target == companion:
		_hide_hex_choice()
		return
	_show_companion_combat_actions(companion, anchor, true)


func _show_companion_combat_actions(companion: EntityState, body_rect: Rect2,
		from_initiative: bool = false) -> void:
	if companion == null or companion.current_health <= 0 or combat_manager == null:
		return
	# A ficha lateral e a caixa contextual são alternativas, não camadas sobrepostas.
	ally_drawer.hide()
	ally_button.text = "ALIADO ▶"
	_hide_hex_choice()
	_clear_buttons(hex_choice_buttons)
	var acting := combat_manager.is_player_turn() \
		and combat_manager.current_actor == companion
	var forced_charm := acting and combat_manager.is_charm_forced_turn(companion)
	var charmed := skill_manager != null and not skill_manager.debuff_manager.can_attack(companion)
	var waiting := combat_manager._attack_animation_pending
	var rolled := combat_manager.has_rolled_turn_die() if acting else false
	var roll := _make_choice_button("JOGAR DADO" if not rolled else \
		"DADO: %d" % combat_manager._turn_die, Color(0.11, 0.43, 0.17))
	_combat_ally_roll_button = roll
	roll.disabled = not acting or waiting or not combat_manager.can_roll_player_turn_die()
	roll.pressed.connect(_on_combat_roll_pressed)
	hex_choice_buttons.add_child(roll)
	var reposition := _make_choice_button("REPOSICIONAR", Color(0.11, 0.43, 0.17))
	reposition.disabled = not acting or waiting or forced_charm or not rolled \
		or companion.stamina_remaining <= 0 or combat_manager._turn_moved
	reposition.pressed.connect(_on_combat_move_pressed)
	hex_choice_buttons.add_child(reposition)
	var attack := _make_choice_button("ATACAR", Color(0.55, 0.10, 0.12))
	attack.disabled = not acting or waiting or forced_charm or charmed or not rolled \
		or combat_manager._attacks_used >= 1 + companion.extra_attacks_this_turn
	attack.pressed.connect(_on_combat_attack_pressed)
	hex_choice_buttons.add_child(attack)
	if skill_manager != null:
		for grant in skill_manager.get_active_grants(companion):
			if not _is_displayed_skill(grant):
				continue
			var skill := grant.skill as ActiveSkillData
			var button := _make_choice_button(skill.display_name,
				Color(0.52, 0.36, 0.055))
			button.disabled = not acting or not _skill_is_available(companion, grant)
			button.tooltip_text = ""
			button.set_meta("skill_info_text", skill.description)
			button.pressed.connect(_on_companion_map_skill_pressed.bind(companion, grant))
			button.mouse_entered.connect(_show_skill_info.bind(button, skill))
			button.mouse_exited.connect(_hide_skill_info)
			hex_choice_buttons.add_child(button)
		# Preserva o atalho de habilidades do ator atual que têm este aliado
		# como alvo (por exemplo, Muro de Tijolo do Pedreiro).
		if combat_manager.is_player_turn() and gerencia != null:
			var actor := combat_manager.current_actor as EntityState
			if actor != null and actor != companion \
					and companion in combat_manager._allies_of(actor):
				for grant in skill_manager.get_active_grants(actor):
					var skill := grant.skill as ActiveSkillData
					if not _is_ally_target_skill(skill):
						continue
					var target_button := _make_choice_button(skill.display_name,
						Color(0.52, 0.36, 0.055), "skill")
					target_button.disabled = not skill_manager.can_use_combat_active(
						actor, grant, gerencia.campaign, combat_manager, companion)
					_add_combat_use_count(target_button, grant)
					target_button.tooltip_text = ""
					target_button.set_meta("skill_info_text", skill.description)
					target_button.pressed.connect(_on_combat_ally_skill_pressed.bind(
						actor, grant, companion))
					target_button.mouse_entered.connect(_show_skill_info.bind(
						target_button, skill))
					target_button.mouse_exited.connect(_hide_skill_info)
					hex_choice_buttons.add_child(target_button)
	var pass_button := _make_choice_button("PASSAR O TURNO", Color(0.24, 0.25, 0.27))
	pass_button.disabled = not acting or waiting or forced_charm
	_style_combat_pass_button(pass_button, companion)
	pass_button.pressed.connect(_on_combat_end_pressed)
	hex_choice_buttons.add_child(pass_button)
	hex_choice_title.text = companion.visible_name().to_upper() \
		if companion.data != null else "ALIADO"
	hex_choice_title.tooltip_text = ""
	_companion_action_target = companion
	_companion_action_choice_open = true
	_companion_actions_from_initiative = from_initiative
	_initiative_action_anchor = body_rect if from_initiative else Rect2()
	hex_choice.show()
	hex_choice.reset_size()
	var screen := get_viewport().get_visible_rect().size
	if from_initiative:
		var under_card := Vector2(body_rect.get_center().x - hex_choice.size.x * 0.5,
			body_rect.end.y + 9.0)
		_position_hex_choice(under_card)
		call_deferred("_refresh_initiative_action_link")
		return
	var x := clampf(body_rect.get_center().x - hex_choice.size.x * 0.5,
		6.0, maxf(6.0, screen.x - hex_choice.size.x - 6.0))
	# Prioriza a faixa livre das casas: o painel fica acima da cabeça e do
	# início visual do chão/hexágonos, sem invadir a faixa superior da UI.
	var safe_ground_y := screen.y * 0.62
	var y := maxf(56.0, minf(body_rect.position.y - 12.0,
		safe_ground_y - 8.0) - hex_choice.size.y)
	hex_choice.position = Vector2(x, y)


func _refresh_initiative_action_link() -> void:
	if not _companion_actions_from_initiative or not hex_choice.visible \
			or _initiative_action_link == null:
		return
	_initiative_action_link.points = PackedVector2Array([
		_initiative_action_anchor.get_center() + Vector2(0.0,
			_initiative_action_anchor.size.y * 0.5),
		Vector2(_initiative_action_anchor.get_center().x,
			hex_choice.position.y - 3.0),
		Vector2(hex_choice.get_global_rect().get_center().x,
			hex_choice.position.y - 3.0),
		Vector2(hex_choice.get_global_rect().get_center().x,
			hex_choice.position.y)])
	_initiative_action_link.show()


func _combat_core_actions_exhausted(actor: EntityState) -> bool:
	if actor == null or combat_manager == null or gerencia == null \
			or not combat_manager.is_player_turn() \
			or combat_manager.current_actor != actor:
		return false
	if combat_manager.can_roll_player_turn_die():
		return false
	var grid := gerencia.campaign.current_map
	if grid == null:
		return true
	for coord in grid.cells:
		if combat_manager.can_player_move(coord):
			return false
	for enemy in combat_manager._opponents_of(actor):
		if enemy != null and enemy.current_health > 0 \
				and combat_manager.can_player_attack(enemy.position):
			return false
	return true


func _style_combat_pass_button(button: Button, actor: EntityState) -> void:
	if button == null:
		return
	var exhausted := _combat_core_actions_exhausted(actor)
	_paint_action_button(button, Color(0.68, 0.10, 0.16) \
		if exhausted else Color(0.24, 0.25, 0.27), exhausted,
		"pass" if exhausted else "")


func _show_combat_pass_only(screen_position: Vector2) -> void:
	if combat_manager == null or not combat_manager.is_player_turn():
		return
	_hide_hex_choice()
	_clear_buttons(hex_choice_buttons)
	var pass_button := _make_choice_button("PASSAR O TURNO", Color(0.68, 0.10, 0.16),
		"pass_only")
	pass_button.disabled = combat_manager._attack_animation_pending \
		or combat_manager.is_charm_forced_turn(combat_manager.current_actor)
	pass_button.pressed.connect(_on_combat_end_pressed)
	hex_choice_buttons.add_child(pass_button)
	hex_choice_title.text = "TURNO CONCLUÍDO"
	hex_choice_title.tooltip_text = ""
	hex_choice.show()
	_position_hex_choice(screen_position + Vector2(16.0, -10.0))


func _on_companion_map_skill_pressed(companion: EntityState,
		grant: SkillGrantState) -> void:
	_hide_hex_choice()
	_on_skill_pressed(companion, grant)


func _refresh_companion_action_choice() -> void:
	if not _companion_action_choice_open or not hex_choice.visible \
			or _companion_action_target == null:
		return
	var target := _companion_action_target
	if _companion_actions_from_initiative:
		_show_companion_combat_actions(target, _initiative_action_anchor, true)
		return
	var hit := _companion_map_hit_buttons.get(target.instance_id) as Button
	if hit == null or not hit.visible:
		_hide_hex_choice()
		return
	_show_companion_combat_actions(target, hit.get_global_rect())


func _pet_skill(companion: EntityState, id: StringName) -> SkillGrantState:
	if skill_manager == null or companion == null:
		return null
	for grant in skill_manager.get_active_grants(companion):
		if grant.skill != null and grant.skill.id == id:
			return grant
	return null


func _pet_visual(companion: EntityState) -> CompanionActorVisual:
	var view := get_parent().get_node_or_null("MapRoot/DepthSorted/CompanionActors") \
		as CompanionPartyView
	return view.visuals_by_id.get(companion.instance_id) as CompanionActorVisual \
		if view != null else null


func _on_companion_map_input(event: InputEvent, companion: EntityState) -> void:
	if _in_combat() or not event is InputEventMouseButton \
			or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed \
			or companion.data == null \
			or not companion.data.tags.has(&"gatinho_vira_lata"):
		return
	var visual := _pet_visual(companion)
	var grant := _pet_skill(companion, &"companion_active_001")
	if visual == null or grant == null or not _skill_is_available(companion, grant):
		return
	# Clique curto abre ações; arrastar começa só após deslocar o mouse.
	_pending_cat_visual = visual
	_pending_cat_actor = companion
	# gui_input usa coordenadas locais do botão; o limiar de arrasto usa viewport.
	var hit := _companion_map_hit_buttons.get(companion.instance_id) as Button
	_pending_cat_press = hit.get_global_transform_with_canvas() * event.position \
		if hit != null else get_viewport().get_mouse_position()


func _finish_cat_drag(screen_position: Vector2) -> void:
	var visual := _drag_pet_visual
	_drag_pet_visual = null
	if visual == null or gerencia == null or gerencia.campaign.current_map == null:
		return
	var owner := gerencia.campaign.get_playable_slot(_drop_actor.owner_instance_id) \
		if _drop_actor != null else null
	if owner == null:
		visual.cancel_mouse_drop()
		return
	var best := EntityState.UNPLACED
	var best_distance := INF
	var parent_canvas := (visual.get_parent() as CanvasItem).get_global_transform_with_canvas()
	for coord in gerencia.campaign.current_map.cells:
		if not skill_manager.can_use_exploration_active(_drop_actor, owner, _drop_grant,
				gerencia.campaign, coord, exploration.block_manager, gerencia.map_view):
			continue
		var point := parent_canvas * PPPMapView.reference_hex_position(coord)
		var distance := screen_position.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			best = coord
	if best == EntityState.UNPLACED:
		visual.cancel_mouse_drop()
		return
	# Também para soltura alta: escolhe o centro de ground elegível mais próximo.
	visual.preview_mouse_drop(best)
	_drop_preview_visual = visual
	_clear_buttons(hex_choice_buttons)
	var confirm := _make_choice_button("REVELAR AQUI", Color(0.52, 0.36, 0.055))
	confirm.pressed.connect(_confirm_cat_reveal.bind(best))
	hex_choice_buttons.add_child(confirm)
	var cancel := _make_choice_button("CANCELAR", Color(0.18, 0.18, 0.20))
	cancel.pressed.connect(_hide_hex_choice)
	hex_choice_buttons.add_child(cancel)
	hex_choice_title.text = "GATINHO · SEXTO-SENTIDO?"
	hex_choice.show()
	_ally_target_choice_open = true
	_position_hex_choice(screen_position + Vector2(14.0, -10.0))


func _clear_companion_click_suppression() -> void:
	_suppress_companion_click = false


func _confirm_cat_reveal(coord: Vector2i) -> void:
	var success := exploration != null and exploration.player_skill_manager != null \
		and exploration.player_skill_manager.use_tile_active(
			_drop_actor, _drop_grant, coord, exploration)
	if success:
		_drop_preview_visual = null
	_hide_hex_choice()


func _show_dog_skill_choice(companion: EntityState, anchor: Vector2) -> void:
	var grant := _pet_skill(companion, &"companion_active_002")
	if grant == null:
		return
	_hide_hex_choice()
	_clear_buttons(hex_choice_buttons)
	var button := _make_choice_button("VAI PEGAR!", Color(0.52, 0.36, 0.055))
	button.disabled = not _skill_is_available(companion, grant)
	button.set_meta("skill_info_text", "Indisponível agora." if button.disabled else \
		(grant.skill as ActiveSkillData).description)
	button.tooltip_text = ""
	button.pressed.connect(_on_dog_skill_confirmed.bind(companion, grant))
	button.mouse_entered.connect(_show_skill_info.bind(button, grant.skill))
	button.mouse_exited.connect(_hide_skill_info)
	hex_choice_buttons.add_child(button)
	hex_choice_title.text = "DOGUINHO"
	hex_choice.show()
	_ally_target_choice_open = true
	_position_hex_choice(anchor)


func _on_dog_skill_confirmed(companion: EntityState, grant: SkillGrantState) -> void:
	if exploration != null and exploration.player_skill_manager != null \
			and exploration.player_skill_manager.use_exploration_active(
				companion, grant, EntityState.UNPLACED, exploration):
		_hide_hex_choice()


func _show_inspect_bubble(actor: EntityState, desired: Vector2) -> void:
	if actor == null or actor.current_health <= 0:
		inspect_bubble.hide()
		return
	_inspection_actor = actor
	var screen := get_viewport().get_visible_rect().size
	inspect_bubble.position = Vector2(clampf(desired.x, 4.0, screen.x - 31.0),
		clampf(desired.y, 54.0, screen.y - 31.0))
	inspect_bubble.show()
	bubble_hint.hide()


func _show_bubble_hint() -> void:
	if not inspect_bubble.visible:
		return
	bubble_hint.show()
	bubble_hint.reset_size()
	var screen := get_viewport().get_visible_rect().size
	bubble_hint.position = Vector2(minf(inspect_bubble.position.x + 31.0,
		screen.x - bubble_hint.size.x - 5.0), inspect_bubble.position.y)


func _open_sheet_from_bubble() -> void:
	if _inspection_actor == null or _inspection_actor.current_health <= 0:
		inspect_bubble.hide()
		return
	_open_character_sheet(_inspection_actor,
		inspect_bubble.position + inspect_bubble.size * 0.5)


func _on_card_sheet_requested(card: PartyCharacterCard) -> void:
	if card.state != null:
		_open_character_sheet(card.state,
			card.get_global_rect().get_center())


func keyboard_focus_active_card() -> void:
	var actor := combat_manager.current_actor if _in_combat() and combat_manager != null \
		else exploration.current_actor if exploration != null else null
	var index := -1
	for candidate in cards.size():
		if cards[candidate].state == actor:
			index = candidate
			break
	if index < 0:
		for candidate in cards.size():
			if cards[candidate].state != null:
				index = candidate
				break
	_keyboard_set_card_index(index)


func keyboard_focus_card_delta(delta: int) -> void:
	var candidates: Array[int] = []
	for index in cards.size():
		if cards[index].state != null:
			candidates.append(index)
	if candidates.is_empty():
		return
	var position := candidates.find(_keyboard_card_index)
	_keyboard_set_card_index(candidates[posmod(position + delta, candidates.size())])


func keyboard_clear_card_focus() -> void:
	_keyboard_set_card_index(-1)


func keyboard_open_highlighted_sheet() -> void:
	if _keyboard_card_index >= 0 and cards[_keyboard_card_index].state != null:
		_on_card_sheet_requested(cards[_keyboard_card_index])


func keyboard_toggle_active_actions() -> void:
	var actor := combat_manager.current_actor if _in_combat() and combat_manager != null \
		else exploration.current_actor if exploration != null else null
	for card in cards:
		if card.state != actor:
			continue
		_on_action_toggle_requested(card)
		if action_drawer.visible:
			_action_keyboard_navigation.reset(action_scroll)
		return


func _keyboard_set_card_index(index: int) -> void:
	_keyboard_card_index = index
	for candidate in cards.size():
		cards[candidate].set_keyboard_highlight(candidate == index)


func _open_character_sheet(actor: EntityState, anchor: Vector2) -> void:
	inspect_bubble.hide()
	bubble_hint.hide()
	_hide_stat_breakdown()
	character_sheet.open_for(actor, skill_manager, anchor)


func show_entity_sheet(actor: EntityState, anchor: Vector2) -> void:
	_open_character_sheet(actor, anchor)


func show_combat_actions_for(actor: EntityState, anchor: Rect2) -> void:
	# Atalho da ordem de iniciativa: só o ator jogável do turno atual pode
	# abrir ações. A ficha dos demais continua disponível separadamente.
	if actor == null or combat_manager == null \
			or not combat_manager.is_player_turn() \
			or combat_manager.current_actor != actor:
		return
	if actor in gerencia.campaign.companion_states:
		var body_rect := _companion_body_rect(actor)
		_show_companion_combat_actions(actor,
			body_rect if body_rect.size != Vector2.ZERO else anchor)
		return
	for card in cards:
		if card.state != actor:
			continue
		if _open_card != card or not action_drawer.visible:
			_on_action_toggle_requested(card)
		else:
			_rebuild_action_buttons()
			_position_action_drawer(false)
		return


func _close_character_sheet() -> void:
	character_sheet.close_sheet()
	_hide_stat_breakdown()


func _show_stat_breakdown(actor: EntityState, stat_key: String,
		anchor: Rect2) -> void:
	_stat_hover_actor = actor
	_stat_hover_key = stat_key
	stat_tooltip_text.text = EntityStatBreakdown.colored_text(actor, stat_key)
	stat_tooltip.show()
	stat_tooltip.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var x := anchor.end.x + 7.0
	if x + stat_tooltip.size.x > screen.x - 6.0:
		x = anchor.position.x - stat_tooltip.size.x - 7.0
	stat_tooltip.position = Vector2(clampf(x, 5.0,
		maxf(5.0, screen.x - stat_tooltip.size.x - 5.0)),
		clampf(anchor.position.y, 55.0,
			maxf(55.0, screen.y - stat_tooltip.size.y - 5.0)))


func _hide_stat_breakdown() -> void:
	stat_tooltip.hide()
	_stat_hover_actor = null
	_stat_hover_key = ""


func _update_turn_border() -> void:
	var current := combat_manager.current_actor if _in_combat() and combat_manager != null \
		else exploration.current_actor if exploration != null else null
	for card in cards:
		card.set_current_turn(card.state != null and card.state == current)


func _on_action_toggle_requested(card: PartyCharacterCard) -> void:
	if card.state == null or card.state.current_health <= 0:
		return
	if exploration != null and exploration.player_skill_manager != null \
			and not exploration.player_skill_manager.get_pending_options().is_empty():
		return
	_walk_target_actor = null
	if card == _open_card:
		_close_actions()
		return
	_close_actions()
	if card.state == null:
		return
	_open_card = card
	card.set_actions_open(true)
	skill_buttons.show()
	action_hint.hide()
	action_drawer.show()
	_rebuild_action_buttons()
	_position_action_drawer(true)
	action_link.show()


func _close_actions() -> void:
	_action_keyboard_navigation.reset(action_scroll)
	_end_future_vision_targeting()
	if _action_tween != null and _action_tween.is_running():
		_action_tween.kill()
	_hide_hex_choice()
	_hide_skill_info()
	if passive_info_popup != null:
		passive_info_popup.hide()
	ally_drawer.hide()
	ally_button.text = "ALIADO ▶"
	_targeting_actor = null
	_targeting_grant = null
	_close_inventory()
	if _open_card != null:
		_open_card.set_actions_open(false)
	_open_card = null
	action_drawer.hide()
	action_link.hide()
	action_hint.hide()
	_action_signature = ""


func close_expandable_boxes() -> void:
	_close_actions()
	if character_sheet.visible:
		character_sheet.close_sheet()
	if hex_title_popup.visible:
		hex_title_popup.hide()
	if debuff_popup.visible:
		debuff_popup.hide()
	if inspect_bubble.visible:
		inspect_bubble.hide()
		bubble_hint.hide()
		_inspection_actor = null
	_hide_stat_breakdown()


func _position_separators() -> void:
	if not is_node_ready():
		return
	var root_control := $Root as Control
	for index in 2:
		var upper := cards[index].get_global_rect()
		var lower := cards[index + 1].get_global_rect()
		var divider := dividers[index]
		divider.position = Vector2(0.0,
			(upper.end.y + lower.position.y) * 0.5 - root_control.global_position.y - 2.0)
		divider.size = Vector2(root_control.size.x, 4.0)
		divider.show()


func _position_action_drawer(animate: bool) -> void:
	if _open_card == null:
		return
	if _action_tween != null and _action_tween.is_running():
		_action_tween.kill()
	action_drawer.reset_size()
	var safe_top := 68.0
	var top_bar := get_parent().get_node_or_null("CampaignTopBar/Bar") as Control
	if top_bar != null:
		safe_top = maxf(safe_top, top_bar.get_global_rect().end.y + 16.0)
	var safe_bottom := get_viewport().get_visible_rect().size.y - 16.0
	if gerencia != null and gerencia.map_view != null:
		safe_bottom = minf(safe_bottom,
			gerencia.map_view.get_ground_screen_top() - 16.0)
	# O scroll absorve a diferença em janelas baixas; nenhuma das três caixas
	# muda de faixa conforme a posição do retrato na lateral.
	var chrome_height := action_drawer.size.y - action_scroll.custom_minimum_size.y
	var allowed_scroll := maxf(70.0, safe_bottom - safe_top - chrome_height - 30.0)
	if action_scroll.custom_minimum_size.y > allowed_scroll:
		action_scroll.custom_minimum_size.y = allowed_scroll
		action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_arrows.show()
		_action_visible_limit = 0
		var used_height := 0.0
		for button in _action_buttons():
			var next_height := _button_height(button) + (4.0 if _action_visible_limit > 0 else 0.0)
			if used_height + next_height > allowed_scroll and _action_visible_limit > 0:
				break
			used_height += next_height
			_action_visible_limit += 1
		_scroll_first_index = clampi(_scroll_first_index, 0,
			maxi(0, _action_buttons().size() - _action_visible_limit))
		_update_scroll_arrow_state()
		action_drawer.reset_size()
	var desired_y := safe_top + 10.0 + float(cards.find(_open_card)) * 32.0
	var root := $Root as Control
	var destination := Vector2(root.position.x + root.size.x + 24.0,
		clampf(desired_y, safe_top, maxf(safe_top, safe_bottom - action_drawer.size.y)))
	if animate:
		action_drawer.position = destination - Vector2(16.0, 0.0)
		action_drawer.modulate.a = 0.0
		_action_tween = create_tween().set_parallel(true)
		_action_tween.tween_property(action_drawer, "position", destination, 0.17) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_action_tween.tween_property(action_drawer, "modulate:a", 1.0, 0.17)
	else:
		action_drawer.position = destination
		action_drawer.modulate.a = 1.0
	_update_connectors()
	if ally_drawer.visible:
		_queue_ally_drawer_position()
	if inventory_panel.visible:
		_position_inventory_panel(false)


func _position_inventory_panel(animate: bool) -> void:
	if not inventory_panel.visible or _open_card == null:
		return
	if _inventory_tween != null and _inventory_tween.is_running():
		_inventory_tween.kill()
	# O Container pode mudar sua largura depois do primeiro frame. Usamos no
	# mínimo o tamanho declarado para a caixa nunca encostar na de ações.
	action_drawer.reset_size()
	inventory_panel.reset_size()
	var scaled_height := inventory_panel.size.y * inventory_panel.scale.y
	var desired_y := action_drawer.position.y + action_drawer.size.y * 0.5 \
		- scaled_height * 0.5
	var max_y := get_viewport().get_visible_rect().size.y - scaled_height - 6.0
	# A caixa de inventário nunca invade a faixa superior (até Y=51).
	var action_width := maxf(action_drawer.size.x, action_drawer.custom_minimum_size.x)
	var destination := Vector2(action_drawer.position.x + action_width + 14.0,
		clampf(desired_y, 56.0, maxf(56.0, max_y)))
	if animate:
		inventory_panel.position = destination - Vector2(16.0, 0.0)
		inventory_panel.modulate.a = 0.0
		_inventory_tween = create_tween().set_parallel(true)
		_inventory_tween.tween_property(inventory_panel, "position", destination, 0.17) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_inventory_tween.tween_property(inventory_panel, "modulate:a", 1.0, 0.17)
	else:
		inventory_panel.position = destination
		inventory_panel.modulate.a = 1.0
	_update_connectors()
	if item_details_panel.visible:
		_position_item_details(false)


func _position_item_details(animate: bool) -> void:
	if not item_details_panel.visible or not inventory_panel.visible:
		return
	if item_details_panel.user_positioned:
		_update_connectors()
		return
	if _details_tween != null and _details_tween.is_running():
		_details_tween.kill()
	inventory_panel.reset_size()
	var inventory_rect := inventory_panel.get_global_rect()
	var source_rect := item_menu.menu.get_global_rect() if item_menu.visible \
		and item_menu.menu.visible else inventory_rect
	var viewport_size := get_viewport().get_visible_rect().size
	var x := source_rect.end.x + 12.0
	var fits_right := x + item_details_panel.custom_minimum_size.x <= viewport_size.x - 8.0
	if not fits_right:
		# Sem espaço lateral, a ficha cresce acima ou abaixo do menu.
		x = clampf(source_rect.position.x, 8.0,
			maxf(8.0, viewport_size.x - item_details_panel.custom_minimum_size.x - 8.0))
	var details_right := x + item_details_panel.custom_minimum_size.x
	var min_y := 56.0
	# Dado e moeda são provisórios; os detalhes podem cobri-los. Apenas a
	# faixa permanente de dia/horário/distrito precisa continuar livre.
	var bottom_limit := viewport_size.y - 6.0
	var phase_button := get_parent().get_node_or_null("RoundUI/NextPhaseButton") as Button
	if phase_button != null and phase_button.visible:
		var phase_rect := phase_button.get_global_rect()
		if phase_rect.position.x < details_right and phase_rect.end.x > x:
			bottom_limit = minf(bottom_limit, phase_rect.position.y - 8.0)
	var below_room := bottom_limit - source_rect.end.y - 10.0
	var above_room := source_rect.position.y - min_y - 10.0
	var place_below := below_room >= above_room
	var available_height := bottom_limit - min_y if fits_right else \
		maxf(above_room, below_room)
	item_details_panel.fit_height(maxf(200.0, available_height))
	var max_y := bottom_limit - item_details_panel.size.y
	var proposed_y := source_rect.position.y if fits_right else \
		(source_rect.end.y + 10.0 if place_below else \
		source_rect.position.y - item_details_panel.size.y - 10.0)
	var destination := Vector2(x,
		clampf(proposed_y, min_y, maxf(min_y, max_y)))
	if animate:
		item_details_panel.position = destination - Vector2(16.0, 0.0)
		item_details_panel.modulate.a = 0.0
		_details_tween = create_tween().set_parallel(true)
		_details_tween.tween_property(item_details_panel, "position", destination, 0.17) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_details_tween.tween_property(item_details_panel, "modulate:a", 1.0, 0.17)
	else:
		item_details_panel.position = destination
		item_details_panel.modulate.a = 1.0
	_update_connectors()


func _update_connectors() -> void:
	if _open_card == null or not action_drawer.visible:
		return
	var card_rect := _open_card.get_global_rect()
	var drawer_rect := action_drawer.get_global_rect()
	action_link.points = _stepped_link(Vector2(card_rect.end.x, card_rect.get_center().y),
		Vector2(drawer_rect.position.x, drawer_rect.get_center().y))
	if inventory_panel.visible:
		var inventory_rect := inventory_panel.get_global_rect()
		inventory_link.points = _stepped_link(Vector2(drawer_rect.end.x,
			drawer_rect.get_center().y), Vector2(inventory_rect.position.x,
			inventory_rect.get_center().y))
		if item_details_panel.visible:
			var details_rect := item_details_panel.get_global_rect()
			var source_rect := item_menu.menu.get_global_rect() if item_menu.visible \
				and item_menu.menu.visible else inventory_rect
			if details_rect.position.y >= source_rect.end.y:
				item_details_link.points = _vertical_stepped_link(
					Vector2(source_rect.get_center().x, source_rect.end.y),
					Vector2(details_rect.get_center().x, details_rect.position.y))
			elif details_rect.end.y <= source_rect.position.y:
				item_details_link.points = _vertical_stepped_link(
					Vector2(source_rect.get_center().x, source_rect.position.y),
					Vector2(details_rect.get_center().x, details_rect.end.y))
			else:
				item_details_link.points = _stepped_link(Vector2(source_rect.end.x,
					source_rect.get_center().y), Vector2(details_rect.position.x,
					details_rect.get_center().y))


func _vertical_stepped_link(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var middle_y := (start.y + finish.y) * 0.5
	return PackedVector2Array([start, Vector2(start.x, middle_y),
		Vector2(finish.x, middle_y), finish])


func _stepped_link(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var first_x := lerpf(start.x, finish.x, 0.33)
	var second_x := lerpf(start.x, finish.x, 0.67)
	# Mesmo com caixas alinhadas, o pequeno degrau continua visível.
	var step_y := finish.y if absf(finish.y - start.y) > 8.0 else start.y + 12.0
	return PackedVector2Array([start, Vector2(first_x, start.y),
		Vector2(first_x, step_y), Vector2(second_x, step_y),
		Vector2(second_x, finish.y), finish])


func _rebuild_action_buttons() -> void:
	if _open_card == null or _open_card.state == null:
		return
	var actor := _open_card.state
	action_title.text = "◎ ◎ ◎ ◎"
	walk_button.disabled = not _open_card.is_available() or exploration == null
	inventory_button.disabled = false
	_clear_buttons(skill_buttons)
	_clear_buttons(ally_skill_buttons)
	_clear_buttons(passive_buttons)
	if _in_combat():
		_set_ally_drawer_exploration_mode(false)
		var acting := combat_manager != null and combat_manager.current_actor == actor \
			and combat_manager.is_player_turn()
		var forced_charm := acting and combat_manager.is_charm_forced_turn(actor)
		var charmed := skill_manager != null and not skill_manager.debuff_manager.can_attack(actor)
		var waiting_for_move := combat_manager != null \
			and combat_manager._attack_animation_pending
		var rolled := combat_manager != null and combat_manager.has_rolled_turn_die()
		var can_roll := combat_manager != null and combat_manager.can_roll_player_turn_die()
		walk_button.text = "CHARME: CAMINHANDO" if forced_charm else \
			("JOGAR DADO" if can_roll else "DADOS ESGOTADOS") if not rolled \
			else "DADO %d · SOMA %d" % [
			combat_manager._turn_die, actor.attack + combat_manager._turn_die]
		walk_button.disabled = not acting or not can_roll or waiting_for_move
		_paint_action_button(walk_button, Color(0.11, 0.43, 0.17), false, "core")
		var reposition := _make_choice_button("REPOSICIONAR", Color(0.11, 0.43, 0.17))
		reposition.disabled = not acting or waiting_for_move or forced_charm or not rolled or actor.stamina_remaining <= 0 \
			or combat_manager._turn_moved
		if not rolled:
			reposition.tooltip_text = "Jogue o dado antes de se mover."
		reposition.pressed.connect(_on_combat_move_pressed)
		skill_buttons.add_child(reposition)
		var attack_button := _make_choice_button("ATACAR", Color(0.55, 0.10, 0.12))
		attack_button.disabled = not acting or waiting_for_move or forced_charm or charmed or not rolled or combat_manager._attacks_used >= \
			1 + actor.extra_attacks_this_turn
		if not rolled:
			attack_button.tooltip_text = "Jogue o dado antes de atacar."
		attack_button.pressed.connect(_on_combat_attack_pressed)
		skill_buttons.add_child(attack_button)
		_combat_pass_button.show()
		_combat_pass_button.disabled = not acting or waiting_for_move or forced_charm
		_style_combat_pass_button(_combat_pass_button, actor)
		if skill_manager != null:
			for grant in skill_manager.get_active_grants(actor):
				if _is_displayed_skill(grant):
					_add_skill_button(skill_buttons, actor, grant)
		_add_passive_buttons(actor)
		var combat_companions := gerencia.campaign.get_companions_for_owner(actor.instance_id)
		ally_button.visible = not combat_companions.is_empty()
		ally_button.disabled = false
		_refresh_ally_info(combat_companions)
		if not combat_companions.is_empty():
			_build_combat_ally_buttons(combat_companions[_ally_selected_index])
		else:
			ally_drawer.hide()
		if acting:
			action_hint.text = "Aguarde o movimento terminar." if waiting_for_move \
				else "Ataques concluídos. Passe o turno." if not rolled and not can_roll \
				else "Jogue o dado para mover e/ou atacar. A Estamina será restaurada." \
					if not rolled and combat_manager._attacks_used > 0 \
				else "Jogue o dado para mover e/ou atacar." if not rolled \
				else "Ataque %d + dado %d = %d. Pode andar até %d hexes pela Estamina." % [
					actor.attack, combat_manager._turn_die,
					actor.attack + combat_manager._turn_die, actor.stamina_remaining]
			action_hint.show()
		else:
			action_hint.hide()
		_action_signature = _skill_list_signature(actor)
		_update_action_scroll()
		_update_ally_scroll()
		return
	_combat_pass_button.hide()
	_paint_action_button(walk_button, Color(0.11, 0.43, 0.17))
	walk_button.text = "ANDAR ATÉ"
	var listed := 0
	if skill_manager != null:
		for grant in skill_manager.get_active_grants(actor):
			if not _is_displayed_skill(grant):
				continue
			_add_skill_button(skill_buttons, actor, grant)
			listed += 1
	if actor.future_vision_uses > 0:
		var vision_button := _make_choice_button(
			"VISÃO DO FUTURO (%d)" % actor.future_vision_uses,
			Color(0.52, 0.36, 0.055), "skill")
		vision_button.disabled = not _open_card.is_available() \
			or exploration == null or exploration.current_actor != actor
		vision_button.tooltip_text = "Escolha qualquer bloco oculto do mapa para revelar seu tipo e efeito. Não há limite de alcance."
		vision_button.pressed.connect(_begin_future_vision_targeting.bind(actor))
		skill_buttons.add_child(vision_button)
		listed += 1
	if gerencia != null and gerencia.campaign != null \
			and actor.premonition_round_index == gerencia.campaign.get_round_index():
		var premonition_button := _make_choice_button("PREMONIÇÃO",
			Color(0.52, 0.36, 0.055), "skill")
		premonition_button.disabled = not _open_card.is_available() \
			or exploration == null or exploration.current_actor != actor \
			or actor.premonition_used_turn_serial == actor.turn_serial
		premonition_button.tooltip_text = "Uma revelação por turno, em qualquer hex oculto, até o fim da Rodada."
		premonition_button.pressed.connect(_begin_future_vision_targeting.bind(actor, true))
		skill_buttons.add_child(premonition_button)
		listed += 1
	var companions: Array[EntityState] = []
	if gerencia != null and gerencia.campaign != null:
		for companion in gerencia.campaign.companion_states:
			if companion != null and companion.current_health > 0:
				companions.append(companion)
	_set_ally_drawer_exploration_mode(true)
	ally_button.visible = not companions.is_empty()
	ally_button.disabled = false
	_refresh_ally_roster(companions)
	if companions.is_empty():
		ally_drawer.hide()
		ally_button.text = "ALIADO ▶"
	action_hint.visible = listed == 0
	action_hint.text = "Sem Ativa de Exploração." if listed == 0 else ""
	_add_passive_buttons(actor)
	_action_signature = _skill_list_signature(actor)
	_update_action_scroll()
	_update_ally_scroll()
	if ally_drawer.visible:
		_queue_ally_drawer_position()


func _build_ally_info() -> void:
	# A caixa-filha pertence ao Aliado, mas fica ligada à caixa de ações do dono.
	# Um seletor evita misturar habilidades/equipamentos quando há vários aliados.
	var content := ally_drawer.get_node("Margin/Content") as VBoxContainer
	(content.get_node("Title") as Label).text = "ALIADO"
	ally_drawer.custom_minimum_size.x = 326.0
	_ally_info = VBoxContainer.new()
	_ally_info.name = "AllyInfo"
	_ally_info.add_theme_constant_override("separation", 7)
	content.add_child(_ally_info)
	content.move_child(_ally_info, 1)
	_ally_roster = VBoxContainer.new()
	_ally_roster.name = "AllyRoster"
	_ally_roster.add_theme_constant_override("separation", 5)
	content.add_child(_ally_roster)
	content.move_child(_ally_roster, 1)
	_ally_roster.hide()
	_ally_select = OptionButton.new()
	_ally_select.item_selected.connect(_on_ally_selected)
	_ally_info.add_child(_ally_select)
	var identity_row := HBoxContainer.new()
	identity_row.name = "IdentityRow"
	identity_row.add_theme_constant_override("separation", 12)
	_ally_info.add_child(identity_row)
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(84, 100)
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.025, 0.045, 0.055, 0.96)
	portrait_style.border_color = Color(0.20, 0.76, 0.87, 0.88)
	portrait_style.set_border_width_all(1)
	portrait_style.set_content_margin_all(5)
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	identity_row.add_child(portrait_frame)
	_ally_portrait = TextureRect.new()
	_ally_portrait.custom_minimum_size = Vector2(72, 88)
	_ally_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ally_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ally_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ally_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_ally_portrait)
	_ally_stats = Label.new()
	_ally_stats.name = "AllyStats"
	_ally_stats.custom_minimum_size.x = 200.0
	_ally_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ally_stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ally_stats.add_theme_font_size_override("font_size", 13)
	_ally_stats.add_theme_color_override("font_color", Color(0.88, 0.94, 0.96))
	identity_row.add_child(_ally_stats)
	var name_row := HBoxContainer.new()
	name_row.name = "NameRow"
	name_row.add_theme_constant_override("separation", 6)
	_ally_info.add_child(name_row)
	_ally_summary = Label.new()
	_ally_summary.name = "AllyName"
	_ally_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ally_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ally_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ally_summary.add_theme_font_override("font", preload("res://fonts/UbuntuSans-Bold.ttf"))
	_ally_summary.add_theme_font_size_override("font_size", 15)
	_ally_summary.add_theme_color_override("font_color", Color(0.34, 0.88, 0.94))
	name_row.add_child(_ally_summary)
	_ally_info_button = Button.new()
	_ally_info_button.name = "AllyInfoButton"
	_ally_info_button.text = "ⓘ"
	_ally_info_button.tooltip_text = "Ficha e descrições das habilidades do aliado"
	_ally_info_button.custom_minimum_size = Vector2(32, 30)
	_ally_info_button.pressed.connect(_on_ally_info_pressed)
	name_row.add_child(_ally_info_button)
	var skills_heading := Label.new()
	skills_heading.name = "SkillsHeading"
	skills_heading.text = "HABILIDADES ATIVAS"
	skills_heading.add_theme_font_size_override("font_size", 11)
	skills_heading.add_theme_color_override("font_color", Color(0.50, 0.86, 0.91))
	content.add_child(skills_heading)
	content.move_child(skills_heading, 2)
	var equipment_section := VBoxContainer.new()
	equipment_section.name = "AllyEquipmentSection"
	equipment_section.add_theme_constant_override("separation", 5)
	content.add_child(equipment_section)
	content.move_child(equipment_section, 4)
	var equipment_heading := Label.new()
	equipment_heading.text = "EQUIPADOS"
	equipment_heading.add_theme_font_size_override("font_size", 11)
	equipment_heading.add_theme_color_override("font_color", Color(0.50, 0.86, 0.91))
	equipment_section.add_child(equipment_heading)
	_ally_equipment = HBoxContainer.new()
	_ally_equipment.add_theme_constant_override("separation", 6)
	equipment_section.add_child(_ally_equipment)


func _set_ally_drawer_exploration_mode(exploration_mode: bool) -> void:
	if _ally_roster == null:
		return
	var content := ally_drawer.get_node("Margin/Content") as VBoxContainer
	(content.get_node("Title") as Label).text = "ALIADOS" if exploration_mode else "ALIADO"
	ally_drawer.custom_minimum_size.x = 270.0 if exploration_mode else 326.0
	_ally_roster.visible = exploration_mode
	_ally_info.visible = not exploration_mode
	(content.get_node("SkillsHeading") as Label).visible = not exploration_mode
	(content.get_node("AllyEquipmentSection") as VBoxContainer).visible = not exploration_mode
	ally_scroll.visible = not exploration_mode
	ally_scroll_arrows.visible = false if exploration_mode else ally_scroll_arrows.visible


func _refresh_ally_roster(companions: Array[EntityState]) -> void:
	if _ally_roster == null:
		return
	_clear_buttons(_ally_roster)
	for companion in companions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		_ally_roster.add_child(row)
		var name_button := _make_choice_button(companion.visible_name(),
			Color(0.075, 0.27, 0.53))
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.pressed.connect(_open_character_sheet.bind(companion,
			ally_drawer.position + Vector2(ally_drawer.size.x, 18.0)))
		row.add_child(name_button)
		var info_button := _make_choice_button("ⓘ", Color(0.075, 0.27, 0.53))
		info_button.custom_minimum_size = Vector2(34.0, 35.0)
		info_button.tooltip_text = "Abrir ficha de %s" % companion.visible_name()
		info_button.pressed.connect(_open_character_sheet.bind(companion,
			ally_drawer.position + Vector2(ally_drawer.size.x, 18.0)))
		row.add_child(info_button)


func _build_ally_owner_badge() -> void:
	_ally_owner_badge = PanelContainer.new()
	_ally_owner_badge.name = "AllyOwnerBadge"
	_ally_owner_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.06, 0.93)
	style.border_color = Color(0.21, 0.78, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	_ally_owner_badge.add_theme_stylebox_override("panel", style)
	_ally_owner_badge_text = Label.new()
	_ally_owner_badge_text.add_theme_font_size_override("font_size", 11)
	_ally_owner_badge_text.add_theme_color_override("font_color", Color(0.91, 0.97, 0.98))
	_ally_owner_badge.add_child(_ally_owner_badge_text)
	add_child(_ally_owner_badge)
	_ally_owner_badge.hide()


func _show_ally_owner_badge(companion: EntityState, body_rect: Rect2,
		instruction: String = "") -> void:
	if _ally_owner_badge == null or gerencia == null:
		return
	var owner := gerencia.campaign.get_playable_slot(companion.owner_instance_id)
	_ally_owner_badge_text.text = "Aliado de %s" % owner.visible_name() \
		if owner != null else "Aliado do grupo"
	if not instruction.is_empty():
		_ally_owner_badge_text.text += "\n%s" % instruction
	_ally_owner_badge.show()
	_ally_owner_badge.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_ally_owner_badge.position = Vector2(clampf(body_rect.end.x + 8.0,
		6.0, maxf(6.0, screen.x - _ally_owner_badge.size.x - 6.0)),
		clampf(body_rect.position.y, 56.0,
			maxf(56.0, screen.y - _ally_owner_badge.size.y - 6.0)))


func _hide_ally_owner_badge() -> void:
	if _ally_owner_badge != null:
		_ally_owner_badge.hide()


func _current_ally() -> EntityState:
	if _open_card == null or _open_card.state == null or gerencia == null:
		return null
	var companions := gerencia.campaign.get_companions_for_owner(_open_card.state.instance_id)
	companions = companions.filter(func(entity: EntityState) -> bool:
		return entity.current_health > 0)
	return companions[_ally_selected_index] if _ally_selected_index < companions.size() else null


func _on_ally_selected(index: int) -> void:
	_ally_selected_index = index
	_rebuild_action_buttons()


func _on_ally_info_pressed() -> void:
	var companion := _current_ally()
	if companion != null:
		_open_character_sheet(companion, _ally_info_button.get_global_rect().get_center())


func _on_companion_added(companion: EntityState) -> void:
	if companion != null and not companion.equipment_changed.is_connected(
			_on_companion_equipment_changed):
		companion.equipment_changed.connect(_on_companion_equipment_changed)
	if _open_card != null:
		_rebuild_action_buttons()


func _on_companion_equipment_changed() -> void:
	if _open_card != null:
		_rebuild_action_buttons()
	inventory_panel.refresh()


func _refresh_ally_info(companions: Array[EntityState]) -> void:
	_ally_select.clear()
	for companion in companions:
		_ally_select.add_item(companion.visible_name())
	_ally_select.visible = companions.size() > 1
	if companions.is_empty():
		_ally_info.hide()
		return
	_ally_info.show()
	_ally_select.select(_ally_selected_index)
	var companion := companions[_ally_selected_index]
	_ally_portrait.texture = _ally_portrait_texture(companion)
	# A ficha do ⓘ apresenta as descrições; aqui fica somente o resumo legível.
	# Inimigos adestrados conservam o nome de EntityData, nunca o do Encontro.
	_ally_summary.text = companion.visible_name()
	_ally_stats.text = "VIDA: %d/%d\nATK: %d\nESTAMINA: %d\nMAESTRIA: %s" % [
		companion.current_health, companion.max_health, companion.attack,
		companion.stamina_remaining, _ally_mastery_label(companion)]
	for child in _ally_equipment.get_children():
		_ally_equipment.remove_child(child)
		child.queue_free()
	_ally_equipment.get_parent().visible = &"jogavel" in companion.data.tags
	_ally_equipment.visible = &"jogavel" in companion.data.tags
	if not _ally_equipment.visible:
		return
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		var entry := companion.primary_equipped(slot)
		var button := Button.new()
		button.name = ["", "WeaponSlot", "ArmorSlot", "AccessorySlot"][slot]
		button.custom_minimum_size = Vector2(94, 70)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name in [&"normal", &"hover", &"pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.045, 0.065, 0.08, 0.96) if style_name == &"normal" \
				else Color(0.11, 0.15, 0.18, 0.98)
			style.border_color = Color(0.67, 0.20, 0.43, 0.94) if style_name == &"normal" \
				else Color(0.98, 0.37, 0.66)
			style.set_border_width_all(1)
			style.set_corner_radius_all(3)
			button.add_theme_stylebox_override(style_name, style)
		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		icon.texture = entry.data.icon if entry != null and entry.data != null else null
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.anchor_left = 0.5
		icon.anchor_right = 0.5
		icon.offset_left = -17.0
		icon.offset_right = 17.0
		icon.offset_top = 6.0
		icon.offset_bottom = 43.0
		button.add_child(icon)
		var caption := Label.new()
		caption.name = "SlotCaption"
		caption.text = ["", "ARMA", "ARMADURA", "ACESSÓRIO"][slot]
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", Color(0.80, 0.88, 0.91))
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.anchor_right = 1.0
		caption.offset_left = 3.0
		caption.offset_right = -3.0
		caption.offset_top = 45.0
		caption.offset_bottom = 64.0
		button.add_child(caption)
		button.tooltip_text = entry.data.display_name if entry != null else "Vazio"
		button.pressed.connect(_on_ally_equipment_slot.bind(slot, button))
		_ally_equipment.add_child(button)


func _ally_mastery_label(companion: EntityState) -> String:
	var names: Array[String] = []
	for mastery in [EntityData.Mastery.BLADE, EntityData.Mastery.IMPACT,
			EntityData.Mastery.RANGED]:
		if not companion.has_mastery(mastery):
			continue
		var label := "LÂMINA" if mastery == EntityData.Mastery.BLADE else \
			"IMPACTO" if mastery == EntityData.Mastery.IMPACT else "DISTÂNCIA"
		var level := companion.get_mastery_level(mastery)
		names.append("%s +%d" % [label, level] if level > 0 else label)
	return " / ".join(names) if not names.is_empty() else "NENHUMA"


func _build_combat_ally_buttons(companion: EntityState) -> void:
	if companion == null or combat_manager == null:
		return
	if skill_manager != null:
		for grant in skill_manager.get_active_grants(companion):
			if _is_displayed_skill(grant):
				_add_skill_button(ally_skill_buttons, companion, grant)


func _ally_portrait_texture(companion: EntityState) -> Texture2D:
	if companion == null or companion.data == null:
		return null
	var data := companion.data
	if data.playable_animation != null and data.playable_animation.idle_sheet != null:
		var frame := AtlasTexture.new()
		frame.atlas = data.playable_animation.idle_sheet
		frame.region = Rect2(Vector2.ZERO, data.playable_animation.frame_size)
		return frame
	var animation := companion.get_animation_variant()
	if animation != null:
		var frames := animation.create_sprite_frames()
		if frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
			return frames.get_frame_texture(&"idle", 0)
	if data.portrait != null:
		return data.portrait
	if data.icon != null:
		return data.icon
	return data.sprite


func _on_ally_equipment_slot(slot: ItemData.EquipmentSlot, button: Button) -> void:
	var companion := _current_ally()
	if companion == null or companion.data == null \
			or &"jogavel" not in companion.data.tags \
			or gerencia == null or skill_manager == null or _open_card == null:
		return
	_close_item_details()
	item_menu.avoid_rect = ally_drawer.get_global_rect()
	var anchor := button.get_global_rect()
	var equipped := companion.primary_equipped(slot)
	if equipped != null:
		item_menu.open_companion_equipped(companion, _open_card.state, equipped,
			anchor, gerencia.campaign, skill_manager)
	else:
		item_menu.open_companion_empty_slot(companion, slot, anchor,
			gerencia.campaign, skill_manager)


func _clear_buttons(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _action_buttons() -> Array[Button]:
	var result: Array[Button] = [walk_button]
	for child in skill_buttons.get_children():
		if child is Button:
			result.append(child)
	if ally_button.visible:
		result.append(ally_button)
	result.append(inventory_button)
	if _combat_pass_button != null and _combat_pass_button.visible:
		result.append(_combat_pass_button)
	for child in passive_buttons.get_children():
		if child is Button:
			result.append(child)
	return result


func _button_height(button: Button) -> float:
	return maxf(button.custom_minimum_size.y, button.get_combined_minimum_size().y)


func _update_action_scroll() -> void:
	var buttons := _action_buttons()
	var limit := 8 if _in_combat() else 6
	_action_visible_limit = mini(buttons.size(), limit)
	var overflow := buttons.size() > limit
	# A altura é calculada por SEIS ações, mesmo quando uma Ativa tem duas
	# linhas. O restante fica cortado pela área de rolagem, nunca pela tela.
	var count := mini(buttons.size(), limit)
	var max_height := INF
	for first in range(buttons.size() - count + 1):
		var height := 4.0 * maxf(0.0, count - 1.0)
		for index in range(first, first + count):
			height += _button_height(buttons[index])
		max_height = minf(max_height, height)
	action_scroll.custom_minimum_size.y = max_height if count > 0 else 0.0
	action_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
		if overflow else ScrollContainer.SCROLL_MODE_DISABLED
	scroll_arrows.visible = overflow
	_scroll_first_index = clampi(_scroll_first_index, 0, maxi(0, buttons.size() - limit))
	_apply_action_scroll_index.call_deferred()
	_update_scroll_arrow_state()


func _button_scroll_offset(index: int) -> int:
	var buttons := _action_buttons()
	var offset := 0.0
	for before in mini(index, buttons.size()):
		offset += _button_height(buttons[before]) + 4.0
	return roundi(offset)


func _apply_action_scroll_index() -> void:
	if not is_node_ready():
		return
	action_scroll.scroll_vertical = _button_scroll_offset(_scroll_first_index)
	_update_scroll_arrow_state()


func _on_action_scroll_up() -> void:
	_scroll_first_index = maxi(0, _scroll_first_index - 1)
	_apply_action_scroll_index()


func _on_action_scroll_down() -> void:
	_scroll_first_index = mini(maxi(0, _action_buttons().size() - _action_visible_limit),
		_scroll_first_index + 1)
	_apply_action_scroll_index()


func _on_action_scroll_changed(value: float) -> void:
	if not scroll_arrows.visible:
		return
	for index in range(maxi(0, _action_buttons().size() - _action_visible_limit + 1)):
		if _button_scroll_offset(index) <= value + 2.0:
			_scroll_first_index = index
	_update_scroll_arrow_state()


func _update_scroll_arrow_state() -> void:
	scroll_up_button.disabled = _scroll_first_index == 0
	scroll_down_button.disabled = _scroll_first_index >= _action_buttons().size() - \
		_action_visible_limit


func _ally_buttons() -> Array[Button]:
	var result: Array[Button] = []
	for child in ally_skill_buttons.get_children():
		if child is Button:
			result.append(child)
	return result


func _update_ally_scroll() -> void:
	var buttons := _ally_buttons()
	var limit := 4
	var count := mini(buttons.size(), limit)
	var max_height := 0.0
	if count > 0:
		max_height = INF
		for first in range(buttons.size() - count + 1):
			var height := 4.0 * maxf(0.0, count - 1.0)
			for index in range(first, first + count):
				height += _button_height(buttons[index])
			max_height = minf(max_height, height)
	ally_scroll.custom_minimum_size.y = max_height
	var overflow := buttons.size() > limit
	ally_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO \
		if overflow else ScrollContainer.SCROLL_MODE_DISABLED
	ally_scroll_arrows.visible = overflow
	_ally_scroll_first_index = clampi(_ally_scroll_first_index, 0, maxi(0, buttons.size() - limit))
	_apply_ally_scroll_index.call_deferred()
	_update_ally_scroll_arrows()


func _ally_button_offset(index: int) -> int:
	var buttons := _ally_buttons()
	var offset := 0.0
	for before in mini(index, buttons.size()):
		offset += _button_height(buttons[before]) + 4.0
	return roundi(offset)


func _apply_ally_scroll_index() -> void:
	if not is_node_ready():
		return
	ally_scroll.scroll_vertical = _ally_button_offset(_ally_scroll_first_index)
	_update_ally_scroll_arrows()


func _on_ally_scroll_up() -> void:
	_ally_scroll_first_index = maxi(0, _ally_scroll_first_index - 1)
	_apply_ally_scroll_index()


func _on_ally_scroll_down() -> void:
	_ally_scroll_first_index = mini(maxi(0, _ally_buttons().size() - \
		4),
		_ally_scroll_first_index + 1)
	_apply_ally_scroll_index()


func _on_ally_scroll_changed(value: float) -> void:
	if not ally_scroll_arrows.visible:
		return
	for index in range(maxi(0, _ally_buttons().size() - 4 + 1)):
		if _ally_button_offset(index) <= value + 2.0:
			_ally_scroll_first_index = index
	_update_ally_scroll_arrows()


func _update_ally_scroll_arrows() -> void:
	ally_scroll_up_button.disabled = _ally_scroll_first_index == 0
	ally_scroll_down_button.disabled = _ally_scroll_first_index >= _ally_buttons().size() - \
		4


func _is_displayed_skill(grant: SkillGrantState) -> bool:
	var skill := grant.skill as ActiveSkillData
	# Também mostra as Ativas de Combate e as condicionais, em cinza enquanto
	# não existe um contexto válido. O personagem não perde uma Ativa da lista.
	return skill != null and skill.automatic_triggers.is_empty()


func _skill_list_signature(actor: EntityState) -> String:
	if actor == null or skill_manager == null or gerencia == null:
		return ""
	var ids: Array[String] = []
	ids.append("future_vision:%d" % actor.future_vision_uses)
	ids.append("premonition:%d:%d:%d" % [actor.premonition_round_index,
		actor.premonition_used_turn_serial, actor.turn_serial])
	if _in_combat() and combat_manager != null:
		# Consumir após atacar muda o limite do turno sem criar/remover Skills.
		# Isso força Atacar a sair do cinza assim que o item for consumido.
		ids.append("combat:%d:%d:%d:%d:%s" % [combat_manager._attacks_used,
			actor.extra_attacks_this_turn, actor.stamina_remaining,
			combat_manager._turn_die, str(combat_manager._turn_moved)])
	for grant in skill_manager.get_active_grants(actor):
		if _is_displayed_skill(grant):
			ids.append(str(grant.get_instance_id()))
			if _in_combat() and _shows_combat_use_count(grant.skill as ActiveSkillData):
				ids.append("uses:%s:%d" % [grant.last_used_combat_id,
					grant.uses_in_last_combat])
	for grant in skill_manager.get_passive_grants(actor):
		ids.append("passive:%s" % grant.get_instance_id())
	for companion in gerencia.campaign.get_companions_for_owner(actor.instance_id):
		if companion.current_health <= 0:
			continue
		ids.append("ally:%s" % companion.instance_id)
		for grant in skill_manager.get_active_grants(companion):
			if _is_displayed_skill(grant):
				ids.append(str(grant.get_instance_id()))
	return ",".join(ids)


func _add_skill_button(container: VBoxContainer, actor: EntityState,
		grant: SkillGrantState) -> void:
	var skill := grant.skill as ActiveSkillData
	var button := Button.new()
	button.text = _fit_skill_label(skill.display_name)
	button.custom_minimum_size.y = 46.0 if "\n" in button.text else 35.0
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	button.disabled = not _skill_is_available(actor, grant)
	_paint_action_button(button, Color(0.52, 0.36, 0.055), false,
		"skill" if gerencia != null and gerencia.campaign != null \
		and actor in gerencia.campaign.active_entity_states else "")
	_add_combat_use_count(button, grant)
	button.set_meta("skill_info_text",
		skill.description + _reveal_unavailability_note(actor, grant))
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_skill_pressed.bind(actor, grant))
	button.mouse_entered.connect(_show_skill_info.bind(button, skill))
	button.mouse_exited.connect(_hide_skill_info)
	# Toda Ativa adquirida (evento, efeito ou equipamento) conserva a origem
	# dinâmica no SkillGrantState e recebe um contorno discreto, sem criar
	# uma lista fixa de habilidades por personagem.
	if grant.source_kind != &"innate":
		for state in ["normal", "hover", "pressed"]:
			var style := button.get_theme_stylebox(state) as StyleBoxFlat
			if style != null:
				var gold := style.duplicate() as StyleBoxFlat
				gold.border_color = Color(0.96, 0.75, 0.32, 0.92)
				button.add_theme_stylebox_override(state, gold)
	button.add_theme_font_size_override("font_size", 10)
	container.add_child(button)


func _shows_combat_use_count(skill: ActiveSkillData) -> bool:
	return skill != null and skill.id in [&"playable_active_004", &"playable_active_006"]


func _add_combat_use_count(button: Button, grant: SkillGrantState) -> void:
	var skill := grant.skill as ActiveSkillData if grant != null else null
	if button == null or not _in_combat() or not _shows_combat_use_count(skill) \
			or combat_manager == null:
		return
	var spent := grant.uses_in_last_combat \
		if grant.last_used_combat_id == combat_manager._combat_id else 0
	var title := button.text
	button.text = ""
	button.custom_minimum_size.y = 49.0
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inset.offset_left = 5
	inset.offset_right = -5
	inset.offset_top = 3
	inset.offset_bottom = -3
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inset)
	var lines := VBoxContainer.new()
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", 1)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(lines)
	var name_label := Label.new()
	name_label.text = title
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color",
		Color(0.63, 0.68, 0.72) if button.disabled else Color(0.95, 0.97, 0.99))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(name_label)
	var count_label := Label.new()
	count_label.name = "CombatUses"
	count_label.text = "%d de %d gastos" % [spent, skill.max_uses_per_combat]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 9)
	count_label.add_theme_color_override("font_color",
		Color(0.59, 0.64, 0.68) if button.disabled else Color(0.87, 0.91, 0.94))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(count_label)
	button.set_meta("combat_uses_text", count_label.text)
	if not button.disabled and str(button.get_meta("action_color_intent", "")) == "skill":
		var palette := get_node_or_null("/root/UIColorManager")
		if palette != null:
			palette.call("bind_color", name_label, "font_color", "action_skill_text")
			palette.call("bind_color", count_label, "font_color", "action_skill_subtext")


func _reveal_unavailability_note(actor: EntityState, grant: SkillGrantState) -> String:
	if actor == null or grant == null or grant.skill == null \
			or (grant.skill as ActiveSkillData).id != &"playable_active_002" \
			or exploration == null or exploration.current_actor != actor \
			or actor.turn_state != EntityState.TurnState.TURNING \
			or gerencia == null or gerencia.campaign == null \
			or gerencia.campaign.current_map == null:
		return ""
	var skill := grant.skill as ActiveSkillData
	if grant.last_used_turn_serial == actor.turn_serial \
			and grant.uses_in_last_turn >= skill.max_uses_per_turn:
		return ""
	var grid := gerencia.campaign.current_map
	var radius := actor.stamina_remaining + skill.range_limit
	for coord in grid.cells:
		var cell := grid.get_cell(coord)
		if cell != null and cell.state == HexGrid.PPPBlockState.HIDDEN \
				and HexGrid.distance(actor.position, coord) <= radius:
			return ""
	return "\n\nOlhar Afiado não foi gasto pela Revelação de Espião. Não há hex oculto no alcance de Estamina + 1 agora."


func _add_passive_buttons(actor: EntityState) -> void:
	if skill_manager == null:
		return
	for grant in skill_manager.get_passive_grants(actor):
		var passive := grant.skill as PassiveSkillData
		if passive == null:
			continue
		var button := Button.new()
		var prefix := "INATO" if grant.source_kind == &"innate" else "PASSIVA"
		button.text = _fit_skill_label("◈ %s: %s  ⓘ" % [prefix, passive.display_name])
		button.custom_minimum_size.y = 56.0 if "\n" in button.text else 44.0
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		_paint_action_button(button, Color(0.27, 0.30, 0.33, 0.92))
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_show_passive_info.bind(button, passive))
		passive_buttons.add_child(button)


func _build_passive_info_popup() -> void:
	passive_info_popup = PanelContainer.new()
	passive_info_popup.name = "PassiveInfoPopup"
	passive_info_popup.custom_minimum_size.x = 305.0
	passive_info_popup.z_index = 105
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.095, 0.96)
	style.border_color = Color(0.60, 0.66, 0.70, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	passive_info_popup.add_theme_stylebox_override("panel", style)
	add_child(passive_info_popup)
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	passive_info_popup.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "VBoxContainer"
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_override("font", preload("res://fonts/UbuntuSans-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.98, 0.98, 0.98))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	var context := Label.new()
	context.name = "Context"
	context.add_theme_font_size_override("font_size", 12)
	context.add_theme_color_override("font_color", Color(0.76, 0.84, 0.89))
	content.add_child(context)
	var description := Label.new()
	description.name = "Description"
	description.custom_minimum_size.x = 280.0
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NARRATIVE_FONT.apply_label(description)
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color(0.96, 0.97, 0.98))
	content.add_child(description)
	passive_info_popup.hide()


func _show_passive_info(button: Button, passive: PassiveSkillData) -> void:
	if passive_info_popup == null or passive == null:
		return
	var content := passive_info_popup.get_node("MarginContainer/VBoxContainer") as VBoxContainer
	(content.get_node("Title") as Label).text = "◈ %s" % passive.display_name
	var use_context := "Combate"
	if passive.activation_context == PassiveSkillData.ActivationContext.EXPLORATION \
			or passive.trigger in [PassiveSkillData.Trigger.ON_ROUND_START,
				PassiveSkillData.Trigger.ON_INFORMATION_OBTAINED,
				PassiveSkillData.Trigger.ON_BLOCK_REVEALED,
				PassiveSkillData.Trigger.ON_DAY_START,
				PassiveSkillData.Trigger.ON_EXPLORATION_DESTINATION_REACHED]:
		use_context = "Exploração"
	elif passive.activation_context == PassiveSkillData.ActivationContext.ANY:
		use_context = "Combate e Exploração"
	(content.get_node("Context") as Label).text = "PASSIVA DE %s" % use_context.to_upper()
	(content.get_node("Description") as Label).text = passive.description
	passive_info_popup.modulate.a = 0.0
	passive_info_popup.show()
	get_tree().create_timer(0.035).timeout.connect(
		_position_passive_info_after_layout.bind(button.get_instance_id(), passive), CONNECT_ONE_SHOT)


func _position_passive_info_after_layout(button_id: int,
		passive: PassiveSkillData) -> void:
	var button := instance_from_id(button_id) as Button
	if not passive_info_popup.visible or passive == null or button == null:
		return
	var content := passive_info_popup.get_node("MarginContainer/VBoxContainer") as VBoxContainer
	if (content.get_node("Title") as Label).text != "◈ %s" % passive.display_name:
		return
	passive_info_popup.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var rect := button.get_global_rect()
	var x := rect.end.x + 10.0
	if x + passive_info_popup.size.x > screen.x - 15.0:
		x = rect.position.x - passive_info_popup.size.x - 10.0
	passive_info_popup.position = Vector2(clampf(x, 15.0,
		maxf(15.0, screen.x - passive_info_popup.size.x - 15.0)),
		clampf(rect.position.y, 56.0,
			maxf(56.0, screen.y - passive_info_popup.size.y - 15.0)))
	passive_info_popup.modulate.a = 1.0


func _fit_skill_label(value: String) -> String:
	var title := value.to_upper()
	if title.length() <= 25:
		return title
	var midpoint := title.length() / 2
	var best := -1
	for index in title.length():
		if title[index] == " " and (best < 0 or absi(index - midpoint) < absi(best - midpoint)):
			best = index
	return title.substr(0, best) + "\n" + title.substr(best + 1) if best > 0 else title


func _skill_is_available(actor: EntityState, grant: SkillGrantState) -> bool:
	if _in_combat():
		if combat_manager == null or skill_manager == null or gerencia == null \
				or combat_manager.current_actor != actor or not combat_manager.is_player_turn():
			return false
		var combat_skill := grant.skill as ActiveSkillData
		if combat_skill == null or combat_skill.use_context == ActiveSkillData.UseContext.EXPLORATION:
			return false
		if combat_skill.id == &"item_active_003":
			return not combat_manager._attack_animation_pending \
				and not combat_manager.is_charm_forced_turn(actor) \
				and (skill_manager.catastrophe_manager == null \
				or not skill_manager.catastrophe_manager.skills_suppressed(
					HexGrid.PPPMapMode.COMBAT, false)) \
				and skill_manager.can_attune_divine_amulet(actor, grant)
		if combat_skill.target_mode in [ActiveSkillData.TargetMode.SELF,
				ActiveSkillData.TargetMode.NONE]:
			return skill_manager.can_use_combat_active(actor, grant,
				gerencia.campaign, combat_manager)
		var targets: Array[EntityState] = combat_manager._opponents_of(actor) \
			if combat_skill.target_mode == ActiveSkillData.TargetMode.ONE_ENEMY \
			else combat_manager._allies_of(actor)
		if combat_skill.id == &"item_active_002":
			targets = gerencia.campaign.get_dead_group_members()
		if combat_skill.target_mode == ActiveSkillData.TargetMode.ONE_ENTITY:
			targets.append_array(combat_manager._opponents_of(actor))
		for target in targets:
			if skill_manager.can_use_combat_active(actor, grant,
					gerencia.campaign, combat_manager, target):
				return true
		return false
	var skill := grant.skill as ActiveSkillData if grant != null else null
	if actor != null and skill != null and skill.id == &"item_active_002" \
			and gerencia != null and exploration != null \
			and actor in gerencia.campaign.companion_states \
			and exploration.current_actor == gerencia.campaign.resurrection_playable_owner(actor) \
			and not exploration.block_manager.is_busy():
		return skill_manager.can_use_exploration_divine_amulet(
			actor, grant, gerencia.campaign)
	if actor != null and skill != null and skill.usable_while_owner_inactive \
			and gerencia != null and gerencia.campaign != null \
			and actor in gerencia.campaign.companion_states \
			and exploration != null and not exploration.block_manager.is_busy():
		var pet_owner := gerencia.campaign.get_playable_slot(actor.owner_instance_id)
		if pet_owner == null or skill.requires_player_confirmation:
			return false
		if skill.target_mode == ActiveSkillData.TargetMode.TILE:
			for coord in gerencia.campaign.current_map.cells:
				if skill_manager.can_use_exploration_active(actor, pet_owner, grant,
						gerencia.campaign, coord, exploration.block_manager,
						gerencia.map_view):
					return true
			return false
		return skill_manager.can_use_exploration_active(actor, pet_owner, grant,
			gerencia.campaign, EntityState.UNPLACED,
			exploration.block_manager, gerencia.map_view)
	if exploration == null or skill_manager == null or gerencia == null \
			or exploration.current_actor == null \
			or exploration.block_manager.is_busy():
		return false
	var owner := exploration.current_actor
	if actor.turn_state == EntityState.TurnState.INACTIVE:
		return exploration.can_reactivate_extra_movement(actor, grant)
	if _open_card != null and _open_card.state != null \
			and _open_card.state.turn_state == EntityState.TurnState.INACTIVE:
		return false
	if actor != owner and actor.owner_instance_id != owner.instance_id:
		return false
	skill = grant.skill as ActiveSkillData
	if skill.id == &"item_active_003":
		return actor == owner and actor.turn_state == EntityState.TurnState.TURNING \
			and (skill_manager.catastrophe_manager == null \
			or not skill_manager.catastrophe_manager.skills_suppressed(
				HexGrid.PPPMapMode.EXPLORATION, false)) \
			and skill_manager.can_attune_divine_amulet(actor, grant)
	if skill.use_context == ActiveSkillData.UseContext.COMBAT \
			or (skill.requires_player_confirmation and skill.id != &"item_active_002"):
		return false
	if skill.id == &"item_active_002":
		return actor == owner and skill_manager.can_use_exploration_divine_amulet(
			actor, grant, gerencia.campaign)
	if skill.target_mode == ActiveSkillData.TargetMode.TILE:
		for coord in gerencia.campaign.current_map.cells:
			if skill_manager.can_use_exploration_active(actor, owner, grant,
					gerencia.campaign, coord, exploration.block_manager, gerencia.map_view):
				return true
		return false
	if skill.effects.any(func(effect: SkillEffectData) -> bool:
		return effect.effect_type == SkillEffectData.EffectType.MODIFY_CRAFT_COST):
		return not exploration.player_skill_manager.get_craft_options(actor, grant, exploration).is_empty()
	if skill.target_mode == ActiveSkillData.TargetMode.ITEM:
		return not _time_accelerator_options(actor, grant).is_empty()
	return skill_manager.can_use_exploration_active(actor, owner, grant,
		gerencia.campaign, EntityState.UNPLACED, exploration.block_manager, gerencia.map_view)


func _on_ally_pressed() -> void:
	if not ally_button.visible:
		return
	_targeting_actor = null
	_targeting_grant = null
	_close_inventory()
	_hide_hex_choice()
	ally_drawer.visible = not ally_drawer.visible
	ally_button.text = "ALIADO ◀" if ally_drawer.visible else "ALIADO ▶"
	if ally_drawer.visible:
		_position_action_drawer(false)
		_queue_ally_drawer_position()


func _queue_ally_drawer_position() -> void:
	if _ally_position_queued:
		return
	_ally_position_queued = true
	get_tree().process_frame.connect(_position_ally_drawer_on_frame,
		CONNECT_ONE_SHOT)


func _position_ally_drawer_on_frame() -> void:
	_ally_position_queued = false
	if is_inside_tree() and ally_drawer.visible:
		_position_ally_drawer()


func _position_ally_drawer() -> void:
	ally_drawer.reset_size()
	# PanelContainer não encolhe automaticamente quando os antigos botões de
	# combate saem do ScrollContainer; remove o espaço vazio retido no painel.
	ally_drawer.size = ally_drawer.get_combined_minimum_size()
	var viewport_size := get_viewport().get_visible_rect().size
	var x := action_drawer.position.x + action_drawer.size.x + 12.0
	# A ficha permanece junto à caixa de ações, na faixa das casas, sem
	# descer até o chão por causa da altura do botão ALIADO na lista.
	var y := action_drawer.position.y
	ally_drawer.position = Vector2(minf(x, viewport_size.x - ally_drawer.size.x - 6.0),
		clampf(y, 56.0, maxf(56.0, viewport_size.y - ally_drawer.size.y - 12.0)))


func _on_hex_choice_requested(coord: Vector2i) -> void:
	_ground_choice_open = false
	if _in_combat():
		_on_combat_hex_choice(coord)
		return
	if exploration == null or gerencia == null \
			or (exploration.current_actor == null and _targeting_grant == null):
		return
	if exploration.player_skill_manager != null \
			and not exploration.player_skill_manager.get_pending_options().is_empty():
		return
	# O botão "Andar até" da ficha arma o próximo clique. Nesse caminho,
	# um hex válido inicia o movimento sem abrir a caixa contextual.
	if _walk_target_actor != null:
		if _walk_target_actor != exploration.current_actor:
			_walk_target_actor = null
		elif exploration.get_available_destinations().has(coord):
			_walk_target_actor = null
			if coord != exploration.get_emergency_destination():
				_hide_hex_choice()
				exploration.try_move(coord)
				return
		else:
			return
	if _targeting_grant != null:
		var skill := _targeting_grant.skill as ActiveSkillData
		var turn_owner := gerencia.campaign.get_playable_slot(
			_targeting_actor.owner_instance_id) if skill != null \
			and skill.usable_while_owner_inactive else exploration.current_actor
		if _targeting_actor != null and skill_manager.can_use_exploration_active(
				_targeting_actor, turn_owner, _targeting_grant,
				gerencia.campaign, coord, exploration.block_manager, gerencia.map_view):
			if exploration.player_skill_manager.use_tile_active(
					_targeting_actor, _targeting_grant, coord, exploration):
				if skill != null and skill.id == &"reading_glasses_reveal" \
						and _targeting_grant.uses_in_last_round < 2:
					action_hint.text = "ÓCULOS: 1 de 2 revelado. Escolha outro hex oculto ao alcance ou passe a vez."
					action_hint.show()
					if _open_card != null:
						_rebuild_action_buttons()
					return
				_close_actions()
				return
		if _open_card != null:
			action_hint.text = "Essa habilidade não pode agir nesse hex. Escolha outro."
			action_hint.show()
		return
	_close_inventory()
	_hide_skill_info()
	_clear_buttons(hex_choice_buttons)
	var destinations := exploration.get_available_destinations()
	var emergency := coord == exploration.get_emergency_destination()
	if destinations.has(coord):
		var move_button := _make_choice_button(
			"IR AO MAIS PRÓXIMO" if emergency else "ANDAR ATÉ",
			Color(0.11, 0.43, 0.17))
		if emergency:
			move_button.add_theme_font_size_override("font_size", 14)
			move_button.custom_minimum_size.y = 40.0
		move_button.tooltip_text = ""
		move_button.pressed.connect(_on_confirm_walk.bind(coord))
		hex_choice_buttons.add_child(move_button)
	for option in exploration.player_skill_manager.get_exploration_skill_options(exploration):
		var owner: EntityState = option["skill_owner"]
		var grant: SkillGrantState = option["grant"]
		if not option["needs_tile"] or not option["implemented"]:
			continue
		if not skill_manager.can_use_exploration_active(owner, exploration.current_actor,
				grant, gerencia.campaign, coord, exploration.block_manager, gerencia.map_view):
			continue
		var skill := grant.skill as ActiveSkillData
		var label := skill.display_name
		if skill.effects.any(func(effect: SkillEffectData) -> bool:
			return effect.effect_type == SkillEffectData.EffectType.REVEAL_BLOCKS):
			label = "REVELAR"
		if option["is_companion"]:
			label = "%s · %s" % [owner.visible_name(), skill.display_name]
		var button := _make_choice_button(label, Color(0.52, 0.36, 0.055),
			"skill" if not option["is_companion"] else "")
		button.pressed.connect(_on_context_skill_pressed.bind(owner, grant, coord))
		button.mouse_entered.connect(_show_skill_info.bind(button, skill))
		button.mouse_exited.connect(_hide_skill_info)
		hex_choice_buttons.add_child(button)
	var revealed_details := _set_hex_revelation_details(coord)
	if hex_choice_buttons.get_child_count() == 0 and not revealed_details:
		_hide_hex_choice()
		return
	if not revealed_details:
		hex_choice_title.text = "SEM HEX AO ALCANCE" if emergency else "◎ ◎ ◎ ◎"
		hex_choice_title.add_theme_font_size_override("font_size", 14 if emergency else 11)
	hex_choice_title.tooltip_text = ""
	hex_choice.show()
	_position_hex_choice(get_viewport().get_mouse_position() + Vector2(16.0, -10.0))


func _on_ground_pressed(screen_position: Vector2) -> void:
	if _in_combat():
		if combat_manager != null and combat_manager.is_player_turn():
			if _combat_core_actions_exhausted(combat_manager.current_actor):
				_show_combat_pass_only(screen_position)
			else:
				show_combat_actions_for(combat_manager.current_actor,
					Rect2(screen_position, Vector2.ZERO))
		return
	if exploration == null or exploration.current_actor == null \
			or exploration.block_manager.is_busy() \
			or exploration.player_skill_manager.has_pending_choice() \
			or _walk_target_actor != null or _targeting_grant != null:
		return
	var actor := exploration.current_actor
	if action_drawer.visible:
		_close_actions()
	_hide_hex_choice()
	_clear_buttons(hex_choice_buttons)
	if skill_manager != null:
		for grant in skill_manager.get_active_grants(actor):
			var skill := grant.skill as ActiveSkillData
			if skill == null or not _is_displayed_skill(grant) \
					or skill.use_context == ActiveSkillData.UseContext.COMBAT \
					or skill.target_mode in [ActiveSkillData.TargetMode.TILE,
						ActiveSkillData.TargetMode.AREA] \
					or not _skill_is_available(actor, grant):
				continue
			var button := _make_choice_button(_fit_skill_label(skill.display_name),
				Color(0.52, 0.36, 0.055), "skill")
			button.pressed.connect(_on_ground_skill_pressed.bind(actor, grant))
			button.mouse_entered.connect(_show_skill_info.bind(button, skill))
			button.mouse_exited.connect(_hide_skill_info)
			hex_choice_buttons.add_child(button)
	var pass_button := _make_choice_button("PASSAR O TURNO", Color(0.24, 0.25, 0.27))
	pass_button.pressed.connect(_on_ground_pass_turn)
	hex_choice_buttons.add_child(pass_button)
	hex_choice_title.text = "◎ ◎ ◎ ◎"
	hex_choice_title.tooltip_text = ""
	_ground_choice_open = true
	hex_choice.show()
	_position_ground_choice(screen_position)


func _on_ground_skill_pressed(actor: EntityState, grant: SkillGrantState) -> void:
	_hide_hex_choice()
	if _skill_is_available(actor, grant):
		_on_skill_pressed(actor, grant)


func _on_ground_pass_turn() -> void:
	_hide_hex_choice()
	if exploration != null:
		exploration.pass_turn()


func _position_ground_choice(click: Vector2) -> void:
	hex_choice.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var top_limit := 64.0
	var top_bar := get_parent().get_node_or_null("CampaignTopBar/Bar") as Control
	if top_bar != null:
		top_limit = maxf(top_limit, top_bar.get_global_rect().end.y + 10.0)
	var menu_size := hex_choice.size
	var y := clampf(click.y - menu_size.y - 14.0, top_limit,
		maxf(top_limit, screen.y - menu_size.y - 10.0))
	var candidates: Array[float] = [click.x + 16.0,
		click.x - menu_size.x - 16.0]
	# Se houver uma entidade perto do clique, procura também espaço livre
	# mais lateralmente, sem nunca jogar a caixa por cima do seu corpo.
	for x_index in range(10, maxi(11, floori(screen.x - menu_size.x - 10.0)), 24):
		candidates.append(float(x_index))
	var best := Vector2.ZERO
	var best_score := INF
	for proposed_x in candidates:
		var x := clampf(proposed_x, 10.0, maxf(10.0, screen.x - menu_size.x - 10.0))
		var box := Rect2(Vector2(x, y), menu_size)
		var score := absf(x - proposed_x) + absf(x - click.x) * 0.04
		for visual in get_tree().get_nodes_in_group("map_entity_visual"):
			if not visual is Node2D or not visual.visible:
				continue
			var feet: Vector2 = (visual as Node2D).get_global_transform_with_canvas().origin
			var entity_box := Rect2(feet - Vector2(44.0, 158.0), Vector2(88.0, 168.0))
			if box.intersects(entity_box):
				score += box.intersection(entity_box).get_area() * 2.0
		if score < best_score:
			best_score = score
			best = box.position
	hex_choice.position = best


func _on_combat_hex_choice(coord: Vector2i) -> void:
	if _combat_roll_animating or combat_manager == null or not combat_manager.is_player_turn():
		return
	match combat_manager.action_mode:
		&"skill":
			var pending_grant := combat_manager._selected_skill_grant
			var selected_target := combat_manager._opponent_at(
				combat_manager.current_actor, coord)
			if _is_taming_skill(pending_grant) and selected_target != null:
				_open_taming_confirmation(pending_grant, selected_target)
				return
			if _is_archenemy_skill(pending_grant) and selected_target != null:
				_open_archenemy_confirmation(pending_grant, selected_target)
				return
			var result := combat_manager.use_player_skill_at(coord)
			if result.get("success", false):
				_hide_hex_choice()
				if _open_card != null:
					_rebuild_action_buttons()
			return
		&"move":
			combat_manager.player_move(coord)
			_hide_hex_choice()
			if _open_card != null:
				_rebuild_action_buttons()
			return
		&"attack":
			if combat_manager.can_player_attack(coord):
				combat_manager.player_attack(coord)
				_hide_hex_choice()
				if _open_card != null:
					_rebuild_action_buttons()
				return
	for ally in combat_manager._allies_of(combat_manager.current_actor):
		if ally != null and ally != combat_manager.current_actor \
				and ally.current_health > 0 and ally.position == coord:
			_show_combat_ally_target_choices(ally,
				get_viewport().get_mouse_position() + Vector2(16.0, -10.0))
			return
	_show_combat_target_choices(coord)


func _show_combat_target_choices(coord: Vector2i) -> void:
	_ally_target_choice_open = false
	_clear_buttons(hex_choice_buttons)
	var target := combat_manager._opponent_at(combat_manager.current_actor, coord)
	if target != null and not combat_manager.has_rolled_turn_die():
		var roll_button := _make_choice_button("JOGAR DADO", Color(0.11, 0.43, 0.17))
		roll_button.disabled = not combat_manager.can_roll_player_turn_die()
		roll_button.pressed.connect(_on_combat_context_roll.bind(coord))
		hex_choice_buttons.add_child(roll_button)
	if combat_manager.can_player_move(coord):
		var move_button := _make_choice_button("ANDAR ATÉ", Color(0.11, 0.43, 0.17))
		move_button.pressed.connect(_on_confirm_walk.bind(coord))
		hex_choice_buttons.add_child(move_button)
	if target != null:
		var attack_button := _make_choice_button("ATACAR", Color(0.55, 0.10, 0.12))
		attack_button.disabled = not combat_manager.can_player_attack(coord)
		if not combat_manager.has_rolled_turn_die():
			attack_button.tooltip_text = "Jogue o dado antes de atacar."
		elif attack_button.disabled:
			attack_button.tooltip_text = "Alvo fora do alcance ou ataque indisponível."
		else:
			attack_button.tooltip_text = "Confirmar ataque contra %s." % target.visible_name()
		attack_button.pressed.connect(_on_combat_context_attack.bind(coord))
		hex_choice_buttons.add_child(attack_button)
		if combat_manager.can_player_approach(coord):
			var approach_button := _make_choice_button("APROXIMAR", Color(0.11, 0.43, 0.17))
			approach_button.tooltip_text = "Andar em direção ao alvo até o limite da Estamina, sem gastar o ataque."
			approach_button.pressed.connect(_on_combat_context_approach.bind(coord))
			hex_choice_buttons.add_child(approach_button)
	if target != null and skill_manager != null and gerencia != null:
		for grant in skill_manager.get_active_grants(combat_manager.current_actor):
			var skill := grant.skill as ActiveSkillData
			if skill == null or skill.target_mode not in [
					ActiveSkillData.TargetMode.ONE_ENEMY,
					ActiveSkillData.TargetMode.ONE_ENTITY] \
					or not skill_manager.can_use_combat_active(combat_manager.current_actor,
						grant, gerencia.campaign, combat_manager, target):
				continue
			var skill_button := _make_choice_button(_fit_skill_label(skill.display_name),
				Color(0.52, 0.36, 0.055), "skill")
			_add_combat_use_count(skill_button, grant)
			skill_button.pressed.connect(_on_combat_context_skill.bind(grant, coord))
			skill_button.mouse_entered.connect(_show_skill_info.bind(skill_button, skill))
			skill_button.mouse_exited.connect(_hide_skill_info)
			hex_choice_buttons.add_child(skill_button)
	if hex_choice_buttons.get_child_count() == 0:
		_hide_hex_choice()
		return
	var targets_here := combat_manager.get_enemies_under_pointer(
		get_viewport().get_mouse_position())
	if target != null and targets_here.size() > 1 and target in targets_here:
		hex_choice_title.text = "ALVO %d DE %d" % [
			targets_here.find(target) + 1, targets_here.size()]
		hex_choice_title.tooltip_text = "Clique de novo no corpo para alternar entre inimigos sobrepostos."
	else:
		hex_choice_title.text = "◎ ◎ ◎ ◎"
		hex_choice_title.tooltip_text = ""
	hex_choice.show()
	_position_hex_choice(get_viewport().get_mouse_position() + Vector2(16.0, -10.0))


func _on_combat_context_roll(coord: Vector2i) -> void:
	combat_manager.action_mode = &""
	_on_combat_roll_pressed()
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree() and combat_manager != null and combat_manager.is_player_turn():
		_show_combat_target_choices(coord)


func _on_combat_context_skill(grant: SkillGrantState, coord: Vector2i) -> void:
	if _is_taming_skill(grant):
		var target := combat_manager._opponent_at(combat_manager.current_actor, coord)
		if target != null:
			_open_taming_confirmation(grant, target)
		return
	if _is_archenemy_skill(grant):
		var target := combat_manager._opponent_at(combat_manager.current_actor, coord)
		if target != null:
			_open_archenemy_confirmation(grant, target)
		return
	if combat_manager == null or not combat_manager.select_player_skill(grant):
		return
	var result := combat_manager.use_player_skill_at(coord)
	if result.get("success", false):
		_hide_hex_choice()
		if _open_card != null:
			_rebuild_action_buttons()


func _is_taming_skill(grant: SkillGrantState) -> bool:
	return grant != null and grant.skill is ActiveSkillData \
		and (grant.skill as ActiveSkillData).id == &"permanent_active_068"


func _is_archenemy_skill(grant: SkillGrantState) -> bool:
	return grant != null and grant.skill is ActiveSkillData \
		and (grant.skill as ActiveSkillData).id == &"permanent_active_070"


func _open_archenemy_confirmation(grant: SkillGrantState,
		target: EntityState) -> void:
	if combat_manager == null or _archenemy_dialog == null or gerencia == null \
			or not combat_manager.is_player_turn() or target == null \
			or not skill_manager.can_use_combat_active(combat_manager.current_actor,
				grant, gerencia.campaign, combat_manager, target):
		return
	_pending_archenemy_grant = grant
	_pending_archenemy_target = target
	_archenemy_dialog.dialog_text = "Declarar %s seu arqui-inimigo?" % target.visible_name()
	_archenemy_dialog.popup_centered(Vector2i(470, 150))


func _cancel_archenemy() -> void:
	if _archenemy_dialog != null:
		_archenemy_dialog.hide()
	_cancel_pending_target_skill(_pending_archenemy_grant)
	_pending_archenemy_grant = null
	_pending_archenemy_target = null


func _confirm_archenemy() -> void:
	var grant := _pending_archenemy_grant
	var target := _pending_archenemy_target
	_cancel_archenemy()
	if combat_manager == null or target == null or not combat_manager.is_player_turn() \
			or not combat_manager.select_player_skill(grant):
		return
	var result := combat_manager.use_player_skill_at(target.position)
	if result.get("success", false):
		_hide_hex_choice()
		if _open_card != null:
			_rebuild_action_buttons()


func _open_taming_confirmation(grant: SkillGrantState,
		target: EntityState) -> void:
	if combat_manager == null or _tame_dialog == null or gerencia == null \
			or not combat_manager.is_player_turn() or target == null \
			or not skill_manager.can_use_combat_active(combat_manager.current_actor,
				grant, gerencia.campaign, combat_manager, target):
		return
	_pending_tame_grant = grant
	_pending_tame_target = target
	_tame_dialog.dialog_text = "Deseja adestrar %s?\nChance de sucesso: 50%%. Uma tentativa por combate." % \
		target.visible_name()
	_tame_dialog.popup_centered(Vector2i(470, 170))


func _cancel_taming() -> void:
	if _tame_dialog != null:
		_tame_dialog.hide()
	_cancel_pending_target_skill(_pending_tame_grant)
	_pending_tame_grant = null
	_pending_tame_target = null


func _cancel_pending_target_skill(grant: SkillGrantState) -> void:
	if combat_manager != null and grant != null \
			and combat_manager._selected_skill_grant == grant:
		combat_manager._selected_skill_grant = null
		combat_manager.action_mode = &""
		combat_manager._sync_combat_view()
		_hide_hex_choice()
		action_hint.hide()


func _confirm_taming() -> void:
	var grant := _pending_tame_grant
	var target := _pending_tame_target
	_cancel_taming()
	if combat_manager == null or target == null or not combat_manager.is_player_turn() \
			or not combat_manager.select_player_skill(grant):
		return
	var result := combat_manager.use_player_skill_at(target.position)
	if not result.get("success", false):
		_tame_result_dialog.dialog_text = "Não foi possível tentar o adestramento deste alvo."
	elif result.get("effects", []).any(func(entry: Dictionary) -> bool:
		return entry.get("chance_failed", false)):
		_tame_result_dialog.dialog_text = "Não foi dessa vez."
	else:
		_tame_result_dialog.dialog_text = "Você adestrou %s. Um novo pet entrou para o grupo!" % \
			target.visible_name()
	_tame_result_dialog.popup_centered(Vector2i(480, 150))
	_hide_hex_choice()
	if _open_card != null:
		_rebuild_action_buttons()


func _on_tame_result_window_input(_event: InputEvent) -> void:
	# O resultado tem OK, não um X: Esc não o dispensa.
	pass


func _on_recruitment_choice_requested(enemy: EntityState, chance: float,
		information_names: String) -> void:
	if _recruitment_dialog == null or enemy == null:
		return
	_recruitment_dialog.dialog_text = \
		"Tentar recrutar %s? %d%% de chance.\nOrigem: %s." % [
			enemy.visible_name(), roundi(chance * 100.0), information_names]
	_recruitment_dialog.call_deferred("popup_centered", Vector2i(510, 180))


func _on_recruitment_declined() -> void:
	if _recruitment_dialog != null:
		_recruitment_dialog.hide()
	if combat_manager != null:
		combat_manager.confirm_encounter_recruitment(false)


func _on_recruitment_confirmed() -> void:
	if _recruitment_dialog != null:
		_recruitment_dialog.hide()
	if combat_manager == null or _recruitment_result_dialog == null:
		return
	var result := combat_manager.confirm_encounter_recruitment(true)
	if not result.get("success", false):
		return
	_recruitment_result_dialog.dialog_text = \
		("Você recrutou %s. Um novo aliado entrou para o grupo!" % \
		(result["enemy"] as EntityState).visible_name()) \
		if result.get("recruited", false) else "Não foi dessa vez. O combate começa."
	# Ponto reservado para uma mini-cutscene entre a rolagem e este outcome.
	_recruitment_result_dialog.popup_centered(Vector2i(480, 155))


func _on_recruitment_result_window_input(_event: InputEvent) -> void:
	# A confirmação visível é obrigatória para concluir o retorno ao combate.
	pass


func _on_recruitment_result_closed() -> void:
	if _recruitment_result_dialog != null:
		_recruitment_result_dialog.hide()
	if combat_manager != null:
		combat_manager.finish_recruitment_feedback()


func _is_ally_target_skill(skill: ActiveSkillData) -> bool:
	return skill != null and skill.use_context != ActiveSkillData.UseContext.EXPLORATION \
		and skill.automatic_triggers.is_empty() and skill.target_mode in [
			ActiveSkillData.TargetMode.ONE_ALLY, ActiveSkillData.TargetMode.ONE_ENTITY]


func _show_combat_ally_target_choices(target: EntityState,
		anchor: Vector2) -> bool:
	if combat_manager == null or not combat_manager.is_player_turn() \
			or target == null or target == combat_manager.current_actor \
			or target not in combat_manager._allies_of(combat_manager.current_actor) \
			or skill_manager == null or gerencia == null:
		return false
	_clear_buttons(hex_choice_buttons)
	var actor := combat_manager.current_actor
	for grant in skill_manager.get_active_grants(actor):
		var skill := grant.skill as ActiveSkillData
		if not _is_ally_target_skill(skill):
			continue
		var button := _make_choice_button(skill.display_name,
			Color(0.52, 0.36, 0.055), "skill")
		button.disabled = not skill_manager.can_use_combat_active(actor, grant,
			gerencia.campaign, combat_manager, target)
		_add_combat_use_count(button, grant)
		button.set_meta("skill_info_text",
			"Indisponível neste turno." if button.disabled else skill.description)
		button.tooltip_text = ""
		button.pressed.connect(_on_combat_ally_skill_pressed.bind(actor, grant, target))
		button.mouse_entered.connect(_show_skill_info.bind(button, skill))
		button.mouse_exited.connect(_hide_skill_info)
		hex_choice_buttons.add_child(button)
	if hex_choice_buttons.get_child_count() == 0:
		return false
	hex_choice_title.text = target.visible_name().to_upper() if target.data != null \
		else "ALIADO"
	hex_choice_title.tooltip_text = ""
	_ally_target_choice_open = true
	hex_choice.show()
	_position_hex_choice(anchor)
	return true


func _show_combat_ally_selection(actor: EntityState,
		grant: SkillGrantState) -> void:
	_clear_buttons(hex_choice_buttons)
	var targets := combat_manager._allies_of(actor)
	if (grant.skill as ActiveSkillData).target_mode == ActiveSkillData.TargetMode.ONE_ENTITY:
		targets.append_array(combat_manager._opponents_of(actor))
	for target in targets:
		if target == null or target == actor or target.data == null:
			continue
		var button := _make_choice_button(target.visible_name(),
			Color(0.52, 0.36, 0.055))
		button.disabled = not skill_manager.can_use_combat_active(actor, grant,
			gerencia.campaign, combat_manager, target)
		button.pressed.connect(_on_combat_ally_skill_pressed.bind(actor, grant, target))
		hex_choice_buttons.add_child(button)
	hex_choice_title.text = "ESCOLHA O ALVO" if \
		(grant.skill as ActiveSkillData).target_mode == ActiveSkillData.TargetMode.ONE_ENTITY \
		else "ESCOLHA O ALIADO"
	hex_choice_title.tooltip_text = ""
	_close_inventory()
	_ally_target_choice_open = true
	hex_choice.show()
	_position_hex_choice(action_drawer.position +
		Vector2(action_drawer.size.x + 12.0, 0.0))


func _on_combat_ally_skill_pressed(actor: EntityState,
		grant: SkillGrantState, target: EntityState) -> void:
	if combat_manager == null or combat_manager.current_actor != actor \
			or not skill_manager.can_use_combat_active(actor, grant,
				gerencia.campaign, combat_manager, target):
		_show_combat_ally_target_choices(target, hex_choice.position)
		return
	var result := skill_manager.use_combat_active(actor, grant,
		gerencia.campaign, combat_manager, target)
	if not result.get("success", false):
		return
	combat_manager.action_resolved.emit(actor, &"skill", result)
	_hide_hex_choice()
	if (grant.skill as ActiveSkillData).ends_turn:
		combat_manager.end_current_turn()
	if _open_card != null:
		_rebuild_action_buttons()


func _show_amulet_dead_selection(owner: EntityState,
		grant: SkillGrantState) -> void:
	if gerencia == null or skill_manager == null or _revive_dialog == null:
		return
	_amulet_owner = owner
	_amulet_grant = grant
	_amulet_target = null
	_clear_buttons(hex_choice_buttons)
	for target in gerencia.campaign.get_dead_group_members():
		var available := skill_manager.can_use_combat_active(owner, grant,
			gerencia.campaign, combat_manager, target) if _in_combat() else \
			skill_manager.can_use_exploration_divine_amulet(owner, grant,
				gerencia.campaign, target)
		if not available:
			continue
		var button := _make_choice_button(target.visible_name(),
			Color(0.12, 0.48, 0.55))
		button.pressed.connect(_select_amulet_dead_target.bind(target))
		hex_choice_buttons.add_child(button)
	if hex_choice_buttons.get_child_count() == 0:
		_hide_hex_choice()
		return
	hex_choice_title.text = "ESCOLHA QUEM RESSUSCITAR"
	hex_choice_title.tooltip_text = "O Amuleto só será consumido após a confirmação."
	_close_inventory()
	_ally_target_choice_open = true
	hex_choice.show()
	_position_hex_choice(action_drawer.position +
		Vector2(action_drawer.size.x + 12.0, 0.0))


func _select_amulet_dead_target(target: EntityState) -> void:
	if _amulet_owner == null or _amulet_grant == null or target == null:
		return
	_amulet_target = target
	_hide_hex_choice()
	_revive_dialog.dialog_text = "Ressuscitar %s com Vida completa? Ao confirmar, o Amuleto Divino equipado será consumido e destruído permanentemente. Ele não poderá ser criado novamente nesta campanha. O escolhido receberá imunidade permanente a Doença, Terror e Tristeza." % target.visible_name()
	_revive_dialog.popup_centered(Vector2i(590, 180))


func _cancel_amulet_revive() -> void:
	if _amulet_owner != null and _amulet_grant != null \
			and _skill_is_available(_amulet_owner, _amulet_grant):
		_show_amulet_dead_selection(_amulet_owner, _amulet_grant)
	else:
		_amulet_owner = null
		_amulet_grant = null
		_amulet_target = null


func _confirm_amulet_revive() -> void:
	var owner := _amulet_owner
	var grant := _amulet_grant
	var target := _amulet_target
	_amulet_owner = null
	_amulet_grant = null
	_amulet_target = null
	if owner == null or grant == null or target == null or gerencia == null:
		return
	if _in_combat():
		var result := skill_manager.use_combat_active(owner, grant,
			gerencia.campaign, combat_manager, target)
		if result.get("success", false):
			combat_manager.action_resolved.emit(owner, &"skill", result)
			if (grant.skill as ActiveSkillData).ends_turn:
				combat_manager.end_current_turn()
	else:
		skill_manager.use_exploration_divine_amulet(owner, grant,
			gerencia.campaign, target)
	_sync_slots()


func _show_amulet_attunement(owner: EntityState, grant: SkillGrantState) -> void:
	if _attune_dialog == null or not _skill_is_available(owner, grant):
		return
	_attune_owner = owner
	_attune_grant = grant
	_attune_dialog.dialog_text = "Sintonizar este Amuleto Divino com %s? Esta escolha é IRREVERSÍVEL: cada cópia pode ser sintonizada uma única vez, por um único personagem. A sintonização não destrói o item. Só %s terá as imunidades enquanto o equipar; outro personagem não poderá sintonizá-lo." % [owner.visible_name(), owner.visible_name()]
	_attune_dialog.popup_centered(Vector2i(620, 210))


func _cancel_amulet_attunement() -> void:
	_attune_owner = null
	_attune_grant = null


func _confirm_amulet_attunement() -> void:
	var owner := _attune_owner
	var grant := _attune_grant
	_cancel_amulet_attunement()
	if owner == null or grant == null or not _skill_is_available(owner, grant):
		return
	var result := skill_manager.attune_divine_amulet(owner, grant,
		gerencia.campaign if gerencia != null else null)
	if result.get("success", false):
		if _in_combat():
			combat_manager.action_resolved.emit(owner, &"skill", result)
		_sync_slots()
		_rebuild_action_buttons()


func _on_combat_context_attack(coord: Vector2i) -> void:
	_hide_hex_choice()
	if combat_manager != null:
		combat_manager.player_attack(coord)
	if _open_card != null:
		_rebuild_action_buttons()


func _on_combat_context_approach(coord: Vector2i) -> void:
	if combat_manager != null and combat_manager.player_approach(coord):
		_hide_hex_choice()
		if _open_card != null:
			_rebuild_action_buttons()


func _on_combat_attack_pressed() -> void:
	if _combat_roll_animating:
		return
	if combat_manager != null and combat_manager.select_player_action(&"attack"):
		_hide_hex_choice()
		# A caixa pode ficar aberta durante o turno, sobretudo a do aliado.
		if _open_card != null:
			_rebuild_action_buttons()


func _on_combat_move_pressed() -> void:
	if _combat_roll_animating:
		return
	if combat_manager != null and combat_manager.select_player_action(&"move"):
		_hide_hex_choice()
		if _open_card != null:
			_rebuild_action_buttons()


func _on_combat_roll_pressed() -> void:
	if not _combat_roll_animating and combat_manager != null:
		combat_manager.roll_player_turn_die()


func _on_combat_end_pressed() -> void:
	if not _combat_roll_animating and combat_manager != null \
			and combat_manager.is_player_turn():
		_close_actions()
		combat_manager.end_current_turn()


func _on_hex_inspection_requested(coord: Vector2i) -> void:
	if gerencia == null or gerencia.campaign.current_map == null:
		return
	# O clique no bloco rosa/vermelho é consulta. Não consome a habilidade,
	# não anda e não ativa o conteúdo: mostra o título. Se for rosa, o
	# MapView também abre as ações (inclusive Andar até) no mesmo clique.
	var content := gerencia.campaign.current_map.get_ppp_block_resource(coord)
	if content == null:
		return
	var title := ""
	if content is Informacao:
		title = content.titulo
	elif content is EventData or content is EncounterData or content is ItemData:
		title = content.display_name
	_last_inspected_coord = coord
	hex_title_popup.call("show_title", title, _hex_classification(content),
		get_viewport().get_mouse_position(),
		gerencia.map_view.is_temporary_inspection(coord),
		_revealed_effect_description(coord, content))


func _on_hex_revealed(coord: Vector2i) -> void:
	if gerencia == null or gerencia.map_view == null:
		return
	var anchor := gerencia.map_view.get_hex_screen_position(coord)
	var content := gerencia.campaign.current_map.get_ppp_block_resource(coord)
	if content == null:
		return
	var title: String = content.titulo if content is Informacao else content.display_name
	_last_inspected_coord = coord
	hex_title_popup.call("show_title", title, _hex_classification(content), anchor, false,
		_revealed_effect_description(coord, content))


func _revealed_effect_description(coord: Vector2i, content: Resource) -> String:
	if gerencia == null or gerencia.campaign.current_map == null \
			or &"event_type_and_effect" not in gerencia.campaign.current_map.revealed_by_skill_ids.get(coord, []):
		return ""
	if content is Informacao:
		return (content as Informacao).descricao
	if content is EventData:
		return (content as EventData).description
	if content is EncounterData:
		return (content as EncounterData).description
	if content is ItemData:
		return (content as ItemData).description
	return ""


func _begin_future_vision_targeting(actor: EntityState, premonition: bool = false) -> void:
	if actor == null or gerencia == null \
			or gerencia.map_view == null or exploration == null \
			or exploration.current_actor != actor or _in_combat():
		return
	if premonition:
		if actor.premonition_round_index != gerencia.campaign.get_round_index() \
				or actor.premonition_used_turn_serial == actor.turn_serial:
			return
	elif actor.future_vision_uses <= 0:
		return
	_future_vision_targeting_actor = actor
	_future_vision_is_premonition = premonition
	gerencia.map_view.begin_future_vision(actor)
	_hide_hex_choice()
	action_hint.text = ("PREMONIÇÃO" if premonition else "VISÃO DO FUTURO") \
		+ ": escolha qualquer bloco oculto (ESC cancela)."
	action_hint.show()


func _end_future_vision_targeting() -> void:
	if _future_vision_targeting_actor == null:
		return
	_future_vision_targeting_actor = null
	_future_vision_is_premonition = false
	if gerencia != null and gerencia.map_view != null:
		gerencia.map_view.end_future_vision()


func _on_future_vision_hex_requested(coord: Vector2i) -> void:
	var actor := _future_vision_targeting_actor
	if actor == null or gerencia == null \
			or gerencia.campaign.current_map == null or gerencia.map_view == null \
			or exploration.current_actor != actor:
		_end_future_vision_targeting()
		return
	var grid := gerencia.campaign.current_map
	var cell := grid.get_cell(coord)
	if cell == null or cell.state != HexGrid.PPPBlockState.HIDDEN \
			or cell.block_type == HexGrid.PPPBlockType.NONE:
		return
	var sources: Array = grid.revealed_by_skill_ids.get(coord, [])
	if &"event_type_and_effect" not in sources:
		sources.append(&"event_type_and_effect")
	grid.revealed_by_skill_ids[coord] = sources
	if _future_vision_is_premonition:
		actor.premonition_used_turn_serial = actor.turn_serial
	else:
		actor.future_vision_uses -= 1
	_end_future_vision_targeting()
	gerencia.map_view.reveal_block(coord)
	if _open_card != null:
		_rebuild_action_buttons()


func _hex_classification(content: Resource) -> String:
	if content is EventData:
		var event := content as EventData
		var kind := "Evento"
		match event.category:
			EventData.EventCategory.PERMANENT_EFFECT:
				kind = "Efeito permanente"
			EventData.EventCategory.CATASTROPHE:
				kind = "Catástrofe"
			EventData.EventCategory.TRAP:
				kind = "Armadilha"
		var valence := "Ambíguo"
		match event.valence:
			EventData.Valence.GOOD:
				valence = "Bom"
			EventData.Valence.BAD:
				valence = "Ruim"
		return "%s | %s" % [kind, valence]
	if content is ItemData:
		var item := content as ItemData
		match item.item_type:
			ItemData.ItemType.CONSUMABLE:
				return "Item | Consumível"
			ItemData.ItemType.CURSED:
				return "Item | Amaldiçoado"
		return "Item | Equipável"
	if content is EncounterData:
		var encounter := content as EncounterData
		var district := gerencia.campaign.district
		if district not in encounter.districts and not encounter.districts.is_empty():
			district = encounter.districts[0]
		match district:
			&"suburbio":
				return "Encontro | Subúrbio"
			&"baixo_centro":
				return "Encontro | Baixo-Centro"
			&"centro":
				return "Encontro | Centro"
		return "Encontro"
	if content is Informacao:
		# Não entregamos o desfecho antes de o bloco ser ativado.
		return "Informação | Pista"
	return "Bloco"


func _make_choice_button(title: String, color: Color,
		intent: String = "") -> Button:
	var button := Button.new()
	button.text = _fit_skill_label(title)
	button.custom_minimum_size.y = 46.0 if "\n" in button.text else 35.0
	button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	if intent.is_empty() and _in_combat() and (
			title.begins_with("JOGAR DADO") or title.begins_with("ATACAR")
			or title == "REPOSICIONAR" or title == "ANDAR ATÉ"
			or title == "APROXIMAR"):
		intent = "core"
	_paint_action_button(button, color, intent == "pass", intent)
	button.add_theme_font_size_override("font_size", 10)
	return button


func _position_hex_choice(anchor_point: Vector2) -> void:
	_hex_choice_anchor = anchor_point
	hex_choice.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var x := clampf(anchor_point.x, 6.0, maxf(6.0, screen.x - hex_choice.size.x - 6.0))
	var y := clampf(anchor_point.y, 56.0, maxf(56.0, screen.y - hex_choice.size.y - 6.0))
	hex_choice.position = Vector2(x, y)
	# Labels que acabaram de receber texto calculam a altura definitiva no
	# próximo layout. Reaplica os limites então para não cortar o último botão.
	call_deferred("_clamp_hex_choice_after_layout")


func _clamp_hex_choice_after_layout() -> void:
	await get_tree().process_frame
	if not hex_choice.visible:
		return
	hex_choice.size = hex_choice.get_combined_minimum_size()
	var screen := get_viewport().get_visible_rect().size
	hex_choice.position = Vector2(
		clampf(_hex_choice_anchor.x, 6.0,
			maxf(6.0, screen.x - hex_choice.size.x - 6.0)),
		clampf(_hex_choice_anchor.y, 56.0,
			maxf(56.0, screen.y - hex_choice.size.y - 6.0)))


func _hide_hex_choice() -> void:
	if _drop_preview_visual != null:
		_drop_preview_visual.cancel_mouse_drop()
		_drop_preview_visual = null
	_drop_actor = null
	_drop_grant = null
	hex_choice.hide()
	if _hex_choice_detail_scroll != null:
		_hex_choice_detail_scroll.hide()
	if _hex_choice_separator != null:
		_hex_choice_separator.hide()
	_companion_action_choice_open = false
	_companion_action_target = null
	_companion_actions_from_initiative = false
	_initiative_action_anchor = Rect2()
	if _initiative_action_link != null:
		_initiative_action_link.hide()
	_ally_target_choice_open = false
	_ground_choice_open = false
	_hide_skill_info()


func _on_confirm_walk(coord: Vector2i) -> void:
	if _in_combat():
		_hide_hex_choice()
		if combat_manager != null and combat_manager.player_move(coord) and _open_card != null:
			_rebuild_action_buttons()
		return
	_walk_target_actor = null
	_hide_hex_choice()
	_close_actions()
	if exploration != null:
		exploration.try_move(coord)


func _on_context_skill_pressed(actor: EntityState, grant: SkillGrantState,
		coord: Vector2i) -> void:
	_walk_target_actor = null
	_hide_hex_choice()
	if exploration != null and exploration.player_skill_manager.use_tile_active(
			actor, grant, coord, exploration):
		_close_actions()
	elif _open_card != null:
		_rebuild_action_buttons()


func _show_skill_info(button: Button, skill: ActiveSkillData) -> void:
	if skill == null or not button.is_inside_tree():
		return
	# A descrição com moldura rosa substitui o tooltip nativo do Godot;
	# os dois ao mesmo tempo causavam a linha solta sobre o mapa.
	if not button.tooltip_text.is_empty():
		button.set_meta("skill_info_text", button.tooltip_text)
		button.tooltip_text = ""
	skill_info_description.text = str(button.get_meta("skill_info_text", skill.description))
	skill_info.show()
	skill_info.reset_size()
	var screen := get_viewport().get_visible_rect().size
	var rect := button.get_global_rect()
	var x := rect.end.x + 8.0
	if x + skill_info.size.x > screen.x - 6.0:
		x = rect.position.x - skill_info.size.x - 8.0
	skill_info.position = Vector2(maxf(6.0, x), clampf(rect.position.y,
		56.0, maxf(56.0, screen.y - skill_info.size.y - 6.0)))


func _hide_skill_info() -> void:
	skill_info.hide()


func _set_mouse_ignore_recursive(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_set_mouse_ignore_recursive(child)


func _on_inventory_pressed() -> void:
	if _open_card == null or _open_card.state == null:
		return
	_targeting_actor = null
	_targeting_grant = null
	ally_drawer.hide()
	ally_button.text = "ALIADO ▶"
	_hide_hex_choice()
	if inventory_panel.visible:
		_close_inventory()
		return
	# O jogador pode abrir Inventário antes de a caixa Ações terminar sua
	# animação. Fixamos Ações no destino para calcular o vão correto.
	_position_action_drawer(false)
	inventory_panel.bind_state(_open_card.state)
	inventory_panel.show()
	inventory_link.show()
	_position_inventory_panel(true)


func _close_inventory() -> void:
	_close_item_details()
	item_menu.close()
	_equipment_pick_actor = null
	_equipment_pick_slot = -1
	if inventory_panel.actor != null and inventory_panel.equip_filter_slot >= 0:
		inventory_panel.set_equip_filter(-1, null)
	if _inventory_tween != null and _inventory_tween.is_running():
		_inventory_tween.kill()
	inventory_panel.hide()
	inventory_link.hide()


func _on_inventory_expansion_changed() -> void:
	_position_inventory_panel.call_deferred(false)
	if item_details_panel.visible:
		_position_item_details.call_deferred(false)


func _on_item_selected(entry: InventoryItemState) -> void:
	if entry == null or not inventory_panel.visible:
		return
	if _equipment_pick_slot >= 0:
		if _equipment_pick_actor == inventory_panel.actor \
				and inventory_panel.is_equip_candidate(entry):
			if EquipmentManager.new().equip(_equipment_pick_actor, entry, skill_manager,
					gerencia.campaign):
				get_node("/root/UISFX").call("play", &"equip")
				_equipment_pick_slot = -1
				_equipment_pick_actor = null
				inventory_panel.set_equip_filter(-1, null)
				_on_item_inventory_changed()
		return
	_close_item_details()
	item_menu.avoid_rect = inventory_panel.get_global_rect()
	item_menu.open_for(inventory_panel.actor, entry, false,
		inventory_panel.selected_anchor, gerencia.campaign, skill_manager)


func _on_equipped_item_selected(card: PartyCharacterCard,
		entry: InventoryItemState, anchor: Rect2) -> void:
	if card == null or card.state == null or gerencia == null \
			or entry == null or entry.data == null:
		return
	_close_item_details()
	item_menu.avoid_rect = inventory_panel.get_global_rect() if inventory_panel.visible else Rect2()
	var equipped_items := card.state.equipped_in_slot(entry.data.equipment_slot)
	if equipped_items.size() > 1:
		item_menu.open_equipped_collection(card.state, equipped_items, anchor,
			gerencia.campaign, skill_manager)
	else:
		item_menu.open_for(card.state, entry, true, anchor,
			gerencia.campaign, skill_manager)


func _on_craft_requested(actor: EntityState, item: ItemData) -> void:
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar == null or top_bar.group_inventory == null:
		return
	_close_item_details()
	item_menu.close()
	craft_hint.hide()
	top_bar.group_inventory.open_craft_for(actor, item)


func _on_inventory_craft_hover(point: Vector2) -> void:
	_craft_hint_from_item = true
	craft_hint.show_near(point)


func _on_equipped_craft_hover(card: PartyCharacterCard,
		entry: InventoryItemState, anchor: Rect2) -> void:
	if card == null or card.state == null or entry == null or entry.data == null \
			or gerencia == null or skill_manager == null:
		return
	if CraftAvailability.status_for(card.state, entry.data, gerencia.campaign,
			skill_manager.inventory_manager, exploration) == CraftAvailability.Status.NONE:
		return
	_craft_hint_from_item = true
	craft_hint.show_near(anchor.get_center())


func _on_craft_hover_ended() -> void:
	_craft_hint_from_item = false
	if craft_hint != null:
		craft_hint.hide()


func _refresh_craft_highlights() -> void:
	if gerencia == null or skill_manager == null or gerencia.campaign == null:
		return
	for card in cards:
		for slot in [ItemData.EquipmentSlot.WEAPON,
				ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
			var status := CraftAvailability.Status.NONE
			if card.state != null:
				var entry := card.state.primary_equipped(slot)
				if entry != null and entry.data != null:
					status = CraftAvailability.status_for(card.state, entry.data,
						gerencia.campaign, skill_manager.inventory_manager, exploration)
			card.set_craft_status(slot, status)


func _update_ground_craft_hint() -> void:
	if craft_hint == null or _craft_hint_from_item or gerencia == null \
			or gerencia.map_view == null or skill_manager == null:
		return
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	if (top_bar != null and top_bar.group_inventory != null \
			and top_bar.group_inventory.visible) or inventory_panel.visible:
		craft_hint.hide()
		return
	var pointer := get_viewport().get_mouse_position()
	var viewport := get_viewport().get_visible_rect().size
	if pointer.x < 285.0 or pointer.y < viewport.y * 0.66 \
			or gerencia.map_view.get_clickable_hex_at_screen_position(pointer) \
			!= EntityState.UNPLACED:
		craft_hint.hide()
		return
	for actor in gerencia.campaign.active_entity_states:
		if not CraftAvailability.options_for(actor, skill_manager.inventory_manager,
				exploration).is_empty():
			craft_hint.show_near(pointer)
			return
	craft_hint.hide()


func _on_equipment_slot_selected(card: PartyCharacterCard,
		slot_type: int, anchor: Rect2) -> void:
	if card == null or card.state == null or gerencia == null:
		return
	_close_item_details()
	item_menu.avoid_rect = Rect2()
	item_menu.open_empty_slot(card.state, slot_type, anchor,
		gerencia.campaign, skill_manager)


func _on_equip_slot_requested(actor: EntityState, slot_type: int) -> void:
	var card: PartyCharacterCard
	for candidate in cards:
		if candidate.state == actor:
			card = candidate
			break
	if card == null:
		return
	if _open_card != card:
		_on_action_toggle_requested(card)
	if _open_card != card:
		return
	if inventory_panel.visible:
		_close_inventory()
	_on_inventory_pressed()
	_equipment_pick_actor = actor
	_equipment_pick_slot = slot_type
	inventory_panel.set_equip_filter(slot_type, skill_manager)


func _on_item_inventory_changed() -> void:
	inventory_panel.refresh()
	for card in cards:
		card.refresh()
	if _open_card != null:
		_rebuild_action_buttons()
	if item_details_panel.visible and _selected_item_entry != null \
			and not _entry_still_in_party(_selected_item_entry):
		_close_item_details()


func _entry_still_in_party(selected: InventoryItemState) -> bool:
	if gerencia == null or gerencia.campaign == null:
		return false
	for owner in gerencia.campaign.active_entity_states:
		if selected in owner.inventory_items or selected in owner.equipped_weapons \
				or selected in owner.equipped_armors or selected in owner.equipped_accessories:
			return true
	for companion in gerencia.campaign.companion_states:
		if selected in companion.equipped_weapons or selected in companion.equipped_armors \
				or selected in companion.equipped_accessories:
			return true
	return false


func _show_item_details(entry: InventoryItemState) -> void:
	if entry == null:
		return
	if item_details_panel.visible and entry == _selected_item_entry:
		_close_item_details()
		return
	_selected_item_entry = entry
	# A ficha também pode abrir por um equipamento do quadro lateral.
	if inventory_panel.visible:
		_position_inventory_panel(false)
	item_details_panel.bind_entry(entry)
	item_details_panel.modulate.a = 0.0
	item_details_panel.show()
	if inventory_panel.visible:
		item_details_link.show()
	# A cena mede textos longos no próximo frame. Esperamos essa medida antes
	# de abrir a caixa para baixo, sem um salto de tamanho fora da tela.
	await get_tree().process_frame
	await get_tree().process_frame
	if _selected_item_entry != entry or not item_details_panel.visible:
		return
	if inventory_panel.visible:
		_position_item_details(true)
	else:
		item_details_panel.modulate.a = 1.0
		var viewport_size := get_viewport().get_visible_rect().size
		item_details_panel.fit_height(minf(470.0, viewport_size.y - 70.0))
		item_details_panel.position = (viewport_size - item_details_panel.size) * 0.5


func _close_item_details() -> void:
	if _details_tween != null and _details_tween.is_running():
		_details_tween.kill()
	_selected_item_entry = null
	if item_menu != null:
		item_menu.details_open = false
	item_details_panel.hide()
	item_details_link.hide()


func _paint_action_button(button: Button, background: Color,
		danger_action: bool = false, intent: String = "") -> void:
	button.set_meta("action_color_intent", intent)
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = background.lightened(0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(10.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = background.lightened(0.18)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = background.darkened(0.2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.17, 0.19, 0.21, 0.86)
	disabled_style.border_color = Color(0.42, 0.45, 0.48, 0.9)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(3)
	disabled_style.set_content_margin_all(10.0)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.67, 0.7, 0.72))
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		var normal_role := "action_%s" % intent if not intent.is_empty() else \
			"button_danger" if danger_action else "button"
		var hover_role := "action_%s_hover" % intent if not intent.is_empty() else \
			"button_danger" if danger_action else "button_hover"
		var pressed_role := "action_%s_pressed" % intent if not intent.is_empty() else \
			"button_danger" if danger_action else "button_selected"
		var text_role := "action_%s_text" % intent if not intent.is_empty() else \
			"on_button"
		var border_role := "danger" if danger_action else "structure"
		if intent in ["skill", "core", "pass_only"]:
			border_role = "action_%s_border" % intent
		palette.call("bind_control_style", button, "normal",
			normal_role, border_role)
		palette.call("bind_control_style", button, "hover",
			hover_role, "action_%s_hover_border" % intent \
			if intent in ["skill", "core", "pass_only"] else \
			"danger" if danger_action else "selection")
		palette.call("bind_control_style", button, "pressed",
			pressed_role, "action_%s_hover_border" % intent \
			if intent in ["skill", "core", "pass_only"] else \
			"danger" if danger_action else "selection")
		palette.call("bind_control_style", button, "disabled", "surface", "disabled")
		for key in ["font_color", "font_hover_color", "font_pressed_color"]:
			palette.call("bind_color", button, key, text_role)
		palette.call("bind_color", button, "font_disabled_color", "on_button_disabled")


func _bind_palette() -> void:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette == null:
		return
	for panel in [action_drawer, ally_drawer, hex_choice, skill_info]:
		var style := (panel as Control).get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		var local_style := style.duplicate() as StyleBoxFlat
		(panel as Control).add_theme_stylebox_override("panel", local_style)
		palette.call("bind_style", local_style, "surface", "structure")
		palette.call("bind_control_style", panel, "panel", "surface", "structure")
	for label in [action_title, action_hint, hex_choice_title,
			skill_info_description]:
		palette.call("bind_color", label, "font_color", "primary")


func _on_walk_pressed() -> void:
	if _in_combat():
		_on_combat_roll_pressed()
		return
	if _open_card == null or exploration == null:
		return
	if exploration.select_actor(_open_card.state.playable_slot_id):
		_close_actions()
		_walk_target_actor = exploration.current_actor


func _on_skill_pressed(actor: EntityState, grant: SkillGrantState) -> void:
	if grant != null and grant.skill != null \
			and grant.skill.id == &"item_active_003":
		_show_amulet_attunement(actor, grant)
		return
	if grant != null and grant.skill != null \
			and grant.skill.id == &"item_active_002":
		if _skill_is_available(actor, grant):
			_show_amulet_dead_selection(actor, grant)
		return
	if _in_combat():
		if not _skill_is_available(actor, grant):
			return
		var combat_skill := grant.skill as ActiveSkillData
		if combat_skill.target_mode in [ActiveSkillData.TargetMode.SELF,
				ActiveSkillData.TargetMode.NONE]:
			var result := skill_manager.use_combat_active(actor, grant,
				gerencia.campaign, combat_manager)
			if result.get("success", false):
				combat_manager.action_resolved.emit(actor, &"skill", result)
				if combat_skill.ends_turn:
					combat_manager.end_current_turn()
			_rebuild_action_buttons()
		elif _is_ally_target_skill(combat_skill):
			_show_combat_ally_selection(actor, grant)
		else:
			if combat_manager.select_player_skill(grant):
				_close_inventory()
				_hide_hex_choice()
				action_hint.text = "Escolha o alvo para %s." % combat_skill.display_name
				action_hint.show()
		return
	if exploration == null or exploration.player_skill_manager == null:
		return
	_walk_target_actor = null
	var skill := grant.skill as ActiveSkillData
	if skill == null:
		return
	if actor.turn_state == EntityState.TurnState.INACTIVE \
			and actor in gerencia.campaign.active_entity_states:
		if exploration.reactivate_extra_movement(actor, grant):
			_close_actions()
		else:
			_rebuild_action_buttons()
		return
	if skill.target_mode == ActiveSkillData.TargetMode.TILE:
		_targeting_actor = actor
		_targeting_grant = grant
		_close_inventory()
		ally_drawer.hide()
		_hide_hex_choice()
		action_hint.text = "Escolha no mapa o hex para %s." % skill.display_name
		action_hint.show()
		_position_action_drawer(false)
		return
	if skill.effects.any(func(effect: SkillEffectData) -> bool:
		return effect.effect_type == SkillEffectData.EffectType.MODIFY_CRAFT_COST):
		_show_craft_choices(actor, grant)
		return
	if skill.target_mode == ActiveSkillData.TargetMode.ITEM:
		_show_time_accelerator_choices(actor, grant)
		return
	if exploration.player_skill_manager.use_exploration_active(actor, grant,
			EntityState.UNPLACED, exploration):
		_close_actions()
	else:
		_rebuild_action_buttons()


func _time_accelerator_options(actor: EntityState,
		grant: SkillGrantState) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if actor == null or grant == null or actor != exploration.current_actor:
		return options
	var inventory := skill_manager.inventory_manager
	for entry in actor.inventory_items:
		if entry == null or entry.data == null:
			continue
		for raw_result in entry.data.craft_result:
			var result := raw_result as ItemData
			if inventory.can_transform_single_item(actor, entry, result) \
					and skill_manager.can_use_exploration_active(actor, actor, grant,
					gerencia.campaign, EntityState.UNPLACED,
					exploration.block_manager, gerencia.map_view, false,
					{"selected_item": entry, "result_item": result}):
				options.append({"entry": entry, "result": result})
	return options


func _show_time_accelerator_choices(actor: EntityState,
		grant: SkillGrantState) -> void:
	_clear_buttons(hex_choice_buttons)
	for option in _time_accelerator_options(actor, grant):
		var entry := option["entry"] as InventoryItemState
		var result := option["result"] as ItemData
		var button := _make_choice_button("%s → %s" % [
			entry.data.display_name, result.display_name], Color(0.52, 0.36, 0.055))
		button.pressed.connect(_on_time_accelerator_choice.bind(actor, grant, entry, result))
		hex_choice_buttons.add_child(button)
	if hex_choice_buttons.get_child_count() == 0:
		_rebuild_action_buttons()
		return
	hex_choice_title.text = "ESCOLHA O ITEM PARA EVOLUIR"
	_close_inventory()
	ally_drawer.hide()
	hex_choice.show()
	_position_hex_choice(action_drawer.position + Vector2(action_drawer.size.x + 12.0, 0.0))


func _on_time_accelerator_choice(actor: EntityState, grant: SkillGrantState,
		entry: InventoryItemState, result: ItemData) -> void:
	_hide_hex_choice()
	if exploration.player_skill_manager.use_exploration_active(actor, grant,
		EntityState.UNPLACED, exploration,
		{"selected_item": entry, "result_item": result}):
		_close_actions()
	else:
		_rebuild_action_buttons()


func _show_craft_choices(actor: EntityState, grant: SkillGrantState) -> void:
	var options := exploration.player_skill_manager.get_craft_options(actor, grant, exploration)
	_clear_buttons(hex_choice_buttons)
	for option in options:
		var ingredient: ItemData = option["ingredient"]
		for result in option["results"]:
			var item := result as ItemData
			var button := _make_choice_button("%s → %s" % [ingredient.display_name,
				item.display_name], Color(0.52, 0.36, 0.055))
			button.pressed.connect(_on_craft_choice_pressed.bind(actor, grant,
				ingredient.id, item.id))
			hex_choice_buttons.add_child(button)
	if hex_choice_buttons.get_child_count() == 0:
		_rebuild_action_buttons()
		return
	hex_choice_title.text = "ESCOLHA O ITEM ÉPICO"
	_close_inventory()
	ally_drawer.hide()
	hex_choice.show()
	_position_hex_choice(action_drawer.position + Vector2(action_drawer.size.x + 12.0, 0.0))


func _on_craft_choice_pressed(actor: EntityState, grant: SkillGrantState,
		ingredient_id: StringName, result_id: StringName) -> void:
	_hide_hex_choice()
	if exploration.player_skill_manager.use_craft_active(actor, grant,
			ingredient_id, result_id, exploration):
		_close_actions()
	else:
		_rebuild_action_buttons()
