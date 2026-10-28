class_name GameDifficulty
extends RefCounted

## Regra da campanha, nunca preferência global nem alteração de Resources.
enum Mode { SUGAR, STANDARD, CHAOTIC }


static func is_available(mode: int) -> bool:
	return mode in [Mode.SUGAR, Mode.STANDARD, Mode.CHAOTIC]


static func label(mode: int) -> String:
	match mode:
		Mode.SUGAR: return "Água com Açúcar"
		Mode.STANDARD: return "Padrão"
		Mode.CHAOTIC: return "Caótico"
	return "Desconhecida"
