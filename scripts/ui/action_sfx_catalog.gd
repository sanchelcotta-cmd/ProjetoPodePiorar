class_name ActionSFXCatalog
extends RefCounted

## Tempos do MP3 exportado, medidos no primeiro transiente audível. O projeto
## original de mixagem tinha espaçamento menor entre os clipes; copiar seus
## marcadores diretamente para o MP3 exportado reproduzia silêncio.
## A escolha não depende da UI nem da animação: recebe a instância efetiva.
const CLIPS := {
	&"punch": [2.30, 2.80, 1.0, 1.25],
	&"quick_swoosh": [4.06, 4.50, 1.08, 1.20],
	# Variante rápida do impacto de lâmina mais presente, distinta da adaga
	# pelo pitch e ganho. Substitui o Slashkut, cujo pico era tímido.
	&"quick_blade": [29.25, 29.70, 1.18, 1.25],
	&"metal_hit": [8.18, 8.60, 0.96, 1.08],
	&"sword_schwing": [10.22, 10.50, 0.88, 1.00],
	&"laser_gun": [12.00, 12.50, 1.0, 1.10],
	&"electric_zap": [14.11, 14.80, 1.0, 1.25],
	&"awwow_impact": [16.08, 16.50, 1.04, 1.10],
	&"punch_whoosh": [18.45, 19.10, 0.86, 1.00],
	&"knife_slice": [20.25, 20.80, 1.5, 1.10],
	&"gun": [22.00, 23.40, 1.0, 1.00],
	&"box": [26.36, 27.00, 1.0, 1.00],
	&"knife_stab": [29.25, 29.70, 1.0, 1.10],
	&"awesome_kick": [30.20, 30.50, 1.04, 1.08],
	&"cigarette": [32.05, 33.10, 1.0, 1.20],
	&"wing": [38.18, 43.50, 1.0, 1.00],
	&"steps_hostile": [46.25, 50.30, 1.10, 1.00],
	&"steps_female": [54.31, 59.20, 1.10, 1.00],
	&"steps_male": [60.40, 66.60, 1.10, 1.00],
	&"steps_armored": [72.00, 80.00, 0.90, 1.10],
}

# Recursos en_000XX: Maestria efetiva -> grupo. Maestrias variáveis mantêm
# as opções do Resource; o override sorteado decide qual coluna usar.
const ENEMY_GROUPS := {
	&"en_00003": {2: &"B", 3: &"B"},
	&"en_00004": {2: &"B"},
	&"en_00005": {0: &"B"},
	&"en_00006": {1: &"A"},
	&"en_00007": {1: &"B"},
	&"en_00008": {2: &"A"},
	&"en_00009": {1: &"B", 2: &"B", 3: &"B"},
	&"en_00010": {1: &"B"},
	&"en_00011": {3: &"A"},
	&"en_00012": {3: &"B"},
	&"en_00013": {1: &"A"},
	&"en_00014": {0: &"B"},
	&"en_00015": {1: &"A"},
	&"en_00016": {2: &"C"},
	&"en_00017": {3: &"A"},
	&"en_00018": {2: &"B"},
	&"en_00019": {1: &"B", 3: &"B"},
	&"en_00020": {0: &"A"},
	&"en_00021": {0: &"B"},
	&"en_00022": {1: &"B"},
	&"en_00023": {1: &"A"},
	&"en_00024": {1: &"B"},
	&"en_00025": {3: &"A"},
	&"en_00026": {2: &"B"},
	&"en_00027": {0: &"B"},
	&"en_00028": {3: &"B"},
	&"en_00029": {1: &"A"},
	&"en_00030": {1: &"B"},
	&"en_00031": {0: &"B", 1: &"B", 2: &"B", 3: &"B"},
	&"en_00032": {1: &"B", 2: &"B"},
	&"en_00033": {0: &"A"},
	&"en_00034": {3: &"B"},
}

const ITEM_ATTACKS := {
	&"aa_00001": &"knife_stab", # Adaga de Sombra e Luz
	&"aa_00002": &"awwow_impact", # Arco da Precisão
	&"aa_00003": &"metal_hit", # Bastão do Guardião
	&"aa_00004": &"gun", # Bumerangue Teleguiado
	&"aa_00005": &"box", # Espada Congelante
	&"aa_00006": &"box", # Espada Flamejante
	&"aa_00007": &"punch_whoosh", # Martelo de Guerra
	&"aa_00008": &"awesome_kick", # Cabo de Vassoura
	&"aa_00009": &"laser_gun", # Chinelo
	&"aa_00010": &"awwow_impact", # Estilingue: distância leve
	&"aa_00011": &"quick_blade", # Faca
	&"aa_00012": &"awesome_kick", # Martelo comum
	&"aa_00013": &"quick_blade", # Tesoura
	&"aa_00014": &"cigarette", # Espada Irada Eletrizante
}


