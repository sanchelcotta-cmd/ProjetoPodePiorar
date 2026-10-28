extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var manager := SkillManager.new()
	root.add_child(manager)
	var experience := load("res://resources/entities/entities_general/a_experiencia.tres") as EntityData
	for passive in experience.skill_passivas:
		check(not manager._passive_has_dodge(passive),
			"A Experiência não possui Esquiva inata.")
	check(not experience.tags.has(&"esquiva_30") and not experience.tags.has(&"esquiva_60"),
		"A Experiência não anuncia Esquiva por tag.")

	var dodge_30 := load("res://resources/skills/passives/esquiva_30.tres") as PassiveSkillData
	var dodge_60 := load("res://resources/skills/passives/esquiva_60.tres") as PassiveSkillData
	var lower := SkillGrantState.new(dodge_30, &"test", &"lower")
	var higher := SkillGrantState.new(dodge_60, &"test", &"higher")
	var grants: Array[SkillGrantState] = [lower, higher]
	var hostile := EntityState.new()
	hostile.controller = EntityState.Controller.AI
	var trigger := PassiveSkillData.Trigger.ON_BEFORE_DAMAGE_RECEIVED
	var preferred := manager._preferred_hostile_dodge(hostile, trigger, grants)
	check(preferred == higher, "O hostil escolhe somente a fonte de Esquiva mais forte.")
	check(is_equal_approx(manager._effective_passive_chance(hostile, trigger, higher,
		preferred), 0.30), "Mesmo com fonte de 60%, o hostil tem teto de 30% por golpe.")
	check(is_zero_approx(manager._effective_passive_chance(hostile, trigger, lower,
		preferred)), "Outra fonte de Esquiva não faz uma segunda tentativa.")

	var playable := EntityState.new()
	playable.controller = EntityState.Controller.PLAYER
	check(manager._preferred_hostile_dodge(playable, trigger, grants) == null,
		"O limite de inimigo não seleciona fonte para personagens do grupo.")
	check(is_equal_approx(manager._effective_passive_chance(playable, trigger, higher,
		null), 0.60), "Item ou habilidade de jogável conserva 60%.")
	check(is_equal_approx(dodge_60.activation_chance, 0.60),
		"Resource compartilhado não foi modificado.")

	print("ENEMY_DODGE_CAP_TEST_OK" if failures == 0 else \
		"ENEMY_DODGE_CAP_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
