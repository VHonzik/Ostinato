extends GutTest


func test_source_inventory_has_every_bounded_row_and_resolves_every_reference_and_item() -> void:
	var count := 0
	for key in NorthshireLoot.TABLES:
		count += NorthshireLoot.TABLES[key].size()
		for row in NorthshireLoot.TABLES[key]:
			if int(row[3]) < 0:
				assert_true(NorthshireLoot.REFERENCES.has(str(-int(row[3]))))
			else:
				var item := ItemData.get_item(int(row[0]))
				assert_false(item.is_empty(), str(row[0]))
				assert_lte(int(row[4]), int(item.stack))
	assert_eq(count, 71, "Seven complete creature tables and two object tables.")
	assert_eq(NorthshireLoot.REFERENCES["60000"].size(), 23)
	assert_eq(NorthshireLoot.REFERENCES["60441"].size(), 5)
	for rows in NorthshireLoot.REFERENCES.values():
		for row in rows:
			assert_false(ItemData.get_item(int(row[0])).is_empty())
	assert_eq(ItemData.get_item(2057).minimum, 2)
	assert_eq(ItemData.get_item(2057).maximum, 4)
	assert_eq(ItemData.get_item(2057).interval, 2.0)
	assert_eq(ItemData.get_item(7280).stats, {"stamina": 1})
	assert_eq(ItemData.get_item(3471).stats, {"strength": 1})
	assert_eq(ItemData.get_item(4766).stats, {"agility": 1})


func test_chest_food_group_has_exclusive_weighted_intervals_and_no_drop_remainder() -> void:
	var group: Array = NorthshireLoot.TABLES["2843"].filter(
		func(row: Array) -> bool: return row[2] == 1)
	for fixture in [[0.0, 117], [18.999, 117], [19.0, 2070], [36.999, 2070],
		[37.0, 4536], [55.999, 4536], [56.0, 4540], [74.999, 4540]]:
		assert_eq(LootData.select_group(group, fixture[0])[0], fixture[1])
	assert_eq(LootData.select_group(group, 75.0), [])
	assert_eq(LootData.select_group(group, 99.999), [])
	var bags: Array = NorthshireLoot.REFERENCES["60441"]
	for fixture in [[0.0, 805], [19.999, 805], [20.0, 828], [40.0, 4496],
		[60.0, 5571], [80.0, 5572], [99.999, 5572]]:
		assert_eq(LootData.select_group(bags, fixture[0])[0], fixture[1])


func test_reference_rolls_select_equipment_and_bags_once_and_keep_source_quantities() -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 3841
	var quantities: Array[int] = []
	for repeat in range(100):
		var grey := LootData.roll_table([[60000, 100, 0, -60000, 1]], generator)
		assert_eq(grey.size(), 1)
		assert_ne(ItemData.get_item(int(grey[0].id)).slot, "")
		assert_eq(int(grey[0].quantity), 1)
		var bags := LootData.roll_table([[60441, 100, 0, -60441, 1]], generator)
		assert_eq(bags.size(), 1)
		assert_true(int(bags[0].id) in [805, 828, 4496, 5571, 5572])
		var loot := LootData.roll_table([[7073, 100, 0, 1, 2]], generator)
		assert_eq(loot.size(), 1)
		assert_true(int(loot[0].quantity) in [1, 2])
		if not quantities.has(int(loot[0].quantity)):
			quantities.append(int(loot[0].quantity))
	assert_eq(quantities.size(), 2, "Controlled sequence exercises both quantity endpoints.")


func test_known_seed_619_treasure_and_ordinary_drops() -> void:
	var world := NorthshireZone.create_world(619, false)
	var fixtures := [
		["wolves/0/0", 0, [ItemData.instance(4865)]],
		["vermin/0/0", 3, []],
		["vineyard/0/0", 3, [ItemData.instance(2070)]],
		["treasure/mine/0", 14, [ItemData.instance(159), ItemData.instance(1364),
			ItemData.instance(4540)]],
		["treasure/vineyard/0", 20, [ItemData.instance(1377), ItemData.instance(4540)]],
		["treasure/valley/0", 16, [ItemData.instance(2652), ItemData.instance(117, 2)]],
	]
	for fixture in fixtures:
		var actor := _source(world, fixture[0])
		LootData.assign(world, actor)
		assert_eq(actor.loot_copper, fixture[1], fixture[0])
		assert_eq(actor.loot, fixture[2], fixture[0])


