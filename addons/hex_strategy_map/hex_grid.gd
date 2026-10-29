class_name HexGrid
extends RefCounted

## O grid guarda posições, conteúdo e estado dos blocos. Ele NÃO sorteia
## Eventos, Itens ou Encontros: essa será a tarefa do MapGenerator.

# Os números são explícitos para não mudar Resources que já os referenciam.
enum PPPBlockType {
	NONE = 0,
	INFORMATION = 1,
	CONSUMABLE = 2,
	EQUIPMENT = 3,
	EVENT = 4,
	ENCOUNTER = 5,
	CATASTROPHE = 6,
	TRAP = 7,
	CURSE = 8,
}

enum PPPMapMode {
	EXPLORATION = 0,
	COMBAT = 1,
}

enum PPPBlockState {
	HIDDEN = 0,
	REVEALED = 1,
	ACTIVATED = 2,
	DESTROYED = 3,
	CANCELLED = 4,
}

const PPP_MAP_WIDTH := 8
const PPP_MAP_HEIGHT := 5
const PPP_START_POSITIONS := [Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3)]
const HEX_SIZE := 32.0
const HEX_SQRT3 := 1.7320508075688772

var cells: Dictionary = {} # Vector2i -> HexCell
var revealed_by_skill_ids: Dictionary = {} # Vector2i -> Array[StringName]
var ppp_map_mode: int = PPPMapMode.EXPLORATION
# O cenário escolhido faz parte deste mapa. Assim redimensionar a janela ou
# recarregar a campanha não sorteia outra fachada para os mesmos 40 blocos.
var ppp_background_path: String = ""
## A decoração usa semente própria para não mudar com resize, save ou zoom.
var ppp_decoration_seed: int = 0
var ppp_anomaly_planned: bool = false
var ppp_anomaly_kind: StringName = &""
var ppp_anomaly_triggered: bool = false
# O céu é escolhido junto com o mapa e permanece igual ao redimensionar.
# A Áurea Fúnebre usa a variante cinzenta já sorteada para este mapa.
var ppp_parallax_path: String = ""
var ppp_aura_parallax_path: String = ""
var ppp_snow_parallax_path: String = ""
var ppp_parallax_filter: int = 0


## Cria os 40 blocos vazios. A StartZone fica fora deles e não recebe conteúdo.
func generate_ppp_exploration_map() -> void:
	cells.clear()
	revealed_by_skill_ids.clear()
	ppp_map_mode = PPPMapMode.EXPLORATION
	ppp_background_path = ""
	ppp_decoration_seed = 0
	ppp_anomaly_planned = false
	ppp_anomaly_kind = &""
	ppp_anomaly_triggered = false
	ppp_parallax_path = ""
	ppp_aura_parallax_path = ""
	ppp_snow_parallax_path = ""
	ppp_parallax_filter = 0
	for y in PPP_MAP_HEIGHT:
		for x in PPP_MAP_WIDTH:
			var coord := Vector2i(x, y)
			cells[coord] = HexCell.new(coord)


## Recebe o Resource sorteado pelo gerador. Substituir conteúdo reinicia o
## bloco para HIDDEN, inclusive quando antes estava ativado ou destruído.
func set_ppp_block(
		coord: Vector2i,
		block_type: int,
		content: Resource = null,
		generated_from_random_block: bool = false,
) -> void:
	var cell := get_cell(coord)
	if cell == null:
		push_warning("HexGrid: bloco fora do mapa: %s" % coord)
		return
	var content_path: String = content.resource_path if content != null else ""
	if content != null and content_path.is_empty():
		push_warning("HexGrid: salve o Resource antes de colocá-lo no mapa: %s" % coord)
	cell.block_type = block_type
	cell.resource_path = content_path
	cell.map_visual_path = ""
	cell.generated_from_random_block = generated_from_random_block
	cell.state = PPPBlockState.HIDDEN
	cell.movement_blocked = false
	revealed_by_skill_ids.erase(coord)


