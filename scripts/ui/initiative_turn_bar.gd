class_name InitiativeTurnBar
extends CanvasLayer

## Retratos na ordem real de iniciativa. Esta camada só apresenta o estado:
## CombatManager continua sendo a única fonte da ordem e do turno ativo.

const FRAME := preload("res://sprites/ui/uielementx_00002.png")
const STATUS_FRAME := preload("res://sprites/ui/uielementx_00005.png")
const STATUS_FRAME_SHADER := preload("res://shaders/ui_black_status_frame.gdshader")
const FRAME_SHADER := preload("res://shaders/ui_initiative_frame.gdshader")
const GRAYSCALE_SHADER := preload("res://shaders/ui_inactive_grayscale.gdshader")
const PORTRAIT_PROVIDER := preload("res://scripts/ui/entity_portrait_provider.gd")
const FONT := preload("res://fonts/UbuntuSans-Regular.ttf")
const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const ALLY_COLOR := Color(0.08, 0.64, 0.78, 0.70)
const ENEMY_COLOR := Color(0.74, 0.10, 0.16, 0.70)
const SPENT_COLOR := Color(0.45, 0.49, 0.52, 0.72)
const LEFT_X := 650.0 # Margem segura após a caixa de ações do HUD.
const TOP_Y := 65.0
const MAX_WIDTH := 805.0
const RIGHT_RESERVED := 185.0
const CARD_WIDTH := 80.0
const CARD_HEIGHT := 145.0
const CARD_GAP := 3.0
const ARROW_WIDTH := 30.0

@export var combat_manager: CombatManager
@export var gerencia: GerenciaJogo
@export var party_hud: PartyStatusHUD

var _root: Control
var _tooltip: PanelContainer
var _tooltip_text: Label
var _action_menu: PanelContainer
var _action_buttons: VBoxContainer
var _map_tooltip: PanelContainer
var _map_tooltip_text: Label
var _participants: Array[EntityState] = []
var _cards: Array[Dictionary] = []
var _acted: Dictionary = {}
var _current_actor: EntityState
var _selected_enemy: EntityState
var _cycle := 0
var _first_visible := 0
var _hover_actor: EntityState
var _refresh_elapsed := 0.0


func _ready() -> void:
	_root = Control.new()
	_root.name = "InitiativeStrip"
	# Espaços vazios da faixa não interceptam cliques nos hexes do mapa.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_tooltip()
	_build_action_menu()
	_build_map_tooltip()
	_root.hide()
	if combat_manager != null:
		combat_manager.combat_prepared.connect(_on_combat_prepared)
		combat_manager.turn_started.connect(_on_turn_started)
		combat_manager.turn_finished.connect(_on_turn_finished)
		combat_manager.enemy_summoned.connect(_on_enemy_summoned)
		combat_manager.ally_revived.connect(_on_ally_revived)
		combat_manager.enemy_inspected.connect(_select_enemy)
		combat_manager.combat_finished.connect(_on_combat_finished)
		if combat_manager.map_view != null:
			combat_manager.map_view.hex_choice_requested.connect(_on_hex_choice_requested)
	if gerencia != null:
		gerencia.map_generated.connect(func(_map: HexGrid) -> void: _reset())
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()


func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "InitiativeStatsTooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.078, 0.91)
	style.border_color = ALLY_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip_text = Label.new()
	_tooltip_text.add_theme_font_override("font", FONT)
	_tooltip_text.add_theme_font_size_override("font_size", 12)
	_tooltip_text.add_theme_color_override("font_color", Color(0.94, 0.96, 0.97))
	_tooltip.add_child(_tooltip_text)
	add_child(_tooltip)
	_tooltip.hide()


func _build_action_menu() -> void:
	_action_menu = PanelContainer.new()
	_action_menu.name = "InitiativeActionMenu"
	_action_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.07, 0.97)
	style.border_color = ALLY_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(7)
	_action_menu.add_theme_stylebox_override("panel", style)
	_action_buttons = VBoxContainer.new()
	_action_buttons.add_theme_constant_override("separation", 4)
	_action_menu.add_child(_action_buttons)
	add_child(_action_menu)
	_action_menu.hide()


