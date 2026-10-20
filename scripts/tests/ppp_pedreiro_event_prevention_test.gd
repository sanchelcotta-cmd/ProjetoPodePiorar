extends SceneTree

## Integração: ao chegar, o Pedreiro vê a consequência e pode destruir o
## bloco ANTES de qualquer Outcome, inclusive Armadilha e Efeito Permanente.
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
	var player_skills := scene.get_node("PlayerSkillManager") as PlayerSkillManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var data: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(data) and round_manager.start_first_map(),
		"Campanha do Pedreiro deve iniciar.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	actor.turn_state = EntityState.TurnState.TURNING
	var grid := campaign.current_map
	var cases: Array[Dictionary] = [
		{"file": "res://resources/events/random_events/21-ataque_sobrenatural.tres",
			"type": HexGrid.PPPBlockType.EVENT},
		{"file": "res://resources/events/random_events/27-poco_magico_e_reluzente.tres",
			"type": HexGrid.PPPBlockType.EVENT},
		{"file": "res://resources/events/permanent_effects/67-todos_estao_doentes.tres",
			"type": HexGrid.PPPBlockType.EVENT},
		{"file": "res://resources/events/catastrophes/72-nevasca.tres",
			"type": HexGrid.PPPBlockType.CATASTROPHE},
		{"file": "res://resources/events/traps/77-minas_explosivas.tres",
			"type": HexGrid.PPPBlockType.TRAP},
	]
	for index in cases.size():
		var event := load(cases[index]["file"]) as EventData
		var coord := Vector2i(index, 0)
		actor.position = coord
		grid.set_ppp_block(coord, int(cases[index]["type"]), event)
		var health_before := actor.current_health
		var max_before := actor.max_health
		var debuffs_before := actor.debuffs.size()
		check(player_skills.offer_before_block_activation(actor, coord),
			"Pedreiro deve receber escolha preventiva para " + event.display_name)
		var cancel_button: Button = null
		for child in popup.buttons.get_children():
			if child is Button and "Quebra 4ª Parede" in child.text:
				cancel_button = child
		check(cancel_button != null and popup.overlay.visible and not block.is_busy(),
			"A caixa narrativa deve mostrar o botão CANCELAR antes do Outcome.")
		if cancel_button != null:
			cancel_button.pressed.emit()
		check(grid.get_cell(coord).state == HexGrid.PPPBlockState.DESTROYED \
			and not block.is_busy() and not popup.overlay.visible,
			"O botão destrói o hex e encerra a escolha sem ativar o evento.")
		check(actor.current_health == health_before and actor.max_health == max_before \
			and actor.debuffs.size() == debuffs_before,
			"Cancelar nunca deve aplicar dano, modificador ou Debuff.")
		# A habilidade é uma vez por Dia. Avançar somente o relógio do teste
		# permite verificar todos os tipos de bloco independentemente.
		campaign.day += 1
	var calmaria := load("res://resources/events/random_events/18-calmaria.tres") as EventData
	var good_coord := Vector2i(5, 0)
	actor.position = good_coord
	grid.set_ppp_block(good_coord, HexGrid.PPPBlockType.EVENT, calmaria)
	check(not player_skills.offer_before_block_activation(actor, good_coord),
		"Pedreiro não oferece CANCELAR em Evento Bom.")
	if failures == 0:
		print("PPP Pedreiro: botão preventivo para Evento, Efeito Permanente, Catástrofe e Armadilha passou")
	else:
		push_error("PPP Pedreiro: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
