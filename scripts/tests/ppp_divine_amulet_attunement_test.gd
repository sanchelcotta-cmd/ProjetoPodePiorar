extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/professora.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(campaign.start_new_game(selected), "A campanha inicia.")
	var owner := campaign.active_entity_states[0]
	var other := campaign.active_entity_states[1]
	owner.inventory_items.clear()
	other.inventory_items.clear()
	var skills := SkillManager.new()
	root.add_child(skills)
	var equipment := EquipmentManager.new()
	var inventory := skills.inventory_manager
	var amulet := load(
		"res://resources/itens/equipments/acessorios/acessorio_epico_amuleto_divino.tres") as ItemData
	var cursed := load("res://resources/itens/curseds/espelho_quebrado.tres") as ItemData
	_check(inventory.add_item(owner, amulet), "A cópia do Amuleto entra na mochila.")
	var entry := owner.inventory_items[-1]
	_check(equipment.equip(owner, entry, skills, campaign),
		"O Amuleto pode ser equipado antes da sintonização.")
	var attune_grant := _find_grant(skills, owner, &"item_active_003")
	_check(attune_grant != null and skills.can_attune_divine_amulet(owner, attune_grant),
		"Sintonizar aparece como Ativa enquanto a cópia está livre.")
	_check(not skills.is_status_immune(owner, &"db_00010")
		and not owner.is_curse_immune(),
		"Equipar sem sintonizar ainda não concede imunidades.")
	_check(skills.debuff_manager.apply_by_id(owner, &"db_00010")
		.get("success", false), "Tristeza pode anteceder a sintonização.")
	var result := skills.attune_divine_amulet(owner, attune_grant, campaign)
	_check(result.get("success", false) and entry in owner.equipped_accessories
		and entry.attuned_owner_instance_id == owner.instance_id
		and entry.attuned_owner_name == owner.visible_name(),
		"Sintonizar vincula a mesma cópia sem consumi-la.")
	_check(skills.debuff_manager.get_debuff(owner, &"db_00010") == null
		and skills.is_status_immune(owner, &"db_00010")
		and owner.is_curse_immune(),
		"A sintonização remove debuff ativo e ativa as imunidades.")
	_check(not skills.can_attune_divine_amulet(owner, attune_grant)
		and not skills.attune_divine_amulet(owner, attune_grant).get("success", false),
		"A mesma cópia não pode ser sintonizada de novo.")
	_check(skills.debuff_manager.apply_by_id(owner, &"db_00010").get("immune", false),
		"Uma aplicação direta posterior também é bloqueada.")
	var count_before := owner.inventory_items.size()
	_check(inventory.add_item(owner, cursed)
		and owner.inventory_items.size() == count_before,
		"A maldição futura é anulada sem entrar na mochila.")
	_check(equipment.unequip(owner, entry, skills, campaign)
		and not skills.is_status_immune(owner, &"db_00010")
		and not owner.is_curse_immune(),
		"Desequipar suspende as imunidades, mas não apaga o vínculo.")
	_check(skills.debuff_manager.apply_by_id(owner, &"db_00010")
		.get("success", false), "Sem o Amuleto, o debuff pode voltar.")
	_check(equipment.equip(owner, entry, skills, campaign)
		and skills.debuff_manager.get_debuff(owner, &"db_00010") == null
		and skills.is_status_immune(owner, &"db_00010")
		and not skills.can_attune_divine_amulet(owner,
			_find_grant(skills, owner, &"item_active_003")),
		"Reequipar reativa a imunidade e limpa o debuff, sem ressintonizar.")
	_check(equipment.unequip(owner, entry, skills, campaign)
		and inventory.transfer_item(owner, other, entry, campaign)
		and equipment.equip(other, entry, skills, campaign),
		"A mesma cópia pode ser transferida e equipada por outro personagem.")
	var other_grant := _find_grant(skills, other, &"item_active_003")
	_check(not skills.is_status_immune(other, &"db_00010")
		and not other.is_curse_immune()
		and not skills.can_attune_divine_amulet(other, other_grant),
		"Outro portador não recebe proteção nem pode refazer o vínculo.")
	var codec := CampaignSaveCodec.new()
	var restored := codec.decode(codec.encode(campaign)) as CampaignState
	_check(restored != null and codec.error.is_empty(),
		"O vínculo sobrevive ao save e ao carregamento.")
	if restored != null:
		var loaded_owner := restored.active_entity_states[0]
		var loaded_other := restored.active_entity_states[1]
		var loaded_entry := loaded_other.equipped_accessories[0]
		_check(loaded_entry.attuned_owner_instance_id == loaded_owner.instance_id
			and not skills.is_status_immune(loaded_other, &"db_00010"),
			"Após carregar, o portador errado continua sem imunidade.")
		_check(equipment.unequip(loaded_other, loaded_entry, skills, restored)
			and inventory.transfer_item(loaded_other, loaded_owner,
				loaded_entry, restored)
			and equipment.equip(loaded_owner, loaded_entry, skills, restored)
			and skills.is_status_immune(loaded_owner, &"db_00010"),
			"A cópia volta a proteger somente o personagem sintonizado.")
		_check(inventory.add_item(loaded_other, amulet),
			"Outro personagem pode obter uma segunda cópia independente.")
		var second_entry := loaded_other.inventory_items[-1]
		_check(equipment.equip(loaded_other, second_entry, skills, restored),
			"A segunda cópia pode ser equipada.")
		var second_grant := _find_grant(skills, loaded_other, &"item_active_003")
		_check(skills.can_attune_divine_amulet(loaded_other, second_grant)
			and skills.attune_divine_amulet(loaded_other, second_grant,
				restored).get("success", false)
			and second_entry.attuned_owner_instance_id == loaded_other.instance_id
			and loaded_entry.attuned_owner_instance_id == loaded_owner.instance_id,
			"Cada cópia só admite seu próprio vínculo, sem afetar a primeira.")
	skills.free()
	print("DIVINE_AMULET_ATTUNEMENT_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _find_grant(skills: SkillManager, actor: EntityState,
		id: StringName) -> SkillGrantState:
	for grant in skills.get_active_grants(actor):
		if grant.skill != null and grant.skill.id == id:
			return grant
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
