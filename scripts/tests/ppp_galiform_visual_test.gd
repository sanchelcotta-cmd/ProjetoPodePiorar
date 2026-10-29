extends SceneTree

const VISUAL_SCENE := preload("res://scenes/visuals/playable_actor_visual.tscn")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var character := load("res://resources/entities/entities_playable/professora.tres") as EntityData
	var actor := EntityState.from_playable_selection(character,
		&"Playable_1", Vector2i(1, 1))
	var enemy_data := load(
		"res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	var target := EntityState.from_encounter_member(enemy_data, &"egg_target",
		1, Vector2i(3, 1))
	var layer := Node2D.new()
	root.add_child(layer)
	var visual := VISUAL_SCENE.instantiate() as PlayableActorVisual
	layer.add_child(visual)
	visual.bind_state(actor)
	visual.set_visual_scale(PlayablePartyView.MAP_CHARACTER_SCALE)
	actor.temporary_appearance = &"chicken_form"
	visual.refresh_temporary_visual()
	var reference_scale := SpriteOrientationReference.chicken_reference_scale()
	_check(visual.animated_sprite.visible
		and visual._animation_data() == PlayableActorVisual.CHICKEN_ANIMATION
		and is_equal_approx(visual.animated_sprite.scale.x, reference_scale)
		and is_equal_approx(visual.animated_sprite.scale.y, reference_scale),
		"Forma galiforme usa sprite real e altura oficial da régua.")
	_check(not visual.held_weapon_sprite.visible,
		"Galinha não exibe a arma humana.")
	var blade := load("res://resources/itens/equipments/armas/faca_de_cozinha.tres") \
		as ItemData
	var ranged := load("res://resources/itens/equipments/armas/estilingue.tres") \
		as ItemData
	visual.play_attack(blade, target)
	_check(visual.animated_sprite.animation == &"attack_blade",
		"Ataque corpo a corpo usa o gesto único da galinha.")
	visual.play_attack(ranged, target)
	_check(visual.animated_sprite.animation == &"attack_blade",
		"Ataque à distância usa o mesmo gesto único da galinha.")
	var arrival := {"received": false}
	visual.projectile_arrived.connect(func(_source: EntityState,
			_destination: EntityState) -> void: arrival["received"] = true)
	visual.animated_sprite.set_frame_and_progress(2, 0.0)
	_check(layer.get_node_or_null("WeaponProjectile") is Sprite2D,
		"O terceiro quadro solta um ovo pixelado.")
	await create_timer(0.18).timeout
	var egg := layer.get_node_or_null("WeaponProjectile") as Sprite2D
	_check(egg != null and egg.position.y < visual.position.y,
		"O ovo percorre trajetória arqueada.")
	await create_timer(0.45).timeout
	_check(bool(arrival["received"])
		and layer.get_node_or_null("WeaponProjectile") == null,
		"O impacto é anunciado só na chegada do ovo.")
	actor.temporary_appearance = &""
	visual.refresh_temporary_visual()
	_check(visual._animation_data() == character.playable_animation
		and is_equal_approx(visual.animated_sprite.scale.y,
			PlayablePartyView.MAP_CHARACTER_SCALE),
		"Fim da transformação restaura os sprites e tamanho originais.")
	layer.free()
	print("PPP galiforme visual: %d falha(s)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
