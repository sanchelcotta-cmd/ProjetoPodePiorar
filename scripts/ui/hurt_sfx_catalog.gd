class_name HurtSFXCatalog
extends RefCounted

## Trechos da folha hurt_hurt.wav. Os IDs são dos Resources, nunca dos slots.
const SEGMENTS := {
	&"pj_00001": Vector2(8.3, 8.7), # Cozinheiro
	&"pj_00002": Vector2(8.3, 8.7), # Jornalista
	&"pj_00003": Vector2(0.0, 0.3), # Mãe
	&"pj_00004": Vector2(12.3, 12.7), # Pedreiro
	&"pj_00005": Vector2(0.0, 0.3), # Professora
	&"pj_00006": Vector2(6.4, 6.7), # Universitário
	&"pj_00007": Vector2(4.3, 4.7), # Velha
	&"en_00001": Vector2(16.4, 16.7), # Doguinho
	&"en_00002": Vector2(18.4, 18.7), # Gatinho
	&"en_00003": Vector2(18.4, 18.7), # Aranha
	&"en_00004": Vector2(10.4, 10.7), # A Experiência
	&"en_00005": Vector2(18.4, 18.7), # Barata
	&"en_00006": Vector2(34.4, 34.7), # Bonequinha
	&"en_00007": Vector2(16.4, 16.7), # Cão Infernal
	&"en_00008": Vector2(24.4, 24.7), # Capanga
	&"en_00009": Vector2(14.4, 14.7), # Cobaia
	&"en_00010": Vector2(22.3, 22.7), # Criatura
	&"en_00011": Vector2(2.2, 2.5), # Cultista
	&"en_00012": Vector2(2.2, 2.5), # Dama
	&"en_00013": Vector2(32.4, 32.7), # Diabretes
	&"en_00014": Vector2(32.4, 32.7), # Esfera
	&"en_00015": Vector2(32.4, 32.7), # Goblin 1
	&"en_00016": Vector2(34.4, 34.7), # Goblin 2
	&"en_00017": Vector2(28.4, 28.7), # Goblin 3
	&"en_00018": Vector2(24.4, 24.7), # Guarda
	&"en_00019": Vector2(26.4, 26.7), # Homem de Preto
	&"en_00020": Vector2(20.4, 20.7), # Mímico 1
	&"en_00021": Vector2(20.4, 20.7), # Mímico 2
	&"en_00022": Vector2(24.4, 24.7), # Palhaço
	&"en_00023": Vector2(28.4, 28.7), # Pinscher
	&"en_00024": Vector2(36.55, 36.80), # Planta: ataque audível começa após 36.5
	&"en_00025": Vector2(30.4, 30.7), # Pomba
	&"en_00026": Vector2(36.55, 36.80), # Raízes
	&"en_00027": Vector2(18.4, 18.7), # Rato
	&"en_00028": Vector2(6.4, 6.7), # Servo 1
	&"en_00029": Vector2(6.4, 6.7), # Servo 2
	&"en_00030": Vector2(24.4, 24.7), # Sombra Disforme
	&"en_00031": Vector2(20.4, 20.7), # Versão do mal
	&"en_00032": Vector2(26.4, 26.7), # Vilão
	&"en_00033": Vector2(38.0, 38.4), # Zumbi dançarino
	&"en_00034": Vector2(38.0, 38.4), # Zumbi gosma
}

# Equalização leve por trecho; os dois últimos gritos vêm especialmente baixos
# na folha original. O limitador do bus CombatSFX protege o pico final.
const GAIN_BY_START := {
	2.2: 1.4, 8.3: 1.25, 12.3: 1.4, 14.4: 1.5,
	16.4: 1.35, 20.4: 1.9, 22.3: 1.9, 24.4: 1.8,
	26.4: 1.7, 36.55: 5.0, 38.0: 4.0,
}


static func for_actor(actor: EntityState) -> Dictionary:
	if actor == null or actor.data == null or not SEGMENTS.has(actor.data.id):
		return {}
	var segment: Vector2 = SEGMENTS[actor.data.id]
	var pitch := 1.15 if actor.data.id in [&"en_00001", &"en_00002"] else 1.10
	return {"start": segment.x, "end": segment.y, "pitch": pitch,
		"gain": float(GAIN_BY_START.get(segment.x, 1.0))}
