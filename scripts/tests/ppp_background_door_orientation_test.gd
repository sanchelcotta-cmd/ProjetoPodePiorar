extends SceneTree

## Confere que cada fachada sorteável tem áreas editáveis na imagem original.
var failures := 0


func _initialize() -> void:
	var scene := load("res://scenes/visuals/orientacao_portas_backgrounds.tscn") as PackedScene
	check(scene != null, "A cena de orientação de portas abre.")
	if scene == null:
		quit(1)
		return
	var root := scene.instantiate() as Node2D
	check(root != null, "A cena de orientação de portas instancia.")
	if root == null:
		quit(1)
		return
	get_root().add_child(root)
	var fachadas := root.get_node("Fachadas")
	check(fachadas.get_child_count() > 0, "Há fachadas orientadas.")
	var found := {}
	var total_areas := 0
	for fachada in fachadas.get_children():
		var source := str(fachada.get_meta("source_background", ""))
		check(source.begins_with("res://sprites/background/cena_"),
			"A fachada %s guarda o caminho da arte original." % fachada.name)
		check(not found.has(source), "A fachada %s não foi duplicada." % source)
		found[source] = true
		var imagem := fachada.get_node("Imagem") as Sprite2D
		var portas := fachada.get_node("Portas") as Node2D
		check(imagem != null and portas != null,
			"A fachada %s tem imagem e marcações." % fachada.name)
		if imagem == null or portas == null:
			continue
		check(imagem.texture != null and imagem.texture.resource_path == source,
			"A fachada %s usa sua arte correta." % fachada.name)
		check(imagem.position == portas.position and imagem.scale == portas.scale,
			"A fachada %s mantém imagem e áreas alinhadas." % fachada.name)
		check(portas.get_child_count() > 0,
			"A fachada %s contém marcações iniciais." % fachada.name)
		if imagem.texture == null:
			continue
		var image_size := imagem.texture.get_size()
		for area in portas.get_children():
			total_areas += 1
			check(area is ReferenceRect,
				"A área %s pode ser editada visualmente." % area.name)
			if not area is ReferenceRect:
				continue
			var rect := (area as ReferenceRect).get_rect()
			check(rect.size.x > 0.0 and rect.size.y > 0.0
				and rect.position.x >= 0.0 and rect.position.y >= 0.0
				and rect.end.x <= image_size.x and rect.end.y <= image_size.y,
				"A área %s/%s fica dentro da arte original." % [fachada.name, area.name])
	check(total_areas > 0, "Há áreas de porta editáveis.")
	var directory := DirAccess.open("res://sprites/background")
	check(directory != null, "A pasta de fachadas existe.")
	if directory != null:
		for filename in directory.get_files():
			if not filename.begins_with("cena_") or not filename.ends_with(".png"):
				continue
			var source := "res://sprites/background/" + filename
			check(found.has(source), "A fachada sorteável %s tem orientação." % filename)
	print("PPP orientação de portas: %d áreas, %d falha(s)" % [total_areas, failures])
	get_root().remove_child(root)
	root.free()
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
