class_name PlayableAnimationData
extends Resource

## Folhas de um jogável. Cada quadro ocupa 64 × 96 pixels; ataques têm
## uma folha para cada gesto de maestria, sem alterar o cálculo do combate.
@export var idle_sheet: Texture2D
@export var walk_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export var blade_attack_sheet: Texture2D
@export var impact_attack_sheet: Texture2D
@export var ranged_attack_sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(64, 96)
@export_range(1, 32) var idle_frames: int = 12
@export_range(1, 32) var walk_frames: int = 8
@export_range(1, 32) var hurt_frames: int = 6
@export_range(1, 16) var hurt_columns: int = 3
@export_range(1, 16) var attack_columns: int = 3
@export_range(1, 32) var attack_frames: int = 5
# Índice zero-based do quadro vermelho exibido nas três piscadas de morte.
# Se a folha mudar, basta editar este valor no Resource de animação.
@export_range(0, 31) var death_hurt_frame: int = 3
@export_range(1.0, 30.0, 0.5) var idle_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var walk_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var hurt_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var attack_fps: float = 8.0
# Um ponto de empunhadura por quadro da folha, em pixels 64 × 96. Os
# pontos são metadados invisíveis: nenhuma cor precisa ser pintada no ator.
@export var hand_roots: Dictionary = {}
# Mão que puxa o elástico no terceiro quadro de Distância (índice 2).
# Coordenada invisível na folha de 64 × 96; cada personagem tem sua pose.
@export var sling_rear_hand_frame3: Vector2i = Vector2i(-1, -1)


func hand_bone_points(clip: StringName, frame: int) -> Dictionary:
	var roots: PackedVector2Array = hand_roots.get(clip, PackedVector2Array())
	if roots.is_empty() or frame < 0 or frame >= roots.size():
		return {}
	var root := roots[frame]
	var direction := Vector2(0.0, 7.0)
	match clip:
		&"attack_blade":
			# Ponta sempre para fora do personagem, inclusive na preparação
			# e na recuperação do golpe (os PNGs olham para a direita).
			direction = [Vector2(8, -3), Vector2(8, -3), Vector2(8, -2),
				Vector2(8, -6), Vector2(10, 0)][mini(frame, 4)]
		&"attack_impact":
			direction = [Vector2(2, -10), Vector2(4, -9), Vector2(8, -4),
				Vector2(8, -2), Vector2(10, 0)][mini(frame, 4)]
		&"attack_ranged":
			direction = [Vector2(0, 7), Vector2(7, -3), Vector2(9, -1),
				Vector2(9, 1), Vector2(0, 7)][mini(frame, 4)]
	return {"root": root, "tip": root + direction}


func create_sprite_frames() -> SpriteFrames:
	var result := SpriteFrames.new()
	if result.has_animation(&"default"):
		result.remove_animation(&"default")
	_add_sheet(result, &"idle", idle_sheet, 4, idle_frames, idle_fps, true)
	_add_sheet(result, &"walk", walk_sheet, 4, walk_frames, walk_fps, true)
	_add_sheet(result, &"hurt", hurt_sheet, hurt_columns, hurt_frames, hurt_fps, false)
	_add_sheet(result, &"attack_blade", blade_attack_sheet,
		attack_columns, attack_frames, attack_fps, false, false)
	_add_sheet(result, &"attack_impact", impact_attack_sheet,
		attack_columns, attack_frames, attack_fps, false, false)
	_add_sheet(result, &"attack_ranged", ranged_attack_sheet,
		attack_columns, attack_frames, attack_fps, false, false)
	return result


func _add_sheet(frames: SpriteFrames, name: StringName, sheet: Texture2D,
		columns: int, count: int, fps: float, loop: bool,
		pingpong_short: bool = true) -> void:
	if sheet == null or frame_size.x <= 0 or frame_size.y <= 0 or columns <= 0:
		push_error("PlayableAnimationData: falta a folha %s ou o tamanho do quadro." % name)
		return
	var rows := ceili(float(count) / float(columns))
	if sheet.get_width() < columns * frame_size.x \
			or sheet.get_height() < rows * frame_size.y:
		push_error("PlayableAnimationData: %s não contém %d quadros de %s." \
			% [name, count, frame_size])
		return
	frames.add_animation(name)
	# A piscada de morte usa DeathBlink, independente desta cadência.
	frames.set_animation_speed(name, fps)
	frames.set_animation_loop(name, loop)
	var sequence: Array[int] = []
	for index in count:
		sequence.append(index)
	if pingpong_short and count > 1 and count < 6:
		for index in range(count - 2, -1, -1):
			sequence.append(index)
	for index in sequence:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(index % columns * frame_size.x,
			floori(float(index) / float(columns)) * frame_size.y,
			frame_size.x, frame_size.y)
		frames.add_frame(name, frame)
