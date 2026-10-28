extends Node

## Tema sem heurística: somente componentes registrados por papel semântico mudam
## de cor. Medidas, estilos, Resources do jogo e saves de campanha não são tocados.
signal palette_changed(palette_id: String)

const CONFIG_PATH := "user://ppp_ui_palette.cfg"
const PALETTE_IDS := ["padrao", "azul", "rosa_branco", "acessivel"]
const PALETTE_NAMES := ["Padrão", "Azul neon", "Rosa e branco", "Acessível"]
const COLORS := {
	"padrao": {
		"canvas": "#05090C", "surface": "#06111A", "surface_hover": "#102630",
		"selected_surface": "#301323", "danger_surface": "#301317",
		"button": "#06111A", "button_hover": "#102630",
		"button_selected": "#301323", "button_danger": "#301317",
		"on_button": "#EBF2F5",
		"on_button_disabled": "#B8C4CA",
		"on_dark_accent": "#38D9F0", "on_dark_muted": "#A3BAC4",
		"card_empty": Color(0.996078, 0.168627, 0.592157),
		"card_active": Color(0.27, 0.82, 0.79),
		"card_inactive": Color(0.48, 0.51, 0.54),
		"card_dead": Color(0.12, 0.13, 0.14),
		"primary": "#EBF2F5", "secondary": "#A3BAC4", "neutral": "#3DC2E6",
		"structure": "#38D9F0", "selection": "#FF66B0", "progress": "#4DE385",
		"warning": "#FFD459", "danger": "#FF646E", "disabled": "#70838B",
		"action_skill": "#FFD459", "action_skill_hover": "#FFE182",
		"action_skill_pressed": "#E5B738", "action_skill_text": "#1E1909",
		"action_skill_subtext": "#302918",
		"action_skill_border": "#FFD459", "action_core_border": "#4DE385",
		"action_skill_hover_border": "#FFD459",
		"action_core_hover_border": "#4DE385",
		"action_core": "#4DE385", "action_core_hover": "#78F1A0",
		"action_core_pressed": "#32BD69", "action_core_text": "#092112",
		"action_pass": "#741F2F", "action_pass_hover": "#8A2A3B",
		"action_pass_pressed": "#5F1927", "action_pass_text": "#FFF5F6",
		"action_pass_only": "#741F2F", "action_pass_only_hover": "#8A2A3B",
		"action_pass_only_pressed": "#5F1927", "action_pass_only_text": "#FFF5F6",
		"action_pass_only_border": "#FF646E",
		"action_pass_only_hover_border": "#FF646E",
	},
	"azul": {
		"canvas": "#071426", "surface": "#10233B", "surface_hover": "#173651",
		"selected_surface": "#1B3C70", "danger_surface": "#30234F",
		"button": "#183B66", "button_hover": "#245180",
		"button_selected": "#315EA5", "button_danger": "#51377B",
		"on_button": "#F4F9FF",
		"on_button_disabled": "#C6D9E8",
		"on_dark_accent": "#83B4FF", "on_dark_muted": "#BDD2E5",
		"card_empty": "#6197D5", "card_active": "#39E7A1",
		"card_inactive": "#8499B3", "card_dead": "#51377B",
		"primary": "#EEF7FF", "secondary": "#BDD2E5", "neutral": "#6197D5",
		"structure": "#40CCED", "selection": "#83B4FF", "progress": "#39E7A1",
		"warning": "#82B8F0", "danger": "#B17AF0", "disabled": "#8499B3",
		"action_skill": "#183B66", "action_skill_hover": "#245180",
		"action_skill_pressed": "#315EA5", "action_skill_text": "#F4F9FF",
		"action_skill_subtext": "#DEE8F0",
		"action_skill_border": "#40CCED", "action_core_border": "#40CCED",
		"action_skill_hover_border": "#83B4FF",
		"action_core_hover_border": "#83B4FF",
		"action_core": "#183B66", "action_core_hover": "#245180",
		"action_core_pressed": "#315EA5", "action_core_text": "#F4F9FF",
		"action_pass": "#51377B", "action_pass_hover": "#51377B",
		"action_pass_pressed": "#51377B", "action_pass_text": "#F4F9FF",
		"action_pass_only": "#183B66", "action_pass_only_hover": "#245180",
		"action_pass_only_pressed": "#315EA5", "action_pass_only_text": "#F4F9FF",
		"action_pass_only_border": "#40CCED",
		"action_pass_only_hover_border": "#83B4FF",
	},
	"rosa_branco": {
		"canvas": "#F4F1F3", "surface": "#FFFFFF", "surface_hover": "#FFF1F7",
		"selected_surface": "#FFE3F0", "danger_surface": "#FDE8EC",
		"button": "#9D1D61", "button_hover": "#AD266F",
		"button_selected": "#86134F", "button_danger": "#AF2339",
		"on_button": "#FFFFFF",
		"on_button_disabled": "#F1C8DA",
		"on_dark_accent": "#F5A9D0", "on_dark_muted": "#E8C4D9",
		"card_empty": "#A71868", "card_active": "#8D1C5B",
		"card_inactive": "#695E66", "card_dead": "#B82A42",
		"primary": "#3A1730", "secondary": "#68445E", "neutral": "#A65A80",
		"structure": "#AD2876", "selection": "#A71868", "progress": "#8D1C5B",
		"warning": "#9F0759", "danger": "#B82A42", "disabled": "#695E66",
		"action_skill": "#9D1D61", "action_skill_hover": "#AD266F",
		"action_skill_pressed": "#86134F", "action_skill_text": "#FFFFFF",
		"action_skill_subtext": "#DEE8F0",
		"action_skill_border": "#AD2876", "action_core_border": "#AD2876",
		"action_skill_hover_border": "#A71868",
		"action_core_hover_border": "#A71868",
		"action_core": "#9D1D61", "action_core_hover": "#AD266F",
		"action_core_pressed": "#86134F", "action_core_text": "#FFFFFF",
		"action_pass": "#AF2339", "action_pass_hover": "#AF2339",
		"action_pass_pressed": "#AF2339", "action_pass_text": "#FFFFFF",
		"action_pass_only": "#9D1D61", "action_pass_only_hover": "#AD266F",
		"action_pass_only_pressed": "#86134F", "action_pass_only_text": "#FFFFFF",
		"action_pass_only_border": "#AD2876",
		"action_pass_only_hover_border": "#A71868",
	},
	"acessivel": {
		"canvas": "#08141C", "surface": "#102630", "surface_hover": "#173844",
		"selected_surface": "#3B1630", "danger_surface": "#3B2026",
		"button": "#102630", "button_hover": "#173844",
		"button_selected": "#3B1630", "button_danger": "#3B2026",
		"on_button": "#F5FAFC",
		"on_button_disabled": "#C7D6DD",
		"on_dark_accent": "#67C6EF", "on_dark_muted": "#C7D6DD",
		"card_empty": "#F3A0CB", "card_active": "#51D6B1",
		"card_inactive": "#8A9DA6", "card_dead": "#FF916F",
		"primary": "#F5FAFC", "secondary": "#C7D6DD", "neutral": "#89CBEA",
		"structure": "#67C6EF", "selection": "#F3A0CB", "progress": "#51D6B1",
		"warning": "#FFD36B", "danger": "#FF916F", "disabled": "#8A9DA6",
		"action_skill": "#102630", "action_skill_hover": "#173844",
		"action_skill_pressed": "#3B1630", "action_skill_text": "#F5FAFC",
		"action_skill_subtext": "#DEE8F0",
		"action_skill_border": "#67C6EF", "action_core_border": "#67C6EF",
		"action_skill_hover_border": "#F3A0CB",
		"action_core_hover_border": "#F3A0CB",
		"action_core": "#102630", "action_core_hover": "#173844",
		"action_core_pressed": "#3B1630", "action_core_text": "#F5FAFC",
		"action_pass": "#3B2026", "action_pass_hover": "#3B2026",
		"action_pass_pressed": "#3B2026", "action_pass_text": "#F5FAFC",
		"action_pass_only": "#102630", "action_pass_only_hover": "#173844",
		"action_pass_only_pressed": "#3B1630", "action_pass_only_text": "#F5FAFC",
		"action_pass_only_border": "#67C6EF",
		"action_pass_only_hover_border": "#F3A0CB",
	},
}

