extends SceneTree

## Regressão do Encontro único: Orchestra 2/5 e 3/5 liberam uma escolha
## antes do combate; o sorteio só acontece após RECRUTAR.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _scenario([], 0, false, -1.0, false)
	await _scenario(["orchestra_2"], 50, false, -1.0, false)
	await _scenario(["orchestra_3"], 50, true, 1.0, true)
	await _scenario(["orchestra_2", "orchestra_3"], 75, true, 0.0, false)
	print("PPP A Experiência recruitment: %d falha(s)" % failures)
	quit(0 if failures == 0 else 1)


func _scenario(information: Array[String], chance: int, accept: bool,
		forced_chance: float, expected_recruited: bool) -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var combat := scene.get_node("CombatManager") as CombatManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	combat.auto_start_turns = chance == 50 or chance == 75
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(choices) and rounds.start_first_map(),
		"Campanha inicia (%s)." % str(information))
	var actor := gerencia.campaign.active_entity_states[0]
	for part in information:
		var info := load("res://resources/informacoes/orchestra/%s.tres" % part) as Informacao
		_check(gerencia.campaign.record_information_obtained(info),
			"Informação Orchestra foi registrada: %s." % part)
	var encounter := load("res://resources/encounters/enc_a_experiencia.tres") as EncounterData
	_check(encounter.unique_encounter and encounter.id == &"enc_00011",
		"A Experiência está marcada como Encontro único.")
	var coord := Vector2i(4, 2)
	actor.position = coord
	gerencia.campaign.current_map.set_ppp_block(coord,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	_check(block.begin_activation(coord, actor), "Encontro abre (%s)." % str(information))
	(popup.buttons.get_child(0) as Button).pressed.emit()
	await process_frame
	_check(combat.enemies.size() == 1, "A Experiência surge uma vez.")
	if combat.enemies.is_empty():
		scene.queue_free()
		await process_frame
		return
	var enemy := combat.enemies[0]
	if chance == 0:
		_check(not hud._recruitment_dialog.visible and combat._pending_recruitment.is_empty(),
			"Sem a Informação específica, não há recrutamento.")
	else:
		_check(hud._recruitment_dialog.visible \
			and hud._recruitment_dialog.dialog_text.contains("%d%%" % chance),
			"A chance correta aparece antes do combate: %d%%." % chance)
		for part in information:
			var label := "Orchestra 2/5" if part == "orchestra_2" else "Orchestra 3/5"
			_check(hud._recruitment_dialog.dialog_text.contains(label),
				"A caixa identifica a Informação %s." % label)
		_check(combat.current_actor == null and enemy in combat.enemies,
			"Nenhum turno/rolagem ocorre antes da decisão.")
		if not accept:
			hud._on_recruitment_declined()
			_check(enemy in combat.enemies and combat._pending_recruitment.is_empty(),
				"Recusar inicia combate sem converter o inimigo.")
			await process_frame
			_check(combat.combat_cycle == 1,
				"Após RECUSAR E COMBATER, a iniciativa começa.")
		else:
			var passive := combat._pending_recruitment["grant"].skill as PassiveSkillData
			var original := passive.activation_chance
			passive.activation_chance = forced_chance
			hud._on_recruitment_confirmed()
			passive.activation_chance = original
			_check(hud._recruitment_result_dialog.visible,
				"A tentativa apresenta o outcome.")
			_check((enemy in gerencia.campaign.companion_states) == expected_recruited,
				"A conversão corresponde ao resultado da tentativa.")
			if expected_recruited:
				_check(enemy.owner_instance_id == actor.instance_id \
					and enemy not in combat.enemies,
					"O inimigo vira aliado do ativador original.")
			else:
				_check(enemy in combat.enemies and \
					hud._recruitment_result_dialog.dialog_text.contains("combate começa"),
					"Falha deixa o hostil e avisa que o combate começa.")
			hud._on_recruitment_result_closed()
			_check(not combat._recruitment_feedback_pending,
				"Após fechar o outcome, o encontro prossegue.")
			if expected_recruited:
				_check(combat.pending_conclusion.get("result", {}).get("reason") == "victory",
					"Recrutamento bem-sucedido encerra o Encontro como vitória.")
			else:
				await process_frame
				_check(combat.combat_cycle == 1,
					"Após a falha, a iniciativa começa.")
	if not expected_recruited:
		_check(combat.request_victory(), "Teste encerra o combate normalmente.")
	_check(combat.confirm_conclusion(), "O Encontro conclui.")
	_check(encounter.id in gerencia.campaign.occurred_unique_encounter_ids,
		"A Experiência fica registrada e não pode ser sorteada novamente.")
	scene.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
