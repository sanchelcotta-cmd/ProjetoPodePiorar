class_name EventCampaignDependencies
extends RefCounted

## Catálogo de dependências MECÂNICAS. IDs/tags são chaves; nomes e falas não.
## Um Encontro só associado a uma série continua elegível no mapa.
const DIRECT_ENDING_BY_EVENT_ID := {
	&"ev_00001": &"khainokata",
	&"ev_00002": &"orchestra",
	&"ev_00003": &"homens_de_preto",
	&"ev_00004": &"controle_da_mente",
}
const INDIRECT_COMPLETE_ONLY_IDS := [&"ev_00017", &"ev_00044"]
const GENIE_EVENT_ID := &"ev_00049"
const GENIE_INFORMATION_OUTCOME_ID := &"random_information"
const EXPERIENCE_ENCOUNTER_ID := &"enc_00011"
const EXPERIENCE_ONE_CLUE_PASSIVE_ID := &"enemy_passive_001"
const EXPERIENCE_TWO_CLUE_PASSIVE_ID := &"enemy_passive_002"
const EXPERIENCE_CLUE_IDS := [&"in_00017", &"in_00018"]


static func direct_ending(event_id: StringName) -> StringName:
	return DIRECT_ENDING_BY_EVENT_ID.get(event_id, &"") as StringName


static func is_complete_only_event_id(event_id: StringName) -> bool:
	return DIRECT_ENDING_BY_EVENT_ID.has(event_id) \
		or event_id in INDIRECT_COMPLETE_ONLY_IDS


static func is_complete_only_outcome(event_id: StringName,
		outcome_id: StringName) -> bool:
	return event_id == GENIE_EVENT_ID \
		and outcome_id == GENIE_INFORMATION_OUTCOME_ID


## Classifica cada outcome separadamente: o Gênio não é excluído por inteiro.
static func classify_outcome(event: EventData,
		outcome: EventOutcomeData) -> Dictionary:
	var record := {"event_id": event.id if event != null else &"",
		"outcome_id": outcome.id if outcome != null else &"",
		"direct_ending": direct_ending(event.id) if event != null else &"",
		"requires_information": false, "grants_information": false,
		"forgets_information": false, "fixed_information_id": &"",
		"encounter_rule": &"",
		"complete_only": false}
	if event == null or outcome == null:
		return record
	record["requires_information"] = outcome.condition != null \
		and outcome.condition.condition_type == EventConditionData.ConditionType.HAS_INFORMATION
	record["complete_only"] = is_complete_only_event_id(event.id) \
		or is_complete_only_outcome(event.id, outcome.id)
	for effect in outcome.effects:
		if effect == null:
			continue
		if effect.effect_type == Event_EffectData.EffectType.GRANT_INFORMATION:
			record["grants_information"] = true
			record["fixed_information_id"] = effect.information_id
		elif effect.effect_type == Event_EffectData.EffectType.FORGET_LAST_INFORMATION:
			record["forgets_information"] = true
		elif effect.effect_type == Event_EffectData.EffectType.START_COMBAT:
			record["encounter_rule"] = &"start_combat"
		elif effect.effect_type == Event_EffectData.EffectType.CUSTOM \
				and effect.custom_rule in [&"start_crazy_old_man_combat_scaled_to_group",
					&"start_dancing_zombie_horde_by_district"]:
			record["encounter_rule"] = effect.custom_rule
	return record


## Associação temática não impede o sorteio do Encontro. Só a oferta de
## recrutamento da Experiência consulta pistas ou contagem de Informações.
static func classify_encounter(encounter: EncounterData) -> Dictionary:
	var is_experience := encounter != null and encounter.id == EXPERIENCE_ENCOUNTER_ID
	return {"encounter_id": encounter.id if encounter != null else &"",
		"entry_requires_information": false,
		"associated_ending": &"orchestra" if is_experience else &"",
		"recruitment_clue_ids": EXPERIENCE_CLUE_IDS.duplicate() if is_experience else [],
		"recruitment_global_short_threshold": 2 if is_experience else 0,
		"recruitment_global_medium_threshold": 4 if is_experience else 0}


