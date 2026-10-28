extends Node

## Preferência visual global, independente de campanha, paleta, vídeo e escala.
## Novos efeitos devem consultar este serviço e oferecer uma variante estática
## ou de baixa intensidade; nunca alterar regras, duração lógica ou RNG de jogo.
signal changed(enabled: bool)

const CONFIG_PATH := "user://ppp_visual_comfort.cfg"
const MAX_DECORATIVE_LIGHT_ENERGY := 0.025
const MAX_DECORATIVE_SHADOW_ALPHA := 0.32
const MAX_PARTICLE_ALPHA := 0.22
const PARTICLE_DENSITY_FACTOR := 0.35

var enabled := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		enabled = bool(config.get_value("accessibility", "reduce_flashes_motion", false))


func set_enabled(value: bool, persist: bool = true) -> bool:
	if enabled != value:
		enabled = value
		changed.emit(enabled)
	if not persist:
		return true
	var config := ConfigFile.new()
	config.set_value("accessibility", "reduce_flashes_motion", enabled)
	return config.save(CONFIG_PATH) == OK


func cap_light_energy(value: float) -> float:
	return minf(value, MAX_DECORATIVE_LIGHT_ENERGY) if enabled else value


func cap_shadow_alpha(value: float) -> float:
	return minf(value, MAX_DECORATIVE_SHADOW_ALPHA) if enabled else value


func cap_particle_alpha(value: float) -> float:
	return minf(value, MAX_PARTICLE_ALPHA) if enabled else value


func particle_density_factor() -> float:
	return PARTICLE_DENSITY_FACTOR if enabled else 1.0
