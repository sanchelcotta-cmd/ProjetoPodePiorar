class_name PPPDecorationView
extends Node2D

## Decoração derivada da semente salva no HexGrid. Nenhum sorteio acontece em
## resize/zoom; as portas vêm da cena editorial sem carregar suas texturas.
const ASSET := "res://sprites/decoration/"
const FILES := {
	"balde": "balde-banquito-pixel_1x.png",
	"banco": "banquinho-madeira-branco-pixel_1x.png",
	"lixeira_brasileira": "lixeira-brasileira-tradicional-pixel_1x.png",
	"lixeira_latao": "lixeira-latao-pixel_1x.png",
	"lixeira_simples": "lixeira-simples-pixel_1x.png",
	"saco": "saco-lixo-preto-pixel_1x.png",
	"vaso": "vaso-espada-sao-jorge-pixel_1x.png",
	"ipe": "arvore-ipe-amarelo-grande-pixel_1x.png",
	"jabuticabeira": "arvore-jabuticabeira-pixel_1x.png",
	"jeriva": "arvore-jeriva-pixel_1x.png",
	"quaresmeira": "arvore-quaresmeira-pixel_1x.png",
	"poste_historico": "poste-brasileiro-historico-pixel_1x.png",
	"poste_tradicional": "poste-brasileiro-tradicional-pixel_1x.png",
	"anomalia_lixo": "anomalia_lixo_pé_1x.png",
	"anomalia_lixeira": "anomalia_duende_lixeira_1x.png",
	"anomalia_arvore": "anomalia_arvore_de_fogo.png",
	"anomalia_poste": "anomalia_poste_olho_2.0_1x.png",
	"anomalia_galo": "anomalia_galo_fundo_1x.png",
	"anomalia_ovni": "anomalia_lixo_ovni_1x.png",
}
const TREE_TYPES := ["ipe", "jabuticabeira", "jeriva", "quaresmeira"]
const STREETLIGHT_CONE_SHADER := preload("res://shaders/streetlight_cone.gdshader")
const FIRE_TREE_EMBERS := preload("res://scripts/maps/ppp_fire_tree_embers.gd")
const TRASH_TYPES := ["lixeira_brasileira", "lixeira_latao", "lixeira_simples"]
const ANOMALY_BASE := {
	"saco": "anomalia_lixo", "lixeira_brasileira": "anomalia_lixeira",
	"ipe": "anomalia_arvore", "jabuticabeira": "anomalia_arvore",
	"jeriva": "anomalia_arvore", "quaresmeira": "anomalia_arvore",
	"poste_tradicional": "anomalia_poste",
}
const ANOMALY_COLUMNS := {
	"anomalia_lixo": 4, "anomalia_lixeira": 3,
	"anomalia_arvore": 4, "anomalia_poste": 4,
	"anomalia_galo": 4, "anomalia_ovni": 4,
}
const ANOMALY_ROWS := 2
const POST_SCALE := 1.75
const POST_HORIZONTAL_SCALE := {"poste_tradicional": 1.45,
	"poste_historico": 1.06}
const SMALL_SCALE := 1.25
const BENCH_SCALE := SMALL_SCALE * 2.0
const TREE_SCALE := 1.40
const LARGE_TREE_SCALE := TREE_SCALE * 1.20
const ANOMALY_POST_LIGHT := Color("#ff526b")
# Grupo A na borda do ground; árvores plantadas na calçada entre hexes,
# nunca junto à parede; postes no início do meio-fio.
# Os PNGs dos postes têm ~10 px de margem transparente sob a base.
const GROUND_GROUP_OFFSET := {"A": 20.0, "B": 47.0, "C": 70.0}

@onready var map_view: PPPMapView = get_node("../../..") as PPPMapView
@onready var exploration: ExplorationManager = get_node_or_null("../../../ExplorationManager") as ExplorationManager
@onready var gerencia: GerenciaJogo = get_node_or_null("../../../GerenciaJogo") as GerenciaJogo
@onready var sky: PPPParallaxBackground = get_node_or_null("../../../ParallaxBackground") as PPPParallaxBackground

var _grid: HexGrid
var _anomaly_visual: Node2D
var _post_anomaly_roots: Array[Node2D] = []
var _ambient_animations: Array[Dictionary] = []
var _post_lights: Array[PointLight2D] = []
var _post_effects: Array[Dictionary] = []
var _fly_groups: Array[Node2D] = []
var _last_night := false
var _ambient_clock := 0.0
var _texture_cache: Dictionary = {}
var _post_base_cache: Dictionary = {}
var _tree_base_cache: Dictionary = {}
var _ground_top := 0.0
var _screen_size := Vector2.ZERO
var _layout_left := 0.0
var _layout_right := 0.0
var _layout_ground := 0.0
var _base_entries: Array[Dictionary] = []
var _ufo_lights: Array[Sprite2D] = []
var _ufo_glow_clock := 0.0
var _halo_texture: Texture2D
var _ground_shadow_texture: Texture2D
var _ground_shadows: Array[Dictionary] = []
var _last_shadow_period := -1
var _last_shadow_grey := false


func _ready() -> void:
	y_sort_enabled = true
	if exploration != null:
		exploration.actor_moved.connect(_on_actor_moved)
		exploration.actor_teleported.connect(_on_actor_teleported)


func _process(delta: float) -> void:
	if _grid == null:
		return
	var period := gerencia.campaign.round_period if gerencia != null \
		else PPPMapGenerator.RoundPeriod.MORNING
	var grey := sky != null and sky.active_set_path.get_file().begins_with("cinzento_")
	if period != _last_shadow_period or grey != _last_shadow_grey:
		_last_shadow_period = period
		_last_shadow_grey = grey
		_refresh_ground_shadows(period, grey)
	if not _ufo_lights.is_empty():
		_ufo_glow_clock += delta
		for index in _ufo_lights.size():
			var glow := _ufo_lights[index]
			if is_instance_valid(glow):
				# Mesmo pulso lento e de baixo contraste com ou sem o modo
				# de conforto visual: nenhuma alternância brusca de luz.
				glow.modulate.a = 0.68 + 0.10 * sin(
					_ufo_glow_clock * 1.7 + float(index) * 1.9)
	var night := gerencia != null and gerencia.campaign.round_period \
		== PPPMapGenerator.RoundPeriod.NIGHT
	if night != _last_night:
		_last_night = night
		for light in _post_lights:
			if is_instance_valid(light):
				light.enabled = night
		for effect in _post_effects:
			for key in ["cone", "halo", "reflection"]:
				var visual := effect.get(key) as CanvasItem
				if is_instance_valid(visual):
					visual.visible = night
		for flies in _fly_groups:
			if is_instance_valid(flies):
				flies.visible = night
	_ambient_clock += delta
	if _ambient_clock < 0.25:
		return
	_ambient_clock = 0.0
	for record in _ambient_animations:
		var sprite := record.get("sprite") as AnimatedSprite2D
		if not is_instance_valid(sprite) or not sprite.visible or sprite.is_playing():
			continue
		record["wait"] = float(record["wait"]) - 0.25
		if float(record["wait"]) <= 0.0:
			sprite.play(&"move")
			record["wait"] = randf_range(float(record["minimum"]),
				float(record["maximum"]))


