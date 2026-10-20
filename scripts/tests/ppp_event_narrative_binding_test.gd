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
	var executor := scene.get_node("EventExecutor") as EventExecutor
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var playable: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	_check(gerencia.start_new_game(playable) and round_manager.start_first_map(),
		"A campanha de teste inicia.")
	var actor := gerencia.campaign.active_entity_states[0]
	var coord := Vector2i(0, 0)
	actor.position = coord
	var context := {"actor": actor, "coord": coord, "map": gerencia.campaign.current_map}
	for number in [46, 47, 48]:
		var filename: String = {
			46: "46-loja_de_acessorios_da_miss_fortuna.tres",
			47: "47-loja_de_ferramentas_da_miss_fortuna.tres",
			48: "48-loja_de_roupas_da_miss_fortuna.tres",
		}[number]
		var shop := load("res://resources/events/random_events/" + filename) as EventData
		var story := executor.resolve_narrative(shop, shop.narrative_description, context)
		_check(not story.contains("[fala_miss_fortuna]") and story.contains("— "),
			"Miss Fortuna %d recebe uma fala real." % number)
		_check(story == executor.resolve_narrative(shop, shop.narrative_description, context),
			"A fala sorteada não muda durante a leitura da mesma ativação.")
	for filename in ["05-um_raio_te_atingiu_na_cabeça_1.tres",
			"06-um_raio_te_atingiu_na_cabeça_2.tres", "17-o_informante.tres",
			"51-transmutacao_galiforme.tres"]:
		var event := load("res://resources/events/random_events/" + filename) as EventData
		var story := executor.resolve_narrative(event, event.narrative_description, context)
		_check(story.contains(actor.data.display_name) and not story.contains("personagem_ativo")
			and not story.contains("Personagem_ativo"),
			"O nome do ativador substitui o marcador em %s." % filename)
	var ally_event := load("res://resources/events/permanent_effects/65-um_aliado.tres") as EventData
	gerencia.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, ally_event)
	_check(block.begin_activation(coord, actor), "O evento 65 abre no mapa.")
	var initial_story := popup.narrative_label.text
	_check(not initial_story.contains("[um{a} Personagem]"),
		"O texto anuncia o aliado sorteado.")
	var expected_ally := executor._narrative_bindings.get("playable_ally") as EntityData
	_check(expected_ally != null and initial_story.contains(expected_ally.display_name),
		"O nome exibido é o nome guardado para o Outcome.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(gerencia.campaign.companion_states.any(func(companion: EntityState) -> bool:
		return companion.data == expected_ally),
		"O aliado que entrou no grupo é exatamente o anunciado.")
	var creature_event := load("res://resources/events/random_events/23-adestramento_sobrenatural.tres") as EventData
	coord = Vector2i(7, 0)
	actor.position = coord
	gerencia.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, creature_event)
	_check(block.begin_activation(coord, actor), "O evento 23 abre no mapa.")
	var expected_creature := executor._narrative_bindings.get("district_enemy") as EntityData
	_check(expected_creature != null and popup.narrative_label.text.contains(expected_creature.display_name)
		and not popup.narrative_label.text.contains("[criatura_sorteada]"),
		"A criatura sorteada aparece por nome no evento 23.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(gerencia.campaign.companion_states.any(func(companion: EntityState) -> bool:
		return companion.data == expected_creature),
		"A criatura anunciada torna-se aliada quando o Outcome é aceito.")
	var artifact := load("res://resources/events/random_events/20-um_artefato_magico.tres") as EventData
	var taming_story := executor.resolve_narrative(artifact,
		artifact.outcomes[2].narrative_description, context)
	_check(not taming_story.contains("[criatura_sorteada]"),
		"O marcador da criatura também é resolvido na narrativa de Outcome.")
	var artisan := load("res://resources/events/random_events/16-mestre_artesao.tres") as EventData
	var outcome_story := artisan.outcomes[0].narrative_description
	_check(not artisan.narrative_description.contains("martelar uma roupa") and
		outcome_story.contains("[resposta_artesao]"),
		"A fala condicional do Artesão está apenas no Outcome.")
	var weapon_data := load("res://resources/itens/equipments/armas/cabo_de_vassoura.tres") as ItemData
	var armor_data := load("res://resources/itens/equipments/armaduras/roupa_de_ficar_em_casa.tres") as ItemData
	if weapon_data != null and armor_data != null:
		var weapon := InventoryItemState.new(weapon_data)
		var armor := InventoryItemState.new(armor_data)
		var weapon_line := executor.resolve_narrative(artisan, outcome_story,
			{"actor": actor, "coord": coord, "decision": {"selected_item": weapon}})
		var armor_line := executor.resolve_narrative(artisan, outcome_story,
			{"actor": actor, "coord": coord, "decision": {"selected_item": armor}})
		_check(weapon_line.contains("Ela parece... melhor.") and
			armor_line.contains("Meio estranho martelar uma roupa") and
			not weapon_line.contains("Se for") and not armor_line.contains("Se for"),
			"A resposta do Artesão muda conforme o tipo selecionado sem mostrar instruções editoriais.")
	var imaginary := load("res://resources/events/random_events/14-amigo_imaginario.tres") as EventData
	_check(imaginary.outcomes[0].narrative_description.is_empty(),
		"O aviso do Amigo Imaginário não antecipa a revelação.")
	var encounter: EncounterData
	for filename in DirAccess.get_files_at("res://resources/encounters"):
		if filename.ends_with(".tres"):
			encounter = load("res://resources/encounters".path_join(filename)) as EncounterData
			if encounter != null and encounter.has_valid_composition():
				break
	coord = Vector2i(0, 0)
	actor.position = coord
	var reveal_coord := Vector2i(-1, -1)
	for candidate in gerencia.campaign.current_map.cells:
		if candidate != coord and HexGrid.distance(coord, candidate) <= actor.max_stamina:
			reveal_coord = candidate
			break
	_check(encounter != null and reveal_coord != Vector2i(-1, -1),
		"O teste encontrou um Encontro dentro do alcance.")
	if encounter != null and reveal_coord != Vector2i(-1, -1):
		gerencia.campaign.current_map.set_ppp_block(reveal_coord,
			HexGrid.PPPBlockType.ENCOUNTER, encounter)
		gerencia.campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.EVENT, imaginary)
		_check(block.begin_activation(coord, actor), "O Amigo Imaginário abre no mapa.")
		(popup.buttons.get_child(0) as Button).pressed.emit()
		_check(popup._outcome_reading and popup.narrative_label.text != "Isso aqui é perigoso!",
			"A fala não surge antes da aplicação da revelação.")
		(popup.buttons.get_child(0) as Button).pressed.emit()
		_check(gerencia.campaign.current_map.get_cell(reveal_coord).state
			== HexGrid.PPPBlockState.REVEALED and popup.overlay.visible
			and popup.narrative_label.text == "Isso aqui é perigoso!",
			"A fala surge somente depois que o Encontro foi revelado.")
		(popup.buttons.get_child(0) as Button).pressed.emit()
		_check(not block.is_busy(), "O OK do aviso encerra a ativação do Amigo Imaginário.")
	print("Narrativas dinâmicas: %d falhas." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
