class_name CampaignState
extends RefCounted

## Dados que mudam durante UMA campanha. Os arquivos .tres continuam sendo
## cadastros; nunca alteramos um EntityData ou EncounterData para guardar
## Vida atual, Informação obtida ou algo que aconteceu na partida.

const SCHEMA_VERSION := 1
const ALL_ENDING_IDS := InformationCampaignEligibility.ENDING_IDS
const INFORMATION_PER_ENDING := 5
enum CampaignStatus { NOT_STARTED, ACTIVE, VICTORY, DEFEAT }

# Metadados da campanha, não cópias do mapa, combate ou inventários. O ID é
# criado uma vez por partida e será persistido com o estado no Pool 4.
var campaign_id: String = ""
var schema_version: int = SCHEMA_VERSION
var campaign_status: int = CampaignStatus.NOT_STARTED
signal campaign_terminal_changed(status: int, information_count: int)
signal journal_entry_added(entry: Dictionary)
## Histórico factual desta linha de campanha. Cada entrada usa apenas tipos
## serializáveis; o Pool 4 guardará a sequência junto ao snapshot de cada slot.
var journal_entries: Array[Dictionary] = []
var next_journal_serial: int = 1
var day: int = 1
## Convite visto uma vez por campanha; o atalho do Dia 1 pode ser dispensado.
var tutorial_invitation_seen: bool = false
var tutorial_day_one_shortcut_dismissed: bool = false
var tutorial_shortcut_y_ratio: float = 0.66
var tutorial_shortcut_collapsed: bool = false
# Evento 32: o templo anula itens amaldiçoados somente no Dia da visita.
var sacred_temple_blessing_day: int = 0
# Valor provisório seguro até a seleção de modo/desfechos do próximo item.
var campaign_mode: int = EventCampaignEligibility.Mode.COMPLETE
var difficulty: int = GameDifficulty.Mode.STANDARD
# -1: sem troca agendada. Uma seleção durante a partida vale só na próxima
# Rodada, inclusive depois de salvar/carregar no meio do Combate.
var pending_difficulty: int = -1
var active_ending_ids: Array[StringName] = []
var round_period: int = PPPMapGenerator.RoundPeriod.MORNING
var district: StringName = &"suburbio"
var current_map: HexGrid
var generated_map_count: int = 0
## Escalonamento da chance ambiental; persiste no save da campanha.
var anomaly_reset_day: int = 2
var anomaly_high_tier_misses: int = 0
var galiform_transformation_seen: bool = false
## A introdução do último mapa é persistida; pending permite retomá-la após carregar.
var final_center_intro_seen: bool = false
var final_center_intro_pending: bool = false
# Instâncias temporárias de catástrofe; os EventData/.tres são apenas cadastro.
# Cada entrada conserva o Dia/Rodada de início e os alvos já afetados.
var active_catastrophes: Array[Dictionary] = []
signal temporary_event_changed
signal solo_exploration_ended
# Instâncias e prazos dos Eventos aleatórios; nenhum .tres é alterado.
var temporary_event_effects: Array[Dictionary] = []
var solo_owner_id: StringName = &""
var solo_turns_remaining: int = 0
var solo_applied_turn_serial: int = -1
var solo_saved_positions: Dictionary = {}
var solo_saved_encounters: Dictionary = {} # coord -> conteúdo/estado original e resultado temporário
var solo_map: HexGrid
# Estas duas catástrofes duram até a virada. A última ativada decide APENAS
# qual céu aparece; os efeitos de jogo das duas podem coexistir.
const AURA_FUNEBRE_EVENT_ID := &"ev_00075"
const NEVASCA_EVENT_ID := &"ev_00072"
const PORTAIS_INFERNAIS_EVENT_ID := &"ev_00074"
var aura_funebre_day: int = 0
var nevasca_day: int = 0
var visual_weather_event_id: StringName = &""
var visual_weather_day: int = 0
# Portais Infernais dura uma Rodada, não o Dia inteiro.
var infernal_portals_round_index: int = -1
# A sorte é de quem JOGA, não de um EntityData específico. Compartilha a
# sequência entre Playable_1/2/3 e sobrevive à geração de novos mapas.
var player_dice_luck: D6Roller = D6Roller.new()
# Também há uma sequência única para TODOS os inimigos da campanha. Ela não
# se mistura com a sequência do jogador.
var enemy_dice_luck: D6Roller = D6Roller.new()
# Sorteios gerais que continuam após carregar a campanha.
var world_rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Um evento ativado ou impedido por uma Skill não pode voltar nos três
# sorteios de Rodada seguintes.
# Um Portal que gere outro mapa na mesma Rodada também respeita a espera.
const EVENT_STANDBY_ROUNDS := 3

# As vagas existem na partida; cada uma recebe o EntityData escolhido pelo
# jogador. Elas não correspondem permanentemente a um dos sete personagens.
const PLAYABLE_SLOTS := [&"Playable_1", &"Playable_2", &"Playable_3"]
const PLAYABLE_DIRECTORY := "res://resources/entities/entities_playable"
var active_entity_states: Array[EntityState] = []
var dead_playable_states: Array[EntityState] = []
# Evento 26: snapshot das identidades visuais para desfazer exatamente a
# primeira permutação, sem trocar EntityData nem estado de jogo.
var visual_swap_originals: Dictionary = {}
signal playable_death_finalized(actor: EntityState, leftover: Array[InventoryItemState])
signal playable_slot_replaced(previous: EntityState, replacement: EntityState)
# Companheiros continuam sendo entidades; apenas não ocupam uma das 3 vagas.
var companion_states: Array[EntityState] = []
signal companion_registered(companion: EntityState)
var _resurrecting_companion: EntityState # Contexto transitório do sinal; não é progresso salvo.
signal wooden_doll_changed(owner_id: StringName, present: bool)
var wooden_dolls_by_owner: Dictionary = {} # owner_instance_id -> bonecos disponíveis
var next_companion_serial: int = 1
var next_event_grant_serial: int = 1
var delayed_skill_effects: Array[DelayedSkillEffectState] = []
# Impede reaplicar passivas da mesma virada se a interface pedir a transição
# duas vezes. Ao mudar day, a nova virada volta a ser válida.
var last_processed_day_start: int = -1
# A mesma Rodada não dispara duas vezes os efeitos de início, mesmo que um
# Portal gere outro mapa sem mudar o horário.
var last_processed_round_start: int = -1

# As chaves são IDs de Informacao; o valor true significa "já foi obtida".
var obtained_information_ids: Dictionary = {}
## Ordem de obtenção usada por Eventos que apagam a última Informação.
var obtained_information_order: Array[StringName] = []
## Efeitos limitados a uma ocorrência por personagem (ex.: Testemunha Ocular).
var event_effects_applied_by_actor: Dictionary = {}
# A chave é o resource_path do EventData; conta mapas em que ele foi gerado.
var event_campaign_counts: Dictionary = {}
# resource_path do EventData -> índice da Rodada em que foi ativado ou impedido.
# Gerar o evento em um mapa NÃO coloca o evento em espera.
var event_last_handled_round: Dictionary = {}
# Apenas Encontros únicos que realmente aconteceram entram nesta lista.
var occurred_unique_encounter_ids: Array[StringName] = []
# Itens marcados como não recriáveis deixam de ser opções de fabricação
# depois que sua cópia é sacrificada nesta campanha.
var consumed_uncraftable_item_ids: Dictionary = {}
# Apenas tipos encontrados no último Combate concluído. Mutação Genética
# apresenta esta lista para o jogador; não escolhe um inimigo aleatório.
var last_encounter_entity_types: Array[EntityData] = []
var completed_encounter_entity_counts: Dictionary = {} # EntityData.id -> número anterior

