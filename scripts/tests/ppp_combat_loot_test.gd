extends SceneTree

const LOOT = preload("res://scripts/combat/combat_loot_resolver.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pools := LOOT._catalog()
	check(not pools["equipment"].is_empty() and not pools["consumable"].is_empty()
		and not pools["rare_consumable"].is_empty(),
		"Catálogo tem equipamento comum, consumível normal e raro elegíveis.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 56005
	var hits := {"suburbio": 0, "baixo_centro": 0, "centro": 0}
	var equipment_count := 0
	var consumable_count := 0
	var rare_count := 0
	for district in [&"suburbio", &"baixo_centro", &"centro"]:
		for iteration in 2000:
			var result: Dictionary = LOOT.roll(district, 40, 100, rng)
			check(result.get("success", false), "O sorteio deve ser válido.")
			var items: Array = result.get("items", [])
			if result.get("regular_success", false):
				hits[str(district)] += 1
				if district == &"centro":
					check(items.size() == 3 and (items[2] as ItemData).item_type
						== ItemData.ItemType.CONSUMABLE,
						"Centro dá exatamente três itens, terceiro sempre consumível.")
				elif district == &"baixo_centro":
					check(items.size() in [1, 2], "Baixo-Centro dá um ou dois itens.")
				else:
					check(items.size() == 1, "Subúrbio dá um item.")
			for item in items:
				var data := item as ItemData
				check(data != null and data.item_type != ItemData.ItemType.CURSED
					and data.rarity != ItemData.Rarity.EPIC,
					"Saque regular nunca inclui maldição ou Épico.")
				if data.item_type == ItemData.ItemType.EQUIPMENT:
					equipment_count += 1
					check(data.rarity == ItemData.Rarity.COMMON,
						"Equipável sorteado é sempre comum.")
				else:
					consumable_count += 1
					if data.rarity == ItemData.Rarity.RARE:
						rare_count += 1
	check(hits["suburbio"] in range(1080, 1321)
		and hits["baixo_centro"] in range(1480, 1721)
		and hits["centro"] == 2000,
		"Chance única por combate se aproxima de 60/80/100%.")
	# O consumível obrigatório do Centro é excluído da comparação 50/50.
	var optional_consumables: int = consumable_count - int(hits["centro"])
	check(abs(optional_consumables - equipment_count) < 350,
		"Os slots livres têm distribuição aproximada 50/50.")
	check(rare_count * 100 > consumable_count
		and rare_count * 100 < consumable_count * 3,
		"Raros aparecem aproximadamente em 2% dos consumíveis.")
	var threshold := LOOT.roll(&"suburbio", 40, 100, rng)
	check(not threshold["damage_bonus"], "40% exatos não concedem bônus.")
	var above_suburb := LOOT.roll(&"suburbio", 41, 100, rng)
	check(above_suburb["damage_bonus"]
		and above_suburb["items"].size()
		== (2 if above_suburb["regular_success"] else 1)
		and (above_suburb["items"][-1] as ItemData).item_type
		== ItemData.ItemType.CONSUMABLE,
		"Subúrbio mantém o Consumível extra acima de 40%, mesmo sem saque regular.")
	var center_no_damage := LOOT.roll(&"centro", 0, 100, rng)
	check(center_no_damage["items"].size() == 3
		and (center_no_damage["items"][-1] as ItemData).item_type
		== ItemData.ItemType.CONSUMABLE,
		"Centro garante o terceiro Consumível até sem dano sofrido.")
	var above := LOOT.roll(&"centro", 41, 100, rng)
	check(not above["damage_bonus"] and above["guaranteed_consumable"]
		and above["items"].size() == 3
		and (above["items"][-1] as ItemData).item_type
		== ItemData.ItemType.CONSUMABLE,
		"Centro tem três itens no total; o terceiro Consumível independe dos 40%.")
	await _integration()
	print("COMBAT_LOOT_TEST: %s (%d falhas)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)


func _integration() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var skills := scene.get_node("SkillManager") as SkillManager
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(game.start_new_game(selected) and rounds.start_first_map(),
		"Campanha de teste iniciou.")
	var actor := game.campaign.active_entity_states[0]
	var coord := Vector2i(3, 2)
	actor.position = coord
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	game.campaign.obtained_information_ids[&"combat_test_info"] = true
	game.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(coord, actor), "Encontro iniciou.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(combat.enemies.size() == 1 and combat._loot_entry_max_health > 0,
		"Limiar de Vida é fotografado na entrada do combate.")
	var before := actor.current_health
	var dealt := skills.apply_incoming_damage(actor, 5, game.campaign)
	check(combat._loot_damage_taken == int(dealt["damage"]),
		"Dano efetivo, não bruto, entra no acumulador.")
	actor.current_health = before
	check(combat._loot_damage_taken == int(dealt["damage"]),
		"Cura não apaga dano acumulado.")
	combat._loot_damage_taken = floori(combat._loot_entry_max_health * 0.4) + 1
	combat.enemies[0].current_health = 0
	check(combat.request_victory(), "Vitória com hostil vencido faz uma rolagem.")
	check(combat._loot_rolled and not combat._loot_items.is_empty()
		and not combat.confirm_conclusion(),
		"Bônus garante ao menos um item e impede sair sem resolver o lote.")
	var rolled_paths: Array[String] = []
	for item in combat._loot_items:
		rolled_paths.append(item.resource_path)
	var loot_codec := CampaignSaveCodec.new()
	var loot_graph := loot_codec.encode({"loot": combat._loot_items,
		"damage": combat._loot_damage_taken, "rng": combat._rng})
	var restored_loot := loot_codec.decode(loot_graph) as Dictionary
	check(loot_codec.error.is_empty() and restored_loot != null
		and (restored_loot["loot"] as Array).size() == combat._loot_items.size()
		and int(restored_loot["damage"]) == combat._loot_damage_taken,
		"Itens e dano sorteados são serializáveis sem nova rolagem.")
	check(not combat.request_victory(), "Reentrada na vitória não repete a rolagem.")
	var unchanged_paths: Array[String] = []
	for item in combat._loot_items:
		unchanged_paths.append(item.resource_path)
	check(rolled_paths == unchanged_paths,
		"Reentrada não substitui os itens sorteados.")
	var expected := combat._loot_items.size()
	await create_timer(0.44).timeout
	check(popup.overlay.visible and popup.feedback_label.text.contains("SAQUE"),
		"Janela identifica o item pendente e oferece destinos.")
	var inventory := skills.inventory_manager
	var pending_item := combat.get_pending_loot_item().get("item") as ItemData
	var filler := load("res://resources/itens/consumables/chocolate.tres") as ItemData
	for index in 30:
		if not inventory.can_receive(actor, pending_item):
			break
		if not inventory.add_item(actor, filler):
			break
	popup._refresh_combat_loot_controls()
	var offers_exchange := false
	for button in popup.buttons.get_children():
		if button is Button and (button as Button).text.begins_with("TROCAR ITENS:"):
			offers_exchange = true
	check(offers_exchange, "Inventário cheio oferece troca explícita.")
	var outgoing: Array[InventoryItemState] = [actor.inventory_items[-1]]
	var journal_before := game.campaign.journal_entries.size()
	check(combat.exchange_pending_loot(actor, outgoing),
		"Troca confirmada guarda o saque e libera espaço sem perda silenciosa.")
	check(outgoing[0] not in actor.inventory_items
		and game.campaign.journal_entries.size() == journal_before + 1
		and str(game.campaign.journal_entries[-1].get("action_id")) == "combat_loot",
		"Só a entrega real do saque entra no livro de registros.")
	for index in expected - 1:
		var pending := combat.get_pending_loot_item()
		check(not pending.is_empty(), "Há item pendente antes da confirmação.")
		if pending.is_empty():
			break
		popup._confirm_combat_loot_decline()
		check(popup.feedback_label.text.contains("Recusar este item"),
			"Recusa exige confirmação visível.")
		check(combat.decline_pending_loot(), "Recusa explícita resolve uma cópia.")
	check(combat.get_pending_loot_item().is_empty()
		and combat._loot_resolved_count == expected,
		"Lote resolvido exatamente uma vez, sem recompensa fantasma.")
	popup._refresh_combat_loot_controls()
	check(combat.confirm_conclusion(), "Combate encerra depois das decisões.")
	check(game.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"Mapa volta à exploração.")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
