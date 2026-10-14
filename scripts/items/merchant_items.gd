class_name MerchantItems
extends RefCounted

## Compact equipment setups and valley supplies.
const ITEMS: Dictionary = {
	"4540": {
		"title": "Tough Hunk of Bread", "quality": 1, "slot": "",
		"level": 1, "stack": 20, "buy": 5,
		"sell": 1, "armor": 0, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "food", "quest": "",
		"tradable": true, "restore": 61, "duration": 18,
	},
	"2121": {
		"title": "Reinforced Cloth Armor", "quality": 1, "slot": "armor",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 90, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true,
	},
	"2379": {
		"title": "Battleworn Armor", "quality": 0, "slot": "armor",
		"level": 1, "stack": 1, "buy": 10,
		"sell": 1, "armor": 20, "two_handed": false,
		"unique": false, "weapon": false, "shield": false,
		"minimum": 0, "maximum": 0, "interval": 0.0,
		"stats": {}, "use": "", "quest": "",
		"tradable": true,
	},
	"2131": {
		"title": "Shortsword", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 70, "two_handed": false,
		"unique": false, "weapon": true, "shield": true,
		"minimum": 3, "maximum": 5, "interval": 2.4,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "shield_pair",
	},
	"1194": {
		"title": "Bastard Sword", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": true,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 5, "maximum": 8, "interval": 3.0,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "two_hand",
	},
	"2132": {
		"title": "Short Staff", "quality": 1, "slot": "weapons",
		"level": 1, "stack": 1, "buy": 200,
		"sell": 20, "armor": 0, "two_handed": true,
		"unique": false, "weapon": true, "shield": false,
		"minimum": 5, "maximum": 8, "interval": 3.2,
		"stats": {"crit": 1.0, "haste": 3.0}, "use": "", "quest": "",
		"tradable": true, "weapon_style": "two_hand",
	},
}
