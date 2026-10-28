class_name GreySkyRain
extends Node2D

## Chuva visual discreta dos céus cinzento_*. Não participa do RNG de jogo,
## colisão lógica, cliques nem do salvamento. Três camadas independentes:
## telhados (gotas finas), entidades e Ground (em alturas variadas).
@export var sky: PPPParallaxBackground
@export_range(12.0, 60.0, 1.0) var pixels_per_drop: float = 18.0
@export_range(120.0, 700.0, 10.0) var minimum_speed: float = 320.0
@export_range(120.0, 700.0, 10.0) var maximum_speed: float = 450.0
@export_range(0.1, 1.0, 0.01) var diagonal_drift: float = 0.58

const LAYER_ROOF := 0
const LAYER_ENTITY := 1
const LAYER_GROUND := 2

@onready var _background: Sprite2D = get_node_or_null("../MapRoot/Background") as Sprite2D
@onready var _background_copies: Node2D = get_node_or_null("../MapRoot/BackgroundCopies") as Node2D
@onready var _ground: Node2D = get_node_or_null("../MapRoot/Ground") as Node2D

var _drops: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _raining := false
var _last_size := Vector2.ZERO
var _roof_cache: Dictionary = {}
var _roof_image: Image
var _roof_texture: Texture2D
var _roof_transform := Transform2D.IDENTITY


func _ready() -> void:
	_rng.randomize()
	z_index = 100
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(func(_enabled: bool) -> void:
			_last_size = Vector2.ZERO)
	_process(0.0)


func _process(delta: float) -> void:
	var should_rain := sky != null \
		and sky.active_set_path.get_file().begins_with("cinzento_")
	if not should_rain:
		if _raining:
			_raining = false
			_drops.clear()
			queue_redraw()
		return
	var size := get_viewport().get_visible_rect().size
	if not _raining or size != _last_size:
		_raining = true
		_last_size = size
		_drops.clear()
		var comfort := get_node_or_null("/root/VisualComfort")
		var density := float(comfort.call("particle_density_factor")) \
			if comfort != null else 1.0
		for index in maxi(6, roundi(size.x / pixels_per_drop * density)):
			_drops.append(_new_drop(size, true))
	var entity_rects := _entity_rects()
	var comfort := get_node_or_null("/root/VisualComfort")
	var speed_factor := 0.60 if comfort != null and bool(comfort.get("enabled")) \
		else 1.0
	for index in _drops.size():
		var drop := _drops[index]
		if drop.at_surface:
			_drops[index] = _new_drop(size, false)
			continue
		var x: float = drop.x + float(drop.speed) * delta * diagonal_drift * speed_factor
		var y: float = drop.y
		if x > size.x + 20.0:
			_drops[index] = _new_drop(size, false)
			continue
		var landing: float = drop.ground_y
		if drop.layer == LAYER_ROOF:
			landing = minf(landing, _roof_y_at_x(x))
			if y >= landing:
				_drops[index] = _new_drop(size, false)
				continue
		elif drop.layer == LAYER_ENTITY:
			for rect in entity_rects:
				# A faixa é levemente mais estreita que a caixa do sprite para
				# preservar a leitura do contorno de personagens pequenos.
				if x < rect.position.x + 4.0 or x > rect.end.x - 4.0:
					continue
				if rect.position.y >= y - drop.length and rect.position.y < landing:
					landing = rect.position.y
		var next_y: float = y + float(drop.speed) * delta * speed_factor
		if next_y >= landing:
			drop.x = x
			drop.y = landing
			drop.at_surface = true
		else:
			drop.x = x
			drop.y = next_y
		_drops[index] = drop
	queue_redraw()


func _draw() -> void:
	if not _raining:
		return
	for drop in _drops:
		var head := Vector2(drop.x, drop.y)
		var tail := head + Vector2(-float(drop.length) * diagonal_drift,
			-float(drop.length))
		var alpha: float = drop.alpha
		var comfort := get_node_or_null("/root/VisualComfort")
		if comfort != null:
			alpha = float(comfort.call("cap_particle_alpha", alpha))
		draw_line(tail, head, Color(0.91, 0.95, 1.0, alpha), 1.2, true)


