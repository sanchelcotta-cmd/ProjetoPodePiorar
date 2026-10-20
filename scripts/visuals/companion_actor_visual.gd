class_name CompanionActorVisual
extends Node2D

## O Resource diz COMO desenhar; EntityState decide QUAL cor esta instância
## recebeu. O Gatinho solto passeia só visualmente e não ocupa hex lógico.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
const DEBUFF_MARKER_SCRIPT := preload("res://scripts/visuals/entity_debuff_marker.gd")
const DEATH_BLINK := preload("res://scripts/visuals/death_blink.gd")

var debuff_marker: Node2D

var state: EntityState
var owner_state: EntityState
var grid: HexGrid
var _animation: SpriteSheetAnimationData
var _motion: Tween
var _roam_timer: Timer
var _landing_timer: Timer
var _rng := RandomNumberGenerator.new()
var _is_cat: bool = false
var _is_dog: bool = false
var _carrying_cat: bool = false
var _carry_target: Vector2
var _mouse_carried := false
var _carry_preview := false
var _carry_origin := Vector2.ZERO
var _previous_z_index := 0
var _death_tween: Tween
var _dying := false


func _ready() -> void:
	add_to_group("map_entity_visual")
	debuff_marker = DEBUFF_MARKER_SCRIPT.new()
	debuff_marker.name = "DebuffMarker"
	add_child(debuff_marker)
	_rng.randomize()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.animation_finished.connect(_on_animation_finished)
	_roam_timer = Timer.new()
	_roam_timer.one_shot = true
	_roam_timer.timeout.connect(_roam)
	add_child(_roam_timer)
	_landing_timer = Timer.new()
	_landing_timer.one_shot = true
	_landing_timer.timeout.connect(_finish_landing)
	add_child(_landing_timer)


func bind_companion(companion: EntityState, companion_owner: EntityState,
		current_grid: HexGrid) -> void:
	if state != null and state.position_changed.is_connected(_on_companion_position_changed):
		state.position_changed.disconnect(_on_companion_position_changed)
	if state != null and state.health_changed.is_connected(_on_health_changed):
		state.health_changed.disconnect(_on_health_changed)
	if owner_state != null and owner_state.position_changed.is_connected(_on_owner_position_changed):
		owner_state.position_changed.disconnect(_on_owner_position_changed)
	state = companion
	_dying = false
	if _death_tween != null and _death_tween.is_running():
		_death_tween.kill()
	modulate.a = 1.0
	debuff_marker.call("bind_actor", companion)
	owner_state = companion_owner
	grid = current_grid
	_animation = state.get_animation_variant() if state != null else null
	_is_cat = state != null and state.data != null \
		and &"gatinho_vira_lata" in state.data.tags
	_is_dog = state != null and state.data != null \
		and &"doguinho_caramelo" in state.data.tags
	if _animation == null:
		push_warning("CompanionActorVisual: companheiro sem aparência sorteada.")
		visible = false
		return
	visible = true
	sprite.sprite_frames = _animation.create_sprite_frames()
	sprite.scale = Vector2.ONE * 1.25
	sprite.position = Vector2(0.0, -float(_animation.canvas_size.y) * 0.5 * 1.25)
	debuff_marker.position = Vector2(0.0, -float(_animation.canvas_size.y) * 1.25 - 13.0)
	state.position_changed.connect(_on_companion_position_changed)
	state.health_changed.connect(_on_health_changed)
	if owner_state != null:
		owner_state.position_changed.connect(_on_owner_position_changed)
	reset_for_map(current_grid)
	# Trocar de mapa enquanto o cão ainda busca não o traz de volta cedo.
	if owner_state != null and owner_state.turn_serial < state.unavailable_until_owner_turn_serial:
		visible = false


func reset_for_map(current_grid: HexGrid) -> void:
	grid = current_grid
	_stop_motion()
	if state == null:
		return
	if state.current_health <= 0:
		hide()
		return
	if grid != null and grid.is_valid(state.position):
		position = PPPMapView.reference_hex_position(state.position)
		play_idle()
		return
	# Sem posição lógica: gatinho passeia somente por cima do asfalto.
	# O cão acompanha visualmente o dono, sem bloquear hex.
	position = _owner_visual_position()
	play_idle()
	if _is_cat or _is_dog:
		_schedule_roam()


