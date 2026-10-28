extends SceneTree

## Regressão de cortes: cada trecho precisa produzir um transiente perceptível
## já no começo de uma ação curta. --scan / --scan-late são diagnósticos.
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	AudioServer.add_bus()
	var bus := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus, &"SFXPeakProbe")
	AudioServer.set_bus_send(bus, &"Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(bus, capture)
	var player := AudioStreamPlayer.new()
	player.bus = &"SFXPeakProbe"
	player.stream = load("res://audio/sfx/movimentos_de_acao_1.mp3") as AudioStream
	root.add_child(player)
	await process_frame
	if "--scan" in OS.get_cmdline_user_args():
		await _scan(player, capture, 0.0)
		player.free()
		AudioServer.remove_bus(bus)
		capture = null
		await create_timer(0.2).timeout
		quit(0)
		return
	if "--scan-late" in OS.get_cmdline_user_args():
		await _scan(player, capture, 35.0)
		player.free()
		AudioServer.remove_bus(bus)
		capture = null
		await create_timer(0.2).timeout
		quit(0)
		return
	if "--sweep" in OS.get_cmdline_user_args():
		for point in [22.00, 22.08, 22.15, 22.22, 22.30,
				31.95, 32.05, 32.12, 32.20,
				46.10, 46.25, 46.35, 46.43, 46.52]:
			capture.clear_buffer()
			player.play(point)
			await create_timer(0.32).timeout
			player.stop()
			var peak := 0.0
			for sample in capture.get_buffer(capture.get_frames_available()):
				peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			print("SWEEP %.2f %.5f" % [point, peak])
		player.free()
		AudioServer.remove_bus(bus)
		capture = null
		await create_timer(0.2).timeout
		quit(0)
		return
	var failures := 0
	for id in ActionSFXCatalog.CLIPS.keys():
		capture.clear_buffer()
		var spec := ActionSFXCatalog.clip(id)
		var start := float(spec["start"])
		player.play(start)
		await create_timer(0.32).timeout
		player.stop()
		var available := capture.get_frames_available()
		if available <= 0:
			push_error("Sem frames capturados: %s" % id)
			failures += 1
			continue
		var samples := capture.get_buffer(available)
		var peak := 0.0
		var peak_index := -1
		for index in samples.size():
			var sample := samples[index]
			var amp := maxf(absf(sample.x), absf(sample.y))
			if amp > peak:
				peak = amp
				peak_index = index
		var first := -1
		for index in samples.size():
			var amplitude := maxf(absf(samples[index].x), absf(samples[index].y))
			if amplitude >= peak * 0.4:
				first = index
				break
		print("SFX_PEAK %s start=%.2f peak=%.5f absolute_peak=%.3fs first=%.3fs available=%d" % [id,
			start, peak, start + float(peak_index) / float(AudioServer.get_mix_rate()),
			float(first) / float(AudioServer.get_mix_rate()), available])
		var prominent_attack: bool = id in [&"punch", &"quick_swoosh",
			&"quick_blade", &"sword_schwing"]
		if peak < (0.20 if prominent_attack else 0.08) or first < 0 \
				or float(first) / float(AudioServer.get_mix_rate()) \
				> (0.18 if prominent_attack else 0.28) \
				or float(spec["gain"]) < 1.0:
			failures += 1
	# O Cabo de Vassoura usa o mesmo trecho do Martelo comum, mas com perfil
	# próprio. Conferir a saída efetiva para evitar reforço tímido ou clipping.
	capture.clear_buffer()
	player.pitch_scale = 0.84
	player.volume_linear = 1.75
	player.play(30.20)
	await create_timer(0.40).timeout
	player.stop()
	var broom_peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		broom_peak = maxf(broom_peak, maxf(absf(sample.x), absf(sample.y)))
	print("BROOM_PEAK %.5f" % broom_peak)
	if broom_peak < 0.5 or broom_peak > 1.0:
		failures += 1
	player.pitch_scale = 1.0
	player.volume_linear = 1.0
	capture.clear_buffer()
	player.stream = load("res://audio/music/radio_a.mp3") as AudioStream
	player.play(3.0)
	await create_timer(0.9).timeout
	player.stop()
	var radio_peak := 0.0
	for sample in capture.get_buffer(capture.get_frames_available()):
		radio_peak = maxf(radio_peak, maxf(absf(sample.x), absf(sample.y)))
	print("RADIO_PEAK %.5f" % radio_peak)
	player.free()
	AudioServer.remove_bus(bus)
	capture = null
	await create_timer(0.2).timeout
	print("PPP_AUDIO_SEGMENT_PEAK_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _scan(player: AudioStreamPlayer, capture: AudioEffectCapture,
		start_at: float) -> void:
	print("SFX_SCAN length=%.3f" % player.stream.get_length())
	capture.clear_buffer()
	player.play(start_at)
	for index in ceili((player.stream.get_length() - start_at) / 0.25) + 1:
		await create_timer(0.25).timeout
		var available := capture.get_frames_available()
		if available <= 0:
			continue
		var samples := capture.get_buffer(available)
		var peak := 0.0
		for sample in samples:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		if peak >= 0.05:
			print("SFX_SCAN %.2f %.4f" % [player.get_playback_position(), peak])
