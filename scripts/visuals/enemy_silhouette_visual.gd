class_name EnemySilhouetteVisual
extends Node2D

signal body_clicked(actor: EntityState, screen_position: Vector2)
signal attack_contact_frame(actor: EntityState, target: EntityState)
const DEBUFF_MARKER_SCRIPT := preload("res://scripts/visuals/entity_debuff_marker.gd")
const DEATH_BLINK := preload("res://scripts/visuals/death_blink.gd")

## Marcador provisório dos inimigos, desenhado em código: corpo humanoide
## escuro com contorno vermelho. O ponto de origem fica nos pés para o Y-sort.
## Substituir pela arte final não muda posição, combate nem EntityState.

var state: EntityState
var is_ally: bool = false
var _walk_tween: Tween
var debuff_marker: Node2D
var _death_tween: Tween
var _dying := false
var _combat_hit_held := false
var _attack_tween: Tween


func _ready() -> void:
	add_to_group("map_entity_visual")
	_ensure_debuff_marker()
	var hit_area := Area2D.new()
	hit_area.name = "BodyClickArea"
	hit_area.input_pickable = true
	hit_area.collision_layer = 1
	hit_area.collision_mask = 0
	add_child(hit_area)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(70.0, 145.0)
	shape.shape = rectangle
	shape.position = Vector2(0.0, -72.5)
	hit_area.add_child(shape)
	hit_area.input_event.connect(_on_body_input)


func _ensure_debuff_marker() -> void:
	if debuff_marker != null:
		return
	debuff_marker = DEBUFF_MARKER_SCRIPT.new()
	debuff_marker.name = "DebuffMarker"
	debuff_marker.position = Vector2(0.0, -157.0)
	add_child(debuff_marker)


func _on_body_input(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed and not event.double_click and state != null:
		body_clicked.emit(state, event.position)


func bind_state(enemy: EntityState, allied: bool = false) -> void:
	if state != null and state.position_changed.is_connected(_on_position_changed):
		state.position_changed.disconnect(_on_position_changed)
	if state != null and state.health_changed.is_connected(_on_health_changed):
		state.health_changed.disconnect(_on_health_changed)
	state = enemy
	_dying = false
	_combat_hit_held = false
	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()
	if _death_tween != null and _death_tween.is_running():
		_death_tween.kill()
	modulate.a = 1.0
	show()
	_ensure_debuff_marker()
	debuff_marker.call("bind_actor", enemy)
	is_ally = allied
	if state != null:
		state.position_changed.connect(_on_position_changed)
		state.health_changed.connect(_on_health_changed)
	queue_redraw()


func play_death() -> void:
	if _dying or _combat_hit_held:
		return
	_dying = true
	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()
	if _walk_tween != null and _walk_tween.is_running():
		_walk_tween.kill()
	var hit_area := get_node_or_null("BodyClickArea") as Area2D
	if hit_area != null:
		hit_area.input_pickable = false
	# A silhueta provisória não possui folha Hurt; o mesmo tom vermelho indica
	# o golpe fatal até a arte final ser adicionada ao Resource da criatura.
	_death_tween = DEATH_BLINK.start(self)
	queue_redraw()


func play_attack(target: EntityState) -> void:
	# Silhuetas ainda não têm sprites de ataque. Três poses deslocadas
	# representam a preparação, avanço e contato até a arte final existir.
	if state == null or target == null or _dying:
		return
	if _attack_tween != null and _attack_tween.is_running():
		_attack_tween.kill()
	var origin := PPPMapView.reference_hex_position(state.position)
	position = origin
	var direction := -1.0 if target.position.x < state.position.x else 1.0
	_attack_tween = create_tween()
	_attack_tween.tween_property(self, "position", origin + Vector2(7.0 * direction, -3.0), 0.06)
	_attack_tween.tween_property(self, "position", origin + Vector2(15.0 * direction, -5.0), 0.06)
	_attack_tween.tween_callback(func() -> void:
		if is_instance_valid(state) and is_instance_valid(target):
			attack_contact_frame.emit(state, target))
	_attack_tween.tween_property(self, "position", origin, 0.13)


func hold_combat_hit() -> void:
	_combat_hit_held = true


func cancel_combat_hit() -> void:
	_combat_hit_held = false


func present_combat_hit() -> void:
	_combat_hit_held = false
	if state == null:
		return
	if state.current_health <= 0:
		play_death()
	else:
		var flash := create_tween()
		flash.tween_property(self, "modulate", Color(1.0, 0.32, 0.35), 0.07)
		flash.tween_property(self, "modulate", Color.WHITE, 0.17)


func _on_health_changed(_previous: int, current: int) -> void:
	if _combat_hit_held and current < _previous:
		return
	if current <= 0:
		play_death()
	elif current < _previous:
		present_combat_hit()
	elif _dying:
		if _death_tween != null and _death_tween.is_running():
			_death_tween.kill()
		_dying = false
		modulate.a = 1.0
		show()
		var hit_area := get_node_or_null("BodyClickArea") as Area2D
		if hit_area != null:
			hit_area.input_pickable = true
		queue_redraw()


func _on_position_changed(_previous: Vector2i, current: Vector2i) -> void:
	if current != EntityState.UNPLACED:
		position = PPPMapView.reference_hex_position(current)


func animate_path(origin: Vector2i, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	if _walk_tween != null and _walk_tween.is_running():
		_walk_tween.kill()
	position = PPPMapView.reference_hex_position(origin)
	_walk_tween = create_tween()
	for coord in path:
		_walk_tween.tween_property(self, "position",
			PPPMapView.reference_hex_position(coord), 0.18)


func _draw() -> void:
	var fill := Color(0.025, 0.16, 0.21, 0.96) if is_ally else \
		Color(0.23, 0.025, 0.045, 0.96)
	if _dying:
		fill = Color(0.86, 0.06, 0.10, 0.97)
	var edge := Color(0.13, 0.86, 1.0, 1.0) if is_ally else \
		Color(1.0, 0.10, 0.16, 1.0)
	var shadow := Color(0.04, 0.01, 0.02, 0.75)
	draw_rect(Rect2(-30.0, -5.0, 60.0, 7.0), shadow)
	# Altura ~145 px, proporcional aos jogáveis da cena.
	draw_circle(Vector2(0.0, -125.0), 17.0, fill)
	draw_arc(Vector2(0.0, -125.0), 17.0, 0.0, TAU, 32, edge, 2.5)
	var body := PackedVector2Array([
		Vector2(-20.0, -105.0), Vector2(20.0, -105.0),
		Vector2(24.0, -52.0), Vector2(13.0, -48.0),
		Vector2(12.0, -7.0), Vector2(2.0, -7.0),
		Vector2(0.0, -48.0), Vector2(-2.0, -7.0),
		Vector2(-12.0, -7.0), Vector2(-13.0, -48.0),
		Vector2(-24.0, -52.0),
	])
	draw_colored_polygon(body, fill)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, edge, 2.5)
	draw_line(Vector2(-19.0, -99.0), Vector2(-34.0, -48.0), edge, 7.0)
	draw_line(Vector2(19.0, -99.0), Vector2(34.0, -48.0), edge, 7.0)
	draw_circle(Vector2(-6.0, -128.0), 2.0, edge)
	draw_circle(Vector2(6.0, -128.0), 2.0, edge)
