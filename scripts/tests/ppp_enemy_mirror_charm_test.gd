extends SceneTree

## Regressão do Reflexo Maligno e do turno compulsório de Charme.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var combat := scene.get_node("CombatManager") as CombatManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var skills := scene.get_node("SkillManager") as SkillManager
	combat.auto_start_turns = false
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	_check(gerencia.start_new_game(choices)
		and (scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Campanha de teste inicia.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(3, 2)
	var expected_attack := actor.attack
	var expected_health := actor.data.vida_base
	var expected_stamina := actor.max_stamina
	var encounter := load("res://resources/encounters/enc_uma_versao_do_mal.tres") as EncounterData
	gerencia.campaign.current_map.set_ppp_block(actor.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	_check(block.begin_activation(actor.position, actor), "Encontro do sósia abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(combat.enemies.size() == 1, "Há exatamente um sósia.")
	if combat.enemies.is_empty():
		_finish(scene)
		return
	var mirror := combat.enemies[0]
	_check(mirror.attack == expected_attack and mirror.attack > 0,
		"Reflexo copia Ataque real do ativador, não zero provisório.")
	_check(mirror.max_health == expected_health and mirror.current_health == expected_health,
		"Reflexo copia Vida base e nasce com Vida cheia.")
	_check(mirror.max_stamina == expected_stamina,
		"Reflexo copia a Estamina máxima atual.")
	for mastery in [EntityData.Mastery.BLADE, EntityData.Mastery.IMPACT,
			EntityData.Mastery.RANGED]:
		_check(mirror.has_mastery(mastery) == actor.has_mastery(mastery),
			"Reflexo copia presença da Maestria %d." % mastery)
		if actor.has_mastery(mastery):
			_check(mirror.get_mastery_level(mastery) == actor.get_mastery_level(mastery),
				"Reflexo copia nível da Maestria %d." % mastery)
	var dama := load("res://resources/entities/entities_general/dama_elemental.tres") as EntityData
	_check(dama.skill_passivas.any(func(passive: PassiveSkillData) -> bool:
		return passive.id == &"ps_00024" and passive.effects.any(
			func(effect: SkillEffectData) -> bool:
				return effect.debuff_id == &"db_00011")),
		"Dama mantém sua passiva ligada ao Charme.")
	var dama_state := EntityState.from_encounter_member(dama, encounter.id, 2,
		mirror.position)
	var charm_passive: PassiveSkillData = dama.skill_passivas.filter(
		func(passive: PassiveSkillData) -> bool: return passive.id == &"ps_00024")[0]
	var original_chance: float = charm_passive.activation_chance
	charm_passive.activation_chance = 1.0 # Determinístico somente neste teste.
	var triggered := skills.dispatch_passive_trigger(dama_state,
		PassiveSkillData.Trigger.ON_AFTER_ATTACK, gerencia.campaign,
		{"mode": HexGrid.PPPMapMode.COMBAT, "combat_id": combat._combat_id,
		"combat_turn_number": 1, "attack_target": actor, "damage_dealt": 1})
	charm_passive.activation_chance = original_chance
	_check(not triggered.is_empty() and skills.debuff_manager.get_debuff(
		actor, &"db_00011") != null,
		"A passiva real da Dama aplica Charme ao alvo após atacar.")
	skills.debuff_manager.remove_debuff(actor, &"db_00011")
	actor.turn_serial = 1
	combat.current_actor = actor
	actor.turn_state = EntityState.TurnState.TURNING
	var hostile_skill := ActiveSkillData.new()
	hostile_skill.id = &"test_hostile_charm"
	hostile_skill.target_mode = ActiveSkillData.TargetMode.ONE_ENEMY
	var hostile_effect := SkillEffectData.new()
	hostile_effect.effect_type = SkillEffectData.EffectType.PERFORM_ATTACK
	hostile_effect.target = SkillEffectData.Target.SELECTED_TARGET
	hostile_skill.effects.append(hostile_effect)
	var hostile_grant := SkillGrantState.new(hostile_skill, &"test", &"hostile")
	actor.skill_grants.append(hostile_grant)
	var support_skill := ActiveSkillData.new()
	support_skill.id = &"test_support_charm"
	support_skill.target_mode = ActiveSkillData.TargetMode.SELF
	var support_effect := SkillEffectData.new()
	support_effect.effect_type = SkillEffectData.EffectType.REDUCE_INCOMING_DAMAGE
	support_effect.target = SkillEffectData.Target.SELF
	support_effect.percent = 0.5
	support_effect.has_duration = true
	support_effect.duration_unit = SkillEffectData.DurationUnit.COMBAT
	support_skill.effects.append(support_effect)
	var support_grant := SkillGrantState.new(support_skill, &"test", &"support")
	actor.skill_grants.append(support_grant)
	_check(skills.can_use_combat_active(actor, hostile_grant,
		gerencia.campaign, combat, mirror), "Ativa hostil é válida sem Charme.")
	var applied := skills.debuff_manager.apply_by_id(actor, &"db_00011", mirror,
		0, gerencia.campaign.day)
	_check(applied.get("success", false), "Charme é aplicado com fonte concreta.")
	_check(not skills.debuff_manager.can_attack(actor),
		"Charme impede ataque imediatamente, antes do próximo turno.")
	_check(not skills.can_use_combat_active(actor, hostile_grant,
		gerencia.campaign, combat, mirror)
		and skills.can_use_combat_active(actor, support_grant,
		gerencia.campaign, combat),
		"Charme bloqueia ativa hostil, mas preserva apoio sem dano no turno atual.")
	combat._turn_die = 4
	_check(not combat.select_player_action(&"attack")
		and not combat.can_player_attack(mirror.position)
		and not combat._resolve_attack(actor, mirror).get("success", false),
		"HUD, clique e executor direto não permitem ataque encantado.")
	for other in gerencia.campaign.active_entity_states:
		if other != actor:
			other.position = EntityState.UNPLACED
	var origin := actor.position
	var distance_before := HexGrid.distance(origin, mirror.position)
	var move_limit := ceili(float(actor.max_stamina) * 0.5)
	actor.turn_serial += 1
	_check(combat._charm_due_this_turn(actor), "Turno seguinte reconhece a compulsão.")
	_check(not skills.can_use_combat_active(actor, support_grant,
		gerencia.campaign, combat) and not combat.can_roll_player_turn_die()
		and not combat.end_current_turn(),
		"Turno compulsório não permite ativa, dado nem encerramento manual.")
	await combat._run_charmed_turn(actor)
	var moved := HexGrid.distance(origin, actor.position)
	_check(moved <= move_limit and HexGrid.distance(actor.position, mirror.position)
		<= distance_before, "Caminhada automática vai até meia Estamina rumo à fonte.")
	_check(combat.current_actor != actor, "Charme consome e encerra o próximo turno.")
	_check(skills.debuff_manager.get_debuff(actor, &"db_00011") == null,
		"Charme de um turno expira após a caminhada compulsória.")
	_finish(scene)


func _finish(scene: Node) -> void:
	scene.queue_free()
	print("ENEMY_MIRROR_CHARM_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
