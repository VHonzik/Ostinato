extends GutTest


func test_starting_supplies_merchants_and_loot_tables_exclude_water() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	for item in game.world.hero.inventory:
		if not item.is_empty():
			assert_ne(ItemData.get_item(int(item.id)).use, "water")
	for catalog: Dictionary in MerchantData.CATALOGS.values():
		for identifier in catalog:
			assert_ne(ItemData.get_item(int(identifier)).use, "water")
	for tables: Dictionary in [NorthshireLoot.TABLES, NorthshireLoot.REFERENCES]:
		for rows: Array in tables.values():
			for row: Array in rows:
				if int(row[3]) >= 0:
					assert_ne(ItemData.get_item(int(row[0])).use, "water")
	assert_true(ItemData.get_item(2132).two_handed)
	assert_true(NorthshireLoot.REFERENCES["60001"].any(func(row: Array) -> bool: return row[0] == 2132))
	assert_true(MerchantData.catalog(900003).has("2132"))


func test_every_loot_row_resolves_and_fits_its_stack() -> void:
	for tables in [NorthshireLoot.TABLES, NorthshireLoot.REFERENCES]:
		for rows in tables.values():
			for row in rows:
				if int(row[3]) < 0:
					assert_has(NorthshireLoot.REFERENCES, str(-int(row[3])))
				else:
					var item := ItemData.get_item(int(row[0]))
					assert_false(item.is_empty(), str(row[0]))
					assert_lte(int(row[4]), int(item.stack))


func test_chest_gear_group_has_guaranteed_common_or_less_likely_uncommon() -> void:
	var group: Array = NorthshireLoot.TABLES["2843"].filter(
		func(row: Array) -> bool: return row[2] == 1)
	assert_eq(LootData.select_group(group, 0.0)[0], 60001)
	assert_eq(LootData.select_group(group, 59.999)[0], 60001)
	assert_eq(LootData.select_group(group, 60.0)[0], 60002)
	assert_eq(LootData.select_group(group, 99.999)[0], 60002)


func test_reference_rolls_select_one_item_and_keep_quantity_endpoints() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 3841
	var quantities: Array[int] = []
	for repeat in range(100):
		var gear := LootData.roll_table([[60000, 100, 0, -60000, 1]], generator)
		assert_eq(gear.size(), 1)
		assert_eq(ItemData.get_item(int(gear[0].id)).quality, 0)
		assert_eq(int(gear[0].quantity), 1)
		var loot := LootData.roll_table([[7073, 100, 0, 1, 2]], generator)
		if not quantities.has(int(loot[0].quantity)):
			quantities.append(int(loot[0].quantity))
	assert_eq(quantities.size(), 2)


func test_seeded_chests_always_contain_usable_common_or_uncommon_gear() -> void:
	for seed_value in range(100):
		var world := ValleyRoute.create_world(seed_value, false)
		for actor in world.actors:
			if not actor.chest:
				continue
			LootData.assign(world, actor)
			var gear := actor.loot.filter(func(item: Dictionary) -> bool:
				return ItemData.get_item(int(item.id)).slot != "")
			assert_eq(gear.size(), 1)
			assert_between(int(ItemData.get_item(int(gear[0].id)).quality), 1, 2)
		world.discard()


func test_loot_order_and_quest_filter_never_consume_or_shift_world_randomness() -> void:
	var first := ValleyRoute.create_world(19, false)
	var second := ValleyRoute.create_world(19, false)
	first.loot_quests.assign(["wolves", "18", "6", "3904"])
	var random_state := first.random.state
	var combat_state := first.combat_random.state
	for actor in first.actors:
		LootData.assign(first, actor)
	var reverse := second.actors.duplicate()
	reverse.reverse()
	for actor in reverse:
		second.combat_random.randi()
		second.random.randi()
		LootData.assign(second, actor)
	for index in range(first.actors.size()):
		var source := first.actors[index]
		var ordinary := source.loot.filter(func(item: Dictionary) -> bool:
			return ItemData.get_item(int(item.id)).quest == "")
		assert_eq(second.actors[index].loot, ordinary, source.spawn_id)
		assert_eq(second.actors[index].loot_copper, source.loot_copper)
	assert_eq(first.random.state, random_state)
	assert_eq(first.combat_random.state, combat_state)


