extends SceneTree

const OUTPUT_DIR := "C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb"
const PANEL_SCRIPT := preload("res://scripts/ui/campaign_load_panel.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var panel := PANEL_SCRIPT.new() as Control
	panel.set("repository", CampaignSaveRepository.new("user://ppp_load_visual_empty"))
	root.add_child(panel)
	await process_frame
	await process_frame
	for scenario in ["three_used", "one_empty", "all_empty", "two_rows", "completed"]:
		var rows := panel.get("_rows") as VBoxContainer
		for child in rows.get_children():
			rows.remove_child(child)
			child.queue_free()
		var slots: Array[Dictionary] = []
		if scenario != "all_empty":
			slots.append(_slot(1, 3, 1, "suburbio", 3,
				"Professora usou Artesanato com EVA e criou um equipamento épico."))
			slots.append(_slot(2, 2, 2, "baixo_centro", 2,
				"Pedreiro protegeu o grupo com Muro de Tijolo."))
		if scenario in ["three_used", "two_rows", "completed"]:
			slots.append(_slot(3, 3, 0, "suburbio", 4,
				"Universitário encontrou uma Informação no mapa."))
		panel.call("_add_campaign", {
			"campaign_id": "preview-demo-001",
			"slots": slots,
			"terminal_count": 1 if scenario == "completed" else 0,
		}, 1)
		if scenario == "two_rows":
			var second_slots: Array[Dictionary] = [
				_slot(1, 5, 0, "centro", 7,
					"Jornalista revelou um bloco e o grupo encontrou uma pista."),
				_slot(2, 4, 2, "baixo_centro", 6,
					"Mãe consumiu Café e recuperou Vida."),
			]
			for slot in second_slots:
				var preview := slot["preview"] as Dictionary
				preview["mode"] = EventCampaignEligibility.Mode.MEDIUM
				preview["ending_ids"] = ["orchestra", "controle_da_mente"]
				preview["information_goal"] = 10
			panel.call("_add_campaign", {
				"campaign_id": "preview-demo-002",
				"slots": second_slots,
				"terminal_count": 0,
			}, 2)
		await process_frame
		await process_frame
		if scenario == "two_rows":
			var scroll := rows.get_parent() as ScrollContainer
			var second_row := rows.get_child(1) as Control
			if second_row.get_global_rect().end.y > scroll.get_global_rect().end.y - 4.0:
				failures += 1
				push_error("Duas campanhas precisam caber na área visível sem rolagem.")
		# O renderizador dummy do --headless não produz textura de janela;
		# nesse modo, validar disposição sem fingir que houve inspeção visual.
		if DisplayServer.get_name() == "headless":
			continue
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			failures += 1
			continue
		if image.save_png(OUTPUT_DIR.path_join("load_%s_preview.png" % scenario)) != OK:
			failures += 1
	print("CAMPAIGN_LOAD_LAYOUT_TEST: %s%s" % [
		"PASS" if failures == 0 else "FAIL",
		" (capturas omitidas no modo headless)"
		if DisplayServer.get_name() == "headless" else ""])
	quit(0 if failures == 0 else 1)


func _slot(number: int, day: int, period: int, district: String,
		information_count: int, latest_entry: String) -> Dictionary:
	return {
		"slot_number": number,
		"slot_id": "preview-slot-%02d" % number,
		"saved_at": "2026-10-20T18:42:00",
		"valid": true,
		"preview": {
			"mode": EventCampaignEligibility.Mode.SHORT,
			"ending_ids": ["khainokata"],
			"day": day,
			"period": period,
			"district": district,
			"information_count": information_count,
			"information_goal": 5,
			"characters": ["Professora", "Pedreiro", "Universitário"],
			"latest_entry": latest_entry,
		},
	}