func _build_map_tooltip() -> void:
	_map_tooltip = PanelContainer.new()
	_map_tooltip.name = "CombatMapStatsTooltip"
	_map_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_tooltip.custom_minimum_size.x = 300.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.15, 0.17, 0.95)
	style.border_color = Color(0.005, 0.005, 0.009, 1.0)
	style.set_border_width_all(2)
	_map_tooltip.add_theme_stylebox_override("panel", style)
	var frame := TextureRect.new()
	frame.name = "StatusFrame"
	frame.texture = STATUS_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_material := ShaderMaterial.new()
	frame_material.shader = STATUS_FRAME_SHADER
	frame.material = frame_material
	_map_tooltip.add_child(frame)
	var margin := MarginContainer.new()
	margin.name = "SafeTextMargin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 29)
	margin.add_theme_constant_override("margin_right", 29)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 29)
	_map_tooltip.add_child(margin)
	_map_tooltip_text = Label.new()
	_map_tooltip_text.custom_minimum_size.x = 240.0
	_map_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_tooltip_text.add_theme_font_override("font", FONT)
	_map_tooltip_text.add_theme_font_size_override("font_size", 11)
	margin.add_child(_map_tooltip_text)
	add_child(_map_tooltip)
	_map_tooltip.hide()


func _on_viewport_resized() -> void:
	if _root == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var left := LEFT_X
	if party_hud != null:
		for drawer in [party_hud.action_drawer, party_hud.ally_drawer]:
			var drawer_control := drawer as Control
			if drawer_control != null and drawer_control.visible:
				var rect := drawer_control.get_global_rect()
				if rect.position.y < TOP_Y + CARD_HEIGHT and rect.end.y > TOP_Y:
					left = maxf(left, rect.end.x + 18.0)
	_root.position = Vector2(left, TOP_Y)
	_root.size = Vector2(maxf(180.0, minf(MAX_WIDTH,
		screen.x - left - RIGHT_RESERVED)), CARD_HEIGHT)
	if _root.visible:
		_ensure_current_visible()
		_render()


func _on_combat_prepared(_encounter: EncounterData, _enemies: Array[EntityState],
		initiative: Array[Dictionary]) -> void:
	_participants.clear()
	for entry in initiative:
		var actor := entry.get("entity") as EntityState
		if actor != null:
			_participants.append(actor)
	_acted.clear()
	_current_actor = null
	_selected_enemy = null
	_cycle = 0
	_first_visible = 0
	_root.visible = not _participants.is_empty()
	_render()


func _on_turn_started(actor: EntityState, cycle_number: int) -> void:
	_action_menu.hide()
	if cycle_number != _cycle:
		_cycle = cycle_number
		_acted.clear()
	_current_actor = actor
	_ensure_current_visible()
	_render()
	if gerencia != null and actor in gerencia.campaign.companion_states \
			and combat_manager != null and combat_manager.is_player_turn():
		call_deferred("_open_current_ally_actions")


func _open_current_ally_actions() -> void:
	if _current_actor == null or combat_manager == null \
			or combat_manager.current_actor != _current_actor \
			or not combat_manager.is_player_turn() or party_hud == null:
		return
	for info in _cards:
		if info["actor"] == _current_actor:
			var button := info["button"] as Button
			party_hud.show_initiative_companion_actions(
				_current_actor, button.get_global_rect())
			return


func _on_turn_finished(actor: EntityState) -> void:
	_action_menu.hide()
	if actor != null:
		_acted[actor.instance_id] = true
	_current_actor = null
	_refresh_cards()


func _on_enemy_summoned(_enemy: EntityState, _summoner: EntityState,
		_acts_immediately: bool) -> void:
	_reload_participants()


func _on_ally_revived(_ally: EntityState) -> void:
	_reload_participants()


func _reload_participants() -> void:
	_participants.clear()
	for entry in combat_manager.initiative_order:
		var actor := entry.get("entity") as EntityState
		if actor != null:
			_participants.append(actor)
	_ensure_current_visible()
	_render()


func _on_combat_finished(_result: Dictionary) -> void:
	_reset()


func _reset() -> void:
	if _action_menu != null:
		_action_menu.hide()
	if combat_manager != null and combat_manager.map_view != null:
		combat_manager.map_view.clear_enemy_hex_highlight()
	if _map_tooltip != null:
		_map_tooltip.hide()
	_participants.clear()
	_cards.clear()
	_acted.clear()
	_current_actor = null
	_selected_enemy = null
	_hover_actor = null
	_cycle = 0
	_first_visible = 0
	if _root != null:
		_root.hide()
	if _tooltip != null:
		_tooltip.hide()


func _visible_capacity(with_arrows: bool) -> int:
	var width := _root.size.x - (ARROW_WIDTH * 2.0 if with_arrows else 0.0)
	return maxi(1, int(floor((width + CARD_GAP) / (CARD_WIDTH + CARD_GAP))))


