class_name BlockActivationPopup
extends CanvasLayer

## Mostra a narrativa do hex antes da decisão. A caixa não aplica efeitos de
## Evento nem simula Combate: ela envia a escolha aos respectivos gestores.
## Itens simples já podem entrar nos inventários usando o InventoryManager.

@export var block_manager: BlockManager
@export var skill_manager: SkillManager
@export var player_skill_manager: PlayerSkillManager
@export var event_executor: Node
@export var combat_manager: Node
@export var exploration: ExplorationManager
@export var playable_party_view: PlayablePartyView

@onready var overlay: Control = $Overlay
@onready var frame_area: Control = $Overlay/Center/FrameArea
@onready var title_label: Label = $Overlay/Center/FrameArea/TitleBanner/Title
@onready var title_banner: TextureRect = $Overlay/Center/FrameArea/TitleBanner
@onready var frame_rect: TextureRect = $Overlay/Center/FrameArea/Frame
@onready var content_area: MarginContainer = $Overlay/Center/FrameArea/Content
@onready var conclusion_title: Label = $Overlay/Center/FrameArea/Content/Body/ConclusionTitle
@onready var encounter_name: Label = $Overlay/Center/FrameArea/Content/Body/EncounterName
@onready var item_preview: CenterContainer = $Overlay/Center/FrameArea/Content/Body/ItemPreview
@onready var item_icon: TextureRect = $Overlay/Center/FrameArea/Content/Body/ItemPreview/PreviewRow/ItemIcon
@onready var missing_item_icon: Label = $Overlay/Center/FrameArea/Content/Body/ItemPreview/PreviewRow/MissingIcon
@onready var item_info_button: Button = $Overlay/Center/FrameArea/Content/Body/ItemPreview/PreviewRow/InfoButton
@onready var narrative_label: Label = $Overlay/Center/FrameArea/Content/Body/NarrativeScroll/NarrativeInset/Narrative
@onready var narrative_scroll: ScrollContainer = $Overlay/Center/FrameArea/Content/Body/NarrativeScroll
@onready var feedback_label: Label = $Overlay/Center/FrameArea/Content/Body/Feedback
@onready var buttons: HFlowContainer = $Overlay/Center/FrameArea/Content/Body/Buttons
@onready var rewards_container: HFlowContainer = $Overlay/Center/FrameArea/Content/Body/Rewards
@onready var skill_info: PanelContainer = $Overlay/SkillInfo
@onready var skill_info_description: Label = $Overlay/SkillInfo/Margin/Content/Description

const ACTION_GOLD := Color(0.52, 0.36, 0.055)
const INVENTORY_BLUE := Color(0.075, 0.27, 0.53)
const COMBAT_BLACK := Color(0.025, 0.025, 0.035)
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const NARRATIVE_FONT := preload("res://scripts/ui/ui_narrative_font.gd")
const WHITE_FRAME_SHADER := preload("res://shaders/ui_cyan_to_white_80.gdshader")
const ITEM_PICKER_SCRIPT := preload("res://scripts/ui/event_item_picker.gd")
const REWARD_DETAILS_SCRIPT := preload("res://scripts/ui/event_reward_details_panel.gd")
const GENIE_SHEET_PATH := "res://scenes/ui/character_sheet_panel.tscn"
const HEX_ARRIVAL_PAUSE_SECONDS := 0.5

var _context: Dictionary = {}
var _pre_activation_pending := false
var _result_shown := false
var _outcome_reading := false
var _theft_outcome_pages: Array[String] = []
var _combat_conclusion_open := false
var _pending_loot_decline_confirmation := false
var _combat_loot_labels: Array[Label] = []
var _combat_trap_open := false
var _event_die_pending := false
var _event_die_animating := false
var _trap_die_pending := false
var _roll_button: Button
var _normal_frame_material: Material
var _invalid_symbiosis := false
var _post_reveal_warning := false
var _wooden_doll_prompt := false
var _coin_choice: StringName = &""
var _waiting_inventory_close := false
var _catalog_picker: Control
var _catalog_pending_decision: Dictionary = {}
var _preview_item: ItemData
var _reward_details: EventRewardDetailsPanel
var _reward_details_blocker: ColorRect
var _reward_details_layer: Control
var _genie_pending_outcome: EventOutcomeData
var _genie_info_panel: PanelContainer
var _genie_info_title: Label
var _genie_info_description: Label
var _genie_sheet: CharacterSheetPanel
var _hex_arrival_token := 0
var _hex_walk_pending := false
var _hex_popup_prepared := false


func _carreta_visual() -> Node:
	return event_executor.get_node_or_null("../CarretaVisualController") \
		if event_executor != null else null


func _start_carreta_visual() -> void:
	var visual := _carreta_visual()
	if visual != null:
		visual.call("start_effect")


func _stop_carreta_visual() -> void:
	var visual := _carreta_visual()
	if visual != null:
		visual.call("stop_effect")


func _ready() -> void:
	title_label.add_theme_font_override("font", BOLD_FONT)
	conclusion_title.add_theme_font_override("font", BOLD_FONT)
	NARRATIVE_FONT.apply_label(narrative_label)
	NARRATIVE_FONT.apply_label(skill_info_description)
	_normal_frame_material = frame_rect.material
	if block_manager != null:
		block_manager.item_decision_requested.connect(show_block)
		block_manager.information_confirmation_requested.connect(show_block)
		block_manager.event_confirmation_requested.connect(show_block)
		block_manager.wooden_doll_cancel_requested.connect(_show_wooden_doll_cancel)
		block_manager.encounter_confirmation_requested.connect(show_block)
		block_manager.block_finished.connect(_on_block_finished)
	if player_skill_manager != null:
		player_skill_manager.pre_activation_choice_requested.connect(_show_pre_activation)
	if exploration != null:
		exploration.actor_moved.connect(_on_exploration_actor_moved)
		exploration.actor_teleported.connect(_on_exploration_actor_teleported)
		exploration.map_entered.connect(_on_exploration_map_entered)
	if event_executor != null:
		event_executor.connect("outcome_prepared", _on_event_outcome_prepared)
		event_executor.connect("result_ready", _on_event_result_ready)
		event_executor.connect("resolution_blocked", _on_event_resolution_blocked)
	if combat_manager != null:
		combat_manager.connect("conclusion_requested", _on_combat_conclusion_requested)
		combat_manager.connect("combat_trap_requested", _on_combat_trap_requested)
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color(0.035, 0.05, 0.065, 0.94)
	info_style.border_color = Color(0.996078, 0.168627, 0.592157)
	info_style.set_border_width_all(1)
	info_style.set_corner_radius_all(4)
	skill_info.add_theme_stylebox_override("panel", info_style)
	_catalog_picker = ITEM_PICKER_SCRIPT.new() as Control
	_catalog_picker.name = "EventItemPicker"
	overlay.add_child(_catalog_picker)
	_catalog_picker.connect("item_confirmed", _confirm_catalog_selection)
	_catalog_picker.connect("reward_forfeited", _forfeit_catalog_reward)
	_catalog_picker.connect("details_requested", _show_reward_item_details)
	item_info_button.pressed.connect(func() -> void:
		_show_reward_item_details(_preview_item))
	_style_item_info_button(item_info_button)
	_reward_details_layer = Control.new()
	_reward_details_layer.name = "RewardDetailsLayer"
	_reward_details_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_details_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_details_layer.z_index = 250
	overlay.add_child(_reward_details_layer)
	_reward_details_blocker = ColorRect.new()
	_reward_details_blocker.name = "RewardDetailsBlocker"
	_reward_details_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reward_details_blocker.color = Color(0, 0, 0, 0.56)
	_reward_details_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_reward_details_blocker.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_reward_item_details())
	_reward_details_layer.add_child(_reward_details_blocker)
	_reward_details = REWARD_DETAILS_SCRIPT.new() as EventRewardDetailsPanel
	_reward_details.name = "RewardItemDetails"
	_reward_details.z_index = 302
	overlay.add_child(_reward_details)
	_reward_details.close_requested.connect(_hide_reward_item_details)
	_build_genie_info_panel()
	_hide_reward_item_details()
	overlay.hide()


func _on_exploration_actor_moved(actor: EntityState,
		_path: Array[Vector2i], _stamina_spent: int) -> void:
	if actor == null or playable_party_view == null:
		return
	var visual := playable_party_view.visuals_by_slot.get(
		actor.playable_slot_id) as PlayableActorVisual
	if visual == null or not visual.is_inside_tree():
		return
	_hex_arrival_token += 1
	_hex_walk_pending = true
	_hex_popup_prepared = false
	visual.walk_finished.connect(_on_hex_walk_finished.bind(_hex_arrival_token),
		CONNECT_ONE_SHOT)


func _on_hex_walk_finished(token: int) -> void:
	await get_tree().create_timer(HEX_ARRIVAL_PAUSE_SECONDS).timeout
	if not is_inside_tree() or token != _hex_arrival_token:
		return
	_hex_walk_pending = false
	if _hex_popup_prepared and not _context.is_empty():
		_present_block_overlay()
	_hex_popup_prepared = false