# Revelar um hex não altera isto. Só obter uma Informação do mapa atual.
var information_obtained_on_current_map: bool = false


func _init() -> void:
	active_ending_ids.assign(ALL_ENDING_IDS)


func has_sacred_temple_blessing() -> bool:
	return sacred_temple_blessing_day > 0 and sacred_temple_blessing_day == day


static func is_cursed_item(item: ItemData) -> bool:
	return item != null and (item.item_type == ItemData.ItemType.CURSED \
		or &"cursed" in item.tags)


func request_difficulty(mode: int) -> bool:
	if campaign_status != CampaignStatus.ACTIVE or not GameDifficulty.is_available(mode):
		return false
	pending_difficulty = -1 if mode == difficulty else mode
	return true


func difficulty_for_next_round() -> int:
	return pending_difficulty if GameDifficulty.is_available(pending_difficulty) else difficulty


func commit_pending_difficulty() -> void:
	if GameDifficulty.is_available(pending_difficulty):
		difficulty = pending_difficulty
	pending_difficulty = -1


func has_carried_curse() -> bool:
	for actor in active_entity_states + companion_states:
		if actor == null or actor.current_health <= 0:
			continue
		for entries in [actor.inventory_items, actor.equipped_weapons,
				actor.equipped_armors, actor.equipped_accessories]:
			for entry in entries:
				if entry != null and entry.data != null \
						and entry.data.item_type == ItemData.ItemType.CURSED:
					return true
	return false


func has_catastrophe_at(target_day: int, target_round_index: int) -> bool:
	for record in active_catastrophes:
		var survives := true
		for effect in record.get("effects", []):
			if effect == null:
				continue
			if effect.expiration_mode == Event_EffectData.ExpirationMode.END_OF_CURRENT_DAY \
					and target_day != int(record.get("day", -1)):
				survives = false
			if effect.expiration_mode == Event_EffectData.ExpirationMode.END_OF_CURRENT_ROUND \
					and target_round_index != int(record.get("round_index", -1)):
				survives = false
		if survives:
			return true
	return false


func has_active_ending(ending_id: StringName) -> bool:
	return ending_id in active_ending_ids


## Consulta de domínio única, disponível a gerador, eventos e recompensas.
func is_information_eligible(information_id: StringName = &"",
		information_type: int = -1) -> bool:
	return InformationCampaignEligibility.is_eligible(
		active_ending_ids, information_id, information_type)


func information_goal() -> int:
	match campaign_mode:
		EventCampaignEligibility.Mode.SHORT:
			return 5
		EventCampaignEligibility.Mode.MEDIUM:
			return 10
		EventCampaignEligibility.Mode.COMPLETE:
			# A campanha completa incorpora todos os desfechos cadastrados ao
			# começar; a meta acompanha o conjunto guardado nessa campanha.
			return active_ending_ids.size() * INFORMATION_PER_ENDING
	return 0


func requires_final_center_map() -> bool:
	return campaign_status == CampaignStatus.ACTIVE \
		and campaign_mode == EventCampaignEligibility.Mode.COMPLETE \
		and obtained_information_ids.size() == information_goal() - 1


func allows_free_information_on_next_map() -> bool:
	# O mapa que pode conceder a penúltima parte não deve antecipar a última
	# pelo hex livre. Eventos, acessórios e outros bônus continuam válidos.
	return campaign_mode != EventCampaignEligibility.Mode.COMPLETE \
		or obtained_information_ids.size() < information_goal() - 2


func is_terminal() -> bool:
	return campaign_status in [CampaignStatus.VICTORY, CampaignStatus.DEFEAT]


## Registra o resultado uma só vez. A UI e os controladores podem observar o
## sinal sem duplicar a decisão de vitória/derrota.
func mark_terminal(result: int) -> bool:
	if campaign_status != CampaignStatus.ACTIVE or result not in [
			CampaignStatus.VICTORY, CampaignStatus.DEFEAT]:
		return false
	campaign_status = result
	campaign_terminal_changed.emit(result, obtained_information_ids.size())
	return true


func _new_campaign_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4),
		hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


func swap_playable_visuals(reverse_on_repeat: bool = true) -> Dictionary:
	if reverse_on_repeat and not visual_swap_originals.is_empty():
		var restored: Array[String] = []
		for actor in visual_swap_originals:
			if actor is EntityState:
				(actor as EntityState).set_visual_identity(visual_swap_originals[actor])
				restored.append((actor as EntityState).visible_name())
		visual_swap_originals.clear()
		return {"success": true, "reversed": true, "names": restored}
	var participants: Array[EntityState] = []
	for actor in active_entity_states:
		if actor != null and actor.current_health > 0 and actor.data != null:
			participants.append(actor)
	if participants.size() < 2:
		return {"success": false,
			"reason": "A troca exige ao menos dois jogáveis vivos."}
	var original_visuals: Array[EntityData] = []
	for actor in participants:
		visual_swap_originals[actor] = actor.visual_data()
		original_visuals.append(actor.visual_data())
	var names: Array[String] = []
	for index in participants.size():
		# Rotação à direita: o visual do último vai ao primeiro, e assim por diante.
		participants[index].set_visual_identity(original_visuals[
			(index - 1 + participants.size()) % participants.size()])
		names.append(participants[index].visible_name())
	return {"success": true, "reversed": false, "names": names}


## A futura tela de seleção lê este catálogo. Novos .tres jogáveis entram sem
## mudar a lista de vagas nem cadastrar seus nomes em código.
func get_playable_catalog() -> Array[EntityData]:
	var catalog: Array[EntityData] = []
	var filenames := DirAccess.get_files_at(PLAYABLE_DIRECTORY)
	filenames.sort()
	for filename in filenames:
		if not filename.ends_with(".tres"):
			continue
		var candidate := load(PLAYABLE_DIRECTORY.path_join(filename)) as EntityData
		if candidate != null and candidate.id != &"" and &"jogavel" in candidate.tags:
			catalog.append(candidate)
	return catalog


## Os personagens NÃO escolhidos são candidatos para "Um Aliado" (evento 65).
## O executor ainda deverá excluir quem já estiver presente no grupo, como o
## próprio EventEffectData desse evento determina.
func get_unselected_playable_allies() -> Array[EntityData]:
	var selected_ids: Dictionary = {}
	for state in active_entity_states:
		selected_ids[state.data.id] = true
	for state in companion_states:
		if state.data != null:
			selected_ids[state.data.id] = true
	for state in dead_playable_states:
		if state != null and state.data != null:
			selected_ids[state.data.id] = true
	var candidates: Array[EntityData] = []
	for candidate in get_playable_catalog():
		if not selected_ids.has(candidate.id):
			candidates.append(candidate)
	return candidates


