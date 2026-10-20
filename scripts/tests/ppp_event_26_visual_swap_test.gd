extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var round_manager := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var party := scene.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(selected) and round_manager.start_first_map(),
		"Partida de teste do evento 26 inicia.")
	var campaign := gerencia.campaign
	var originals: Array[Dictionary] = []
	for actor in campaign.active_entity_states:
		originals.append({"data": actor.data, "health": actor.current_health,
			"attack": actor.attack, "stamina": actor.max_stamina,
			"skills": actor.skill_grants.duplicate(),
			"inventory": actor.inventory_items.duplicate(),
			"weapons": actor.equipped_weapons.duplicate(),
			"armors": actor.equipped_armors.duplicate(),
			"accessories": actor.equipped_accessories.duplicate(),
			"position": actor.position})
	var event := load("res://resources/events/random_events/26-troca_de_corpos.tres") as EventData
	var actor := campaign.active_entity_states[0]
	var coord := Vector2i(3, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	check(block.begin_activation(coord, actor), "Evento 26 abre no hex.")
	check(actor.visual_data() == actor.data, "A leitura inicial não troca a aparência.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup._outcome_reading and actor.visual_data() == actor.data,
		"A narração do Outcome precede a troca.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not block.is_busy(), "O OK aplica o evento 26 e encerra o bloco.")
	for index in campaign.active_entity_states.size():
		var member := campaign.active_entity_states[index]
		var expected := selected[(index - 1 + selected.size()) % selected.size()]
		check(member.visual_data() == expected and member.visible_name() == expected.display_name,
			"Nome e identidade visual seguem a rotação cíclica.")
		check(member.data == originals[index]["data"]
			and member.current_health == originals[index]["health"]
			and member.attack == originals[index]["attack"]
			and member.max_stamina == originals[index]["stamina"]
			and member.skill_grants == originals[index]["skills"]
			and member.inventory_items == originals[index]["inventory"]
			and member.equipped_weapons == originals[index]["weapons"]
			and member.equipped_armors == originals[index]["armors"]
			and member.equipped_accessories == originals[index]["accessories"],
			"A troca não move mecânica, Skills, inventário ou equipamento.")
		var visual := party.visuals_by_slot.get(member.playable_slot_id) as PlayableActorVisual
		check(visual != null and visual.data == expected,
			"O sprite e suas animações mudam no mapa imediatamente.")
		check(hud.cards[index].name_label.text == expected.display_name,
			"O HUD mostra o nome recebido.")
	# Uma segunda ocorrência, em outro hex, deve acionar a reversão pelo mesmo
	# fluxo de narrativa/Outcome/OK, sem alterar as fichas mecânicas.
	coord = Vector2i(4, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, event)
	check(block.begin_activation(coord, actor), "A segunda ocorrência abre normalmente.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not block.is_busy() and campaign.visual_swap_originals.is_empty(),
		"A segunda ativação reverte a troca visual e conclui o bloco.")
	for index in campaign.active_entity_states.size():
		var member := campaign.active_entity_states[index]
		check(member.visual_data() == originals[index]["data"]
			and member.visible_name() == selected[index].display_name,
			"A reversão devolve nome, sprite e retrato originais.")
	if failures == 0:
		print("PPP evento 26: fluxo, identidade visual, mecânica intacta e reversão passaram")
	else:
		push_error("PPP evento 26: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
