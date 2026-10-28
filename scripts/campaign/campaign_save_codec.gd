class_name CampaignSaveCodec
extends RefCounted

## Formato de dados, não de objetos arbitrários. Somente estas classes de
## estado podem ser reconstruídas; Resources são referidos por res://.
const GRAPH_VERSION := 1
const ALLOWED_SCRIPTS := {
	"res://scripts/campaign/campaign_state.gd": true,
	"res://scripts/campaign/entity_state.gd": true,
	"res://scripts/campaign/inventory_item_state.gd": true,
	"res://scripts/campaign/skill_grant_state.gd": true,
	"res://scripts/campaign/debuff_instance_state.gd": true,
	"res://scripts/campaign/delayed_skill_effect_state.gd": true,
	"res://addons/hex_strategy_map/hex_grid.gd": true,
	"res://addons/hex_strategy_map/hex_cell.gd": true,
	"res://scripts/random/d6_roller.gd": true,
}
const MAX_OBJECTS := 30000
const MAX_DEPTH := 160

var error := ""
var _seen: Dictionary = {}
var _records: Array[Dictionary] = []
var _decoded: Array = []
var _source_records: Array = []


func encode(root_value: Variant) -> Dictionary:
	error = ""
	_seen.clear()
	_records.clear()
	var root_node := _pack(root_value, 0)
	if not error.is_empty():
		return {}
	return {"graph_version": GRAPH_VERSION, "root": root_node,
		"objects": _records}


func decode(graph: Dictionary) -> Variant:
	error = ""
	if int(graph.get("graph_version", -1)) != GRAPH_VERSION:
		error = "Versão do grafo incompatível."
		return null
	_source_records = graph.get("objects", [])
	if not _source_records is Array or _source_records.size() > MAX_OBJECTS:
		error = "Tabela de objetos inválida."
		return null
	_decoded.resize(_source_records.size())
	_decoded.fill(null)
	var result: Variant = _unpack(graph.get("root"), 0)
	if not error.is_empty():
		return null
	_rebind_legacy_equipment_sources()
	return result


## Saves anteriores guardavam o ID volátil da instância somente na concessão.
## Vincula-o à cópia equipada antes de qualquer troca/desequipar após carregar.
func _rebind_legacy_equipment_sources() -> void:
	var skills := SkillManager.new()
	for object in _decoded:
		var actor := object as EntityState
		if actor == null:
			continue
		var assigned := {}
		for slot in [actor.equipped_weapons, actor.equipped_armors,
				actor.equipped_accessories]:
			for entry in slot:
				if entry == null or entry.data == null:
					continue
				if entry.equipment_source_id != &"":
					assigned[entry.equipment_source_id] = true
					continue
				for grant in actor.skill_grants:
					if grant.source_kind == &"equipment" \
							and grant.bound_source == entry.data \
							and not assigned.has(grant.source_id):
						entry.equipment_source_id = grant.source_id
						assigned[grant.source_id] = true
						break
		# Saves feitos após a falha antiga podem conter a concessão da
		# mochila já desequipada. Nenhum equipamento fora dos slots pode
		# conservar uma origem "equipment".
		var orphan_sources := {}
		for grant in actor.skill_grants:
			if grant.source_kind == &"equipment" and not assigned.has(grant.source_id):
				orphan_sources[grant.source_id] = true
		for source_id in orphan_sources:
			skills.remove_source(actor, &"equipment", source_id)
	skills.free()


