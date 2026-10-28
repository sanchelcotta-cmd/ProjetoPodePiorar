extends SceneTree

## Auditoria dos invocadores presentes em EntityData e Encontros reais.
## "Uma criatura" significa uma instância, nunca o EncounterData do alvo.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var expected := {
		&"enemy_active_006": {"chance": 0.5, "min": 1, "max": 1, "opening": true},
		&"enemy_active_007": {"chance": 0.5, "min": 1, "max": 1, "opening": true},
		&"enemy_active_008": {"chance": 0.5, "min": 1, "max": 1, "opening": true},
		&"enemy_active_009": {"chance": 0.5, "min": 1, "max": 1, "opening": false},
		&"enemy_active_010": {"chance": 0.5, "min": 1, "max": 1, "opening": false},
		&"enemy_active_011": {"chance": 1.0, "min": 1, "max": 1, "opening": false},
		&"enemy_active_012": {"chance": 0.5, "min": 1, "max": 1, "opening": true},
		&"enemy_active_013": {"chance": 1.0, "min": 2, "max": 2, "opening": false},
	}
	var found: Dictionary = {}
	for filename in DirAccess.get_files_at("res://resources/entities/entities_general"):
		if not filename.ends_with(".tres"):
			continue
		var data := load("res://resources/entities/entities_general".path_join(filename)) as EntityData
		if data == null:
			continue
		for skill in data.skill_ativas:
			if skill == null:
				continue
			for effect in skill.effects:
				if effect == null or effect.effect_type != SkillEffectData.EffectType.SUMMON_ENTITY:
					continue
				found[skill.id] = true
				_check(expected.has(skill.id), "Invocador %s está auditado." % skill.id)
				if not expected.has(skill.id):
					continue
				var rule: Dictionary = expected[skill.id]
				var minimum := effect.minimum_amount if effect.maximum_amount > 0 else effect.amount
				var maximum := effect.maximum_amount if effect.maximum_amount > 0 else effect.amount
				_check(is_equal_approx(skill.activation_chance, rule["chance"])
					and minimum == rule["min"] and maximum == rule["max"],
					"%s respeita chance e número de instâncias da descrição." % skill.id)
				_check((ActiveSkillData.AutomaticTrigger.ON_COMBAT_START in skill.automatic_triggers)
					== rule["opening"],
					"%s dispara no início correto do Combate/turno." % skill.id)
				_check(effect.entity_id != &"" or not effect.entity_ids.is_empty(),
					"%s aponta para EntityData, não EncounterData." % skill.id)
				_check(not effect.summoned_can_summon,
					"%s: convidado não convida sem exceção explícita." % skill.id)
				if skill.id == &"enemy_active_013":
					_check(skill.activate_once_per_encounter,
						"Horda zumbi invoca uma leva compartilhada por Encontro.")
	_check(found.size() == expected.size(),
		"Todos os oito invocadores conectados a entidades foram encontrados.")
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	for path in ["res://resources/encounters/enc_dama_elemental.tres",
			"res://resources/encounters/enc_planta_carnivora.tres",
			"res://resources/encounters/enc_raizes_mutantes.tres"]:
		var scene := load("res://teste.tscn").instantiate() as PPPMapView
		root.add_child(scene)
		await process_frame
		var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
		var combat := scene.get_node("CombatManager") as CombatManager
		var block := scene.get_node("BlockManager") as BlockManager
		var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
		combat.auto_start_turns = false
		_check(gerencia.start_new_game(choices)
			and (scene.get_node("RoundManager") as RoundManager).start_first_map(),
			"Campanha inicia para %s." % path)
		var actor := gerencia.campaign.active_entity_states[0]
		actor.position = Vector2i(3, 2)
		var encounter := load(path) as EncounterData
		gerencia.campaign.current_map.set_ppp_block(actor.position,
			HexGrid.PPPBlockType.ENCOUNTER, encounter)
		_check(block.begin_activation(actor.position, actor),
			"Encontro %s abre." % encounter.id)
		(popup.buttons.get_child(0) as Button).pressed.emit()
		var originals: Dictionary = {}
		var summons: Dictionary = {}
		for enemy in combat.enemies:
			if enemy.summoned_by_instance_id == &"":
				originals[enemy.instance_id] = enemy
			else:
				summons[enemy.summoned_by_instance_id] = int(
					summons.get(enemy.summoned_by_instance_id, 0)) + 1
				_check(enemy.summoned_by_instance_id in originals
					and enemy.data.id != (originals.get(enemy.summoned_by_instance_id) as EntityState).data.id
					and not enemy.summoned_can_summon,
					"%s chama outro tipo, uma geração apenas." % encounter.id)
		for owner_id in summons:
			_check(int(summons[owner_id]) == 1,
				"%s cria exatamente uma entidade por invocador bem-sucedido." % encounter.id)
		_check(combat.enemies.size() <= originals.size() * 2,
			"%s não cria encontro completo por invocação." % encounter.id)
		for enemy in combat.enemies:
			if enemy.summoned_by_instance_id == &"":
				continue
			var before := combat.enemies.size()
			combat._run_automatic_actives(enemy, ActiveSkillData.AutomaticTrigger.ON_COMBAT_START)
			_check(combat.enemies.size() == before,
				"Convidado de %s não chama mais ninguém." % encounter.id)
		scene.queue_free()
		await process_frame
	var zombie_scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(zombie_scene)
	await process_frame
	var zombie_gerencia := zombie_scene.get_node("GerenciaJogo") as GerenciaJogo
	var zombie_combat := zombie_scene.get_node("CombatManager") as CombatManager
	var zombie_block := zombie_scene.get_node("BlockManager") as BlockManager
	var zombie_popup := zombie_scene.get_node("BlockActivationPopup") as BlockActivationPopup
	zombie_combat.auto_start_turns = false
	_check(zombie_gerencia.start_new_game(choices)
		and (zombie_scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Campanha inicia para a horda zumbi.")
	var zombie_actor := zombie_gerencia.campaign.active_entity_states[0]
	zombie_actor.position = Vector2i(3, 2)
	var zombie_encounter := load(
		"res://resources/encounters/enc_zumbis_que_tacam_gosma_centro.tres") as EncounterData
	zombie_gerencia.campaign.current_map.set_ppp_block(zombie_actor.position,
		HexGrid.PPPBlockType.ENCOUNTER, zombie_encounter)
	_check(zombie_block.begin_activation(zombie_actor.position, zombie_actor),
		"Encontro da horda zumbi abre.")
	(zombie_popup.buttons.get_child(0) as Button).pressed.emit()
	var original_zombies := zombie_combat.enemies.duplicate()
	zombie_combat.combat_cycle = 2
	for zombie in original_zombies:
		zombie_combat._combat_turns_by_id[zombie.instance_id] = 2
		zombie_combat._run_automatic_actives(zombie,
			ActiveSkillData.AutomaticTrigger.ON_COMBAT_TURN_START)
	_check(zombie_combat.enemies.size() == original_zombies.size(),
		"A horda não invoca antes do terceiro turno do Encontro.")
	# A habilidade pertence à horda: basta UM zumbi continuar vivo.
	for index in range(1, original_zombies.size()):
		original_zombies[index].current_health = 0
	zombie_combat.combat_cycle = 3
	for zombie in original_zombies:
		zombie_combat._combat_turns_by_id[zombie.instance_id] = 3
		zombie_combat._run_automatic_actives(zombie,
			ActiveSkillData.AutomaticTrigger.ON_COMBAT_TURN_START)
	var dancers := zombie_combat.enemies.size() - original_zombies.size()
	_check(dancers == 2,
		"No terceiro turno, a horda inteira invoca só dois dançarinos no total.")
	_check(zombie_combat._encounter_automatic_skill_uses.has(&"enemy_active_013"),
		"A invocação coletiva fica marcada como usada neste Encontro.")
	zombie_combat.combat_cycle = 4
	for zombie in original_zombies:
		zombie_combat._combat_turns_by_id[zombie.instance_id] = 4
		zombie_combat._run_automatic_actives(zombie,
			ActiveSkillData.AutomaticTrigger.ON_COMBAT_TURN_START)
	_check(zombie_combat.enemies.size() == original_zombies.size() + 2,
		"A horda não invoca outra leva após o terceiro turno.")
	zombie_scene.queue_free()
	await process_frame
	for scenario in [
		{"path": "res://resources/encounters/enc_servos_invocadores_baixo_centro.tres",
			"summoner": &"en_00028", "trigger": ActiveSkillData.AutomaticTrigger.ON_TURN_START},
		{"path": "res://resources/encounters/enc_guarda_fantoche.tres",
			"summoner": &"en_00018", "trigger": ActiveSkillData.AutomaticTrigger.ON_TURN_START},
		{"path": "res://resources/encounters/enc_palhaco_assassino.tres",
			"summoner": &"en_00022", "trigger": ActiveSkillData.AutomaticTrigger.ON_TURN_START},
		{"path": "res://resources/encounters/enc_vilao_tipicamente_do_mal.tres",
			"summoner": &"en_00032", "trigger": ActiveSkillData.AutomaticTrigger.ON_TURN_START},
	]:
		var turn_scene := load("res://teste.tscn").instantiate() as PPPMapView
		root.add_child(turn_scene)
		await process_frame
		var turn_gerencia := turn_scene.get_node("GerenciaJogo") as GerenciaJogo
		var turn_combat := turn_scene.get_node("CombatManager") as CombatManager
		var turn_block := turn_scene.get_node("BlockManager") as BlockManager
		var turn_popup := turn_scene.get_node("BlockActivationPopup") as BlockActivationPopup
		turn_combat.auto_start_turns = false
		_check(turn_gerencia.start_new_game(choices)
			and (turn_scene.get_node("RoundManager") as RoundManager).start_first_map(),
			"Campanha inicia para %s." % scenario["path"])
		var turn_actor := turn_gerencia.campaign.active_entity_states[0]
		turn_actor.position = Vector2i(3, 2)
		var turn_encounter := load(scenario["path"]) as EncounterData
		turn_gerencia.campaign.current_map.set_ppp_block(turn_actor.position,
			HexGrid.PPPBlockType.ENCOUNTER, turn_encounter)
		_check(turn_block.begin_activation(turn_actor.position, turn_actor),
			"Encontro %s abre." % turn_encounter.id)
		(turn_popup.buttons.get_child(0) as Button).pressed.emit()
		var initial := turn_combat.enemies.duplicate()
		for original in initial:
			if original.data.id != scenario["summoner"]:
				continue
			var opening_summons := 0
			for enemy in turn_combat.enemies:
				if enemy.summoned_by_instance_id == original.instance_id:
					opening_summons += 1
			_check(opening_summons <= 1,
				"%s invoca no máximo uma entidade na abertura." % original.data.display_name)
			turn_combat._combat_turns_by_id[original.instance_id] = 3
			var before_turn := turn_combat.enemies.size()
			turn_combat._run_automatic_actives(original, scenario["trigger"])
			var added := turn_combat.enemies.size() - before_turn
			_check(added in [0, 1],
				"%s invoca no máximo uma instância no turno." % original.data.display_name)
			if original.data.id == &"en_00028":
				_check(added == 1, "Servo Invocador chama uma Sombra no turno 3.")
			for enemy in turn_combat.enemies:
				if enemy.summoned_by_instance_id == original.instance_id:
					_check(not enemy.summoned_can_summon,
						"Convidado de %s não invoca de novo." % original.data.display_name)
		turn_scene.queue_free()
		await process_frame
	print("ENEMY_SUMMON_AUDIT_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
