class_name QuestData
extends RefCounted

## DATA-004: docs/data/northshire.md.
const QUESTS: Dictionary = {
	"6": {
		"title": "Bounty on Garrick Padfoot",
		"level": 5,
		"minimum": 2,
		"previous": [
			"18"
		],
		"giver": 823,
		"receiver": 823,
		"category": "",
		"objectives": [
			{
				"kind": "loot",
				"target": "182",
				"count": 1
			}
		],
		"xp": 340,
		"copper": 0,
		"choices": [
			6076,
			60,
			3070
		],
		"source_item": 0
	},
	"7": {
		"title": "Kobold Camp Cleanup",
		"level": 2,
		"minimum": 1,
		"previous": [
			"783"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			{
				"kind": "kill",
				"target": "6",
				"count": 10
			}
		],
		"xp": 170,
		"copper": 25,
		"choices": [],
		"source_item": 0
	},
	"15": {
		"title": "Investigate Echo Ridge",
		"level": 3,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			{
				"kind": "kill",
				"target": "257",
				"count": 10
			}
		],
		"xp": 250,
		"copper": 40,
		"choices": [],
		"source_item": 0
	},
	"18": {
		"title": "Brotherhood of Thieves",
		"level": 4,
		"minimum": 2,
		"previous": [
			"783"
		],
		"giver": 823,
		"receiver": 823,
		"category": "",
		"objectives": [
			{
				"kind": "loot",
				"target": "752",
				"count": 12
			}
		],
		"xp": 360,
		"copper": 0,
		"choices": [
			2224,
			5580,
			1161,
			5579,
			1159
		],
		"source_item": 0
	},
	"21": {
		"title": "Skirmish at Echo Ridge",
		"level": 5,
		"minimum": 1,
		"previous": [
			"15"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			{
				"kind": "kill",
				"target": "80",
				"count": 12
			}
		],
		"xp": 450,
		"copper": 0,
		"choices": [
			2186,
			2691,
			11192
		],
		"source_item": 0
	},
	"wolves": {
		"title": "Wolves Across the Border",
		"level": 2,
		"minimum": 1,
		"previous": [
			"5261"
		],
		"giver": 196,
		"receiver": 196,
		"category": "",
		"objectives": [
			{
				"kind": "loot",
				"target": "750",
				"count": 8
			}
		],
		"xp": 170,
		"copper": 0,
		"choices": [
			80,
			6070
		],
		"source_item": 0
	},
	"783": {
		"title": "A Threat Within",
		"level": 1,
		"minimum": 1,
		"previous": [],
		"giver": 823,
		"receiver": 197,
		"category": "",
		"objectives": [
			{
				"kind": "talk",
				"target": "197",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3104": {
		"title": "Glyphic Letter",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 198,
		"category": "Mage",
		"objectives": [
			{
				"kind": "loot",
				"target": "9571",
				"count": 1
			},
			{
				"kind": "talk",
				"target": "198",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 9571
	},
	"3903": {
		"title": "Milly Osworth",
		"level": 4,
		"minimum": 2,
		"previous": [
			"wolves"
		],
		"giver": 823,
		"receiver": 9296,
		"category": "",
		"objectives": [
			{
				"kind": "talk",
				"target": "9296",
				"count": 1
			}
		],
		"xp": 35,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3904": {
		"title": "Milly's Harvest",
		"level": 4,
		"minimum": 2,
		"previous": [
			"3903"
		],
		"giver": 9296,
		"receiver": 9296,
		"category": "",
		"objectives": [
			{
				"kind": "loot",
				"target": "11119",
				"count": 8
			}
		],
		"xp": 180,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3905": {
		"title": "Grape Manifest",
		"level": 4,
		"minimum": 2,
		"previous": [
			"3904"
		],
		"giver": 9296,
		"receiver": 952,
		"category": "",
		"objectives": [
			{
				"kind": "loot",
				"target": "11125",
				"count": 1
			},
			{
				"kind": "talk",
				"target": "952",
				"count": 1
			}
		],
		"xp": 360,
		"copper": 0,
		"choices": [
			11475,
			2690
		],
		"source_item": 11125
	},
	"5261": {
		"title": "Eagan Peltskinner",
		"level": 2,
		"minimum": 1,
		"previous": [
			"783"
		],
		"giver": 823,
		"receiver": 196,
		"category": "",
		"objectives": [
			{
				"kind": "talk",
				"target": "196",
				"count": 1
			}
		],
		"xp": 85,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"druid_referral": {
		"title": "A Druid at the Abbey",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 900001,
		"category": "Druid",
		"objectives": [
			{
				"kind": "talk",
				"target": "900001",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"gate_survey": {
		"title": "Watch the Northshire Gate",
		"level": 2,
		"minimum": 1,
		"previous": [
			"783"
		],
		"giver": 197,
		"receiver": 197,
		"category": "",
		"objectives": [
			{
				"kind": "location",
				"target": "gate_overlook",
				"count": 1
			},
			{
				"kind": "talk",
				"target": "823",
				"count": 1
			}
		],
		"xp": 85,
		"copper": 0,
		"choices": [],
		"source_item": 0
	},
	"3101": {
		"title": "Consecrated Letter",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 925,
		"category": "Paladin",
		"objectives": [
			{
				"kind": "talk",
				"target": "925",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 9570
	},
	"3103": {
		"title": "Hallowed Letter",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 375,
		"category": "Priest",
		"objectives": [
			{
				"kind": "talk",
				"target": "375",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 9548
	},
	"3105": {
		"title": "Tainted Letter",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 459,
		"category": "Warlock",
		"objectives": [
			{
				"kind": "talk",
				"target": "459",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 9576
	},
	"shaman_referral": {
		"title": "A Shaman at the Abbey",
		"level": 1,
		"minimum": 1,
		"previous": [
			"7"
		],
		"giver": 197,
		"receiver": 900002,
		"category": "Shaman",
		"objectives": [
			{
				"kind": "talk",
				"target": "900002",
				"count": 1
			}
		],
		"xp": 40,
		"copper": 0,
		"choices": [],
		"source_item": 0
	}
}
