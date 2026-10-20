extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var velha_data := load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData
	var owner := EntityState.from_playable_selection(velha_data, &"Playable_1", Vector2i(1, 2))
	owner.turn_state = EntityState.TurnState.TURNING
	owner.turn_serial = 1
	campaign.active_entity_states.append(owner)
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	for coord in grid.cells:
		grid.set_ppp_block(coord, HexGrid.PPPBlockType.INFORMATION, information)
	var catastrophe := load("res://resources/events/catastrophes/72-nevasca.tres") as EventData
	var encounter := load("res://resources/encounters/enc_barata_voadora.tres") as EncounterData
	check(catastrophe != null and encounter != null, "Resources de perigo e encontro devem existir.")
	grid.set_ppp_block(Vector2i(2, 2), HexGrid.PPPBlockType.CATASTROPHE, catastrophe)
	grid.set_ppp_block(Vector2i(3, 2), HexGrid.PPPBlockType.ENCOUNTER, encounter)
	grid.set_ppp_block(Vector2i(5, 2), HexGrid.PPPBlockType.ENCOUNTER, encounter)
	var bad_event := load("res://resources/events/random_events/13-ladroes_das_sombras.tres") as EventData
	var bad_permanent := load("res://resources/events/permanent_effects/66-voce_esta_doente.tres") as EventData
	var good_event := load("res://resources/events/random_events/14-amigo_imaginario.tres") as EventData
	grid.set_ppp_block(Vector2i(1, 1), HexGrid.PPPBlockType.EVENT, bad_event)
	grid.set_ppp_block(Vector2i(2, 1), HexGrid.PPPBlockType.EVENT, bad_permanent)
	grid.set_ppp_block(Vector2i(1, 3), HexGrid.PPPBlockType.EVENT, good_event)
	campaign.current_map = grid
	var manager := SkillManager.new()
	root.add_child(manager)
	var view := PPPMapView.new()
	view.grid = grid

	var mae_skill := load("res://resources/skills/actives/playables/mae/eu_ja_sabia.tres") as ActiveSkillData
	var mae_grant := manager.grant_skill(owner, mae_skill, &"event", &"test_mae")
	check(manager.use_exploration_active(owner, owner, mae_grant, campaign,
		EntityState.UNPLACED, null, view), "Busca da Mãe deve executar pelo gerenciador universal.")
	check(view.is_temporary_inspection(Vector2i(2, 2)) \
		and grid.get_cell(Vector2i(2, 2)).state == HexGrid.PPPBlockState.HIDDEN,
		"Catástrofe no alcance fica destacada sem virar revelação permanente.")
	check(view.is_temporary_inspection(Vector2i(1, 1)) \
		and view.is_temporary_inspection(Vector2i(2, 1)) \
		and not view.is_temporary_inspection(Vector2i(1, 3)),
		"A Mãe destaca Eventos ruins comuns e permanentes, mas não Eventos bons.")
	check(grid.get_cell(Vector2i(3, 2)).state == HexGrid.PPPBlockState.HIDDEN, "Encontro não deve ser revelado pelo filtro da Mãe.")
	view.clear_temporary_inspection(owner)
	check(not view.is_temporary_inspection(Vector2i(2, 2)),
		"Destaque da Mãe termina junto do turno.")
	check(not manager.use_exploration_active(owner, owner, mae_grant, campaign), "Limite de uma vez na Rodada deve valer.")

	var vision := load("res://resources/skills/actives/permanent_effects/olhos_bionicos_revelar.tres") as ActiveSkillData
	var vision_grant := manager.grant_skill(owner, vision, &"event", &"eyes")
	check(manager.use_exploration_active(owner, owner, vision_grant, campaign, Vector2i(3, 2)), "Ativa concedida por Evento usa o mesmo caminho.")
	check(grid.get_cell(Vector2i(3, 2)).state == HexGrid.PPPBlockState.REVEALED, "Visão Biônica revela sem ativar.")
	check(not manager.use_exploration_active(owner, owner, vision_grant, campaign, Vector2i(4, 2)), "Visão Biônica é uma vez por turno.")
	var glasses := load("res://resources/itens/equipments/acessorios/oculos_de_leitura.tres") as ItemData
	var glasses_skill := glasses.granted_active_skills[0]
	var glasses_grant := manager.grant_skill(owner, glasses_skill, &"item", &"glasses_test")
	owner.stamina_remaining = owner.max_stamina
	check(manager.use_exploration_active(owner, owner, glasses_grant, campaign,
		Vector2i(2, 2)), "Óculos revelam o primeiro hex escolhido ao alcance da Estamina.")
	check(manager.use_exploration_active(owner, owner, glasses_grant, campaign,
		Vector2i(2, 3)), "Óculos revelam o segundo hex no mesmo turno.")
	check(grid.get_cell(Vector2i(2, 2)).state == HexGrid.PPPBlockState.REVEALED \
		and grid.get_cell(Vector2i(2, 3)).state == HexGrid.PPPBlockState.REVEALED,
		"Os dois hexes escolhidos ficam revelados, sem ativar o conteúdo.")
	check(not manager.use_exploration_active(owner, owner, glasses_grant, campaign,
		Vector2i(1, 3)), "Terceira revelação dos Óculos na Rodada é bloqueada.")
	var second_pair := manager.grant_skill(owner, glasses_skill, &"item", &"glasses_turn_test")
	check(manager.use_exploration_active(owner, owner, second_pair, campaign,
		Vector2i(1, 3)), "Outra tentativa pode revelar um primeiro hex.")
	owner.turn_serial += 1
	check(not manager.use_exploration_active(owner, owner, second_pair, campaign,
		Vector2i(0, 1)), "Passar o turno perde a segunda revelação dos Óculos.")
	var cartola := load("res://resources/itens/equipments/acessorios/acessorio_epico_cartola_do_magico.tres") as ItemData
	var teleport_grant := manager.grant_skill(owner, cartola.granted_active_skills[0],
		&"item", &"cartola_test")
	check(manager.can_use_exploration_active(owner, owner, teleport_grant, campaign,
		Vector2i(7, 3), null, view),
		"Cartola aceita um hex livre distante, sem limite de Estamina.")
	check(not manager.can_use_exploration_active(owner, owner, teleport_grant, campaign,
		owner.position, null, view), "Cartola não oferece o hex já ocupado.")
	var timepiece := load("res://resources/itens/equipments/acessorios/acessorio_epico_passa_tempo.tres") as ItemData
	var evolution_grant := manager.grant_skill(owner, timepiece.granted_active_skills[0],
		&"item", &"timepiece_test")
	var sling := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	var sling_copy := InventoryItemState.new(sling)
	sling_copy.improvement_attack = 3
	owner.inventory_items.append(sling_copy)
	var epic := sling.craft_result[0]
	check(manager.use_exploration_active(owner, owner, evolution_grant, campaign,
		EntityState.UNPLACED, null, view, false,
		{"selected_item": sling_copy, "result_item": epic}),
		"Passa-tempo transforma uma cópia comum escolhida na evolução Épica.")
	check(owner.inventory_items[owner.inventory_items.size() - 1].data == epic \
		and owner.inventory_items[owner.inventory_items.size() - 1].improvement_attack == 3,
		"Passa-tempo preserva melhorias da cópia ao transformá-la.")
	var inventory := InventoryManager.new()
	var chance_food := ItemData.new()
	chance_food.id = &"test_chance_food"
	chance_food.display_name = "Teste de chance"
	chance_food.item_type = ItemData.ItemType.CONSUMABLE
	var healing := SkillEffectData.new()
	healing.effect_type = SkillEffectData.EffectType.HEAL_FIXED
	healing.amount = 2
	var chance_effect := SkillEffectData.new()
	chance_effect.effect_type = SkillEffectData.EffectType.MODIFY_ATTRIBUTE
	chance_effect.attribute_id = &"attack"
	chance_effect.amount = 2
	chance_effect.activation_chance = 0.0
	chance_food.use_effects.append(healing)
	chance_food.use_effects.append(chance_effect)
	var chance_copy := InventoryItemState.new(chance_food)
	owner.inventory_items.append(chance_copy)
	owner.current_health = owner.max_health - 3
	var chance_result := inventory.use_consumable(owner, chance_copy, manager, campaign)
	check(chance_result.get("success", false) and owner.current_health == owner.max_health - 1 \
		and chance_result.get("chance_results", []).has("Não foi dessa vez..."),
		"Consumível informa falha percentual sem perder seu efeito garantido.")
	var faro := load("res://resources/skills/actives/playables/jornalista/faro_jornalistico.tres") as ActiveSkillData
	var faro_grant := manager.grant_skill(owner, faro, &"event", &"journalist")
	check(not manager.use_exploration_active(owner, owner, faro_grant, campaign, Vector2i(6, 2)), "Faro precisa de Informação obtida, não só revelada.")
	check(campaign.record_information_obtained(information), "Ativar Informação deve registrar sua obtenção.")
	check(manager.use_exploration_active(owner, owner, faro_grant, campaign, Vector2i(6, 2)), "Uma Informação dá um uso diário ao Faro.")
	check(not manager.use_exploration_active(owner, owner, faro_grant, campaign, Vector2i(7, 2)), "O uso diário do Faro se esgota.")
	campaign.day = 2
	check(manager.use_exploration_active(owner, owner, faro_grant, campaign, Vector2i(7, 2)), "No Dia seguinte o uso volta, sem apagar o limite acumulado.")

	var cat_data := load("res://resources/entities/entities_general/companions/gatinho_vira_lata.tres") as EntityData
	var cat := EntityState.from_playable_selection(cat_data, &"Companion_1", EntityState.UNPLACED)
	check(campaign.register_companion(owner, cat), "Gatinho deve ficar ligado ao dono sem ocupar uma vaga jogável.")
	var cat_grant := manager.get_active_grants(cat)[0]
	check((cat_grant.skill as ActiveSkillData).target_mode == ActiveSkillData.TargetMode.TILE, "Gatinho escolhe hex, não entidade.")
	check(manager.use_exploration_active(cat, owner, cat_grant, campaign, Vector2i(4, 2)), "Gatinho pode ser posicionado em hex livre.")
	check(cat.position == Vector2i(4, 2), "A posição pertence ao estado da instância do Gatinho.")
	check(grid.get_cell(Vector2i(5, 2)).state == HexGrid.PPPBlockState.REVEALED, "Gatinho revela Encontro adjacente.")
	check(not manager.use_exploration_active(cat, owner, cat_grant, campaign, Vector2i(5, 2)), "Reposicionamento espera turnos do dono.")
	check(grid.get_cell(Vector2i(4, 2)).state == HexGrid.PPPBlockState.HIDDEN, "Posicionar não ativa nem revela o centro.")
	var extra_cat_grant := manager.grant_skill(cat, cat_grant.skill, &"event", &"extra_source")
	check(not manager.use_exploration_active(cat, owner, extra_cat_grant, campaign, owner.position), "Não pode posicionar em hex ocupado.")

	print("EXPLORATION_SKILLS_TEST_OK" if failures == 0 else "EXPLORATION_SKILLS_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
