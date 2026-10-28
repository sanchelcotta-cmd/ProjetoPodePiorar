class_name GameMusicController
extends Node

## Ponte de estado entre a partida e as músicas globais. O serviço de áudio
## conserva a rádio escolhida; esta cena apenas informa se há Exploração,
## Combate, pausa ou nenhuma campanha em curso. Também cobre load em Combate.
@export var gerencia: GerenciaJogo

var _audio: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_audio = get_node_or_null("/root/GameAudio")
	set_process(_audio != null)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _exit_tree() -> void:
	if _audio != null:
		_audio.call("set_game_context", &"none")


func _refresh() -> void:
	if _audio == null:
		return
	var context: StringName = &"none"
	if gerencia != null and gerencia.campaign != null \
			and gerencia.campaign.current_map != null \
			and not gerencia.campaign.is_terminal():
		if get_tree().paused:
			context = &"paused"
		elif gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
			context = &"combat"
		else:
			context = &"exploration"
	_audio.call("set_game_context", context)
