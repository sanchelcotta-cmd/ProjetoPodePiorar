extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var debuff_popup := DebuffInfoPopup.new()
	root.add_child(debuff_popup)
	var data := load("res://resources/skills/effects/debuffs/terror.tres") as DebuffData
	var instance := DebuffInstanceState.new(data)
	instance.remaining_turns = 2
	debuff_popup.show_debuff(instance, Rect2(300, 260, 30, 30), false)
	await create_timer(0.07).timeout
	var first_debuff_size := debuff_popup.size
	check(debuff_popup.visible and debuff_popup.modulate.a == 1.0
		and first_debuff_size.y < 350.0,
		"Debuff abre compacto e legível na primeira vez.")
	debuff_popup.hide()
	debuff_popup.show_debuff(instance, Rect2(300, 260, 30, 30), false)
	await create_timer(0.07).timeout
	check(debuff_popup.size.is_equal_approx(first_debuff_size),
		"Debuff não muda de tamanho entre a primeira e a segunda abertura.")
	var title_popup := HexTitlePopup.new()
	root.add_child(title_popup)
	title_popup.show_title("Poço Reluzente", "Evento | Ambíguo",
		Vector2(430, 300), false)
	await create_timer(0.07).timeout
	var first_title_size := title_popup.size
	check(title_popup.visible and title_popup.modulate.a == 1.0
		and first_title_size.y < 200.0,
		"Título de hex abre compacto na primeira vez.")
	title_popup.hide()
	title_popup.show_title("Poço Reluzente", "Evento | Ambíguo",
		Vector2(430, 300), false)
	await create_timer(0.07).timeout
	check(title_popup.size.is_equal_approx(first_title_size),
		"Título de hex mantém a medida ao reabrir.")
	print("Popups na primeira abertura: %d falhas" % failures)
	quit(0 if failures == 0 else 1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
