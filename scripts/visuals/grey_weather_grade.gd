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
	if overlay.visible != grey:
		overlay.visible = grey
