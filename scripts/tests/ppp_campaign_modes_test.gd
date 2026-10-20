extends SceneTree

const SELECTION_SCENE := preload("res://scenes/ui/playable_selection.tscn")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	var campaign := CampaignState.new()
	_check(campaign.start_new_game(selected), "Completa inicia com configuração padrão.")
	_check(campaign.information_goal() == 20
		and campaign.active_ending_ids.size() == 4,
		"Completa guarda os quatro desfechos e meta 20.")
	var original_id := campaign.campaign_id
	var duplicate: Array[StringName] = [&"orchestra", &"orchestra"]
	_check(not campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.MEDIUM, duplicate)
		and campaign.campaign_id == original_id,
		"Seleção repetida é rejeitada sem apagar a campanha existente.")
	var incomplete: Array[StringName] = [&"orchestra"]
	_check(not campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.MEDIUM, incomplete)
		and campaign.campaign_id == original_id,
		"Média exige exatamente dois desfechos.")
	var unknown: Array[StringName] = [&"outro"]
	_check(not campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.SHORT, unknown)
		and campaign.campaign_id == original_id,
		"ID não cadastrado é rejeitado.")
	_check(not campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.SHORT, duplicate)
		and campaign.campaign_id == original_id,
		"Curta não aceita dois desfechos.")
	_check(not campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.COMPLETE, incomplete)
		and campaign.campaign_id == original_id,
		"Completa não aceita escolha manual: ativa os quatro automaticamente.")
	_check(not campaign.start_new_game(selected, 12, null, 99)
		and campaign.campaign_id == original_id, "Modo desconhecido é rejeitado.")
	var manual_short: Array[StringName] = [&"orchestra"]
	_check(campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.SHORT, manual_short)
		and campaign.active_ending_ids == manual_short
		and campaign.information_goal() == 5,
		"Curta manual guarda exatamente um desfecho e meta 5.")
	var manual_medium: Array[StringName] = [&"khainokata", &"controle_da_mente"]
	_check(campaign.start_new_game(selected, 12, null,
		EventCampaignEligibility.Mode.MEDIUM, manual_medium)
		and campaign.active_ending_ids == manual_medium
		and campaign.information_goal() == 10,
		"Média manual guarda dois distintos e meta 10.")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	_check(campaign.start_new_game(selected, 12, rng,
		EventCampaignEligibility.Mode.MEDIUM),
		"Média pode sortear dois desfechos.")
	var rolled := campaign.active_ending_ids.duplicate()
	_check(rolled.size() == 2 and rolled[0] != rolled[1]
		and rolled[0] in CampaignState.ALL_ENDING_IDS
		and rolled[1] in CampaignState.ALL_ENDING_IDS,
		"Sorteio é sem reposição e usa apenas os quatro desfechos.")
	campaign.day = 2
	_check(campaign.active_ending_ids == rolled,
		"Avançar a campanha não refaz o sorteio.")
	var rng_again := RandomNumberGenerator.new()
	rng_again.seed = 12345
	var another := CampaignState.new()
	_check(another.start_new_game(selected, 12, rng_again,
		EventCampaignEligibility.Mode.MEDIUM)
		and another.active_ending_ids == rolled,
		"Seed igual reproduz o sorteio inicial para testes.")
	var occurrences: Dictionary = {}
	var sample_rng := RandomNumberGenerator.new()
	sample_rng.seed = 7654321
	for index in 400:
		var result := campaign._resolve_active_endings(
			EventCampaignEligibility.Mode.SHORT, [], sample_rng)
		occurrences[result[0]] = int(occurrences.get(result[0], 0)) + 1
	_check(occurrences.size() == 4,
		"Cada desfecho participa do mesmo sorteio uniforme.")
	for ending_id in CampaignState.ALL_ENDING_IDS:
		_check(int(occurrences.get(ending_id, 0)) in range(60, 141),
			"Sorteio uniforme não favorece %s na amostra fixa." % ending_id)

	var narrow_viewport := SubViewport.new()
	narrow_viewport.size = Vector2i(800, 600)
	root.add_child(narrow_viewport)
	var selection := SELECTION_SCENE.instantiate() as PlayableSelectionScreen
	narrow_viewport.add_child(selection)
	await process_frame
	await process_frame
	var modes := selection.get_node("Content/Stack/CampaignModes") as GridContainer
	var endings := selection.get_node("Content/Stack/EndingSetup") as VBoxContainer
	var cards := selection.get_node("Content/Stack/CardsScroll") as ScrollContainer
	var confirm := selection.get_node("Content/Stack/ConfirmSelection") as Button
	_check(not endings.visible, "Completa oculta a linha de desfechos.")
	_check(not modes.get_global_rect().intersects(cards.get_global_rect())
		and not modes.get_global_rect().intersects(confirm.get_global_rect()),
		"Modo não cobre cartões nem confirmação.")
	selection.get_node("Content/Stack/CampaignModes/Short").pressed.emit()
	await process_frame
	_check(endings.visible and not endings.get_global_rect().intersects(
		cards.get_global_rect()) and not endings.get_global_rect().intersects(
		confirm.get_global_rect()),
		"Na curta, a linha de desfechos não cobre outras áreas clicáveis.")
	_check(cards.size.y >= 80.0
		and confirm.get_global_rect().end.y <= narrow_viewport.size.y,
		"Cartões continuam roláveis e confirmação cabe na janela estreita.")
	var children := endings.get_node("Choices").get_children()
	for first in children.size():
		var button := children[first] as Button
		_check(button.get_global_rect().position.x >= 0
			and button.get_global_rect().end.x <= narrow_viewport.size.x,
			"Botão %s cabe na janela estreita (%s; largura %d)." % [
				button.name, button.get_global_rect(), narrow_viewport.size.x])
		for second in range(first + 1, children.size()):
			_check(not button.get_global_rect().intersects(
				(children[second] as Button).get_global_rect()),
				"Botões de desfecho não compartilham área de clique.")
	selection.cards[0].pressed.emit()
	_check(not confirm.disabled, "Sortear permite iniciar com um personagem escolhido.")
	selection.get_node("Content/Stack/EndingSetup/Choices/Orchestra").pressed.emit()
	_check(not confirm.disabled, "Escolha manual única habilita campanha curta.")
	selection.get_node("Content/Stack/CampaignModes/Medium").pressed.emit()
	_check(endings.visible and not confirm.disabled,
		"Média oferece sorteio sem exigir seleção manual.")
	selection.get_node("Content/Stack/EndingSetup/Choices/Orchestra").pressed.emit()
	_check(confirm.disabled, "Uma escolha manual não basta para campanha média.")
	selection.get_node("Content/Stack/EndingSetup/Choices/Khainokata").pressed.emit()
	_check(not confirm.disabled, "Duas escolhas manuais habilitam campanha média.")
	selection.get_node("Content/Stack/CampaignModes/Complete").pressed.emit()
	_check(not endings.visible and not confirm.disabled,
		"Completa oculta escolhas e continua pronta para iniciar.")
	selection.get_node("Content/Stack/CampaignModes/Short").pressed.emit()
	selection.get_node("Content/Stack/EndingSetup/Choices/Orchestra").pressed.emit()
	selection._confirm_selection()
	await process_frame
	var pregame := selection.get_node("PreGameSummary") as ColorRect
	_check(pregame.visible and pregame.color == Color(0.008, 0.008, 0.012, 1),
		"Seleção mostra revisão preta antes de abrir o mapa.")
	var pregame_actions := selection.get_node(
		"PreGameSummary/Center/Details/Actions") as HBoxContainer
	var back_button := pregame_actions.get_node("Back") as Button
	var start_button := pregame_actions.get_node("Start") as Button
	_check(pregame.get_global_rect().size == Vector2(narrow_viewport.size)
		and not back_button.get_global_rect().intersects(start_button.get_global_rect())
		and start_button.get_global_rect().end.y <= narrow_viewport.size.y,
		"Revisão cobre a seleção e mantém os dois alvos de clique separados.")
	_check((selection.get_node("PreGameSummary/Center/Details/Mode") as Label).text
		== "Curta · Meta: 5 Informações"
		and "Orchestra" in (selection.get_node(
			"PreGameSummary/Center/Details/Endings") as Label).text,
		"Resumo apresenta modo, meta e desfecho da campanha real.")
	var pending := selection._pending_game
	back_button.pressed.emit()
	_check(not pregame.visible, "Voltar mantém a seleção acessível.")
	selection._confirm_selection()
	_check(selection._pending_game == pending and pregame.visible,
		"Reabrir o resumo não refaz campanha nem sorteios.")
	start_button.pressed.emit()
	await process_frame
	var game := current_scene as PPPMapView
	_check(game != null, "A seleção abre o mapa.")
	if game != null:
		var actual := (game.get_node("GerenciaJogo") as GerenciaJogo).campaign
		_check(actual.campaign_mode == EventCampaignEligibility.Mode.SHORT
			and actual.active_ending_ids == manual_short
			and actual.information_goal() == 5,
			"Modo e desfecho escolhidos chegam à campanha real.")
	print("CAMPAIGN_MODES_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
