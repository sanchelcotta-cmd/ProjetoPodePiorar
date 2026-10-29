class_name PPPFireTreeEmbers
extends Node2D

## Brasas leves, determinísticas para cada árvore. Permanecem dentro do halo
## circular e somem suavemente ao alcançar sua borda superior/lateral.
const COUNT := 14
const HALO_CENTER := Vector2(0, -52)
const HALO_FADE_START := 75.0
const HALO_RADIUS := 126.0
const COLORS := [Color("#cf57f5"), Color("#f06acc"), Color("#a66aff")]

var _rng := RandomNumberGenerator.new()
var _embers: Array[Dictionary] = []


func configure(seed_value: int) -> void:
	_rng.seed = maxi(1, seed_value)
	_embers.clear()
	for index in COUNT:
		_embers.append({})
		_reset(index, true)


func _process(delta: float) -> void:
	if not visible:
		return
	for index in _embers.size():
		var ember := _embers[index]
		ember["age"] = float(ember["age"]) + delta
		if float(ember["age"]) >= float(ember["duration"]):
			_reset(index, false)
	queue_redraw()


func _draw() -> void:
	for ember in _embers:
		var progress: float = float(ember["age"]) / float(ember["duration"])
		var base := ember["origin"] as Vector2
		var swirl: float = sin(progress * TAU * float(ember["turns"])
			+ float(ember["phase"])) * float(ember["amplitude"]) * progress
		var point := base + Vector2(swirl, -float(ember["rise"]) * progress)
		var distance := point.distance_to(HALO_CENTER)
		if distance >= HALO_RADIUS:
			continue
		var edge_alpha := 1.0 - smoothstep(HALO_FADE_START, HALO_RADIUS, distance)
		var life_alpha := smoothstep(0.0, 0.12, progress) \
			* (1.0 - smoothstep(0.74, 1.0, progress))
		var alpha := edge_alpha * life_alpha
		if alpha <= 0.02:
			continue
		var tint := ember["color"] as Color
		draw_circle(point, float(ember["radius"]) * 2.3,
			Color(tint.r, tint.g, tint.b, alpha * 0.18))
		draw_circle(point, float(ember["radius"]),
			Color(tint.r, tint.g, tint.b, alpha * 0.92))


func _reset(index: int, spread_age: bool) -> void:
	var duration := _rng.randf_range(2.0, 3.6)
	_embers[index] = {
		"origin": Vector2(_rng.randf_range(-25.0, 25.0),
			_rng.randf_range(-67.0, -27.0)),
		"age": _rng.randf_range(0.0, duration) if spread_age else 0.0,
		"duration": duration,
		"rise": _rng.randf_range(65.0, 118.0),
		"amplitude": _rng.randf_range(10.0, 23.0),
		"turns": _rng.randf_range(0.8, 1.6),
		"phase": _rng.randf_range(0.0, TAU),
		"radius": _rng.randf_range(1.3, 2.5),
		"color": COLORS[_rng.randi_range(0, COLORS.size() - 1)],
	}