func _on_exploration_actor_teleported(_actor: EntityState,
		_destination: Vector2i) -> void:
	_hex_arrival_token += 1
	_hex_walk_pending = true
	_hex_popup_prepared = false
	_on_hex_walk_finished(_hex_arrival_token)


func _on_exploration_map_entered(_map: HexGrid) -> void:
	_cancel_hex_arrival_wait()


func _cancel_hex_arrival_wait() -> void:
	_hex_arrival_token += 1
	_hex_walk_pending = false
	_hex_popup_prepared = false


func _style_item_info_button(button: Button) -> void:
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.82, 0.72, 0.34))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.51))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())


## Também permite uma prévia visual sem ativar um bloco (útil no editor/teste).
func show_block(context: Dictionary) -> void:
	_stop_carreta_visual()
	_pre_activation_pending = false
	_result_shown = false
	_outcome_reading = false
	_event_die_pending = false
	_event_die_animating = false
	_trap_die_pending = false
	_combat_conclusion_open = false
	_invalid_symbiosis = false
	_post_reveal_warning = false
	_wooden_doll_prompt = false
	_coin_choice = &""
	_waiting_inventory_close = false
	_catalog_pending_decision.clear()
	_genie_pending_outcome = null
	frame_area.custom_minimum_size.y = 585.0
	content_area.offset_left = 64.0
	content_area.offset_bottom = -102.0
	narrative_scroll.custom_minimum_size.y = 0.0
	narrative_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hide_reward_item_details()
	if _catalog_picker != null:
		_catalog_picker.hide()
	_clear_rewards()
	_restore_normal_frame()
	skill_info.hide()
	_context = context.duplicate()
	var content := _context.get("resource") as Resource
	if content == null:
		return
	if content is EncounterData:
		title_label.text = "ENCONTRO INDESEJADO"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.23, 0.28))
		encounter_name.text = (content as EncounterData).display_name
		encounter_name.show()
	else:
		title_label.text = _display_name(content).to_upper()
		title_label.add_theme_color_override("font_color", Color(0.996, 0.169, 0.592))
		encounter_name.hide()
	_fit_title_inside_banner()
	narrative_label.text = _narrative(content)
	feedback_label.hide()
	_clear_buttons()
	if content is ItemData:
		_show_item_preview(content as ItemData)
		_show_item_buttons(content as ItemData)
	elif content is Informacao:
		_add_button("CONFIRMAR", ACTION_GOLD, _confirm_information, true)
	elif content is EncounterData:
		_add_button("INICIAR COMBATE", COMBAT_BLACK, _confirm_encounter, true)
	elif content is EventData:
		_show_event_buttons(content as EventData)
	else:
		return
	if _hex_walk_pending:
		_hex_popup_prepared = true
		return
	_present_block_overlay()


func _present_block_overlay() -> void:
	var content := _context.get("resource") as Resource
	if content == null:
		return
	overlay.show()
	get_node("/root/UISFX").call("play", &"hex_open")
	if content is ItemData:
		get_node("/root/UISFX").call("play", &"item_reward")
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.16)


func _show_item_preview(item: ItemData) -> void:
	# Ícone ampliado, mas contido no espaço reservado do diálogo.
	item_icon.texture = item.icon
	_preview_item = item
	item_icon.visible = item.icon != null
	missing_item_icon.visible = item.icon == null
	item_preview.show()
	frame_area.custom_minimum_size.y = 585.0


func _show_reward_item_details(item: ItemData) -> void:
	if item == null or _reward_details == null:
		return
	_reward_details.bind_catalog_item(item)
	_position_reward_item_details()
	_reward_details_blocker.show()
	_reward_details.show()


func _position_reward_item_details() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var event_bounds := frame_area.get_global_rect()
	var right_space := viewport_size.x - event_bounds.end.x - 22.0
	var left_space := event_bounds.position.x - 22.0
	var place_right := right_space >= left_space
	var side_space := right_space if place_right else left_space
	_reward_details.layout_compact(clampf(side_space, 220.0, 310.0))
	var x := event_bounds.end.x + 12.0 if place_right else event_bounds.position.x - _reward_details.size.x - 12.0
	if side_space < _reward_details.size.x:
		x = viewport_size.x - _reward_details.size.x - 10.0 if place_right else 10.0
	_reward_details.position = Vector2(
		clampf(x, 10.0, maxf(10.0, viewport_size.x - _reward_details.size.x - 10.0)),
		clampf(event_bounds.position.y + 25.0, 55.0,
			maxf(55.0, viewport_size.y - _reward_details.size.y - 10.0)))


func _hide_reward_item_details() -> void:
	if _reward_details != null:
		_reward_details.hide()
	if _genie_info_panel != null:
		_genie_info_panel.hide()
	if _genie_sheet != null and _genie_sheet.visible:
		_genie_sheet.close_sheet()
	if _reward_details_blocker != null:
		_reward_details_blocker.hide()


func _build_genie_info_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.z_index = 305
	overlay.add_child(center)
	_genie_info_panel = PanelContainer.new()
	_genie_info_panel.custom_minimum_size = Vector2(480, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.075, 0.98)
	style.border_color = Color(0.996, 0.169, 0.592)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	_genie_info_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_genie_info_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_genie_info_panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	_genie_info_title = Label.new()
	_genie_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_genie_info_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_genie_info_title.add_theme_font_override("font", BOLD_FONT)
	_genie_info_title.add_theme_font_size_override("font_size", 17)
	_genie_info_title.add_theme_color_override("font_color", Color(0.996, 0.169, 0.592))
	header.add_child(_genie_info_title)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(30, 30)
	close.add_theme_font_override("font", BOLD_FONT)
	close.add_theme_color_override("font_color", Color(0.95, 0.26, 0.30))
	close.pressed.connect(_hide_reward_item_details)
	header.add_child(close)
	_genie_info_description = Label.new()
	_genie_info_description.custom_minimum_size = Vector2(430, 90)
	_genie_info_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	NARRATIVE_FONT.apply_label(_genie_info_description)
	_genie_info_description.add_theme_font_size_override("font_size", 15)
	_genie_info_description.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
	body.add_child(_genie_info_description)
	_genie_info_panel.hide()


func _show_genie_info(title: String, description: String) -> void:
	_genie_info_title.text = title.to_upper()
	_genie_info_description.text = description
	_reward_details_blocker.show()
	_genie_info_panel.show()


func _show_genie_actor_sheet(actor: EntityState) -> void:
	if actor == null:
		return
	if _genie_sheet == null:
		_genie_sheet = (load(GENIE_SHEET_PATH) as PackedScene).instantiate() as CharacterSheetPanel
		_genie_sheet.z_index = 310
		overlay.add_child(_genie_sheet)
		_genie_sheet.close_requested.connect(_hide_reward_item_details)
	_reward_details_blocker.show()
	_genie_sheet.open_for(actor, skill_manager, frame_area.global_position)


func _fit_title_inside_banner() -> void:
	# Título curto usa moldura estreita; nomes longos só a expandem se necessário.
	var base_width := frame_area.custom_minimum_size.x
	var max_width := base_width - 28.0
	var banner_width := minf(400.0, max_width)
	var font_size := 20
	while font_size > 14 and BOLD_FONT.get_string_size(title_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * 4.0 / 3.0)).x \
			> banner_width - 106.0:
		font_size -= 1
	var text_width := BOLD_FONT.get_string_size(title_label.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * 4.0 / 3.0)).x
	banner_width = clampf(text_width + 106.0, banner_width, max_width)
	while font_size > 12 and text_width > banner_width - 106.0:
		font_size -= 1
		text_width = BOLD_FONT.get_string_size(title_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * 4.0 / 3.0)).x
	var side := (base_width - banner_width) * 0.5
	title_banner.offset_left = side
	title_banner.offset_right = -side
	title_label.add_theme_font_size_override("font_size", font_size)


func _show_pre_activation(actor: EntityState, coord: Vector2i,
		options: Array[SkillGrantState]) -> void:
	if block_manager == null or block_manager.gerencia == null:
		return
	var event := block_manager.gerencia.campaign.current_map.get_ppp_block_resource(coord) as EventData
	if event == null:
		return
	# Mostra primeiro a MESMA narrativa e os botões normais do Evento.
	# A Ativa preventiva entra como mais uma escolha na própria consequência.
	show_block({"resource": event, "actor": actor, "coord": coord})
	_pre_activation_pending = true
	for grant in options:
		var skill := grant.skill as ActiveSkillData
		if skill == null:
			continue
		var label := skill.consequence_button_label
		if label.is_empty():
			label = "CANCELAR / %s" % skill.display_name
		var button := _add_button(label, ACTION_GOLD,
			_confirm_prevent_event.bind(grant), true)
		button.custom_minimum_size.x = 258.0
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.add_theme_font_size_override("font_size", 11)
		button.tooltip_text = skill.description
		button.mouse_entered.connect(_show_skill_info.bind(button, skill))
		button.mouse_exited.connect(_hide_skill_info)


func _confirm_prevent_event(grant: SkillGrantState) -> void:
	if player_skill_manager == null or not player_skill_manager.answer_pre_activation_choice(grant):
		_show_feedback("Não foi possível cancelar este evento.")


