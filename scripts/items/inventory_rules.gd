class_name InventoryRules
extends RefCounted

## Atomic 40-slot transactions: mutate copies, then commit only on success.
const SLOTS: Array[String] = [
	"armor", "neck", "ring_1", "ring_2", "weapons",
]


static func has_quality_upgrade(hero: HeroState) -> bool:
	for item in hero.inventory:
		if item.is_empty():
			continue
		var data := ItemData.get_item(int(item.id))
		for slot in SLOTS:
			if not fits_slot(data, slot):
				continue
			var equipped: Dictionary = hero.equipment.get(slot, {})
			if equipped.is_empty() or int(data.quality) > int(ItemData.get_item(int(equipped.id)).quality):
				return true
	return false


## Display order only: actions keep the original slot indices and stack provenance.
static func sorted_indices(inventory: Array[Dictionary]) -> Array[int]:
	var indices: Array[int] = []
	for index in range(inventory.size()):
		indices.append(index)
	indices.sort_custom(func(a: int, b: int) -> bool:
		var first := inventory[a]
		var second := inventory[b]
		if first.is_empty() or second.is_empty():
			return not first.is_empty() if first.is_empty() != second.is_empty() else a < b
		var first_data := ItemData.get_item(int(first.id))
		var second_data := ItemData.get_item(int(second.id))
		if first_data.quality != second_data.quality:
			return int(first_data.quality) > int(second_data.quality)
		var comparison := String(first_data.title).naturalnocasecmp_to(String(second_data.title))
		return comparison < 0 if comparison != 0 else a < b)
	return indices


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


static func receive(hero: HeroState, item: Dictionary) -> bool:
	var draft := InventoryDraft.new(hero)
	if not draft.receive(item):
		return false
	draft.commit()
	return true


static func equip(hero: HeroState, index: int, slot: String = "") -> bool:
	if index < 0 or index >= hero.inventory.size() or hero.inventory[index].is_empty():
		return false
	var item: Dictionary = hero.inventory[index]
	var data := ItemData.get_item(int(item.id))
	if data.slot == "":
		return false
	if slot == "":
		slot = data.slot
		if slot == "ring":
			slot += "_1" if not hero.equipment.has(slot + "_1") else "_2"
	if not fits_slot(data, slot):
		return false
	var draft := InventoryDraft.new(hero)
	var equipment := draft.equipment
	var inventory := draft.inventory
	inventory[index] = {}
	var displaced: Array[String] = [slot]
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
	draft.commit()
	return true


static func unequip(hero: HeroState, slot: String) -> bool:
	if not hero.equipment.has(slot):
		return false
	var draft := InventoryDraft.new(hero)
	if not add(draft.inventory, draft.equipment[slot]):
		return false
	draft.equipment.erase(slot)
	draft.commit()
	return true


static func fits_slot(data: Dictionary, slot: String) -> bool:
	return (SLOTS.has(slot) and (data.slot == slot
		or (data.slot == "ring" and slot in ["ring_1", "ring_2"])))


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