func play_idle() -> void:
	if sprite.sprite_frames == null:
		return
	var idle_name := &"idle_alt" if _rng.randf() < 0.35 \
		and sprite.sprite_frames.has_animation(&"idle_alt") else &"idle"
	if sprite.sprite_frames.has_animation(idle_name):
		sprite.play(idle_name)
		sprite.frame = _rng.randi_range(0, sprite.sprite_frames.get_frame_count(idle_name) - 1)


func begin_mouse_carry() -> bool:
	if not _is_cat or not visible or grid == null \
			or grid.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION:
		return false
	_stop_motion()
	_carry_origin = position
	_previous_z_index = z_index
	z_index = 100
	_mouse_carried = true
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"carrying_pickup"):
		sprite.play(&"carrying_pickup")
	return true


func update_mouse_carry(screen_position: Vector2) -> void:
	if _mouse_carried and get_parent() is CanvasItem:
		var parent_canvas := (get_parent() as CanvasItem).get_global_transform_with_canvas()
		position = parent_canvas.affine_inverse() * screen_position + Vector2(0.0, -30.0)


func preview_mouse_drop(coord: Vector2i) -> void:
	if not _mouse_carried:
		return
	_mouse_carried = false
	_carry_preview = true
	z_index = _previous_z_index
	position = PPPMapView.reference_hex_position(coord)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"carrying_landing"):
		sprite.play(&"carrying_landing")
		_landing_timer.start(1.5)
	else:
		play_idle()


func cancel_mouse_drop() -> void:
	if not (_mouse_carried or _carry_preview):
		return
	_mouse_carried = false
	_carry_preview = false
	z_index = _previous_z_index
	position = _carry_origin
	play_idle()
	if state != null and state.position == EntityState.UNPLACED:
		_schedule_roam()


func play_attack() -> void:
	_play_once(&"attack")


func play_jump() -> void:
	_play_once(&"jump")


func animate_combat_path(origin: Vector2i, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	_stop_motion()
	position = PPPMapView.reference_hex_position(origin)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"walk"):
		sprite.flip_h = path[0].x < origin.x
		sprite.play(&"walk")
	_motion = create_tween()
	for coord in path:
		_motion.tween_property(self, "position",
			PPPMapView.reference_hex_position(coord), 0.18)
	_motion.finished.connect(play_idle)


func start_fetching() -> void:
	# Enquanto busca o item, o Doguinho está fora do mapa e indisponível.
	_stop_motion()
	visible = false


func return_walking() -> void:
	visible = true
	reset_for_map(grid)
	var destination := position
	position += Vector2(52.0, 0.0)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"walk"):
		sprite.flip_h = true
		sprite.play(&"walk")
	_motion = create_tween()
	_motion.tween_property(self, "position", destination, 1.25)
	_motion.finished.connect(play_idle)


func _play_once(animation_name: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)


func _on_companion_position_changed(_old: Vector2i, current: Vector2i) -> void:
	if _carry_preview and grid != null and grid.is_valid(current) \
			and position.is_equal_approx(PPPMapView.reference_hex_position(current)):
		_carry_preview = false
		return
	_stop_motion()
	if grid != null and grid.is_valid(current):
		var target := PPPMapView.reference_hex_position(current)
		if grid.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
			position = target
			play_idle()
		elif _is_cat and sprite.sprite_frames != null \
				and sprite.sprite_frames.has_animation(&"carrying_pickup"):
			_start_carry_to(target)
		else:
			position = target
			play_jump()
	else:
		position = _owner_visual_position()
		play_idle()
		if _is_cat or _is_dog:
			_schedule_roam()


func _on_owner_position_changed(_old: Vector2i, _current: Vector2i) -> void:
	if state == null or state.position != EntityState.UNPLACED or _is_cat or not visible:
		return
	_stop_motion()
	_walk_to(_owner_visual_position(), true)


func _owner_visual_position() -> Vector2:
	if owner_state == null:
		return Vector2.ZERO
	return PPPMapView.reference_hex_position(owner_state.position) + Vector2(34.0, 25.0)


func _schedule_roam() -> void:
	if not (_is_cat or _is_dog) or state == null \
			or state.position != EntityState.UNPLACED or not visible \
			or _mouse_carried or _carry_preview:
		return
	# Pausas visuais curtas; não contam como posição/turno lógico.
	_roam_timer.start(_rng.randf_range(6.0, 12.0))


