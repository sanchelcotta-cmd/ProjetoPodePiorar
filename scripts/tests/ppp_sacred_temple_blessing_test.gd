extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var inventory := (scene.get_node("SkillManager") as SkillManager).inventory_manager
	var data: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(game.start_new_game(data) and rounds.start_first_map(), "Campanha inicia.")
	var campaign := game.campaign
	var actor := campaign.active_entity_states[0]
	actor.base_inventory_capacity = 30
	var curse := load("res://resources/itens/curseds/agulha_de_costura.tres") as ItemData
	check(inventory.add_item(actor, curse), "Maldição de controle entra antes do Templo.")
	var temple := load("res://resources/events/random_events/32-templo_sagrado.tres") as EventData
	var coord := Vector2i(3, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, temple)
	check(block.begin_activation(coord, actor), "Templo abre normalmente.")
	popup._confirm_event({})
	check(popup._outcome_reading
		and popup.narrative_label.text.contains("O dia de hoje está abençoado.")
		and not campaign.has_sacred_temple_blessing(),
		"A bênção não começa antes de confirmar o resultado.")
	popup._execute_prepared_event()
	check(campaign.has_sacred_temple_blessing()
		and not _has_item(actor, curse),
		"Templo remove a maldição existente e protege o Dia atual.")
	var before := actor.inventory_items.size()
	check(inventory.add_item(actor, curse) and actor.inventory_items.size() == before,
		"Item amaldiçoado recebido por qualquer caminho é anulado sem ocupar espaço.")
	var grant := Event_EffectData.new()
	grant.effect_type = Event_EffectData.EffectType.GRANT_ITEM
	grant.item = curse
	var event_grant := (scene.get_node("EventExecutor") as EventExecutor)._apply_effect(
		grant, actor, temple, {}, false)
	check(event_grant.get("success", false)
		and event_grant.get("temple_blessing_nullified", false)
		and actor.inventory_items.size() == before,
		"Concessão por outro Evento também informa a anulação, sem entregar o item.")
	coord = Vector2i(4, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.CURSE, curse)
	check(block.begin_activation(coord, actor)
		and popup.narrative_label.text == "O dia de hoje está abençoado."
		and popup.buttons.get_child_count() == 1,
		"Hex de maldição mostra o resultado abençoado, sem escolha de item.")
	popup._acknowledge_curse_immunity()
	check(not block.is_busy() and actor.inventory_items.size() == before,
		"Hex é concluído e não entrega maldição.")
	var codec := CampaignSaveCodec.new()
	var saved := codec.encode(campaign)
	var restored := codec.decode(saved) as CampaignState
	check(restored != null and restored.has_sacred_temple_blessing(),
		"O Dia protegido persiste no save.")
	campaign.day += 1
	check(not campaign.has_sacred_temple_blessing()
		and inventory.add_item(actor, curse) and _has_item(actor, curse),
		"No Dia seguinte a proteção acaba e a maldição volta a funcionar.")
	print("SACRED_TEMPLE_BLESSING_TEST_OK" if failures == 0 else
		"SACRED_TEMPLE_BLESSING_TEST_FAIL %d" % failures)
	quit(1 if failures > 0 else 0)


func _has_item(actor: EntityState, item: ItemData) -> bool:
	for copy in actor.inventory_items:
		if copy != null and copy.data == item:
			return true
	return false


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
