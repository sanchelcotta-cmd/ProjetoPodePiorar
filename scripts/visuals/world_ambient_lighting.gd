class_name WorldAmbientLighting
extends CanvasModulate

## Luz ambiente do cenário. CanvasModulate age no canvas do mapa, não nas
## CanvasLayers da interface. PointLight2D dos futuros postes pode clarear
## regiões deste mesmo canvas sem substituir este controle de horário.
@export var gerencia: GerenciaJogo
@export var sky: PPPParallaxBackground
@export var sky_light: DirectionalLight2D

@export_group("Paleta")
@export var afternoon_base: Color = Color("#e09470")
@export_range(0.0, 1.0, 0.01) var afternoon_strength: float = 0.44
@export var night_base: Color = Color("#745c89")
@export_range(0.0, 1.0, 0.01) var night_strength: float = 0.82
@export var grey_base: Color = Color("#aeb4bf")
@export_range(0.0, 1.0, 0.01) var grey_strength: float = 0.55
@export_range(0.0, 2.0, 0.05) var transition_seconds: float = 0.55

var _last_period := -1
var _last_grey := false
var _tween: Tween


func _ready() -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(_on_comfort_changed)
	_refresh(true)


func _on_comfort_changed(_enabled: bool) -> void:
	_last_period = -1
	_refresh(true)


func _process(_delta: float) -> void:
	# O período também pode mudar ao carregar um slot, sem round_advanced.
	# O céu pode trocar por Evento; ambos são apenas estado visual derivado.
	_refresh(false)


func _refresh(instant: bool) -> void:
	if gerencia == null or sky == null:
		return
	var period := gerencia.campaign.round_period
	var grey := sky.active_set_path.get_file().begins_with("cinzento_")
	if not instant and period == _last_period and grey == _last_grey:
		return
	_last_period = period
	_last_grey = grey
	var target := Color.WHITE
	var light_color := Color("#fff1d9")
	var light_energy := 0.08
	if grey:
		target = Color.WHITE.lerp(grey_base, grey_strength)
		light_color = Color("#cbd3dc")
		light_energy = 0.05
	else:
		match period:
			PPPMapGenerator.RoundPeriod.AFTERNOON:
				target = Color.WHITE.lerp(afternoon_base, afternoon_strength)
				light_color = Color("#ffd7b9")
				light_energy = 0.10
			PPPMapGenerator.RoundPeriod.NIGHT:
				target = Color.WHITE.lerp(night_base, night_strength)
				light_color = Color("#b3c5ea")
				light_energy = 0.07
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		light_energy = float(comfort.call("cap_light_energy", light_energy))
	if _tween != null and _tween.is_running():
		_tween.kill()
	if instant or transition_seconds <= 0.0:
		color = target
		if sky_light != null:
			sky_light.color = light_color
			sky_light.energy = light_energy
	else:
		_tween = create_tween()
		_tween.set_parallel(true)
		_tween.tween_property(self, "color", target, transition_seconds)
		if sky_light != null:
			_tween.tween_property(sky_light, "color", light_color,
				transition_seconds)
			_tween.tween_property(sky_light, "energy", light_energy,
				transition_seconds)
