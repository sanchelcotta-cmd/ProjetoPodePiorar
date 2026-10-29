class_name TutorialContent
extends RefCounted

const DATA_PATH := "res://resources/tutorial_pages.json"

static func load_pages() -> Array[Dictionary]:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Tutorial: conteúdo não encontrado em %s." % DATA_PATH)
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not data is Dictionary or not data.has("pages") or not data["pages"] is Array:
		push_error("Tutorial: catálogo de páginas inválido.")
		return []
	var result: Array[Dictionary] = []
	var ids := {}
	for entry in data["pages"]:
		if not entry is Dictionary:
			continue
		var id := str(entry.get("id", ""))
		if id.is_empty() or ids.has(id) or str(entry.get("body", "")).is_empty():
			continue
		ids[id] = true
		result.append(entry)
	return result
