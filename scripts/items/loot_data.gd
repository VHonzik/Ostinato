class_name LootData
extends RefCounted

const DEVELOPMENT_SUPPLIES: int = -1


## Per-source RNG never consumes combat/wandering randomness.
static func assign(world: GridWorld, source: GridActor) -> void:
	if source.loot_assigned:
		return
	source.loot_assigned = true
	var generator := RandomNumberGenerator.new()
	generator.seed = world.seed_value ^ int(source.spawn_id.hash()) ^ 32452843
	if source.chest and source.loot_table == DEVELOPMENT_SUPPLIES:
		# Only the isolated movement fixture can expose the historical M5 supplies.
		if world.northshire or not OS.is_debug_build():
			return
		source.loot_copper = generator.randi_range(350, 450)
		source.loot.append(ItemData.instance(4560 if generator.randi_range(0, 1) == 0 else 2139))
		source.loot.append(ItemData.instance(85))
		source.loot.append(ItemData.instance(118, 2))
		source.loot.append(ItemData.instance(2572))
		return
	var key := str(source.loot_table)
	if not NorthshireLoot.TABLES.has(key):
		return
	if source.chest and source.loot_table == 2843:
		source.loot_copper = generator.randi_range(10, 20)
	elif not source.chest and NorthshireData.CREATURES.has(key):
		var profile: Dictionary = NorthshireData.CREATURES[key]
		source.loot_copper = generator.randi_range(int(profile.copper_min), int(profile.copper_max))
	var rolled := roll_table(NorthshireLoot.TABLES[key], generator)
	# Roll everything before filtering, so quest eligibility cannot shift ordinary rolls.
	for item in rolled:
		if collectable(world, item):
			source.loot.append(item)


## The bounded tables need independent rows, exclusive groups and two shared references.
## Keeping this traversal here avoids copying world-drop equipment into seven NPC tables.
static func roll_table(rows: Array, generator: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var groups: Dictionary = {}
	for row in rows:
		var group := int(row[2])
		if group > 0:
			if not groups.has(group):
				groups[group] = []
			groups[group].append(row)
		elif _percent(generator) < absf(float(row[1])):
			_append_row(result, row, generator)
	for group in groups:
		var selected := select_group(groups[group], _percent(generator))
		if not selected.is_empty():
			_append_row(result, selected, generator)
	return result


## Explicit chances occupy intervals; zero-chance rows share the remaining probability.
## Source item order is fixed, with strict upper bounds (e.g. 75% means [0, 75)).
static func select_group(rows: Array, percent: float) -> Array:
	var remainder := percent
	var equal: Array = []
	var total := 0.0
	for row in rows:
		var chance := absf(float(row[1]))
		if chance == 0.0:
			equal.append(row)
		else:
			total += chance
			if remainder < chance:
				return row
			remainder -= chance
	if not equal.is_empty() and total < 100.0:
		var index := mini(floori(remainder / (100.0 - total) * equal.size()), equal.size() - 1)
		return equal[index]
	return []


static func collectable(world: GridWorld, item: Dictionary) -> bool:
	var quest: String = ItemData.get_item(int(item.id)).quest
	return quest == "" or world.loot_quests.has(quest)


static func _append_row(result: Array[Dictionary], row: Array,
		generator: RandomNumberGenerator) -> void:
	var minimum := int(row[3])
	if minimum < 0:
		for repeat in range(int(row[4])):
			result.append_array(roll_table(NorthshireLoot.REFERENCES[str(-minimum)], generator))
	else:
		result.append(ItemData.instance(int(row[0]), generator.randi_range(minimum, int(row[4]))))


static func _percent(generator: RandomNumberGenerator) -> float:
	# Half-open [0, 100): guaranteed rows cannot fail on an inclusive randf endpoint.
	return float(generator.randi()) / 4294967296.0 * 100.0
