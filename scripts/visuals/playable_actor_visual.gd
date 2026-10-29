class_name PlayableActorVisual
extends Node2D

signal walk_finished
signal attack_contact_frame(actor: EntityState, target: EntityState)
signal projectile_arrived(actor: EntityState, target: EntityState)

## Um desenho reutilizável: a tela de seleção liga apenas EntityData;
## o mapa também liga EntityState para reagir a movimento e perda de Vida.
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var weapon_hand_bone: Bone2D = $WeaponSkeleton/WeaponHandBone
@onready var held_weapon_sprite: Sprite2D = $WeaponSkeleton/WeaponHandBone/HeldWeapon
@onready var sling_elastic: Line2D = $WeaponSkeleton/SlingElastic
@onready var sling_elastic_highlight: Line2D = $WeaponSkeleton/SlingElasticHighlight
@onready var active_arrow: Polygon2D = $ActiveArrow
const DEBUFF_MARKER_SCRIPT := preload("res://scripts/visuals/entity_debuff_marker.gd")
const DEATH_BLINK := preload("res://scripts/visuals/death_blink.gd")
const CHICKEN_ANIMATION := preload("res://resources/entities/animations/galinha_animation.tres")
const HEX_MOVE_SECONDS := 0.225
const DETOUR_HALF_SECONDS := 0.15
const MAX_HEX_MOVE_SECONDS := DETOUR_HALF_SECONDS * 2.0
const THROWN_IMPACT_WEAPONS: Array[StringName] = [&"aa_00009", &"aa_00004"]

var debuff_marker: Node2D

var data: EntityData
var state: EntityState
var _scale_factor: float = 1.0
var _walking: bool = false
var _hurt_queued: bool = false
var _hurt_blink_version := 0
var _hurt_blinking := false
var _walk_tween: Tween
var _arrow_pulse_time := 0.0
var _death_tween: Tween
var _dying := false
var _held_texture_cache: Dictionary = {}
var _pending_attack_weapon: ItemData
var _pending_attack_target: EntityState
var _attack_aspect: StringName = &""
var _projectile_launched := false
var _thrown_in_flight := false
var _attack_contact_sent := false
var _combat_hit_held := false
var _bound_animation: PlayableAnimationData
static var _egg_texture: Texture2D


func _animation_data() -> PlayableAnimationData:
	if state != null and state.temporary_appearance == &"chicken_form":
		return CHICKEN_ANIMATION
	return data.playable_animation if data != null else null


func _is_chicken_form() -> bool:
	return state != null and state.temporary_appearance == &"chicken_form"


func refresh_temporary_visual() -> void:
	visible = state == null or state.current_health > 0 \
		and not state.temporarily_absent_from_map
	var animation := _animation_data()
	if animation != null and animation != _bound_animation:
		_bound_animation = animation
		animated_sprite.sprite_frames = animation.create_sprite_frames()
		set_visual_scale(_scale_factor)
		play_idle()
	animated_sprite.visible = true
	_update_held_weapon()
	_position_head_indicators()


func _ready() -> void:
	add_to_group("map_entity_visual")
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.frame_changed.connect(_on_hurt_frame_changed)
	animated_sprite.frame_changed.connect(_update_weapon_hand_bone)
	animated_sprite.animation_changed.connect(_update_weapon_hand_bone)
	animated_sprite.frame_changed.connect(_on_attack_frame_changed)
	debuff_marker = DEBUFF_MARKER_SCRIPT.new()
	debuff_marker.name = "DebuffMarker"
	add_child(debuff_marker)


func _process(delta: float) -> void:
	if _animation_data() != null:
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
	_bound_animation = character.playable_animation
	animated_sprite.sprite_frames = _bound_animation.create_sprite_frames()
	_held_texture_cache.clear()
	set_visual_scale(_scale_factor)
	play_idle()
	_update_weapon_hand_bone()