func _show_wooden_doll_cancel(context: Dictionary) -> void:
	show_block(context)
	var event := context.get("resource") as EventData
	if event == null:
		return
	_wooden_doll_prompt = true
	title_label.text = "Bonequinho cancelou %s" % event.display_name
	_fit_title_inside_banner()
	narrative_label.text = "Ufa?"
	_clear_buttons()
	_add_button("OK", ACTION_GOLD, _confirm_wooden_doll_cancel, true)
	feedback_label.hide()


func _confirm_wooden_doll_cancel() -> void:
	if block_manager == null or not block_manager.confirm_wooden_doll_cancellation():
		_show_feedback("Não foi possível concluir a proteção do Bonequinho.")


func _show_skill_info(button: Button, skill: ActiveSkillData) -> void:
	if button == null or skill == null or not button.is_inside_tree():
		return
	skill_info_description.text = skill.description
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


func _display_name(content: Resource) -> String:
	if content is ItemData:
		return (content as ItemData).display_name
	if content is Informacao:
		return (content as Informacao).titulo
	if content is EncounterData:
		return (content as EncounterData).display_name
	if content is EventData:
		return (content as EventData).display_name
	return "Bloco ativado"


func _narrative(content: Resource) -> String:
	if content is EventData:
		var event := content as EventData
		var story := event.narrative_description if not event.narrative_description.is_empty() else event.description
		if event_executor != null and event_executor.has_method("resolve_narrative"):
			return event_executor.call("resolve_narrative", event, story, _context)
		return story
	if content is EncounterData:
		var encounter := content as EncounterData
		if not encounter.narrative_description.is_empty():
			return encounter.narrative_description
		var stories: Array[String] = []
		for member in encounter.members:
			if member != null and member.entity != null:
				var story: String = member.entity.narrative_description.strip_edges()
				if story.is_empty():
					story = member.entity.description.strip_edges()
				if not story.is_empty() and story not in stories:
					stories.append(story)
		return "\n\n".join(stories) if not stories.is_empty() else "Criaturas surgem à sua frente."
	if content is ItemData:
		return (content as ItemData).description
	if content is Informacao:
		return (content as Informacao).descricao
	return ""


func _show_item_buttons(item: ItemData) -> void:
	var owner := _context.get("actor") as EntityState
	var campaign := block_manager.gerencia.campaign if block_manager != null \
		and block_manager.gerencia != null else null
	if CampaignState.is_cursed_item(item) and campaign != null \
			and campaign.has_sacred_temple_blessing():
		title_label.text = "MALDIÇÃO ANULADA"
		_fit_title_inside_banner()
		narrative_label.text = "O dia de hoje está abençoado."
		item_preview.hide()
		_add_button("OK", INVENTORY_BLUE, _acknowledge_curse_immunity, true)
		return
	if CampaignState.is_cursed_item(item) and owner != null \
			and owner.is_curse_immune():
		_add_button("OK", INVENTORY_BLUE, _acknowledge_curse_immunity, true)
		_show_feedback("A proteção milagrosa impediu esta maldição.")
		return
	var inventory := _inventory()
	var can_accept := inventory != null and inventory.can_receive(owner, item)
	# Inventário cheio abre a janela do grupo; a troca só ocorre após SIM.
	_add_button("ACEITAR", INVENTORY_BLUE, _accept_item,
		inventory != null and owner != null)
	var recipients := _available_teammates(item)
	_add_button("TRANSFERIR", INVENTORY_BLUE, _show_transfer_choices,
		item.item_type != ItemData.ItemType.CURSED and not recipients.is_empty())
	_add_button("DESCARTAR", INVENTORY_BLUE, _discard_item,
		item.can_be_discarded and item.item_type != ItemData.ItemType.CURSED)
	if not can_accept:
		_show_feedback("Seu inventário está cheio. Selecione ACEITAR para abrir o inventário do grupo e escolher uma troca.")


func _acknowledge_curse_immunity() -> void:
	if block_manager != null and block_manager.finish_item_resolution(false):
		overlay.hide()


func _show_transfer_choices() -> void:
	var item := _context.get("resource") as ItemData
	if item == null:
		return
	_clear_buttons()
	for recipient in _available_teammates(item):
		_add_button(recipient.data.display_name.to_upper(), INVENTORY_BLUE,
			func() -> void: _transfer_item(recipient), true)
	_add_button("VOLTAR", INVENTORY_BLUE, func() -> void: _show_item_buttons(item), true)
	_show_feedback("Escolha qual colega receberá o item.")


func _available_teammates(item: ItemData) -> Array[EntityState]:
	var result: Array[EntityState] = []
	var owner := _context.get("actor") as EntityState
	var inventory := _inventory()
	if owner == null or inventory == null or block_manager == null \
			or block_manager.gerencia == null or item.item_type == ItemData.ItemType.CURSED:
		return result
	for candidate in block_manager.gerencia.campaign.active_entity_states:
		if candidate != owner and inventory.can_receive(candidate, item):
			result.append(candidate)
	return result


func _accept_item() -> void:
	var owner := _context.get("actor") as EntityState
	var item := _context.get("resource") as ItemData
	var inventory := _inventory()
	if inventory == null or item == null:
		return
	if not inventory.can_receive(owner, item):
		_open_item_exchange()
		return
	if not inventory.add_item(owner, item):
		_show_feedback("Não foi possível guardar o item.")
		return
	if block_manager != null:
		block_manager.finish_item_resolution(true)
	else:
		overlay.hide()


func _open_item_exchange() -> void:
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	var owner := _context.get("actor") as EntityState
	var item := _context.get("resource") as ItemData
	if top_bar == null or top_bar.group_inventory == null or owner == null or item == null:
		_show_feedback("O Inventário do grupo não está disponível.")
		return
	var can_refuse := item.item_type != ItemData.ItemType.CURSED and item.can_be_discarded
	if not top_bar.group_inventory.begin_exchange(owner, item,
			_complete_map_item_exchange, _decline_map_item_exchange, can_refuse):
		_show_feedback("Não foi possível abrir a troca no Inventário do grupo.")
		return
	_waiting_inventory_close = true
	overlay.hide()


func _complete_map_item_exchange(outgoing: Array[InventoryItemState]) -> bool:
	var owner := _context.get("actor") as EntityState
	var item := _context.get("resource") as ItemData
	var inventory := _inventory()
	if owner == null or item == null or inventory == null \
			or block_manager == null or not block_manager.is_busy() \
			or not inventory.exchange_items(owner, outgoing, item):
		return false
	return block_manager.finish_item_resolution(true)


func _decline_map_item_exchange() -> bool:
	var item := _context.get("resource") as ItemData
	return item != null and item.can_be_discarded \
		and item.item_type != ItemData.ItemType.CURSED \
		and block_manager != null and block_manager.finish_item_resolution(false)


func _transfer_item(recipient: EntityState) -> void:
	var item := _context.get("resource") as ItemData
	var inventory := _inventory()
	if inventory == null or not inventory.add_item(recipient, item):
		_show_feedback("Não há espaço no inventário escolhido.")
		return
	if block_manager != null:
		block_manager.finish_item_resolution(true)
	else:
		overlay.hide()


func _discard_item() -> void:
	var item := _context.get("resource") as ItemData
	if item == null or not item.can_be_discarded \
			or item.item_type == ItemData.ItemType.CURSED:
		return
	if block_manager != null:
		block_manager.finish_item_resolution(false)
	else:
		overlay.hide()