func test_chest_pools_are_seeded_legal_and_never_expose_development_supplies() -> void:
	var positions: Dictionary = {}
	for seed_value in range(12):
		var first := ValleyRoute.create_world(seed_value, true)
		var second := ValleyRoute.create_world(seed_value, false)
		var count := 0
		for actor in first.actors:
			assert_ne(actor.loot_table, LootData.DEVELOPMENT_SUPPLIES)
			assert_ne(actor.spawn_id, "abbey/chest/0")
			if actor.loot_table != 2843:
				continue
			count += 1
			var pool: String = actor.spawn_id.split("/")[2]
			assert_true(ValleyLandmarks.CHESTS[pool].tile == actor.tile)
			assert_false(first.blocked_tiles.has(actor.tile))
			assert_eq(_source(second, actor.spawn_id).tile, actor.tile)
			positions[actor.tile] = true
		assert_eq(count, 3)
	assert_eq(positions.size(), 3, "Caches are deliberate landmarks across seeds.")
	var world := ValleyRoute.create_world(619, true)
	var supplies := GridActor.new(Vector2i(20, 15))
	supplies.chest = true
	supplies.loot_table = LootData.DEVELOPMENT_SUPPLIES
	LootData.assign(world, supplies)
	assert_eq(supplies.loot, [])
	assert_eq(supplies.loot_copper, 0)
	var unknown := GridActor.new(Vector2i(20, 15))
	unknown.chest = true
	LootData.assign(world, unknown)
	assert_eq(unknown.loot, [], "An unrecognized chest cannot default to fixture rewards.")


func test_partial_collection_full_bags_depletion_save_load_and_loop_reset() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var world := game.world
	var chest := _source(world, "valley/treasure/ridge_chest")
	world.player_tile = chest.tile
	assert_true(world.open_loot(chest))
	var seeded_loot := chest.loot.duplicate(true)
	chest.loot = [ItemData.instance(1367), ItemData.instance(4540, 2)]
	var original := chest.loot.duplicate(true)
	# Filled feet force this equipment into inventory, preserving the capacity check.
	world.hero.equipment["armor"] = ItemData.instance(1374)
	world.hero.refresh_stats()
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(118, 5)
	assert_false(world.loot_item(chest, 0))
	assert_eq(chest.loot, original)
	world.hero.inventory[0] = {}
	assert_true(world.loot_item(chest, 0))
	assert_eq(chest.loot, [ItemData.instance(4540, 2)])
	world.hero.inventory[1] = ItemData.instance(4540, 19)
	assert_false(world.loot_item(chest, 0), "Whole offered stack must fit, with no partial transfer.")
	assert_eq(world.hero.inventory[1].quantity, 19)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), true)
	assert_not_null(restored)
	if restored == null:
		return
	game.restore(restored, 619, 1)
	world = game.world
	chest = _source(world, "valley/treasure/ridge_chest")
	assert_eq(chest.loot, [ItemData.instance(4540, 2)])
	assert_eq(chest.loot_copper, 12)
	assert_false(world.loot_item(chest, 0))
	world.hero.inventory[2] = {}
	assert_true(world.loot_item(chest, 0))
	assert_eq(world.hero.inventory[1].quantity, 20)
	assert_eq(world.hero.inventory[2], ItemData.instance(4540))
	assert_true(chest.corpse_visible, "Copper remains after the last item.")
	assert_true(world.loot_money(chest))
	assert_eq(world.hero.copper, 12)
	assert_false(chest.corpse_visible)
	assert_false(world.loot_money(chest))
	assert_eq(world.turn_count, 0)
	restored = SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), true)
	assert_not_null(restored)
	if restored == null:
		return
	game.restore(restored, 619, 1)
	chest = _source(game.world, "valley/treasure/ridge_chest")
	game.world.turn_count = 1000
	LootData.assign(game.world, chest)
	assert_eq(chest.loot, [])
	assert_eq(chest.loot_copper, 0)
	assert_false(chest.corpse_visible, "Depletion persists after load and elapsed deadlines.")
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	chest = _source(game.world, "valley/treasure/ridge_chest")
	assert_true(chest.corpse_visible)
	assert_false(chest.loot_assigned)
	LootData.assign(game.world, chest)
	assert_eq(chest.loot, seeded_loot)
	assert_eq(chest.loot_copper, 12)
	assert_eq(game.world.hero.copper, 0)


