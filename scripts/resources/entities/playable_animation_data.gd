class_name PlayableAnimationData
extends Resource

## As três folhas de um jogável. Cada quadro ocupa 64 × 96 pixels; somente
## a quantidade de colunas/quadros de Hurt pode variar entre personagens.
@export var idle_sheet: Texture2D
@export var walk_sheet: Texture2D
@export var hurt_sheet: Texture2D
@export var frame_size: Vector2i = Vector2i(64, 96)
@export_range(1, 32) var idle_frames: int = 12
@export_range(1, 32) var walk_frames: int = 8
@export_range(1, 32) var hurt_frames: int = 6
@export_range(1, 16) var hurt_columns: int = 3
# Índice zero-based do quadro vermelho exibido nas três piscadas de morte.
# Se a folha mudar, basta editar este valor no Resource de animação.
@export_range(0, 31) var death_hurt_frame: int = 3
@export_range(1.0, 30.0, 0.5) var idle_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var walk_fps: float = 6.0
@export_range(1.0, 30.0, 0.5) var hurt_fps: float = 6.0


func create_sprite_frames() -> SpriteFrames:
	var result := SpriteFrames.new()
	if result.has_animation(&"default"):
		result.remove_animation(&"default")
	_add_sheet(result, &"idle", idle_sheet, 4, idle_frames, idle_fps, true)
	_add_sheet(result, &"walk", walk_sheet, 4, walk_frames, walk_fps, true)
	_add_sheet(result, &"hurt", hurt_sheet, hurt_columns, hurt_frames, hurt_fps, false)
	return result


func _add_sheet(frames: SpriteFrames, name: StringName, sheet: Texture2D,
		columns: int, count: int, fps: float, loop: bool) -> void:
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
	if count > 1 and count < 6:
		for index in range(count - 2, -1, -1):
			sequence.append(index)
	for index in sequence:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(index % columns * frame_size.x,
			floori(float(index) / float(columns)) * frame_size.y,
			frame_size.x, frame_size.y)
		frames.add_frame(name, frame)
