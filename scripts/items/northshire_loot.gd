class_name NorthshireLoot
extends RefCounted

## Pre-pivot Northshire loot tables.
## Row: item ID, percent chance (negative = quest), group, min count/reference, max count.
## Group 0 rolls independently; a positive group selects at most one item.
const TABLES: Dictionary = {
	"6": [
		[159, 6.5536, 0, 1, 1], # Refreshing Spring Water
		[755, 29.7889, 0, 1, 1], # Melted Candle
		[2772, 0.0073, 0, 1, 1], # Iron Ore
		[4536, 13.4595, 0, 1, 1], # Shiny Red Apple
		[5364, 0.0073, 0, 1, 1], # Dry Salt Lick
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.66, 0, -60441, 1], # Six-slot bag reference
	],
	"38": [
		[117, 0.02, 0, 1, 1], # Tough Jerky
		[159, 6.4011, 0, 1, 1], # Refreshing Spring Water
		[752, -80, 0, 1, 1], # Red Burlap Bandana
		[2057, 1.96, 0, 1, 1], # Pitted Defias Shortsword
		[2070, 13.2319, 0, 1, 1], # Darnassian Bleu
		[4536, 0.02, 0, 1, 1], # Shiny Red Apple
		[4540, 0.02, 0, 1, 1], # Tough Hunk of Bread
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.5, 0, -60441, 1], # Six-slot bag reference
	],
	"69": [
		[750, -80, 0, 1, 1], # Tough Wolf Meat
		[4865, 39.122, 0, 1, 2], # Ruined Pelt
		[5498, 0.0248509, 0, 1, 1], # Small Lustrous Pearl
		[7073, 38.3399, 0, 1, 2], # Broken Fang
		[7074, 38.3736, 0, 1, 2], # Chipped Claw
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.5, 0, -60441, 1], # Six-slot bag reference
	],
	"80": [
		[117, 0.02, 0, 1, 1], # Tough Jerky
		[159, 6.4425, 0, 1, 1], # Refreshing Spring Water
		[755, 29.3913, 0, 1, 1], # Melted Candle
		[2055, 2.04, 0, 1, 1], # Small Wooden Hammer
		[2070, 0.02, 0, 1, 1], # Darnassian Bleu
		[2770, 0.02, 0, 1, 1], # Copper Ore
		[2835, 0.02, 0, 1, 1], # Rough Stone
		[4536, 13.542, 0, 1, 1], # Shiny Red Apple
		[4540, 0.02, 0, 1, 1], # Tough Hunk of Bread
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.66, 0, -60441, 1], # Six-slot bag reference
	],
	"103": [
		[117, 0.02, 0, 1, 1], # Tough Jerky
		[159, 7.3689, 0, 1, 1], # Refreshing Spring Water
		[182, -100, 0, 1, 1], # Garrick's Head
		[2057, 0.83, 0, 1, 1], # Pitted Defias Shortsword
		[2070, 12.364, 0, 1, 1], # Darnassian Bleu
		[4540, 0.04, 0, 1, 1], # Tough Hunk of Bread
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.5, 0, -60441, 1], # Six-slot bag reference
	],
	"257": [
		[159, 6.5174, 0, 1, 1], # Refreshing Spring Water
		[755, 29.5539, 0, 1, 1], # Melted Candle
		[2770, 0.02, 0, 1, 1], # Copper Ore
		[2835, 0.02, 0, 1, 1], # Rough Stone
		[4536, 13.2892, 0, 1, 1], # Shiny Red Apple
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.66, 0, -60441, 1], # Six-slot bag reference
	],
	"299": [
		[750, -80, 0, 1, 1], # Tough Wolf Meat
		[765, 0.02, 0, 1, 1], # Silverleaf
		[2396, 0.02, 0, 1, 1], # Light Mail Bracers
		[2398, 0.02, 0, 1, 1], # Light Chain Armor
		[2447, 0.02, 0, 1, 1], # Peacebloom
		[2770, 0.02, 0, 1, 1], # Copper Ore
		[3471, 0.02, 0, 1, 1], # Copper Chain Vest
		[4302, 0.02, 0, 1, 1], # Small Green Dagger
		[4766, 0.02, 0, 1, 1], # Feral Blade
		[4865, 36.9481, 0, 1, 2], # Ruined Pelt
		[7073, 37.8937, 0, 1, 2], # Broken Fang
		[7074, 37.7572, 0, 1, 2], # Chipped Claw
		[7280, 0.02, 0, 1, 1], # Rugged Leather Pants
		[60000, 9, 0, -60000, 1], # Grey equipment reference
		[60441, 0.5, 0, -60441, 1], # Six-slot bag reference
	],
	"2843": [
		[117, 19, 1, 1, 2], # Tough Jerky
		[159, 35, 0, 1, 2], # Refreshing Spring Water
		[2070, 18, 1, 1, 2], # Darnassian Bleu
		[4536, 19, 1, 1, 2], # Shiny Red Apple
		[4540, 19, 1, 1, 2], # Tough Hunk of Bread
		[60000, 100, 0, -60000, 1], # Grey equipment reference
	],
	"161557": [
		[11119, -100, 0, 1, 1], # Milly's Harvest
	],
}

const REFERENCES: Dictionary = {
	"60000": [
		[1364, 0, 1, 1, 1], # Ragged Leather Vest
		[1366, 0, 1, 1, 1], # Ragged Leather Pants
		[1367, 0, 1, 1, 1], # Ragged Leather Boots
		[1368, 0, 1, 1, 1], # Ragged Leather Gloves
		[1369, 0, 1, 1, 1], # Ragged Leather Belt
		[1370, 0, 1, 1, 1], # Ragged Leather Bracers
		[1372, 0, 1, 1, 1], # Ragged Cloak
		[1374, 0, 1, 1, 1], # Frayed Shoes
		[1376, 0, 1, 1, 1], # Frayed Cloak
		[1377, 0, 1, 1, 1], # Frayed Gloves
		[1378, 0, 1, 1, 1], # Frayed Pants
		[1380, 0, 1, 1, 1], # Frayed Robe
		[2210, 0, 1, 1, 1], # Battered Buckler
		[2211, 0, 1, 1, 1], # Bent Large Shield
		[2649, 0, 1, 1, 1], # Flimsy Chain Belt
		[2650, 0, 1, 1, 1], # Flimsy Chain Boots
		[2651, 0, 1, 1, 1], # Flimsy Chain Bracers
		[2652, 0, 1, 1, 1], # Flimsy Chain Cloak
		[2653, 0, 1, 1, 1], # Flimsy Chain Gloves
		[2654, 0, 1, 1, 1], # Flimsy Chain Pants
		[2656, 0, 1, 1, 1], # Flimsy Chain Vest
		[3363, 0, 1, 1, 1], # Frayed Belt
		[3365, 0, 1, 1, 1], # Frayed Bracers
	],
	"60441": [
		[805, 0, 1, 1, 1], # Small Red Pouch
		[828, 0, 1, 1, 1], # Small Blue Pouch
		[4496, 0, 1, 1, 1], # Small Brown Pouch
		[5571, 0, 1, 1, 1], # Small Black Pouch
		[5572, 0, 1, 1, 1], # Small Green Pouch
	],
}
