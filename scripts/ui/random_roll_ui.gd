class_name RandomRollUI
extends CanvasLayer

## A moeda ainda é provisória. O dado não fica solto na lateral: Combate e
## Eventos mostram o botão no próprio contexto e usam D6Roller.
signal coin_flipped(choice: int, result: int, guessed: bool)

const ANIMATION_STEPS := 12
const ANIMATION_INTERVAL := 0.05
const GREY := Color("#4d5664")
const YELLOW := Color("#d1ac52")

@onready var _coin_button: Button = $RollContainer/CoinButton
@onready var _choice_panel: Panel = $RollContainer/ChoicePanel
@onready var _choice_a: Button = $RollContainer/ChoicePanel/ChoiceA
@onready var _choice_b: Button = $RollContainer/ChoicePanel/ChoiceB
@onready var _confirm_button: Button = $RollContainer/ChoicePanel/ConfirmButton

var _rng := RandomNumberGenerator.new()
var _busy := false
var _choice := -1


func _ready() -> void:
	_rng.randomize()
	_coin_button.pressed.connect(_on_coin_pressed)
	_choice_a.pressed.connect(_on_choice_pressed.bind(CoinFlip.Side.A))
	_choice_b.pressed.connect(_on_choice_pressed.bind(CoinFlip.Side.B))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_confirm_button.disabled = true
	_choice_panel.hide()
	_set_button_color(_coin_button, GREY)
	_set_button_color(_choice_a, GREY)
	_set_button_color(_choice_b, GREY)
	_set_button_color(_confirm_button, GREY)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#333945")
	panel_style.border_color = Color("#82909f")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	_choice_panel.add_theme_stylebox_override("panel", panel_style)


func _on_coin_pressed() -> void:
	if _busy:
		return
	_choice = -1
	_confirm_button.disabled = true
	_choice_panel.show()
	_coin_button.text = "CARA OU COROA\nEscolha A ou B"
	_set_button_color(_coin_button, YELLOW)
	_set_button_color(_choice_a, GREY)
	_set_button_color(_choice_b, GREY)


func close_expandable_boxes() -> void:
	if _busy or not _choice_panel.visible:
		return
	_choice_panel.hide()
	_choice = -1
	_confirm_button.disabled = true
	_coin_button.text = "CARA OU COROA\nClique para escolher"
	_set_button_color(_coin_button, GREY)


func _on_choice_pressed(side: int) -> void:
	if _busy:
		return
	_choice = side
	_confirm_button.disabled = false
	_set_button_color(_choice_a, YELLOW if side == CoinFlip.Side.A else GREY)
	_set_button_color(_choice_b, YELLOW if side == CoinFlip.Side.B else GREY)


func _on_confirm_pressed() -> void:
	if _busy or _choice < 0:
		return
	_busy = true
	_choice_panel.hide()
	# A escolha do jogador já foi confirmada antes de sortear a moeda.
	var chosen_side := _choice
	var result := CoinFlip.flip(_rng)
	for index in ANIMATION_STEPS:
		_coin_button.text = "CARA OU COROA\n%s" % CoinFlip.side_label(
			CoinFlip.Side.A if randi_range(0, 1) == 0 else CoinFlip.Side.B)
		await get_tree().create_timer(ANIMATION_INTERVAL).timeout
		if not is_inside_tree():
			return
	var guessed := chosen_side == result
	_coin_button.text = "MOEDA: %s\n%s" % [CoinFlip.side_label(result),
		"Acertou!" if guessed else "Errou!"]
	_busy = false
	coin_flipped.emit(chosen_side, result, guessed)


func _set_button_color(button: Button, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("disabled", style)
	var font_color := Color("#1c2430") if color == YELLOW else Color.WHITE
	for theme_color in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		button.add_theme_color_override(theme_color, font_color)
