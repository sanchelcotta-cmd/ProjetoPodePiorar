class_name GerenciaJogo
extends Node

## Coordena o estado da campanha, o gerador e a cena do mapa.
## Não decide movimentos, resolve eventos ou executa combates.

signal map_generated(new_map: HexGrid)
signal information_granted(information: Informacao, result: Dictionary)
signal final_center_map_entered

const INFORMATION_DIRECTORY := "res://resources/informacoes"

# Arraste o nó da cena que possui PPPMapView para este campo no Inspetor.
# Sem ele, o mapa ainda é gerado e guardado no estado, mas não é desenhado.
@export var map_view: PPPMapView
# Valor inicial, não limite permanente. Equipamentos e efeitos podem somar
# bônus no EntityState.inventory_capacity_bonus durante a campanha.
@export_range(0, 999) var initial_inventory_capacity: int = 12

var campaign: CampaignState = CampaignState.new()
var _map_generator: PPPMapGenerator = PPPMapGenerator.new()
var save_repository: CampaignSaveRepository = CampaignSaveRepository.new()


func list_saved_campaigns() -> Array[Dictionary]:
	return save_repository.list_campaigns()


func save_manual_slot(slot_number: int, overwrite_confirmed: bool = false) -> Dictionary:
	var controller := get_parent().get_node_or_null("CampaignAutosaveController")
	if controller != null and controller.get("enabled"):
		return controller.call("request_manual_slot", slot_number, overwrite_confirmed)
	return save_repository.save_campaign(campaign, slot_number, get_parent(),
		overwrite_confirmed)


func load_manual_slot(campaign_id: String, slot_number: int) -> Dictionary:
	return save_repository.load_campaign(campaign_id, slot_number, get_parent())


## A tela de seleção chama isto com três EntityData, na ordem das vagas.
## Não gera o mapa ainda: essa é uma transição separada do início da campanha.
func start_new_game(selected: Array[EntityData],
		mode: int = EventCampaignEligibility.Mode.COMPLETE,
		ending_ids: Array[StringName] = [],
		difficulty: int = GameDifficulty.Mode.STANDARD) -> bool:
	return campaign.start_new_game(selected, initial_inventory_capacity, null,
		mode, ending_ids, difficulty)


## O futuro controlador de Exploração fornece Informações elegíveis pelas
## regras narrativas. Aqui retiramos as que o grupo já obteve.
## Portal Mágico também pode chamar isto, sem mudar Dia nem Rodada.
func generate_map(
		eligible_information: Array[Resource],
		rng: RandomNumberGenerator = null,
) -> bool:
	var destination := resolve_next_map_district(campaign.district)
	var new_map := prepare_map(eligible_information, destination,
		campaign.round_period, campaign.get_round_index(), rng)
	if new_map == null:
		return false
	campaign.district = destination
	return install_map(new_map)


func resolve_next_map_district(requested: StringName) -> StringName:
	return &"centro" if campaign.requires_final_center_map() else requested


## Prepara o próximo mapa sem trocar Dia/Rodada nem tocar no mapa atual.
## Assim um pool insuficiente não deixa a campanha presa numa transição parcial.
func prepare_map(
		eligible_information: Array[Resource],
		target_district: StringName,
		target_period: PPPMapGenerator.RoundPeriod,
		target_round_index: int,
		rng: RandomNumberGenerator = null,
		difficulty_override: int = -1,
) -> HexGrid:
	if campaign.is_terminal():
		return null
	var remaining := campaign.filter_uncollected_information(eligible_information)
	target_district = resolve_next_map_district(target_district)
	var target_difficulty := difficulty_override if GameDifficulty.is_available(difficulty_override) \
		else campaign.difficulty
	var target_day := floori(float(target_round_index) / 3.0) + 1
	var suppress_hazards := target_difficulty == GameDifficulty.Mode.SUGAR \
		and (campaign.has_carried_curse() \
		or campaign.has_catastrophe_at(target_day, target_round_index))
	var source_rng := rng if rng != null else campaign.world_rng
	var new_map := _map_generator.generate_new_map(
		remaining,
		target_district,
		target_period,
		campaign.event_campaign_counts.duplicate(),
		campaign.occurred_unique_encounter_ids.duplicate(),
		source_rng,
		campaign.get_events_on_standby(target_round_index),
		target_day,
		not campaign.last_encounter_entity_types.is_empty(),
		campaign.obtained_information_ids.size(),
		campaign.generated_map_count > 0,
		campaign.needs_replacement_ally(),
		campaign.campaign_mode,
		campaign.allows_free_information_on_next_map(),
		target_difficulty,
		suppress_hazards,
	)
	if new_map != null:
		new_map.ppp_decoration_seed = source_rng.randi()
		new_map.ppp_anomaly_planned = source_rng.randf() \
			< campaign.decoration_anomaly_chance(target_day)
	return new_map


