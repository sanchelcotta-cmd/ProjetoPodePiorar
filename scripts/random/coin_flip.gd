class_name CoinFlip
extends RefCounted

## A e B representam os dois lados até existirem ícones de cara e coroa.
enum Side { A, B }


static func flip(rng: RandomNumberGenerator = null) -> int:
	var value := rng.randi_range(0, 1) if rng != null else randi_range(0, 1)
	return Side.A if value == 0 else Side.B


static func side_label(side: int) -> String:
	return "A" if side == Side.A else "B"


## Sorteia uma moeda para qualquer Evento com duas opções cadastradas.
## O palpite é validado aqui; a interface apenas anima A/B e mostra o resultado.
static func resolve_guess(options: Array[StringName], guess: StringName,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if options.size() != 2 or options[0] == options[1] or guess not in options:
		return {"success": false, "reason": "A moeda precisa de duas opções distintas e um palpite válido."}
	var side := flip(rng)
	var landed := options[side]
	return {"success": true, "guess": guess, "coin_result": landed,
		"coin_side": side, "guessed": guess == landed}
