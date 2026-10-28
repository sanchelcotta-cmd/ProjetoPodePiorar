class_name CampaignJournalRecorder
extends Node

## Escuta ações já resolvidas; a interface só lê CampaignState.journal_entries.
## Não registrar clique, hover ou intenção ainda cancelável.

@export var gerencia: GerenciaJogo
@export var exploration: ExplorationManager
@export var player_skill_manager: PlayerSkillManager
@export var block_manager: BlockManager
@export var combat: CombatManager
@export var event_executor: EventExecutor
@export var round_manager: RoundManager

var _last_combat_id: StringName = &""
var _last_encounter_name := ""
var _encounter_activator: EntityState
var _deaths_logged: Dictionary = {}
var _pending_promotions: Dictionary = {}
var suspended := false # Reidratar a UI não é uma nova ação da campanha.


func _ready() -> void:
	if gerencia != null:
		gerencia.information_granted.connect(_on_information_granted)
		gerencia.campaign.campaign_terminal_changed.connect(_on_terminal)
		gerencia.campaign.playable_death_finalized.connect(_on_playable_death)
		gerencia.campaign.playable_slot_replaced.connect(_on_playable_slot_replaced)
		gerencia.campaign.companion_registered.connect(_on_companion_registered)
	if exploration != null:
		exploration.actor_teleported.connect(_on_exploration_teleport)
	if player_skill_manager != null:
		player_skill_manager.exploration_active_resolved.connect(_on_exploration_skill)
	if block_manager != null:
		block_manager.combat_requested.connect(_on_combat_requested)
		block_manager.block_finished.connect(_on_block_finished)
	if combat != null:
		combat.combat_prepared.connect(_on_combat_prepared)
		combat.action_resolved.connect(_on_combat_action)
		combat.combat_finished.connect(_on_combat_finished)
		combat.loot_item_delivered.connect(_on_combat_loot_delivered)
	if event_executor != null:
		event_executor.result_ready.connect(_on_event_result)


func _campaign() -> CampaignState:
	return gerencia.campaign if gerencia != null else null


func _seg(value: String, tone: String = "text") -> Dictionary:
	return {"text": value, "tone": tone}


func _name(actor: EntityState) -> String:
	return actor.visible_name() if actor != null else "Alguém"


func _tone(actor: EntityState) -> String:
	return "hostile" if combat != null and actor in combat.enemies else "actor"


func _record(action_id: StringName, parts: Array, actor: EntityState = null,
		references: Dictionary = {}) -> void:
	if suspended:
		return
	var campaign := _campaign()
	if campaign != null:
		campaign.append_journal_entry(action_id, parts,
			actor.instance_id if actor != null else &"", references)


func _on_exploration_teleport(actor: EntityState, destination: Vector2i) -> void:
	if actor != null:
		_record(&"teleport", [_seg(_name(actor), "actor"),
			_seg(" se teleportou em %s." % _district_name())], actor,
			{"destination": str(destination)})


func _district_name() -> String:
	var campaign := _campaign()
	if campaign == null:
		return "distrito não identificado"
	match str(campaign.district):
		"suburbio": return "Subúrbio"
		"baixo_centro": return "Baixo-Centro"
		"centro": return "Centro"
	return str(campaign.district).replace("_", " ").capitalize()


func _block_title(coord: Vector2i) -> String:
	var campaign := _campaign()
	if campaign == null or campaign.current_map == null:
		return "Trecho corrompido//arquivo perdido. ERRO de registro"
	var content := campaign.current_map.get_ppp_block_resource(coord)
	if content is Informacao:
		return (content as Informacao).titulo
	if content is EventData or content is EncounterData or content is ItemData:
		return content.display_name
	return "Trecho corrompido//arquivo perdido. ERRO de registro"


