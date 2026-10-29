extends SceneTree

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
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var data: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	check(gerencia.start_new_game(data) and round_manager.start_first_map(), "Campanha inicia.")
	var campaign := gerencia.campaign
	var actor := campaign.active_entity_states[0]
	var grid := campaign.current_map
	var info_khainokata := load("res://resources/informacoes/khainokata/khaikonata_1.tres") as Informacao
	var info_orchestra := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	var context := {"map": grid, "actor": actor, "coord": Vector2i(0, 0)}
	var event01 := _event("01-artefato_do_vazio")
	var event02 := _event("02-cobaia_secreta")
	var branch01 := executor._select_outcome(event01, {}).get("outcome") as EventOutcomeData
	check(branch01 != null and branch01.display_name == "Consequência Ruim",
		"01 sem informação escolhe consequência ruim.")
	campaign.record_information_obtained(info_khainokata)
	branch01 = executor._select_outcome(event01, {}).get("outcome") as EventOutcomeData
	check(branch01 != null and branch01.display_name == "Consequência Boa",
		"01 com Khainokata evita punição.")
	var branch02 := executor._select_outcome(event02, {}).get("outcome") as EventOutcomeData
	check(branch02 != null and branch02.display_name == "Consequência Ruim",
		"02 sem Orchestra escolhe consequência ruim.")
	campaign.record_information_obtained(info_orchestra)
	branch02 = executor._select_outcome(event02, {}).get("outcome") as EventOutcomeData
	check(branch02 != null and branch02.display_name == "Consequência Boa",
		"02 com Orchestra evita punição.")
	campaign.obtained_information_ids.erase(info_orchestra.id)
	var event15 := _event("15-revelacao_lunar")
	campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
	check((executor._select_outcome(event15, {}).get("outcome") as EventOutcomeData).display_name == "É dia.",
		"15 é inerte de dia.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	check((executor._select_outcome(event15, {}).get("outcome") as EventOutcomeData).display_name == "É noite",
		"15 revela somente de noite.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
	var fixed_info := event02.outcomes[0].effects[0]
	var info_result := executor._apply_effect(fixed_info, actor, event02, context, false)
	check(info_result.get("success", false) and campaign.obtained_information_ids.has(&"in_00019"),
		"02 registra Informação #4 da Orchestra.")
	var event17 := _event("17-o_informante")
	var random_info := event17.outcomes[0].effects[0]
	var previous_info_count := campaign.obtained_information_ids.size()
	var random_result := executor._apply_effect(random_info, actor, event17, context, false)
	check(random_result.get("success", false) \
		and campaign.obtained_information_ids.size() == previous_info_count + 1,
		"17 concede Informação ainda não obtida.")
	var event35 := _event("35-pulsar_da_terra")
	var event36 := _event("36-terremoto")
	var event37 := _event("37-visao_do_futuro")
	var event38 := _event("38-premonicao")
	var event42 := _event("42-a_cartomante_do_olho_de_vidro")
	var event52 := _event("52-testemunha_ocular")
	for map_coord in grid.cells:
		grid.set_ppp_block(map_coord, HexGrid.PPPBlockType.NONE)
	grid.set_ppp_block(Vector2i(1, 0), HexGrid.PPPBlockType.ENCOUNTER,
		load("res://resources/encounters/enc_barata_voadora.tres"))
	grid.set_ppp_block(Vector2i(7, 4), HexGrid.PPPBlockType.TRAP,
		load("res://resources/events/traps/76-bomba_de_gelo.tres"))
	for near_coord in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]:
		grid.set_ppp_block(near_coord, HexGrid.PPPBlockType.EVENT, event17)
	var moon_result := executor._apply_map_effect(event15.outcomes[0].effects[0], context)
	check(moon_result.get("revealed_count", 0) == 1 \
		and grid.get_cell(Vector2i(1, 0)).state == HexGrid.PPPBlockState.REVEALED \
		and grid.get_cell(Vector2i(7, 4)).state == HexGrid.PPPBlockState.HIDDEN,
		"15 revela encontros, não armadilhas.")
	var pulse_result := executor._apply_map_effect(event35.outcomes[0].effects[0], context)
	check(pulse_result.get("success", false) \
		and pulse_result.get("revealed_count", 0) == 3 \
		and not (Vector2i(7, 4) in pulse_result.get("revealed_tiles", [])),
		"35 revela todos dentro do raio 2, não apenas dois.")
	var report := executor._apply_map_effect(event42.outcomes[0].effects[1], context)
	check(report.get("success", false) and report.get("presence", {}).get(&"trap", false),
		"42 detecta armadilha da Rodada sem revelar posição.")
	var vision := executor._apply_map_effect(event37.outcomes[0].effects[0], context)
	check(vision.get("success", false) and actor.future_vision_uses == 3,
		"37 concede três consultas persistentes.")
	var premonition := executor._apply_map_effect(event38.outcomes[0].effects[0], context)
	check(premonition.get("success", false) \
		and actor.premonition_round_index == campaign.get_round_index(),
		"38 concede ativa até o fim da Rodada.")
	hud._begin_future_vision_targeting(actor)
	check(scene.is_future_vision_active(), "37 arma a seleção de qualquer hex oculto.")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene._on_cell_pressed(Vector2i(7, 4), click)
	check(actor.future_vision_uses == 2 \
		and grid.get_cell(Vector2i(7, 4)).state == HexGrid.PPPBlockState.REVEALED \
		and &"event_type_and_effect" in grid.revealed_by_skill_ids.get(Vector2i(7, 4), []),
		"37 usa uma carga sem limite de alcance e revela tipo/efeito.")
	grid.set_ppp_block(Vector2i(6, 4), HexGrid.PPPBlockType.TRAP,
		load("res://resources/events/traps/76-bomba_de_gelo.tres"))
	hud._begin_future_vision_targeting(actor, true)
	scene._on_cell_pressed(Vector2i(6, 4), click)
	check(actor.premonition_used_turn_serial == actor.turn_serial \
		and grid.get_cell(Vector2i(6, 4)).state == HexGrid.PPPBlockState.REVEALED,
		"38 usa uma revelação no turno, sem limite de alcance.")
	hud._begin_future_vision_targeting(actor, true)
	check(not scene.is_future_vision_active(), "38 não permite segunda revelação no mesmo turno.")
	check(executor._unsupported_reason(event52.outcomes[0].effects[0], context).is_empty(),
		"52 aceita limite por personagem e duração de Rodada.")
	check(hud != null and popup != null and event36 != null, "Cena liga HUD e popup.")
	var block := scene.get_node("BlockManager") as BlockManager
	var event_coord := Vector2i(4, 0)
	for resource in gerencia.get_information_catalog():
		var info := resource as Informacao
		if info != null and &"khainokata" in info.tags:
			campaign.obtained_information_ids.erase(info.id)
	var initial_maxima: Array[int] = []
	for member in campaign.active_entity_states:
		initial_maxima.append(member.max_health)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event01)
	check(block.begin_activation(event_coord, actor), "01 inicia pela caixa narrativa.")
	popup._confirm_event({})
	check(popup._outcome_reading and campaign.active_entity_states[0].max_health == initial_maxima[0],
		"01 mostra Outcome antes de aplicar dano.")
	popup._execute_prepared_event()
	var halved := true
	for index in campaign.active_entity_states.size():
		halved = halved and campaign.active_entity_states[index].max_health == \
			initial_maxima[index] - floori(initial_maxima[index] * 0.5)
	check(halved and not block.is_busy(), "01 subtrai metade da Vida máxima do grupo.")
	actor.current_health = actor.max_health
	for resource in gerencia.get_information_catalog():
		var info := resource as Informacao
		if info != null and &"orchestra" in info.tags:
			campaign.obtained_information_ids.erase(info.id)
	event_coord = Vector2i(5, 0)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event02)
	check(block.begin_activation(event_coord, actor), "02 inicia.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(campaign.obtained_information_ids.has(&"in_00019") \
		and popup.overlay.visible and block.is_busy(),
		"02 registra Informação e permite lê-la antes de fechar.")
	popup._acknowledge_event_result()
	check(not block.is_busy(), "02 encerra após leitura da Informação.")
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	check(skill_manager.debuff_manager.get_debuff(actor, &"db_00003") != null,
		"02 aplica Doença Leve.")
	var before_earthquake: Array[int] = []
	for member in campaign.active_entity_states:
		member.current_health = member.max_health
		before_earthquake.append(member.current_health)
	event_coord = Vector2i(6, 0)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event36)
	var earthquake_results: Array[Dictionary] = []
	executor.result_ready.connect(func(_event_context: Dictionary, result: Dictionary) -> void:
		if result.get("event_id") == &"ev_00036":
			earthquake_results.append(result.duplicate(true)))
	check(block.begin_activation(event_coord, actor), "36 inicia.")
	popup._confirm_event({})
	popup._event_die_pending = false
	popup._execute_prepared_event()
	var rolled_each := earthquake_results.size() == 1
	if rolled_each:
		var effect_results: Array = earthquake_results[0].get("effects", [])
		var damage_index := 0
		var six_targets: Dictionary = {}
		for effect_result in effect_results:
			if effect_result.get("effect") != Event_EffectData.EffectType.MODIFY_HP:
				continue
			var member := campaign.active_entity_states[damage_index]
			var die := int(effect_result.get("roll", 0))
			six_targets[member.instance_id] = die == 6
			rolled_each = rolled_each and die >= 1 and die <= 6 \
				and before_earthquake[damage_index] - member.current_health == die
			damage_index += 1
		rolled_each = rolled_each and damage_index == 3
		for member in campaign.active_entity_states:
			var stun_applied := scene.get_node("SkillManager").debuff_manager.get_debuff(
				member, &"db_00002") != null
			rolled_each = rolled_each and stun_applied == six_targets.get(member.instance_id, false)
	check(rolled_each and not block.is_busy(),
		"36 rola dano por jogável e atordoa somente quem tirou 6 no mesmo dado.")
	event_coord = Vector2i(7, 0)
	skill_manager.debuff_manager.remove_debuff(actor, &"db_00009")
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event52)
	check(block.begin_activation(event_coord, actor), "52 inicia na primeira ocorrência.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	var terror := skill_manager.debuff_manager.get_debuff(actor, &"db_00009")
	check(terror != null and terror.expiration_round_index == campaign.get_round_index() + 1,
		"52 aplica Terror até a virada da Rodada.")
	skill_manager.debuff_manager.remove_debuff(actor, &"db_00009")
	event_coord = Vector2i(0, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event52)
	check(block.begin_activation(event_coord, actor), "52 pode reaparecer no mapa.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(skill_manager.debuff_manager.get_debuff(actor, &"db_00009") == null \
		and campaign.event_effects_applied_by_actor.get("ev_00052:%s" % actor.instance_id, 0) == 1,
		"52 não reaplica Terror ao mesmo personagem na campanha.")
	event_coord = Vector2i(1, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event42)
	check(block.begin_activation(event_coord, actor), "42 inicia.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(block.is_busy() and popup.overlay.visible \
		and "Armadilha" in popup.narrative_label.text,
		"42 mostra relatório de presença sem posição de blocos.")
	popup._acknowledge_event_result()
	check(not block.is_busy(), "42 encerra só depois da leitura do relatório.")
	event_coord = Vector2i(2, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event17)
	var info_count_before_17 := campaign.obtained_information_ids.size()
	var max_health_before_17 := actor.max_health
	check(block.begin_activation(event_coord, actor), "17 inicia.")
	popup._confirm_event({"outcome": event17.outcomes[0]})
	popup._execute_prepared_event()
	check(actor.max_health == max_health_before_17 - 5 \
		and campaign.obtained_information_ids.size() == info_count_before_17 + 1 \
		and popup.overlay.visible,
		"17 troca 5 de Vida máxima por Informação nova e a exibe.")
	popup._acknowledge_event_result()
	event_coord = Vector2i(3, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event38)
	check(executor._unsupported_reason(event38.outcomes[0].effects[0],
		{"map": grid, "actor": actor, "resource": event38}).is_empty(),
		"38 é aceita pelo executor como ação temporária.")
	check(block.begin_activation(event_coord, actor), "38 inicia.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(actor.premonition_round_index == campaign.get_round_index() \
		and not block.is_busy(), "38 é concedida no fluxo completo.")
	campaign.record_information_obtained(info_khainokata)
	event_coord = Vector2i(4, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event01)
	var before_safe_void := actor.max_health
	check(block.begin_activation(event_coord, actor), "01 reaparece para ramo protegido.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(actor.max_health == before_safe_void and not block.is_busy(),
		"01 não pune quando existe Informação Khainokata.")
	event_coord = Vector2i(5, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event02)
	var before_safe_cobaia := actor.current_health
	var before_safe_info := campaign.obtained_information_ids.size()
	check(block.begin_activation(event_coord, actor), "02 reaparece para ramo protegido.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(actor.current_health == before_safe_cobaia \
		and campaign.obtained_information_ids.size() == before_safe_info \
		and not block.is_busy(), "02 não pune nem concede pista com Orchestra prévia.")
	event_coord = Vector2i(6, 1)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event17)
	var before_refusal := actor.max_health
	check(block.begin_activation(event_coord, actor), "17 abre opção de recusa.")
	popup._confirm_event({"outcome": event17.outcomes[1]})
	popup._execute_prepared_event()
	check(actor.max_health == before_refusal and not block.is_busy(),
		"17 permite recusar sem cobrar Vida máxima.")
	var later_encounter := Vector2i(7, 3)
	grid.set_ppp_block(later_encounter, HexGrid.PPPBlockType.ENCOUNTER,
		load("res://resources/encounters/enc_barata_voadora.tres"))
	campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
	event_coord = Vector2i(0, 2)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event15)
	check(block.begin_activation(event_coord, actor), "15 inicia de dia.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(grid.get_cell(later_encounter).state == HexGrid.PPPBlockState.HIDDEN \
		and not block.is_busy(), "15 de dia não revela Encontro.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	event_coord = Vector2i(1, 2)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event15)
	check(block.begin_activation(event_coord, actor), "15 inicia à Noite.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(grid.get_cell(later_encounter).state == HexGrid.PPPBlockState.REVEALED \
		and not block.is_busy(), "15 noturno revela Encontro no fluxo completo.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
	var nearby_hidden := Vector2i(3, 3)
	grid.set_ppp_block(nearby_hidden, HexGrid.PPPBlockType.EVENT, event17)
	actor.position = Vector2i(2, 2)
	event_coord = actor.position
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event35)
	for member in campaign.active_entity_states:
		member.current_health = member.max_health
	var before_pulse := actor.current_health
	check(block.begin_activation(event_coord, actor), "35 inicia.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(grid.get_cell(nearby_hidden).state == HexGrid.PPPBlockState.REVEALED \
		and actor.current_health == before_pulse - 1 and not block.is_busy(),
		"35 revela vizinhos e desconta 1 de Vida após a leitura.")
	event_coord = Vector2i(4, 2)
	grid.set_ppp_block(event_coord, HexGrid.PPPBlockType.EVENT, event37)
	var previous_vision_uses := actor.future_vision_uses
	check(block.begin_activation(event_coord, actor), "37 inicia.")
	popup._confirm_event({})
	popup._execute_prepared_event()
	check(actor.future_vision_uses == previous_vision_uses + 3 \
		and not block.is_busy(), "37 acrescenta três usos no fluxo completo.")
	actor.turn_serial += 1
	grid.set_ppp_block(Vector2i(6, 3), HexGrid.PPPBlockType.TRAP,
		load("res://resources/events/traps/76-bomba_de_gelo.tres"))
	hud._begin_future_vision_targeting(actor, true)
	check(scene.is_future_vision_active(),
		"38 volta a permitir uma consulta no turno seguinte da mesma Rodada.")
	hud._end_future_vision_targeting()
	campaign.round_period = PPPMapGenerator.RoundPeriod.AFTERNOON
	hud._begin_future_vision_targeting(actor, true)
	check(not scene.is_future_vision_active(), "38 expira na virada da Rodada.")
	if failures == 0:
		print("PPP Group 1: condições, informações, revelações e concessões passaram")
	else:
		push_error("PPP Group 1: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _event(stem: String) -> EventData:
	return load("res://resources/events/random_events/%s.tres" % stem) as EventData


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
