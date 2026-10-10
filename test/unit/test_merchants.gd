extends GutTest


func _merchant(world: GridWorld, npc_id: int) -> GridActor:
	for actor in world.actors:
		if actor.npc_id == npc_id:
			return actor
	return null


func _beside(world: GridWorld, merchant: GridActor) -> void:
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(merchant.tile + direction):
			world.player_tile = merchant.tile + direction
			return
	fail_test("Merchant has no reachable adjacent tile.")


func test_source_catalogs_and_explicit_exclusions() -> void:
	var game := GameSession.new()
	game.new_game(819)
	var expected := {
		152: [4540, 159],
		190: [2121, 3599, 2120, 2117, 3600, 2119, 2127, 2122, 2126, 2123, 2124, 2125],
		1213: [2379, 2381, 2380, 2383, 2384, 2385, 17184, 2129],
		78: [2131, 1194, 2134, 2479, 2130, 2480, 2139, 2132],
	}
	for npc_id in expected:
		var merchant := _merchant(game.world, npc_id)
		assert_eq(merchant.service, &"Trader")
		assert_eq(MerchantData.catalog(npc_id).keys(), expected[npc_id].map(str))
		for key in MerchantData.catalog(npc_id):
			assert_false(ItemData.get_item(int(key)).is_empty(), key)
			assert_eq(game.world.vendor_stock[merchant.spawn_id][key], -1)
	assert_eq(_merchant(game.world, 11940).service, &"")
	assert_true(MerchantData.catalog(11940).is_empty(), "Merissa has no Vanilla vendor catalog.")
	assert_eq(ItemData.get_item(2121).armor, 10)
	assert_eq(ItemData.get_item(2132).interval, 3.2)
	assert_eq(ItemData.get_item(4540).restore, 61)


func test_selected_merchant_catalog_and_identity_are_enforced() -> void:
	var world := NorthshireZone.create_world(819, false)
	var danil := _merchant(world, 152)
	var janos := _merchant(world, 78)
	world.hero.copper = 1000
	_beside(world, danil)
	assert_false(world.buy_item(danil, 2131, 1), "Danil cannot sell Janos's sword.")
	assert_false(world.buy_item(janos, 2131, 1), "Another nearby merchant cannot authorize Janos.")
	assert_true(world.buy_item(danil, 4540, 10))
	assert_eq(world.hero.inventory[0].quantity, 10)
	assert_eq(world.hero.copper, 950)
	var impostor := GridActor.new(danil.tile)
	impostor.npc_id = 152
	impostor.spawn_id = danil.spawn_id
	impostor.service = &"Trader"
	assert_false(world.buy_item(impostor, 159, 1))
	assert_false(world.sell_item(impostor, 0, 1))
	danil.alive = false
	assert_false(world.buy_item(danil, 159, 1))
	assert_false(world.sell_item(danil, 0, 1))
	danil.alive = true
	danil.relationship = GridActor.Relationship.HOSTILE
	assert_false(world.buy_item(danil, 159, 1))
	danil.relationship = GridActor.Relationship.FRIENDLY
	assert_true(world.sell_item(danil, 0, 3))
	assert_eq(world.hero.inventory[0].quantity, 7)
	assert_eq(world.hero.copper, 953)
	assert_eq(world.turn_count, 0)
	assert_eq(world.vendor_stock[danil.spawn_id]["4540"], -1)


func test_quantities_reject_partial_money_and_capacity_without_changing_stock() -> void:
	var world := NorthshireZone.create_world(819, false)
	var danil := _merchant(world, 152)
	_beside(world, danil)
	world.hero.copper = 49
	assert_false(world.buy_item(danil, 159, 10))
	assert_eq(world.hero.copper, 49)
	assert_true(world.hero.inventory.all(func(item: Dictionary) -> bool: return item.is_empty()))
	world.hero.copper = 1000
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(159, 20)
	world.hero.inventory[0].quantity = 16
	var before := world.hero.inventory.duplicate(true)
	assert_false(world.buy_item(danil, 159, 5), "Four free units cannot fit five items.")
	assert_eq(world.hero.inventory, before)
	assert_eq(world.hero.copper, 1000)
	world.hero.inventory[0].quantity = 15
	assert_true(world.buy_item(danil, 159, 5))
	assert_eq(world.hero.inventory[0].quantity, 20)
	assert_eq(world.hero.copper, 975)
	for amount in [-1, 0, 1001]:
		assert_false(world.buy_item(danil, 159, amount))
	assert_eq(world.vendor_stock[danil.spawn_id]["159"], -1)
	assert_eq(world.turn_count, 0)