## Só instala um mapa COMPLETO. O controlador temporal chama isto depois de
## confirmar a nova Rodada; Portal também pode usar generate_map() normalmente.
func install_map(new_map: HexGrid) -> bool:
	if new_map == null or campaign.is_terminal():
		return false
	campaign.record_generated_map(new_map)
	if campaign.requires_final_center_map() and campaign.district == &"centro" \
			and not campaign.final_center_intro_seen:
		campaign.final_center_intro_pending = true
		final_center_map_entered.emit()
	if map_view != null:
		map_view.show_generated_map(new_map)
		map_view.set_visual_effects(campaign.get_active_visual_weather(),
			campaign.are_infernal_portals_visuals_active())
	map_generated.emit(new_map)
	return true


## Lê as Informações cadastradas, sem fixar os 20 arquivos em código.
## CampaignState.filter_uncollected_information retira as já obtidas.
func get_information_catalog() -> Array[Resource]:
	return _load_information_folder(INFORMATION_DIRECTORY)


func _load_information_folder(folder: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var files := ResourceLoader.list_directory(folder)
	files.sort()
	for entry in files:
		if entry.ends_with("/"):
			result.append_array(_load_information_folder(folder.path_join(entry.trim_suffix("/"))))
		elif entry.ends_with(".tres"):
			var information := load(folder.path_join(entry)) as Informacao
			if information != null and information.id != &"":
				result.append(information)
	return result


## Ponto de entrada comum para todas as fontes reais ou futuras. Revelar não
## chama isto: só obter conta. O resultado explica recusa sem rerrolar.
func grant_information(information: Informacao,
		source_id: StringName = &"", force_debug: bool = false) -> Dictionary:
	var result := campaign.grant_information(information, source_id, force_debug)
	if result.get("success", false):
		information_granted.emit(information, result)
		if result.get("victory", false):
			# A última Informação só entra no livro depois do sinal acima.
			# O registro terminal é separado dos três slots e nunca os altera.
			campaign.append_journal_entry(&"campaign_terminal", [
				{"text": "A campanha terminou em ", "tone": "text"},
				{"text": "vitória", "tone": "positive"},
				{"text": ".", "tone": "text"},
			])
			result["terminal_record"] = request_terminal_record()
	return result


func request_terminal_record() -> Dictionary:
	if campaign == null or not campaign.is_terminal():
		return {"success": false, "reason": "A campanha ainda não terminou."}
	var controller := get_parent().get_node_or_null("CampaignAutosaveController")
	if controller != null and controller.get("enabled"):
		controller.call("request_terminal_record")
		return {"success": true, "queued": true}
	return save_repository.record_terminal_line(campaign)


## Compatibilidade com chamadas que só esperavam um booleano.
func record_information_obtained(information: Informacao) -> bool:
	return grant_information(information).get("success", false)


func record_encounter_occurred(encounter: EncounterData) -> bool:
	return campaign.record_encounter_occurred(encounter)


## O BlockManager chama isto quando o jogador ATIVA o evento.
## Só aparecer no mapa não inicia a espera.
func record_event_activated(event: EventData) -> bool:
	# Standby começa ao ativar o bloco. Filtro/efeitos só começam depois de
	# confirmar o resultado na janela; o Pedreiro ainda pode impedi-los.
	return campaign.record_event_activated(event)


## Usado quando uma Skill destrói o bloco antes de o Evento fazer efeito.
func record_event_prevented(event: EventData) -> bool:
	return campaign.record_event_prevented(event)
