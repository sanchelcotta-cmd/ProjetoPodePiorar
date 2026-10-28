extends SceneTree

const VISUAL_SCENE := preload("res://scenes/visuals/playable_actor_visual.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var names := ["cozinheiro", "jornalista", "mae", "pedreiro",
		"professora", "universitario", "velha"]
	for name in names:
		var animation := load("res://resources/entities/animations/%s_animation.tres" % name) \
			as PlayableAnimationData
		_check(animation != null, "%s carrega seu conjunto v2." % name)
		if animation == null:
			continue
		var frames := animation.create_sprite_frames()
		for clip in [&"idle", &"walk", &"hurt"]:
			_check(frames.has_animation(clip), "%s possui %s." % [name, clip])
		for clip in [&"attack_blade", &"attack_impact", &"attack_ranged"]:
			_check(frames.has_animation(clip)
				and frames.get_frame_count(clip) == 5
				and not frames.get_animation_loop(clip),
				"%s possui cinco quadros não repetidos de %s." % [name, clip])
		for clip in [&"idle", &"walk", &"hurt", &"attack_blade",
				&"attack_impact", &"attack_ranged"]:
			for frame_index in frames.get_frame_count(clip):
				var points := animation.hand_bone_points(clip, frame_index)
				_check(not points.is_empty(),
					"%s: âncora da mão existe em %s/%d." \
					% [name, clip, frame_index])
				if clip in [&"attack_blade", &"attack_impact"] \
						and not points.is_empty():
					_check((points.tip - points.root).x > 0.0,
						"%s: %s/%d aponta para fora do personagem." \
						% [name, clip, frame_index])
		var rear := animation.sling_rear_hand_frame3
		var ranged_image := animation.ranged_attack_sheet.get_image()
		_check(rear.x >= 0 and rear.x < animation.frame_size.x
			and rear.y >= 0 and rear.y < animation.frame_size.y
			and ranged_image.get_pixel(animation.frame_size.x * 2 + rear.x,
				rear.y).a > 0.0,
			"%s: elástico do quadro 3 termina em pixel da mão traseira." % name)
	var chef := load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData
	var visual := VISUAL_SCENE.instantiate() as PlayableActorVisual
	var visual_layer := Node2D.new()
	root.add_child(visual_layer)
	visual_layer.add_child(visual)
	visual.bind_data(chef)
	var actor := EntityState.from_playable_selection(chef, &"Playable_1", Vector2i(1, 1))
	visual.bind_state(actor)
	var party := PlayablePartyView.new()
	root.add_child(party)
	party.visuals_by_slot[actor.playable_slot_id] = visual
	var chinelo := load("res://resources/itens/equipments/armas/chinelo.tres") as ItemData
	var bumerangue := load("res://resources/itens/equipments/armas/arma_epica_bumerangue_teleguiado.tres") as ItemData
	var ranged := load("res://resources/itens/equipments/armas/estilingue.tres") as ItemData
	var blade := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") as ItemData
	var impact := load("res://resources/itens/equipments/armas/martelo.tres") as ItemData
	_check(PlayableActorVisual.attack_clip_for_weapon(null) == &"attack_blade",
		"Desarmado usa a animação de lâmina.")
	_check(PlayableActorVisual.attack_clip_for_weapon(chinelo) == &"attack_impact"
		and PlayableActorVisual.attack_clip_for_weapon(bumerangue) == &"attack_impact",
		"Chinelo e Bumerangue usam o gesto de lançar por impacto.")
	_check(PlayableActorVisual.attack_clip_for_weapon(ranged) == &"attack_ranged"
		and PlayableActorVisual.attack_clip_for_weapon(blade) == &"attack_blade"
		and PlayableActorVisual.attack_clip_for_weapon(impact) == &"attack_impact",
		"Demais armas escolhem a folha pela maestria equipada.")
	var intercept := bumerangue.granted_passives[0] as PassiveSkillData
	var skill_manager := SkillManager.new()
	root.add_child(skill_manager)
	var campaign := CampaignState.new()
	_check(intercept != null and intercept.activation_chance == 0.6
		and intercept.incoming_attack_type == PassiveSkillData.IncomingAttackType.RANGED,
		"Bumerangue mantém 60% e restringe a interceptação a tiros.")
	_check(skill_manager._passive_conditions_met(actor, intercept, campaign,
		{"incoming_attack_type": PassiveSkillData.IncomingAttackType.RANGED})
		and not skill_manager._passive_conditions_met(actor, intercept, campaign,
			{"incoming_attack_type": PassiveSkillData.IncomingAttackType.MELEE}),
		"Ataque corpo a corpo não aciona a interceptação.")
	var enemy_data := load("res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	var target := EntityState.from_encounter_member(enemy_data, &"test", 1, Vector2i(2, 1))
	party._on_combat_action_resolved(actor, &"attack", {"target": target})
	_check(visual.animated_sprite.animation == &"attack_blade",
		"Ataque desarmado resolvido anima o jogável.")
	actor.equipped_weapons.append(InventoryItemState.new(chinelo))
	party._on_combat_action_resolved(actor, &"counterattack", {"target": target})
	_check(visual.animated_sprite.animation == &"attack_impact",
		"Contra-ataque com Chinelo anima por impacto.")
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(ranged))
	party._on_combat_action_resolved(actor, &"attack_missed_reach", {"target": target})
	_check(visual.animated_sprite.animation == &"attack_ranged",
		"Tentativa sem alcance mantém o gesto da arma equipada.")
	var intercept_grant := SkillGrantState.new(intercept, &"equipment", &"test_boomerang")
	intercept_grant.bound_source = bumerangue
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(bumerangue))
	actor.equipment_changed.emit()
	_check(visual.held_weapon_sprite.visible,
		"Bumerangue equipado aparece na âncora da mão.")
	party._on_passive_triggered(actor, intercept_grant,
		{"effects": [{"dodged": true}], "damage_source": target})
	_check(visual.animated_sprite.animation == &"attack_impact",
		"Interceptação usa a animação de arremesso do Bumerangue.")
	visual.animated_sprite.set_frame_and_progress(1, 0.0)
	_check(visual_layer.get_node_or_null("WeaponProjectile") == null,
		"Bumerangue permanece na mão no segundo quadro de Impacto.")
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	await process_frame
	_check(visual_layer.get_node_or_null("WeaponProjectile") != null,
		"Bumerangue sai entre o segundo e o terceiro quadro de Impacto.")
	_check(not visual.held_weapon_sprite.visible,
		"Item sai da mão enquanto o Bumerangue intercepta.")
	await create_timer(0.45).timeout
	_check(visual_layer.get_node_or_null("WeaponProjectile") == null,
		"Projétil desaparece ao atingir o agressor, sem animação de volta.")
	_check(visual.held_weapon_sprite.visible,
		"Nova cópia visual retorna à mão após atingir o agressor.")
	_check(int(WeaponHandVisual.variant(&"aa_00010", &"light",
		&"attack_ranged", 1).cell) == 2
		and int(WeaponHandVisual.variant(&"aa_00010", &"light",
			&"attack_ranged", 2).cell) == 2
		and int(WeaponHandVisual.variant(&"aa_00010", &"light",
			&"attack_ranged", 3).cell) == 1,
		"Estilingue estica no segundo e terceiro quadros; relaxa no disparo.")
	_check(int(WeaponHandVisual.variant(&"aa_00002", &"light",
		&"attack_ranged", 1).cell) == 1
		and int(WeaponHandVisual.variant(&"aa_00002", &"light",
			&"attack_ranged", 2).cell) == 2
		and int(WeaponHandVisual.variant(&"aa_00002", &"light",
			&"attack_ranged", 3).cell) == 0,
		"Arco puxa a corda no segundo, mostra flecha no terceiro e solta no quarto.")
	_check(int(WeaponHandVisual.variant(&"aa_00001", &"light").cell) == 3
		and int(WeaponHandVisual.variant(&"aa_00001", &"shadow").cell) == 4,
		"Adaga mostra Luz e Sombra em sprites distintos.")
	for weapon_id in [&"aa_00001", &"aa_00002", &"aa_00003", &"aa_00004",
			&"aa_00005", &"aa_00006", &"aa_00007", &"aa_00008",
			&"aa_00009", &"aa_00010", &"aa_00011", &"aa_00012",
			&"aa_00013", &"aa_00014"]:
		_check(not WeaponHandVisual.variant(weapon_id).is_empty(),
			"Arma %s possui sprite na mão." % weapon_id)
	_check(is_equal_approx(WeaponHandVisual.held_scale(&"aa_00009"), 0.70 * 0.90)
		and is_equal_approx(WeaponHandVisual.held_scale(&"aa_00004"), 0.82 * 0.90),
		"Chinelo e Bumerangue permanecem provisórios, agora 10% menores.")
	for weapon_id in [&"aa_00001", &"aa_00002", &"aa_00003", &"aa_00004",
			&"aa_00005", &"aa_00006", &"aa_00007", &"aa_00008",
			&"aa_00009", &"aa_00010", &"aa_00011", &"aa_00012",
			&"aa_00013", &"aa_00014"]:
		var spec := WeaponHandVisual.variant(weapon_id)
		var original := (spec.sheet as Texture2D).get_image().get_region(
			Rect2i(int(spec.cell) * 48, 0, 48, 96))
		var composed := (WeaponHandVisual.make_held_texture(spec,
			WeaponHandVisual.skin_for_playable(&"pj_00005"), false,
			WeaponHandVisual.held_scale(weapon_id)).texture \
			as Texture2D).get_image()
		var gap := false
		for y in original.get_height():
			for x in original.get_width():
				if WeaponHandVisual._is_grip_pixel(original.get_pixel(x, y)) \
						and composed.get_pixel(x, y).a <= 0.0:
					gap = true
		_check(not gap,
			"Arma %s não deixa buraco transparente no antigo verde." % weapon_id)
	for thrown in [[&"aa_00004", 0, 1], [&"aa_00009", 2, 3]]:
		var thrown_spec := WeaponHandVisual.variant(thrown[0])
		_check(thrown_spec.sheet == WeaponHandVisual.THROWN_PAIR
			and int(thrown_spec.cell) == int(thrown[1])
			and int(thrown_spec.projectile_cell) == int(thrown[2]),
			"Arremesso usa o par correto de sprites, com/sem dedo.")
		var held := WeaponHandVisual.make_held_texture(thrown_spec,
			WeaponHandVisual.skin_for_playable(&"pj_00005"), false,
			WeaponHandVisual.held_scale(thrown[0]))
		var held_image := (held.texture as Texture2D).get_image()
		var projectile_image := WeaponHandVisual.make_projectile_texture(
			thrown_spec).get_image()
		var has_green := false
		for image in [held_image, projectile_image]:
			for y in image.get_height():
				for x in image.get_width():
					if WeaponHandVisual._is_grip_pixel(image.get_pixel(x, y)):
						has_green = true
		_check(not has_green and WeaponHandVisual.THUMB_PIXELS == 2,
			"Dedo de 2 px substitui o marcador; projétil voa sem verde.")
		var original_flight := WeaponHandVisual.THROWN_PAIR.get_image().get_region(
			Rect2i(int(thrown[2]) * 48, 0, 48, 96))
		_check(projectile_image.get_data() == original_flight.get_data(),
			"Projétil usa exatamente o desenho fornecido sem dedo.")
	var previous_scales := {
		&"aa_00001": 0.62, &"aa_00002": 0.82, &"aa_00003": 0.56,
		&"aa_00004": 0.82, &"aa_00005": 0.68, &"aa_00006": 0.68,
		&"aa_00007": 0.67, &"aa_00008": 0.56, &"aa_00009": 0.70,
		&"aa_00010": 0.68, &"aa_00011": 0.80, &"aa_00012": 0.50,
		&"aa_00013": 0.72, &"aa_00014": 0.68,
	}
	for weapon_id in previous_scales:
		var expected: float = previous_scales[weapon_id]
		if weapon_id not in [&"aa_00003", &"aa_00008"]:
			expected *= 0.90
		_check(is_equal_approx(WeaponHandVisual.held_scale(weapon_id), expected),
			"Arma %s respeita a redução de 10%% ou sua exceção." % weapon_id)
	_check(is_equal_approx(WeaponHandVisual.held_rotation(&"aa_00011", 0.0),
		deg_to_rad(42.0)) and is_equal_approx(
		WeaponHandVisual.held_rotation(&"aa_00007", PI), deg_to_rad(114.0)),
		"Eixos diagonais de Faca e Martelo de Guerra apontam para o alvo.")
	_check(is_equal_approx(WeaponHandVisual.held_rotation(&"aa_00011", 0.0, true),
		deg_to_rad(138.0)) and is_equal_approx(
		WeaponHandVisual.held_rotation(&"aa_00007", PI, true), deg_to_rad(66.0)),
		"Eixos diagonais continuam para fora quando o ator olha à esquerda.")
	_check(is_zero_approx(WeaponHandVisual.held_rotation(&"aa_00002", 0.0))
		and is_equal_approx(WeaponHandVisual.held_rotation(&"aa_00010", PI), -PI),
		"Corda do Arco e elástico do Estilingue ficam na direção da mão de trás.")
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(chinelo))
	actor.equipment_changed.emit()
	party._on_combat_action_resolved(actor, &"attack", {"target": target})
	_check(visual.animated_sprite.animation == &"attack_impact",
		"Chinelo mantém a exceção da animação de Impacto.")
	visual.animated_sprite.set_frame_and_progress(1, 0.0)
	_check(visual_layer.get_node_or_null("WeaponProjectile") == null,
		"Chinelo ainda não sai no segundo quadro de Impacto.")
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	await process_frame
	_check(visual_layer.get_node_or_null("WeaponProjectile") != null,
		"Chinelo é arremessado entre o segundo e o terceiro quadro.")
	await create_timer(0.45).timeout
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(ranged))
	actor.equipment_changed.emit()
	party._on_combat_action_resolved(actor, &"attack", {"target": target})
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	_check(visual_layer.get_node_or_null("WeaponProjectile") == null,
		"Estilingue ainda não lança a bolinha no terceiro quadro.")
	visual.animated_sprite.set_frame_and_progress(3, 0.0)
	await process_frame
	_check(visual_layer.get_node_or_null("WeaponProjectile") != null,
		"Estilingue lança a bolinha no quarto quadro.")
	await create_timer(0.45).timeout
	var bow := load("res://resources/itens/equipments/armas/arma_epica_arco_da_precisao.tres") as ItemData
	actor.equipped_weapons.clear()
	actor.equipped_weapons.append(InventoryItemState.new(bow))
	actor.equipment_changed.emit()
	party._on_combat_action_resolved(actor, &"attack", {"target": target})
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	_check(visual_layer.get_node_or_null("WeaponProjectile") == null,
		"Arco retém a flecha no terceiro quadro.")
	visual.animated_sprite.set_frame_and_progress(3, 0.0)
	await process_frame
	_check(visual_layer.get_node_or_null("WeaponProjectile") != null,
		"Arco lança a flecha no quarto quadro.")
	await create_timer(0.45).timeout
	visual._on_animation_finished()
	_check(visual.animated_sprite.animation == &"idle",
		"O ataque termina em Idle, sem deixar o personagem travado.")
	visual.reset_at(Vector2i(1, 1))
	var path: Array[Vector2i] = [Vector2i(2, 1)]
	visual.animate_path(path)
	await create_timer(0.19).timeout
	_check(visual._walking, "Caminhada desacelerada ainda está em curso aos 0,19 s.")
	await create_timer(0.18).timeout
	_check(not visual._walking and visual.position.is_equal_approx(
		PPPMapView.reference_hex_position(Vector2i(2, 1))),
		"A caminhada termina no hex de destino.")
	actor.equipped_weapons.clear()
	actor.equipment_changed.emit()
	actor.position = Vector2i(3, 1)
	var approach: Array[Vector2i] = [Vector2i(3, 1)]
	visual.animate_path(approach)
	party._on_combat_action_resolved(actor, &"attack", {"target": target})
	visual._finish_walk() # Simula a conclusão tardia da aproximação no mesmo quadro.
	_check(visual.animated_sprite.animation == &"attack_blade"
		and visual.position.is_equal_approx(PPPMapView.reference_hex_position(actor.position)),
		"Golpe corpo a corpo desarmado preserva Lâmina após a aproximação.")
	await create_timer(0.25).timeout
	_check(visual.animated_sprite.animation == &"attack_blade",
		"Uma conclusão tardia da caminhada não interrompe a Lâmina.")
	for name in names:
		var entity_file: String = "velha_fofoqueira" if name == "velha" else name
		var playable := load("res://resources/entities/entities_playable/%s.tres" \
			% entity_file) as EntityData
		var sling_actor := EntityState.from_playable_selection(playable,
			&"Playable_1", Vector2i(1, 1))
		sling_actor.equipped_weapons.append(InventoryItemState.new(ranged))
		visual.bind_state(sling_actor)
		visual.animated_sprite.play(&"attack_ranged")
		visual.animated_sprite.set_frame_and_progress(2, 0.0)
		_check(visual.sling_elastic.visible and visual.sling_elastic.points.size() == 2,
			"%s: terceiro quadro usa elástico dinâmico." % name)
		var animation := playable.playable_animation
		var rear := Vector2(animation.sling_rear_hand_frame3)
		var rear_local := visual.animated_sprite.position + \
			(rear - Vector2(animation.frame_size) * 0.5) \
			* visual.animated_sprite.scale
		var skeleton := visual.weapon_hand_bone.get_parent() as Node2D
		var expected := skeleton.to_local(visual.to_global(rear_local))
		_check(visual.sling_elastic.points[0].distance_to(expected) < 0.1,
			"%s: elástico alcança a mão traseira no quadro 3." % name)
		visual.animated_sprite.flip_h = true
		visual._update_weapon_hand_bone()
		rear.x = float(animation.frame_size.x) - rear.x
		rear_local = visual.animated_sprite.position + \
			(rear - Vector2(animation.frame_size) * 0.5) \
			* visual.animated_sprite.scale
		expected = skeleton.to_local(visual.to_global(rear_local))
		_check(visual.sling_elastic.points[0].distance_to(expected) < 0.1,
			"%s: elástico espelhado alcança a mão traseira." % name)
		visual.animated_sprite.set_frame_and_progress(3, 0.0)
		_check(not visual.sling_elastic.visible,
			"%s: elástico relaxa após o terceiro quadro." % name)
	print("PPP_PLAYABLE_ATTACK_ANIMATION: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
