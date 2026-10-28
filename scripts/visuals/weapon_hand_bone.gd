extends Bone2D

## Âncora invisível dirigida por metadados de cada quadro, sem IK nem
## deformação do personagem. Inicializa antes de entrar no Skeleton2D.
func _init() -> void:
	set_autocalculate_length_and_angle(false)
	set_length(7.0)
	set_rest(Transform2D.IDENTITY)
