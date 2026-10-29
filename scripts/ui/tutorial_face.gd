class_name TutorialFace
extends HBoxContainer

## Rosto de caracteres e fala pré-escrita. Não conversa nem gera conteúdo.
const MONO_FONT := preload("res://fonts/CutiveMono-Regular.ttf")

var _portrait: RichTextLabel
var _speech: Label
var _expression := "neutro"
var _line := ""
var _blink := false
var _blink_timer: Timer
var _detail := ":"


func _ready() -> void:
	add_theme_constant_override("separation", 22)
	_portrait = RichTextLabel.new()
	_portrait.name = "CharacterFace"
	_portrait.bbcode_enabled = true
	_portrait.scroll_active = false
	_portrait.fit_content = true
	_portrait.autowrap_mode = TextServer.AUTOWRAP_OFF
	_portrait.custom_minimum_size = Vector2(170, 92)
	_portrait.add_theme_font_override("normal_font", MONO_FONT)
	_portrait.add_theme_font_size_override("normal_font_size", 12)
	add_child(_portrait)
	_speech = Label.new()
	_speech.name = "CharacterSpeech"
	_speech.add_theme_font_override("font", MONO_FONT)
	_speech.add_theme_font_size_override("font_size", 13)
	_speech.autowrap_mode = TextServer.AUTOWRAP_OFF
	_speech.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speech.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(_speech)
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	_blink_timer.timeout.connect(_on_blink)
	add_child(_blink_timer)
	_schedule_blink()
	_redraw()


func show_page(expression: String, speech: String) -> void:
	_expression = expression.to_lower().strip_edges()
	_line = speech.strip_edges().trim_prefix("“").trim_suffix("”")
	_detail = ":" if randi() % 2 == 0 else "¨"
	_blink = false
	_redraw()


func _on_blink() -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort == null or not bool(comfort.get("enabled")):
		_blink = true
		_redraw()
		get_tree().create_timer(0.13, true).timeout.connect(func() -> void:
			if is_instance_valid(self):
				_blink = false
				_redraw(), CONNECT_ONE_SHOT)
	_schedule_blink()


func _schedule_blink() -> void:
	_blink_timer.start(randf_range(5.5, 9.0))


func _redraw() -> void:
	if _portrait == null:
		return
	var mint := _palette_color("progress").to_html()
	var eye := _palette_color("warning").to_html()
	var pink := _palette_color("selection").to_html()
	var eyes := "-" if _blink else "@"
	var mouth := "\\_/" if "sorriso" in _expression else \
		" o " if "surpres" in _expression else \
		"~_~" if "confus" in _expression else \
		"___" if "triste" in _expression else " - "
	_portrait.text = "[color=#%s]+[/color] [color=#%s].- - - -.[/color] [color=#%s]#[/color]\n" % [
		pink, mint, eye]
	_portrait.text += "[color=#%s]#[/color] [color=#%s]//[/color] [color=#%s]%s[/color] %s [color=#%s]%s[/color] [color=#%s]\\\\[/color]\n" % [
		eye, mint, eye, eyes, _detail, eye, eyes, mint]
	_portrait.text += "  [color=#%s]||[/color][color=#%s]*[/color]  [color=#%s]%s[/color]  [color=#%s]*[/color][color=#%s]||[/color] [color=#%s]+[/color]\n" % [
		mint, pink, mint, mouth, pink, mint, pink]
	_portrait.text += "  [color=#%s]\\\\[/color] [color=#%s]- - -[/color] [color=#%s]//[/color]\n" % [
		mint, mint, mint]
	_portrait.text += "[color=#%s]#[/color]      [color=#%s]+[/color]" % [pink, eye]
	_speech.visible = not _line.is_empty()
	if _line.is_empty():
		_speech.text = ""
		return
	_speech.add_theme_color_override("font_color", _palette_color("warning"))
	_speech.text = _boxed_line(_line)


func _palette_color(role: String) -> Color:
	var palette := get_node_or_null("/root/UIColorManager")
	if palette != null:
		return palette.call("color", role)
	return Color.WHITE


func _boxed_line(value: String) -> String:
	var max_width := 44 if get_viewport_rect().size.x >= 1200.0 else 34
	var words := value.replace("\n", " ").split(" ", false)
	var lines: Array[String] = []
	var current := ""
	for word in words:
		if current.is_empty():
			current = word
		elif current.length() + 1 + word.length() <= max_width:
			current += " " + word
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	var width := 0
	for line in lines:
		width = maxi(width, line.length())
	var border := "+" + "-".repeat(width + 2) + "+"
	var result := border
	for line in lines:
		result += "\n| " + line.rpad(width) + " |"
	return result + "\n" + border
