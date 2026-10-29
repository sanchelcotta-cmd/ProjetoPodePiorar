extends Node

## Preferências de áudio globais, independentes da campanha e dos temas de UI.
## Música e efeitos permanecem independentes. Sub-buses de efeitos fixam a
## hierarquia relativa quando os três controles do jogador estão em 100%.
signal volume_changed(channel: StringName, percent: int)
signal station_changed(station_id: StringName, title: String)
signal station_catalog_changed

const CONFIG_PATH := "user://ppp_audio_settings.cfg"
const MASTER: StringName = &"master"
const MUSIC: StringName = &"music"
const EFFECTS: StringName = &"effects"
const CHANNELS: Array[StringName] = [MASTER, EFFECTS, MUSIC]
const BUS_NAMES := {
	MASTER: &"Master",
	EFFECTS: &"EffectsUI",
	MUSIC: &"Music",
}
const EFFECT_MIX_LEVELS := {
	&"Ambience": 0.8075,
	&"GeneralSFX": 1.00,
	&"CombatSFX": 1.00,
	&"SpecialSFX": 1.00,
	&"ClickUI": 1.00,
}
const DEFAULT_VOLUMES := {
	MASTER: 100,
	EFFECTS: 100,
	MUSIC: 70,
}
const PRE_GAME_MENU_TRACK := "res://audio/music/pre_game_menu.mp3"
const PAUSE_RADIO_GAIN := 0.5
const STATION_ASSETS := [
	{"id": &"radio_a", "title": "Rádio A",
		"path": "res://audio/music/radio_a.mp3",
		"combat_path": "res://audio/music/combat_radio_a.mp3"},
	{"id": &"radio_b", "title": "Rádio B",
		"path": "res://audio/music/radio_b.mp3",
		"combat_path": "res://audio/music/combat_radio_b.mp3"},
	{"id": &"radio_c", "title": "Rádio C",
		"path": "res://audio/music/radio_c.mp3",
		"combat_path": "res://audio/music/combat_radio_c.mp3"},
]

var config_path := CONFIG_PATH
var _volumes: Dictionary = DEFAULT_VOLUMES.duplicate()
var _last_audible: Dictionary = DEFAULT_VOLUMES.duplicate()
var _stations: Array[Dictionary] = []
var _station_index := -1
var _preferred_station_id: StringName = &""
var _music_player: AudioStreamPlayer
var _combat_player: AudioStreamPlayer
var _menu_player: AudioStreamPlayer
var _game_context: StringName = &"none"
var _context_before_pause: StringName = &"none"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_NAMES[EFFECTS])
	_ensure_bus(BUS_NAMES[MUSIC])
	for bus_name in EFFECT_MIX_LEVELS:
		_ensure_effect_sub_bus(bus_name, float(EFFECT_MIX_LEVELS[bus_name]))
	# Os golpes têm ganho próprio acima dos demais efeitos. Limitar seus picos
	# (e a soma final com a rádio) evita distorção quando vários sons coincidem.
	_ensure_peak_limiter(&"CombatSFX")
	_ensure_peak_limiter(&"Master")
	_load_settings()
	for channel in CHANNELS:
		_apply_volume(channel)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "StationPlayer"
	_music_player.bus = BUS_NAMES[MUSIC]
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)
	_combat_player = AudioStreamPlayer.new()
	_combat_player.name = "CombatMusicPlayer"
	_combat_player.bus = BUS_NAMES[MUSIC]
	_combat_player.finished.connect(_on_combat_music_finished)
	add_child(_combat_player)
	_menu_player = AudioStreamPlayer.new()
	_menu_player.name = "PreGameMenuPlayer"
	_menu_player.bus = BUS_NAMES[MUSIC]
	_menu_player.finished.connect(_on_menu_music_finished)
	add_child(_menu_player)
	_menu_player.stream = load(PRE_GAME_MENU_TRACK) as AudioStream
	if _menu_player.stream == null:
		push_error("GameAudio: música do menu inicial ausente: %s" % PRE_GAME_MENU_TRACK)
	elif _menu_player.stream is AudioStreamMP3:
		(_menu_player.stream as AudioStreamMP3).loop = true
	for station in STATION_ASSETS:
		if not ResourceLoader.exists(str(station["path"])) \
				or not ResourceLoader.exists(str(station["combat_path"])):
			push_error("GameAudio: rádio incompleta (Exploração/Combate): %s" % station["id"])
			continue
		_stations.append({"id": station["id"], "title": station["title"],
			"path": station["path"], "combat_path": station["combat_path"],
			"stream": null, "combat_stream": null})
	if not _stations.is_empty():
		_station_index = 0
		for index in _stations.size():
			if _stations[index]["id"] == _preferred_station_id:
				_station_index = index
				break
		station_changed.emit(_stations[_station_index]["id"],
			str(_stations[_station_index]["title"]))
		station_catalog_changed.emit()


