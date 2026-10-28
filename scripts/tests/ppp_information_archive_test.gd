extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var gerencia := GerenciaJogo.new()
	root.add_child(gerencia)
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	check(gerencia.start_new_game(selected),
		"Arquivo de Informações acompanha uma campanha ativa.")
	var top_bar := load("res://scenes/ui/campaign_top_bar.tscn").instantiate() as CampaignTopBar
	top_bar.gerencia = gerencia
	root.add_child(top_bar)
	await process_frame
	var archive := top_bar.information_archive
	check(archive != null and top_bar.information_button.text.contains("INFORMAÇÕES"),
		"O botão fica na barra de Dia e abre o arquivo.")
	var day_panel := top_bar.get_node("Bar/Items/Day") as Control
	var button_gap := day_panel.global_position.x \
		- top_bar.journal_button.get_global_rect().end.x
	check(top_bar.information_button.global_position.x \
		< top_bar.group_inventory_button.global_position.x \
		and top_bar.group_inventory_button.global_position.x \
		< top_bar.journal_button.global_position.x \
		and button_gap >= 50.0 and button_gap <= 60.0,
		"Informações, Inventário e Registros ficam antes do Dia, com a folga combinada.")
	var catalog := gerencia.get_information_catalog()
	check(catalog.size() == 20, "O catálogo contém as 20 Informações dos quatro desfechos.")
	top_bar.information_button.pressed.emit()
	await process_frame
	check(archive.folder_keys.size() == 4 and "khainokata" in archive.folder_keys,
		"As pastas são lidas dos diretórios dos Resources, não de uma lista fixa.")
	check(archive.visible and archive.total_label.text.begins_with("0 / 20"),
		"Sem descobertas, o arquivo abre e mostra zero coletadas.")
	var archive_before_drag := archive.window.position
	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	archive._on_header_gui_input(drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.relative = Vector2(30.0, 20.0)
	archive._input(drag_motion)
	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	archive._input(drag_release)
	check(archive.window.position.is_equal_approx(archive_before_drag + drag_motion.relative),
		"Arrastar a faixa superior move a janela de Informações.")
	archive._layout_window()
	check(archive.window.position.is_equal_approx(archive_before_drag + drag_motion.relative),
		"Atualizar o arquivo preserva sua posição arrastada.")
	var clamped_archive := archive._clamp_window_position(Vector2(-9999.0, 9999.0))
	var archive_viewport := archive.get_viewport_rect().size
	check(clamped_archive.x >= 15.0 and clamped_archive.y \
		<= archive_viewport.y - archive.window.size.y - 15.0,
		"A janela de Informações fica dentro da câmera ao arrastar.")
	check(archive.window.get_theme_stylebox("panel") is StyleBoxFlat,
		"O arquivo mantém margem simples sem decoração de canto.")
	check(archive.document_buttons[0].disabled and not archive.notebook.visible,
		"Documento desconhecido não pode abrir a anotação.")
	check(archive.window.size.x < root.size.x and archive.window.size.y < root.size.y,
		"A janela cobre só parte do mapa, não a tela inteira.")
	var khainokata := load("res://resources/informacoes/khainokata/khaikonata_1.tres") as Informacao
	check(khainokata != null, "A primeira Informação de Khainokata é localizada pelo Resource.")
	gerencia.record_information_obtained(khainokata)
	archive.open()
	archive._select_folder("khainokata")
	var khainokata_index := archive.folder_keys.find("khainokata")
	check(archive.folder_counts[khainokata_index].text == "1 / 5" \
		and archive.folder_progress[khainokata_index].value == 1,
		"A pasta atualiza seu progresso conforme a campanha.")
	check(not archive.document_buttons[0].disabled and archive.document_buttons[1].disabled,
		"Só o documento obtido é clicável.")
	archive._select_document(khainokata.id)
	check(archive.notebook.visible and archive.notebook_title.text.contains(khainokata.titulo)
		and archive.notebook_text.text == khainokata.descricao,
		"A anotação abaixo da lista lê título e descrição do .tres.")
	await process_frame
	var document_scroll := archive.document_list.get_parent() as ScrollContainer
	check(archive.notebook.global_position.y >= document_scroll.get_global_rect().end.y,
		"O bloco de notas fica abaixo da área rolável dos documentos, sem cobri-la.")
	archive._select_folder("orchestra")
	check(not archive.notebook.visible and archive.document_buttons[0].disabled,
		"Trocar de pasta oculta a anotação anterior.")
	var future := Informacao.new()
	future.id = &"in_teste_futuro"
	future.titulo = "Informação de uma pasta futura"
	future.resource_path = "res://resources/informacoes/pasta_futura/informacao_1.tres"
	archive.catalog.append(future)
	archive._collect_folders()
	archive._rebuild_folder_list()
	archive._refresh()
	check("pasta_futura" in archive.folder_keys
		and archive.folder_buttons.size() == 5,
		"Uma pasta futura entra no arquivo sem alterar uma lista fixa ou enum da UI.")
	archive.close()
	check(not archive.visible, "O arquivo fecha sem mudar o estado da campanha.")
	print("Arquivo de Informações: %s" % ("OK" if failures == 0 else "%d FALHAS" % failures))
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
