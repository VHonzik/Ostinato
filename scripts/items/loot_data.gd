class_name LootData
extends RefCounted

## Per-source RNG never consumes combat/wandering randomness (FR-028).
static func assign(world: GridWorld, source: GridActor) -> void:
	if source.loot_assigned:
		return
	source.loot_assigned = true
	var generator := RandomNumberGenerator.new()
	generator.seed = world.seed_value ^ int(source.spawn_id.hash()) ^ 32452843
	if source.loot_table == 161557:
		if world.loot_quests.has("3904"):
			source.loot.append(ItemData.instance(11119))
	elif source.chest:
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
	elif source.loot_table in [6, 257, 80, 38, 103]:
		var profile: Dictionary = NorthshireData.CREATURES[str(source.loot_table)]
		source.loot_copper = generator.randi_range(int(profile.copper_min), int(profile.copper_max))
		var quest := "18" if source.loot_table == 38 else "6"
		var item := 752 if source.loot_table == 38 else 182
		var rolled := generator.randf() < (0.8 if source.loot_table == 38 else 1.0)
		if source.loot_table in [38, 103] and rolled and world.loot_quests.has(quest):
			source.loot.append(ItemData.instance(item))


static func collectable(world: GridWorld, item: Dictionary) -> bool:
	var quest: String = ItemData.get_item(int(item.id)).quest
	return quest == "" or world.loot_quests.has(quest)
