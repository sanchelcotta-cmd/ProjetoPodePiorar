class_name PPPParallaxBackground
extends CanvasLayer

## Céu do mapa: escolhe uma pasta uma vez por mapa e desenha seus 1.png,
## 2.png... em ordem. orig.png e orig_big.png são apenas prévias.
## A camada -100 fica atrás das fachadas, do chão, dos hexes e da interface.

enum SkyFilter {
	NONE,
	RED,
	GREEN,
	INFERNAL_RED,
}

const SKY_DIRECTORY := "res://sprites/background/fundosparalax"
const SPECIAL_FILTER_CHANCE := 0.05 # Chance TOTAL; vermelho/verde dividem estes 5%.
const PREVIEW_SKY := "res://sprites/background/fundosparalax/manha_0001"
const PREVIEW_GREY_SKY := "res://sprites/background/fundosparalax/cinzento_0001"
const PREVIEW_SNOW_SKY := "res://sprites/background/fundosparalax/nevasca_0001"
const AURA_FUNEBRE_ID := &"ev_00075"
const NEVASCA_ID := &"ev_00072"
const AFTERNOON_PERIOD := 1 # Mantém os valores de PPPMapGenerator.RoundPeriod.
const NIGHT_PERIOD := 2
const CLOUD_LIFT_RATIO := 0.15 # Céu ligeiramente mais baixo, ainda acima dos telhados.
const LIGHTNING_SET := "cinzento_0002"
const LIGHTNING_LAYER := "4.png"
const LIGHTNING_FLASH_SECONDS := 0.25
const LIGHTNING_WAIT_MIN_SECONDS := 20.0
const LIGHTNING_WAIT_MAX_SECONDS := 40.0

# A câmera ainda não está montada. Quando existir, as camadas mais distantes
# responderão menos ao seu movimento que as próximas, sem trocar os PNGs.
@export_range(0.0, 1.0, 0.01) var far_scroll: float = 0.08
@export_range(0.0, 1.0, 0.01) var near_scroll: float = 0.45
# Velocidades em pixels da área lógica por segundo. As nuvens de trás andam
# quase imperceptivelmente; as da frente andam um pouco mais rápido.
@export_range(0.0, 20.0, 0.01) var far_cloud_speed: float = 0.0
@export_range(0.0, 20.0, 0.01) var near_cloud_speed: float = 0.65

var active_set_path: String = ""
var active_filter: int = SkyFilter.NONE
var _grid: HexGrid
var _visual_weather: StringName = &""
var _infernal_portals_active: bool = false


func _ready() -> void:
	layer = -100
	get_viewport().size_changed.connect(_render)
	_render()


## O sorteio pertence à geração, não ao desenho. Redimensionar a janela
## nunca muda o céu que já foi sorteado para este mapa.
static func choose_visuals(period: int, day: int, rng: RandomNumberGenerator,
		allow_grey_main_sky: bool = true) -> Dictionary:
	var category := "manha_"
	match period:
		AFTERNOON_PERIOD: category = "tarde_"
		NIGHT_PERIOD: category = "noite_"
	var eligible := _find_sets(category)
	if period != NIGHT_PERIOD and allow_grey_main_sky:
		eligible.append_array(_find_sets("cinzento_"))
	if eligible.is_empty():
		push_error("PPPParallaxBackground: não há céu para o horário %d." % period)
		return {}
	var selected: String = eligible[rng.randi_range(0, eligible.size() - 1)]
	var grey: String = selected if selected.get_file().begins_with("cinzento_") else _choose_grey(rng)
	if grey.is_empty():
		push_error("PPPParallaxBackground: falta ao menos uma pasta cinzento_* para a Áurea Fúnebre.")
		return {}
	var snow := _choose_snow(rng)
	if snow.is_empty():
		push_error("PPPParallaxBackground: falta ao menos uma pasta nevasca_* para a Nevasca.")
		return {}
	var visual_filter := SkyFilter.NONE
	if day >= 2 and rng.randf() < SPECIAL_FILTER_CHANCE:
		visual_filter = SkyFilter.RED if rng.randf() < 0.5 else SkyFilter.GREEN
	return {"path": selected, "aura_path": grey, "snow_path": snow, "filter": visual_filter}


static func _choose_grey(rng: RandomNumberGenerator) -> String:
	var options := _find_sets("cinzento_")
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else ""


static func _choose_snow(rng: RandomNumberGenerator) -> String:
	var options := _find_sets("nevasca_")
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else ""


static func _find_sets(prefix: String) -> Array[String]:
	var result: Array[String] = []
	for folder in DirAccess.get_directories_at(SKY_DIRECTORY):
		if not folder.begins_with(prefix):
			continue
		var path := SKY_DIRECTORY.path_join(folder)
		if ResourceLoader.exists(path.path_join("1.png")):
			result.append(path)
	result.sort()
	return result


func show_generated_map(grid: HexGrid) -> void:
	_grid = grid
	_render()


func set_visual_effects(weather_event_id: StringName, infernal_portals_active: bool) -> void:
	if _visual_weather == weather_event_id and _infernal_portals_active == infernal_portals_active:
		return
	_visual_weather = weather_event_id
	_infernal_portals_active = infernal_portals_active
	_render()


func get_visual_weather() -> StringName:
	return _visual_weather