func _roam() -> void:
	if not (_is_cat or _is_dog) or state == null \
			or state.position != EntityState.UNPLACED or grid == null or not visible \
			or _mouse_carried or _carry_preview:
		return
	var around := owner_state.position if owner_state != null else Vector2i(0, 2)
	# O destino fica no corredor ENTRE centros, nunca sobre o ponto clicável
	# de um hex. Isto é só desenho; position lógico continua UNPLACED.
	var destination := Vector2i(clampi(around.x + _rng.randi_range(-1, 2), 0,
		HexGrid.PPP_MAP_WIDTH - 1), clampi(around.y + _rng.randi_range(-1, 1), 0,
		HexGrid.PPP_MAP_HEIGHT - 1))
	var target := PPPMapView.reference_hex_position(destination) + Vector2(34.0, 25.0)
	if _is_cat and _rng.randf() < 0.35 and position.distance_to(target) > 60.0:
		_jump_to(target)
	else:
		_walk_to(target, true)


func _jump_to(target: Vector2) -> void:
	var origin := position
	var duration := clampf(origin.distance_to(target) / 140.0, 0.45, 1.25)
	sprite.flip_h = target.x < origin.x
	_play_once(&"jump")
	_motion = create_tween()
	_motion.tween_method(func(progress: float) -> void:
		# Arco modesto, com ambos os pés novamente no ground ao terminar.
		position = origin.lerp(target, progress) - Vector2(0.0, sin(progress * PI) * 24.0),
		0.0, 1.0, duration)
	_motion.finished.connect(func() -> void:
		position = target
		play_idle()
		_schedule_roam())


func _walk_to(target: Vector2, resume_roam: bool) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"walk"):
		sprite.flip_h = target.x < position.x
		sprite.play(&"walk")
	_motion = create_tween()
	_motion.tween_property(self, "position", target,
		maxf(0.25, position.distance_to(target) / 85.0))
	_motion.finished.connect(func() -> void:
		play_idle()
		if resume_roam:
			_schedule_roam()
	)


func _start_carry_to(target: Vector2) -> void:
	_carry_target = target
	_carrying_cat = true
	# O quarto desenho não entra nesta animação: só aparece no pouso.
	sprite.play(&"carrying_pickup")


func _begin_held_travel() -> void:
	if not _carrying_cat:
		return
	# Alterna lentamente os desenhos 2 e 3 durante TODO o transporte.
	sprite.play(&"carrying_held")
	_motion = create_tween()
	_motion.tween_property(self, "position", _carry_target,
		maxf(1.2, position.distance_to(_carry_target) / 85.0))
	_motion.finished.connect(_land_cat)


func _land_cat() -> void:
	if not _carrying_cat:
		return
	position = _carry_target
	sprite.play(&"carrying_landing")
	_landing_timer.start(1.5)


func _finish_landing() -> void:
	_carrying_cat = false
	play_idle()


func _stop_motion() -> void:
	_carrying_cat = false
	_mouse_carried = false
	_carry_preview = false
	if _motion != null and _motion.is_running():
		_motion.kill()
	if _roam_timer != null:
		_roam_timer.stop()
	if _landing_timer != null:
		_landing_timer.stop()


func _on_animation_finished() -> void:
	if _dying and sprite.animation == &"hurt":
		sprite.play(&"hurt")
		return
	if sprite.animation == &"carrying_pickup" and _mouse_carried:
		sprite.play(&"carrying_held")
		return
	if sprite.animation == &"carrying_pickup" and _carrying_cat:
		_begin_held_travel()
		return
	if sprite.animation == &"jump" and _motion != null and _motion.is_running():
		return
	if sprite.animation in [&"attack", &"jump", &"hurt"]:
		play_idle()


func _on_health_changed(_previous: int, current: int) -> void:
	if current <= 0:
		if _dying:
			return
		_dying = true
		_stop_motion()
		if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"hurt"):
			sprite.animation = &"hurt"
			sprite.stop()
			sprite.frame = mini(_animation.death_hurt_frame,
				sprite.sprite_frames.get_frame_count(&"hurt") - 1)
		else:
			# Pets ainda não têm folha Hurt própria; vermelho temporário no sprite.
			sprite.modulate = Color(1.0, 0.20, 0.24)
		_death_tween = DEATH_BLINK.start(self)
	elif _dying:
		if _death_tween != null and _death_tween.is_running():
			_death_tween.kill()
		_dying = false
		modulate.a = 1.0
		sprite.modulate = Color.WHITE
		show()
		play_idle()
