extends SceneTree

## Evento 05: sorteio ponderado e execução real de todos os superpoderes.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha inicia para testar o Raio de superpoderes.")
	var actor := gerencia.campaign.active_entity_states[0]
	var grid := gerencia.campaign.current_map
	var ray := load("res://resources/events/random_events/05-um_raio_te_atingiu_na_cabeça_1.tres") as EventData
	for branch in ray.outcomes.size():
		for index in ray.outcomes.size():
			ray.outcomes[index].weight = 1 if branch == index else 0
		actor.attack = actor.data.ataque_base
		actor.max_health = actor.data.vida_base
		actor.current_health = 10
		actor.max_stamina = actor.data.stamina_base
		actor.stamina_remaining = actor.max_stamina
		var coord := Vector2i(branch, 0)
		actor.position = coord
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, ray)
		_check(block.begin_activation(coord, actor), "Raio ramo %d inicia." % branch)
		popup._confirm_event({})
		if popup._outcome_reading:
			popup._execute_prepared_event()
		_check(not block.is_busy(), "Raio ramo %d aplica e encerra." % branch)
		if branch in [0, 3]:
			_check(actor.attack == actor.data.ataque_base * 2 \
				and actor.current_health == 20 \
				and actor.max_health == actor.data.vida_base,
				"Força dobra Ataque e Vida atual, sem mudar a máxima.")
		if branch in [1, 3]:
			_check(actor.max_stamina == actor.data.stamina_base + 2 \
				and _has_passive(skills, actor, &"ps_00014"),
				"Super-agilidade dá +2 Estamina e 60% de Esquiva.")
		if branch in [2, 3]:
			_check(_has_passive(skills, actor, &"ps_00022") \
				and _has_passive(skills, actor, &"ps_00023"),
				"Voar concede recuo pós-ataque e movimento sobre obstáculos.")
	# A rota direta voando atravessa obstáculos, mas o destino ainda precisa
	# estar ativável, desocupado e dentro da Estamina normal.
	actor.position = Vector2i(0, 2)
	actor.max_stamina = 2
	actor.stamina_remaining = 2
	exploration.current_actor = actor
	actor.turn_state = EntityState.TurnState.TURNING
	exploration._awaiting_block = false
	exploration._has_moved_this_turn = false
	var blocker := grid.get_cell(Vector2i(1, 2))
	blocker.movement_blocked = true
	var target := Vector2i(2, 2)
	grid.set_ppp_block(target, HexGrid.PPPBlockType.CONSUMABLE,
		load("res://resources/itens/consumables/bolinho_de_chuva.tres"))
	_check(exploration.get_available_destinations().has(target),
		"Voar alcança um bloco ativável atrás de obstáculo dentro de 2 hexes.")
	print("PPP ray superpowers: %d falha(s)" % failures)
	quit(0 if failures == 0 else 1)


func _has_passive(skills: SkillManager, actor: EntityState,
		id: StringName) -> bool:
	for grant in skills.get_passive_grants(actor):
		if grant.skill is PassiveSkillData and (grant.skill as PassiveSkillData).id == id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