func _on_exploration_skill(actor: EntityState, skill: ActiveSkillData,
		coord: Vector2i) -> void:
	if actor == null or skill == null:
		return
	# Craft registra o item criado no instante da confirmação, em vez de
	# duplicar uma linha genérica da habilidade que reduziu o custo.
	if skill.effects.any(func(effect: SkillEffectData) -> bool:
		return effect.effect_type == SkillEffectData.EffectType.MODIFY_CRAFT_COST):
		return
	var parts: Array = [_seg(_name(actor), "actor"), _seg(" usou "),
		_seg(skill.display_name, "skill")]
	var outcomes: Array[String] = []
	var manager := player_skill_manager.skill_manager if player_skill_manager != null else null
	var feedback: Dictionary = manager.last_exploration_result if manager != null else {}
	if feedback.get("actor_id") == actor.instance_id \
			and feedback.get("skill_id") == skill.id:
		for value in feedback.get("effects", []):
			if not value is Dictionary:
				continue
			var effect := value as Dictionary
			if effect.get("chance_failed", false):
				outcomes.append("não foi dessa vez")
			elif effect.has("revealed_tiles"):
				var titles: Array[String] = []
				for revealed_coord in effect["revealed_tiles"]:
					titles.append(_block_title(revealed_coord))
				if not titles.is_empty():
					parts.append(_seg(" e revelou: "))
					parts.append(_seg(", ".join(titles), "positive"))
			elif effect.has("extra_movements"):
				outcomes.append("ganhou %d movimento(s) extra" % int(effect["extra_movements"]))
			elif effect.has("teleport_to"):
				outcomes.append("teleportou-se no mapa")
			elif effect.has("destroyed_tile"):
				outcomes.append("destruiu um bloco")
			elif effect.has("positioned_tile"):
				outcomes.append("reposicionou-se no mapa")
			elif effect.has("returns_on_owner_turn"):
				outcomes.append("saiu de cena até o próximo turno do dono")
			elif effect.has("delayed_until_owner_turn"):
				outcomes.append("preparou seu efeito para o próximo turno do dono")
			elif effect.has("crafted_item"):
				var created := effect["crafted_item"] as ItemData
				if created != null:
					outcomes.append("criou %s" % created.display_name)
			elif effect.has("item"):
				var delivered := effect["item"] as ItemData
				if delivered != null:
					outcomes.append("obteve %s" % delivered.display_name)
	if not outcomes.is_empty():
		parts.append(_seg(" e %s." % ", ".join(outcomes), "positive"))
	elif parts.size() > 3:
		parts.append(_seg("."))
	else:
		parts.append(_seg("."))
	_record(&"exploration_skill", parts, actor, {"skill_id": str(skill.id),
		"hex": str(coord) if coord != EntityState.UNPLACED else ""})


func _on_information_granted(information: Informacao, _result: Dictionary) -> void:
	if information != null:
		_record(&"information", [_seg("O grupo encontrou a Informação: "),
			_seg(information.titulo, "information"), _seg(".")], null,
			{"information_id": str(information.id)})


func _on_combat_loot_delivered(recipient: EntityState, item: ItemData) -> void:
	if recipient != null and item != null:
		_record(&"combat_loot", [_seg(_name(recipient), "actor"),
			_seg(" guardou o saque do combate: "),
			_seg(item.display_name, "item"), _seg(".")], recipient,
			{"item_id": str(item.id)})


func _on_combat_requested(context: Dictionary) -> void:
	_encounter_activator = context.get("actor") as EntityState


