class_name EntityStatBreakdown
extends RefCounted

## A mesma decomposição é usada em todo lugar que mostra Vida, Ataque ou
## Estamina. Fontes conhecidas ganham nome; alterações sem origem rastreada
## aparecem honestamente como Bônus/Penalidade, nunca como item inventado.

static func parts(actor: EntityState, stat_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if actor == null or actor.data == null:
		return result
	var base := 0
	var current := 0
	match stat_key:
		"max_hp":
			base = actor.data.vida_base
			current = actor.max_health
		"attack":
			base = actor.data.ataque_base
			current = actor.attack
		"stamina":
			base = actor.data.stamina_base
			current = actor.max_stamina
		_:
			return result
	result.append({"value": base, "label": "base", "temporary": false})
	var accounted := base
	# Bônus numéricos do ItemData só existem enquanto a cópia está equipada.
	# Identificá-los aqui evita chamar uma arma de "bônus desconhecido".
	for slot in [ItemData.EquipmentSlot.WEAPON, ItemData.EquipmentSlot.ARMOR,
			ItemData.EquipmentSlot.ACCESSORY]:
		for copy in actor.equipped_in_slot(slot):
			if copy == null or copy.data == null:
				continue
			var item := copy.data
			var amount := 0
			match stat_key:
				"max_hp": amount = item.bonus_life
				"attack": amount = item.bonus_attack
				"stamina": amount = item.bonus_stamina
			if amount != 0:
				result.append({"value": amount, "label": item.display_name,
					"temporary": true})
				accounted += amount
			if stat_key == "attack" and item.mastery_granted != EntityData.Mastery.NONE \
					and item.mastery_granted in actor.data.maestrias \
					and item.mastery_bonus > 0:
				result.append({"value": item.mastery_bonus,
					"label": "%s · Maestria correspondente" % item.display_name,
					"temporary": true})
				accounted += item.mastery_bonus
	for grant in actor.skill_grants:
		if grant == null:
			continue
		var amount := int(grant.applied_stat_contributions.get(stat_key, 0))
		if amount == 0:
			continue
		var source: String = "habilidade"
		if grant.skill is ActiveSkillData:
			source = (grant.skill as ActiveSkillData).display_name
		elif grant.skill is PassiveSkillData:
			source = (grant.skill as PassiveSkillData).display_name
		if grant.bound_source is ItemData:
			source = (grant.bound_source as ItemData).display_name
		result.append({"value": amount, "label": source,
			"temporary": grant.source_kind in [&"item", &"equipment", &"temporary"]})
		accounted += amount
	for instance in actor.debuffs:
		if instance == null:
			continue
		var amount := 0
		match stat_key:
			"max_hp": amount = instance.applied_max_health_delta - instance.accrued_max_health_loss
			"attack": amount = instance.applied_attack_delta
			"stamina": amount = instance.applied_stamina_delta
		if amount == 0:
			continue
		result.append({"value": amount, "label": instance.data.display_name \
			if instance.data != null else "penalidade",
			"temporary": instance.duration_kind != DebuffData.DurationType.PERMANENT})
		accounted += amount
	for record in actor.consumable_timed_modifiers:
		if String(record.get("attribute_id", "")) != stat_key:
			continue
		var amount := int(record.get("amount", 0))
		if amount != 0:
			result.append({"value": amount, "label": str(record.get("source", "consumível")),
				"temporary": true})
			accounted += amount
	if stat_key == "stamina" and actor.round_stamina_penalty != 0:
		result.append({"value": -actor.round_stamina_penalty,
			"label": "Rodada", "temporary": true})
		accounted -= actor.round_stamina_penalty
	var other := current - accounted
	if other != 0:
		# Alterações diretas atuais sem prazo são permanentes. Quando um
		# executor temporário surgir, ele deve registrar sua fonte como acima.
		result.append({"value": other,
			"label": "bônus" if other > 0 else "penalidade",
			"temporary": false})
	# A leitura humana fica: base, acréscimos e por fim reduções.
	var ordered: Array[Dictionary] = [result[0]]
	for index in range(1, result.size()):
		if int(result[index]["value"]) > 0:
			ordered.append(result[index])
	for index in range(1, result.size()):
		if int(result[index]["value"]) < 0:
			ordered.append(result[index])
	return ordered


static func colored_text(actor: EntityState, stat_key: String) -> String:
	var values := parts(actor, stat_key)
	if values.is_empty():
		return ""
	var title := "VIDA MÁXIMA" if stat_key == "max_hp" else \
		("ATAQUE" if stat_key == "attack" else "ESTAMINA MÁXIMA")
	var text := "[b]%s[/b]\n" % title
	for index in values.size():
		var entry := values[index]
		var amount := int(entry["value"])
		var label := String(entry["label"]).replace("[", "(").replace("]", ")")
		if index == 0:
			text += "%d %s" % [amount, label]
		elif amount > 0:
			var positive_period := "temporário" if entry["temporary"] else "permanente"
			var positive_name := "bônus %s" % positive_period if label == "bônus" \
				else "%s (bônus %s)" % [label, positive_period]
			text += "\n[color=#65df86]+ %d %s[/color]" % [amount, positive_name]
		else:
			var negative_period := "temporária" if entry["temporary"] else "permanente"
			var negative_name := "penalidade %s" % negative_period if label == "penalidade" \
				else "%s (penalidade %s)" % [label, negative_period]
			text += "\n[color=#ff6678]- %d %s[/color]" % [-amount, negative_name]
	return text
