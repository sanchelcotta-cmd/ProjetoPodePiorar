class_name PPPMapGenerator
extends RefCounted

enum RoundPeriod {
	MORNING,
	AFTERNOON,
	NIGHT,
}

## Distribui Resources pelos 40 hexágonos de um mapa PPP.
## Use generate_new_map() TODA vez que um novo mapa nascer: nova Rodada,
## Portal Mágico ou outro efeito que substitua o mapa. Não chame ao ativar hex.

# EDITAR A DISTRIBUIÇÃO AQUI. A soma de todas as linhas deve continuar em 40.
# A StartZone dos personagens fica fora desses 40 hexágonos.
const INFORMATION_COUNT := 1
const CONSUMABLE_COUNT := 6
const EQUIPMENT_COUNT := 8
const ENCOUNTER_COUNT := 10
const GOOD_EVENT_COUNT := 4
const AMBIGUOUS_EVENT_COUNT := 5
const BAD_EVENT_COUNT := 3
const FREE_BLOCK_COUNT := 3

# Caótico conserva 1 Informação fixa e 3 livres, mas varia as outras 36
# posições. Não existe cota, compensação ou teto de valência dos Eventos.
const CHAOTIC_BASE_COUNTS := {"consumable": 5, "equipment": 7,
	"encounter": 10, "event": 14}
const CHAOTIC_MIN_COUNTS := {"consumable": 4, "equipment": 6,
	"encounter": 8, "event": 12}
const CHAOTIC_MAX_COUNTS := {"consumable": 7, "equipment": 9,
	"encounter": 11, "event": 15}

# Limites por Resource dentro de UM mapa. Os contadores reiniciam no mapa novo.
const MAX_ENCOUNTER_COPIES_PER_MAP := 3
const MAX_ITEM_COPIES_PER_MAP := 3
const MAX_CURSE_COPIES_PER_MAP := 1
const BACKGROUND_DIRECTORY := "res://sprites/background"
const LIGHTNING_EVENT_IDS := [&"ev_00005", &"ev_00006"]
const REPLACEMENT_ALLY_EVENT := preload("res://resources/events/permanent_effects/65-um_aliado.tres")

# Os 3 blocos livres escolhem primeiro um TIPO, com chance igual por tipo.
# Um tipo escolhido sai da lista: não podem surgir duas Armadilhas livres,
# duas Informações livres etc. O Resource é sorteado depois, dentro do tipo.
const FREE_TYPES := [
	HexGrid.PPPBlockType.INFORMATION,
	HexGrid.PPPBlockType.CONSUMABLE,
	HexGrid.PPPBlockType.EQUIPMENT,
	HexGrid.PPPBlockType.EVENT,
	HexGrid.PPPBlockType.ENCOUNTER,
	HexGrid.PPPBlockType.CATASTROPHE,
	HexGrid.PPPBlockType.TRAP,
	HexGrid.PPPBlockType.CURSE,
]

var _rng: RandomNumberGenerator
var _information_used: Dictionary = {}
var _event_placements: Dictionary = {}
var _event_campaign_counts: Dictionary = {}
var _events_on_standby: Dictionary = {}
var _standby_oldest_first: Array[String] = []
var _encounter_placements: Dictionary = {}
var _item_placements: Dictionary = {}
var _occurred_encounter_ids: Dictionary = {}
var _has_completed_encounter_history := false
var _allow_traps := false
var _allow_catastrophes := false
var _force_replacement_ally := false
var _campaign_mode: int = EventCampaignEligibility.Mode.COMPLETE
var _difficulty: int = GameDifficulty.Mode.STANDARD
var _hazard_budget := 999999
var _hazards_placed := 0
var _pools: Dictionary = {}
var _chaotic_counts: Dictionary = {}


