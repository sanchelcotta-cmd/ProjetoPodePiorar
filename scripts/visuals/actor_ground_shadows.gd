class_name ActorGroundShadows
extends Node2D

## Sombras suaves sob entidades, abaixo de StartZone e Hexes. A máscara
## radial é criada com ImageTexture nativa: centro opaco, bordas transparentes.
## Os postes reais registram seus PointLight2D em ppp_streetlight. Dentro do
## feixe, a sombra se afasta da lâmpada junto com o movimento do personagem.
@export var gerencia: GerenciaJogo
@export var sky: PPPParallaxBackground

const STREETLIGHT_GROUP := "ppp_streetlight"
const ENTITY_OPACITY_FACTOR := 0.80

var _falloff: Texture2D
var _frame_bounds: Dictionary = {}


func _ready() -> void:
	_falloff = create_falloff_texture()


static func create_falloff_texture() -> Texture2D:
	var diameter := 96
	var mask := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	for y in diameter:
		for x in diameter:
			var normalized := (Vector2(x + 0.5, y + 0.5) /
				float(diameter) - Vector2(0.5, 0.5)) * 2.0
			var radius := normalized.length()
			var alpha: float = 1.0 - smoothstep(0.48, 1.0, radius)
			mask.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(mask)


static func ambient_shadow_style(period: int, grey: bool) -> Dictionary:
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
				# Direção oposta à tarde, mas curta e difusa.
				offset.x = -8.0
	return {"tint": tint, "opacity": opacity,
		"stretch": stretch, "offset": offset}


func _process(_delta: float) -> void:
	# Os sprites se movem por Tween, inclusive durante o Combate.
	queue_redraw()


func _draw() -> void:
	if _falloff == null or gerencia == null:
		return
	var period := gerencia.campaign.round_period
	var grey := sky != null \
		and sky.active_set_path.get_file().begins_with("cinzento_")
	var style := ambient_shadow_style(period, grey)
	var tint: Color = style.tint
	var opacity: float = style.opacity
	var stretch: float = style.stretch
	var offset: Vector2 = style.offset
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
		var from_post := {}
		# Chuva/céu cinzento não apagam os postes acesos à noite.
		if period == PPPMapGenerator.RoundPeriod.NIGHT:
			from_post = _nearby_streetlight(feet)
			if not from_post.is_empty():
				actor_offset = from_post.offset
				actor_stretch = from_post.stretch
				actor_opacity = from_post.opacity
		var comfort := get_node_or_null("/root/VisualComfort")
		if comfort != null:
			actor_opacity = float(comfort.call("cap_shadow_alpha", actor_opacity))
		actor_opacity *= ENTITY_OPACITY_FACTOR
		if not from_post.is_empty():
			_draw_cast_shadow(feet, actor, from_post, actor_opacity)
		var half_width := _shadow_half_width(actor) * actor_stretch
		var half_height := maxf(13.0, half_width * 0.38 / actor_stretch)
		var rect := Rect2(feet + actor_offset - Vector2(half_width, half_height),
			Vector2(half_width * 2.0, half_height * 2.0))
		draw_texture_rect(_falloff, rect, false,
			Color(tint.r, tint.g, tint.b, actor_opacity))


func _nearby_streetlight(feet: Vector2) -> Dictionary:
	var best_score := INF
	var chosen := Vector2.ZERO
	var chosen_reach := 0.0
	var chosen_delta := Vector2.ZERO
	for candidate in get_tree().get_nodes_in_group(STREETLIGHT_GROUP):
		var light := candidate as PointLight2D
		if light == null or not light.enabled or not light.is_visible_in_tree():
			continue
		var light_position := to_local(light.global_position)
		var reach := maxf(1.0, float(light.get_meta("shadow_reach", 500.0)))
		var delta := feet - light_position
		if delta.y <= 0.0 or delta.y >= reach:
			continue
		var half_width := lerpf(18.0,
			float(light.get_meta("cone_half_width", 250.0)), delta.y / reach)
		if absf(delta.x) >= half_width:
			continue
		var score := absf(delta.x) / half_width + delta.y / reach * 0.25
		if score < best_score:
			best_score = score
			chosen = light_position
			chosen_reach = reach
			chosen_delta = delta
	if not is_finite(best_score):
		return {}
	var influence := 1.0 - chosen_delta.y / chosen_reach
	var away := Vector2(chosen_delta.x * 0.8, chosen_delta.y).normalized()
	return {
		"offset": away * (9.0 + 15.0 * influence),
		"stretch": 1.45 + 0.55 * influence,
		"opacity": 0.84 + 0.09 * influence,
		"direction": away,
		"length": 48.0 + 86.0 * influence,
	}


func _draw_cast_shadow(feet: Vector2, actor: Node2D,
		from_post: Dictionary, opacity: float) -> void:
	var away := from_post.direction as Vector2
	var across := Vector2(-away.y, away.x)
	var width := clampf(_shadow_half_width(actor) * 0.42, 11.0, 23.0)
	var origin := feet + away * 5.0
	var tip: Vector2 = feet + away * float(from_post.length)
	var shadow := Color("#0d1430")
	var strength := minf(0.52, opacity * 0.48)
	draw_polygon(PackedVector2Array([
		origin + across * width, origin - across * width,
		tip - across * width * 1.25, tip + across * width * 1.25,
	]), PackedColorArray([
		Color(shadow.r, shadow.g, shadow.b, strength),
		Color(shadow.r, shadow.g, shadow.b, strength),
		Color(shadow.r, shadow.g, shadow.b, 0.0),
		Color(shadow.r, shadow.g, shadow.b, 0.0),
	]))


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
