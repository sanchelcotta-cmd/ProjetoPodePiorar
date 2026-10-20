class_name HexCell
extends RefCounted

## Um dos 40 blocos jogáveis. A posição e o conteúdo pertencem ao mapa;
## a Vida e a posição das entidades não ficam aqui.
var coord: Vector2i = Vector2i.ZERO
var block_type: int = 0
var resource_path: String = ""
# Aparência visível colocada por uma regra especial (ex.: duende). O efeito
# continua vindo de resource_path; a cor não denuncia qual efeito é.
var map_visual_path: String = ""
var generated_from_random_block: bool = false
var state: int = 0
## Reserva para efeitos do próprio bloco que vedem passagem/destino.
## O tipo do Resource (Item, Evento, Informação...) nunca bloqueia por si.
var movement_blocked: bool = false


func _init(cell_coord: Vector2i = Vector2i.ZERO) -> void:
	coord = cell_coord


## Os Resources são salvos pelo caminho, não duplicados dentro do mapa.
func serialize() -> Dictionary:
	return {
		"coord": [coord.x, coord.y],
		"block_type": block_type,
		"resource_path": resource_path,
		"map_visual_path": map_visual_path,
		"generated_from_random_block": generated_from_random_block,
		"state": state,
		"movement_blocked": movement_blocked,
	}


static func deserialize(data: Dictionary) -> HexCell:
	var pair: Array = data.get("coord", [0, 0])
	if pair.size() < 2:
		pair = [0, 0]
	var cell := HexCell.new(Vector2i(int(pair[0]), int(pair[1])))
	cell.block_type = int(data.get("block_type", 0))
	cell.resource_path = str(data.get("resource_path", ""))
	cell.map_visual_path = str(data.get("map_visual_path", ""))
	cell.generated_from_random_block = bool(data.get("generated_from_random_block", false))
	cell.state = int(data.get("state", 0))
	cell.movement_blocked = bool(data.get("movement_blocked", false))
	return cell
