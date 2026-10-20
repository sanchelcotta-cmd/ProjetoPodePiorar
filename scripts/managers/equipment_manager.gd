class_name EquipmentManager
extends RefCounted

## Move a MESMA cópia entre inventário carregado e espaços equipados.
## Equipar libera o espaço da mochila; desequipar volta a ocupá-lo.
## Cada cópia mantém suas Skills pela própria origem, sem alterar ItemData.

signal item_equipped(actor: EntityState, entry: InventoryItemState)
signal item_unequipped(actor: EntityState, entry: InventoryItemState)


## Evento 07: troca o conteúdo de uma cópia já equipada sem colocá-la
## temporariamente na mochila. Mantém o slot, recalcula bônus/Skills e
## desfaz esta cópia se a nova concessão não puder ser aplicada.
func transform_equipped(actor: EntityState, entry: InventoryItemState,
		replacement: ItemData, skill_manager: SkillManager,
		campaign: CampaignState) -> bool:
	if actor == null or entry == null or entry.data == null or replacement == null \
			or skill_manager == null or entry not in actor.equipped_in_slot(
				entry.data.equipment_slot) \
			or replacement.item_type != ItemData.ItemType.EQUIPMENT \
			or replacement.equipment_slot != entry.data.equipment_slot \
			or not skill_manager.can_equip_item(actor, replacement):
		return false
	var original := entry.data
	var source_id := _source_id(entry)
	skill_manager.remove_source(actor, &"equipment", source_id)
	_apply_numeric_bonuses(actor, original, -1)
	_apply_instance_bonuses(actor, entry, -1)
	entry.data = replacement
	var granted := true
	for passive in replacement.granted_passives:
		if passive != null and skill_manager.grant_skill(actor, passive,
				&"equipment", source_id, campaign, replacement) == null:
			granted = false
			break
	if granted:
		for active in replacement.granted_active_skills:
			if active != null and skill_manager.grant_skill(actor, active,
					&"equipment", source_id, campaign, replacement) == null:
				granted = false
				break
	if not granted:
		skill_manager.remove_source(actor, &"equipment", source_id)
		entry.data = original
		for passive in original.granted_passives:
			if passive != null:
				skill_manager.grant_skill(actor, passive, &"equipment", source_id,
					campaign, original)
		for active in original.granted_active_skills:
			if active != null:
				skill_manager.grant_skill(actor, active, &"equipment", source_id,
						campaign, original)
		_apply_numeric_bonuses(actor, original, 1)
		_apply_instance_bonuses(actor, entry, 1)
		return false
	entry.states.clear()
	entry.improvement_attack = 0
	entry.improvement_life = 0
	entry.improvement_stamina = 0
	_apply_numeric_bonuses(actor, replacement, 1)
	actor.equipment_changed.emit()
	return true


