extends SceneTree

# Confere os dois hostis sem Stamina fixa antes de ligar o executor de Combate.
func _initialize() -> void:
	var black_suit := load("res://resources/entities/entities_general/homem_de_preto.tres") as EntityData
	var mirror := load("res://resources/entities/entities_general/uma_versao_do_mal.tres") as EntityData
	var valid := black_suit != null and mirror != null
	if valid:
		var information_passive := black_suit.skill_passivas[1] as PassiveSkillData
		valid = information_passive != null \
			and information_passive.minimum_group_information_count == 1 \
			and information_passive.effects.size() == 2
		if valid:
			var attack_effect := information_passive.effects[0] as SkillEffectData
			var stamina_effect := information_passive.effects[1] as SkillEffectData
			valid = attack_effect != null and stamina_effect != null \
				and attack_effect.effect_type == SkillEffectData.EffectType.SET_ATTRIBUTE_FROM_GROUP_INFORMATION_COUNT \
				and stamina_effect.effect_type == attack_effect.effect_type \
				and attack_effect.attribute_id == &"attack" \
				and stamina_effect.attribute_id == &"stamina" \
				and attack_effect.context_caps == stamina_effect.context_caps
	if valid:
		var end_passive := black_suit.skill_passivas[2] as PassiveSkillData
		valid = end_passive != null \
			and end_passive.maximum_group_information_count == 0 \
			and end_passive.effects.size() == 1 \
			and end_passive.effects[0].effect_type == SkillEffectData.EffectType.END_COMBAT
	if valid:
		var copy_passive := mirror.skill_passivas[1] as PassiveSkillData
		valid = copy_passive != null and copy_passive.effects.size() == 1
		if valid:
			var copy_effect := copy_passive.effects[0] as SkillEffectData
			valid = copy_effect != null \
				and copy_effect.effect_type == SkillEffectData.EffectType.COPY_ATTRIBUTES_FROM_TARGET \
				and &"stamina" in copy_effect.attribute_ids
	if not valid:
		push_error("Hostis de atributos variáveis não representam sua Stamina dinâmica.")
	quit(0 if valid else 1)
