class_name ItemData
extends RefCounted

## Compact equipment setups and valley supplies.
const ITEMS: Dictionary = {
	"35": {
		"title": "Bent Staff", "quality": 0, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 10,
		"sell": 2, "armor": 0, "two_handed": true,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 3, "maximum": 5, "interval": 2.9,
		"stats": {}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "two_hand",
	},
	"2139": {
		"title": "Balanced Daggers", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 2, "maximum": 4, "interval": 1.6,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "dual_wield", "off_minimum": 2,
		"off_maximum": 4, "off_interval": 1.6,
	},
	"2129": {
		"title": "Guard Sword and Shield", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 70, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 3, "maximum": 5, "interval": 2.4,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"85": {
		"title": "Patrol Armor", "quality": 1, "slot": "armor",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 90, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"2572": {
		"title": "Runed Linen Armor", "quality": 2, "slot": "armor",
		"level": 5, "stack": 1, "buy": 300,
		"sell": 30, "armor": 130, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"strength": 2, "stamina": 1, "crit": 1.0, "haste": 5.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"117": {
		"title": "Tough Jerky", "quality": 1, "slot": "",
		"level": 1, "stack": 20, "buy": 5,
		"sell": 1, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "food", "quest": "",
		"tradable": true, "restore": 61, "duration": 18,
	},
	"118": {
		"title": "Minor Healing Potion", "quality": 1, "slot": "",
		"level": 1, "stack": 5, "buy": 20,
		"sell": 5, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "health", "quest": "",
		"tradable": true, "restore_min": 30, "restore_max": 40,
		"cooldown": 120,
	},
	"7073": {
		"title": "Broken Fang", "quality": 0, "slot": "",
		"level": 0, "stack": 5, "buy": 25,
		"sell": 6, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"7074": {
		"title": "Chipped Claw", "quality": 0, "slot": "",
		"level": 0, "stack": 5, "buy": 16,
		"sell": 4, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"4865": {
		"title": "Ruined Pelt", "quality": 0, "slot": "",
		"level": 0, "stack": 5, "buy": 20,
		"sell": 5, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"750": {
		"title": "Tough Wolf Meat", "quality": 1, "slot": "",
		"level": 0, "stack": 20, "buy": 0,
		"sell": 0, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "wolves",
		"tradable": false,
	},
	"4560": {
		"title": "Fine Scimitar", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 70, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 3, "maximum": 5, "interval": 2.4,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"70001": {
		"title": "Patrol Amulet", "quality": 1, "slot": "neck",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"stamina": 1, "haste": 2.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70002": {
		"title": "Steady Band", "quality": 1, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"strength": 1, "crit": 1.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70003": {
		"title": "Quick Band", "quality": 1, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"agility": 1, "haste": 2.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70011": {
		"title": "Amber Amulet", "quality": 2, "slot": "neck",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"stamina": 2, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70012": {
		"title": "Wolfstone Ring", "quality": 2, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"strength": 2, "crit": 2.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70013": {
		"title": "Leafstone Ring", "quality": 2, "slot": "ring",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"agility": 2, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"70021": {
		"title": "Oakheart Staff", "quality": 2, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 30, "armor": 0, "two_handed": true,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 7, "maximum": 11, "interval": 2.9,
		"stats": {"strength": 2, "crit": 1.0, "haste": 4.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "two_hand",
	},
	"70022": {
		"title": "Sentinel Sword and Shield", "quality": 2, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 30, "armor": 100, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 6, "maximum": 9, "interval": 2.4,
		"stats": {"strength": 2, "crit": 1.0, "haste": 4.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"70023": {
		"title": "Briar Daggers", "quality": 2, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 30, "armor": 0, "two_handed": false,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 3, "maximum": 6, "interval": 1.6,
		"stats": {"strength": 2, "crit": 1.0, "haste": 4.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "dual_wield", "off_minimum": 3,
		"off_maximum": 6, "off_interval": 1.6,
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
	var detail := "%s / %s" % [item.title,
		slot_name(item.slot) if item.slot != "" else "Item"]
	if int(item.armor) != 0:
		detail += " / armor %d" % item.armor
	if item.weapon:
		detail += " / " + String(item.weapon_style).replace("_", " ")
		detail += " / %.0f–%.0f damage, %.1fs" % [item.minimum, item.maximum, item.interval]
		if item.weapon_style == "dual_wield":
			detail += " / off-hand %.0f–%.0f damage, %.1fs" % [
				item.off_minimum, item.off_maximum, item.off_interval]
	for stat in item.stats:
		if float(item.stats[stat]) == 0.0:
			continue
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


static func slot_name(slot: String) -> String:
	return "Outfit" if slot == "armor" else slot.replace("_", " ").capitalize()


static func quality_name(quality: int) -> String:
	return ["Poor (gray)", "Common (white)", "Uncommon (green)"][quality]


static func quality_color(quality: int) -> Color:
	return [Color("9d9d9d"), Color.WHITE, Color("1eff00")][quality]