func _new_drop(screen: Vector2, anywhere: bool) -> Dictionary:
	var layer_roll := _rng.randf()
	var layer := LAYER_GROUND
	if layer_roll < 0.30:
		layer = LAYER_ROOF
	elif layer_roll < 0.60:
		layer = LAYER_ENTITY
	var drop := {
		"layer": layer,
		"x": _rng.randf_range(-screen.y * diagonal_drift, screen.x + 12.0),
		"y": _rng.randf_range(-screen.y, screen.y) if anywhere else -16.0,
		"speed": _rng.randf_range(minimum_speed, maximum_speed),
		"length": _rng.randf_range(12.0, 21.0),
		"alpha": _rng.randf_range(0.31, 0.48),
		"ground_y": _rng.randf_range(_ground_top_y(screen) + 8.0,
			screen.y - 4.0),
		"at_surface": false,
	}
	if layer == LAYER_ROOF:
		drop.length = _rng.randf_range(8.0, 11.0)
		drop.alpha = _rng.randf_range(0.25, 0.39)
		if anywhere:
			var roof_y := _roof_y_at_x(drop.x)
			if is_finite(roof_y):
				drop.y = minf(drop.y, roof_y - _rng.randf_range(12.0, 100.0))
	return drop


func _ground_top_y(screen: Vector2) -> float:
	if _ground != null and _ground.get_child_count() > 0:
		var tile := _ground.get_child(0) as Sprite2D
		if tile != null and tile.texture != null:
			return to_local(tile.to_global(Vector2(0.0,
				-float(tile.texture.get_height()) * 0.5))).y
	return screen.y * 0.70


func _roof_y_at_x(screen_x: float) -> float:
	# A arte das casas tem céu transparente. O primeiro pixel opaco de
	# cada coluna é a superfície real do telhado naquele ponto, inclusive
	# em telhados inclinados; não usamos uma linha horizontal aproximada.
	if _background == null or _background.texture == null:
		return INF
	if _roof_texture != _background.texture \
			or _roof_transform != _background.global_transform:
		_roof_texture = _background.texture
		_roof_transform = _background.global_transform
		_roof_image = _roof_texture.get_image()
		_roof_cache.clear()
	if _roof_image == null:
		return INF
	var facades: Array[Sprite2D] = [_background]
	if _background_copies != null:
		for child in _background_copies.get_children():
			if child is Sprite2D:
				facades.append(child as Sprite2D)
	for facade in facades:
		var source_x := roundi(facade.to_local(Vector2(screen_x, 0.0)).x \
			+ float(_roof_image.get_width()) * 0.5)
		if source_x < 0 or source_x >= _roof_image.get_width():
			continue
		if _roof_cache.has(source_x):
			var cached_y := float(_roof_cache[source_x])
			if is_finite(cached_y):
				return cached_y
			continue
		var roof_y := INF
		for source_y in range(0, _roof_image.get_height(), 2):
			if _roof_image.get_pixel(source_x, source_y).a >= 0.65:
				roof_y = facade.to_global(Vector2(0.0,
					float(source_y) - float(_roof_image.get_height()) * 0.5)).y
				break
		_roof_cache[source_x] = roof_y
		if is_finite(roof_y):
			return roof_y
	return INF


func _entity_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for visual in get_tree().get_nodes_in_group("map_entity_visual"):
		if not visual is Node2D or not visual.is_visible_in_tree():
			continue
		var actor := visual as Node2D
		var sprite := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if sprite != null and sprite.visible and sprite.sprite_frames != null:
			var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,
				sprite.frame)
			if texture != null:
				var half := texture.get_size() * 0.5
				var first := to_local(sprite.to_global(-half + sprite.offset))
				var second := to_local(sprite.to_global(half + sprite.offset))
				result.append(Rect2(first.min(second), (second - first).abs()))
				continue
		# Silhuetas provisórias e formas temporárias desenhadas em código.
		var feet := to_local(actor.global_position)
		result.append(Rect2(feet + Vector2(-35.0, -145.0),
			Vector2(70.0, 145.0)))
	return result
