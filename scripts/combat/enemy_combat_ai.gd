class_name EnemyCombatAI
extends RefCounted

## IA compartilhada de ataque convencional. Não executa Skills especiais:
## CombatManager entrega o turno e aplica dano/gatilhos depois da decisão.

const RETALIATION_RATIO := 0.40


func choose_target(enemy: EntityState, opponents: Array[EntityState],
		skill_manager: SkillManager, retaliation: Dictionary,
		rng: RandomNumberGenerator) -> EntityState:
	var alive: Array[EntityState] = []
	for opponent in opponents:
		if opponent != null and opponent.current_health > 0 \
				and opponent.position != EntityState.UNPLACED:
			alive.append(opponent)
	if alive.is_empty():
		return null
	var lowest_health := 999999
	for opponent in alive:
		lowest_health = mini(lowest_health, opponent.current_health)
	var best_score := -999999
	var tied: Array[EntityState] = []
	for opponent in alive:
		var score := threat_score(enemy, opponent, lowest_health,
			skill_manager, retaliation)
		if score > best_score:
			best_score = score
			tied.clear()
		if score == best_score:
			tied.append(opponent)
	return tied[rng.randi_range(0, tied.size() - 1)] if rng != null else tied.pick_random()


func threat_score(enemy: EntityState, opponent: EntityState, lowest_health: int,
		skill_manager: SkillManager, retaliation: Dictionary) -> int:
	var distance := HexGrid.distance(enemy.position, opponent.position)
	var score := 250 if distance == 1 else maxi(20, 120 - distance * 10)
	if opponent.current_health == lowest_health:
		score += 12
	if retaliation.has(opponent.instance_id):
		score += 35
	if skill_manager != null:
		for entry in skill_manager.get_continuous_effects(opponent,
				SkillEffectData.EffectType.FORCE_TARGET_PRIORITY):
			score += (entry["effect"] as SkillEffectData).amount
		for grant in skill_manager.get_passive_grants(opponent):
			var passive := grant.skill as PassiveSkillData
			if passive == null or &"archenemy" not in passive.tags:
				continue
			var bound := grant.bound_source as EntityData
			if bound != null and enemy.data != null and bound.id == enemy.data.id:
				score += 500
				break # Duas passivas do mesmo vínculo não duplicam a preferência.
	return score


## Caminhos de até max_steps sem atravessar hexes ocupados. A origem pode
## ser StartZone externa; seu primeiro passo custa 1 como na Exploração.
func reachable_paths(grid: HexGrid, origin: Vector2i, max_steps: int,
		occupied: Dictionary) -> Dictionary:
	var paths: Dictionary = {}
	if grid == null or max_steps < 0:
		return paths
	var queue: Array[Vector2i] = []
	if grid.is_valid(origin):
		paths[origin] = []
		queue.append(origin)
	elif grid.is_ppp_start_zone(origin) and max_steps > 0:
		var entry := grid.get_ppp_start_entry(origin)
		if grid.can_traverse_ppp(entry) and not occupied.has(entry):
			paths[entry] = [entry]
			queue.append(entry)
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var path: Array = paths[current]
		if path.size() >= max_steps:
			continue
		for neighbor in HexGrid.get_neighbors(current):
			if not grid.can_traverse_ppp(neighbor) or occupied.has(neighbor) \
					or paths.has(neighbor):
				continue
			var next_path := path.duplicate()
			next_path.append(neighbor)
			paths[neighbor] = next_path
			queue.append(neighbor)
	return paths


## Aproxima-se do alvo fixado. Não troca de alvo se o caminho estiver ruim.
func choose_melee_position(enemy: EntityState, target: EntityState,
		paths: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var current_distance := HexGrid.distance(enemy.position, target.position)
	if current_distance <= 1:
		return enemy.position
	var best_distance := current_distance
	var best_cost := 999
	var tied: Array[Vector2i] = []
	for coord in paths:
		var distance := HexGrid.distance(coord, target.position)
		var cost := (paths[coord] as Array).size()
		if cost == 0:
			continue
		if distance < best_distance or (distance == best_distance and cost < best_cost):
			best_distance = distance
			best_cost = cost
			tied.clear()
		if distance == best_distance and cost == best_cost:
			tied.append(coord)
	return (tied[rng.randi_range(0, tied.size() - 1)] if rng != null else tied.pick_random()) \
		if not tied.is_empty() else enemy.position


## Primeiro procura um disparo seguro (ninguém adjacente), depois qualquer
## posição que permita disparar. Sem disparo possível, aproxima-se do alvo.
func choose_ranged_position(enemy: EntityState, target: EntityState,
		opponents: Array[EntityState], paths: Dictionary, attack_range: int,
		rng: RandomNumberGenerator) -> Vector2i:
	var best: Array[Vector2i] = []
	var best_rank := Vector3i(-1, -999, -999)
	for coord in paths:
		var target_distance := HexGrid.distance(coord, target.position)
		if target_distance > attack_range:
			continue
		var nearest := 999
		for opponent in opponents:
			if opponent != null and opponent.current_health > 0:
				nearest = mini(nearest, HexGrid.distance(coord, opponent.position))
		var cost := (paths[coord] as Array).size()
		var rank := Vector3i(1 if nearest >= 2 else 0, -cost, nearest)
		if rank.x > best_rank.x or (rank.x == best_rank.x and rank.y > best_rank.y) \
				or (rank.x == best_rank.x and rank.y == best_rank.y and rank.z > best_rank.z):
			best_rank = rank
			best.clear()
		if rank == best_rank:
			best.append(coord)
	if not best.is_empty():
		return best[rng.randi_range(0, best.size() - 1)] if rng != null else best.pick_random()
	return choose_melee_position(enemy, target, paths, rng)
