class_name InventoryDraft
extends RefCounted

## Prepare inventory/equipment changes without touching live stats. Commit only on success.
var inventory: Array[Dictionary]
var equipment: Dictionary
var _hero: HeroState


func _init(hero: HeroState) -> void:
	_hero = hero
	inventory = hero.inventory.duplicate(true)
	equipment = hero.equipment.duplicate(true)


## Acquired gear fills vacant slots without displacing existing gear.
func receive(item: Dictionary) -> bool:
	var data := ItemData.get_item(int(item.id))
	var slot: String = data.slot
	if slot == "ring":
		slot += "_1" if not equipment.has(slot + "_1") else "_2"
	var can_equip: bool = InventoryRules.fits_slot(data, slot) and not equipment.has(slot)
	if data.unique:
		for equipped in equipment.values():
			if equipped.id == item.id:
				can_equip = false
	if not can_equip:
		return InventoryRules.add(inventory, item)
	if int(item.quantity) > 1:
		var remaining := item.duplicate()
		remaining.quantity -= 1
		if not InventoryRules.add(inventory, remaining):
			return false
	equipment[slot] = ItemData.instance(int(item.id), 1, item.starter)
	return true


func commit() -> void:
	var equipment_changed := equipment != _hero.equipment
	_hero.inventory.assign(inventory.duplicate(true))
	_hero.equipment = equipment.duplicate(true)
	if equipment_changed:
		_hero.refresh_stats()
