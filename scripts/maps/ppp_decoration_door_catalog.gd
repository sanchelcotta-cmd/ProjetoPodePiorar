class_name PPPDecorationDoorCatalog
extends RefCounted

## Lê apenas os retângulos da cena editorial, sem instanciar suas sete PNGs.
## A cena que o artista salva continua sendo a única fonte das portas.
const ORIENTATION_SCENE := "res://scenes/visuals/orientacao_portas_backgrounds.tscn"
static var _cached_zones: Dictionary = {}


static func zones_for(background_path: String) -> Array[Rect2]:
	if _cached_zones.is_empty():
		_cached_zones = _read_orientation_scene()
	var result: Array[Rect2] = []
	result.assign(_cached_zones.get(background_path, []))
	return result


static func clear_cache() -> void:
	_cached_zones.clear()


static func _read_orientation_scene() -> Dictionary:
	var result := {}
	var facade_sources := {}
	var facade_areas := {}
	var file := FileAccess.open(ORIENTATION_SCENE, FileAccess.READ)
	if file == null:
		push_error("Decoração: cena de orientação das portas indisponível.")
		return result
	var node_name := ""
	var node_parent := ""
	var node_type := ""
	var source := ""
	var offsets := {}
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("[node "):
			_commit_node(node_name, node_parent, node_type, source, offsets,
				facade_sources, facade_areas)
			node_name = _attribute(line, "name")
			node_parent = _attribute(line, "parent")
			node_type = _attribute(line, "type")
			source = ""
			offsets = {}
		elif line.begins_with("metadata/source_background = "):
			source = _quoted_value(line)
		elif line.begins_with("offset_"):
			var key := line.get_slice(" = ", 0)
			if key in ["offset_left", "offset_top", "offset_right", "offset_bottom"]:
				offsets[key] = float(line.get_slice(" = ", 1))
	_commit_node(node_name, node_parent, node_type, source, offsets,
		facade_sources, facade_areas)
	for facade in facade_sources:
		result[facade_sources[facade]] = facade_areas.get(facade, [])
	return result


static func _commit_node(node_name: String, node_parent: String,
		node_type: String, source: String, offsets: Dictionary,
		facade_sources: Dictionary, facade_areas: Dictionary) -> void:
	if node_parent == "Fachadas" and not source.is_empty():
		facade_sources[node_name] = source
	if node_type != "ReferenceRect" or not node_parent.ends_with("/Portas"):
		return
	if not offsets.has_all(["offset_left", "offset_top",
			"offset_right", "offset_bottom"]):
		return
	var facade := node_parent.trim_prefix("Fachadas/").trim_suffix("/Portas")
	var rect := Rect2(Vector2(offsets["offset_left"], offsets["offset_top"]),
		Vector2(offsets["offset_right"] - offsets["offset_left"],
			offsets["offset_bottom"] - offsets["offset_top"]))
	if rect.size.x > 0.0 and rect.size.y > 0.0:
		if not facade_areas.has(facade):
			facade_areas[facade] = []
		facade_areas[facade].append(rect)


static func _attribute(header: String, key: String) -> String:
	var token := key + '="'
	var start := header.find(token)
	if start < 0:
		return ""
	start += token.length()
	var ending := header.find('"', start)
	return header.substr(start, ending - start) if ending >= start else ""


static func _quoted_value(line: String) -> String:
	var start := line.find('"')
	var ending := line.rfind('"')
	return line.substr(start + 1, ending - start - 1) if ending > start else ""
