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
	_check(campaign.active_ending_ids == CampaignState.ALL_ENDING_IDS
		and campaign.information_goal() == CampaignState.ALL_ENDING_IDS.size()
			* CampaignState.INFORMATION_PER_ENDING,
		"Completa guarda todos os desfechos cadastrados e a meta proporcional.")
	var original_endings := campaign.active_ending_ids.duplicate()
	campaign.active_ending_ids.append(&"desfecho_futuro_teste")
	_check(campaign.information_goal() ==
		(campaign.active_ending_ids.size() * CampaignState.INFORMATION_PER_ENDING),
		"A meta da Completa acompanha um desfecho adicional sem número fixo.")
	campaign.active_ending_ids = original_endings
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
		"Completa não aceita escolha manual: ativa o catálogo inteiro automaticamente.")
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
		"Sorteio é sem reposição e usa apenas desfechos cadastrados.")
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
	_check(occurrences.size() == CampaignState.ALL_ENDING_IDS.size(),
		"Cada desfecho participa do mesmo sorteio uniforme.")
	var expected := 400.0 / float(CampaignState.ALL_ENDING_IDS.size())
	for ending_id in CampaignState.ALL_ENDING_IDS:
		_check(float(occurrences.get(ending_id, 0)) >= expected * 0.6
			and float(occurrences.get(ending_id, 0)) <= expected * 1.4,
			"Sorteio uniforme não favorece %s na amostra fixa." % ending_id)

	var narrow_viewport := SubViewport.new()
	narrow_viewport.size = Vector2i(800, 600)
	root.add_child(narrow_viewport)
	var selection := SELECTION_SCENE.instantiate() as PlayableSelectionScreen
	narrow_viewport.add_child(selection)
	await process_frame
	await process_frame
	var mode_path := "Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/ModeBlock/CampaignModes"
	var ending_path := "Content/Stack/BodyScroll/Body/CampaignPanel/CampaignMargin/CampaignStack/CampaignTop/EndingSetup"
	var modes := selection.get_node(mode_path) as VBoxContainer
	var endings := selection.get_node(ending_path) as VBoxContainer
	var cards := selection.get_node("Content/Stack/BodyScroll/Body/Carousel") as HBoxContainer
	var body_scroll := selection.get_node("Content/Stack/BodyScroll") as ScrollContainer
	var confirm := selection.get_node("Content/Stack/Footer/FooterMargin/FooterRow/ConfirmSelection") as Button
	_check(not endings.visible, "Completa oculta a linha de desfechos.")
	_check(not modes.get_global_rect().intersects(cards.get_global_rect())
		and not modes.get_global_rect().intersects(confirm.get_global_rect()),
		"Modo não cobre cartões nem confirmação.")
	selection.get_node(mode_path + "/Short").pressed.emit()
	await process_frame
	_check(endings.visible and not endings.get_global_rect().intersects(
		cards.get_global_rect()) and not endings.get_global_rect().intersects(
		confirm.get_global_rect()),
		"Na curta, a linha de desfechos não cobre outras áreas clicáveis.")
	_check(body_scroll.size.y >= 80.0
		and confirm.get_global_rect().end.y <= narrow_viewport.size.y,
		"Conteúdo continua rolável e confirmação cabe na janela estreita.")
	var children := endings.get_node("EndingRow/Choices").get_children()
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
	selection.get_node(ending_path + "/EndingRow/Choices/Orchestra").pressed.emit()
	_check(not confirm.disabled, "Escolha manual única habilita campanha curta.")
	selection.get_node(mode_path + "/Medium").pressed.emit()
	_check(endings.visible and not confirm.disabled,
		"Média oferece sorteio sem exigir seleção manual.")
	selection.get_node(ending_path + "/EndingRow/Choices/Orchestra").pressed.emit()
	_check(confirm.disabled, "Uma escolha manual não basta para campanha média.")
	selection.get_node(ending_path + "/EndingRow/Choices/Khainokata").pressed.emit()
	_check(not confirm.disabled, "Duas escolhas manuais habilitam campanha média.")
	selection.get_node(mode_path + "/Complete").pressed.emit()
	_check(not endings.visible and not confirm.disabled,
		"Completa oculta escolhas e continua pronta para iniciar.")
	selection.get_node(mode_path + "/Short").pressed.emit()
	selection.get_node(ending_path + "/EndingRow/Choices/Orchestra").pressed.emit()
	selection._confirm_selection()
	for _frame in 40:
		if current_scene is CampaignPreGameSummary:
			break
		await process_frame
	var pregame := current_scene as Control
	_check(pregame != null and
		(pregame.get_node("BlackBackground") as ColorRect).color == Color.BLACK,
		"Cena intermediária própria fica preta antes do primeiro mapa.")
	_check(pregame.get_node_or_null("Center/Summary/Artwork") is TextureRect,
		"A cena pré-jogo reserva um espaço central para a futura imagem.")
	var start_button := pregame.get_node("Center/Summary/Start") as Button
	_check(start_button.text == "OK" and
		pregame.get_node_or_null("Center/Summary/Characters") is Label,
		"Cena intermediária mostra campanha e personagens com um único OK.")
	var pending := pregame.get("prepared_campaign") as CampaignState
	_check(pending.campaign_mode == EventCampaignEligibility.Mode.SHORT
		and pending.active_ending_ids == manual_short,
		"Cena intermediária preserva o único sorteio e a escolha de desfecho.")
	start_button.pressed.emit()
	for _frame in 40:
		if current_scene is PPPMapView:
			break
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
