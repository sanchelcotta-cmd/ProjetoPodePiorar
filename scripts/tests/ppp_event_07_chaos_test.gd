extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var skills := scene.get_node("SkillManager") as SkillManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Partida de teste do evento 07 inicia.")
	var campaign := gerencia.campaign
	var owner := campaign.active_entity_states[0]
	var ally_data := load("res://resources/entities/entities_playable/professora.tres") as EntityData
	var ally := EntityState.from_playable_selection(ally_data, &"Companion_1",
		EntityState.UNPLACED)
	ally.playable_slot_id = &""
	skills.ensure_innate_skills(ally)
	check(campaign.register_companion(owner, ally, null, skills),
		"Aliada humana participa do grupo.")
	var equipment := EquipmentManager.new()
	var epic := load("res://resources/itens/equipments/armas/arma_epica_martelo_de_guerra.tres") as ItemData
	var old_ally_weapon := ally.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	check(old_ally_weapon != null and equipment.consume_equipped_item(ally,
		old_ally_weapon, skills), "Aliada prepara arma Épica equipada.")
	var epic_entry := InventoryItemState.new(epic)
	ally.inventory_items.append(epic_entry)
	check(equipment.equip(ally, epic_entry, skills, campaign),
		"Épico está somente no equipamento da aliada antes do caos.")
	var curse := load("res://resources/itens/curseds/bonequinha_de_pano.tres") as ItemData
	var cursed_copy := InventoryItemState.new(curse)
	owner.inventory_items.append(cursed_copy)
	check(skills.grant_skill(owner, curse.granted_passives[0], &"item",
		&"curse_test", campaign, curse) != null,
		"A Maldição carregada concede seu efeito antes do evento.")
	var snapshots: Array[Dictionary] = []
	var all_owners: Array[EntityState] = []
	all_owners.append_array(campaign.active_entity_states)
	all_owners.append(ally)
	for member in all_owners:
		for entry in member.inventory_items:
			if entry != null and entry.data != null:
				snapshots.append({"owner": member, "entry": entry,
					"old": entry.data, "slot": -1})
		for slot in [ItemData.EquipmentSlot.WEAPON,
				ItemData.EquipmentSlot.ARMOR, ItemData.EquipmentSlot.ACCESSORY]:
			for entry in member.equipped_in_slot(slot):
				if entry != null and entry.data != null:
					snapshots.append({"owner": member, "entry": entry,
						"old": entry.data, "slot": slot})
	var results: Array[Dictionary] = []
	executor.result_ready.connect(func(_context: Dictionary, result: Dictionary) -> void:
		if result.get("event_id") == &"ev_00007":
			results.append(result))
	var event := load("res://resources/events/random_events/07-gnomos_do_caos_1.tres") as EventData
	var coord := Vector2i(3, 0)
	owner.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	check(block.begin_activation(coord, owner), "O evento 07 abre no hex.")
	check(cursed_copy.data == curse and epic_entry.data == epic,
		"Ler a narrativa ainda não transforma nada.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup._outcome_reading and cursed_copy.data == curse,
		"A consequência é lida antes da transformação.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not block.is_busy() and results.size() == 1,
		"O OK aplica todos os resultados e encerra o bloco.")
	var any_epic := false
	for snapshot in snapshots:
		var member := snapshot["owner"] as EntityState
		var entry := snapshot["entry"] as InventoryItemState
		var slot := int(snapshot["slot"])
		check(entry.data != null and entry.data != snapshot["old"] \
			and entry.data.item_type != ItemData.ItemType.CURSED \
			and &"cursed" not in entry.data.tags,
			"Toda cópia muda e nenhuma Maldição nova aparece.")
		if slot >= 0:
			check(entry in member.equipped_in_slot(slot)
				and int(entry.data.equipment_slot) == slot,
				"Equipados, inclusive da aliada, continuam em seus próprios slots.")
		else:
			check(entry in member.inventory_items,
				"Item carregado permanece com seu dono.")
		any_epic = any_epic or entry.data.rarity == ItemData.Rarity.EPIC
	check(any_epic, "Um Épico equipado antes da troca garante ao menos um Épico de volta.")
	check(not owner.skill_grants.any(func(grant: SkillGrantState) -> bool:
		return grant.source_kind == &"item" and grant.bound_source == curse),
		"Transformar a Maldição remove também sua passiva carregada.")
	for member in campaign.active_entity_states:
		check(member.inventory_used_space() <= member.inventory_capacity(),
			"Os novos itens cabem na mochila de cada jogável.")
	check(ally.inventory_items.is_empty(), "Aliada continua sem mochila própria.")
	if results.size() == 1:
		var effect: Dictionary = results[0].get("effects", [{}])[0]
		check(effect.get("transformed", 0) == snapshots.size()
			and effect.get("had_epic", false) and effect.get("returned_epic", false),
			"Resultado informa todas as cópias e a garantia do Épico.")
	# Amostra de sorteios independentes para flagrar combinações que extrapolem
	# espaço ou deixem um grupo que tinha Épico sem nenhum Épico no retorno.
	for seed_value in 24:
		var starting_rng := RandomNumberGenerator.new()
		starting_rng.seed = seed_value + 300
		check(campaign.start_new_game(selected, 12, starting_rng),
			"A amostra de caos inicia uma campanha nova.")
		var first := campaign.active_entity_states[0]
		first.inventory_items.append(InventoryItemState.new(epic))
		first.inventory_items.append(InventoryItemState.new(curse))
		executor._rng.seed = seed_value + 900
		var sample := executor._apply_gnome_chaos(event.outcomes[0].effects[0])
		check(sample.get("success", false) and sample.get("returned_epic", false),
			"Sorteio %d devolve um Épico sem falhar." % seed_value)
		for member in campaign.active_entity_states:
			check(member.inventory_used_space() <= member.inventory_capacity(),
				"Sorteio %d respeita a capacidade do grupo." % seed_value)
			for entry in member.inventory_items:
				check(entry.data.item_type != ItemData.ItemType.CURSED
					and &"cursed" not in entry.data.tags,
					"Sorteio %d não cria Maldição." % seed_value)
	var capacity_rng := RandomNumberGenerator.new()
	capacity_rng.seed = 5142
	check(campaign.start_new_game(selected, 12, capacity_rng),
		"Caso-limite da mochila inicia uma campanha nova.")
	var carriers := campaign.active_entity_states
	var backpack_owner := carriers[0]
	var backpack := load("res://resources/itens/equipments/acessorios/acessorio_epico_mochila_do_mochileiro_das_galaxias.tres") as ItemData
	var backpack_copy := InventoryItemState.new(backpack)
	var filler := load("res://resources/itens/consumables/chocolate.tres") as ItemData
	check(backpack != null and filler != null, "Mochila e item de teste existem.")
	for member in carriers:
		member.inventory_items.clear()
		var old_accessory: InventoryItemState = member.primary_equipped(
			ItemData.EquipmentSlot.ACCESSORY)
		if old_accessory != null:
			check(equipment.consume_equipped_item(member, old_accessory, skills),
				"Caso-limite libera acessórios que poderiam substituir a mochila.")
	backpack_owner.inventory_items.append(backpack_copy)
	check(equipment.equip(backpack_owner, backpack_copy, skills, campaign),
		"A mochila dá +12 espaços ao primeiro jogável.")
	var carried_before: Array[InventoryItemState] = []
	for index in carriers.size():
		var amount := 20 if index == 0 else 10
		for _copy in amount:
			var entry := InventoryItemState.new(filler)
			carriers[index].inventory_items.append(entry)
			carried_before.append(entry)
		check(carriers[index].inventory_used_space() <= carriers[index].inventory_capacity(),
			"Todos cabem antes do caos graças à mochila.")
	check(carried_before.size() > 36, "Sem mochila, faltaria espaço no grupo.")
	executor._rng.seed = 8742
	var overflow_result := executor._apply_gnome_chaos(event.outcomes[0].effects[0])
	check(overflow_result.get("success", false),
		"O caos resolve a superlotação sem bloquear nem descartar cópias.")
	var new_backpack_owner: EntityState = null
	var total_after := 0
	for member in carriers:
		if backpack_copy in member.equipped_accessories:
			new_backpack_owner = member
		total_after += member.inventory_items.size()
		check(member.inventory_used_space() <= member.inventory_capacity(),
			"Depois do remanejamento, nenhum inventário excede seu limite.")
	check(new_backpack_owner != null and new_backpack_owner != backpack_owner \
		and backpack_copy.data == backpack,
		"A mochila indispensável permanece e muda para outro jogável.")
	check(total_after == carried_before.size(),
		"Nenhuma das 40 cópias carregadas desaparece.")
	for entry in carried_before:
		var appearances := 0
		for member in carriers:
			if entry in member.inventory_items:
				appearances += 1
		check(appearances == 1, "Cada cópia remanejada tem exatamente um dono.")
	var swap_rng := RandomNumberGenerator.new()
	swap_rng.seed = 5613
	check(campaign.start_new_game(selected, 12, swap_rng),
		"A permuta de dois acessórios inicia uma campanha nova.")
	var swap_origin := campaign.active_entity_states[0]
	var swap_destination := campaign.active_entity_states[1]
	for member in [swap_origin, swap_destination]:
		member.inventory_items.clear()
		var old_accessory: InventoryItemState = member.primary_equipped(
			ItemData.EquipmentSlot.ACCESSORY)
		if old_accessory != null:
			check(equipment.consume_equipped_item(member, old_accessory, skills),
				"O teste libera os dois slots de acessório.")
	var kept_backpack := InventoryItemState.new(backpack)
	swap_origin.inventory_items.append(kept_backpack)
	check(equipment.equip(swap_origin, kept_backpack, skills, campaign),
		"A mochila é equipada na origem antes da permuta.")
	var common_accessory := load("res://resources/itens/equipments/acessorios/relogio_de_bolso.tres") as ItemData
	var common_copy := InventoryItemState.new(common_accessory)
	swap_destination.inventory_items.append(common_copy)
	check(equipment.equip(swap_destination, common_copy, skills, campaign),
		"O outro jogável tem um acessório para remanejar.")
	check(equipment.swap_equipped_accessories(swap_origin, swap_destination,
		kept_backpack, common_copy, skills, campaign),
		"A permuta de acessórios equipados é aceita.")
	check(kept_backpack in swap_destination.equipped_accessories \
		and common_copy in swap_origin.equipped_accessories \
		and swap_origin.inventory_capacity() == 12 \
		and swap_destination.inventory_capacity() == 24,
		"As duas cópias mudam de dono e o bônus de capacidade acompanha a mochila.")
	if failures == 0:
		print("PPP evento 07: grupo, aliado, Épico, Maldição e mochila remanejada passaram")
	else:
		push_error("PPP evento 07: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
