class_name CatastropheVisualController
extends Node2D

## A arte vive exatamente enquanto o estado da catástrofe vive. O céu já
## usa os filtros de Nevasca, Áurea e Portais do PPPParallaxBackground.
## Perfis adicionados no Inspetor podem complementar isso com sprites,
## AnimationPlayer e um filtro sobre o mundo, sem mexer na regra de jogo.

@export var catastrophe_manager: CatastropheManager
@export var visual_root: Node2D
@export var profiles: Array[CatastropheVisualProfile] = []

var _instances: Dictionary = {}
var _filter: ColorRect


func _ready() -> void:
	_filter = ColorRect.new()
	_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_filter.color = Color.TRANSPARENT
	_filter.z_index = 100
	add_child(_filter)
	resized_filter()
	get_viewport().size_changed.connect(resized_filter)
	if catastrophe_manager != null:
		catastrophe_manager.catastrophe_started.connect(_on_started)
		catastrophe_manager.catastrophe_ended.connect(_on_ended)
		if catastrophe_manager.gerencia != null:
			catastrophe_manager.gerencia.map_generated.connect(_on_map_generated)
			for record in catastrophe_manager.gerencia.campaign.active_catastrophes:
				_on_started(record["event_id"])


func resized_filter() -> void:
	if _filter != null:
		_filter.size = get_viewport_rect().size
		# O chão/casas podem mudar de posição ao gerar o mapa; o filtro deve
		# cobrir a viewport, não começar na origem deslocada do MapRoot.
		_filter.global_position = Vector2.ZERO


func _on_map_generated(_new_map: HexGrid) -> void:
	resized_filter.call_deferred()


func _on_started(event_id: StringName) -> void:
	if _instances.has(event_id):
		return
	var profile := _profile(event_id)
	if profile != null and profile.animation_scene != null and visual_root != null:
		var instance := profile.animation_scene.instantiate()
		visual_root.add_child(instance)
		_instances[event_id] = instance
		_play_animations(instance, profile.animation_name)
	else:
		_instances[event_id] = null
	_refresh_filter()


func _on_ended(event_id: StringName) -> void:
	var instance := _instances.get(event_id) as Node
	if instance != null:
		instance.queue_free()
	_instances.erase(event_id)
	_refresh_filter()


func _profile(event_id: StringName) -> CatastropheVisualProfile:
	for profile in profiles:
		if profile != null and profile.event_id == event_id:
			return profile
	return null


func _refresh_filter() -> void:
	_filter.color = Color.TRANSPARENT
	if catastrophe_manager == null or catastrophe_manager.gerencia == null:
		return
	# A última ativada que tem filtro vence; efeitos de jogo coexistem.
	for record in catastrophe_manager.gerencia.campaign.active_catastrophes:
		var profile := _profile(record["event_id"])
		if profile != null and profile.filter_color.a > 0.0:
			_filter.color = profile.filter_color
	# Portais Infernais sobrepõe qualquer outro filtro de céu/ambiente
	# enquanto sua Rodada ainda estiver ativa, mesmo se foi criado antes.
	if catastrophe_manager.gerencia.campaign.are_infernal_portals_visuals_active():
		var infernal := _profile(CampaignState.PORTAIS_INFERNAIS_EVENT_ID)
		if infernal != null and infernal.filter_color.a > 0.0:
			_filter.color = infernal.filter_color


func _play_animations(root: Node, animation_name: StringName) -> void:
	if root is AnimatedSprite2D:
		(root as AnimatedSprite2D).play(animation_name)
	if root is AnimationPlayer:
		(root as AnimationPlayer).play(animation_name)
	for child in root.get_children():
		_play_animations(child, animation_name)
