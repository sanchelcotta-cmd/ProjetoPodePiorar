extends Resource
class_name Informacao

enum TipoInformacao {
	KHAINOKATA,
	ORCHESTRA,
	HOMENS_DE_PRETO,
	CONTROLE_DA_MENTE
}

@export var id: int = -1
@export var titulo: String = ""
@export_multiline var descricao: String = ""
@export var tipo: TipoInformacao

@export_range(1, 5) var numero: int = 1
