extends SceneTree

const PREVIEW_PATH := "C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_menu_preview.png"
const SHORT_PREVIEW_PATH := "C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_short_preview.png"
const DETAIL_PREVIEW_PATH := "C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_details_preview.png"
const PICKED_PREVIEW_PATH := "C:/Users/55319/.codex/.chatgpt-projects/g-p-6a5d33a5a45881918a00f0e4cf3ee3cb/selection_picked_preview.png"
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var selection := load("res://scenes/ui/playable_selection.tscn").instantiate() as PlayableSelectionScreen
	root.add_child(selection)
	await process_frame
	await process_frame
	var grid := selection.get_node("Content/Stack/BodyScroll/Body/Carousel/CardsCenter/CardsGrid") as GridContainer
	var previous := selection.get_node("Content/Stack/BodyScroll/Body/Carousel/Previous") as Button
	var next := selection.get_node("Content/Stack/BodyScroll/Body/Carousel/Next") as Button
	_check(grid.columns == 7 and selection.cards.size() == 7,
		"Sete personagens cabem juntos sem navegação lateral.")
	_check(previous.disabled and next.disabled and selection.cards.all(
		func(card: PlayableSelectionCard) -> bool: return card.visible),
		"Sem personagem oculto, setas não aceitam clique.")
	var first_card := selection.cards[0]
	first_card.details_button.pressed.emit()
	_check(selection._detail_panel.visible and selection.selected.is_empty(),
		"Detalhes abre a ficha sem selecionar o personagem.")
	await process_frame
	await process_frame
	var detail_image := root.get_texture().get_image()
	if detail_image != null and not detail_image.is_empty():
		detail_image.save_png(DETAIL_PREVIEW_PATH)
	selection._detail_panel.hide()
	first_card.pressed.emit()
	_check(selection.selected.size() == 1,
		"Clicar no corpo do card seleciona o personagem.")
	await process_frame
	await process_frame
	var picked_image := root.get_texture().get_image()
	if picked_image != null and not picked_image.is_empty():
		picked_image.save_png(PICKED_PREVIEW_PATH)
	first_card.pressed.emit()
	var image := root.get_texture().get_image()
	if image != null and not image.is_empty():
		var error := image.save_png(PREVIEW_PATH)
		_check(error == OK, "Prévia visual é gravada para inspeção.")
	else:
		push_warning("Renderizador headless não produziu imagem; cliques e geometria foram testados.")
	selection._on_mode_pressed(EventCampaignEligibility.Mode.SHORT)
	await process_frame
	await process_frame
	var short_image := root.get_texture().get_image()
	if short_image != null and not short_image.is_empty():
		short_image.save_png(SHORT_PREVIEW_PATH)
	for index in 2:
		var extra := load("res://scenes/ui/playable_selection_card.tscn").instantiate() as PlayableSelectionCard
		grid.add_child(extra)
		extra.setup(selection.cards[index].character)
		selection.cards.append(extra)
	selection._update_layout()
	_check(not next.disabled and not selection.cards[8].visible,
		"A nona ficha habilita a próxima página, sem aparecer sobre as oito primeiras.")
	next.pressed.emit()
	_check(not previous.disabled and selection.cards[8].visible
		and not selection.cards[0].visible,
		"A seta revela somente os personagens da página seguinte.")
	print("PLAYABLE_SELECTION_LAYOUT_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
