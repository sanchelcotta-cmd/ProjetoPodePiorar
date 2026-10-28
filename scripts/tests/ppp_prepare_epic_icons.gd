extends SceneTree

## Preparação determinística do atlas fornecido pelo jogador. Remove somente
## o preto conectado às bordas; pixels coloridos dos sprites não são redesenhados.


func _initialize() -> void:
	var source := Image.load_from_file("res://sprites/itens_icons/armas_epicas_2.png")
	if source == null or source.is_empty():
		push_error("Atlas original das armas épicas não encontrado.")
		quit(1)
		return
	source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width()
	var height := source.get_height()
	var pixels := source.get_data()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue := PackedInt32Array()
	for x in width:
		_try_enqueue(x, pixels, visited, queue)
		_try_enqueue((height - 1) * width + x, pixels, visited, queue)
	for y in height:
		_try_enqueue(y * width, pixels, visited, queue)
		_try_enqueue(y * width + width - 1, pixels, visited, queue)
	var head := 0
	while head < queue.size():
		var index := queue[head]
		head += 1
		pixels[index * 4 + 3] = 0
		var x := index % width
		if x > 0:
			_try_enqueue(index - 1, pixels, visited, queue)
		if x + 1 < width:
			_try_enqueue(index + 1, pixels, visited, queue)
		if index >= width:
			_try_enqueue(index - width, pixels, visited, queue)
		if index + width < width * height:
			_try_enqueue(index + width, pixels, visited, queue)
	var result := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, pixels)
	var error := result.save_png("res://sprites/itens_icons/armas_epicas_2_transparent.png")
	if error != OK:
		push_error("Não foi possível salvar o atlas transparente: %s" % error_string(error))
		quit(1)
		return
	print("PPP atlas épico: %d pixels de fundo removidos." % queue.size())
	quit(0)


func _try_enqueue(index: int, pixels: PackedByteArray,
		visited: PackedByteArray, queue: PackedInt32Array) -> void:
	if visited[index] != 0:
		return
	visited[index] = 1
	var offset := index * 4
	if pixels[offset] <= 2 and pixels[offset + 1] <= 2 and pixels[offset + 2] <= 2:
		queue.append(index)
