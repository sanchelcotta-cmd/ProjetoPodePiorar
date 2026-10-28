class_name RoundManager
extends Node

## Liga o botão "Próxima fase" ao relógio da campanha e ao gerador do mapa.
## Informação só HABILITA a escolha; ninguém é transportado até o jogador
## confirmar um distrito permitido. Não resolve Eventos nem Combates.

signal destination_choice_opened(options: Array[StringName])
signal advance_rejected(reason: String)
signal round_advanced(day: int, period: int, district: StringName, new_map: HexGrid)
signal new_day_started(day: int)

const DISTRICT_ORDER: Array[StringName] = [&"suburbio", &"baixo_centro", &"centro"]
const DESTINATION_PICKER_SCENE := preload("res://scenes/ui/campaign_destination_picker.tscn")

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var block_manager: BlockManager
@export var player_skill_manager: PlayerSkillManager
@export var skill_manager: SkillManager
@export var catastrophe_manager: CatastropheManager
@export var advance_button: Button
var destination_picker: CampaignDestinationPicker


func _ready() -> void:
	if advance_button != null:
		advance_button.pressed.connect(_on_advance_button_pressed)
	destination_picker = DESTINATION_PICKER_SCENE.instantiate() as CampaignDestinationPicker
	get_parent().add_child.call_deferred(destination_picker)
	destination_picker.destination_confirmed.connect(_on_destination_confirmed)
	if block_manager != null:
		block_manager.block_started.connect(_on_block_state_changed)
		block_manager.block_finished.connect(_on_block_state_changed)
	if exploration != null:
		exploration.map_entered.connect(_on_map_entered)
		exploration.turn_started.connect(_on_turn_state_changed)
		exploration.turn_finished.connect(_on_turn_state_changed)
	_refresh_button()


## A futura tela de seleção chama primeiro GerenciaJogo.start_new_game(),
## depois este método. Não escolhemos personagens pelo jogador.
func start_first_map(rng: RandomNumberGenerator = null) -> bool:
	if not _dependencies_ready() or gerencia.campaign.current_map != null \
			or gerencia.campaign.active_entity_states.size() != 3:
		return _reject("Selecione três jogáveis antes de gerar o primeiro mapa.")
	var campaign := gerencia.campaign
	var new_map := gerencia.prepare_map(gerencia.get_information_catalog(),
		campaign.district, campaign.round_period, campaign.get_round_index(), rng)
	if new_map == null or not gerencia.install_map(new_map):
		return _reject("Não foi possível gerar o primeiro mapa; a campanha não avançou.")
	skill_manager.on_day_started(campaign, rng)
	skill_manager.on_round_started(campaign, rng)
	if not exploration.enter_map(true):
		return _reject("O mapa foi gerado, mas a Exploração não pôde iniciar.")
	_refresh_button()
	return true


func can_advance() -> bool:
	return _dependencies_ready() and gerencia.campaign.information_allows_round_advance() \
		and exploration.can_leave_map_now() \
		and not block_manager.is_busy() \
		and not player_skill_manager.has_pending_choice()


## Permanecer ou caminhar para um vizinho; em 19/20 na Completa, o destino
## excepcional é sempre o Centro, mesmo vindo diretamente do Subúrbio.
func available_districts() -> Array[StringName]:
	var result: Array[StringName] = []
	if gerencia == null:
		return result
	if gerencia.campaign.requires_final_center_map():
		result.append(&"centro")
		return result
	var index := DISTRICT_ORDER.find(gerencia.campaign.district)
	if index < 0:
		return result
	result.append(DISTRICT_ORDER[index])
	if index > 0:
		result.append(DISTRICT_ORDER[index - 1])
	if index + 1 < DISTRICT_ORDER.size():
		result.append(DISTRICT_ORDER[index + 1])
	return result


