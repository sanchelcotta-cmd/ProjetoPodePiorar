class_name CombatLootResolver
extends RefCounted

## Uma rolagem por vitória elegível. Resources do catálogo nunca são alterados.
const ITEM_DIRECTORY := "res://resources/itens"
static var _catalog_cache: Dictionary = {}


static func roll(district: StringName, damage_taken: int, entry_max_health: int,
		rng: RandomNumberGenerator) -> Dictionary:
	if rng == null:
		return {"success": false, "reason": "Sorteador de saque indisponível."}
	var pools := _catalog()
	if pools["equipment"].is_empty() or pools["consumable"].is_empty() \
			or pools["rare_consumable"].is_empty():
		return {"success": false, "reason": "Catálogo de saque inimigo incompleto."}
	var chance := 0.0
	var count := 0
	match district:
		&"suburbio":
			chance = 0.60
			count = 1
		&"baixo_centro":
			chance = 0.80
			count = rng.randi_range(1, 2)
		&"centro":
			chance = 1.0
			count = 3
		_:
			return {"success": false, "reason": "Distrito de saque inválido."}
	var items: Array[ItemData] = []
	var regular_success := chance >= 1.0 or rng.randf() < chance
	if regular_success:
		# No Centro há exatamente três itens: dois livres e o terceiro
		# Consumível garantido, sem rolagem adicional por dano sofrido.
		for index in (count - 1 if district == &"centro" else count):
			items.append(_pick_consumable(pools, rng) if rng.randf() < 0.5 \
				else _pick(pools["equipment"], rng))
		if district == &"centro":
			items.append(_pick_consumable(pools, rng))
	var damage_bonus := district != &"centro" and entry_max_health > 0 \
		and damage_taken * 5 > entry_max_health * 2
	if damage_bonus:
		items.append(_pick_consumable(pools, rng))
	return {"success": true, "items": items, "regular_success": regular_success,
		"damage_bonus": damage_bonus,
		"guaranteed_consumable": district == &"centro"}


static func _pick_consumable(pools: Dictionary,
		rng: RandomNumberGenerator) -> ItemData:
	return _pick(pools["rare_consumable"] if rng.randf() < 0.02 \
		else pools["consumable"], rng)


static func _pick(pool: Array, rng: RandomNumberGenerator) -> ItemData:
	return pool[rng.randi_range(0, pool.size() - 1)] as ItemData


static func _catalog() -> Dictionary:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	var pools := {"equipment": [], "consumable": [], "rare_consumable": []}
	for path in _item_paths(ITEM_DIRECTORY):
		var item := load(path) as ItemData
		if item == null or item.id == &"" \
				or item.acquisition_sources & ItemData.AcquisitionSource.ENEMY_LOOT == 0:
			continue
		if item.item_type == ItemData.ItemType.EQUIPMENT \
				and item.rarity == ItemData.Rarity.COMMON:
			pools["equipment"].append(item)
		elif item.item_type == ItemData.ItemType.CONSUMABLE:
			if item.rarity == ItemData.Rarity.RARE:
				pools["rare_consumable"].append(item)
			elif item.rarity in [ItemData.Rarity.COMMON, ItemData.Rarity.UNCOMMON]:
				pools["consumable"].append(item)
	_catalog_cache = pools
	return _catalog_cache


static func _item_paths(directory: String) -> Array[String]:
	var paths: Array[String] = []
	for filename in DirAccess.get_files_at(directory):
		if filename.ends_with(".tres"):
			paths.append(directory.path_join(filename))
	for folder in DirAccess.get_directories_at(directory):
		paths.append_array(_item_paths(directory.path_join(folder)))
	paths.sort()
	return paths
