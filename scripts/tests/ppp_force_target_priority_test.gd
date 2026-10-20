extends SceneTree

# Garante que a Bonequinha de Pano declare a prioridade para a futura IA hostil.
func _initialize() -> void:
	var curse := load("res://resources/itens/curseds/bonequinha_de_pano.tres") as ItemData
	var valid := curse != null
	if valid:
		valid = curse.granted_passives.size() == 1
	if valid:
		var passive := curse.granted_passives[0] as PassiveSkillData
		valid = passive != null and passive.continuous_effects.size() == 1
		if valid:
			var priority := passive.continuous_effects[0] as SkillEffectData
			valid = priority != null \
				and priority.effect_type == SkillEffectData.EffectType.FORCE_TARGET_PRIORITY \
				and priority.target == SkillEffectData.Target.SELF \
				and priority.amount == 5000 \
				and priority.effect_lifetime == SkillEffectData.EffectLifetime.WHILE_CARRIED
	if not valid:
		push_error("Bonequinha de Pano deve conceder Prioridade Forçada +5000 enquanto carregada.")
	quit(0 if valid else 1)