func bind_state(entity: EntityState) -> void:
	if state != null and state.health_changed.is_connected(_on_health_changed):
		state.health_changed.disconnect(_on_health_changed)
	if state != null and state.appearance_changed.is_connected(_on_appearance_changed):
		state.appearance_changed.disconnect(_on_appearance_changed)
	if state != null and state.equipment_changed.is_connected(_update_held_weapon):
		state.equipment_changed.disconnect(_update_held_weapon)
	state = entity
	_held_texture_cache.clear()
	_thrown_in_flight = false
	_dying = false
	_combat_hit_held = false
	if _death_tween != null and _death_tween.is_running():
		_death_tween.kill()
	modulate.a = 1.0
	show()
	debuff_marker.call("bind_actor", entity)
	if state != null:
		state.health_changed.connect(_on_health_changed)
		state.appearance_changed.connect(_on_appearance_changed)
		state.equipment_changed.connect(_update_held_weapon)
	# O personagem no mapa mantém suas cores. Só o retrato na ficha lateral
	# perde a cor quando fica indisponível.
	bind_data(entity.visual_data() if entity != null else null)
	refresh_temporary_visual()


func _on_appearance_changed() -> void:
	if state != null:
		bind_data(state.visual_data())
		refresh_temporary_visual()


func set_visual_scale(factor: float) -> void:
	_scale_factor = maxf(factor, 0.1)
	var sprite_scale := SpriteOrientationReference.chicken_reference_scale() \
		if _is_chicken_form() else _scale_factor
	animated_sprite.scale = Vector2.ONE * sprite_scale
	var height := 96
	var animation := _animation_data()
	if animation != null:
		height = animation.frame_size.y
	# O pé do quadro fica no centro do hex; não usamos a cabeça como âncora.
	animated_sprite.position = Vector2(0.0, -float(height) * 0.5 * sprite_scale)
	# A ponta da seta fica acima da cabeça, não no rosto do personagem.
	_position_head_indicators()
	_update_weapon_hand_bone()


func _position_head_indicators() -> void:
	var height := 96
	var animation := _animation_data()
	if animation != null:
		height = animation.frame_size.y
	var head_top := -float(height) * animated_sprite.scale.y
	debuff_marker.position = Vector2(0.0, head_top - 13.0)
	active_arrow.position = Vector2(0.0,
		head_top - (42.0 if bool(debuff_marker.call("has_debuffs")) else 17.0))


func play_idle() -> void:
	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(&"idle"):
		animated_sprite.flip_h = false
		animated_sprite.play(&"idle")
		_attack_aspect = &""
		_update_weapon_hand_bone()


static func attack_clip_for_weapon(weapon: ItemData) -> StringName:
	# Sem arma, o gesto desarmado usa a folha de lâmina. Chinelo e
	# Bumerangue são lançados erguendo a mão, apesar da Maestria Distância.
	if weapon == null:
		return &"attack_blade"
	if weapon.id in THROWN_IMPACT_WEAPONS:
		return &"attack_impact"
	match weapon.mastery_granted:
		EntityData.Mastery.IMPACT:
			return &"attack_impact"
		EntityData.Mastery.RANGED:
			return &"attack_ranged"
		_:
			return &"attack_blade"


func play_attack(weapon: ItemData = null, target: EntityState = null,
		allow_projectile: bool = true, dagger_aspect: StringName = &"") -> void:
	if _dying or animated_sprite.sprite_frames == null:
		return
	# A resolução do golpe pode chegar no mesmo quadro em que o Tween de
	# aproximação termina. Impedir que _finish_walk volte a Idle sobre o ataque.
	if _walking:
		_walking = false
		if _walk_tween != null and _walk_tween.is_running():
			_walk_tween.kill()
		if state != null and state.position != EntityState.UNPLACED:
			position = PPPMapView.reference_hex_position(state.position)
	var clip := &"attack_blade" if _is_chicken_form() \
		else attack_clip_for_weapon(weapon)
	if not animated_sprite.sprite_frames.has_animation(clip):
		clip = &"attack_blade"
	if not animated_sprite.sprite_frames.has_animation(clip):
		return
	_hurt_blink_version += 1
	_hurt_blinking = false
	_pending_attack_weapon = weapon if allow_projectile else null
	_pending_attack_target = target
	_projectile_launched = false
	_attack_contact_sent = false
	_attack_aspect = dagger_aspect
	animated_sprite.visible = true
	animated_sprite.flip_h = state != null and target != null \
		and target.position.x < state.position.x
	animated_sprite.animation = clip
	animated_sprite.set_frame_and_progress(0, 0.0)
	animated_sprite.play()
	_update_weapon_hand_bone()


