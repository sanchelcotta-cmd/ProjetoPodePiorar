class_name GameAmbientAudio
extends Node

## Som decorativo do mapa. RNG próprio: nunca consome resultados da campanha.
## Os sons passam por Ambience (85%) -> EffectsUI -> Master, nunca por Music.
@export var gerencia: GerenciaJogo
@export var sky: PPPParallaxBackground

const AMBIENCE_BUS: StringName = &"Ambience"
const MUSIC_BOX_ITEM_ID: StringName = &"cu_00003"
const TRACKS := {
	"bird_park": "res://audio/ambience/bird_park.mp3",
	"forest_birds": "res://audio/ambience/forest_birds.mp3",
	"night_ambience": "res://audio/ambience/night_ambience.mp3",
	"night_crickets": "res://audio/ambience/night_crickets.mp3",
	"owl_hooting": "res://audio/ambience/owl_hooting.mp3",
	"music_box": "res://audio/ambience/music_box.mp3",
	"thunderstorm": "res://audio/ambience/thunderstorm.mp3",
	"rain_thunder": "res://audio/ambience/rain_thunder.mp3",
}
const BASE_LEVEL := 1.0 # A hierarquia de 85% pertence ao bus Ambience.
const OWL_LEVEL := 0.45
const MUSIC_BOX_LEVEL := 0.35
const CHANGE_FADE_SECONDS := 0.45
const OWL_MIN_SECONDS := 60.0
const OWL_MAX_SECONDS := 180.0

var _rng := RandomNumberGenerator.new()
var _base: AudioStreamPlayer
var _owl: AudioStreamPlayer
var _music_box: AudioStreamPlayer
var _owl_timer: Timer
var _signature := ""
var _base_track := ""
var _music_box_present := false
var _base_tween: Tween
var _pending_track := ""
var _stream_cache: Dictionary = {}


func _ready() -> void:
	_rng.randomize()
	_base = _make_player("BaseAmbience", BASE_LEVEL)
	_owl = _make_player("OwlOverlay", OWL_LEVEL)
	_music_box = _make_player("MusicBoxOverlay", MUSIC_BOX_LEVEL)
	_base.finished.connect(func() -> void:
		if _base_track != "" and _base.stream != null:
			_base.play())
	_music_box.finished.connect(func() -> void:
		if _music_box_present and _music_box.stream != null:
			_music_box.play())
	_owl_timer = Timer.new()
	_owl_timer.name = "OwlInterval"
	_owl_timer.one_shot = true
	_owl_timer.timeout.connect(_play_owl)
	add_child(_owl_timer)
	_refresh()
	set_process(true)


func _exit_tree() -> void:
	if _base_tween != null and _base_tween.is_running():
		_base_tween.kill()
	if _owl_timer != null:
		_owl_timer.stop()
	for player in [_base, _owl, _music_box]:
		if player != null:
			player.stop()
			player.stream = null
	_stream_cache.clear()


func _make_player(node_name: String, level: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = AMBIENCE_BUS
	player.volume_linear = level
	add_child(player)
	return player


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	if gerencia == null or gerencia.campaign == null or sky == null:
		return
	var campaign := gerencia.campaign
	if campaign.current_map == null or sky.active_set_path.is_empty():
		return
	var sky_name := sky.active_set_path.get_file()
	var signature := "%d|%d|%s|%s" % [campaign.current_map.get_instance_id(),
		campaign.round_period, campaign.district, sky_name]
	if signature != _signature:
		_signature = signature
		_set_base_track(_choose_base_track(campaign.round_period,
			campaign.district, sky_name))
	var has_box := _party_has_music_box(campaign)
	if has_box != _music_box_present:
		_music_box_present = has_box
		if has_box:
			_music_box.stream = _stream("music_box")
			if _music_box.stream != null:
				_music_box.play()
		else:
			_music_box.stop()


func _choose_base_track(period: int, district: StringName,
		sky_name: String) -> String:
	if sky_name.begins_with("cinzento_"):
		# cinzento_0002 favorece rain-thunder sem impedir a outra faixa.
		return "rain_thunder" if _rng.randf() < (
			0.75 if sky_name == "cinzento_0002" else 0.50) else "thunderstorm"
	if period == PPPMapGenerator.RoundPeriod.NIGHT:
		# O grilo é mais comum no Subúrbio; ambos continuam possíveis.
		return "night_crickets" if _rng.randf() < (
			0.75 if district == &"suburbio" else 0.25) else "night_ambience"
	return "bird_park" if _rng.randf() < 0.5 else "forest_birds"


func _set_base_track(track_id: String) -> void:
	if track_id == _base_track:
		return
	_base_track = track_id
	_owl.stop()
	_owl_timer.stop()
	if _base_tween != null and _base_tween.is_running():
		_base_tween.kill()
	_pending_track = track_id
	if _base.playing:
		_base_tween = create_tween()
		_base_tween.tween_property(_base, "volume_linear", 0.0, CHANGE_FADE_SECONDS)
		_base_tween.finished.connect(_start_pending_track)
	else:
		_start_pending_track()


func _start_pending_track() -> void:
	if _pending_track == "":
		return
	var track_id := _pending_track
	_pending_track = ""
	_base.stop()
	_base.stream = _stream(track_id)
	_base.volume_linear = 0.0
	if _base.stream == null:
		return
	_base.play()
	_base_tween = create_tween()
	_base_tween.tween_property(_base, "volume_linear", BASE_LEVEL,
		CHANGE_FADE_SECONDS)
	if track_id == "night_ambience":
		_schedule_owl()


func _schedule_owl() -> void:
	if _base_track != "night_ambience":
		return
	_owl_timer.start(_rng.randf_range(OWL_MIN_SECONDS, OWL_MAX_SECONDS))


func _play_owl() -> void:
	if _base_track != "night_ambience":
		return
	_owl.stream = _stream("owl_hooting")
	if _owl.stream != null:
		_owl.play()
	_schedule_owl()


func _stream(track_id: String) -> AudioStream:
	if not TRACKS.has(track_id):
		return null
	if not _stream_cache.has(track_id):
		_stream_cache[track_id] = load(str(TRACKS[track_id])) as AudioStream
	return _stream_cache[track_id] as AudioStream


func _party_has_music_box(campaign: CampaignState) -> bool:
	for actor in campaign.active_entity_states + campaign.companion_states:
		for item in actor.inventory_items:
			if item != null and item.data != null and item.data.id == MUSIC_BOX_ITEM_ID:
				return true
	return false
