extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var comfort := root.get_node("VisualComfort")
	var palette := root.get_node("UIColorManager")
	var scale := root.get_node("UniversalFontScale")
	var original_comfort := bool(comfort.get("enabled"))
	var original_palette := str(palette.get("palette_id"))
	var original_scale := float(scale.get("ui_factor"))
	palette.call("set_palette", "azul", false)
	comfort.call("set_enabled", true, false)
	_check(str(palette.get("palette_id")) == "azul" and
		is_equal_approx(float(scale.get("ui_factor")), original_scale),
		"Redução visual não altera paleta nem escala.")
	_check(float(comfort.call("cap_light_energy", 0.5)) <= 0.025 and
		float(comfort.call("cap_shadow_alpha", 0.9)) <= 0.32 and
		float(comfort.call("cap_particle_alpha", 0.9)) <= 0.22,
		"Luzes, sombras e partículas obedecem aos tetos somente quando ativada.")
	var game := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(game)
	current_scene = game
	await process_frame
	var manager := game.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := game.get_node("RoundManager") as RoundManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres"),
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 92170
	_check(manager.start_new_game(selected) and rounds.start_first_map(rng),
		"Campanha de teste inicia.")
	var codec := CampaignSaveCodec.new()
	var encoded := codec.encode(manager.campaign)
	_check(not JSON.stringify(encoded).contains("reduce_flashes_motion") and
		not JSON.stringify(encoded).contains("palette_id"),
		"Tema e redução visual não entram no grafo de save da campanha.")
	var restored := codec.decode(encoded) as CampaignState
	_check(restored != null and restored.campaign_id == manager.campaign.campaign_id
		and bool(comfort.get("enabled")) and str(palette.get("palette_id")) == "azul",
		"Decodificar campanha não substitui preferências de interface.")
	var repository := CampaignSaveRepository.new("user://ppp_visual_comfort_tests")
	var saved := repository.save_campaign(manager.campaign, 1, game)
	_check(bool(saved.get("success", false)), "Campanha salva com redução visual ativa.")
	if saved.get("success", false):
		var loaded := repository.load_campaign(manager.campaign.campaign_id, 1)
		_check(bool(loaded.get("success", false)) and bool(comfort.get("enabled"))
			and str(palette.get("palette_id")) == "azul",
			"Carregar slot não substitui tema ou preferência de redução.")
	var rain := game.get_node("GreySkyRain") as GreySkyRain
	var sky := game.get_node("ParallaxBackground") as PPPParallaxBackground
	sky.active_set_path = "res://sprites/background/fundosparalax/cinzento_0001"
	rain._process(0.0)
	var reduced_drops := rain._drops.size()
	comfort.call("set_enabled", false, false)
	rain._process(0.0)
	var normal_drops := rain._drops.size()
	_check(reduced_drops > 0 and normal_drops > reduced_drops * 2,
		"Chuva reduzida preserva as três camadas com densidade bem menor.")
	comfort.call("set_enabled", true, false)
	var glitch := game.get_node("GlitchVisualController") as GlitchVisualController
	glitch.start_effect()
	_check(float(glitch._pixel_material.get_shader_parameter("amount")) == 4.0 and
		float(glitch._sky_pixel_material.get_shader_parameter("amount")) == 2.0 and
		glitch._actor_reduced_pixel_material.shader ==
		load("res://shaders/glitch_scene_pixelate.gdshader"),
		"Glitch reduzido permanece perceptível, mas usa pixelização estática.")
	_check(glitch.active and not glitch._world_layer.visible and
		not glitch._flash_layer.visible and not glitch._terminal_layer.visible and
		glitch._original_ui_materials.is_empty() and glitch._original_buttons.is_empty(),
		"Glitch reduzido pixeliza apenas a cena sem tocar na UI ou piscar.")
	glitch._process(200.0)
	_check(not glitch._flash_layer.visible,
		"Temporizador do Glitch não reativa flashes na redução visual.")
	var pause: CampaignPauseMenu = (game.get_node("CampaignTopBar") as CampaignTopBar).pause_menu
	pause.open()
	pause.open_save()
	pause._open_settings()
	_check(not pause._settings_menu.visible,
		"Configurações não se sobrepõem ao seletor de save na pausa.")
	pause._save_panel.close()
	pause._open_settings()
	_check(paused and pause._settings_menu.visible and
		pause._settings_menu._reduce_control.button_pressed,
		"A configuração aparece ativa também no menu de pausa.")
	pause._settings_menu._reduce_control.button_pressed = false
	_check(not bool(comfort.get("enabled")) and glitch._world_layer.visible,
		"Desligar a opção na pausa restaura o Glitch normal sem mudar a partida.")
	pause._settings_menu._reduce_control.button_pressed = true
	_check(bool(comfort.get("enabled")) and not glitch._world_layer.visible
		and not glitch._flash_layer.visible and glitch._original_buttons.is_empty()
		and glitch._original_ui_materials.is_empty(),
		"Ligar no meio do Glitch remove imediatamente flashes e mudanças de UI.")
	pause._settings_menu._reduce_control.button_pressed = false
	_check(float(comfort.call("cap_light_energy", 0.5)) == 0.5 and
		float(comfort.call("cap_shadow_alpha", 0.9)) == 0.9,
		"Sem redução, os efeitos mantêm seus valores originais.")
	pause.close()
	glitch.stop_effect()
	# O clique real persiste a escolha; restaurar a preferência do usuário.
	comfort.call("set_enabled", original_comfort)
	palette.call("set_palette", original_palette, false)
	_check(is_equal_approx(float(scale.get("ui_factor")), original_scale),
		"Abrir Configurações na pausa não modifica a escala.")
	game.queue_free()
	await process_frame
	print("PPP_VISUAL_COMFORT_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
