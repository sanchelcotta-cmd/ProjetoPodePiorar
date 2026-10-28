class_name InventoryManager
extends RefCounted

## Operações de cópias concretas no inventário. Nunca modifica ItemData.

signal recipient_choice_requested(item: ItemData, options: Array[EntityState])
signal item_delivered(recipient: EntityState, item: ItemData)
signal item_lost(item: ItemData)
signal item_transferred(source: EntityState, recipient: EntityState, item: InventoryItemState)

const ITEM_DIRECTORY := "res://resources/itens"

var _pending_deliveries: Array[Dictionary] = []
var campaign: CampaignState


## Catálogo de início: só cópias Comuns, sem Maldições, sem Raros.
## A inclusão é por tipo/raridade, para novos .tres entrarem sem alterar código.
func get_common_starting_items(item_type: ItemData.ItemType) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for path in _item_paths(ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"" or item.rarity != ItemData.Rarity.COMMON \
				or item.item_type != item_type or item.inventory_space != 1 \
				or &"cursed" in item.tags:
			continue
		if item_type == ItemData.ItemType.EQUIPMENT \
				and item.equipment_slot == ItemData.EquipmentSlot.NONE:
			continue
		result.append(item)
	return result


## A criação da campanha precisa dos dois tipos. Uma única varredura evita
## carregar e validar todos os Resources de itens duas vezes no mesmo quadro.
func get_common_starting_catalog() -> Dictionary:
	var equipment: Array[ItemData] = []
	var consumables: Array[ItemData] = []
	for path in _item_paths(ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"" or item.rarity != ItemData.Rarity.COMMON \
				or item.inventory_space != 1 or &"cursed" in item.tags:
			continue
		if item.item_type == ItemData.ItemType.EQUIPMENT \
				and item.equipment_slot != ItemData.EquipmentSlot.NONE:
			equipment.append(item)
		elif item.item_type == ItemData.ItemType.CONSUMABLE:
			consumables.append(item)
	return {"equipment": equipment, "consumables": consumables}


func get_equipment_by_rarity(rarity: ItemData.Rarity,
		slot: ItemData.EquipmentSlot) -> Array[ItemData]:
	var result: Array[ItemData] = []
	for path in _item_paths(ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item != null and item.id != &"" \
				and item.item_type == ItemData.ItemType.EQUIPMENT \
				and item.rarity == rarity and item.equipment_slot == slot \
				and &"cursed" not in item.tags:
			result.append(item)
	return result


## Só remédios puros podem ser entregues a aliados. Um alimento que também
## cura Vida ou altera atributos não vira remédio por ter efeito secundário.
func is_ally_debuff_remedy(item: ItemData) -> bool:
	if item == null or item.item_type != ItemData.ItemType.CONSUMABLE \
			or item.use_effects.is_empty():
		return false
	for effect in item.use_effects:
		if effect == null or effect.effect_type != SkillEffectData.EffectType.REMOVE_DEBUFF \
				or effect.debuff_id == &"":
			return false
	return true


func can_remedy_ally(item: ItemData, companion: EntityState) -> bool:
	if not is_ally_debuff_remedy(item) or companion == null \
			or companion.current_health <= 0:
		return false
	for effect in item.use_effects:
		for instance in companion.debuffs:
			if instance != null and instance.data != null \
					and instance.data.id == effect.debuff_id:
				return true
	return false


## Grade física com espaços vazios. Itens de mais de um espaço ocupam posições
## contíguas; entradas recém-recebidas entram no primeiro vão que comporta.
static func inventory_layout(owner: EntityState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if owner == null:
		return result
	result.resize(owner.inventory_capacity())
	for index in result.size():
		result[index] = {}
	var pending: Array[InventoryItemState] = []
	for entry in owner.inventory_items:
		if entry == null or entry.data == null:
			continue
		if entry.inventory_slot_index < 0 or not _fits_layout(result,
				entry.inventory_slot_index, entry.data.inventory_space):
			pending.append(entry)
		else:
			_place_in_layout(result, entry, entry.inventory_slot_index)
	for entry in pending:
		var first_free := _first_fit(result, entry.data.inventory_space)
		if first_free < 0:
			# Fragmentação: compactar antes de perder acesso visual ao item.
			return _compact_layout(owner)
		entry.inventory_slot_index = first_free
		_place_in_layout(result, entry, first_free)
	return result


static func _fits_layout(layout: Array[Dictionary], start: int, width: int) -> bool:
	if start < 0 or start + maxi(1, width) > layout.size():
		return false
	for index in range(start, start + maxi(1, width)):
		if not layout[index].is_empty():
			return false
	return true


static func _first_fit(layout: Array[Dictionary], width: int) -> int:
	for index in layout.size():
		if _fits_layout(layout, index, width):
			return index
	return -1


static func _place_in_layout(layout: Array[Dictionary], entry: InventoryItemState,
		start: int) -> void:
	for offset in maxi(1, entry.data.inventory_space):
		layout[start + offset] = {"entry": entry, "first": offset == 0}


static func _compact_layout(owner: EntityState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.resize(owner.inventory_capacity())
	for index in result.size():
		result[index] = {}
	var cursor := 0
	for entry in owner.inventory_items:
		if entry == null or entry.data == null:
			continue
		if cursor + maxi(1, entry.data.inventory_space) > result.size():
			break
		entry.inventory_slot_index = cursor
		_place_in_layout(result, entry, cursor)
		cursor += maxi(1, entry.data.inventory_space)
	return result


## Inserir num slot ocupado empurra os seguintes na ordem direita → baixo.
## Se a grade estiver cheia, compacta usando o espaço liberado pela origem.
static func reorder_item_to_slot(owner: EntityState, entry: InventoryItemState,
		slot_index: int) -> bool:
	if owner == null or entry == null or entry not in owner.inventory_items \
			or slot_index < 0 or slot_index >= owner.inventory_capacity():
		return false
	var layout := inventory_layout(owner)
	owner.inventory_items.sort_custom(func(a: InventoryItemState,
			b: InventoryItemState) -> bool:
		return a.inventory_slot_index < b.inventory_slot_index)
	if layout[slot_index].get("entry") == entry:
		return false
	var source_start := entry.inventory_slot_index
	var source_width := maxi(1, entry.data.inventory_space)
	for offset in source_width:
		layout[source_start + offset] = {}
	var displaced: Array[InventoryItemState] = []
	var displaced_seen := {}
	for index in range(slot_index, layout.size()):
		var other := layout[index].get("entry") as InventoryItemState
		if other != null and not displaced_seen.has(other):
			displaced.append(other)
			displaced_seen[other] = true
	var occupied_target := layout[slot_index].get("entry") as InventoryItemState
	if occupied_target != null:
		slot_index = occupied_target.inventory_slot_index
	var cursor := slot_index + source_width
	for other in displaced:
		cursor += maxi(1, other.data.inventory_space)
	if cursor > layout.size():
		# Cheio: insertion estável, sem tentar criar um décimo terceiro slot.
		var target_entry := occupied_target
		var target_index := owner.inventory_items.find(target_entry) \
			if target_entry != null else owner.inventory_items.size()
		owner.inventory_items.erase(entry)
		owner.inventory_items.insert(mini(target_index, owner.inventory_items.size()), entry)
		_compact_layout(owner)
		return true
	for other in displaced:
		for offset in maxi(1, other.data.inventory_space):
			layout[other.inventory_slot_index + offset] = {}
	entry.inventory_slot_index = slot_index
	_place_in_layout(layout, entry, slot_index)
	cursor = slot_index + source_width
	for other in displaced:
		other.inventory_slot_index = cursor
		_place_in_layout(layout, other, cursor)
		cursor += maxi(1, other.data.inventory_space)
	owner.inventory_items.sort_custom(func(a: InventoryItemState,
			b: InventoryItemState) -> bool:
		return a.inventory_slot_index < b.inventory_slot_index)
	return true


## 0: tipo; 1: nome; 2: aquisição antiga primeiro; 3: recente primeiro.
static func sort_inventory(owner: EntityState, mode: int) -> bool:
	if owner == null or mode < 0 or mode > 3:
		return false
	owner.inventory_items.sort_custom(func(a: InventoryItemState,
			b: InventoryItemState) -> bool:
		if a == null or a.data == null:
			return false
		if b == null or b.data == null:
			return true
		match mode:
			0:
				var a_key := _type_sort_key(a.data)
				var b_key := _type_sort_key(b.data)
				if a_key != b_key:
					return a_key < b_key
				var a_name := a.data.display_name.naturalnocasecmp_to(b.data.display_name)
				if a_name != 0:
					return a_name < 0
			1:
				var compared := a.data.display_name.naturalnocasecmp_to(b.data.display_name)
				if compared != 0:
					return compared < 0
			2:
				return a.acquisition_order < b.acquisition_order
			3:
				return a.acquisition_order > b.acquisition_order
		return a.acquisition_order < b.acquisition_order)
	_compact_layout(owner)
	return true


static func _type_sort_key(item: ItemData) -> int:
	if item.item_type == ItemData.ItemType.CURSED:
		return 0
	if item.item_type == ItemData.ItemType.CONSUMABLE:
		return 10 + item.rarity
	match item.equipment_slot:
		ItemData.EquipmentSlot.WEAPON: return 20
		ItemData.EquipmentSlot.ARMOR: return 30
		ItemData.EquipmentSlot.ACCESSORY: return 40
	return 50


func can_receive(recipient: EntityState, item: ItemData) -> bool:
	if recipient == null or item == null or recipient.current_health <= 0 \
			or recipient.owner_instance_id != &"":
		return false
	if campaign != null and campaign.has_sacred_temple_blessing() \
			and CampaignState.is_cursed_item(item):
		return true
	if recipient.is_curse_immune() and CampaignState.is_cursed_item(item):
		return true
	return recipient.inventory_used_space() + item.inventory_space <= recipient.inventory_capacity()


func add_item(recipient: EntityState, item: ItemData) -> bool:
	if not can_receive(recipient, item):
		return false
	# Recebimento consumado, porém a bênção destrói a cópia antes de entrar
	# no inventário. Não emite item_delivered nem aplica maldição.
	if campaign != null and campaign.has_sacred_temple_blessing() \
			and CampaignState.is_cursed_item(item):
		return true
	if recipient.is_curse_immune() and CampaignState.is_cursed_item(item):
		return true
	recipient.inventory_items.append(InventoryItemState.new(item))
	item_delivered.emit(recipient, item)
	return true


## Recebimento atômico usado por recompensas com inventário cheio. Se um
## remanejamento liberar espaço, outgoing pode ficar vazio. Nenhuma cópia
## é descartada até o jogador confirmar explicitamente a lista exibida.
func can_exchange_items(owner: EntityState, outgoing: Array[InventoryItemState],
		incoming: ItemData) -> bool:
	if owner == null or incoming == null or owner.current_health <= 0:
		return false
	var freed := 0
	var seen: Dictionary = {}
	for entry in outgoing:
		if entry == null or entry.data == null or entry not in owner.inventory_items \
				or not entry.data.can_be_discarded \
				or entry.data.item_type == ItemData.ItemType.CURSED \
				or seen.has(entry.get_instance_id()):
			return false
		seen[entry.get_instance_id()] = true
		freed += maxi(1, entry.data.inventory_space)
	return owner.inventory_used_space() - freed + maxi(1, incoming.inventory_space) \
		<= owner.inventory_capacity()


func exchange_items(owner: EntityState, outgoing: Array[InventoryItemState],
		incoming: ItemData) -> bool:
	if not can_exchange_items(owner, outgoing, incoming):
		return false
	for entry in outgoing:
		owner.inventory_items.erase(entry)
	if not add_item(owner, incoming):
		owner.inventory_items.append_array(outgoing)
		return false
	for entry in outgoing:
		item_lost.emit(entry.data)
	return true


## Descarta uma cópia concreta escolhida pelo jogador. Maldições e itens
## marcados como não descartáveis nunca saem por este caminho.
func discard_item(owner: EntityState, entry: InventoryItemState,
		campaign: CampaignState = null) -> bool:
	if owner == null or entry == null or entry.data == null \
			or entry not in owner.inventory_items \
			or not entry.data.can_be_discarded \
			or entry.data.item_type == ItemData.ItemType.CURSED:
		return false
	owner.inventory_items.erase(entry)
	item_lost.emit(entry.data)
	return true


## Move a própria cópia, com seus estados, entre os três jogáveis. Não cria
## outra cópia nem apaga atributos como "apodrecido". Maldição não troca de dono.
func transfer_item(source: EntityState, recipient: EntityState, entry: InventoryItemState,
		campaign: CampaignState, allow_dead_source: bool = false) -> bool:
	if source == null or recipient == null or entry == null or entry.data == null \
			or campaign == null or source == recipient \
			or (source not in campaign.active_entity_states \
				and not (allow_dead_source and source in campaign.dead_playable_states)) \
			or recipient not in campaign.active_entity_states \
			or entry not in source.inventory_items \
			or entry.data.item_type == ItemData.ItemType.CURSED \
			or not can_receive(recipient, entry.data):
		return false
	source.inventory_items.erase(entry)
	entry.inventory_slot_index = -1
	recipient.inventory_items.append(entry)
	item_transferred.emit(source, recipient, entry)
	return true


## Consome apenas efeitos cuja aplicação completa já está implementada.
## A checagem vem ANTES de qualquer mudança: um efeito novo ainda sem motor
## não pode gastar o item e entregar só parte do resultado.
func use_consumable(owner: EntityState, entry: InventoryItemState,
		skill_manager: SkillManager, campaign: CampaignState,
		selected_curse: InventoryItemState = null,
		recipient: EntityState = null,
		combat: CombatManager = null) -> Dictionary:
	if owner == null or owner.current_health <= 0 or entry == null or entry.data == null or skill_manager == null \
			or campaign == null or entry not in owner.inventory_items \
			or entry.data.item_type != ItemData.ItemType.CONSUMABLE:
		return {"success": false, "reason": "Consumível indisponível."}
	if not skill_manager.debuff_manager.can_use_consumable(owner):
		return {"success": false, "reason": "Este personagem não pode usar consumíveis agora."}
	var target := recipient if recipient != null else owner
	var health_before := target.current_health
	if target != owner:
		if owner not in campaign.active_entity_states \
				or target not in campaign.companion_states \
				or not can_remedy_ally(entry.data, target):
			return {"success": false,
				"reason": "Apenas remédios puros podem ser dados a aliados com o debuff correspondente."}
	for state in entry.states:
		if state != null and state.id == &"apodrecido":
			return {"success": false, "reason": "Este consumível apodreceu."}
	var effects := _chosen_use_effects(entry.data.use_effects, campaign.world_rng)
	if effects.is_empty():
		return {"success": false, "reason": "Este item ainda não tem efeito utilizável."}
	for effect in effects:
		if not _supports_use_effect(effect, owner, selected_curse):
			return {"success": false,
				"reason": "Este efeito ainda precisa de execução própria antes do consumo."}
	if skill_manager.catastrophe_manager != null \
			and not skill_manager.catastrophe_manager.before_action(owner):
		return {"success": false, "reason": "A catástrofe impediu esta ação."}
	var chance_results: Array[String] = []
	var journal_effects: Array[Dictionary] = []
	for effect in effects:
		if target == owner and effect.activation_chance < 1.0 \
				and campaign.world_rng.randf() >= effect.activation_chance:
			if not _is_negative_chance_effect(effect):
				chance_results.append("Não foi dessa vez.")
				journal_effects.append({"text": "não foi dessa vez", "tone": "negative"})
			else:
				journal_effects.append({"text": "não causou alteração", "tone": "text"})
			continue
		var chance_applied := target == owner and (effect.activation_chance < 1.0 \
			or effect.random_choice_group != &"")
		match effect.effect_type:
			SkillEffectData.EffectType.HEAL_FIXED:
				var health_before_effect := target.current_health
				var targets: Array[EntityState] = [target]
				if effect.target == SkillEffectData.Target.ALL_ALLIES:
					targets.assign(campaign.active_entity_states)
					targets.append_array(campaign.companion_states)
				for healed in targets:
					if healed == null or healed.current_health <= 0:
						continue
					var restored := effect.amount
					if effect.percent > 0.0:
						restored = ceili(healed.max_health * effect.percent)
					restored = maxi(0, restored + skill_manager.debuff_manager.consumable_modifier(healed))
					healed.current_health = mini(healed.max_health, healed.current_health + restored)
				if chance_applied and target.current_health > health_before_effect:
					chance_results.append("Recuperou %d de Vida." % (target.current_health - health_before_effect))
			SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
				# Oferecer comida não transmite seus efeitos negativos/debuffs ao
				# companheiro; a cópia consumida ainda pertence ao jogável.
				if target != owner and effect.modify_mode == SkillEffectData.ModifyMode.SUBTRACT:
					continue
				var delta := effect.amount
				if effect.modify_mode == SkillEffectData.ModifyMode.SUBTRACT:
					delta = -delta
				var actual := _change_attribute(target, effect.attribute_id, delta)
				if effect.duration_turns > 0 and actual != 0:
					target.consumable_timed_modifiers.append({
						"attribute_id": effect.attribute_id,
						"amount": actual,
						"source": entry.data.display_name,
						"expires_at": target.turn_serial + effect.duration_turns})
				if chance_applied and actual != 0:
					var duration := " por %d %s" % [effect.duration_turns,
						"turno" if effect.duration_turns == 1 else "turnos"] \
						if effect.duration_turns > 0 else " permanentemente"
					var attribute_name := _chance_attribute_name(effect.attribute_id)
					var gender_suffix := "o" if effect.attribute_id == &"attack" else "a"
					if actual < 0:
						chance_results.append("Algo não caiu bem. Agora %s foi reduzid%s em %d%s." % [
							attribute_name, gender_suffix, -actual, duration])
					else:
						chance_results.append("%s aumentad%s em %d%s." % [
							attribute_name, gender_suffix, actual, duration])
				if actual != 0 and not (effect.attribute_id == &"hp" and actual > 0):
					var attribute_name := _chance_attribute_name(effect.attribute_id)
					var time_text := " por %d %s" % [effect.duration_turns,
						"turno" if effect.duration_turns == 1 else "turnos"] \
						if effect.duration_turns > 0 else ""
					journal_effects.append({"text": "%s %s em %d%s" % [attribute_name,
						"diminuiu" if actual < 0 else "aumentou", abs(actual), time_text],
						"tone": "negative" if actual < 0 else "positive"})
			SkillEffectData.EffectType.REMOVE_DEBUFF:
				if target == owner and effect.percent > 0.0 and effect.percent < 1.0 \
						and campaign.world_rng.randf() >= effect.percent:
					chance_results.append("Não foi dessa vez.")
					journal_effects.append({"text": "não foi dessa vez", "tone": "negative"})
					continue
				var removed := skill_manager.debuff_manager.remove_debuff(target, effect.debuff_id)
				if target == owner and effect.percent > 0.0 and effect.percent < 1.0:
					var debuff := skill_manager.debuff_manager.find_debuff(effect.debuff_id)
					var name := debuff.display_name if debuff != null else String(effect.debuff_id)
					if removed:
						chance_results.append("Debuff %s removido." % name)
				if removed:
					var debuff := skill_manager.debuff_manager.find_debuff(effect.debuff_id)
					journal_effects.append({"text": "removeu %s" % (
						debuff.display_name if debuff != null else String(effect.debuff_id)),
						"tone": "positive"})
			SkillEffectData.EffectType.REMOVE_INVENTORY_ITEMS:
				journal_effects.append({"text": "removeu a maldição %s" %
					selected_curse.data.display_name, "tone": "positive"})
				owner.inventory_items.erase(selected_curse)
				item_lost.emit(selected_curse.data)
	if entry.data.consumed_on_use:
		owner.inventory_items.erase(entry)
		item_lost.emit(entry.data)
	var mode := campaign.current_map.ppp_map_mode if campaign.current_map != null \
		else HexGrid.PPPMapMode.EXPLORATION
	var combat_id := &""
	var combat_turn_number := 0
	if mode == HexGrid.PPPMapMode.COMBAT and combat != null \
			and combat._combat_id != &"":
		combat_id = combat._combat_id
		combat_turn_number = int(combat._combat_turns_by_id.get(owner.instance_id, 0))
		if combat.current_actor != owner:
			combat_turn_number += 1
	var before_extra := owner.extra_attacks_this_turn
	skill_manager.on_item_consumed(owner, entry.data, campaign, mode,
		combat_id, combat_turn_number)
	if combat_id != &"" and combat.current_actor != owner:
		var granted := owner.extra_attacks_this_turn - before_extra
		if granted > 0:
			owner.extra_attacks_this_turn = before_extra
			owner.extra_attacks_next_turn = maxi(owner.extra_attacks_next_turn, granted)
	var journal_parts: Array = [
		{"text": owner.visible_name(), "tone": "actor"},
		{"text": " consumiu ", "tone": "text"},
		{"text": entry.data.display_name, "tone": "item"},
	]
	if target != owner:
		journal_parts.append({"text": " em ", "tone": "text"})
		journal_parts.append({"text": target.visible_name(), "tone": "actor"})
	var healed := maxi(0, target.current_health - health_before)
	if healed > 0:
		journal_parts.append({"text": " e recuperou %d de Vida" % healed,
			"tone": "positive"})
	for effect_result in journal_effects:
		journal_parts.append({"text": "; " + str(effect_result["text"]),
			"tone": str(effect_result["tone"])})
	journal_parts.append({"text": ".", "tone": "text"})
	campaign.append_journal_entry(&"consume_item", journal_parts, owner.instance_id,
		{"item_id": str(entry.data.id), "target_id": str(target.instance_id),
			"healed": healed})
	return {"success": true, "chance_results": chance_results}


func _is_negative_chance_effect(effect: SkillEffectData) -> bool:
	if effect.effect_type != SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
		return false
	var delta := -effect.amount if effect.modify_mode == SkillEffectData.ModifyMode.SUBTRACT \
		else effect.amount
	return delta < 0


func _chance_attribute_name(attribute_id: StringName) -> String:
	match attribute_id:
		&"hp": return "sua Vida"
		&"max_hp": return "sua Vida máxima"
		&"attack": return "seu Ataque"
		&"stamina": return "sua Estamina"
	return "seu atributo"


func _supports_use_effect(effect: SkillEffectData, owner: EntityState,
		selected_curse: InventoryItemState) -> bool:
	if effect == null or effect.target not in [SkillEffectData.Target.SELF,
			SkillEffectData.Target.ALL_ALLIES]:
		return false
	match effect.effect_type:
		SkillEffectData.EffectType.HEAL_FIXED:
			return effect.amount > 0 or effect.percent > 0.0
		SkillEffectData.EffectType.MODIFY_ATTRIBUTE:
			return effect.attribute_id in \
				[&"hp", &"max_hp", &"attack", &"stamina"] and effect.modify_mode in \
				[SkillEffectData.ModifyMode.ADD, SkillEffectData.ModifyMode.SUBTRACT] \
				and (effect.duration_turns == 0 or effect.attribute_id in [&"attack", &"stamina"])
		SkillEffectData.EffectType.REMOVE_DEBUFF:
			return effect.debuff_id != &""
		SkillEffectData.EffectType.REMOVE_INVENTORY_ITEMS:
			return selected_curse != null and selected_curse in owner.inventory_items \
				and selected_curse.data != null \
				and selected_curse.data.item_type == ItemData.ItemType.CURSED
	return false


## Executado uma vez no começo de cada turno verdadeiro, após turn_serial
## avançar. Um bônus de 1 turno usado agora desaparece no próximo turno.
func expire_timed_consumables(actor: EntityState) -> void:
	if actor == null:
		return
	for index in range(actor.consumable_timed_modifiers.size() - 1, -1, -1):
		var record := actor.consumable_timed_modifiers[index]
		if actor.turn_serial < int(record["expires_at"]):
			continue
		_change_attribute(actor, record["attribute_id"], -int(record["amount"]))
		actor.consumable_timed_modifiers.remove_at(index)


func _change_attribute(actor: EntityState, attribute_id: StringName, delta: int) -> int:
	var before := 0
	match attribute_id:
		&"hp":
			before = actor.current_health
			actor.current_health = clampi(before + delta, 0, actor.max_health)
			return actor.current_health - before
		&"max_hp":
			before = actor.max_health
			actor.max_health = maxi(1, before + delta)
			actor.current_health = mini(actor.current_health, actor.max_health)
			return actor.max_health - before
		&"attack":
			before = actor.attack
			actor.attack = maxi(0, before + delta)
			return actor.attack - before
		&"stamina":
			before = actor.max_stamina
			actor.max_stamina = maxi(0, before + delta)
			actor.stamina_remaining = clampi(actor.stamina_remaining + delta, 0, actor.max_stamina)
			return actor.max_stamina - before
	return 0


func _chosen_use_effects(all_effects: Array[SkillEffectData],
		rng: RandomNumberGenerator = null) -> Array[SkillEffectData]:
	var chosen: Array[SkillEffectData] = []
	var groups: Dictionary = {}
	for effect in all_effects:
		if effect == null:
			continue
		if effect.random_choice_group == &"":
			chosen.append(effect)
		else:
			if not groups.has(effect.random_choice_group):
				groups[effect.random_choice_group] = []
			groups[effect.random_choice_group].append(effect)
	for group in groups.values():
		var total := 0
		for option in group:
			total += option.random_choice_weight
		var draw := rng.randi_range(1, total) if rng != null else randi_range(1, total)
		for option in group:
			draw -= option.random_choice_weight
			if draw <= 0:
				chosen.append(option)
				break
	return chosen


## Na passagem Noite → Manhã, alimentos que já apodreceram são descartados.
## O estado da cópia é consultado; o ItemData original permanece intocado.
func discard_spoiled_consumables(campaign: CampaignState,
		extra_actors: Array[EntityState] = []) -> int:
	if campaign == null:
		return 0
	var removed := 0
	var owners: Array[EntityState] = []
	owners.append_array(campaign.active_entity_states)
	owners.append_array(campaign.companion_states)
	for actor in extra_actors:
		if actor != null and actor not in owners:
			owners.append(actor)
	for owner in owners:
		for index in range(owner.inventory_items.size() - 1, -1, -1):
			var entry := owner.inventory_items[index]
			if entry == null or entry.data == null \
					or entry.data.item_type != ItemData.ItemType.CONSUMABLE:
				continue
			for state in entry.states:
				if state != null and state.id == &"apodrecido":
					owner.inventory_items.remove_at(index)
					removed += 1
					break
	return removed


## A origem tem prioridade. Se ela está cheia, o jogador escolhe entre os
## outros jogáveis que comportam o item. Se ninguém tem espaço, ele se perde.
func deliver_created_item(owner: EntityState, item: ItemData, campaign: CampaignState) -> Dictionary:
	if owner == null or item == null or campaign == null:
		return {"success": false}
	if can_receive(owner, item):
		return {"success": add_item(owner, item), "recipient": owner, "item": item}
	var options: Array[EntityState] = []
	for candidate in campaign.active_entity_states:
		if candidate != owner and can_receive(candidate, item):
			options.append(candidate)
	if options.is_empty():
		return {"success": true, "pending_exchange": true,
			"recipient": owner, "item": item}
	if options.size() == 1:
		return {"success": add_item(options[0], item), "recipient": options[0], "item": item}
	_pending_deliveries.append({"item": item, "options": options})
	if _pending_deliveries.size() == 1:
		recipient_choice_requested.emit(item, options)
	return {"success": true, "pending_recipient": true, "item": item}


func has_pending_recipient_choice() -> bool:
	return not _pending_deliveries.is_empty()


func get_pending_recipient_options() -> Array[EntityState]:
	var options: Array[EntityState] = []
	if has_pending_recipient_choice():
		options.assign(_pending_deliveries[0]["options"])
	return options


func choose_recipient(recipient: EntityState) -> bool:
	if not has_pending_recipient_choice():
		return false
	var entry := _pending_deliveries[0]
	if recipient not in entry["options"] or not can_receive(recipient, entry["item"]):
		return false
	if not add_item(recipient, entry["item"]):
		return false
	_pending_deliveries.remove_at(0)
	if has_pending_recipient_choice():
		recipient_choice_requested.emit(_pending_deliveries[0]["item"], _pending_deliveries[0]["options"])
	return true


## O craft normal usa 3 cópias. Artesanato com EVA passa 2. Cópias equipadas
## também pertencem ao próprio personagem e entram na contagem; nunca se
## consome peça de outro membro do grupo automaticamente.
func get_craftable_options(actor: EntityState, required_copies: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if actor == null or required_copies < 1:
		return options
	var counts: Dictionary = {}
	var resources: Dictionary = {}
	for entry in _craft_entries(actor):
		if entry == null or entry.data == null or entry.data.id == &"":
			continue
		var item := entry.data
		counts[item.id] = int(counts.get(item.id, 0)) + 1
		resources[item.id] = item
	for item_id in counts:
		if int(counts[item_id]) < required_copies:
			continue
		var ingredient := resources[item_id] as ItemData
		var results: Array[ItemData] = []
		for raw_result in ingredient.craft_result:
			var result := raw_result as ItemData
			if result != null and result.rarity == ItemData.Rarity.EPIC \
					and can_craft(actor, ingredient.id, result.id, required_copies):
				results.append(result)
		if not results.is_empty():
			options.append({"ingredient": ingredient, "results": results})
	return options


func can_craft(actor: EntityState, ingredient_id: StringName, result_id: StringName, required_copies: int) -> bool:
	if actor == null or ingredient_id == &"" or result_id == &"" or required_copies < 1:
		return false
	var matching := _craft_matching_entries(actor, ingredient_id)
	if matching.size() < required_copies:
		return false
	var ingredient := (matching[0] as InventoryItemState).data
	for raw_result in ingredient.craft_result:
		var result := raw_result as ItemData
		if result != null and result.id == result_id and result.rarity == ItemData.Rarity.EPIC:
			if result.cannot_craft_after_consumed and campaign != null \
					and campaign.consumed_uncraftable_item_ids.has(result.id):
				return false
			var used_after := actor.inventory_used_space() + result.inventory_space
			var capacity_after := actor.inventory_capacity()
			for index in required_copies:
				var entry := matching[index] as InventoryItemState
				if entry in actor.inventory_items:
					used_after -= entry.data.inventory_space
				else:
					capacity_after -= EquipmentManager.new()._capacity_bonus(entry.data)
			return used_after <= capacity_after
	return false


func craft(actor: EntityState, ingredient_id: StringName, result_id: StringName,
		required_copies: int, skill_manager: SkillManager = null) -> Dictionary:
	if not can_craft(actor, ingredient_id, result_id, required_copies):
		return {"success": false}
	var matching := _craft_matching_entries(actor, ingredient_id)
	var ingredient := (matching[0] as InventoryItemState).data
	for index in required_copies:
		var entry := matching[index] as InventoryItemState
		if entry not in actor.inventory_items and skill_manager == null:
			return {"success": false, "reason": "Ingrediente equipado requer gestor de equipamento."}
	var result: ItemData
	for raw_candidate in ingredient.craft_result:
		var candidate := raw_candidate as ItemData
		if candidate != null and candidate.id == result_id:
			result = candidate
			break
	var removed := 0
	var inherited_attack := 0
	var inherited_life := 0
	var inherited_stamina := 0
	var equipment := EquipmentManager.new()
	for index in required_copies:
		var entry := matching[index] as InventoryItemState
		inherited_attack += entry.improvement_attack
		inherited_life += entry.improvement_life
		inherited_stamina += entry.improvement_stamina
		if entry in actor.inventory_items:
			actor.inventory_items.erase(entry)
		else:
			equipment.consume_equipped_for_craft(actor, entry, skill_manager)
		item_lost.emit(entry.data)
		removed += 1
	var crafted_copy := InventoryItemState.new(result)
	crafted_copy.improvement_attack = inherited_attack
	crafted_copy.improvement_life = inherited_life
	crafted_copy.improvement_stamina = inherited_stamina
	actor.inventory_items.append(crafted_copy)
	item_delivered.emit(actor, result)
	return {"success": true, "crafted_item": result, "crafted_copy": crafted_copy,
		"consumed_item": ingredient, "consumed_count": removed}


func _craft_entries(actor: EntityState) -> Array[InventoryItemState]:
	var entries: Array[InventoryItemState] = []
	if actor == null:
		return entries
	entries.append_array(actor.inventory_items)
	entries.append_array(actor.equipped_weapons)
	entries.append_array(actor.equipped_armors)
	entries.append_array(actor.equipped_accessories)
	return entries


func _craft_matching_entries(actor: EntityState,
		ingredient_id: StringName) -> Array[InventoryItemState]:
	var matching: Array[InventoryItemState] = []
	for entry in _craft_entries(actor):
		if entry != null and entry.data != null and entry.data.id == ingredient_id:
			matching.append(entry)
	return matching


## Passa-tempo: troca uma única cópia comum pela evolução Épica cadastrada.
func can_transform_single_item(actor: EntityState, entry: InventoryItemState,
		result: ItemData) -> bool:
	if actor == null or entry == null or entry.data == null or result == null \
			or entry not in actor.inventory_items \
			or entry.data.rarity != ItemData.Rarity.COMMON \
			or entry.data.item_type == ItemData.ItemType.CURSED \
			or result.rarity != ItemData.Rarity.EPIC \
			or result not in entry.data.craft_result:
		return false
	return actor.inventory_used_space() - entry.data.inventory_space \
		+ result.inventory_space <= actor.inventory_capacity()


func transform_single_item(actor: EntityState, entry: InventoryItemState,
		result: ItemData) -> Dictionary:
	if not can_transform_single_item(actor, entry, result):
		return {"success": false, "reason": "Item ou espaço indisponível."}
	var original := entry.data
	var upgraded := InventoryItemState.new(result)
	upgraded.improvement_attack = entry.improvement_attack
	upgraded.improvement_life = entry.improvement_life
	upgraded.improvement_stamina = entry.improvement_stamina
	var index := actor.inventory_items.find(entry)
	actor.inventory_items[index] = upgraded
	item_lost.emit(original)
	item_delivered.emit(actor, result)
	return {"success": true, "transformed_item": result,
		"consumed_item": original, "transformed_copy": upgraded}


## Lê o catálogo já cadastrado em ItemData; não gera itens a partir de nomes.
func draw_random_item(effect: SkillEffectData, rng: RandomNumberGenerator = null) -> ItemData:
	if effect == null:
		return null
	var candidates := get_eligible_items(effect)
	if candidates.is_empty():
		return null
	var source := rng
	if source == null:
		source = RandomNumberGenerator.new()
		source.randomize()
	return candidates[source.randi_range(0, candidates.size() - 1)]


func get_eligible_items(effect: SkillEffectData) -> Array[ItemData]:
	var candidates: Array[ItemData] = []
	if effect == null:
		return candidates
	for path in _item_paths(ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"":
			continue
		if not effect.tags_filter.is_empty() and not _shares_tag(item.tags, effect.tags_filter):
			continue
		if _shares_tag(item.tags, effect.excluded_tags):
			continue
		if &"raro" in effect.excluded_tags and item.rarity == ItemData.Rarity.RARE:
			continue
		candidates.append(item)
	return candidates


func _shares_tag(actual: Array[StringName], wanted: Array[StringName]) -> bool:
	for tag in wanted:
		if tag in actual:
			return true
	return false


func _item_paths(directory: String) -> Array[String]:
	var paths: Array[String] = []
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".tres"):
			paths.append(directory.path_join(filename))
	for folder in DirAccess.get_directories_at(directory):
		paths.append_array(_item_paths(directory.path_join(folder)))
	paths.sort()
	return paths
