extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Mapa de Exploração e HUD iniciam.")
	var grid := gerencia.campaign.current_map
	for coord in grid.cells:
		grid.activate_ppp_block(coord)
	var destination := Vector2i(7, 1)
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	grid.set_ppp_block(destination, HexGrid.PPPBlockType.INFORMATION, info)
	_check(exploration.enter_map(true), "Turno do jogável reinicia.")
	var actor := exploration.current_actor
	var sadness := load("res://resources/skills/effects/debuffs/tristeza.tres") as DebuffData
	_check(exploration.player_skill_manager.skill_manager.debuff_manager.apply_debuff(
		actor, sadness).get("success", false), "Tristeza é aplicada ao jogável ilhado.")
	actor.stamina_remaining = 0
	exploration.refresh_map_feedback()
	var other_destination := Vector2i(0, 2)
	grid.set_ppp_block(other_destination, HexGrid.PPPBlockType.INFORMATION, info)
	_check(exploration.get_emergency_destination() == other_destination,
		"A saída do jogável ilhado existe mesmo se outro membro alcança o bloco.")
	grid.activate_ppp_block(other_destination)
	for member in gerencia.campaign.active_entity_states:
		if member != actor:
			member.current_health = 0
	_check(exploration.get_emergency_destination() == destination,
		"Último jogável vivo avança mesmo com Tristeza e Estamina zero.")
	hud._walk_target_actor = actor
	hud._on_hex_choice_requested(destination)
	_check(hud.hex_choice.visible
		and hud.hex_choice_title.text == "SEM HEX AO ALCANCE"
		and hud.hex_choice_buttons.get_child_count() == 1,
		"A mesma caixa contextual explica a exceção, sem nova janela.")
	var button := hud.hex_choice_buttons.get_child(0) as Button
	_check(button != null and button.text == "IR AO MAIS PRÓXIMO"
		and button.tooltip_text.is_empty() and actor.position != destination
		and button.get_theme_font_size("font_size") == 14
		and hud.hex_choice_title.get_theme_font_size("font_size") == 14,
		"O botão não duplica a dica em tooltip e espera confirmação.")
	button.pressed.emit()
	_check(actor.position == destination and actor.stamina_remaining == 0,
		"A confirmação move o personagem ao bloco disponível.")
	print("PPP emergency movement UI: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