func test_quest_hand_in_and_abandonment_remove_only_quest_drops_without_rerolling() -> void:
	for hand_in in [false, true]:
		var world := ValleyRoute.create_world(10, false)
		world.quests["18"] = {"handed_in": false, "counts": [0]}
		world.loot_quests.assign(["18"])
		world.ever_accepted_quest = true
		assert_true(InventoryRules.add(world.hero.inventory, ItemData.instance(752, 12)))
		assert_true(QuestRules.ready(world, "18"))
		var corpse := _source(world, "valley/vineyard/9")
		corpse.spawn_id = "vineyard/0/0" # Controlled loot identity, independent of map placement.
		corpse.health = 0
		world._check_npc_death(corpse, 0)
		assert_true(corpse.loot.any(func(item: Dictionary) -> bool: return item.id == 752),
			"Ready objectives still permit fresh quest drops.")
		corpse.loot.append(ItemData.instance(4536))
		var ordinary := corpse.loot.filter(func(item: Dictionary) -> bool: return item.id != 752)
		assert_false(ordinary.is_empty(), "Fixture includes ordinary loot to preserve.")
		var copper := corpse.loot_copper
		if hand_in:
			var deputy := _source(world, "fixed/823")
			world.player_tile = deputy.tile + Vector2i.DOWN
			assert_true(QuestRules.hand_in(world, "18", deputy, 2224))
		else:
			assert_true(QuestRules.abandon(world, "18"))
		assert_eq(corpse.loot, ordinary)
		assert_eq(corpse.loot_copper, copper)
		assert_false(world.hero.inventory.any(func(item: Dictionary) -> bool:
			return not item.is_empty() and item.id == 752))
		world.loot_quests.append("18")
		LootData.assign(world, corpse)
		assert_eq(corpse.loot, ordinary, "Reacceptance cannot refill assigned loot.")


func test_encounter_identity_preserves_loot_after_reset_and_different_combat_rolls() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var first := _source(game.world, "valley/camp/0")
	LootData.assign(game.world, first)
	var expected := first.loot.duplicate(true)
	var copper := first.loot_copper
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	for count in range(100):
		game.world.combat_random.randi()
	var second := _source(game.world, "valley/camp/0")
	LootData.assign(game.world, second)
	assert_eq(second.loot, expected)
	assert_eq(second.loot_copper, copper)


func test_new_food_and_equipment_use_existing_rules_and_bags_never_expand_capacity() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 10, 10), Vector2i(5, 5), 1, false)
	world.hero.level = 6
	world.hero._apply_level_stats()
	world.hero.inventory[0] = ItemData.instance(7280)
	var stamina := world.hero.stamina
	assert_true(world.equip_item(0))
	assert_eq(world.hero.stamina, stamina + 1)
	world.hero.inventory[0] = ItemData.instance(805)
	assert_false(world.equip_item(0))
	assert_false(world.consume_item(0))
	assert_eq(world.hero.inventory.size(), 40)
	world.hero.health = 1
	world.hero.inventory[1] = ItemData.instance(4536, 2)
	assert_true(world.consume_item(1))
	assert_eq(world.hero.inventory[1].quantity, 1)
	for count in range(10):
		world.wait_turn()
	assert_gte(world.hero.health, 51)


func test_unopened_treasure_and_partially_looted_corpse_continue_after_save_load() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var world := game.world
	var corpse := _source(world, "valley/vineyard/8")
	corpse.health = 0
	world._check_npc_death(corpse, 0)
	world.player_tile = corpse.tile
	assert_true(world.loot_money(corpse))
	# Explicit remaining loot exercises persistence independently of changed drop tuning.
	corpse.loot = [ItemData.instance(4536)]
	corpse.corpse_visible = true
	var experience := world.hero.experience
	var state := SaveCodec.capture(game)
	var chest := _source(world, "valley/treasure/mine_chest")
	assert_false(chest.loot_assigned)
	LootData.assign(world, chest)
	var expected := chest.loot.duplicate(true)
	var copper := chest.loot_copper
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(state)), true)
	assert_not_null(restored)
	if restored == null:
		return
	chest = _source(restored, "valley/treasure/mine_chest")
	assert_false(chest.loot_assigned)
	LootData.assign(restored, chest)
	assert_eq(chest.loot, expected)
	assert_eq(chest.loot_copper, copper)
	corpse = _source(restored, "valley/vineyard/8")
	assert_true(corpse.loot_assigned)
	assert_true(corpse.corpse_visible)
	assert_eq(corpse.loot, [ItemData.instance(4536)])
	assert_eq(corpse.loot_copper, 0)
	assert_false(restored.loot_money(corpse))
	assert_true(restored.loot_item(corpse, 0))
	assert_false(corpse.corpse_visible)
	assert_false(restored.loot_item(corpse, 0))
	assert_eq(restored.hero.experience, experience, "Looting never repeats kill XP.")


