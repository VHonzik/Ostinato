class_name QuestRules
extends RefCounted

## Concrete quest transactions and objective updates.
static func available(world: GridWorld, identifier: String) -> bool:
	if not QuestData.QUESTS.has(identifier) or world.quests.has(identifier):
		return false
	var quest: Dictionary = QuestData.QUESTS[identifier]
	if world.hero.level < int(quest.minimum):
		return false
	if quest.category != "" and quest.category != String(world.hero.selected_class):
		return false
	for previous in quest.previous:
		if not world.quests.has(previous) or not world.quests[previous].handed_in:
			return false
	return true


static func in_range(world: GridWorld, actor: GridActor, identity: int) -> bool:
	return (actor != null and actor.alive and actor.npc_id == identity
		and actor.relationship == GridActor.Relationship.FRIENDLY
		and world.interaction_candidates().has(actor) and world.item_action_ready())


static func accept(world: GridWorld, identifier: String, actor: GridActor) -> bool:
	if not available(world, identifier):
		return false
	var quest: Dictionary = QuestData.QUESTS[identifier]
	if not in_range(world, actor, int(quest.giver)):
		return false
	var inventory := world.hero.inventory.duplicate(true)
	if int(quest.source_item) > 0:
		if not InventoryRules.add(inventory, ItemData.instance(int(quest.source_item))):
			world.add_message("Inventory full. Quest was not accepted.")
			return false
	var counts: Array[int] = []
	counts.resize(quest.objectives.size())
	counts.fill(0)
	world.hero.inventory.assign(inventory)
	world.quests[identifier] = {"handed_in": false, "counts": counts}
	world.loot_quests.append(identifier)
	world.ever_accepted_quest = true
	world.add_message("Accepted: " + String(quest.title))
	visit(world)
	return true


static func progress(world: GridWorld, identifier: String, index: int) -> int:
	var objective: Dictionary = QuestData.QUESTS[identifier].objectives[index]
	if objective.kind == "loot":
		var total := 0
		for item in world.hero.inventory:
			if not item.is_empty() and str(item.id) == objective.target:
				total += int(item.quantity)
		return mini(total, int(objective.count))
	return int(world.quests[identifier].counts[index])


static func ready(world: GridWorld, identifier: String) -> bool:
	if not world.quests.has(identifier) or world.quests[identifier].handed_in:
		return false
	var objectives: Array = QuestData.QUESTS[identifier].objectives
	for index in range(objectives.size()):
		if progress(world, identifier, index) < int(objectives[index].count):
			return false
	return true


static func event(world: GridWorld, kind: String, target: String) -> void:
	for identifier in world.quests:
		if world.quests[identifier].handed_in:
			continue
		var objectives: Array = QuestData.QUESTS[identifier].objectives
		for index in range(objectives.size()):
			var objective: Dictionary = objectives[index]
			if objective.kind == kind and objective.target == target:
				var old: int = world.quests[identifier].counts[index]
				world.quests[identifier].counts[index] = mini(old + 1, int(objective.count))
				if old < int(objective.count):
					world.add_message("%s: %d/%d %s." % [
						QuestData.QUESTS[identifier].title, old + 1, objective.count,
						objective_label(objective)])


static func visit(world: GridWorld) -> void:
	if world.northshire and Rect2i(43, 11, 3, 7).has_point(world.player_tile):
		event(world, "location", "gate_overlook")