func _show_event_buttons(event: EventData) -> void:
	if event.id == &"ev_00049":
		_show_genie_wishes(event)
		return
	# Algumas consequências automáticas precisam de UMA escolha do jogador
	# antes do OK. A escolha vira parte da decisão enviada ao EventExecutor.
	if event.id == &"ev_00016":
		var actor := _context.get("actor") as EntityState
		if actor != null:
			for collection in [actor.equipped_weapons, actor.equipped_armors,
					actor.inventory_items]:
				for entry in collection:
					if entry != null and entry.data != null \
							and entry.data.equipment_slot in [
								ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR]:
						_add_button("APRIMORAR %s" % entry.data.display_name.to_upper(),
							ACTION_GOLD, _confirm_event.bind({"selected_item": entry}), true)
		if buttons.get_child_count() == 0:
			narrative_label.text = "Sem melhorias hoje... Quem sabe depois, né?!"
			_add_button("OK", ACTION_GOLD,
				_confirm_event.bind({"no_item": true}), true)
		return
	if event.outcomes.size() == 1 and event.outcomes[0] != null:
		var catalog_effect := _catalog_effect_for_outcome(event.outcomes[0])
		if catalog_effect != null:
			_add_button("ESCOLHER ITEM", ACTION_GOLD,
				_open_catalog_picker.bind(catalog_effect, {}), true)
			return
		for effect in event.outcomes[0].effects:
			if effect == null:
				continue
			if effect.effect_type == Event_EffectData.EffectType.APPLY_SKILL_EFFECT \
					and effect.effect != null \
					and effect.effect.effect_type == SkillEffectData.EffectType.MODIFY_MASTERY \
					and effect.effect.selection_mode == SkillEffectData.SelectionMode.PLAYER_CHOOSES_FROM_OPTIONS:
				for mastery in effect.effect.mastery_options:
					var label: String = ["", "LÂMINA", "IMPACTO", "DISTÂNCIA"][mastery]
					_add_button(label, ACTION_GOLD,
						_confirm_event.bind({"selected_mastery": mastery}), true)
				return
			if effect.grant_binding_source == Event_EffectData.GrantBindingSource.SELECTED_OWNED_ITEM:
				var actor := _context.get("actor") as EntityState
				if actor != null:
					var entries: Array[InventoryItemState] = []
					entries.append_array(actor.inventory_items)
					entries.append_array(actor.equipped_weapons)
					if event.id == &"ev_00058":
						_show_symbiosis_choices(actor, entries)
						return
					for entry in entries:
						if entry.data != null \
								and entry.data.equipment_slot == effect.required_bound_item_slot \
								and entry.data.rarity == effect.required_bound_item_rarity:
							_add_button("ABSORVER %s" % entry.data.display_name.to_upper(),
								ACTION_GOLD, _confirm_event.bind({"selected_item": entry}), true)
				if buttons.get_child_count() == 0:
					_show_feedback("É preciso possuir uma arma Épica para este efeito.")
				return
			if effect.grant_binding_source == Event_EffectData.GrantBindingSource.SELECTED_ENEMY_FROM_LAST_ENCOUNTER:
				if block_manager != null and block_manager.gerencia != null:
					for enemy in block_manager.gerencia.campaign.last_encounter_entity_types:
						_add_button("COPIAR %s" % enemy.display_name.to_upper(), ACTION_GOLD,
							_confirm_event.bind({"selected_enemy": enemy}), true)
				if buttons.get_child_count() == 0:
					_show_feedback("Este efeito precisa de um Encontro anterior.")
				return
	match event.resolution_mode:
		EventData.ResolutionMode.PLAYER_CHOOSES_OUTCOME:
			for outcome in event.outcomes:
				if outcome != null:
					if event.id == &"ev_00049" \
							and outcome.id == &"revive_dead_playable":
						if block_manager != null and block_manager.gerencia != null:
							for deceased in block_manager.gerencia.campaign.dead_playable_states:
								_add_button("RESSUSCITAR %s" % deceased.data.display_name.to_upper(),
									ACTION_GOLD, _confirm_event.bind({"outcome": outcome,
										"outcome_id": outcome.id,
										"selected_dead_actor": deceased}), true)
						continue
					var decision := {"outcome": outcome, "outcome_id": outcome.id}
					var chosen_effect := _catalog_effect_for_outcome(outcome)
					var choice_button := _add_button(outcome.display_name.to_upper(), ACTION_GOLD,
						_open_catalog_picker.bind(chosen_effect, decision) if chosen_effect != null \
						else _confirm_event.bind(decision), true)
					if event.id == &"ev_00017" and not outcome.effects.is_empty() \
							and block_manager != null and block_manager.gerencia != null \
							and block_manager.gerencia.campaign.filter_uncollected_information(
								block_manager.gerencia.get_information_catalog()).is_empty():
						choice_button.disabled = true
						choice_button.tooltip_text = "Todas as Informações já foram obtidas; não há nova pista para receber."
		EventData.ResolutionMode.PLAYER_ACCEPTS_THEN_OUTCOME:
			_add_button("CONCORDAR", ACTION_GOLD,
				func() -> void: _confirm_event({"accepted": true}), true)
			_add_button("RECUSAR", ACTION_GOLD,
				func() -> void: _confirm_event({"accepted": false}), true)
		EventData.ResolutionMode.PLAYER_GUESSES_RANDOM_OPTION:
			# A mesma interface atende qualquer Evento futuro com duas faces.
			for index in event.guess_options.size():
				var option := event.guess_options[index]
				_add_button("%s (%s)" % [str(option).to_upper(), CoinFlip.side_label(index)],
					ACTION_GOLD, _select_coin_guess.bind(option), true)
			if event.guess_refusal_outcome != null:
				_add_button("NÃO JOGAR", ACTION_GOLD,
					func() -> void: _confirm_event({"refused": true}), true)
		_:
			_add_button("OK", ACTION_GOLD,
				_preview_gnome_spawn.bind(event) if event.custom_rule == &"spawn_gnomes_3" \
					and not event.outcomes.is_empty() \
					and event.outcomes[0] != null \
					and not event.outcomes[0].narrative_description.is_empty() \
					else func() -> void: _confirm_event({}), true)
	if buttons.get_child_count() == 0:
		_add_button("PROSSEGUIR", ACTION_GOLD,
			func() -> void: _confirm_event({}), true)


func _preview_gnome_spawn(event: EventData) -> void:
	var outcome := event.outcomes[0]
	_outcome_reading = true
	title_label.text = outcome.display_name.to_upper()
	_fit_title_inside_banner()
	narrative_label.text = outcome.narrative_description
	_clear_buttons()
	_add_button("OK", ACTION_GOLD, func() -> void:
		_outcome_reading = false
		_confirm_event({}), true)
	feedback_label.hide()
	get_node("/root/UISFX").call("play", &"hex_open")


func _show_genie_wishes(event: EventData) -> void:
	_genie_pending_outcome = null
	frame_area.custom_minimum_size.y = 685.0
	content_area.offset_left = 82.0
	# O texto do desejo deve ficar todo visível: os botões podem avançar sobre
	# a faixa rosa decorativa, preservando a margem inferior da janela.
	content_area.offset_bottom = -65.0
	narrative_scroll.custom_minimum_size.y = 155.0
	narrative_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_label.text = event.display_name.to_upper()
	_fit_title_inside_banner()
	narrative_label.text = event.narrative_description
	_clear_buttons()
	var actor := _context.get("actor") as EntityState
	var deceased: Array[EntityState] = []
	if block_manager != null and block_manager.gerencia != null:
		deceased = block_manager.gerencia.campaign.dead_playable_states
	for outcome in event.outcomes:
		if outcome == null or outcome.id == &"revive_dead_playable" and deceased.is_empty() \
				or not EventCampaignEligibility.allows_outcome(outcome,
					block_manager.gerencia.campaign.campaign_mode):
			continue
		var caption := _genie_wish_caption(outcome)
		_add_genie_option(caption, outcome.narrative_description,
			_preview_genie_wish.bind(outcome))
	if actor == null:
		_show_feedback("O desejante não está disponível.")
	else:
		feedback_label.hide()


func _genie_wish_caption(outcome: EventOutcomeData) -> String:
	match outcome.id:
		&"new_passive": return "PASSIVA NOVA"
		&"status_immunity": return "IMUNIDADE A STATUS"
		&"combat_protection": return "PROTEÇÃO DE COMBATE"
		&"remove_curses": return "REMOVER MALDIÇÕES"
		&"choose_item": return "ESCOLHER ITEM"
		&"random_information": return "INFORMAÇÃO ALEATÓRIA"
		&"double_stat": return "DOBRAR ATRIBUTO"
		&"revive_dead_playable": return "RESSUSCITAR PERSONAGEM"
	return outcome.display_name


func _add_genie_option(caption: String, description: String,
		action: Callable, info_action: Callable = Callable()) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(275, 46)
	row.add_theme_constant_override("separation", 4)
	buttons.add_child(row)
	var main := _add_button(caption.to_upper(), ACTION_GOLD, action, true, row)
	main.custom_minimum_size = Vector2(238, 46)
	main.add_theme_font_size_override("font_size", 13)
	var info := Button.new()
	info.text = "ⓘ"
	info.tooltip_text = "Ver informações sobre %s" % caption
	info.custom_minimum_size = Vector2(30, 42)
	info.focus_mode = Control.FOCUS_ALL
	info.pressed.connect(info_action if info_action.is_valid() else \
		_show_genie_info.bind(caption, description))
	_style_item_info_button(info)
	row.add_child(info)


func _preview_genie_wish(outcome: EventOutcomeData) -> void:
	_genie_pending_outcome = outcome
	title_label.text = "CONFIRMAR DESEJO"
	_fit_title_inside_banner()
	narrative_label.text = outcome.narrative_description
	_clear_buttons()
	_add_button("CONFIRMAR E PROSSEGUIR", ACTION_GOLD, _continue_genie_wish, true)
	_add_button("VOLTAR AOS DESEJOS", ACTION_GOLD,
		_show_genie_wishes.bind(_context.get("resource") as EventData), true)
	feedback_label.hide()