## Evento 07: move a mochila preservada para outro jogável e remaneja o
## acessório que ocupava aquele slot. Concede as Skills de destino antes de
## mexer nas cópias; uma falha deixa ambos os equipamentos intactos.
func swap_equipped_accessories(from_owner: EntityState, to_owner: EntityState,
		backpack: InventoryItemState, other: InventoryItemState,
		skill_manager: SkillManager, campaign: CampaignState) -> bool:
	if from_owner == null or to_owner == null or from_owner == to_owner \
			or backpack == null or backpack.data == null or skill_manager == null \
			or backpack not in from_owner.equipped_accessories \
			or not skill_manager.can_equip_item(to_owner, backpack.data) \
			or (other != null and (other.data == null \
				or other not in to_owner.equipped_accessories \
				or not skill_manager.can_equip_item(from_owner, other.data))):
		return false
	var backpack_source := _source_id(backpack)
	var other_source := _source_id(other) if other != null else &""
	for passive in backpack.data.granted_passives:
		if passive != null and skill_manager.grant_skill(to_owner, passive,
				&"equipment", backpack_source, campaign, backpack.data) == null:
			skill_manager.remove_source(to_owner, &"equipment", backpack_source)
			return false
	for active in backpack.data.granted_active_skills:
		if active != null and skill_manager.grant_skill(to_owner, active,
				&"equipment", backpack_source, campaign, backpack.data) == null:
			skill_manager.remove_source(to_owner, &"equipment", backpack_source)
			return false
	if other != null:
		for passive in other.data.granted_passives:
			if passive != null and skill_manager.grant_skill(from_owner, passive,
					&"equipment", other_source, campaign, other.data) == null:
				skill_manager.remove_source(to_owner, &"equipment", backpack_source)
				skill_manager.remove_source(from_owner, &"equipment", other_source)
				return false
		for active in other.data.granted_active_skills:
			if active != null and skill_manager.grant_skill(from_owner, active,
					&"equipment", other_source, campaign, other.data) == null:
				skill_manager.remove_source(to_owner, &"equipment", backpack_source)
				skill_manager.remove_source(from_owner, &"equipment", other_source)
				return false
	skill_manager.remove_source(from_owner, &"equipment", backpack_source)
	_apply_numeric_bonuses(from_owner, backpack.data, -1)
	_apply_instance_bonuses(from_owner, backpack, -1)
	from_owner.equipped_accessories.erase(backpack)
	if other != null:
		skill_manager.remove_source(to_owner, &"equipment", other_source)
		_apply_numeric_bonuses(to_owner, other.data, -1)
		_apply_instance_bonuses(to_owner, other, -1)
		to_owner.equipped_accessories.erase(other)
		from_owner.equipped_accessories.append(other)
		_apply_numeric_bonuses(from_owner, other.data, 1)
		_apply_instance_bonuses(from_owner, other, 1)
	to_owner.equipped_accessories.append(backpack)
	_apply_numeric_bonuses(to_owner, backpack.data, 1)
	_apply_instance_bonuses(to_owner, backpack, 1)
	from_owner.equipment_changed.emit()
	to_owner.equipment_changed.emit()
	return true


func equip(actor: EntityState, entry: InventoryItemState,
		skill_manager: SkillManager, campaign: CampaignState = null,
		replacement: InventoryItemState = null) -> bool:
	if actor == null or entry == null or entry.data == null or skill_manager == null \
			or entry not in actor.inventory_items:
		return false
	var item := entry.data
	if item.item_type != ItemData.ItemType.EQUIPMENT \
			or item.equipment_slot == ItemData.EquipmentSlot.NONE \
			or not skill_manager.can_equip_item(actor, item):
		return false
	var equipped := actor.equipped_in_slot(item.equipment_slot)
	var slot_capacity := actor.equipment_slot_capacity(_slot_key(item.equipment_slot))
	if equipped.size() >= slot_capacity:
		# Com apenas um espaço, substituir é inequívoco. Com vários, quem
		# chamou precisa escolher explicitamente qual cópia vai sair.
		if replacement == null and equipped.size() == 1:
			replacement = equipped[0]
		if replacement == null or replacement not in equipped:
			return false
	elif replacement != null:
		return false
	var old_item: ItemData = replacement.data if replacement != null else null
	var used_after := actor.inventory_used_space() - item.inventory_space
	var capacity_after := actor.inventory_capacity() + _capacity_bonus(item)
	if old_item != null:
		used_after += old_item.inventory_space
		capacity_after -= _capacity_bonus(old_item)
	if used_after > capacity_after:
		return false
	# Primeiro confirma que todas as habilidades do novo item podem entrar.
	# Se alguma falhar, remove somente essa origem e mantém tudo no lugar.
	var source_id := _source_id(entry)
	for passive in item.granted_passives:
		if passive != null and skill_manager.grant_skill(actor, passive,
				&"equipment", source_id, campaign, item) == null:
			skill_manager.remove_source(actor, &"equipment", source_id)
			return false
	for active in item.granted_active_skills:
		if active != null and skill_manager.grant_skill(actor, active,
				&"equipment", source_id, campaign, item) == null:
			skill_manager.remove_source(actor, &"equipment", source_id)
			return false
	if replacement != null:
		skill_manager.remove_source(actor, &"equipment", _source_id(replacement))
		_apply_numeric_bonuses(actor, old_item, -1)
		_apply_instance_bonuses(actor, replacement, -1)
		equipped.erase(replacement)
		actor.inventory_items.append(replacement)
		item_unequipped.emit(actor, replacement)
	actor.inventory_items.erase(entry)
	equipped.append(entry)
	_apply_numeric_bonuses(actor, item, 1)
	_apply_instance_bonuses(actor, entry, 1)
	actor.equipment_changed.emit()
	item_equipped.emit(actor, entry)
	return true


