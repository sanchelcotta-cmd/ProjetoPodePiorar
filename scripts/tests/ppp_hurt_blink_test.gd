extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var comfort := root.get_node("VisualComfort")
	var original := bool(comfort.get("enabled"))
	comfort.call("set_enabled", false, false)
	var actor := load("res://scenes/visuals/playable_actor_visual.tscn").instantiate() \
		as PlayableActorVisual
	root.add_child(actor)
	await process_frame
	actor.bind_data(load("res://resources/entities/entities_playable/professora.tres") \
		as EntityData)
	actor.play_hurt()
	var red_frame := actor.data.playable_animation.death_hurt_frame
	actor.animated_sprite.set_frame_and_progress(red_frame, 0.0)
	_check(actor.animated_sprite.visible and actor.animated_sprite.frame == red_frame,
		"Quadro vermelho aparece antes da piscada.")
	await create_timer(0.095).timeout
	_check(not actor.animated_sprite.visible,
		"Sprite some rapidamente depois do primeiro vermelho.")
	await create_timer(0.065).timeout
	_check(actor.animated_sprite.visible and actor.animated_sprite.frame == red_frame,
		"O mesmo quadro vermelho reaparece após o vazio.")
	await create_timer(0.090).timeout
	_check(actor.animated_sprite.is_playing(),
		"Hurt continua após a piscada breve.")
	comfort.call("set_enabled", true, false)
	actor.play_hurt()
	await create_timer(0.24).timeout
	_check(actor.animated_sprite.visible and actor.animated_sprite.frame <= 1,
		"Hurt reduzido mostra os primeiros quadros sem apagar o sprite.")
	await create_timer(0.22).timeout
	_check(actor.animated_sprite.visible and actor.animated_sprite.frame == red_frame,
		"Hurt reduzido usa o quadro vermelho correto sem piscar.")
	await create_timer(0.22).timeout
	_check(actor.animated_sprite.visible and actor.animated_sprite.animation == &"idle",
		"Hurt reduzido volta ao idle após uma passagem, sem repetição.")
	comfort.call("set_enabled", original, false)
	actor.queue_free()
	await process_frame
	if failures == 0:
		print("HURT_BLINK_TEST_OK")
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
