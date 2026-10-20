class_name D6Roller
extends RefCounted

## Dado de seis lados usado pelas regras do jogo. O resultado é sorteado aqui;
## a animação da interface apenas mostra esse resultado depois.
## Uma instância guardada na CampaignState acompanha a sorte do JOGADOR.
## Rolagens de inimigos usam roll() e não recebem esse benefício.
const STREAK_TO_TRIGGER := 5
const LUCK_ROLL_LIMIT := 4

var consecutive_low_rolls: int = 0
var favored_rolls_remaining: int = 0
var consecutive_high_rolls: int = 0
var enemy_low_bias_rolls_remaining: int = 0


static func roll(rng: RandomNumberGenerator = null) -> int:
	return rng.randi_range(1, 6) if rng != null else randi_range(1, 6)


## Após 5 resultados seguidos de 1 ou 2, as PRÓXIMAS 4 rolagens do jogador
## favorecem 4, 5 e 6: cada um tem peso 3; 1, 2 e 3 têm peso 1.
## A chance total de 4–6 é 9/12 = 75%. Um 6 encerra o bônus antes.
func roll_for_player(rng: RandomNumberGenerator = null) -> int:
	var favored := favored_rolls_remaining > 0
	var result := _roll_favored(rng) if favored else roll(rng)
	if favored:
		favored_rolls_remaining -= 1
		if result == 6:
			favored_rolls_remaining = 0
		# Durante o bônus, os resultados não criam outra sequência paralela.
		consecutive_low_rolls = 0
	elif result <= 2:
		consecutive_low_rolls += 1
		if consecutive_low_rolls >= STREAK_TO_TRIGGER:
			consecutive_low_rolls = 0
			favored_rolls_remaining = LUCK_ROLL_LIMIT
	else:
		consecutive_low_rolls = 0
	return result


## Espelho para os inimigos: 5 resultados seguidos de 5 ou 6 ativam até 4
## rolagens com 75% de chance total de 1, 2 ou 3. Um 1 encerra antes.
## A sequência é compartilhada entre todos os inimigos pela CampaignState.
func roll_for_enemy(rng: RandomNumberGenerator = null) -> int:
	var biased := enemy_low_bias_rolls_remaining > 0
	var result := _roll_enemy_low_bias(rng) if biased else roll(rng)
	if biased:
		enemy_low_bias_rolls_remaining -= 1
		if result == 1:
			enemy_low_bias_rolls_remaining = 0
		consecutive_high_rolls = 0
	elif result >= 5:
		consecutive_high_rolls += 1
		if consecutive_high_rolls >= STREAK_TO_TRIGGER:
			consecutive_high_rolls = 0
			enemy_low_bias_rolls_remaining = LUCK_ROLL_LIMIT
	else:
		consecutive_high_rolls = 0
	return result


func reset() -> void:
	consecutive_low_rolls = 0
	favored_rolls_remaining = 0
	consecutive_high_rolls = 0
	enemy_low_bias_rolls_remaining = 0


func _roll_favored(rng: RandomNumberGenerator) -> int:
	var slot := rng.randi_range(0, 11) if rng != null else randi_range(0, 11)
	if slot < 3:
		return slot + 1
	return 4 + floori(float(slot - 3) / 3.0)


func _roll_enemy_low_bias(rng: RandomNumberGenerator) -> int:
	var slot := rng.randi_range(0, 11) if rng != null else randi_range(0, 11)
	if slot < 9:
		return 1 + floori(float(slot) / 3.0)
	return 4 + slot - 9


## Retorna cada dado separadamente. Assim uma regra como Sangramento pode
## conhecer o valor bruto de um dado, mesmo se o dano final for diferente.
static func roll_many(count: int, rng: RandomNumberGenerator = null) -> Array[int]:
	var values: Array[int] = []
	for index in maxi(0, count):
		values.append(roll(rng))
	return values


static func roll_sum(count: int, rng: RandomNumberGenerator = null) -> int:
	var total := 0
	for value in roll_many(count, rng):
		total += value
	return total
