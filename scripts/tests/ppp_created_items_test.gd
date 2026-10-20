extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
	]
	check(campaign.start_new_game(selected, 12), "Campanha deve iniciar com capacidade editável.")
	for member in campaign.active_entity_states:
		member.inventory_items.clear() # Isola as cópias fabricadas pelo teste.
	var owner := campaign.active_entity_states[0]
	owner.turn_state = EntityState.TurnState.TURNING
	owner.turn_serial = 1
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	campaign.current_map = grid
	var skills := SkillManager.new()
	root.add_child(skills)
	var player := PlayerSkillManager.new()
	player.skill_manager = skills
	root.add_child(player)
	var inventory := skills.inventory_manager
	check(owner.inventory_capacity() == 12, "Capacidade base deve ser 12.")
	owner.inventory_capacity_bonus = 3
	check(owner.inventory_capacity() == 15, "Bônus deve somar sem substituir a capacidade base.")
	owner.inventory_capacity_bonus = 0
	var cook_grant := skills.get_active_grants(owner)[0]
	check(skills.use_exploration_active(owner, owner, cook_grant, campaign), "Marmita deve criar um item.")
	check(owner.inventory_items.size() == 1, "Marmita entrega no inventário do próprio Cozinheiro.")
	var meal := owner.inventory_items[0].data
	check(meal.item_type == ItemData.ItemType.CONSUMABLE and meal.rarity != ItemData.Rarity.RARE \
		and &"comida" in meal.tags and &"recupera_vida" in meal.tags, "Marmita só traz comida que cura e não é rara.")
	check(not skills.use_exploration_active(owner, owner, cook_grant, campaign), "Marmita respeita uma vez por Rodada.")

	var filler := load("res://resources/itens/consumables/bolinho_de_chuva.tres") as ItemData
	while owner.inventory_used_space() + filler.inventory_space <= owner.inventory_capacity():
		check(inventory.add_item(owner, filler), "Preenchimento de teste deve caber.")
	var generated := inventory.deliver_created_item(owner, filler, campaign)
	check(generated.get("pending_recipient", false), "Com dono cheio e dois espaços alternativos, jogador escolhe.")
	check(player.has_pending_choice(), "A escolha de destinatário bloqueia novas ações até ser respondida.")
	check(inventory.get_pending_recipient_options().size() == 2, "Ambos os outros jogáveis devem ser opções.")
	check(player.answer_created_item_recipient(campaign.active_entity_states[2]), "Escolha do terceiro jogável deve entregar o item.")
	check(not player.has_pending_choice(), "Depois da escolha, as ações voltam a ficar disponíveis.")
	check(campaign.active_entity_states[2].inventory_items.size() == 1, "Item chegou à pessoa escolhida.")
	for recipient in campaign.active_entity_states.slice(1):
		while inventory.can_receive(recipient, filler):
			inventory.add_item(recipient, filler)
	generated = inventory.deliver_created_item(owner, filler, campaign)
	check(generated.get("pending_exchange", false) and not generated.get("item_lost", false),
		"Com os três inventários cheios, item criado aguarda troca confirmada.")

	var dog_data := load("res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	var dog := EntityState.from_playable_selection(dog_data, &"Companion_1", EntityState.UNPLACED)
	check(campaign.register_companion(owner, dog), "Doguinho pertence ao seu dono.")
	var return_signal := {"source_id": -1}
	skills.delayed_skill_effect_resolved.connect(func(_turn_owner: EntityState, result: Dictionary) -> void:
		return_signal["source_id"] = result.get("source_actor_id", -1)
	)
	var dog_grant := skills.get_active_grants(dog)[0]
	check(skills.use_exploration_active(dog, owner, dog_grant, campaign), "Vai Pegar deve enviar o Doguinho.")
	check(campaign.delayed_skill_effects.size() == 1 and dog.unavailable_until_owner_turn_serial == 3, "Retorno ocorre após dois turnos do dono.")
	check(not skills.can_use_exploration_active(dog, owner, dog_grant, campaign), "Doguinho fica indisponível enquanto busca.")
	owner.turn_serial = 2
	skills.resolve_delayed_effects_for_owner(owner, campaign)
	check(campaign.delayed_skill_effects.size() == 1, "Item não chega antes da hora.")
	owner.turn_serial = 3
	skills.resolve_delayed_effects_for_owner(owner, campaign)
	check(campaign.delayed_skill_effects.is_empty(), "Busca termina no turno devido.")
	check(return_signal["source_id"] == dog.instance_id,
		"O retorno identifica o Doguinho para sua animação de carregar.")
	check(owner.inventory_items.size() == 12, "Inventário cheio não recebe o item do Doguinho.")

	print("CREATED_ITEMS_TEST_OK" if failures == 0 else "CREATED_ITEMS_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