func test_finite_stock_is_per_instance_and_never_refilled_by_waiting_or_selling() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 89, false)
	var first := GridActor.new(Vector2i(4, 5))
	var second := GridActor.new(Vector2i(6, 5))
	for actor in [first, second]:
		actor.service = &"Trader"
		actor.npc_id = 900003
		actor.spawn_id = "merchant/%d" % actor.tile.x
		world.actors.append(actor)
	world.vendor_stock = MerchantData.initial_stock(world.actors)
	world.hero.copper = 1000
	assert_true(world.buy_item(first, 2455, 3))
	assert_false(world.buy_item(first, 2455, 1))
	assert_eq(world.vendor_stock[second.spawn_id]["2455"], 3)
	assert_true(world.sell_item(first, 0, 3))
	for turn in range(40):
		world.wait_turn()
	assert_eq(world.vendor_stock[first.spawn_id]["2455"], 0)
	assert_true(world.buy_item(second, 2455, 2))
	assert_eq(world.vendor_stock[second.spawn_id]["2455"], 1)
	assert_eq(world.turn_count, 40)


func test_stock_save_round_trip_continuation_reset_and_stale_merchant_rejection() -> void:
	var game := GameSession.new()
	game.new_game(819)
	var old := _merchant(game.world, 900003)
	_beside(game.world, old)
	game.world.hero.copper = 1000
	assert_true(game.world.buy_item(old, 2455, 2))
	var captured := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(captured)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.vendor_stock, game.world.vendor_stock)
	assert_false(restored.buy_item(old, 2455, 1))
	assert_false(restored.sell_item(old, 0, 1))
	assert_true(restored.buy_item(_merchant(restored, 900003), 2455, 1))
	assert_true(game.world.buy_item(old, 2455, 1))
	assert_eq(restored.hero.inventory, game.world.hero.inventory)
	assert_eq(restored.hero.copper, game.world.hero.copper)
	assert_eq(restored.vendor_stock, game.world.vendor_stock)
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.vendor_stock["fixed/900003"]["2455"], 3)
	assert_false(game.world.buy_item(old, 2455, 1))
	game.new_game(820)
	assert_eq(game.world.vendor_stock["fixed/900003"]["2455"], 3)


func test_invalid_saved_stock_cannot_change_catalog_or_finite_unlimited_semantics() -> void:
	var game := GameSession.new()
	game.new_game(819)
	var original := SaveCodec.capture(game)
	for value in [-2, -1, 4, 1.5, "2"]:
		var bad := original.duplicate(true)
		bad.vendor_stock["fixed/900003"]["2455"] = value
		assert_null(SaveCodec.restore(bad, false), str(value))
	var bad := original.duplicate(true)
	bad.vendor_stock["fixed/152"]["159"] = 0
	assert_null(SaveCodec.restore(bad, false))
	bad = original.duplicate(true)
	bad.vendor_stock["fixed/152"].erase("159")
	assert_null(SaveCodec.restore(bad, false))
	bad = original.duplicate(true)
	bad.vendor_stock["fixed/152"]["2139"] = -1
	assert_null(SaveCodec.restore(bad, false))
	bad = original.duplicate(true)
	bad.vendor_stock["missing"] = bad.vendor_stock["fixed/152"]
	assert_null(SaveCodec.restore(bad, false))
	bad = original.duplicate(true)
	bad.vendor_stock.erase("fixed/152")
	assert_null(SaveCodec.restore(bad, false))
	assert_eq(SaveCodec.capture(game), original, "Rejected restoration leaves the active world intact.")


func test_trading_in_combat_is_free_but_pending_actions_reject_it() -> void:
	var world := NorthshireZone.create_world(819, false)
	var merchant := _merchant(world, 152)
	_beside(world, merchant)
	world.hero.copper = 100
	var enemy := _merchant(world, 38)
	enemy.engaged = true
	assert_true(world.in_combat())
	assert_true(world.buy_item(merchant, 159, 5))
	assert_true(world.sell_item(merchant, 0, 1))
	assert_eq(world.turn_count, 0)
	world.pending_skill = SkillRank.catalog(&"fireball_1")
	assert_false(world.buy_item(merchant, 159, 1))
	assert_false(world.sell_item(merchant, 0, 1))
	assert_eq(world.hero.inventory[0].quantity, 4)
	assert_eq(world.hero.copper, 76)


func test_new_merchant_equipment_and_food_use_existing_item_rules() -> void:
	var world := NorthshireZone.create_world(819, false)
	var merchant := _merchant(world, 190)
	_beside(world, merchant)
	world.hero.copper = 1000
	assert_true(world.buy_item(merchant, 2121, 1))
	var armor := world.hero.melee.armor
	var previous := int(ItemData.get_item(int(world.hero.equipment.chest.id)).armor)
	assert_true(world.equip_item(0))
	assert_eq(world.hero.melee.armor, armor - previous + 10)
	merchant = _merchant(world, 78)
	_beside(world, merchant)
	assert_true(world.buy_item(merchant, 2132, 1))
	var staff_slot := -1
	for index in range(40):
		if world.hero.inventory[index].get("id", 0) == 2132:
			staff_slot = index
	assert_true(world.equip_item(staff_slot))
	assert_eq(world.hero.melee.damage_min, 5.0)
	assert_eq(world.hero.melee.damage_max, 8.0)
	assert_eq(world.hero.melee.interval, 3.2)
	merchant = _merchant(world, 152)
	_beside(world, merchant)
	assert_true(world.buy_item(merchant, 4540, 5))
	var bread_slot := -1
	for index in range(40):
		if world.hero.inventory[index].get("id", 0) == 4540:
			bread_slot = index
	world.hero.health = 1
	assert_true(world.consume_item(bread_slot))
	assert_eq(world.hero.inventory[bread_slot].quantity, 4)
	assert_eq(world.hero.restoration.food.total, 61)
	assert_eq(world.hero.restoration.food.duration, 18)


