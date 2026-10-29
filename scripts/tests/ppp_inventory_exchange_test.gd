extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var game := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
	]
	check(game.start_new_game(choices), "Campanha criada.")
	var actor := game.campaign.active_entity_states[0]
	var teammate := game.campaign.active_entity_states[1]
	actor.inventory_items.clear()
	teammate.inventory_items.clear()
	var inventory := (scene.get_node("SkillManager") as SkillManager).inventory_manager
	var filler := load("res://resources/itens/consumables/bolinho_de_chuva.tres") as ItemData
	while inventory.can_receive(actor, filler):
		inventory.add_item(actor, filler)
	var incoming := load("res://resources/itens/consumables/chocolate.tres") as ItemData
	var group := (scene.get_node("CampaignTopBar") as CampaignTopBar).group_inventory
	var confirmed := {"called": false}
	var callback := func(outgoing: Array[InventoryItemState]) -> bool:
		confirmed["called"] = true
		return inventory.exchange_items(actor, outgoing, incoming)
	check(group.begin_exchange(actor, incoming, callback, Callable(), false),
		"Troca obrigatória abre Inventário do Grupo.")
	check(not group._exchange_decline_button.visible and group._close_button.visible
		and group._exchange_cancel_button.visible,
		"Troca obrigatória oferece Voltar, mas não recusar o item.")
	group.close()
	check(not group.visible and not confirmed["called"] and
		actor.inventory_items.size() == actor.inventory_capacity(),
		"Voltar conserva o item pendente e não altera o inventário.")
	check(group.begin_exchange(actor, incoming, callback, Callable(), false),
		"Após voltar, é possível tentar a troca de novo.")
	var moved := actor.inventory_items[0] as InventoryItemState
	var moved_slot := moved.inventory_slot_index
	group.drop_inventory_entry(actor, teammate, moved, 0)
	check(moved in teammate.inventory_items and moved not in actor.inventory_items
		and not group._exchange_accept_button.disabled,
		"Remanejar para outro jogável libera espaço sem descarte.")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	group._input(escape)
	check(not group.visible and moved in actor.inventory_items and
		moved not in teammate.inventory_items and
		moved.inventory_slot_index == moved_slot and not confirmed["called"],
		"Esc desfaz o remanejamento e volta à caixa anterior.")
	check(group.begin_exchange(actor, incoming, callback, Callable(), false),
		"Item continua pendente após Esc.")
	group.drop_inventory_entry(actor, teammate, moved, 0)
	group._ask_exchange_confirmation()
	check(group._exchange_confirmation.visible and
		"Guardar" in group._exchange_question.text,
		"Espaço liberado permite guardar sem descartar outro item.")
	await process_frame
	var dialog := group._exchange_confirmation.get_node("ConfirmationCenter/Dialog") as Control
	check(dialog != null and dialog.size.y < root.size.y * 0.6,
		"Confirmação permanece uma caixa compacta, não uma faixa até o chão.")
	group._confirm_exchange()
	check(confirmed["called"] and moved in teammate.inventory_items and
		actor.inventory_items.any(func(entry: InventoryItemState) -> bool:
			return entry.data == incoming) and not group.visible,
		"Guardar sem descarte conclui após remanejamento.")
	actor.inventory_items.clear()
	while inventory.can_receive(actor, filler):
		inventory.add_item(actor, filler)
	confirmed["called"] = false
	check(group.begin_exchange(actor, incoming, callback, Callable(), false),
		"Troca por descarte continua disponível.")
	var outgoing := actor.inventory_items[0] as InventoryItemState
	var test_cell := Button.new()
	group._on_carried_clicked(0, outgoing, test_cell)
	test_cell.free()
	check(not group._exchange_accept_button.disabled,
		"Escolher item descartável habilita aceitar troca.")
	group._ask_exchange_confirmation()
	check(group._exchange_confirmation.visible and
		outgoing.data.display_name in group._exchange_question.text and
		incoming.display_name in group._exchange_question.text,
		"Confirmação exibe nomes do item que sai e do que entra.")
	group._exchange_confirmation.hide()
	check(outgoing in actor.inventory_items and not confirmed["called"],
		"Ainda não retorna à escolha sem descartar.")
	group._ask_exchange_confirmation()
	group._confirm_exchange()
	check(confirmed["called"] and outgoing not in actor.inventory_items and
		actor.inventory_items.any(func(entry: InventoryItemState) -> bool:
			return entry.data == incoming) and not group.visible,
		"Sim conclui uma única troca e fecha a janela.")
	print("INVENTORY_EXCHANGE_TEST_OK" if failures == 0 else
		"INVENTORY_EXCHANGE_TEST_FAILED: %d" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