func rebuild(new_grid: HexGrid, background: Sprite2D, copies: Node2D,
		ground_screen_top: float, screen_size: Vector2) -> void:
	_clear()
	_base_entries.clear()
	_grid = new_grid
	_ground_top = ground_screen_top
	_screen_size = screen_size
	if _grid == null or _grid.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION \
			or background == null or background.texture == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, _grid.ppp_decoration_seed)
	var district := _district_of(_grid.ppp_background_path)
	var map_root := map_view.get_node("MapRoot") as Node2D
	var local_ground: float = ground_screen_top - map_root.position.y
	var left: float = screen_size.x * 0.27 - map_root.position.x
	var right: float = screen_size.x * 0.93 - map_root.position.x
	var doors := _door_segments(background, copies)
	var entries: Array[Dictionary] = []
	_build_posts(entries, rng, district, left, right, local_ground)
	_build_facade_items(entries, rng, district, left, right, local_ground, doors)
	_build_trees(entries, rng, district, left, right, local_ground)
	_layout_left = left
	_layout_right = right
	_layout_ground = local_ground
	_base_entries = entries.duplicate(true)
	_assign_anomaly(entries, rng)
	_render_planned_entries(entries, rng)


func _render_planned_entries(entries: Array[Dictionary],
		rng: RandomNumberGenerator) -> void:
	for entry in entries:
		_render_entry(entry, rng)
	if _grid.ppp_anomaly_kind in [&"anomalia_galo", &"anomalia_ovni"]:
		_render_background_anomaly(rng, _layout_ground)
	_last_night = not (gerencia != null and gerencia.campaign.round_period \
		== PPPMapGenerator.RoundPeriod.NIGHT)
	_process(0.0)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ambient_animations.clear()
	_post_lights.clear()
	_post_effects.clear()
	_fly_groups.clear()
	_ufo_lights.clear()
	_ufo_glow_clock = 0.0
	_ground_shadows.clear()
	_last_shadow_period = -1
	_anomaly_visual = null
	_post_anomaly_roots.clear()
	_ambient_clock = 0.0
	_grid = null


func force_anomaly(kind: StringName) -> bool:
	if _grid == null or _grid.ppp_map_mode != HexGrid.PPPMapMode.EXPLORATION \
			or _base_entries.is_empty():
		return false
	if kind != &"" and kind not in [
			&"anomalia_lixo", &"anomalia_lixeira", &"anomalia_arvore",
			&"anomalia_poste", &"anomalia_galo", &"anomalia_ovni"]:
		return false
	var grid := _grid
	var previous_planned := grid.ppp_anomaly_planned
	var previous_kind := grid.ppp_anomaly_kind
	var previous_triggered := grid.ppp_anomaly_triggered
	grid.ppp_anomaly_planned = true
	grid.ppp_anomaly_kind = kind
	grid.ppp_anomaly_triggered = false
	var rng := RandomNumberGenerator.new()
	rng.seed = maxi(1, grid.ppp_decoration_seed)
	var entries: Array[Dictionary] = _base_entries.duplicate(true)
	_assign_anomaly(entries, rng)
	var success := grid.ppp_anomaly_kind != &"" \
		and (kind == &"" or grid.ppp_anomaly_kind == kind)
	if not success:
		# O teste não pode deixar um sorteio pendente nem apagar a anomalia
		# anterior quando o objeto-base não encontra uma posição segura.
		grid.ppp_anomaly_planned = previous_planned
		grid.ppp_anomaly_kind = previous_kind
		grid.ppp_anomaly_triggered = previous_triggered
		return false
	# O arranjo-base está em coordenadas locais, imune a zoom/pan. Depurar
	# troca apenas a anomalia, sem sortear fachadas ou mover árvores.
	_clear()
	_grid = grid
	_render_planned_entries(entries, rng)
	return success


func _district_of(path: String) -> String:
	if path.contains("baixocentro"):
		return "baixo_centro"
	return "centro" if path.contains("centro") else "suburbio"


func _texture(kind: String) -> Texture2D:
	if not FILES.has(kind):
		return null
	if not _texture_cache.has(kind):
		_texture_cache[kind] = load(ASSET + FILES[kind]) as Texture2D
	return _texture_cache[kind] as Texture2D


func prepare_assets(progress: Callable = Callable()) -> void:
	# Cada lote cede um quadro ao loading; a primeira entrada no mapa não
	# concentra importação/decodificação de todas as artes em um único frame.
	var count := 0
	for kind in FILES:
		_texture(str(kind))
		count += 1
		if count % 2 == 0:
			if progress.is_valid():
				progress.call()
			await get_tree().process_frame
	if count % 2 != 0:
		if progress.is_valid():
			progress.call()
		await get_tree().process_frame


func _scale_for(kind: String) -> float:
	return POST_SCALE if kind.begins_with("poste_") else \
		TREE_SCALE if kind == "quaresmeira" else \
		LARGE_TREE_SCALE if kind in TREE_TYPES else \
		BENCH_SCALE if kind == "banco" else \
		SMALL_SCALE * 1.2 if kind in TRASH_TYPES else SMALL_SCALE


func _width_for(kind: String) -> float:
	var texture := _texture(kind)
	var horizontal := float(POST_HORIZONTAL_SCALE.get(kind, _scale_for(kind)))
	return float(texture.get_width()) * horizontal if texture != null else 0.0


func _door_segments(background: Sprite2D, copies: Node2D) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var zones := PPPDecorationDoorCatalog.zones_for(_grid.ppp_background_path)
	if zones.is_empty():
		return result
	var sprites: Array[Sprite2D] = [background]
	for child in copies.get_children():
		if child is Sprite2D:
			sprites.append(child as Sprite2D)
	for sprite in sprites:
		var image_left := sprite.position.x - sprite.texture.get_width() \
			* sprite.scale.x * 0.5
		for zone in zones:
			result.append(Vector2(image_left + zone.position.x * sprite.scale.x,
				image_left + zone.end.x * sprite.scale.x))
	return result


func _build_posts(entries: Array[Dictionary], rng: RandomNumberGenerator,
		district: String, left: float, right: float, ground: float) -> void:
	var amount := rng.randi_range(3, 4)
	var force_post := _grid.ppp_anomaly_planned \
		and _grid.ppp_anomaly_kind == &"anomalia_poste"
	var kind := "poste_tradicional" if force_post or district == "suburbio" \
		or rng.randf() < 0.42 else "poste_historico"
	var y := ground + GROUND_GROUP_OFFSET["C"]
	var anchors := map_view.get_node_or_null(
		"PostSpawnAnchors/FourPosts" if amount == 4 else
		"PostSpawnAnchors/ThreePosts") as Node2D
	if anchors == null:
		push_error("Cena sem marcadores de spawn dos postes.")
		return
	var base := _post_base_rect(kind)
	var base_center_x := base.position.x + base.size.x * 0.5
	var map_root := map_view.get_node("MapRoot") as Node2D
	for marker in anchors.get_children():
		if not marker is Marker2D:
			continue
		var target_foot_x: float = (marker as Marker2D).position.x \
			/ PPPMapView.REFERENCE_VIEWPORT.x * _screen_size.x \
			- map_root.position.x
		var placed := false
		for search in 81:
			for side in [1.0, -1.0]:
				var foot_x: float = target_foot_x + float(search) * side
				if foot_x + map_root.position.x < _screen_size.x * 0.20 \
						or foot_x + map_root.position.x > _screen_size.x * 0.98:
					continue
				var root_x: float = foot_x - base_center_x
				if _post_foot_clear(root_x, y, base):
					entries.append({"kind": kind, "group": "C",
						"x": root_x, "y": y})
					placed = true
					break
			if placed:
				break
		if not placed:
			push_warning("Decoração: marcador de poste sem vão livre.")