## A tela passa três Resources distintos, na ordem das vagas. Uma seleção
## inválida não apaga nem modifica uma partida que já estiver em andamento.
## Esta etapa monta a campanha; a geração do primeiro mapa vem depois.
func start_new_game(selected: Array[EntityData], initial_inventory_capacity: int = 12,
		rng: RandomNumberGenerator = null,
		mode: int = EventCampaignEligibility.Mode.COMPLETE,
		ending_ids: Array[StringName] = [],
		chosen_difficulty: int = GameDifficulty.Mode.STANDARD) -> bool:
	if not GameDifficulty.is_available(chosen_difficulty):
		return false
	if selected.size() != PLAYABLE_SLOTS.size():
		push_warning("CampaignState: selecione exatamente três personagens jogáveis.")
		return false
	var seen_ids: Dictionary = {}
	for character in selected:
		if character == null or character.id == &"" or character.resource_path.is_empty():
			push_warning("CampaignState: personagem sem Resource salvo ou sem ID.")
			return false
		if &"jogavel" not in character.tags or seen_ids.has(character.id):
			push_warning("CampaignState: os três escolhidos devem ser jogáveis diferentes.")
			return false
		seen_ids[character.id] = true
	var chosen_endings := _resolve_active_endings(mode, ending_ids, rng)
	if chosen_endings.is_empty():
		push_warning("CampaignState: modo ou seleção de desfechos inválida.")
		return false
	var start_positions := HexGrid.new().get_ppp_start_positions()
	var new_states: Array[EntityState] = []
	for index in selected.size():
		var state := EntityState.from_playable_selection(
			selected[index], PLAYABLE_SLOTS[index], start_positions[index]
		)
		state.base_inventory_capacity = maxi(2, initial_inventory_capacity)
		new_states.append(state)
	_grant_starting_items(new_states, rng, mode, chosen_difficulty)
	for state in new_states:
		# A partida começa com a Estamina cheia, incluindo bônus do kit já
		# vestido. Equipar no meio da partida continua usando a regra normal.
		state.stamina_remaining = state.max_stamina
	campaign_id = _new_campaign_id()
	schema_version = SCHEMA_VERSION
	campaign_mode = mode
	difficulty = chosen_difficulty
	pending_difficulty = -1
	active_ending_ids = chosen_endings
	campaign_status = CampaignStatus.ACTIVE
	day = 1
	tutorial_invitation_seen = false
	tutorial_day_one_shortcut_dismissed = false
	tutorial_shortcut_y_ratio = 0.66
	tutorial_shortcut_collapsed = false
	round_period = PPPMapGenerator.RoundPeriod.MORNING
	district = &"suburbio"
	current_map = null
	generated_map_count = 0
	anomaly_reset_day = 2
	anomaly_high_tier_misses = 0
	galiform_transformation_seen = false
	final_center_intro_seen = false
	final_center_intro_pending = false
	active_catastrophes.clear()
	visual_swap_originals.clear()
	temporary_event_effects.clear()
	solo_owner_id = &""
	solo_turns_remaining = 0
	solo_applied_turn_serial = -1
	solo_saved_positions.clear()
	solo_saved_encounters.clear()
	solo_map = null
	aura_funebre_day = 0
	nevasca_day = 0
	sacred_temple_blessing_day = 0
	visual_weather_event_id = &""
	visual_weather_day = 0
	infernal_portals_round_index = -1
	player_dice_luck.reset()
	enemy_dice_luck.reset()
	world_rng.randomize()
	obtained_information_ids.clear()
	obtained_information_order.clear()
	journal_entries.clear()
	next_journal_serial = 1
	event_effects_applied_by_actor.clear()
	event_campaign_counts.clear()
	event_last_handled_round.clear()
	occurred_unique_encounter_ids.clear()
	last_encounter_entity_types.clear()
	completed_encounter_entity_counts.clear()
	information_obtained_on_current_map = false
	active_entity_states = new_states
	dead_playable_states.clear()
	companion_states.clear()
	wooden_dolls_by_owner.clear()
	next_companion_serial = 1
	next_event_grant_serial = 1
	delayed_skill_effects.clear()
	last_processed_day_start = -1
	last_processed_round_start = -1
	return true


## Registrar somente depois de uma ação resolvida. Segmentos permitem que a
## consulta pinte nomes/itens/resultados sem tentar inferi-los de texto solto.
func append_journal_entry(action_id: StringName, segments: Array,
		actor_id: StringName = &"", references: Dictionary = {}) -> Dictionary:
	if campaign_status == CampaignStatus.NOT_STARTED or segments.is_empty():
		return {}
	var clean_segments: Array[Dictionary] = []
	var plain_text := ""
	for value in segments:
		if not value is Dictionary:
			continue
		var segment := value as Dictionary
		var part := str(segment.get("text", ""))
		if part.is_empty():
			continue
		clean_segments.append({"text": part, "tone": str(segment.get("tone", "text"))})
		plain_text += part
	if plain_text.is_empty():
		return {}
	var entry := {
		"serial": next_journal_serial,
		"day": day,
		"period": round_period,
		"district": str(district),
		"round_index": get_round_index(),
		"actor_id": str(actor_id),
		"action_id": str(action_id),
		"text": plain_text,
		"segments": clean_segments,
		"references": references.duplicate(true),
	}
	next_journal_serial += 1
	journal_entries.append(entry)
	journal_entry_added.emit(entry)
	return entry


## A ausência de IDs em curta/média solicita um único sorteio uniforme, sem
## reposição. A UI não sorteia: o resultado fica guardado nesta campanha.
func _resolve_active_endings(mode: int, requested: Array[StringName],
		rng: RandomNumberGenerator) -> Array[StringName]:
	var result: Array[StringName] = []
	var count := 0
	match mode:
		EventCampaignEligibility.Mode.SHORT:
			count = 1
		EventCampaignEligibility.Mode.MEDIUM:
			count = 2
		EventCampaignEligibility.Mode.COMPLETE:
			count = ALL_ENDING_IDS.size()
		_:
			return result
	if mode == EventCampaignEligibility.Mode.COMPLETE:
		if not requested.is_empty():
			return result
		result.assign(ALL_ENDING_IDS)
		return result
	if not requested.is_empty():
		if requested.size() != count:
			return result
		for ending_id in requested:
			if ending_id not in ALL_ENDING_IDS or ending_id in result:
				result.clear()
				return result
			result.append(ending_id)
		return result
	var available: Array[StringName] = []
	available.assign(ALL_ENDING_IDS)
	var source := rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	while result.size() < count:
		result.append(available.pop_at(source.randi_range(0, available.size() - 1)))
	return result


func add_temporary_stamina_loss(target: EntityState, amount: int, turns: int) -> void:
	if target == null or amount <= 0 or turns <= 0:
		return
	var actual := mini(amount, target.max_stamina)
	target.max_stamina -= actual
	target.stamina_remaining = mini(target.stamina_remaining, target.max_stamina)
	var owner_turn_serial := -1
	if target in companion_states:
		var owner := get_playable_slot(target.owner_instance_id)
		if owner != null:
			owner_turn_serial = owner.turn_serial
	temporary_event_effects.append({"kind": &"stamina_loss", "target": target,
		"amount": actual, "remaining_turns": turns,
		"applied_serial": target.turn_serial,
		"applied_owner_serial": owner_turn_serial})
	temporary_event_changed.emit()


func add_ghost_pursuit(target: EntityState, damage: int) -> void:
	if target == null or damage <= 0:
		return
	temporary_event_effects.append({"kind": &"ghost_pursuit", "target": target,
		"damage": damage, "expires_day": day + 1})
	temporary_event_changed.emit()


func add_temporary_appearance(target: EntityState, appearance: StringName) -> void:
	if target == null:
		return
	target.temporary_appearance = appearance
	temporary_event_effects.append({"kind": &"appearance", "target": target,
		"appearance": appearance, "expires_round": get_round_index() + 1})
	temporary_event_changed.emit()


func add_imaginary_friend(target: EntityState) -> void:
	if target == null:
		return
	var expires_round := get_round_index() + 1
	for entry in temporary_event_effects:
		if entry.get("kind") == &"imaginary_friend" and entry.get("target") == target:
			entry["expires_round"] = expires_round
			temporary_event_changed.emit()
			return
	temporary_event_effects.append({"kind": &"imaginary_friend", "target": target,
		"expires_round": expires_round})
	temporary_event_changed.emit()


