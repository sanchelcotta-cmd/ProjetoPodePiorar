extends SceneTree

func _initialize() -> void:
	var path := "res://fonts/UbuntuSans-Regular.ttf"
	var configured := str(ProjectSettings.get_setting("gui/theme/custom_font"))
	var loaded := load(path) as FontFile
	var failures := 0
	if configured != path:
		failures += 1
		push_error("A configuração global precisa apontar para Ubuntu Sans.")
	if loaded == null:
		failures += 1
		push_error("O arquivo de fonte precisa carregar como FontFile.")
	var label := Label.new()
	var button := Button.new()
	var popup := PopupMenu.new()
	root.add_child(label)
	root.add_child(button)
	root.add_child(popup)
	if label.get_theme_font("font").resource_path != path \
			or button.get_theme_font("font").resource_path != path \
			or popup.get_theme_font("font").resource_path != path:
		failures += 1
		push_error("Rótulos, botões e menus precisam herdar Ubuntu Sans.")
	print("PPP global font: %d falhas" % failures)
	quit(0 if failures == 0 else 1)