## Passe apenas as Informações ainda elegíveis na campanha. Os Encontros são
## carregados como EncounterData da pasta res://resources/encounters/.
## Cada EncounterData referencia suas criaturas e quantidades internamente.
##
## event_campaign_counts usa resource_path -> quantidade já gerada na campanha.
## events_on_standby contém caminhos de Eventos ATIVADOS recentemente,
## do mais antigo ao mais recente. Somente Eventos entram nesse standby:
## Encontros e Itens nunca são bloqueados entre mapas por esta regra.
## aparecer no mapa sem ativação nunca bloqueia um próximo sorteio.
## occurred_encounter_ids contém IDs de encontros únicos que de fato já
## aconteceram. Gerar um hex e não ativá-lo NÃO conta como ocorrência.
## has_completed_encounter_history permite sortear Eventos que dependem do
## último inimigo enfrentado, como Mutação Genética.
## Se qualquer pool obrigatório faltar, devolve null, sem criar mapa incompleto.
func generate_new_map(
		eligible_information: Array[Resource],
		district: StringName,
		round_period: RoundPeriod,
		event_campaign_counts: Dictionary = {},
		occurred_encounter_ids: Array[StringName] = [],
		rng: RandomNumberGenerator = null,
		events_on_standby: Array[String] = [],
		day: int = 1,
		has_completed_encounter_history: bool = false,
		group_information_count: int = 0,
		has_generated_map_before: bool = false,
		force_replacement_ally: bool = false,
		campaign_mode: int = EventCampaignEligibility.Mode.COMPLETE,
		allow_free_information: bool = true,
		difficulty: int = GameDifficulty.Mode.STANDARD,
		suppress_hazards: bool = false,
) -> HexGrid:
	if not GameDifficulty.is_available(difficulty):
		push_error("PPPMapGenerator: dificuldade indisponível.")
		return null
	_difficulty = difficulty
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()
	_chaotic_counts = _draw_chaotic_counts() if _difficulty == GameDifficulty.Mode.CHAOTIC else {}
	if not _quotas_are_valid():
		push_error("PPPMapGenerator: as cotas não somam 40. Revise os valores no início do script.")
		return null
	_information_used.clear()
	_event_placements.clear()
	_encounter_placements.clear()
	_item_placements.clear()
	_occurred_encounter_ids.clear()
	_events_on_standby.clear()
	_standby_oldest_first.clear()
	for event_path in events_on_standby:
		if _events_on_standby.has(event_path):
			continue
		_events_on_standby[event_path] = true
		_standby_oldest_first.append(event_path)
	for encounter_id in occurred_encounter_ids:
		_occurred_encounter_ids[encounter_id] = true
	_event_campaign_counts = event_campaign_counts.duplicate()
	_has_completed_encounter_history = has_completed_encounter_history
	# Valem para TODOS os sorteios: Eventos fixos por valência e blocos livres.
	# Um Portal na primeira Rodada pode criar outro mapa, mas Armadilha ainda
	# exige uma Informação de fato coletada pelo grupo.
	_allow_traps = group_information_count > 0 and has_generated_map_before
	_allow_catastrophes = day > 1
	_force_replacement_ally = force_replacement_ally
	_campaign_mode = campaign_mode
	_hazards_placed = 0
	_hazard_budget = 0 if _difficulty == GameDifficulty.Mode.SUGAR \
		and (not has_generated_map_before or suppress_hazards) else \
		1 if _difficulty == GameDifficulty.Mode.SUGAR else 999999
	_pools = _build_pools(eligible_information, district, round_period)
	if _difficulty == GameDifficulty.Mode.CHAOTIC and _force_replacement_ally:
		# Reserva o aliado obrigatório antes dos sorteios sem valência.
		_event_placements[REPLACEMENT_ALLY_EVENT.resource_path] = 1
	if not _fixed_pools_are_available():
		return null

	var placements: Array[Dictionary] = []
	for _index in INFORMATION_COUNT:
		if not _append_choice(placements, HexGrid.PPPBlockType.INFORMATION, false):
			return null
	for _index in _consumable_count():
		if not _append_choice(placements, HexGrid.PPPBlockType.CONSUMABLE, false):
			return null
	for _index in _equipment_count():
		if not _append_choice(placements, HexGrid.PPPBlockType.EQUIPMENT, false):
			return null
	for _index in _encounter_count():
		if not _append_choice(placements, HexGrid.PPPBlockType.ENCOUNTER, false):
			return null
	if _difficulty == GameDifficulty.Mode.CHAOTIC:
		for index in _chaotic_event_count():
			if index == 0 and _force_replacement_ally:
				var ally_event := REPLACEMENT_ALLY_EVENT as EventData
				placements.append({"type": _type_for_event(ally_event),
					"resource": ally_event, "free": false})
			elif not _append_event_choice(placements, -1, false):
				return null
	else:
		for index in _good_event_count():
			if index == 0 and _force_replacement_ally:
				var ally_event := REPLACEMENT_ALLY_EVENT as EventData
				placements.append({"type": _type_for_event(ally_event),
					"resource": ally_event, "free": false})
				_event_placements[ally_event.resource_path] = 1
			elif not _append_event_choice(placements, EventData.Valence.GOOD, false):
				return null
		for _index in AMBIGUOUS_EVENT_COUNT:
			if not _append_event_choice(placements, EventData.Valence.AMBIGUOUS, false):
				return null
		for _index in _bad_event_count():
			if not _append_event_choice(placements, EventData.Valence.BAD, false):
				return null

	var remaining_types: Array[int] = []
	remaining_types.assign(FREE_TYPES)
	# Na reta final da Completa, a última parte não vem de um segundo hex.
	# A Informação fixa acima permanece; Eventos/itens concedem bônus fora daqui.
	if not allow_free_information or _difficulty == GameDifficulty.Mode.CHAOTIC:
		remaining_types.erase(HexGrid.PPPBlockType.INFORMATION)
	var chaotic_free_counts: Dictionary = {}
	for _index in FREE_BLOCK_COUNT:
		var available_types: Array[int] = []
		for block_type in remaining_types:
			if _difficulty == GameDifficulty.Mode.CHAOTIC and \
					int(chaotic_free_counts.get(block_type, 0)) >= \
					(2 if block_type in [HexGrid.PPPBlockType.CONSUMABLE,
						HexGrid.PPPBlockType.EQUIPMENT, HexGrid.PPPBlockType.EVENT,
						HexGrid.PPPBlockType.ENCOUNTER] else 1):
				continue
			if block_type in [HexGrid.PPPBlockType.TRAP,
					HexGrid.PPPBlockType.CATASTROPHE] \
					and _placements_contain_type(placements, block_type):
				continue
			if _can_draw(block_type):
				available_types.append(block_type)
		if available_types.is_empty():
			push_error("PPPMapGenerator: faltam tipos/Resources elegíveis para os blocos livres.")
			return null
		var chosen_type: int = _draw_free_type(available_types)
		if _difficulty == GameDifficulty.Mode.CHAOTIC:
			chaotic_free_counts[chosen_type] = int(chaotic_free_counts.get(chosen_type, 0)) + 1
		else:
			remaining_types.erase(chosen_type)
		if not _append_choice(placements, chosen_type, true):
			return null

	# Só agora colocamos os 40 conteúdos em posições aleatórias.
	# Assim o mapa nunca fica parcialmente preenchido por um sorteio que falhou.
	var coordinates: Array[Vector2i] = []
	for y in HexGrid.PPP_MAP_HEIGHT:
		for x in HexGrid.PPP_MAP_WIDTH:
			coordinates.append(Vector2i(x, y))
	if placements.size() != coordinates.size():
		push_error("PPPMapGenerator: quantidade sorteada difere dos 40 hexágonos.")
		return null
	for index in range(coordinates.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var saved := coordinates[index]
		coordinates[index] = coordinates[other]
		coordinates[other] = saved
	if _difficulty == GameDifficulty.Mode.CHAOTIC:
		_ensure_chaotic_entry_resource(placements, coordinates)
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	for index in placements.size():
		var placement: Dictionary = placements[index]
		grid.set_ppp_block(
			coordinates[index],
			placement["type"],
			placement["resource"],
			placement["free"]
		)
	# Sorteado uma vez por MAPA, não em cada redesenho da janela. O nome dos
	# arquivos usa "baixocentro"; o distrito lógico usa "baixo_centro".
	grid.ppp_background_path = _draw_background_path(district)
	if grid.ppp_background_path.is_empty():
		push_error("PPPMapGenerator: não há cena de fundo para o distrito %s." % district)
		return null
	# Os 40 conteúdos já foram sorteados. Se algum hex contém um dos dois
	# Eventos de raio, o céu principal não pode ser cinzento neste mapa.
	# A reserva cinzenta da Áurea Fúnebre não é o céu principal: só aparece
	# caso aquela Catástrofe seja ativada durante a partida.
	var has_lightning_event := false
	for placement in placements:
		var event := placement["resource"] as EventData
		if event != null and event.id in LIGHTNING_EVENT_IDS:
			has_lightning_event = true
			break
	# O céu é sorteado uma vez por mapa. Vermelho/verde continuam sendo
	# apenas filtros visuais raros a partir do Dia 2.
	var sky := PPPParallaxBackground.choose_visuals(round_period, maxi(day, 1),
		_rng, not has_lightning_event)
	if sky.is_empty():
		return null
	grid.ppp_parallax_path = sky["path"]
	grid.ppp_aura_parallax_path = sky["aura_path"]
	grid.ppp_snow_parallax_path = sky["snow_path"]
	grid.ppp_parallax_filter = sky["filter"]
	return grid


func _placements_contain_type(placements: Array[Dictionary], block_type: int) -> bool:
	for placement in placements:
		if int(placement["type"]) == block_type:
			return true
	return false


func _draw_chaotic_counts() -> Dictionary:
	var counts := CHAOTIC_BASE_COUNTS.duplicate()
	var categories: Array[String] = ["consumable", "equipment", "encounter", "event"]
	# Quatro transferências entre categorias, sem alterar as 36 posições fixas.
	for _swap in 4:
		var donors: Array[String] = []
		for category in categories:
			if int(counts[category]) > int(CHAOTIC_MIN_COUNTS[category]):
				donors.append(category)
		var donor := donors[_rng.randi_range(0, donors.size() - 1)]
		var receivers: Array[String] = []
		for category in categories:
			if category != donor and int(counts[category]) < int(CHAOTIC_MAX_COUNTS[category]):
				receivers.append(category)
		if receivers.is_empty():
			continue
		var receiver := receivers[_rng.randi_range(0, receivers.size() - 1)]
		counts[donor] = int(counts[donor]) - 1
		counts[receiver] = int(counts[receiver]) + 1
	return counts


func _ensure_chaotic_entry_resource(placements: Array[Dictionary],
		coordinates: Array[Vector2i]) -> void:
	# Só evita uma borda inicial sem qualquer item. Não olha a valência dos Eventos.
	var entry_indices: Array[int] = []
	var item_indices: Array[int] = []
	for index in placements.size():
		var block_type := int(placements[index]["type"])
		if block_type in [HexGrid.PPPBlockType.CONSUMABLE,
				HexGrid.PPPBlockType.EQUIPMENT]:
			item_indices.append(index)
			if coordinates[index].x == 0:
				return
		if coordinates[index].x == 0:
			entry_indices.append(index)
	if entry_indices.is_empty() or item_indices.is_empty():
		return
	var entry := entry_indices[_rng.randi_range(0, entry_indices.size() - 1)]
	var item := item_indices[_rng.randi_range(0, item_indices.size() - 1)]
	var saved := coordinates[entry]
	coordinates[entry] = coordinates[item]
	coordinates[item] = saved


func _draw_background_path(district: StringName) -> String:
	var prefix := "cena_%s_" % str(district).replace("_", "")
	var filenames: Array[String] = []
	for filename in DirAccess.get_files_at(BACKGROUND_DIRECTORY):
		if filename.begins_with(prefix) and filename.ends_with(".png"):
			filenames.append(filename)
	filenames.sort()
	if filenames.is_empty():
		return ""
	return BACKGROUND_DIRECTORY.path_join(filenames[_rng.randi_range(0, filenames.size() - 1)])


func _quotas_are_valid() -> bool:
	var counts := [INFORMATION_COUNT, _consumable_count(), _equipment_count(),
		_encounter_count(), FREE_BLOCK_COUNT]
	if _difficulty == GameDifficulty.Mode.CHAOTIC:
		counts.append(_chaotic_event_count())
		for category in CHAOTIC_BASE_COUNTS:
			if int(_chaotic_counts.get(category, -1)) < int(CHAOTIC_MIN_COUNTS[category]) \
					or int(_chaotic_counts.get(category, -1)) > int(CHAOTIC_MAX_COUNTS[category]):
				return false
	else:
		counts.append_array([_good_event_count(), AMBIGUOUS_EVENT_COUNT,
			_bad_event_count()])
	var total := 0
	for count in counts:
		if count < 0:
			return false
		total += count
	return (
		total == HexGrid.PPP_MAP_WIDTH * HexGrid.PPP_MAP_HEIGHT
		and FREE_BLOCK_COUNT <= FREE_TYPES.size()
		and MAX_ENCOUNTER_COPIES_PER_MAP > 0
		and MAX_ITEM_COPIES_PER_MAP > 0
		and MAX_CURSE_COPIES_PER_MAP > 0
	)


func _consumable_count() -> int:
	if _difficulty == GameDifficulty.Mode.CHAOTIC:
		return int(_chaotic_counts["consumable"])
	return CONSUMABLE_COUNT + 2 if _difficulty == GameDifficulty.Mode.SUGAR else CONSUMABLE_COUNT


func _equipment_count() -> int:
	return int(_chaotic_counts["equipment"]) if _difficulty == GameDifficulty.Mode.CHAOTIC \
		else EQUIPMENT_COUNT


func _encounter_count() -> int:
	if _difficulty == GameDifficulty.Mode.CHAOTIC:
		return int(_chaotic_counts["encounter"])
	return ENCOUNTER_COUNT - 2 if _difficulty == GameDifficulty.Mode.SUGAR else ENCOUNTER_COUNT


func _chaotic_event_count() -> int:
	return int(_chaotic_counts["event"])


func _good_event_count() -> int:
	return GOOD_EVENT_COUNT + 1 if _difficulty == GameDifficulty.Mode.SUGAR else GOOD_EVENT_COUNT


func _bad_event_count() -> int:
	return BAD_EVENT_COUNT - 1 if _difficulty == GameDifficulty.Mode.SUGAR else BAD_EVENT_COUNT


func _draw_free_type(available: Array[int]) -> int:
	if _difficulty != GameDifficulty.Mode.SUGAR:
		return available[_rng.randi_range(0, available.size() - 1)]
	# O tipo continua sem repetição. Só o sorteio do modo fácil favorece
	# Informações, itens e Eventos; no Padrão todos conservam peso 1.
	var weights := {
		HexGrid.PPPBlockType.INFORMATION: 2,
		HexGrid.PPPBlockType.CONSUMABLE: 4,
		HexGrid.PPPBlockType.EQUIPMENT: 3,
		HexGrid.PPPBlockType.EVENT: 3,
	}
	var total := 0
	for block_type in available:
		total += int(weights.get(block_type, 1))
	var ticket := _rng.randi_range(1, total)
	for block_type in available:
		ticket -= int(weights.get(block_type, 1))
		if ticket <= 0:
			return block_type
	return available.back()


func _build_pools(
		information: Array[Resource],
		district: StringName,
		round_period: RoundPeriod,
) -> Dictionary:
	var result: Dictionary = {}
	result[HexGrid.PPPBlockType.INFORMATION] = _saved_resources(information)
	var encounter_pool: Array[EncounterData] = []
	for candidate in _load_folder("res://resources/encounters", true):
		var encounter := candidate as EncounterData
		if encounter == null:
			push_warning("PPPMapGenerator: Resource não é EncounterData: %s" % candidate.resource_path)
			continue
		if not encounter.has_valid_composition():
			push_warning("PPPMapGenerator: EncounterData incompleto: %s" % candidate.resource_path)
			continue
		if encounter.unique_encounter and encounter.id == &"":
			push_warning("PPPMapGenerator: encontro único sem ID: %s" % candidate.resource_path)
			continue
		if encounter.can_appear_in(district, round_period == RoundPeriod.NIGHT):
			encounter_pool.append(encounter)
	result[HexGrid.PPPBlockType.ENCOUNTER] = encounter_pool

	result[HexGrid.PPPBlockType.CONSUMABLE] = _map_items(
		_load_folder("res://resources/itens/consumables", false), ItemData.ItemType.CONSUMABLE
	)
	result[HexGrid.PPPBlockType.EQUIPMENT] = _map_items(
		_load_folder("res://resources/itens/equipments", true), ItemData.ItemType.EQUIPMENT
	)
	result[HexGrid.PPPBlockType.CURSE] = _map_items(
		_load_folder("res://resources/itens/curseds", false), ItemData.ItemType.CURSED
	)

	var events: Array[Resource] = []
	events.append_array(_load_folder("res://resources/events/random_events", false))
	events.append_array(_load_folder("res://resources/events/permanent_effects", false))
	events.append_array(_load_folder("res://resources/events/catastrophes", false))
	events.append_array(_load_folder("res://resources/events/traps", false))
	result[HexGrid.PPPBlockType.EVENT] = _events_of_category(
		events, [EventData.EventCategory.RANDOM_EVENT, EventData.EventCategory.PERMANENT_EFFECT]
	)
	result[HexGrid.PPPBlockType.CATASTROPHE] = _events_of_category(
		events, [EventData.EventCategory.CATASTROPHE]
	)
	result[HexGrid.PPPBlockType.TRAP] = _events_of_category(
		events, [EventData.EventCategory.TRAP]
	)
	# Os 12 sorteios de valência usam todos: 75 eventos + 5 Armadilhas.
	result["all_events"] = _events_of_category(events, [
		EventData.EventCategory.RANDOM_EVENT,
		EventData.EventCategory.PERMANENT_EFFECT,
		EventData.EventCategory.CATASTROPHE,
		EventData.EventCategory.TRAP,
	])
	return result


func _fixed_pools_are_available() -> bool:
	var required_counts := {
		HexGrid.PPPBlockType.INFORMATION: INFORMATION_COUNT,
		HexGrid.PPPBlockType.CONSUMABLE: _consumable_count(),
		HexGrid.PPPBlockType.EQUIPMENT: _equipment_count(),
		HexGrid.PPPBlockType.ENCOUNTER: _encounter_count(),
	}
	for block_type in required_counts:
		if _remaining_capacity(block_type) < required_counts[block_type]:
			push_error("PPPMapGenerator: faltam Resources diferentes para preencher %d blocos do tipo %d sem ultrapassar o limite por mapa." % [required_counts[block_type], block_type])
			return false
	if _difficulty == GameDifficulty.Mode.CHAOTIC:
		var required_events := _chaotic_event_count() - int(_force_replacement_ally)
		_release_oldest_chaotic_standby_events_if_needed(required_events)
		if _event_candidates(_pools["all_events"]).size() < required_events:
			push_error("PPPMapGenerator: faltam Eventos únicos elegíveis para os blocos caóticos.")
			return false
		return true
	var valence_counts := {
		EventData.Valence.GOOD: _good_event_count() - int(_force_replacement_ally),
		EventData.Valence.AMBIGUOUS: AMBIGUOUS_EVENT_COUNT,
		EventData.Valence.BAD: _bad_event_count(),
	}
	_release_oldest_standby_events_if_needed(valence_counts)
	for valence in valence_counts:
		if _event_candidates(_pools["all_events"], valence).size() < valence_counts[valence]:
			push_error("PPPMapGenerator: faltam Eventos únicos para %d blocos da valência %d." % [valence_counts[valence], valence])
			return false
	return true


func _release_oldest_chaotic_standby_events_if_needed(required: int) -> void:
	var all_events: Array[Resource] = _pools["all_events"]
	while _event_candidates(all_events).size() < required:
		var oldest_eligible_path := ""
		for path in _standby_oldest_first:
			if not _events_on_standby.has(path):
				continue
			for resource in all_events:
				var event := resource as EventData
				if event != null and event.resource_path == path \
						and _event_is_campaign_eligible(event):
					oldest_eligible_path = path
					break
			if not oldest_eligible_path.is_empty():
				break
		if oldest_eligible_path.is_empty():
			return
		_events_on_standby.erase(oldest_eligible_path)


## Só afrouxa o standby quando os Eventos disponíveis não bastam para os
## blocos fixos. Libera o mais antigo DA VALÊNCIA em falta, um por vez.
## Regras permanentes (evento único/limite da campanha) continuam valendo.
func _release_oldest_standby_events_if_needed(required: Dictionary) -> void:
	var all_events: Array[Resource] = _pools["all_events"]
	while true:
		var deficient_valences: Dictionary = {}
		for valence in required:
			if _event_candidates(all_events, valence).size() < required[valence]:
				deficient_valences[valence] = true
		if deficient_valences.is_empty():
			return
		var oldest_eligible_path := ""
		for path in _standby_oldest_first:
			if not _events_on_standby.has(path):
				continue
			for resource in all_events:
				var event := resource as EventData
				if event != null and event.resource_path == path \
						and deficient_valences.has(event.valence) \
						and _event_is_campaign_eligible(event):
					oldest_eligible_path = path
					break
			if not oldest_eligible_path.is_empty():
				break
		if oldest_eligible_path.is_empty():
			return # Faltam Resources por outro motivo; o erro aparece no chamador.
		_events_on_standby.erase(oldest_eligible_path)


func _remaining_capacity(block_type: int) -> int:
	var capacity := 0
	var counted: Dictionary = {}
	if block_type == HexGrid.PPPBlockType.INFORMATION:
		for item in _pools[block_type]:
			if not _information_used.has(item.resource_path):
				counted[item.resource_path] = true
		return counted.size()
	if block_type == HexGrid.PPPBlockType.ENCOUNTER:
		var encounters: Array[EncounterData] = _pools[block_type]
		for encounter in _encounter_candidates(encounters):
			if counted.has(encounter.resource_path):
				continue
			counted[encounter.resource_path] = true
			var encounter_limit := 1 if encounter.unique_encounter else MAX_ENCOUNTER_COPIES_PER_MAP
			capacity += encounter_limit - int(_encounter_placements.get(encounter.resource_path, 0))
		return capacity
	var items: Array[Resource] = _pools[block_type]
	var item_limit := _item_limit(block_type)
	for item in _item_candidates(items, item_limit):
		if counted.has(item.resource_path):
			continue
		counted[item.resource_path] = true
		capacity += item_limit - int(_item_placements.get(item.resource_path, 0))
	return capacity


func _append_choice(placements: Array[Dictionary], block_type: int, is_free: bool) -> bool:
	var chosen: Resource = null
	if block_type == HexGrid.PPPBlockType.EVENT or block_type == HexGrid.PPPBlockType.CATASTROPHE or block_type == HexGrid.PPPBlockType.TRAP:
		var favor_good := _difficulty == GameDifficulty.Mode.SUGAR and is_free \
			and block_type == HexGrid.PPPBlockType.EVENT and _rng.randf() < 0.70 \
			and not _event_candidates(_pools[block_type], EventData.Valence.GOOD).is_empty()
		chosen = _draw_event(_pools[block_type], EventData.Valence.GOOD if favor_good else -1)
	elif block_type == HexGrid.PPPBlockType.INFORMATION:
		var available: Array[Resource] = []
		for item in _pools[block_type]:
			if not _information_used.has(item.resource_path):
				available.append(item)
		chosen = _draw_uniform(available)
		if chosen != null:
			_information_used[chosen.resource_path] = true
	elif block_type == HexGrid.PPPBlockType.ENCOUNTER:
		var encounters: Array[EncounterData] = _pools[block_type]
		chosen = _draw_encounter(encounters)
	elif block_type in [HexGrid.PPPBlockType.CONSUMABLE, HexGrid.PPPBlockType.EQUIPMENT, HexGrid.PPPBlockType.CURSE]:
		if block_type == HexGrid.PPPBlockType.CURSE and _hazards_placed >= _hazard_budget:
			return false
		var items: Array[Resource] = _pools[block_type]
		chosen = _draw_item(items, _item_limit(block_type))
		if chosen != null and block_type == HexGrid.PPPBlockType.CURSE:
			_hazards_placed += 1
	else:
		chosen = _draw_uniform(_pools[block_type])
	if chosen == null:
		push_error("PPPMapGenerator: não foi possível sortear Resource para tipo %d." % block_type)
		return false
	placements.append({"type": block_type, "resource": chosen, "free": is_free})
	return true


func _append_event_choice(placements: Array[Dictionary], valence: int, is_free: bool) -> bool:
	var chosen: EventData = _draw_event(_pools["all_events"], valence) as EventData
	if chosen == null:
		push_error("PPPMapGenerator: faltou Evento da valência %d." % valence)
		return false
	placements.append({"type": _type_for_event(chosen), "resource": chosen, "free": is_free})
	return true


func _can_draw(block_type: int) -> bool:
	if block_type == HexGrid.PPPBlockType.CURSE and _hazards_placed >= _hazard_budget:
		return false
	if block_type == HexGrid.PPPBlockType.INFORMATION:
		for item in _pools[block_type]:
			if not _information_used.has(item.resource_path):
				return true
		return false
	if block_type in [HexGrid.PPPBlockType.EVENT, HexGrid.PPPBlockType.CATASTROPHE, HexGrid.PPPBlockType.TRAP]:
		return not _event_candidates(_pools[block_type]).is_empty()
	if block_type == HexGrid.PPPBlockType.ENCOUNTER:
		var encounters: Array[EncounterData] = _pools[block_type]
		return not _encounter_candidates(encounters).is_empty()
	if block_type in [HexGrid.PPPBlockType.CONSUMABLE, HexGrid.PPPBlockType.EQUIPMENT, HexGrid.PPPBlockType.CURSE]:
		var items: Array[Resource] = _pools[block_type]
		return not _item_candidates(items, _item_limit(block_type)).is_empty()
	return not _pools[block_type].is_empty()


func _event_candidates(pool: Array[Resource], valence: int = -1) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in pool:
		var event := item as EventData
		if event == null:
			continue
		if valence >= 0 and event.valence != valence:
			continue
		if _events_on_standby.has(event.resource_path):
			continue
		if _event_is_campaign_eligible(event):
			result.append(event)
	return result


func _event_is_campaign_eligible(event: EventData) -> bool:
	if not EventCampaignEligibility.allows_event(event, _campaign_mode):
		return false
	if event.category == EventData.EventCategory.TRAP and not _allow_traps:
		return false
	if event.category == EventData.EventCategory.CATASTROPHE and not _allow_catastrophes:
		return false
	if event.category in [EventData.EventCategory.TRAP,
			EventData.EventCategory.CATASTROPHE] and _hazards_placed >= _hazard_budget:
		return false
	var placed: int = _event_placements.get(event.resource_path, 0)
	var previous: int = _event_campaign_counts.get(event.resource_path, 0)
	# Mesmo um Evento repetível na campanha só pode aparecer uma vez neste mapa.
	return (not event.requires_completed_encounter or _has_completed_encounter_history) \
		and placed == 0 \
		and (event.can_repeat or previous == 0) \
		and (event.max_times_per_campaign == 0 or previous < event.max_times_per_campaign)


func _draw_event(pool: Array[Resource], valence: int = -1) -> Resource:
	var candidates := _event_candidates(pool, valence)
	if candidates.is_empty():
		return null
	var total_weight := 0
	for item in candidates:
		var event := item as EventData
		total_weight += maxi(1, event.selection_weight)
	var ticket := _rng.randi_range(1, total_weight)
	for item in candidates:
		var event := item as EventData
		ticket -= maxi(1, event.selection_weight)
		if ticket <= 0:
			_event_placements[event.resource_path] = _event_placements.get(event.resource_path, 0) + 1
			if event.category in [EventData.EventCategory.TRAP,
					EventData.EventCategory.CATASTROPHE]:
				_hazards_placed += 1
			return event
	return null


func _draw_uniform(pool: Array[Resource]) -> Resource:
	return pool[_rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


func _item_limit(block_type: int) -> int:
	return MAX_CURSE_COPIES_PER_MAP if block_type == HexGrid.PPPBlockType.CURSE else MAX_ITEM_COPIES_PER_MAP


func _item_candidates(pool: Array[Resource], limit: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for candidate in pool:
		var item := candidate as ItemData
		if item == null:
			continue
		if int(_item_placements.get(item.resource_path, 0)) < limit:
			result.append(item)
	return result


func _draw_item(pool: Array[Resource], limit: int) -> Resource:
	var candidates := _item_candidates(pool, limit)
	if candidates.is_empty():
		return null
	# Um item ainda não sorteado tem mais chances, mas repetir até o limite pode.
	var total_weight := 0
	for item in candidates:
		total_weight += limit - int(_item_placements.get(item.resource_path, 0))
	var ticket := _rng.randi_range(1, total_weight)
	for item in candidates:
		ticket -= limit - int(_item_placements.get(item.resource_path, 0))
		if ticket <= 0:
			_item_placements[item.resource_path] = int(_item_placements.get(item.resource_path, 0)) + 1
			return item
	return null


func _encounter_candidates(pool: Array[EncounterData]) -> Array[EncounterData]:
	var result: Array[EncounterData] = []
	for encounter in pool:
		var placed: int = _encounter_placements.get(encounter.resource_path, 0)
		var limit := 1 if encounter.unique_encounter else MAX_ENCOUNTER_COPIES_PER_MAP
		if placed >= limit:
			continue
		if encounter.unique_encounter and _occurred_encounter_ids.has(encounter.id):
			continue
		result.append(encounter)
	return result


func _draw_encounter(pool: Array[EncounterData]) -> EncounterData:
	var candidates := _encounter_candidates(pool)
	if candidates.is_empty():
		return null
	var total_weight := 0
	for encounter in candidates:
		var candidate_limit := 1 if encounter.unique_encounter else MAX_ENCOUNTER_COPIES_PER_MAP
		var placed: int = _encounter_placements.get(encounter.resource_path, 0)
		total_weight += maxi(1, encounter.selection_weight) * (candidate_limit - placed)
	var ticket := _rng.randi_range(1, total_weight)
	for encounter in candidates:
		var draw_limit := 1 if encounter.unique_encounter else MAX_ENCOUNTER_COPIES_PER_MAP
		var draw_placed: int = _encounter_placements.get(encounter.resource_path, 0)
		ticket -= maxi(1, encounter.selection_weight) * (draw_limit - draw_placed)
		if ticket <= 0:
			_encounter_placements[encounter.resource_path] = draw_placed + 1
			return encounter
	return null


func _type_for_event(event: EventData) -> int:
	if event.category == EventData.EventCategory.CATASTROPHE:
		return HexGrid.PPPBlockType.CATASTROPHE
	if event.category == EventData.EventCategory.TRAP:
		return HexGrid.PPPBlockType.TRAP
	return HexGrid.PPPBlockType.EVENT


func _saved_resources(input: Array[Resource]) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in input:
		if item != null and not item.resource_path.is_empty():
			result.append(item)
	return result


func _map_items(input: Array[Resource], item_type: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in input:
		var map_item := item as ItemData
		if map_item != null and map_item.item_type == item_type:
			# Raros são permitidos se o próprio ItemData marcar MAP_BLOCK.
			if (map_item.acquisition_sources & ItemData.AcquisitionSource.MAP_BLOCK) != 0:
				result.append(map_item)
	return result


func _events_of_category(input: Array[Resource], categories: Array) -> Array[Resource]:
	var result: Array[Resource] = []
	for item in input:
		var event := item as EventData
		if event != null and event.category in categories:
			result.append(event)
	return result


func _load_folder(folder: String, recursive: bool) -> Array[Resource]:
	var result: Array[Resource] = []
	var entries := ResourceLoader.list_directory(folder)
	entries.sort() # Sorteio com seed fixa deve produzir a mesma sequência.
	for entry in entries:
		if entry.ends_with("/"):
			if recursive:
				result.append_array(_load_folder(folder.path_join(entry.substr(0, entry.length() - 1)), true))
		elif entry.ends_with(".tres"):
			var loaded := ResourceLoader.load(folder.path_join(entry))
			if loaded != null:
				result.append(loaded)
	return result
