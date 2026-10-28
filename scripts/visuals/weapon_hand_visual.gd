class_name WeaponHandVisual
extends RefCounted

## Atlas de 48×96 fornecido para armas na mão. Não altera PNGs nem ItemData:
## cada aparência é criada como ImageTexture local à instância do ator.
const BLADE_COMMON := preload("res://sprites/equipment/lamina_comuns_1x.png")
const BLADE_EPIC := preload("res://sprites/equipment/lamina_epicas_1x.png")
const IMPACT_COMMON := preload("res://sprites/equipment/impacto_comuns_1x.png")
const IMPACT_EPIC := preload("res://sprites/equipment/impacto_epicas_1x.png")
const RANGED_COMMON := preload("res://sprites/equipment/distancia_comuns_1x.png")
const RANGED_EPIC := preload("res://sprites/equipment/distancia_epicas_1x.png")
const THROWN_PAIR := preload("res://sprites/equipment/distancia_arremesso_1x.png")
const ARROWS := preload("res://sprites/equipment/flecha_arco_precisao_1x.png")
const GRIP_LIGHT := Color8(80, 150, 90)
const GRIP_DARK := Color8(40, 150, 50)
const THROWN_GRIP_LIGHT := Color8(80, 153, 89)
const THROWN_GRIP_DARK := Color8(43, 145, 53)
const THUMB_PIXELS := 2 # Meta exibida em 1×: um terço da mão média (~6 px).
const WEAPON_SIZE_REDUCTION := 0.90
static var _projectile_cache: Dictionary = {}
static var _arrow_cache: Dictionary = {}
static var _sling_ball_cache: Texture2D


static func variant(item_id: StringName, aspect: StringName = &"light",
		clip: StringName = &"idle", frame: int = 0) -> Dictionary:
	match item_id:
		&"aa_00011": return {"sheet": BLADE_COMMON, "cell": 0}
		&"aa_00013": return {"sheet": BLADE_COMMON, "cell": 1}
		&"aa_00005": return {"sheet": BLADE_EPIC, "cell": 0}
		&"aa_00014": return {"sheet": BLADE_EPIC, "cell": 1}
		&"aa_00006": return {"sheet": BLADE_EPIC, "cell": 2}
		&"aa_00001": return {"sheet": BLADE_EPIC,
			"cell": 4 if aspect == &"shadow" else 3}
		&"aa_00012": return {"sheet": IMPACT_COMMON, "cell": 0}
		&"aa_00008": return {"sheet": IMPACT_COMMON, "cell": 1}
		&"aa_00007": return {"sheet": IMPACT_EPIC, "cell": 0}
		&"aa_00003": return {"sheet": IMPACT_EPIC, "cell": 1}
		&"aa_00009": return {"sheet": THROWN_PAIR, "cell": 2,
			"projectile_cell": 3}
		&"aa_00010": return {"sheet": RANGED_COMMON,
			"cell": 2 if clip == &"attack_ranged" and frame in [1, 2] else 1,
			"dynamic_elastic": clip == &"attack_ranged" and frame == 2}
		&"aa_00002": return {"sheet": RANGED_EPIC,
			"cell": 1 if clip == &"attack_ranged" and frame == 1 else \
				2 if clip == &"attack_ranged" and frame == 2 else 0}
		&"aa_00004": return {"sheet": THROWN_PAIR, "cell": 0,
			"projectile_cell": 1}
	return {}


static func skin_for_playable(character_id: StringName) -> Color:
	match character_id:
		&"pj_00001": return Color8(120, 80, 40)
		&"pj_00002": return Color8(180, 140, 110)
		&"pj_00003": return Color8(240, 180, 150)
		&"pj_00004": return Color8(170, 120, 70)
		&"pj_00005": return Color8(230, 160, 110)
		&"pj_00006": return Color8(240, 190, 160)
		&"pj_00007": return Color8(140, 90, 80)
	return Color8(210, 155, 115)


static func make_held_texture(spec: Dictionary, skin: Color,
		purple_symbiosis: bool = false, weapon_scale: float = 1.0) -> Dictionary:
	if spec.is_empty():
		return {}
	var sheet := spec["sheet"] as Texture2D
	var image := sheet.get_image().get_region(Rect2i(int(spec["cell"]) * 48,
		0, 48, 96))
	var source_image := image.duplicate() as Image
	if bool(spec.get("dynamic_elastic", false)):
		# No terceiro quadro, a linha fixa do atlas não alcança a mão de trás
		# em todas as poses. Mantemos o garfo e traçamos o elástico em cena.
		image.fill_rect(Rect2i(0, 38, 26, 6), Color.TRANSPARENT)
	var min_x := 48
	var min_y := 96
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if _is_grip_pixel(pixel):
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
				# Mantemos a escala da arma e reconstruímos todo o marcador
				# com a cor opaca mais próxima do seu próprio material.
				var material := _nearest_material_color(source_image, x, y)
				image.set_pixel(x, y, _purple_tint(material) \
					if purple_symbiosis else material)
			elif purple_symbiosis and pixel.a > 0.0:
				image.set_pixel(x, y, _purple_tint(pixel))
	var grip := Vector2(24.0, 70.0)
	if max_x >= 0:
		grip = Vector2(float(min_x + max_x) * 0.5,
			float(min_y + max_y) * 0.5)
		# O marcador maior agora está preenchido pelo material da arma;
		# o dedo tem ~2 px depois da escala da arma, não antes dela.
		var thumb_source_size := clampi(roundi(float(THUMB_PIXELS)
			/ maxf(weapon_scale, 0.05)), 1, 8)
		var thumb_x := clampi(roundi(grip.x) - (thumb_source_size >> 1), 0,
			48 - thumb_source_size)
		var thumb_y := clampi(roundi(grip.y) - (thumb_source_size >> 1), 0,
			96 - thumb_source_size)
		image.fill_rect(Rect2i(thumb_x, thumb_y, thumb_source_size,
			thumb_source_size), skin)
		image.set_pixel(thumb_x, thumb_y + thumb_source_size - 1,
			skin.darkened(0.24))
	return {"texture": ImageTexture.create_from_image(image), "grip": grip}