static func clip(id: StringName) -> Dictionary:
	var resolved := id if CLIPS.has(id) else &"punch"
	var values: Array = CLIPS[resolved]
	return {"id": resolved, "start": float(values[0]), "end": float(values[1]),
		"pitch": float(values[2]), "gain": float(values[3])}


static func effective_mastery(actor: EntityState) -> int:
	if actor == null or actor.data == null:
		return EntityData.Mastery.NONE
	if actor.encounter_mastery_override != EntityData.Mastery.NONE:
		return actor.encounter_mastery_override
	for mastery in actor.data.maestrias:
		if mastery != EntityData.Mastery.NONE:
			return mastery
	return EntityData.Mastery.NONE


static func attack(actor: EntityState, alternation: int = 0) -> Dictionary:
	if actor == null:
		return clip(&"punch")
	var equipped := actor.primary_equipped(ItemData.EquipmentSlot.WEAPON)
	if equipped != null and equipped.data != null:
		var item_id := equipped.data.id
		if ITEM_ATTACKS.has(item_id):
			var item_sound := clip(ITEM_ATTACKS[item_id])
			if item_id == &"aa_00008":
				# O golpe curto do Cabo de Vassoura precisa atravessar a rádio:
				# mesmo trecho do martelo comum, porém mais grave e presente.
				item_sound["pitch"] = 0.84
				item_sound["gain"] = 1.75
			return item_sound
		# Uma arma nova sem trecho específico ainda conserva o seu tipo.
		return _mastery_attack(equipped.data.mastery_granted, &"A")
	if actor.data != null and actor.data.id == &"en_00002":
		var cat_blade := clip(&"quick_blade")
		cat_blade["pitch"] = 1.24
		return cat_blade
	if actor.data != null and actor.data.id == &"en_00001":
		var dog_blade := clip(&"sword_schwing")
		dog_blade["pitch"] = 1.05
		return dog_blade
	var is_playable := actor.data != null and &"jogavel" in actor.data.tags
	if is_playable:
		return clip(&"quick_swoosh" if alternation % 2 == 1 else &"punch")
	var mastery := effective_mastery(actor)
	var groups: Dictionary = ENEMY_GROUPS.get(actor.data.id, {}) if actor.data != null else {}
	var group: StringName = groups.get(mastery, &"A")
	return _mastery_attack(mastery, group)


static func _mastery_attack(mastery: int, group: StringName) -> Dictionary:
	match mastery:
		EntityData.Mastery.BLADE:
			return clip(&"sword_schwing" if group == &"B" else &"quick_blade")
		EntityData.Mastery.IMPACT:
			return clip(&"awesome_kick" if group == &"C" else
				&"punch_whoosh" if group == &"B" else &"metal_hit")
		EntityData.Mastery.RANGED:
			return clip(&"gun" if group == &"B" else &"awwow_impact")
	return clip(&"quick_swoosh" if group == &"B" else &"punch")


static func movement(actor: EntityState) -> Dictionary:
	if actor == null or actor.data == null:
		return clip(&"steps_hostile")
	var data := actor.data
	var result: Dictionary
	if data.id == &"en_00027":
		result = clip(&"electric_zap")
	elif &"voador" in data.tags or &"voar" in data.tags:
		result = clip(&"wing")
		if data.id == &"en_00005":
			result["pitch"] = 1.2
	elif &"criatura" in data.tags or data.id in [&"en_00001", &"en_00002",
			&"en_00006"]:
		result = clip(&"knife_slice")
	elif data.id in [&"pj_00002", &"pj_00003", &"pj_00005", &"pj_00007"]:
		result = clip(&"steps_female")
	elif &"jogavel" in data.tags or data.id == &"en_00004":
		result = clip(&"steps_male")
	elif &"humanoide" in data.tags:
		result = clip(&"steps_hostile")
	else:
		result = clip(&"steps_hostile")
	if data.id in [&"en_00033", &"en_00034"]:
		result["pitch"] = 0.8
	if &"jogavel" in data.tags:
		for armor in actor.equipped_armors:
			if armor != null and armor.data != null and armor.data.id == &"ar_00002":
				result = clip(&"steps_armored")
				break
	return result