func play_boomerang_interception(weapon: ItemData,
		attacker: EntityState) -> void:
	# A interceptação é uma Esquiva bem-sucedida, não um contra-ataque:
	# reproduz o mesmo gesto de arremesso e só desenha a ida do projétil.
	play_attack(weapon, attacker)


func _on_attack_frame_changed() -> void:
	if not _attack_contact_sent and animated_sprite.frame == 2 \
			and animated_sprite.animation in [&"attack_blade", &"attack_impact",
				&"attack_ranged"]:
		_attack_contact_sent = true
		if state != null and _pending_attack_target != null:
			attack_contact_frame.emit(state, _pending_attack_target)
	if _projectile_launched or animated_sprite.animation not in [
			&"attack_blade", &"attack_impact", &"attack_ranged"]:
		return
	if _pending_attack_weapon == null or _pending_attack_target == null \
			or not (_is_chicken_form() and _pending_attack_weapon.mastery_granted \
				== EntityData.Mastery.RANGED) \
			and (_pending_attack_weapon.id not in [&"aa_00002", &"aa_00004",
				&"aa_00009", &"aa_00010"] or animated_sprite.animation \
				== &"attack_blade"):
		return
	var release_frame := 2 if _is_chicken_form() or _pending_attack_weapon.id in [
		&"aa_00004", &"aa_00009"] else 3
	if animated_sprite.frame != release_frame:
		return
	_projectile_launched = true
	_launch_weapon_projectile(_pending_attack_weapon, _pending_attack_target)


func _launch_weapon_projectile(weapon: ItemData, target: EntityState) -> void:
	var layer := get_parent() as Node2D
	if layer == null:
		return
	var projectile := Sprite2D.new()
	projectile.name = "WeaponProjectile"
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_index = 4
	if _is_chicken_form():
		projectile.texture = _chicken_egg_texture()
		projectile.scale = Vector2.ONE * 1.5
	else:
		match weapon.id:
			&"aa_00002":
				projectile.texture = WeaponHandVisual.arrow_texture(0)
				projectile.scale = Vector2.ONE * 1.40
			&"aa_00010":
				projectile.texture = WeaponHandVisual.sling_ball_texture()
				projectile.scale = Vector2.ONE * 0.72
			_:
				projectile.texture = WeaponHandVisual.make_projectile_texture(
					WeaponHandVisual.variant(weapon.id))
				projectile.scale = Vector2.ONE * WeaponHandVisual.held_scale(weapon.id)
				_thrown_in_flight = true
				_update_held_weapon()
	layer.add_child(projectile)
	var origin := layer.to_local(to_global(Vector2(20.0, -48.0))) \
		if _is_chicken_form() else layer.to_local(weapon_hand_bone.global_position)
	var destination := PPPMapView.reference_hex_position(target.position) \
		+ Vector2(0.0, -42.0)
	projectile.position = origin
	var curved := _is_chicken_form() or weapon.id in [&"aa_00004", &"aa_00009"]
	if not curved:
		projectile.rotation = (destination - origin).angle()
	var flight := projectile.create_tween()
	var update_flight := func(progress: float) -> void:
		if not is_instance_valid(projectile):
			return
		projectile.position = origin.lerp(destination, progress)
		if curved:
			projectile.position.y -= 58.0 * 4.0 * progress * (1.0 - progress)
			projectile.rotation = progress * TAU * 2.0
		elif weapon.id == &"aa_00002":
			projectile.texture = WeaponHandVisual.arrow_texture(int(progress * 10.0))
	flight.tween_method(update_flight, 0.0, 1.0, 0.40)
	flight.finished.connect(func() -> void:
		projectile.queue_free()
		if is_instance_valid(self):
			_thrown_in_flight = false
			_update_held_weapon()
			if state != null and is_instance_valid(target):
				projectile_arrived.emit(state, target))


