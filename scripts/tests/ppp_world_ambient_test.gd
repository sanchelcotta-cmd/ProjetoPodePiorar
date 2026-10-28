extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var sky := scene.get_node("ParallaxBackground") as PPPParallaxBackground
	var ambient := scene.get_node("WorldAmbientLighting") as WorldAmbientLighting
	var sky_light := scene.get_node("SkyFillLight") as DirectionalLight2D
	var shadows := scene.get_node("MapRoot/ActorGroundShadows") as ActorGroundShadows
	var rain := scene.get_node("GreySkyRain") as GreySkyRain
	ambient.transition_seconds = 0.0
	_check(shadows.z_index < scene.get_node("MapRoot/Hexes").z_index
		and shadows._falloff != null,
		"Elipses de sombra ficam abaixo dos hexes e usam borda suave.")
	var shadow_mask := shadows._falloff.get_image()
	_check(shadow_mask.get_pixel(48, 48).a > 0.9
		and shadow_mask.get_pixel(0, 0).a < 0.01,
		"Máscara da sombra tem centro opaco e cantos transparentes.")
	_check(ambient.color.is_equal_approx(Color.WHITE),
		"Manhã mantém as cores originais do mapa.")
	_check(sky_light.energy > 0.0 and sky_light.energy < 0.15,
		"Luz do céu é leve e pertence ao canvas do cenário.")
	gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.AFTERNOON
	await process_frame
	_check(ambient.color.is_equal_approx(Color.WHITE.lerp(
		ambient.afternoon_base, ambient.afternoon_strength)),
		"Tarde aplica a cor quente em intensidade leve.")
	gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
	await process_frame
	_check(ambient.color.is_equal_approx(Color.WHITE.lerp(
		ambient.night_base, ambient.night_strength)),
		"Noite aplica o roxo escuro sem escurecimento total.")
	sky.active_set_path = "res://sprites/background/fundosparalax/cinzento_0001"
	await process_frame
	_check(ambient.color.is_equal_approx(Color.WHITE.lerp(
		ambient.grey_base, ambient.grey_strength)),
		"Céu cinzento prevalece sobre a cor do período.")
	_check(rain._raining and not rain._drops.is_empty(),
		"Chuva inicia somente com céu cinzento.")
	var roof_y := rain._roof_y_at_x(500.0)
	_check(is_finite(roof_y) and roof_y > 0.0 and roof_y < 648.0,
		"A máscara de transparência encontra o telhado das casas.")
	var roof_impact_x := 500.0 + 400.0 * 0.05 * rain.diagonal_drift
	var roof_impact_y := rain._roof_y_at_x(roof_impact_x)
	rain._drops = [{"x": 500.0, "y": roof_impact_y - 4.0,
		"speed": 400.0, "length": 9.0, "alpha": 0.25,
		"ground_y": 640.0, "layer": GreySkyRain.LAYER_ROOF,
		"at_surface": false}]
	rain._process(0.05)
	_check(rain._drops[0].at_surface \
		and is_equal_approx(rain._drops[0].y, roof_impact_y),
		"Gota fina para ao atingir o telhado, mesmo em trecho inclinado.")
	var actor := Node2D.new()
	actor.position = Vector2(900.0, 530.0)
	actor.add_to_group("map_entity_visual")
	scene.add_child(actor)
	rain._drops = [{"x": 900.0 - 400.0 * 0.05 * rain.diagonal_drift,
		"y": 380.0, "speed": 400.0, "length": 12.0, "alpha": 0.25,
		"ground_y": 640.0, "layer": GreySkyRain.LAYER_ENTITY,
		"at_surface": false}]
	rain._process(0.05)
	_check(rain._drops[0].at_surface and is_equal_approx(rain._drops[0].y, 385.0),
		"Gota da frente para ao atingir a silhueta de uma entidade.")
	rain._drops = [{"x": 900.0 - 400.0 * 0.05 * rain.diagonal_drift,
		"y": 380.0, "speed": 400.0, "length": 12.0, "alpha": 0.25,
		"ground_y": 420.0, "layer": GreySkyRain.LAYER_GROUND,
		"at_surface": false}]
	rain._process(0.1)
	_check(rain._drops[0].at_surface and is_equal_approx(rain._drops[0].y, 420.0),
		"Camada do chão atravessa telhados e entidades e para no Ground.")
	var foot_image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	foot_image.fill(Color.TRANSPARENT)
	foot_image.fill_rect(Rect2i(12, 8, 40, 46), Color.WHITE)
	var foot_frames := SpriteFrames.new()
	foot_frames.add_animation(&"idle")
	foot_frames.add_frame(&"idle", ImageTexture.create_from_image(foot_image))
	var foot_sprite := AnimatedSprite2D.new()
	foot_sprite.name = "AnimatedSprite2D"
	foot_sprite.sprite_frames = foot_frames
	foot_sprite.animation = &"idle"
	foot_sprite.position = Vector2(0.0, -32.0)
	actor.add_child(foot_sprite)
	_check(is_equal_approx(shadows._visual_feet(actor).y,
		shadows.to_local(actor.global_position).y - 10.0)
		and is_equal_approx(shadows._shadow_half_width(actor), 26.0),
		"Sombra ancora na base opaca dos pés, não no quadrado transparente do sprite.")
	actor.queue_free()
	var inclined := false
	var layers := {GreySkyRain.LAYER_ROOF: false,
		GreySkyRain.LAYER_ENTITY: false,
		GreySkyRain.LAYER_GROUND: false}
	rain._drops = []
	for index in 100:
		rain._drops.append(rain._new_drop(Vector2(1152.0, 648.0), true))
	for drop in rain._drops:
		layers[drop.layer] = true
		if drop.layer == GreySkyRain.LAYER_ROOF and drop.length <= 11.0:
			inclined = true
	_check(inclined and rain.diagonal_drift >= 0.5 and \
		layers[GreySkyRain.LAYER_ENTITY] and layers[GreySkyRain.LAYER_GROUND],
		"Três camadas presentes; parte da chuva é fina, inclinada e para em telhados.")
	sky.active_set_path = "res://sprites/background/fundosparalax/nevasca_0001"
	await process_frame
	_check(not rain._raining and rain._drops.is_empty(),
		"Nevasca não ativa a chuva de céu cinzento.")
	scene.queue_free()
	await process_frame
	if failures == 0:
		print("WORLD_AMBIENT_TEST_OK")
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
