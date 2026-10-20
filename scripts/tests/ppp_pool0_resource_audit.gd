extends SceneTree

# Inventário somente leitura para a auditoria da campanha 0.5.
# Emite uma linha AUDIT_JSON para ferramentas externas montarem a matriz.
const EVENT_ROOT := "res://resources/events"
const INFORMATION_ROOT := "res://resources/informacoes"
const ENCOUNTER_ROOT := "res://resources/encounters"


func _initialize() -> void:
	var event_paths := _paths(EVENT_ROOT)
	var information_paths := _paths(INFORMATION_ROOT)
	var encounter_paths := _paths(ENCOUNTER_ROOT)
	var events: Array[Dictionary] = []
	var information: Array[Dictionary] = []
	var encounters: Array[Dictionary] = []
	var load_errors: Array[String] = []
	var other_resources: Array[String] = []
	for path in event_paths:
		var resource := load(path)
		if resource == null:
			load_errors.append(path)
			continue
		var event := resource as EventData
		if event == null:
			other_resources.append(path)
			continue
		events.append(_event_record(path, event))
	for path in information_paths:
		var info := load(path) as Informacao
		if info == null:
			load_errors.append(path)
			continue
		information.append({"path": path, "id": str(info.id), "tipo": str(info.tipo),
			"tags": _names(info.tags)})
	for path in encounter_paths:
		var encounter := load(path) as EncounterData
		if encounter == null:
			load_errors.append(path)
			continue
		encounters.append({"path": path, "id": str(encounter.id),
			"unique": encounter.unique_encounter, "districts": _names(encounter.districts),
			"tags": _names(encounter.tags), "weight": encounter.selection_weight,
			"valid_composition": encounter.has_valid_composition()})
	var diagnostics := _diagnostics(events, information, encounters)
	print("AUDIT_JSON=" + JSON.stringify({"events": events, "information": information,
		"encounters": encounters, "load_errors": load_errors,
		"other_resources": other_resources,
		"diagnostics": diagnostics}))
	var valid: bool = load_errors.is_empty() and diagnostics["blank_ids"].is_empty() \
		and diagnostics["duplicate_ids"].is_empty() \
		and diagnostics["duplicate_outcome_ids"].is_empty() \
		and diagnostics["unnamed_outcomes"] == 0 \
		and diagnostics["orphaned_references"].is_empty()
	quit(0 if valid else 1)


func _paths(folder: String) -> Array[String]:
	var result: Array[String] = []
	var entries := ResourceLoader.list_directory(folder)
	entries.sort()
	for entry in entries:
		if entry.ends_with("/"):
			result.append_array(_paths(folder.path_join(entry.trim_suffix("/"))))
		elif entry.ends_with(".tres"):
			result.append(folder.path_join(entry))
	return result


func _event_record(path: String, event: EventData) -> Dictionary:
	var generated: Array[String] = []
	for child in event.generated_events:
		generated.append(str(child.id) if child != null else "<null>")
	var outcomes: Array[Dictionary] = []
	for outcome in event.outcomes:
		if outcome == null:
			outcomes.append({"id": "<null>"})
			continue
		var effects: Array[Dictionary] = []
		for effect in outcome.effects:
			effects.append(_effect_record(effect, ""))
		for choice in outcome.effect_choices:
			if choice == null:
				continue
			for effect in choice.effects:
				effects.append(_effect_record(effect, str(choice.id)))
		var condition := {}
		if outcome.condition != null:
			condition = {"type": _enum_name(EventConditionData.ConditionType,
				outcome.condition.condition_type), "tag": str(outcome.condition.tag),
				"negate": outcome.condition.negate,
				"custom_rule": str(outcome.condition.custom_rule)}
		outcomes.append({"id": str(outcome.id), "weight": outcome.weight,
			"condition": condition, "effects": effects, "tags": _names(outcome.tags)})
	return {"path": path, "id": str(event.id), "name": event.display_name,
		"category": _enum_name(EventData.EventCategory, event.category),
		"valence": _enum_name(EventData.Valence, event.valence),
		"resolution": _enum_name(EventData.ResolutionMode, event.resolution_mode),
		"weight": event.selection_weight, "can_repeat": event.can_repeat,
		"max_times": event.max_times_per_campaign,
		"requires_completed_encounter": event.requires_completed_encounter,
		"custom_rule": str(event.custom_rule), "tags": _names(event.tags),
		"generated": generated, "outcomes": outcomes}


func _effect_record(effect: Event_EffectData, choice_id: String) -> Dictionary:
	if effect == null:
		return {"type": "<null>", "choice": choice_id}
	return {"type": _enum_name(Event_EffectData.EffectType, effect.effect_type),
		"choice": choice_id, "information_id": str(effect.information_id),
		"event_id": str(effect.event_id), "tags_filter": _names(effect.tags_filter),
		"selection_mode": _enum_name(Event_EffectData.SelectionMode,
			effect.selection_mode), "custom_rule": str(effect.custom_rule),
		"encounter_selection": _enum_name(Event_EffectData.EncounterSelection,
			effect.encounter_selection)}


func _names(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _enum_name(values: Dictionary, value: int) -> String:
	for key in values:
		if int(values[key]) == value:
			return str(key)
	return "<invalid:%d>" % value


func _diagnostics(events: Array[Dictionary], information: Array[Dictionary],
		encounters: Array[Dictionary]) -> Dictionary:
	var event_ids: Dictionary = {}
	var information_ids: Dictionary = {}
	var encounter_ids: Dictionary = {}
	var duplicate_ids: Array[String] = []
	var blank_ids: Array[String] = []
	var outcome_ids: Dictionary = {}
	var duplicate_outcome_ids: Array[String] = []
	for catalog in [events, information, encounters]:
		var seen: Dictionary = {}
		for record in catalog:
			var id := str(record["id"])
			if id.is_empty():
				blank_ids.append(str(record["path"]))
			elif seen.has(id):
				duplicate_ids.append("%s: %s | %s" % [id, seen[id], record["path"]])
			seen[id] = record["path"]
		if catalog == events:
			event_ids = seen
		elif catalog == information:
			information_ids = seen
		else:
			encounter_ids = seen
	var orphaned_references: Array[String] = []
	var unnamed_outcomes := 0
	for event in events:
		for child_id in event["generated"]:
			if not event_ids.has(child_id):
				orphaned_references.append("%s generates %s" % [event["id"], child_id])
		for outcome in event["outcomes"]:
			var outcome_id := str(outcome["id"])
			if outcome_id.is_empty():
				unnamed_outcomes += 1
			elif outcome_ids.has(outcome_id):
				duplicate_outcome_ids.append("%s: %s | %s" % [
					outcome_id, outcome_ids[outcome_id], event["id"]])
			else:
				outcome_ids[outcome_id] = event["id"]
			for effect in outcome["effects"]:
				if not str(effect["event_id"]).is_empty() \
						and not event_ids.has(effect["event_id"]):
					orphaned_references.append("%s event %s" % [event["id"],
						effect["event_id"]])
				if not str(effect["information_id"]).is_empty() \
						and not information_ids.has(effect["information_id"]):
					orphaned_references.append("%s information %s" % [event["id"],
						effect["information_id"]])
	return {"duplicate_ids": duplicate_ids, "blank_ids": blank_ids,
		"duplicate_outcome_ids": duplicate_outcome_ids,
		"orphaned_references": orphaned_references,
		"unnamed_outcomes": unnamed_outcomes,
		"outcome_count": outcome_ids.size(),
		"event_count": event_ids.size(), "information_count": information_ids.size(),
		"encounter_count": encounter_ids.size()}
