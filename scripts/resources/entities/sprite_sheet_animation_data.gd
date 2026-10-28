class_name SpriteSheetAnimationData
extends Resource

## Lê as folhas ORIGINAIS sem redesenhar os bichos. As folhas recebidas não
## têm o mesmo tamanho nem um grid comum: cada pose é recortada pela área
## transparente e colocada num quadro padronizado, sempre apoiada pelos pés.
enum Layout { TRANSPARENT_COLUMNS, REGULAR_GRID }
enum Palette { ORIGINAL, CAT_ORANGE, CAT_WHITE, CAT_BLACK, CAT_TABBY, DOG_CARAMEL }

@export_category("Folhas")
@export var idle_sheet: Texture2D
@export var idle_alternative_sheet: Texture2D
@export var walk_sheet: Texture2D
@export var jump_sheet: Texture2D
@export var carrying_sheet: Texture2D
@export var attack_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export_range(0, 31) var death_hurt_frame: int = 0

@export_category("Recorte")
@export var layout: Layout = Layout.TRANSPARENT_COLUMNS
@export_range(1, 16) var grid_columns: int = 3
@export_range(1, 16) var grid_rows: int = 2
@export var canvas_size: Vector2i = Vector2i(64, 64)
@export_range(1, 256) var subject_height: int = 44
@export_range(1, 256) var maximum_subject_width: int = 54
@export var palette: Palette = Palette.ORIGINAL
@export var normalize_to_first_idle_frame: bool = false

@export_category("Velocidade")
@export_range(1.0, 30.0, 0.5) var idle_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var walk_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var action_fps: float = 6.0
@export_range(1.0, 6.0, 0.5) var carrying_held_fps: float = 2.0
@export var irregular_idle: bool = false

var _cached_frames: SpriteFrames
var _reference_size := Vector2i.ZERO


func create_sprite_frames() -> SpriteFrames:
	if _cached_frames != null:
		return _cached_frames
	var frames := SpriteFrames.new()
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	if normalize_to_first_idle_frame and idle_sheet != null:
		var reference := idle_sheet.get_image()
		if reference != null and not reference.is_empty():
			if reference.get_format() != Image.FORMAT_RGBA8:
				reference.convert(Image.FORMAT_RGBA8)
			var first := _find_frames(reference)
			if not first.is_empty():
				var factor := minf(float(subject_height) / float(first[0].size.y),
					float(maximum_subject_width) / float(first[0].size.x))
				_reference_size = Vector2i(maxi(1, roundi(first[0].size.x * factor)),
					maxi(1, roundi(first[0].size.y * factor)))
	_add_clip(frames, &"idle", idle_sheet, idle_fps, true)
	_add_clip(frames, &"idle_alt", idle_alternative_sheet, idle_fps, true)
	_add_clip(frames, &"walk", walk_sheet, walk_fps, true)
	_add_clip(frames, &"jump", jump_sheet, action_fps, false)
	_add_clip(frames, &"carrying", carrying_sheet, action_fps, false)
	_add_carrying_phases(frames)
	_add_clip(frames, &"attack", attack_sheet, action_fps, false)
	_add_clip(frames, &"hurt", hurt_sheet, action_fps, false)
	_cached_frames = frames
	return frames


func _add_carrying_phases(frames: SpriteFrames) -> void:
	if not frames.has_animation(&"carrying") \
			or frames.get_frame_count(&"carrying") < 4:
		return
	# 1→2→3 ao pegar; depois somente 2↔3, sem mostrar o quadro 4.
	frames.add_animation(&"carrying_pickup")
	frames.set_animation_speed(&"carrying_pickup", _standard_fps(3, action_fps))
	frames.set_animation_loop(&"carrying_pickup", false)
	for index in 3:
		frames.add_frame(&"carrying_pickup", frames.get_frame_texture(&"carrying", index))
	frames.add_animation(&"carrying_held")
	frames.set_animation_speed(&"carrying_held", _standard_fps(2, carrying_held_fps))
	frames.set_animation_loop(&"carrying_held", true)
	for index in [1, 2]:
		frames.add_frame(&"carrying_held", frames.get_frame_texture(&"carrying", index))
	frames.add_animation(&"carrying_landing")
	frames.set_animation_speed(&"carrying_landing", _standard_fps(1, action_fps))
	frames.set_animation_loop(&"carrying_landing", false)
	frames.add_frame(&"carrying_landing", frames.get_frame_texture(&"carrying", 3))