## A tela ou um teste chama isto após a escolha. O próximo mapa é preparado
## ANTES de alterar Dia/Rodada; se faltar um Resource, tudo permanece igual.
func advance_to_district(chosen_district: StringName,
		rng: RandomNumberGenerator = null, force_debug: bool = false) -> bool:
	if force_debug and (not OS.has_feature("debug") \
			or not bool(ProjectSettings.get_setting("ppp/debug/enabled", false))):
		return _reject("Avanço forçado indisponível nesta versão.")
	if not force_debug and not can_advance():
		return _reject("Encontre uma Informação e conclua a ação pendente antes de avançar.")
	if force_debug and (not _dependencies_ready() or block_manager.is_busy() \
			or player_skill_manager.has_pending_choice() \
			or not exploration.can_leave_map_now() \
			or gerencia.campaign.is_terminal() or gerencia.campaign.current_map == null):
		return _reject("Conclua a ação ou o combate antes de avançar.")
	if chosen_district not in available_districts():
		return _reject("Só é possível permanecer ou ir a um distrito adjacente.")
	chosen_district = gerencia.resolve_next_map_district(chosen_district)
	var campaign := gerencia.campaign
	var next_day := campaign.day
	var next_period := campaign.round_period + 1
	if next_period > PPPMapGenerator.RoundPeriod.NIGHT:
		next_period = PPPMapGenerator.RoundPeriod.MORNING
		next_day += 1
	var next_round_index := (next_day - 1) * 3 + next_period
	var new_map := gerencia.prepare_map(gerencia.get_information_catalog(),
		chosen_district, next_period, next_round_index, rng,
		campaign.difficulty_for_next_round())
	if new_map == null:
		return _reject("Não foi possível gerar o próximo mapa; a fase atual foi preservada.")
	var is_new_day := next_day != campaign.day
	campaign.day = next_day
	campaign.round_period = next_period
	campaign.district = chosen_district
	campaign.expire_temporary_events_for_clock()
	if catastrophe_manager != null:
		catastrophe_manager.expire_for_current_time()
	if not gerencia.install_map(new_map):
		return _reject("Não foi possível instalar o novo mapa.")
	campaign.commit_pending_difficulty()
	if is_new_day:
		# Itens que a Praga de Lavas marcou continuam apodrecidos até aqui;
		# a virada descarta as CÓPIAS, não altera os ItemData originais.
		var external_actors: Array[EntityState] = catastrophe_manager.get_external_actors() \
			if catastrophe_manager != null else []
		skill_manager.inventory_manager.discard_spoiled_consumables(campaign, external_actors)
		skill_manager.on_day_started(campaign, rng)
	skill_manager.on_round_started(campaign, rng)
	if not exploration.enter_map(true):
		return _reject("A nova Rodada foi gerada, mas a Exploração não pôde iniciar.")
	_refresh_button()
	round_advanced.emit(campaign.day, campaign.round_period, campaign.district, new_map)
	if is_new_day:
		new_day_started.emit(campaign.day)
	return true


func _on_advance_button_pressed() -> void:
	if not can_advance():
		_reject("O avanço ainda não está disponível.")
		return
	if destination_picker == null:
		_reject("A janela de escolha de distrito ainda não está ligada à cena.")
		return
	var districts := available_districts()
	destination_picker.open_picker(districts, gerencia.campaign.district,
		gerencia.campaign.requires_final_center_map())
	destination_choice_opened.emit(districts)


## A barra superior pode abrir a mesma escolha sem depender do botão antigo.
func request_next_phase() -> void:
	_on_advance_button_pressed()


func _on_destination_confirmed(district: StringName) -> void:
	advance_to_district(district)


func is_destination_choice_open() -> bool:
	return destination_picker != null and destination_picker.is_open()


func _on_block_state_changed(_context: Dictionary) -> void:
	_refresh_button.call_deferred()


func _on_map_entered(_new_map: HexGrid) -> void:
	if destination_picker != null:
		destination_picker.close_picker()
	_refresh_button()


func _on_turn_state_changed(_actor: EntityState) -> void:
	_refresh_button.call_deferred()


func _refresh_button() -> void:
	if advance_button == null:
		return
	var next_period := PPPMapGenerator.RoundPeriod.MORNING
	if gerencia != null:
		next_period = (gerencia.campaign.round_period + 1) % 3
	advance_button.text = "Próxima fase: %s" % _period_label(next_period)
	# Encontrar uma Informação na fase atual faz o botão surgir. Pendências
	# podem desabilitá-lo temporariamente, mas não apagam a descoberta.
	advance_button.visible = gerencia != null \
		and gerencia.campaign.information_allows_round_advance()
	advance_button.disabled = not can_advance()


func _period_label(period: int) -> String:
	match period:
		PPPMapGenerator.RoundPeriod.MORNING: return "Manhã"
		PPPMapGenerator.RoundPeriod.AFTERNOON: return "Tarde"
		PPPMapGenerator.RoundPeriod.NIGHT: return "Noite"
	return "?"


func _dependencies_ready() -> bool:
	return gerencia != null and exploration != null and block_manager != null \
		and player_skill_manager != null and skill_manager != null \
		and gerencia.campaign != null


func _reject(reason: String) -> bool:
	advance_rejected.emit(reason)
	return false