func test_treasure_does_not_expire_or_replenish_after_ordinary_corpse_timeout() -> void:
	var world := ValleyRoute.create_world(619, false)
	var unopened := _source(world, "valley/treasure/mine_chest")
	var depleted := _source(world, "valley/treasure/ridge_chest")
	world.player_tile = depleted.tile
	assert_true(world.open_loot(depleted))
	while not depleted.loot.is_empty():
		assert_true(world.loot_item(depleted, 0))
	assert_true(world.loot_money(depleted))
	world.player_tile = Vector2i(20, 14)
	world.turn_count = 999
	world.wait_turn()
	assert_eq(world.turn_count, 1000)
	assert_true(unopened.corpse_visible)
	assert_false(unopened.loot_assigned)
	assert_false(depleted.corpse_visible)
	assert_eq(depleted.loot, [])
	assert_eq(depleted.loot_copper, 0)
	assert_eq(world.actors.filter(func(actor: GridActor) -> bool:
		return actor.loot_table == 2843).size(), 3)


func test_development_supplies_remain_only_in_the_explicit_debug_fixture() -> void:
	var debug_world := MovementFixture.create_world(619, true, true)
	var release_world := MovementFixture.create_world(619, false, true)
	var debug_chest := debug_world.actors[-1]
	var release_chest := release_world.actors[-1]
	LootData.assign(debug_world, debug_chest)
	LootData.assign(release_world, release_chest)
	assert_eq(debug_chest.loot.size(), 4)
	assert_between(debug_chest.loot_copper, 350, 450)
	assert_eq(release_chest.loot, [])
	assert_eq(release_chest.loot_copper, 0)


func _source(world: GridWorld, identity: String) -> GridActor:
	for actor in world.actors:
		if actor.spawn_id == identity:
			return actor
	fail_test("Missing source: " + identity)
	return null


func test_loot_all_collects_money_and_later_fitting_stacks_leaving_unfit_and_ineligible_loot() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var world := game.world
	var chest := _source(world, "valley/treasure/mine_chest")
	world.player_tile = chest.tile
	chest.loot_assigned = true
	chest.loot_copper = 12
	chest.loot = [ItemData.instance(35), ItemData.instance(750), ItemData.instance(117, 2)]
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(117, 20)
	world.hero.inventory[0].quantity = 18
	assert_true(world.loot_all(chest))
	assert_eq(world.hero.copper, 12)
	assert_eq(world.hero.inventory[0].quantity, 20)
	assert_eq(chest.loot, [ItemData.instance(35), ItemData.instance(750)])
	assert_true(chest.corpse_visible)
	assert_false(world.loot_all(chest))
	assert_eq(world.hero.copper, 12)
	var restored := SaveCodec.restore(SaveCodec.capture(game), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_false(restored.loot_all(chest), "A stale chest cannot authorize a transfer.")
	chest = _source(restored, "valley/treasure/mine_chest")
	assert_eq(chest.loot, [ItemData.instance(35), ItemData.instance(750)])
	restored.hero.inventory[1] = {}
	assert_true(restored.loot_all(chest))
	assert_eq(restored.hero.inventory[1].id, 35)
	assert_eq(chest.loot, [ItemData.instance(750)])
	assert_eq(restored.hero.copper, 12)
	assert_eq(restored.turn_count, 0)


func test_loot_all_empties_corpses_and_chests_once_and_obeys_action_guards() -> void:
	for is_chest in [false, true]:
		var world := GridWorld.new(Rect2i(0, 0, 8, 8), Vector2i(4, 4), 619, false)
		var source := GridActor.new(Vector2i(4, 5))
		source.alive = false
		source.corpse_visible = true
		source.chest = is_chest
		source.loot_assigned = true
		source.loot_copper = 7
		source.loot = [ItemData.instance(7073, 2), ItemData.instance(117, 3), ItemData.instance(750)]
		world.loot_quests.append("wolves")
		world.actors.append(source)
		world.player_tile = Vector2i.ZERO
		assert_false(world.loot_all(source))
		world.player_tile = Vector2i(4, 4)
		world.pending_skill = SkillDefinition.catalog(&"mortal_strike_1")
		assert_false(world.loot_all(source))
		assert_eq(source.loot_copper, 7)
		assert_eq(source.loot.size(), 3)
		world.pending_skill = null
		assert_true(world.loot_all(source))
		assert_eq(world.hero.inventory[0], ItemData.instance(7073, 2))
		assert_eq(world.hero.inventory[1], ItemData.instance(117, 3))
		assert_eq(world.hero.inventory[2], ItemData.instance(750))
		assert_true(source.loot.is_empty())
		assert_false(source.corpse_visible)
		assert_false(world.loot_all(source))
		assert_eq(world.hero.copper, 7)
		assert_eq(world.turn_count, 0)
