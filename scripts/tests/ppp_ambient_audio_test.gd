extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var audio := root.get_node("GameAudio")
	for pair in [[&"Ambience", 0.85], [&"GeneralSFX", 1.00],
			[&"CombatSFX", 1.00], [&"SpecialSFX", 1.00],
			[&"ClickUI", 1.00]]:
		var index := AudioServer.get_bus_index(pair[0])
		_check(index >= 0 and AudioServer.get_bus_send(index) == &"EffectsUI"
			and is_equal_approx(AudioServer.get_bus_volume_db(index),
				linear_to_db(pair[1])),
			"%s mantém seu nível relativo dentro de Efeitos/UI." % pair[0])
	var original_effects := int(audio.call("get_volume", &"effects"))
	var original_music := int(audio.call("get_volume", &"music"))
	audio.call("set_volume", &"effects", 100, false)
	audio.call("set_volume", &"music", 100, false)
	audio.call("set_volume", &"effects", 0, false)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"EffectsUI"))
		and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")),
		"Silenciar Efeitos/UI silencia ambiente sem mexer em Música.")
	audio.call("set_volume", &"effects", original_effects, false)
	audio.call("set_volume", &"music", original_music, false)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var ambient := scene.get_node("GameAmbientAudio") as GameAmbientAudio
	var sky := scene.get_node("ParallaxBackground") as PPPParallaxBackground
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	_check(ambient != null and ambient._base.bus == &"Ambience"
		and ambient._owl.bus == &"Ambience" and ambient._music_box.bus == &"Ambience",
		"Base, coruja e caixinha usam somente o bus Ambiente.")
	for track in GameAmbientAudio.TRACKS:
		_check(ambient._stream(track) != null, "%s importa como áudio real." % track)
	ambient._rng.seed = 91731
	for index in 50:
		_check(ambient._choose_base_track(PPPMapGenerator.RoundPeriod.MORNING,
			&"centro", "manha_0001") in ["bird_park", "forest_birds"],
			"Manhã/tarde usam apenas pássaros.")
		_check(ambient._choose_base_track(PPPMapGenerator.RoundPeriod.NIGHT,
			&"suburbio", "noite_0001") in ["night_crickets", "night_ambience"],
			"Noite usa apenas sons noturnos.")
		_check(ambient._choose_base_track(PPPMapGenerator.RoundPeriod.AFTERNOON,
			&"centro", "cinzento_0002") in ["rain_thunder", "thunderstorm"],
			"Céu cinzento substitui pássaros por chuva/trovão.")
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/universitario.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(gerencia.start_new_game(selected), "Campanha de teste inicia.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 40012
	_check(rounds.start_first_map(rng), "Mapa gera céu e ambientação.")
	await process_frame
	_check(ambient._base_track != "" and ambient._base.stream != null,
		"Mapa sorteia e toca um ambiente.")
	var box_data := load("res://resources/itens/curseds/caixinha_de_musicas.tres") as ItemData
	var owner := gerencia.campaign.active_entity_states[0]
	var copy := InventoryItemState.new(box_data)
	owner.inventory_items.append(copy)
	ambient._refresh()
	_check(ambient._music_box_present and ambient._music_box.playing
		and is_equal_approx(ambient._music_box.volume_linear, 0.35),
		"Caixinha em qualquer inventário sobrepõe ambiente em volume baixo.")
	owner.inventory_items.erase(copy)
	ambient._refresh()
	_check(not ambient._music_box_present and not ambient._music_box.playing,
		"Tirar a caixinha silencia sua camada sem parar o ambiente base.")
	sky.active_set_path = "res://sprites/background/fundosparalax/cinzento_0002"
	ambient._refresh()
	_check(ambient._base_track in ["rain_thunder", "thunderstorm"],
		"Céu cinzento aplicado depois da geração troca o áudio.")
	ambient._base.stop()
	ambient._set_base_track("night_ambience")
	_check(ambient._owl_timer.time_left >= GameAmbientAudio.OWL_MIN_SECONDS - 1.0
		and ambient._owl_timer.time_left <= GameAmbientAudio.OWL_MAX_SECONDS,
		"Coruja espera entre um e três minutos sobre night-ambience.")
	scene.queue_free()
	await process_frame
	print("PPP_AMBIENT_AUDIO_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
