class_name LootData
extends RefCounted

## Per-source RNG never consumes combat/wandering randomness (FR-028).
static func assign(world: GridWorld, source: GridActor) -> void:
	if source.loot_assigned:
		return
	source.loot_assigned = true
	var generator := RandomNumberGenerator.new()
	generator.seed = world.seed_value ^ int(source.spawn_id.hash()) ^ 32452843
	if source.chest:
		# Training-ground supplies, explicitly adapted fixture table (DATA-004 M5).
		source.loot_copper = generator.randi_range(350, 450)
		source.loot.append(ItemData.instance(4560 if generator.randi_range(0, 1) == 0 else 2139))
		source.loot.append(ItemData.instance(85))
		source.loot.append(ItemData.instance(118, 2))
		source.loot.append(ItemData.instance(2572))
	elif source.loot_table in [69, 299]:
		var chances := [38.3399, 38.3736, 39.122] if source.loot_table == 69 else [37.8937, 37.7572, 36.9481]
		for index in range(3):
			var roll := generator.randf() * 100.0
			var quantity := generator.randi_range(1, 2)
			if roll < chances[index]:
				source.loot.append(ItemData.instance([7073, 7074, 4865][index], quantity))
		# Roll independently even when the quest is ineligible.
		if generator.randf() < 0.8 and world.loot_quests.has("wolves"):
			source.loot.append(ItemData.instance(750))


static func collectable(world: GridWorld, item: Dictionary) -> bool:
	var quest: String = ItemData.get_item(int(item.id)).quest
	return quest == "" or world.loot_quests.has(quest)