func _exit_tree() -> void:
	# Ao encerrar imediatamente (inclusive --quit headless), libere o playback
	# antes de desmontar o AudioServer e o cache de recursos.
	for player in [_music_player, _combat_player, _menu_player]:
		if player != null:
			player.stop()
			player.stream = null
	_stations.clear()


func _process(_delta: float) -> void:
	# Apenas cenas anteriores à partida possuem a música do menu. Painéis
	# abertos pela pausa continuam dentro de PPPMapView e não entram aqui.
	var scene := get_tree().current_scene
	if scene is PPPMainMenu or scene is PlayableSelectionScreen \
			or scene is CampaignPreGameSummary:
		set_game_context(&"menu")
	elif _game_context == &"menu":
		set_game_context(&"none")


func get_volume(channel: StringName) -> int:
	return int(_volumes.get(channel, -1))


func set_volume(channel: StringName, percent: int, persist: bool = true) -> bool:
	if not CHANNELS.has(channel) or percent < 0 or percent > 100:
		return false
	if int(_volumes[channel]) == percent:
		return true
	_volumes[channel] = percent
	if percent > 0:
		_last_audible[channel] = percent
	_apply_volume(channel)
	volume_changed.emit(channel, percent)
	return _save_settings() if persist else true


func toggle_mute(channel: StringName, persist: bool = true) -> bool:
	if not CHANNELS.has(channel):
		return false
	var current := get_volume(channel)
	return set_volume(channel, 0 if current > 0 else int(_last_audible[channel]), persist)


func register_station(station_id: StringName, title: String, stream: AudioStream,
		combat_stream: AudioStream) -> bool:
	if station_id.is_empty() or title.is_empty() or stream == null or combat_stream == null:
		return false
	for station in _stations:
		if station["id"] == station_id:
			return false
	_stations.append({"id": station_id, "title": title, "stream": stream,
		"combat_stream": combat_stream})
	if _station_index < 0:
		# Tocar a primeira disponível sem esquecer uma preferência cuja faixa
		# ainda não foi registrada nesta sessão.
		_play_station(0, _preferred_station_id.is_empty()
			or station_id == _preferred_station_id)
	elif station_id == _preferred_station_id:
		_play_station(_stations.size() - 1)
	station_catalog_changed.emit()
	return true


func get_station_count() -> int:
	return _stations.size()


func get_current_station_title() -> String:
	if _station_index < 0 or _station_index >= _stations.size():
		return "Nenhuma música cadastrada"
	return str(_stations[_station_index]["title"])


func next_station() -> bool:
	if _stations.size() < 2 or _game_context != &"exploration":
		return false
	_play_station((_station_index + 1) % _stations.size())
	return true


## Índices de atalho são 1–9; rádios ainda não cadastradas não fazem nada.
func select_station_number(number: int) -> bool:
	if number < 1 or number > _stations.size() \
			or _game_context not in [&"exploration", &"combat"]:
		return false
	_play_station(number - 1)
	return true


func get_music_context() -> StringName:
	return _game_context


