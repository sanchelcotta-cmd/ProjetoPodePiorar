class_name PlayableActorVisual
extends Node2D

signal walk_finished

## Um desenho reutilizável: a tela de seleção liga apenas EntityData;
## o mapa também liga EntityState para reagir a movimento e perda de Vida.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var active_arrow: Polygon2D = $ActiveArrow
const DEBUFF_MARKER_SCRIPT := preload("res://scripts/visuals/entity_debuff_marker.gd")
const DEATH_BLINK := preload("res://scripts/visuals/death_blink.gd")

var debuff_marker: Node2D

var data: EntityData
var state: EntityState
var _scale_factor: float = 1.0
var _walking: bool = false
var _hurt_queued: bool = false
var _walk_tween: Tween
var _arrow_pulse_time := 0.0
var _death_tween: Tween
var _dying := false


func _draw() -> void:
	if state == null or state.temporary_appearance != &"chicken_form" \
			or state.temporarily_absent_from_map:
		return
	# Silhueta azul provisória; substituir aqui pelos frames da Galinha quando houver arte.
	var blue := Color(0.21, 0.64, 0.94)
	var outline := Color(0.035, 0.13, 0.25)
	draw_circle(Vector2(0, -31), 26, outline)
	draw_circle(Vector2(0, -31), 22, blue)
	draw_circle(Vector2(13, -64), 16, outline)
	draw_circle(Vector2(13, -64), 13, blue)
	draw_colored_polygon(PackedVector2Array([Vector2(23, -67),
		Vector2(42, -61), Vector2(23, -56)]), Color(0.49, 0.85, 1.0))
	draw_line(Vector2(-9, -10), Vector2(-11, 1), outline, 4)
	draw_line(Vector2(10, -10), Vector2(12, 1), outline, 4)
	draw_circle(Vector2(18, -68), 2.5, outline)


func refresh_temporary_visual() -> void:
	visible = state == null or state.current_health > 0 \
		and not state.temporarily_absent_from_map
	animated_sprite.visible = state == null or state.temporary_appearance != &"chicken_form"
	_position_head_indicators()
	queue_redraw()


func _ready() -> void:
	add_to_group("map_entity_visual")
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.animation_finished.connect(_on_animation_finished)
	debuff_marker = DEBUFF_MARKER_SCRIPT.new()
	debuff_marker.name = "DebuffMarker"
	add_child(debuff_marker)


func _process(delta: float) -> void:
	if data != null and data.playable_animation != null:
		_position_head_indicators()
	if not active_arrow.visible:
		return
	_arrow_pulse_time += delta
	# Pisca sem sumir: a transparência fica sempre entre 30% e 90%.
	active_arrow.color.a = lerpf(0.3, 0.9,
		(sin(_arrow_pulse_time * 2.7) + 1.0) * 0.5)


func set_active_marker(is_active: bool) -> void:
	active_arrow.visible = is_active
	if is_active:
		_arrow_pulse_time = 0.0
		active_arrow.color.a = 0.6


func bind_data(character: EntityData) -> void:
	data = character
	if character == null or character.playable_animation == null:
		push_warning("PlayableActorVisual: personagem sem animação vinculada.")
		return
	animated_sprite.sprite_frames = character.playable_animation.create_sprite_frames()
	set_visual_scale(_scale_factor)
	play_idle()


func bind_state(entity: EntityState) -> void:
	if state != null and state.health_changed.is_connected(_on_health_changed):
		state.health_changed.disconnect(_on_health_changed)
	if state != null and state.appearance_changed.is_connected(_on_appearance_changed):
		state.appearance_changed.disconnect(_on_appearance_changed)
	state = entity
	_dying = false
	if _death_tween != null and _death_tween.is_running():
		_death_tween.kill()
	modulate.a = 1.0
	show()
	debuff_marker.call("bind_actor", entity)
	if state != null:
		state.health_changed.connect(_on_health_changed)
		state.appearance_changed.connect(_on_appearance_changed)
	# O personagem no mapa mantém suas cores. Só o retrato na ficha lateral
	# perde a cor quando fica indisponível.
	bind_data(entity.visual_data() if entity != null else null)
	refresh_temporary_visual()


func _on_appearance_changed() -> void:
	if state != null:
		bind_data(state.visual_data())


func set_visual_scale(factor: float) -> void:
	_scale_factor = maxf(factor, 0.1)
	animated_sprite.scale = Vector2.ONE * _scale_factor
	var height := 96
	if data != null and data.playable_animation != null:
		height = data.playable_animation.frame_size.y
	# O pé do quadro fica no centro do hex; não usamos a cabeça como âncora.
	animated_sprite.position = Vector2(0.0, -float(height) * 0.5 * _scale_factor)
	# A ponta da seta fica acima da cabeça, não no rosto do personagem.
	_position_head_indicators()


