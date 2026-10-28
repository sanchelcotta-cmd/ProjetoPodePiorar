class_name HexPalette
extends Resource

## Cores visuais, sem regras de jogo. Podem ser ajustadas no Inspector
## futuramente sem mudar estados, alcance ou conteúdo dos blocos.
@export var default_color: Color = Color("#EBF2F5")
@export var reachable_color: Color = Color("#FFD459")
@export var selected_color: Color = Color("#38D9F0")
@export var revealed_color: Color = Color("#FF66B0")
@export var temporary_inspection_color: Color = Color("#FF646E")
@export var inactive_color: Color = Color(0.44, 0.51, 0.55, 0.60)
@export var active_color: Color = Color("#FFEB7A")


func apply_ui_palette(palette_id: String) -> void:
	match palette_id:
		"azul":
			default_color = Color.WHITE
			reachable_color = Color("#83B9FF")
			selected_color = Color("#386BFF")
			revealed_color = Color("#6550FF")
			temporary_inspection_color = Color("#A78BFA")
			inactive_color = Color("#72839C", 0.60)
			active_color = Color("#83E6FF")
		"rosa_branco":
			default_color = Color.WHITE
			reachable_color = Color("#E84B9D")
			selected_color = Color("#FFD36B")
			revealed_color = Color("#6550FF")
			temporary_inspection_color = Color("#A78BFA")
			inactive_color = Color("#8A9DA6", 0.60)
			active_color = Color("#F3A0CB")
		"acessivel":
			default_color = Color("#F5FAFC")
			reachable_color = Color("#51D6B1")
			selected_color = Color("#F3A0CB")
			revealed_color = Color("#67C6EF")
			temporary_inspection_color = Color("#FFD36B")
			inactive_color = Color("#8A9DA6", 0.60)
			active_color = Color("#F5FAFC")
		_:
			default_color = Color("#EBF2F5")
			reachable_color = Color("#FFD459")
			selected_color = Color("#38D9F0")
			revealed_color = Color("#FF66B0")
			temporary_inspection_color = Color("#FF646E")
			inactive_color = Color("#70838B", 0.60)
			active_color = Color("#FFEB7A")
