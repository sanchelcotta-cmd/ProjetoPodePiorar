extends Control

## Ícone vetorial provisório: não depende de fonte emoji nem de sprite.
func _draw() -> void:
	var cyan := Color(0.38, 0.91, 0.96)
	draw_circle(Vector2(21, 24), 8.5, cyan)
	draw_circle(Vector2(21, 14), 4.7, cyan)
	draw_line(Vector2(18, 10), Vector2(14, 6), cyan, 1.5, true)
	draw_line(Vector2(24, 10), Vector2(28, 6), cyan, 1.5, true)
	for y in [19.0, 25.0, 30.0]:
		draw_line(Vector2(13, y), Vector2(7, y - 3), cyan, 1.5, true)
		draw_line(Vector2(29, y), Vector2(35, y - 3), cyan, 1.5, true)
	draw_line(Vector2(21, 17), Vector2(21, 31), Color(0.02, 0.05, 0.07), 1.4, true)
