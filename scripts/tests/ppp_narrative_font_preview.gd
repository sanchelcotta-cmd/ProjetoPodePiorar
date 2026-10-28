extends SceneTree

const SCREEN_SIZE := Vector2i(1440, 810)


func _initialize() -> void:
	_make_previews.call_deferred()


func _make_previews() -> void:
	root.size = SCREEN_SIZE
	var scaler := root.get_node("UniversalFontScale")
	var original_scale := float(scaler.get("ui_factor"))
	scaler.call("set_ui_scale", 1.0, false)

	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() \
		as PlayableSelectionScreen
	root.add_child(selection)
	await process_frame
	selection._difficulty_info_button.pressed.emit()
	await _settle()
	_save("ppp_fonte_descricao_botao.png")
	selection.free()
	await process_frame

	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var popup := load("res://scenes/ui/block_activation_popup.tscn").instantiate() \
		as BlockActivationPopup
	root.add_child(popup)
	var event := load("res://resources/events/random_events/25-pacto_de_sangue.tres") \
		as EventData
	popup.show_block({"resource": event})
	await _settle()
	_save("ppp_fonte_evento.png")

	var item := load("res://resources/itens/equipments/armas/estilingue.tres") \
		as ItemData
	popup.show_block({"resource": item})
	await _settle()
	popup._show_reward_item_details(item)
	await _settle()
	_save("ppp_fonte_item.png")

	popup.free()
	background.free()
	scaler.call("set_ui_scale", original_scale, false)
	quit()


func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	RenderingServer.force_draw(false)
	await process_frame


func _save(file_name: String) -> void:
	var path := "user://" + file_name
	var image := root.get_texture().get_image()
	if image == null or image.save_png(path) != OK:
		push_error("Falha ao salvar prévia: " + file_name)
	else:
		print("FONTE_PREVIEW=" + ProjectSettings.globalize_path(path))