func unequip(actor: EntityState, entry: InventoryItemState,
		skill_manager: SkillManager) -> bool:
	if actor == null or entry == null or entry.data == null or skill_manager == null:
		return false
	var item := entry.data
	var equipped := actor.equipped_in_slot(item.equipment_slot)
	if entry not in equipped:
		return false
	# Uma mochila equipada pode sustentar espaços extras. Se o retorno
	# deixaria a bagagem maior que a capacidade restante, espera espaço livre.
	var capacity_after := actor.inventory_capacity() - _capacity_bonus(item)
	if actor.inventory_used_space() + item.inventory_space > capacity_after:
		return false
	skill_manager.remove_source(actor, &"equipment", _source_id(entry))
	_apply_numeric_bonuses(actor, item, -1)
	_apply_instance_bonuses(actor, entry, -1)
	equipped.erase(entry)
	actor.inventory_items.append(entry)
	actor.equipment_changed.emit()
	item_unequipped.emit(actor, entry)
	return true


## Consumo transacional pelo craft: retira a cópia equipada sem colocá-la
## provisoriamente na mochila e desfaz imediatamente seus bônus e Skills.
func consume_equipped_for_craft(actor: EntityState, entry: InventoryItemState,
		skill_manager: SkillManager) -> bool:
	if actor == null or entry == null or entry.data == null or skill_manager == null:
		return false
	var equipped := actor.equipped_in_slot(entry.data.equipment_slot)
	if entry not in equipped:
		return false
	skill_manager.remove_source(actor, &"equipment", _source_id(entry))
	_apply_numeric_bonuses(actor, entry.data, -1)
	_apply_instance_bonuses(actor, entry, -1)
	equipped.erase(entry)
	actor.equipment_changed.emit()
	return true


## Arrastar uma peça entre jogáveis equipa diretamente o destino. A peça
## substituída volta à mochila de origem; a vaga liberada pelo arrasto a
## comporta quando os itens têm o mesmo custo, sem duplicar nenhuma cópia.
func can_equip_playable_from_playable(donor: EntityState, recipient: EntityState,
		entry: InventoryItemState, skill_manager: SkillManager,
		campaign: CampaignState) -> bool:
	if donor == null or recipient == null or donor == recipient or entry == null \
			or entry.data == null or skill_manager == null or campaign == null \
			or (donor.current_health <= 0 and donor not in campaign.dead_playable_states) \
			or recipient.current_health <= 0 \
			or donor not in campaign.active_entity_states \
			or recipient not in campaign.active_entity_states \
			or entry not in donor.inventory_items:
		return false
	var item := entry.data
	if item.item_type != ItemData.ItemType.EQUIPMENT \
			or item.equipment_slot == ItemData.EquipmentSlot.NONE \
			or not skill_manager.can_equip_item(recipient, item):
		return false
	var equipped := recipient.equipped_in_slot(item.equipment_slot)
	var capacity := recipient.equipment_slot_capacity(_slot_key(item.equipment_slot))
	var old := equipped[0] if equipped.size() >= capacity and equipped.size() == 1 \
		else null
	if equipped.size() >= capacity and old == null:
		return false
	var old_space := old.data.inventory_space if old != null else 0
	return donor.inventory_used_space() - item.inventory_space + old_space \
		<= donor.inventory_capacity()


