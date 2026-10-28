extends SceneTree

const LIBRARY_SCRIPT := preload("res://scripts/ui/campaign_archive_library.gd")
const OUTPUT_DIR := "res://artifacts/archive_ui"


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	root.size = Vector2i(1600, 900)
	var library = LIBRARY_SCRIPT.new()
	root.add_child(library)
	await process_frame
	library.open()
	for child in library._grid.get_children():
		library._grid.remove_child(child)
		child.queue_free()
	var mode: Array[int] = [EventCampaignEligibility.Mode.SHORT,
		EventCampaignEligibility.Mode.MEDIUM, EventCampaignEligibility.Mode.COMPLETE]
	var endings: Array[Array] = [["khainokata"], ["orchestra", "homens_de_preto"],
		["khainokata", "orchestra", "homens_de_preto", "controle_da_mente"]]
	var first_archive: Dictionary = {}
	for index in 8:
		var line := _line(index, mode[index % 3], endings[index % 3])
		var archive := {"campaign_id": "example-%d" % index,
			"archived_at": "2026-10-%02dT14:30:00" % (21 - index),
			"lines": [line]}
		if index == 0:
			first_archive = archive
		library._add_folder(archive, index)
	library._total.text = "8 arquivos"
	library._layout()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var first_image := root.get_texture().get_image()
	print("ARCHIVE_PREVIEW_1:", first_image.save_png(OUTPUT_DIR + "/arquivos.png"))
	library._select_folder(first_archive)
	library._open_book()
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var second_image := root.get_texture().get_image()
	print("ARCHIVE_PREVIEW_2:", second_image.save_png(OUTPUT_DIR + "/livro_aberto.png"))
	library.queue_free()
	quit()


func _line(index: int, mode: int, ending_ids: Array) -> Dictionary:
	var entries: Array[Dictionary] = []
	entries.append(_entry(1, 1, 0, "suburbio", "event_outcome",
		[{"text": "Pedreiro", "tone": "actor"},
		{"text": " ativou o Evento ", "tone": "text"},
		{"text": "A Florzinha", "tone": "event"}]))
	entries.append(_entry(2, 1, 0, "suburbio", "encounter_started",
		[{"text": "Zumbis Dançarinos", "tone": "negative"}]))
	entries.append(_entry(3, 1, 0, "suburbio", "attack",
		[{"text": "Pedreiro", "tone": "actor"}], {"damage": 18}))
	entries.append(_entry(4, 1, 0, "suburbio", "attack",
		[{"text": "Zumbi", "tone": "hostile"}], {"damage": 9}))
	entries.append(_entry(5, 1, 0, "suburbio", "combat_finished", []))
	entries.append(_entry(6, 1, 0, "suburbio", "item_collected",
		[{"text": "Café", "tone": "item"}]))
	entries.append(_entry(7, 2, 1, "baixo_centro", "event_outcome",
		[{"text": "Gênio da Lâmpada", "tone": "event"}]))
	entries.append(_entry(8, 2, 1, "baixo_centro", "craft_item",
		[{"text": "Espada Flamejante", "tone": "item"}]))
	entries.append(_entry(9, 2, 1, "baixo_centro", "playable_death",
		[{"text": "Pedreiro", "tone": "actor"}]))
	entries.append(_entry(10, 2, 1, "baixo_centro", "recruitment",
		[{"text": "Jornalista", "tone": "actor"},
		{"text": "Professora", "tone": "actor"}]))
	return {"mode": mode, "ending_ids": ending_ids,
		"status": CampaignState.CampaignStatus.VICTORY,
		"journal_schema_version": 2, "created_at": "2026-10-21T14:20:00",
		"entries": entries, "index": index}


func _entry(serial: int, day: int, period: int, district: String,
		action: String, segments: Array, references: Dictionary = {}) -> Dictionary:
	return {"serial": serial, "day": day, "period": period,
		"district": district, "round_index": day, "action_id": action,
		"segments": segments, "references": references, "text": action}
