extends SceneTree

## Diagnóstico somente leitura: usa saves existentes, mas jamais os altera.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var repository := CampaignSaveRepository.new()
	var ids := repository.list_campaign_ids()
	var started := Time.get_ticks_msec()
	var worst_entry := 0
	var found := 0
	for campaign_id in ids:
		var entry_started := Time.get_ticks_msec()
		repository.inspect_recoverable_autosave(campaign_id)
		if not repository.inspect_campaign(campaign_id).is_empty():
			found += 1
		worst_entry = maxi(worst_entry, Time.get_ticks_msec() - entry_started)
		await process_frame
	print("PPP_SAVE_CATALOG_HEALTH folders=%d visible=%d elapsed_ms=%d worst_entry_ms=%d" \
		% [ids.size(), found, Time.get_ticks_msec() - started, worst_entry])
	quit()
