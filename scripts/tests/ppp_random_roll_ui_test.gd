extends SceneTree

var failures := 0


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	root.size = Vector2i(1152, 648)
	var game := load("res://teste.tscn").instantiate() as PPPMapView
	check(game != null, "Cena de jogo deve carregar.")
	if game == null:
		quit(1)
		return
	root.add_child(game)
	await process_frame
	check(game.get_node_or_null("RandomRollUI") == null,
		"A moeda provisória não aparece mais na lateral do mapa.")

	var seed_a := RandomNumberGenerator.new()
	var seed_b := RandomNumberGenerator.new()
	seed_a.seed = 9042
	seed_b.seed = 9042
	var values := D6Roller.roll_many(3, seed_a)
	check(values.size() == 3 and values.all(func(value: int) -> bool: return value >= 1 and value <= 6),
		"D6 sempre devolve valores individuais de 1 a 6.")
	check(values == D6Roller.roll_many(3, seed_b),
		"A fonte de aleatoriedade pode ser injetada para testes e regras.")
	check(CoinFlip.flip(seed_a) in [CoinFlip.Side.A, CoinFlip.Side.B],
		"Cara ou coroa devolve apenas A ou B.")
	check_player_luck_rule()

	var options: Array[StringName] = [&"cara", &"coroa"]
	var flip_result := CoinFlip.resolve_guess(options, &"cara", seed_a)
	check(flip_result.get("success", false) and flip_result.get("coin_result") in options
		and flip_result.get("guessed") == (flip_result.get("coin_result") == &"cara"),
		"A moeda reutilizável compara o palpite com um resultado A/B.")
	check(not CoinFlip.resolve_guess(options, &"invalido", seed_a).get("success", false),
		"Palpites fora das duas faces cadastradas não são aceitos.")
	if failures == 0:
		print("RANDOM_ROLL_UI_TEST_OK")
	quit(1 if failures > 0 else 0)


func check_player_luck_rule() -> void:
	var search_rng := RandomNumberGenerator.new()
	var streak_seed := -1
	for candidate in 10000:
		search_rng.seed = candidate
		var five_lows := true
		for index in 5:
			if D6Roller.roll(search_rng) > 2:
				five_lows = false
				break
		if five_lows:
			streak_seed = candidate
			break
	check(streak_seed >= 0, "Teste encontra sequência de cinco dados baixos.")
	if streak_seed < 0:
		return
	var player_rng := RandomNumberGenerator.new()
	player_rng.seed = streak_seed
	var luck := D6Roller.new()
	for index in 5:
		check(luck.roll_for_player(player_rng) <= 2,
			"Os cinco resultados da sequência são 1 ou 2.")
	check(luck.favored_rolls_remaining == 4 and luck.consecutive_low_rolls == 0,
		"O quinto resultado baixo ativa exatamente quatro próximas rolagens favorecidas.")
	var next_result := luck.roll_for_player(player_rng)
	check(luck.favored_rolls_remaining == (0 if next_result == 6 else 3),
		"A rolagem que ativa a sorte não gasta uma das quatro chances futuras.")
	luck.reset()
	check(luck.favored_rolls_remaining == 0 and luck.consecutive_low_rolls == 0,
		"Iniciar uma nova campanha pode zerar a sorte antiga.")

	var six_seed := -1
	var four_without_six_seed := -1
	for candidate in 10000:
		search_rng.seed = candidate
		var first_slot := search_rng.randi_range(0, 11)
		if first_slot >= 9 and six_seed < 0:
			six_seed = candidate
		if first_slot >= 9:
			continue
		var no_six := true
		for index in 3:
			if search_rng.randi_range(0, 11) >= 9:
				no_six = false
				break
		if no_six:
			four_without_six_seed = candidate
		if six_seed >= 0 and four_without_six_seed >= 0:
			break
	check(six_seed >= 0 and four_without_six_seed >= 0,
		"Teste encontra os dois caminhos de término da sorte.")
	if six_seed < 0 or four_without_six_seed < 0:
		return
	var early_end := D6Roller.new()
	early_end.favored_rolls_remaining = 4
	player_rng.seed = six_seed
	check(early_end.roll_for_player(player_rng) == 6
		and early_end.favored_rolls_remaining == 0,
		"Sair 6 encerra a sorte imediatamente, sem esperar as quatro rolagens.")
	var full_end := D6Roller.new()
	full_end.favored_rolls_remaining = 4
	player_rng.seed = four_without_six_seed
	for index in 4:
		check(full_end.roll_for_player(player_rng) != 6,
			"O teste de quatro rolagens não contém 6.")
	check(full_end.favored_rolls_remaining == 0,
		"Depois da quarta rolagem, a sorte termina sem forçar um 6.")

	var boosted_count := 0
	var sample := D6Roller.new()
	player_rng.seed = 54321
	for index in 12000:
		sample.favored_rolls_remaining = 1
		if sample.roll_for_player(player_rng) >= 4:
			boosted_count += 1
	check(boosted_count >= 8760 and boosted_count <= 9240,
		"As chances de 4, 5 ou 6 devem ficar perto de 75%, não de 50%.")
	check_enemy_luck_rule()


