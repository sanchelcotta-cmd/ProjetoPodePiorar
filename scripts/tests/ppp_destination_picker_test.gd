extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1440, 810)
	var picker := load("res://scenes/ui/campaign_destination_picker.tscn").instantiate() as CampaignDestinationPicker
	root.add_child(picker)
	await process_frame
	var confirmed: Array[StringName] = []
	var canceled_count := [0]
	picker.destination_confirmed.connect(func(district: StringName) -> void:
		confirmed.append(district))
	picker.canceled.connect(func() -> void: canceled_count[0] += 1)
	picker.open_picker([&"suburbio", &"baixo_centro"], &"suburbio")
	check(picker.is_open() and picker.displayed_districts().size() == 3,
		"Seleção comum mostra os três distritos.")
	check(picker.row_for(&"centro").disabled \
		and not picker.select_district(&"centro"),
		"Centro indisponível aparece, mas não pode ser escolhido.")
	var center_art := picker._row_controls[&"centro"]["artwork"] as TextureRect
	check(center_art.material is ShaderMaterial,
		"Arte indisponível recebe cinza sem alterar o sprite original.")
	for district in picker.displayed_districts():
		var art := picker._row_controls[district]["artwork"] as TextureRect
		check(art.texture.resource_path.ends_with("_0001.png"),
			"A arte de %s é sempre a primeira cena do distrito." % district)
		var target_door: float = art.custom_minimum_size.y \
			* float(picker.DOOR_HEIGHT_PX[district]) / art.texture.get_size().y
		check(absf(target_door - (46.0 if district == &"suburbio" else 35.0)) < 0.2,
			"As portas de %s têm escala visual equivalente." % district)
	check(picker.select_district(&"baixo_centro") \
		and picker.row_for(&"baixo_centro").custom_minimum_size.y \
		> picker.row_for(&"suburbio").custom_minimum_size.y,
		"A seleção cresce em imagem e altura sem mudar a escala-base dos demais.")
	picker._confirm.pressed.emit()
	check(not picker.is_open() and confirmed == [&"baixo_centro"],
		"Confirmar fecha a caixa e envia apenas o distrito escolhido.")
	picker.open_picker([&"suburbio", &"baixo_centro"], &"baixo_centro")
	picker._cancel.pressed.emit()
	check(not picker.is_open() and canceled_count[0] == 1 \
		and confirmed.size() == 1,
		"Continuar no mapa atual fecha sem avançar.")
	picker.open_picker([&"centro"], &"suburbio", true)
	check(picker.displayed_districts() == [&"centro"] \
		and picker.row_for(&"suburbio") == null \
		and picker.row_for(&"baixo_centro") == null \
		and picker.selected_district() == &"centro",
		"Rota final mostra apenas Centro e o pré-seleciona.")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	picker._input(esc)
	check(not picker.is_open() and canceled_count[0] == 2,
		"Esc cancela a escolha, sem confirmar destino.")
	print("PPP_DESTINATION_PICKER_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