func _ensure_current_visible() -> void:
	if _current_actor == null:
		return
	var index := _participants.find(_current_actor)
	if index < 0:
		return
	var capacity := _visible_capacity(_participants.size() > _visible_capacity(false))
	if index < _first_visible:
		_first_visible = index
	elif index >= _first_visible + capacity:
		_first_visible = index - capacity + 1
	_first_visible = clampi(_first_visible, 0, maxi(0, _participants.size() - capacity))


func _render() -> void:
	if _root == null:
		return
	for node in _root.get_children():
		_root.remove_child(node)
		node.queue_free()
	_cards.clear()
	if _participants.is_empty():
		_root.hide()
		return
	var overflow := _participants.size() > _visible_capacity(false)
	var capacity := _visible_capacity(overflow)
	_first_visible = clampi(_first_visible, 0, maxi(0, _participants.size() - capacity))
	var left_pad := ARROW_WIDTH if overflow else 0.0
	if overflow:
		_add_scroll_button("◀", 0.0, _first_visible > 0, -1)
		_add_scroll_button("▶", _root.size.x - ARROW_WIDTH,
			_first_visible + capacity < _participants.size(), 1)
	for index in range(_first_visible, mini(_participants.size(), _first_visible + capacity)):
		var x := left_pad + (index - _first_visible) * (CARD_WIDTH + CARD_GAP)
		_cards.append(_make_card(_participants[index], index, x))
	_refresh_cards()


func _add_scroll_button(label: String, x: float, enabled: bool,
		direction: int) -> void:
	var button := Button.new()
	button.text = label
	button.position = Vector2(x, 53.0)
	button.size = Vector2(26.0, 30.0)
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", ALLY_COLOR)
	button.pressed.connect(_scroll.bind(direction))
	_root.add_child(button)


func _scroll(direction: int) -> void:
	var capacity := _visible_capacity(true)
	_first_visible = clampi(_first_visible + direction, 0,
		maxi(0, _participants.size() - capacity))
	_render()


func _make_card(actor: EntityState, order_index: int, x: float) -> Dictionary:
	var card := Control.new()
	card.name = "Turn_%d_%s" % [order_index + 1, actor.instance_id]
	card.position = Vector2(x, 0.0)
	card.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(card)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([
		Vector2(-10.0, -8.0), Vector2(10.0, -8.0), Vector2(0.0, 7.0)])
	arrow.position = Vector2(39.0, 10.0)
	card.add_child(arrow)
	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture = FRAME
	frame.custom_minimum_size = Vector2.ZERO
	frame.position = Vector2(0.0, 21.0)
	frame.size = Vector2(78.0, 84.0)
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = FRAME_SHADER
	frame.material = material
	card.add_child(frame)
	var glow := Panel.new()
	glow.name = "SelectionGlow"
	glow.position = Vector2(0.0, 21.0)
	glow.size = Vector2(78.0, 84.0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_style := StyleBoxFlat.new()
	glow_style.bg_color = Color.TRANSPARENT
	glow_style.border_color = Color(0.31, 0.94, 1.0, 1.0)
	glow_style.set_border_width_all(2)
	glow_style.shadow_color = Color(0.25, 0.89, 1.0, 0.65)
	glow_style.shadow_size = 7
	glow.add_theme_stylebox_override("panel", glow_style)
	card.add_child(glow)
	glow.hide()
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = PORTRAIT_PROVIDER.for_state(actor)
	portrait.custom_minimum_size = Vector2.ZERO
	portrait.position = Vector2(6.0, 27.0)
	portrait.size = Vector2(66.0, 69.0)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gray_material := ShaderMaterial.new()
	gray_material.shader = GRAYSCALE_SHADER
	card.add_child(portrait)
	var rank := Label.new()
	rank.text = str(order_index + 1)
	rank.position = Vector2(7.0, 24.0)
	rank.size = Vector2(18.0, 18.0)
	rank.add_theme_font_override("font", BOLD_FONT)
	rank.add_theme_font_size_override("font_size", 12)
	rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rank)
	var debuffs := GridContainer.new()
	debuffs.name = "Debuffs"
	debuffs.columns = 5
	debuffs.position = Vector2(2.0, 107.0)
	debuffs.size = Vector2(76.0, 34.0)
	debuffs.add_theme_constant_override("h_separation", 1)
	debuffs.add_theme_constant_override("v_separation", 1)
	debuffs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(debuffs)
	var button := Button.new()
	button.name = "Inspect"
	button.flat = true
	button.position = Vector2.ZERO
	button.size = Vector2(78.0, 139.0)
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = ""
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_open_action_menu.bind(actor, button))
	button.mouse_entered.connect(_show_tooltip.bind(actor, button))
	button.mouse_exited.connect(_hide_tooltip.bind(actor))
	button.focus_entered.connect(_show_tooltip.bind(actor, button))
	button.focus_exited.connect(_hide_tooltip.bind(actor))
	card.add_child(button)
	return {"actor": actor, "button": button, "frame": frame, "portrait": portrait,
		"rank": rank, "arrow": arrow, "glow": glow, "debuffs": debuffs,
		"gray_material": gray_material,
		"visual_identity": actor.visual_data(),
		"debuff_signature": ""}


