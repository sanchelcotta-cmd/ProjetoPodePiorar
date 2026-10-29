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
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var block := scene.get_node("BlockManager") as BlockManager
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var data: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(data) and round_manager.start_first_map(),
		"Campanha inicia para sorteios ramificados.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	var grid := campaign.current_map
	var event10 := load("res://resources/events/random_events/10-soro_desconhecido.tres") as EventData
	var event24 := load("res://resources/events/random_events/24-fantasmas_buh.tres") as EventData
	var event25 := load("res://resources/events/random_events/25-pacto_de_sangue.tres") as EventData
	var event44 := load("res://resources/events/random_events/44-duas_caras.tres") as EventData
	var results: Array[Dictionary] = []
	executor.result_ready.connect(func(_context: Dictionary, result: Dictionary) -> void:
		results.append(result.duplicate(true)))
	check(scene.get_node_or_null("RandomRollUI") == null,
		"Não há mais botão provisório de moeda no mapa.")
	check(event10 != null and event24 != null and event25 != null and event44 != null,
		"Resources 10, 24, 25 e 44 carregam.")
	if event10 == null or event24 == null or event25 == null or event44 == null:
		quit(1)
		return
	check(event24.narrative_description == "Os fantasmas podem ser bonzinhos. Mas nem todos... Alguns Outros, não são!"
		and event24.outcomes[0].narrative_description.contains("desaparece dando uma risadinha")
		and event24.outcomes[1].narrative_description.contains("Buh!\nQuando tudo acaba, o terror ainda ecoa."),
		"24 exibe a abertura e as duas narrativas revisadas.")
	check(event25.outcomes[0].narrative_description.contains("Você perde um pouco de vida, mas garante um item.")
		and event25.outcomes[1].narrative_description.contains("Você não perde nada, mas também não ganha nada."),
		"25 exibe a consequência narrativa de aceitar ou recusar.")

	# O mecanismo da moeda consulta as opções do Resource: não há lógica
	# exclusiva de ev_00044, então outro Evento pode usá-lo depois.
	check(event44.guess_options == Array([&"cara", &"coroa"])
		and event44.resolution_mode == EventData.ResolutionMode.PLAYER_GUESSES_RANDOM_OPTION,
		"44 cadastra duas faces reutilizáveis.")
	check(not executor._select_outcome(event44, {"guess": &"x"}).get("success", false),
		"Palpite inválido não lança a moeda.")
	var refusal := executor._select_outcome(event44, {"refused": true})
	check(refusal.get("success", false) and refusal.get("outcome") == event44.guess_refusal_outcome,
		"Recusa não lança nem aplica prêmio/punição.")
	var seed := 5021
	var probe := RandomNumberGenerator.new()
	probe.seed = seed
	var winning_guess := event44.guess_options[CoinFlip.flip(probe)]
	executor._rng.seed = seed
	var previous_count := campaign.obtained_information_ids.size()
	var coord := Vector2i(4, 0)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event44)
	check(block.begin_activation(coord, actor), "44 abre a narrativa antes do palpite.")
	popup._select_coin_guess(winning_guess)
	check(popup._coin_choice == winning_guess and results.is_empty(),
		"Escolher face não executa nem sorteia o Outcome.")
	await popup._animate_coin_and_confirm()
	check(popup._outcome_reading and campaign.obtained_information_ids.size() == previous_count
		and popup.narrative_label.text.contains("A moeda caiu"),
		"A/B anima, revela acerto e aguarda o OK antes de conceder Informação.")
	popup._execute_prepared_event()
	check(campaign.obtained_information_ids.size() == previous_count + 1
		and results.back().get("guessed", false), "Acerto concede uma Informação nova.")
	popup._acknowledge_event_result()
	check(not block.is_busy(), "44 encerra após a leitura da Informação.")
	var first_info_id: StringName = campaign.obtained_information_order.back()
	var second_info: Informacao
	for resource in gerencia.get_information_catalog():
		var info := resource as Informacao
		if info != null and info.id != first_info_id:
			second_info = info
			break
	check(second_info != null and campaign.record_information_obtained(second_info),
		"Uma segunda Informação forma uma ordem de obtenção.")
	var losing_guess := event44.guess_options[1 - CoinFlip.flip(probe)]
	executor._rng.seed = seed
	campaign.event_last_handled_round.erase(event44.resource_path)
	coord = Vector2i(5, 0)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event44)
	check(block.begin_activation(coord, actor), "44 pode ser ativado novamente para testar erro.")
	popup._confirm_event({"guess": losing_guess})
	check(popup._outcome_reading and campaign.obtained_information_ids.has(second_info.id),
		"Erro também aguarda confirmação antes de esquecer.")
	popup._execute_prepared_event()
	check(not campaign.obtained_information_ids.has(second_info.id)
		and campaign.obtained_information_ids.has(first_info_id)
		and not results.back().get("guessed", true),
		"Erro esquece somente a Informação obtida por último.")
	check(popup.narrative_label.text.contains(second_info.titulo),
		"A caixa informa qual Informação foi esquecida.")
	popup._acknowledge_event_result()
	campaign.event_last_handled_round.erase(event44.resource_path)
	coord = Vector2i(6, 0)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event44)
	check(block.begin_activation(coord, actor), "44 oferece a recusa.")
	popup._confirm_event({"refused": true})
	check(popup._outcome_reading, "A recusa mostra sua própria narrativa.")
	popup._execute_prepared_event()
	check(not block.is_busy() and campaign.obtained_information_ids.has(first_info_id),
		"Recusar não altera as Informações.")

	# Cada um dos cinco outcomes do Soro precisa de executor real.
	var weights: Array[int] = []
	for outcome in event10.outcomes:
		weights.append(outcome.weight)
		for effect in outcome.effects:
			check(executor._unsupported_reason(effect, {"resource": event10, "actor": actor,
				"map": grid, "decision": {"accepted": true}}).is_empty(),
				"10 executa o efeito de %s." % outcome.display_name)
	check(weights == [10, 20, 20, 30, 20], "10 respeita pesos 10/20/20/30/20.")
	for index in event10.outcomes.size():
		var branch_actor := EntityState.from_playable_selection(data[0],
			StringName("Soro_%d" % index), EntityState.UNPLACED)
		var branch_context := {"resource": event10, "actor": branch_actor, "map": grid}
		var base_health := branch_actor.max_health
		var base_attack := branch_actor.attack
		for effect in event10.outcomes[index].effects:
			check(executor._apply_effect(effect, branch_actor, event10, branch_context, false)
				.get("success", false), "10 aplica %s." % event10.outcomes[index].display_name)
		match index:
			0: check(branch_actor.max_health == base_health * 2
				and branch_actor.attack == base_attack * 2, "Superpoder dobra Vida máxima e Ataque.")
			1: check(branch_actor.max_health == base_health + 5
				and branch_actor.attack == base_attack + 2, "Força soma +5/+2.")
			2: check(&"db_00003" in branch_actor.permanent_status_immunities
				and &"db_00005" in branch_actor.permanent_status_immunities,
				"Imunidade protege dos três estágios de Doença.")
			3: check(skill_manager.debuff_manager.get_debuff(branch_actor, &"db_00004") != null,
				"Ramo Doença aplica o Debuff descrito no Resource.")
			4: check(branch_actor.max_health == base_health
				and branch_actor.attack == base_attack, "Placebo não altera atributos.")
	check(executor._select_outcome(event10, {"accepted": false}).get("outcome") == null,
		"Recusar o Soro não gera consequência.")
	coord = Vector2i(6, 0)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event10)
	check(block.begin_activation(coord, actor), "10 abre a opção de recusar o Soro.")
	var refusal_health := actor.max_health
	var refusal_attack := actor.attack
	var results_before_refusal := results.size()
	popup._confirm_event({"accepted": false})
	check(popup._outcome_reading and popup.title_label.text == "RECUSA"
		and popup.narrative_label.text == event10.refusal_narrative_description,
		"10 apresenta a narrativa de recusa numa caixa de resultado.")
	check(results.size() == results_before_refusal and actor.max_health == refusal_health
		and actor.attack == refusal_attack,
		"A recusa não aplica efeitos antes do OK.")
	popup._execute_prepared_event()
	check(not block.is_busy() and results.size() == results_before_refusal + 1
		and not results.back().get("accepted", true)
		and results.back().get("outcome_id", &"") == &""
		and actor.max_health == refusal_health and actor.attack == refusal_attack,
		"Após o OK, a recusa encerra sem sorteio ou efeito.")
	campaign.event_last_handled_round.erase(event10.resource_path)
	coord = Vector2i(7, 0)
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event10)
	check(block.begin_activation(coord, actor), "10 abre a escolha do Soro.")
	var old_health := actor.max_health
	var old_attack := actor.attack
	popup._confirm_event({"accepted": true})
	check(popup._outcome_reading and actor.max_health == old_health and actor.attack == old_attack,
		"10 sorteia e narra o ramo antes de aplicar os atributos.")
	popup._execute_prepared_event()
	check(results.back().get("event_id") == &"ev_00010" and not block.is_busy(),
		"10 aplica o ramo e conclui o bloco.")
	for branch_index in event10.outcomes.size():
		var branch_seed := -1
		for candidate in 200:
			executor._rng.seed = candidate
			if executor._select_outcome(event10, {"accepted": true}).get("outcome") \
					== event10.outcomes[branch_index]:
				branch_seed = candidate
				break
		check(branch_seed >= 0, "10 sorteia o ramo %d." % branch_index)
		if branch_seed < 0:
			continue
		campaign.event_last_handled_round.erase(event10.resource_path)
		executor._rng.seed = branch_seed
		coord = Vector2i(branch_index, 2)
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event10)
		check(block.begin_activation(coord, actor), "10 inicia ramo %d." % branch_index)
		popup._confirm_event({"accepted": true})
		check(popup._outcome_reading and popup.title_label.text \
			== event10.outcomes[branch_index].display_name.to_upper(),
			"10 apresenta o ramo %d antes do efeito." % branch_index)
		popup._execute_prepared_event()
		check(not block.is_busy() and results.back().get("outcome_name") \
			== event10.outcomes[branch_index].display_name,
			"10 aplica e encerra o ramo %d." % branch_index)

	# Os Fantasmas têm apenas os dois pesos cadastrados, sem escolha falsa.
	check(event24.outcomes.size() == 2 and event24.outcomes[0].weight == 30
		and event24.outcomes[1].weight == 70,
		"24 mantém item 30% e dano/Terror 70%.")
	for outcome in event24.outcomes:
		for effect in outcome.effects:
			check(executor._unsupported_reason(effect, {"resource": event24, "actor": actor,
				"map": grid}).is_empty(),
				"24 executa o efeito de %s." % outcome.display_name)
	var good_seed := -1
	var bad_seed := -1
	for candidate in 100:
		executor._rng.seed = candidate
		var chosen := executor._select_outcome(event24, {}).get("outcome") as EventOutcomeData
		if chosen == event24.outcomes[0] and good_seed < 0:
			good_seed = candidate
		if chosen == event24.outcomes[1] and bad_seed < 0:
			bad_seed = candidate
	check(good_seed >= 0 and bad_seed >= 0, "24 alcança ambos os ramos do sorteio.")
	if good_seed >= 0:
		executor._rng.seed = good_seed
		coord = Vector2i(0, 1)
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event24)
		var item_count := actor.inventory_items.size()
		check(block.begin_activation(coord, actor), "24 inicia ramo de item.")
		popup._confirm_event({})
		check(popup._outcome_reading and actor.inventory_items.size() == item_count,
			"24 revela o Fantasma do Bem antes de conceder item.")
		popup._execute_prepared_event()
		check(actor.inventory_items.size() == item_count + 1 and not block.is_busy(),
			"Fantasma do Bem entrega item aleatório e encerra.")
	if bad_seed >= 0:
		campaign.event_last_handled_round.erase(event24.resource_path)
		executor._rng.seed = bad_seed
		coord = Vector2i(1, 1)
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event24)
		var before_health: Array[int] = []
		for member in campaign.active_entity_states:
			member.current_health = member.max_health
			before_health.append(member.current_health)
		check(block.begin_activation(coord, actor), "24 inicia ramo de dano/Terror.")
		popup._confirm_event({})
		check(popup._outcome_reading and actor.current_health == before_health[0],
			"24 narra o Fantasma do Mal antes de causar dano.")
		popup._event_die_pending = false
		popup._execute_prepared_event()
		var group_hurt := true
		for index in campaign.active_entity_states.size():
			var member := campaign.active_entity_states[index]
			var terror := skill_manager.debuff_manager.get_debuff(member, &"db_00009")
			group_hurt = group_hurt and member.current_health == before_health[index] - 2 \
				and terror != null and terror.remaining_turns >= 1 \
				and terror.remaining_turns <= 4
		check(group_hurt and not block.is_busy(),
			"Fantasma do Mal dá 2 de dano e Terror 1d4 em todo o grupo.")
	if good_seed >= 0:
		campaign.event_last_handled_round.erase(event24.resource_path)
		executor._rng.seed = good_seed
		coord = Vector2i(2, 1)
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event24)
		var previous_capacity := actor.base_inventory_capacity
		actor.base_inventory_capacity = actor.inventory_used_space() - actor.inventory_capacity_bonus
		check(block.begin_activation(coord, actor), "24 pode iniciar com inventário lotado.")
		popup._confirm_event({})
		popup._execute_prepared_event()
		check(block.is_busy() and popup.feedback_label.text.contains("Libere espaço")
			and popup.buttons.get_child_count() == 2,
			"Prêmio lotado oferece escolher troca, sem perder o ramo. busy=%s; aviso=%s; botões=%d; outcome=%s" % [
			str(block.is_busy()), popup.feedback_label.text, popup.buttons.get_child_count(),
			str(executor._prepared.get("outcome"))])
		var reward := executor.get_prepared_item_reward()
		var selected_item := reward.get("item") as ItemData
		var reward_effect := reward.get("effect") as Event_EffectData
		check(selected_item != null, "Item sorteado fica conhecido antes da troca.")
		reward_effect.item_acceptance_required = true
		popup._open_inventory_for_event()
		var group := (scene.get_node("CampaignTopBar") as CampaignTopBar).group_inventory
		check(group.visible and group._exchange_item == selected_item,
			"Inventário do grupo mostra o mesmo item sorteado.")
		check(not group._exchange_decline_button.visible and
			not executor.decline_prepared_item(),
			"Outcome marcado obrigatório não pode ser recusado pela UI nem pela regra.")
		for entry in actor.inventory_items:
			if entry.data.can_be_discarded:
				group._exchange_selected.append(entry)
				if executor._inventory_manager.can_exchange_items(actor,
						group._exchange_selected, selected_item):
					break
		group._update_exchange_ui()
		check(not group._exchange_accept_button.disabled,
			"Espaço selecionado habilita a troca.")
		group._ask_exchange_confirmation()
		group._confirm_exchange()
		check(not block.is_busy() and results.back().get("event_id") == &"ev_00024"
			and results.back().get("effects", [])[0].get("item") == selected_item,
			"Confirmar troca entrega o mesmo prêmio e conclui o Evento.")
		reward_effect.item_acceptance_required = false
		actor.base_inventory_capacity = previous_capacity
	for resource in gerencia.get_information_catalog():
		var info := resource as Informacao
		if info != null:
			campaign.record_information_obtained(info)
	var edge_context := {"resource": event44, "actor": actor, "map": grid}
	var no_new_info := executor._apply_effect(event44.guess_match_outcome.effects[0],
		actor, event44, edge_context, false)
	check(no_new_info.get("success", false)
		and no_new_info.get("no_eligible_information", false),
		"Acerto com catálogo esgotado é explicado, não trava o Evento.")
	campaign.obtained_information_ids.clear()
	campaign.obtained_information_order.clear()
	var no_info_to_lose := executor._apply_effect(event44.guess_miss_outcome.effects[0],
		actor, event44, edge_context, false)
	check(no_info_to_lose.get("success", false)
		and no_info_to_lose.get("forgotten_information_id") == &"",
		"Erro sem Informação para esquecer não trava o Evento.")
	if failures == 0:
		print("RANDOM_EVENTS_GROUP4_TEST_OK")
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
