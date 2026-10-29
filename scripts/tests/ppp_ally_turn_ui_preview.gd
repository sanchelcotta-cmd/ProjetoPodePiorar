extends SceneTree

## Janela isolada para revisão manual do combate com aliado recrutado.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	DisplayServer.window_set_title("PPP · revisão de aliados")
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var combat := scene.get_node("CombatManager") as CombatManager
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	if not game.start_new_game(selected) or not rounds.start_first_map():
		return
	var owner := game.campaign.active_entity_states[0]
	owner.position = Vector2i(3, 2)
	var ally := EntityState.from_encounter_member(load(
		"res://resources/entities/entities_general/goblin_1.tres"),
		&"ally_ui_preview", 1, EntityState.UNPLACED)
	game.campaign.register_companion(owner, ally)
	var encounter := load(
		"res://resources/encounters/enc_zumbis_dancarinos_suburbio.tres") as EncounterData
	game.campaign.current_map.set_ppp_block(owner.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	block.begin_activation(owner.position, owner)
	(popup.buttons.get_child(0) as Button).pressed.emit()
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": ally})
	combat.initiative_order.append({"entity": owner})
	for enemy in combat.enemies:
		combat.initiative_order.append({"entity": enemy})
	(scene.get_node("InitiativeTurnBar") as InitiativeTurnBar)._reload_participants()
	combat._start_combat_turns()
