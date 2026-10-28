class_name CampaignAutosaveController
extends Node

## Pedidos de save são filas de intenção. Nada é serializado no meio de uma
## ação: o repositório confirma o primeiro limite estável antes de gravar.
signal manual_save_completed(result: Dictionary)
signal autosave_completed(result: Dictionary)

const ACTIVE_INTERVAL_SECONDS := 20.0 * 60.0
const RETRY_SECONDS := 5.0

var enabled := true
var active_seconds := 0.0
var seconds_since_autosave := 0.0
var _session_marked_id := ""
var _last_clock_key := ""
var _pending_manual: Array[Dictionary] = []
var _pending_auto: Array[StringName] = []
var _pending_terminal := false
var _retry_remaining := 0.0
var _save_panel_open := false
var _last_manual_result: Dictionary = {}

@onready var gerencia: GerenciaJogo = get_parent().get_node("GerenciaJogo")
@onready var round_manager: RoundManager = get_parent().get_node("RoundManager")
@onready var combat: CombatManager = get_parent().get_node("CombatManager")
@onready var top_bar: CampaignTopBar = get_parent().get_node("CampaignTopBar")


func _ready() -> void:
	# A suíte headless só escreve quando o teste habilita explicitamente este
	# controlador e aponta um diretório user:// exclusivo do teste.
	if DisplayServer.get_name() == "headless":
		enabled = false
	gerencia.information_granted.connect(_on_information_granted)
	gerencia.map_generated.connect(_on_map_generated)
	round_manager.round_advanced.connect(_on_round_advanced)
	combat.combat_finished.connect(_on_combat_finished)


func _process(delta: float) -> void:
	if not enabled or gerencia == null or gerencia.campaign == null:
		return
	var campaign := gerencia.campaign
	if campaign.campaign_status == CampaignState.CampaignStatus.NOT_STARTED \
			or campaign.current_map == null:
		return
	if _session_marked_id != campaign.campaign_id:
		if not gerencia.save_repository.mark_session_open(campaign.campaign_id):
			return
		_session_marked_id = campaign.campaign_id
		_last_clock_key = _clock_key(campaign)
		active_seconds = 0.0
		seconds_since_autosave = 0.0
	if not campaign.is_terminal() and _is_active_play():
		active_seconds += delta
		seconds_since_autosave += delta
		if seconds_since_autosave >= ACTIVE_INTERVAL_SECONDS:
			request_autosave(&"vinte_minutos")
	_retry_remaining = maxf(0.0, _retry_remaining - delta)
	if _retry_remaining <= 0.0:
		_flush_pending()


func _is_active_play() -> bool:
	if get_tree().paused or _save_panel_open or not (get_parent() as CanvasItem).visible:
		return false
	if top_bar == null:
		return true
	if top_bar.information_archive != null and top_bar.information_archive.visible:
		return false
	if top_bar.group_inventory != null and top_bar.group_inventory.visible:
		return false
	if top_bar.journal_ui != null and top_bar.journal_ui.is_book_open():
		return false
	if round_manager != null and round_manager.is_destination_choice_open():
		return false
	return true


func request_autosave(trigger: StringName) -> void:
	if trigger not in _pending_auto:
		_pending_auto.append(trigger)


func request_terminal_record() -> void:
	_pending_terminal = true


func request_manual_slot(slot_number: int,
		overwrite_confirmed: bool = false) -> Dictionary:
	if slot_number < 1 or slot_number > CampaignSaveRepository.SLOT_COUNT:
		return {"success": false, "reason": "Escolha um dos três slots."}
	if gerencia == null or gerencia.campaign == null \
			or gerencia.campaign.current_map == null:
		return {"success": false, "reason": "Ainda não há campanha para salvar."}
	_pending_manual.append({"slot": slot_number,
		"confirmed": overwrite_confirmed,
		"campaign_id": gerencia.campaign.campaign_id})
	_last_manual_result.clear()
	_flush_pending()
	if _pending_manual.is_empty() and not _last_manual_result.is_empty():
		return _last_manual_result
	return {"success": true, "queued": not _pending_manual.is_empty(),
		"reason": "O save aguardará o fim da ação atual." \
			if not _pending_manual.is_empty() else "Save concluído."}


func set_save_panel_open(open: bool) -> void:
	_save_panel_open = open


func confirm_exit_without_saving() -> bool:
	if gerencia == null or gerencia.campaign == null:
		return false
	# O comando explícito descarta apenas o backup oculto. Saves manuais ficam.
	if not gerencia.save_repository.discard_autosave(gerencia.campaign.campaign_id):
		return false
	_pending_auto.clear()
	_pending_manual.clear()
	_pending_terminal = false
	_session_marked_id = ""
	_last_clock_key = ""
	return true


func _flush_pending() -> void:
	if _pending_manual.is_empty() and _pending_auto.is_empty() \
			and not _pending_terminal:
		return
	if not gerencia.save_repository._scene_save_readiness(get_parent()).get("success", false):
		return
	if _pending_terminal:
		var terminal := gerencia.save_repository.record_terminal_line(gerencia.campaign)
		if terminal.get("success", false):
			_pending_terminal = false
		else:
			_retry_remaining = RETRY_SECONDS
		return
	if not _pending_manual.is_empty():
		var request: Dictionary = _pending_manual.pop_front()
		if request["campaign_id"] != gerencia.campaign.campaign_id:
			_last_manual_result = {"success": false,
				"reason": "A campanha mudou antes do save."}
			manual_save_completed.emit(_last_manual_result)
			return
		var result := gerencia.save_repository.save_campaign(gerencia.campaign,
			int(request["slot"]), get_parent(), bool(request["confirmed"]))
		_last_manual_result = result
		manual_save_completed.emit(result)
		return
	var trigger := _pending_auto[0]
	var result := gerencia.save_repository.save_autosave(gerencia.campaign,
		get_parent(), trigger, active_seconds)
	if result.get("success", false):
		_pending_auto.clear()
		seconds_since_autosave = 0.0
	else:
		_retry_remaining = RETRY_SECONDS
	autosave_completed.emit(result)


func _on_information_granted(_information: Informacao, result: Dictionary) -> void:
	if result.get("success", false):
		request_autosave(&"informacao")


func _on_round_advanced(_day: int, _period: int, _district: StringName,
		_new_map: HexGrid) -> void:
	request_autosave(&"virada_rodada")


func _on_map_generated(_new_map: HexGrid) -> void:
	if gerencia == null or gerencia.campaign == null:
		return
	var current := _clock_key(gerencia.campaign)
	if not _last_clock_key.is_empty() and current != _last_clock_key:
		# Também cobre avanço de Dia provocado por Eventos, sem limitar a
		# geração regular de mapa pelo RoundManager.
		request_autosave(&"virada_rodada")
	_last_clock_key = current


func _clock_key(campaign: CampaignState) -> String:
	return "%d:%d" % [campaign.day, campaign.round_period]


func _on_combat_finished(result: Dictionary) -> void:
	if str(result.get("reason", "")) == "victory":
		request_autosave(&"vitoria_combate")