static func _chicken_egg_texture() -> Texture2D:
	if _egg_texture != null:
		return _egg_texture
	var pixels := Image.create(12, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in 8:
		for x in 12:
			var dx := (float(x) - 5.5) / 5.5
			var dy := (float(y) - 3.5) / 3.5
			if dx * dx + dy * dy <= 1.0:
				pixels.set_pixel(x, y, Color("#f4f0da") if y > 4 \
					else Color.WHITE)
	_egg_texture = ImageTexture.create_from_image(pixels)
	return _egg_texture


func _update_weapon_hand_bone() -> void:
	var animation := _animation_data()
	if weapon_hand_bone == null or animation == null:
		return
	var points := animation.hand_bone_points(animated_sprite.animation,
		animated_sprite.frame)
	if points.is_empty():
		weapon_hand_bone.visible = false
		held_weapon_sprite.visible = false
		return
	var center := Vector2(animation.frame_size) * 0.5
	var root_point: Vector2 = points.root
	var tip_point: Vector2 = points.tip
	if animated_sprite.flip_h:
		root_point.x = float(animation.frame_size.x) - root_point.x
		tip_point.x = float(animation.frame_size.x) - tip_point.x
	var root_local := animated_sprite.position + \
		(root_point - center) * animated_sprite.scale
	var tip_local := animated_sprite.position + \
		(tip_point - center) * animated_sprite.scale
	weapon_hand_bone.position = root_local
	weapon_hand_bone.rotation = (tip_local - root_local).angle()
	weapon_hand_bone.length = root_local.distance_to(tip_local)
	weapon_hand_bone.visible = true
	_update_held_weapon()


func _update_held_weapon() -> void:
	if sling_elastic != null:
		sling_elastic.visible = false
		sling_elastic_highlight.visible = false
	if held_weapon_sprite == null or state == null or data == null \
			or _thrown_in_flight or state.temporary_appearance == &"chicken_form" \
			or not animated_sprite.visible or not weapon_hand_bone.visible:
		if held_weapon_sprite != null:
			held_weapon_sprite.visible = false
		return
	var equipped := state.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	var weapon: ItemData = equipped.data if equipped != null else null
	var purple_symbiosis := false
	if weapon == null:
		for grant in state.skill_grants:
			if grant.skill != null and grant.skill.id == &"permanent_passive_058" \
					and grant.bound_source is ItemData:
				weapon = grant.bound_source as ItemData
				purple_symbiosis = weapon.rarity == ItemData.Rarity.EPIC
				break
	if weapon == null:
		held_weapon_sprite.visible = false
		return
	var aspect := _attack_aspect if _attack_aspect != &"" \
		else state.dagger_next_aspect
	var spec := WeaponHandVisual.variant(weapon.id, aspect,
		animated_sprite.animation, animated_sprite.frame)
	if spec.is_empty():
		held_weapon_sprite.visible = false
		return
	var key := "%s:%s:%d:%s:%s:%s" % [state.data.id, weapon.id,
		int(spec["cell"]), aspect, str(purple_symbiosis),
		str(bool(spec.get("dynamic_elastic", false)))]
	if not _held_texture_cache.has(key):
		_held_texture_cache[key] = WeaponHandVisual.make_held_texture(spec,
			WeaponHandVisual.skin_for_playable(state.data.id), purple_symbiosis,
			WeaponHandVisual.held_scale(weapon.id))
	var result: Dictionary = _held_texture_cache[key]
	held_weapon_sprite.texture = result["texture"] as Texture2D
	var grip: Vector2 = result["grip"]
	held_weapon_sprite.offset = Vector2(24.0, 48.0) - grip
	if weapon.id == &"aa_00010" and animated_sprite.flip_h:
		# Ao espelhar o PNG, a empunhadura também muda de lado no retângulo.
		held_weapon_sprite.offset.x = grip.x - 24.0
	held_weapon_sprite.scale = Vector2.ONE * _scale_factor \
		* WeaponHandVisual.held_scale(weapon.id)
	held_weapon_sprite.rotation = WeaponHandVisual.held_rotation(
		weapon.id, weapon_hand_bone.rotation, animated_sprite.flip_h)
	held_weapon_sprite.flip_h = animated_sprite.flip_h
	held_weapon_sprite.visible = true
	if bool(spec.get("dynamic_elastic", false)):
		_update_sling_elastic()


func _update_sling_elastic() -> void:
	var animation := _animation_data()
	if animation == null or animation.sling_rear_hand_frame3.x < 0:
		return
	var rear := Vector2(animation.sling_rear_hand_frame3)
	if animated_sprite.flip_h:
		rear.x = float(animation.frame_size.x) - rear.x
	var rear_local := animated_sprite.position + \
		(rear - Vector2(animation.frame_size) * 0.5) * animated_sprite.scale
	# A linha impressa no PNG nasce na ponta esquerda do garfo (26, 41).
	# Calculamos a posição já transformada do garfo para uni-la à mão de trás.
	var fork_x := 48.0 - 26.0 if animated_sprite.flip_h else 26.0
	var fork_in_sprite := Vector2(fork_x - 24.0, 41.0 - 48.0) \
		+ held_weapon_sprite.offset
	var skeleton := weapon_hand_bone.get_parent() as Node2D
	var points := PackedVector2Array([
		skeleton.to_local(to_global(rear_local)),
		skeleton.to_local(held_weapon_sprite.to_global(fork_in_sprite)),
	])
	sling_elastic.points = points
	sling_elastic_highlight.points = points
	sling_elastic.width = maxf(1.0, 2.5 * _scale_factor)
	sling_elastic_highlight.width = maxf(1.0, _scale_factor)
	sling_elastic.visible = true
	sling_elastic_highlight.visible = true


func play_hurt() -> void:
	if _walking:
		_hurt_queued = true
		return
	if animated_sprite.sprite_frames != null \
			and animated_sprite.sprite_frames.has_animation(&"hurt"):
		_hurt_blink_version += 1
		_hurt_blinking = false
		refresh_temporary_visual()
		animated_sprite.flip_h = false
		animated_sprite.visible = true
		var comfort := get_node_or_null("/root/VisualComfort")
		if comfort != null and bool(comfort.get("enabled")):
			_play_reduced_hurt(_hurt_blink_version)
			return
		animated_sprite.set_frame_and_progress(0, 0.0)
		animated_sprite.play(&"hurt")


func hold_combat_hit() -> void:
	_combat_hit_held = true


func cancel_combat_hit() -> void:
	_combat_hit_held = false


func present_combat_hit() -> void:
	_combat_hit_held = false
	if state == null:
		return
	if state.current_health <= 0:
		_start_death()
	else:
		play_hurt()


func _play_reduced_hurt(version: int) -> void:
	# A folha Hurt define o frame vermelho para cada personagem. Sem sumiço,
	# repetição de vermelho ou alternância rápida de visibilidade.
	animated_sprite.animation = &"hurt"
	animated_sprite.pause()
	var frame_count := animated_sprite.sprite_frames.get_frame_count(&"hurt")
	var animation := _animation_data()
	var red_frame := mini(animation.death_hurt_frame, frame_count - 1) \
		if animation != null else frame_count - 1
	# A coroutine abaixo espera temporizadores; não deve reter o Resource
	# de animação se a cena for fechada durante esse intervalo.
	animation = null
	for frame_index in [0, mini(1, frame_count - 1), red_frame]:
		if not _can_continue_hurt_blink(version):
			return
		animated_sprite.set_frame_and_progress(frame_index, 0.0)
		await get_tree().create_timer(0.20).timeout
	if _can_continue_hurt_blink(version):
		play_idle()


func reset_at(coord: Vector2i) -> void:
	_hurt_blink_version += 1
	_hurt_blinking = false
	_thrown_in_flight = false
	_pending_attack_weapon = null
	_pending_attack_target = null
	_projectile_launched = false
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
			_walk_tween.tween_property(self, "position", detour, DETOUR_HALF_SECONDS)
			_walk_tween.tween_property(self, "position", target, DETOUR_HALF_SECONDS)
		else:
			_walk_tween.tween_property(self, "position", target, HEX_MOVE_SECONDS)
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
	var blocker_radius := 38.0
	var blockers := get_tree().get_nodes_in_group("map_entity_visual")
	blockers.append_array(get_tree().get_nodes_in_group("map_walk_obstacle"))
	for other in blockers:
		if other == self or not other is Node2D or not other.visible:
			continue
		var other_local: Vector2 = get_parent().to_local((other as Node2D).global_position)
		var progress := clampf((other_local - origin).dot(direction) / length_squared, 0.0, 1.0)
		if progress <= 0.12 or progress >= 0.88:
			continue
		var offset: Vector2 = other_local - origin.lerp(destination, progress)
		var radius := float(other.get_meta("walk_radius", 38.0))
		if offset.length() < radius and offset.length() < closest_distance:
			closest_distance = offset.length()
			blocker_offset = offset
			crossing = progress
			blocker_radius = radius
	if closest_distance == INF:
		return Vector2.INF
	var side := -1.0 if direction.cross(blocker_offset) > 0.0 else 1.0
	var perpendicular := Vector2(-direction.y, direction.x).normalized() * side
	return origin.lerp(destination, crossing) + perpendicular * (blocker_radius + 10.0)


func _face_walk(face_left: bool) -> void:
	animated_sprite.flip_h = face_left
	_update_weapon_hand_bone()


func _finish_walk() -> void:
	if not _walking:
		return
	_walking = false
	if _hurt_queued:
		_hurt_queued = false
		play_hurt()
	else:
		play_idle()
	walk_finished.emit()


func _on_health_changed(previous: int, current: int) -> void:
	if _combat_hit_held and current < previous:
		return
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
	elif animated_sprite.animation in [&"attack_blade", &"attack_impact", &"attack_ranged"]:
		play_idle()


func _on_hurt_frame_changed() -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null and bool(comfort.get("enabled")):
		return
	var animation := _animation_data()
	if _dying or _hurt_blinking or animated_sprite.animation != &"hurt" \
			or animation == null:
		return
	if animated_sprite.frame != animation.death_hurt_frame:
		return
	# A espera assíncrona não deve manter o spritesheet carregado após
	# a cena sair da árvore durante o breve piscar do dano.
	animation = null
	_hurt_blinking = true
	var version := _hurt_blink_version
	animated_sprite.pause()
	# Vermelho visível → nenhum sprite → o MESMO vermelho → continuação.
	await get_tree().create_timer(0.075).timeout
	if not _can_continue_hurt_blink(version):
		return
	animated_sprite.visible = false
	await get_tree().create_timer(0.055).timeout
	if not _can_continue_hurt_blink(version):
		return
	animated_sprite.visible = true
	await get_tree().create_timer(0.075).timeout
	if not _can_continue_hurt_blink(version):
		return
	_hurt_blinking = false
	animated_sprite.play(&"hurt")


func _can_continue_hurt_blink(version: int) -> bool:
	return is_inside_tree() and version == _hurt_blink_version and not _dying \
		and not _walking \
		and animated_sprite.animation == &"hurt"


func _start_death() -> void:
	if _dying:
		return
	_dying = true
	_hurt_blink_version += 1
	_hurt_blinking = false
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
		var animation := _animation_data()
		var death_frame := animation.death_hurt_frame if animation != null else 0
		animated_sprite.frame = mini(death_frame,
			animated_sprite.sprite_frames.get_frame_count(&"hurt") - 1)
	_death_tween = DEATH_BLINK.start(self)