func _position_head_indicators() -> void:
	var height := 96
	if data != null and data.playable_animation != null:
		height = data.playable_animation.frame_size.y
	var head_top := -float(height) * _scale_factor
	if state != null and state.temporary_appearance == &"chicken_form":
		head_top = -82.0
	debuff_marker.position = Vector2(0.0, head_top - 13.0)
	active_arrow.position = Vector2(0.0,
		head_top - (42.0 if bool(debuff_marker.call("has_debuffs")) else 17.0))


func play_idle() -> void:
	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(&"idle"):
		animated_sprite.flip_h = false
		animated_sprite.play(&"idle")


func play_hurt() -> void:
	if _walking:
		_hurt_queued = true
		return
	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(&"hurt"):
		animated_sprite.flip_h = false
		animated_sprite.play(&"hurt")


func reset_at(coord: Vector2i) -> void:
	if _death_tween != null and _death_tween.is_running():
		_death_tween.kill()
	_dying = false
	modulate.a = 1.0
	refresh_temporary_visual()
	if _walk_tween != null and _walk_tween.is_running():
		_walk_tween.kill()
	_walking = false
	_hurt_queued = false
	position = PPPMapView.reference_hex_position(coord)
	play_idle()


func animate_path(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	if _walk_tween != null and _walk_tween.is_running():
		_walk_tween.kill()
	_walking = true
	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(&"walk"):
		animated_sprite.play(&"walk")
	_walk_tween = create_tween()
	var previous := position
	for coord in path:
		var target := PPPMapView.reference_hex_position(coord)
		_walk_tween.tween_callback(Callable(self, "_face_walk").bind(target.x < previous.x))
		var detour := _visual_detour(previous, target)
		if detour != Vector2.INF:
			# Desvio só visual: o caminho lógico e seu custo continuam iguais.
			_walk_tween.tween_property(self, "position", detour, 0.12)
			_walk_tween.tween_property(self, "position", target, 0.12)
		else:
			_walk_tween.tween_property(self, "position", target, 0.18)
		previous = target
	_walk_tween.finished.connect(_finish_walk)


func _visual_detour(origin: Vector2, destination: Vector2) -> Vector2:
	var direction := destination - origin
	var length_squared := direction.length_squared()
	if length_squared < 1.0:
		return Vector2.INF
	var closest_distance := INF
	var blocker_offset := Vector2.ZERO
	var crossing := 0.0
	for other in get_tree().get_nodes_in_group("map_entity_visual"):
		if other == self or not other is Node2D or not other.visible:
			continue
		var other_local: Vector2 = get_parent().to_local((other as Node2D).global_position)
		var progress := clampf((other_local - origin).dot(direction) / length_squared, 0.0, 1.0)
		if progress <= 0.12 or progress >= 0.88:
			continue
		var offset: Vector2 = other_local - origin.lerp(destination, progress)
		if offset.length() < 38.0 and offset.length() < closest_distance:
			closest_distance = offset.length()
			blocker_offset = offset
			crossing = progress
	if closest_distance == INF:
		return Vector2.INF
	var side := -1.0 if direction.cross(blocker_offset) > 0.0 else 1.0
	var perpendicular := Vector2(-direction.y, direction.x).normalized() * side
	return origin.lerp(destination, crossing) + perpendicular * 38.0


func _face_walk(face_left: bool) -> void:
	animated_sprite.flip_h = face_left


func _finish_walk() -> void:
	_walking = false
	if _hurt_queued:
		_hurt_queued = false
		play_hurt()
	else:
		play_idle()
	walk_finished.emit()


func _on_health_changed(previous: int, current: int) -> void:
	if current <= 0:
		_start_death()
		return
	if _dying and current > 0:
		if _death_tween != null and _death_tween.is_running():
			_death_tween.kill()
		_dying = false
		modulate.a = 1.0
		show()
		refresh_temporary_visual()
		play_idle()
		return
	if current < previous:
		play_hurt()


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"hurt" and _dying:
		animated_sprite.play(&"hurt")
	elif animated_sprite.animation == &"hurt" and not _walking:
		play_idle()


func _start_death() -> void:
	if _dying:
		return
	_dying = true
	if _walk_tween != null and _walk_tween.is_running():
		_walk_tween.kill()
	_walking = false
	set_active_marker(false)
	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(&"hurt"):
		# O Resource escolhe o quadro vermelho; trocar a folha não exige
		# reescrever a lógica da morte.
		animated_sprite.animation = &"hurt"
		animated_sprite.stop()
		var death_frame := data.playable_animation.death_hurt_frame \
			if data != null and data.playable_animation != null else 0
		animated_sprite.frame = mini(death_frame,
			animated_sprite.sprite_frames.get_frame_count(&"hurt") - 1)
	_death_tween = DEATH_BLINK.start(self)
