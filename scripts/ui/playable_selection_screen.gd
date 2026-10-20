class_name PlayableSelectionScreen
extends Control

## Esta é a entrada da campanha: o jogador escolhe de um a três EntityData.
## O jogo sorteia vagas restantes sem repetição; a campanha sempre recebe
## três personagens diferentes em Playable_1, 2 e 3.
const CARD_SCENE := preload("res://scenes/ui/playable_selection_card.tscn")
const GAME_SCENE := preload("res://teste.tscn")
const CARD_HEIGHT := 240.0
const CARD_MIN_WIDTH := 144.0
const CARD_GAP := 8.0

@onready var _scroll: ScrollContainer = $Content/Stack/CardsScroll
@onready var _center: CenterContainer = $Content/Stack/CardsScroll/CardsCenter
@onready var _grid: GridContainer = $Content/Stack/CardsScroll/CardsCenter/CardsGrid
@onready var _summary: Label = $Content/Stack/Summary
@onready var _status: Label = $Content/Stack/Status
@onready var _confirm: Button = $Content/Stack/ConfirmSelection
@onready var _mode_short: Button = $Content/Stack/CampaignModes/Short
@onready var _mode_medium: Button = $Content/Stack/CampaignModes/Medium
@onready var _mode_complete: Button = $Content/Stack/CampaignModes/Complete
@onready var _ending_setup: VBoxContainer = $Content/Stack/EndingSetup
@onready var _ending_hint: Label = $Content/Stack/EndingSetup/Hint
@onready var _ending_choices: GridContainer = $Content/Stack/EndingSetup/Choices
@onready var _ending_random: Button = $Content/Stack/EndingSetup/Choices/Random
@onready var _pregame_summary: ColorRect = $PreGameSummary
@onready var _pregame_mode: Label = $PreGameSummary/Center/Details/Mode
@onready var _pregame_endings: Label = $PreGameSummary/Center/Details/Endings
@onready var _pregame_party: Label = $PreGameSummary/Center/Details/Party
@onready var _pregame_status: Label = $PreGameSummary/Center/Details/Status
@onready var _pregame_back: Button = $PreGameSummary/Center/Details/Actions/Back
@onready var _pregame_start: Button = $PreGameSummary/Center/Details/Actions/Start

var selected: Array[EntityData] = []
var cards: Array[PlayableSelectionCard] = []
var _rng := RandomNumberGenerator.new()
var _selected_mode: int = EventCampaignEligibility.Mode.COMPLETE
var _selected_endings: Array[StringName] = []
var _random_endings := false
var _ending_buttons: Dictionary = {}
var _pending_game: PPPMapView


func _ready() -> void:
	_rng.randomize()
	var catalog := CampaignState.new().get_playable_catalog()
	catalog.sort_custom(func(a: EntityData, b: EntityData) -> bool: return String(a.id) < String(b.id))
	for character in catalog:
		var card := CARD_SCENE.instantiate() as PlayableSelectionCard
		_grid.add_child(card)
		card.setup(character)
		card.chosen.connect(_on_card_chosen)
		cards.append(card)
	_mode_short.pressed.connect(_on_mode_pressed.bind(EventCampaignEligibility.Mode.SHORT))
	_mode_medium.pressed.connect(_on_mode_pressed.bind(EventCampaignEligibility.Mode.MEDIUM))
	_mode_complete.pressed.connect(_on_mode_pressed.bind(EventCampaignEligibility.Mode.COMPLETE))
	_ending_buttons = {
		&"khainokata": $Content/Stack/EndingSetup/Choices/Khainokata,
		&"orchestra": $Content/Stack/EndingSetup/Choices/Orchestra,
		&"homens_de_preto": $Content/Stack/EndingSetup/Choices/HomensDePreto,
		&"controle_da_mente": $Content/Stack/EndingSetup/Choices/ControleDaMente,
	}
	for ending_id in _ending_buttons:
		(_ending_buttons[ending_id] as Button).pressed.connect(
			_on_ending_pressed.bind(ending_id))
	_ending_random.pressed.connect(_on_random_pressed)
	_confirm.pressed.connect(_confirm_selection)
	_pregame_back.pressed.connect(_return_to_selection)
	_pregame_start.pressed.connect(_start_pending_campaign)
	_scroll.resized.connect(_update_layout)
	_update_layout.call_deferred()
	_refresh_campaign_setup()
	_refresh_selection()
	if catalog.size() != 7:
		_status.text = "Foram encontrados %d personagens jogáveis; eram esperados 7." % catalog.size()


