extends Node

## Escala tipográfica única para toda a interface, inclusive controles criados
## durante a partida. Um override posterior ainda é tratado como tamanho-base.
const FONT_FACTOR := 4.0 / 3.0
const FONT_KEYS: Array[StringName] = [
	&"font_size", &"normal_font_size", &"bold_font_size",
	&"italics_font_size", &"bold_italics_font_size", &"mono_font_size",
]
const META_LAST_SCALED := &"_ppp_last_scaled_font_sizes"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _scan(node: Node) -> void:
	if node is Control:
		_watch_and_scale(node as Control)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	if node is Control:
		_watch_and_scale_ref.call_deferred(weakref(node))


func _watch_and_scale_ref(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if control != null:
		_watch_and_scale(control)


func _watch_and_scale(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	if not control.theme_changed.is_connected(_on_theme_changed.bind(control)):
		control.theme_changed.connect(_on_theme_changed.bind(control))
	_scale(control)


func _on_theme_changed(control: Control) -> void:
	if is_instance_valid(control):
		_scale_ref.call_deferred(weakref(control))


func _scale_ref(reference: WeakRef) -> void:
	var control := reference.get_ref() as Control
	if control != null:
		_scale(control)


func _scale(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return
	var last: Dictionary = control.get_meta(META_LAST_SCALED, {})
	for key in FONT_KEYS:
		if not control.has_theme_font_size_override(key):
			last.erase(key)
			continue
		var current := control.get_theme_font_size(key)
		if last.get(key, -1) == current:
			continue
		var scaled := maxi(12, roundi(float(current) * FONT_FACTOR))
		last[key] = scaled
		# Marcar antes de alterar o Theme evita reescalar o próprio sinal.
		control.set_meta(META_LAST_SCALED, last)
		control.add_theme_font_size_override(key, scaled)
	control.set_meta(META_LAST_SCALED, last)
