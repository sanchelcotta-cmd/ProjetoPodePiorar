class_name GreyWeatherGrade
extends CanvasLayer

@export var sky: PPPParallaxBackground

@onready var overlay: ColorRect = $ColorRect


func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/grey_weather_grade.gdshader")
	overlay.material = material
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var grey := sky != null \
		and sky.active_set_path.get_file().begins_with("cinzento_")
	# Este shader lê a tela pronta. Durante o Glitch Atemporal, o passe de
	# ruído acima do mundo invalidava essa leitura no viewport embutido e
	# produzia branco sólido. O próprio céu cinzento e a chuva permanecem;
	# só a película de dessaturação fica suspensa até o efeito terminar.
	var glitch := get_node_or_null("../GlitchVisualController") as GlitchVisualController
	var show_grade := grey and not (glitch != null and glitch.active
		and not glitch._reduced())
	if overlay.visible != show_grade:
		overlay.visible = show_grade
