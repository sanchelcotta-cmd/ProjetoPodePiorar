extends SceneTree

## Verifica a cadeia completa: bloco → decisão → Outcome → efeitos → confirmar.
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
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var resolved_results: Array[Dictionary] = []
	executor.result_ready.connect(func(_context: Dictionary, result: Dictionary) -> void:
		resolved_results.append(result.duplicate(true)))
	var data: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(data) and round_manager.start_first_map(),
		"A campanha deve iniciar para testar os eventos.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	# Itens iniciais agora vêm equipados e podem aumentar a Vida máxima.
	var starting_max_health := actor.max_health
	var grid := campaign.current_map
	var coord := Vector2i(0, 0)
	actor.position = coord
	var attack := load("res://resources/events/random_events/21-ataque_sobrenatural.tres") as EventData
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, attack)
	check(block.begin_activation(coord, actor) and popup.overlay.visible,
		"A narrativa aparece antes dos efeitos.")
	check(actor.max_health == starting_max_health,
		"Ler a narrativa sem clicar em OK ainda não aplica o Outcome.")
	check(popup.buttons.get_child_count() == 1 \
		and (popup.buttons.get_child(0) as Button).text == "OK",
		"O evento automático oferece um OK para confirmar a leitura.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(block.is_busy() and popup._outcome_reading \
		and actor.max_health == starting_max_health,
		"O primeiro OK abre a narração do Outcome sem aplicar os efeitos.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(actor.max_health == starting_max_health - 5 and actor.current_health == actor.max_health,
		"Ataque Sobrenatural reduz a Vida máxima e limita a atual.")
	check(not block.is_busy() and not popup.overlay.visible,
		"OK fecha a caixa, aplica o Outcome e libera o bloco.")
	var raio_evento := load("res://resources/events/random_events/06-um_raio_te_atingiu_na_cabeça_2.tres") as EventData
	coord = Vector2i(7, 0)
	actor.position = coord
	var hp_before_early_raio := actor.current_health
	var raio_results: Array[Dictionary] = []
	executor.result_ready.connect(func(_context: Dictionary, result: Dictionary) -> void:
		if result.get("event_id") == raio_evento.id:
			raio_results.append(result.duplicate(true)))
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, raio_evento)
	check(block.begin_activation(coord, actor), "Raio inicia com a narração antes do dano.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(popup._outcome_reading and (popup.buttons.get_child(0) as Button).text == "JOGAR DADO"
		and actor.current_health == hp_before_early_raio,
		"Outcome com dado mostra Jogar Dado dentro do Evento, sem aplicar dano antes do clique.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	await create_timer(2.2).timeout
	check(raio_results.size() == 1 and (raio_results[0].get("dice_results", []) as Array).size() == 1,
		"Evento rola um único dado real ao confirmar sua consequência.")
	if raio_results.size() == 1 and (raio_results[0].get("dice_results", []) as Array).size() == 1:
		check(hp_before_early_raio - actor.current_health == 2 * int(raio_results[0]["dice_results"][0]),
			"O dado mostrado pelo Evento é o mesmo usado para calcular seu dano.")
	check(block.is_busy() and popup.overlay.visible \
		and (popup.buttons.get_child(0) as Button).text == "OK",
		"Depois do dado, o resultado permanece legível até o OK final.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(not block.is_busy() and not popup.overlay.visible,
		"O OK final do resultado do dado libera o bloco.")
	var calmaria := load("res://resources/events/random_events/18-calmaria.tres") as EventData
	coord = Vector2i(1, 0)
	actor.position = coord
	actor.current_health = 6
	var enraizado := load("res://resources/skills/effects/debuffs/enraizado.tres") as DebuffData
	check(scene.get_node("SkillManager").debuff_manager.apply_debuff(actor, enraizado).get("success", false),
		"O teste aplica um Debuff antes de Calmaria.")
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, calmaria)
	check(block.begin_activation(coord, actor), "Calmaria deve iniciar.")
	_confirm_and_read(popup, {})
	check(actor.current_health == actor.max_health and actor.debuffs.is_empty(),
		"Calmaria recupera toda a Vida e remove todos os Debuffs.")
	check(not block.is_busy(), "Calmaria deve encerrar após confirmação.")
	var gelo := load("res://resources/events/traps/76-bomba_de_gelo.tres") as EventData
	coord = Vector2i(2, 0)
	actor.position = coord
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.TRAP, gelo)
	check(block.begin_activation(coord, actor), "Bomba de Gelo deve iniciar.")
	_confirm_and_read(popup, {})
	var stun := scene.get_node("SkillManager").debuff_manager.get_debuff(actor, &"db_00002") as DebuffInstanceState
	check(stun != null and stun.remaining_turns >= 1 and stun.remaining_turns <= 6,
		"Atordoamento deve durar o valor real do dado de seis lados.")
	check(not resolved_results.is_empty() and stun != null and
		str(resolved_results.back().get("narrative", "")).contains(
			"por %d turnos" % stun.remaining_turns),
		"Bomba de Gelo mostra na narrativa a duração realmente sorteada.")
	check(not block.is_busy(), "Armadilha deve encerrar após confirmação.")
	var mine := load("res://resources/events/traps/77-minas_explosivas.tres") as EventData
	coord = Vector2i(4, 0)
	actor.position = coord
	var adjacent := campaign.active_entity_states[1]
	adjacent.position = Vector2i(4, 1)
	var distant := campaign.active_entity_states[2]
	distant.position = Vector2i(0, 4)
	var actor_hp := actor.current_health
	var adjacent_hp := adjacent.current_health
	var distant_hp := distant.current_health
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.TRAP, mine)
	check(block.begin_activation(coord, actor), "Minas Explosivas devem iniciar.")
	_confirm_and_read(popup, {})
	var damage := actor_hp - actor.current_health
	var burn_actor := scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00007") as DebuffInstanceState
	var burn_adjacent := scene.get_node("SkillManager").debuff_manager.get_debuff(adjacent,
		&"db_00007") as DebuffInstanceState
	check(damage >= 1 and damage <= 6 and adjacent_hp - adjacent.current_health == damage \
		and distant.current_health == distant_hp,
		"Uma rolagem da mina atinge apenas quem estava no hex e nos seis vizinhos.")
	check(burn_actor != null and burn_adjacent != null \
		and burn_actor.current_tick_damage == damage \
		and burn_adjacent.current_tick_damage == damage,
		"Queimadura começa com a mesma rolagem de dano da mina.")
	check(not resolved_results.is_empty() and str(resolved_results.back().get(
		"narrative", "")).contains("com %d de queimadura" % damage),
		"Mina mostra na narrativa o mesmo dado usado para dano e Queimadura.")
	check(not block.is_busy(), "Mina deve encerrar após confirmação.")
	var boca := load("res://resources/events/traps/78-boca_de_lobo.tres") as EventData
	coord = Vector2i(5, 0)
	actor.position = coord
	var hp_before_boca := actor.current_health
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.TRAP, boca)
	check(block.begin_activation(coord, actor), "Boca de Lobo deve iniciar.")
	_confirm_and_read(popup, {})
	var root_debuff := scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00006") as DebuffInstanceState
	check(hp_before_boca - actor.current_health in [1, 2, 3, 4, 5, 6] \
		and root_debuff != null,
		"Boca de Lobo causa 1d6 de dano e Enraizado.")
	check(not resolved_results.is_empty() and str(resolved_results.back().get(
		"narrative", "")).contains(
			"%d de dano" % (hp_before_boca - actor.current_health)),
		"Boca de Lobo mostra na narrativa o dano realmente sorteado.")
	check(not block.is_busy(), "Boca de Lobo deve encerrar após confirmação.")
	var prego := load("res://resources/events/traps/79-prego_enferrujado.tres") as EventData
	coord = Vector2i(6, 0)
	actor.position = coord
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.TRAP, prego)
	check(block.begin_activation(coord, actor), "Prego Enferrujado deve iniciar.")
	_confirm_and_read(popup, {})
	check(scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00004") != null,
		"Prego Enferrujado aplica Doença no estágio doença.")
	check(not block.is_busy(), "Prego Enferrujado deve encerrar após confirmação.")
	var danacao := load("res://resources/events/random_events/39-danacao.tres") as EventData
	coord = Vector2i(7, 0)
	actor.position = coord
	actor.current_health = 15
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, danacao)
	check(block.begin_activation(coord, actor), "Danação deve iniciar.")
	_confirm_and_read(popup, {})
	check(actor.current_health == 7, "Danação subtrai metade da Vida atual, arredondada para cima.")
	check(not block.is_busy(), "Danação deve encerrar após confirmação.")
	var raio := load("res://resources/events/random_events/06-um_raio_te_atingiu_na_cabeça_2.tres") as EventData
	coord = Vector2i(0, 1)
	actor.position = coord
	actor.current_health = actor.max_health
	var hp_before_raio := actor.current_health
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, raio)
	check(block.begin_activation(coord, actor), "Raio deve iniciar.")
	_confirm_and_read(popup, {})
	var raio_damage := hp_before_raio - actor.current_health
	var raio_stun := scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00002") as DebuffInstanceState
	check(raio_damage in [2, 4, 6, 8, 10, 12] \
		and actor.current_health == hp_before_raio - raio_damage \
		and raio_stun != null and raio_stun.remaining_turns == 1 \
		and raio_stun.exploration_event_control,
		"Raio causa exatamente 2×1d6 de dano e Atordoamento por um turno.")
	check(not block.is_busy(), "Raio deve encerrar após confirmação.")
	var congelado := load("res://resources/events/random_events/11-voce_foi_congelado.tres") as EventData
	coord = Vector2i(1, 1)
	actor.position = coord
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, congelado)
	check(block.begin_activation(coord, actor), "Congelado deve iniciar.")
	_confirm_and_read(popup, {})
	var frozen := scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00002") as DebuffInstanceState
	check(frozen != null and frozen.expiration_round_index == campaign.get_round_index() + 1 \
		and frozen.exploration_event_control,
		"Congelado deixa o Atordoamento ativo até a próxima virada de Rodada.")
	check(not block.is_busy(), "Congelado deve encerrar após confirmação.")
	var raizes := load("res://resources/events/random_events/34-raizes_traicoeiras.tres") as EventData
	coord = Vector2i(2, 1)
	actor.position = coord
	scene.get_node("SkillManager").debuff_manager.remove_debuff(actor, &"db_00006")
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, raizes)
	check(block.begin_activation(coord, actor), "Raízes Traiçoeiras devem iniciar.")
	_confirm_and_read(popup, {})
	check(scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00006") != null \
		and not scene.get_node("SkillManager").debuff_manager.can_move_to(actor, Vector2i(3, 1)),
		"Raízes Traiçoeiras aplicam Enraizado e impedem movimento.")
	check(not block.is_busy(), "Raízes devem encerrar após confirmação.")
	var moto := load("res://resources/events/random_events/40-dois_caras_em_uma_moto.tres") as EventData
	coord = Vector2i(3, 1)
	actor.position = coord
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, moto)
	check(block.begin_activation(coord, actor), "Dois Caras em uma Moto deve iniciar.")
	_confirm_and_read(popup, {})
	var all_terrified := true
	for member in campaign.active_entity_states:
		var terror := scene.get_node("SkillManager").debuff_manager.get_debuff(member,
			&"db_00009") as DebuffInstanceState
		all_terrified = all_terrified and terror != null \
			and terror.expiration_round_index == campaign.get_round_index() + 1
	check(all_terrified, "A moto aplica Terror em todo o grupo até a próxima Rodada.")
	check(not block.is_busy(), "A moto deve encerrar após confirmação.")
	var doente := load("res://resources/events/permanent_effects/66-voce_esta_doente.tres") as EventData
	coord = Vector2i(4, 1)
	actor.position = coord
	scene.get_node("SkillManager").debuff_manager.remove_debuff(actor, &"db_00004")
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, doente)
	check(block.begin_activation(coord, actor), "Você Está Doente deve iniciar.")
	_confirm_and_read(popup, {})
	check(scene.get_node("SkillManager").debuff_manager.get_debuff(actor,
		&"db_00003") != null,
		"Você Está Doente aplica Doença Leve, conforme decisão confirmada.")
	check(not block.is_busy(), "Doença individual deve encerrar após confirmação.")
	var todos_doentes := load("res://resources/events/permanent_effects/67-todos_estao_doentes.tres") as EventData
	coord = Vector2i(5, 1)
	actor.position = coord
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, todos_doentes)
	check(block.begin_activation(coord, actor), "Todos Estão Doentes deve iniciar.")
	_confirm_and_read(popup, {})
	var all_sick := true
	for member in campaign.active_entity_states:
		all_sick = all_sick and scene.get_node("SkillManager").debuff_manager.get_debuff(member,
			&"db_00003") != null
	check(all_sick, "Todos Estão Doentes aplica Doença Leve aos três jogáveis.")
	check(not block.is_busy(), "Doença do grupo deve encerrar após confirmação.")
	var gnomo_cura := load("res://resources/events/random_events/gnomes_3/02-festa_da_recuperacao.tres") as EventData
	coord = Vector2i(6, 1)
	actor.position = coord
	for member in campaign.active_entity_states:
		member.current_health = 2
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, gnomo_cura)
	check(block.begin_activation(coord, actor), "Gnomo da Recuperação deve iniciar.")
	_confirm_and_read(popup, {})
	var all_healed := true
	for member in campaign.active_entity_states:
		all_healed = all_healed and member.current_health == member.max_health
	check(all_healed, "O Gnomo 2 recupera toda a Vida dos três jogáveis.")
	check(not block.is_busy(), "Gnomo 2 deve encerrar após confirmação.")
	var poco := load("res://resources/events/random_events/27-poco_magico_e_reluzente.tres") as EventData
	var prior_weights: Array[int] = []
	for outcome in poco.outcomes:
		prior_weights.append(outcome.weight)
	for chosen_index in poco.outcomes.size():
		# Forçamos cada ramo só no TESTE, sem salvar nem mudar o Resource do jogo.
		for index in poco.outcomes.size():
			poco.outcomes[index].weight = 1 if index == chosen_index else 0
		coord = Vector2i(chosen_index, 2)
		actor.position = coord
		actor.current_health = 15
		actor.attack = 10
		var initial_max_health := actor.max_health
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, poco)
		check(block.begin_activation(coord, actor), "Poço deve abrir antes de beber.")
		popup._confirm_event({"accepted": true})
		check(block.is_busy() and actor.current_health == 15 and actor.attack == 10 \
			and popup.overlay.visible \
			and (popup.buttons.get_child(0) as Button).text == "OK",
			"O ramo sorteado do Poço deve ser lido antes de alterar atributos.")
		(popup.buttons.get_child(0) as Button).pressed.emit()
		var expected_max_health: int = initial_max_health \
			+ [-5, 5, 5, 0, 5][chosen_index]
		var expected_hp: int = mini(15, expected_max_health)
		var expected_attack: int = [15, 5, 10, 15, 15][chosen_index]
		check(actor.max_health == expected_max_health and actor.current_health == expected_hp \
			and actor.attack == expected_attack \
			and not block.is_busy() and not popup.overlay.visible,
			"Cada um dos cinco Outcomes do Poço aplica a combinação correta após OK.")
	for index in poco.outcomes.size():
		poco.outcomes[index].weight = prior_weights[index]
	coord = Vector2i(5, 2)
	actor.position = coord
	actor.current_health = 15
	actor.attack = 10
	grid.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, poco)
	check(block.begin_activation(coord, actor), "Poço deve permitir recusa.")
	popup._confirm_event({"accepted": false})
	check(actor.current_health == 15 and actor.attack == 10 and not block.is_busy(),
		"Recusar o Poço não altera Vida ou Ataque e encerra o bloco.")
	if failures == 0:
		print("PPP EventExecutor: Vida, Cura e armadilhas passaram")
	else:
		push_error("PPP EventExecutor: %d falha(s)" % failures)
	scene.queue_free()
	for _frame in 4:
		await process_frame
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _confirm_and_read(popup: BlockActivationPopup, decision: Dictionary) -> void:
	popup._confirm_event(decision)
	if popup._outcome_reading:
		# Estes casos testam o executor, não a animação contextual do dado.
		popup._event_die_pending = false
		popup._execute_prepared_event()