func test_loot_order_and_quest_filter_never_consume_or_shift_world_randomness() -> void:
	var first := NorthshireZone.create_world(19, false)
	var second := NorthshireZone.create_world(19, false)
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
		var first := NorthshireZone.create_world(seed_value, true)
		var second := NorthshireZone.create_world(seed_value, false)
		var count := 0
		for actor in first.actors:
			assert_ne(actor.loot_table, LootData.DEVELOPMENT_SUPPLIES)
			assert_ne(actor.spawn_id, "abbey/chest/0")
			if actor.loot_table != 2843:
				continue
			count += 1
			var pool: String = actor.spawn_id.split("/")[1]
			assert_true(NorthshireZone.CHEST_POOLS[pool].has(actor.tile))
			assert_false(first.blocked_tiles.has(actor.tile))
			assert_eq(_source(second, actor.spawn_id).tile, actor.tile)
			positions[actor.tile] = true
		assert_eq(count, 3)
	assert_gt(positions.size(), 3, "Different seeds can select other source-pool positions.")
	var world := NorthshireZone.create_world(619, true)
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
	var chest := _source(world, "treasure/valley/0")
	world.player_tile = chest.tile
	assert_true(world.open_loot(chest))
	var original := chest.loot.duplicate(true)
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(118, 5)
	assert_false(world.loot_item(chest, 0))
	assert_eq(chest.loot, original)
	world.hero.inventory[0] = {}
	assert_true(world.loot_item(chest, 0))
	assert_eq(chest.loot, [ItemData.instance(117, 2)])
	world.hero.inventory[1] = ItemData.instance(117, 19)
	assert_false(world.loot_item(chest, 0), "Whole offered stack must fit, with no partial transfer.")
	assert_eq(world.hero.inventory[1].quantity, 19)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), true)
	assert_not_null(restored)
	if restored == null:
		return
	game.restore(restored, 619, 1)
	world = game.world
	chest = _source(world, "treasure/valley/0")
	assert_eq(chest.loot, [ItemData.instance(117, 2)])
	assert_eq(chest.loot_copper, 16)
	assert_false(world.loot_item(chest, 0))
	world.hero.inventory[2] = {}
	assert_true(world.loot_item(chest, 0))
	assert_eq(world.hero.inventory[1].quantity, 20)
	assert_eq(world.hero.inventory[2], ItemData.instance(117))
	assert_true(chest.corpse_visible, "Copper remains after the last item.")
	assert_true(world.loot_money(chest))
	assert_eq(world.hero.copper, 16)
	assert_false(chest.corpse_visible)
	assert_false(world.loot_money(chest))
	assert_eq(world.turn_count, 0)
	restored = SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), true)
	assert_not_null(restored)
	if restored == null:
		return
	game.restore(restored, 619, 1)
	chest = _source(game.world, "treasure/valley/0")
	game.world.turn_count = 1000
	NorthshireZone.tick_population(game.world)
	LootData.assign(game.world, chest)
	assert_eq(chest.loot, [])
	assert_eq(chest.loot_copper, 0)
	assert_false(chest.corpse_visible, "Depletion persists after load and elapsed deadlines.")
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	chest = _source(game.world, "treasure/valley/0")
	assert_true(chest.corpse_visible)
	assert_false(chest.loot_assigned)
	LootData.assign(game.world, chest)
	assert_eq(chest.loot, original)
	assert_eq(chest.loot_copper, 16)
	assert_eq(game.world.hero.copper, 0)


func test_quest_hand_in_and_abandonment_remove_only_quest_drops_without_rerolling() -> void:
	for hand_in in [false, true]:
		var world := NorthshireZone.create_world(10, false)
		world.quests["18"] = {"handed_in": false, "counts": [0]}
		world.loot_quests.assign(["18"])
		world.ever_accepted_quest = true
		assert_true(InventoryRules.add(world.hero.inventory, ItemData.instance(752, 12)))
		assert_true(QuestRules.ready(world, "18"))
		var corpse := _source(world, "vineyard/0/0")
		corpse.health = 0
		world._check_npc_death(corpse, 0)
		assert_true(corpse.loot.any(func(item: Dictionary) -> bool: return item.id == 752),
			"Ready objectives still permit fresh quest drops.")
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