var palette_id := "padrao"
var _bindings: Array[Dictionary] = []


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		var saved := str(config.get_value("ui", "palette", "padrao"))
		if saved in PALETTE_IDS:
			palette_id = saved
	var scale_service := get_node_or_null("/root/UniversalFontScale")
	if scale_service != null:
		scale_service.ui_scale_changed.connect(_on_ui_scale_changed)
	_connect_visual_comfort.call_deferred()


func _connect_visual_comfort() -> void:
	var comfort := get_node_or_null("/root/VisualComfort")
	if comfort != null:
		comfort.changed.connect(_on_visual_comfort_changed)


func _on_visual_comfort_changed(_enabled: bool) -> void:
	_apply_bindings.call_deferred()


func _on_ui_scale_changed(_factor: float) -> void:
	# O serviço de escala duplica StyleBoxes locais. Reaplicar somente as cores
	# depois da duplicação conserva a geometria nova sem trocar o tema.
	_apply_bindings.call_deferred()


func color(role: String) -> Color:
	var profile: Dictionary = COLORS[palette_id]
	var value: Variant = profile.get(role, profile["primary"])
	return value if value is Color else Color(str(value))


func set_palette(new_id: String, persist: bool = true) -> bool:
	if new_id not in PALETTE_IDS:
		return false
	palette_id = new_id
	_apply_bindings()
	palette_changed.emit(new_id)
	if not persist:
		return true
	var config := ConfigFile.new()
	config.set_value("ui", "palette", new_id)
	return config.save(CONFIG_PATH) == OK