func _post_base_rect(kind: String) -> Rect2:
	if _post_base_cache.has(kind):
		return _post_base_cache[kind]
	var image := _texture(kind).get_image()
	var min_x := image.get_width()
	var max_x := -1
	var min_y := image.get_height()
	var max_y := -1
	for pixel_y in range(image.get_height() - 24, image.get_height()):
		for pixel_x in image.get_width():
			if image.get_pixel(pixel_x, pixel_y).a <= 0.1:
				continue
			min_x = mini(min_x, pixel_x)
			max_x = maxi(max_x, pixel_x)
			min_y = mini(min_y, pixel_y)
			max_y = maxi(max_y, pixel_y)
	var sx := float(POST_HORIZONTAL_SCALE[kind])
	var rect := Rect2(Vector2((float(min_x) - image.get_width() * 0.5) * sx,
		(float(min_y) - image.get_height()) * POST_SCALE),
		Vector2(float(max_x - min_x + 1) * sx,
			float(max_y - min_y + 1) * POST_SCALE)).grow(1.0)
	_post_base_cache[kind] = rect
	return rect


func _post_foot_clear(x: float, y: float, base: Rect2) -> bool:
	var footprint := Rect2(base.position + Vector2(x, y), base.size)
	var corners := PackedVector2Array([
		footprint.position, Vector2(footprint.end.x, footprint.position.y),
		footprint.end, Vector2(footprint.position.x, footprint.end.y)])
	var coords: Array[Vector2i] = []
	coords.assign(_grid.cells.keys())
	coords.append_array(_grid.get_ppp_start_positions())
	for coord in coords:
		var center := PPPMapView.reference_hex_position(coord)
		if absf(center.x - footprint.get_center().x) > footprint.size.x * 0.5 + 34.0 \
				or absf(center.y - footprint.get_center().y) > footprint.size.y * 0.5 + 38.0:
			continue
		var polygon := HexGrid.hex_polygon_points(
			HexRenderer.PPP_HEX_OUTLINE_RADIUS_PIXELS)
		for index in polygon.size():
			polygon[index] = polygon[index] * HexRenderer.REFERENCE_SPRITE_SCALE \
				+ center
		if not Geometry2D.intersect_polygons(corners, polygon).is_empty():
			return false
	return true


func _tree_base_rect(kind: String) -> Rect2:
	if _tree_base_cache.has(kind):
		return _tree_base_cache[kind]
	var image := _texture(kind).get_image()
	var used := image.get_used_rect()
	var min_x := image.get_width()
	var max_x := -1
	var min_y := image.get_height()
	var max_y := -1
	# A linha inferior opaca é o contato real com o chão. O desenho da
	# raiz/canteiro acima dela não aumenta artificialmente a colisão.
	for pixel_y in range(used.end.y - 1, used.end.y):
		for pixel_x in range(used.position.x, used.end.x):
			if image.get_pixel(pixel_x, pixel_y).a <= 0.1:
				continue
			min_x = mini(min_x, pixel_x)
			max_x = maxi(max_x, pixel_x)
			min_y = mini(min_y, pixel_y)
			max_y = maxi(max_y, pixel_y)
	var scale := _scale_for(kind)
	var rect := Rect2(Vector2((float(min_x) - image.get_width() * 0.5) * scale,
		(float(min_y) - image.get_height()) * scale),
		Vector2(float(max_x - min_x + 1) * scale,
			float(max_y - min_y + 1) * scale)).grow(1.0)
	_tree_base_cache[kind] = rect
	return rect


func _tree_base_clear(x: float, y: float, kind: String) -> bool:
	return _post_foot_clear(x, y, _tree_base_rect(kind))


func _build_facade_items(entries: Array[Dictionary], rng: RandomNumberGenerator,
		district: String, left: float, right: float, ground: float,
		doors: Array[Vector2]) -> void:
	# Uma fachada nova sem marcações nunca recebe objetos do grupo A.
	if doors.is_empty():
		return
	var amount := rng.randi_range(1 if district == "centro" else 0, 5)
	if amount == 0:
		return
	var trash_pool: Array[String] = ["lixeira_brasileira"]
	if not (_grid.ppp_anomaly_planned \
			and _grid.ppp_anomaly_kind == &"anomalia_lixeira"):
		trash_pool.append("lixeira_latao")
		if district != "centro":
			trash_pool.append("lixeira_simples")
	var trash_kind: String = trash_pool[rng.randi_range(0, trash_pool.size() - 1)]
	var kinds: Array[String] = [trash_kind]
	if amount >= 3 and rng.randf() < 0.42:
		kinds.append(trash_kind)
	while kinds.size() < amount:
		var pool: Array[String] = ["par", "banco", "saco", "vaso"]
		if district == "suburbio":
			pool.append_array(["vaso", "vaso"])
		elif district == "centro":
			# Bancos e o conjunto balde+banco ficam menos frequentes.
			pool.append_array(["saco", "vaso", "vaso", "vaso"])
		kinds.append(pool[rng.randi_range(0, pool.size() - 1)])
	for kind in kinds:
		var width := _width_for("banco") + _width_for("balde") + 8.0 \
			if kind == "par" else _width_for(kind)
		var x := _find_open_x(entries, rng, left, right, width, doors, true,
			ground + GROUND_GROUP_OFFSET["A"])
		# O grupo A toca a faixa superior do ground, sem cair na parede.
		if is_finite(x):
			entries.append({"kind": kind, "group": "A", "x": x,
				"y": ground + GROUND_GROUP_OFFSET["A"]})