## Validação de cruzamento entre catálogo e Resources; falha se ID/tag mudar.
static func catalog_errors() -> Array[String]:
	var errors: Array[String] = []
	var paths := [
		"res://resources/events/random_events/01-artefato_do_vazio.tres",
		"res://resources/events/random_events/02-cobaia_secreta.tres",
		"res://resources/events/random_events/03-o_velho_louco.tres",
		"res://resources/events/random_events/04-termos_de_uso.tres",
		"res://resources/events/random_events/17-o_informante.tres",
		"res://resources/events/random_events/44-duas_caras.tres",
		"res://resources/events/random_events/49-genio_da_lampada.tres",
	]
	var expected_ids := [&"ev_00001", &"ev_00002", &"ev_00003", &"ev_00004",
		&"ev_00017", &"ev_00044", GENIE_EVENT_ID]
	for index in paths.size():
		var event := load(paths[index]) as EventData
		if event == null or event.id != expected_ids[index]:
			errors.append("Evento ausente ou ID alterado: %s" % paths[index])
			continue
		if is_complete_only_event_id(event.id) \
				and EventCampaignEligibility.COMPLETE_ONLY not in event.tags:
			errors.append("Tag de campanha completa ausente: %s" % event.id)
		var ending := direct_ending(event.id)
		var has_direct_condition := false
		for outcome in event.outcomes:
			if outcome != null and outcome.condition != null \
					and outcome.condition.condition_type \
					== EventConditionData.ConditionType.HAS_INFORMATION \
					and outcome.condition.tag == ending:
				has_direct_condition = true
		if ending != &"" and not has_direct_condition:
			errors.append("Condição direta sem tag do desfecho: %s" % event.id)
		if event.id == &"ev_00002" and not event.outcomes.any(
				func(outcome: EventOutcomeData) -> bool:
					return outcome != null and classify_outcome(event,
						outcome)["fixed_information_id"] == &"in_00019"):
			errors.append("Cobaia Secreta perdeu sua Informação fixa in_00019.")
		if event.id in INDIRECT_COMPLETE_ONLY_IDS:
			var has_indirect_effect := false
			for outcome in event.outcomes:
				var record := classify_outcome(event, outcome)
				if record["grants_information"] or record["forgets_information"]:
					has_indirect_effect = true
			if not has_indirect_effect:
				errors.append("Evento indireto sem efeito de Informação: %s" % event.id)
		if event.id == GENIE_EVENT_ID:
			var found := false
			for outcome in event.outcomes:
				if outcome == null or outcome.id != GENIE_INFORMATION_OUTCOME_ID:
					continue
				found = true
				if EventCampaignEligibility.COMPLETE_ONLY not in outcome.tags \
						or not classify_outcome(event, outcome)["grants_information"]:
					errors.append("Desejo de Informação sem tag/efeito: %s" % outcome.id)
			if not found:
				errors.append("Desejo de Informação não encontrado no Gênio.")
	var encounter := load("res://resources/encounters/enc_a_experiencia.tres") as EncounterData
	if encounter == null or encounter.id != EXPERIENCE_ENCOUNTER_ID \
			or not encounter.unique_encounter:
		errors.append("A Experiência perdeu o ID estável ou unicidade.")
	for info_id in EXPERIENCE_CLUE_IDS:
		if InformationCampaignEligibility.ending_for_id(info_id) != &"orchestra":
			errors.append("Pista Orchestra inválida: %s" % info_id)
	var passive_paths := [
		"res://resources/skills/passives/enemies/a_experiencia/recrutamento_uma_informacao.tres",
		"res://resources/skills/passives/enemies/a_experiencia/recrutamento_duas_informacoes.tres"]
	var passive_ids := [EXPERIENCE_ONE_CLUE_PASSIVE_ID,
		EXPERIENCE_TWO_CLUE_PASSIVE_ID]
	for index in passive_paths.size():
		var passive := load(passive_paths[index]) as PassiveSkillData
		if passive == null or passive.id != passive_ids[index] \
				or passive.required_information_ids.size() != EXPERIENCE_CLUE_IDS.size() \
				or not EXPERIENCE_CLUE_IDS.all(func(id: StringName) -> bool:
					return id in passive.required_information_ids) \
				or not is_equal_approx(passive.activation_chance,
					0.5 if index == 0 else 0.75):
			errors.append("Passiva de recrutamento da Experiência divergente: %s" %
				passive_paths[index])
	return errors
