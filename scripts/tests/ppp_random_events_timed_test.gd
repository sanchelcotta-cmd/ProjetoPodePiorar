extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var skill := scene.get_node("SkillManager") as SkillManager
	var block := scene.get_node("BlockManager") as BlockManager
	var chosen: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(game.start_new_game(chosen) and round_manager.start_first_map(),
		"A campanha precisa iniciar para os eventos temporários.")
	var campaign := game.campaign
	var actor := campaign.active_entity_states[0]
	var teammate := campaign.active_entity_states[1]
	var context := {"actor": actor, "coord": actor.position,
		"map": campaign.current_map}
	var wind := load("res://resources/events/random_events/19-ventos_assombrosos.tres") as EventData
	context["resource"] = wind
	var stamina_effect := wind.outcomes[0].effects[0]
	check(executor._unsupported_reason(stamina_effect, context).is_empty(),
		"Ventos agora têm executor com expiração.")
	var old_stamina := actor.max_stamina
	check(executor._apply_effect(stamina_effect, actor, wind, context, false).get("success", false)
		and actor.max_stamina == maxi(0, old_stamina - 2),
		"Ventos retiram 2 de Estamina.")
	campaign.on_temporary_event_turn_finished(actor)
	check(actor.max_stamina == maxi(0, old_stamina - 2),
		"O turno de ativação não consome os dois turnos futuros.")
	actor.turn_serial += 1
	campaign.on_temporary_event_turn_finished(actor)
	check(actor.max_stamina == maxi(0, old_stamina - 2),
		"Ventos ainda valem no primeiro turno futuro.")
	actor.turn_serial += 1
	campaign.on_temporary_event_turn_finished(actor)
	check(actor.max_stamina == old_stamina, "Ventos expiram após dois turnos.")
	var companion := EntityState.from_playable_selection(chosen[1],
		&"Companion_Timed", EntityState.UNPLACED)
	companion.playable_slot_id = &""
	companion.owner_instance_id = actor.instance_id
	campaign.companion_states.append(companion)
	var companion_stamina := companion.max_stamina
	executor._apply_effect(stamina_effect, companion, wind, context, false)
	campaign.on_temporary_event_turn_finished(actor)
	for unused in 2:
		actor.turn_serial += 1
		campaign.on_temporary_event_turn_finished(actor)
	check(companion.max_stamina == companion_stamina,
		"Aliado sem turno lógico na Exploração recupera Estamina após dois turnos do dono.")
	campaign.companion_states.erase(companion)

	var ghost := load("res://resources/events/random_events/22-perseguicao_sobrenatural.tres") as EventData
	context["resource"] = ghost
	var ghost_effect := ghost.outcomes[0].effects[0]
	check(executor._unsupported_reason(ghost_effect, context).is_empty(),
		"Perseguição é aceita como gatilho recorrente.")
	executor._apply_effect(ghost_effect, actor, ghost, context, false)
	var old_hp := actor.current_health
	campaign.on_temporary_event_turn_started(actor)
	check(actor.current_health == maxi(0, old_hp - 2),
		"Perseguição causa 2 de dano no início do turno.")
	campaign.day += 1
	campaign.expire_temporary_events_for_clock()
	old_hp = actor.current_health
	campaign.on_temporary_event_turn_started(actor)
	check(actor.current_health == old_hp, "Perseguição expira no próximo Dia.")

	var flower := load("res://resources/events/random_events/45-florzinha_misteriosa.tres") as EventData
	context["resource"] = flower
	check(executor._select_outcome(flower, {}).get("success", false),
		"Florzinha entra no sorteio real de Outcomes, não só na aplicação direta.")
	var before_attack := actor.attack
	var before_life := actor.max_health
	var blessing := executor._apply_effect(flower.outcomes[0].effects[0], actor,
		flower, context, false)
	check(blessing.get("success", false) and
		(actor.attack == before_attack + 5 or actor.max_health == before_life + 5),
		"Florzinha concede +5 Ataque ou Vida.")
	var immune_ids: Array[StringName] = []
	if blessing.get("immunity") == &"terror":
		immune_ids.append(&"db_00009")
	else:
		immune_ids.assign([&"db_00003", &"db_00004", &"db_00005"])
	check(immune_ids.all(func(id: StringName) -> bool:
		return skill.is_status_immune(actor, id)),
		"Florzinha protege de Terror ou dos três graus de Doença.")
	actor.position = Vector2i(0, 0)
	teammate.position = Vector2i(1, 0)
	context["coord"] = Vector2i(0, 0)
	var spores := executor._apply_effect(flower.outcomes[1].effects[0], actor,
		flower, context, false)
	check(spores.get("success", false) and teammate.instance_id in spores.get("affected", []),
		"Esporos atingem entidades a até 3 hexágonos.")
	campaign.day += 1
	campaign.expire_temporary_events_for_clock()
	check(actor.attack == before_attack and actor.max_health <= before_life
		and immune_ids[0] not in actor.temporary_status_immunities,
		"A bênção e a imunidade são revertidas no Dia seguinte (Doença pode reduzir Vida separadamente).")

	var chicken := load("res://resources/events/random_events/51-transmutacao_galiforme.tres") as EventData
	context["resource"] = chicken
	check(executor._apply_effect(chicken.outcomes[0].effects[0], actor,
		chicken, context, false).get("success", false)
		and actor.temporary_appearance == &"chicken_form",
		"Galinha muda só a aparência da instância.")
	var party_view := scene.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
	var actor_visual := party_view.visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	check(actor_visual != null and not actor_visual.animated_sprite.visible,
		"A silhueta provisória substitui o sprite normal da Galinha.")
	campaign.round_period += 1
	campaign.expire_temporary_events_for_clock()
	check(actor.temporary_appearance == &"" and actor_visual.animated_sprite.visible,
		"Galinha expira visualmente na virada da Rodada.")

	var wagon := load("res://resources/events/random_events/53-carreta_da_alegria.tres") as EventData
	context["resource"] = wagon
	var wagon_visual := scene.get_node("CarretaVisualController") as CarretaVisualController
	wagon_visual.start_effect()
	check(wagon_visual._veil.visible and wagon_visual._veil.mouse_filter \
		== Control.MOUSE_FILTER_IGNORE and wagon_visual.layer < 50 \
		and wagon_visual._veil.size.x >= root.size.x \
		and wagon_visual._veil.size.y >= root.size.y,
		"O filtro da Carreta aparece abaixo do HUD e não captura cliques.")
	wagon_visual.stop_effect()
	check(not wagon_visual._veil.visible, "O filtro encerra ao fechar a narração.")
	actor.current_health = maxi(1, actor.max_health - 5)
	for effect in wagon.outcomes[0].effects:
		executor._apply_effect(effect, actor, wagon, context, false)
	check(actor.current_health == actor.max_health and skill.is_status_immune(actor, &"db_00009"),
		"Carreta cura e protege contra Terror.")
	campaign.day += 1
	campaign.expire_temporary_events_for_clock()
	check(not skill.is_status_immune(actor, &"db_00009"),
		"A imunidade da Carreta expira no Dia seguinte.")

	var solitude := load("res://resources/events/random_events/54-ninguem_alem_de_voce.tres") as EventData
	context["resource"] = solitude
	check(executor._select_outcome(solitude, {}).get("success", false),
		"Isolamento entra no fluxo normal do Evento.")
	var encounter_path := ""
	for filename in DirAccess.get_files_at("res://resources/encounters"):
		if filename.ends_with(".tres"):
			encounter_path = filename
			break
	var encounter := load("res://resources/encounters".path_join(encounter_path)) as EncounterData
	var encounter_coords := [Vector2i(3, 2), Vector2i(4, 2)]
	for encounter_coord in encounter_coords:
		campaign.current_map.set_ppp_block(encounter_coord, HexGrid.PPPBlockType.ENCOUNTER,
			encounter)
	var original_teammate_position := teammate.position
	check(executor._apply_effect(solitude.outcomes[0].effects[0], actor,
		solitude, context, false).get("success", false)
		and teammate.temporarily_absent_from_map
		and not campaign.can_act_during_solo(teammate),
		"Isolamento esconde e suspende os demais jogadores.")
	var teammate_visual := party_view.visuals_by_slot.get(teammate.playable_slot_id) as PlayableActorVisual
	check(teammate_visual != null and not teammate_visual.visible,
		"O membro isolado desaparece também do mapa visual.")
	var solo_visual = scene.get_node("SoloEventVisualController")
	check(solo_visual._banner_layer.visible,
		"A faixa Ninguém Além de Você aparece durante o efeito.")
	var item_coord := Vector2i(-1, -1)
	var cricket_coord := Vector2i(-1, -1)
	for encounter_coord in campaign.solo_saved_encounters:
		if campaign.current_map.get_ppp_block_type(encounter_coord) == HexGrid.PPPBlockType.ENCOUNTER:
			cricket_coord = encounter_coord
		else:
			item_coord = encounter_coord
	check(item_coord != Vector2i(-1, -1) and cricket_coord != Vector2i(-1, -1),
		"Os Encontros produzem tanto itens quanto Cric Cric durante o isolamento.")
	check(campaign.current_map.get_ppp_block_resource(item_coord) is ItemData,
		"O hex sorteado como item usa um ItemData real.")
	check(block.begin_activation(item_coord, actor)
		and block.get_phase() == BlockManager.Phase.WAITING_ITEM,
		"O item substituto abre a escolha normal de coleta, não o Combate.")
	check(block.finish_item_resolution(false) and not block.is_busy(),
		"É possível deixar o item temporário sem iniciar Encontro.")
	check(block.begin_activation(cricket_coord, actor) and block.is_busy()
		and solo_visual._dialog_layer.visible
		and solo_visual._dialog_heading.text == "Cric Cric..."
		and solo_visual._dialog_body.text == "Cric.. Cric.. Cric..",
		"O hex silencioso abre somente a caixa dos grilos.")
	solo_visual._okay_button.pressed.emit()
	check(not block.is_busy() and not solo_visual._dialog_layer.visible,
		"OKAY fecha Cric Cric sem iniciar combate ou entregar item.")
	var old_solo_map := campaign.current_map
	var following_map := HexGrid.new()
	following_map.generate_ppp_exploration_map()
	for encounter_coord in encounter_coords:
		following_map.set_ppp_block(encounter_coord, HexGrid.PPPBlockType.ENCOUNTER,
			encounter)
	campaign.record_generated_map(following_map)
	check(old_solo_map.get_ppp_block_type(item_coord) == HexGrid.PPPBlockType.ENCOUNTER
		and old_solo_map.get_ppp_block_type(cricket_coord) == HexGrid.PPPBlockType.ENCOUNTER
		and campaign.solo_saved_encounters.size() == 2,
		"Ao trocar de mapa no isolamento, o anterior é restaurado e o novo sorteado.")
	campaign.record_generated_map(old_solo_map)
	check(following_map.get_ppp_block_type(encounter_coords[0])
		== HexGrid.PPPBlockType.ENCOUNTER,
		"O mapa deixado para trás também recupera os Encontros originais.")
	for turn in 3:
		actor.turn_serial += 1
		campaign.on_temporary_event_turn_finished(actor)
	check(campaign.solo_turns_remaining == 0 and not teammate.temporarily_absent_from_map
		and teammate.position == original_teammate_position and teammate_visual.visible,
		"Após três turnos, o grupo retorna às posições originais.")
	for encounter_coord in encounter_coords:
		check(campaign.current_map.get_ppp_block_type(encounter_coord) \
			== HexGrid.PPPBlockType.ENCOUNTER \
			and campaign.current_map.get_ppp_block_resource(encounter_coord) == encounter,
			"Os hexes temporários recuperam seus Encontros originais.")
	check(not solo_visual._banner_layer.visible and solo_visual._dialog_layer.visible
		and solo_visual._dialog_body.text.contains("Você não está mais sozinho"),
		"A faixa desaparece e o retorno do grupo é anunciado.")
	solo_visual._okay_button.pressed.emit()
	check(not solo_visual._dialog_layer.visible, "OKAY fecha o aviso de retorno.")
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var wagon_coord := Vector2i(4, 1)
	campaign.current_map.set_ppp_block(wagon_coord, HexGrid.PPPBlockType.EVENT, wagon)
	actor.position = wagon_coord
	check(block.begin_activation(wagon_coord, actor),
		"Carreta entra no fluxo real de confirmação.")
	if popup.buttons.get_child_count() > 0:
		(popup.buttons.get_child(0) as Button).pressed.emit()
	check(wagon_visual._veil.visible and popup._outcome_reading,
		"O filtro começa junto com a leitura do efeito da Carreta.")
	if popup.buttons.get_child_count() > 0:
		(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not wagon_visual._veil.visible and not block.is_busy(),
		"Confirmar a leitura encerra o filtro e conclui a Carreta.")
	var solitude_coord := Vector2i(5, 1)
	campaign.current_map.set_ppp_block(solitude_coord, HexGrid.PPPBlockType.EVENT, solitude)
	actor.position = solitude_coord
	check(block.begin_activation(solitude_coord, actor),
		"Isolamento inicia a narrativa pelo fluxo real do bloco.")
	if popup.buttons.get_child_count() > 0:
		(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup._outcome_reading and campaign.solo_turns_remaining == 0,
		"O isolamento espera a leitura do Outcome antes de ocultar o grupo.")
	if popup.buttons.get_child_count() > 0:
		(popup.buttons.get_child(0) as Button).pressed.emit()
	check(campaign.solo_turns_remaining == 3 and not block.is_busy(),
		"O segundo OK aplica o isolamento e libera o bloco.")
	check(solo_visual._banner_layer.visible,
		"A faixa volta a ficar visível no segundo isolamento.")
	check(exploration.pass_turn() and campaign.solo_turns_remaining == 3
		and exploration.current_actor == actor
		and actor.turn_serial > campaign.solo_applied_turn_serial,
		"A vez da ativação não conta; começa um novo turno real do dono.")
	for next_turn in 3:
		check(exploration.pass_turn(), "O dono pode passar cada turno do isolamento.")
		check(campaign.solo_turns_remaining == 2 - next_turn,
			"Cada turno real do dono reduz o isolamento exatamente uma vez.")
	check(not teammate.temporarily_absent_from_map and teammate_visual.visible,
		"Depois do terceiro turno real, o grupo reaparece sem comando de teste.")
	check(solo_visual._dialog_layer.visible and not solo_visual._banner_layer.visible,
		"O terceiro turno real abre o aviso de retorno e esconde a faixa.")

	print("TIMED_RANDOM_EVENTS_OK" if failures == 0 else
		"TIMED_RANDOM_EVENTS_FAILED: %d" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