static func make_projectile_texture(spec: Dictionary) -> Texture2D:
	var projectile_cell := int(spec.get("projectile_cell", spec["cell"]))
	var key := "%s:%d" % [(spec["sheet"] as Texture2D).resource_path,
		projectile_cell]
	if _projectile_cache.has(key):
		return _projectile_cache[key] as Texture2D
	var sheet := spec["sheet"] as Texture2D
	var image := sheet.get_image().get_region(Rect2i(projectile_cell * 48,
		0, 48, 96))
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if _is_grip_pixel(pixel):
				image.set_pixel(x, y, Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(image)
	_projectile_cache[key] = texture
	return texture


static func _is_grip_pixel(pixel: Color) -> bool:
	return pixel == GRIP_LIGHT or pixel == GRIP_DARK \
		or pixel == THROWN_GRIP_LIGHT or pixel == THROWN_GRIP_DARK


static func _purple_tint(pixel: Color) -> Color:
	var light := pixel.get_luminance()
	return Color(0.18 + light * 0.63,
		0.08 + light * 0.34, 0.25 + light * 0.67, pixel.a)


static func _nearest_material_color(image: Image, x: int, y: int) -> Color:
	for radius in range(1, 20):
		for yy in range(maxi(0, y - radius), mini(image.get_height(), y + radius + 1)):
			for xx in range(maxi(0, x - radius), mini(image.get_width(), x + radius + 1)):
				if maxi(absi(xx - x), absi(yy - y)) != radius:
					continue
				var candidate := image.get_pixel(xx, yy)
				if candidate.a > 0.0 and not _is_grip_pixel(candidate):
					return candidate
	return Color8(80, 60, 50)


static func held_scale(item_id: StringName) -> float:
	var previous_scale := 0.86
	match item_id:
		&"aa_00001": previous_scale = 0.62
		&"aa_00002": previous_scale = 0.82
		&"aa_00004": previous_scale = 0.82 # Escala provisória para aprovação visual.
		&"aa_00003", &"aa_00008": previous_scale = 0.56
		&"aa_00005", &"aa_00006", &"aa_00014": previous_scale = 0.68
		&"aa_00007": previous_scale = 0.67
		&"aa_00009": previous_scale = 0.70 # Escala provisória para aprovação visual.
		&"aa_00010": previous_scale = 0.68
		&"aa_00011": previous_scale = 0.80
		&"aa_00012": previous_scale = 0.50
		&"aa_00013": previous_scale = 0.72
	# Cabo de Vassoura e Bastão do Guardião permanecem idênticos.
	return previous_scale if item_id in [&"aa_00008", &"aa_00003"] \
		else previous_scale * WEAPON_SIZE_REDUCTION


static func held_rotation(item_id: StringName, bone_rotation: float,
		face_left: bool = false) -> float:
	# Arco e estilingue mantêm corda/elástico atrás da mão que dispara.
	if item_id in [&"aa_00002", &"aa_00010"]:
		return -bone_rotation
	# Cada PNG tem um eixo próprio entre a empunhadura e a ponta. A correção
	# abaixo alinha esse eixo ao bone, inclusive para faca e tesoura diagonais.
	var angle := 90.0
	match item_id:
		&"aa_00001": angle = 85.0 # Adaga.
		&"aa_00003": angle = 87.0 # Bastão.
		&"aa_00007": angle = 114.0 # Martelo de Guerra.
		&"aa_00008": angle = 81.0 # Cabo de Vassoura.
		&"aa_00011": angle = 42.0 # Faca.
		&"aa_00012": angle = 77.0 # Martelo.
		&"aa_00013": angle = 60.0 # Tesoura.
	# O sprite espelhado também espelha seu eixo diagonal interno.
	return deg_to_rad(180.0 - angle if face_left else angle)


static func arrow_texture(phase: int) -> Texture2D:
	var index := phase % 2
	if _arrow_cache.has(index):
		return _arrow_cache[index] as Texture2D
	var image := ARROWS.get_image().get_region(Rect2i(index * 48,
		12, 48, 12))
	var texture := ImageTexture.create_from_image(image)
	_arrow_cache[index] = texture
	return texture


static func sling_ball_texture() -> Texture2D:
	if _sling_ball_cache != null:
		return _sling_ball_cache
	var image := RANGED_COMMON.get_image().get_region(Rect2i(144, 30, 48, 30))
	_sling_ball_cache = ImageTexture.create_from_image(image)
	return _sling_ball_cache