func has_imaginary_friend(target: EntityState) -> bool:
	if target == null:
		return false
	for entry in temporary_event_effects:
		if entry.get("kind") == &"imaginary_friend" and entry.get("target") == target \
				and get_round_index() < int(entry.get("expires_round", 0)):
			return true
	return false


func add_day_status_immunity(target: EntityState, status_id: StringName) -> void:
	if target == null or status_id == &"":
		return
	if status_id not in target.temporary_status_immunities:
		target.temporary_status_immunities.append(status_id)
	temporary_event_effects.append({"kind": &"status_immunity", "target": target,
		"status_id": status_id, "expires_day": day + 1})
	temporary_event_changed.emit()


func add_day_attribute_blessing(target: EntityState, statistic: StringName,
		amount: int) -> void:
	if target == null or amount <= 0:
		return
	if statistic == &"attack":
		target.attack += amount
	elif statistic == &"life":
		target.max_health += amount
		target.current_health += amount
	else:
		return
	temporary_event_effects.append({"kind": &"day_blessing", "target": target,
		"statistic": statistic, "amount": amount, "expires_day": day + 1})
	temporary_event_changed.emit()


func start_solo_exploration(owner: EntityState, turns: int) -> bool:
	if owner == null or owner not in active_entity_states or solo_turns_remaining > 0:
		return false
	solo_owner_id = owner.instance_id
	solo_turns_remaining = maxi(1, turns)
	solo_applied_turn_serial = owner.turn_serial
	solo_saved_positions.clear()
	solo_map = current_map
	solo_saved_encounters.clear()
	_replace_solo_encounters()
	for member in active_entity_states + companion_states:
		if member == null or member == owner or member.current_health <= 0:
			continue
		solo_saved_positions[member.instance_id] = member.position
		member.temporarily_absent_from_map = true
	temporary_event_changed.emit()
	return true


## Metade dos Encontros vira item; a outra metade produz apenas Cric Cric.
## Uma única ocorrência pode cair em qualquer um dos dois caminhos.
func _replace_solo_encounters() -> void:
	if solo_map == null:
		return
	var candidates: Array[ItemData] = []
	var inventory := InventoryManager.new()
	for path in inventory._item_paths(InventoryManager.ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"" or item.resource_path.is_empty() \
				or item.item_type not in [ItemData.ItemType.CONSUMABLE,
					ItemData.ItemType.EQUIPMENT] or &"cursed" in item.tags:
			continue
		candidates.append(item)
	if candidates.is_empty():
		push_warning("Ninguém Além de Você: não há itens elegíveis; todos os Encontros serão Cric Cric.")
	var encounters: Array[Vector2i] = []
	for coord in solo_map.cells:
		var cell := solo_map.get_cell(coord)
		if cell == null or cell.block_type != HexGrid.PPPBlockType.ENCOUNTER \
				or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
					HexGrid.PPPBlockState.REVEALED]:
			continue
		encounters.append(coord)
	for index in range(encounters.size() - 1, 0, -1):
		var other := world_rng.randi_range(0, index)
		var chosen: Vector2i = encounters[index]
		encounters[index] = encounters[other]
		encounters[other] = chosen
	var item_count := ceili(float(encounters.size()) * 0.5)
	if encounters.size() == 1:
		item_count = world_rng.randi_range(0, 1)
	for index in encounters.size():
		var coord := encounters[index]
		var cell := solo_map.get_cell(coord)
		var original := solo_map.get_ppp_block_data(coord)
		var becomes_item := index < item_count and not candidates.is_empty()
		var item := candidates[world_rng.randi_range(0, candidates.size() - 1)] \
			if becomes_item else null
		solo_saved_encounters[coord] = {"original": original,
			"revealers": solo_map.revealed_by_skill_ids.get(coord, []).duplicate(),
			"temporary_path": item.resource_path if item != null else "",
			"cricket": not becomes_item}
		if not becomes_item:
			cell.map_visual_path = ""
			continue
		cell.block_type = HexGrid.PPPBlockType.CONSUMABLE \
			if item.item_type == ItemData.ItemType.CONSUMABLE \
			else HexGrid.PPPBlockType.EQUIPMENT
		cell.resource_path = item.resource_path
		cell.map_visual_path = ""


func is_solo_cricket(coord: Vector2i) -> bool:
	return solo_turns_remaining > 0 and solo_saved_encounters.has(coord) \
		and bool(solo_saved_encounters[coord].get("cricket", false))


func _restore_solo_encounters() -> void:
	if solo_map == null:
		return
	for coord in solo_saved_encounters:
		var cell := solo_map.get_cell(coord)
		var record: Dictionary = solo_saved_encounters[coord]
		if cell == null:
			continue
		if bool(record.get("cricket", false)):
			if cell.resource_path != record["original"]["resource_path"] \
					or cell.block_type != HexGrid.PPPBlockType.ENCOUNTER:
				continue
		elif cell.resource_path != record["temporary_path"] \
					or cell.block_type not in [HexGrid.PPPBlockType.CONSUMABLE,
						HexGrid.PPPBlockType.EQUIPMENT]:
			continue # Outro efeito substituiu esse hex: não sobrescrever.
		var original: Dictionary = record["original"]
		cell.block_type = original["block_type"]
		cell.resource_path = original["resource_path"]
		cell.map_visual_path = original["map_visual_path"]
		cell.generated_from_random_block = original["generated_from_random_block"]
		cell.state = original["state"]
		cell.movement_blocked = original["movement_blocked"]
		var revealers: Array = record["revealers"]
		if revealers.is_empty():
			solo_map.revealed_by_skill_ids.erase(coord)
		else:
			solo_map.revealed_by_skill_ids[coord] = revealers.duplicate()
	solo_saved_encounters.clear()
	solo_map = null


func is_solo_owner(actor: EntityState) -> bool:
	return actor != null and solo_turns_remaining > 0 \
		and actor.instance_id == solo_owner_id


func can_act_during_solo(actor: EntityState) -> bool:
	return solo_turns_remaining <= 0 or is_solo_owner(actor)


func on_temporary_event_turn_started(actor: EntityState) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if actor == null:
		return results
	for entry in temporary_event_effects:
		if entry.get("kind") != &"ghost_pursuit" or entry.get("target") != actor \
				or day >= int(entry.get("expires_day", 0)) or actor.current_health <= 0:
			continue
		var previous := actor.current_health
		actor.current_health = maxi(0, previous - int(entry.get("damage", 0)))
		results.append({"event_id": &"ev_00022", "target": actor.instance_id,
			"damage": previous - actor.current_health})
	return results


func on_temporary_event_turn_finished(actor: EntityState) -> void:
	if actor == null:
		return
	if is_solo_owner(actor) and actor.current_health <= 0:
		end_solo_exploration()
	for index in range(temporary_event_effects.size() - 1, -1, -1):
		var entry := temporary_event_effects[index]
		if entry.get("kind") != &"stamina_loss":
			continue
		var target := entry.get("target") as EntityState
		var own_turn := target == actor and actor.turn_serial \
			> int(entry.get("applied_serial", 0))
		# Aliados não possuem turno lógico na Exploração: contam os dois
		# próximos turnos do dono, sem deixar a perda presa para sempre.
		var owner_turn := target != null and target in companion_states \
			and current_map != null \
			and current_map.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION \
			and target.position == EntityState.UNPLACED \
			and actor.instance_id == target.owner_instance_id \
			and actor.turn_serial > int(entry.get("applied_owner_serial", -1))
		if not own_turn and not owner_turn:
			continue
		entry["remaining_turns"] = int(entry.get("remaining_turns", 0)) - 1
		if int(entry["remaining_turns"]) <= 0:
			_expire_temporary_entry(index)
	if is_solo_owner(actor) and actor.turn_serial > solo_applied_turn_serial:
		solo_turns_remaining -= 1
		if solo_turns_remaining <= 0:
			end_solo_exploration()


