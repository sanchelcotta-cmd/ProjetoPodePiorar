extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data := load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData
	var playable := EntityState.from_playable_selection(data, &"p1", Vector2i(0, 0))
	var sprite := load("res://scenes/visuals/playable_actor_visual.tscn").instantiate() \
		as PlayableActorVisual
	root.add_child(sprite)
	sprite.bind_state(playable)
	var silhouette := EnemySilhouetteVisual.new()
	root.add_child(silhouette)
	var hostile := EntityState.from_playable_selection(data, &"test_enemy", Vector2i(1, 0))
	silhouette.bind_state(hostile)
	var enemy_status := DebuffData.new()
	enemy_status.id = &"enemy_marker_test"
	hostile.debuffs.append(DebuffInstanceState.new(enemy_status))
	await process_frame
	await process_frame
	_check(silhouette.is_in_group("map_entity_visual") \
		and (silhouette.debuff_marker.call("get_inspection_targets") as Array).size() == 1,
		"Marcador de Debuff de hostil também oferece área de inspeção no mapa.")
	playable.current_health = 0
	hostile.current_health = 0
	_check(sprite.visible and sprite.animated_sprite.animation == &"hurt" \
		and sprite.animated_sprite.frame == 3,
		"Jogável usa o quarto quadro vermelho do Hurt durante as piscadas.")
	_check(silhouette.visible and not (silhouette.get_node("BodyClickArea") as Area2D).input_pickable,
		"Hostil morto deixa de receber cliques antes de sumir.")
	await create_timer(0.25).timeout
	_check(sprite.visible and sprite.modulate.a < 0.25,
		"Primeira piscada reduz a opacidade até aproximadamente 10%.")
	await create_timer(1.0).timeout
	_check(sprite.visible and silhouette.visible,
		"Os visuais permanecem na cena durante o intervalo entre piscadas.")
	await create_timer(1.5).timeout
	_check(not sprite.visible and not silhouette.visible,
		"Após três piscadas em 2,5 segundos os visuais desaparecem.")
	print("COMBAT_DEATH_VISUAL_TEST_OK" if failures == 0 else \
		"COMBAT_DEATH_VISUAL_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
