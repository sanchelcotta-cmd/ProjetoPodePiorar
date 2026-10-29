extends SceneTree

## Playtest automatizado de uma politica fixa de jogador comum. O controlador
## escolhe destinos SOMENTE entre os hexes que a UI ja permite selecionar;
## jamais consulta o conteudo de blocos ocultos antes da ativacao.

const SEED := 261022
const MAX_STEPS := 10000
const ALLOW_FORCED_MAP_SKIP := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for use_loot in [false, true]:
		await _play_campaign(use_loot)
	quit()


func _play_campaign(use_loot: bool) -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	# A HUD visual nao participa das escolhas do bot; remove-la evita que
	# hover/ficha visual influenciem um teste headless de regras e combate.
	var hud := scene.get_node_or_null("PartyStatusHUD")
	if hud != null:
		scene.remove_child(hud)
		hud.free()
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var explore := scene.get_node("ExplorationManager") as ExplorationManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup")
	var skills := scene.get_node("SkillManager") as SkillManager
	var player_skills := scene.get_node("PlayerSkillManager") as PlayerSkillManager
	var event_executor := scene.get_node("EventExecutor")
	var autosave := scene.get_node_or_null("CampaignAutosaveController")
	if autosave != null:
		autosave.set("enabled", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	var endings: Array[StringName] = [&"khainokata", &"orchestra"]
	var started := game.campaign.start_new_game(selected, 12, rng,
		EventCampaignEligibility.Mode.MEDIUM, endings)
	game.campaign.world_rng.seed = SEED + 1
	combat._rng.seed = SEED + 2
	event_executor._rng.seed = SEED + 3
	started = started and rounds.start_first_map(rng)
	var label := "COM_SAQUE" if use_loot else "SEM_SAQUE"
	if not started:
		print("PLAYTEST %s: FALHA AO INICIAR" % label)
		scene.queue_free()
		await process_frame
		return
	var turns := 0
	var fights := 0
	var wins := 0
	var loot_offered := 0
	var loot_kept := 0
	var consumed := 0
	var forced_map_skips := 0
	var encountered: Dictionary = {}
	var last_combat_id := ""
	var last_loot_combat_id := ""
	var previous_info := 0
	var stagnant := 0
	var last_state := ""
	var stop_reason := "limite de passos"
	for step in MAX_STEPS:
		await process_frame
		if game.campaign.is_terminal():
			stop_reason = "vitoria" if game.campaign.campaign_status \
				== CampaignState.CampaignStatus.VICTORY else "derrota"
			break
		var information_count := game.campaign.obtained_information_ids.size()
		if information_count != previous_info:
			print("PLAYTEST %s INFO %d/10 DIA %d RODADA %d DISTRITO %s" % [
				label, information_count, game.campaign.day,
				game.campaign.get_round_index(), str(game.campaign.district)])
			previous_info = information_count
		var state := "%d|%d|%d|%d|%s|%s|%s" % [
			information_count, game.campaign.generated_map_count,
			block.get_phase(), combat.combat_cycle,
			str(combat.current_actor.instance_id) if combat.current_actor != null else "-",
			str(popup.overlay.visible), str(popup.feedback_label.text)]
		stagnant = stagnant + 1 if state == last_state else 0
		last_state = state
		if stagnant > 120:
			stop_reason = "travamento em %s" % state
			var button_names: Array[String] = []
			for child in popup.buttons.get_children():
				if child is Button:
					button_names.append((child as Button).text)
			print("PLAYTEST %s BLOQUEIO: titulo=%s botoes=%s picker=%s evento=%s" % [
				label, popup.title_label.text, str(button_names),
				str(popup._catalog_picker.visible),
				str(block.get_pending_context().get("resource"))])
			if combat.current_actor != null:
				print("PLAYTEST %s ATOR TRAVADO: %s controlador=%s vivo=%s pos=%s jogador=%s dado=%s animacao=%s trap=%s pausado=%s escala=%s" % [
					label, combat.current_actor.visible_name(),
					str(combat.current_actor.controller),
					str(combat.current_actor.current_health),
					str(combat.current_actor.position),
					str(combat.is_player_turn()), str(combat._turn_die),
					str(combat._attack_animation_pending), str(combat._pending_trap),
					str(paused), str(Engine.time_scale)])
			break
		if combat.current_encounter != null and last_combat_id != str(combat._combat_id):
			last_combat_id = str(combat._combat_id)
			fights += 1
			var encounter_name := combat.current_encounter.display_name
			encountered[encounter_name] = int(encountered.get(encounter_name, 0)) + 1
			print("PLAYTEST %s COMBATE %d: %s" % [label, fights, encounter_name])
			if fights >= 8:
				stop_reason = "marco comparativo: inicio do 8o combate"
				break
		if popup._combat_conclusion_open and combat._combat_id != &"" \
				and last_loot_combat_id != str(combat._combat_id):
			last_loot_combat_id = str(combat._combat_id)
			loot_offered += combat._loot_items.size()
			var loot_names: Array[String] = []
			for reward in combat._loot_items:
				if reward is ItemData:
					loot_names.append((reward as ItemData).display_name)
			print("PLAYTEST %s SAQUE: %s" % [label, str(loot_names)])
		if popup._catalog_picker.visible:
			if popup._catalog_picker._choice_panel.visible:
				popup._catalog_picker._confirm()
			elif popup._catalog_picker._grid.get_child_count() > 0:
				(popup._catalog_picker._grid.get_child(0) as Button).pressed.emit()
			else:
				stop_reason = "catalogo aberto sem itens elegiveis"
				break
			continue
		if popup.overlay.visible and popup.buttons.get_child_count() > 0:
			var clicked := _choose_popup_button(popup, combat, skills, use_loot)
			if clicked == "loot_claim":
				loot_kept += 1
			elif clicked == "combat_end":
				wins += 1
			if clicked != "":
				await create_timer(0.025).timeout
				continue
		if player_skills.has_pending_choice():
			player_skills.answer_pre_activation_choice()
			continue
		if combat.current_encounter != null:
			if not combat.pending_conclusion.is_empty():
				await create_timer(0.06).timeout
				continue
			if combat.is_player_turn():
				if combat._attack_animation_pending:
					await create_timer(0.30).timeout
					continue
				var actor := combat.current_actor
				if _try_heal(actor, game.campaign, skills, combat):
					consumed += 1
					continue
				if combat.can_roll_player_turn_die():
					combat.roll_player_turn_die()
					turns += 1
					continue
				var enemies := combat.enemies.duplicate()
				enemies.sort_custom(func(a: EntityState, b: EntityState) -> bool:
					return a.current_health < b.current_health)
				var acted := false
				for enemy in enemies:
					if enemy.current_health > 0 and combat.can_player_attack(enemy.position):
						acted = combat.player_attack(enemy.position)
						break
				if acted:
					await create_timer(0.04).timeout
					continue
				var destination := _nearest_combat_move(combat, actor, enemies,
					game.campaign.current_map)
				if destination != EntityState.UNPLACED and combat.player_move(destination):
					await create_timer(0.30).timeout
					continue
				combat.end_current_turn()
				continue
			await create_timer(0.12).timeout
			continue
		if block.is_busy():
			await create_timer(0.05).timeout
			continue
		if rounds.can_advance():
			var district := _choose_district(rounds, game.campaign.get_round_index())
			if not rounds.advance_to_district(district, rng):
				stop_reason = "falha ao avancar distrito"
				break
			continue
		if ALLOW_FORCED_MAP_SKIP and explore.cycle_number >= 4 \
				and not game.campaign.information_allows_round_advance():
			if _force_advance_without_information(game, rounds, explore, skills, rng):
				forced_map_skips += 1
				print("PLAYTEST %s MAPA_PULADO sem Informacao: total=%d" % [
					label, forced_map_skips])
				continue
		if explore.current_actor == null:
			explore.select_next_available_actor()
			continue
		var current := explore.current_actor
		if _try_heal(current, game.campaign, skills, null):
			consumed += 1
			continue
		var destinations := explore.get_available_destinations()
		var chosen := _choose_visible_destination(current.position, destinations)
		if chosen != EntityState.UNPLACED:
			if not explore.try_move(chosen):
				stop_reason = "movimento anunciado recusado"
				break
			continue
		explore.pass_turn()
	var alive := []
	for actor in game.campaign.active_entity_states:
		alive.append("%s:%d/%d" % [actor.visible_name(), actor.current_health,
			actor.max_health])
	print(("PLAYTEST %s FINAL: %s; info=%d/10; mapas=%d; dia=%d; rodadas=%d; "
		+ "combates=%d; vitorias=%d; saques_oferecidos=%d; saques_guardados=%d; "
		+ "consumiveis=%d; turnos_combate=%d; pulos_mapa=%d; vivos=%s; encontros=%s") % [
		label, stop_reason, game.campaign.obtained_information_ids.size(),
		game.campaign.generated_map_count, game.campaign.day,
		game.campaign.get_round_index(), fights, wins, loot_offered, loot_kept,
		consumed, turns, forced_map_skips, str(alive), str(encountered)])
	scene.queue_free()
	await process_frame


func _choose_popup_button(popup: Node, combat: CombatManager,
		skills: SkillManager, use_loot: bool) -> String:
	var candidates: Array[Button] = []
	_collect_buttons(popup.buttons, candidates)
	if candidates.is_empty():
		return ""
	var chosen: Button
	var result := "popup"
	if popup._combat_conclusion_open:
		var pending := combat.get_pending_loot_item()
		if not pending.is_empty():
			result = "loot_offer"
			if use_loot:
				for button in candidates:
					if button.text.begins_with("GUARDAR:"):
						chosen = button
						result = "loot_claim"
						break
			if chosen == null:
				for button in candidates:
					if button.text in ["RECUSAR ITEM", "SIM, RECUSAR"]:
						chosen = button
						break
		else:
			result = "combat_end"
	for button in candidates:
		if chosen != null:
			break
		if button.text in ["ACEITAR", "CONCORDAR", "OK", "PROSSEGUIR",
				"JOGAR DADO", "CONFIRMAR E PROSSEGUIR", "CRIAR ÉPICO"]:
			chosen = button
	if chosen == null:
		chosen = candidates[0]
	chosen.pressed.emit()
	return result


func _collect_buttons(container: Node, result: Array[Button]) -> void:
	for child in container.get_children():
		if child is Button and not child.disabled and child.visible:
			result.append(child as Button)
		elif child.get_child_count() > 0:
			_collect_buttons(child, result)


func _try_heal(actor: EntityState, campaign: CampaignState,
		skills: SkillManager, combat: CombatManager) -> bool:
	if actor == null or actor.current_health <= 0 \
			or actor.current_health >= actor.max_health * 0.50:
		return false
	for entry in actor.inventory_items.duplicate():
		if entry == null or entry.data == null or entry.data.item_type \
				!= ItemData.ItemType.CONSUMABLE:
			continue
		var heals := false
		for effect in entry.data.use_effects:
			if effect != null and effect.effect_type == SkillEffectData.EffectType.HEAL_FIXED:
				heals = true
		if heals and skills.inventory_manager.use_consumable(actor, entry,
				skills, campaign, null, null, combat).get("success", false):
			return true
	return false


func _nearest_combat_move(combat: CombatManager, actor: EntityState,
		enemies: Array, grid: HexGrid) -> Vector2i:
	var chosen := EntityState.UNPLACED
	var best := 99999
	for coord in grid.cells:
		if not combat.can_player_move(coord):
			continue
		var distance := 999
		for enemy in enemies:
			if enemy.current_health > 0:
				distance = mini(distance, HexGrid.distance(coord, enemy.position))
		var score: int = distance * 100 + HexGrid.distance(actor.position, coord)
		if score < best:
			best = score
			chosen = coord
	return chosen


func _choose_visible_destination(origin: Vector2i,
		destinations: Dictionary) -> Vector2i:
	var chosen := EntityState.UNPLACED
	var best := 99999
	for coord in destinations:
		var distance := int(destinations[coord])
		var score: int = distance * 1000 + HexGrid.distance(origin, coord) * 10 \
			+ coord.y * 2 + coord.x
		if score < best:
			best = score
			chosen = coord
	return chosen


func _choose_district(rounds: RoundManager, round_index: int) -> StringName:
	var wanted := &"suburbio" if round_index < 3 else \
		&"baixo_centro" if round_index < 7 else &"centro"
	return wanted if wanted in rounds.available_districts() \
		else rounds.available_districts()[-1]


func _force_advance_without_information(game: GerenciaJogo,
		rounds: RoundManager, explore: ExplorationManager,
		skills: SkillManager, rng: RandomNumberGenerator) -> bool:
	# Excecao somente do playtest, pedida pelo usuario. Nao concede Informacao.
	var campaign := game.campaign
	var district := _choose_district(rounds, campaign.get_round_index())
	var next_day := campaign.day
	var next_period := campaign.round_period + 1
	if next_period > PPPMapGenerator.RoundPeriod.NIGHT:
		next_period = PPPMapGenerator.RoundPeriod.MORNING
		next_day += 1
	var next_index := (next_day - 1) * 3 + next_period
	var new_map := game.prepare_map(game.get_information_catalog(), district,
		next_period, next_index, rng)
	if new_map == null:
		return false
	var new_day := next_day != campaign.day
	campaign.day = next_day
	campaign.round_period = next_period
	campaign.district = district
	campaign.expire_temporary_events_for_clock()
	if not game.install_map(new_map):
		return false
	if new_day:
		skills.on_day_started(campaign, rng)
	skills.on_round_started(campaign, rng)
	return explore.enter_map(true)
