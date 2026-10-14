class_name ItemData
extends RefCounted

## Item definitions and equipment values.
const ITEMS: Dictionary = {
	"35": {
		"title": "Bent Staff",
		"quality": 1,
		"slot": "main_hand",
		"level": 1,
		"stack": 1,
		"buy": 47,
		"sell": 9,
		"armor": 0,
		"two_handed": true,
		"unique": false,
		"weapon": true,
		"shield": false,
		"minimum": 3,
		"maximum": 5,
		"interval": 2.9,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"2139": {
		"title": "Dirk",
		"quality": 1,
		"slot": "main_hand",
		"level": 1,
		"stack": 1,
		"buy": 57,
		"sell": 11,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": true,
		"shield": false,
		"minimum": 1,
		"maximum": 3,
		"interval": 1.6,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"2129": {
		"title": "Large Round Shield",
		"quality": 1,
		"slot": "off_hand",
		"level": 1,
		"stack": 1,
		"buy": 77,
		"sell": 15,
		"armor": 55,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": true,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"85": {
		"title": "Dirty Leather Vest",
		"quality": 1,
		"slot": "chest",
		"level": 1,
		"stack": 1,
		"buy": 62,
		"sell": 12,
		"armor": 33,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"2572": {
		"title": "Red Linen Robe",
		"quality": 2,
		"slot": "chest",
		"level": 5,
		"stack": 1,
		"buy": 496,
		"sell": 99,
		"armor": 19,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {
			"stamina": 1,
			"crit": 1.0,
			"haste": 5.0
		},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"117": {
		"title": "Tough Jerky",
		"quality": 1,
		"slot": "",
		"level": 1,
		"stack": 20,
		"buy": 5,
		"sell": 1,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "food",
		"quest": "",
		"tradable": true,
		"restore": 61,
		"duration": 18
	},
	"118": {
		"title": "Minor Healing Potion",
		"quality": 1,
		"slot": "",
		"level": 1,
		"stack": 5,
		"buy": 20,
		"sell": 5,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "health",
		"quest": "",
		"tradable": true,
		"restore_min": 70,
		"restore_max": 90,
		"cooldown": 120
	},
	"7073": {
		"title": "Broken Fang",
		"quality": 0,
		"slot": "",
		"level": 0,
		"stack": 5,
		"buy": 25,
		"sell": 6,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"7074": {
		"title": "Chipped Claw",
		"quality": 0,
		"slot": "",
		"level": 0,
		"stack": 5,
		"buy": 16,
		"sell": 4,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"4865": {
		"title": "Ruined Pelt",
		"quality": 0,
		"slot": "",
		"level": 0,
		"stack": 5,
		"buy": 20,
		"sell": 5,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
	"750": {
		"title": "Tough Wolf Meat",
		"quality": 1,
		"slot": "",
		"level": 0,
		"stack": 20,
		"buy": 0,
		"sell": 0,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": false,
		"shield": false,
		"minimum": 0,
		"maximum": 0,
		"interval": 0.0,
		"stats": {},
		"use": "",
		"quest": "wolves",
		"tradable": false
	},
	"4560": {
		"title": "Fine Scimitar",
		"quality": 1,
		"slot": "main_hand",
		"level": 1,
		"stack": 1,
		"buy": 185,
		"sell": 37,
		"armor": 0,
		"two_handed": false,
		"unique": false,
		"weapon": true,
		"shield": false,
		"minimum": 3,
		"maximum": 6,
		"interval": 1.9,
		"stats": {},
		"use": "",
		"quest": "",
		"tradable": true
	},
}


static func get_item(identifier: int) -> Dictionary:
	return ITEMS.get(str(identifier), NorthshireItems.ITEMS.get(str(identifier),
		ClassItems.ITEMS.get(str(identifier), MerchantItems.ITEMS.get(str(identifier),
		LootItems.ITEMS.get(str(identifier), {})))))


static func instance(identifier: int, quantity: int = 1, starter: bool = false) -> Dictionary:
	return {"id": identifier, "quantity": quantity, "starter": starter}


static func describe(identifier: int) -> String:
	var item := get_item(identifier)
	var detail := "%s / level %d / %s / armor %d" % [
		item.title, item.level, item.slot if item.slot != "" else "Item", item.armor]
	if int(item.quality) == 0:
		detail += " / Poor (grey)"
	if item.weapon:
		detail += " / %.0f–%.0f damage, %.1fs" % [item.minimum, item.maximum, item.interval]
	for stat in item.stats:
		if stat in ["crit", "haste"]:
			detail += " / +%.2f%% %s" % [item.stats[stat], stat]
		else:
			detail += " / +%d %s" % [item.stats[stat], stat]
	if item.two_handed:
		detail += " / two hands"
	if item.use != "":
		detail += " / restores " + String(item.use)
	if item.has("note"):
		detail += " / " + String(item.note)
	return detail
