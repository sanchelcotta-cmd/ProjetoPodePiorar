extends SceneTree

## Confere a caixa de confirmação da Marmita sem criar um item duplicado.
var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres") as EntityData,
		load("res://resources/entities/entities_playable/jornalista.tres") as EntityData,
		load("res://resources/entities/entities_playable/professora.tres") as EntityData,
	]
	check(gerencia.start_new_game(choices), "Campanha inicia com o Cozinheiro.")
	check((scene.get_node("RoundManager") as RoundManager).start_first_map(),
		"Mapa inicia para testar a Ativa.")
	for member in gerencia.campaign.active_entity_states:
		member.inventory_items.clear() # Só o item criado deve aparecer neste teste.
	await process_frame
	var actor := gerencia.campaign.active_entity_states[0]
	var skills := scene.get_node("SkillManager") as SkillManager
	var grant := skills.get_active_grants(actor)[0]
	check((grant.skill as ActiveSkillData).id == &"playable_active_009",
		"A primeira Ativa do Cozinheiro é Marmita do Dia.")
	check(skills.use_exploration_active(actor, actor, grant, gerencia.campaign),
		"Marmita cria uma refeição.")
	var popup := (scene.get_node("PartyStatusHUD") as PartyStatusHUD).created_item_popup
	var name_label := popup.get("_name") as Label
	var icon := popup.get("_icon") as TextureRect
	check(popup.visible and name_label.text == actor.inventory_items[0].data.display_name \
		and icon.texture == actor.inventory_items[0].data.icon,
		"A caixa central mostra o nome e o ícone do item realmente recebido.")
	check(actor.inventory_items.size() == 1,
		"Abrir a caixa não duplica o item no inventário.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	popup.call("_input", escape)
	check(not popup.visible, "ESC fecha a confirmação do item criado.")
	print("CREATED_ITEM_POPUP_TEST_OK" if failures == 0 else \
		"CREATED_ITEM_POPUP_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