func _continue_genie_wish() -> void:
	var outcome := _genie_pending_outcome
	if outcome == null:
		return
	var decision := {"outcome": outcome, "outcome_id": outcome.id}
	if not outcome.effect_choices.is_empty():
		title_label.text = "ESCOLHA A PROTEÇÃO" if outcome.id != &"double_stat" \
			else "ESCOLHA O ATRIBUTO"
		_fit_title_inside_banner()
		narrative_label.text = outcome.narrative_description
		_clear_buttons()
		for option in outcome.effect_choices:
			var selected := decision.duplicate()
			selected["effect_choice"] = option
			_add_genie_option(option.display_name, option.description,
				_confirm_event.bind(selected))
		_add_button("VOLTAR", ACTION_GOLD, _preview_genie_wish.bind(outcome), true)
		return
	match outcome.id:
		&"new_passive":
			var actor := _context.get("actor") as EntityState
			var choices: Array[PassiveSkillData] = event_executor.get_passive_choices(actor) \
				if event_executor != null else []
			title_label.text = "ESCOLHA A PASSIVA"
			_fit_title_inside_banner()
			narrative_label.text = "Escolha uma Passiva que o desejante ainda não possui. O ⓘ descreve sua função."
			_clear_buttons()
			for passive in choices:
				var selected := decision.duplicate()
				selected["selected_passive"] = passive
				_add_genie_option(passive.display_name, passive.description,
					_confirm_event.bind(selected))
			if choices.is_empty():
				_show_feedback("Não há Passiva nova disponível para este personagem.")
			_add_button("VOLTAR", ACTION_GOLD, _preview_genie_wish.bind(outcome), true)
		&"choose_item":
			_open_catalog_picker(_catalog_effect_for_outcome(outcome), decision)
		&"revive_dead_playable":
			title_label.text = "ESCOLHA QUEM RESSUSCITAR"
			_fit_title_inside_banner()
			narrative_label.text = outcome.narrative_description
			_clear_buttons()
			if block_manager != null and block_manager.gerencia != null:
				for deceased in block_manager.gerencia.campaign.dead_playable_states:
					var selected := decision.duplicate()
					selected["selected_dead_actor"] = deceased
					_add_genie_option(deceased.visible_name(),
						"Consulte a ficha do personagem que será ressuscitado.",
						_confirm_event.bind(selected),
						_show_genie_actor_sheet.bind(deceased))
			_add_button("VOLTAR", ACTION_GOLD, _preview_genie_wish.bind(outcome), true)
		_:
			_confirm_event(decision)


func _catalog_effect_for_outcome(outcome: EventOutcomeData) -> Event_EffectData:
	if outcome == null:
		return null
	for effect in outcome.effects:
		if effect != null and effect.effect_type == Event_EffectData.EffectType.GRANT_ITEM \
				and effect.selection_mode == Event_EffectData.SelectionMode.PLAYER_CHOOSES_FROM_CATALOG:
			return effect
	return null


func _open_catalog_picker(effect: Event_EffectData, decision: Dictionary) -> void:
	if effect == null or event_executor == null or _catalog_picker == null:
		_show_feedback("O catálogo deste evento não está disponível.")
		return
	var choices: Array[ItemData] = event_executor.call("get_catalog_choices", effect)
	if choices.is_empty():
		_show_feedback("Não há itens elegíveis para escolher.")
		return
	_catalog_pending_decision = decision.duplicate()
	_catalog_picker.call("open_catalog", choices, "ESCOLHA SEU ITEM")


func _confirm_catalog_selection(item: ItemData) -> void:
	var decision := _catalog_pending_decision.duplicate()
	decision["selected_catalog_item"] = item
	_catalog_pending_decision.clear()
	_confirm_event(decision)


func _forfeit_catalog_reward() -> void:
	var decision := _catalog_pending_decision.duplicate()
	decision["forfeit_catalog_reward"] = true
	_catalog_pending_decision.clear()
	_confirm_event(decision)


func _select_coin_guess(option: StringName) -> void:
	var event := _context.get("resource") as EventData
	if event == null or option not in event.guess_options:
		return
	_coin_choice = option
	_clear_buttons()
	_add_button("CONFIRMAR PALPITE", ACTION_GOLD, _animate_coin_and_confirm, true)
	_add_button("TROCAR PALPITE", ACTION_GOLD, _show_event_buttons.bind(event), true)
	if event.guess_refusal_outcome != null:
		_add_button("NÃO JOGAR", ACTION_GOLD,
			func() -> void: _confirm_event({"refused": true}), true)
	_show_feedback("Palpite escolhido: %s. Confirme para lançar a moeda." % str(option).to_upper())


func _animate_coin_and_confirm() -> void:
	if _coin_choice == &"" or _event_die_animating:
		return
	_event_die_animating = true
	_clear_buttons()
	for index in 12:
		_show_feedback("MOEDA: %s" % CoinFlip.side_label(randi_range(0, 1)))
		await get_tree().create_timer(0.05).timeout
		if not is_inside_tree():
			return
	_event_die_animating = false
	_confirm_event({"guess": _coin_choice})


func _show_symbiosis_choices(actor: EntityState,
		entries: Array[InventoryItemState]) -> void:
	# Primeiro a Épica equipada; somente na ausência dela sorteamos entre
	# Épicas carregadas. O mesmo critério vale depois para armas comuns.
	for entry in actor.equipped_weapons:
		if entry != null and entry.data != null \
				and entry.data.rarity == ItemData.Rarity.EPIC:
			_add_button("ABSORVER %s" % entry.data.display_name.to_upper(),
				ACTION_GOLD, _confirm_event.bind({"selected_item": entry}), true)
			return
	var epics: Array[InventoryItemState] = []
	for entry in actor.inventory_items:
		if entry != null and entry.data != null \
				and entry.data.equipment_slot == ItemData.EquipmentSlot.WEAPON \
				and entry.data.rarity == ItemData.Rarity.EPIC:
			epics.append(entry)
	if not epics.is_empty():
		var choice_rng := block_manager.gerencia.campaign.world_rng
		var chosen_epic := epics[choice_rng.randi_range(0, epics.size() - 1)]
		_add_button("ACEITAR SIMBIOSE", ACTION_GOLD,
			_confirm_event.bind({"selected_item": chosen_epic}), true)
		return
	# Sem Épica: a equipada prevalece. Sem equipada, a mochila sorteia
	# uma arma comum. A evolução vem do craft_result do próprio Resource.
	for entry in actor.equipped_weapons:
		if _can_evolve_symbiosis_weapon(entry):
			_add_button("ABSORVER %s" % entry.data.display_name.to_upper(),
				ACTION_GOLD, _confirm_event.bind({"selected_item": entry}), true)
			return
	var carried: Array[InventoryItemState] = []
	for entry in actor.inventory_items:
		if _can_evolve_symbiosis_weapon(entry):
			carried.append(entry)
	if not carried.is_empty():
		var choice_rng := block_manager.gerencia.campaign.world_rng
		var chosen := carried[choice_rng.randi_range(0, carried.size() - 1)]
		_add_button("ACEITAR SIMBIOSE", ACTION_GOLD,
			_confirm_event.bind({"selected_item": chosen}), true)
		return
	_invalid_symbiosis = true
	narrative_label.text = "error_:voce_nao_tem_arma. Efeito inválido. Tente novamente mais tarde --*"
	_add_button("OKAY", ACTION_GOLD, _complete_invalid_symbiosis, true)


func _can_evolve_symbiosis_weapon(entry: InventoryItemState) -> bool:
	if entry == null or entry.data == null \
			or entry.data.equipment_slot != ItemData.EquipmentSlot.WEAPON:
		return false
	for raw_result in entry.data.craft_result:
		var result := raw_result as ItemData
		if result != null and result.rarity == ItemData.Rarity.EPIC:
			return true
	return false


func _complete_invalid_symbiosis() -> void:
	if _pre_activation_pending and player_skill_manager != null:
		player_skill_manager.answer_pre_activation_choice()
	if block_manager != null:
		block_manager.finish_event_resolution({"success": false,
			"reason": "Sem arma para Simbiose Elemental."})
	else:
		overlay.hide()


func _confirm_event(decision: Dictionary) -> void:
	if block_manager == null:
		_show_feedback("Prévia visual: a decisão não foi aplicada.")
		return
	if _pre_activation_pending and (player_skill_manager == null \
			or not player_skill_manager.answer_pre_activation_choice()):
		_show_feedback("Não foi possível ativar este evento.")
		return
	_result_shown = false
	if not block_manager.confirm_event_action(decision):
		_show_feedback("Este evento não está mais disponível.")
		return
	if overlay.visible and not _result_shown:
		_clear_buttons()
		_show_feedback("Decisão registrada. Aguardando a resolução dos efeitos do evento.")