func _add_clip(frames: SpriteFrames, clip_name: StringName, sheet: Texture2D,
		fps: float, loop: bool) -> void:
	if sheet == null:
		return
	var source := sheet.get_image()
	if source == null or source.is_empty():
		push_warning("SpriteSheetAnimationData: folha vazia: %s" % clip_name)
		return
	if source.get_format() != Image.FORMAT_RGBA8:
		source.convert(Image.FORMAT_RGBA8)
	var rectangles := _find_frames(source)
	if rectangles.is_empty():
		push_warning("SpriteSheetAnimationData: nenhum quadro encontrado em %s" % clip_name)
		return
	frames.add_animation(clip_name)
	frames.set_animation_loop(clip_name, loop)
	var textures: Array[Texture2D] = []
	for rect in rectangles:
		textures.append(_normalized_frame(source, rect))
	if textures.size() > 1 and textures.size() < 6:
		# Cinco poses: 1→2→3→4→5→4→3→2→1. A mesma regra
		# se adapta a folhas de duas, três ou quatro poses.
		for index in textures.size():
			frames.add_frame(clip_name, textures[index])
		for index in range(textures.size() - 2, -1, -1):
			frames.add_frame(clip_name, textures[index])
	elif irregular_idle and clip_name in [&"idle", &"idle_alt"] and textures.size() > 1:
		# Pequenos retornos a poses vizinhas evitam o ciclo 1→2→3→4 mecânico.
		for index in [0, 1, 0, 1, 2, 2, 1, 2, 3, 2, 1, 0]:
			frames.add_frame(clip_name, textures[mini(index, textures.size() - 1)])
	else:
		for texture in textures:
			frames.add_frame(clip_name, texture)
	frames.set_animation_speed(clip_name, _standard_fps(frames.get_frame_count(clip_name), fps))


func _standard_fps(_frame_count: int, original_fps: float) -> float:
	# Não alongar clipes curtos; as folhas normais usam 6 fps.
	# carrying_held conserva os 2 fps específicos do transporte do gato.
	return original_fps


func _find_frames(source: Image) -> Array[Rect2i]:
	var rectangles: Array[Rect2i] = []
	if layout == Layout.REGULAR_GRID:
		var cell_size := Vector2i(source.get_width() / grid_columns,
			source.get_height() / grid_rows)
		for row in grid_rows:
			for column in grid_columns:
				var cell := Rect2i(Vector2i(column, row) * cell_size, cell_size)
				var bounds := _opaque_bounds(source, cell)
				if not bounds.has_area():
					continue
				rectangles.append(bounds)
		return rectangles
	# Nestas folhas cada pose é separada das outras por pelo menos uma coluna
	# totalmente transparente. Não adivinhamos uma largura de quadro.
	var first := -1
	for x in source.get_width():
		var occupied := false
		for y in source.get_height():
			if source.get_pixel(x, y).a > 0.03:
				occupied = true
				break
		if occupied and first < 0:
			first = x
		elif not occupied and first >= 0:
			var bounds := _opaque_bounds(source,
				Rect2i(first, 0, x - first, source.get_height()))
			if bounds.has_area():
				rectangles.append(bounds)
			first = -1
	if first >= 0:
		var last := _opaque_bounds(source,
			Rect2i(first, 0, source.get_width() - first, source.get_height()))
		if last.has_area():
			rectangles.append(last)
	return rectangles


func _opaque_bounds(source: Image, area: Rect2i) -> Rect2i:
	var left := area.end.x
	var top := area.end.y
	var right := area.position.x - 1
	var bottom := area.position.y - 1
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if source.get_pixel(x, y).a <= 0.03:
				continue
			left = mini(left, x)
			right = maxi(right, x)
			top = mini(top, y)
			bottom = maxi(bottom, y)
	if right < left:
		return Rect2i()
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