func _on_block_finished(result: Dictionary) -> void:
	var actor := result.get("actor") as EntityState
	var item := result.get("resource") as ItemData
	var kind := int(result.get("completion_kind", -1))
	if item != null and kind == BlockManager.CompletionKind.ITEM_COLLECTED:
		_record(&"item_collected", [_seg(_name(actor), "actor"),
			_seg(" recolheu "), _seg(item.display_name, "item"),
			_seg(" encontrado em %s." % _district_name(), "positive")], actor,
			{"item_id": str(item.id)})
	elif item != null and kind == BlockManager.CompletionKind.ITEM_LEFT:
		_record(&"item_left", [_seg(_name(actor), "actor"),
			_seg(" deixou "), _seg(item.display_name, "item"),
			_seg(" no bloco.")], actor,
			{"item_id": str(item.id)})
	elif kind == BlockManager.CompletionKind.EVENT_PREVENTED:
		var event := result.get("resource") as EventData
		_record(&"event_prevented", [_seg("Bonequinho cancelou "),
			_seg(event.display_name if event != null else "o evento", "event"),
			_seg(". Ufa?", "positive")], actor,
			{"event_id": str(event.id) if event != null else ""})


func _on_combat_prepared(encounter: EncounterData, enemies: Array[EntityState],
		_initiative: Array[Dictionary]) -> void:
	if combat == null or combat._combat_id == _last_combat_id:
		return
	_last_combat_id = combat._combat_id
	_last_encounter_name = encounter.display_name if encounter != null else "Encontro Indesejado"
	var parts: Array = []
	if _encounter_activator != null:
		parts.append(_seg(_name(_encounter_activator), "actor"))
		parts.append(_seg(" caiu em um Encontro Indesejado com "))
	else:
		parts.append(_seg("O grupo caiu em um Encontro Indesejado com "))
	parts.append(_seg(encounter.display_name if encounter != null else "desconhecido", "negative"))
	if not enemies.is_empty():
		parts.append(_seg(" contra "))
		for index in enemies.size():
			if index > 0:
				parts.append(_seg(", " if index < enemies.size() - 1 else " e "))
			parts.append(_seg(_name(enemies[index]), "hostile"))
	parts.append(_seg("."))
	_record(&"encounter_started", parts, _encounter_activator,
		{"encounter_id": str(encounter.id) if encounter != null else ""})
	_encounter_activator = null


