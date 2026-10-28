extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1440, 810)
	var picker := load("res://scenes/ui/campaign_destination_picker.tscn").instantiate() as CampaignDestinationPicker
	root.add_child(picker)
	await process_frame
	picker.open_picker([&"suburbio", &"baixo_centro"], &"baixo_centro")
	await process_frame
	await process_frame
	var result := root.get_texture().get_image().save_png(
		"res://artifacts/destination_picker_preview.png")
	picker.open_picker([&"centro"], &"suburbio", true)
	await process_frame
	await process_frame
	var final_result := root.get_texture().get_image().save_png(
		"res://artifacts/destination_picker_final_center_preview.png")
	root.size = Vector2i(800, 600)
	picker.open_picker([&"suburbio", &"baixo_centro"], &"baixo_centro")
	await process_frame
	await process_frame
	var compact_result := root.get_texture().get_image().save_png(
		"res://artifacts/destination_picker_800x600_preview.png")
	var valid := result == OK and final_result == OK and compact_result == OK \
		and picker.displayed_districts().size() == 3 \
		and picker.row_for(&"centro") != null
	print("PPP_DESTINATION_PICKER_PREVIEW: %s" % ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
