class_name CarretaVisualController
extends CanvasLayer

## Filtro curto do evento 53. A UI está nas camadas 50+; esta fica na 20.
## Gancho de áudio: tocar/parar o som da Carreta em start_effect/stop_effect.
const RAINBOW_SHADER := preload("res://shaders/carreta_rainbow.gdshader")
const MAX_DURATION := 4.0

var _veil: ColorRect
var _remaining := 0.0


func _ready() -> void:
	layer = 20
	_veil = ColorRect.new()
	_veil.name = "RainbowVeil"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.material = ShaderMaterial.new()
	(_veil.material as ShaderMaterial).shader = RAINBOW_SHADER
	add_child(_veil)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.hide()
	set_process(false)


func start_effect() -> void:
	_remaining = MAX_DURATION
	_veil.show()
	set_process(true)
	# TODO ÁUDIO: iniciar aqui a faixa/efeito alegre da Carreta quando houver asset.


func stop_effect() -> void:
	_remaining = 0.0
	_veil.hide()
	set_process(false)
	# TODO ÁUDIO: parar aqui o som da Carreta junto com a caixa de resultado.


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining <= 0.0:
		stop_effect()
