class_name PPPScenicBackdrop
extends Node2D

## A camada distante acompanha a câmera do mapa, mas fica atrás das fachadas.
## A escolha depende da semente do mapa; resize e zoom só refazem o desenho.
const ASSET_DIRECTORY := "res://sprites/background/camadas_cenario"
const GREY_SHADER := preload("res://shaders/scenic_backdrop_grey.gdshader")
const MINIMUM_ZOOM := 0.85
const MINIMUM_SKY_FRACTION := 0.40
const SKY_SAMPLE_COLUMNS := 48
const SKY_SAMPLE_ROWS := 24

@export var sky: PPPParallaxBackground

var active_asset_path := ""
var visible_top_screen_y := 0.0
var visible_bottom_screen_y := 0.0
var remaining_sky_fraction := 1.0
var _shared_material: ShaderMaterial


func _ready() -> void:
	_shared_material = ShaderMaterial.new()
	_shared_material.shader = GREY_SHADER
	if sky != null:
		sky.visuals_changed.connect(_on_sky_visuals_changed)
		_on_sky_visuals_changed(sky.active_set_path)


func rebuild(grid: HexGrid, screen_size: Vector2, map_position: Vector2,
		ground_top: float, facades: Array[Sprite2D]) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	active_asset_path = ""
	remaining_sky_fraction = 1.0
	if grid == null or screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return
	var options := candidates_for_background(grid.ppp_background_path)
	if options.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, grid.ppp_decoration_seed + 3821)
	active_asset_path = options[rng.randi_range(0, options.size() - 1)]
	var texture := load(active_asset_path) as Texture2D
	if texture == null:
		return
	var picture := texture.get_image()
	if picture == null:
		return
	var opaque_top := picture.get_used_rect().position.y
	var visible_height := float(texture.get_height() - opaque_top)
	if visible_height <= 0.0:
		return
	if facades.is_empty() or facades[0] == null or facades[0].texture == null:
		return
	# Todas as cópias usam a mesma textura; decodificá-la só uma vez.
	var facade_picture := facades[0].texture.get_image()
	if facade_picture == null:
		return
	var bottom := _safe_bottom_line(facades, facade_picture, screen_size.x,
		ground_top - rng.randf_range(12.0, 22.0), ground_top)
	var sky_points := _visible_sky_points(screen_size, ground_top, facades,
		facade_picture)
	var horizontal_shift := rng.randf_range(-42.0, 42.0)
	var art_scale := 0.0
	for step in 27:
		var candidate_scale := 1.80 - float(step) * 0.05
		var remaining := _sky_fraction_after_art(sky_points, picture,
			candidate_scale, bottom, screen_size.x * 0.5 + horizontal_shift)
		if remaining >= MINIMUM_SKY_FRACTION:
			art_scale = candidate_scale
			remaining_sky_fraction = remaining
			break
	if art_scale <= 0.0:
		return
	visible_bottom_screen_y = bottom
	visible_top_screen_y = bottom - visible_height * art_scale
	var tile_width := float(texture.get_width()) * art_scale
	var center_x := screen_size.x * 0.5 - map_position.x \
		+ horizontal_shift
	var center_y := bottom - map_position.y \
		- float(texture.get_height()) * art_scale * 0.5
	# As cópias alternadas espelham a borda vizinha. Há cobertura além do
	# campo visível mesmo no zoom 85%, sem esticar ou revelar laterais.
	var side_tiles := ceili(screen_size.x / MINIMUM_ZOOM / tile_width * 0.5) + 2
	for tile_index in range(-side_tiles, side_tiles + 1):
		var tile := Sprite2D.new()
		tile.name = "CenarioDistante_%d" % tile_index
		tile.texture = texture
		tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tile.material = _shared_material
		tile.flip_h = absi(tile_index) % 2 == 1
		tile.scale = Vector2.ONE * art_scale
		tile.position = Vector2(center_x + tile_index * tile_width, center_y)
		add_child(tile)


