class_name EncounterData
extends Resource

## Cadastro de um Encontro Indesejado, não de um inimigo isolado.
## Cada elemento de members liga um EntityData à sua própria quantidade.

@export_category("Identidade")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export_multiline var narrative_description: String

@export_category("Onde e quando aparece")
## Use os nomes padronizados: suburbio, baixo_centro e centro.
## Pode listar mais de um distrito. Vazio = não entra no mapa normal;
## ainda pode ser iniciado por um Evento que escolha este encontro.
@export var districts: Array[StringName] = []
@export var night_only: bool = false
## Marque apenas se este encontro puder acontecer uma vez em toda a campanha.
@export var unique_encounter: bool = false

@export_category("Composição")
## Exemplo: três entradas com 1 Goblin de cada tipo; ou duas entradas
## com as quantidades de Zumbi Dançarino e Zumbi que Taca Gosma.
@export var members: Array[EncounterMemberData] = []

@export_category("Sorteio")
@export_range(1, 999) var selection_weight: int = 1

@export_category("Tags")
@export var tags: Array[StringName] = []


func can_appear_in(district: StringName, is_night: bool) -> bool:
	return district in districts and (not night_only or is_night)


func has_valid_composition() -> bool:
	if members.is_empty():
		return false
	for member in members:
		if member == null or member.entity == null:
			return false
		if member.minimum < 1 or member.maximum < member.minimum:
			return false
	return true
