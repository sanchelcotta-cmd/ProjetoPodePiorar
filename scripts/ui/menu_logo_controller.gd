extends TextureRect

## A abertura toca uma vez por execução do jogo. Voltar ao menu não reinicia a
## revelação, mas mantém a logo oficial e seus pequenos glitches ocasionais.
const PREVIEW := preload("res://sprites/ui/logo/logo_previa.png")
const OFFICIAL := preload("res://sprites/ui/logo/logo_oficial.png")
const GLITCH_SHADER := preload("res://shaders/menu_logo_glitch.gdshader")
const FIRST_LETTERS_SECONDS := 1.0
const QUESTION_SECONDS := 3.0
const REVEAL_GLITCH_SECONDS := 0.34
const OCCASIONAL_GLITCH_SECONDS := 0.5
const CURSOR_COLORS := [Color("#54FFE6"), Color("#29CCFF"), Color("#F45BAC")]
const PALETTE_ROLES := ["structure", "selection", "progress", "warning", "danger", "neutral"]

static var _intro_played := false

var _phase := 0
var _elapsed := 0.0
var _until_glitch := 0.0
var _rng := RandomNumberGenerator.new()
var _logo_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	_logo_material = ShaderMaterial.new()
	_logo_material.shader = GLITCH_SHADER
	material = _logo_material
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(_on_visual_comfort_changed)
	if _intro_played or _reduced_motion():
		_show_official()
	else:
		texture = PREVIEW
		_set_phase(0, 0.55)


func _process(delta: float) -> void:
	_elapsed += delta
	match _phase:
		0:
			if _elapsed >= FIRST_LETTERS_SECONDS:
				_set_phase(1, 0.0)
		1:
			if _elapsed >= QUESTION_SECONDS:
				_set_phase(2, 0.88)
		2:
			if _elapsed >= REVEAL_GLITCH_SECONDS:
				_show_official()
		3:
			_until_glitch -= delta
			if _until_glitch <= 0.0 and not _reduced_motion():
				_pick_glitch_colors()
				_set_phase(4, 0.75)
		4:
			if _elapsed >= OCCASIONAL_GLITCH_SECONDS:
				_set_phase(3, 0.0)
				_until_glitch = _rng.randf_range(8.0, 19.0)
	if _phase in [0, 2, 4]:
		_logo_material.set_shader_parameter("effect_time", Time.get_ticks_msec() * 0.001)


func _set_phase(value: int, strength: float) -> void:
	_phase = value
	_elapsed = 0.0
	_logo_material.set_shader_parameter("phase", value)
	_logo_material.set_shader_parameter("intensity", strength)


func _show_official() -> void:
	_intro_played = true
	texture = OFFICIAL
	_set_phase(3, 0.0)
	_until_glitch = _rng.randf_range(8.0, 19.0)


func _pick_glitch_colors() -> void:
	var candidates: Array[Color] = []
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		for role in PALETTE_ROLES:
			candidates.append(palette.color(role))
	for cursor_color in CURSOR_COLORS:
		candidates.append(cursor_color)
	candidates.shuffle()
	_logo_material.set_shader_parameter("palette_a", candidates[0])
	_logo_material.set_shader_parameter("palette_b", candidates[1])
	_logo_material.set_shader_parameter("palette_c", candidates[2])


func _reduced_motion() -> bool:
	var comfort := get_node_or_null("/root/VisualComfort")
	return comfort != null and bool(comfort.get("enabled"))


func _on_visual_comfort_changed(enabled: bool) -> void:
	if enabled:
		_show_official()
