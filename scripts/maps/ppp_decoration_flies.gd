class_name PPPDecorationFlies
extends Node2D

## Pontos escuros discretos em órbitas curtas ao redor da lâmpada.
var _time := 0.0


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	for index in 4:
		var phase := _time * (1.6 + index * 0.27) + index * TAU / 4.0
		var point := Vector2(cos(phase) * (14.0 + index * 3.0),
			sin(phase * 1.3) * (8.0 + index * 2.0))
		draw_circle(point, 1.5, Color(0.04, 0.04, 0.06, 0.75))
