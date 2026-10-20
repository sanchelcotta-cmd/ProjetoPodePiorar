class_name CampaignTopBar
extends CanvasLayer

## Relógio e localização da campanha. Lê o estado atual; não decide regras.
## Menu contém o acesso à próxima fase. Som alterna o bus Master do Godot.

@export var gerencia: GerenciaJogo
@export var round_manager: RoundManager
@export var combat_mode_style: StyleBoxFlat

@onready var day_label: Label = $Bar/Items/Day/DayText
@onready var information_button: Button = $Bar/Items/InformationButton
@onready var group_inventory_button: Button = $Bar/Items/GroupInventoryButton
@onready var period_label: Label = $Bar/Items/Period/PeriodText
@onready var district_label: Label = $Bar/Items/District/DistrictText
@onready var mode_label: Label = $Bar/Items/Mode/ModeText
@onready var mode_panel: PanelContainer = $Bar/Items/Mode
@onready var bar_panel: PanelContainer = $Bar
@onready var combat_border: Panel = $CombatBorder
@onready var menu_button: MenuButton = $Bar/Items/MenuButton
@onready var sound_button: Button = $Bar/Items/SoundButton

var _last_signature := ""
var information_archive: InformationArchivePanel
var group_inventory: GroupInventoryPanel
var _exploration_mode_style: StyleBox
var _exploration_bar_style: StyleBox
var _combat_bar_style: StyleBoxFlat
var _exploration_mode_text_color: Color
const INFORMATION_ARCHIVE_SCENE = preload("res://scenes/ui/information_archive_panel.tscn")
const GROUP_INVENTORY_SCENE = preload("res://scenes/ui/group_inventory_panel.tscn")


func _ready() -> void:
	_exploration_mode_style = mode_panel.get_theme_stylebox("panel")
	_exploration_bar_style = bar_panel.get_theme_stylebox("panel")
	_exploration_mode_text_color = mode_label.get_theme_color("font_color")
	_combat_bar_style = _exploration_bar_style.duplicate() as StyleBoxFlat
	_combat_bar_style.border_width_top = 2
	_combat_bar_style.border_color = Color(0.87, 0.09, 0.12, 1.0)
	information_archive = INFORMATION_ARCHIVE_SCENE.instantiate() as InformationArchivePanel
	add_child(information_archive)
	information_archive.gerencia = gerencia
	group_inventory = GROUP_INVENTORY_SCENE.instantiate() as GroupInventoryPanel
	add_child(group_inventory)
	group_inventory.gerencia = gerencia
	group_inventory.skill_manager = get_parent().get_node_or_null("SkillManager") as SkillManager
	group_inventory.combat_manager = get_parent().get_node_or_null("CombatManager") as CombatManager
	group_inventory.exploration = get_parent().get_node_or_null("ExplorationManager") as ExplorationManager
	information_button.pressed.connect(_toggle_information_archive)
	group_inventory_button.pressed.connect(_toggle_group_inventory)
	var popup := menu_button.get_popup()
	popup.clear()
	popup.add_item("Próxima fase", 0)
	popup.add_item("Fechar menu", 1)
	popup.about_to_popup.connect(_refresh_menu)
	popup.id_pressed.connect(_on_menu_item_pressed)
	sound_button.pressed.connect(_toggle_sound)
	if gerencia != null:
		gerencia.map_generated.connect(func(_map: HexGrid) -> void: refresh())
		gerencia.campaign.playable_death_finalized.connect(
			_on_playable_death_finalized)
	if round_manager != null:
		round_manager.round_advanced.connect(func(_day: int, _period: int,
			_district: StringName, _map: HexGrid) -> void: refresh())
	refresh()
	_refresh_sound()


func _on_playable_death_finalized(actor: EntityState,
		leftover: Array[InventoryItemState]) -> void:
	if leftover.is_empty() or group_inventory == null:
		return
	group_inventory.begin_death_cleanup.call_deferred(actor)


func _toggle_information_archive() -> void:
	if group_inventory != null and group_inventory.get("_death_owner") != null:
		return
	if information_archive.visible:
		information_archive.close()
	else:
		group_inventory.close()
		information_archive.open()


func _toggle_group_inventory() -> void:
	if group_inventory != null and group_inventory.get("_death_owner") != null:
		return
	if group_inventory.visible:
		group_inventory.close()
	else:
		information_archive.close()
		group_inventory.open()


func close_expandable_boxes() -> void:
	menu_button.get_popup().hide()
	if information_archive != null and information_archive.visible:
		information_archive.close()
	if group_inventory != null and group_inventory.visible:
		group_inventory.close()


func _process(_delta: float) -> void:
	# A troca Exploração/Combate ainda não emite sinal próprio.
	refresh()


func refresh() -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	var campaign := gerencia.campaign
	var mode := HexGrid.PPPMapMode.EXPLORATION
	if campaign.current_map != null:
		@warning_ignore("int_as_enum_without_cast")
		mode = campaign.current_map.ppp_map_mode
	var signature := "%d|%d|%s|%d" % [campaign.day, campaign.round_period,
		campaign.district, mode]
	if signature == _last_signature:
		return
	_last_signature = signature
	day_label.text = "▣ DIA %d" % campaign.day
	match campaign.round_period:
		PPPMapGenerator.RoundPeriod.MORNING:
			period_label.text = "☀ MANHÃ"
		PPPMapGenerator.RoundPeriod.AFTERNOON:
			period_label.text = "☀ TARDE"
		PPPMapGenerator.RoundPeriod.NIGHT:
			period_label.text = "☾ NOITE"
	match campaign.district:
		&"suburbio": district_label.text = "◆ SUBÚRBIO"
		&"baixo_centro": district_label.text = "◆ BAIXO-CENTRO"
		&"centro": district_label.text = "◆ CENTRO"
		_: district_label.text = "◆ %s" % str(campaign.district).to_upper()
	mode_label.text = "MODO:\nCOMBATE" if mode == HexGrid.PPPMapMode.COMBAT \
		else "MODO:\nEXPLORAÇÃO"
	var in_combat := mode == HexGrid.PPPMapMode.COMBAT
	mode_panel.add_theme_stylebox_override("panel", combat_mode_style if in_combat \
		else _exploration_mode_style)
	bar_panel.add_theme_stylebox_override("panel", _combat_bar_style if in_combat \
		else _exploration_bar_style)
	mode_label.add_theme_color_override("font_color", Color(1.0, 0.38, 0.39) \
		if in_combat else _exploration_mode_text_color)
	combat_border.visible = in_combat


func _refresh_menu() -> void:
	menu_button.get_popup().set_item_disabled(0,
		round_manager == null or not round_manager.can_advance())


func _on_menu_item_pressed(id: int) -> void:
	if id == 0 and round_manager != null:
		round_manager.request_next_phase()


func _toggle_sound() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, not AudioServer.is_bus_mute(bus))
	_refresh_sound()


func _refresh_sound() -> void:
	var bus := AudioServer.get_bus_index("Master")
	var muted := bus >= 0 and AudioServer.is_bus_mute(bus)
	sound_button.text = "▬" if muted else "♪"
	sound_button.tooltip_text = "Ativar som" if muted else "Silenciar som"
