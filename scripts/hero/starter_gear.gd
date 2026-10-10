class_name StarterGear
extends RefCounted

## Granted outfit provenance survives moves and cannot erase acquired items.


static func outfit(category: StringName) -> Array[int]:
	var outfits := {"Mage": [56, 1395, 55, 6096, 35], "Druid": [6123, 6124, 35], "Warlock": [57, 1396, 59, 6097, 2092], "Priest": [6144, 52, 51, 53, 36], "Shaman": [6134, 6135, 36, 2362], "Paladin": [43, 44, 45, 2361]}
	var result: Array[int] = []
	result.assign(outfits[String(category)])
	return result


static func item(identifier: int) -> Dictionary:
	return {"id": identifier, "starter": true, "quantity": 1}


static func equip_outfit(hero: HeroState) -> void:
	hero.inventory.resize(40)
	hero.inventory.fill({})
	for identifier in outfit(&"Mage"):
		hero.equipment[ItemData.get_item(identifier).slot] = item(identifier)
	hero.refresh_stats()


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
		var slot: String = ItemData.get_item(identifier).slot
		var hands_blocked: bool = (slot == "main_hand"
			and ItemData.get_item(identifier).two_handed and equipment.has("off_hand"))
		hands_blocked = hands_blocked or (slot == "off_hand" and equipment.has("main_hand")
			and ItemData.get_item(int(equipment.main_hand.id)).two_handed)
		if not equipment.has(slot) and not hands_blocked:
			equipment[slot] = item(identifier)
		else:
			var empty := inventory.find({})
			if empty == -1:
				return false
			inventory[empty] = item(identifier)
	hero.equipment = equipment
	hero.inventory.assign(inventory)
	hero.selected_class = category
	hero.refresh_stats()
	hero.health = mini(hero.health, hero.max_health)
	hero.mana = mini(hero.mana, hero.max_mana)
	return true
