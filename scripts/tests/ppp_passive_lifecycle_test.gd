extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var campaign := CampaignState.new()
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/universitario.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
	]
	check(campaign.start_new_game(selected), "Campanha deve iniciar.")
	var journalist := campaign.active_entity_states[0]
	var student := campaign.active_entity_states[1]
	var manager := SkillManager.new()
	root.add_child(manager)
	var eyes := load("res://resources/skills/passives/permanent_effects/olhos_bionicos.tres") as PassiveSkillData
	check(manager.grant_skill(journalist, eyes, &"event", &"eyes", campaign) != null,
		"Olhos Biônicos é concedido pelo mesmo gerenciador.")
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 1,
		"Maestria Distância existente recebe +1.")
	check(manager.ignores_attack_range(journalist, EntityData.Mastery.RANGED),
		"Efeito contínuo de alcance fica consultável.")
	check(manager.remove_source(journalist, &"event", &"eyes") == 1,
		"Remover origem retira a concessão.")
	check(journalist.get_mastery_level(EntityData.Mastery.RANGED) == 0 \
		and not manager.ignores_attack_range(journalist, EntityData.Mastery.RANGED),
		"Número e regra contínua são removidos juntos.")
	check(manager.grant_skill(student, eyes, &"event", &"eyes", campaign) != null,
		"Olhos Biônicos também pode conceder Maestria nova.")
	check(student.has_mastery(EntityData.Mastery.RANGED) \
		and student.get_mastery_level(EntityData.Mastery.RANGED) == 0,
		"Maestria nova começa no nível 0.")
	manager.remove_source(student, &"event", &"eyes")
	check(not student.has_mastery(EntityData.Mastery.RANGED),
		"Ao perder a fonte, perde a Maestria nova.")

	var third_arm := load("res://resources/skills/passives/permanent_effects/protese_do_terceiro_braco.tres") as PassiveSkillData
	check(manager.grant_skill(student, third_arm, &"event", &"arm", campaign) != null,
		"Prótese registra sua regra contínua.")
	check(student.equipment_slot_capacity(&"weapon") == 2,
		"Prótese permite dois slots de arma.")
	manager.remove_source(student, &"event", &"arm")
	check(student.equipment_slot_capacity(&"weapon") == 1,
		"Remover a Prótese desfaz somente seu slot adicional.")

	var curse := load("res://resources/skills/passives/curses/agulha_de_costura.tres") as PassiveSkillData
	var epic := load("res://resources/itens/equipments/armas/arma_epica_espada_irada_flamejante.tres") as ItemData
	check(manager.grant_skill(student, curse, &"item", &"needle", campaign) != null,
		"Maldição contínua pode ser registrada.")
	check(not manager.can_equip_item(student, epic), "Agulha impede Épicos.")
	manager.remove_source(student, &"item", &"needle")
	check(manager.can_equip_item(student, epic), "Remover Agulha libera Épicos novamente.")

	var mutation := load("res://resources/skills/passives/permanent_effects/mutacao_genetica.tres") as PassiveSkillData
	var enemy := load("res://resources/entities/entities_general/barata_voadora.tres") as EntityData
	check(manager.grant_skill(student, mutation, &"event", &"mutation", campaign) == null,
		"Mutação sem inimigo escolhido não finge funcionar.")
	var hp_before := student.max_health
	var attack_before := student.attack
	check(manager.grant_skill(student, mutation, &"event", &"mutation", campaign, enemy) != null,
		"Mutação copia um EntityData escolhido.")
	check(student.max_health == hp_before + enemy.vida_base \
		and student.attack == attack_before + enemy.ataque_base,
		"Valores-base são somados sem aumentar a Vida atual.")
	check(student.skill_grants.size() > 2,
		"Passivas copiadas ficam ligadas à origem da Mutação.")
	manager.remove_source(student, &"event", &"mutation")
	check(student.max_health == hp_before and student.attack == attack_before,
		"Remover Mutação desfaz somente seus bônus.")
	for grant in student.skill_grants:
		check(grant.source_kind != &"copied_trait", "Passivas copiadas também são removidas.")

	var symbiosis := load("res://resources/skills/passives/permanent_effects/simbiose_elemental.tres") as PassiveSkillData
	var weapon := load("res://resources/itens/equipments/armas/arma_epica_espada_irada_flamejante.tres") as ItemData
	var mastery_before := student.get_mastery_level(weapon.mastery_granted)
	check(manager.grant_skill(student, symbiosis, &"event", &"symbiosis", campaign, weapon) != null,
		"Simbiose aceita a arma Épica escolhida como fonte.")
	check(student.attack == attack_before + weapon.bonus_attack \
		and student.max_health == hp_before + weapon.bonus_life,
		"Bônus da arma são preservados sem curar Vida atual.")
	check(student.get_mastery_level(weapon.mastery_granted) == mastery_before + weapon.mastery_bonus,
		"Maestria numérica da arma é copiada.")
	manager.remove_source(student, &"event", &"symbiosis")
	check(student.attack == attack_before and student.max_health == hp_before,
		"Remover origem da Simbiose desfaz seus bônus.")

	print("PASSIVE_LIFECYCLE_TEST_OK" if failures == 0 else "PASSIVE_LIFECYCLE_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