func _normalized_frame(source: Image, rect: Rect2i) -> Texture2D:
	var picture := Image.create_empty(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	picture.blit_rect(source, rect, Vector2i.ZERO)
	# O primeiro Idle define a altura aparente; cada pose usa seu próprio
	# fator porque as folhas originais têm escalas diferentes. O limite de
	# largura preserva cauda/salto/ataque sem estourar o quadro de 96 px.
	var target_height := _reference_size.y if _reference_size.y > 0 else subject_height
	var factor := minf(float(target_height) / float(rect.size.y),
		float(maximum_subject_width) / float(rect.size.x))
	var size := Vector2i(maxi(1, roundi(rect.size.x * factor)),
		maxi(1, roundi(rect.size.y * factor)))
	# Nenhum pixel do topo ou das laterais pode ser descartado pelo canvas.
	if size.x > canvas_size.x or size.y > canvas_size.y - 3:
		var fit := minf(float(canvas_size.x) / float(size.x),
			float(canvas_size.y - 3) / float(size.y))
		size = Vector2i(maxi(1, floori(size.x * fit)),
			maxi(1, floori(size.y * fit)))
	picture.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	if palette != Palette.ORIGINAL:
		for y in picture.get_height():
			for x in picture.get_width():
				var color := picture.get_pixel(x, y)
				if color.a > 0.03:
					picture.set_pixel(x, y, _harmonize_color(color))
	var canvas := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color.TRANSPARENT)
	# Pé no mesmo lugar para o gato não "pular" entre Idle e Walk.
	var offset := Vector2i((canvas_size.x - size.x) / 2, canvas_size.y - size.y - 3)
	canvas.blit_rect(picture, Rect2i(Vector2i.ZERO, size), offset)
	return ImageTexture.create_from_image(canvas)


func _harmonize_color(input: Color) -> Color:
	var red := input.r8
	var green := input.g8
	var blue := input.b8
	var output := input
	# A borda cinza comum às folhas e os olhos não são recoloridos. Só os
	# grupos de cor do pelo entram na paleta fixa de cada variante.
	if red == 97 and green == 97 and blue == 97:
		return input
	match palette:
		Palette.CAT_ORANGE:
			if red >= 125 and red > green * 1.12 and green >= blue * 1.16:
				output = _shade(red, [Color8(150, 70, 30), Color8(190, 100, 40),
					Color8(230, 130, 30), Color8(245, 165, 70)])
			elif red >= 195 and green >= 165 and blue >= 130 and red >= green and green >= blue:
				output = _shade(red, [Color8(220, 175, 145), Color8(230, 195, 165),
					Color8(240, 210, 185), Color8(250, 235, 215)])
		Palette.CAT_WHITE:
			if red >= 120 and red >= green and green >= blue and red - green <= 70 \
					and green - blue <= 60:
				output = _shade(red, [Color8(165, 125, 110), Color8(205, 175, 150),
					Color8(235, 215, 195), Color8(250, 240, 230)])
		Palette.CAT_BLACK:
			if red < 170 and green < 160 and blue < 180 \
					and abs(red - green) <= 55 and abs(blue - red) <= 70:
				output = _shade(maxi(red, green), [Color8(10, 10, 20), Color8(40, 30, 50),
					Color8(70, 60, 80), Color8(120, 110, 130)])
		Palette.CAT_TABBY:
			if red >= 45 and red >= green and green >= blue and red - blue >= 25:
				output = _shade(red, [Color8(70, 25, 5), Color8(110, 55, 25),
					Color8(200, 155, 120), Color8(240, 210, 180)])
		Palette.DOG_CARAMEL:
			if red >= 35 and red >= green and green >= blue and red - blue >= 25:
				output = _shade(red, [Color8(55, 20, 5), Color8(110, 60, 25),
					Color8(190, 125, 55), Color8(245, 175, 90)])
	output.a = input.a
	return output


func _shade(red: int, colors: Array[Color]) -> Color:
	if red < 90:
		return colors[0]
	if red < 160:
		return colors[1]
	if red < 225:
		return colors[2]
	return colors[3]