func _build_trees(entries: Array[Dictionary], rng: RandomNumberGenerator,
		district: String, left: float, right: float, ground: float) -> void:
	var group_chance := 0.48 if district == "suburbio" else \
		0.77 if district == "baixo_centro" else 0.56
	# O arranjo das árvores não depende de quantos itens de fachada ou
	# anomalias foram sorteados antes dele. Assim a anomalia não reorganiza
	# as árvores do mesmo mapa.
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = maxi(1, _grid.ppp_decoration_seed + 5071)
	if tree_rng.randf() > group_chance:
		return
	var target := tree_rng.randi_range(0, 4)
	if target == 0:
		return
	var y := ground + GROUND_GROUP_OFFSET["B"]
	var doors := _door_segments(map_view.get_node("MapRoot/Background") as Sprite2D,
		map_view.get_node("MapRoot/BackgroundCopies") as Node2D)
	var slots: Array[float] = []
	match target:
		1:
			slots.assign([0.12 if tree_rng.randf() < 0.5 else 0.88])
		2:
			slots.assign([0.12, 0.88])
		_:
			slots.assign([0.12, 0.50, 0.88])
	var primary_count := slots.size()
	var occupied: Array[bool] = []
	occupied.resize(primary_count)
	occupied.fill(false)
	for index in primary_count:
		if occupied[index]:
			continue
		var fraction := slots[index]
		var preferred_x := lerpf(left, right, fraction)
		var slot_left := left if index == 0 else \
			lerpf(left, right, (slots[index - 1] + fraction) * 0.5)
		var slot_right := right if index == primary_count - 1 else \
			lerpf(left, right, (fraction + slots[index + 1]) * 0.5)
		var kind := _draw_tree(tree_rng, district)
		if kind == "jabuticabeira":
			if primary_count < 2 or index != 0:
				kind = "quaresmeira"
			else:
				var left_x := _find_tree_x_near(entries,
					preferred_x, left, right, kind, y, doors, left, slot_right)
				var proposed: Array[Dictionary] = entries.duplicate()
				if is_finite(left_x):
					proposed.append({"kind": kind, "group": "B", "x": left_x, "y": y})
				var right_x := _find_tree_x_near(proposed,
					lerpf(left, right, slots.back()), left, right, kind, y, doors,
					lerpf(left, right, (slots[primary_count - 2] + slots.back()) * 0.5),
					right) \
					if is_finite(left_x) else INF
				if is_finite(right_x):
					entries.append({"kind": kind, "group": "B", "x": left_x, "y": y})
					entries.append({"kind": kind, "group": "B", "x": right_x, "y": y})
					occupied[0] = true
					occupied[primary_count - 1] = true
					continue
				kind = "quaresmeira"
		# Só espécies de porte até o da quaresmeira podem usar o centro.
		if primary_count == 3 and index == 1 and kind != "quaresmeira":
			kind = "quaresmeira"
		var x := _find_ipe_edge_x(entries, left, right,
			y, index == 0) if kind == "ipe" else \
			_find_tree_x_near(entries, preferred_x, left, right,
				kind, y, doors, slot_left, slot_right)
		if kind == "ipe" and not is_finite(x):
			# Se a borda estiver ocupada, tentar uma espécie menor na mesma
			# vaga, nunca deslocar o ipê para uma vaga central.
			kind = "quaresmeira"
			x = _find_tree_x_near(entries, preferred_x, left, right,
				kind, y, doors, slot_left, slot_right)
		if is_finite(x):
			entries.append({"kind": kind, "group": "B", "x": x, "y": y})
	if target == 4 and _group_b_count(entries) < 4:
		var fourth_kind := _draw_tree(tree_rng, district)
		if fourth_kind == "jabuticabeira":
			fourth_kind = "quaresmeira"
		var clipped_x := _find_clipped_tree_x(entries, fourth_kind, y, doors)
		if is_finite(clipped_x):
			entries.append({"kind": fourth_kind, "group": "B",
				"x": clipped_x, "y": y})
	# Vasos são opcionais e sorteados depois das árvores; nunca mudam a
	# espécie ou posição das vagas seguintes.
	if _grid.ppp_anomaly_planned:
		return
	var vase_rng := RandomNumberGenerator.new()
	vase_rng.seed = maxi(1, _grid.ppp_decoration_seed + 991)
	var planted: Array[Dictionary] = entries.duplicate()
	for tree in planted:
		if _group_b_count(entries) >= 4:
			break
		if str(tree["group"]) != "B" or str(tree["kind"]) not in TREE_TYPES \
				or vase_rng.randf() >= 0.20:
			continue
		var vase_x := float(tree["x"]) + _width_for(str(tree["kind"])) * 0.5 + 16.0
		if _can_place(entries, vase_x, y, _width_for("vaso"), [], false) \
				and _tree_base_clear(vase_x, y, "vaso"):
			entries.append({"kind": "vaso", "group": "B", "x": vase_x, "y": y})


func _group_b_count(entries: Array[Dictionary]) -> int:
	var total := 0
	for entry in entries:
		if str(entry["group"]) == "B":
			total += 1
	return total


func _find_tree_x_near(entries: Array[Dictionary], preferred: float,
		left: float, right: float, kind: String, y: float,
		doors: Array[Vector2], slot_left: float, slot_right: float) -> float:
	# Busca simétrica perto da faixa sorteada, sem aglomerar tudo no mesmo lado.
	var width := minf(_width_for(kind), 76.0)
	var maximum_shift := (right - left) * 0.15
	# A posição predeterminada prevalece: cruzar uma porta custa um pequeno
	# desvio no escore, mas não empurra a árvore para outra faixa do mapa.
	var best_x := INF
	var best_score := INF
	for step in 49:
		var shift := maximum_shift * float(step) / 48.0
		if shift >= best_score:
			break
		for direction: float in [1.0, -1.0]:
			var x: float = preferred + shift * direction
			if x < maxf(left + width * 0.5, slot_left) \
					or x > minf(right - width * 0.5, slot_right):
				continue
			if not _can_place(entries, x, y, width, doors, false, "B") \
					or not _tree_base_clear(x, y, kind):
				continue
			var door_penalty := 0.0 if _can_place(entries, x, y,
				width, doors, true, "B") else 24.0
			var score := shift + door_penalty
			if score < best_score:
				best_score = score
				best_x = x
	return best_x


func _find_ipe_edge_x(entries: Array[Dictionary],
		left: float, right: float, y: float, left_edge: bool) -> float:
	# Cada ipê usa a sua própria vaga extrema; nunca concorre com as centrais.
	var edge_width := (right - left) * 0.16
	var doors := _door_segments(map_view.get_node("MapRoot/Background") as Sprite2D,
		map_view.get_node("MapRoot/BackgroundCopies") as Node2D)
	for avoid_doors in [true, false]:
		for step in 17:
			var inset := 20.0 + edge_width * float(step) / 16.0
			var x := left + inset if left_edge else right - inset
			if _can_place(entries, x, y, 76.0, doors, avoid_doors, "B") \
					and _tree_base_clear(x, y, "ipe"):
				return x
	return INF


func _find_clipped_tree_x(entries: Array[Dictionary], kind: String,
		y: float, doors: Array[Vector2]) -> float:
	# Centro visual sobre a borda direita: só metade do sprite fica visível.
	# A quarta árvore é opcional quando nem esse ponto comporta sua base.
	var map_root := map_view.get_node("MapRoot") as Node2D
	var screen_edge := _screen_size.x - map_root.position.x
	var width := minf(_width_for(kind), 76.0)
	for avoid_doors in [true, false]:
		for step in 21:
			for side: float in [1.0, -1.0]:
				var x := screen_edge + float(step) * 2.0 * side
				if _can_place(entries, x, y, width, doors, avoid_doors, "B") \
						and _tree_base_clear(x, y, kind):
					return x
	return INF


func _draw_tree(rng: RandomNumberGenerator, district: String) -> String:
	var pool: Array[String] = ["ipe", "jabuticabeira", "quaresmeira"]
	if district == "baixo_centro":
		pool.append("jeriva")
	if district == "suburbio":
		pool.append_array(["quaresmeira", "quaresmeira"])
	else:
		pool.append_array(["ipe", "ipe"])
	if district != "baixo_centro" and rng.randf() < 0.06:
		return "jeriva"
	return pool[rng.randi_range(0, pool.size() - 1)]


func _find_open_x(entries: Array[Dictionary], rng: RandomNumberGenerator,
		left: float, right: float, width: float, doors: Array[Vector2],
		check_doors: bool, y: float = 0.0) -> float:
	var group := "A" if check_doors else "B"
	for _attempt in 60:
		var x := rng.randf_range(left + width * 0.5, right - width * 0.5)
		if _can_place(entries, x, y, width, doors, check_doors, group):
			return x
	# Os vãos para pés/troncos são estreitos entre os hexes; uma varredura
	# determinística evita falhar só porque o sorteio não encontrou o vão.
	var x := left + width * 0.5
	while x <= right - width * 0.5:
		if _can_place(entries, x, y, width, doors, check_doors, group):
			return x
		x += 2.0
	return INF


