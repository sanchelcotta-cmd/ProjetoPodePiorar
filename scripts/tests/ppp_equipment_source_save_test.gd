extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(campaign.start_new_game(selected), "Campanha de teste inicia.")
	var mason := campaign.active_entity_states[0]
	var donor := campaign.active_entity_states[1]
	mason.inventory_items.clear()
	donor.inventory_items.clear()
	var backpack := InventoryItemState.new(load(
		"res://resources/itens/equipments/acessorios/mochila_cor_de_rosa.tres"))
	var epic := InventoryItemState.new(load(
		"res://resources/itens/equipments/acessorios/acessorio_epico_passa_tempo.tres"))
	var filler := load("res://resources/itens/consumables/bolinho_de_chuva.tres") as ItemData
	var skills := SkillManager.new()
	root.add_child(skills)
	var equipment := EquipmentManager.new()
	mason.inventory_items.append(backpack)
	check(equipment.equip(mason, backpack, skills, campaign),
		"Mochila equipada concede capacidade extra.")
	check(mason.inventory_capacity() == 15, "Mochila eleva 12 para 15.")
	while mason.inventory_used_space() < 12:
		mason.inventory_items.append(InventoryItemState.new(filler))
	donor.inventory_items.append(epic)
	var codec := CampaignSaveCodec.new()
	var graph := codec.encode(campaign).duplicate(true)
	check(codec.error.is_empty(), "Save codifica o equipamento.")
	var restored := codec.decode(graph) as CampaignState
	check(restored != null and codec.error.is_empty(),
		"Save restaura o equipamento.")
	if restored != null:
		var loaded_mason := restored.active_entity_states[0]
		var loaded_donor := restored.active_entity_states[1]
		var loaded_epic := loaded_donor.inventory_items[0]
		check(equipment.equip_playable_from_playable(loaded_donor,
			loaded_mason, loaded_epic, skills, restored),
			"Passa-tempo substitui a mochila após carregar.")
		check(loaded_mason.inventory_capacity() == 12
			and loaded_mason.inventory_used_space() == 12,
			"Bônus da mochila sai: inventário do Pedreiro fica 12/12.")
		var stale_backpack_grant := false
		for grant in loaded_mason.skill_grants:
			if grant.source_kind == &"equipment" and grant.bound_source == backpack.data:
				stale_backpack_grant = true
		check(not stale_backpack_grant,
			"Concessão da mochila removida, sem efeito órfão.")
		# Reproduz um save já afetado pela falha antes da correção.
		var stale_source := &"equipped:legacy_orphan"
		check(skills.grant_skill(loaded_mason,
			backpack.data.granted_passives[0], &"equipment", stale_source,
			restored, backpack.data) != null,
			"Concessão órfã de save afetado é reproduzida.")
		check(loaded_mason.inventory_capacity() == 15,
			"Save afetado contém três espaços indevidos.")
		var affected := codec.decode(codec.encode(restored)) as CampaignState
		check(affected != null and affected.active_entity_states[0].inventory_capacity() == 12,
			"Carregar save afetado retira bônus sem equipamento correspondente.")
	# Em saves antigos, a cópia não tinha a chave persistente. Recuperá-la
	# da concessão existente mantém a retirada correta ao trocar acessórios.
	for record in graph["objects"]:
		if record.get("script", "") == "res://scripts/campaign/inventory_item_state.gd":
			(record["fields"] as Dictionary).erase("equipment_source_id")
	var legacy := codec.decode(graph) as CampaignState
	check(legacy != null and codec.error.is_empty(),
		"Save antigo sem chave continua legível.")
	if legacy != null:
		var old_mason := legacy.active_entity_states[0]
		var old_donor := legacy.active_entity_states[1]
		check(old_mason.equipped_accessories[0].equipment_source_id != &"",
			"Origem legada foi religada à mochila equipada.")
		check(equipment.equip_playable_from_playable(old_donor, old_mason,
			old_donor.inventory_items[0], skills, legacy),
			"Troca também funciona em save antigo.")
		check(old_mason.inventory_capacity() == 12,
			"Save antigo também perde os três espaços ao tirar mochila.")
	print("EQUIPMENT_SOURCE_SAVE_TEST_OK" if failures == 0 else
		"EQUIPMENT_SOURCE_SAVE_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
