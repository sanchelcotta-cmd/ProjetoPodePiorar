extends SceneTree

## Isola a construção dos painéis que o menu cria antes de mostrá-los.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var components := [
		{"name": "load panel", "script": "res://scripts/ui/campaign_load_panel.gd"},
		{"name": "archive library", "script": "res://scripts/ui/campaign_archive_library.gd"},
		{"name": "settings menu", "script": "res://scripts/ui/campaign_settings_menu.gd"},
		{"name": "selection detail", "script": "res://scripts/ui/playable_selection_detail_panel.gd"},
	]
	for spec in components:
		var started := Time.get_ticks_msec()
		var script := load(str(spec.script)) as Script
		var panel := script.new() as Control
		print("PPP_UI_PROFILE %-20s create %5d ms" % [spec.name,
			Time.get_ticks_msec() - started])
		started = Time.get_ticks_msec()
		root.add_child(panel)
		print("PPP_UI_PROFILE %-20s ready  %5d ms" % [spec.name,
			Time.get_ticks_msec() - started])
		panel.queue_free()
	quit(0)
