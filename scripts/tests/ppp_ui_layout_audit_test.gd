extends SceneTree

## Auditoria dos textos de uma linha nas interfaces principais a 1440x810.
## Rótulos intrínsecos são medidos contra a moldura próxima, não contra si mesmos.
var issues: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var scene := load("res://scenes/game/campaign_game.tscn").instantiate() as PPPMapView
	root.add_child(scene)
	await process_frame
	var gerencia := scene.get_node("GerenciaJogo") as GerenciaJogo
	var choices: Array[EntityData] = [
		load("res://resources/entities/entities_playable/jornalista.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/velha_fofoqueira.tres"),
	]
	gerencia.start_new_game(choices)
	(scene.get_node("RoundManager") as RoundManager).start_first_map()
	await process_frame
	var hud := scene.get_node("PartyStatusHUD") as PartyStatusHUD
	_audit(scene, "mapa")
	hud.cards[0].action_button.pressed.emit()
	await process_frame
	_audit(scene, "ações")
	hud.inventory_button.pressed.emit()
	await process_frame
	_audit(scene, "inventário individual")
	var top := scene.get_node("CampaignTopBar") as CampaignTopBar
	top.group_inventory.open()
	await process_frame
	_audit(scene, "inventário do grupo")
	top.group_inventory.close()
	top.information_archive.open()
	await process_frame
	_audit(scene, "informações")
	top.information_archive.close()
	var actor := gerencia.campaign.active_entity_states[0]
	var information := load("res://resources/informacoes/orchestra/orchestra_1.tres") as Informacao
	gerencia.campaign.current_map.set_ppp_block(Vector2i(6, 2),
		HexGrid.PPPBlockType.INFORMATION, information)
	(scene.get_node("BlockManager") as BlockManager).begin_activation(Vector2i(6, 2), actor)
	await process_frame
	_audit(scene, "ativação de bloco")
	for issue in issues:
		print("MARGEM UI: " + issue)
	print("Auditoria de textos UI: %d possíveis cortes" % issues.size())
	quit(0 if issues.is_empty() else 1)


func _audit(node: Node, context: String) -> void:
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree():
			return
		var caption := ""
		if control is Label:
			caption = (control as Label).text
			if (control as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
				caption = ""
		elif control is Button:
			caption = (control as Button).text
			# Ícones de comando não são palavras; têm centralização e tooltip próprios.
			if caption.strip_edges().length() <= 2:
				caption = ""
		if not caption.is_empty() and not caption.contains("\n") and control.size.x > 0.0:
			var available_width := control.size.x
			if control is Label:
				var ancestor := control.get_parent()
				while ancestor != null and not (ancestor is Panel or ancestor is PanelContainer):
					ancestor = ancestor.get_parent()
				if ancestor is Control:
					available_width = (ancestor as Control).size.x
				else:
					available_width = INF
			var font := control.get_theme_font("font")
			if font != null:
				var font_size := control.get_theme_font_size("font_size")
				var text_width := font.get_string_size(caption,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				if text_width > available_width - 20.0 + 2.0:
					var issue := "%s: %s (%s): texto %.1f px, caixa %.1f px" % [
						context, str(control.get_path()), caption, text_width, available_width]
					if issue not in issues:
						issues.append(issue)
	for child in node.get_children():
		_audit(child, context)
