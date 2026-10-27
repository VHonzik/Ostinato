class_name MerchantData
extends RefCounted

## Merchant catalogs, prices, and finite stock.
## Quantity/price are per purchase bundle; stock counts individual items, -1 unlimited.
const CATALOGS: Dictionary = {
	"152": {
		"117": {"quantity": 1, "price": 5, "stock": -1},
	},
	"190": {
		"2121": {"quantity": 1, "price": 200, "stock": -1},
		"70001": {"quantity": 1, "price": 200, "stock": -1},
		"70002": {"quantity": 1, "price": 200, "stock": -1},
		"70003": {"quantity": 1, "price": 200, "stock": -1},
	},
	"1213": {
		"85": {"quantity": 1, "price": 200, "stock": -1},
		"2129": {"quantity": 1, "price": 200, "stock": -1},
	},
	"78": {
		"2131": {"quantity": 1, "price": 200, "stock": -1},
		"1194": {"quantity": 1, "price": 200, "stock": -1},
		"2139": {"quantity": 1, "price": 200, "stock": -1},
		"2132": {"quantity": 1, "price": 200, "stock": -1},
	},
	"900003": {
		"85": {"quantity": 1, "price": 200, "stock": -1},
		"2129": {"quantity": 1, "price": 200, "stock": -1},
		"2139": {"quantity": 1, "price": 200, "stock": -1},
		"2132": {"quantity": 1, "price": 200, "stock": -1},
		"70001": {"quantity": 1, "price": 200, "stock": -1},
		"70002": {"quantity": 1, "price": 200, "stock": -1},
		"70003": {"quantity": 1, "price": 200, "stock": -1},
		"117": {"quantity": 1, "price": 5, "stock": -1},
		"118": {"quantity": 1, "price": 20, "stock": 3},
	},
}


static func catalog(npc_id: int) -> Dictionary:
	return CATALOGS.get(str(npc_id), {})


## Source bundle prices divide evenly into copper per item for every demo offer.
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
