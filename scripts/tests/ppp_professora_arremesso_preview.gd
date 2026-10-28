extends SceneTree

## Amostra fiel das poses de Impacto: os dois primeiros quadros mostram a
## arma na mão; no terceiro ela vira projétil, sem o marcador verde.
const VISUAL_SCENE := preload("res://scenes/visuals/playable_actor_visual.tscn")
const OUTPUT := "user://ppp_professora_arremesso_preview.png"
var _canvas: SubViewport


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
	_canvas = SubViewport.new()
	_canvas.size = Vector2i(1300, 900)
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var background := ColorRect.new()
	background.color = Color(0.97, 0.96, 0.95)
	background.size = _canvas.size
	_canvas.add_child(background)
	var professor := load("res://resources/entities/entities_playable/professora.tres") \
		as EntityData
	var weapons: Array[ItemData] = [
		load("res://resources/itens/equipments/armas/arma_epica_bumerangue_teleguiado.tres") as ItemData,
		load("res://resources/itens/equipments/armas/chinelo.tres") as ItemData,
	]
	_add_label("PROFESSORA • IMPACTO • AMOSTRA 3×", Vector2(22, 13), 24)
	_add_label("Quadros 1–2: na mão  |  Quadro 3: lançamento sem marcador verde",
		Vector2(22, 46), 15)
	for row in weapons.size():
		var weapon := weapons[row]
		var row_y := 415.0 + float(row) * 445.0
		_add_label("BUMERANGUE" if row == 0 else "CHINELO",
			Vector2(22, row_y - 345.0), 19)
		for frame in 5:
			var column_x := 150.0 + float(frame) * 225.0
			_add_label("QUADRO %d" % (frame + 1),
				Vector2(column_x - 52.0, row_y - 310.0), 13)
			var actor := EntityState.from_playable_selection(professor,
				&"preview", Vector2i.ZERO)
			actor.equipped_weapons.append(InventoryItemState.new(weapon))
			var visual := VISUAL_SCENE.instantiate() as PlayableActorVisual
			_canvas.add_child(visual)
			visual.position = Vector2(column_x, row_y)
			visual.bind_state(actor)
			visual.set_visual_scale(3.0)
			visual.animated_sprite.animation = &"attack_impact"
			visual.animated_sprite.set_frame_and_progress(frame, 0.0)
			visual.animated_sprite.stop()
			if frame >= 2:
				visual._thrown_in_flight = true
				visual._update_held_weapon()
				var projectile := Sprite2D.new()
				projectile.texture = WeaponHandVisual.make_projectile_texture(
					WeaponHandVisual.variant(weapon.id))
				projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				projectile.scale = Vector2.ONE * 3.0 \
					* WeaponHandVisual.held_scale(weapon.id)
				projectile.position = visual.position + visual.weapon_hand_bone.position \
					+ Vector2(42.0 + 13.0 * (frame - 2),
						-30.0 - 11.0 * (frame - 2))
				projectile.rotation = float(frame - 1) * 0.65
				_canvas.add_child(projectile)
			elif not visual.held_weapon_sprite.visible:
				push_error("Arma não apareceu no quadro %d." % (frame + 1))
	await process_frame
	await process_frame
	await process_frame
	var image := _canvas.get_texture().get_image()
	if image == null or image.save_png(OUTPUT) != OK:
		push_error("Não foi possível gravar a amostra de arremesso.")
		quit(1)
		return
	print("PPP_THROW_PREVIEW: ", ProjectSettings.globalize_path(OUTPUT))
	quit(0)


func _add_label(value: String, point: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.20, 0.15, 0.20))
	_canvas.add_child(label)
