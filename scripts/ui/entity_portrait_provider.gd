class_name EntityPortraitProvider
extends RefCounted

## Retrato compartilhado pela fila de iniciativa e pela ficha. Enquanto um
## EntityData não tiver arte, gera a mesma silhueta provisória do Combate.


static func for_state(actor: EntityState) -> Texture2D:
	if actor == null or actor.data == null:
		return null
	var data := actor.visual_data()
	if data.playable_animation != null and data.playable_animation.idle_sheet != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = data.playable_animation.idle_sheet
		atlas.region = Rect2(Vector2.ZERO, Vector2(
			data.playable_animation.frame_size.x,
			data.playable_animation.frame_size.y))
		return atlas
	if data.portrait != null:
		return data.portrait
	var variant := actor.get_animation_variant()
	if variant != null:
		var frames := variant.create_sprite_frames()
		if frames.has_animation(&"idle") and frames.get_frame_count(&"idle") > 0:
			return frames.get_frame_texture(&"idle", 0)
	if data.icon != null:
		return data.icon
	if data.sprite != null:
		return data.sprite
	return _provisional_silhouette(actor.controller == EntityState.Controller.PLAYER)


static func _provisional_silhouette(allied: bool) -> Texture2D:
	var image := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var fill := Color(0.025, 0.16, 0.21) if allied else Color(0.23, 0.025, 0.045)
	var outline := Color(0.13, 0.86, 1.0) if allied else Color(1.0, 0.10, 0.16)
	for y in 64:
		for x in 48:
			if not _silhouette_mask(x, y):
				continue
			var edge := not _silhouette_mask(x - 1, y) \
				or not _silhouette_mask(x + 1, y) \
				or not _silhouette_mask(x, y - 1) \
				or not _silhouette_mask(x, y + 1)
			image.set_pixel(x, y, outline if edge else fill)
	image.set_pixel(21, 14, outline)
	image.set_pixel(27, 14, outline)
	return ImageTexture.create_from_image(image)


static func _silhouette_mask(x: int, y: int) -> bool:
	if x < 0 or x >= 48 or y < 0 or y >= 64:
		return false
	var head := (x - 24) * (x - 24) + (y - 14) * (y - 14) <= 72
	var torso := y >= 23 and y <= 43 and x >= 15 and x <= 33
	var left_arm := y >= 27 and y <= 44 and x >= 10 and x <= 14
	var right_arm := y >= 27 and y <= 44 and x >= 34 and x <= 38
	var left_leg := y >= 43 and y <= 61 and x >= 17 and x <= 23
	var right_leg := y >= 43 and y <= 61 and x >= 25 and x <= 31
	return head or torso or left_arm or right_arm or left_leg or right_leg