func expire_temporary_events_for_clock() -> void:
	for index in range(temporary_event_effects.size() - 1, -1, -1):
		var entry := temporary_event_effects[index]
		if entry.has("expires_day") and day >= int(entry["expires_day"]) \
				or entry.has("expires_round") \
				and get_round_index() >= int(entry["expires_round"]):
			_expire_temporary_entry(index)


func _expire_temporary_entry(index: int) -> void:
	var entry := temporary_event_effects[index]
	var target := entry.get("target") as EntityState
	temporary_event_effects.remove_at(index)
	if target != null:
		match entry.get("kind"):
			&"stamina_loss":
				target.max_stamina += int(entry.get("amount", 0))
				# Expirar o redutor não concede movimento já gasto neste turno.
			&"appearance":
				if target.temporary_appearance == entry.get("appearance"):
					target.temporary_appearance = &""
			&"status_immunity":
				var status_id: StringName = entry.get("status_id", &"")
				var another_source := temporary_event_effects.any(func(other: Dictionary) -> bool:
					return other.get("kind") == &"status_immunity" \
						and other.get("target") == target \
						and other.get("status_id") == status_id)
				if not another_source:
					target.temporary_status_immunities.erase(status_id)
			&"day_blessing":
				var amount := int(entry.get("amount", 0))
				if entry.get("statistic") == &"attack":
					target.attack = maxi(0, target.attack - amount)
				else:
					target.max_health = maxi(1, target.max_health - amount)
					target.current_health = mini(target.current_health, target.max_health)
	temporary_event_changed.emit()


func end_solo_exploration() -> void:
	if solo_owner_id == &"" and solo_saved_positions.is_empty():
		return
	for member in active_entity_states + companion_states:
		if member == null or not solo_saved_positions.has(member.instance_id):
			continue
		member.position = solo_saved_positions[member.instance_id]
		member.temporarily_absent_from_map = false
		if member in active_entity_states and member.current_health > 0:
			member.turn_state = EntityState.TurnState.AVAILABLE
	_restore_solo_encounters()
	solo_saved_positions.clear()
	solo_owner_id = &""
	solo_turns_remaining = 0
	solo_applied_turn_serial = -1
	temporary_event_changed.emit()
	solo_exploration_ended.emit()


func has_dead_playable_slot() -> bool:
	for actor in active_entity_states:
		if actor != null and actor.current_health <= 0:
			return true
	return false


func needs_replacement_ally() -> bool:
	return has_dead_playable_slot() and not get_unselected_playable_allies().is_empty()


## Só um personagem do catálogo jogável já recrutado pode preencher a vaga.
## A ordem de recrutamento em companion_states desempata sem sorteio.
func first_promotable_playable_companion() -> EntityState:
	var playable_ids: Dictionary = {}
	for data in get_playable_catalog():
		playable_ids[data.id] = true
	for companion in companion_states:
		if companion != null and companion.current_health > 0 \
				and companion.data != null and playable_ids.has(companion.data.id):
			return companion
	return null


func _promote_playable_companion(previous: EntityState) -> EntityState:
	var replacement := first_promotable_playable_companion()
	if replacement == null or previous == null or previous.playable_slot_id == &"":
		return null
	var index := active_entity_states.find(previous)
	if index < 0:
		return null
	var old_companion_id := replacement.instance_id
	companion_states.erase(replacement)
	replacement.instance_id = previous.playable_slot_id
	replacement.playable_slot_id = previous.playable_slot_id
	replacement.owner_instance_id = &""
	replacement.base_inventory_capacity = 12
	replacement.turn_state = EntityState.TurnState.AVAILABLE
	active_entity_states[index] = replacement
	# Dependentes do antigo companheiro e do personagem morto continuam com
	# um dono válido. A instância promovida conserva Vida, Skills e equipamento.
	for companion in companion_states:
		if companion != null and companion.owner_instance_id in [old_companion_id,
				previous.instance_id]:
			companion.owner_instance_id = replacement.instance_id
	if wooden_dolls_by_owner.has(previous.instance_id):
		wooden_dolls_by_owner[replacement.instance_id] = int(
			wooden_dolls_by_owner.get(replacement.instance_id, 0)) + int(
				wooden_dolls_by_owner[previous.instance_id])
		wooden_dolls_by_owner.erase(previous.instance_id)
		wooden_doll_changed.emit(replacement.instance_id, true)
	playable_slot_replaced.emit(previous, replacement)
	return replacement


## Morte definitiva é concluída depois da janela de ressurreição do Combate.
## Equipamentos viram cópias carregadas; as demais cópias são distribuídas
## sem duplicação, em ordem e destinatários sorteados. Maldições permanecem
## no espólio do morto para o descarte confirmado.
func finalize_dead_playables(skill_manager: SkillManager,
		rng: RandomNumberGenerator = null) -> Array[EntityState]:
	var finalized: Array[EntityState] = []
	var random := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		random.randomize()
	var equipment := EquipmentManager.new()
	var inventory := InventoryManager.new()
	for actor in active_entity_states.duplicate():
		if actor == null or actor.current_health > 0 or actor in dead_playable_states:
			continue
		dead_playable_states.append(actor)
		finalized.append(actor)
		actor.turn_state = EntityState.TurnState.INACTIVE
		var promoted := _promote_playable_companion(actor)
		for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
				ItemData.EquipmentSlot.ACCESSORY]:
			for entry in actor.equipped_in_slot(slot).duplicate():
				if equipment.consume_equipped_item(actor, entry, skill_manager):
					entry.inventory_slot_index = -1
					actor.inventory_items.append(entry)
		var survivors: Array[EntityState] = []
		for teammate in active_entity_states:
			if teammate != null and teammate != actor and teammate.current_health > 0:
				survivors.append(teammate)
		var shuffled: Array[InventoryItemState] = actor.inventory_items.duplicate()
		for index in range(shuffled.size() - 1, 0, -1):
			var other := random.randi_range(0, index)
			var previous: InventoryItemState = shuffled[index]
			shuffled[index] = shuffled[other]
			shuffled[other] = previous
		for entry in shuffled:
			if entry == null or entry.data == null \
					or entry.data.item_type == ItemData.ItemType.CURSED:
				continue
			var eligible: Array[EntityState] = survivors.filter(func(candidate: EntityState) -> bool:
				return inventory.can_receive(candidate, entry.data))
			if eligible.is_empty():
				continue
			var recipient: EntityState = promoted if promoted in eligible else \
				eligible[random.randi_range(0, eligible.size() - 1)]
			actor.inventory_items.erase(entry)
			entry.inventory_slot_index = -1
			recipient.inventory_items.append(entry)
		# O espólio inteiro continua visível na janela mesmo acima dos 12 slots.
		actor.base_inventory_capacity = maxi(actor.base_inventory_capacity,
			actor.inventory_used_space())
		var leftovers: Array[InventoryItemState] = []
		leftovers.append_array(actor.inventory_items)
		for survivor in survivors:
			if skill_manager != null:
				skill_manager.debuff_manager.apply_by_id(survivor, &"db_00010",
					actor, 0, day)
		playable_death_finalized.emit(actor, leftovers)
	# Ausência de Ninguém Além de Você/Vórtice não é morte. Só a Vida real
	# dos jogáveis, depois da janela de ressurreição, decide derrota.
	if not active_entity_states.is_empty() and active_entity_states.all(
			func(member: EntityState) -> bool:
				return member == null or member.current_health <= 0):
		mark_terminal(CampaignStatus.DEFEAT)
	return finalized