func test_replacement_identity_preserves_loot_after_reset_and_different_combat_rolls() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var first := _replace_vermin(game.world)
	var expected := first.loot.duplicate(true)
	var copper := first.loot_copper
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	for count in range(100):
		game.world.combat_random.randi()
	var second := _replace_vermin(game.world)
	assert_eq(second.spawn_id, "vermin/0/1")
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
	for count in range(18):
		world.wait_turn()
	assert_gte(world.hero.health, 62)


func test_unopened_treasure_and_partially_looted_corpse_continue_after_save_load() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var world := game.world
	var corpse := _source(world, "vineyard/0/0")
	corpse.health = 0
	world._check_npc_death(corpse, 0)
	world.player_tile = corpse.tile
	assert_true(world.loot_money(corpse))
	assert_eq(corpse.loot, [ItemData.instance(2070)])
	var experience := world.hero.experience
	var state := SaveCodec.capture(game)
	var chest := _source(world, "treasure/mine/0")
	assert_false(chest.loot_assigned)
	LootData.assign(world, chest)
	var expected := chest.loot.duplicate(true)
	var copper := chest.loot_copper
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(state)), true)
	assert_not_null(restored)
	if restored == null:
		return
	chest = _source(restored, "treasure/mine/0")
	assert_false(chest.loot_assigned)
	LootData.assign(restored, chest)
	assert_eq(chest.loot, expected)
	assert_eq(chest.loot_copper, copper)
	corpse = _source(restored, "vineyard/0/0")
	assert_true(corpse.loot_assigned)
	assert_true(corpse.corpse_visible)
	assert_eq(corpse.loot, [ItemData.instance(2070)])
	assert_eq(corpse.loot_copper, 0)
	assert_false(restored.loot_money(corpse))
	assert_true(restored.loot_item(corpse, 0))
	assert_false(corpse.corpse_visible)
	assert_false(restored.loot_item(corpse, 0))
	assert_eq(restored.hero.experience, experience, "Looting never repeats kill XP.")


func test_treasure_does_not_expire_or_replenish_after_ordinary_corpse_timeout() -> void:
	var world := NorthshireZone.create_world(619, false)
	var unopened := _source(world, "treasure/mine/0")
	var depleted := _source(world, "treasure/valley/0")
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


func _replace_vermin(world: GridWorld) -> GridActor:
	var original := _source(world, "vermin/0/0")
	original.health = 0
	world._check_npc_death(original, 0)
	world.turn_count = 30
	NorthshireZone.tick_population(world)
	var replacement := _source(world, "vermin/0/1")
	LootData.assign(world, replacement)
	return replacement


func test_loot_all_collects_money_and_later_fitting_stacks_leaving_unfit_and_ineligible_loot() -> void:
	var game := GameSession.new()
	game.new_game(619)
	var world := game.world
	var chest := _source(world, "treasure/mine/0")
	world.player_tile = chest.tile
	chest.loot_assigned = true
	chest.loot_copper = 12
	chest.loot = [ItemData.instance(35), ItemData.instance(750), ItemData.instance(159, 2)]
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(159, 20)
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
	chest = _source(restored, "treasure/mine/0")
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
		source.loot = [ItemData.instance(7073, 2), ItemData.instance(159, 3), ItemData.instance(750)]
		world.loot_quests.append("wolves")
		world.actors.append(source)
		world.player_tile = Vector2i.ZERO
		assert_false(world.loot_all(source))
		world.player_tile = Vector2i(4, 4)
		world.pending_skill = SkillRank.catalog(&"fireball_1")
		assert_false(world.loot_all(source))
		assert_eq(source.loot_copper, 7)
		assert_eq(source.loot.size(), 3)
		world.pending_skill = null
		assert_true(world.loot_all(source))
		assert_eq(world.hero.inventory[0], ItemData.instance(7073, 2))
		assert_eq(world.hero.inventory[1], ItemData.instance(159, 3))
		assert_eq(world.hero.inventory[2], ItemData.instance(750))
		assert_true(source.loot.is_empty())
		assert_false(source.corpse_visible)
		assert_false(world.loot_all(source))
		assert_eq(world.hero.copper, 7)
		assert_eq(world.turn_count, 0)
