extends SceneTree

var failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(rng),
		"Campanha real deve iniciar.")
	var campaign := gerencia.campaign
	campaign.active_entity_states[0].current_health -= 3
	campaign.current_map.reveal_ppp_block(Vector2i(2, 1))
	campaign.current_map.revealed_by_skill_ids[Vector2i(2, 1)] = [&"test_skill"]
	var ally_data := load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData
	var ally := EntityState.from_playable_selection(ally_data, &"Companion_Save_Test",
		EntityState.UNPLACED)
	ally.playable_slot_id = &""
	_check(campaign.register_companion(campaign.active_entity_states[0], ally, null,
		scene.get_node("SkillManager") as SkillManager),
		"Companheiro humano deve entrar no estado salvo.")
	var bleeding := load("res://resources/skills/effects/debuffs/sangramento.tres") as DebuffData
	var debuff := DebuffInstanceState.new(bleeding, ally)
	debuff.remaining_turns = 3
	campaign.active_entity_states[0].debuffs.append(debuff)
	campaign.visual_swap_originals[campaign.active_entity_states[0]] = campaign.active_entity_states[0].data
	campaign.active_entity_states[0].visual_identity = ally_data
	if not campaign.active_entity_states[0].equipped_weapons.is_empty():
		campaign.active_entity_states[0].equipped_weapons[0].improvement_attack = 3
	var codec := CampaignSaveCodec.new()
	var graph := codec.encode(campaign)
	_check(codec.error.is_empty(), "Codificação: " + codec.error)
	if codec.error.is_empty():
		var restored := codec.decode(graph) as CampaignState
		_check(codec.error.is_empty(), "Decodificação: " + codec.error)
		_check(restored != null and restored.campaign_id == campaign.campaign_id,
			"Identidade da campanha preservada.")
		if restored != null:
			_check(restored.current_map != campaign.current_map
				and restored.current_map.get_ppp_block_data(Vector2i(2, 1))
				== campaign.current_map.get_ppp_block_data(Vector2i(2, 1)),
				"Mapa não é regenerado e mantém o estado de cada bloco.")
			_check(restored.current_map.revealed_by_skill_ids.has(Vector2i(2, 1)),
				"Origem da revelação preservada.")
			_check(restored.active_entity_states[0].current_health
				== campaign.active_entity_states[0].current_health,
				"Estado mutável do personagem preservado.")
			_check(restored.active_entity_states[0].inventory_items.size()
				== campaign.active_entity_states[0].inventory_items.size(),
				"Inventário preservado.")
			_check(restored.companion_states.size() == 1
				and restored.companion_states[0].owner_instance_id
				== restored.active_entity_states[0].instance_id
				and restored.active_entity_states[0].debuffs[0].source
				== restored.companion_states[0],
				"Aliado, dono e fonte do Debuff preservam referências compartilhadas.")
			_check(restored.visual_swap_originals.has(restored.active_entity_states[0])
				and restored.active_entity_states[0].visual_identity == ally_data,
				"Troca visual e chave de objeto no estado da campanha sobrevivem.")
			_check(restored.world_rng.state == campaign.world_rng.state,
				"Sequência de sorteios gerais preservada.")
	var repository := CampaignSaveRepository.new("user://ppp_pool4_tests")
	var saved := repository.save_campaign(campaign, 1, scene)
	_check(saved.get("success", false), "Gravação do primeiro slot: " +
		str(saved.get("reason", "")))
	if saved.get("success", false):
		var first_catalog := repository.inspect_campaign(campaign.campaign_id)
		var first_preview: Dictionary = first_catalog.get("slots", [])[0].get("preview", {}) \
			if not first_catalog.get("slots", []).is_empty() else {}
		_check(not first_preview.get("legacy", false) and int(first_preview.get("day", -1)) \
			== campaign.day, "Save novo possui prévia leve verificável no catálogo.")
		var loaded := repository.load_campaign(campaign.campaign_id, 1)
		_check(loaded.get("success", false), "Leitura do slot: " +
			str(loaded.get("reason", "")))
		if loaded.get("success", false):
			_check((loaded["campaign"] as CampaignState).current_map
				.get_ppp_block_data(Vector2i(2, 1))
				== campaign.current_map.get_ppp_block_data(Vector2i(2, 1)),
				"Save em disco conserva o mapa sorteado.")
		var slot_one_id := str(saved["slot_id"])
		campaign.active_entity_states[0].current_health -= 2
		var later_health := campaign.active_entity_states[0].current_health
		var semantic_before := repository.capture(campaign, scene)
		var slot_two := repository.save_campaign(campaign, 2, scene)
		var slot_three := repository.save_campaign(campaign, 3, scene)
		_check(slot_two.get("success", false) and slot_three.get("success", false),
			"Três slots manuais devem ser independentes.")
		_check(slot_one_id != str(slot_two.get("slot_id", ""))
			and str(slot_two.get("slot_id", "")) != str(slot_three.get("slot_id", "")),
			"Cada slot recebe ID estável e distinto.")
		_check(not repository.save_campaign(campaign, 4, scene).get("success", false),
			"Quarto slot manual não deve existir.")
		_check(not repository.save_campaign(campaign, 1, scene).get("success", false),
			"Sobrescrita requer confirmação explícita.")
		var slot_one_again := repository.load_campaign(campaign.campaign_id, 1)
		_check(slot_one_again.get("success", false)
			and (slot_one_again["campaign"] as CampaignState)
				.active_entity_states[0].current_health == later_health + 2,
			"Salvar em outro slot não modifica o primeiro.")
		var overwrite := repository.save_campaign(campaign, 2, scene, true)
		_check(overwrite.get("success", false)
			and overwrite.get("slot_id") == slot_two.get("slot_id"),
			"Sobrescrita confirmada preserva ID do slot.")
		if overwrite.get("success", false):
			var corrupted_path := repository._slot_path(campaign.campaign_id, 2)
			var corrupt_file := FileAccess.open(corrupted_path, FileAccess.WRITE)
			corrupt_file.store_string("arquivo de teste corrompido")
			corrupt_file.close()
			var recovered := repository.load_campaign(campaign.campaign_id, 2)
			_check(recovered.get("success", false) and recovered.get("used_backup", false),
				"Backup válido recupera o slot cujo arquivo principal corrompeu.")
			_check(not repository.save_campaign(campaign, 2, scene, true).get("success", false),
				"Sobrescrita não pode apagar o único backup válido de um slot corrompido.")
			var recovered_in_catalog := false
			for entry in repository.list_campaigns():
				if entry["campaign_id"] != campaign.campaign_id:
					continue
				for listed_slot in entry["slots"]:
					recovered_in_catalog = recovered_in_catalog or (listed_slot["slot_number"] == 2
						and listed_slot["valid"] and listed_slot["backup_only"])
			_check(recovered_in_catalog,
				"Catálogo identifica o backup válido como recuperação do slot.")
		var fresh := load("res://teste.tscn").instantiate() as PPPMapView
		root.add_child(fresh)
		await process_frame
		var loaded_scene := repository.load_campaign(campaign.campaign_id, 3, fresh)
		_check(loaded_scene.get("success", false),
			"Carregamento em cena nova: " + str(loaded_scene.get("reason", "")))
		if loaded_scene.get("success", false):
			var fresh_campaign := (fresh.get_node("GerenciaJogo") as GerenciaJogo).campaign
			_check(fresh_campaign.current_map.get_ppp_block_data(Vector2i(2, 1))
				== campaign.current_map.get_ppp_block_data(Vector2i(2, 1))
				and fresh_campaign.active_entity_states[0].current_health == later_health,
				"Cena restaurada contém o mesmo mapa e personagens.")
			_check((fresh.get_node("ExplorationManager") as ExplorationManager)
				.current_actor == fresh_campaign.active_entity_states[0],
				"Turno restaurado aponta para a mesma instância do personagem.")
			var semantic_after := repository.capture(fresh_campaign, fresh)
			_check(semantic_after.get("success", false) and
				JSON.stringify(JSON.parse_string(JSON.stringify(semantic_before.get("graph"))))
				== JSON.stringify(JSON.parse_string(JSON.stringify(semantic_after.get("graph")))),
				"Estado de campanha e controladores deve ser semanticamente igual após carregar.")
			var incompatible_path := repository._slot_path(campaign.campaign_id, 3)
			var incompatible_file := FileAccess.open(incompatible_path, FileAccess.READ)
			var incompatible_envelope: Dictionary = JSON.parse_string(incompatible_file.get_as_text())
			incompatible_file.close()
			incompatible_envelope["format_version"] = 99
			incompatible_file = FileAccess.open(incompatible_path, FileAccess.WRITE)
			incompatible_file.store_string(JSON.stringify(incompatible_envelope))
			incompatible_file.close()
			var refused := repository.load_campaign(campaign.campaign_id, 3, fresh)
			_check(not refused.get("success", false)
				and (fresh.get_node("GerenciaJogo") as GerenciaJogo).campaign
					.active_entity_states[0].current_health == later_health,
				"Formato incompatível é recusado sem alterar campanha ativa.")
		var unsaved := CampaignState.new()
		_check(unsaved.start_new_game(selected), "Novo Jogo de teste deve iniciar.")
		var catalog := repository.list_campaigns()
		var found_saved := false
		var found_unsaved := false
		for entry in catalog:
			found_saved = found_saved or entry["campaign_id"] == campaign.campaign_id
			found_unsaved = found_unsaved or entry["campaign_id"] == unsaved.campaign_id
		_check(found_saved and not found_unsaved,
			"Novo Jogo sem salvar não ocupa o catálogo nem algum slot.")
		var other_saved := repository.save_campaign(unsaved, 1)
		_check(other_saved.get("success", false)
			and other_saved.get("campaign_id") != saved.get("campaign_id"),
			"Outra campanha recebe identidade própria e pode ocupar seu próprio slot 1.")
		var multi_catalog := repository.list_campaigns()
		var found_other := false
		for entry in multi_catalog:
			found_other = found_other or entry["campaign_id"] == unsaved.campaign_id
		_check(found_other, "Catálogo inclui múltiplas campanhas sem teto fixo.")
	print("PPP_SAVE_CODEC_OK" if not failed else "PPP_SAVE_CODEC_FAILED")
	quit(0 if not failed else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
