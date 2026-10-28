extends SceneTree

const NARRATIVE_FONT := preload("res://fonts/CutiveMono-Narrative.tres")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scaler := root.get_node("UniversalFontScale")
	var original_scale := float(scaler.get("ui_factor"))
	var label := Label.new()
	var rich := RichTextLabel.new()
	root.add_child(label)
	root.add_child(rich)
	UINarrativeFont.apply_label(label)
	UINarrativeFont.apply_rich_text(rich)
	_check(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT,
		"Descrições usam alinhamento à esquerda.")
	_check(label.get_theme_font("font") == NARRATIVE_FONT
		and rich.get_theme_font("normal_font") == NARRATIVE_FONT,
		"Descrições simples e ricas compartilham a mesma fonte.")
	_check(bool(scaler.call("set_ui_scale", 0.8, false)),
		"A escala de 80% pode ser aplicada sem gravar preferências.")
	_check(is_equal_approx((label.get_theme_font("font") as FontVariation).variation_embolden,
		0.3),
		"Em 80%, o reforço do traço é discreto.")
	_check(bool(scaler.call("set_ui_scale", 1.0, false)),
		"A escala de 100% pode ser restaurada.")
	_check(is_equal_approx((label.get_theme_font("font") as FontVariation).variation_embolden,
		0.5),
		"A partir de 100%, o traço ganha leve reforço.")
	scaler.call("set_ui_scale", original_scale, false)
	label.free()
	rich.free()
	print("PPP_NARRATIVE_FONT_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