func _refresh_cards() -> void:
	for info in _cards:
		var actor := info["actor"] as EntityState
		if info["visual_identity"] != actor.visual_data():
			info["visual_identity"] = actor.visual_data()
			(info["portrait"] as TextureRect).texture = PORTRAIT_PROVIDER.for_state(actor)
		var hostile := combat_manager != null and actor in combat_manager.enemies
		var spent := _acted.has(actor.instance_id) or actor.current_health <= 0 \
			or (actor.position == EntityState.UNPLACED and actor != _current_actor)
		var accent := SPENT_COLOR if spent else ENEMY_COLOR if hostile else ALLY_COLOR
		((info["frame"] as TextureRect).material as ShaderMaterial).set_shader_parameter(
			"accent", accent)
		(info["portrait"] as TextureRect).material = info["gray_material"] if spent else null
		(info["rank"] as Label).add_theme_color_override("font_color", accent)
		var arrow := info["arrow"] as Polygon2D
		arrow.visible = actor == _current_actor and not spent
		arrow.color = accent
		(info["glow"] as Panel).visible = actor == _selected_enemy \
			and actor.current_health > 0
		_refresh_debuffs(info)


func _refresh_debuffs(info: Dictionary) -> void:
	var actor := info["actor"] as EntityState
	var signature := ""
	for instance in actor.debuffs:
		if instance != null and instance.data != null:
			signature += "%d:%s|" % [instance.get_instance_id(),
				instance.data.icon.resource_path if instance.data.icon != null else ""]
	if signature == info["debuff_signature"]:
		return
	info["debuff_signature"] = signature
	var holder := info["debuffs"] as GridContainer
	for node in holder.get_children():
		holder.remove_child(node)
		node.queue_free()
	for instance in actor.debuffs:
		if instance == null or instance.data == null:
			continue
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(14.0, 14.0)
		icon.texture = instance.data.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.tooltip_text = instance.data.display_name
		holder.add_child(icon)


func _show_tooltip(actor: EntityState, button: Button) -> void:
	_hover_actor = actor
	_update_tooltip_text(actor)
	_tooltip.modulate.a = 0.0
	_tooltip.show()
	get_tree().create_timer(0.035).timeout.connect(
		_finish_strip_tooltip.bind(actor, button), CONNECT_ONE_SHOT)
	var style := _tooltip.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = ENEMY_COLOR if actor in combat_manager.enemies else ALLY_COLOR


func _finish_strip_tooltip(actor: EntityState, button: Button) -> void:
	if _hover_actor != actor or not _tooltip.visible or not is_instance_valid(button):
		return
	_tooltip.reset_size()
	var rect := button.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	_tooltip.position = Vector2(clampf(rect.position.x, 8.0,
		maxf(8.0, screen.x - _tooltip.size.x - 8.0)),
		clampf(rect.end.y + 5.0, 56.0,
			maxf(56.0, screen.y - _tooltip.size.y - 8.0)))
	_tooltip.modulate.a = 1.0


func _update_tooltip_text(actor: EntityState) -> void:
	if actor == null or actor.data == null:
		return
	var masteries: Array[String] = []
	for mastery in [EntityData.Mastery.BLADE, EntityData.Mastery.IMPACT,
			EntityData.Mastery.RANGED]:
		if actor.has_mastery(mastery):
			var label: String = ["", "Lâmina", "Impacto", "Distância"][mastery]
			var level := actor.get_mastery_level(mastery)
			masteries.append("%s +%d" % [label, level] if level > 0 else label)
	_tooltip_text.text = "%s\nVida: %d/%d   ATK: %d\nStamina: %d/%d\nMaestria: %s" % [
		actor.visible_name(), actor.current_health, actor.max_health,
		actor.attack, actor.stamina_remaining, actor.max_stamina,
		", ".join(masteries) if not masteries.is_empty() else "Nenhuma"]