func _can_place(entries: Array[Dictionary], x: float, y: float,
		width: float, doors: Array[Vector2], check_doors: bool,
		group: String = "B") -> bool:
	if check_doors:
		for segment in doors:
			if x + width * 0.5 + 13.0 >= segment.x \
					and x - width * 0.5 - 13.0 <= segment.y:
				return false
	for entry in entries:
		if absf(y - float(entry["y"])) > 105.0:
			continue
		if group == "A" and str(entry["group"]) == "C":
			# Fachada e poste estão em faixas de chão distintas; a copa
			# horizontal do poste não bloqueia uma lixeira atrás dele.
			continue
		if group == "B" and str(entry["group"]) == "C":
			# A copa não é obstáculo no chão. A folga relevante é entre
			# tronco e base do poste, não entre as larguras dos sprites.
			if absf(x - float(entry["x"])) < 56.0:
				return false
			continue
		var other_width := _width_for(str(entry["kind"]))
		if str(entry["kind"]) == "par":
			other_width = _width_for("banco") + _width_for("balde") + 8.0
		elif str(entry["group"]) in ["B", "C"]:
			other_width = minf(other_width, 76.0)
		if absf(x - float(entry["x"])) < (width + other_width) * 0.5 + 18.0:
			return false
	# O grupo B usa a base opaca real, validada separadamente por espécie.
	if group == "B":
		return true
	var ground_radius := 0.0 if group == "A" else width * 0.5
	return _clear_of_hexes(x, y, ground_radius)


func _clear_of_hexes(x: float, y: float, radius: float) -> bool:
	for coord in _grid.cells:
		var center := PPPMapView.reference_hex_position(coord)
		if absf(center.x - x) < radius + 34.0 \
				and absf(center.y - y) < 38.0:
			return false
	for coord in _grid.get_ppp_start_positions():
		var center := PPPMapView.reference_hex_position(coord)
		if absf(center.x - x) < radius + 34.0 \
				and absf(center.y - y) < 38.0:
			return false
	return true


