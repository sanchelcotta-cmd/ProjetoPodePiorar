extends SceneTree

var failures := 0

func _initialize() -> void:
	var campaign := CampaignState.new()
	var catalog := campaign.get_playable_catalog()
	check(catalog.size() == 7, "O catálogo deve conter os sete jogáveis atuais.")
	var selected: Array[EntityData] = []
	selected.append(load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData)
	selected.append(load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData)
	selected.append(load("res://resources/entities/entities_playable/mae.tres") as EntityData)
	check(campaign.start_new_game(selected), "A seleção válida deve iniciar a campanha.")
	check(campaign.active_entity_states.size() == 3, "Precisam existir três estados.")
	var positions := [Vector2i(-1, 1), Vector2i(-1, 2), Vector2i(-1, 3)]
	for index in 3:
		var state := campaign.active_entity_states[index]
		check(state.data == selected[index], "O Resource deve estar na vaga selecionada.")
		check(state.instance_id == StringName("Playable_%d" % (index + 1)), "A vaga precisa de ID estável.")
		check(state.position == positions[index], "A vaga deve iniciar na StartZone.")
		check(state.current_health == state.max_health \
			and state.max_health >= selected[index].vida_base,
			"Vida inicial cheia, incluindo o equipável de início.")
		check(state.stamina_remaining == state.max_stamina \
			and state.max_stamina >= selected[index].stamina_base,
			"Estamina inicial cheia, incluindo o equipável de início.")
	check(campaign.get_unselected_playable_allies().size() == 4, "Quatro jogáveis devem ficar para Um Aliado.")
	var first := campaign.active_entity_states[0]
	first.current_health = 1
	check(selected[0].vida_base != 1, "Alterar EntityState não pode mudar o Resource.")
	var repeated: Array[EntityData] = [selected[0], selected[0], selected[2]]
	check(not campaign.start_new_game(repeated), "Não pode selecionar um personagem duas vezes.")
	check(campaign.active_entity_states[0] == first, "Seleção inválida não pode apagar a partida.")
	campaign.day = 5
	check(campaign.start_new_game(selected), "Uma nova partida válida deve reiniciar.")
	check(campaign.day == 1 and campaign.active_entity_states[0] != first, "Nova partida deve criar estados novos.")
	print("ENTITY_STATE_TEST_OK" if failures == 0 else "ENTITY_STATE_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
