class_name WoodenDollVisual
extends EnemySilhouetteVisual

## Mesma silhueta provisória dos hostis, mas azul e menor. É um seguidor
## visual: não ocupa hex, não bloqueia clique e não entra na iniciativa.
const FOLLOW_OFFSET := Vector2(-41.0, 3.0)

var owner_state: EntityState
var _follow_tween: Tween


func _ready() -> void:
	super._ready()
	is_ally = true
	scale = Vector2.ONE * 0.60
	var hit_area := get_node_or_null("BodyClickArea") as Area2D
	if hit_area != null:
		hit_area.input_pickable = false
	queue_redraw()


func bind_owner(owner: EntityState) -> void:
	if owner_state != null and owner_state.position_changed.is_connected(
			_on_owner_position_changed):
		owner_state.position_changed.disconnect(_on_owner_position_changed)
	owner_state = owner
	if owner_state != null:
		owner_state.position_changed.connect(_on_owner_position_changed)
	reset_for_map()


func reset_for_map() -> void:
	if _follow_tween != null and _follow_tween.is_running():
		_follow_tween.kill()
	if owner_state == null or owner_state.position == EntityState.UNPLACED:
		hide()
		return
	position = PPPMapView.reference_hex_position(owner_state.position) + FOLLOW_OFFSET
	show()


func _on_owner_position_changed(previous: Vector2i, current: Vector2i) -> void:
	if current == EntityState.UNPLACED:
		hide()
		return
	if previous == EntityState.UNPLACED:
		reset_for_map()
		return
	if _follow_tween != null and _follow_tween.is_running():
		_follow_tween.kill()
	show()
	var target := PPPMapView.reference_hex_position(current) + FOLLOW_OFFSET
	var duration := clampf(float(HexGrid.distance(previous, current)) * 0.18, 0.24, 1.8)
	_follow_tween = create_tween()
	_follow_tween.tween_interval(0.12)
	_follow_tween.tween_property(self, "position", target, duration)


func follow_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	if _follow_tween != null and _follow_tween.is_running():
		_follow_tween.kill()
	_follow_tween = create_tween()
	_follow_tween.tween_interval(0.12)
	for coord in path:
		_follow_tween.tween_property(self, "position",
			PPPMapView.reference_hex_position(coord) + FOLLOW_OFFSET, 0.18)
