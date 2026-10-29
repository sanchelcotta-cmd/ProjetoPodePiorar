extends SceneTree

## Regressão dos Efeitos Permanentes que já devem funcionar na Exploração.
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
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	check(gerencia.start_new_game(choices) and round_manager.start_first_map(),
		"A campanha inicia para testar efeitos permanentes.")
	for member in gerencia.campaign.active_entity_states:
		member.inventory_items.clear() # Eventos testados sem o kit aleatório inicial.
	var actor := gerencia.campaign.active_entity_states[0]
	var grid := gerencia.campaign.current_map
	var epic_entry: InventoryItemState
	var curse_entry: InventoryItemState
	var coords := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0),
		Vector2i(7, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var ids := [55, 56, 57, 58, 59, 60, 62, 63, 64, 65, 69]
	for i in ids.size():
		var event_path := _event_path(ids[i])
		var event := load(event_path) as EventData
		check(event != null, "Resource %d pode ser carregado." % ids[i])
		if event == null:
			continue
		var coord: Vector2i = coords[i]
		actor.position = coord
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
		if ids[i] == 58:
			var epic := load("res://resources/itens/equipments/armas/arma_epica_espada_irada_flamejante.tres") as ItemData
			epic_entry = InventoryItemState.new(epic)
			actor.inventory_items.append(epic_entry)
		if ids[i] == 59:
			check(skill_manager.debuff_manager.apply_by_id(actor, &"db_00008",
				null, 0, gerencia.campaign.day, -1, &"", -1.0, 3).get("success", false),
				"Sangramento já está ativo antes de Pele Endurecida.")
			check(skill_manager.debuff_manager.apply_by_id(actor, &"db_00002").get("success", false),
				"Atordoamento já está ativo antes de Pele Endurecida.")
		if ids[i] == 60:
			curse_entry = InventoryItemState.new(load(
				"res://resources/itens/curseds/espelho_quebrado.tres"))
			actor.inventory_items.append(curse_entry)
			for status_id in [&"db_00005", &"db_00010", &"db_00009"]:
				check(skill_manager.debuff_manager.apply_by_id(actor, status_id).get("success", false),
					"Debuff %s já está ativo antes da Áurea Milagrosa." % status_id)
		check(block.begin_activation(coord, actor), "Evento %d inicia." % ids[i])
		var decision := {}
		if ids[i] == 56:
			decision = {"selected_mastery": EntityData.Mastery.BLADE}
		elif ids[i] == 58:
			decision = {"selected_item": actor.inventory_items.back()}
		popup._confirm_event(decision)
		if popup._outcome_reading:
			popup._execute_prepared_event()
		check(not block.is_busy(), "Evento %d conclui seu Outcome." % ids[i])
		if block.is_busy():
			push_error("Evento %d bloqueou a suíte: %s" % [ids[i], popup.feedback_label.text])
			quit(1)
			return
		if ids[i] == 59 or ids[i] == 60:
			var protected_ids: Array[StringName] = []
			if ids[i] == 59:
				protected_ids.assign([&"db_00008", &"db_00002"])
			else:
				protected_ids.assign([&"db_00003", &"db_00004", &"db_00005", &"db_00010", &"db_00009"])
			for status_id in protected_ids:
				check(skill_manager.debuff_manager.get_debuff(actor, status_id) == null \
					and skill_manager.is_status_immune(actor, status_id),
					"Evento %d limpa %s existente e torna o alvo imune." % [ids[i], status_id])
				check(skill_manager.debuff_manager.apply_by_id(actor, status_id,
					null, 0, gerencia.campaign.day, -1, &"", -1.0, 3).get("immune", false),
					"Evento %d também impede nova aplicação direta de %s." % [ids[i], status_id])
	check(actor.has_mastery(EntityData.Mastery.BLADE),
		"Prótese concede a Maestria escolhida.")
	check(epic_entry not in actor.inventory_items,
		"Simbiose absorve a cópia exata da arma Épica.")
	var previous_max := actor.max_health
	var previous_attack := actor.attack
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	gerencia.campaign.record_information_obtained(information)
	skill_manager.on_information_obtained(gerencia.campaign)
	check(actor.max_health == previous_max + 2 and actor.attack == previous_attack + 2,
		"Informação é Poder recalcula Vida máxima e Ataque ao obter uma Informação.")
	check(actor.permanent_curse_immunity,
		"Áurea Milagrosa protege contra maldições.")
	check(curse_entry not in actor.inventory_items,
		"Áurea Milagrosa remove as maldições que o portador já possuía.")
	var curse_coord := Vector2i(5, 1)
	actor.position = curse_coord
	var new_curse := load("res://resources/itens/curseds/agulha_de_costura.tres") as ItemData
	grid.set_ppp_block(curse_coord, HexGrid.PPPBlockType.CURSE, new_curse)
	check(block.begin_activation(curse_coord, actor), "Nova maldição abre a caixa para leitura.")
	check(popup.buttons.get_child_count() == 1 \
		and (popup.buttons.get_child(0) as Button).text == "OK",
		"A imunidade oferece OK em vez de obrigar a carregar a nova maldição.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not block.is_busy() and actor.inventory_items.all(func(entry: InventoryItemState) -> bool:
		return entry.data != new_curse),
		"Nova maldição é impedida e seu bloco termina normalmente.")
	check(actor.ignore_ranged_critical_bonus,
		"Pele Endurecida registra proteção contra crítico à distância.")
	for passive_id in [&"permanent_passive_055", &"permanent_passive_056",
			&"permanent_passive_057", &"permanent_passive_058",
			&"permanent_passive_059", &"permanent_passive_060",
			&"permanent_passive_062"]:
		check(skill_manager.get_passive_grants(actor).any(func(grant: SkillGrantState) -> bool:
			return grant.skill.id == passive_id),
			"Efeito permanente instala a Passiva %s no personagem." % passive_id)
	for active_id in [&"permanent_active_055", &"permanent_active_069"]:
		check(skill_manager.get_active_grants(actor).any(func(grant: SkillGrantState) -> bool:
			return grant.skill.id == active_id),
			"Efeito permanente instala a Ativa %s no personagem." % active_id)
	check(gerencia.campaign.companion_states.size() == 3,
		"Doguinho, Gatinho e aliado humano entram na party.")
	var human := gerencia.campaign.companion_states[2]
	check(human.base_inventory_capacity == 0,
		"Aliado humano não carrega itens.")
	var view := scene.get_node("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	check(view.visuals_by_id.size() == 3,
		"Gatinho, Doguinho e aliado humano aparecem visualmente na Exploração.")
	for visual in view.visuals_by_id.values():
		var actor_visual := visual as CompanionActorVisual
		if actor_visual.state.data.tags.has(&"jogavel"):
			continue
		check((actor_visual._roam_timer.time_left >= 5.0 \
			or (actor_visual._motion != null and actor_visual._motion.is_running())) \
			and actor_visual.state.position == EntityState.UNPLACED,
			"Gatinho e Doguinho passeiam sem ocupar hex e pausam 6–12 segundos.")
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	hud._open_card = hud.cards[0]
	hud._rebuild_action_buttons()
	var passive_labels: Array[String] = []
	for button in hud.passive_buttons.get_children():
		passive_labels.append((button as Button).text.replace("\n", " "))
	check(passive_labels.any(func(label: String) -> bool:
		return "PELE ENDURECIDA" in label) and passive_labels.any(func(label: String) -> bool:
		return "ÁUREA MILAGROSA" in label),
		"HUD oferece consulta às Passivas permanentes 59 e 60.")
	var active_labels: Array[String] = []
	for button in hud.skill_buttons.get_children():
		active_labels.append((button as Button).text.replace("\n", " "))
	check(active_labels.any(func(label: String) -> bool:
		return "VISÃO BIÔNICA" in label) and active_labels.any(func(label: String) -> bool:
		return "UMA MALETA DE CURA" in label),
		"HUD oferece os botões das Ativas permanentes 55 e 69.")
	var sheet := hud.character_sheet
	sheet.open_for(actor, skill_manager, Vector2(400, 200))
	var acquired_text := ""
	for page in range(1, sheet._page_count()):
		sheet.page_index = page
		sheet._render_page()
		for label in sheet.skill_list.find_children("*", "Label", true, false):
			acquired_text += (label as Label).text + "\n"
	check("Pele Endurecida" in acquired_text and "Áurea Milagrosa" in acquired_text,
		"Ficha apresenta as Passivas adquiridas nos Eventos 59 e 60.")
	sheet.hide()
	check(hud.ally_button.visible and hud._ally_roster.get_child_count() == 3,
		"A caixa do dono lista os três aliados para abrir suas fichas.")
	var human_listed := false
	for row in hud._ally_roster.get_children():
		human_listed = human_listed or (row.get_child(0) as Button).text \
			== human.visible_name().to_upper()
	check(human_listed, "O aliado humano aparece pelo nome na lista de aliados.")
	var donor := gerencia.campaign.active_entity_states[1]
	var recipient := gerencia.campaign.active_entity_states[2]
	var weapon := InventoryItemState.new(load("res://resources/itens/equipments/armas/martelo.tres"))
	donor.inventory_items.append(weapon)
	var equipment := EquipmentManager.new()
	check(equipment.equip_companion_from_playable(donor, human, weapon,
		skill_manager, gerencia.campaign),
		"Jogável escolhido entrega uma arma diretamente ao aliado humano.")
	check(weapon in human.equipped_weapons and weapon not in donor.inventory_items \
		and human.inventory_items.is_empty(),
		"Arma fica apenas no slot equipado, sem inventário do aliado.")
	check(equipment.unequip_companion_to_playable(human, recipient, weapon,
		skill_manager, gerencia.campaign),
		"Outro jogável escolhido recebe a mesma cópia ao desequipar.")
	check(weapon in recipient.inventory_items and human.equipped_weapons.is_empty(),
		"Desequipar não duplica o item.")
	var maleta: SkillGrantState
	for grant in skill_manager.get_active_grants(actor):
		if grant.skill.id == &"permanent_active_069":
			maleta = grant
	check(maleta != null, "Maleta de Cura vira uma Ativa de uso único.")
	if maleta != null:
		var disease := load("res://resources/skills/effects/debuffs/doenca_1.tres") as DebuffData
		skill_manager.debuff_manager.apply_debuff(recipient, disease)
		actor.turn_state = EntityState.TurnState.TURNING
		check(skill_manager.use_exploration_active(actor, actor, maleta,
			gerencia.campaign), "Maleta de Cura pode ser usada na Exploração.")
		check(skill_manager.debuff_manager.get_debuff(recipient, disease.id) == null \
			and maleta not in actor.skill_grants,
			"Maleta cura o grupo e desaparece após um uso.")
	for number in [68, 70]:
		var event := load(_event_path(number)) as EventData
		var coord := Vector2i(3 if number == 68 else 4, 1)
		actor.position = coord
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
		check(block.begin_activation(coord, actor), "Evento %d inicia." % number)
		popup._confirm_event({})
		var expected_story := event.outcomes[0].narrative_description.strip_edges()
		if expected_story.is_empty():
			expected_story = event.outcomes[0].display_name
		check(popup._outcome_reading and block.is_busy() \
			and popup.narrative_label.text == expected_story,
			"A narração do Outcome %d abre separada e antes dos efeitos." % number)
		if number == 68:
			var escape := InputEventKey.new()
			escape.pressed = true
			escape.keycode = KEY_ESCAPE
			popup._input(escape)
		else:
			var outside := InputEventMouseButton.new()
			outside.pressed = true
			outside.button_index = MOUSE_BUTTON_LEFT
			outside.position = popup.overlay.get_global_rect().end - Vector2(2, 2)
			popup._input(outside)
		check(not block.is_busy(), "Fechar o Outcome %d aplica o resultado." % number)
	check(skill_manager.get_active_grants(actor).any(func(grant: SkillGrantState) -> bool:
		return grant.skill.id == &"permanent_active_068"),
		"Adestramento Bestial é concedido; seu uso depende do Combate.")
	check(skill_manager.get_active_grants(actor).any(func(grant: SkillGrantState) -> bool:
		return grant.skill.id == &"permanent_active_070"),
		"Arqui-Inimigo é concedido; a declaração depende do Combate.")
	var goblins := load("res://resources/encounters/enc_goblins.tres") as EncounterData
	var mutation := load(_event_path(61)) as EventData
	var next_information: Array[Resource] = [
		load("res://resources/informacoes/orchestra/orchestra_2.tres")]
	var before_history_map := gerencia.prepare_map(next_information,
		gerencia.campaign.district, gerencia.campaign.round_period,
		gerencia.campaign.get_round_index())
	check(before_history_map != null and mutation.requires_completed_encounter \
		and not gerencia._map_generator._event_candidates(
			gerencia._map_generator._pools["all_events"]).has(mutation),
		"Mutação não entra no pool antes de um Encontro concluído, mesmo que o mapa tenha encontros gerados.")
	gerencia.campaign.record_completed_encounter(goblins)
	var after_history_map := gerencia.prepare_map(next_information,
		gerencia.campaign.district, gerencia.campaign.round_period,
		gerencia.campaign.get_round_index())
	check(after_history_map != null and gerencia._map_generator._has_completed_encounter_history,
		"Após registrar um Encontro concluído, Mutação passa pelo requisito de sorteio.")
	var chosen_enemy := goblins.members[1].entity
	var mutation_coord := Vector2i(6, 1)
	actor.position = mutation_coord
	grid.set_ppp_block(mutation_coord, HexGrid.PPPBlockType.EVENT, mutation)
	var before_mutation_hp := actor.max_health
	var before_mutation_attack := actor.attack
	check(block.begin_activation(mutation_coord, actor),
		"Mutação Genética oferece os tipos do último Encontro.")
	popup._confirm_event({"selected_enemy": chosen_enemy})
	if popup._outcome_reading:
		popup._execute_prepared_event()
	check(not block.is_busy() and actor.max_health == before_mutation_hp + chosen_enemy.vida_base \
		and actor.attack == before_mutation_attack + chosen_enemy.ataque_base,
		"Mutação copia os atributos base do inimigo escolhido, sem escolher por conta própria.")
	var combat := scene.get_node("CombatManager") as CombatManager
	combat.auto_start_turns = false
	var combat_coord := Vector2i(4, 3)
	actor.position = combat_coord
	grid.set_ppp_block(combat_coord, HexGrid.PPPBlockType.ENCOUNTER, goblins)
	check(block.begin_activation(combat_coord, actor),
		"Encontro real inicia com os aliados dos Eventos 63–65 recrutados.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT \
		and gerencia.campaign.companion_states.all(func(companion: EntityState) -> bool:
			return grid.is_valid(companion.position)) \
		and combat.initiative_order.any(func(entry: Dictionary) -> bool:
			return entry.get("entity") == gerencia.campaign.companion_states[0]) \
		and combat.initiative_order.any(func(entry: Dictionary) -> bool:
			return entry.get("entity") == gerencia.campaign.companion_states[1]) \
		and combat.initiative_order.any(func(entry: Dictionary) -> bool:
			return entry.get("entity") == human),
		"Doguinho, Gatinho e aliado humano nascem em hexes e entram na iniciativa.")
	var playable_health_before_victory := actor.current_health
	for companion in gerencia.campaign.companion_states:
		companion.current_health = 1
	check(combat.request_victory() and combat.confirm_conclusion() \
		and grid.ppp_map_mode == HexGrid.PPPMapMode.EXPLORATION,
		"Combate com os três aliados retorna à Exploração.")
	check(gerencia.campaign.companion_states.all(func(companion: EntityState) -> bool:
		return companion.current_health == companion.max_health) \
		and actor.current_health == playable_health_before_victory,
		"Ao concluir o Encontro, todos os aliados recuperam Vida total sem curar o jogável.")
	print("PPP permanent effects: %d falhas" % failures)
	await create_timer(2.6).timeout
	scene.queue_free()
	for _frame in 4:
		await process_frame
	quit(1 if failures else 0)


func _event_path(number: int) -> String:
	var directory := "res://resources/events/permanent_effects"
	for file in DirAccess.get_files_at(directory):
		if file.begins_with("%02d-" % number) and file.ends_with(".tres"):
			return directory.path_join(file)
	return ""


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