func _update_layout() -> void:
	var usable := maxf(_scroll.size.x - 12.0, CARD_MIN_WIDTH)
	# Em janela estreita, duas linhas mantêm todos os alvos de clique visíveis.
	_ending_choices.columns = 3 if usable < 960.0 else 5
	var columns := clampi(floori((usable + CARD_GAP) / (CARD_MIN_WIDTH + CARD_GAP)),
		1, maxi(cards.size(), 1))
	_grid.columns = columns
	var width := floorf((usable - CARD_GAP * float(columns - 1)) / float(columns))
	width = minf(width, 160.0)
	for card in cards:
		card.custom_minimum_size = Vector2(width, CARD_HEIGHT)
	_center.custom_minimum_size.x = _scroll.size.x


func _on_card_chosen(card: PlayableSelectionCard) -> void:
	_discard_pending_game()
	if card.character in selected:
		selected.erase(card.character)
	elif selected.size() < 3:
		selected.append(card.character)
	else:
		_status.text = "Já há três escolhidos. Desmarque um para trocar."
		return
	_status.text = ""
	_refresh_selection()


func _on_mode_pressed(mode: int) -> void:
	_discard_pending_game()
	_selected_mode = mode
	_selected_endings.clear()
	_random_endings = mode != EventCampaignEligibility.Mode.COMPLETE
	_status.text = ""
	_refresh_campaign_setup()


func _on_ending_pressed(ending_id: StringName) -> void:
	if _selected_mode == EventCampaignEligibility.Mode.COMPLETE:
		return
	_discard_pending_game()
	if _random_endings:
		_random_endings = false
		_selected_endings.clear()
	if ending_id in _selected_endings:
		_selected_endings.erase(ending_id)
	elif _selected_endings.size() < _required_endings():
		_selected_endings.append(ending_id)
	else:
		_status.text = "Desmarque um desfecho para escolher outro."
		_refresh_campaign_setup()
		return
	_status.text = ""
	_refresh_campaign_setup()


func _on_random_pressed() -> void:
	_discard_pending_game()
	_random_endings = true
	_selected_endings.clear()
	_status.text = ""
	_refresh_campaign_setup()


func _required_endings() -> int:
	return 1 if _selected_mode == EventCampaignEligibility.Mode.SHORT else 2


func _refresh_campaign_setup() -> void:
	_mode_short.button_pressed = _selected_mode == EventCampaignEligibility.Mode.SHORT
	_mode_medium.button_pressed = _selected_mode == EventCampaignEligibility.Mode.MEDIUM
	_mode_complete.button_pressed = _selected_mode == EventCampaignEligibility.Mode.COMPLETE
	_ending_setup.visible = _selected_mode != EventCampaignEligibility.Mode.COMPLETE
	if _ending_setup.visible:
		_ending_hint.text = "Escolha %d desfecho%s ou use Sortear (%d/%d)." % [
			_required_endings(), "s" if _required_endings() > 1 else "",
			_selected_endings.size(), _required_endings()]
		_ending_random.button_pressed = _random_endings
		for ending_id in _ending_buttons:
			(_ending_buttons[ending_id] as Button).button_pressed = (
				ending_id in _selected_endings)
	_update_layout.call_deferred()
	_refresh_selection()