func confirm_dead_inventory_discard(actor: EntityState) -> bool:
	if actor == null or actor not in dead_playable_states:
		return false
	actor.inventory_items.clear()
	return true


func replace_dead_playable(ally_data: EntityData, owner: EntityState,
		skill_manager: SkillManager, rng: RandomNumberGenerator = null) -> EntityState:
	if ally_data == null or owner == null or owner.current_health <= 0 \
			or ally_data not in get_unselected_playable_allies() \
			or not has_dead_playable_slot():
		return null
	for index in active_entity_states.size():
		var previous := active_entity_states[index]
		if previous == null or previous.current_health > 0 \
				or previous not in dead_playable_states:
			continue
		var replacement := EntityState.from_playable_selection(ally_data,
			previous.playable_slot_id, previous.position)
		replacement.base_inventory_capacity = 12
		active_entity_states[index] = replacement
		if skill_manager != null:
			skill_manager.ensure_innate_skills(replacement)
			_grant_recruited_human_equipment(replacement, rng, skill_manager)
		playable_slot_replaced.emit(previous, replacement)
		return replacement
	return null


func revive_dead_playable(actor: EntityState, wisher: EntityState,
		skill_manager: SkillManager, rng: RandomNumberGenerator = null) -> Dictionary:
	if actor == null or actor not in dead_playable_states or wisher == null \
			or wisher.current_health <= 0 or skill_manager == null:
		return {"success": false}
	# O espólio já foi redistribuído/descartado na morte. Qualquer cópia que
	# ainda tenha permanecido no corpo (inclusive Maldição) não volta com ele.
	var equipment := EquipmentManager.new()
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		for entry in actor.equipped_in_slot(slot).duplicate():
			equipment.consume_equipped_item(actor, entry, skill_manager)
	actor.inventory_items.clear()
	dead_playable_states.erase(actor)
	resurrect_entity(actor, actor.max_health, skill_manager, true)
	actor.stamina_remaining = actor.max_stamina
	for current in active_entity_states:
		if current == actor:
			actor.turn_state = EntityState.TurnState.AVAILABLE
			playable_slot_replaced.emit(actor, actor)
			return {"success": true, "as_companion": false, "actor": actor}
	actor.instance_id = StringName("Companion_%d" % next_companion_serial)
	next_companion_serial += 1
	actor.playable_slot_id = &""
	actor.base_inventory_capacity = 0
	_resurrecting_companion = actor
	var registered := register_companion(wisher, actor, rng, skill_manager, false)
	_resurrecting_companion = null
	if not registered:
		return {"success": false}
	return {"success": true, "as_companion": true, "actor": actor}


## Ponto único para efeitos de ressurreição. Cura comum não ressuscita.
## Novos efeitos que tragam uma entidade de volta devem usar esta operação.
static func resurrect_entity(actor: EntityState, health_amount: int,
		skill_manager: SkillManager, full_health: bool = false) -> bool:
	if actor == null or actor.current_health > 0 or skill_manager == null:
		return false
	grant_revive_immunity(actor, skill_manager)
	# Remover Doença pode restaurar Vida máxima; "Vida completa" usa o teto
	# já limpo, nunca o valor reduzido de antes da ressurreição.
	actor.current_health = actor.max_health if full_health else \
		clampi(health_amount, 1, actor.max_health)
	return true


## A escolha do Amuleto consulta identidades estáveis, não sprites nem nomes.
## Inclui quem morreu neste combate e os jogáveis mortos já arquivados.
func get_dead_group_members() -> Array[EntityState]:
	var dead: Array[EntityState] = []
	for group in [active_entity_states, dead_playable_states, companion_states]:
		for member in group:
			if member != null and member.current_health <= 0 and member not in dead:
				dead.append(member)
	return dead


func can_resurrect_group_member(target: EntityState, owner: EntityState) -> bool:
	var playable_owner := resurrection_playable_owner(owner)
	return target != null and owner != null and owner.current_health > 0 \
		and playable_owner != null and playable_owner.current_health > 0 \
		and target in get_dead_group_members()


func resurrection_playable_owner(actor: EntityState) -> EntityState:
	if actor in active_entity_states:
		return actor
	if actor in companion_states:
		return get_playable_slot(actor.owner_instance_id)
	return null


func resurrect_group_member(target: EntityState, owner: EntityState,
		skill_manager: SkillManager) -> Dictionary:
	if skill_manager == null or not can_resurrect_group_member(target, owner):
		return {"success": false}
	var playable_owner := resurrection_playable_owner(owner)
	if target in dead_playable_states:
		var recovered := revive_dead_playable(target, playable_owner, skill_manager)
		if recovered.get("success", false):
			target.position = playable_owner.position
		return recovered
	if not resurrect_entity(target, target.max_health, skill_manager, true):
		return {"success": false}
	if target in companion_states:
		var former_owner := get_playable_slot(target.owner_instance_id)
		if former_owner == null or former_owner.current_health <= 0:
			target.owner_instance_id = playable_owner.instance_id
		target.position = playable_owner.position
	else:
		target.turn_state = EntityState.TurnState.AVAILABLE
	return {"success": true, "actor": target}


## Regra compartilhada por QUALQUER efeito de ressurreição, presente ou futuro.
static func grant_revive_immunity(actor: EntityState,
		skill_manager: SkillManager) -> void:
	if actor == null or skill_manager == null:
		return
	for status_id in [&"db_00003", &"db_00004", &"db_00005", &"db_00009", &"db_00010"]:
		if status_id not in actor.permanent_status_immunities:
			actor.permanent_status_immunities.append(status_id)
		skill_manager.debuff_manager.remove_debuff(actor, status_id)


