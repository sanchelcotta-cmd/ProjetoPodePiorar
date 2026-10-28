extends RefCounted

## Apenas desenvolvimento. Consulta Resources; altera somente instâncias da campanha.
const FOLDERS := {
	"event": "res://resources/events",
	"encounter": "res://resources/encounters",
	"item": "res://resources/itens",
	"ally": "res://resources/entities",
	"active": "res://resources/skills",
	"passive": "res://resources/skills",
	"debuff": "res://resources/skills/effects/debuffs",
	"information": "res://resources/informacoes",
}

var gerencia: GerenciaJogo
var blocks: BlockManager
var skills: SkillManager
var rounds: RoundManager
var _catalogs: Dictionary = {}
var _undo: Dictionary = {}


static func is_enabled() -> bool:
	# A exportação pública release nunca habilita o painel, mesmo com flag.
	return OS.has_feature("debug") and bool(ProjectSettings.get_setting(
		"ppp/debug/enabled", true))


func setup(game: Node) -> void:
	gerencia = game.get_node_or_null("GerenciaJogo") as GerenciaJogo
	blocks = game.get_node_or_null("BlockManager") as BlockManager
	skills = game.get_node_or_null("SkillManager") as SkillManager
	rounds = game.get_node_or_null("RoundManager") as RoundManager


func campaign_ready() -> bool:
	return is_enabled() and gerencia != null and blocks != null and skills != null \
		and gerencia.campaign != null \
		and gerencia.campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE


func actors() -> Array[EntityState]:
	var result: Array[EntityState] = []
	if gerencia != null and gerencia.campaign != null:
		for actor in gerencia.campaign.active_entity_states + gerencia.campaign.companion_states:
			if actor != null and actor.current_health > 0:
				result.append(actor)
	return result


func catalog(kind: String) -> Array[Dictionary]:
	if _catalogs.has(kind):
		return _catalogs[kind]
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	if kind == "attribute":
		for pair in [["health", "Vida atual"], ["max_health", "Vida máxima"],
				["attack", "Ataque"], ["stamina", "Estamina máxima"]]:
			result.append({"id": StringName(pair[0]), "name": pair[1], "resource": null})
	elif FOLDERS.has(kind):
		var paths: Array[String] = []
		_scan(str(FOLDERS[kind]), paths)
		if kind in ["active", "passive"]:
			_scan("res://resources/entities", paths)
			_scan("res://resources/itens", paths)
		for path in paths:
			var resource := load(path)
			if kind == "event" and resource is EventData:
				_add(result, seen, resource.id, resource.display_name, resource)
			elif kind == "encounter" and resource is EncounterData:
				_add(result, seen, resource.id, resource.display_name, resource)
			elif kind == "item" and resource is ItemData:
				_add(result, seen, resource.id, resource.display_name, resource)
			elif kind == "ally" and resource is EntityData:
				_add(result, seen, resource.id, resource.display_name, resource)
			elif kind == "information" and resource is Informacao:
				_add(result, seen, resource.id, resource.titulo, resource)
			elif kind == "debuff" and resource is DebuffData:
				_add(result, seen, resource.id, resource.display_name, resource)
			elif kind == "active":
				if resource is ActiveSkillData:
					_add(result, seen, resource.id, resource.display_name, resource)
				elif resource is EntityData:
					for value in resource.skill_ativas:
						if value != null:
							_add(result, seen, value.id, value.display_name, value)
				elif resource is ItemData:
					for value in resource.granted_active_skills:
						if value != null:
							_add(result, seen, value.id, value.display_name, value)
			elif kind == "passive":
				if resource is PassiveSkillData:
					_add(result, seen, resource.id, resource.display_name, resource)
				elif resource is EntityData:
					for value in resource.skill_passivas:
						if value != null:
							_add(result, seen, value.id, value.display_name, value)
				elif resource is ItemData:
					for value in resource.granted_passives:
						if value != null:
							_add(result, seen, value.id, value.display_name, value)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	_catalogs[kind] = result
	return result


func _scan(folder: String, paths: Array[String]) -> void:
	for file in ResourceLoader.list_directory(folder):
		var path := folder.path_join(file.trim_suffix("/"))
		if file.ends_with("/"):
			_scan(path, paths)
		elif file.ends_with(".tres"):
			paths.append(path)


func _add(rows: Array[Dictionary], seen: Dictionary, id: StringName,
		title: String, resource: Resource) -> void:
	if id == &"" or seen.has(id):
		return
	seen[id] = true
	rows.append({"id": id, "name": title, "resource": resource})


func find(kind: String, id: StringName) -> Dictionary:
	for row in catalog(kind):
		if row["id"] == id:
			return row
	return {}