func _assign_anomaly(entries: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	if not _grid.ppp_anomaly_planned:
		return
	var requested := str(_grid.ppp_anomaly_kind)
	if requested in ["anomalia_galo", "anomalia_ovni"]:
		return
	if not requested.is_empty():
		_ensure_forced_base(entries, requested, rng)
	var candidates: Array[int] = []
	for index in entries.size():
		if ANOMALY_BASE.has(entries[index]["kind"]):
			candidates.append(index)
	if candidates.is_empty():
		# Grupo C é obrigatório; converter todos os postes preserva a regra
		# de um modelo por mapa e garante um objeto-base elegível.
		for entry in entries:
			if entry["group"] == "C":
				entry["kind"] = "poste_tradicional"
		for index in entries.size():
			if entries[index]["kind"] == "poste_tradicional":
				candidates.append(index)
	if candidates.is_empty():
		_grid.ppp_anomaly_kind = &""
		return
	# As anomalias do fundo concorrem no MESMO sorteio: uma por mapa.
	var pool: Array[String] = ["anomalia_galo", "anomalia_ovni"]
	if gerencia != null and gerencia.campaign != null \
			and gerencia.campaign.galiform_transformation_seen:
		pool.append_array(["anomalia_galo", "anomalia_galo"])
	if gerencia != null and gerencia.campaign != null \
			and gerencia.campaign.round_period == PPPMapGenerator.RoundPeriod.NIGHT:
		pool.append_array(["anomalia_ovni", "anomalia_ovni"])
	for index in candidates:
		pool.append(str(ANOMALY_BASE[entries[index]["kind"]]))
	var anomaly := requested if not requested.is_empty() else \
		pool[rng.randi_range(0, pool.size() - 1)]
	if not requested.is_empty() and anomaly not in ["anomalia_galo", "anomalia_ovni"]:
		var matching_base := false
		for index in candidates:
			if ANOMALY_BASE[entries[index]["kind"]] == anomaly:
				matching_base = true
				break
		if not matching_base:
			_grid.ppp_anomaly_kind = &""
			return
	_grid.ppp_anomaly_kind = StringName(anomaly)
	if anomaly in ["anomalia_galo", "anomalia_ovni"]:
		return
	if anomaly == "anomalia_arvore":
		# A anomalia é uma só por mapa, mas contagia todas as árvores dele.
		for entry in entries:
			if str(entry["kind"]) in TREE_TYPES:
				entry["anomaly"] = anomaly
		return
	if anomaly == "anomalia_poste":
		# Uma ocorrência, mas todos os postes do mapa viram mãos.
		for entry in entries:
			if str(entry["group"]) == "C":
				entry["anomaly"] = anomaly
		return
	var chosen := candidates[0]
	if not requested.is_empty():
		for index in candidates:
			if ANOMALY_BASE[entries[index]["kind"]] == anomaly:
				chosen = index
				break
	else:
		var matches: Array[int] = []
		for index in candidates:
			if ANOMALY_BASE[entries[index]["kind"]] == anomaly:
				matches.append(index)
		chosen = matches[rng.randi_range(0, matches.size() - 1)]
	entries[chosen]["anomaly"] = anomaly


func _ensure_forced_base(entries: Array[Dictionary], requested: String,
		rng: RandomNumberGenerator) -> void:
	var required := ""
	var group := ""
	match requested:
		"anomalia_lixo":
			required = "saco"
			group = "A"
		"anomalia_lixeira":
			required = "lixeira_brasileira"
			group = "A"
		"anomalia_arvore":
			required = "quaresmeira"
			group = "B"
		"anomalia_poste":
			required = "poste_tradicional"
			group = "C"
	if required.is_empty():
		return
	if requested == "anomalia_lixeira":
		# O duende exige a lixeira brasileira. Converter todas as lixeiras
		# juntas preserva a regra de um único modelo por mapa.
		var found_trash := false
		for entry in entries:
			if str(entry["kind"]) in TRASH_TYPES:
				entry["kind"] = required
				found_trash = true
		if found_trash:
			return
	for entry in entries:
		if entry["kind"] == required or requested == "anomalia_arvore" \
				and str(entry["kind"]) in TREE_TYPES:
			return
	if requested == "anomalia_poste":
		# Um poste só nasce nos marcadores validados contra os hexes.
		return
	for entry in entries:
		if entry["group"] == group and group != "B" \
				and requested != "anomalia_lixeira":
			if group == "A":
				# A lixeira obrigatória do Centro permanece; um objeto mais
				# estreito não pode ser alargado diante de uma porta.
				if str(entry["kind"]) in TRASH_TYPES:
					continue
				var prior_width := _width_for(str(entry["kind"]))
				if str(entry["kind"]) == "par":
					prior_width = _width_for("banco") + _width_for("balde") + 8.0
				if prior_width < _width_for(required):
					continue
			entry["kind"] = required
			if group == "C":
				for other in entries:
					if other["group"] == "C":
						other["kind"] = required
			return
	# Depuração pode inserir uma fachada/árvore ausente, mas não em porta/hex.
	var left := _layout_left
	var right := _layout_right
	var y: float = _layout_ground + float(GROUND_GROUP_OFFSET[group])
	var doors: Array[Vector2] = []
	if group in ["A", "B"]:
		doors = _door_segments(map_view.get_node("MapRoot/Background") as Sprite2D,
			map_view.get_node("MapRoot/BackgroundCopies") as Node2D)
	var x := _find_tree_x_near(entries, lerpf(left, right, 0.5),
		left, right, required, y, doors, left, right) if group == "B" else \
		_find_open_x(entries, rng, left, right, _width_for(required),
			doors, group == "A", y)
	if is_finite(x):
		entries.append({"kind": required, "group": group, "x": x, "y": y})


func _galo_offscreen_bounds() -> Vector2:
	var map_root := map_view.get_node("MapRoot") as Node2D
	var sheet := _texture("anomalia_galo")
	var frame_width := float(sheet.get_width()) \
		/ float(ANOMALY_COLUMNS["anomalia_galo"]) * 0.65
	# A câmera pode afastar a 85%: margem proporcional à largura da tela,
	# mais o quadro inteiro, impede até a cauda de reaparecer nas laterais.
	var bleed := _screen_size.x * 0.25 + frame_width + 80.0
	return Vector2(-map_root.position.x - bleed,
		_screen_size.x - map_root.position.x + bleed)


func _render_background_anomaly(rng: RandomNumberGenerator,
		ground: float) -> void:
	if _grid.ppp_anomaly_kind == &"anomalia_galo":
		var travel := _galo_offscreen_bounds()
		var walker := Node2D.new()
		walker.name = "GaloAoFundo"
		walker.z_as_relative = false
		walker.z_index = -32
		# O pé lógico da folha fica na altura do topo das janelas baixas;
		# a fachada oculta a parte inferior, não o corpo inteiro.
		walker.position = Vector2(travel.x, ground - 150.0)
		add_child(walker)
		# Mantém cabeça, corpo e início das pernas; corta os pés para que não
		# pareçam flutuar em frestas de fachadas futuras.
		var sprite := _add_animation(walker, "anomalia_galo", 0.65, 0.76)
		sprite.play(&"move")
		sprite.sprite_frames.set_animation_loop(&"move", true)
		_anomaly_visual = walker
		_start_galo_journey(walker, sprite, rng, travel)
	else:
		var map_root := map_view.get_node("MapRoot") as Node2D
		var left_edge := -map_root.position.x - 200.0
		var right_edge := _screen_size.x - map_root.position.x + 200.0
		var flight_y := 130.0 - map_root.position.y
		var flyer := Node2D.new()
		flyer.name = "OvniEntreCidadeECasas"
		flyer.z_as_relative = false
		flyer.z_index = -35 # cidade: -40; fachadas: -31/-30
		flyer.position = Vector2(right_edge, flight_y)
		add_child(flyer)
		var sprite := _add_animation(flyer, "anomalia_ovni", 1.4 * 0.65)
		sprite.sprite_frames.set_animation_loop(&"move", true)
		sprite.play(&"move")
		if gerencia != null and gerencia.campaign.round_period \
				== PPPMapGenerator.RoundPeriod.NIGHT:
			_add_ufo_glow(flyer)
		var journey := flyer.create_tween().set_loops()
		for step in 8:
			journey.tween_property(flyer, "position",
				Vector2(lerpf(right_edge, left_edge,
					float(step + 1) / 8.0),
					flight_y + (24.0 if step % 2 == 0 else -20.0)), 1.1)
		journey.tween_interval(rng.randf_range(5.0, 12.0))
		for step in 8:
			journey.tween_property(flyer, "position",
				Vector2(lerpf(left_edge, right_edge,
					float(step + 1) / 8.0),
					flight_y + (24.0 if step % 2 == 0 else -20.0)), 1.1)
		journey.tween_interval(rng.randf_range(5.0, 12.0))
		_anomaly_visual = flyer


func _start_galo_journey(walker: Node2D, sprite: AnimatedSprite2D,
		rng: RandomNumberGenerator, travel: Vector2) -> void:
	# Cada travessia sorteia pausas novas. Um tween em loop repetiria para
	# sempre os mesmos dois intervalos sorteados na primeira volta. O callback
	# pertence ao próprio nó e morre junto com ele quando o mapa é reconstruído.
	if not is_instance_valid(walker) or not walker.is_inside_tree():
		return
	var journey := walker.create_tween()
	journey.tween_property(walker, "position:x", travel.y, 13.0)
	journey.tween_interval(rng.randf_range(20.0, 40.0))
	journey.tween_callback(func() -> void: sprite.flip_h = true)
	journey.tween_property(walker, "position:x", travel.x, 13.0)
	journey.tween_interval(rng.randf_range(20.0, 40.0))
	journey.tween_callback(func() -> void: sprite.flip_h = false)
	journey.tween_callback(_start_galo_journey.bind(walker, sprite, rng, travel))


func _add_ufo_glow(root: Node2D) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.34, 0.95, 1.0, 0.88))
	gradient.set_color(1, Color(0.34, 0.95, 1.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var glow := Sprite2D.new()
	glow.name = "LuzDoOvni"
	glow.texture = texture
	glow.scale = Vector2(1.0, 0.66)
	glow.position = Vector2(0, 43)
	glow.z_index = -1
	root.add_child(glow)
	_ufo_lights.append(glow)
	for detail in [
		{"x": -24.0, "color": Color("#7cf9e6")},
		{"x": 0.0, "color": Color("#f15cb8")},
		{"x": 24.0, "color": Color("#ffe480")},
	]:
		var point := Sprite2D.new()
		point.name = "LuzColorida"
		point.texture = texture
		point.scale = Vector2.ONE * 0.28
		point.position = Vector2(float(detail["x"]), 1.0)
		point.modulate = detail["color"]
		root.add_child(point)
		_ufo_lights.append(point)


func _render_entry(entry: Dictionary, rng: RandomNumberGenerator) -> void:
	var kind := str(entry["kind"])
	var root := Node2D.new()
	root.name = kind.replace("_", " ").capitalize()
	root.position = Vector2(float(entry["x"]), float(entry["y"]))
	# O Decor root é ordenado pela base/pés dentro de DepthSorted. Não
	# habilitar Y-sort nele: isso achata os filhos e passa a ordenar cada
	# sprite pelo centro da imagem, invertendo árvore e poste altos.
	root.y_sort_enabled = false
	# Fachada e árvores ficam atrás dos atores, inclusive quando a copa
	# cruza o sprite de quem está num hex. Postes conservam o mesmo plano
	# dos atores, de modo que sua base ainda participa da ordenação por Y.
	match str(entry["group"]):
		"A": root.z_index = -2
		"B": root.z_index = -1
		_: root.z_index = 0
	root.set_meta("decoration_group", entry["group"])
	root.set_meta("decoration_kind", kind)
	add_child(root)
	if entry["group"] in ["B", "C"]:
		root.add_to_group("map_walk_obstacle")
		root.set_meta("walk_radius", 34.0 if entry["group"] == "C" else 44.0)
	if kind == "par":
		var gap := 8.0
		var bench_width := _width_for("banco")
		var bucket_width := _width_for("balde")
		_add_sprite(root, "banco", Vector2(-(bucket_width + gap) * 0.5, 0.0))
		_add_sprite(root, "balde", Vector2((bench_width + gap) * 0.5, 0.0))
		_add_ground_shadow(root, kind, str(entry["group"]))
		return
	var anomaly := str(entry.get("anomaly", ""))
	if anomaly == "anomalia_lixeira" or anomaly == "anomalia_arvore" \
			or (anomaly == "anomalia_poste" and _grid.ppp_anomaly_triggered):
		var animation := _add_animation(root, anomaly, _scale_for(kind))
		if anomaly == "anomalia_lixeira":
			_ambient_animations.append({"sprite": animation, "wait": rng.randf_range(10, 45),
				"minimum": 10.0, "maximum": 45.0})
		elif anomaly == "anomalia_poste":
			_ambient_animations.append({"sprite": animation, "wait": rng.randf_range(6, 30),
				"minimum": 6.0, "maximum": 30.0})
	else:
		if anomaly != "anomalia_lixo" or not _grid.ppp_anomaly_triggered:
			_add_sprite(root, kind)
	if not anomaly.is_empty():
		if anomaly == "anomalia_poste":
			_post_anomaly_roots.append(root)
		else:
			_anomaly_visual = root
		root.set_meta("anomaly", anomaly)
	if anomaly == "anomalia_arvore":
		_add_light(root, Vector2(0, -52), Color("#9b3bea"), 0.20, true)
		_add_halo(root, Vector2(0, -52), Color("#aa4fff"), 1.02, 0.82, -12)
		var embers := FIRE_TREE_EMBERS.new()
		embers.name = "BrasasRoxas"
		root.add_child(embers)
		embers.configure(_grid.ppp_decoration_seed + roundi(root.position.x * 13.0))
	if entry["group"] == "C":
		# Cor de luz: 5% verdes por poste, independente do sorteio de anomalia.
		var lamp_color := Color("#44f779") if rng.randf() < 0.05 \
			else Color("#ffdc9c")
		# Antes do primeiro movimento o poste ainda parece comum; a luz
		# vermelha aparece junto da mão/olho, inclusive ao restaurar o mapa.
		if anomaly == "anomalia_poste" and _grid.ppp_anomaly_triggered:
			lamp_color = ANOMALY_POST_LIGHT
		_add_post_effect(root, kind, lamp_color)
		if rng.randf() < 0.33:
			var flies := PPPDecorationFlies.new()
			flies.position = _lamp_offset(kind)
			flies.visible = false
			root.add_child(flies)
			_fly_groups.append(flies)
	_add_ground_shadow(root, kind, str(entry["group"]))


func _add_ground_shadow(root: Node2D, kind: String, group: String) -> void:
	if _ground_shadow_texture == null:
		_ground_shadow_texture = ActorGroundShadows.create_falloff_texture()
	var base := Rect2()
	if group == "B" and kind in TREE_TYPES:
		base = _tree_base_rect(kind)
	elif group == "C":
		base = _post_base_rect(kind)
	elif kind == "par":
		base = Rect2(Vector2(-_width_for("banco") * 0.5, 0.0),
			Vector2(_width_for("banco") + _width_for("balde") + 8.0, 1.0))
	else:
		var texture := _texture(kind)
		if texture == null:
			return
		var used := texture.get_image().get_used_rect()
		var factor := _scale_for(kind)
		base = Rect2(Vector2((used.position.x - texture.get_width() * 0.5) * factor,
			(used.end.y - texture.get_height()) * factor),
			Vector2(used.size.x * factor, 1.0))
	var half_width := clampf(base.size.x * 0.58 + 10.0,
		25.0 if group == "B" else 19.0, 78.0 if kind == "par" else 66.0)
	if group == "B" and kind in TREE_TYPES:
		# A copa, não a largura estreita do tronco, define a sombra da árvore.
		var crown_width := _visible_tree_width(root)
		if crown_width > 0.0:
			half_width = crown_width * 0.5
	elif group == "C":
		half_width = clampf(base.size.x * 0.72 + 9.0, 24.0, 43.0)
		half_width *= 1.10
	else:
		half_width *= 1.10
	var half_height := clampf(half_width * 0.32, 10.0, 19.0)
	var shadow := Sprite2D.new()
	shadow.name = "GroundShadow"
	shadow.texture = _ground_shadow_texture
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shadow.z_index = -4
	root.add_child(shadow)
	_ground_shadows.append({"sprite": shadow, "group": group,
		# O centro fica junto à base: a sombra avança atrás e à frente.
		"base": Vector2(base.get_center().x, base.end.y - half_height * 0.25),
		"half_width": half_width, "half_height": half_height})


func _visible_tree_width(root: Node2D) -> float:
	if root.get_child_count() == 0:
		return 0.0
	var visual := root.get_child(0)
	var texture: Texture2D
	var horizontal_scale := 1.0
	if visual is Sprite2D:
		texture = (visual as Sprite2D).texture
		horizontal_scale = absf((visual as Sprite2D).scale.x)
	elif visual is AnimatedSprite2D:
		var animated := visual as AnimatedSprite2D
		texture = animated.sprite_frames.get_frame_texture(animated.animation,
			animated.frame)
		horizontal_scale = absf(animated.scale.x)
	if texture == null:
		return 0.0
	return float(texture.get_image().get_used_rect().size.x) * horizontal_scale


func _refresh_ground_shadows(period: int, grey: bool) -> void:
	var style := ActorGroundShadows.ambient_shadow_style(period, grey)
	var opacity: float = style.opacity
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		opacity = float(comfort.call("cap_shadow_alpha", opacity))
	var tint: Color = style.tint
	var stretch: float = style.stretch
	var offset: Vector2 = style.offset
	for record in _ground_shadows:
		var shadow := record.get("sprite") as Sprite2D
		if not is_instance_valid(shadow):
			continue
		var group := str(record["group"])
		shadow.visible = group != "C" or period != PPPMapGenerator.RoundPeriod.NIGHT
		var width: float = record["half_width"]
		var height: float = record["half_height"]
		shadow.scale = Vector2(width * 2.0 * stretch / 96.0,
			height * 2.0 / 96.0)
		shadow.position = (record["base"] as Vector2) + offset
		shadow.modulate = Color(tint.r, tint.g, tint.b,
			opacity * ActorGroundShadows.ENTITY_OPACITY_FACTOR * 0.70)


func _add_sprite(root: Node2D, kind: String,
		offset: Vector2 = Vector2.ZERO) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "DecorationSprite"
	sprite.texture = _texture(kind)
	if sprite.texture == null:
		push_error("Decoração sem textura: %s" % kind)
		return sprite
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * _scale_for(kind)
	if POST_HORIZONTAL_SCALE.has(kind):
		sprite.scale.x = float(POST_HORIZONTAL_SCALE[kind])
	sprite.position = offset - Vector2(0, sprite.texture.get_height() * sprite.scale.y * 0.5)
	root.add_child(sprite)
	return sprite


func _add_animation(root: Node2D, kind: String,
		scale_factor: float, visible_height_fraction: float = 1.0) -> AnimatedSprite2D:
	var texture := _texture(kind)
	var columns: int = ANOMALY_COLUMNS[kind]
	var frame_size := Vector2i(texture.get_width() / columns,
		texture.get_height() / ANOMALY_ROWS)
	var visible_height := clampi(roundi(frame_size.y * visible_height_fraction),
		1, frame_size.y)
	var frames := SpriteFrames.new()
	frames.add_animation(&"move")
	frames.set_animation_speed(&"move", 8.0)
	frames.set_animation_loop(&"move", false)
	for index in columns * ANOMALY_ROWS:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(Vector2i(index % columns, index / columns) * frame_size,
			Vector2i(frame_size.x, visible_height))
		frames.add_frame(&"move", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"move"
	sprite.frame = 0
	sprite.scale = Vector2.ONE * scale_factor
	if kind == "anomalia_poste":
		sprite.scale.x = float(POST_HORIZONTAL_SCALE["poste_tradicional"])
	sprite.position.y = -frame_size.y * scale_factor \
		+ visible_height * scale_factor * 0.5 if visible_height < frame_size.y \
		else -frame_size.y * scale_factor * 0.5
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(sprite)
	sprite.animation_finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.stop()
			sprite.frame = 0)
	return sprite


func _lamp_offset(kind: String) -> Vector2:
	# Coordenadas dentro dos PNGs originais, não relativas ao centro do poste.
	var anchor := Vector2(51, 18) if kind == "poste_tradicional" else Vector2(21, 49)
	var texture := _texture(kind)
	return Vector2((anchor.x - texture.get_width() * 0.5) \
		* float(POST_HORIZONTAL_SCALE[kind]),
		(anchor.y - texture.get_height()) * POST_SCALE)


func _add_post_effect(root: Node2D, kind: String, color: Color) -> void:
	var lamp := _lamp_offset(kind)
	var beam_height := 195.0 - lamp.y
	var cone := ColorRect.new()
	cone.name = "FeixeDoPoste"
	cone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cone.position = lamp - Vector2(beam_height * 0.58, 0)
	cone.size = Vector2(beam_height * 1.16, beam_height)
	cone.z_as_relative = false
	cone.z_index = -13
	cone.visible = false
	var material := ShaderMaterial.new()
	material.shader = STREETLIGHT_CONE_SHADER
	cone.material = material
	root.add_child(cone)
	var halo := _add_halo(root, lamp, color, 0.47, 0.82, -12)
	var reflection := _add_halo(root, lamp + Vector2(12, 7),
		Color("#71dbea"), 0.24, 0.35, -11)
	halo.visible = false
	reflection.visible = false
	var light := _add_light(root, lamp, color, 0.34, false)
	light.texture_scale = 2.4
	light.add_to_group("ppp_streetlight")
	light.set_meta("shadow_reach", beam_height)
	light.set_meta("cone_half_width", cone.size.x * 0.46)
	var effect := {"root": root, "light": light, "cone": cone, "halo": halo,
		"reflection": reflection}
	_post_effects.append(effect)
	_apply_post_palette(effect, color)


func set_post_light_color(index: int, color: Color) -> void:
	# Prévia/depuração: mantém luz, halo e feixe da mesma variante.
	if index < 0 or index >= _post_effects.size():
		return
	var effect: Dictionary = _post_effects[index]
	if _grid != null and _grid.ppp_anomaly_kind == &"anomalia_poste" \
			and _grid.ppp_anomaly_triggered \
			and (effect["root"] as Node2D) in _post_anomaly_roots:
		color = ANOMALY_POST_LIGHT
	_apply_post_palette(effect, color)


func _apply_post_palette(effect: Dictionary, color: Color) -> void:
	var green := color.g > color.r + 0.15
	var red := color.r > color.g + 0.15 and color.r > color.b + 0.15
	(effect["light"] as PointLight2D).color = color
	(effect["light"] as PointLight2D).energy = 0.40 if red else 0.34
	(effect["halo"] as Sprite2D).modulate = Color("#ff6179") if red else \
		Color("#44ff7e") if green else Color("#ffd87d")
	(effect["halo"] as Sprite2D).modulate.a = 0.94 if red else 0.88
	(effect["reflection"] as Sprite2D).modulate = Color("#ffb1bd") if red else \
		Color("#9affbd") if green else Color("#71dbea")
	(effect["reflection"] as Sprite2D).modulate.a = 0.42 if red else 0.36
	var cone := effect["cone"] as ColorRect
	(cone.material as ShaderMaterial).set_shader_parameter("beam_tint",
		Color("#f54560") if red else Color("#3bf475") if green \
		else Color("#ffdb8b"))
	(cone.material as ShaderMaterial).set_shader_parameter("beam_opacity",
		0.24 if red else 0.20)


func _add_halo(root: Node2D, offset: Vector2, tint: Color,
		scale_factor: float, opacity: float, layer: int) -> Sprite2D:
	if _halo_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 256
		texture.height = 256
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		_halo_texture = texture
	var halo := Sprite2D.new()
	halo.texture = _halo_texture
	halo.position = offset
	halo.scale = Vector2.ONE * scale_factor
	halo.modulate = Color(tint.r, tint.g, tint.b, opacity)
	halo.z_as_relative = false
	halo.z_index = layer
	# Mistura normal preserva lilás/verde; aditiva lavava o centro em branco.
	root.add_child(halo)
	return halo


func _add_light(root: Node2D, offset: Vector2, tint: Color,
		energy: float, always_on: bool) -> PointLight2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.85))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.texture = texture
	light.texture_scale = 2.7 if not always_on else 1.4
	light.color = tint
	light.energy = energy
	light.position = offset
	light.enabled = always_on
	root.add_child(light)
	if not always_on:
		_post_lights.append(light)
	return light


