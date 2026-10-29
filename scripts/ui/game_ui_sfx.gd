class_name GameUISFX
extends Node

## Um roteador para cliques, hover e avisos de interface. Os sons usam ClickUI,
## portanto seguem Efeitos/interface e Geral sem afetar o canal Música.
## A escolha de maior prioridade no mesmo frame impede clique duplo quando
## equipar/criar/confirmar também dispara o botão genérico.

const TRACKS := {
	&"start_game": "res://audio/sfx/ui/start_game.mp3",
	&"blocked_button": "res://audio/sfx/ui/blocked_button.mp3",
	&"hover": "res://audio/sfx/ui/hover.mp3",
	&"menu_page": "res://audio/sfx/ui/menu_page.mp3",
	&"confirm": "res://audio/sfx/ui/confirm.mp3",
	&"equip": "res://audio/sfx/ui/equip.mp3",
	&"unequip": "res://audio/sfx/ui/unequip.mp3",
	&"item_reward": "res://audio/sfx/ui/item_reward.mp3",
	&"inventory_click": "res://audio/sfx/ui/inventory_click.mp3",
	&"epic_craft": "res://audio/sfx/ui/epic_craft.mp3",
	&"outcome_click": "res://audio/sfx/ui/outcome_click.mp3",
	&"general_click": "res://audio/sfx/ui/general_click.mp3",
	&"world_click": "res://audio/sfx/ui/general_click.mp3",
	&"hex_open": "res://audio/sfx/ui/hex_open.mp3",
	&"information_found": "res://audio/sfx/ui/information_found.mp3",
	&"info_records_click": "res://audio/sfx/ui/info_records_click.mp3",
}
const PRIORITY := {
	&"general_click": 10, &"world_click": 10,
	&"menu_page": 20, &"inventory_click": 25,
	&"info_records_click": 30, &"outcome_click": 35,
	&"confirm": 40, &"equip": 55, &"unequip": 55,
	&"epic_craft": 65, &"item_reward": 70,
	&"information_found": 75, &"blocked_button": 75,
	&"start_game": 90,
}
const NOTICES := [&"start_game", &"item_reward", &"epic_craft", &"information_found"]
const HOVER_GAIN := 0.2925 # Metade dos 58,5% anteriores; só mouse sobre botão.

var _streams: Dictionary = {}
var _click_voice: AudioStreamPlayer
var _notice_voice: AudioStreamPlayer
var _panel_voice: AudioStreamPlayer
var _hover_voice: AudioStreamPlayer
var _pending_kind: StringName = &""
var _pending_priority := -1
var _flush_scheduled := false
var _last_hover_msec := -1000
var last_played_kind: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for kind in TRACKS:
		var stream := load(TRACKS[kind]) as AudioStream
		if stream == null:
			push_error("GameUISFX: efeito ausente: %s" % TRACKS[kind])
		else:
			_streams[kind] = stream
	_click_voice = _voice("ClickVoice")
	_notice_voice = _voice("NoticeVoice")
	_panel_voice = _voice("HexPanelVoice")
	_hover_voice = _voice("HoverVoice")
	get_tree().node_added.connect(_register_node)
	_register_tree(get_tree().root)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_register_node):
		tree.node_added.disconnect(_register_node)
	stop_all_playback()
	_streams.clear()


func stop_all_playback() -> void:
	for player in [_click_voice, _notice_voice, _panel_voice, _hover_voice]:
		if player != null:
			player.stop()
			player.stream = null
	_pending_kind = &""
	_pending_priority = -1
	_flush_scheduled = false


func quit_game(exit_code: int = 0) -> void:
	stop_all_playback()
	# O mixer trabalha em outra thread; um quadro isolado ainda pode terminar
	# antes de ela soltar os playbacks MP3.
	await get_tree().create_timer(0.1).timeout
	get_tree().quit(exit_code)


