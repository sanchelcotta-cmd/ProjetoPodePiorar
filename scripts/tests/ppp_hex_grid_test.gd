extends SceneTree

## Rodar com: godot --headless --path . --script res://scripts/tests/ppp_hex_grid_test.gd
var failures := 0


func _initialize() -> void:
	var grid := HexGrid.new()
	grid.generate_ppp_exploration_map()
	check(HexGrid.PPPBlockType.INFORMATION == 1 and HexGrid.PPPBlockType.CURSE == 8, "números dos tipos de bloco não podem mudar")
	check(grid.cells.size() == 40, "o mapa precisa ter 40 blocos")
	check(grid.get_ppp_start_positions().size() == 3, "a StartZone precisa ter 3 vagas")

	var start := Vector2i(-1, 2)
	check(grid.get_ppp_reachable_hexes(start, 0).is_empty(), "entrar no mapa custa 1 Stamina")
	var one_step := grid.get_ppp_reachable_hexes(start, 1)
	check(one_step.size() == 1 and one_step.get(Vector2i(0, 2), -1) == 1, "primeiro passo da StartZone")
	check(grid.get_ppp_movement_path(start, Vector2i(0, 2), 1) == [Vector2i(0, 2)], "caminho de entrada")

	var used := Vector2i(1, 2)
	grid.activate_ppp_block(used)
	check(not grid.can_choose_ppp_destination(used, Vector2i(0, 2)), "bloco usado não é destino na Exploração")
	check(grid.get_ppp_reachable_hexes(Vector2i(0, 2), 2).has(used), "bloco usado continua atravessável")
	grid.ppp_map_mode = HexGrid.PPPMapMode.COMBAT
	check(grid.can_choose_ppp_destination(used, Vector2i(0, 2)), "bloco usado pode ser destino no Combate")
	var occupied: Dictionary = {}
	occupied[used] = true
	check(not grid.can_choose_ppp_destination(used, Vector2i(0, 2), occupied), "entidade ocupando destino impede parar")
	grid.destroy_ppp_block(used)
	check(grid.can_choose_ppp_destination(used, Vector2i(0, 2)), "bloco destruído continua selecionável no Combate")

	check(grid.get_ring(Vector2i(3, 2), 1).size() == 6, "cada hex central tem seis vizinhos")
	grid.ppp_background_path = "res://sprites/background/cena_suburbio_0002.png"
	var restored := HexGrid.deserialize(grid.serialize())
	check(restored.cells.size() == 40, "salvar e carregar mantém 40 blocos")
	check(restored.get_ppp_block_data(used).get("state") == HexGrid.PPPBlockState.DESTROYED, "salvar e carregar mantém estado")
	check(restored.ppp_background_path == grid.ppp_background_path,
		"salvar e carregar mantém o cenário sorteado para este mapa")

	if failures == 0:
		print("PPP HexGrid: testes passaram")
	else:
		push_error("PPP HexGrid: %d teste(s) falharam" % failures)
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
