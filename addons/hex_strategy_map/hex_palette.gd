class_name HexPalette
extends Resource

## Cores visuais, sem regras de jogo. Podem ser ajustadas no Inspector
## futuramente sem mudar estados, alcance ou conteúdo dos blocos.
@export var default_color: Color = Color.WHITE
@export var reachable_color: Color = Color(1.0, 0.78, 0.25, 1.0)
@export var selected_color: Color = Color(0.18, 0.90, 1.0, 1.0)
@export var revealed_color: Color = Color(1.0, 0.40, 0.72, 1.0)
@export var temporary_inspection_color: Color = Color(1.0, 0.15, 0.22, 1.0)
@export var inactive_color: Color = Color(0.22, 0.24, 0.27, 0.60)
@export var active_color: Color = Color(1.0, 0.92, 0.48, 1.0)
