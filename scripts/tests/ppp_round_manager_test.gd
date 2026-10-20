extends SceneTree

## Testa o caminho inteiro: seleção inicial → mapa → Informação → botão →
## escolha de distrito → próxima fase → virada de Dia.

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node_or_null("GerenciaJogo") as GerenciaJogo
	var exploration := scene.get_node_or_null("ExplorationManager") as ExplorationManager
	var block := scene.get_node_or_null("BlockManager") as BlockManager
	var rounds := scene.get_node_or_null("RoundManager") as RoundManager
	var button := scene.get_node_or_null("RoundUI/NextPhaseButton") as Button
	var dialog := scene.get_node_or_null("RoundUI/DestinationDialog") as ConfirmationDialog
	var options := scene.get_node_or_null("RoundUI/DestinationDialog/DistrictOptions") as OptionButton
	check(gerencia != null and exploration != null and block != null and rounds != null \
		and button != null and dialog != null and options != null,
		"A cena principal deve conter a máquina e o botão de próxima fase.")
	if rounds == null or gerencia == null:
		quit(1)
		return
	check(gerencia.map_view == scene and exploration.gerencia == gerencia \
		and rounds.exploration == exploration and rounds.advance_button == button,
		"Os nós da cena devem estar conectados.")
	check(button.disabled and not button.visible,
		"Antes da Informação, o botão de próxima fase fica invisível.")
	check(button.get_theme_stylebox("disabled") is StyleBoxFlat \
		and not button.get_node("NeonEdge").visible,
		"Ao ficar indisponível, o botão usa cinza e perde o brilho de clique.")
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(selected), "Três personagens distintos iniciam a campanha.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	check(rounds.start_first_map(rng), "O primeiro mapa deve ser gerado após a seleção.")
	check(gerencia.campaign.current_map.cells.size() == 40, "O mapa inicial tem 40 hexes.")
	check(button.disabled and not rounds.can_advance(), "Revelar/gerar mapa não libera avanço.")
	var first_map := gerencia.campaign.current_map
	check(not rounds.advance_to_district(&"centro", rng),
		"Sem Informação, o botão não pode trocar de fase.")
	check(gerencia.campaign.current_map == first_map, "Avanço recusado preserva o mapa.")
	activate_information_by_moving(gerencia, exploration)
	await process_frame
	check(gerencia.campaign.information_allows_round_advance() and button.visible \
		and not button.disabled,
		"Ativar Informação libera o botão, sem avançar automaticamente.")
	await process_frame
	check(button.get_node("NeonEdge").visible,
		"O brilho verde reaparece apenas quando o avanço está disponível.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await create_timer(0.2).timeout
		var preview_path := "user://ppp_next_phase_button_preview.png"
		root.get_texture().get_image().save_png(preview_path)
		print("NEXT_PHASE_PREVIEW=" + ProjectSettings.globalize_path(preview_path))
	check(gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.MORNING,
		"Obter Informação não muda o horário.")
	check(not rounds.advance_to_district(&"centro", rng),
		"Subúrbio não pode pular diretamente ao Centro.")
	check(gerencia.campaign.current_map == first_map, "Distrito inválido preserva o mapa.")
	var pending_event := load("res://resources/events/random_events/33-tropeco_perigoso.tres") as EventData
	first_map.set_ppp_block(Vector2i(7, 4), HexGrid.PPPBlockType.EVENT, pending_event)
	check(block.begin_activation(Vector2i(7, 4), exploration.current_actor),
		"Um Evento pode permanecer pendente após a Informação.")
	check(not rounds.can_advance(), "Evento pendente bloqueia a troca de mapa.")
	check(block.finish_event_resolution(), "O Evento pendente pode ser concluído.")
	await process_frame
	check(rounds.can_advance(), "Depois da conclusão, a escolha volta a ser possível.")
	button.pressed.emit()
	check(options.item_count == 2 and dialog.visible,
		"Clicar abre a escolha entre Subúrbio e Baixo-Centro.")
	options.select(1)
	dialog.confirmed.emit()
	check(gerencia.campaign.day == 1 \
		and gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.AFTERNOON \
		and gerencia.campaign.district == &"baixo_centro",
		"A confirmação avança Manhã → Tarde e muda para o distrito escolhido.")
	check(gerencia.campaign.current_map != first_map and button.disabled \
		and not button.visible,
		"Novo mapa nasce e o botão some até outra Informação.")
	check(gerencia.campaign.current_map.ppp_background_path.contains("cena_baixocentro_"),
		"O fundo acompanha o distrito escolhido.")
	check(exploration.current_actor.position == Vector2i(-1, 1),
		"O grupo volta à StartZone na nova Rodada.")
	activate_information_by_moving(gerencia, exploration)
	check(rounds.advance_to_district(&"baixo_centro", rng),
		"É permitido permanecer no Baixo-Centro ao avançar Tarde → Noite.")
	check(gerencia.campaign.day == 1 \
		and gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.NIGHT,
		"Tarde → Noite não muda o Dia.")
	activate_information_by_moving(gerencia, exploration)
	var owner := gerencia.campaign.active_entity_states[0]
	var skill_manager := scene.get_node("SkillManager") as SkillManager
	var doll := load("res://resources/skills/passives/curses/bonequinha_de_pano.tres") as PassiveSkillData
	owner.current_health = owner.max_health
	check(skill_manager.grant_skill(owner, doll, &"test", &"day_turn_doll") != null,
		"Uma passiva de virada de Dia pode estar ativa antes de avançar.")
	var food := load("res://resources/itens/consumables/pipoca_de_rua.tres") as ItemData
	var rotten := load("res://resources/itens/states/apodrecido.tres") as ItemStateData
	var spoiled_copy := InventoryItemState.new(food)
	spoiled_copy.states.append(rotten)
	owner.inventory_items.append(spoiled_copy)
	var fresh_copy := InventoryItemState.new(food)
	owner.inventory_items.append(fresh_copy)
	check(rounds.advance_to_district(&"suburbio", rng),
		"Da Noite, pode entrar no novo Dia por distrito adjacente.")
	check(gerencia.campaign.day == 2 \
		and gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.MORNING \
		and gerencia.campaign.district == &"suburbio",
		"Noite → Manhã incrementa o Dia e aplica a escolha de distrito.")
	check(spoiled_copy not in owner.inventory_items and fresh_copy in owner.inventory_items,
		"Na virada, apenas a cópia apodrecida é descartada.")
	var health_after_day_start := owner.current_health
	check(health_after_day_start < owner.max_health,
		"A virada de Dia despacha a passiva diária já executável.")
	check(skill_manager.on_day_started(gerencia.campaign).is_empty() \
		and owner.current_health == health_after_day_start,
		"A mesma manhã não dispara a passiva diária duas vezes.")
	check(gerencia.campaign.last_processed_day_start == 2 \
		and gerencia.campaign.last_processed_round_start == gerencia.campaign.get_round_index(),
		"Efeitos de início de Dia e Rodada são registrados uma vez.")
	print("ROUND_MANAGER_TEST_OK" if failures == 0 else "ROUND_MANAGER_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func activate_information_by_moving(gerencia: GerenciaJogo,
		exploration: ExplorationManager) -> void:
	var grid := gerencia.campaign.current_map
	var information: Informacao
	for coord in grid.cells:
		if grid.get_ppp_block_type(coord) == HexGrid.PPPBlockType.INFORMATION:
			information = grid.get_ppp_block_resource(coord) as Informacao
			break
	check(information != null, "O mapa precisa conter Informação.")
	if information == null:
		return
	grid.set_ppp_block(Vector2i(0, 1), HexGrid.PPPBlockType.INFORMATION, information)
	check(exploration.try_move(Vector2i(0, 1)),
		"O primeiro jogável chega à Informação e ativa o bloco automaticamente.")
	# Hoje a Informação abre uma janela de leitura; só CONFIRMAR a registra.
	var popup := gerencia.map_view.get_node("BlockActivationPopup") as BlockActivationPopup
	if popup != null:
		popup._confirm_information()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