func test_direct_purchase_units_preserve_prices_and_stack_limits() -> void:
	var world := NorthshireZone.create_world(819, false)
	var danil := _merchant(world, 152)
	_beside(world, danil)
	world.hero.copper = 155
	for amount in [1, 10, 20]:
		assert_true(world.buy_item(danil, 4540, amount))
	assert_eq(world.hero.inventory[0], ItemData.instance(4540, 20))
	assert_eq(world.hero.inventory[1], ItemData.instance(4540, 11))
	assert_eq(world.hero.copper, 0)
	assert_false(world.buy_item(danil, 4540, 1))
	assert_eq(world.turn_count, 0)
	for catalog in MerchantData.CATALOGS.values():
		for offer in catalog.values():
			assert_eq(int(offer.price) % int(offer.quantity), 0,
				"Individual source prices must be exact whole copper.")


func test_sell_all_grey_preserves_equipment_and_non_grey_items_and_cannot_repeat_proceeds() -> void:
	var world := NorthshireZone.create_world(819, false)
	var merchant := _merchant(world, 152)
	_beside(world, merchant)
	world.hero.inventory[0] = ItemData.instance(7073, 5)
	world.hero.inventory[1] = ItemData.instance(7073, 2)
	world.hero.inventory[2] = ItemData.instance(56) # Grey carried robe.
	world.hero.inventory[3] = ItemData.instance(159, 20) # White water.
	world.hero.inventory[4] = ItemData.instance(2572) # Green equipment.
	world.hero.inventory[5] = ItemData.instance(750, 2) # Quest item.
	world.hero.inventory[6] = ItemData.instance(5349, 4) # Conjured food.
	world.hero.inventory[7] = ItemData.instance(35) # Common equipment.
	var retained := world.hero.inventory.slice(3).duplicate(true)
	var equipment := world.hero.equipment.duplicate(true)
	var stock := world.vendor_stock.duplicate(true)
	world.hero.copper = 10
	assert_true(world.sell_all_grey(merchant))
	assert_eq(world.hero.copper, 53, "Seven fangs at 6c plus a 1c grey robe.")
	for index in range(3):
		assert_true(world.hero.inventory[index].is_empty())
	assert_eq(world.hero.inventory.slice(3), retained)
	assert_eq(world.hero.equipment, equipment)
	assert_eq(world.vendor_stock, stock)
	assert_false(world.sell_all_grey(merchant))
	assert_eq(world.hero.copper, 53)
	assert_eq(world.turn_count, 0)


func test_bulk_sale_rejects_distant_dead_stale_and_busy_merchants_without_transfer() -> void:
	var world := NorthshireZone.create_world(819, false)
	var merchant := _merchant(world, 152)
	world.hero.inventory[0] = ItemData.instance(7073, 2)
	assert_false(world.sell_all_grey(merchant))
	_beside(world, merchant)
	merchant.alive = false
	assert_false(world.sell_all_grey(merchant))
	merchant.alive = true
	world.pending_skill = SkillRank.catalog(&"fireball_1")
	assert_false(world.sell_all_grey(merchant))
	world.pending_skill = null
	var other := NorthshireZone.create_world(819, false)
	assert_false(world.sell_all_grey(_merchant(other, 152)))
	assert_eq(world.hero.inventory[0], ItemData.instance(7073, 2))
	assert_eq(world.hero.copper, 0)
	world.hero.health = 0
	world.check_terminal()
	assert_false(world.sell_all_grey(merchant))


func test_all_item_catalogs_record_source_quality_including_grey_loot_and_starter_gear() -> void:
	for catalog in [ItemData.ITEMS, NorthshireItems.ITEMS, ClassItems.ITEMS,
		MerchantItems.ITEMS, LootItems.ITEMS]:
		for item in catalog.values():
			assert_true(item.has("quality"), item.title)
			assert_between(int(item.quality), 0, 4)
	assert_eq(ItemData.get_item(7073).quality, 0)
	assert_eq(ItemData.get_item(56).quality, 0)
	assert_eq(ItemData.get_item(35).quality, 1)
	assert_eq(ItemData.get_item(159).quality, 1)
	assert_eq(ItemData.get_item(2572).quality, 2)
