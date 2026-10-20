extends SceneTree

## Regressão curta: arma comum usa a evolução vinculada no ItemData;
## ausência total de arma apresenta erro narrativo sem conceder efeito.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(gerencia.start_new_game(choices) and rounds.start_first_map(),
		"Campanha inicia para testar Simbiose.")
	var actor := gerencia.campaign.active_entity_states[0]
	var unarmed := gerencia.campaign.active_entity_states[2]
	var equipment := EquipmentManager.new()
	for equipped in actor.equipped_weapons.duplicate():
		check(equipment.unequip(actor, equipped, scene.get_node("SkillManager") as SkillManager),
			"Kit inicial removido para isolar a arma da mochila.")
	actor.inventory_items.clear()
	var common := load("res://resources/itens/equipments/armas/cabo_de_vassoura.tres") as ItemData
	var entry := InventoryItemState.new(common)
	actor.inventory_items.append(entry)
	var event := load("res://resources/events/permanent_effects/58-simbiose_elemental.tres") as EventData
	var coord := Vector2i(2, 1)
	actor.position = coord
	gerencia.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	check(block.begin_activation(coord, actor), "Simbiose abre no hex.")
	var absorb_button: Button
	for child in popup.buttons.get_children():
		if child is Button and (child as Button).text == "ACEITAR SIMBIOSE":
			absorb_button = child
	check(absorb_button != null,
		"Sem arma equipada, a interface oferece o sorteio da mochila.")
	if absorb_button != null:
		absorb_button.pressed.emit()
	if popup._outcome_reading:
		popup._execute_prepared_event()
	if block.is_busy():
		push_error("Simbiose bloqueada: %s" % popup.feedback_label.text)
	check(not block.is_busy() and entry not in actor.inventory_items,
		"A arma comum é consumida ao completar o Outcome.")
	var bound: ItemData
	for grant in actor.skill_grants:
		if grant.skill != null and grant.skill.id == &"permanent_passive_058":
			bound = grant.bound_source as ItemData
	check(bound != null and bound.id == &"aa_00003",
		"O Cabo de Vassoura evolui para Bastão do Guardião.")
	var cards := (scene.get_node("PartyStatusHUD") as PartyStatusHUD).cards
	var card := cards[0] as PartyCharacterCard
	card.refresh()
	check(card.weapon_icon.texture == bound.icon \
		and card.weapon_icon.modulate.b > card.weapon_icon.modulate.g \
		and actor.equipped_weapons.is_empty(),
		"A arma absorvida aparece como sombra roxa somente no slot equipado.")
	var second_weapon := InventoryItemState.new(common)
	actor.inventory_items.append(second_weapon)
	check(not equipment.equip(actor, second_weapon,
		scene.get_node("SkillManager") as SkillManager, gerencia.campaign),
		"Simbiose bloqueia o slot de arma pelo restante do jogo.")
	check(not (scene.get_node("CombatManager") as CombatManager)._uses_ranged_attack(unarmed),
		"Maestria Distância não transforma um jogável desarmado em atacante à distância.")
	popup.show_block({"resource": event, "actor": unarmed, "coord": Vector2i(3, 1)})
	check(popup.narrative_label.text ==
		"error_:voce_nao_tem_arma. Efeito inválido. Tente novamente mais tarde --*" \
		and popup.buttons.get_child_count() == 1 \
		and (popup.buttons.get_child(0) as Button).text == "OKAY",
		"Sem arma, a única resposta é OKAY e aparece o texto exato de erro.")
	var second_scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(second_scene)
	await process_frame
	var second_game := second_scene.get_node("GerenciaJogo") as GerenciaJogo
	var second_round := second_scene.get_node("RoundManager") as RoundManager
	var second_skills := second_scene.get_node("SkillManager") as SkillManager
	var second_block := second_scene.get_node("BlockManager") as BlockManager
	var second_popup := second_scene.get_node("BlockActivationPopup") as BlockActivationPopup
	check(second_game.start_new_game(choices) and second_round.start_first_map(),
		"Nova campanha inicia para testar a prioridade da Épica equipada.")
	var second_actor := second_game.campaign.active_entity_states[0]
	for equipped in second_actor.equipped_weapons.duplicate():
		check(equipment.unequip(second_actor, equipped, second_skills),
			"Arma inicial sai antes do teste de prioridade.")
	second_actor.inventory_items.clear()
	var bow := load("res://resources/itens/equipments/armas/arma_epica_arco_da_precisao.tres") as ItemData
	var sword := load("res://resources/itens/equipments/armas/arma_epica_espada_irada_flamejante.tres") as ItemData
	var equipped_bow := InventoryItemState.new(bow)
	second_actor.inventory_items.append(equipped_bow)
	check(equipment.equip(second_actor, equipped_bow, second_skills,
		second_game.campaign), "Arco Épico equipado para a Simbiose.")
	var carried_sword := InventoryItemState.new(sword)
	second_actor.inventory_items.append(carried_sword)
	second_actor.position = coord
	second_game.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	check(second_block.begin_activation(coord, second_actor),
		"Simbiose inicia com Épica equipada e outra na mochila.")
	check(second_popup.buttons.get_child_count() == 1 \
		and "ARCO DA PRECISÃO" in (second_popup.buttons.get_child(0) as Button).text,
		"Épica equipada tem prioridade sobre Épica carregada.")
	(second_popup.buttons.get_child(0) as Button).pressed.emit()
	if second_popup._outcome_reading:
		second_popup._execute_prepared_event()
	var chosen: ItemData
	for grant in second_skills.get_passive_grants(second_actor):
		if grant.skill.id == &"permanent_passive_058":
			chosen = grant.bound_source as ItemData
	check(not second_block.is_busy() and chosen != null and chosen.id == bow.id \
		and carried_sword in second_actor.inventory_items \
		and second_actor.equipped_weapons.is_empty(),
		"Simbiose consome só a Épica equipada e mantém a outra na mochila.")
	print("PPP symbiosis: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