func equip_playable_from_playable(donor: EntityState, recipient: EntityState,
		entry: InventoryItemState, skill_manager: SkillManager,
		campaign: CampaignState) -> bool:
	if not can_equip_playable_from_playable(donor, recipient, entry,
			skill_manager, campaign):
		return false
	var item := entry.data
	var equipped := recipient.equipped_in_slot(item.equipment_slot)
	var old := recipient.primary_equipped(item.equipment_slot) \
		if equipped.size() >= recipient.equipment_slot_capacity(
			_slot_key(item.equipment_slot)) else null
	var source_id := _source_id(entry)
	for passive in item.granted_passives:
		if passive != null and skill_manager.grant_skill(recipient, passive,
				&"equipment", source_id, campaign, item) == null:
			skill_manager.remove_source(recipient, &"equipment", source_id)
			return false
	for active in item.granted_active_skills:
		if active != null and skill_manager.grant_skill(recipient, active,
				&"equipment", source_id, campaign, item) == null:
			skill_manager.remove_source(recipient, &"equipment", source_id)
			return false
	if old != null:
		skill_manager.remove_source(recipient, &"equipment", _source_id(old))
		_apply_numeric_bonuses(recipient, old.data, -1)
		_apply_instance_bonuses(recipient, old, -1)
		equipped.erase(old)
		old.inventory_slot_index = -1
		donor.inventory_items.append(old)
		item_unequipped.emit(recipient, old)
	donor.inventory_items.erase(entry)
	entry.inventory_slot_index = -1
	equipped.append(entry)
	_apply_numeric_bonuses(recipient, item, 1)
	_apply_instance_bonuses(recipient, entry, 1)
	recipient.equipment_changed.emit()
	item_equipped.emit(recipient, entry)
	return true


## Aliado humano não possui inventário. Ao substituir, a peça antiga volta
## ao MESMO jogável que entregou a nova, sem cópias intermediárias.
func can_equip_companion_from_playable(donor: EntityState, companion: EntityState,
		entry: InventoryItemState, skill_manager: SkillManager,
		campaign: CampaignState) -> bool:
	if donor == null or companion == null or entry == null or entry.data == null \
			or skill_manager == null or campaign == null \
			or donor not in campaign.active_entity_states \
			or companion not in campaign.companion_states \
			or companion.data == null or &"jogavel" not in companion.data.tags \
			or entry not in donor.inventory_items:
		return false
	var item := entry.data
	if item.item_type != ItemData.ItemType.EQUIPMENT \
			or item.equipment_slot == ItemData.EquipmentSlot.NONE \
			or not skill_manager.can_equip_item(companion, item):
		return false
	var old := companion.primary_equipped(item.equipment_slot)
	var returned_space := old.data.inventory_space if old != null else 0
	return donor.inventory_used_space() - item.inventory_space + returned_space \
		<= donor.inventory_capacity()


func equip_companion_from_playable(donor: EntityState, companion: EntityState,
		entry: InventoryItemState, skill_manager: SkillManager,
		campaign: CampaignState) -> bool:
	if not can_equip_companion_from_playable(donor, companion, entry,
			skill_manager, campaign):
		return false
	var item := entry.data
	var equipped := companion.equipped_in_slot(item.equipment_slot)
	var old := companion.primary_equipped(item.equipment_slot)
	var source_id := _source_id(entry)
	for passive in item.granted_passives:
		if passive != null and skill_manager.grant_skill(companion, passive,
				&"equipment", source_id, campaign, item) == null:
			skill_manager.remove_source(companion, &"equipment", source_id)
			return false
	for active in item.granted_active_skills:
		if active != null and skill_manager.grant_skill(companion, active,
				&"equipment", source_id, campaign, item) == null:
			skill_manager.remove_source(companion, &"equipment", source_id)
			return false
	if old != null:
		skill_manager.remove_source(companion, &"equipment", _source_id(old))
		_apply_numeric_bonuses(companion, old.data, -1)
		_apply_instance_bonuses(companion, old, -1)
		equipped.erase(old)
		old.inventory_slot_index = -1
		donor.inventory_items.append(old)
		item_unequipped.emit(companion, old)
	donor.inventory_items.erase(entry)
	equipped.append(entry)
	_apply_numeric_bonuses(companion, item, 1)
	_apply_instance_bonuses(companion, entry, 1)
	companion.equipment_changed.emit()
	item_equipped.emit(companion, entry)
	return true


