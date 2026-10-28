class_name UINarrativeFont
extends RefCounted

## Apenas corpos de texto descritivos. Nunca aplicar ao tema global, títulos ou botões.
const FONT := preload("res://fonts/CutiveMono-Narrative.tres")


static func set_embolden(weight: float) -> void:
	var variation := FONT as FontVariation
	if not is_equal_approx(variation.variation_embolden, weight):
		variation.variation_embolden = weight


static func apply_label(label: Label) -> void:
	label.add_theme_font_override("font", FONT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


static func apply_rich_text(label: RichTextLabel) -> void:
	label.add_theme_font_override("normal_font", FONT)
