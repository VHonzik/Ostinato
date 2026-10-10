class_name MerchantData
extends RefCounted

## Vanilla catalogs and the retained supply-trader adaptation: docs/data/merchants.md.
## Quantity/price are per purchase bundle; stock counts individual items, -1 unlimited.
const CATALOGS: Dictionary = {
	"152": {
		"4540": {
			"quantity": 5,
			"price": 25,
			"stock": -1
		},
		"159": {
			"quantity": 5,
			"price": 25,
			"stock": -1
		}
	},
	"190": {
		"2121": {
			"quantity": 1,
			"price": 50,
			"stock": -1
		},
		"3599": {
			"quantity": 1,
			"price": 24,
			"stock": -1
		},
		"2120": {
			"quantity": 1,
			"price": 50,
			"stock": -1
		},
		"2117": {
			"quantity": 1,
			"price": 37,
			"stock": -1
		},
		"3600": {
			"quantity": 1,
			"price": 24,
			"stock": -1
		},
		"2119": {
			"quantity": 1,
			"price": 25,
			"stock": -1
		},
		"2127": {
			"quantity": 1,
			"price": 60,
			"stock": -1
		},
		"2122": {
			"quantity": 1,
			"price": 32,
			"stock": -1
		},
		"2126": {
			"quantity": 1,
			"price": 60,
			"stock": -1
		},
		"2123": {
			"quantity": 1,
			"price": 49,
			"stock": -1
		},
		"2124": {
			"quantity": 1,
			"price": 33,
			"stock": -1
		},
		"2125": {
			"quantity": 1,
			"price": 33,
			"stock": -1
		}
	},
	"1213": {
		"2379": {
			"quantity": 1,
			"price": 76,
			"stock": -1
		},
		"2381": {
			"quantity": 1,
			"price": 76,
			"stock": -1
		},
		"2380": {
			"quantity": 1,
			"price": 38,
			"stock": -1
		},
		"2383": {
			"quantity": 1,
			"price": 58,
			"stock": -1
		},
		"2384": {
			"quantity": 1,
			"price": 38,
			"stock": -1
		},
		"2385": {
			"quantity": 1,
			"price": 38,
			"stock": -1
		},
		"17184": {
			"quantity": 1,
			"price": 36,
			"stock": -1
		},
		"2129": {
			"quantity": 1,
			"price": 77,
			"stock": -1
		}
	},
	"78": {
		"2131": {
			"quantity": 1,
			"price": 54,
			"stock": -1
		},
		"1194": {
			"quantity": 1,
			"price": 104,
			"stock": -1
		},
		"2134": {
			"quantity": 1,
			"price": 82,
			"stock": -1
		},
		"2479": {
			"quantity": 1,
			"price": 108,
			"stock": -1
		},
		"2130": {
			"quantity": 1,
			"price": 54,
			"stock": -1
		},
		"2480": {
			"quantity": 1,
			"price": 72,
			"stock": -1
		},
		"2139": {
			"quantity": 1,
			"price": 57,
			"stock": -1
		},
		"2132": {
			"quantity": 1,
			"price": 102,
			"stock": -1
		}
	},
	"900003": {
		"2139": {
			"quantity": 1,
			"price": 57,
			"stock": -1
		},
		"2129": {
			"quantity": 1,
			"price": 77,
			"stock": -1
		},
		"85": {
			"quantity": 1,
			"price": 62,
			"stock": -1
		},
		"117": {
			"quantity": 1,
			"price": 5,
			"stock": -1
		},
		"159": {
			"quantity": 1,
			"price": 5,
			"stock": -1
		},
		"2455": {
			"quantity": 1,
			"price": 40,
			"stock": 3
		}
	}
}


static func catalog(npc_id: int) -> Dictionary:
	return CATALOGS.get(str(npc_id), {})


## FR-038: source bundle prices divide evenly into copper per item for every demo offer.
static func unit_price(npc_id: int, identifier: int) -> int:
	var offer: Dictionary = catalog(npc_id)[str(identifier)]
	@warning_ignore("integer_division")
	return int(offer.price) / int(offer.quantity)


static func initial_stock(actors: Array[GridActor]) -> Dictionary:
	var result: Dictionary = {}
	for actor in actors:
		if actor.service != &"Trader" or catalog(actor.npc_id).is_empty():
			continue
		var stock: Dictionary = {}
		for key in catalog(actor.npc_id):
			stock[key] = int(catalog(actor.npc_id)[key].stock)
		result[actor.spawn_id] = stock
	return result
