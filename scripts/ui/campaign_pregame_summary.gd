class_name CampaignPreGameSummary
extends Control

## Cena independente: mantém a escolha já sorteada; não há mapa nem HUD
## instanciados enquanto o jogador lê a confirmação.
const GAME_SCENE_PATH := "res://scenes/game/campaign_game.tscn"
const ENDING_NAMES := {
	&"khainokata": "Khainokata", &"orchestra": "Orchestra",
	&"homens_de_preto": "Homens de Preto", &"controle_da_mente": "Controle da Mente",
}

@export var artwork: Texture2D

var prepared_campaign: CampaignState
var _loading_step := 0

@onready var _mode: Label = $Presentation/Center/Summary/Mode
@onready var _endings: Label = $Presentation/Center/Summary/Endings
@onready var _characters: Label = $Presentation/Center/Summary/Characters
@onready var _status: Label = $Presentation/Center/Summary/Status
@onready var _start: Button = $Presentation/Center/Summary/Start
@onready var _artwork: TextureRect = $Presentation/Center/Summary/Artwork
@onready var _loading: Control = $Presentation/Loading
@onready var _progress: TextureProgressBar = $Presentation/Loading/Content/Progress


func _ready() -> void:
	_artwork.texture = artwork
	var campaign := prepared_campaign
	if campaign == null or campaign.campaign_status != CampaignState.CampaignStatus.ACTIVE:
		_status.text = "Campanha não preparada."
		_start.disabled = true
		return
	match campaign.campaign_mode:
		EventCampaignEligibility.Mode.SHORT:
			_mode.text = "CAMPANHA CURTA"
		EventCampaignEligibility.Mode.MEDIUM:
			_mode.text = "CAMPANHA MÉDIA"
		EventCampaignEligibility.Mode.COMPLETE:
			_mode.text = "CAMPANHA COMPLETA"
	if campaign.campaign_mode == EventCampaignEligibility.Mode.COMPLETE:
		_endings.hide()
	else:
		var names: Array[String] = []
		for ending_id in campaign.active_ending_ids:
			names.append(str(ENDING_NAMES.get(ending_id,
				str(ending_id).replace("_", " ").capitalize())))
		_endings.text = "DESFECHO" + ("S" if names.size() > 1 else "") \
			+ " · " + "  /  ".join(names)
	var character_names: Array[String] = []
	for slot in CampaignState.PLAYABLE_SLOTS:
		var actor := campaign.get_playable_slot(slot)
		if actor != null:
			character_names.append(actor.visible_name())
	_characters.text = "  ·  ".join(character_names)
	_status.text = "DIFICULDADE · %s" % GameDifficulty.label(campaign.difficulty).to_upper()
	_start.pressed.connect(_start_campaign)
	_start.grab_focus.call_deferred()


func _start_campaign() -> void:
	if prepared_campaign == null or _start.disabled:
		return
	_start.disabled = true
	_loading.show()
	get_node("/root/GameCursor").call("begin_loading", self)
	_loading_step = 0
	_progress.max_value = 42
	_progress.value = 0
	await _show_loading_frame()
	var packed := load(GAME_SCENE_PATH) as PackedScene
	if packed == null:
		_loading_failed("Não foi possível abrir a cena do mapa.")
		return
	_advance_loading_step()
	await _show_loading_frame()
	var game := packed.instantiate() as PPPMapView
	if game == null:
		_loading_failed("Não foi possível abrir a cena do mapa.")
		return
	game.set_meta("defer_preview_map", true)
	_advance_loading_step()
	await _show_loading_frame()
	# Injetar o estado ANTES de _ready: todos os controladores se conectam à
	# instância definitiva, sem criar uma segunda campanha nem refazer sorteios.
	var gerencia := game.get_node_or_null("GerenciaJogo") as GerenciaJogo
	if gerencia == null:
		game.queue_free()
		_loading_failed("Cena de campanha incompleta.")
		return
	gerencia.campaign = prepared_campaign
	game.visible = false
	get_tree().root.add_child(game)
	_advance_loading_step()
	await _show_loading_frame()
	var interface_ready := await game.prepare_initial_interface(_advance_loading_step)
	if not interface_ready:
		game.queue_free()
		_loading_failed("Não foi possível preparar a interface do jogo.")
		return
	var rounds := game.get_node_or_null("RoundManager") as RoundManager
	if rounds == null or not rounds.start_first_map():
		game.queue_free()
		_loading_failed("Não foi possível gerar o mapa. Tente novamente.")
		return
	_advance_loading_step()
	await _show_loading_frame()
	var visuals_ready := await game.prepare_initial_visuals(_advance_loading_step)
	if not visuals_ready:
		game.queue_free()
		_loading_failed("Não foi possível desenhar o mapa. Tente novamente.")
		return
	# O resumo mora numa CanvasLayer acima de toda a HUD. Só retire a tela
	# depois que mapa, interface e paralaxe terminaram de preparar seus nós.
	get_tree().current_scene = game
	get_node("/root/UISFX").call("play", &"start_game")
	game.visible = true
	_advance_loading_step()
	_progress.value = _progress.max_value
	prepared_campaign = null
	get_node("/root/GameCursor").call("end_loading", self)
	queue_free()
	var top_bar := game.get_node_or_null("CampaignTopBar") as CampaignTopBar
	if top_bar != null:
		top_bar.maybe_show_initial_tutorial.call_deferred()


func _show_loading_frame() -> void:
	# A leitura da barra avança apenas depois de etapas concluídas. Dois quadros
	# garantem que o resultado seja desenhado antes da próxima etapa custosa.
	await get_tree().process_frame
	await get_tree().process_frame


func _advance_loading_step() -> void:
	_loading_step += 1
	_progress.value = mini(_loading_step, int(_progress.max_value))


func _loading_failed(message: String) -> void:
	get_node("/root/UISFX").call("play", &"blocked_button")
	_status.text = message
	_loading.hide()
	_start.disabled = false
	get_node("/root/GameCursor").call("end_loading", self)