func _on_combat_action(actor: EntityState, action: StringName,
		details: Dictionary) -> void:
	if actor == null:
		return
	var actor_part := _seg(_name(actor), _tone(actor))
	var target := details.get("target") as EntityState
	match action:
		&"ricochet":
			var damage := int(details.get("damage", 0))
			var source_target := details.get("source_target") as EntityState
			_record(action, [actor_part,
				_seg(" atingiu "), _seg(_name(source_target), _tone(source_target)),
				_seg(" com a "), _seg("Espada Irada Eletrizante", "item"),
				_seg("; o ricochete acertou "), _seg(_name(target), _tone(target)),
				_seg(" e causou %d de dano." % damage,
					"positive" if damage > 0 else "negative")], actor,
				{"target_id": str(target.instance_id) if target != null else "",
					"damage": damage})
		&"attack", &"counterattack":
			var damage := int(details.get("damage", 0))
			var parts: Array = [actor_part,
				_seg(" contra-atacou " if action == &"counterattack" else " atacou "),
				_seg(_name(target), _tone(target))]
			if bool(details.get("dodged", false)):
				parts.append(_seg(", mas o alvo esquivou.", "negative"))
			else:
				parts.append(_seg(" e causou %d de dano" % damage,
					"negative" if _tone(actor) == "hostile" or damage <= 0 else "positive"))
				if bool(details.get("critical", false)):
					parts.append(_seg(" — CRITOU!", "critical"))
				var statuses: Array = details.get("applied_statuses", [])
				if not statuses.is_empty():
					parts.append(_seg(" e aplicou %s" % ", ".join(statuses), "negative"))
				parts.append(_seg("."))
			_record(action, parts, actor,
				{"target_id": str(target.instance_id) if target != null else "",
					"damage": damage, "critical": bool(details.get("critical", false)),
					"applied_statuses": details.get("applied_statuses", [])})
		&"attack_missed_reach":
			_record(action, [actor_part, _seg(" tentou atacar "),
				_seg(_name(target), _tone(target)),
				_seg(", mas não alcançou o alvo.", "negative")], actor)
		&"move":
			pass # Movimento comum não é acontecimento editorial no livro.
		&"roll":
			pass # O dano resolvido é o dado útil; valor do lançamento é ruído.
		&"skill":
			var skill_name := str(details.get("skill_name", "habilidade ativa"))
			var used_skill := details.get("skill") as ActiveSkillData
			if used_skill != null:
				skill_name = used_skill.display_name
			elif combat._selected_skill_grant != null \
					and combat._selected_skill_grant.skill != null:
				skill_name = combat._selected_skill_grant.skill.display_name
			var outcomes: Array[String] = []
			var skill_damage := 0
			for effect_value in details.get("effects", []):
				if not effect_value is Dictionary:
					continue
				var effect := effect_value as Dictionary
				if effect.get("chance_failed", false):
					outcomes.append("não foi dessa vez")
				elif effect.has("damage"):
					skill_damage += maxi(0, int(effect["damage"]))
					outcomes.append("causou %d de dano" % int(effect["damage"]))
				elif effect.has("summoned") and effect["summoned"] is Array:
					outcomes.append("invocou %d entidade(s)" % (effect["summoned"] as Array).size())
				elif effect.has("revived"):
					outcomes.append("ressuscitou %s" % _name(effect["revived"] as EntityState))
				elif effect.has("companion"):
					outcomes.append("recrutou %s" % _name(effect["companion"] as EntityState))
				elif effect.has("targets") and effect["targets"] is Array:
					var status_names: Array[String] = []
					for target_result in effect["targets"]:
						if not target_result is Dictionary:
							continue
						var applied := (target_result as Dictionary).get("result", {}) as Dictionary
						var instance := applied.get("instance") as DebuffInstanceState
						if instance != null and instance.data != null \
								and instance.data.display_name not in status_names:
							status_names.append(instance.data.display_name)
					if not status_names.is_empty():
						outcomes.append("aplicou %s" % ", ".join(status_names))
					else:
						outcomes.append("afetou %d alvo(s)" % (effect["targets"] as Array).size())
				elif effect.has("reduction"):
					outcomes.append("reduziu Ataque em %d" % int(effect["reduction"]))
				elif effect.has("guard"):
					outcomes.append("protegeu %s" % _name(effect.get("protected") as EntityState))
				elif effect.has("remaining_fraction"):
					outcomes.append("reduziu o próximo dano recebido")
				elif effect.has("missed_reach"):
					outcomes.append("não alcançou o alvo")
			var outcome_text := "." if outcomes.is_empty() else " e %s." % ", ".join(outcomes)
			var outcome_tone := "text"
			if not details.get("success", true) or "não foi dessa vez" in outcomes:
				outcome_tone = "negative"
			elif not outcomes.is_empty():
				outcome_tone = "negative" if _tone(actor) == "hostile" else "positive"
			var skill_parts: Array = [actor_part, _seg(" usou "), _seg(skill_name, "skill")]
			if target != null and target != actor:
				skill_parts.append(_seg(" em "))
				skill_parts.append(_seg(_name(target), _tone(target)))
			skill_parts.append(_seg(outcome_text if details.get("success", true) else
					", mas não obteve efeito.", outcome_tone))
			_record(action, skill_parts, actor, {"skill_id": str(used_skill.id) if used_skill != null else "",
					"target_id": str(target.instance_id) if target != null else "",
					"damage": skill_damage})
		&"trap":
			var trap := details.get("event") as EventData
			_record(action, [actor_part, _seg(" ativou a armadilha "),
				_seg(trap.display_name if trap != null else "desconhecida", "negative"),
				_seg(".")], actor)


func _on_combat_finished(result: Dictionary) -> void:
	var won := str(result.get("reason", "")) == "victory"
	_record(&"combat_finished", [_seg("O grupo "),
		_seg("venceu" if won else "perdeu", "positive" if won else "negative"),
		_seg(" o Encontro Indesejado: "),
		_seg(_last_encounter_name if not _last_encounter_name.is_empty() else "desconhecido", "event"),
		_seg(".")])
	_last_encounter_name = ""


