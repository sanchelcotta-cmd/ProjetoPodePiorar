extends SceneTree

const ORIENTATION_SCENE := preload("res://scenes/visuals/orientacao_sprites.tscn")
const ORIENTATION_SCALE := preload("res://scripts/visuals/sprite_orientation_reference.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var board := ORIENTATION_SCENE.instantiate() as Node2D
	_check(board != null, "A cena de orientação abre.")
	if board == null:
		quit(1)
		return
	root.add_child(board)
	var fixed := board.get_node("ReguasFixas") as Node2D
	var pets := board.get_node("Companheiros") as Node2D
	var event_followers := board.get_node("SeguidoresEventos") as Node2D
	var gnomes := board.get_node("Duendes") as Node2D
	var transformations := board.get_node("Transformacoes") as Node2D
	var pending := board.get_node("EntidadesPendentes") as Node2D
	_check(fixed.get_child_count() == 7, "Há sete jogáveis fixos.")
	_check(pets.get_child_count() == 5, "Há quatro gatos e um cachorro.")
	_check(event_followers.get_child_count() == 1,
		"Bonequinho e Amigo Imaginário compartilham uma única régua.")
	_check(gnomes.get_child_count() == 1, "Só o Duende 1 serve de régua.")
	_check(transformations.get_child_count() == 1,
		"A forma galiforme tem uma referência própria.")
	var expected_entities: Dictionary = {}
	for file_name in DirAccess.get_files_at("res://resources/entities/entities_general"):
		if file_name.ends_with(".tres"):
			expected_entities["res://resources/entities/entities_general/" + file_name] = true
	_check(pending.get_child_count() == expected_entities.size(),
		"Cada cadastro de entidade geral tem um espaço na régua.")
	for entry in pending.get_children():
		var path := str(entry.get_meta("source_resource", ""))
		_check(expected_entities.erase(path),
			"%s corresponde a um cadastro único de entidade." % entry.name)
		var empty_sprite := entry.get_node("Sprite") as Sprite2D
		_check(empty_sprite.texture == null and entry.has_meta("pending_sprite"),
			"%s está reservado, ainda sem arte inventada." % entry.name)
	_check(expected_entities.is_empty(), "Nenhuma entidade geral ficou sem espaço.")
	for group in [fixed, pets, event_followers, gnomes, transformations]:
		for entry in group.get_children():
			var sprite := entry.get_node("Sprite") as Sprite2D
			_check(sprite.texture != null and sprite.region_enabled
				and sprite.region_rect.has_area(),
				"%s tem um quadro Idle independente e editável." % entry.name)
			_check(entry.has_meta("source_resource")
				and ResourceLoader.exists(str(entry.get_meta("source_resource"))),
				"%s guarda referência ao cadastro de origem." % entry.name)
			_check(sprite.has_meta("base_scale") and sprite.scale.x > 0.0
				and is_equal_approx(sprite.scale.x, sprite.scale.y),
				"%s pode ser redimensionado proporcionalmente." % entry.name)
			if group == fixed:
				_check(is_equal_approx(sprite.scale.x, 1.70)
					and bool(sprite.get_meta("reference_fixed")),
					"%s preserva a escala atual dos jogáveis." % entry.name)
	var gnome_sprite := gnomes.get_node("Duende1/Sprite") as Sprite2D
	var reference_height := gnome_sprite.region_rect.size.y * gnome_sprite.scale.y
	_check(is_equal_approx(ORIENTATION_SCALE.gnome_reference_height(),
		reference_height), "A altura salva do Duende 1 é lida diretamente da cena.")
	var chicken_sprite := transformations.get_node("Galinha/Sprite") as Sprite2D
	_check(is_equal_approx(chicken_sprite.scale.x, chicken_sprite.scale.y),
		"Galinha conserva a proporção definida pela altura no editor.")
	_check(is_equal_approx(ORIENTATION_SCALE.chicken_reference_scale(),
		chicken_sprite.scale.y),
		"Escala oficial da galinha é lida da cena de orientação.")
	var follower_sprite := event_followers.get_node("BonequinhoAmigo/Sprite") as Sprite2D
	_check(is_equal_approx(follower_sprite.region_rect.size.y * follower_sprite.scale.y,
		chicken_sprite.region_rect.size.y * chicken_sprite.scale.y),
		"O seguidor tem a mesma altura visual da galinha.")
	_check(is_equal_approx(ORIENTATION_SCALE.event_follower_reference_scale(),
		follower_sprite.scale.y), "Escala do seguidor é lida da cena de orientação.")
	var pet_sprite := pets.get_node("GatoLaranja/Sprite") as Sprite2D
	var original_scale := pet_sprite.scale
	pet_sprite.scale = Vector2(original_scale.x, original_scale.y + 0.25)
	board.enforce_uniform_scales()
	_check(is_equal_approx(pet_sprite.scale.x, pet_sprite.scale.y)
		and is_equal_approx(pet_sprite.scale.y, original_scale.y + 0.25),
		"Alterar altura ajusta a largura proporcionalmente.")
	pet_sprite.scale = original_scale
	if "--preview" in OS.get_cmdline_user_args() \
			and DisplayServer.get_name() != "headless":
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1600, 2380)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		board.reparent(viewport)
		await process_frame
		await process_frame
		await process_frame
		var image := viewport.get_texture().get_image()
		_check(image != null and image.save_png(
			"user://ppp_orientacao_sprites_preview.png") == OK,
			"A prévia visual da régua foi renderizada.")
	else:
		if "--preview" in OS.get_cmdline_user_args():
			print("Prévia não disponível no renderizador headless; rode em janela real.")
		board.free()
	print("PPP orientação sprites: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
