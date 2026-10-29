@tool
class_name SpriteOrientationReference
extends Node2D

## Mantém todos os Sprites ajustáveis proporcionais mesmo quando a ferramenta
## Escala do editor 2D ou o Inspetor altera só um dos eixos.
const EDITABLE_GROUPS := ["Companheiros", "SeguidoresEventos", "Duendes", "Transformacoes",
	"EntidadesPendentes"]
const SCENE_PATH := "res://scenes/visuals/orientacao_sprites.tscn"
const GNOME_SPRITE_PATH := "./Duendes/Duende1/Sprite"
const CHICKEN_SPRITE_PATH := "./Transformacoes/Galinha/Sprite"
const EVENT_FOLLOWER_SPRITE_PATH := "./SeguidoresEventos/BonequinhoAmigo/Sprite"

static var _chicken_scale_cache := 0.0
static var _event_follower_scale_cache := 0.0

var _last_scales: Dictionary = {}


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	for sprite in _editable_sprites():
		_last_scales[sprite.get_instance_id()] = sprite.scale


func _process(_delta: float) -> void:
	enforce_uniform_scales()


func enforce_uniform_scales() -> void:
	for sprite in _editable_sprites():
		var key := sprite.get_instance_id()
		var previous: Vector2 = _last_scales.get(key, sprite.scale)
		var current := sprite.scale
		if not is_equal_approx(current.x, current.y):
			# Na transformação galiforme, a altura é sempre a referência.
			# Nos demais sprites, o eixo arrastado rege ambos os lados.
			var is_chicken := sprite.get_parent().name == "Galinha"
			var y_changed := not is_equal_approx(current.y, previous.y)
			var uniform := current.y if is_chicken or y_changed else current.x
			if uniform > 0.0:
				sprite.scale = Vector2.ONE * uniform
				current = sprite.scale
		_last_scales[key] = current


func _editable_sprites() -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for group_name in EDITABLE_GROUPS:
		var group := get_node_or_null(group_name)
		if group == null:
			continue
		for entry in group.get_children():
			var sprite := entry.get_node_or_null("Sprite") as Sprite2D
			if sprite != null:
				result.append(sprite)
	return result


## Altura visual salva pelo artista no Duende 1. O mapa lê somente esta
## propriedade do PackedScene; não instancia toda a régua em cada hex.
static func gnome_reference_height() -> float:
	var packed := ResourceLoader.load(SCENE_PATH) as PackedScene
	if packed == null:
		return 0.0
	var state := packed.get_state()
	for node_index in state.get_node_count():
		if str(state.get_node_path(node_index)) != GNOME_SPRITE_PATH:
			continue
		var sprite_scale := Vector2.ONE
		var region := Rect2()
		for property_index in state.get_node_property_count(node_index):
			match str(state.get_node_property_name(node_index, property_index)):
				"scale":
					sprite_scale = state.get_node_property_value(node_index, property_index)
				"region_rect":
					region = state.get_node_property_value(node_index, property_index)
		if region.has_area() and sprite_scale.y > 0.0:
			return region.size.y * sprite_scale.y
	return 0.0


## A altura escolhida no editor rege os dois eixos da galinha no jogo.
static func chicken_reference_scale() -> float:
	if _chicken_scale_cache > 0.0:
		return _chicken_scale_cache
	var packed := ResourceLoader.load(SCENE_PATH) as PackedScene
	if packed == null:
		return 1.0
	var state := packed.get_state()
	for node_index in state.get_node_count():
		if str(state.get_node_path(node_index)) != CHICKEN_SPRITE_PATH:
			continue
		for property_index in state.get_node_property_count(node_index):
			if str(state.get_node_property_name(node_index, property_index)) == "scale":
				var reference_scale: Vector2 = state.get_node_property_value(
					node_index, property_index)
				_chicken_scale_cache = maxf(0.1, reference_scale.y)
				return _chicken_scale_cache
	return 1.0


static func event_follower_reference_scale() -> float:
	if _event_follower_scale_cache > 0.0:
		return _event_follower_scale_cache
	var packed := ResourceLoader.load(SCENE_PATH) as PackedScene
	if packed == null:
		return chicken_reference_scale()
	var state := packed.get_state()
	for node_index in state.get_node_count():
		if str(state.get_node_path(node_index)) != EVENT_FOLLOWER_SPRITE_PATH:
			continue
		for property_index in state.get_node_property_count(node_index):
			if str(state.get_node_property_name(node_index, property_index)) == "scale":
				var reference_scale: Vector2 = state.get_node_property_value(
					node_index, property_index)
				_event_follower_scale_cache = maxf(0.1, reference_scale.y)
				return _event_follower_scale_cache
	return chicken_reference_scale()
