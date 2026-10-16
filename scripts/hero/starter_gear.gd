class_name StarterGear
extends RefCounted

## Granted outfit provenance survives moves and cannot erase acquired items.


static func outfit(category: StringName) -> Array[int]:
	var outfits := {"Warrior": [2361, 2379], "Shaman": [36, 44],
		"Paladin": [2361, 44], "Rogue": [35, 44]}
	var result: Array[int] = []
	result.assign(outfits.get(String(category), []))
	return result


static func item(identifier: int) -> Dictionary:
	return {"id": identifier, "starter": true, "quantity": 1}


static func equip_travel_clothes(hero: HeroState) -> void:
	var identifiers: Array[int] = [35, 44]
	_equip(hero, identifiers)


static func equip_outfit(hero: HeroState) -> void:
	_equip(hero, outfit(hero.selected_class))


static func exchange(hero: HeroState, category: StringName) -> bool:
	if category not in ClassSkillData.PLAYABLE_CLASSES:
		return false
	var draft := InventoryDraft.new(hero)
	var equipment := draft.equipment
	var inventory := draft.inventory
	for slot in equipment.keys():
		if equipment[slot].starter:
			equipment.erase(slot)
	for index in range(inventory.size()):
		if not inventory[index].is_empty() and inventory[index].starter:
			inventory[index] = {}
	for identifier in outfit(category):
		if not draft.receive(item(identifier)):
			return false
	hero.selected_class = category
	draft.commit()
	return true


static func _equip(hero: HeroState, identifiers: Array[int]) -> void:
	hero.equipment.clear()
	hero.inventory.resize(40)
	hero.inventory.fill({})
	for identifier in identifiers:
		hero.equipment[ItemData.get_item(identifier).slot] = item(identifier)
	hero.refresh_stats()