func _render() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	active_set_path = ""
	active_filter = SkyFilter.NONE
	if _grid == null:
		return
	match _visual_weather:
		AURA_FUNEBRE_ID: active_set_path = _grid.ppp_aura_parallax_path
		NEVASCA_ID: active_set_path = _grid.ppp_snow_parallax_path
		_: active_set_path = _grid.ppp_parallax_path
	if active_set_path.is_empty():
		match _visual_weather:
			AURA_FUNEBRE_ID: active_set_path = PREVIEW_GREY_SKY
			NEVASCA_ID: active_set_path = PREVIEW_SNOW_SKY
			_: active_set_path = PREVIEW_SKY
	if _infernal_portals_active:
		active_filter = SkyFilter.INFERNAL_RED
	else:
		active_filter = SkyFilter.NONE if _visual_weather != &"" else _grid.ppp_parallax_filter
	var files := _numbered_layers(active_set_path)
	if files.is_empty():
		push_error("PPPParallaxBackground: pasta sem camadas numeradas: %s" % active_set_path)
		return
	var screen := get_viewport().get_visible_rect().size
	for index in files.size():
		var texture := load(files[index]) as Texture2D
		if texture == null:
			continue
		var parallax := Parallax2D.new()
		parallax.name = "SkyLayer_%d" % (index + 1)
		# A última folha numerada é a mais distante: céu imóvel. As folhas
		# anteriores se movem progressivamente, mas ainda muito devagar.
		var fraction := float(files.size() - 1 - index) \
			/ float(maxi(files.size() - 1, 1))
		var speed := lerpf(far_scroll, near_scroll, fraction)
		parallax.scroll_scale = Vector2(speed, speed)
		parallax.autoscroll = Vector2(-lerpf(far_cloud_speed, near_cloud_speed, fraction), 0.0)
		parallax.repeat_times = 2
		add_child(parallax)
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var scale_to_cover := maxf(screen.x / texture.get_width(), screen.y / texture.get_height())
		sprite.scale = Vector2.ONE * scale_to_cover
		# As camadas originais concentram as nuvens embaixo. Subir o conjunto
		# deixa as nuvens visíveis acima dos telhados; a imagem ainda cobre toda
		# a região até o começo do chão.
		sprite.position = screen * 0.5 - Vector2(0.0, screen.y * CLOUD_LIFT_RATIO)
		parallax.add_child(sprite)
		# A cópia espelhada se encaixa perfeitamente na borda da original.
		# Repetir esse par evita a nuvem desaparecer e reaparecer de repente,
		# sem precisar criar/destruir sprites durante a partida.
		var width := float(texture.get_width()) * scale_to_cover
		var mirror := Sprite2D.new()
		mirror.name = "MirroredClouds"
		mirror.texture = texture
		mirror.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mirror.scale = sprite.scale
		mirror.flip_h = true
		mirror.position = sprite.position + Vector2(width, 0.0)
		parallax.add_child(mirror)
		parallax.repeat_size = Vector2(width * 2.0, 0.0)
		if active_set_path.get_file() == LIGHTNING_SET \
				and files[index].get_file() == LIGHTNING_LAYER:
			# Esta folha contém o raio. Ele não é uma nuvem contínua:
			# fica oculto, pisca por 1/4 s e espera 20–40 s para piscar de novo.
			parallax.visible = false
			var lightning_timer := Timer.new()
			lightning_timer.name = "LightningWait"
			lightning_timer.one_shot = true
			parallax.add_child(lightning_timer)
			lightning_timer.timeout.connect(_show_lightning.bind(parallax, lightning_timer))
			lightning_timer.start(randf_range(LIGHTNING_WAIT_MIN_SECONDS,
				LIGHTNING_WAIT_MAX_SECONDS))
	var overlay_color := _filter_color()
	if overlay_color.a > 0.0:
		var overlay := ColorRect.new()
		overlay.name = "SkyFilter"
		overlay.position = Vector2.ZERO
		overlay.size = screen
		overlay.color = overlay_color
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(overlay)


func _show_lightning(lightning_layer: Parallax2D, lightning_timer: Timer) -> void:
	if not is_instance_valid(lightning_layer) or lightning_layer.is_queued_for_deletion():
		return
	lightning_layer.visible = true
	get_tree().create_timer(LIGHTNING_FLASH_SECONDS).timeout.connect(
		_hide_lightning.bind(lightning_layer, lightning_timer))


func _hide_lightning(lightning_layer: Parallax2D, lightning_timer: Timer) -> void:
	if not is_instance_valid(lightning_layer) or lightning_layer.is_queued_for_deletion():
		return
	lightning_layer.visible = false
	lightning_timer.start(randf_range(LIGHTNING_WAIT_MIN_SECONDS,
		LIGHTNING_WAIT_MAX_SECONDS))


func _numbered_layers(folder: String) -> Array[String]:
	var files: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() == "png" and file.get_basename().is_valid_int() \
				and file.get_basename().to_int() > 0:
			files.append(file)
	files.sort_custom(func(a: String, b: String) -> bool: return a.get_basename().to_int() < b.get_basename().to_int())
	var paths: Array[String] = []
	for file in files:
		paths.append(folder.path_join(file))
	return paths


func _filter_color() -> Color:
	if active_filter == SkyFilter.INFERNAL_RED:
		# Mantém as imagens do céu, mas domina qualquer outro filtro enquanto
		# Portais Infernais estiver ativo nesta Rodada.
		return Color(0.90, 0.01, 0.025, 0.78)
	if _visual_weather == AURA_FUNEBRE_ID:
		# O cinzento já vem da arte; esta película o deixa mais sombrio.
		return Color(0.10, 0.10, 0.14, 0.55)
	if _visual_weather == NEVASCA_ID:
		# Nuvens de neve com um filtro escuro/azulado: impressão de tempestade.
		return Color(0.06, 0.08, 0.15, 0.52)
	match active_filter:
		SkyFilter.RED: return Color(0.80, 0.06, 0.12, 0.48)
		SkyFilter.GREEN: return Color(0.08, 0.62, 0.20, 0.48)
	return Color.TRANSPARENT