func _voice(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"ClickUI"
	add_child(player)
	return player


func _register_tree(node: Node) -> void:
	_register_node(node)
	for child in node.get_children():
		_register_tree(child)


func _register_node(node: Node) -> void:
	if node is GerenciaJogo and not node.has_meta("ui_sfx_information_bound"):
		node.set_meta("ui_sfx_information_bound", true)
		(node as GerenciaJogo).information_granted.connect(
			func(_information: Informacao, _result: Dictionary) -> void:
				play(&"information_found"))
	if not node is BaseButton or node.has_meta("ui_sfx_bound"):
		return
	var button := node as BaseButton
	button.set_meta("ui_sfx_bound", true)
	button.pressed.connect(_on_button_pressed.bind(button))
	button.mouse_entered.connect(_on_button_hover.bind(button))


func _on_button_pressed(button: BaseButton) -> void:
	if not is_instance_valid(button) or not button.is_visible_in_tree():
		return
	play(&"blocked_button" if button.disabled else _button_kind(button))


func _on_button_hover(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled or not button.is_visible_in_tree():
		return
	var now := Time.get_ticks_msec()
	if now - _last_hover_msec < 85:
		return
	_last_hover_msec = now
	_play_now(&"hover", _hover_voice, 1.0, HOVER_GAIN)


func _button_kind(button: BaseButton) -> StringName:
	if button.has_meta("ui_sfx_kind"):
		return StringName(str(button.get_meta("ui_sfx_kind")))
	if _is_world_control(button):
		return &"world_click"
	var current: Node = button
	while current != null:
		if current is InformationArchivePanel or current is CampaignJournalUI \
				or current is CampaignArchiveLibrary:
			return &"info_records_click"
		if current is GroupInventoryPanel or current is CharacterInventoryPanel \
				or current is InventoryItemMenu or current is EpicCraftPanel:
			return &"inventory_click"
		current = current.get_parent()
	var caption: String = (button as Button).text.strip_edges().to_upper() \
		if button is Button else ""
	if caption.begins_with("CONFIRM") or caption.begins_with("SIM") \
			or caption == "OK" or caption.begins_with("PROSSEGUIR") \
			or caption.begins_with("ACEITAR"):
		return &"confirm"
	return &"general_click"


func _is_world_control(control: Control) -> bool:
	var current: Node = control
	while current != null:
		var node_name := str(current.name)
		if node_name.begins_with("MapCharacter_") \
				or node_name.begins_with("MapCompanion_") \
				or node_name.begins_with("MapDebuff_") \
				or node_name == "HexClickPriority":
			return true
		current = current.get_parent()
	return false


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT \
			or not event.pressed or event.double_click:
		return
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered is BaseButton and (hovered as BaseButton).disabled:
		play(&"blocked_button")
		return
	var scene := get_tree().current_scene
	if not scene is PPPMapView or get_tree().paused:
		return
	if hovered == null or _is_world_control(hovered):
		play(&"world_click")


func play(kind: StringName) -> bool:
	if not _streams.has(kind):
		return false
	if kind == &"hex_open":
		# A abertura da consequência é uma camada distinta do clique no Outcome.
		_play_now(kind, _panel_voice)
		return true
	if kind == &"hover":
		_play_now(kind, _hover_voice, 1.0, HOVER_GAIN)
		return true
	var priority := int(PRIORITY.get(kind, 0))
	if priority >= _pending_priority:
		_pending_kind = kind
		_pending_priority = priority
	if not _flush_scheduled:
		_flush_scheduled = true
		_flush_pending.call_deferred()
	return true


func _flush_pending() -> void:
	_flush_scheduled = false
	var kind := _pending_kind
	_pending_kind = &""
	_pending_priority = -1
	if kind.is_empty():
		return
	var player := _notice_voice if kind in NOTICES else _click_voice
	_play_now(kind, player, 1.13 if kind == &"world_click" else 1.0,
		0.68 if kind == &"blocked_button" else 1.0)


func _play_now(kind: StringName, player: AudioStreamPlayer,
		pitch: float = 1.0, gain: float = 1.0) -> void:
	if player == null or not _streams.has(kind):
		return
	player.stop()
	player.stream = _streams[kind]
	player.pitch_scale = pitch
	player.volume_linear = gain
	player.play()
	last_played_kind = kind
