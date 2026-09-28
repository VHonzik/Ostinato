class_name InventoryRules
extends RefCounted

## Atomic 40-slot transactions: mutate copies, then commit only on success (FR-037/038).
const SLOTS: Array[String] = [
	"head", "neck", "shoulders", "back", "chest", "shirt", "tabard", "wrists",
	"hands", "waist", "legs", "feet", "ring_1", "ring_2", "trinket_1", "trinket_2",
	"main_hand", "off_hand", "ranged",
]


static func add(inventory: Array[Dictionary], item: Dictionary) -> bool:
	var next := inventory.duplicate(true)
	var remaining := int(item.quantity)
	var limit := int(ItemData.get_item(int(item.id)).stack)
	for slot in next:
		if not slot.is_empty() and slot.id == item.id and slot.starter == item.starter:
			var amount := mini(remaining, limit - int(slot.quantity))
			slot.quantity += amount
			remaining -= amount
	for index in range(next.size()):
		if remaining <= 0:
			break
		if next[index].is_empty():
			var amount := mini(remaining, limit)
			next[index] = ItemData.instance(int(item.id), amount, item.starter)
			remaining -= amount
	if remaining > 0:
		return false
	inventory.assign(next)
	return true


static func equip(hero: HeroState, index: int, slot: String = "") -> bool:
	if index < 0 or index >= hero.inventory.size() or hero.inventory[index].is_empty():
		return false
	var item: Dictionary = hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	if data.slot == "" or hero.level < int(data.level):
		return false
	if slot == "":
		slot = data.slot
		if slot in ["ring", "trinket"]:
			slot += "_1" if not hero.equipment.has(slot + "_1") else "_2"
	if not fits_slot(data, slot):
		return false
	# No included class learns dual wield: one-handed weapons still use the main hand.
	if slot == "off_hand" and data.weapon:
		return false
	var equipment := hero.equipment.duplicate(true)
	var inventory := hero.inventory.duplicate(true)
	inventory[index] = {}
	var displaced: Array[String] = [slot]
	if slot == "main_hand" and data.two_handed:
		displaced.append("off_hand")
	if slot == "off_hand" and equipment.has("main_hand"):
		if ItemData.get_item(int(equipment.main_hand.id)).two_handed:
			displaced.append("main_hand")
	for location in displaced:
		if equipment.has(location):
			if not add(inventory, equipment[location]):
				return false
			equipment.erase(location)
	if data.unique:
		for equipped in equipment.values():
			if equipped.id == item.id:
				return false
	equipment[slot] = item.duplicate()
	hero.inventory.assign(inventory)
	hero.equipment = equipment
	hero.refresh_stats()
	return true


static func unequip(hero: HeroState, slot: String) -> bool:
	if not hero.equipment.has(slot):
		return false
	if not add(hero.inventory, hero.equipment[slot]):
		return false
	hero.equipment.erase(slot)
	hero.refresh_stats()
	return true


static func fits_slot(data: Dictionary, slot: String) -> bool:
	return (SLOTS.has(slot) and (data.slot == slot
		or (data.slot == "ring" and slot in ["ring_1", "ring_2"])
		or (data.slot == "trinket" and slot in ["trinket_1", "trinket_2"])))


static func move(hero: HeroState, source: int, destination: int, quantity: int) -> bool:
	if (source < 0 or source >= 40 or destination < 0 or destination >= 40
		or source == destination or hero.inventory[source].is_empty() or quantity < 1):
		return false
	var item := hero.inventory[source]
	if quantity > int(item.quantity):
		return false
	var target := hero.inventory[destination]
	if target.is_empty():
		hero.inventory[destination] = ItemData.instance(int(item.id), quantity, item.starter)
	elif target.id == item.id and target.starter == item.starter:
		if int(target.quantity) + quantity > int(ItemData.get_item(int(item.id)).stack):
			return false
		target.quantity += quantity
	elif quantity == int(item.quantity):
		hero.inventory[source] = target
		hero.inventory[destination] = item
		return true
	else:
		return false
	item.quantity -= quantity
	if item.quantity == 0:
		hero.inventory[source] = {}
	return true


static func money(copper: int) -> String:
	return "%dg %ds %dc" % [floori(copper / 10000.0), floori(copper / 100.0) % 100, copper % 100]
