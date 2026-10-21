class_name NorthshireData
extends RefCounted

## Valley combat profiles: first patrol/camp, wolves, mine, vineyard, then Garrick.
const CREATURES: Dictionary = {
	"6": {
		"title": "Kobold Vermin",
		"level": 1,
		"health": 40,
		"armor": 20,
		"minimum": 3,
		"maximum": 4,
		"power": 0,
		"interval": 2.0,
		"copper_min": 4,
		"copper_max": 8
	},
	"38": {
		"title": "Defias Thug",
		"level": 4,
		"health": 70,
		"armor": 85,
		"minimum": 5,
		"maximum": 7,
		"power": 0,
		"interval": 2.4,
		"copper_min": 4,
		"copper_max": 8
	},
	"69": {
		"title": "Timber Wolf",
		"level": 2,
		"health": 50,
		"armor": 35,
		"minimum": 4,
		"maximum": 5,
		"power": 0,
		"interval": 2.0,
		"copper_min": 0,
		"copper_max": 0
	},
	"80": {
		"title": "Kobold Laborer",
		"level": 3,
		"health": 60,
		"armor": 65,
		"minimum": 4,
		"maximum": 6,
		"power": 0,
		"interval": 2.0,
		"copper_min": 4,
		"copper_max": 8
	},
	"103": {
		"title": "Garrick Padfoot",
		"level": 5,
		"health": 220,
		"armor": 105,
		"minimum": 10,
		"maximum": 13,
		"power": 0,
		"interval": 2.6,
		"copper_min": 4,
		"copper_max": 8
	},
	"257": {
		"title": "Kobold Worker",
		"level": 3,
		"health": 60,
		"armor": 65,
		"minimum": 4,
		"maximum": 6,
		"power": 0,
		"interval": 2.0,
		"copper_min": 4,
		"copper_max": 8
	},
	"299": {
		"title": "Young Wolf",
		"level": 1,
		"health": 40,
		"armor": 20,
		"minimum": 4,
		"maximum": 5,
		"power": 0,
		"interval": 2.0,
		"copper_min": 0,
		"copper_max": 0
	}
}

const STALKER: Dictionary = {
	"level": 8,
	"health": 600,
	"armor": 240,
	"minimum": 14,
	"maximum": 18,
	"power": 0,
	"interval": 2.5,
}