func _hide_tooltip(actor: EntityState) -> void:
	if _hover_actor == actor:
		_hover_actor = null
		_tooltip.hide()


func _open_sheet(actor: EntityState, button: Button) -> void:
	_action_menu.hide()
	_tooltip.hide()
	_hover_actor = null
	if party_hud != null:
		party_hud.show_entity_sheet(actor, button.get_global_rect().get_center())


func _open_action_menu(actor: EntityState, button: Button) -> void:
	if actor == null or actor.current_health <= 0:
		return
	if actor == _current_actor and gerencia != null \
			and actor in gerencia.campaign.companion_states \
			and combat_manager != null and combat_manager.is_player_turn():
		_action_menu.hide()
		_tooltip.hide()
		_hover_actor = null
		if party_hud != null:
			party_hud.show_initiative_companion_actions(actor, button.get_global_rect())
		return
	if combat_manager != null and actor in combat_manager.enemies:
		_select_enemy(actor)
		if combat_manager.map_view != null:
			combat_manager.map_view.highlight_enemy_hex(actor.position)
	_tooltip.hide()
	_hover_actor = null
	if _action_menu.visible and _action_menu.get_meta("actor") == actor:
		_action_menu.hide()
		return
	for child in _action_buttons.get_children():
		_action_buttons.remove_child(child)
		child.queue_free()
	_action_menu.set_meta("actor", actor)
	_add_action_button("DETALHES", func() -> void: _open_sheet(actor, button))
	if actor == _current_actor and combat_manager != null \
			and combat_manager.is_player_turn():
		_add_action_button("AÇÕES", func() -> void:
			_action_menu.hide()
			if party_hud != null:
				party_hud.show_combat_actions_for(actor, button.get_global_rect()))
	(_action_menu.get_theme_stylebox("panel") as StyleBoxFlat).border_color = \
		ENEMY_COLOR if combat_manager != null and actor in combat_manager.enemies else ALLY_COLOR
	_action_menu.show()
	_action_menu.reset_size()
	var rect := button.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	_action_menu.position = Vector2(clampf(rect.position.x, 6.0,
		maxf(6.0, screen.x - _action_menu.size.x - 6.0)),
		clampf(rect.end.y + 5.0, 56.0,
			maxf(56.0, screen.y - _action_menu.size.y - 6.0)))


func _on_hex_choice_requested(coord: Vector2i) -> void:
	if combat_manager == null:
		return
	for enemy in combat_manager.enemies:
		if enemy != null and enemy.current_health > 0 and enemy.position == coord:
			_select_enemy(enemy)
			if combat_manager.map_view != null:
				combat_manager.map_view.highlight_enemy_hex(coord)
			return
	_select_enemy(null)
	if combat_manager.map_view != null:
		combat_manager.map_view.clear_enemy_hex_highlight()


func _select_enemy(enemy: EntityState) -> void:
	_selected_enemy = enemy
	if enemy != null:
		var index := _participants.find(enemy)
		if index >= 0:
			var capacity := _visible_capacity(_participants.size() > _visible_capacity(false))
			if index < _first_visible or index >= _first_visible + capacity:
				_first_visible = clampi(index, 0, maxi(0, _participants.size() - capacity))
				_render()
	_refresh_cards()


func _add_action_button(caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(125.0, 30.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_font_size_override("font_size", 11)
	button.pressed.connect(action)
	_action_buttons.add_child(button)


func _input(event: InputEvent) -> void:
	if _action_menu == null or not _action_menu.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_action_menu.hide()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not _action_menu.get_global_rect().has_point(event.position):
		_action_menu.hide()


func _process(delta: float) -> void:
	if _root == null or not _root.visible:
		if _map_tooltip != null:
			_map_tooltip.hide()
		return
	var previous_x := _root.position.x
	var previous_width := _root.size.x
	_on_viewport_resized_if_needed(previous_x, previous_width)
	_update_map_hover()
	var alpha := 0.4 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.003))
	for info in _cards:
		var arrow := info["arrow"] as Polygon2D
		if arrow.visible:
			arrow.modulate.a = alpha
		var glow := info["glow"] as Panel
		if glow.visible:
			glow.modulate.a = 0.72 + 0.28 * (0.5 + 0.5 \
				* sin(Time.get_ticks_msec() * 0.006))
	_refresh_elapsed += delta
	if _refresh_elapsed < 0.2:
		return
	_refresh_elapsed = 0.0
	_refresh_cards()
	if _hover_actor != null:
		_update_tooltip_text(_hover_actor)


