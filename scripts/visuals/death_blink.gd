class_name DeathBlink
extends RefCounted

## Saída visual compartilhada por jogáveis, aliados e hostis. O estado de Vida
## já é zero antes daqui; a animação não atrasa o resultado lógico do combate.
static func start(visual: CanvasItem) -> Tween:
	if visual == null or not visual.is_inside_tree():
		return null
	visual.show()
	visual.modulate.a = 1.0
	var tween := visual.create_tween()
	var comfort := visual.get_node_or_null("/root/VisualComfort")
	if comfort != null and bool(comfort.get("enabled")):
		# Morte continua visível, mas sem alternância rápida de opacidade.
		tween.tween_property(visual, "modulate:a", 0.0, 0.65)
		tween.tween_callback(visual.hide)
		return tween
	for blink in 3:
		# Três piscadas de 0,5 s, com 0,5 s entre elas: 2,5 s no total.
		tween.tween_property(visual, "modulate:a", 0.10, 0.25)
		tween.tween_property(visual, "modulate:a", 1.0, 0.25)
		if blink < 2:
			tween.tween_interval(0.5)
	tween.tween_callback(visual.hide)
	return tween