func _on_event_outcome_prepared(event_context: Dictionary, preview: Dictionary) -> void:
	_context = event_context.duplicate()
	_result_shown = true
	_event_die_pending = preview.get("requires_die_roll", false)
	var reward: Dictionary = event_executor.call("get_prepared_item_reward") \
		if event_executor != null else {}
	var reward_item := reward.get("item") as ItemData
	if reward_item != null:
		_show_item_preview(reward_item)
	else:
		item_preview.hide()
	if not preview.get("requires_second_ack", false):
		_execute_prepared_event()
		return
	var story := str(preview.get("narrative", "")).strip_edges()
	if _event_die_pending:
		story = story.replace("[resultado_dado]", "?")
	if story.is_empty():
		story = str(preview.get("outcome_name", "")).strip_edges()
	if preview.get("coin_result", &"") != &"":
		var landed := str(preview["coin_result"]).to_upper()
		var side := CoinFlip.side_label(int(preview.get("coin_side", 0)))
		var verdict := "ACERTOU" if preview.get("guessed", false) else "ERROU"
		story = "Seu palpite: %s. A moeda caiu: %s (%s). %s!\n\n%s" % [
			str(preview.get("guess", &"")).to_upper(), landed, side, verdict, story]
	_outcome_reading = true
	if _context.get("resource") is EventData \
			and (_context["resource"] as EventData).id == &"ev_00053":
		_start_carreta_visual()
	title_label.text = str(preview.get("outcome_name", "RESULTADO")).to_upper()
	_fit_title_inside_banner()
	narrative_label.text = story
	_clear_buttons()
	if _event_die_pending:
		_roll_button = _add_button("JOGAR DADO", ACTION_GOLD,
			_roll_event_and_execute, true)
	else:
		_add_button("OK", ACTION_GOLD, _execute_prepared_event, true)
	feedback_label.hide()
	# A consequência aparece como uma segunda leitura, separada da caixa
	# inicial do Evento. Só fechar esta leitura aplica os efeitos.
	overlay.show()
	get_node("/root/UISFX").call("play", &"hex_open")
	if reward_item != null:
		get_node("/root/UISFX").call("play", &"item_reward")


func _execute_prepared_event() -> void:
	# A caixa fecha ANTES de qualquer mudança de Vida, Status ou inventário.
	_stop_carreta_visual()
	_outcome_reading = false
	overlay.hide()
	if event_executor == null or not event_executor.call("apply_prepared_result"):
		overlay.show()
		if not feedback_label.visible:
			_show_feedback("Não foi possível executar o resultado deste evento.")


func _roll_event_and_execute() -> void:
	if _event_die_animating or not _event_die_pending:
		return
	_event_die_animating = true
	await _animate_roll_preview()
	if not is_inside_tree():
		return
	_outcome_reading = false
	_stop_carreta_visual()
	if event_executor == null or not event_executor.call("apply_prepared_result"):
		_event_die_animating = false
		_show_feedback("Não foi possível executar a rolagem deste evento.")


func _on_event_result_ready(_event_context: Dictionary, result: Dictionary) -> void:
	_result_shown = true
	if _event_die_pending:
		_finish_event_die_result(result)
		return
	for effect_result in result.get("effects", []):
		if effect_result is Dictionary \
				and effect_result.get("temple_blessing_nullified", false):
			_show_event_effect_summary("MALDIÇÃO ANULADA",
				"O dia de hoje está abençoado.")
			return
	if result.get("event_id") in [&"ev_00012", &"ev_00013"]:
		_theft_outcome_pages.clear()
		for detail in result.get("effects", []):
			if detail is Dictionary and detail.has("theft_narrative"):
				_theft_outcome_pages.append(str(detail["theft_narrative"]))
		if not _theft_outcome_pages.is_empty():
			_show_next_theft_outcome()
			return
	if result.get("event_id") == &"ev_00045":
		for effect_result in result.get("effects", []):
			if not effect_result is Dictionary:
				continue
			var detail := effect_result as Dictionary
			if detail.has("statistic") and detail.has("immunity"):
				var bonus_name := "Ataque" if detail["statistic"] == &"attack" else "Vida máxima e atual"
				var immune_name := "Doença" if detail["immunity"] == &"disease" else "Terror"
				_show_event_effect_summary("BÊNÇÃO DA FLORZINHA",
					"+5 de %s e imunidade a %s até o fim do Dia. Debuffs ativos desse tipo foram removidos." % [bonus_name, immune_name])
				return
			if detail.has("affected"):
				_show_event_effect_summary("ESPOROS DA FLORZINHA",
					"A flor liberou esporos num raio de 3 hexágonos. %d entidades foram atingidas pela Doença Leve." % (detail["affected"] as Array).size())
				return
	var discovered_information: Informacao
	var forgotten_information := ""
	var forgot_result := false
	var no_eligible_information := false
	var information_not_granted := ""
	var map_presence: Dictionary = {}
	for effect_result in result.get("effects", []):
		if not effect_result is Dictionary:
			continue
		if effect_result.get("information") is Informacao:
			discovered_information = effect_result["information"] as Informacao
		if effect_result.has("forgotten_information_title"):
			forgot_result = true
			forgotten_information = str(effect_result["forgotten_information_title"])
		if effect_result.get("no_eligible_information", false):
			no_eligible_information = true
		if effect_result.get("information_not_granted", false):
			information_not_granted = str(effect_result.get("reason", ""))
		if effect_result.has("presence"):
			map_presence = effect_result["presence"]
	if discovered_information != null:
		title_label.text = discovered_information.titulo.to_upper()
		_fit_title_inside_banner()
		narrative_label.text = discovered_information.descricao
		_clear_buttons()
		_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
		feedback_label.hide()
		overlay.show()
		get_node("/root/UISFX").call("play", &"hex_open")
		return
	if forgot_result or no_eligible_information:
		title_label.text = "RESULTADO DA MOEDA"
		_fit_title_inside_banner()
		if not forgotten_information.is_empty():
			narrative_label.text = "A última Informação foi esquecida: %s." % forgotten_information
		elif forgot_result:
			narrative_label.text = "Você errou, mas ainda não havia Informação para esquecer."
		else:
			narrative_label.text = "Você acertou, mas já possui todas as Informações disponíveis."
		_clear_buttons()
		_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
		feedback_label.hide()
		overlay.show()
		get_node("/root/UISFX").call("play", &"hex_open")
		return
	if not information_not_granted.is_empty():
		title_label.text = "INFORMAÇÃO NÃO CONCEDIDA"
		_fit_title_inside_banner()
		var other_effects := (result.get("effects", []) as Array).size() > 1
		narrative_label.text = str(result.get("narrative", "")) + "\n\n" \
			+ information_not_granted \
			+ (" Os demais efeitos foram aplicados." if other_effects else "")
		_clear_buttons()
		_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
		feedback_label.hide()
		overlay.show()
		get_node("/root/UISFX").call("play", &"hex_open")
		return
	if not map_presence.is_empty():
		var lines: Array[String] = []
		for entry in [[&"catastrophe", "Catástrofe"],
				[&"trap", "Armadilha"], [&"cursed", "Maldição"]]:
			var exists: bool = map_presence.get(entry[0], false)
			lines.append("%s: %s" % [entry[1], "presente" if exists else "ausente"])
		title_label.text = "AVISO DA CARTOMANTE"
		_fit_title_inside_banner()
		narrative_label.text = "Nesta Rodada, a cartomante pressente:\n" + "\n".join(lines)
		_clear_buttons()
		_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
		feedback_label.hide()
		overlay.show()
		get_node("/root/UISFX").call("play", &"hex_open")
		return
	if result.get("event_id") == &"ev_00014":
		for effect_result in result.get("effects", []):
			if effect_result is Dictionary and int(effect_result.get("revealed_count", 0)) > 0:
				_post_reveal_warning = true
				title_label.text = "REVELAÇÃO MISTERIOSA"
				_fit_title_inside_banner()
				narrative_label.text = "Isso aqui é perigoso!"
				_clear_buttons()
				_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
				feedback_label.hide()
				overlay.show()
				get_node("/root/UISFX").call("play", &"hex_open")
				return
	_acknowledge_event_result()


func _show_next_theft_outcome() -> void:
	if _theft_outcome_pages.is_empty():
		_acknowledge_event_result()
		return
	title_label.text = "PERDEU, PERDEU!"
	_fit_title_inside_banner()
	narrative_label.text = _theft_outcome_pages.pop_front()
	_clear_buttons()
	_add_button("PRÓXIMO" if not _theft_outcome_pages.is_empty() else "OK",
		ACTION_GOLD, _show_next_theft_outcome, true)
	feedback_label.hide()
	overlay.show()
	get_node("/root/UISFX").call("play", &"hex_open")


func _show_event_effect_summary(title: String, description: String) -> void:
	title_label.text = title
	_fit_title_inside_banner()
	narrative_label.text = description
	_clear_buttons()
	_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
	feedback_label.hide()
	overlay.show()
	get_node("/root/UISFX").call("play", &"hex_open")


func _acknowledge_event_result() -> void:
	_post_reveal_warning = false
	if event_executor == null or not event_executor.call("acknowledge_result"):
		overlay.show()
		_show_feedback("O resultado foi aplicado, mas o bloco não pôde ser encerrado.")


func _finish_event_die_result(result: Dictionary) -> void:
	if is_instance_valid(_roll_button):
		_roll_button.text = _dice_result_text(result)
	_event_die_pending = false
	_event_die_animating = false
	var story := str(result.get("narrative", "")).strip_edges()
	if not story.is_empty():
		narrative_label.text = story
	_clear_buttons()
	_add_button("OK", ACTION_GOLD, _acknowledge_event_result, true)
	overlay.show()


func _animate_roll_preview() -> void:
	if not is_instance_valid(_roll_button):
		return
	_roll_button.disabled = true
	for index in 12:
		_roll_button.text = "DADO: %d" % randi_range(1, 6)
		await get_tree().create_timer(0.05).timeout
		if not is_inside_tree() or not is_instance_valid(_roll_button):
			return