func set_game_context(context: StringName) -> bool:
	if context not in [&"none", &"menu", &"exploration", &"combat", &"paused"]:
		return false
	if context == _game_context:
		return true
	if context == &"paused":
		_context_before_pause = _game_context
	_game_context = context
	# O ganho temporário nunca modifica a preferência persistida nem o bus Music.
	_music_player.volume_linear = PAUSE_RADIO_GAIN if context == &"paused" else 1.0
	match context:
		&"menu":
			_music_player.stop()
			_combat_player.stop()
			if _menu_player.stream != null:
				_menu_player.play()
		&"exploration":
			_menu_player.stop()
			_combat_player.stop()
			_ensure_station_music()
			if _station_index >= 0 and _music_player.stream != null:
				if _music_player.playing:
					_music_player.stream_paused = false
				else:
					_music_player.play()
		&"combat":
			_menu_player.stop()
			_ensure_station_combat()
			if _music_player.playing:
				_music_player.stream_paused = true
			if _combat_player.stream != null:
				if _combat_player.playing:
					_combat_player.stream_paused = false
				else:
					_combat_player.play()
		&"paused":
			_menu_player.stop()
			_ensure_station_music()
			if _combat_player.playing:
				_combat_player.stream_paused = true
			if _context_before_pause in [&"exploration", &"combat"] \
					and _station_index >= 0 and _music_player.stream != null:
				if _music_player.playing:
					_music_player.stream_paused = false
				else:
					_music_player.play()
		&"none":
			_menu_player.stop()
			_music_player.stop()
			_combat_player.stop()
	station_catalog_changed.emit()
	return true


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")


func _ensure_effect_sub_bus(bus_name: StringName, relative_level: float) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, bus_name)
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_send(index, BUS_NAMES[EFFECTS])
	AudioServer.set_bus_volume_db(index, linear_to_db(relative_level))


func _ensure_peak_limiter(bus_name: StringName) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect_index) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.3
	AudioServer.add_bus_effect(index, limiter)


func _apply_volume(channel: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(BUS_NAMES[channel])
	if bus_index < 0:
		return
	var percent := get_volume(channel)
	AudioServer.set_bus_mute(bus_index, percent == 0)
	if percent > 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(float(percent) / 100.0))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return
	for channel in CHANNELS:
		var key := str(channel)
		_volumes[channel] = clampi(int(config.get_value("audio", key,
			DEFAULT_VOLUMES[channel])), 0, 100)
		_last_audible[channel] = clampi(int(config.get_value("audio", key + "_last",
			DEFAULT_VOLUMES[channel])), 1, 100)
	_preferred_station_id = StringName(str(config.get_value("audio", "station_id", "")))


func _save_settings() -> bool:
	var config := ConfigFile.new()
	for channel in CHANNELS:
		var key := str(channel)
		config.set_value("audio", key, _volumes[channel])
		config.set_value("audio", key + "_last", _last_audible[channel])
	config.set_value("audio", "station_id", str(_preferred_station_id))
	return config.save(config_path) == OK


func _play_station(index: int, remember: bool = true) -> void:
	_station_index = index
	var station := _stations[index]
	if remember:
		_preferred_station_id = station["id"]
	_music_player.stop()
	_music_player.stream = _station_stream(index, "stream", "path")
	# A faixa de combate acompanha a rádio escolhida, mesmo que a troca de
	# estação seja feita muito antes de começar o encontro.
	_combat_player.stop()
	_combat_player.stream = _station_stream(index, "combat_stream", "combat_path")
	if _game_context == &"exploration":
		_music_player.play()
	elif _game_context == &"combat" and _combat_player.stream != null:
		_combat_player.play()
	if remember:
		_save_settings()
	station_changed.emit(station["id"], str(station["title"]))


func _station_stream(index: int, stream_key: String, path_key: String) -> AudioStream:
	var station := _stations[index]
	var stream := station.get(stream_key) as AudioStream
	if stream == null and station.has(path_key):
		stream = load(str(station[path_key])) as AudioStream
		station[stream_key] = stream
		_stations[index] = station
	return stream


func _ensure_station_music() -> void:
	if _station_index >= 0 and _music_player.stream == null:
		_music_player.stream = _station_stream(_station_index, "stream", "path")


func _ensure_station_combat() -> void:
	if _station_index >= 0 and _combat_player.stream == null:
		_combat_player.stream = _station_stream(_station_index,
			"combat_stream", "combat_path")


func _on_music_finished() -> void:
	if (_game_context == &"exploration" or \
			(_game_context == &"paused" and _context_before_pause in [&"exploration", &"combat"])) \
			and _station_index >= 0 \
			and _music_player.stream != null:
		_music_player.play()


func _on_combat_music_finished() -> void:
	if _game_context == &"combat" and _combat_player.stream != null:
		_combat_player.play()


func _on_menu_music_finished() -> void:
	if _game_context == &"menu" and _menu_player.stream != null:
		_menu_player.play()
