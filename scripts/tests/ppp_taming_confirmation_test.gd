extends SceneTree

## O Adestramento recebido do Evento 68 só sorteia após SIM; sucesso
## converte a própria instância hostil durante o combate.
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://teste.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var combat := scene.get_node("CombatManager") as CombatManager
	var skills := scene.get_node("SkillManager") as SkillManager
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	combat.auto_start_turns = false
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/mae.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/jornalista.tres")]
	_check(gerencia.start_new_game(choices) and rounds.start_first_map(),
		"Campanha inicia.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(3, 2)
	var event := load("res://resources/events/permanent_effects/68-adestramento_bestial.tres") as EventData
	gerencia.campaign.current_map.set_ppp_block(actor.position,
		HexGrid.PPPBlockType.EVENT, event)
	_check(block.begin_activation(actor.position, actor), "Evento 68 abre a narrativa.")
	popup._confirm_event({})
	if popup._outcome_reading:
		popup._execute_prepared_event()
	_check(not block.is_busy(), "Evento 68 concede a Ativa e libera o bloco.")
	var grant: SkillGrantState
	for candidate in skills.get_active_grants(actor):
		if (candidate.skill as ActiveSkillData).id == &"permanent_active_068":
			grant = candidate
	_check(grant != null, "Adestramento aparece nas Ativas do personagem.")
	var encounter := load("res://resources/encounters/enc_zumbis_dancarinos_suburbio.tres") as EncounterData
	gerencia.campaign.current_map.set_ppp_block(Vector2i(4, 2),
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	actor.position = Vector2i(4, 2)
	_check(block.begin_activation(actor.position, actor), "Encontro inicia.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(not combat.enemies.is_empty(), "Inimigo surge no mapa.")
	if combat.enemies.is_empty() or grant == null:
		quit(1)
		return
	var target := combat.enemies[0]
	combat.current_actor = actor
	combat._combat_turns_by_id[actor.instance_id] = 1
	_check(skills.can_use_combat_active(actor, grant, gerencia.campaign,
		combat, target), "Alvo hostil é elegível para Adestramento.")
	hud._on_combat_context_skill(grant, target.position)
	_check(hud._tame_dialog.visible and target in combat.enemies \
		and grant.uses_in_last_combat == 0,
		"Clique abre SIM/NÃO sem sortear ou converter antecipadamente.")
	hud._cancel_taming()
	_check(target in combat.enemies and grant.uses_in_last_combat == 0,
		"NÃO preserva inimigo e tentativa.")
	var rival_skill := load(
		"res://resources/skills/actives/permanent_effects/declarar_arqui_inimigo.tres") as ActiveSkillData
	var rival_grant := skills.grant_skill(actor, rival_skill, &"event",
		&"rival_confirmation_test", gerencia.campaign)
	_check(combat.select_player_skill(rival_grant),
		"Botão do HUD prepara a escolha de Arqui-inimigo.")
	hud._on_combat_hex_choice(target.position)
	_check(hud._archenemy_dialog.visible and hud._archenemy_dialog.dialog_text == \
		"Declarar %s seu arqui-inimigo?" % target.visible_name(),
		"Arqui-inimigo pede confirmação com o nome da entidade.")
	hud._cancel_archenemy()
	_check(rival_grant in skills.get_active_grants(actor) and target in combat.enemies \
		and combat.action_mode == &"" and combat._selected_skill_grant == null,
		"NÃO não consome a Ativa nem declara o Arqui-inimigo.")
	hud._on_combat_context_skill(rival_grant, target.position)
	hud._archenemy_dialog.hide()
	hud._confirm_archenemy()
	_check(rival_grant not in skills.get_active_grants(actor) and \
		skills.get_passive_grants(actor).any(func(candidate: SkillGrantState) -> bool:
			return candidate.skill.id == &"permanent_passive_070_attack"),
		"SIM declara o tipo escolhido e instala a Passiva.")
	var effect := (grant.skill as ActiveSkillData).effects[0]
	_check(is_equal_approx(effect.activation_chance, 0.5),
		"Resource conserva chance real de 50%.")
	# Forçar os dois ramos nesta regressão, sem alterar o Resource salvo.
	effect.activation_chance = 0.0
	hud._on_combat_context_skill(grant, target.position)
	hud._confirm_taming()
	_check(target in combat.enemies and grant in skills.get_active_grants(actor) \
		and grant.uses_in_last_combat == 1 and hud._tame_result_dialog.visible \
		and hud._tame_result_dialog.dialog_text == "Não foi dessa vez.",
		"Falha mantém inimigo e Ativa, mas consome a tentativa neste combate.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	hud._on_tame_result_window_input(escape)
	_check(not hud._tame_result_dialog.visible,
		"ESC fecha o resultado sem alterar a tentativa realizada.")
	effect.activation_chance = 0.5
	_check(combat.request_victory() and combat.confirm_conclusion(),
		"Primeiro combate termina após a tentativa falha.")
	actor.position = Vector2i(5, 2)
	gerencia.campaign.current_map.set_ppp_block(actor.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	_check(block.begin_activation(actor.position, actor),
		"Um segundo Encontro começa para restaurar o uso da Ativa.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	_check(not combat.enemies.is_empty(), "Novo inimigo surge no segundo combate.")
	if combat.enemies.is_empty():
		quit(1)
		return
	target = combat.enemies[0]
	combat.current_actor = actor
	combat._combat_turns_by_id[actor.instance_id] = 1
	_check(skills.can_use_combat_active(actor, grant, gerencia.campaign,
		combat, target), "Falha anterior libera nova tentativa no próximo combate.")
	hud._on_combat_context_skill(grant, target.position)
	effect.activation_chance = 1.0
	hud._confirm_taming()
	_check(target not in combat.enemies and target in gerencia.campaign.companion_states \
		and hud._tame_result_dialog.visible and hud._tame_result_dialog.dialog_text == \
		"Você adestrou %s. Um novo pet entrou para o grupo!" % target.visible_name(),
		"SIM aplica a chance e, em sucesso, o inimigo vira aliado imediatamente.")
	effect.activation_chance = 0.5
	print("PPP taming confirmation: %d falha(s)" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
