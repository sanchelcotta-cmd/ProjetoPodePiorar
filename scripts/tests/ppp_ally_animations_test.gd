extends SceneTree

const ORIENTATION_SCALE := preload("res://scripts/visuals/sprite_orientation_reference.gd")

## Cobertura visual: recorte dos novos sheets, cor fixa por instância e
## cinco duendes de cores embaralhadas sem substituir Informação.
var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var cats := load("res://resources/entities/entities_general/companions/gatinho_vira_lata.tres") as EntityData
	var dog := load("res://resources/entities/entities_general/companions/doguinho_caramelo.tres") as EntityData
	check(cats != null and cats.animation_variants.size() == 4,
		"O mesmo EntityData do Gatinho oferece as quatro cores.")
	check(dog != null and dog.animation_variants.size() == 1,
		"O Doguinho tem seu próprio conjunto de animações.")
	if cats == null or dog == null:
		quit(1)
		return
	for playable in CampaignState.new().get_playable_catalog():
		var playable_frames := playable.playable_animation.create_sprite_frames()
		for clip in playable_frames.get_animation_names():
			var expected_fps := 8.0 if String(clip).begins_with("attack_") else 6.0
			check(is_equal_approx(playable_frames.get_animation_speed(clip), expected_fps),
				"Cadência atual dos jogáveis corresponde ao tipo de animação.")
	var base_animation := (CampaignState.new().get_playable_catalog()[0] as EntityData).playable_animation
	var short_animation := PlayableAnimationData.new()
	short_animation.idle_sheet = base_animation.idle_sheet
	short_animation.walk_sheet = base_animation.walk_sheet
	short_animation.hurt_sheet = base_animation.hurt_sheet
	short_animation.blade_attack_sheet = base_animation.blade_attack_sheet
	short_animation.impact_attack_sheet = base_animation.impact_attack_sheet
	short_animation.ranged_attack_sheet = base_animation.ranged_attack_sheet
	short_animation.idle_frames = 5
	short_animation.walk_frames = 5
	short_animation.hurt_frames = 5
	short_animation.hurt_columns = base_animation.hurt_columns
	var short_frames := short_animation.create_sprite_frames()
	for clip in [&"idle", &"walk", &"hurt"]:
		check(short_frames.get_frame_count(clip) == 9
			and is_equal_approx(short_frames.get_animation_speed(clip), 6.0),
			"Cinco poses de jogável percorrem 1→2→3→4→5→4→3→2→1 a 6 fps.")
		for index in 5:
			var outward := short_frames.get_frame_texture(clip, index) as AtlasTexture
			var returning := short_frames.get_frame_texture(clip, 8 - index) as AtlasTexture
			check(outward != null and returning != null and outward.region == returning.region,
				"A volta da animação curta usa os mesmos quadros da ida.")
	for variant in cats.animation_variants:
		var frames := variant.create_sprite_frames()
		check(variant.normalize_to_first_idle_frame and variant.canvas_size == Vector2i(96, 96),
			"As quatro paletas usam o primeiro Idle como referência de tamanho.")
		var idle_used := frames.get_frame_texture(&"idle", 0).get_image().get_used_rect()
		check(idle_used.size.y > 0 and idle_used.size.y <= variant.subject_height,
			"Primeiro Idle define altura visual válida para cada gatinho.")
		for clip in [&"idle", &"idle_alt", &"walk", &"jump", &"carrying", &"attack"]:
			for pose_index in frames.get_frame_count(clip):
				var rendered := frames.get_frame_texture(clip,
					pose_index).get_image().get_used_rect()
				check(rendered.size.x <= variant.maximum_subject_width
					and rendered.size.y <= idle_used.size.y + 1
					and rendered.position.x >= 0 and rendered.position.y >= 0
					and rendered.end.x <= variant.canvas_size.x
					and rendered.end.y <= variant.canvas_size.y - 3,
					"%s/%s/%d respeita o tamanho do Idle sem recorte." % [
						variant.palette, clip, pose_index])
		var carrying_rects := variant._find_frames(variant.carrying_sheet.get_image())
		for pose_index in carrying_rects.size():
			var source_rect: Rect2i = carrying_rects[pose_index]
			var rendered := frames.get_frame_texture(&"carrying",
				pose_index).get_image().get_used_rect()
			var factor := minf(float(idle_used.size.y) / source_rect.size.y,
				float(variant.maximum_subject_width) / source_rect.size.x)
			var expected := Vector2i(roundi(source_rect.size.x * factor),
				roundi(source_rect.size.y * factor))
			check(abs(rendered.size.x - expected.x) <= 2
				and abs(rendered.size.y - expected.y) <= 2,
				"%s/Carrying/%d mantém cabeça e corpo completos." % [
					variant.palette, pose_index])
		for clip in frames.get_animation_names():
			check(is_equal_approx(frames.get_animation_speed(clip),
				2.0 if clip == &"carrying_held" else 6.0),
				"Gatinho usa 6 fps; transporte sustentado mantém cadência própria.")
		var original_idle_count := variant._find_frames(variant.idle_sheet.get_image()).size()
		if original_idle_count > 1 and original_idle_count < 6:
			check(frames.get_frame_count(&"idle") == original_idle_count * 2 - 1,
				"Idle curto percorre as poses de ida e volta.")
			for index in range(1, original_idle_count):
				check(frames.get_frame_texture(&"idle", index) == frames.get_frame_texture(
					&"idle", 2 * original_idle_count - 2 - index),
					"Idle curto espelha as poses no retorno.")
		check(frames.get_frame_count(&"carrying") == 7 \
			and frames.get_frame_count(&"carrying_pickup") == 3 \
			and frames.get_frame_count(&"carrying_held") == 2 \
			and frames.get_frame_count(&"carrying_landing") == 1,
			"Carregar o Gatinho separa pegar, transportar e pousar.")
		for index in 4:
			check(frames.get_frame_texture(&"carrying", index)
				== frames.get_frame_texture(&"carrying", 6 - index),
				"Quatro poses de carregar fazem ida e volta completa.")
		check(frames.get_animation_loop(&"carrying_held") \
			and not frames.get_animation_loop(&"carrying_pickup") \
			and frames.get_animation_speed(&"carrying_held") <= 2.0,
			"Apenas os quadros 2 e 3 alternam lentamente enquanto o gato é carregado.")
		check(frames.get_frame_texture(&"carrying_held", 0) \
			== frames.get_frame_texture(&"carrying", 1) \
			and frames.get_frame_texture(&"carrying_held", 1) \
			== frames.get_frame_texture(&"carrying", 2) \
			and frames.get_frame_texture(&"carrying_landing", 0) \
			== frames.get_frame_texture(&"carrying", 3),
			"O quadro 4 fica reservado exclusivamente ao pouso.")
		for clip in [&"idle", &"idle_alt", &"walk", &"jump", &"carrying", &"attack"]:
			check(frames.has_animation(clip) and frames.get_frame_count(clip) > 0,
				"Cada cor do Gatinho tem quadros de %s." % clip)
			if not frames.has_animation(clip):
				continue
			for index in frames.get_frame_count(clip):
				var frame := frames.get_frame_texture(clip, index)
				check(frame.get_size() == Vector2(96, 96)
					and frame.get_image().get_used_rect().end.y == 93,
					"Quadros de gato têm 96×96 e pés alinhados.")
	if "--preview" in OS.get_cmdline_user_args():
		var preview := Image.create_empty(96 * 4, 96 * 6, false, Image.FORMAT_RGBA8)
		preview.fill(Color(0.19, 0.21, 0.24))
		var clips := [&"idle", &"idle_alt", &"walk", &"jump", &"carrying", &"attack"]
		for column in cats.animation_variants.size():
			var sample := cats.animation_variants[column].create_sprite_frames()
			for row in clips.size():
				var picture := sample.get_frame_texture(clips[row], 0).get_image()
				preview.blend_rect(picture, Rect2i(0, 0, 96, 96),
					Vector2i(column * 96, row * 96))
		preview.save_png("user://ppp_cat_palette_preview.png")
	var dog_frames := dog.animation_variants[0].create_sprite_frames()
	check(dog_frames.get_frame_count(&"walk") == 8
		and dog_frames.get_frame_count(&"attack") == 9,
		"Doguinho usa oito poses Walk; cinco Attack fazem ida e volta.")
	for index in 5:
		check(dog_frames.get_frame_texture(&"attack", index)
			== dog_frames.get_frame_texture(&"attack", 8 - index),
			"Cinco poses de ataque do Doguinho fazem ida e volta completa.")
	check(not dog_frames.has_animation(&"carrying"),
		"Doguinho não recebe animação de carregar que não foi desenhada.")
	if "--preview" in OS.get_cmdline_user_args():
		var dog_preview := Image.create_empty(96 * 4, 80, false, Image.FORMAT_RGBA8)
		dog_preview.fill(Color(0.19, 0.21, 0.24))
		var dog_clips := [&"idle", &"idle_alt", &"walk", &"attack"]
		for column in dog_clips.size():
			dog_preview.blend_rect(dog_frames.get_frame_texture(dog_clips[column], 0).get_image(),
				Rect2i(0, 0, 96, 80), Vector2i(column * 96, 0))
		dog_preview.save_png("user://ppp_dog_palette_preview.png")
		var gnome_preview := Image.create_empty(64 * 5, 64, false, Image.FORMAT_RGBA8)
		gnome_preview.fill(Color(0.19, 0.21, 0.24))
		for column in 5:
			var gnome := load("res://resources/events/random_events/gnomes_3/duende_cor_%d.tres" % [column + 1]) as SpriteSheetAnimationData
			gnome_preview.blend_rect(gnome.create_sprite_frames().get_frame_texture(&"idle", 0).get_image(),
				Rect2i(0, 0, 64, 64), Vector2i(column * 64, 0))
		gnome_preview.save_png("user://ppp_gnome_palette_preview.png")
	for color in 5:
		var animation := load("res://resources/events/random_events/gnomes_3/duende_cor_%d.tres" % [color + 1]) as SpriteSheetAnimationData
		check(animation != null and animation.create_sprite_frames().get_frame_count(&"idle") == 6,
			"Cada duende usa seus seis quadros de 64×64.")

	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var campaign := gerencia.campaign
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
	]
	check(campaign.start_new_game(selected), "A campanha aceita três jogáveis distintos.")
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	var info := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	var source := load("res://resources/events/random_events/09-gnomos_do_caos_3.tres") as EventData
	var source_coord := Vector2i(1, 1)
	var info_coord := Vector2i(2, 2)
	grid.set_ppp_block(source_coord, HexGrid.PPPBlockType.EVENT, source)
	grid.set_ppp_block(info_coord, HexGrid.PPPBlockType.INFORMATION, info)
	campaign.current_map = grid
	scene.show_generated_map(grid)
	var cat := EntityState.from_playable_selection(cats, &"TestCat", EntityState.UNPLACED)
	var rng := RandomNumberGenerator.new()
	rng.seed = 456
	check(campaign.register_companion(campaign.active_entity_states[0], cat, rng),
		"Registrar o aliado sorteia sua aparência.")
	var initial_variant := cat.visual_variant_index
	check(initial_variant >= 0 and initial_variant < 4 and cat.get_animation_variant() != null,
		"O índice sorteado aponta para uma das quatro paletas.")
	var party := scene.get_node("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	check(party.visuals_by_id.has(cat.instance_id),
		"Gatinho recrutado aparece na camada das entidades.")
	cat.position = Vector2i(4, 3)
	var cat_visual := party.visuals_by_id[cat.instance_id] as CompanionActorVisual
	check(cat_visual.sprite.animation == &"walk" and cat_visual._motion != null,
		"Habilidade de revelar faz o Gatinho andar, nunca flutuar em Carrying.")
	await create_timer(0.3).timeout
	check(cat_visual.sprite.animation == &"walk",
		"Durante o trajeto por habilidade o Gatinho permanece em Walk.")
	check(cat.visual_variant_index == initial_variant,
		"Posicionar o Gatinho não muda sua cor.")
	cat.position = EntityState.UNPLACED
	check(cat.visual_variant_index == initial_variant,
		"Voltar a andar solto não sorteia outra cor.")
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var skills := scene.get_node("SkillManager") as SkillManager
	var cat_grant := skills.get_active_grants(cat)[0]
	var owner := campaign.active_entity_states[0]
	var old_turn_state := owner.turn_state
	owner.turn_state = EntityState.TurnState.INACTIVE
	check(hud._skill_is_available(cat, cat_grant),
		"O dono inativo ainda pode usar o Sexto-Sentido do Gatinho.")
	var loose_position := cat_visual.position
	var shadows := scene.get_node("MapRoot/ActorGroundShadows") as ActorGroundShadows
	cat_visual._stop_motion()
	cat_visual._jump_to(loose_position + Vector2(80.0, 0.0))
	await create_timer(0.20).timeout
	var jump_shadow := shadows._shadow_feet(cat_visual)
	check(cat_visual.jump_ground_shadow_position() != Vector2.INF \
		and jump_shadow.y > shadows._visual_feet(cat_visual).y + 8.0,
		"No salto, a sombra do Gatinho permanece projetada no ground.")
	cat_visual._stop_motion()
	cat_visual.position = loose_position
	check(cat_visual.jump_ground_shadow_position() == Vector2.INF,
		"Interromper o salto limpa a projeção antiga da sombra.")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(12.0, 10.0)
	hud._on_companion_map_input(press, cat)
	check(hud._pending_cat_visual == cat_visual and hud._drag_pet_visual == null,
		"Pressionar o Gatinho aguarda deslocamento antes de iniciar Carrying.")
	var cat_hit := hud._companion_map_hit_buttons.get(cat.instance_id) as Button
	check(hud._pending_cat_press.is_equal_approx(
		cat_hit.get_global_transform_with_canvas() * press.position),
		"Limiar de arrasto compara coordenadas de viewport com viewport.")
	# Em jogo, _process detecta o arrasto após 12 px com o botão pressionado.
	# O teste headless não injeta um cursor físico; reproduz a transição validada.
	check(cat_visual.begin_mouse_carry(), "Arrastar inicia Carrying após o clique.")
	check(cat_visual.suppress_ground_shadow() \
		and shadows._shadow_feet(cat_visual) == Vector2.INF,
		"Gatinho suspenso pelo cursor não desenha sombra.")
	hud._drag_pet_visual = cat_visual
	hud._drop_actor = cat
	hud._drop_grant = cat_grant
	hud._pending_cat_visual = null
	hud._pending_cat_actor = null
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(550.0, -500.0)
	hud._input(release)
	check(cat.position == EntityState.UNPLACED and hud.hex_choice.visible \
		and hud._drop_preview_visual == cat_visual,
		"Soltar no céu pousa visualmente em ground e pede confirmação sem revelar.")
	check(not cat_visual.suppress_ground_shadow() \
		and shadows._shadow_feet(cat_visual) != Vector2.INF,
		"A sombra volta quando o Gatinho pousa para pré-visualizar o hex.")
	hud._hide_hex_choice()
	check(cat.position == EntityState.UNPLACED \
		and cat_visual.position.is_equal_approx(loose_position),
		"Cancelar a caixa devolve o Gatinho à posição visual original.")
	check(cat_visual.begin_mouse_carry(), "Gatinho pode ser carregado de novo.")
	hud._drag_pet_visual = cat_visual
	hud._drop_actor = cat
	hud._drop_grant = cat_grant
	hud._finish_cat_drag(Vector2(550.0, -500.0))
	var chosen_coord := EntityState.UNPLACED
	for coord in grid.cells:
		if cat_visual.position.is_equal_approx(PPPMapView.reference_hex_position(coord)):
			chosen_coord = coord
			break
	check(chosen_coord != EntityState.UNPLACED, "Soltura alta escolhe um hex seguro do ground.")
	if chosen_coord != EntityState.UNPLACED:
		hud._confirm_cat_reveal(chosen_coord)
		check(cat.position == chosen_coord and not hud.hex_choice.visible,
			"Só após confirmar a habilidade posiciona logicamente o Gatinho e revela.")
	cat.position = EntityState.UNPLACED
	owner.turn_state = old_turn_state
	var combat_for_animation := scene.get_node("CombatManager") as CombatManager
	combat_for_animation.action_resolved.emit(cat, &"attack", {})
	check(cat_visual.sprite.animation == &"attack",
		"Todo ataque básico resolvido do Gatinho dispara sua animação Attack.")
	combat_for_animation.action_resolved.emit(cat, &"counterattack", {})
	check(cat_visual.sprite.animation == &"attack",
		"Contra-ataque resolvido do Gatinho também dispara Attack.")
	combat_for_animation.action_resolved.emit(cat, &"ricochet", {})
	check(cat_visual.sprite.animation == &"attack",
		"Ricochete ofensivo do Gatinho também dispara Attack.")
	skills.active_skill_used.emit(cat, cat_grant,
		{"effects": [{"missed_reach": true}]})
	check(cat_visual.sprite.animation == &"attack",
		"Tentativa de ataque por Ativa sem alcance também dispara Attack.")
	cat_visual.play_idle()
	var dog_state := EntityState.from_playable_selection(dog, &"TestDog", EntityState.UNPLACED)
	check(campaign.register_companion(campaign.active_entity_states[0], dog_state, rng),
		"Doguinho também aparece junto ao dono.")
	var dog_visual := party.visuals_by_id[dog_state.instance_id] as CompanionActorVisual
	var dog_grant := skills.get_active_grants(dog_state)[0]
	owner.turn_state = EntityState.TurnState.INACTIVE
	check(hud._skill_is_available(dog_state, dog_grant),
		"Vai Pegar! permanece disponível mesmo com o dono inativo.")
	var exploration := scene.get_node("ExplorationManager") as ExplorationManager
	check(exploration.player_skill_manager.use_exploration_active(
		dog_state, dog_grant, EntityState.UNPLACED, exploration),
		"Doguinho executa Vai Pegar! fora do turno sem reativar o dono.")
	check(owner.turn_state == EntityState.TurnState.INACTIVE,
		"Ativa do pet não abre um novo turno do personagem.")
	hud._show_dog_skill_choice(dog_state, Vector2(500.0, 200.0))
	check(hud.hex_choice.visible and hud.hex_choice_buttons.get_child_count() == 1 \
		and (hud.hex_choice_buttons.get_child(0) as Button).disabled,
		"A caixa do Doguinho mantém Vai Pegar! visível e cinza quando indisponível.")
	hud._hide_hex_choice()
	owner.turn_state = old_turn_state
	check(not dog_visual.visible, "Doguinho sai do mapa durante Vai Pegar!.")
	skills.delayed_skill_effect_resolved.emit(campaign.active_entity_states[0],
		{"source_actor_id": dog_state.instance_id})
	check(dog_visual.visible and dog_visual.sprite.animation == &"walk",
		"Ao voltar, o Doguinho usa Walk, nunca Carrying.")
	var block := scene.get_node("BlockManager") as BlockManager
	check(block.begin_activation(source_coord, campaign.active_entity_states[0]),
		"Ativar Gnomos 3 inicia sua regra personalizada.")
	check(block.is_busy(), "A caixa narrativa espera o jogador confirmar Gnomos 3.")
	check(block.confirm_event_action(), "Prosseguir dispara a criação dos gnomos.")
	check(not block.is_busy(), "A criação dos gnomos termina a resolução do bloco original.")
	var gnome_coords: Array[Vector2i] = []
	var colors: Dictionary = {}
	for coord in grid.cells:
		var event := grid.get_ppp_block_resource(coord) as EventData
		if event == null or not String(event.id).begins_with("gn_"):
			continue
		gnome_coords.append(coord)
		colors[grid.get_cell(coord).map_visual_path] = true
	check(gnome_coords.size() == 5 and colors.size() == 5,
		"Surgem cinco efeitos e cinco cores únicas embaralhadas.")
	check(grid.get_ppp_block_resource(info_coord) == info,
		"Nenhum duende substitui Informação.")
	var markers := scene.get_node("MapRoot/DepthSorted/SpecialEventVisuals") as Node2D
	check(markers.get_child_count() == 5, "Os cinco duendes são desenhados no mapa.")
	var expected_gnome_scale := ORIENTATION_SCALE.gnome_reference_height() / 48.0
	for marker in markers.get_children():
		var visual := marker.get_child(0) as AnimatedSprite2D
		check(visual != null and is_equal_approx(visual.scale.x, expected_gnome_scale)
			and is_equal_approx(visual.scale.y, expected_gnome_scale)
			and is_equal_approx(visual.position.y, -32.0 * expected_gnome_scale),
			"Cada cor de duende usa a altura do Duende 1 sem distorção e apoia os pés no hex.")
	for index in mini(3, gnome_coords.size()):
		check(block.begin_activation(gnome_coords[index], campaign.active_entity_states[0]),
			"O duende pode ser ativado como Evento.")
		check(block.confirm_event_action(), "Cada duende aguarda Prosseguir.")
		check(block.finish_event_resolution(), "O executor conclui o duende de teste.")
	var still_active := 0
	for coord in gnome_coords:
		if grid.get_cell(coord).state in [HexGrid.PPPBlockState.HIDDEN, HexGrid.PPPBlockState.REVEALED]:
			still_active += 1
	check(still_active == 0 and markers.get_child_count() == 0,
		"Após o terceiro, os duendes restantes somem.")
	print("PPP ally animations: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