func _on_actor_moved(actor: EntityState, path: Array[Vector2i],
		_stamina_spent: int) -> void:
	if actor == null or path.is_empty() or _grid == null \
			or _grid.ppp_anomaly_triggered:
		return
	if _grid.ppp_anomaly_kind == &"anomalia_poste":
		if _post_anomaly_roots.is_empty():
			return
		_grid.ppp_anomaly_triggered = true
		_activate_post()
	elif _grid.ppp_anomaly_kind == &"anomalia_lixo":
		if _anomaly_visual == null:
			return
		var destination := path[-1]
		if destination.x not in [HexGrid.PPP_MAP_WIDTH / 2 - 1,
			HexGrid.PPP_MAP_WIDTH / 2]:
			return
		var expected_grid := _grid
		var party := map_view.get_node_or_null("MapRoot/DepthSorted/PlayableActors") \
			as PlayablePartyView
		var visual := party.visuals_by_slot.get(actor.playable_slot_id) \
			as PlayableActorVisual if party != null else null
		if visual != null:
			await visual.walk_finished
		if is_inside_tree() and _grid == expected_grid \
				and not _grid.ppp_anomaly_triggered:
			_grid.ppp_anomaly_triggered = true
			_activate_litter()


func _on_actor_teleported(actor: EntityState, destination: Vector2i) -> void:
	if actor == null or _grid == null or _grid.ppp_anomaly_triggered \
			or _grid.ppp_anomaly_kind != &"anomalia_lixo" or _anomaly_visual == null:
		return
	if destination.x in [HexGrid.PPP_MAP_WIDTH / 2 - 1,
			HexGrid.PPP_MAP_WIDTH / 2]:
		_grid.ppp_anomaly_triggered = true
		_activate_litter()


