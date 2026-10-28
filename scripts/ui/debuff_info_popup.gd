class_name DebuffInfoPopup
extends PanelContainer

## Consulta rápida de uma condição aplicada. Hover é transitório; clique fixa
## a ficha até o próximo clique fora ou Esc.

const FONT := preload("res://fonts/UbuntuSans-Regular.ttf")
const BOLD := preload("res://fonts/UbuntuSans-Bold.ttf")

var pinned := false
var title_label: Label
var type_label: Label
var description_label: Label
var duration_label: Label
var _shown_instance: DebuffInstanceState
var _campaign: CampaignState
var _layout_request := 0


func _ready() -> void:
	custom_minimum_size = Vector2(350, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.085, 0.10, 0.96)
	style.border_color = Color(0.48, 0.08, 0.10, 0.9)
	style.set_border_width_all(2)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	title_label = Label.new()
	title_label.add_theme_font_override("font", BOLD)
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.86, 0.24, 0.29))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(title_label)
	type_label = Label.new()
	type_label.add_theme_font_override("font", FONT)
	type_label.add_theme_font_size_override("font_size", 12)
	type_label.add_theme_color_override("font_color", Color(0.88, 0.76, 0.78))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(type_label)
	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UINarrativeFont.apply_label(description_label)
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.95))
	stack.add_child(description_label)
	duration_label = Label.new()
	duration_label.add_theme_font_override("font", FONT)
	duration_label.add_theme_font_size_override("font_size", 11)
	duration_label.add_theme_color_override("font_color", Color(0.82, 0.83, 0.86))
	duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(duration_label)
	hide()


func show_debuff(instance: DebuffInstanceState, anchor: Rect2, fix_open: bool,
		campaign: CampaignState = null) -> void:
	if instance == null or instance.data == null:
		return
	pinned = fix_open
	_shown_instance = instance
	_campaign = campaign
	title_label.text = instance.data.display_name
	type_label.text = "CONDIÇÃO"
	description_label.text = instance.data.description
	_update_duration()
	_layout_request += 1
	var request := _layout_request
	modulate.a = 0.0
	show()
	get_tree().create_timer(0.035).timeout.connect(
		_finish_show_debuff.bind(request, anchor), CONNECT_ONE_SHOT)


func _finish_show_debuff(request: int, anchor: Rect2) -> void:
	if request != _layout_request or not visible:
		return
	reset_size()
	var screen := get_viewport_rect().size
	var x := anchor.end.x + 11.0
	if x + size.x > screen.x - 8.0:
		x = anchor.position.x - size.x - 11.0
	position = Vector2(clampf(x, 8.0, maxf(8.0, screen.x - size.x - 8.0)),
		clampf(anchor.position.y - 4.0, 56.0,
			maxf(56.0, screen.y - size.y - 8.0)))
	modulate.a = 1.0


func _process(_delta: float) -> void:
	if visible:
		_update_duration()


func _update_duration() -> void:
	if _shown_instance == null or _shown_instance.data == null:
		return
	var next_text := _duration_text(_shown_instance, _campaign)
	if duration_label.text != next_text:
		duration_label.text = next_text


func _duration_text(instance: DebuffInstanceState,
		campaign: CampaignState) -> String:
	if instance.data.id in DebuffManager.CLEARED_ON_ROUND_CHANGE:
		if instance.data.id == &"db_00008":
			return "Turnos restantes: %d (ou até a próxima Rodada)" % maxi(0,
				instance.remaining_turns)
		return "Até cessar ou até a próxima Rodada"
	match instance.duration_kind:
		DebuffData.DurationType.TURNS:
			if instance.remaining_turns > 0:
				return "Turnos restantes: %d" % instance.remaining_turns
			return "Até cessar" if instance.data.ends_when_tick_damage_reaches_zero else "Até curar"
		DebuffData.DurationType.DAYS:
			return "Dias restantes: %d" % maxi(0, instance.remaining_days)
		DebuffManager.DURATION_ROUND:
			if campaign != null and instance.expiration_round_index >= 0:
				return "Rodadas restantes: %d" % maxi(0,
					instance.expiration_round_index - campaign.get_round_index())
			return "Até o fim da Rodada"
		DebuffData.DurationType.UNTIL_CURE:
			return "Até curar"
		DebuffData.DurationType.UNTIL_RESIST:
			return "Até resistir"
		_:
			return "Permanente"


func _input(event: InputEvent) -> void:
	if not visible or not pinned:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		hide()
		pinned = false
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and not get_global_rect().has_point(event.position):
		hide()
		pinned = false
