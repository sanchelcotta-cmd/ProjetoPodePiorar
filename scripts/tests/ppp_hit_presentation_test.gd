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
	var party := scene.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/professora.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"A campanha real inicia para testar a apresentação do golpe.")
	await process_frame
	_check(sfx._hurt_sheet != null and sfx.playable_view == party,
		"Folha de gritos e sinais dos sprites estão ligados.")
	var stream := sfx._hurt_sheet as AudioStreamWAV
	_check(stream != null and stream.get_length() >= 39.0,
		"O áudio convertido contém todos os trechos mapeados.")
	for folder in ["res://resources/entities/entities_playable",
			"res://resources/entities/entities_general",
			"res://resources/entities/entities_general/companions"]:
		for filename in DirAccess.get_files_at(folder):
			if not filename.ends_with(".tres"):
				continue
			var data := load(folder.path_join(filename)) as EntityData
			_check(data != null and HurtSFXCatalog.SEGMENTS.has(data.id),
				"Trecho de grito cadastrado para %s." % filename)
	var actor := gerencia.campaign.active_entity_states[0] as EntityState
	actor.position = Vector2i(2, 2)
	var visual := party.visuals_by_slot.get(actor.playable_slot_id) as PlayableActorVisual
	var zombie := load("res://resources/entities/entities_general/zumbi_dancarino.tres") \
		as EntityData
	var target := EntityState.from_encounter_member(zombie, &"presentation_target", 1,
		Vector2i(3, 2))
	target.max_health = 100
	target.current_health = 100
	combat.enemies.append(target)
	combat._draw_enemy(target)
	var target_visual := combat._visual_for_actor(target)
	gerencia.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	await process_frame
	combat.hit_prepared.emit(target)
	combat.action_resolved.emit(actor, &"attack", {"target": target,
		"damage": 0, "dodged": true, "ranged": false})
	_check(not target_visual._combat_hit_held and sfx._hurt_voices.is_empty(),
		"Esquiva não deixa reação pendente nem toca grito.")
	sfx._stop_all()
	combat.hit_prepared.emit(target)
	target.current_health -= 2
	combat.action_resolved.emit(actor, &"attack", {"target": target,
		"damage": 2, "ranged": false})
	_check(target_visual._combat_hit_held and not target_visual._dying
		and sfx._hurt_voices.is_empty(),
		"Dano lógico não antecipa reação nem grito do corpo a corpo.")
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	_check(not target_visual._combat_hit_held
		and bool(sfx._pending_hits[target.get_instance_id()]["presented"])
		and sfx._hurt_voices.is_empty(),
		"Quadro 3 mostra a reação, mas ainda espera terminar o som do golpe.")
	await create_timer(0.70).timeout
	_check(not sfx._hurt_voices.is_empty(),
		"O grito corpo a corpo começa após o corte de ataque acabar.")
	sfx._stop_all()
	target_visual.bind_state(target)
	var bow := load("res://resources/itens/equipments/armas/arma_epica_arco_da_precisao.tres") \
		as ItemData
	_check(bow != null, "Arco da Precisão disponível para o teste à distância.")
	if bow != null:
		actor.equipped_weapons.clear()
		actor.equipped_weapons.append(InventoryItemState.new(bow))
		combat.hit_prepared.emit(target)
		target.current_health -= 2
		combat.action_resolved.emit(actor, &"attack", {"target": target,
			"damage": 2, "ranged": true})
		visual.animated_sprite.set_frame_and_progress(2, 0.0)
		_check(target_visual._combat_hit_held and sfx._hurt_voices.is_empty(),
			"Quadro 3 de Distância não finge que o projétil já atingiu.")
		visual.animated_sprite.set_frame_and_progress(3, 0.0)
		await create_timer(0.20).timeout
		_check(target_visual._combat_hit_held and sfx._hurt_voices.is_empty(),
			"Durante o voo, alvo ainda não reage nem grita.")
		await create_timer(0.22).timeout
		_check(not target_visual._combat_hit_held and not sfx._hurt_voices.is_empty(),
			"Chegada real do projétil dispara reação e grito juntos.")
	sfx._stop_all()
	combat.hit_prepared.emit(actor)
	actor.current_health -= 2
	combat.action_resolved.emit(target, &"attack", {"target": actor,
		"damage": 2, "ranged": false})
	_check(visual._combat_hit_held and visual.animated_sprite.animation != &"hurt",
		"Ataque inimigo não antecipa reação do jogável.")
	await create_timer(0.15).timeout
	_check(not visual._combat_hit_held and visual.animated_sprite.animation == &"hurt",
		"Terceira pose da silhueta inimiga inicia a animação de dano.")
	sfx._stop_all()
	visual.play_idle()
	combat.hit_prepared.emit(actor)
	actor.current_health -= 2
	combat.action_resolved.emit(target, &"attack", {"target": actor,
		"damage": 2, "ranged": true})
	await create_timer(0.25).timeout
	_check(visual._combat_hit_held and sfx._hurt_voices.is_empty(),
		"Tiro inimigo espera seu projétil alcançar o personagem.")
	await create_timer(0.32).timeout
	_check(not visual._combat_hit_held and not sfx._hurt_voices.is_empty(),
		"Tiro inimigo dispara dano e grito na chegada do projétil.")
	sfx._stop_all()
	target_visual.bind_state(target)
	target.current_health = 1
	actor.equipped_weapons.clear()
	combat.hit_prepared.emit(target)
	target.current_health = 0
	combat.action_resolved.emit(actor, &"attack", {"target": target,
		"damage": 1, "ranged": false})
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	_check(target_visual._dying and sfx._delayed_hurts.is_empty(),
		"Morte visual inicia no contato, sem grito antecipado.")
	await create_timer(0.57).timeout
	_check(not sfx._delayed_hurts.is_empty() or not sfx._hurt_voices.is_empty(),
		"Grito fatal só é agendado após o som da arma.")
	await create_timer(0.16).timeout
	_check(not sfx._hurt_voices.is_empty(),
		"Morte toca o grito após atraso curto e seu eco discreto.")
	print("PPP_HIT_PRESENTATION: %s" % ("PASS" if failures == 0 else "FAIL"))
	sfx._stop_all()
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("PPP_HIT_PRESENTATION: %s" % message)
