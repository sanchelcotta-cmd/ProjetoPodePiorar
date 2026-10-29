class_name SoloEventVisualController
extends Node

## Evento 54: faixa não interativa durante o isolamento e aviso ao término.
## O estado e a troca dos hexes pertencem à CampaignState, não à UI.

const BOLD_FONT := preload("res://fonts/UbuntuSans-Bold.ttf")
const TITLE := "NINGUÉM ALÉM DE VOCÊ"
const RETURN_TEXT := "Os outros retornaram. Você não está mais sozinho."

var _campaign: CampaignState
var _map_view: PPPMapView
var _block_manager: BlockManager
var _banner_layer: CanvasLayer
var _banner: Panel
var _dialog_layer: CanvasLayer
var _dialog_overlay: ColorRect
var _dialog: PanelContainer
var _okay_button: Button
var _dialog_heading: Label
var _dialog_body: Label
var _dialog_kind: StringName = &""


func _ready() -> void:
	_map_view = get_parent() as PPPMapView
	var game := get_parent().get_node_or_null("GerenciaJogo") as GerenciaJogo
	if game == null:
		return
	_campaign = game.campaign
	_block_manager = get_parent().get_node_or_null("BlockManager") as BlockManager
	_campaign.temporary_event_changed.connect(_refresh_banner)
	_campaign.solo_exploration_ended.connect(_show_return_dialog)
	if _block_manager != null:
		_block_manager.solo_cricket_requested.connect(_show_cricket_dialog)
	_banner_layer = CanvasLayer.new()
	_banner_layer.layer = 49 # A faixa superior permanece acima.
	add_child(_banner_layer)
	_banner = Panel.new()
	_banner.name = "NinguemAlemDeVoceBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -190.0
	_banner.offset_right = 190.0
	_banner.offset_top = 61.0
	_banner.offset_bottom = 117.0
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.025, 0.045, 0.055, 0.91)
	banner_style.border_color = Color(0.25, 0.82, 0.88, 0.88)
	banner_style.set_border_width_all(1)
	_banner.add_theme_stylebox_override("panel", banner_style)
	_banner_layer.add_child(_banner)
	var ornament := Label.new()
	ornament.text = "───  · · ·  _ _ _  · · ·  ───"
	ornament.position = Vector2(12, 5)
	ornament.size = Vector2(356, 17)
	ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornament.add_theme_color_override("font_color", Color(0.50, 0.9, 0.93))
	ornament.add_theme_font_size_override("font_size", 11)
	_banner.add_child(ornament)
	var title := Label.new()
	title.text = TITLE
	title.position = Vector2(12, 23)
	title.size = Vector2(356, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_override("font", BOLD_FONT)
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color(0.96, 1.0, 1.0))
	_banner.add_child(title)

	_dialog_layer = CanvasLayer.new()
	_dialog_layer.layer = 80
	add_child(_dialog_layer)
	_dialog_overlay = ColorRect.new()
	_dialog_overlay.color = Color(0.015, 0.02, 0.035, 0.54)
	_dialog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_layer.add_child(_dialog_overlay)
	_dialog = PanelContainer.new()
	_dialog.name = "NinguemAlemDeVoceReturn"
	_dialog.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_dialog.custom_minimum_size = Vector2(470, 190)
	_dialog.position = Vector2(-235, -95)
	var dialog_style := StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.055, 0.07, 0.09, 0.96)
	dialog_style.border_color = Color(0.98, 0.25, 0.60)
	dialog_style.set_border_width_all(2)
	dialog_style.set_content_margin_all(22)
	_dialog.add_theme_stylebox_override("panel", dialog_style)
	_dialog_overlay.add_child(_dialog)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 19)
	_dialog.add_child(contents)
	_dialog_heading = Label.new()
	_dialog_heading.text = "NINGUÉM ALÉM DE VOCÊ"
	_dialog_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_heading.add_theme_font_override("font", BOLD_FONT)
	_dialog_heading.add_theme_font_size_override("font_size", 19)
	_dialog_heading.add_theme_color_override("font_color", Color(1.0, 0.44, 0.71))
	contents.add_child(_dialog_heading)
	_dialog_body = Label.new()
	_dialog_body.text = RETURN_TEXT
	_dialog_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_body.add_theme_font_size_override("font_size", 17)
	_dialog_body.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	contents.add_child(_dialog_body)
	_okay_button = Button.new()
	_okay_button.text = "OKAY"
	_okay_button.custom_minimum_size = Vector2(130, 38)
	_okay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_okay_button.pressed.connect(_dismiss_return_dialog)
	contents.add_child(_okay_button)
	_dialog_layer.hide()
	_refresh_banner()


func _refresh_banner() -> void:
	if _campaign == null or _banner_layer == null:
		return
	_banner_layer.visible = _campaign.solo_turns_remaining > 0
	if _map_view != null and _map_view.grid == _campaign.current_map:
		_map_view._refresh_feedback()
		_map_view.refresh_special_event_visuals()


func _show_return_dialog() -> void:
	_refresh_banner()
	_dialog_kind = &"return"
	_dialog_heading.text = "NINGUÉM ALÉM DE VOCÊ"
	_dialog_body.text = RETURN_TEXT
	_dialog_layer.show()
	_okay_button.grab_focus()


func _show_cricket_dialog(_context: Dictionary) -> void:
	_dialog_kind = &"cricket"
	_dialog_heading.text = "Cric Cric..."
	_dialog_body.text = "Cric.. Cric.. Cric.."
	_dialog_layer.show()
	_okay_button.grab_focus()


func _dismiss_return_dialog() -> void:
	if _dialog_kind == &"cricket":
		_dialog_kind = &""
		_dialog_layer.hide()
		# Concluir o hex pode encerrar o terceiro turno e abrir, no mesmo
		# instante, o aviso de retorno. Não escondê-lo após esse sinal.
		if _block_manager != null:
			_block_manager.confirm_solo_cricket()
		return
	_dialog_kind = &""
	_dialog_layer.hide()


func _unhandled_input(_event: InputEvent) -> void:
	# O retorno exige o botão visível; Esc não confirma o aviso.
	pass
