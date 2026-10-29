class_name EventFollowerVisual
extends Node2D

## Seguidor de Evento: é puramente visual e nunca ocupa um hex lógico.
const IDLE_TEXTURE := preload("res://sprites/entities_allies/event_followers/bonequinho_idle.png")
const WALK_TEXTURE := preload("res://sprites/entities_allies/event_followers/bonequinho_walk.png")
const IMAGINARY_SHADER := preload("res://shaders/imaginary_friend_recolor.gdshader")
const FRAME_SIZE := Vector2i(64, 64)
const WOODEN_OFFSET := Vector2(-36.0, 25.0)
const IMAGINARY_OFFSET := Vector2(36.0, 25.0)

var owner_state: EntityState
var imaginary := false
var sprite: AnimatedSprite2D
var _follow_tween: Tween


func _ready() -> void:
	add_to_group("map_entity_visual")
	set_meta("walk_radius", 25.0)
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = _make_frames()
	sprite.position = Vector2(0.0, -32.0 * SpriteOrientationReference.event_follower_reference_scale())
	sprite.scale = Vector2.ONE * SpriteOrientationReference.event_follower_reference_scale()
	add_child(sprite)
	_set_variant()
	sprite.play(&"idle")


func bind_owner(owner: EntityState, is_imaginary: bool = false) -> void:
	if owner_state != null and owner_state.position_changed.is_connected(
			_on_owner_position_changed):
		owner_state.position_changed.disconnect(_on_owner_position_changed)
	if owner_state != null and owner_state.health_changed.is_connected(
			_on_owner_health_changed):
		owner_state.health_changed.disconnect(_on_owner_health_changed)
	owner_state = owner
	imaginary = is_imaginary
	_set_variant()
	if owner_state != null:
		owner_state.position_changed.connect(_on_owner_position_changed)
		owner_state.health_changed.connect(_on_owner_health_changed)
	reset_for_map()


func reset_for_map() -> void:
	_stop_motion()
	if owner_state == null or owner_state.position == EntityState.UNPLACED \
			or owner_state.current_health <= 0 or owner_state.temporarily_absent_from_map:
		hide()
		return
	position = _target_for(owner_state.position)
	show()
	sprite.play(&"idle")


func _on_owner_position_changed(previous: Vector2i, current: Vector2i) -> void:
	if current == EntityState.UNPLACED:
		_stop_motion()
		hide()
		return
	if previous == EntityState.UNPLACED:
		reset_for_map()
		return
	_move_to(_target_for(current), clampf(float(HexGrid.distance(previous, current)) * 0.18,
		0.24, 1.8))


func _on_owner_health_changed(_previous: int, current: int) -> void:
	if current <= 0:
		_stop_motion()
		hide()
	elif owner_state != null and owner_state.position != EntityState.UNPLACED:
		reset_for_map()


func follow_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	_stop_motion()
	show()
	_follow_tween = create_tween()
	_follow_tween.tween_interval(0.10)
	var from := position
	for coord in path:
		var target := _target_for(coord)
		_append_segment(_follow_tween, from, target, 0.20)
		from = target
	_follow_tween.finished.connect(_play_idle)


func _move_to(target: Vector2, duration: float) -> void:
	_stop_motion()
	show()
	_follow_tween = create_tween()
	_follow_tween.tween_interval(0.10)
	_append_segment(_follow_tween, position, target, duration)
	_follow_tween.finished.connect(_play_idle)


func _append_segment(tween: Tween, from: Vector2, target: Vector2,
		duration: float) -> void:
	if sprite == null:
		return
	sprite.flip_h = target.x < from.x
	sprite.play(&"walk")
	var control := _avoidance_control_point(from, target)
	if control == Vector2.INF:
		tween.tween_property(self, "position", target, duration)
	else:
		tween.tween_method(func(progress: float) -> void:
			position = from.lerp(control, progress).lerp(
				control.lerp(target, progress), progress), 0.0, 1.0, duration)


func _avoidance_control_point(from: Vector2, target: Vector2) -> Vector2:
	var travel := target - from
	if travel.length_squared() < 625.0 or not get_parent() is Node2D:
		return Vector2.INF
	var nearest := INF
	var side := 0.0
	var blockers := get_tree().get_nodes_in_group("map_entity_visual")
	blockers.append_array(get_tree().get_nodes_in_group("map_walk_obstacle"))
	for other in blockers:
		if other == self or not other is Node2D or not other.visible:
			continue
		var point := (get_parent() as Node2D).to_local(other.global_position)
		var progress := (point - from).dot(travel) / travel.length_squared()
		if progress <= 0.10 or progress >= 0.90:
			continue
		var projected := from + travel * progress
		var clearance := point.distance_to(projected)
		var radius := float(other.get_meta("walk_radius", 30.0))
		if clearance < radius and clearance < nearest:
			nearest = clearance
			side = travel.cross(point - from)
	if nearest == INF:
		return Vector2.INF
	var perpendicular := Vector2(-travel.y, travel.x).normalized()
	return from.lerp(target, 0.5) + perpendicular * (-48.0 if side >= 0.0 else 48.0)


func _target_for(coord: Vector2i) -> Vector2:
	return PPPMapView.reference_hex_position(coord) + \
		(IMAGINARY_OFFSET if imaginary else WOODEN_OFFSET)


func _play_idle() -> void:
	if is_instance_valid(sprite):
		sprite.play(&"idle")


func _stop_motion() -> void:
	if _follow_tween != null and _follow_tween.is_running():
		_follow_tween.kill()


func _set_variant() -> void:
	if sprite == null:
		return
	if imaginary:
		var material := ShaderMaterial.new()
		material.shader = IMAGINARY_SHADER
		sprite.material = material
	else:
		sprite.material = null


static func _make_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.set_animation_speed(&"idle", 5.0)
	frames.add_animation(&"walk")
	frames.set_animation_speed(&"walk", 10.0)
	for frame_index in 16:
		var frame := AtlasTexture.new()
		frame.atlas = IDLE_TEXTURE
		frame.region = Rect2i((frame_index % 4) * FRAME_SIZE.x,
			(frame_index / 4) * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(&"idle", frame)
	for frame_index in 8:
		var frame := AtlasTexture.new()
		frame.atlas = WALK_TEXTURE
		frame.region = Rect2i((frame_index % 4) * FRAME_SIZE.x,
			(frame_index / 4) * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame(&"walk", frame)
	return frames