func _on_event_result(context: Dictionary, result: Dictionary) -> void:
	var event := context.get("resource") as EventData
	if event == null:
		return
	var actor := context.get("actor") as EntityState
	var parts: Array = [_seg(_name(actor), "actor"), _seg(" ativou o Evento "),
		_seg(event.display_name, "event")]
	if not bool(result.get("accepted", true)):
		parts.append(_seg(". Recusou.", "negative"))
	else:
		var decision: Dictionary = context.get("decision", {})
		var selected_item := decision.get("selected_catalog_item") as ItemData
		if selected_item != null:
			parts.append(_seg(". Escolheu "))
			parts.append(_seg(selected_item.display_name, "item"))
			parts.append(_seg("."))
		elif event.resolution_mode == EventData.ResolutionMode.PLAYER_CHOOSES_OUTCOME \
				and not str(result.get("outcome_name", "")).is_empty():
			parts.append(_seg(". Escolheu "))
			parts.append(_seg(str(result["outcome_name"]), "event"))
			parts.append(_seg("."))
		elif event.resolution_mode == EventData.ResolutionMode.PLAYER_ACCEPTS_THEN_OUTCOME:
			parts.append(_seg(". Aceitou."))
		else:
			parts.append(_seg("."))
		var effect_phrases := _event_effect_phrases(result, selected_item != null)
		if effect_phrases.is_empty():
			var narrative := str(result.get("narrative", "")).strip_edges()
			if not narrative.is_empty():
				parts.append(_seg(" " + narrative, "text"))
		else:
			for phrase in effect_phrases:
				parts.append(_seg(" " + str(phrase["text"]), str(phrase["tone"])))
	_record(&"event_outcome", parts, actor, {"event_id": str(event.id),
		"outcome_id": str(result.get("outcome_id", ""))})


func _event_effect_phrases(result: Dictionary, chosen_catalog_item: bool) -> Array[Dictionary]:
	var phrases: Array[Dictionary] = []
	for value in result.get("effects", []):
		if not value is Dictionary:
			continue
		var effect := value as Dictionary
		if not bool(effect.get("success", true)):
			continue
		var kind := int(effect.get("effect", -1))
		if effect.has("before") and effect.has("after"):
			var delta := int(effect["after"]) - int(effect["before"])
			if delta == 0:
				continue
			var attribute := ""
			match kind:
				Event_EffectData.EffectType.MODIFY_HP: attribute = "Vida"
				Event_EffectData.EffectType.MODIFY_MAX_HP: attribute = "Vida máxima"
				Event_EffectData.EffectType.MODIFY_STAT:
					match int(effect.get("statistic", -1)):
						Event_EffectData.Statistic.HP: attribute = "Vida"
						Event_EffectData.Statistic.MAX_HP: attribute = "Vida máxima"
						Event_EffectData.Statistic.ATTACK: attribute = "Ataque"
						Event_EffectData.Statistic.STAMINA: attribute = "Estamina máxima"
			if not attribute.is_empty():
				var verb := "Recuperou" if attribute == "Vida" else "Ganhou"
				if delta < 0:
					verb = "Perdeu"
				phrases.append({"text": "%s %d de %s." % [verb, abs(delta), attribute],
					"tone": "positive" if delta > 0 else "negative"})
				continue
		if kind == Event_EffectData.EffectType.CUSTOM and effect.has("bonus"):
			var attribute := "Ataque" if str(effect.get("statistic", "")) == "attack" else "Vida máxima"
			phrases.append({"text": "Ganhou %d de %s por um dia." % [
				int(effect["bonus"]), attribute], "tone": "positive"})
			if effect.has("immunity"):
				var protected_status := "Doença" if str(effect["immunity"]) == "disease" else "Terror"
				phrases.append({"text": "Ficou imune a %s por um dia." % protected_status,
					"tone": "positive"})
			continue
		if effect.get("temple_blessing_nullified", false):
			phrases.append({"text": "O dia de hoje está abençoado: a maldição foi anulada.",
				"tone": "positive"})
			continue
		if kind in [Event_EffectData.EffectType.GRANT_ITEM,
				Event_EffectData.EffectType.GRANT_RANDOM_ITEM] \
				and not chosen_catalog_item and effect.has("item_name"):
			phrases.append({"text": "Recebeu %s." % str(effect["item_name"]),
				"tone": "positive"})
	return phrases


