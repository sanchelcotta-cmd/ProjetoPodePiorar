class_name CatastropheVisualProfile
extends Resource

## Arte opcional de UMA catástrofe. Sem perfil, a regra de jogo funciona
## normalmente. A cena pode conter AnimatedSprite2D e/ou AnimationPlayer.
@export var event_id: StringName
@export var animation_scene: PackedScene
@export var animation_name: StringName = &"default"
# Camada opcional sobre o mundo (não sobre HUD); alfa zero a deixa desligada.
@export var filter_color: Color = Color.TRANSPARENT