func unequip_companion_to_playable(companion: EntityState, recipient: EntityState,
		entry: InventoryItemState, skill_manager: SkillManager,
		campaign: CampaignState) -> bool:
	if companion == null or recipient == null or entry == null or entry.data == null \
			or skill_manager == null or campaign == null \
			or companion not in campaign.companion_states \
			or companion.data == null or &"jogavel" not in companion.data.tags \
			or recipient not in campaign.active_entity_states \
			or recipient.inventory_used_space() + entry.data.inventory_space \
			> recipient.inventory_capacity():
		return false
	var equipped := companion.equipped_in_slot(entry.data.equipment_slot)
	if entry not in equipped:
		return false
	skill_manager.remove_source(companion, &"equipment", _source_id(entry))
	_apply_numeric_bonuses(companion, entry.data, -1)
	_apply_instance_bonuses(companion, entry, -1)
	equipped.erase(entry)
	recipient.inventory_items.append(entry)
	companion.equipment_changed.emit()
	item_unequipped.emit(companion, entry)
	return true


## Simbiose Elemental consome a arma equipada diretamente. Não há etapa
## intermediária de inventário, portanto não exige espaço livre na mochila.
func consume_equipped_item(actor: EntityState, entry: InventoryItemState,
		skill_manager: SkillManager) -> bool:
	if actor == null or entry == null or entry.data == null or skill_manager == null:
		return false
	var equipped := actor.equipped_in_slot(entry.data.equipment_slot)
	if entry not in equipped:
		return false
	skill_manager.remove_source(actor, &"equipment", _source_id(entry))
	_apply_numeric_bonuses(actor, entry.data, -1)
	_apply_instance_bonuses(actor, entry, -1)
	equipped.erase(entry)
	actor.equipment_changed.emit()
	item_unequipped.emit(actor, entry)
	return true


func _apply_numeric_bonuses(actor: EntityState, item: ItemData, direction: int) -> void:
	if item == null:
		return
	actor.max_health = maxi(1, actor.max_health + item.bonus_life * direction)
	# Vestir aumenta Vida máxima E atual. Retirar não é dano: só ajusta
	# a Vida atual se ela passar do novo teto.
	if direction > 0:
		actor.current_health += item.bonus_life
	actor.current_health = mini(actor.current_health, actor.max_health)
	# O Ataque do equipamento sempre entra. O bônus de Maestria também entra
	# no Ataque final, mas só se o tipo JÁ era próprio do personagem. O futuro
	# executor de Combate deve usar actor.attack sem somar este bônus outra vez.
	var matching_mastery_bonus := 0
	if actor.data != null and item.mastery_granted != EntityData.Mastery.NONE \
			and item.mastery_granted in actor.data.maestrias:
		matching_mastery_bonus = item.mastery_bonus
	actor.attack += (item.bonus_attack + matching_mastery_bonus) * direction
	actor.max_stamina = maxi(0, actor.max_stamina + item.bonus_stamina * direction)
	actor.stamina_remaining = mini(actor.stamina_remaining, actor.max_stamina)
	# Maestria não é alterada aqui: EntityState consulta o bônus do item
	# enquanto ele estiver equipado, somente se o tipo for inato.


func _apply_instance_bonuses(actor: EntityState, entry: InventoryItemState,
		direction: int) -> void:
	if actor == null or entry == null:
		return
	actor.max_health = maxi(1, actor.max_health + entry.improvement_life * direction)
	if direction > 0:
		actor.current_health += entry.improvement_life
	actor.current_health = mini(actor.current_health, actor.max_health)
	actor.attack += entry.improvement_attack * direction
	actor.max_stamina = maxi(0, actor.max_stamina + entry.improvement_stamina * direction)
	actor.stamina_remaining = mini(actor.stamina_remaining, actor.max_stamina)


func _capacity_bonus(item: ItemData) -> int:
	if item == null:
		return 0
	var bonus := 0
	for passive in item.granted_passives:
		if passive == null:
			continue
		for effect in passive.continuous_effects:
			if effect != null and effect.effect_type == SkillEffectData.EffectType.MODIFY_INVENTORY_CAPACITY:
				bonus += effect.amount
	return bonus


func _slot_key(slot: ItemData.EquipmentSlot) -> StringName:
	match slot:
		ItemData.EquipmentSlot.WEAPON: return &"weapon"
		ItemData.EquipmentSlot.ARMOR: return &"armor"
		ItemData.EquipmentSlot.ACCESSORY: return &"accessory"
	return &""


func _source_id(entry: InventoryItemState) -> StringName:
	return StringName("equipped:%d" % entry.get_instance_id())