## Padrão/Fácil: quatro itens na Curta/Média e três na Completa.
## Caótico: exatamente dois em qualquer campanha, um equipável e um consumível.
## Equipáveis nunca repetem o tipo/slot no mesmo kit.
func _grant_starting_items(states: Array[EntityState], rng: RandomNumberGenerator,
		mode: int, chosen_difficulty: int) -> void:
	var inventory := InventoryManager.new()
	var equipment_manager := EquipmentManager.new()
	var skill_manager := SkillManager.new()
	var catalog := inventory.get_common_starting_catalog()
	var equipment: Array[ItemData] = catalog["equipment"]
	var consumables: Array[ItemData] = catalog["consumables"]
	var source := rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	var chaotic := chosen_difficulty == GameDifficulty.Mode.CHAOTIC
	var item_target := 2 if chaotic else \
		(3 if mode == EventCampaignEligibility.Mode.COMPLETE else 4)
	for actor in states:
		var eligible: Array[ItemData] = []
		var available_slots: Dictionary = {}
		for item in equipment:
			if item.equipment_slot != ItemData.EquipmentSlot.WEAPON \
					or actor.data == null or actor.data.maestrias.is_empty() \
					or actor.data.maestrias == [EntityData.Mastery.NONE] \
					or item.mastery_granted in actor.data.maestrias:
				eligible.append(item)
				available_slots[item.equipment_slot] = true
		var consumable_target := 1 if chaotic else source.randi_range(1, 2)
		if not chaotic and available_slots.size() < item_target - consumable_target:
			consumable_target = 2
		var equipment_target := item_target - consumable_target
		var weighted := eligible.duplicate()
		# O Bloco de Notas tem peso 2 apenas no sorteio do Jornalista.
		# A identidade do Resource, nunca o nome exibido, controla o peso.
		if actor.data.id == &"pj_00002":
			for item in eligible:
				if item.id == &"ac_00010":
					weighted.append(item)
		var equipped_slots: Dictionary = {}
		while equipped_slots.size() < equipment_target and not weighted.is_empty():
			var chosen: ItemData = weighted[source.randi_range(0, weighted.size() - 1)]
			if not inventory.add_item(actor, chosen):
				weighted.erase(chosen)
				continue
			var entry := actor.inventory_items.back() as InventoryItemState
			if equipment_manager.equip(actor, entry, skill_manager):
				equipped_slots[chosen.equipment_slot] = true
				weighted = weighted.filter(func(candidate: ItemData) -> bool:
					return candidate.equipment_slot != chosen.equipment_slot)
			else:
				actor.inventory_items.erase(entry)
				weighted.erase(chosen)
		if chaotic and equipped_slots.is_empty():
			# Catálogos futuros podem não oferecer equipável compatível a algum
			# jogável. Mantém os 2 itens prometidos sem criar Resource inválido.
			consumable_target = 2
			push_warning("CampaignState: Caótico sem equipamento inicial compatível para %s; dois consumíveis concedidos." % actor.data.display_name)
		# Equipáveis começam vestidos, como antes; os consumíveis ficam no
		# inventário. Itens de mesmo slot nunca entram duas vezes no kit.
		for _index in range(consumable_target):
			if not consumables.is_empty():
				inventory.add_item(actor,
					consumables[source.randi_range(0, consumables.size() - 1)])
	# SkillManager é Node e foi criado apenas como auxiliar do kit inicial.
	# Sem free(), fica fora da árvore e sobrevive até o encerramento do Godot.
	skill_manager.free()


func get_playable_slot(slot_id: StringName) -> EntityState:
	for state in active_entity_states:
		if state.playable_slot_id == slot_id:
			return state
	return null


func get_companions_for_owner(owner_id: StringName) -> Array[EntityState]:
	var result: Array[EntityState] = []
	for companion in companion_states:
		if companion.owner_instance_id == owner_id:
			result.append(companion)
	return result


func has_wooden_doll(owner: EntityState) -> bool:
	return owner != null and int(wooden_dolls_by_owner.get(owner.instance_id, 0)) > 0


func grant_wooden_doll(owner: EntityState) -> bool:
	if owner == null or owner not in active_entity_states:
		return false
	wooden_dolls_by_owner[owner.instance_id] = int(
		wooden_dolls_by_owner.get(owner.instance_id, 0)) + 1
	wooden_doll_changed.emit(owner.instance_id, true)
	return true


func consume_wooden_doll(owner: EntityState) -> bool:
	if not has_wooden_doll(owner):
		return false
	var remaining := int(wooden_dolls_by_owner[owner.instance_id]) - 1
	if remaining > 0:
		wooden_dolls_by_owner[owner.instance_id] = remaining
	else:
		wooden_dolls_by_owner.erase(owner.instance_id)
	wooden_doll_changed.emit(owner.instance_id, remaining > 0)
	return true


func record_completed_encounter(encounter: EncounterData) -> void:
	last_encounter_entity_types.clear()
	if encounter == null:
		return
	var seen: Dictionary = {}
	for member in encounter.members:
		if member != null and member.entity != null \
				and not seen.has(member.entity.id):
			seen[member.entity.id] = true
			last_encounter_entity_types.append(member.entity)
			completed_encounter_entity_counts[member.entity.id] = int(
				completed_encounter_entity_counts.get(member.entity.id, 0)) + 1


## Chamado quando um Evento/Encontro concede o companheiro. A mesma instância
## não é adicionada duas vezes, e a habilidade continua pertencendo a ela.
func register_companion(owner: EntityState, companion: EntityState,
		rng: RandomNumberGenerator = null,
		skill_manager: SkillManager = null,
		grant_starting_equipment: bool = true) -> bool:
	if owner == null or companion == null or owner not in active_entity_states \
			or companion.instance_id == &"" or companion in companion_states:
		return false
	if companion.data != null and not companion.data.animation_variants.is_empty() \
			and companion.visual_variant_index < 0:
		var last := companion.data.animation_variants.size() - 1
		companion.visual_variant_index = rng.randi_range(0, last) if rng != null \
			else world_rng.randi_range(0, last)
	companion.owner_instance_id = owner.instance_id
	# Um inimigo recrutado deixa de usar o redutor exclusivo dos hostis do
	# Água com Açúcar. A bonificação/desbonificação de outras fontes permanece.
	if companion.sugar_enemy_attack_penalty > 0:
		companion.attack += companion.sugar_enemy_attack_penalty
		companion.sugar_enemy_attack_penalty = 0
	companion.controller = EntityState.Controller.PLAYER
	if companion.data != null and companion.data.id == &"en_00019":
		# A regra hostil encerra o encontro sem Informações; se recrutado por
		# outra fonte, o aliado usa o primeiro patamar jogável (2 de cada).
		var district_cap := 5 if district == &"suburbio" else 10 \
			if district == &"baixo_centro" else 15
		var information_power := mini(maxi(2, obtained_information_ids.size()),
			district_cap)
		companion.attack = information_power
		companion.max_stamina = information_power
		companion.stamina_remaining = information_power
	companion_states.append(companion)
	if companion.data != null and &"jogavel" in companion.data.tags:
		companion.base_inventory_capacity = 0
		if grant_starting_equipment:
			_grant_recruited_human_equipment(companion, rng, skill_manager)
	companion_registered.emit(companion)
	return true


func _grant_recruited_human_equipment(companion: EntityState,
		rng: RandomNumberGenerator, skill_manager: SkillManager) -> void:
	var source := rng
	if source == null:
		source = world_rng
	var owns_skills := skill_manager == null
	var skills := skill_manager if skill_manager != null else SkillManager.new()
	var inventory := InventoryManager.new()
	var equipment := EquipmentManager.new()
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		var rarity := ItemData.Rarity.EPIC if _all_playables_have_epic(slot) \
			else ItemData.Rarity.COMMON
		var candidates := inventory.get_equipment_by_rarity(rarity, slot)
		if slot == ItemData.EquipmentSlot.WEAPON and companion.data != null \
				and not companion.data.maestrias.is_empty() \
				and companion.data.maestrias != [EntityData.Mastery.NONE]:
			candidates = candidates.filter(func(item: ItemData) -> bool:
				return item.mastery_granted in companion.data.maestrias)
		while not candidates.is_empty():
			var index := source.randi_range(0, candidates.size() - 1)
			var item := candidates[index]
			candidates.remove_at(index)
			var entry := InventoryItemState.new(item)
			companion.inventory_items.append(entry)
			if equipment.equip(companion, entry, skills, self):
				break
			companion.inventory_items.erase(entry)
	if owns_skills:
		skills.free()


func _all_playables_have_epic(slot: ItemData.EquipmentSlot) -> bool:
	if active_entity_states.is_empty():
		return false
	for actor in active_entity_states:
		var equipped := actor.primary_equipped(slot) if actor != null else null
		if equipped == null or equipped.data == null \
				or equipped.data.rarity != ItemData.Rarity.EPIC:
			return false
	return true