func inspect(kind: String, id: StringName, actor: EntityState = null,
		outcome_id: StringName = &"") -> Dictionary:
	if not campaign_ready():
		return {"eligible": false, "forceable": false,
			"reason": "Inicie uma campanha ativa."}
	var row := find(kind, id)
	if row.is_empty():
		return {"eligible": false, "forceable": false, "reason": "ID não encontrado."}
	var campaign := gerencia.campaign
	var reason := ""
	var forceable := false
	if blocks.is_busy():
		reason = "Conclua a ação pendente primeiro."
	elif kind != "information" and (actor == null or actor.current_health <= 0
			or (actor not in campaign.active_entity_states
			and actor not in campaign.companion_states)):
		reason = "Selecione um personagem vivo desta campanha."
	elif kind == "event":
		var event := row["resource"] as EventData
		if actor not in campaign.active_entity_states:
			reason = "O ativador de Evento precisa ser um jogável."
		elif not _in_exploration():
			reason = "Evento virtual exige Exploração."
		else:
			var match_outcome: EventOutcomeData
			if outcome_id != &"":
				for outcome in event.outcomes:
					if outcome != null and outcome.id == outcome_id:
						match_outcome = outcome
						break
			if outcome_id != &"" and match_outcome == null:
				reason = "Outcome não pertence ao Evento."
			elif not EventCampaignEligibility.allows_event(event, campaign.campaign_mode):
				reason = "Evento excluído deste modo de campanha."
				forceable = true
			elif match_outcome != null and not EventCampaignEligibility.allows_outcome(
					match_outcome, campaign.campaign_mode):
				reason = "Outcome excluído deste modo de campanha."
				forceable = true
	elif kind == "encounter":
		var encounter := row["resource"] as EncounterData
		if actor not in campaign.active_entity_states:
			reason = "O ativador do Encontro precisa ser um jogável."
		elif not _in_exploration():
			reason = "Encontro virtual exige Exploração."
		elif not encounter.has_valid_composition():
			reason = "Encontro sem composição válida."
		elif encounter.unique_encounter and encounter.id in campaign.occurred_unique_encounter_ids:
			reason = "Encontro único já concluído."
			forceable = true
		elif not encounter.can_appear_in(campaign.district,
				campaign.round_period == PPPMapGenerator.RoundPeriod.NIGHT):
			reason = "Fora do distrito/período atual."
			forceable = true
	elif kind == "information":
		var info := row["resource"] as Informacao
		if campaign.obtained_information_ids.has(id):
			reason = "Informação repetida; nem debug duplica partes."
		elif not campaign.is_information_eligible(id, info.tipo):
			reason = "Desfecho inativo: impossível em campanha normal."
			forceable = true
	elif kind == "item":
		if not skills.inventory_manager.can_receive(actor, row["resource"] as ItemData):
			reason = "Inventário sem capacidade ou alvo inválido."
	elif kind in ["active", "passive"]:
		for grant in actor.skill_grants:
			if grant.skill != null and grant.skill.get("id") == id:
				reason = "Personagem já possui esta habilidade."
				break
	elif kind == "ally" and actor not in campaign.active_entity_states:
		reason = "O dono precisa ser um jogável."
	elif kind == "debuff" and skills.is_status_immune(actor, id):
		reason = "Personagem imune a este estado."
	return {"eligible": reason.is_empty(), "forceable": forceable,
		"reason": "Elegível pelas regras atuais." if reason.is_empty() else reason,
		"impossible_in_normal_campaign": forceable}


func _in_exploration() -> bool:
	return gerencia.campaign.current_map != null \
		and gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION


func execute(kind: String, id: StringName, actor: EntityState = null,
		amount: int = 1, force: bool = false,
		outcome_id: StringName = &"") -> Dictionary:
	if outcome_id != &"" and (kind != "event" or not force):
		return {"success": false,
			"reason": "Outcome específico exige Forçar (debug)."}
	var check := inspect(kind, id, actor, outcome_id)
	if not check.get("eligible", false) and not (force and check.get("forceable", false)):
		return {"success": false, "reason": check.get("reason", "Indisponível.")}
	var row := find(kind, id)
	var result: Dictionary = {"success": false, "reason": "Comando indisponível."}
	_undo.clear() # Não oferecer um desfazer antigo depois de outra mutação.
	match kind:
		"event", "encounter":
			result = blocks.begin_debug_content(row["resource"], actor,
				force or outcome_id != &"", outcome_id if kind == "event" else &"")
		"information":
			result = gerencia.grant_information(row["resource"] as Informacao,
				&"debug_forced" if force else &"debug_normal", force)
		"item":
			var before := actor.inventory_items.size()
			var added := skills.inventory_manager.add_item(actor, row["resource"] as ItemData)
			result = {"success": added,
				"reason": "Item entregue." if added else "Entrega recusada."}
			if added and actor.inventory_items.size() > before:
				_undo = {"kind": kind, "actor": actor, "entry": actor.inventory_items.back()}
		"active", "passive":
			var source_id := StringName("debug:%s:%s" % [kind, id])
			var grant := skills.grant_skill(actor, row["resource"], &"debug", source_id,
				gerencia.campaign)
			result = {"success": grant != null,
				"reason": "Habilidade concedida." if grant != null else "Concessão recusada pelo gestor."}
			if grant != null:
				_undo = {"kind": kind, "actor": actor, "source_id": source_id,
					"grant": grant}
		"ally":
			var data := row["resource"] as EntityData
			var serial := gerencia.campaign.next_companion_serial
			var companion := EntityState.from_encounter_member(data, &"debug_ally",
				serial, EntityState.UNPLACED)
			companion.instance_id = StringName("debug:ally:%d" % serial)
			gerencia.campaign.next_companion_serial += 1
			var added := gerencia.campaign.register_companion(actor, companion,
				gerencia.campaign.world_rng, skills)
			if added:
				skills.ensure_innate_skills(companion)
			result = {"success": added,
				"reason": "Aliado recrutado." if added else "Registro de aliado recusado."}
		"attribute":
			var property := str(id)
			if property == "health": property = "current_health"
			if property == "stamina": property = "max_stamina"
			var old := int(actor.get(property))
			var before_health := actor.current_health
			var before_stamina := actor.stamina_remaining
			var value := maxi(0 if property in ["attack", "max_stamina"] else 1,
				old + amount)
			if property == "current_health": value = mini(value, actor.max_health)
			actor.set(property, value)
			if property == "max_health": actor.current_health = mini(actor.current_health, value)
			if property == "max_stamina": actor.stamina_remaining = mini(actor.stamina_remaining, value)
			result = {"success": value != old, "reason": "%d → %d" % [old, value]}
			if value != old:
				_undo = {"kind": kind, "actor": actor, "property": property,
					"before": old, "after": value,
					"before_health": before_health, "after_health": actor.current_health,
					"before_stamina": before_stamina, "after_stamina": actor.stamina_remaining}
		"debuff":
			var prior := skills.debuff_manager.get_debuff(actor, id)
			result = skills.debuff_manager.apply_debuff(actor,
				row["resource"] as DebuffData, actor, 1, gerencia.campaign.day,
				-1, &"debug", -1.0, 1)
			if result.get("success", false) and prior == null:
				_undo = {"kind": kind, "actor": actor, "id": id,
					"turn_serial": actor.turn_serial,
					"round_index": gerencia.campaign.get_round_index(),
					"health": actor.current_health}
	if result.get("success", false):
		result["forced"] = force
		result["impossible_in_normal_campaign"] = check.get("impossible_in_normal_campaign", false)
		gerencia.campaign.append_journal_entry(&"debug_command", [
			{"text": "[DEBUG %s] %s" % ["FORÇADO" if force else "NORMAL", row["name"]],
				"tone": "muted"}], actor.instance_id if actor != null else &"",
			{"debug": true, "forced": force, "resource_id": str(id)})
	return result


func advance_time(district: StringName, force: bool = false) -> Dictionary:
	if not campaign_ready() or rounds == null:
		return {"success": false, "reason": "Relógio indisponível."}
	var success := rounds.advance_to_district(district, null, force)
	return {"success": success,
		"reason": "Nova Rodada iniciada." if success else "Avanço recusado: fase ou destino indisponível."}


func undo_last() -> Dictionary:
	if not campaign_ready() or _undo.is_empty() or blocks.is_busy():
		return {"success": false, "reason": "Nada reversível em estado seguro."}
	var actor := _undo.get("actor") as EntityState
	if actor == null:
		return {"success": false, "reason": "Personagem ausente."}
	var success := false
	match str(_undo.get("kind", "")):
		"item":
			if _undo["entry"] in actor.inventory_items:
				actor.inventory_items.erase(_undo["entry"])
				success = true
		"active", "passive":
			var grant := _undo.get("grant") as SkillGrantState
			if grant != null and grant in actor.skill_grants \
					and grant.uses_in_last_turn == 0 and grant.uses_in_last_round == 0 \
					and grant.uses_in_last_day == 0 and grant.passive_uses_in_turn == 0 \
					and grant.passive_uses_in_combat == 0:
				success = skills.remove_source(actor, &"debug", _undo["source_id"]) > 0
		"attribute":
			if int(actor.get(_undo["property"])) == int(_undo["after"]) \
					and actor.current_health == int(_undo["after_health"]) \
					and actor.stamina_remaining == int(_undo["after_stamina"]):
				actor.set(_undo["property"], _undo["before"])
				actor.current_health = int(_undo["before_health"])
				actor.stamina_remaining = int(_undo["before_stamina"])
				success = true
		"debuff":
			if actor.turn_serial == int(_undo["turn_serial"]) \
					and gerencia.campaign.get_round_index() == int(_undo["round_index"]) \
					and actor.current_health == int(_undo["health"]):
				success = skills.debuff_manager.remove_debuff(actor, _undo["id"])
	if success: _undo.clear()
	return {"success": success,
		"reason": "Ação desfeita." if success else "O estado mudou; não é seguro desfazer."}
