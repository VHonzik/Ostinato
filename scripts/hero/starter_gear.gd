class_name StarterGear
extends RefCounted

## Granted outfit provenance survives moves and cannot erase acquired items.


static func outfit(category: StringName) -> Array[int]:
	var outfits := {"Warrior": [2362, 2361, 2379, 2381, 2383],
		"Shaman": [6134, 6135, 36, 2362], "Paladin": [43, 44, 45, 2361],
		"Rogue": [43, 44, 45, 2092]}
	var result: Array[int] = []
	result.assign(outfits.get(String(category), []))
	return result


static func item(identifier: int) -> Dictionary:
	return {"id": identifier, "starter": true, "quantity": 1}


static func equip_travel_clothes(hero: HeroState) -> void:
	var identifiers: Array[int] = [35, 44, 45]
	_equip(hero, identifiers)


static func equip_outfit(hero: HeroState) -> void:
	_equip(hero, outfit(hero.selected_class))


static func exchange(hero: HeroState, category: StringName) -> bool:
	if category not in ClassSkillData.PLAYABLE_CLASSES:
		return false
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
	return true


static func _equip(hero: HeroState, identifiers: Array[int]) -> void:
	hero.equipment.clear()
	hero.inventory.resize(40)
	hero.inventory.fill({})
	for identifier in identifiers:
		hero.equipment[ItemData.get_item(identifier).slot] = item(identifier)
	hero.refresh_stats()
