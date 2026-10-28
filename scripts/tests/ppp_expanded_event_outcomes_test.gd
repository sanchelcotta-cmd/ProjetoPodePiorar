extends SceneTree

## Regressão: todos os ramos dos gnomos, raio de superpoderes, Fio de
## Alarme e retorno do Combate ao mesmo bloco de Evento.
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
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha inicia para outcomes expandidos.")
	var campaign := gerencia.campaign
	var grid := campaign.current_map
	var actor := campaign.active_entity_states[0]
	for member in campaign.active_entity_states:
		member.inventory_items.clear()
		# O ramo doloroso do primeiro gnomo pode causar mais de 10; o teste
		# subsequente de prêmio exige um destinatário vivo.
		member.current_health = member.max_health
		member.position = Vector2i(6, campaign.active_entity_states.find(member))
	campaign.obtained_information_ids[&"test_info"] = true
	var results: Array[Dictionary] = []
	executor.result_ready.connect(func(_context: Dictionary, result: Dictionary) -> void:
		results.append(result.duplicate(true)))
	var gnome := load("res://resources/events/random_events/gnomes_3/01-raio_misterioso.tres") as EventData
	for branch in gnome.outcomes.size():
		for index in gnome.outcomes.size():
			gnome.outcomes[index].weight = 1 if index == branch else 0
		var before_results := results.size()
		var before_attacks := {}
		for member in campaign.active_entity_states:
			before_attacks[member.instance_id] = member.attack
		var coord := Vector2i(branch, 0)
		actor.position = coord
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, gnome)
		_check(block.begin_activation(coord, actor), "Gnomo 1 ramo %d inicia." % branch)
		_confirm(popup)
		if branch == 3:
			await create_timer(0.9).timeout
		_check(results.size() == before_results + 1 and not block.is_busy(),
			"Gnomo 1 ramo %d encerra após efeito real." % branch)
		if results.size() <= before_results:
			continue
		var applied: Array = results.back().get("effects", [])
		_check(not applied.is_empty(), "Gnomo 1 aplica efeitos no ramo %d." % branch)
		if applied.is_empty():
			continue
		match branch:
			0:
				_check(applied.size() == 2 and applied[0].get("target") == applied[1].get("target"),
					"Força do gnomo usa o mesmo jogável aleatório nos dois efeitos.")
				if applied.size() == 2:
					var affected := _by_id(campaign, applied[0].get("target", &""))
					_check(affected != null and affected.attack == 2 * int(
						before_attacks.get(affected.instance_id, 0)),
						"Força dobra o Ataque do alvo sorteado.")
			1:
				var affected := _by_id(campaign, applied[0].get("target", &""))
				_check(affected != null and affected.unlimited_exploration_movement,
					"Teletransporte é concessão permanente, não salto imediato.")
			2:
				var affected := _by_id(campaign, applied[0].get("target", &""))
				_check(affected != null and affected.skill_grants.any(
					func(grant: SkillGrantState) -> bool:
						return grant.skill is PassiveSkillData \
							and (grant.skill as PassiveSkillData).id == &"ps_00014"),
					"Super-agilidade concede a Passiva de Esquiva ao sorteado.")
			3:
				_check(results.back().get("dice_results", []).size() == 1,
					"Raio doloroso reutiliza um único dado de seis lados.")
	var epic_gnome := load("res://resources/events/random_events/gnomes_3/04-presente_epico.tres") as EventData
	actor.position = Vector2i(4, 0)
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.EVENT, epic_gnome)
	_check(block.begin_activation(actor.position, actor), "Gnomo 4 inicia.")
	_confirm(popup)
	_check(not block.is_busy() and actor.inventory_items.any(
		func(entry: InventoryItemState) -> bool:
			return entry.data.rarity == ItemData.Rarity.EPIC),
		"Gnomo 4 entrega de fato um item Épico ao inventário.")
	var fruit_gnome := load("res://resources/events/random_events/gnomes_3/05-frutinha_magica.tres") as EventData
	actor.position = Vector2i(5, 0)
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.EVENT, fruit_gnome)
	_check(block.begin_activation(actor.position, actor), "Gnomo 5 inicia.")
	_confirm(popup)
	_check(not block.is_busy() and actor.inventory_items.any(
		func(entry: InventoryItemState) -> bool:
			return entry.data.id == &"cs_00017"),
		"Gnomo 5 entrega a Frutinha como cópia carregada.")
	# O sorteio do outro Distrito passa pela máquina de Combate e volta ao Evento.
	var other_gnome := load("res://resources/events/random_events/gnomes_3/03-encontro_de_outro_distrito.tres") as EventData
	actor.position = Vector2i(6, 0)
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.EVENT, other_gnome)
	_check(block.begin_activation(actor.position, actor), "Gnomo 3 inicia.")
	_confirm(popup)
	_check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT and combat.current_encounter != null \
		and campaign.district not in combat.current_encounter.districts,
		"Gnomo 3 inicia Encontro real de outro Distrito.")
	_check(combat.request_victory() and combat.confirm_conclusion(),
		"Combate do gnomo retorna pela janela de vitória.")
	_check(not block.is_busy() and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"Após vitória, o Evento conclui e volta à Exploração.")
	var former_period := campaign.round_period
	campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	var night_encounter := executor._other_district_encounter()
	_check(night_encounter != null and campaign.district not in night_encounter.districts \
		and night_encounter.members.any(func(member: EncounterMemberData) -> bool:
			return member != null and member.entity != null \
				and &"coisa_do_capeta" in member.entity.tags),
		"À Noite, o terceiro duende escolhe só Encontro infernal de outro Distrito.")
	campaign.round_period = former_period
	var mutation := load(
		"res://resources/events/permanent_effects/61-mutacao_genetica.tres") as EventData
	var copied_type := campaign.last_encounter_entity_types[0] \
		if not campaign.last_encounter_entity_types.is_empty() else null
	_check(copied_type != null,
		"Vitória real registra os tipos de inimigo para Mutação Genética.")
	if copied_type != null:
		var mutation_coord := Vector2i(5, 2)
		var old_max := actor.max_health
		var old_attack := actor.attack
		actor.position = mutation_coord
		grid.set_ppp_block(mutation_coord, HexGrid.PPPBlockType.EVENT, mutation)
		_check(block.begin_activation(mutation_coord, actor),
			"Mutação pode ser ativada após Combate concluído.")
		popup._confirm_event({"selected_enemy": copied_type})
		if popup._outcome_reading:
			popup._execute_prepared_event()
		_check(not block.is_busy() and actor.max_health == old_max + copied_type.vida_base \
			and actor.attack == old_attack + copied_type.ataque_base,
			"Mutação copia o EntityData escolhido do Combate real.")
	var encounter := load("res://resources/encounters/enc_zumbis_dancarinos_suburbio.tres") as EncounterData
	grid.set_ppp_block(Vector2i(7, 2), HexGrid.PPPBlockType.ENCOUNTER, encounter)
	var alarm := load("res://resources/events/traps/80-fio_de_alarme.tres") as EventData
	actor.position = Vector2i(6, 2)
	grid.set_ppp_block(actor.position, HexGrid.PPPBlockType.TRAP, alarm)
	var nearest := 999
	var nearest_encounters: Array[EncounterData] = []
	for candidate_coord in grid.cells:
		var cell := grid.get_cell(candidate_coord)
		if cell == null or cell.block_type != HexGrid.PPPBlockType.ENCOUNTER \
				or cell.state not in [HexGrid.PPPBlockState.HIDDEN,
					HexGrid.PPPBlockState.REVEALED]:
			continue
		var distance := HexGrid.distance(actor.position, candidate_coord)
		if distance < nearest:
			nearest = distance
			nearest_encounters.clear()
		if distance == nearest:
			nearest_encounters.append(grid.get_ppp_block_resource(candidate_coord) as EncounterData)
	_check(block.begin_activation(actor.position, actor), "Fio de Alarme inicia.")
	_confirm(popup)
	_check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT \
		and combat.current_encounter in nearest_encounters,
		"Fio escolhe Encontro do mapa e inicia Combate real.")
	_check(combat.request_victory() and combat.confirm_conclusion(),
		"Combate do alarme retorna pela janela de vitória.")
	_check(not block.is_busy() and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"Fio só conclui após o Combate.")
	# Mesmo com o bônus, só os hexes ainda ativáveis e desocupados entram na lista.
	var teleporter: EntityState
	for member in campaign.active_entity_states:
		if member.unlimited_exploration_movement:
			teleporter = member
	if teleporter != null:
		exploration.current_actor = teleporter
		teleporter.turn_state = EntityState.TurnState.TURNING
		teleporter.stamina_remaining = 0
		exploration._awaiting_block = false
		exploration._has_moved_this_turn = false
		var far := Vector2i(7, 4)
		grid.set_ppp_block(far, HexGrid.PPPBlockType.CONSUMABLE,
			load("res://resources/itens/consumables/bolinho_de_chuva.tres"))
		_check(exploration.get_available_destinations().has(far),
			"Teletransportador alcança hex distante mesmo com Estamina zero.")
	print("PPP expanded event outcomes: %d falha(s)" % failures)
	await create_timer(2.6).timeout
	scene.queue_free()
	for _frame in 4:
		await process_frame
	quit(0 if failures == 0 else 1)


func _confirm(popup: BlockActivationPopup) -> void:
	popup._confirm_event({})
	if popup._outcome_reading:
		popup._event_die_pending = false
		popup._execute_prepared_event()


func _by_id(campaign: CampaignState, id: StringName) -> EntityState:
	for member in campaign.active_entity_states:
		if member.instance_id == id:
			return member
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