func _dice_result_text(result: Dictionary) -> String:
	var dice: Array = result.get("dice_results", [])
	if dice.is_empty():
		return "DADO ROLADO"
	var labels: Array[String] = []
	for value in dice:
		labels.append(str(value))
	return ("DADO: " if dice.size() == 1 else "DADOS: ") + " + ".join(labels)


func _on_event_resolution_blocked(_event_context: Dictionary, reason: String) -> void:
	_result_shown = true
	_event_die_animating = false
	overlay.show()
	get_node("/root/UISFX").call("play", &"hex_open")
	_clear_buttons()
	_show_feedback("Este resultado ainda não pode ser aplicado: " + reason)
	if reason.contains("Libere espaço no inventário"):
		_add_button("ESCOLHER TROCA", INVENTORY_BLUE, _open_inventory_for_event, true)
		_add_button("TENTAR NOVAMENTE", ACTION_GOLD, _execute_prepared_event, true)


func _open_inventory_for_event() -> void:
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar == null or top_bar.group_inventory == null:
		_show_feedback("O Inventário do grupo não está disponível.")
		return
	var reward: Dictionary = event_executor.call("get_prepared_item_reward") \
		if event_executor != null else {}
	var owner := reward.get("actor") as EntityState
	var item := reward.get("item") as ItemData
	if owner == null or item == null:
		_show_feedback("Não foi possível identificar o item da troca.")
		return
	var effect := reward.get("effect") as Event_EffectData
	var can_refuse := item.item_type != ItemData.ItemType.CURSED \
		and item.can_be_discarded and (effect == null or not effect.item_acceptance_required)
	if not top_bar.group_inventory.begin_exchange(owner, item,
			_complete_event_item_exchange, _decline_event_item_exchange, can_refuse):
		_show_feedback("Não foi possível abrir a troca no Inventário do grupo.")
		return
	_waiting_inventory_close = true
	overlay.hide()


func _complete_event_item_exchange(outgoing: Array[InventoryItemState]) -> bool:
	return event_executor != null and event_executor.exchange_prepared_item(outgoing)


func _decline_event_item_exchange() -> bool:
	return event_executor != null and event_executor.decline_prepared_item()


func _process(_delta: float) -> void:
	if not _waiting_inventory_close:
		return
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar == null or top_bar.group_inventory == null \
			or top_bar.group_inventory.visible:
		return
	_waiting_inventory_close = false
	overlay.show()


func _confirm_encounter() -> void:
	if block_manager == null:
		_show_feedback("Prévia visual: o combate não foi iniciado.")
		return
	if block_manager.confirm_encounter():
		overlay.hide()
	else:
		_show_feedback("Este encontro não está mais disponível.")


func _on_combat_conclusion_requested(title: String, narrative: String,
		rewards: Array[Resource]) -> void:
	_combat_conclusion_open = true
	_pending_loot_decline_confirmation = false
	_context.clear()
	skill_info.hide()
	item_preview.hide()
	_preview_item = null
	frame_area.custom_minimum_size.y = 525.0
	# Nesta janela tudo, inclusive o título, fica DENTRO do uielementx_00005.
	title_banner.hide()
	frame_rect.offset_top = 0.0
	var white_material := ShaderMaterial.new()
	white_material.shader = WHITE_FRAME_SHADER
	frame_rect.material = white_material
	content_area.offset_left = 78.0
	content_area.offset_top = 54.0
	content_area.offset_right = -78.0
	content_area.offset_bottom = -82.0
	conclusion_title.text = title
	conclusion_title.show()
	encounter_name.hide()
	narrative_label.text = narrative
	($Overlay/Center/FrameArea/Content/Body/NarrativeScroll as ScrollContainer).visible = not narrative.is_empty()
	feedback_label.hide()
	_clear_rewards()
	_combat_loot_labels.clear()
	var loot_count := (combat_manager.get("_loot_items") as Array).size() \
		if combat_manager != null else 0
	for reward_index in rewards.size():
		var reward := rewards[reward_index]
		if reward == null:
			continue
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var icon: Texture2D = null
		var name := "Recompensa"
		if reward is ItemData:
			icon = (reward as ItemData).icon
			name = (reward as ItemData).display_name
		elif reward is EntityData:
			icon = (reward as EntityData).icon
			name = (reward as EntityData).display_name
		if icon != null:
			var image := TextureRect.new()
			image.texture = icon
			image.custom_minimum_size = Vector2(30, 30)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			line.add_child(image)
		var label := Label.new()
		var is_loot := reward_index >= rewards.size() - loot_count
		label.text = "%d/%d · %s" % [reward_index - (rewards.size() - loot_count) + 1,
			loot_count, name] if is_loot else name
		label.add_theme_color_override("font_color", Color(0.95, 0.84, 0.94))
		line.add_child(label)
		if is_loot:
			_combat_loot_labels.append(label)
		if reward is ItemData:
			var info := Button.new()
			info.text = "ⓘ"
			info.tooltip_text = "Ver descrição e estatísticas de %s" % name
			info.custom_minimum_size = Vector2(30, 30)
			_style_item_info_button(info)
			info.pressed.connect(_show_reward_item_details.bind(reward as ItemData))
			line.add_child(info)
		rewards_container.add_child(line)
	rewards_container.visible = rewards_container.get_child_count() > 0
	_refresh_combat_loot_controls()
	overlay.modulate.a = 1.0
	overlay.show()
	if rewards.any(func(reward: Resource) -> bool: return reward is ItemData):
		get_node("/root/UISFX").call("play", &"item_reward")


func _refresh_combat_loot_controls() -> void:
	_clear_buttons()
	_update_combat_loot_labels()
	var pending: Dictionary = combat_manager.call("get_pending_loot_item") \
		if combat_manager != null else {}
	if pending.is_empty():
		feedback_label.hide()
		_add_button("PROSSEGUIR", ACTION_GOLD, _confirm_combat_conclusion, true)
		return
	var item := pending["item"] as ItemData
	_show_feedback("SAQUE %d/%d · %s — escolha quem vai guardar." % [
		int(pending["index"]), int(pending["count"]), item.display_name])
	var campaign := block_manager.gerencia.campaign if block_manager != null \
		and block_manager.gerencia != null else null
	var inventory := _inventory()
	if campaign != null and inventory != null:
		for recipient in campaign.active_entity_states:
			if recipient == null or recipient.current_health <= 0:
				continue
			if inventory.can_receive(recipient, item):
				_add_button("GUARDAR: %s" % recipient.visible_name().to_upper(),
					INVENTORY_BLUE, _claim_combat_loot.bind(recipient), true)
			else:
				_add_button("TROCAR ITENS: %s" % recipient.visible_name().to_upper(),
					INVENTORY_BLUE, _open_combat_loot_exchange.bind(recipient), true)
	_add_button("RECUSAR ITEM", Color(0.38, 0.13, 0.16),
		_confirm_combat_loot_decline, true)


func _update_combat_loot_labels() -> void:
	if combat_manager == null:
		return
	var items := combat_manager.get("_loot_items") as Array
	var resolutions := combat_manager.get("_loot_resolutions") as Array
	for index in mini(_combat_loot_labels.size(), items.size()):
		var label := _combat_loot_labels[index]
		var status := "PENDENTE"
		if index < resolutions.size():
			var resolution := resolutions[index] as Dictionary
			status = "COM %s" % str(resolution.get("recipient", "")) \
				if resolution.get("kind") == &"claimed" else "RECUSADO"
		elif index == int(combat_manager.get("_loot_resolved_count")):
			status = "ESCOLHENDO"
		label.text = "%d/%d · %s · %s" % [index + 1, items.size(),
			(items[index] as ItemData).display_name, status]
		label.add_theme_color_override("font_color", Color(0.40, 0.93, 0.69) \
			if status.begins_with("COM ") else Color(0.96, 0.40, 0.46) \
			if status == "RECUSADO" else Color(0.93, 0.95, 0.97))


func _claim_combat_loot(recipient: EntityState) -> void:
	if combat_manager == null or not combat_manager.call("claim_pending_loot", recipient):
		_show_feedback("Não foi possível guardar este item. Escolha outro destino.")
		return
	_refresh_combat_loot_controls()


func _confirm_combat_loot_decline() -> void:
	_pending_loot_decline_confirmation = true
	_clear_buttons()
	_show_feedback("Recusar este item? Ele não será colocado em nenhum inventário.")
	_add_button("SIM, RECUSAR", Color(0.45, 0.11, 0.14),
		_decline_combat_loot, true)
	_add_button("VOLTAR", INVENTORY_BLUE, _cancel_combat_loot_decline, true)


func _cancel_combat_loot_decline() -> void:
	_pending_loot_decline_confirmation = false
	_refresh_combat_loot_controls()


func _decline_combat_loot() -> void:
	if combat_manager == null or not combat_manager.call("decline_pending_loot"):
		_show_feedback("A recusa não pôde ser concluída.")
		return
	_pending_loot_decline_confirmation = false
	_refresh_combat_loot_controls()


