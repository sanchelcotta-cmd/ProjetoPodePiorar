extends SceneTree

## Testa os sete Resources, a exceção Hurt da Professora e o primeiro mapa.
var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1440, 810)
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() \
		as PlayableSelectionScreen
	root.add_child(selection)
	await process_frame
	await process_frame
	check(selection.cards.size() == 7, "A seleção mostra os sete personagens.")
	var grid := selection.get_node("Content/Stack/BodyScroll/Body/Carousel/CardsCenter/CardsGrid") \
		as GridContainer
	check(grid.columns == 7, "Os sete aparecem juntos sem navegação lateral.")
	for card in selection.cards:
		check(card.get_global_rect().position.x >= 0.0 \
			and card.get_global_rect().end.x <= selection.get_viewport_rect().size.x,
			"O cartão de %s não sai das margens." % card.character.display_name)
	for card in selection.cards:
		var animation := card.character.playable_animation
		check(animation != null, "%s tem Resource de animação." % card.character.display_name)
		if animation == null:
			continue
		var frames := animation.create_sprite_frames()
		check(frames.get_frame_count(&"idle") == 12 \
			and frames.get_frame_count(&"walk") == 8 \
			and frames.get_frame_count(&"hurt") == 6,
			"%s tem 12/8/6 quadros válidos." % card.character.display_name)
		check(card.character_visual.animated_sprite.animation == &"idle",
			"%s aparece animado em idle na seleção." % card.character.display_name)
		if card.character.display_name == "Professora do Primário":
			check(animation.hurt_columns == 3,
				"Hurt atualizado da Professora usa três colunas e seis quadros.")
			var fifth := frames.get_frame_texture(&"hurt", 4) as AtlasTexture
			var sixth := frames.get_frame_texture(&"hurt", 5) as AtlasTexture
			check(fifth.region.position == Vector2(64, 96) \
				and sixth.region.position == Vector2(128, 96),
				"Os dois últimos quadros da Professora vêm da segunda linha.")
	selection.cards[0].pressed.emit()
	var one_pick := selection._complete_party()
	check(one_pick.size() == 3 and one_pick[0] == selection.cards[0].character \
		and one_pick[0] != one_pick[1] and one_pick[1] != one_pick[2] \
		and one_pick[0] != one_pick[2],
		"Uma escolha mantém a primeira vaga e sorteia duas diferentes.")
	check(not selection.get_node("Content/Stack/Footer/FooterMargin/FooterRow/ConfirmSelection").disabled,
		"Uma escolha já habilita confirmar.")
	selection.cards[1].pressed.emit()
	var two_picks := selection._complete_party()
	check(two_picks.size() == 3 and two_picks[0] == selection.cards[0].character \
		and two_picks[1] == selection.cards[1].character \
		and two_picks[2] not in selection.selected,
		"Duas escolhas mantêm a ordem e sorteiam a terceira.")
	selection.cards[2].pressed.emit()
	check(selection.selected.size() == 3 \
		and not selection.get_node("Content/Stack/Footer/FooterMargin/FooterRow/ConfirmSelection").disabled,
		"Três escolhas distintas também habilitam confirmação.")
	check(selection._complete_party() == selection.selected,
		"Com três escolhas, não há sorteio adicional.")
	selection.cards[3].pressed.emit()
	check(selection.selected.size() == 3, "Uma quarta escolha não substitui ninguém.")
	selection.cards[1].pressed.emit()
	selection.cards[2].pressed.emit()
	var chosen_manually := selection.selected[0]
	selection._confirm_selection()
	for _frame in 40:
		if current_scene is CampaignPreGameSummary:
			break
		await process_frame
	var pregame := current_scene as Control
	check(pregame != null and
		(pregame.get_node("BlackBackground") as ColorRect).color == Color.BLACK,
		"Antes do primeiro mapa, uma cena própria revisa a campanha.")
	var early_game := false
	for child in root.get_children():
		early_game = early_game or child is PPPMapView
	check(not early_game, "A confirmação não instancia o mapa por trás da tela preta.")
	if pregame != null:
		(pregame.get_node("Center/Summary/Start") as Button).pressed.emit()
	for _frame in 40:
		if current_scene is PPPMapView:
			break
		await process_frame
	var game := current_scene as PPPMapView
	check(game != null, "Confirmar abre a cena do mapa.")
	if game != null:
		var exploration := game.get_node("ExplorationManager") as ExplorationManager
		check(exploration.current_actor != null,
			"A cena do jogo inicia a Exploração normal.")
		var campaign := (game.get_node("GerenciaJogo") as GerenciaJogo).campaign
		var party := game.get_node("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
		check(party.get_parent().y_sort_enabled and party.y_sort_enabled,
			"Personagens ficam na camada que ordena todos os visuais pelo pé.")
		check(campaign.current_map != null and campaign.active_entity_states.size() == 3,
			"O primeiro mapa é gerado com três vagas ativas.")
		check(party.visuals_by_slot.size() == 3,
			"O mapa desenha Playable_1/2/3 nas posições iniciais.")
		check(campaign.active_entity_states[0].data == chosen_manually,
			"A escolha manual ocupa Playable_1 na campanha iniciada.")
		check(campaign.active_entity_states[0].data != campaign.active_entity_states[1].data \
			and campaign.active_entity_states[0].data != campaign.active_entity_states[2].data \
			and campaign.active_entity_states[1].data != campaign.active_entity_states[2].data,
			"As duas vagas sorteadas não repetem personagens.")
		for index in 3:
			var state := campaign.active_entity_states[index]
			var actor := party.visuals_by_slot.get(state.playable_slot_id) as PlayableActorVisual
			check(actor != null \
				and actor.position == PPPMapView.reference_hex_position(state.position),
				"A vaga %d usa a escolha e a StartZone corretas." % (index + 1))
			check(actor != null and actor.get_parent() == party and actor.z_index == 0,
				"Cada personagem participa da mesma ordenação vertical do mundo.")
		var first := campaign.active_entity_states[0]
		var first_actor := party.visuals_by_slot.get(first.playable_slot_id) as PlayableActorVisual
		var second_actor := party.visuals_by_slot.get(&"Playable_2") as PlayableActorVisual
		var saved_second_position := second_actor.position
		var path_end := PPPMapView.reference_hex_position(Vector2i(0, first.position.y))
		second_actor.position = first_actor.position.lerp(path_end, 0.5)
		var detour := first_actor._visual_detour(first_actor.position, path_end)
		check(detour != Vector2.INF and absf(detour.y - first_actor.position.y) >= 30.0,
			"O trajeto visual desvia de uma entidade cruzada sem mudar o caminho lógico.")
		second_actor.position = saved_second_position
		first.current_health -= 1
		await process_frame
		check(first_actor.animated_sprite.animation == &"hurt",
			"Perder Vida dispara Hurt no personagem correto.")
		var next_hex := Vector2i(0, first.position.y)
		var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
		campaign.current_map.set_ppp_block(next_hex, HexGrid.PPPBlockType.INFORMATION,
			information)
		check(exploration.try_move(next_hex), "Movimento real deve iniciar caminhada visual.")
		check(first_actor.animated_sprite.animation == &"walk",
			"Movimento dispara Walk.")
		var information_popup := game.get_node("BlockActivationPopup") as BlockActivationPopup
		check(not information_popup.overlay.visible and exploration.current_actor == first,
			"A caixa da Informação espera a chegada visual ao hex.")
		await first_actor.walk_finished
		check(not information_popup.overlay.visible,
			"A caixa ainda aguarda a pausa breve após a caminhada.")
		await create_timer(0.55).timeout
		check(information_popup.overlay.visible,
			"Após a chegada e a pausa, a Informação aguarda confirmação.")
		information_popup._confirm_information()
		check(exploration.current_actor.playable_slot_id == &"Playable_2",
			"A Informação resolvida encerra o turno e sugere a vaga seguinte.")
		await create_timer(0.25).timeout
		check(first_actor.position == PPPMapView.reference_hex_position(next_hex) \
			and first_actor.animated_sprite.animation == &"idle",
			"Ao chegar no hex, o personagem volta ao Idle.")
		check(campaign.current_map.get_cell(next_hex).state == HexGrid.PPPBlockState.ACTIVATED,
			"A caminhada normal ativa o bloco de destino.")
		var start_marker := game.get_node_or_null("MapRoot/StartZone/Start_%d" % next_hex.y)
		check(start_marker == null or not start_marker.visible,
			"O hex inicial desaparece quando seu personagem sai dele.")
	if failures == 0:
		print("PLAYABLE_SELECTION_TEST_OK")
	else:
		push_error("PLAYABLE_SELECTION_TEST: %d falha(s)" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
