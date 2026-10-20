extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	var visuals := scene.get_node("MapRoot/CatastropheVisualController") as CatastropheVisualController
	var profile := CatastropheVisualProfile.new()
	profile.event_id = CampaignState.PORTAIS_INFERNAIS_EVENT_ID
	profile.filter_color = Color(0.8, 0.05, 0.05, 0.2)
	var visual_scene := PackedScene.new()
	var visual_sample := Node2D.new()
	visual_sample.name = "InfernalTestVisual"
	check(visual_scene.pack(visual_sample) == OK, "Cena de animação de teste é válida.")
	visual_sample.free()
	profile.animation_scene = visual_scene
	var snow_profile := CatastropheVisualProfile.new()
	snow_profile.event_id = CampaignState.NEVASCA_EVENT_ID
	var snow_scene := PackedScene.new()
	var snow_sample := Node2D.new()
	snow_sample.name = "SnowTestVisual"
	check(snow_scene.pack(snow_sample) == OK, "Cena de neve de teste é válida.")
	snow_sample.free()
	snow_profile.animation_scene = snow_scene
	visuals.profiles = [profile, snow_profile]
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var manager := scene.get_node("CatastropheManager") as CatastropheManager
	var skill := scene.get_node("SkillManager") as SkillManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var rounds := scene.get_node("RoundManager") as RoundManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(), "Campanha e mapa inicial.")
	var campaign := gerencia.campaign
	for member in campaign.active_entity_states:
		member.inventory_items.clear() # Isola a Praga do kit inicial sorteado.
	var actor := campaign.active_entity_states[0]
	var other := campaign.active_entity_states[1]
	var chocolate := load("res://resources/itens/consumables/chocolate.tres") as ItemData
	check(skill.inventory_manager.add_item(actor, chocolate), "Consumível inicial inserido.")
	var original_max := actor.max_health
	var original_attack := actor.attack
	var coord := Vector2i(0, 0)
	var plague := load("res://resources/events/catastrophes/71-uma_praga_de_lavas.tres") as EventData
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.CATASTROPHE, plague)
	check(block.begin_activation(coord, actor), "Praga abre consequência.")
	check(campaign.active_catastrophes.is_empty() and actor.inventory_items[0].states.is_empty(),
		"Antes de confirmar, a catástrofe ainda não alterou o jogo.")
	_confirm_and_read(popup)
	check(not block.is_busy() and manager.gerencia == gerencia and campaign.active_catastrophes.size() == 1,
		"OK aplica a regra e libera o bloco.")
	check(actor.inventory_items[0].states.any(func(s: ItemStateData) -> bool: return s.id == &"apodrecido"),
		"Consumível já carregado apodrece.")
	skill.inventory_manager.add_item(other, chocolate)
	check(other.inventory_items[0].states.any(func(s: ItemStateData) -> bool: return s.id == &"apodrecido"),
		"Consumível adquirido durante a Praga nasce apodrecido.")

	var snow := load("res://resources/events/catastrophes/72-nevasca.tres") as EventData
	coord = Vector2i(1, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.CATASTROPHE, snow)
	check(block.begin_activation(coord, actor), "Nevasca abre consequência.")
	_confirm_and_read(popup)
	check(campaign.get_active_visual_weather() == snow.id, "Nevasca começa após OK, inclusive visual.")
	check(scene.get_node_or_null("MapRoot/DepthSorted/CatastropheVisuals/SnowTestVisual") != null,
		"Animação da Nevasca nasce após OK.")
	check(actor.max_health == original_max - ceili(float(original_max) * 0.1)
		and actor.attack == original_attack - ceili(float(original_attack) * 0.1),
		"Nevasca reduz Vida máxima e Ataque em 10%, arredondando para cima.")
	check(manager.allowed_movement_distance(actor, 4) == 1, "Nevasca limita o turno a 1 hex.")
	manager.on_movement_finished(actor, 1)
	check(manager.allowed_movement_distance(actor, 4) == 0,
		"Após andar 1 hex, não sobra deslocamento neste turno da Nevasca.")
	actor.turn_serial += 1
	check(manager.allowed_movement_distance(actor, 4) == 1,
		"Novo turno libera novamente 1 hex de deslocamento.")
	var enemy := EntityState.new()
	enemy.instance_id = &"test_enemy"
	enemy.controller = EntityState.Controller.AI
	enemy.max_health = 20
	enemy.current_health = 20
	enemy.attack = 6
	enemy.inventory_items.append(InventoryItemState.new(chocolate))
	manager.register_actor(enemy)
	check(enemy.max_health == 18 and enemy.attack == 5
		and manager.allowed_movement_distance(enemy, 4) == 1,
		"Inimigo surgido durante a Nevasca também recebe os efeitos globais.")
	check(enemy.inventory_items[0].states.any(func(s: ItemStateData) -> bool: return s.id == &"apodrecido"),
		"Inventário de inimigo surgido durante a Praga também apodrece.")
	var epic := ItemData.new()
	epic.item_type = ItemData.ItemType.EQUIPMENT
	epic.equipment_slot = ItemData.EquipmentSlot.ARMOR
	epic.rarity = ItemData.Rarity.EPIC
	actor.equipped_armors.append(InventoryItemState.new(epic))
	actor.equipment_changed.emit()
	check(actor.max_health == original_max and actor.attack == original_attack,
		"Armadura Épica remove penalidade imediatamente.")
	actor.equipped_armors.clear()
	actor.equipment_changed.emit()
	check(actor.max_health < original_max, "Desequipar a Épica reaplica penalidade.")

	var locusts := load("res://resources/events/catastrophes/73-chuva_de_gafanhotos.tres") as EventData
	coord = Vector2i(2, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.CATASTROPHE, locusts)
	check(block.begin_activation(coord, actor), "Gafanhotos abrem consequência.")
	_confirm_and_read(popup)
	check(manager.skills_suppressed(HexGrid.PPPMapMode.EXPLORATION, true)
		and manager.skills_suppressed(HexGrid.PPPMapMode.EXPLORATION, false)
		and not manager.skills_suppressed(HexGrid.PPPMapMode.COMBAT, false),
		"Passivas e ativas de Exploração ficam indisponíveis, sem bloquear Combate.")
	var hp_before := actor.current_health
	check(manager.before_action(actor) and actor.current_health == hp_before - 1,
		"Gafanhotos ferem antes de cada ação pela manhã.")

	var portals := load("res://resources/events/catastrophes/74-portais_infernais.tres") as EventData
	coord = Vector2i(3, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.CATASTROPHE, portals)
	check(block.begin_activation(coord, actor), "Portais abrem consequência.")
	_confirm_and_read(popup)
	check(campaign.are_infernal_portals_visuals_active(), "Filtro dos Portais liga após OK.")
	check(scene.get_node_or_null("MapRoot/DepthSorted/CatastropheVisuals/InfernalTestVisual") != null,
		"Cena de animação opcional permanece enquanto Portais está ativo.")
	check((visuals.get_child(0) as ColorRect).color == profile.filter_color,
		"Filtro opcional permanece enquanto Portais está ativo.")
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 74
	var was_hit := false
	for index in 12:
		var before := other.current_health
		manager.on_movement_finished(other, 1, seeded)
		if other.current_health < before:
			was_hit = true
			check(before - other.current_health >= 1 and before - other.current_health <= 6,
				"Portal causa 1d6 ao parar no destino.")
			break
	check(was_hit, "Sorteio de Portal pode atingir o alvo.")

	var aura := load("res://resources/events/catastrophes/75-aurea_funebre.tres") as EventData
	coord = Vector2i(4, 0)
	actor.position = coord
	campaign.current_map.set_ppp_block(coord, HexGrid.PPPBlockType.CATASTROPHE, aura)
	check(block.begin_activation(coord, actor), "Áurea abre consequência.")
	_confirm_and_read(popup)
	check(campaign.get_active_visual_weather() == aura.id, "Última catástrofe diária define o céu.")
	check(skill.debuff_manager.get_debuff(actor, &"db_00010") != null,
		"Áurea aplica Tristeza.")
	check(skill.debuff_manager.get_debuff(enemy, &"db_00010") != null,
		"Áurea também atinge inimigos registrados.")
	skill.debuff_manager.remove_debuff(actor, &"db_00010")
	check(skill.debuff_manager.get_debuff(actor, &"db_00010") != null,
		"Tristeza removida durante a Áurea é reaplicada enquanto o ambiente durar.")
	campaign.information_obtained_on_current_map = true
	check(rounds.advance_to_district(&"suburbio"),
		"Próxima fase real gera novo mapa e avança à Tarde.")
	check(campaign.active_catastrophes.size() == 3
		and not manager.skills_suppressed(HexGrid.PPPMapMode.EXPLORATION, true)
		and not campaign.are_infernal_portals_visuals_active(),
		"Na próxima Rodada, Gafanhotos e Portais terminam; efeitos diários ficam.")
	check(scene.get_node_or_null("MapRoot/DepthSorted/CatastropheVisuals/SnowTestVisual") != null,
		"Animação diária sobrevive à regeneração do mapa na Tarde.")
	await process_frame
	check(scene.get_node_or_null("MapRoot/DepthSorted/CatastropheVisuals/InfernalTestVisual") == null
		and (visuals.get_child(0) as ColorRect).color.a == 0.0,
		"Cena persistente e filtro são removidos quando a Rodada termina.")
	campaign.information_obtained_on_current_map = true
	check(rounds.advance_to_district(&"suburbio"), "Avança da Tarde para a Noite.")
	campaign.information_obtained_on_current_map = true
	check(rounds.advance_to_district(&"suburbio"),
		"Virada real de Noite para Manhã inicia o Dia 2.")
	check(campaign.active_catastrophes.is_empty() and actor.max_health == original_max
		and actor.attack == original_attack and skill.debuff_manager.get_debuff(actor, &"db_00010") == null,
		"Virada do Dia restaura atributos e encerra Tristeza sem curar Vida atual.")
	await process_frame
	check(scene.get_node_or_null("MapRoot/DepthSorted/CatastropheVisuals/SnowTestVisual") == null,
		"Animação da Nevasca sai apenas na virada do Dia.")
	check(enemy.max_health == 20 and enemy.attack == 6
		and skill.debuff_manager.get_debuff(enemy, &"db_00010") == null,
		"Inimigo também volta ao normal na virada.")
	check(actor.inventory_items.is_empty() and other.inventory_items.is_empty()
		and enemy.inventory_items.is_empty(),
		"A virada real descarta as três cópias apodrecidas, inclusive a do inimigo.")
	skill.inventory_manager.add_item(actor, chocolate)
	check(actor.inventory_items[0].states.is_empty(), "Novo Dia gera consumíveis normais.")
	campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	check(manager.activate(locusts, locusts.outcomes[0]).get("success", false),
		"Gafanhotos podem surgir de novo em outra Rodada.")
	var night_hp := enemy.current_health
	check(manager.before_action(enemy) and enemy.current_health == night_hp - 2,
		"À Noite, o dano anterior à ação é 2 também para inimigos.")
	print("CATASTROPHES_TEST: ", "PASS" if failures == 0 else "%d FAILURE(S)" % failures)
	quit(0 if failures == 0 else 1)


func _confirm_and_read(popup: BlockActivationPopup) -> void:
	popup._confirm_event({})
	if popup._outcome_reading:
		popup._execute_prepared_event()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