static func hand_in(
	world: GridWorld, identifier: String, actor: GridActor, choice: int = 0
) -> bool:
	if not ready(world, identifier):
		return false
	var quest: Dictionary = QuestData.QUESTS[identifier]
	if not in_range(world, actor, int(quest.receiver)):
		return false
	if (not quest.choices.is_empty() and not quest.choices.has(choice)
		or quest.choices.is_empty() and choice != 0):
		return false
	var inventory := world.hero.inventory.duplicate(true)
	_remove_items(inventory, identifier)
	if choice > 0 and not InventoryRules.add(inventory, ItemData.instance(choice)):
		world.add_message("Inventory full. Make room before collecting your reward.")
		return false
	# Nothing changes until the complete reward fits.
	world.hero.inventory.assign(inventory)
	world.quests[identifier].handed_in = true
	_clear_loot(world, identifier)
	world.hero.copper += int(quest.copper)
	var xp := experience(int(quest.xp), int(quest.level), world.hero.level)
	world.add_message("Handed in %s: %d XP, %s." % [
		quest.title, xp, InventoryRules.money(int(quest.copper))])
	for level in world.hero.add_experience(xp):
		world.add_message("Level up! You are now level %d." % level)
	return true


static func abandon(world: GridWorld, identifier: String) -> bool:
	if (not world.item_action_ready() or not world.quests.has(identifier)
		or world.quests[identifier].handed_in):
		return false
	_remove_items(world.hero.inventory, identifier)
	_clear_loot(world, identifier)
	world.quests.erase(identifier)
	world.add_message("Abandoned: " + String(QuestData.QUESTS[identifier].title))
	return true


static func _remove_items(inventory: Array[Dictionary], identifier: String) -> void:
	for index in range(inventory.size()):
		var item := inventory[index]
		if not item.is_empty() and ItemData.get_item(int(item.id)).quest == identifier:
			inventory[index] = {}


static func _clear_loot(world: GridWorld, identifier: String) -> void:
	world.loot_quests.erase(identifier)
	for source in world.actors:
		for index in range(source.loot.size() - 1, -1, -1):
			if ItemData.get_item(int(source.loot[index].id)).quest == identifier:
				source.loot.remove_at(index)
		if source.loot_assigned:
			world._hide_empty_corpse(source)


static func experience(base: int, quest_level: int, player_level: int) -> int:
	var difference := player_level - quest_level
	var percent := 100
	if difference >= 10:
		percent = 10
	elif difference >= 6:
		percent = 100 - (difference - 5) * 20
	return ceili(base * percent / 100.0)


static func difficulty(quest_level: int, player_level: int) -> String:
	var difference := quest_level - player_level
	if difference >= 5:
		return "Red"
	if difference >= 3:
		return "Orange"
	if difference >= -2:
		return "Yellow"
	var green_range := 4
	if player_level >= 60:
		green_range = 12
	elif player_level >= 40:
		green_range = player_level / 5
	elif player_level >= 10:
		green_range = 4 + player_level / 10
	return "Green" if difference >= -green_range else "Gray"


static func objective_label(objective: Dictionary) -> String:
	match objective.kind:
		"loot":
			return ItemData.get_item(int(objective.target)).title
		"kill":
			return NorthshireData.CREATURES[objective.target].title
		"location":
			return "Visit the gate overlook (43–45, 11–17)"
		"talk":
			return "Speak with " + NorthshireZone.npc_name(int(objective.target))
	return ""


static func restore(world: GridWorld, records: Variant) -> bool:
	if not records is Dictionary:
		return false
	for identifier in records:
		if not QuestData.QUESTS.has(identifier):
			return false
		var record: Variant = records[identifier]
		var objectives: Array = QuestData.QUESTS[identifier].objectives
		if (not record is Dictionary or not record.get("handed_in") is bool
			or not record.get("counts") is Array or record.counts.size() != objectives.size()):
			return false
		var counts: Array[int] = []
		for index in range(objectives.size()):
			var value: Variant = record.counts[index]
			if not SaveCodec._integer(value, 0) or value > int(objectives[index].count):
				return false
			counts.append(int(value))
		world.quests[identifier] = {"handed_in": record.handed_in, "counts": counts}
		if world.loot_quests.has(identifier) == record.handed_in:
			return false
	if not records.is_empty() and not world.ever_accepted_quest:
		return false
	return true
