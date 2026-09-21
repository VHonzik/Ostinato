class_name StarterGear
extends RefCounted

## DATA-001: outfit storage for FR-001/005; full item services follow in M5.
const ITEMS: Dictionary = {
	35: {"title": "Bent Staff", "slot": "main_hand", "armor": 0},
	55: {"title": "Apprentice's Boots", "slot": "feet", "armor": 0},
	56: {"title": "Apprentice's Robe", "slot": "chest", "armor": 3},
	1395: {"title": "Apprentice's Pants", "slot": "legs", "armor": 2},
	6096: {"title": "Apprentice's Shirt", "slot": "shirt", "armor": 0},
	6123: {"title": "Novice's Robe", "slot": "chest", "armor": 3},
	6124: {"title": "Novice's Pants", "slot": "legs", "armor": 2},
}


static func outfit(category: StringName) -> Array[int]:
	return [6123, 6124, 35] if category == &"Druid" else [56, 1395, 55, 6096, 35]


static func item(identifier: int) -> Dictionary:
	return {"id": identifier, "starter": true, "quantity": 1}


static func equip_outfit(hero: HeroState) -> void:
	hero.inventory.resize(40)
	hero.inventory.fill({})
	for identifier in outfit(&"Mage"):
		hero.equipment[ITEMS[identifier].slot] = item(identifier)
	hero.refresh_melee_stats()


static func exchange(hero: HeroState, category: StringName) -> bool:
	var equipment := hero.equipment.duplicate(true)
	var inventory := hero.inventory.duplicate(true)
	for slot in equipment.keys():
		if equipment[slot].starter:
			equipment.erase(slot)
	for index in range(inventory.size()):
		if not inventory[index].is_empty() and inventory[index].starter:
			inventory[index] = {}
	for identifier in outfit(category):
		var slot: String = ITEMS[identifier].slot
		if not equipment.has(slot):
			equipment[slot] = item(identifier)
		else:
			var empty := inventory.find({})
			if empty == -1:
				return false
			inventory[empty] = item(identifier)
	hero.equipment = equipment
	hero.inventory.assign(inventory)
	hero.selected_class = category
	hero.refresh_melee_stats()
	hero.health = mini(hero.health, hero.max_health)
	hero.mana = mini(hero.mana, hero.max_mana)
	return true