func _pack(value: Variant, depth: int) -> Dictionary:
	if not error.is_empty():
		return {}
	if depth > MAX_DEPTH:
		error = "Estado profundo demais para salvar."
		return {}
	if value is Resource:
		var path := (value as Resource).resource_path
		if not path.begins_with("res://") or not ResourceLoader.exists(path):
			error = "Resource sem caminho estável: %s" % path
			return {}
		return {"t": "resource", "path": path}
	if value is Object:
		var object := value as Object
		var instance_key := object.get_instance_id()
		if _seen.has(instance_key):
			return {"t": "ref", "id": _seen[instance_key]}
		if _records.size() >= MAX_OBJECTS:
			error = "Quantidade excessiva de objetos no save."
			return {}
		var record_id := _records.size()
		_seen[instance_key] = record_id
		_records.append({})
		if object is RandomNumberGenerator:
			_records[record_id] = {"kind": "rng",
				"seed": str(object.seed), "state": str(object.state)}
			return {"t": "ref", "id": record_id}
		var script := object.get_script() as Script
		var path := script.resource_path if script != null else ""
		if not ALLOWED_SCRIPTS.has(path):
			error = "Classe fora do esquema de save: %s" % path
			return {}
		var fields := {}
		_records[record_id] = {"kind": "state", "script": path, "fields": fields}
		for property in object.get_property_list():
			if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			var name := str(property.name)
			fields[name] = _pack(object.get(name), depth + 1)
			if not error.is_empty():
				return {}
		return {"t": "ref", "id": record_id}
	if value is Array:
		var elements: Array = []
		for item in value:
			elements.append(_pack(item, depth + 1))
			if not error.is_empty():
				return {}
		return {"t": "array", "items": elements}
	if value is Dictionary:
		var pairs: Array = []
		for key in value:
			pairs.append([_pack(key, depth + 1), _pack(value[key], depth + 1)])
			if not error.is_empty():
				return {}
		return {"t": "dict", "pairs": pairs}
	if value is Callable or value is Signal:
		error = "Referência executável não pode ser salva."
		return {}
	var binary := var_to_bytes(value)
	if binary.is_empty():
		error = "Valor não serializável: %d" % typeof(value)
		return {}
	return {"t": "variant", "data": Marshalls.raw_to_base64(binary)}


func _unpack(node: Variant, depth: int) -> Variant:
	if not error.is_empty():
		return null
	if depth > MAX_DEPTH or not node is Dictionary:
		error = "Nó do save inválido."
		return null
	match str(node.get("t", "")):
		"variant":
			var raw := Marshalls.base64_to_raw(str(node.get("data", "")))
			if raw.is_empty():
				error = "Valor binário corrompido."
				return null
			return bytes_to_var(raw)
		"resource":
			var path := str(node.get("path", ""))
			if not path.begins_with("res://") or not ResourceLoader.exists(path):
				error = "Resource ausente ou inválido: %s" % path
				return null
			return load(path)
		"array":
			var items: Variant = node.get("items", [])
			if not items is Array:
				error = "Array inválido."
				return null
			var result: Array = []
			for item in items:
				result.append(_unpack(item, depth + 1))
			return result
		"dict":
			var pairs: Variant = node.get("pairs", [])
			if not pairs is Array:
				error = "Dicionário inválido."
				return null
			var result := {}
			for pair in pairs:
				if not pair is Array or pair.size() != 2:
					error = "Par de dicionário inválido."
					return null
				var key: Variant = _unpack(pair[0], depth + 1)
				var item: Variant = _unpack(pair[1], depth + 1)
				if not error.is_empty():
					return null
				result[key] = item
			return result
		"ref":
			return _unpack_reference(int(node.get("id", -1)), depth + 1)
	error = "Tipo de nó desconhecido."
	return null


func _unpack_reference(index: int, depth: int) -> Object:
	if index < 0 or index >= _source_records.size():
		error = "Referência de objeto inválida."
		return null
	if _decoded[index] != null:
		return _decoded[index]
	var record: Dictionary = _source_records[index]
	var instance: Object
	if record.get("kind") == "rng":
		instance = RandomNumberGenerator.new()
		_decoded[index] = instance
		instance.seed = int(str(record.get("seed", "0")))
		instance.state = int(str(record.get("state", "0")))
		return instance
	if record.get("kind") != "state":
		error = "Espécie de objeto inválida."
		return null
	var path := str(record.get("script", ""))
	if not ALLOWED_SCRIPTS.has(path):
		error = "Classe não permitida no save: %s" % path
		return null
	var script := load(path) as Script
	if script == null:
		error = "Script de estado indisponível: %s" % path
		return null
	instance = script.new()
	_decoded[index] = instance
	var fields: Variant = record.get("fields", {})
	if not fields is Dictionary:
		error = "Campos de estado inválidos."
		return null
	var allowed_fields := {}
	for property in instance.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			allowed_fields[str(property.name)] = true
	for name in fields:
		if not allowed_fields.has(name):
			error = "Campo fora do esquema: %s" % name
			return null
		var value: Variant = _unpack(fields[name], depth + 1)
		if not error.is_empty():
			return null
		var existing: Variant = instance.get(name)
		if existing is Array and value is Array:
			existing.clear()
			for item in value:
				existing.append(item)
			instance.set(name, existing)
		else:
			instance.set(name, value)
	return instance