func get_ppp_block_type(coord: Vector2i) -> int:
	var cell := get_cell(coord)
	return cell.block_type if cell != null else PPPBlockType.NONE


## Devolve uma fotografia dos dados; alterar este Dictionary não altera o mapa.
func get_ppp_block_data(coord: Vector2i) -> Dictionary:
	var cell := get_cell(coord)
	if cell == null:
		return {}
	return {
		"block_type": cell.block_type,
		"resource_path": cell.resource_path,
		"map_visual_path": cell.map_visual_path,
		"generated_from_random_block": cell.generated_from_random_block,
		"state": cell.state,
		"movement_blocked": cell.movement_blocked,
	}


func get_ppp_block_resource(coord: Vector2i) -> Resource:
	var cell := get_cell(coord)
	if cell == null or cell.resource_path.is_empty():
		return null
	return load(cell.resource_path)


## Cor/animação do conteúdo deste HEX, não do EventData compartilhado.
## Assim o mesmo efeito pode ganhar qualquer cor a cada novo surgimento.
func set_ppp_map_visual(coord: Vector2i, visual: SpriteSheetAnimationData) -> void:
	var cell := get_cell(coord)
	if cell != null:
		cell.map_visual_path = visual.resource_path if visual != null else ""


func get_ppp_map_visual(coord: Vector2i) -> SpriteSheetAnimationData:
	var cell := get_cell(coord)
	if cell == null or cell.map_visual_path.is_empty():
		return null
	return load(cell.map_visual_path) as SpriteSheetAnimationData


## Revelar informa o que há ali, sem executar o conteúdo.
func reveal_ppp_block(coord: Vector2i) -> void:
	var cell := get_cell(coord)
	if cell != null and cell.state == PPPBlockState.HIDDEN:
		cell.state = PPPBlockState.REVEALED


## Ativar executa o conteúdo uma vez. O executor fará a execução; aqui só
## registramos que o bloco foi resolvido.
func activate_ppp_block(coord: Vector2i) -> void:
	var cell := get_cell(coord)
	if cell != null and cell.state in [PPPBlockState.HIDDEN, PPPBlockState.REVEALED]:
		cell.state = PPPBlockState.ACTIVATED


func cancel_ppp_block(coord: Vector2i) -> void:
	var cell := get_cell(coord)
	if cell != null and cell.state in [PPPBlockState.HIDDEN, PPPBlockState.REVEALED]:
		cell.state = PPPBlockState.CANCELLED


func destroy_ppp_block(coord: Vector2i) -> void:
	var cell := get_cell(coord)
	if cell != null:
		cell.state = PPPBlockState.DESTROYED


## Poder atravessar e poder PARAR são perguntas diferentes. Na Exploração,
## resolvidos são passagem, mas não destino. No Combate, qualquer bloco
## desocupado pode ser destino, até o mesmo bloco em outro movimento.
func can_choose_ppp_destination(
		coord: Vector2i,
		actor_coord: Vector2i,
		occupied_coords: Dictionary = {},
) -> bool:
	if not is_valid(coord):
		return false
	if coord != actor_coord and occupied_coords.has(coord):
		return false
	if not can_traverse_ppp(coord):
		return false
	if ppp_map_mode == PPPMapMode.COMBAT:
		return true
	var cell := get_cell(coord)
	return cell.state in [PPPBlockState.HIDDEN, PPPBlockState.REVEALED]


func can_traverse_ppp(coord: Vector2i) -> bool:
	var cell := get_cell(coord)
	return cell != null and not cell.movement_blocked


