class_name ActorGroundShadows
extends Node2D

## Sombras suaves sob entidades, abaixo de StartZone e Hexes. A máscara
## radial é criada com ImageTexture nativa: centro opaco, bordas transparentes.
## Futuro poste: adicione seu PointLight2D ao grupo ppp_streetlight e,
## opcionalmente, defina a metadata shadow_reach (pixels de alcance).
@export var gerencia: GerenciaJogo
@export var sky: PPPParallaxBackground

const STREETLIGHT_GROUP := "ppp_streetlight"

var _falloff: Texture2D
var _frame_bounds: Dictionary = {}


func _ready() -> void:
	var diameter := 96
	var mask := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	for y in diameter:
		for x in diameter:
			var normalized := (Vector2(x + 0.5, y + 0.5) /
				float(diameter) - Vector2(0.5, 0.5)) * 2.0
			var radius := normalized.length()
			var alpha: float = 1.0 - smoothstep(0.48, 1.0, radius)
			mask.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_falloff = ImageTexture.create_from_image(mask)


func _process(_delta: float) -> void:
	# Os sprites se movem por Tween, inclusive durante o Combate.
	queue_redraw()


func _draw() -> void:
	if _falloff == null or gerencia == null:
		return
	var period := gerencia.campaign.round_period
	var grey := sky != null \
		and sky.active_set_path.get_file().begins_with("cinzento_")
	var tint := Color("#103453")
	var opacity := 0.85
	var stretch := 1.0
	var offset := Vector2(0.0, 3.0)
	if grey:
		tint = Color("#173a58")
		opacity = 0.74
		stretch = 1.25
		offset.x = 4.0
	else:
		match period:
			PPPMapGenerator.RoundPeriod.AFTERNOON:
				tint = Color("#112d50")
				opacity = 0.88
				stretch = 1.55
				offset.x = 17.0
			PPPMapGenerator.RoundPeriod.NIGHT:
				tint = Color("#102747")
				opacity = 0.84
				stretch = 1.28
				# Direção oposta à tarde, mas curta e difusa: sem poste,
				# a luz do céu noturno não projeta sombra longa.
				offset.x = -8.0
	for visual in get_tree().get_nodes_in_group("map_entity_visual"):
		if not visual is Node2D or not visual.is_visible_in_tree():
			continue
		var actor := visual as Node2D
		var feet := _shadow_feet(actor)
		if feet == Vector2.INF:
			continue
		var actor_offset := offset
		var actor_stretch := stretch
		var actor_opacity := opacity
		if not grey and period == PPPMapGenerator.RoundPeriod.NIGHT:
			var from_post := _nearby_streetlight(feet)
			if not from_post.is_empty():
				actor_offset = from_post.offset
				actor_stretch = from_post.stretch
				actor_opacity = from_post.opacity
		var comfort := get_node_or_null("/root/VisualComfort")
		if comfort != null:
			actor_opacity = float(comfort.call("cap_shadow_alpha", actor_opacity))
		var half_width := _shadow_half_width(actor) * actor_stretch
		var half_height := maxf(13.0, half_width * 0.38 / actor_stretch)
		var rect := Rect2(feet + actor_offset - Vector2(half_width, half_height),
			Vector2(half_width * 2.0, half_height * 2.0))
		draw_texture_rect(_falloff, rect, false,
			Color(tint.r, tint.g, tint.b, actor_opacity))


func _nearby_streetlight(feet: Vector2) -> Dictionary:
	var closest_distance := INF
	var chosen := Vector2.ZERO
	var chosen_reach := 0.0
	for candidate in get_tree().get_nodes_in_group(STREETLIGHT_GROUP):
		var light := candidate as PointLight2D
		if light == null or not light.enabled or not light.is_visible_in_tree():
			continue
		var light_position := to_local(light.global_position)
		var reach := maxf(1.0, float(light.get_meta("shadow_reach", 260.0)))
		var distance := feet.distance_to(light_position)
		if distance < reach and distance < closest_distance:
			closest_distance = distance
			chosen = light_position
			chosen_reach = reach
	if not is_finite(closest_distance):
		return {}
	var influence := 1.0 - closest_distance / chosen_reach
	var away := (feet - chosen).normalized()
	return {
		"offset": Vector2(away.x * (8.0 + 18.0 * influence),
			5.0 + away.y * 3.0),
		"stretch": 1.28 + 0.55 * influence,
		"opacity": 0.84 + 0.09 * influence,
	}


func _shadow_half_width(actor: Node2D) -> float:
	var sprite := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null and sprite.visible and sprite.sprite_frames != null:
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,
			sprite.frame)
		if texture != null:
			var used := _used_rect(texture)
			return clampf(float(used.size.x) * absf(sprite.scale.x) * 0.62,
				26.0, 54.0)
	return 40.0


func _visual_feet(actor: Node2D) -> Vector2:
	var sprite := actor.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null or not sprite.visible or sprite.sprite_frames == null:
		return to_local(actor.global_position)
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,
		sprite.frame)
	if texture == null:
		return to_local(actor.global_position)
	var used := _used_rect(texture)
	if not used.has_area():
		return to_local(actor.global_position)
	var foot_x := float(used.position.x) + float(used.size.x) * 0.5 \
		- float(texture.get_width()) * 0.5
	if sprite.flip_h:
		foot_x = -foot_x
	var foot_y := float(used.end.y) - float(texture.get_height()) * 0.5
	return to_local(sprite.to_global(Vector2(foot_x, foot_y)))


func _shadow_feet(actor: Node2D) -> Vector2:
	var companion := actor as CompanionActorVisual
	if companion != null:
		if companion.suppress_ground_shadow():
			return Vector2.INF
		var jump_ground := companion.jump_ground_shadow_position()
		if jump_ground != Vector2.INF:
			return to_local(jump_ground)
	return _visual_feet(actor)


func _used_rect(texture: Texture2D) -> Rect2i:
	var key := texture.get_instance_id()
	if not _frame_bounds.has(key):
		_frame_bounds[key] = texture.get_image().get_used_rect()
	return _frame_bounds[key]
