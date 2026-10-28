extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	var campaign := CampaignState.new()
	check(campaign.start_new_game(party, 12, null,
		EventCampaignEligibility.Mode.COMPLETE, [], GameDifficulty.Mode.SUGAR),
		"Água com Açúcar inicia uma campanha própria.")
	check(campaign.difficulty == GameDifficulty.Mode.SUGAR,
		"A dificuldade inicial pertence à campanha.")
	check(campaign.request_difficulty(GameDifficulty.Mode.CHAOTIC),
		"Caótico pode ser agendado como dificuldade da campanha.")
	check(campaign.request_difficulty(GameDifficulty.Mode.SUGAR),
		"Retornar ao modo atual cancela a troca agendada.")

	var first := _map(101, 1, false, 0, GameDifficulty.Mode.SUGAR, false)
	check(first != null, "Primeiro mapa fácil é gerado.")
	if first != null:
		check(_fixed_count(first, HexGrid.PPPBlockType.CONSUMABLE) == 8,
			"Fácil gera oito Consumíveis fixos.")
		check(_fixed_count(first, HexGrid.PPPBlockType.ENCOUNTER) == 8,
			"Fácil gera oito Encontros fixos.")
		check(_fixed_valence(first, EventData.Valence.GOOD) == 5 \
			and _fixed_valence(first, EventData.Valence.BAD) == 2,
			"Fácil desloca uma cota de Evento ruim para bom.")
		check(_hazards(first) == 0,
			"Primeiro mapa fácil não tem Maldição, Catástrofe ou Armadilha.")
	for seed in 6:
		var next := _map(303 + seed, 2, true, 1, GameDifficulty.Mode.SUGAR, false)
		check(next != null, "Mapa posterior fácil é gerado: %d." % seed)
		if next != null:
			check(_hazards(next) <= 1, "Mapa fácil não acumula três tipos de perigo.")
	var suppressed := _map(901, 2, true, 1, GameDifficulty.Mode.SUGAR, true)
	check(suppressed != null and _hazards(suppressed) == 0,
		"Maldição carregada ou Catástrofe vigente suspende perigos no mapa fácil.")
	var ordinary_with_suppression := _map(901, 2, true, 1,
		GameDifficulty.Mode.STANDARD, true)
	check(ordinary_with_suppression != null \
		and _fixed_count(ordinary_with_suppression, HexGrid.PPPBlockType.ENCOUNTER) == 10,
		"Sinal de supressão do fácil não altera cotas do Padrão.")
	var standard := _map(101, 1, false, 0, GameDifficulty.Mode.STANDARD, false)
	check(standard != null, "Mapa Padrão continua gerável.")
	if standard != null:
		check(_fixed_count(standard, HexGrid.PPPBlockType.CONSUMABLE) == 6 \
			and _fixed_count(standard, HexGrid.PPPBlockType.ENCOUNTER) == 10 \
			and _fixed_valence(standard, EventData.Valence.GOOD) == 4 \
			and _fixed_valence(standard, EventData.Valence.BAD) == 3,
			"Cotas do Padrão permanecem originais.")

	var skills := SkillManager.new()
	root.add_child(skills)
	var experience := load("res://resources/entities/entities_general/a_experiencia.tres") as EntityData
	var enemy := EntityState.from_encounter_member(experience, &"sugar", 1, Vector2i.ZERO)
	var protected := skills.apply_incoming_damage(enemy, 10, campaign)
	check(protected.get("damage") == 8,
		"Proteção hostil de 75% é limitada a 25% no fácil.")
	var guarded_enemy := EntityState.from_encounter_member(experience,
		&"sugar_guard", 1, Vector2i.ZERO)
	var guarded := skills.apply_incoming_damage(guarded_enemy, 3, campaign,
		{"protection_basis": 10})
	check(guarded.get("damage") == 8,
		"Redução prévia de guarda não contorna o teto total de Proteção fácil.")
	campaign.difficulty = GameDifficulty.Mode.STANDARD
	var standard_enemy := EntityState.from_encounter_member(experience,
		&"standard", 1, Vector2i.ZERO)
	var standard_protection := skills.apply_incoming_damage(standard_enemy, 10, campaign)
	check(standard_protection.get("damage") == 2,
		"Padrão mantém a Proteção original de 75%.")
	var dodge := load("res://resources/skills/passives/esquiva_60.tres") as PassiveSkillData
	var grant := SkillGrantState.new(dodge, &"test", &"dodge")
	var grants: Array[SkillGrantState] = [grant]
	var trigger := PassiveSkillData.Trigger.ON_BEFORE_DAMAGE_RECEIVED
	var preferred := skills._preferred_hostile_dodge(enemy, trigger, grants)
	check(is_equal_approx(skills._effective_passive_chance(enemy, trigger,
		grant, preferred, campaign), 0.30), "Padrão mantém teto inimigo de 30%.")
	campaign.difficulty = GameDifficulty.Mode.SUGAR
	check(is_equal_approx(skills._effective_passive_chance(enemy, trigger,
		grant, preferred, campaign), 0.10), "Fácil limita Esquiva inimiga a 10%.")
	check(is_equal_approx(dodge.activation_chance, 0.60),
		"Trocar modo não modifica o Resource de Esquiva.")

	var actor := campaign.active_entity_states[0]
	var curse := load("res://resources/itens/curseds/bonequinha_de_pano.tres") as ItemData
	var curse_entry := InventoryItemState.new(curse)
	actor.inventory_items.append(curse_entry)
	check(campaign.has_carried_curse(), "Maldição carregada é detectada sem equipá-la.")
	actor.inventory_items.erase(curse_entry)
	check(not campaign.has_carried_curse(), "Retirar maldição libera a regra futura de perigo.")
	var ending_effect := Event_EffectData.new()
	ending_effect.expiration_mode = Event_EffectData.ExpirationMode.END_OF_CURRENT_ROUND
	campaign.active_catastrophes.append({"day": 1, "round_index": 0,
		"effects": [ending_effect]})
	check(campaign.has_catastrophe_at(1, 0) \
		and not campaign.has_catastrophe_at(1, 1),
		"Catástrofe que expira na virada não bloqueia perigos da Rodada seguinte.")
	campaign.active_catastrophes.clear()
	actor.skill_grants.clear()
	actor.current_health = 5
	var hit := {"mode": HexGrid.PPPMapMode.COMBAT,
		"combat_id": &"sugar_combat_1", "direct_attack": true,
		"damage_source": enemy}
	var saved := skills.apply_incoming_damage(actor, 10, campaign, hit)
	check(saved.get("survived_lethal_hit", false) and actor.current_health == 1,
		"Primeiro golpe letal deixa o jogável com 1 Vida.")
	skills.apply_incoming_damage(actor, 2, campaign, hit)
	check(actor.current_health == 0, "Segundo golpe letal do mesmo combate pode matar.")
	actor.current_health = 5
	hit["combat_id"] = &"sugar_combat_2"
	skills.apply_incoming_damage(actor, 10, campaign, hit)
	check(actor.current_health == 1, "Proteção recarrega em outro combate.")
	actor.current_health = 5
	var periodic := skills.apply_incoming_damage(actor, 10, campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat_id": &"sugar_combat_3",
		"damage_source": enemy})
	check(actor.current_health == 0 and not periodic.get("survived_lethal_hit", false),
		"Dano não classificado como ataque direto não usa a proteção.")
	campaign.difficulty = GameDifficulty.Mode.STANDARD
	actor.current_health = 5
	hit["combat_id"] = &"standard_combat"
	skills.apply_incoming_damage(actor, 10, campaign, hit)
	check(actor.current_health == 0, "Padrão nunca usa sobrevivência do fácil.")
	actor.current_health = 5
	campaign.difficulty = GameDifficulty.Mode.SUGAR

	var combat := CombatManager.new()
	var game := GerenciaJogo.new()
	game.campaign = campaign
	combat.gerencia = game
	root.add_child(combat)
	combat.enemy_visual_root = Node2D.new()
	root.add_child(combat.enemy_visual_root)
	combat._show_damage_popup(actor, 4, "SEM DANO", true)
	var rescue_popup := combat.enemy_visual_root.get_child(0) as Label
	check(rescue_popup.text == "-4 · 1 DE VIDA",
		"Golpe salvo exibe dano e a sobrevivência no mesmo popup.")
	var recruit := EntityState.from_encounter_member(experience, &"recruit", 2,
		Vector2i.ZERO)
	combat._apply_easy_enemy_attack_adjustment(recruit)
	combat._apply_easy_enemy_attack_adjustment(recruit)
	check(recruit.attack == experience.ataque_base - 1 \
		and experience.ataque_base == 12,
		"Redução de Ataque é única e não altera a ficha.")
	check(campaign.register_companion(actor, recruit, null, null, false)
		and recruit.attack == experience.ataque_base,
		"Recrutar devolve o ponto retirado apenas enquanto hostil.")
	campaign.difficulty = GameDifficulty.Mode.STANDARD
	var normal_spawn := EntityState.from_encounter_member(experience,
		&"normal_spawn", 3, Vector2i.ZERO)
	combat._apply_easy_enemy_attack_adjustment(normal_spawn)
	check(normal_spawn.attack == experience.ataque_base,
		"Modo Padrão não herda redutor de Ataque.")

	var settings := CampaignSettingsMenu.new()
	settings.campaign = campaign
	root.add_child(settings)
	settings.open()
	var easy_button := settings._difficulty_controls[GameDifficulty.Mode.SUGAR]
	var standard_button := settings._difficulty_controls[GameDifficulty.Mode.STANDARD]
	check(not easy_button.disabled and not standard_button.disabled \
		and not settings._difficulty_controls[GameDifficulty.Mode.CHAOTIC].disabled,
		"Configurações ingame libera os três modos.")
	easy_button.pressed.emit()
	check(campaign.pending_difficulty == GameDifficulty.Mode.SUGAR,
		"Botão ingame agenda Água com Açúcar.")
	standard_button.pressed.emit()
	check(campaign.pending_difficulty == -1,
		"Selecionar o modo atual cancela troca pendente.")
	easy_button.pressed.emit()
	settings.close()
	check(campaign.pending_difficulty == GameDifficulty.Mode.SUGAR
		and campaign.difficulty == GameDifficulty.Mode.STANDARD
		and campaign.difficulty_for_next_round() == GameDifficulty.Mode.SUGAR,
		"Troca pelas Configurações fica pendente até a próxima Rodada.")
	var codec := CampaignSaveCodec.new()
	var graph := codec.encode(campaign)
	check(codec.error.is_empty() and not graph.is_empty(),
		"Campanha com troca pendente é serializada.")
	var restored := codec.decode(graph) as CampaignState
	check(codec.error.is_empty() and restored != null \
		and restored.difficulty == GameDifficulty.Mode.STANDARD \
		and restored.pending_difficulty == GameDifficulty.Mode.SUGAR,
		"Save/load mantém dificuldade vigente e próxima separadas.")
	var legacy_graph := graph.duplicate(true)
	for record in legacy_graph["objects"]:
		if record.get("script", "") == "res://scripts/campaign/campaign_state.gd":
			(record["fields"] as Dictionary).erase("difficulty")
			(record["fields"] as Dictionary).erase("pending_difficulty")
	var legacy := codec.decode(legacy_graph) as CampaignState
	check(codec.error.is_empty() and legacy != null \
		and legacy.difficulty == GameDifficulty.Mode.STANDARD \
		and legacy.pending_difficulty == -1,
		"Saves antigos sem dificuldade abrem em Padrão, sem pendência.")
	if restored != null:
		restored.commit_pending_difficulty()
		check(restored.difficulty == GameDifficulty.Mode.SUGAR \
			and restored.pending_difficulty == -1,
			"Próxima Rodada ativa e consome a troca pendente.")
		check(restored.request_difficulty(GameDifficulty.Mode.STANDARD),
			"Pode solicitar retorno ao Padrão.")
		restored.commit_pending_difficulty()
		check(restored.difficulty == GameDifficulty.Mode.STANDARD,
			"Retorno ao Padrão não conserva regras do fácil.")

	root.size = Vector2i(1600, 900)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var live := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var seeded := RandomNumberGenerator.new()
	seeded.seed = 4242
	check(live.start_new_game(party) and rounds.start_first_map(seeded),
		"Campanha Padrão inicia em cena real.")
	var bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	bar.pause_button.pressed.emit()
	var pause: Variant = bar.pause_menu
	check(pause.is_open(), "Menu de pausa abre para mudar dificuldade ingame.")
	pause._open_settings()
	var live_settings := pause.get("_settings_menu") as CampaignSettingsMenu
	check(live_settings.visible and live_settings.campaign == live.campaign,
		"Configurações da pausa apontam à campanha real.")
	live_settings._difficulty_controls[GameDifficulty.Mode.SUGAR].pressed.emit()
	check(live.campaign.pending_difficulty == GameDifficulty.Mode.SUGAR \
		and live.campaign.difficulty == GameDifficulty.Mode.STANDARD,
		"Mudar na pausa não altera o mapa/combate atual.")
	pause.close()
	live.campaign.information_obtained_on_current_map = true
	seeded.seed = 4243
	check(rounds.advance_to_district(&"suburbio", seeded),
		"Avanço real instala a Rodada com Água com Açúcar.")
	check(live.campaign.difficulty == GameDifficulty.Mode.SUGAR \
		and live.campaign.pending_difficulty == -1 \
		and _fixed_count(live.campaign.current_map,
			HexGrid.PPPBlockType.CONSUMABLE) == 8,
		"A troca se confirma junto ao mapa fácil, nunca antes.")
	check(live.campaign.request_difficulty(GameDifficulty.Mode.STANDARD),
		"Pode retornar ao Padrão durante a campanha.")
	live.campaign.information_obtained_on_current_map = true
	seeded.seed = 4244
	check(rounds.advance_to_district(&"suburbio", seeded),
		"Rodada seguinte retorna ao Padrão.")
	check(live.campaign.difficulty == GameDifficulty.Mode.STANDARD \
		and _fixed_count(live.campaign.current_map,
			HexGrid.PPPBlockType.CONSUMABLE) == 6 \
		and _fixed_count(live.campaign.current_map,
			HexGrid.PPPBlockType.ENCOUNTER) == 10,
		"Retorno ao Padrão restaura cotas sem vestígios do fácil.")
	check(live.campaign.request_difficulty(GameDifficulty.Mode.CHAOTIC),
		"Pode agendar Caótico durante a campanha.")
	check(live.campaign.difficulty == GameDifficulty.Mode.STANDARD,
		"Agendar Caótico não altera o mapa corrente.")
	live.campaign.information_obtained_on_current_map = true
	seeded.seed = 4245
	check(rounds.advance_to_district(&"suburbio", seeded),
		"Rodada seguinte instala mapa Caótico.")
	check(live.campaign.difficulty == GameDifficulty.Mode.CHAOTIC \
		and live.campaign.pending_difficulty == -1 \
		and _fixed_count(live.campaign.current_map,
			HexGrid.PPPBlockType.CONSUMABLE) in [4, 5, 6, 7],
		"Caótico aplica cotas próprias somente após instalar o mapa.")
	check(live.campaign.request_difficulty(GameDifficulty.Mode.STANDARD),
		"Pode retornar do Caótico ao Padrão.")
	live.campaign.information_obtained_on_current_map = true
	seeded.seed = 4246
	check(rounds.advance_to_district(&"suburbio", seeded),
		"Rodada posterior reinstala o Padrão após o Caótico.")
	check(live.campaign.difficulty == GameDifficulty.Mode.STANDARD \
		and _fixed_count(live.campaign.current_map,
			HexGrid.PPPBlockType.CONSUMABLE) == 6 \
		and _fixed_count(live.campaign.current_map,
			HexGrid.PPPBlockType.ENCOUNTER) == 10,
		"Padrão não herda quotas do Caótico.")

	print("SUGAR_DIFFICULTY_TEST_OK" if failures == 0 else \
		"SUGAR_DIFFICULTY_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _map(seed: int, day: int, previous: bool, information_count: int,
		difficulty: int, suppress_hazards: bool) -> HexGrid:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var information: Array[Resource] = [
		load("res://resources/informacoes/orchestra/orchestra_1.tres"),
		load("res://resources/informacoes/orchestra/orchestra_2.tres")]
	var occurred: Array[StringName] = []
	var standby: Array[String] = []
	return PPPMapGenerator.new().generate_new_map(information, &"suburbio",
		PPPMapGenerator.RoundPeriod.MORNING, {}, occurred, rng, standby,
		day, false, information_count, previous, false,
		EventCampaignEligibility.Mode.COMPLETE, true, difficulty, suppress_hazards)


func _fixed_count(grid: HexGrid, block_type: int) -> int:
	var count := 0
	for coord in grid.cells:
		if grid.get_ppp_block_type(coord) == block_type \
				and not bool(grid.get_ppp_block_data(coord).get(
					"generated_from_random_block", false)):
			count += 1
	return count


func _fixed_valence(grid: HexGrid, valence: int) -> int:
	var count := 0
	for coord in grid.cells:
		var event := grid.get_ppp_block_resource(coord) as EventData
		if event != null and event.valence == valence \
				and not bool(grid.get_ppp_block_data(coord).get(
					"generated_from_random_block", false)):
			count += 1
	return count


func _hazards(grid: HexGrid) -> int:
	var count := 0
	for coord in grid.cells:
		if grid.get_ppp_block_type(coord) in [HexGrid.PPPBlockType.CURSE,
				HexGrid.PPPBlockType.CATASTROPHE, HexGrid.PPPBlockType.TRAP]:
			count += 1
	return count


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
