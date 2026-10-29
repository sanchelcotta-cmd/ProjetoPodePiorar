extends SceneTree

const PREVIEW_PATH := "res://artifacts/event_followers_scene.png"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var companions := scene.get_node("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/professora.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
	]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha inicia para validar os dois seguidores.")
	if failures > 0:
		quit(1)
		return
	var owner := gerencia.campaign.active_entity_states[0]
	var other := gerencia.campaign.active_entity_states[1]
	owner.turn_state = EntityState.TurnState.TURNING
	owner.position = Vector2i(4, 2)
	other.position = Vector2i(6, 2)
	gerencia.campaign.active_entity_states[2].position = Vector2i(3, 4)
	var playables := scene.get_node("MapRoot/DepthSorted/PlayableActors") \
		as PlayablePartyView
	for member in gerencia.campaign.active_entity_states:
		var actor_visual := playables.visuals_by_slot.get(member.playable_slot_id) \
			as PlayableActorVisual
		if actor_visual != null:
			actor_visual.reset_at(member.position)
	var event := load("res://resources/events/random_events/14-amigo_imaginario.tres") as EventData
	gerencia.campaign.current_map.set_ppp_block(owner.position,
		HexGrid.PPPBlockType.EVENT, event)
	_check(block.begin_activation(owner.position, owner),
		"Amigo Imaginário abre a caixa de Evento.")
	for _step in 3:
		if not block.is_busy() or popup.buttons.get_child_count() == 0:
			break
		(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(gerencia.campaign.has_imaginary_friend(owner),
		"O Evento registra o amigo apenas até o fim da Rodada.")
	var imaginary := companions.imaginary_visuals_by_owner_id.get(owner.instance_id) \
		as EventFollowerVisual
	_check(imaginary != null and imaginary.visible and imaginary.imaginary
		and imaginary.sprite.material is ShaderMaterial,
		"Amigo Imaginário aparece com sua variante visual.")
	_check(gerencia.campaign.grant_wooden_doll(other),
		"Bonequinho é concedido para comparar o visual original.")
	var doll := companions.doll_visuals_by_owner_id.get(other.instance_id) \
		as EventFollowerVisual
	_check(doll != null and doll.visible and doll.sprite.material == null,
		"Bonequinho conserva as cores originais.")
	if imaginary != null and doll != null:
		_check(is_equal_approx(imaginary.sprite.scale.y,
			SpriteOrientationReference.chicken_reference_scale()) and
			is_equal_approx(doll.sprite.scale.y, imaginary.sprite.scale.y),
			"Os dois seguidores têm a altura da galinha na cena de referência.")
		_check(imaginary.position.distance_to(
			PPPMapView.reference_hex_position(owner.position)) > 40.0 and
			doll.position.distance_to(
			PPPMapView.reference_hex_position(other.position)) > 40.0,
			"Ambos ficam entre os hexes, sem ocupar seus centros.")
		var blocker := Node2D.new()
		blocker.position = imaginary.position + Vector2(45.0, 0.0)
		imaginary.get_parent().add_child(blocker)
		blocker.add_to_group("map_entity_visual")
		blocker.set_meta("walk_radius", 32.0)
		_check(imaginary._avoidance_control_point(imaginary.position,
			imaginary.position + Vector2(90.0, 0.0)) != Vector2.INF,
			"O seguidor calcula desvio diante de outra entidade no caminho.")
		blocker.free()
	if "--preview" in OS.get_cmdline_user_args() \
			and DisplayServer.get_name() != "headless":
		Input.warp_mouse(Vector2(10, 10))
		await create_timer(1.5).timeout
		(scene.get_node("PartyStatusHUD/HexChoiceLayer/HexChoice") as Control).hide()
		for _frame in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty() and
			image.save_png(PREVIEW_PATH) == OK,
			"Cena com os seguidores é capturada para aprovação visual.")
	else:
		owner.position = Vector2i(5, 2)
		if imaginary != null:
			_check(imaginary.sprite.animation == &"walk",
				"A mudança de hex inicia a animação Walk.")
		await create_timer(0.55).timeout
		if imaginary != null:
			_check(imaginary.position.distance_to(
				PPPMapView.reference_hex_position(owner.position) +
				EventFollowerVisual.IMAGINARY_OFFSET) < 2.0,
				"Amigo Imaginário caminha com o dono usando Walk.")
		for entry in gerencia.campaign.temporary_event_effects:
			if entry.get("kind") == &"imaginary_friend":
				entry["expires_round"] = gerencia.campaign.get_round_index()
		gerencia.campaign.expire_temporary_events_for_clock()
		await process_frame
		_check(not companions.imaginary_visuals_by_owner_id.has(owner.instance_id),
			"O visual desaparece quando a duração do Evento termina.")
		scene.free()
	print("PPP seguidores de Evento: %d falhas." % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