func _visible_sky_points(screen_size: Vector2, ground_top: float,
		facades: Array[Sprite2D], picture: Image) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for row in SKY_SAMPLE_ROWS:
		for column in SKY_SAMPLE_COLUMNS:
			var point := Vector2((float(column) + 0.5) * screen_size.x \
				/ float(SKY_SAMPLE_COLUMNS),
				(float(row) + 0.5) * ground_top / float(SKY_SAMPLE_ROWS))
			var covered := false
			for index in facades.size():
				var facade := facades[index]
				if facade == null:
					continue
				var source := facade.to_local(point) + Vector2(picture.get_size()) * 0.5
				var x := floori(source.x)
				var y := floori(source.y)
				if x >= 0 and x < picture.get_width() \
						and y >= 0 and y < picture.get_height() \
						and picture.get_pixel(x, y).a >= 0.70:
					covered = true
					break
			if not covered:
				points.append(point)
	return points


func _safe_bottom_line(facades: Array[Sprite2D], picture: Image,
		screen_width: float, preferred_y: float, ground_top: float) -> float:
	for step in 48:
		var y := preferred_y - float(step) * 2.0
		if _facades_cover_line(facades, picture, screen_width, y):
			return y
	# Fachada futura sem faixa opaca contínua: o chão cobre a borda.
	push_warning("Cenário distante: fachada sem base opaca contínua; " \
		+ "a margem inferior ficará escondida pelo ground.")
	return ground_top + 2.0


func _facades_cover_line(facades: Array[Sprite2D], picture: Image,
		screen_width: float, y: float) -> bool:
	for column in 64:
		var point := Vector2((float(column) + 0.5) * screen_width / 64.0, y)
		var covered := false
		for facade in facades:
			if facade == null:
				continue
			var source := facade.to_local(point) + Vector2(picture.get_size()) * 0.5
			var x := floori(source.x)
			var source_y := floori(source.y)
			if x >= 0 and x < picture.get_width() and source_y >= 0 \
					and source_y < picture.get_height() \
					and picture.get_pixel(x, source_y).a >= 0.70:
				covered = true
				break
		if not covered:
			return false
	return true


func _sky_fraction_after_art(sky_points: Array[Vector2], picture: Image,
		art_scale: float, bottom: float, center_x: float) -> float:
	if sky_points.is_empty():
		return 1.0
	var visible_sky := 0
	var tile_width := float(picture.get_width()) * art_scale
	for point in sky_points:
		var source_y := float(picture.get_height()) - (bottom - point.y) / art_scale
		if source_y < 0.0 or source_y >= float(picture.get_height()):
			visible_sky += 1
			continue
		var tile_index := roundi((point.x - center_x) / tile_width)
		var source_x := (point.x - center_x - float(tile_index) * tile_width) \
			/ art_scale + float(picture.get_width()) * 0.5
		if absi(tile_index) % 2 == 1:
			source_x = float(picture.get_width() - 1) - source_x
		var x := clampi(floori(source_x), 0, picture.get_width() - 1)
		if picture.get_pixel(x, floori(source_y)).a < 0.25:
			visible_sky += 1
	return float(visible_sky) / float(sky_points.size())


static func candidates_for_background(background_path: String) -> Array[String]:
	var district := "suburbio"
	if background_path.contains("baixocentro") or background_path.contains("baixo_centro"):
		district = "baixo_centro"
	elif background_path.contains("centro"):
		district = "centro"
	var result: Array[String] = []
	for file in DirAccess.get_files_at(ASSET_DIRECTORY):
		if not file.ends_with(".png"):
			continue
		var eligible := false
		match district:
			"suburbio": eligible = file.contains("suburbio")
			"baixo_centro": eligible = file.contains("baixo-centro")
			"centro": eligible = file.contains("centro") \
				and not file.contains("baixo-centro")
		if eligible:
			result.append(ASSET_DIRECTORY.path_join(file))
	result.sort()
	return result


func _on_sky_visuals_changed(path: String) -> void:
	if _shared_material != null:
		_shared_material.set_shader_parameter("grey_strength",
			1.0 if path.get_file().begins_with("cinzento_") else 0.0)
