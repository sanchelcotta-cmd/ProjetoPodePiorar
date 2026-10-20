extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var expected := {
		"jornalista": [EntityData.Mastery.RANGED, 1, 1],
		"velha_fofoqueira": [EntityData.Mastery.IMPACT, 1, 1],
		"mae": [EntityData.Mastery.RANGED, 1, 1],
		"professora": [EntityData.Mastery.BLADE, 0, 2],
		"pedreiro": [EntityData.Mastery.IMPACT, 1, 2],
		"universitario": [EntityData.Mastery.NONE, 1, 1],
		"cozinheiro": [EntityData.Mastery.BLADE, 1, 1],
	}
	var ids := {}
	for name in expected:
		var data := load("res://resources/entities/entities_playable/%s.tres" % name) as EntityData
		check(data != null, "%s precisa carregar." % name)
		if data == null:
			continue
		check(not ids.has(data.id), "ID de personagem duplicado: %s" % data.id)
		ids[data.id] = true
		check(data.maestrias.size() == 1 and data.maestrias[0] == expected[name][0], "Maestria incorreta: %s" % name)
		check(data.skill_passivas.size() == expected[name][1], "Quantidade de Passivas incorreta: %s" % name)
		check(data.skill_ativas.size() == expected[name][2], "Quantidade de Ativas incorreta: %s" % name)
		check(data.equipamentos_iniciais.is_empty(), "Os itens indicados não são kit inicial fixo: %s" % name)
		var seen_paths := {}
		var all_skills: Array[Resource] = []
		for skill in data.skill_passivas:
			all_skills.append(skill)
		for skill in data.skill_ativas:
			all_skills.append(skill)
		for skill in all_skills:
			check(skill != null, "Skill inválida: %s" % name)
			if skill == null:
				continue
			check(not seen_paths.has(skill.resource_path), "Skill repetida no mesmo personagem: %s" % name)
			seen_paths[skill.resource_path] = true

	var cook := load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData
	var meal := cook.skill_ativas[0]
	check(meal.id == &"playable_active_009", "Marmita deve estar ligada ao Cozinheiro.")
	check(meal.use_context == ActiveSkillData.UseContext.EXPLORATION and meal.max_uses_per_round == 1, "Marmita só pode ser usada uma vez por Rodada na Exploração.")
	check(meal.effects.size() == 1 and meal.effects[0].effect_type == SkillEffectData.EffectType.GRANT_RANDOM_ITEM, "Marmita deve sortear um item.")
	check(&"comida" in meal.effects[0].tags_filter and &"raro" in meal.effects[0].excluded_tags, "Marmita deve excluir comidas Raras.")
	check(cook.skill_passivas[0].requires_melee_attack, "Tempero do Chef deve exigir ataque corpo a corpo.")
	var builder := load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData
	var wall := builder.skill_passivas[0]
	check(wall.trigger == PassiveSkillData.Trigger.ON_AFTER_DAMAGE_RECEIVED, "Paredão reage depois do dano sofrido.")
	check(wall.effects[0].stack_with_existing_effects, "Paredão acumula +2 por dano.")
	var student := load("res://resources/entities/entities_playable/universitario.tres") as EntityData
	var movement := student.skill_ativas[0]
	check(movement.max_uses_per_turn == 1 and movement.max_uses_per_round == 3, "Multitarefa Nervosa tem limite por turno e Rodada.")
	check(movement.effects.size() == 1 and movement.effects[0].effect_type == SkillEffectData.EffectType.GRANT_EXTRA_MOVEMENT, "Ativar Multitarefa concede o movimento extra.")
	check(movement.on_extra_movement_used_effects.size() == 1, "A penalidade só é programada para quando o movimento extra for usado.")
	for name in ["velha_fofoqueira", "mae", "pedreiro", "cozinheiro"]:
		var data := load("res://resources/entities/entities_playable/%s.tres" % name) as EntityData
		check(data.skill_passivas[0].activation_context == PassiveSkillData.ActivationContext.COMBAT, "Passiva de combate fora do modo: %s" % name)

	print("PLAYABLE_RESOURCES_TEST_OK" if failures == 0 else "PLAYABLE_RESOURCES_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
