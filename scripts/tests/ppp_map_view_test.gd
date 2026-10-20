extends SceneTree

## Rodar com: godot --headless --path . --script res://scripts/tests/ppp_map_view_test.gd
var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	# Sem janela, o Godot usa 64×64; teste o tamanho real da cena-modelo.
	root.size = Vector2i(1152, 648)
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	check(scene != null, "teste.tscn precisa usar PPPMapView")
	if scene == null:
		quit(1)
		return
	root.add_child(scene)
	await process_frame
	var anchor := scene.get_node_or_null("PontoZero") as Node2D
	var hexes := scene.get_node_or_null("MapRoot/Hexes") as Node2D
	var start_zone := scene.get_node_or_null("MapRoot/StartZone") as Node2D
	var ground := scene.get_node_or_null("MapRoot/Ground") as Node2D
	var background := scene.get_node_or_null("MapRoot/Background") as Sprite2D
	var depth := scene.get_node_or_null("MapRoot/DepthSorted") as PPPDepthLayer
	var parallax := scene.get_node_or_null("ParallaxBackground") as PPPParallaxBackground
	check(anchor != null, "PontoZero deve existir")
	check(hexes != null and hexes.get_child_count() == 40, "Devem existir 40 hexágonos")
	check(start_zone != null and start_zone.get_child_count() == 3, "StartZone deve ter 3 posições")
	check(ground != null and ground.get_child_count() >= 1, "O chão deve se repetir até cobrir a largura visível")
	check(background != null and background.texture != null, "O cenário do distrito deve aparecer atrás do chão")
	check(depth != null and depth.y_sort_enabled and depth.z_index > hexes.z_index,
		"Visuais do mundo ficam em camada ordenada por posição vertical, à frente dos hexes")
	if depth != null:
		var future_decoration := Node2D.new()
		depth.add_world_visual(future_decoration, Vector2(100, 300))
		check(future_decoration.get_parent() == depth \
			and future_decoration.position == Vector2(100, 300) \
			and future_decoration.z_index == 0,
			"Futuras decorações/entidades entram na mesma ordenação pela base")
	check(parallax != null and parallax.layer < 0 and parallax.get_child_count() >= 4,
		"Céu em camadas deve ficar atrás de todo o mapa")
	if anchor != null and hexes != null:
		var first_hex := hexes.get_node_or_null("Hex_0_0") as Node2D
		var next_hex := hexes.get_node_or_null("Hex_1_0") as Node2D
		var lower_hex := hexes.get_node_or_null("Hex_0_1") as Node2D
		check(first_hex != null, "O primeiro hexágono deve existir")
		if first_hex != null:
			var viewport_size := scene.get_viewport_rect().size
			var expected_first := anchor.global_position + Vector2(
				(viewport_size.x - PPPMapView.REFERENCE_VIEWPORT.x) * 0.5,
				viewport_size.y - PPPMapView.REFERENCE_VIEWPORT.y \
					+ PPPMapView.MAP_VERTICAL_NUDGE
			)
			check(first_hex.global_position.is_equal_approx(expected_first),
				"PontoZero ancora o primeiro hex; outra resolução só desloca o conjunto")
			var outline := first_hex.get_node_or_null("Outline") as Sprite2D
			check(outline != null and outline.scale.is_equal_approx(HexRenderer.REFERENCE_SPRITE_SCALE),
				"O hex deve usar a escala visual configurada")
			if outline != null:
				check((Vector2(outline.texture.get_size()) * outline.scale).is_equal_approx(Vector2(92, 82)),
					"O hex de teste deve medir exatamente 92 × 82 px")
		if first_hex != null and next_hex != null:
			check(is_equal_approx(next_hex.position.x - first_hex.position.x, 93.0),
				"Passo horizontal médio arredondado deve ser 93 px")
		if first_hex != null and lower_hex != null:
			check((lower_hex.position - first_hex.position).is_equal_approx(Vector2(47, 55)),
				"Linha seguinte deve descer 55 px e deslocar 47 px")
	for hex in hexes.get_children():
		var hex_node := hex as Node2D
		var outline := hex_node.get_node_or_null("Outline") as Sprite2D
		var size := Vector2(outline.texture.get_size()) * outline.scale
		var bounds := Rect2(hex_node.global_position - size * 0.5, size)
		check(Rect2(Vector2.ZERO, scene.get_viewport_rect().size).encloses(bounds),
			"Todos os hexágonos de 92 × 82 px devem caber na tela de referência")
	if ground != null and ground.get_child_count() >= 1:
		var first_tile := ground.get_child(0) as Sprite2D
		var last_tile := ground.get_child(ground.get_child_count() - 1) as Sprite2D
		var tile_size := Vector2(first_tile.texture.get_size()) * first_tile.scale
		var viewport_size := scene.get_viewport_rect().size
		var ground_top := first_tile.global_position.y - tile_size.y * 0.5
		for hex in hexes.get_children():
			var hex_node := hex as Node2D
			var outline := hex_node.get_node("Outline") as Sprite2D
			var hex_top := hex_node.global_position.y \
				- float(outline.texture.get_height()) * outline.scale.y * 0.5
			check(hex_top >= ground_top,
				"O hex %s invade a fachada em %.1f px" % [hex_node.name, ground_top - hex_top])
		for marker in start_zone.get_children():
			var start := marker as Sprite2D
			var start_top := start.global_position.y \
				- float(start.texture.get_height()) * start.scale.y * 0.5
			check(start_top >= ground_top,
				"A StartZone deve ficar inteira sobre o chão, nunca na fachada")
		check(first_tile.global_position.x - tile_size.x * 0.5 <= 1.0,
			"O chão deve começar na borda esquerda")
		check(last_tile.global_position.x + tile_size.x * 0.5 >= viewport_size.x,
			"O chão deve chegar até a borda direita")
		check(first_tile.global_position.y + tile_size.y * 0.5 >= viewport_size.y + 1.0,
			"O chão deve ultrapassar a borda inferior sem deixar faixa cinza")
		if ground.get_child_count() >= 2:
			var second_tile := ground.get_child(1) as Sprite2D
			check(is_equal_approx(second_tile.global_position.x - first_tile.global_position.x, 440.0),
				"O espaçamento dos tapetes segue a média do modelo")
		check(tile_size.y < viewport_size.y and first_tile.global_position.y > viewport_size.y * 0.5,
			"O chão deve ser uma faixa inferior, sem ocupar o fundo inteiro")
	var generated := HexGrid.new()
	generated.generate_ppp_exploration_map()
	generated.ppp_background_path = "res://sprites/background/cena_centro_0002.png"
	generated.ppp_parallax_path = "res://sprites/background/fundosparalax/noite_0001"
	generated.ppp_aura_parallax_path = "res://sprites/background/fundosparalax/cinzento_0002"
	generated.ppp_snow_parallax_path = "res://sprites/background/fundosparalax/nevasca_0001"
	generated.ppp_parallax_filter = PPPParallaxBackground.SkyFilter.RED
	scene.show_generated_map(generated)
	check(background.texture.resource_path == generated.ppp_background_path,
		"Exibir mapa gerado deve usar seu cenário persistido, não sortear novamente")
	# Todas as fachadas têm margens transparentes diferentes na imagem. Nenhuma
	# delas deve deixar o céu aparecer entre a base das casas e o asfalto.
	for file in DirAccess.get_files_at("res://sprites/background"):
		if not file.begins_with("cena_") or not file.ends_with(".png"):
			continue
		generated.ppp_background_path = "res://sprites/background/" + file
		scene.show_generated_map(generated)
		var ground_tile := ground.get_child(0) as Sprite2D
		var ground_top := ground_tile.global_position.y \
			- float(ground_tile.texture.get_height()) * ground_tile.scale.y * 0.5
		var bottom_row := scene._visible_background_bottom_row(background.texture)
		var facade_bottom := background.global_position.y + (float(bottom_row + 1) \
			- float(background.texture.get_height()) * 0.5) * background.scale.y
		check(absf(facade_bottom - ground_top - PPPMapView.GROUND_BACKGROUND_OVERLAP) < 0.05,
			"O cenário %s precisa encontrar o chão com 2 px de sobreposição" % file)
		var horizontal := scene._visible_facade_horizontal_bounds(background.texture)
		var left_edge := background.global_position.x + (float(horizontal.x) \
			- float(background.texture.get_width()) * 0.5) * background.scale.x
		var right_edge := background.global_position.x + (float(horizontal.y + 1) \
			- float(background.texture.get_width()) * 0.5) * background.scale.x
		check(left_edge <= -PPPMapView.BACKGROUND_SIDE_BLEED + 0.1 \
			and right_edge >= scene.get_viewport_rect().size.x \
				+ PPPMapView.BACKGROUND_SIDE_BLEED - 0.1,
			"As casas de %s devem ultrapassar as duas margens da câmera" % file)
	generated.ppp_background_path = "res://sprites/background/cena_centro_0002.png"
	scene.show_generated_map(generated)
	check(parallax.active_set_path == generated.ppp_parallax_path and \
		parallax.active_filter == PPPParallaxBackground.SkyFilter.RED,
		"Céu e filtro do mapa devem persistir ao redesenhar")
	var first_sky := parallax.get_node_or_null("SkyLayer_1") as Parallax2D
	if first_sky != null:
		var sky_sprite := first_sky.get_child(0) as Sprite2D
		check(is_equal_approx(sky_sprite.position.y,
			float(scene.get_viewport_rect().size.y) * (0.5 - PPPParallaxBackground.CLOUD_LIFT_RATIO)),
			"Nuvens sobem, permanecendo atrás das casas e acima do chão")
		var mirror := first_sky.get_node_or_null("MirroredClouds") as Sprite2D
		check(first_sky.autoscroll.x < 0.0 and mirror != null and mirror.flip_h \
			and is_equal_approx(first_sky.repeat_size.x,
				float(sky_sprite.texture.get_width()) * sky_sprite.scale.x * 2.0),
			"Nuvens devem mover-se e repetir sem emenda visível")
	scene.set_visual_effects(CampaignState.AURA_FUNEBRE_EVENT_ID, false)
	check(parallax.active_set_path == generated.ppp_aura_parallax_path and \
		parallax.active_filter == PPPParallaxBackground.SkyFilter.NONE and \
		parallax.get_node_or_null("SkyFilter") != null,
		"Áurea Fúnebre deve trocar imediatamente para céu cinzento e escuro")
	var lightning_layer := parallax.get_node_or_null("SkyLayer_4") as Parallax2D
	var lightning_wait := lightning_layer.get_node_or_null("LightningWait") as Timer \
		if lightning_layer != null else null
	check(lightning_layer != null and lightning_wait != null \
		and not lightning_layer.visible and lightning_wait.wait_time >= 20.0 \
		and lightning_wait.wait_time <= 40.0,
		"O raio de cinzento_0002 inicia oculto e aguarda entre 20 e 40 segundos.")
	if lightning_layer != null and lightning_wait != null:
		parallax._show_lightning(lightning_layer, lightning_wait)
		check(lightning_layer.visible, "O raio aparece quando seu intervalo termina.")
		await create_timer(0.28).timeout
		check(not lightning_layer.visible and lightning_wait.time_left > 0.0,
			"O raio dura 1/4 segundo e volta a aguardar o próximo intervalo.")
	scene.set_visual_effects(CampaignState.NEVASCA_EVENT_ID, false)
	check(parallax.active_set_path == generated.ppp_snow_parallax_path and \
		parallax.get_node_or_null("SkyFilter") != null,
		"Nevasca ativada depois deve mostrar suas nuvens de tempestade")
	scene.set_visual_effects(CampaignState.NEVASCA_EVENT_ID, true)
	check(parallax.active_set_path == generated.ppp_snow_parallax_path and \
		parallax.active_filter == PPPParallaxBackground.SkyFilter.INFERNAL_RED,
		"Portais Infernais sobrepõe o filtro sem substituir as nuvens")
	scene.set_visual_effects(CampaignState.NEVASCA_EVENT_ID, false)
	check(parallax.active_filter == PPPParallaxBackground.SkyFilter.NONE,
		"Fim da Rodada remove só o vermelho infernal")
	scene.set_visual_effects(&"", false)
	check(parallax.active_set_path == generated.ppp_parallax_path,
		"Ao virar o Dia, volta o céu sorteado para o mapa")
	var top_bar := scene.get_node("CampaignTopBar") as CampaignTopBar
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	gerencia.campaign.current_map = generated
	scene.set_map_mode(HexGrid.PPPMapMode.COMBAT)
	top_bar.refresh()
	check(top_bar.mode_label.text.contains("COMBATE") and top_bar.combat_border.visible \
		and (top_bar.mode_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color.r > 0.9,
		"Combate marca a faixa superior e a borda da cena em vermelho.")
	check(top_bar.combat_border.get_global_rect().position.is_equal_approx(Vector2.ZERO) \
		and top_bar.combat_border.size.is_equal_approx(scene.get_viewport_rect().size) \
		and top_bar.combat_border.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"A moldura vermelha circunda a área visível sem bloquear cliques.")
	scene.set_map_mode(HexGrid.PPPMapMode.EXPLORATION)
	top_bar.refresh()
	check(top_bar.mode_label.text.contains("EXPLORAÇÃO") and not top_bar.combat_border.visible,
		"Ao sair do Combate, a moldura vermelha desaparece.")

	if failures == 0:
		print("PPP MapView: hexágonos de 92 × 82 px, chão repetido e cenário passaram")
	else:
		push_error("PPP MapView: %d teste(s) falharam" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