func _refresh_selection() -> void:
	for card in cards:
		card.set_pick_number(selected.find(card.character) + 1)
	var names: Array[String] = []
	for character in selected:
		names.append(character.display_name)
	_summary.text = "Escolhidos (%d/3): %s" % [selected.size(),
		", ".join(names) if not names.is_empty() else "nenhum"]
	var missing := 3 - selected.size()
	if selected.size() > 0 and missing > 0:
		_summary.text += " • %d vaga(s) serão sorteadas" % missing
	_confirm.disabled = selected.is_empty() or (
		_ending_setup.visible and not _random_endings
		and _selected_endings.size() != _required_endings())


func _complete_party() -> Array[EntityData]:
	var party: Array[EntityData] = []
	party.append_array(selected)
	var candidates: Array[EntityData] = []
	for card in cards:
		if card.character not in selected:
			candidates.append(card.character)
	while party.size() < 3 and not candidates.is_empty():
		party.append(candidates.pop_at(_rng.randi_range(0, candidates.size() - 1)))
	return party


func _confirm_selection() -> void:
	if selected.is_empty():
		return
	if _pending_game != null:
		_show_pregame_summary()
		return
	if _ending_setup.visible and not _random_endings and (
			_selected_endings.size() != _required_endings()):
		_status.text = "Escolha %d desfecho(s) ou use Sortear." % _required_endings()
		return
	var party := _complete_party()
	if party.size() != 3:
		_status.text = "Não há personagens suficientes para completar a equipe."
		return
	_confirm.disabled = true
	var game := GAME_SCENE.instantiate() as PPPMapView
	if game == null:
		_status.text = "Não foi possível abrir a cena do mapa."
		_confirm.disabled = false
		return
	game.visible = false
	get_tree().root.add_child(game)
	var gerencia := game.get_node_or_null("GerenciaJogo") as GerenciaJogo
	var endings: Array[StringName] = []
	if not _random_endings:
		endings.assign(_selected_endings)
	if gerencia == null or not gerencia.start_new_game(party, _selected_mode, endings):
		game.queue_free()
		_status.text = "Não foi possível preparar a campanha; a seleção foi preservada."
		_confirm.disabled = false
		return
	_pending_game = game
	_show_pregame_summary()


func _show_pregame_summary() -> void:
	var campaign := (_pending_game.get_node("GerenciaJogo") as GerenciaJogo).campaign
	var mode_name := "Completa"
	match campaign.campaign_mode:
		EventCampaignEligibility.Mode.SHORT:
			mode_name = "Curta"
		EventCampaignEligibility.Mode.MEDIUM:
			mode_name = "Média"
	_pregame_mode.text = "%s · Meta: %d Informações" % [
		mode_name, campaign.information_goal()]
	var ending_names: Array[String] = []
	for ending_id in campaign.active_ending_ids:
		ending_names.append((_ending_buttons[ending_id] as Button).text)
	_pregame_endings.text = "Desfechos: %s" % ", ".join(ending_names)
	var party_names: Array[String] = []
	for actor in campaign.active_entity_states:
		party_names.append(actor.visible_name())
	_pregame_party.text = "Equipe: %s" % ", ".join(party_names)
	_pregame_status.text = ""
	_pregame_summary.visible = true
	_pregame_start.grab_focus.call_deferred()


func _return_to_selection() -> void:
	_pregame_summary.visible = false
	_confirm.disabled = false
	_confirm.grab_focus.call_deferred()


func _discard_pending_game() -> void:
	if _pending_game != null:
		_pending_game.queue_free()
		_pending_game = null


func _start_pending_campaign() -> void:
	if _pending_game == null:
		return
	_pregame_start.disabled = true
	var round_manager := _pending_game.get_node_or_null("RoundManager") as RoundManager
	if round_manager == null or not round_manager.start_first_map():
		_pregame_status.text = "Não foi possível gerar o mapa. Tente novamente ou volte às escolhas."
		_pregame_start.disabled = false
		return
	var game := _pending_game
	_pending_game = null
	get_tree().current_scene = game
	game.visible = true
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if _pregame_summary.visible and event.is_action_pressed("ui_cancel"):
		_return_to_selection()
		get_viewport().set_input_as_handled()
