extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var sfx := scene.get_node("GameActionSFX") as GameActionSFX
	var combat := scene.get_node("CombatManager") as CombatManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"O teste abre campanha e mapa reais.")
	await process_frame
	_check(sfx._sheet != null and AudioServer.get_bus_index(&"GeneralSFX") >= 0
		and AudioServer.get_bus_index(&"CombatSFX") >= 0
		and AudioServer.get_bus_send(AudioServer.get_bus_index(&"CombatSFX")) == &"EffectsUI",
		"SFX importado passa pelo volume de Efeitos, independente de Música.")
	var combat_bus := AudioServer.get_bus_index(&"CombatSFX")
	var master_bus := AudioServer.get_bus_index(&"Master")
	_check(_has_peak_limiter(combat_bus) and _has_peak_limiter(master_bus),
		"Ataques amplificados e soma com a rádio têm proteção contra picos.")
	_catalog_coverage()
	var actor := gerencia.campaign.active_entity_states[0] as EntityState
	var grid := gerencia.campaign.current_map
	var destination := Vector2i(0, actor.position.y)
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	grid.set_ppp_block(destination, HexGrid.PPPBlockType.INFORMATION, information)
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	_check(exploration.try_move(destination), "O jogável realiza movimento real de Exploração.")
	await process_frame
	_check(sfx._movement_voices.has(actor.get_instance_id())
		and (sfx._movement_voices[actor.get_instance_id()]["player"] as AudioStreamPlayer).bus \
			== &"GeneralSFX"
		and (sfx._movement_voices[actor.get_instance_id()]["player"] as AudioStreamPlayer).playing,
		"Movimento concluído toca no sub-bus de efeitos gerais.")
	await create_timer(0.45).timeout
	_check(not sfx._movement_voices.has(actor.get_instance_id()),
		"Loop de passos cessa ao terminar o deslocamento.")
	var dog_data := load(
		"res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	var dog := EntityState.from_encounter_member(dog_data, &"sfx_dog", 1,
		EntityState.UNPLACED)
	_check(gerencia.campaign.register_companion(actor, dog),
		"Doguinho entra como companheiro da campanha.")
	var companions := scene.get_node(
		"MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	var dog_visual := companions.visuals_by_id.get(dog.instance_id) as CompanionActorVisual
	_check(dog_visual != null, "Doguinho tem visual real no mapa.")
	if dog_visual != null:
		dog_visual._walk_to(dog_visual.position + Vector2(90, 0), false)
		await process_frame
		await process_frame
		_check(sfx._movement_voices.has(dog.get_instance_id())
			and sfx._movement_voices[dog.get_instance_id()]["spec"]["id"] == &"knife_slice",
			"Companheiro andando só visualmente também recebe SFX não humanoide.")
		dog_visual._stop_motion()
		_check(not sfx._movement_voices.has(dog.get_instance_id()),
			"Cancelar animação visual interrompe o loop do companheiro.")
	var enemy_data := load("res://resources/entities/entities_general/zumbi_dancarino.tres") as EntityData
	var enemy := EntityState.from_encounter_member(enemy_data, &"sfx_enemy", 1,
		Vector2i(3, 2))
	enemy.max_health = 999
	enemy.current_health = 999
	actor.position = Vector2i(2, 2)
	combat.enemies.append(enemy)
	grid.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	combat.current_actor = actor
	combat._combat_id = &"sfx_test"
	combat._turn_die = 4
	sfx._sync_entities()
	await process_frame
	await process_frame
	actor.equipped_weapons.clear()
	var combat_capture := AudioEffectCapture.new()
	combat_capture.buffer_length = 1.0
	AudioServer.add_bus_effect(combat_bus, combat_capture)
	var before := sfx._attack_voices.size()
	_check(combat._resolve_attack(actor, enemy).get("success", false),
		"Ataque de Combate é efetivamente resolvido.")
	_check(sfx._attack_voices.size() == before + 1
		and (sfx._attack_voices[-1]["player"] as AudioStreamPlayer).bus == &"CombatSFX"
		and ActionSFXCatalog.attack(actor, sfx._attack_serial)["id"] \
			in [&"punch", &"quick_swoosh"]
		and is_equal_approx(
			(sfx._attack_voices[-1]["player"] as AudioStreamPlayer).volume_linear,
			float(ActionSFXCatalog.attack(actor, sfx._attack_serial)["gain"])
				* GameActionSFX.ATTACK_GAIN_MULTIPLIER),
		"Ataque real cria uma voz no sub-bus de combate com ganho de 1,5x.")
	await process_frame
	_check(not sfx._attack_voices.is_empty()
		and (sfx._attack_voices[-1]["player"] as AudioStreamPlayer).playing,
		"Voz do golpe continua tocando após um frame, não morre antes do transiente.")
	await create_timer(0.28).timeout
	var attack_peak := 0.0
	for sample in combat_capture.get_buffer(combat_capture.get_frames_available()):
		attack_peak = maxf(attack_peak, maxf(absf(sample.x), absf(sample.y)))
	_check(attack_peak > 0.2 and attack_peak <= db_to_linear(-0.3) + 0.01,
		"Golpe amplificado chega audível à saída sem ultrapassar o teto do limitador.")
	before = sfx._attack_voices.size()
	combat.action_resolved.emit(actor, &"ricochet", {"target": enemy, "damage": 2})
	_check(sfx._attack_voices.size() == before + 1,
		"Ricochete resolvido recebe outro corte para o alvo secundário.")
	before = sfx._attack_voices.size()
	(scene.get_node("SkillManager") as SkillManager).active_skill_used.emit(actor, null,
		{"effects": [{"missed_reach": true}]})
	_check(sfx._attack_voices.size() == before + 1,
		"Ativa ofensiva gasta sem alcance audível não fica muda.")
	combat._apply_move(enemy, [Vector2i(4, 2)])
	await process_frame
	await process_frame
	_check(sfx._movement_voices.has(enemy.get_instance_id())
		and is_equal_approx(float(sfx._movement_voices[enemy.get_instance_id()]["spec"]["pitch"]), 0.8),
		"Movimento real do zumbi usa passos hostis a 0,8x.")
	var broom := load("res://resources/itens/equipments/armas/cabo_de_vassoura.tres") as ItemData
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(broom))
	before = sfx._attack_voices.size()
	combat.action_resolved.emit(actor, &"attack", {"target": enemy, "damage": 3})
	var broom_voice: AudioStreamPlayer = null
	if sfx._attack_voices.size() > before:
		broom_voice = sfx._attack_voices[-1]["player"] as AudioStreamPlayer
	_check(sfx._attack_voices.size() == before + 1
		and broom_voice != null
		and is_equal_approx(broom_voice.pitch_scale, 0.84)
		and is_equal_approx(broom_voice.volume_linear,
			1.75 * GameActionSFX.ATTACK_GAIN_MULTIPLIER)
		and broom_voice.playing,
		"Golpe real com Cabo de Vassoura toca mais grave e mais alto.")
	for blade_path in ["res://resources/itens/equipments/armas/faca_de_cozinha.tres",
			"res://resources/itens/equipments/armas/tesoura_de_jardinagem.tres"]:
		var blade := load(blade_path) as ItemData
		actor.equipped_weapons.clear()
		actor.equipped_weapons.append(InventoryItemState.new(blade))
		before = sfx._attack_voices.size()
		combat.action_resolved.emit(actor, &"attack", {"target": enemy, "damage": 3})
		var blade_voice := sfx._attack_voices[-1]["player"] as AudioStreamPlayer
		_check(sfx._attack_voices.size() == before + 1
			and ActionSFXCatalog.attack(actor)["id"] == &"quick_blade"
			and blade_voice.playing
			and absf(blade_voice.get_playback_position() - 29.25) < 0.05
			and is_equal_approx(blade_voice.volume_linear,
				1.25 * GameActionSFX.ATTACK_GAIN_MULTIPLIER),
			"Faca/Tesoura disparam o trecho de lâmina com o ganho novo.")
	var boomerang := load(
		"res://resources/itens/equipments/armas/arma_epica_bumerangue_teleguiado.tres") as ItemData
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(boomerang))
	before = sfx._attack_voices.size()
	_check(combat.try_passive_counterattack(actor, enemy).get("counterattack", false)
		and sfx._attack_voices.size() == before + 1,
		"Contra-ataque resolvido emite uma única voz da arma equipada.")
	var dodge_grant := SkillGrantState.new(boomerang.granted_passives[0],
		&"equipment", &"sfx_boomerang")
	dodge_grant.bound_source = boomerang
	before = sfx._attack_voices.size()
	sfx._on_passive_triggered(actor, dodge_grant,
		{"effects": [{"success": true, "dodged": true}]})
	_check(sfx._attack_voices.size() == before + 1
		and ActionSFXCatalog.attack(actor)["id"] == &"gun",
		"Interceptação real do Bumerangue tem Gun além do ataque normal.")
	var fixed := SkillEffectData.new()
	fixed.effect_type = SkillEffectData.EffectType.DEAL_FIXED_DAMAGE
	var passive := PassiveSkillData.new()
	passive.effects.append(fixed)
	var fixed_grant := SkillGrantState.new(passive, &"test", &"fixed")
	before = sfx._attack_voices.size()
	sfx._on_passive_triggered(actor, fixed_grant,
		{"effects": [{"success": true, "targets": [{"target": enemy}]}]})
	_check(sfx._attack_voices.size() == before + 1,
		"Passiva ofensiva com alvo atingido não fica sem SFX.")
	enemy.current_health = 0
	_check(not sfx._movement_voices.has(enemy.get_instance_id()),
		"Morte interrompe imediatamente o loop de movimento.")
	enemy.current_health = 999
	sfx._start_movement(enemy, 8)
	grid.ppp_map_mode = HexGrid.PPPMapMode.EXPLORATION
	await process_frame
	await process_frame
	_check(sfx._movement_voices.is_empty() and sfx._attack_voices.is_empty(),
		"Troca de modo interrompe SFX pendentes e loops.")
	var audio := root.get_node("GameAudio")
	var original_effects := int(audio.call("get_volume", &"effects"))
	var original_music := int(audio.call("get_volume", &"music"))
	audio.call("set_volume", &"music", 100, false)
	audio.call("set_volume", &"effects", 100, false)
	audio.call("set_volume", &"effects", 0, false)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"EffectsUI"))
		and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),
		"Mudo em Efeitos corta ataque/passos, sem cortar Rádio.")
	audio.call("set_volume", &"effects", original_effects, false)
	audio.call("set_volume", &"music", original_music, false)
	AudioServer.remove_bus_effect(combat_bus,
		AudioServer.get_bus_effect_count(combat_bus) - 1)
	combat_capture = null
	await process_frame
	print("PPP_ACTION_SFX_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _catalog_coverage() -> void:
	var folder := "res://resources/entities/entities_general"
	var count := 0
	for filename in DirAccess.get_files_at(folder):
		if not filename.ends_with(".tres"):
			continue
		var data := load(folder.path_join(filename)) as EntityData
		if data == null:
			continue
		count += 1
		var actor := EntityState.from_encounter_member(data, &"sfx_catalog", 1, Vector2i.ZERO)
		_check(ActionSFXCatalog.ENEMY_GROUPS.has(data.id),
			"Inimigo %s possui grupo documentado." % data.display_name)
		for mastery in data.maestrias:
			if mastery == EntityData.Mastery.NONE:
				continue
			_check((ActionSFXCatalog.ENEMY_GROUPS.get(data.id, {}) as Dictionary).has(mastery),
				"%s tem classificação de cada Maestria real." % data.display_name)
		_check(_valid_clip(ActionSFXCatalog.attack(actor))
			and _valid_clip(ActionSFXCatalog.movement(actor)),
			"Inimigo %s nunca fica sem ataque ou movimento." % data.display_name)
	_check(count >= 30, "Catálogo cobre todos os inimigos gerais atuais.")
	var playable := load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData
	var user := EntityState.from_playable_selection(playable, &"sfx_playable", Vector2i.ZERO)
	for filename in DirAccess.get_files_at("res://resources/itens/equipments/armas"):
		if not filename.ends_with(".tres"):
			continue
		var item := load("res://resources/itens/equipments/armas".path_join(filename)) as ItemData
		if item == null:
			continue
		user.equipped_weapons.clear()
		user.equipped_weapons.append(InventoryItemState.new(item))
		_check(_valid_clip(ActionSFXCatalog.attack(user)),
			"Arma %s sempre produz SFX." % item.display_name)
		_check(ActionSFXCatalog.ITEM_ATTACKS.has(item.id),
			"Arma atual %s possui decisão específica registrada." % item.display_name)
		if item.id == &"aa_00008":
			var broom_sound := ActionSFXCatalog.attack(user)
			_check(broom_sound["id"] == &"awesome_kick"
				and is_equal_approx(float(broom_sound["pitch"]), 0.84)
				and is_equal_approx(float(broom_sound["gain"]), 1.75),
				"Cabo de Vassoura fica mais grave e forte sem mudar o Martelo comum.")
	user.equipped_weapons.clear()
	var future_item := ItemData.new()
	future_item.id = &"future_ranged"
	future_item.mastery_granted = EntityData.Mastery.RANGED
	user.equipped_weapons.append(InventoryItemState.new(future_item))
	_check(ActionSFXCatalog.attack(user)["id"] == &"awwow_impact",
		"Arma futura cai no fallback de Maestria Distância.")
	user.equipped_weapons.clear()
	_check(_valid_clip(ActionSFXCatalog.attack(user))
		and ActionSFXCatalog.attack(user, 0)["id"] != ActionSFXCatalog.attack(user, 1)["id"],
		"Desarmado alterna dois punches sem silêncio.")
	var rat := load("res://resources/entities/entities_general/rato_mutante_do_baixo_centro.tres") as EntityData
	var rat_actor := EntityState.from_encounter_member(rat, &"rat", 1, Vector2i.ZERO)
	_check(ActionSFXCatalog.movement(rat_actor)["id"] == &"electric_zap",
		"Rato recebe o zap de movimento explicitamente.")
	var fly := load("res://resources/entities/entities_general/barata_voadora.tres") as EntityData
	var fly_actor := EntityState.from_encounter_member(fly, &"fly", 1, Vector2i.ZERO)
	_check(ActionSFXCatalog.movement(fly_actor)["id"] == &"wing"
		and is_equal_approx(float(ActionSFXCatalog.movement(fly_actor)["pitch"]), 1.2),
		"Barata voadora usa Wing a 1,2x.")
	var dog := load("res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	var dog_actor := EntityState.from_encounter_member(dog, &"dog", 1, Vector2i.ZERO)
	_check(ActionSFXCatalog.attack(dog_actor)["id"] == &"sword_schwing"
		and ActionSFXCatalog.movement(dog_actor)["id"] == &"knife_slice",
		"Doguinho ataca com lâmina média e se desloca como criatura.")
	var cat := load("res://resources/entities/entities_general/companions/gatinho_vira_lata.tres") as EntityData
	var cat_actor := EntityState.from_encounter_member(cat, &"cat", 1, Vector2i.ZERO)
	_check(ActionSFXCatalog.attack(cat_actor)["id"] == &"quick_blade"
		and float(ActionSFXCatalog.attack(cat_actor)["pitch"]) > 1.2,
		"Gatinho ataca com lâmina aguda, não com punch.")
	_check(float(ActionSFXCatalog.attack(user, 0)["gain"]) >= 1.0
		and float(ActionSFXCatalog.movement(user)["gain"]) >= 1.0,
		"Soco desarmado e passos não recebem atenuação local sob a rádio.")
	var protection := load(
		"res://resources/itens/equipments/armaduras/armadura_epica_armadura_de_protecao.tres") as ItemData
	user.equipped_armors.append(InventoryItemState.new(protection))
	_check(ActionSFXCatalog.movement(user)["id"] == &"steps_armored"
		and is_equal_approx(float(ActionSFXCatalog.movement(user)["pitch"]), 0.90),
		"Armadura de Proteção usa seu próprio trecho de passos, mais grave.")
	var black_suit := load("res://resources/entities/entities_general/homem_de_preto.tres") as EntityData
	var black_actor := EntityState.from_encounter_member(black_suit, &"black_suit", 1,
		Vector2i.ZERO)
	black_actor.encounter_mastery_override = EntityData.Mastery.RANGED
	_check(ActionSFXCatalog.attack(black_actor)["id"] == &"gun",
		"Homem de Preto com Maestria Distância usa grupo B/Gun.")
	black_actor.encounter_mastery_override = EntityData.Mastery.BLADE
	_check(ActionSFXCatalog.attack(black_actor)["id"] == &"sword_schwing",
		"Maestria sorteada do Homem de Preto prevalece sobre a ordem do Resource.")
	_check(ActionSFXCatalog.clip(&"desconhecido")["id"] == &"punch",
		"ID inesperado ainda possui fallback seguro.")


func _valid_clip(spec: Dictionary) -> bool:
	return ActionSFXCatalog.CLIPS.has(spec.get("id", &"")) \
		and float(spec.get("end", 0.0)) > float(spec.get("start", 0.0)) \
		and float(spec.get("pitch", 0.0)) > 0.0 \
		and float(spec.get("gain", 0.0)) >= 1.0


func _has_peak_limiter(bus_index: int) -> bool:
	if bus_index < 0:
		return false
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		if AudioServer.get_bus_effect(bus_index, effect_index) is AudioEffectHardLimiter:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
