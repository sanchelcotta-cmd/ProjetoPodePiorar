class_name GerenciaJogo
extends Node

## Coordena o estado da campanha, o gerador e a cena do mapa.
## Não decide movimentos, resolve eventos ou executa combates.

signal map_generated(new_map: HexGrid)

const INFORMATION_DIRECTORY := "res://resources/informacoes"

# Arraste o nó da cena que possui PPPMapView para este campo no Inspetor.
# Sem ele, o mapa ainda é gerado e guardado no estado, mas não é desenhado.
@export var map_view: PPPMapView
# Valor inicial, não limite permanente. Equipamentos e efeitos podem somar
# bônus no EntityState.inventory_capacity_bonus durante a campanha.
@export_range(0, 999) var initial_inventory_capacity: int = 12

var campaign: CampaignState = CampaignState.new()
var _map_generator: PPPMapGenerator = PPPMapGenerator.new()


## A tela de seleção chama isto com três EntityData, na ordem das vagas.
## Não gera o mapa ainda: essa é uma transição separada do início da campanha.
func start_new_game(selected: Array[EntityData],
		mode: int = EventCampaignEligibility.Mode.COMPLETE,
		ending_ids: Array[StringName] = []) -> bool:
	return campaign.start_new_game(selected, initial_inventory_capacity, null,
		mode, ending_ids)


## O futuro controlador de Exploração fornece Informações elegíveis pelas
## regras narrativas. Aqui retiramos as que o grupo já obteve.
## Portal Mágico também pode chamar isto, sem mudar Dia nem Rodada.
func generate_map(
		eligible_information: Array[Resource],
		rng: RandomNumberGenerator = null,
) -> bool:
	var new_map := prepare_map(eligible_information, campaign.district,
		campaign.round_period, campaign.get_round_index(), rng)
	return install_map(new_map)


## Prepara o próximo mapa sem trocar Dia/Rodada nem tocar no mapa atual.
## Assim um pool insuficiente não deixa a campanha presa numa transição parcial.
func prepare_map(
		eligible_information: Array[Resource],
		target_district: StringName,
		target_period: PPPMapGenerator.RoundPeriod,
		target_round_index: int,
		rng: RandomNumberGenerator = null,
) -> HexGrid:
	var remaining := campaign.filter_uncollected_information(eligible_information)
	return _map_generator.generate_new_map(
		remaining,
		target_district,
		target_period,
		campaign.event_campaign_counts.duplicate(),
		campaign.occurred_unique_encounter_ids.duplicate(),
		rng,
		campaign.get_events_on_standby(target_round_index),
		floori(float(target_round_index) / 3.0) + 1,
		not campaign.last_encounter_entity_types.is_empty(),
		campaign.obtained_information_ids.size(),
		campaign.generated_map_count > 0,
		campaign.needs_replacement_ally(),
		campaign.campaign_mode,
	)


## Só instala um mapa COMPLETO. O controlador temporal chama isto depois de
## confirmar a nova Rodada; Portal também pode usar generate_map() normalmente.
func install_map(new_map: HexGrid) -> bool:
	if new_map == null:
		return false
	campaign.record_generated_map(new_map)
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


## São pontos de entrada para o futuro BlockManager. Revelar não chama isto.
func record_information_obtained(information: Informacao) -> bool:
	return campaign.record_information_obtained(information)


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