## Cada vizinho custa exatamente 1 Stamina. Personagens na StartZone gastam
## 1 ponto para entrar na primeira coluna; a StartZone não consome hex do mapa.
func get_ppp_reachable_hexes(origin: Vector2i, stamina: int) -> Dictionary:
	var costs: Dictionary = {}
	if stamina < 0:
		return costs
	var queue: Array[Vector2i] = []
	if is_ppp_start_zone(origin):
		var entry := get_ppp_start_entry(origin)
		if stamina < 1 or not can_traverse_ppp(entry):
			return costs
		costs[entry] = 1
		queue.append(entry)
	elif is_valid(origin):
		costs[origin] = 0
		queue.append(origin)
	else:
		return costs
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var next_cost: int = costs[current] + 1
		if next_cost > stamina:
			continue
		for neighbor in get_neighbors(current):
			if can_traverse_ppp(neighbor) and not costs.has(neighbor):
				costs[neighbor] = next_cost
				queue.append(neighbor)
	return costs


## O retorno não inclui a origem. Saindo da StartZone, começa pelo hex de entrada.
func get_ppp_movement_path(origin: Vector2i, destination: Vector2i, stamina: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var reachable := get_ppp_reachable_hexes(origin, stamina)
	if not reachable.has(destination):
		return path
	var entry := get_ppp_start_entry(origin) if is_ppp_start_zone(origin) else origin
	var parents: Dictionary = {}
	var seen: Dictionary = {}
	seen[entry] = true
	var queue: Array[Vector2i] = [entry]
	var head := 0
	while head < queue.size() and not seen.has(destination):
		var current := queue[head]
		head += 1
		for neighbor in get_neighbors(current):
			if reachable.has(neighbor) and not seen.has(neighbor):
				seen[neighbor] = true
				parents[neighbor] = current
				queue.append(neighbor)
	var cursor := destination
	while cursor != entry:
		path.push_front(cursor)
		cursor = parents[cursor]
	if is_ppp_start_zone(origin):
		path.push_front(entry)
	return path


func get_ppp_available_destinations(
		reachable: Dictionary,
		actor_coord: Vector2i,
		occupied_coords: Dictionary = {},
) -> Dictionary:
	var result: Dictionary = {}
	for coord in reachable:
		if can_choose_ppp_destination(coord, actor_coord, occupied_coords):
			result[coord] = reachable[coord]
	return result


func get_ppp_start_positions() -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	positions.assign(PPP_START_POSITIONS)
	return positions


func is_ppp_start_zone(coord: Vector2i) -> bool:
	return coord in PPP_START_POSITIONS


func get_ppp_start_entry(start_coord: Vector2i) -> Vector2i:
	return Vector2i(0, start_coord.y) if is_ppp_start_zone(start_coord) else Vector2i(-1, -1)


func get_cell(coord: Vector2i) -> HexCell:
	return cells.get(coord, null)


func is_valid(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < PPP_MAP_WIDTH and coord.y >= 0 and coord.y < PPP_MAP_HEIGHT and cells.has(coord)


## Salvar mapa inclui o Resource de cada bloco pelo caminho e seu estado.
func serialize() -> Dictionary:
	var cell_data: Array = []
	for cell in cells.values():
		cell_data.append(cell.serialize())
	var reveal_origins: Array[Dictionary] = []
	for coord in revealed_by_skill_ids:
		var serialized_ids: Array[String] = []
		for id in revealed_by_skill_ids[coord]:
			serialized_ids.append(str(id))
		reveal_origins.append({"coord": [coord.x, coord.y],
			"skill_ids": serialized_ids})
	return {
		"format_version": 1,
		"map_mode": ppp_map_mode,
		"background_path": ppp_background_path,
		"decoration_seed": ppp_decoration_seed,
		"anomaly_planned": ppp_anomaly_planned,
		"anomaly_kind": str(ppp_anomaly_kind),
		"anomaly_triggered": ppp_anomaly_triggered,
		"parallax_path": ppp_parallax_path,
		"aura_parallax_path": ppp_aura_parallax_path,
		"snow_parallax_path": ppp_snow_parallax_path,
		"parallax_filter": ppp_parallax_filter,
		"revealed_by_skill_ids": reveal_origins,
		"cells": cell_data,
	}


static func deserialize(data: Dictionary) -> HexGrid:
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	for entry in data.get("cells", []):
		if entry is Dictionary:
			var cell := HexCell.deserialize(entry)
			if grid.is_valid(cell.coord):
				grid.cells[cell.coord] = cell
	grid.ppp_map_mode = int(data.get("map_mode", PPPMapMode.EXPLORATION))
	grid.ppp_background_path = str(data.get("background_path", ""))
	grid.ppp_decoration_seed = int(data.get("decoration_seed", 0))
	grid.ppp_anomaly_planned = bool(data.get("anomaly_planned", false))
	grid.ppp_anomaly_kind = StringName(str(data.get("anomaly_kind", "")))
	grid.ppp_anomaly_triggered = bool(data.get("anomaly_triggered", false))
	grid.ppp_parallax_path = str(data.get("parallax_path", ""))
	grid.ppp_aura_parallax_path = str(data.get("aura_parallax_path", ""))
	grid.ppp_snow_parallax_path = str(data.get("snow_parallax_path", ""))
	grid.ppp_parallax_filter = int(data.get("parallax_filter", 0))
	for entry in data.get("revealed_by_skill_ids", []):
		if not entry is Dictionary:
			continue
		var pair: Array = entry.get("coord", [])
		if pair.size() != 2:
			continue
		var coord := Vector2i(int(pair[0]), int(pair[1]))
		if not grid.is_valid(coord):
			continue
		var ids: Array[StringName] = []
		for id in entry.get("skill_ids", []):
			ids.append(StringName(str(id)))
		grid.revealed_by_skill_ids[coord] = ids
	return grid


## Coordenadas offset odd-r: a posição alterna meio hex nas linhas ímpares.
static func offset_to_pixel(coord: Vector2i, size: float = HEX_SIZE) -> Vector2:
	var x := size * HEX_SQRT3 * (coord.x + 0.5 * (coord.y & 1))
	var y := size * 1.5 * coord.y
	return Vector2(x, y)


static func offset_to_cube(coord: Vector2i) -> Vector3i:
	var x := coord.x - floori(float(coord.y - (coord.y & 1)) / 2.0)
	var z := coord.y
	return Vector3i(x, -x - z, z)


static func distance(a: Vector2i, b: Vector2i) -> int:
	var ca := offset_to_cube(a)
	var cb := offset_to_cube(b)
	return maxi(absi(ca.x - cb.x), maxi(absi(ca.y - cb.y), absi(ca.z - cb.z)))


static func hex_polygon_points(size: float, scale_factor: float = 0.95) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 6:
		var angle := PI / 3.0 * i - PI / 6.0
		points.append(Vector2(cos(angle), sin(angle)) * size * scale_factor)
	return points


## Os seis vizinhos matemáticos; quem chama filtra os que ficam fora do mapa.
static func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	if (coord.y & 1) == 0:
		return [
			Vector2i(coord.x - 1, coord.y - 1),
			Vector2i(coord.x, coord.y - 1),
			Vector2i(coord.x - 1, coord.y),
			Vector2i(coord.x + 1, coord.y),
			Vector2i(coord.x - 1, coord.y + 1),
			Vector2i(coord.x, coord.y + 1),
		]
	return [
		Vector2i(coord.x, coord.y - 1),
		Vector2i(coord.x + 1, coord.y - 1),
		Vector2i(coord.x - 1, coord.y),
		Vector2i(coord.x + 1, coord.y),
		Vector2i(coord.x, coord.y + 1),
		Vector2i(coord.x + 1, coord.y + 1),
	]


## Útil para efeitos que atingem todos os hexes a uma distância exata.
func get_ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if radius < 0:
		return result
	for coord in cells:
		if distance(center, coord) == radius:
			result.append(coord)
	return result
