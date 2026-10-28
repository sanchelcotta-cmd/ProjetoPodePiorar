extends SceneTree

const AUDIO_SETTINGS_SCRIPT := preload("res://scripts/ui/game_audio_settings.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var audio := root.get_node("GameAudio")
	var old_path := str(audio.get("config_path"))
	var original: Dictionary = {}
	for channel in [&"master", &"effects", &"music"]:
		original[channel] = int(audio.call("get_volume", channel))
	audio.set("config_path", "user://ppp_audio_settings_test.cfg")
	var effects_bus := AudioServer.get_bus_index(&"EffectsUI")
	var music_bus := AudioServer.get_bus_index(&"Music")
	_check(AUDIO_SETTINGS_SCRIPT.DEFAULT_VOLUMES[&"effects"] == 100,
		"Nova instalação começa com Efeitos/interface em 100%, sem alterar preferências já salvas.")
	for bus_name in [&"GeneralSFX", &"CombatSFX", &"SpecialSFX", &"ClickUI"]:
		_check(is_equal_approx(AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(bus_name)), 0.0),
			"%s não recebe redução extra: 100%% do canal Efeitos/interface." % bus_name)
	_check(is_equal_approx(AudioServer.get_bus_volume_db(
		AudioServer.get_bus_index(&"Ambience")), linear_to_db(0.85)),
		"Ambiente fica em 85% quando Efeitos/interface está em 100%.")
	_check(effects_bus >= 0 and music_bus >= 0
		and AudioServer.get_bus_send(effects_bus) == &"Master"
		and AudioServer.get_bus_send(music_bus) == &"Master",
		"Efeitos/UI e Música têm buses independentes que enviam à Master.")
	_check(bool(audio.call("set_volume", &"master", 40))
		and bool(audio.call("set_volume", &"effects", 30))
		and bool(audio.call("set_volume", &"music", 60)),
		"Os três canais aceitam porcentagens reais.")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(effects_bus),
		linear_to_db(0.3)) and
		is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.6)),
		"Os valores são aplicados ao AudioServer, não só exibidos na UI.")
	_check(bool(audio.call("toggle_mute", &"effects")) and
		int(audio.call("get_volume", &"effects")) == 0 and
		AudioServer.is_bus_mute(effects_bus) and
		int(audio.call("get_volume", &"music")) == 60,
		"Mudo de efeitos fixa 0% sem modificar Música.")
	_check(bool(audio.call("toggle_mute", &"effects")) and
		int(audio.call("get_volume", &"effects")) == 30 and
		not AudioServer.is_bus_mute(effects_bus),
		"O segundo clique restaura o último volume audível.")
	var persisted := ConfigFile.new()
	_check(persisted.load("user://ppp_audio_settings_test.cfg") == OK and
		int(persisted.get_value("audio", "master", -1)) == 40 and
		int(persisted.get_value("audio", "effects", -1)) == 30 and
		int(persisted.get_value("audio", "music", -1)) == 60,
		"Volumes independentes persistem entre sessões.")
	for channel in [&"master", &"effects", &"music"]:
		audio.call("set_volume", channel, 100, false)
	audio.call("_load_settings")
	for channel in [&"master", &"effects", &"music"]:
		audio.call("_apply_volume", channel)
	_check(int(audio.call("get_volume", &"master")) == 40 and
		int(audio.call("get_volume", &"effects")) == 30 and
		int(audio.call("get_volume", &"music")) == 60,
		"Os três volumes são recuperados do arquivo na próxima leitura.")
	var game := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(game)
	await process_frame
	var bar := game.get_node("CampaignTopBar") as CampaignTopBar
	var quick := bar.get("_audio_quick_panel") as Control
	bar.sound_button.pressed.emit()
	await process_frame
	_check(quick.visible and bar.sound_button.text == "♪" and
		int(audio.call("get_volume", &"master")) == 40,
		"O botão ♪ abre a minicaixa sem alternar mudo.")
	var controls := quick.find_child("AudioVolumeControls", true, false) as Control
	var effects_slider := controls.find_child("VolumeSlider_effects", true, false) as HSlider
	var station_button := quick.find_child("ChangeStation", true, false) as Button
	_check(effects_slider != null and int(effects_slider.value) == 30 and
		station_button != null and station_button.disabled,
		"Minicaixa mostra os valores reais e só permite rádio durante Exploração.")
	var ui_scale := root.get_node("UniversalFontScale")
	var original_scale := float(ui_scale.get("ui_factor"))
	ui_scale.call("set_ui_scale", 1.25, false)
	await process_frame
	await process_frame
	var quick_box := quick.find_child("SoundQuickPanel", true, false) as Control
	var quick_rect := quick_box.get_global_rect()
	_check(quick_rect.position.x >= 0 and quick_rect.end.x <= root.size.x,
		"Minicaixa de áudio permanece na tela com escala de UI ampliada.")
	ui_scale.call("set_ui_scale", original_scale, false)
	var settings := bar.pause_menu.get("_settings_menu") as Control
	var settings_audio := settings.find_child("AudioVolumeControls", true, false) as Control
	var settings_effects := settings_audio.find_child(
		"VolumeSlider_effects", true, false) as HSlider
	effects_slider.value = 45
	_check(int(audio.call("get_volume", &"effects")) == 45 and
		int(settings_effects.value) == 45,
		"Minicaixa e Configurações compartilham um único estado de áudio.")
	_check(int(audio.call("get_station_count")) == 3
		and str(audio.call("get_current_station_title")) in ["Rádio A", "Rádio B", "Rádio C"],
		"As três rádios reais são registradas ao iniciar o jogo.")
	var combat_paths := {
		&"radio_a": "res://audio/music/combat_radio_a.mp3",
		&"radio_b": "res://audio/music/combat_radio_b.mp3",
		&"radio_c": "res://audio/music/combat_radio_c.mp3",
	}
	var registered_stations: Array = audio.get("_stations")
	for station in registered_stations:
		var combat_stream := station.get("combat_stream") as AudioStream
		_check(str(station.get("combat_path", combat_stream.resource_path \
			if combat_stream != null else "")) == combat_paths.get(station.get("id"), ""),
			"Cada rádio registra sua própria faixa definitiva de Combate.")
	var game_state := game.get_node("GerenciaJogo") as GerenciaJogo
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(game_state.start_new_game(selected)
		and (game.get_node("RoundManager") as RoundManager).start_first_map(),
		"Campanha abre para testar a troca contextual de música.")
	await process_frame
	await process_frame
	_check(audio.call("get_music_context") == &"exploration"
		and not station_button.disabled
		and (audio.get("_music_player") as AudioStreamPlayer).playing,
		"Na Exploração, rádio escolhida toca e a minicaixa libera mudar estação.")
	var previous_title := str(audio.call("get_current_station_title"))
	station_button.pressed.emit()
	_check(str(audio.call("get_current_station_title")) != previous_title
		and audio.get("_music_player").get("bus") == &"Music",
		"Mudar estação troca a música real no bus Music.")
	var chosen_title := str(audio.call("get_current_station_title"))
	bar.pause_button.pressed.emit()
	await process_frame
	var station_voice := audio.get("_music_player") as AudioStreamPlayer
	_check(not quick.visible, "Abrir a pausa recolhe a minicaixa de áudio.")
	_check(bar.pause_menu.is_open() and paused \
		and audio.call("get_music_context") == &"paused" \
		and station_voice.playing and not station_voice.stream_paused \
		and is_equal_approx(station_voice.volume_linear, 0.5),
		"Pausa real mantém a rádio tocando com metade do ganho local.")
	audio.call("set_volume", &"music", 80, false)
	_check(int(audio.call("get_volume", &"music")) == 80 \
		and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music_bus)) \
			* station_voice.volume_linear, 0.4),
		"Música a 80% resulta em 40% efetivos na pausa, sem alterar a preferência.")
	bar.pause_menu.close()
	await process_frame
	_check(not paused and audio.call("get_music_context") == &"exploration" \
		and station_voice.playing and not station_voice.stream_paused \
		and is_equal_approx(station_voice.volume_linear, 1.0),
		"Sair da pausa restaura a rádio ao volume normal sem reiniciar a faixa.")
	audio.call("set_volume", &"music", 60, false)
	game_state.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	await process_frame
	var selected_station: Dictionary = registered_stations[int(audio.get("_station_index"))]
	_check(audio.call("get_music_context") == &"combat"
		and station_button.disabled
		and (audio.get("_combat_player") as AudioStreamPlayer).playing
		and (audio.get("_combat_player") as AudioStreamPlayer).bus == &"Music"
		and (audio.get("_combat_player") as AudioStreamPlayer).stream.resource_path
			== combat_paths[selected_station["id"]]
		and (audio.get("_music_player") as AudioStreamPlayer).stream_paused
		and not bool(audio.call("next_station")),
		"Combate toca a faixa da rádio escolhida, sem trocar estação ou sobrepor Exploração.")
	audio.call("set_game_context", &"paused")
	_check((audio.get("_combat_player") as AudioStreamPlayer).stream_paused \
		and station_voice.playing and not station_voice.stream_paused \
		and is_equal_approx(station_voice.volume_linear, 0.5),
		"Pausa durante Combate suspende a faixa de Combate e toca a rádio a 50%.")
	audio.call("set_game_context", &"combat")
	_check((audio.get("_combat_player") as AudioStreamPlayer).playing
		and not (audio.get("_combat_player") as AudioStreamPlayer).stream_paused
		and station_voice.stream_paused
		and is_equal_approx(station_voice.volume_linear, 1.0)
		and (audio.get("_combat_player") as AudioStreamPlayer).stream.resource_path
			== combat_paths[selected_station["id"]],
		"Retomar o Combate continua a faixa correta da rádio.")
	game_state.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.EXPLORATION
	await process_frame
	_check(audio.call("get_music_context") == &"exploration"
		and str(audio.call("get_current_station_title")) == chosen_title
		and (audio.get("_music_player") as AudioStreamPlayer).playing,
		"A rádio escolhida retorna após o Combate.")
	for _next in 2:
		station_button.pressed.emit()
		selected_station = registered_stations[int(audio.get("_station_index"))]
		game_state.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
		await process_frame
		_check((audio.get("_combat_player") as AudioStreamPlayer).playing
			and (audio.get("_combat_player") as AudioStreamPlayer).stream.resource_path
				== combat_paths[selected_station["id"]]
			and (audio.get("_music_player") as AudioStreamPlayer).stream_paused,
			"Trocar estação na Exploração troca também a próxima faixa de Combate.")
		game_state.campaign.current_map.ppp_map_mode = HexGrid.PPPMapMode.EXPLORATION
		await process_frame
	bar.sound_button.pressed.emit()
	_check(quick.visible, "O botão ♪ reabre a minicaixa após a pausa.")
	bar.sound_button.pressed.emit()
	_check(not quick.visible, "O botão ♪ também recolhe a minicaixa.")
	audio.get("_music_player").stop()
	game.queue_free()
	await process_frame
	for channel in original:
		audio.call("set_volume", channel, int(original[channel]), false)
	audio.set("config_path", old_path)
	print("PPP_AUDIO_SETTINGS_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