func check_enemy_luck_rule() -> void:
	var search_rng := RandomNumberGenerator.new()
	var streak_seed := -1
	for candidate in 10000:
		search_rng.seed = candidate
		var five_highs := true
		for index in 5:
			if D6Roller.roll(search_rng) < 5:
				five_highs = false
				break
		if five_highs:
			streak_seed = candidate
			break
	check(streak_seed >= 0, "Teste encontra sequência de cinco dados altos.")
	if streak_seed < 0:
		return
	var enemy_rng := RandomNumberGenerator.new()
	enemy_rng.seed = streak_seed
	var luck := D6Roller.new()
	for index in 5:
		check(luck.roll_for_enemy(enemy_rng) >= 5,
			"Os cinco resultados da sequência inimiga são 5 ou 6.")
	check(luck.enemy_low_bias_rolls_remaining == 4 and luck.consecutive_high_rolls == 0,
		"O quinto resultado alto ativa quatro próximas rolagens enfraquecidas.")
	var next_result := luck.roll_for_enemy(enemy_rng)
	check(luck.enemy_low_bias_rolls_remaining == (0 if next_result == 1 else 3),
		"O bônus contrário termina cedo com 1, sem forçar o resultado.")

	var one_seed := -1
	var four_without_one_seed := -1
	for candidate in 10000:
		search_rng.seed = candidate
		var first_slot := search_rng.randi_range(0, 11)
		if first_slot < 3 and one_seed < 0:
			one_seed = candidate
		if first_slot < 3:
			continue
		var no_one := true
		for index in 3:
			if search_rng.randi_range(0, 11) < 3:
				no_one = false
				break
		if no_one:
			four_without_one_seed = candidate
		if one_seed >= 0 and four_without_one_seed >= 0:
			break
	check(one_seed >= 0 and four_without_one_seed >= 0,
		"Teste encontra as duas formas de término da sorte inimiga.")
	if one_seed < 0 or four_without_one_seed < 0:
		return
	var early_end := D6Roller.new()
	early_end.enemy_low_bias_rolls_remaining = 4
	enemy_rng.seed = one_seed
	check(early_end.roll_for_enemy(enemy_rng) == 1
		and early_end.enemy_low_bias_rolls_remaining == 0,
		"Sair 1 encerra o benefício contrário imediatamente.")
	var full_end := D6Roller.new()
	full_end.enemy_low_bias_rolls_remaining = 4
	enemy_rng.seed = four_without_one_seed
	for index in 4:
		check(full_end.roll_for_enemy(enemy_rng) != 1,
			"O teste de quatro rolagens inimigas não contém 1.")
	check(full_end.enemy_low_bias_rolls_remaining == 0,
		"O efeito inimigo termina após a quarta rolagem, sem forçar um 1.")

	var weak_count := 0
	var sample := D6Roller.new()
	enemy_rng.seed = 67890
	for index in 12000:
		sample.enemy_low_bias_rolls_remaining = 1
		if sample.roll_for_enemy(enemy_rng) <= 3:
			weak_count += 1
	check(weak_count >= 8760 and weak_count <= 9240,
		"A chance inimiga de 1, 2 ou 3 fica perto de 75%.")


func check_no_hex_overlap(game: PPPMapView, ui: RandomRollUI) -> void:
	var panel := ui.get_node("RollContainer") as Control
	var panel_rect := panel.get_global_rect()
	var hexes := game.get_node("MapRoot/Hexes") as Node2D
	for hex in hexes.get_children():
		var hex_node := hex as Node2D
		var outline := hex_node.get_node("Outline") as Sprite2D
		var size := Vector2(outline.texture.get_size()) * outline.scale
		var bounds := Rect2(hex_node.global_position - size * 0.5, size)
		check(not panel_rect.intersects(bounds),
			"As caixas, inclusive A/B, não podem cobrir o hex %s." % hex_node.name)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
