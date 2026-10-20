extends Node2D

## Marcadores de condições sobre a entidade no mapa. Lê o EntityState real,
## portanto funciona para jogáveis, aliados e hostis sem duplicar efeitos.
const RADIUS := 12.0
const STEP := 27.0
const ICON_SIZE := 19.0
const FILL := Color(0.025, 0.025, 0.035, 0.9)
const EDGE := Color(0.72, 0.19, 0.25, 0.95)

var actor: EntityState
var _icons: Array[Texture2D] = []
var _instances: Array[DebuffInstanceState] = []
var _signature := ""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_signature = ""
	_refresh()


func bind_actor(value: EntityState) -> void:
	actor = value
	_signature = ""
	_refresh()


func has_debuffs() -> bool:
	return not _icons.is_empty()


func _process(_delta: float) -> void:
	if actor != null:
		_refresh()


func _refresh() -> void:
	var signature := ""
	if actor != null:
		for instance in actor.debuffs:
			if instance != null and instance.data != null:
				signature += "%d:%d|" % [instance.get_instance_id(),
					instance.data.icon.get_instance_id() if instance.data.icon != null else 0]
	if signature == _signature:
		return
	_signature = signature
	_icons.clear()
	_instances.clear()
	if actor != null:
		for instance in actor.debuffs:
			if instance != null and instance.data != null:
				_instances.append(instance)
				_icons.append(instance.data.icon)
	visible = not _icons.is_empty()
	queue_redraw()


## Retângulos de tela para o HUD capturar hover/clique sem alterar o desenho.
func get_inspection_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	if not is_visible_in_tree():
		return targets
	var row_width := float(maxi(0, _instances.size() - 1)) * STEP
	var transform := get_global_transform_with_canvas()
	var bounds_size := Vector2(absf(transform.x.x), absf(transform.y.y)) * RADIUS * 2.0
	for index in _instances.size():
		var center := Vector2(float(index) * STEP - row_width * 0.5, 0.0)
		targets.append({"instance": _instances[index],
			"rect": Rect2(transform * center - bounds_size * 0.5, bounds_size)})
	return targets


func _draw() -> void:
	var row_width := float(maxi(0, _icons.size() - 1)) * STEP
	for index in _icons.size():
		var center := Vector2(float(index) * STEP - row_width * 0.5, 0.0)
		draw_circle(center, RADIUS, FILL)
		draw_arc(center, RADIUS, 0.0, TAU, 24, EDGE, 1.25)
		if _icons[index] != null:
			draw_texture_rect(_icons[index], Rect2(center - Vector2.ONE * ICON_SIZE * 0.5,
				Vector2.ONE * ICON_SIZE), false)
