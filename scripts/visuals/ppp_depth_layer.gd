class_name PPPDepthLayer
extends Node2D

## Camada do mundo para personagens, inimigos, aliados e decorações futuras.
## O ponto (position) de cada visual deve ficar nos PÉS/BASE do objeto.
## Assim, quem está mais perto da margem inferior (Y maior) aparece na frente.
## Deixe todos com o mesmo z_index; z diferentes NÃO são ordenados por Y.


func _ready() -> void:
	y_sort_enabled = true


## Para novos visuais criados durante a partida. Grupos internos também
## precisam de y_sort_enabled=true para seus membros se misturarem aos demais.
func add_world_visual(visual: Node2D, feet_position: Vector2) -> void:
	if visual == null or visual.get_parent() != null:
		push_error("PPPDepthLayer: o visual deve existir e ainda não ter pai.")
		return
	add_child(visual)
	visual.position = feet_position
	visual.z_index = 0
