extends SceneTree

## Perfil reproduzível das três transições iniciais. Não lê nem grava saves.
## Rodar com --headless --script res://scripts/tests/ppp_scene_transition_profile.gd
var _last_msec := 0
var _previous_frame_tick := 0
var _max_frame_ms := 0
var _phase := "startup"


func _initialize() -> void:
	_run.call_deferred()


func _mark(label: String) -> void:
	var now := Time.get_ticks_msec()
	print("PPP_SCENE_PROFILE %-24s %6d ms" % [label, now - _last_msec])
	_last_msec = now
	_phase = label


func _sample_frame() -> void:
	var now := Time.get_ticks_msec()
	if _previous_frame_tick > 0:
		var frame_ms := now - _previous_frame_tick
		_max_frame_ms = maxi(_max_frame_ms, frame_ms)
		if frame_ms >= 100:
			print("PPP_SCENE_PROFILE slow frame %-24s %6d ms" % [_phase, frame_ms])
	_previous_frame_tick = now


func _run() -> void:
	ProjectSettings.set_setting("ppp/profile_startup", true)
	process_frame.connect(_sample_frame)
	_last_msec = Time.get_ticks_msec()
	var menu_scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	_mark("menu load")
	var menu := menu_scene.instantiate() as Control
	_mark("menu instantiate")
	root.add_child(menu)
	current_scene = menu
	_mark("menu ready")
	if not menu._catalog_prepared:
		await menu.playable_catalog_ready
	_mark("menu catalog prepared")
	# São interações humanas distintas. Sem esta separação o perfil somaria
	# menu, seleção e confirmação no mesmo quadro artificialmente.
	await process_frame
	var selection_scene := load("res://scenes/ui/playable_selection.tscn") as PackedScene
	_mark("selection load")
	var selection := selection_scene.instantiate() as PlayableSelectionScreen
	_mark("selection instantiate")
	selection.preloaded_catalog = menu._playable_catalog
	root.add_child(selection)
	current_scene = selection
	_mark("selection ready")
	menu.queue_free()
	await process_frame
	await process_frame
	var party: Array[EntityData] = [
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres") as EntityData,
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
	]
	var campaign := CampaignState.new()
	var endings: Array[StringName] = [&"orchestra"]
	if not campaign.start_new_game(party, 12, null,
			EventCampaignEligibility.Mode.SHORT, endings):
		push_error("PPP_SCENE_PROFILE: preparação da campanha falhou.")
		quit(1)
		return
	_mark("campaign prepare")
	var summary_scene := load("res://scenes/ui/campaign_pregame_summary.tscn") as PackedScene
	_mark("summary load")
	var summary := summary_scene.instantiate() as CampaignPreGameSummary
	summary.prepared_campaign = campaign
	root.add_child(summary)
	current_scene = summary
	_mark("summary ready")
	selection.queue_free()
	await process_frame
	await process_frame
	var game_scene := load("res://teste.tscn") as PackedScene
	_mark("map load")
	await process_frame
	await process_frame
	var game := game_scene.instantiate() as PPPMapView
	_mark("map instantiate")
	await process_frame
	await process_frame
	game.set_meta("defer_preview_map", true)
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	gerencia.campaign = campaign
	game.visible = false
	root.add_child(game)
	_mark("map ready")
	await process_frame
	await process_frame
	await game.prepare_initial_interface()
	_mark("map UI staged")
	var rounds := game.get_node("RoundManager") as RoundManager
	if not rounds.start_first_map():
		push_error("PPP_SCENE_PROFILE: primeiro mapa falhou.")
		quit(1)
		return
	_mark("first map")
	await game.prepare_initial_visuals()
	_mark("map visuals staged")
	game.visible = true
	current_scene = game
	_mark("map visible")
	await process_frame
	_mark("first rendered frame")
	print("PPP_SCENE_PROFILE longest frame             %6d ms" % _max_frame_ms)
	quit(0)