func _on_terminal(status: int, _information_count: int) -> void:
	# Vitória por Informação emite o sinal antes de information_granted. A
	# GerenciaJogo anota a conclusão após a Informação para manter a cronologia.
	if status == CampaignState.CampaignStatus.VICTORY:
		return
	_record(&"campaign_terminal", [_seg("A campanha terminou em "),
		_seg("derrota", "negative"),
		_seg(".")])


func _on_playable_death(actor: EntityState,
		_leftover: Array[InventoryItemState]) -> void:
	if actor != null:
		_record(&"playable_death", [_seg(_name(actor), "actor"),
			_seg(" morreu.", "negative")], actor)
		_deaths_logged[actor.instance_id] = true
		if _pending_promotions.has(actor.instance_id):
			_record_promotion(actor, _pending_promotions[actor.instance_id] as EntityState)
			_pending_promotions.erase(actor.instance_id)


func _on_playable_slot_replaced(previous: EntityState,
		replacement: EntityState) -> void:
	if replacement == null:
		return
	if previous == replacement:
		_record(&"resurrection", [_seg(_name(replacement), "actor"),
			_seg(" ressuscitou.", "positive")], replacement)
	else:
		if previous != null and previous in gerencia.campaign.dead_playable_states \
				and not _death_was_logged(previous):
			_pending_promotions[previous.instance_id] = replacement
		else:
			_record_promotion(previous, replacement)


func _death_was_logged(actor: EntityState) -> bool:
	if _deaths_logged.has(actor.instance_id):
		return true
	for entry in gerencia.campaign.journal_entries:
		if str(entry.get("action_id", "")) == "playable_death" \
				and str(entry.get("actor_id", "")) == str(actor.instance_id):
			return true
	return false


func _record_promotion(previous: EntityState, replacement: EntityState) -> void:
	_record(&"promotion", [_seg(_name(replacement), "actor"),
		_seg(" foi promovido a personagem jogável.", "positive")], replacement,
		{"previous_id": str(previous.instance_id) if previous != null else ""})


func _on_companion_registered(companion: EntityState) -> void:
	if companion == null:
		return
	var owner := gerencia.campaign.get_playable_slot(companion.owner_instance_id)
	if gerencia.campaign._resurrecting_companion == companion:
		var revived_parts: Array = []
		if owner != null:
			revived_parts.append(_seg(_name(owner), "actor"))
			revived_parts.append(_seg(" ressuscitou "))
		else:
			revived_parts.append(_seg("O grupo ressuscitou "))
		revived_parts.append(_seg(_name(companion), "actor"))
		revived_parts.append(_seg(" como aliado.", "positive"))
		_record(&"resurrection", revived_parts, owner,
			{"companion_id": str(companion.instance_id)})
		return
	var parts: Array = []
	if owner != null:
		parts.append(_seg(_name(owner), "actor"))
		parts.append(_seg(" recrutou "))
	else:
		parts.append(_seg("O grupo recrutou "))
	parts.append(_seg(_name(companion), "actor"))
	parts.append(_seg(" como aliado.", "positive"))
	_record(&"recruitment", parts, owner,
		{"companion_id": str(companion.instance_id),
		"entity_id": str(companion.data.id) if companion.data != null else ""})
