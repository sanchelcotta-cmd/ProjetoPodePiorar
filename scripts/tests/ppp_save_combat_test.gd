extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	var created_scenes: Array[PPPMapView] = [scene]
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 10514
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(rng),
		"Campanha de Combate deve iniciar.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(3, 2)
	var encounter := load("res://resources/encounters/enc_barata_voadora.tres") as EncounterData
	gerencia.campaign.current_map.set_ppp_block(actor.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	_check(block.begin_activation(actor.position, actor), "Encontro deve abrir.")
	var repository := CampaignSaveRepository.new("user://ppp_pool4_combat_tests")
	_check(not repository.capture(gerencia.campaign, scene).get("success", false),
		"Diálogo pré-combate não pode virar save sem sua escolha restaurável.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT
		and not combat.enemies.is_empty(), "Combate real deve estar preparado.")
	combat.initiative_order.clear()
	combat.initiative_order.append({"entity": actor})
	for enemy in combat.enemies:
		combat.initiative_order.append({"entity": enemy})
	combat._start_combat_turns()
	_check(combat.current_actor == actor and block.get_phase() == BlockManager.Phase.WAITING_COMBAT,
		"Turno do jogador deve estar aguardando ação em Combate.")
	combat.current_actor = combat.enemies[0]
	_check(not repository.capture(gerencia.campaign, scene).get("success", false),
		"Turno da IA não é limite estável para save durante o Combate.")
	combat.current_actor = actor
	var skills := scene.get_node("SkillManager") as SkillManager
	var health_before := actor.current_health
	var damage := skills.apply_incoming_damage(actor, 3, gerencia.campaign)
	actor.current_health = health_before
	_check(combat._loot_damage_taken == int(damage.get("damage", 0))
		and combat._loot_entry_max_health > 0,
		"Dano do combate persiste no acumulador mesmo após cura.")
	var before := repository.capture(gerencia.campaign, scene)
	_check(before.get("success", false), "Combate deve ser capturável entre ações: "
		+ str(before.get("reason", "")))
	var saved := repository.save_campaign(gerencia.campaign, 1, scene)
	_check(saved.get("success", false), "Combate deve salvar: "
		+ str(saved.get("reason", "")))
	if saved.get("success", false):
		var fresh := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
		root.add_child(fresh)
		created_scenes.append(fresh)
		await process_frame
		var loaded := repository.load_campaign(gerencia.campaign.campaign_id, 1, fresh)
		_check(loaded.get("success", false), "Combate deve carregar: "
			+ str(loaded.get("reason", "")))
		if loaded.get("success", false):
			var restored_game := fresh.get_node("GerenciaJogo") as GerenciaJogo
			var restored_combat := fresh.get_node("CombatManager") as CombatManager
			var restored_journal := fresh.get_node("CampaignJournalRecorder") as CampaignJournalRecorder
			var restored_block := fresh.get_node("BlockManager") as BlockManager
			_check(restored_game.campaign.current_map.ppp_map_mode
				== HexGrid.PPPMapMode.COMBAT and restored_combat.enemies.size()
				== combat.enemies.size() and restored_combat.current_actor
				== restored_game.campaign.active_entity_states[0],
				"Mapa, inimigos e personagem da vez são os mesmos.")
			_check(restored_block.get_phase() == BlockManager.Phase.WAITING_COMBAT
				and restored_combat._rng.state == combat._rng.state,
				"Bloco pendente e sequência aleatória de Combate continuam.")
			_check(restored_combat._loot_damage_taken == combat._loot_damage_taken
				and restored_combat._loot_entry_max_health == combat._loot_entry_max_health
				and restored_combat._loot_participant_ids == combat._loot_participant_ids,
				"Roster, limiar e dano acumulado atravessam o save de Combate.")
			_check(fresh.selection_validator.get_object() == restored_combat,
				"Cliques após carregar continuam usando as regras de Combate.")
			_check(restored_journal._last_encounter_name == encounter.display_name,
				"Nome do Encontro atravessa o save para o registro do desfecho.")
			var after := repository.capture(restored_game.campaign, fresh)
			var before_text := JSON.stringify(JSON.parse_string(JSON.stringify(before.get("graph"))))
			var after_text := JSON.stringify(JSON.parse_string(JSON.stringify(after.get("graph"))))
			if before_text != after_text:
				var difference := 0
				while difference < mini(before_text.length(), after_text.length()) \
						and before_text[difference] == after_text[difference]:
					difference += 1
				print("COMBAT_DIFF ", difference, " ",
					before_text.substr(difference, 160), " <> ",
					after_text.substr(difference, 160))
			_check(after.get("success", false) and before_text == after_text,
				"Estado de Combate deve ter igualdade semântica após carregar.")
			var old_format_scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
			root.add_child(old_format_scene)
			created_scenes.append(old_format_scene)
			await process_frame
			var old_graph: Dictionary = before["graph"].duplicate(true)
			var codec := CampaignSaveCodec.new()
			var old_decoded := codec.decode(old_graph) as Dictionary
			if old_decoded != null:
				var old_runtime: Dictionary = old_decoded["runtime"]
				for field in CampaignSaveRepository.OPTIONAL_RUNTIME_FIELDS["CombatManager"]:
					(old_runtime["CombatManager"] as Dictionary).erase(field)
				var compatible := repository.apply_to_scene(old_format_scene, old_decoded)
				_check(compatible.get("success", false)
					and (old_format_scene.get_node("CombatManager") as CombatManager)
						._loot_entry_max_health > 0,
					"Save anterior à leva 0.5 continua carregável no Combate.")
		gerencia.save_repository = repository
		var automatic := scene.get_node("CampaignAutosaveController")
		automatic.enabled = true
		await process_frame
		combat._attack_animation_pending = true
		var waiting := gerencia.save_manual_slot(2)
		_check(waiting.get("queued", false) and not FileAccess.file_exists(
			repository._slot_path(gerencia.campaign.campaign_id, 2)),
			"Salvar no meio de ataque aguarda seu fim sem perder o pedido.")
		combat._attack_animation_pending = false
		await process_frame
		_check(FileAccess.file_exists(repository._slot_path(
			gerencia.campaign.campaign_id, 2)),
			"Combate grava no slot escolhido após o ataque terminar.")
	for game_scene in created_scenes:
		game_scene.queue_free()
	await process_frame
	await process_frame
	# Deixar a coroutine soltar suas referências locais antes de encerrar o motor.
	call_deferred("_finish")


func _finish() -> void:
	print("PPP_SAVE_COMBAT_OK" if failures == 0 else "PPP_SAVE_COMBAT_FAILED")
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
