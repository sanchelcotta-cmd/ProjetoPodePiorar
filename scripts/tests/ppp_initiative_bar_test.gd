extends SceneTree

## Verifica a apresentação da iniciativa sem depender da arte final dos hostis.
const BAR_SCRIPT := preload("res://scripts/ui/initiative_turn_bar.gd")

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1656, 932)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var rounds := scene.get_node("RoundManager") as RoundManager
	var block := scene.get_node("BlockManager") as BlockManager
	var combat := scene.get_node("CombatManager") as CombatManager
	var popup := scene.get_node("BlockActivationPopup") as BlockActivationPopup
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	var bar := scene.get_node("InitiativeTurnBar") as BAR_SCRIPT
	combat.auto_start_turns = false
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/pedreiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/mae.tres") as EntityData,
	]
	check(gerencia.start_new_game(selected) and rounds.start_first_map(),
		"A campanha inicia para testar a fila.")
	var actor := gerencia.campaign.active_entity_states[0]
	actor.position = Vector2i(3, 2)
	gerencia.campaign.obtained_information_ids[&"ui_test_info"] = true
	var encounter := load("res://resources/encounters/enc_homens_de_preto_suburbio.tres") as EncounterData
	gerencia.campaign.current_map.set_ppp_block(actor.position,
		HexGrid.PPPBlockType.ENCOUNTER, encounter)
	check(block.begin_activation(actor.position, actor), "O encontro abre.")
	(popup.buttons.get_child(0) as Button).pressed.emit()
	check(bar._root.visible and bar._participants.size() == combat.initiative_order.size(),
		"A fila aparece somente no Combate e espelha a iniciativa.")
	for index in bar._participants.size():
		check(bar._participants[index] == combat.initiative_order[index]["entity"],
			"Posição %d mantém a ordem real de iniciativa." % index)
	check(bar._cards.size() == bar._participants.size(),
		"Sem excesso, todos os quadros aparecem e as setas não são necessárias.")
	var enemy := combat.enemies[0]
	var enemy_card: Control
	for info in bar._cards:
		if info["actor"] == enemy:
			enemy_card = (info["frame"] as TextureRect).get_parent() as Control
			check((info["frame"] as TextureRect).size.y <= 90.0,
				"A moldura não pode esticar até o chão da cena.")
			check((info["portrait"] as TextureRect).texture != null,
				"Hostil sem sprite usa retrato provisório.")
			check(((info["frame"] as TextureRect).material as ShaderMaterial)
				.get_shader_parameter("accent") == bar.ENEMY_COLOR,
				"Moldura de hostil usa vermelho.")
	check(enemy_card != null, "O quadro do hostil está na fila.")
	var status_frame := bar._map_tooltip.get_node("StatusFrame") as TextureRect
	bar._map_tooltip_text.text = "%s\nVida: 30/30   ATK: 6\nStamina: 4/4\nMaestria: Nenhuma\n\nATK 6 + dado 4 − movimento 2 − distância 0 = 8 dano previsto." % enemy.data.display_name
	bar._map_tooltip.show()
	bar._map_tooltip.reset_size()
	check(status_frame.texture.resource_path.ends_with("uielementx_00005.png") \
		and bar._map_tooltip.size.x <= 340.0 \
		and (bar._map_tooltip.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a >= 0.9,
		"Status no mapa usa a moldura pedida, com fundo legível e largura compacta.")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		bar.set_process(false)
		bar._map_tooltip_text.add_theme_font_override("font", bar.BOLD_FONT)
		bar._map_tooltip_text.add_theme_color_override("font_color", Color(1.0, 0.36, 0.40))
		bar._map_tooltip.position = Vector2(760.0, 330.0)
		await process_frame
		var status_preview := "user://ppp_enemy_status_preview.png"
		root.get_texture().get_image().save_png(status_preview)
		print("ENEMY_STATUS_PREVIEW=" + ProjectSettings.globalize_path(status_preview))
		bar.set_process(true)
	bar._map_tooltip.hide()
	var debuff := DebuffInstanceState.new(load(
		"res://resources/skills/effects/debuffs/doenca_1.tres") as DebuffData, actor)
	enemy.debuffs.append(debuff)
	bar._refresh_cards()
	for info in bar._cards:
		if info["actor"] == enemy:
			check((info["debuffs"] as GridContainer).get_child_count() == 1
				and ((info["debuffs"] as GridContainer).get_child(0) as TextureRect).texture
					== debuff.data.icon,
				"Debuff aplicado aparece como ícone pequeno sob o quadro.")
	enemy.debuffs.erase(debuff)
	bar._refresh_cards()
	if enemy_card != null:
		var inspect := enemy_card.get_node("Inspect") as Button
		bar._show_tooltip(enemy, inspect)
		check(bar._tooltip.visible and bar._tooltip_text.text.contains(enemy.data.display_name)
			and bar._tooltip_text.text.contains("Stamina:"),
			"Hover apresenta nome e estatísticas.")
		inspect.pressed.emit()
		check(bar._action_menu.visible \
			and bar._action_buttons.get_child_count() == 1,
			"Hostil na iniciativa oferece somente Detalhes.")
		check(bar._selected_enemy == enemy and scene._enemy_link_glow.visible \
			and scene._enemy_link_coord == enemy.position,
			"Selecionar a caixa hostil acende o hex correspondente.")
		(bar._action_buttons.get_child(0) as Button).pressed.emit()
		check(hud.character_sheet.visible and hud.character_sheet.actor == enemy
			and hud.character_sheet.portrait.texture != null,
			"Detalhes abre a ficha arrastável, inclusive para hostis.")
	for index in combat.initiative_order.size():
		if combat.initiative_order[index]["entity"] == actor:
			var player_entry: Dictionary = combat.initiative_order[index]
			combat.initiative_order.remove_at(index)
			combat.initiative_order.push_front(player_entry)
			break
	combat._start_combat_turns()
	check(bar._current_actor == combat.current_actor,
		"A seta acompanha a entidade cujo turno começou.")
	check(combat.current_actor == actor and combat.is_player_turn(),
		"Jogável abre o primeiro turno neste cenário de teste.")
	for info in bar._cards:
		if info["actor"] != actor:
			continue
		var active_button := (info["frame"] as TextureRect).get_parent().get_node(
			"Inspect") as Button
		active_button.pressed.emit()
		check(bar._action_menu.visible and bar._action_buttons.get_child_count() == 2 \
			and (bar._action_buttons.get_child(1) as Button).text == "AÇÕES",
			"Jogável ativo oferece Detalhes e Ações na iniciativa.")
		(bar._action_buttons.get_child(1) as Button).pressed.emit()
		check(hud.action_drawer.visible and hud._open_card.state == actor,
			"Ações da iniciativa abre a caixa de ações do jogável.")
		bar._process(0.2)
		check(bar._root.position.x >= bar.LEFT_X \
			and bar._root.position.x >= hud.action_drawer.get_global_rect().end.x + 18.0,
			"A fila começa à direita da caixa de ações, com margem de clique.")
		break
	scene.request_combat_selection(enemy.position)
	var selected_enemy_card: Dictionary = {}
	for info in bar._cards:
		if info["actor"] == enemy:
			selected_enemy_card = info
	check(bar._selected_enemy == enemy and scene._enemy_link_glow.visible \
		and not selected_enemy_card.is_empty() \
		and (selected_enemy_card["glow"] as Panel).visible,
		"Selecionar o hex hostil acende também sua caixa na iniciativa.")
	var current := combat.current_actor
	bar._on_turn_finished(current)
	var spent_card: Dictionary = {}
	for info in bar._cards:
		if info["actor"] == current:
			spent_card = info
	if not spent_card.is_empty():
		check(((spent_card["frame"] as TextureRect).material as ShaderMaterial)
			.get_shader_parameter("accent") == bar.SPENT_COLOR
			and (spent_card["portrait"] as TextureRect).material != null,
			"Após agir, moldura e retrato ficam cinza.")
	# A terceira entidade morre: o quarto quadro assume imediatamente a
	# terceira posição. Se voltar à vida, entra no último lugar da fila real.
	var enemy_entry: Dictionary = {}
	for entry in combat.initiative_order:
		if entry.get("entity") == enemy:
			enemy_entry = entry
			break
	combat.initiative_order.erase(enemy_entry)
	combat.initiative_order.insert(2, enemy_entry)
	combat.initiative_order_changed.emit()
	var fourth := combat.initiative_order[3]["entity"] as EntityState
	var initial_count := combat.initiative_order.size()
	enemy.current_health = 0
	check(combat.initiative_order.size() == initial_count - 1
		and combat.initiative_order[2]["entity"] == fourth
		and bar._participants.size() == initial_count - 1
		and bar._participants[2] == fourth
		and bar._cards.size() == initial_count - 1,
		"Morte remove o terceiro quadro e o quarto passa à terceira posição.")
	enemy.current_health = enemy.max_health
	check(combat.initiative_order.size() == initial_count
		and combat.initiative_order[-1]["entity"] == enemy
		and bar._participants[-1] == enemy,
		"Ressurreição durante o combate entra no fim da fila.")
	var extra: Array[EntityState] = []
	for index in 14:
		var dummy := EntityState.new()
		dummy.instance_id = StringName("initiative_test_%d" % index)
		dummy.data = selected[0]
		dummy.max_health = 10
		dummy.current_health = 10
		extra.append(dummy)
	bar._participants.append_array(extra)
	bar._render()
	check(bar._cards.size() < bar._participants.size(),
		"Fila extensa exibe somente os quadros que cabem.")
	var before := bar._first_visible
	bar._scroll(1)
	check(bar._first_visible == before + 1,
		"Seta lateral avança a faixa um quadro por clique.")
	bar._on_turn_started(extra[-1], 2)
	check(bar._cards.any(func(info: Dictionary) -> bool:
		return info["actor"] == extra[-1]),
		"A faixa acompanha automaticamente a entidade ativa oculta.")
	print("PPP initiative bar: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