func _activate_post() -> void:
	for root in _post_anomaly_roots:
		if not is_instance_valid(root):
			continue
		var base_sprite := root.get_node_or_null("DecorationSprite") as Sprite2D
		if base_sprite != null:
			root.remove_child(base_sprite)
			base_sprite.queue_free()
		var animation := _add_animation(root, "anomalia_poste", POST_SCALE)
		_ambient_animations.append({"sprite": animation,
			"wait": randf_range(6, 30), "minimum": 6.0, "maximum": 30.0})
		for effect in _post_effects:
			if effect["root"] == root:
				_apply_post_palette(effect, ANOMALY_POST_LIGHT)
				break


func _activate_litter() -> void:
	if not is_instance_valid(_anomaly_visual):
		return
	for child in _anomaly_visual.get_children():
		if child is Sprite2D:
			child.queue_free()
	var animation := _add_animation(_anomaly_visual,
		"anomalia_lixo", SMALL_SCALE)
	animation.play(&"move")
	var map_root := map_view.get_node("MapRoot") as Node2D
	var screen_middle: float = get_viewport_rect().size.x * 0.5 \
		- map_root.position.x
	var target_x := -300.0 if _anomaly_visual.position.x < screen_middle else \
		get_viewport_rect().size.x + 300.0
	var tween := _anomaly_visual.create_tween()
	tween.tween_property(_anomaly_visual, "position:x", target_x, 1.4)
	tween.parallel().tween_property(_anomaly_visual, "modulate:a", 0.0, 0.4) \
		.set_delay(1.0)
	tween.finished.connect(func() -> void:
		if is_instance_valid(_anomaly_visual):
			_anomaly_visual.queue_free())