func _open_combat_loot_exchange(recipient: EntityState) -> void:
	var pending: Dictionary = combat_manager.call("get_pending_loot_item") \
		if combat_manager != null else {}
	var item := pending.get("item") as ItemData
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	if item == null or top_bar == null or top_bar.group_inventory == null \
			or not top_bar.group_inventory.begin_exchange(recipient, item,
			_complete_combat_loot_exchange.bind(recipient), Callable(), false):
		_show_feedback("Não foi possível abrir a troca de inventário.")
		return
	_waiting_inventory_close = true
	overlay.hide()


func _complete_combat_loot_exchange(outgoing: Array[InventoryItemState],
		recipient: EntityState) -> bool:
	if combat_manager == null or not combat_manager.call("exchange_pending_loot",
			recipient, outgoing):
		return false
	_refresh_combat_loot_controls()
	return true


func _restore_normal_frame() -> void:
	item_preview.hide()
	_preview_item = null
	frame_area.custom_minimum_size.y = 585.0
	title_banner.show()
	frame_rect.offset_top = 100.0
	frame_rect.material = _normal_frame_material
	content_area.offset_left = 64.0
	content_area.offset_top = 146.0
	content_area.offset_right = -64.0
	content_area.offset_bottom = -102.0
	conclusion_title.hide()
	($Overlay/Center/FrameArea/Content/Body/NarrativeScroll as ScrollContainer).show()


func _confirm_combat_conclusion() -> void:
	if combat_manager != null and combat_manager.call("confirm_conclusion"):
		_combat_conclusion_open = false
		overlay.hide()
	else:
		var reward: Dictionary = combat_manager.call("get_pending_reward_exchange") \
			if combat_manager != null else {}
		if not reward.is_empty():
			_open_combat_reward_exchange(reward)
		else:
			_show_feedback("Não foi possível encerrar o Encontro.")


func _open_combat_reward_exchange(reward: Dictionary) -> void:
	var top_bar := get_parent().get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar == null or top_bar.group_inventory == null:
		_show_feedback("O Inventário do grupo não está disponível para receber a recompensa.")
		return
	var owner := reward.get("actor") as EntityState
	var item := reward.get("item") as ItemData
	if owner == null or item == null or not top_bar.group_inventory.begin_exchange(
			owner, item, _complete_combat_reward_exchange, Callable(), false):
		_show_feedback("Não foi possível abrir a troca obrigatória da recompensa.")
		return
	_waiting_inventory_close = true
	overlay.hide()


func _complete_combat_reward_exchange(outgoing: Array[InventoryItemState]) -> bool:
	if combat_manager == null or not combat_manager.call("exchange_pending_reward", outgoing):
		return false
	if not combat_manager.call("confirm_conclusion"):
		return false
	_combat_conclusion_open = false
	overlay.hide()
	return true


func _on_combat_trap_requested(event: EventData, _actor: EntityState,
		_coord: Vector2i) -> void:
	if event == null:
		return
	_combat_trap_open = true
	_trap_die_pending = false
	_context.clear()
	_restore_normal_frame()
	_clear_rewards()
	title_label.text = event.display_name.to_upper()
	title_label.add_theme_color_override("font_color", Color(0.96, 0.26, 0.33))
	_fit_title_inside_banner()
	encounter_name.hide()
	var outcome := event.outcomes[0] if not event.outcomes.is_empty() else null
	if outcome != null:
		for effect in outcome.effects:
			if effect != null and effect.dice_count > 0:
				_trap_die_pending = true
				break
	var story := event.narrative_description
	if outcome != null and not outcome.narrative_description.is_empty():
		story += "\n\n" + outcome.narrative_description
	narrative_label.text = story
	feedback_label.hide()
	_clear_buttons()
	if _trap_die_pending:
		_roll_button = _add_button("JOGAR DADO", ACTION_GOLD,
			_roll_combat_trap, true)
	else:
		_add_button("PROSSEGUIR", ACTION_GOLD, _confirm_combat_trap, true)
	overlay.modulate.a = 1.0
	overlay.show()
	get_node("/root/UISFX").call("play", &"hex_open")


func _confirm_combat_trap() -> void:
	if combat_manager == null:
		return
	var result: Dictionary = combat_manager.call("resolve_pending_trap")
	if result.get("success", false):
		_combat_trap_open = false
		overlay.hide()
	else:
		_show_feedback(str(result.get("reason", "A armadilha não pôde ser aplicada.")))


func _roll_combat_trap() -> void:
	if _event_die_animating or not _trap_die_pending or combat_manager == null:
		return
	_event_die_animating = true
	await _animate_roll_preview()
	if not is_inside_tree():
		return
	var result: Dictionary = combat_manager.call("resolve_pending_trap")
	if result.get("success", false):
		if is_instance_valid(_roll_button):
			_roll_button.text = _dice_result_text(result)
		await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
		_combat_trap_open = false
		_trap_die_pending = false
		overlay.hide()
	else:
		_show_feedback(str(result.get("reason", "A armadilha não pôde ser aplicada.")))
	_event_die_animating = false


func _clear_rewards() -> void:
	if rewards_container == null:
		return
	for child in rewards_container.get_children():
		rewards_container.remove_child(child)
		child.queue_free()
	rewards_container.hide()


func _confirm_information() -> void:
	if block_manager != null and block_manager.confirm_information():
		overlay.hide()
	else:
		_show_feedback(str(block_manager.last_information_grant_result.get(
			"reason", "Não foi possível registrar esta Informação.")) \
			if block_manager != null else "Não foi possível registrar esta Informação.")


func _input(event: InputEvent) -> void:
	if not overlay.visible:
		return
	if (_reward_details != null and _reward_details.visible) \
			or (_genie_info_panel != null and _genie_info_panel.visible) \
			or (_genie_sheet != null and _genie_sheet.visible):
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			_hide_reward_item_details()
			get_viewport().set_input_as_handled()
		return
	if _invalid_symbiosis and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		_complete_invalid_symbiosis()
		get_viewport().set_input_as_handled()
		return
	if _event_die_animating:
		return
	if _wooden_doll_prompt:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			_confirm_wooden_doll_cancel()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and not ($Overlay/Center/FrameArea as Control).get_global_rect().has_point(event.position):
			_confirm_wooden_doll_cancel()
			get_viewport().set_input_as_handled()
		return
	if _post_reveal_warning:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			_acknowledge_event_result()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and not ($Overlay/Center/FrameArea as Control).get_global_rect().has_point(event.position):
			_acknowledge_event_result()
			get_viewport().set_input_as_handled()
		return
	if _combat_trap_open and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		if _trap_die_pending:
			_roll_combat_trap()
		else:
			_confirm_combat_trap()
		get_viewport().set_input_as_handled()
		return
	if _combat_conclusion_open and event is InputEventKey and event.pressed \
			and not event.echo and event.keycode == KEY_ESCAPE:
		if _pending_loot_decline_confirmation:
			_cancel_combat_loot_decline()
		elif combat_manager != null and not combat_manager.call(
				"get_pending_loot_item").is_empty():
			_show_feedback("Escolha o destino ou recuse o saque antes de prosseguir.")
		else:
			_confirm_combat_conclusion()
		get_viewport().set_input_as_handled()
		return
	if _outcome_reading:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			if _event_die_pending:
				_roll_event_and_execute()
			else:
				_execute_prepared_event()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			var frame := $Overlay/Center/FrameArea as Control
			if not frame.get_global_rect().has_point(event.position):
				if _event_die_pending:
					_roll_event_and_execute()
				else:
					_execute_prepared_event()
				get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey or not event.pressed \
			or event.echo or event.keycode != KEY_ESCAPE:
		return
	if _context.get("resource") is Informacao:
		_confirm_information()
		get_viewport().set_input_as_handled()


func _inventory() -> InventoryManager:
	return skill_manager.inventory_manager if skill_manager != null else null


func _show_feedback(message: String) -> void:
	feedback_label.text = message
	feedback_label.show()


func _clear_buttons() -> void:
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()


func _add_button(label: String, color: Color, action: Callable,
		enabled: bool, parent: Container = null) -> Button:
	var button := Button.new()
	button.text = label
	if _context.get("resource") is EventData:
		button.set_meta("ui_sfx_kind", &"outcome_click")
	button.custom_minimum_size = Vector2(165, 42)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = label
	button.disabled = not enabled
	button.pressed.connect(action)
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.border_color = color.lightened(0.3)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.set_content_margin_all(10.0)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.17)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.18)
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.18, 0.20, 0.22, 0.8)
	disabled_style.border_color = Color(0.42, 0.45, 0.48)
	disabled_style.set_border_width_all(1)
	disabled_style.set_corner_radius_all(3)
	disabled_style.set_content_margin_all(10.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.74, 0.76))
	(parent if parent != null else buttons).add_child(button)
	return button


func _on_block_finished(_result: Dictionary) -> void:
	_cancel_hex_arrival_wait()
	_theft_outcome_pages.clear()
	_context.clear()
	_post_reveal_warning = false
	_wooden_doll_prompt = false
	_waiting_inventory_close = false
	_pre_activation_pending = false
	_combat_conclusion_open = false
	_clear_rewards()
	_hide_reward_item_details()
	skill_info.hide()
	overlay.hide()
