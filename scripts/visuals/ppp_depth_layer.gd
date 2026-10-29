class_name PPPDepthLayer
extends Node2D

## Camada do mundo para personagens, inimigos, aliados e decorações futuras.
## O ponto (position) de cada visual deve ficar nos PÉS/BASE do objeto.
## Assim, quem está mais perto da margem inferior (Y maior) aparece na frente.
## Personagens e postes ficam no mesmo z_index e se ordenam por Y.
## Árvores e objetos de fachada usam estratos abaixo: sua copa nunca cobre
## quem está num hex, mesmo quando a base da árvore está mais à frente.


func _ready() -> void:
	y_sort_enabled = true


## Para novos visuais criados durante a partida. Contêineres de personagens
## usam Y-sort interno; objetos únicos com base/pés próprios não devem usar,
## para que o centro do sprite não substitua a base na ordem visual.
func add_world_visual(visual: Node2D, feet_position: Vector2) -> void:
	if visual == null or visual.get_parent() != null:
		push_error("PPPDepthLayer: o visual deve existir e ainda não ter pai.")
		return
	add_child(visual)
	visual.position = feet_position
	visual.z_index = 0