func bind_color(control: Control, theme_key: String, role: String) -> void:
	if control == null or not COLORS[palette_id].has(role):
		return
	for binding in _bindings:
		if binding.get("kind") == "color" and binding.get("key") == theme_key \
				and (binding["target"] as WeakRef).get_ref() == control:
			binding["role"] = role
			control.add_theme_color_override(theme_key, color(role))
			return
	_bindings.append({"kind": "color", "target": weakref(control),
		"key": theme_key, "role": role})
	control.add_theme_color_override(theme_key, color(role))


func bind_style(style: StyleBoxFlat, background_role: String,
		border_role: String = "", shadow_role: String = "") -> void:
	if style == null or not COLORS[palette_id].has(background_role):
		return
	_bindings.append({"kind": "style", "target": weakref(style),
		"background": background_role, "border": border_role,
		"shadow": shadow_role, "bg_alpha": style.bg_color.a,
		"border_alpha": style.border_color.a,
		"shadow_alpha": style.shadow_color.a,
		"shadow_size": style.shadow_size})
	_apply_binding(_bindings.back())


func bind_control_style(control: Control, theme_key: String, background_role: String,
		border_role: String = "", shadow_role: String = "") -> void:
	if control == null or not control.has_theme_stylebox_override(theme_key) \
			or not COLORS[palette_id].has(background_role):
		return
	var style := control.get_theme_stylebox(theme_key) as StyleBoxFlat
	if style == null:
		return
	for binding in _bindings:
		if binding.get("kind") == "control_style" and binding.get("key") == theme_key \
				and (binding["target"] as WeakRef).get_ref() == control:
			binding["background"] = background_role
			binding["border"] = border_role
			binding["shadow"] = shadow_role
			_apply_binding.call_deferred(binding)
			return
	var binding := {"kind": "control_style", "target": weakref(control),
		"key": theme_key, "background": background_role, "border": border_role,
		"shadow": shadow_role, "bg_alpha": style.bg_color.a,
		"border_alpha": style.border_color.a, "shadow_alpha": style.shadow_color.a,
		"shadow_size": style.shadow_size}
	_bindings.append(binding)
	_apply_binding.call_deferred(binding)


func bind_rect(rect: ColorRect, role: String) -> void:
	if rect == null or not COLORS[palette_id].has(role):
		return
	_bindings.append({"kind": "rect", "target": weakref(rect),
		"role": role, "alpha": rect.color.a})
	_apply_binding(_bindings.back())


func _apply_bindings() -> void:
	var survivors: Array[Dictionary] = []
	for binding in _bindings:
		if (binding["target"] as WeakRef).get_ref() == null:
			continue
		_apply_binding(binding)
		survivors.append(binding)
	_bindings = survivors


func _apply_binding(binding: Dictionary) -> void:
	var target: Variant = (binding["target"] as WeakRef).get_ref()
	if target == null:
		return
	match str(binding["kind"]):
		"color":
			(target as Control).add_theme_color_override(
				str(binding["key"]), color(str(binding["role"])))
		"rect":
			var rect_color := color(str(binding["role"]))
			rect_color.a = float(binding["alpha"])
			(target as ColorRect).color = rect_color
		"style":
			var style := target as StyleBoxFlat
			_apply_style_colors(style, binding)
		"control_style":
			var control := target as Control
			if not control.has_theme_stylebox_override(str(binding["key"])):
				return
			var current := control.get_theme_stylebox(str(binding["key"])) as StyleBoxFlat
			if current != null:
				_apply_style_colors(current, binding)


func _apply_style_colors(style: StyleBoxFlat, binding: Dictionary) -> void:
	var bg := color(str(binding["background"]))
	bg.a = float(binding["bg_alpha"])
	style.bg_color = bg
	if str(binding["border"]) != "":
		var border := color(str(binding["border"]))
		border.a = float(binding["border_alpha"])
		style.border_color = border
	if str(binding["shadow"]) != "":
		var shadow := color(str(binding["shadow"]))
		shadow.a = float(binding["shadow_alpha"])
		var comfort := get_node_or_null("/root/VisualComfort")
		if comfort != null and bool(comfort.get("enabled")):
			shadow.a = minf(shadow.a, 0.12)
			style.shadow_size = mini(int(binding["shadow_size"]), 2)
		else:
			style.shadow_size = int(binding["shadow_size"])
		style.shadow_color = shadow