func _on_viewport_resized_if_needed(previous_x: float, previous_width: float) -> void:
	# Reposiciona apenas quando uma caixa expansiva invade a faixa. Sem
	# invasão, o início continua fixo e as setas preservam a navegação.
	var safe_left := LEFT_X
	if party_hud != null:
		for drawer in [party_hud.action_drawer, party_hud.ally_drawer]:
			var drawer_control := drawer as Control
			if drawer_control != null and drawer_control.visible:
				var rect := drawer_control.get_global_rect()
				if rect.position.y < TOP_Y + CARD_HEIGHT and rect.end.y > TOP_Y:
					safe_left = maxf(safe_left, rect.end.x + 18.0)
	if not is_equal_approx(previous_x, safe_left) \
			or not is_equal_approx(previous_width, maxf(180.0, minf(MAX_WIDTH,
				get_viewport().get_visible_rect().size.x - safe_left - RIGHT_RESERVED))):
		_on_viewport_resized()


func _update_map_hover() -> void:
	if combat_manager == null or combat_manager.map_view == null:
		_map_tooltip.hide()
		return
	var pointer := get_viewport().get_mouse_position()
	var hovered: EntityState
	var best_distance := INF
	var overlapping := combat_manager.get_enemies_under_pointer(pointer)
	if not overlapping.is_empty():
		hovered = overlapping[combat_manager.get_body_target_index(pointer,
			overlapping.size())]
	else:
		for actor in _participants:
			if actor == null or actor.current_health <= 0 \
					or actor.position == EntityState.UNPLACED:
				continue
			var center := combat_manager.map_view.get_hex_screen_position(actor.position)
			var bounds := Rect2(center + Vector2(-34.0, -145.0), Vector2(68.0, 145.0))
			if bounds.has_point(pointer) and pointer.distance_to(center) < best_distance:
				hovered = actor
				best_distance = pointer.distance_to(center)
	if hovered == null:
		_map_tooltip.hide()
		return
	_update_tooltip_text(hovered)
	_map_tooltip_text.text = _tooltip_text.text
	var hostile := hovered in combat_manager.enemies
	if hostile and overlapping.size() > 1 and combat_manager.is_player_turn():
		_map_tooltip_text.text = "ALVO %d DE %d · clique novamente para alternar\n%s" % [
			combat_manager.get_body_target_index(pointer, overlapping.size()) + 1,
			overlapping.size(), _map_tooltip_text.text]
	if hostile:
		var preview := combat_manager.get_player_attack_preview(hovered.position)
		if not preview.is_empty():
			_map_tooltip_text.text += "\n%s" % preview.get("text", "")
	_map_tooltip_text.add_theme_color_override("font_color",
		Color(1.0, 0.36, 0.40) if hostile else Color.WHITE)
	_map_tooltip_text.add_theme_font_override("font", BOLD_FONT if hostile else FONT)
	var first_open := not _map_tooltip.visible
	if first_open:
		_map_tooltip.modulate.a = 0.0
	_map_tooltip.show()
	_map_tooltip.reset_size()
	var screen := get_viewport().get_visible_rect().size
	_map_tooltip.position = Vector2(
		clampf(pointer.x + 14.0, 8.0, screen.x - _map_tooltip.size.x - 8.0),
		clampf(pointer.y - _map_tooltip.size.y - 12.0, 55.0,
			screen.y - _map_tooltip.size.y - 8.0))
	if first_open:
		get_tree().create_timer(0.035).timeout.connect(
			_finish_map_tooltip_open, CONNECT_ONE_SHOT)


func _finish_map_tooltip_open() -> void:
	if not _map_tooltip.visible:
		return
	_map_tooltip.reset_size()
	var pointer := get_viewport().get_mouse_position()
	var screen := get_viewport().get_visible_rect().size
	_map_tooltip.position = Vector2(
		clampf(pointer.x + 14.0, 8.0, screen.x - _map_tooltip.size.x - 8.0),
		clampf(pointer.y - _map_tooltip.size.y - 12.0, 55.0,
			screen.y - _map_tooltip.size.y - 8.0))
	_map_tooltip.modulate.a = 1.0
