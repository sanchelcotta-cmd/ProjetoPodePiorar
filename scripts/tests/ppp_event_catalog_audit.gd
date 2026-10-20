extends SceneTree

## Inventário legível dos Events cadastrados: godot --headless --path .
## --script res://scripts/tests/ppp_event_catalog_audit.gd
const ROOT := "res://resources/events"


func _initialize() -> void:
	for path in _paths(ROOT):
		var event := load(path) as EventData
		if event == null:
			continue
		var names: Array[String] = []
		for outcome in event.outcomes:
			if outcome == null:
				continue
			for effect in outcome.effects:
				if effect != null:
					names.append(Event_EffectData.EffectType.keys()[effect.effect_type])
			for option in outcome.effect_choices:
				if option != null:
					for effect in option.effects:
						if effect != null:
							names.append(Event_EffectData.EffectType.keys()[effect.effect_type])
		print("%s | %s | %s | %s" % [event.id, event.display_name,
			EventData.ResolutionMode.keys()[event.resolution_mode], ",".join(names)])
	quit()


func _paths(directory: String) -> Array[String]:
	var result: Array[String] = []
	for entry in ResourceLoader.list_directory(directory):
		if entry.ends_with("/"):
			result.append_array(_paths(directory.path_join(entry.trim_suffix("/"))))
		elif entry.ends_with(".tres"):
			result.append(directory.path_join(entry))
	result.sort()
	return result
