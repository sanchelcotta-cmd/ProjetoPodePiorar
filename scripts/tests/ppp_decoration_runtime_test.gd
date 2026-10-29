extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
	]
	_check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"Campanha e primeiro mapa iniciam.")
	await process_frame
	var decoration := scene.get_node("MapRoot/DepthSorted/Decorations") as PPPDecorationView
	_check(decoration != null, "Nó de decoração existe.")
	if decoration != null:
		var depth := decoration.get_parent() as Node2D
		var hexes := scene.get_node("MapRoot/Hexes") as Node2D
		_check(depth.z_index - 2 > hexes.z_index,
			"Objetos de fachada continuam acima dos hexes.")
		_check(is_equal_approx(decoration._scale_for("banco"),
			PPPDecorationView.SMALL_SCALE * 2.0),
			"Banquinho avulso e do conjunto têm o dobro da escala anterior.")
		_check(is_equal_approx(decoration._scale_for("balde"),
			PPPDecorationView.SMALL_SCALE),
			"Balde conserva a escala anterior.")
		var pair_rng := RandomNumberGenerator.new()
		decoration._render_entry({"kind": "par", "group": "A",
			"x": 0.0, "y": 0.0}, pair_rng)
		decoration._refresh_ground_shadows(gerencia.campaign.round_period, false)
		var pair := decoration.get_child(decoration.get_child_count() - 1) as Node2D
		if pair != null and pair.get_child_count() == 3:
			var bench := pair.get_child(0) as Sprite2D
			var bucket := pair.get_child(1) as Sprite2D
			var pair_shadow := pair.get_node("GroundShadow") as Sprite2D
			_check(pair_shadow != null and pair_shadow.scale.x > pair_shadow.scale.y
				and pair_shadow.position.y - pair_shadow.scale.y * 48.0 < 0.0
				and pair_shadow.position.y + pair_shadow.scale.y * 48.0 > 0.0,
				"Sombra oval do conjunto cruza a base, atrás e à frente.")
			_check(is_equal_approx(bench.scale.x,
				PPPDecorationView.SMALL_SCALE * 2.0),
				"Banquinho dentro do conjunto também dobra.")
			_check(is_equal_approx(bucket.scale.x,
				PPPDecorationView.SMALL_SCALE),
				"Balde dentro do conjunto não aumenta.")
			var bench_right := bench.position.x \
				+ bench.texture.get_width() * bench.scale.x * 0.5
			var bucket_left := bucket.position.x \
				- bucket.texture.get_width() * bucket.scale.x * 0.5
			_check(is_equal_approx(bucket_left - bench_right, 8.0),
				"Conjunto mantém folga entre banco ampliado e balde.")
		else:
			_check(false, "Conjunto renderiza banquinho e balde.")
		var grid := scene.grid
		var background := scene.get_node("MapRoot/Background") as Sprite2D
		var copies := scene.get_node("MapRoot/BackgroundCopies") as Node2D
		var sample_with_trees := -1
		var maximum_trees := 0
		for seed in 48:
			grid.ppp_decoration_seed = seed + 1
			grid.ppp_anomaly_planned = false
			grid.ppp_anomaly_kind = &""
			decoration.rebuild(grid, background, copies,
				decoration._ground_top, decoration._screen_size)
			var group_b := 0
			var trees := 0
			for item in decoration.get_children():
				if not item.has_meta("decoration_group") \
						or str(item.get_meta("decoration_group")) != "B":
					continue
				group_b += 1
				var kind := str(item.get_meta("decoration_kind"))
				if kind in PPPDecorationView.TREE_TYPES:
					trees += 1
					_check(decoration._tree_base_clear(item.position.x,
						item.position.y, kind),
						"A base de %s não ocupa nenhum hex." % kind)
			_check(group_b <= 4, "Grupo B tem no máximo quatro elementos.")
			maximum_trees = maxi(maximum_trees, trees)
			if trees >= 2:
				sample_with_trees = seed + 1
		_check(sample_with_trees > 0, "Há mapa com mais de uma árvore.")
		_check(maximum_trees == 4, "A quarta árvore pode aparecer cortada pela borda.")
		var saved_background_path: String = grid.ppp_background_path
		var saved_texture := background.texture
		var map_root := scene.get_node("MapRoot") as Node2D
		var facade_left: float = decoration._screen_size.x * 0.27 - map_root.position.x
		var facade_right: float = decoration._screen_size.x * 0.93 - map_root.position.x
		var local_ground: float = decoration._ground_top - map_root.position.y
		for center_path in ["res://sprites/background/cena_centro_0001.png",
				"res://sprites/background/cena_centro_0002.png"]:
			grid.ppp_background_path = center_path
			background.texture = load(center_path)
			var doors := decoration._door_segments(background, copies)
			_check(not doors.is_empty(), "Fachada do Centro tem portas marcadas.")
			for seed in 40:
				var rng := RandomNumberGenerator.new()
				rng.seed = seed + 1
				var entries: Array[Dictionary] = []
				decoration._build_posts(entries, rng, "centro",
					facade_left, facade_right, local_ground)
				decoration._build_facade_items(entries, rng, "centro",
					facade_left, facade_right, local_ground, doors)
				var trash_kind := ""
				var trash_count := 0
				for entry in entries:
					if str(entry["group"]) == "A":
						var width := decoration._width_for(str(entry["kind"]))
						if str(entry["kind"]) == "par":
							width = decoration._width_for("banco") \
								+ decoration._width_for("balde") + 8.0
						for segment in doors:
							_check(float(entry["x"]) + width * 0.5 + 13.0 < segment.x \
								or float(entry["x"]) - width * 0.5 - 13.0 > segment.y,
								"Grupo A deixa todas as portas livres.")
					if str(entry["kind"]) in ["lixeira_brasileira", "lixeira_latao",
							"lixeira_simples"]:
						trash_count += 1
						if trash_kind.is_empty():
							trash_kind = str(entry["kind"])
						_check(str(entry["kind"]) == trash_kind,
							"Lixeiras do mesmo mapa usam o mesmo modelo.")
				_check(trash_count >= 1 and trash_kind != "lixeira_simples",
					"Centro sempre tem lixeira tradicional ou latão.")
		grid.ppp_background_path = saved_background_path
		background.texture = saved_texture
		if sample_with_trees > 0:
			grid.ppp_decoration_seed = sample_with_trees
			decoration.rebuild(grid, background, copies,
				decoration._ground_top, decoration._screen_size)
			var post_shadows: Array[Sprite2D] = []
			var tree_shadow_count := 0
			for item in decoration.get_children():
				if not item.has_meta("decoration_group"):
					continue
				var group := str(item.get_meta("decoration_group"))
				_check(item.z_index == (-2 if group == "A" else -1 if group == "B" else 0),
					"Fachada, árvores e postes usam estratos distintos.")
				var shadow := item.get_node_or_null("GroundShadow") as Sprite2D
				_check(shadow != null and shadow.scale.x > shadow.scale.y
					and shadow.modulate.a > 0.0 and shadow.modulate.a < 0.75,
					"Cada decoração tem sombra oval mais fraca que a dos personagens.")
				if str(item.get_meta("decoration_group")) == "B":
					tree_shadow_count += 1
					_check(shadow != null and shadow.scale.x * 96.0 >= \
						decoration._visible_tree_width(item) * 0.98,
						"Sombra de árvore acompanha a largura da copa.")
				if str(item.get_meta("decoration_group")) == "C":
					post_shadows.append(shadow)
			_check(tree_shadow_count >= 2 and post_shadows.size() in [3, 4],
				"Árvores e postes receberam sombras em suas bases.")
			var previous_period := gerencia.campaign.round_period
			gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.AFTERNOON
			decoration._process(0.0)
			for shadow in post_shadows:
				_check(shadow.visible, "Poste conserva sombra à tarde.")
			gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
			decoration._process(0.0)
			for shadow in post_shadows:
				_check(not shadow.visible, "Poste não projeta sombra de base à noite.")
			gerencia.campaign.round_period = previous_period
			decoration._process(0.0)
			var tree_positions: Array[Vector2] = []
			for item in decoration.get_children():
				if item.has_meta("decoration_kind") and \
						str(item.get_meta("decoration_kind")) in PPPDecorationView.TREE_TYPES:
					tree_positions.append(item.position)
			scene._set_camera_level(3)
			_check(scene.force_decoration_anomaly(&"anomalia_lixeira"),
				"Depuração insere a lixeira mesmo com câmera ampliada.")
			var trees_after: Array[Vector2] = []
			var anomaly_bin: Node2D = null
			for item in decoration.get_children():
				if item.has_meta("decoration_kind") and \
						str(item.get_meta("decoration_kind")) in PPPDecorationView.TREE_TYPES:
					trees_after.append(item.position)
				if item.has_meta("anomaly") and \
						str(item.get_meta("anomaly")) == "anomalia_lixeira":
					anomaly_bin = item as Node2D
			_check(tree_positions == trees_after,
				"Forçar anomalia não move nem reordena as árvores do mapa.")
			if anomaly_bin != null:
				var bin_sprite := anomaly_bin.get_child(0) as AnimatedSprite2D
				var bin_frame := bin_sprite.sprite_frames.get_frame_texture(
					&"move", 0).get_image().get_used_rect()
				var bin_foot := bin_sprite.to_global(Vector2(0,
					float(bin_frame.end.y) - bin_sprite.sprite_frames.get_frame_texture(
					&"move", 0).get_height() * 0.5)).y
				var foot_offset := bin_foot - scene.get_ground_screen_top()
				_check(foot_offset > 10.0 and foot_offset < 35.0,
					"Lixeira anômala mantém a base sobre a borda do ground com zoom.")
			else:
				_check(false, "Lixeira forçada produz um sprite anômalo.")
			scene._set_camera_level(1)
			_check(scene.force_decoration_anomaly(&"anomalia_arvore"),
				"Anomalia de árvores pode ser forçada.")
			for item in decoration.get_children():
				if item.has_meta("decoration_kind") and \
						str(item.get_meta("decoration_kind")) in PPPDecorationView.TREE_TYPES:
					_check(item.has_meta("anomaly") and \
						str(item.get_meta("anomaly")) == "anomalia_arvore" \
						and item.get_node_or_null("BrasasRoxas") != null,
						"Todas as árvores queimam e têm brasas.")
		print("GROUND_TOP=", scene.get_ground_screen_top(),
			" ROOT=", (scene.get_node("MapRoot") as Node2D).position)
		for kind in ["lixeira_latao", "saco", "poste_tradicional", "poste_historico"]:
			var texture := decoration._texture(kind) as Texture2D
			print("ASSET=", kind, " size=", texture.get_size(),
				" used=", texture.get_image().get_used_rect())
			if kind.begins_with("poste_"):
				var image := texture.get_image()
				var left := image.get_width()
				var right := 0
				for y in range(image.get_height() - 24, image.get_height()):
					for x in image.get_width():
						if image.get_pixel(x, y).a > 0.1:
							left = mini(left, x)
							right = maxi(right, x)
				print("POST_BASE=", kind, " pixels=", left, "..", right)
		var layer_y := {}
		for entry in decoration.get_children():
			if entry is Node2D:
				print("DECOR=", entry.name, " pos=", (entry as Node2D).global_position)
				if entry.has_meta("decoration_group"):
					var group := str(entry.get_meta("decoration_group"))
					layer_y[group] = (entry as Node2D).position.y
					_check(not (entry as Node2D).y_sort_enabled,
						"Sprite decorativo é ordenado pela base, não pelo centro.")
		if layer_y.has_all(["A", "B", "C"]):
			_check(layer_y["A"] < layer_y["B"] and layer_y["B"] < layer_y["C"],
				"Postes ficam diante das árvores, e árvores diante da fachada.")
		_check(gerencia.campaign.day == 1,
			"Todas as anomalias são forçadas para teste ainda no dia 1.")
		for kind in [&"anomalia_lixo", &"anomalia_lixeira", &"anomalia_arvore",
				&"anomalia_poste", &"anomalia_galo", &"anomalia_ovni"]:
			_check(scene.force_decoration_anomaly(kind), "Forçar %s funciona." % kind)
			if kind == &"anomalia_lixeira":
				var trash_model := ""
				for item in decoration.get_children():
					if not item.has_meta("decoration_kind"):
						continue
					var item_kind := str(item.get_meta("decoration_kind"))
					if item_kind not in PPPDecorationView.TRASH_TYPES:
						continue
					if trash_model.is_empty():
						trash_model = item_kind
					_check(item_kind == trash_model,
						"Duende forçado não mistura modelos de lixeira.")
			if kind == &"anomalia_poste":
				_check(decoration._texture("anomalia_poste").resource_path \
					== "res://sprites/decoration/anomalia_poste_olho_2.0_1x.png",
					"O poste usa o spritesheet 2.0 indicado pelo artista.")
				var post_count := decoration._post_anomaly_roots.size()
				_check(post_count in [3, 4],
					"Todos os postes entram na mesma anomalia.")
				var period_before_post := gerencia.campaign.round_period
				gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.NIGHT
				decoration._process(0.0)
				for effect in decoration._post_effects:
					_check((effect["light"] as PointLight2D).enabled
						and not (effect["light"] as PointLight2D).color.is_equal_approx(
							PPPDecorationView.ANOMALY_POST_LIGHT),
						"Antes do primeiro movimento, o poste mantém luz comum.")
				decoration._on_actor_moved(gerencia.campaign.active_entity_states[0],
					[Vector2i.ZERO], 1)
				_check(grid.ppp_anomaly_triggered,
					"Primeiro movimento ativa os postes anômalos.")
				for effect in decoration._post_effects:
					var light := effect["light"] as PointLight2D
					var cone := effect["cone"] as ColorRect
					_check(light.enabled and light.color.is_equal_approx(
						PPPDecorationView.ANOMALY_POST_LIGHT)
						and light.energy > 0.34
						and (cone.material as ShaderMaterial).get_shader_parameter(
							"beam_tint").is_equal_approx(Color("#f54560")),
						"Todos os postes com olho acesos usam feixe vermelho.")
				decoration.set_post_light_color(0, Color("#44f779"))
				_check((decoration._post_effects[0]["light"] as PointLight2D).color \
					.is_equal_approx(PPPDecorationView.ANOMALY_POST_LIGHT),
					"Depuração de cor não apaga a cor da anomalia ativa.")
				gerencia.campaign.round_period = PPPMapGenerator.RoundPeriod.MORNING
				decoration._process(0.0)
				_check(not (decoration._post_effects[0]["light"] as PointLight2D).enabled,
					"A luz vermelha do poste se apaga de dia.")
				gerencia.campaign.round_period = period_before_post
				decoration._process(0.0)
				for post in decoration._post_anomaly_roots:
					_check(post.get_node_or_null("DecorationSprite") == null,
						"O poste normal desaparece quando a mão surge.")
					_check(post.get_child_count() > 0 \
						and post.get_children().any(func(child: Node) -> bool:
							return child is AnimatedSprite2D),
						"Cada poste recebe a nova folha animada.")
			if kind == &"anomalia_galo":
				var galo := decoration._anomaly_visual
				var sprite := galo.get_child(0) as AnimatedSprite2D \
					if galo != null else null
				_check(sprite != null and (sprite.sprite_frames.get_frame_texture(
					&"move", 0) as AtlasTexture).region.size.y > 380.0
					and (sprite.sprite_frames.get_frame_texture(
					&"move", 0) as AtlasTexture).region.size.y < 400.0,
					"O galo mostra o início das pernas, mas recorta os pés.")
				_check(is_equal_approx(galo.global_position.y,
					decoration._ground_top - 150.0),
					"O galo sobe em relação à borda do ground.")
				var travel := decoration._galo_offscreen_bounds()
				scene._set_camera_level(0)
				var half_width := (sprite.sprite_frames.get_frame_texture(
					&"move", 0) as AtlasTexture).region.size.x \
					* sprite.scale.x * map_root.scale.x * 0.5
				_check(map_root.to_global(Vector2(travel.x, 0)).x + half_width < 0.0 \
					and map_root.to_global(Vector2(travel.y, 0)).x - half_width > root.size.x,
					"Galo inteiro some nas duas margens mesmo com zoom afastado.")
				scene._set_camera_level(1)
			if kind == &"anomalia_ovni":
				var ovni := decoration._anomaly_visual
				var city := scene.get_node("MapRoot/ScenicBackdrop") as Node2D
				var houses := scene.get_node("MapRoot/Background") as Sprite2D
				_check(ovni != null and ovni.get_parent() == decoration
					and not ovni.z_as_relative and ovni.z_index > city.z_index
					and ovni.z_index < houses.z_index,
					"O OVNI passa à frente da cidade e atrás das casas.")
			await process_frame
	root.remove_child(scene)
	scene.free()
	print("PPP decoração: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