func filter_uncollected_information(candidates: Array[Resource]) -> Array[Resource]:
	var eligible: Array[Resource] = []
	if is_terminal():
		return eligible
	for candidate in candidates:
		var information := candidate as Informacao
		if information == null or information.id == &"":
			continue
		if is_information_eligible(information.id, information.tipo) \
				and not obtained_information_ids.has(information.id):
			eligible.append(information)
	return eligible


## Única operação de domínio para hex, Evento, recompensa, Skill e debug.
## Motivos explícitos impedem que o chamador substitua uma parte inválida por
## outra ao acaso. O contador de mapas não participa da meta de vitória.
func grant_information(information: Informacao,
		source_id: StringName = &"", force_debug: bool = false) -> Dictionary:
	if force_debug and (not OS.has_feature("debug") \
			or not bool(ProjectSettings.get_setting("ppp/debug/enabled", false))):
		return {"success": false, "code": &"debug_unavailable",
			"reason": "A concessão forçada não está disponível nesta versão."}
	if campaign_status != CampaignStatus.ACTIVE:
		return {"success": false, "code": &"campaign_not_active",
			"reason": "A campanha não está ativa."}
	if information == null or information.id == &"":
		return {"success": false, "code": &"invalid_information",
			"reason": "Esta Informação não possui um ID válido."}
	if not force_debug and not is_information_eligible(information.id, information.tipo):
		return {"success": false, "code": &"inactive_ending",
			"reason": "Esta Informação não pertence aos desfechos ativos da campanha."}
	if obtained_information_ids.has(information.id):
		return {"success": false, "code": &"already_obtained",
			"reason": "Esta Informação já foi obtida."}
	obtained_information_order.append(information.id)
	obtained_information_ids[information.id] = true
	information_obtained_on_current_map = true
	var won := obtained_information_ids.size() == information_goal() \
		and mark_terminal(CampaignStatus.VICTORY)
	# Chefes de finalização poderão entrar nesta condição futuramente, sem
	# transformar a quantidade de mapas em requisito.
	return {"success": true, "code": &"forced_debug" if force_debug else &"granted", "information_id": information.id,
		"source_id": source_id, "information_count": obtained_information_ids.size(),
		"goal": information_goal(), "victory": won,
		"impossible_in_normal_campaign": force_debug and not is_information_eligible(
			information.id, information.tipo)}


## Compatibilidade para chamadas antigas e testes; usa a mesma decisão.
func record_information_obtained(information: Informacao) -> bool:
	return grant_information(information).get("success", false)


func forget_last_information() -> StringName:
	if is_terminal():
		return &""
	while not obtained_information_order.is_empty():
		var information_id: StringName = obtained_information_order.pop_back()
		if obtained_information_ids.erase(information_id):
			return information_id
	return &""


## O gerador exclui estes IDs dos mapas futuros. Apenas gerar o hex não conta.
func record_encounter_occurred(encounter: EncounterData) -> bool:
	if encounter == null or not encounter.unique_encounter or encounter.id == &"":
		return false
	if encounter.id not in occurred_unique_encounter_ids:
		occurred_unique_encounter_ids.append(encounter.id)
	return true


## Chamado pelo futuro BlockManager quando a ativação do evento começa.
## Vale para qualquer EventData: aleatório, permanente, catástrofe ou armadilha.
func record_event_activated(event: EventData) -> bool:
	return _put_event_on_standby(event)


func activate_visual_catastrophe(event_id: StringName) -> bool:
	if event_id == AURA_FUNEBRE_EVENT_ID:
		aura_funebre_day = day
	elif event_id == NEVASCA_EVENT_ID:
		nevasca_day = day
	elif event_id == PORTAIS_INFERNAIS_EVENT_ID:
		infernal_portals_round_index = get_round_index()
		return true
	else:
		return false
	visual_weather_event_id = event_id
	visual_weather_day = day
	return true


func get_active_visual_weather() -> StringName:
	return visual_weather_event_id if visual_weather_day == day else &""


func are_infernal_portals_visuals_active() -> bool:
	return infernal_portals_round_index == get_round_index()


## Quebra da (Quarta) Parede impede o efeito antes da ativação, mas o Evento
## ainda deve esperar as mesmas três Rodadas antes de voltar ao sorteio.
func record_event_prevented(event: EventData) -> bool:
	return _put_event_on_standby(event)


func _put_event_on_standby(event: EventData) -> bool:
	if event == null or event.resource_path.is_empty():
		push_warning("CampaignState: Evento sem arquivo salvo não pode entrar em espera.")
		return false
	event_last_handled_round[event.resource_path] = get_round_index()
	return true


## Manhã do Dia 1 = 0; Tarde = 1; Noite = 2; Manhã do Dia 2 = 3.
func get_round_index() -> int:
	return (day - 1) * 3 + round_period


## Um evento ativado na Rodada N fica fora de qualquer novo mapa em N,
## N+1, N+2 e N+3. Volta a concorrer em N+4.
func get_events_on_standby(at_round_index: int = -1) -> Array[String]:
	var blocked: Array[String] = []
	var current_round := at_round_index if at_round_index >= 0 else get_round_index()
	for path in event_last_handled_round:
		var elapsed: int = current_round - int(event_last_handled_round[path])
		if elapsed <= EVENT_STANDBY_ROUNDS:
			blocked.append(path)
	# O gerador pode precisar liberar Eventos para completar um mapa. A ordem
	# abaixo garante que o primeiro liberado seja o que espera há mais tempo.
	blocked.sort_custom(func(a: String, b: String) -> bool:
		var a_round: int = int(event_last_handled_round[a])
		var b_round: int = int(event_last_handled_round[b])
		return a_round < b_round if a_round != b_round else a < b
	)
	return blocked


## Chamar só depois de o gerador devolver um mapa completo.
func decoration_anomaly_chance(target_day: int) -> float:
	var information_count := obtained_information_ids.size()
	if campaign_mode == EventCampaignEligibility.Mode.COMPLETE and information_count >= 16:
		return 0.90
	if campaign_mode == EventCampaignEligibility.Mode.COMPLETE and information_count >= 12:
		return minf(1.0, 0.50 + 0.10 * anomaly_high_tier_misses)
	if target_day < 2:
		return 0.0
	return minf(1.0, 0.05 * (maxi(target_day - anomaly_reset_day, 0) + 1))


## Chamar só depois de o gerador devolver um mapa completo.
func record_generated_map(new_map: HexGrid) -> void:
	if new_map == null:
		return
	if solo_turns_remaining > 0:
		# A Rodada pode avançar antes dos três turnos terminarem. O mapa
		# anterior recupera seus Encontros; o novo recebe o mesmo sorteio.
		_restore_solo_encounters()
	current_map = new_map
	if solo_turns_remaining > 0:
		solo_map = new_map
		_replace_solo_encounters()
	generated_map_count += 1
	if new_map.ppp_anomaly_planned:
		anomaly_reset_day = day
		anomaly_high_tier_misses = 0
	elif campaign_mode == EventCampaignEligibility.Mode.COMPLETE \
			and obtained_information_ids.size() >= 12:
		anomaly_high_tier_misses += 1
	information_obtained_on_current_map = false
	for coord in new_map.cells:
		var event := new_map.get_ppp_block_resource(coord) as EventData
		if event == null or event.resource_path.is_empty():
			continue
		var path := event.resource_path
		event_campaign_counts[path] = int(event_campaign_counts.get(path, 0)) + 1


## Isto indica apenas que a Informação liberou o botão. A futura máquina de
## Exploração ainda deverá impedir avanço durante bloco/combate pendente.
func information_allows_round_advance() -> bool:
	return campaign_status == CampaignStatus.ACTIVE \
		and information_obtained_on_current_map
