extends GutTest


func test_paid_training_enforces_class_level_money_and_previous_rank_without_spending_time() -> void:
	var world := _world()
	world.hero.copper = 1000
	assert_false(world.train(&"Mage", &"fireball_2"))
	world.hero.level = 6
	world.hero._apply_level_stats()
	assert_false(world.train(&"Druid", &"wrath_2"))
	world.hero.copper = 99
	assert_false(world.train(&"Mage", &"fireball_2"))
	assert_eq(world.hero.copper, 99)
	world.hero.copper = 100
	assert_true(world.train(&"Mage", &"fireball_2"))
	assert_eq(world.hero.copper, 0)
	assert_false(world.train(&"Mage", &"fireball_2"))
	assert_eq(world.hero.learned_skills.filter(func(s: SkillRank) -> bool: return s.id == &"fireball_2").size(), 1)
	world.hero.level = 8
	world.hero.copper = 200
	assert_false(world.train(&"Mage", &"frostbolt_2"), "Rank 1 must be learned first.")
	assert_eq(world.hero.copper, 200)
	assert_eq(world.turn_count, 0)


func test_higher_rank_retention_after_death_keeps_casting_but_resets_items_money_and_stock() -> void:
	var game := GameSession.new()
	game.new_game(97)
	game.world.hero.level = 6
	game.world.hero._apply_level_stats()
	game.world.hero.copper = 500
	assert_true(game.world.train(&"Mage", &"fireball_2"))
	game.world.hero.inventory[0] = ItemData.instance(118, 4)
	game.world.vendor_stock["2455"] = 0
	game.world.hero.cooldowns["fire_blast"] = 500
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.level, 1)
	assert_eq(game.world.hero.copper, 0)
	assert_true(game.world.hero.inventory.all(func(item: Dictionary) -> bool: return item.is_empty()))
	assert_eq(game.world.vendor_stock["2455"], 3)
	assert_eq(game.world.hero.cooldowns, {})
	assert_true(game.select_class(&"Druid"))
	var target := game.world.actors[5]
	game.world.player_tile = Vector2i(20, 15)
	assert_true(game.world.cast_skill(&"fireball_2", target), "Class and current level do not gate casting.")
	while game.world.pending_skill != null:
		game.world.continue_cast()
	assert_eq(game.world.hero.mana, 120)


func test_loot_is_seeded_by_identity_independent_of_kill_order_and_combat_rng() -> void:
	var first := GameSession.new()
	var second := GameSession.new()
	first.new_game(619)
	second.new_game(619)
	for index in [2, 5, 6]:
		var actor := first.world.actors[index]
		actor.health = 0
		first.world._check_npc_death(actor)
	for index in [6, 5, 2]:
		for roll in range(17):
			second.world.combat_random.randf()
		var actor := second.world.actors[index]
		actor.health = 0
		second.world._check_npc_death(actor)
	for index in [2, 5, 6]:
		assert_eq(first.world.actors[index].loot, second.world.actors[index].loot)
	var chest := first.world.actors[-1]
	LootData.assign(first.world, chest)
	var original := chest.loot.duplicate(true)
	var money := chest.loot_copper
	first.world.hero.health = 0
	first.restart_after_death()
	LootData.assign(first.world, first.world.actors[-1])
	assert_eq(first.world.actors[-1].loot, original)
	assert_eq(first.world.actors[-1].loot_copper, money)


func test_full_inventory_preserves_loot_and_repeated_collection_cannot_duplicate_it() -> void:
	var world := _world()
	var chest := GridActor.new(Vector2i(4, 5))
	chest.alive = false
	chest.chest = true
	chest.spawn_id = "chest/test/0"
	world.actors.append(chest)
	assert_true(world.open_loot(chest))
	var original := chest.loot.duplicate(true)
	_fill(world.hero)
	assert_false(world.loot_item(chest, 0))
	assert_eq(chest.loot, original)
	world.hero.inventory[3] = {}
	assert_true(world.loot_item(chest, 0))
	assert_eq(chest.loot.size(), original.size() - 1)
	var money := chest.loot_copper
	assert_true(world.loot_money(chest))
	assert_false(world.loot_money(chest))
	assert_eq(world.hero.copper, money)
	assert_eq(world.turn_count, 0)


func test_quest_eligibility_filters_without_rerolling_ordinary_loot() -> void:
	var world := _world()
	var found := false
	for seed_value in range(1, 30):
		world.seed_value = seed_value
		var eligible := GridActor.new(Vector2i(4, 5))
		eligible.spawn_id = "wolf/test/0"
		eligible.loot_table = 69
		world.loot_quests.assign(["wolves"])
		LootData.assign(world, eligible)
		var without := GridActor.new(Vector2i(4, 5))
		without.spawn_id = eligible.spawn_id
		without.loot_table = 69
		world.loot_quests.clear()
		LootData.assign(world, without)
		var ordinary := eligible.loot.filter(func(item: Dictionary) -> bool: return item.id != 750)
		assert_eq(ordinary, without.loot)
		for item in eligible.loot:
			if item.id == 750:
				found = true
				assert_false(LootData.collectable(world, item))
		world.loot_quests.assign(["wolves"])
		LootData.assign(world, without)
		assert_eq(without.loot, ordinary, "Later acceptance cannot add loot retroactively.")
	assert_true(found)


func test_equipment_changes_stats_without_refilling_and_unrestricted_armor_is_usable() -> void:
	var world := _world()
	world.hero.inventory[0] = ItemData.instance(85)
	world.hero.health = 10
	world.hero.mana = 30
	assert_true(world.equip_item(0), "A mage can wear leather without a proficiency grind.")
	assert_eq(world.hero.melee.armor, 75, "40 agility armor +33 leather +2 pants.")
	assert_eq(world.hero.health, 10)
	assert_eq(world.hero.mana, 30)
	assert_eq(world.turn_count, 1)
	world.hero.inventory[1] = ItemData.instance(6527)
	assert_false(world.equip_item(1), "Item level remains enforced.")
	assert_eq(world.turn_count, 1)
	world.hero.level = 8
	world.hero._apply_level_stats()
	var maximum := world.hero.max_mana
	var health := world.hero.health
	assert_true(world.equip_item(1))
	assert_eq(world.hero.max_mana, maximum + 30)
	assert_gte(world.hero.max_health, health + 10)
	assert_lte(world.hero.health, health + 10, "Equipment itself never refills.")
	world.hero.mana = world.hero.max_mana
	assert_true(world.unequip_item("chest"))
	assert_eq(world.hero.max_mana, maximum)
	assert_lte(world.hero.mana, maximum)


func test_two_handed_swap_requires_room_for_both_displaced_items_atomically() -> void:
	var world := _world()
	world.hero.inventory[0] = ItemData.instance(2139)
	assert_true(world.equip_item(0))
	world.hero.inventory[1] = ItemData.instance(2129)
	assert_true(world.equip_item(1))
	assert_eq(world.hero.melee.interval, 1.6)
	assert_eq(world.hero.melee.block, 5.0)
	_fill(world.hero)
	world.hero.inventory[0] = ItemData.instance(35)
	var before := world.hero.equipment.duplicate(true)
	var inventory := world.hero.inventory.duplicate(true)
	var turn := world.turn_count
	assert_false(world.equip_item(0))
	assert_eq(world.hero.inventory, inventory)
	assert_eq(world.hero.equipment, before)
	assert_eq(world.turn_count, turn)
	world.hero.inventory[1] = {}
	assert_true(world.equip_item(0))
	assert_false(world.hero.equipment.has("off_hand"))
	assert_eq(world.hero.melee.interval, 2.9)
	assert_eq(world.hero.melee.block, 0.0)
	assert_false(world.equip_item(0, "off_hand"), "No dual wield capability.")


func test_stack_merge_split_swap_and_overflow_are_free_and_preserve_starter_provenance() -> void:
	var hero := HeroState.new()
	hero.inventory[0] = ItemData.instance(118, 4)
	assert_true(InventoryRules.add(hero.inventory, ItemData.instance(118, 3)))
	assert_eq(hero.inventory[0].quantity, 5)
	assert_eq(hero.inventory[1].quantity, 2)
	assert_true(InventoryRules.move(hero, 0, 3, 2))
	assert_eq(hero.inventory[0].quantity, 3)
	assert_eq(hero.inventory[3].quantity, 2)
	assert_false(InventoryRules.move(hero, 0, 1, 4))
	hero.inventory[4] = StarterGear.item(35)
	assert_true(InventoryRules.move(hero, 4, 6, 1))
	assert_true(hero.inventory[6].starter)
	_fill(hero)
	hero.inventory[0] = ItemData.instance(118, 4)
	var before := hero.inventory.duplicate(true)
	assert_false(InventoryRules.add(hero.inventory, ItemData.instance(118, 2)))
	assert_eq(hero.inventory, before, "Partial merge must roll back when the rest cannot fit.")


func test_trade_quantity_is_atomic_and_finite_stock_does_not_replenish() -> void:
	var world := _world()
	var trader := GridActor.new(Vector2i(4, 5))
	trader.service = &"Trader"
	world.actors.append(trader)
	world.hero.copper = 119
	assert_false(world.buy_item(2455, 3))
	assert_eq(world.hero.copper, 119)
	assert_eq(world.vendor_stock["2455"], 3)
	world.hero.copper = 120
	assert_true(world.buy_item(2455, 3))
	assert_eq(world.hero.copper, 0)
	assert_eq(world.hero.inventory[0].quantity, 3)
	assert_eq(world.vendor_stock["2455"], 0)
	assert_false(world.sell_item(0, 4))
	assert_true(world.sell_item(0, 2))
	assert_eq(world.hero.copper, 20)
	assert_eq(world.hero.inventory[0].quantity, 1)
	assert_eq(world.turn_count, 0)
	for turn in range(40):
		world.wait_turn()
	assert_eq(world.vendor_stock["2455"], 0)
	_fill(world.hero)
	var money := world.hero.copper
	assert_false(world.buy_item(159, 1))
	assert_eq(world.hero.copper, money)
	assert_eq(world.vendor_stock["159"], -1)


func test_potion_cooldown_is_shared_and_rejected_use_is_free() -> void:
	var world := _world()
	world.hero.level = 5
	world.hero._apply_level_stats()
	world.hero.health = 1
	world.hero.inventory[0] = ItemData.instance(118, 2)
	world.hero.inventory[1] = ItemData.instance(2455)
	assert_true(world.consume_item(0))
	assert_between(world.hero.health, 71, 91)
	assert_eq(world.hero.inventory[0].quantity, 1)
	assert_false(world.consume_item(1))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.inventory[1].quantity, 1)
	assert_eq(world.hero.potion_ready_turn, 121)
	world.turn_count = 121
	assert_true(world.consume_item(1))


func test_food_and_water_restore_only_on_turns_and_movement_or_combat_interrupts() -> void:
	var world := _world()
	world.hero.inventory[0] = ItemData.instance(159, 2)
	world.hero.mana = 0
	world.hero.last_mana_turn = 1000
	assert_true(world.consume_item(0))
	assert_eq(world.hero.mana, 0)
	for turn in range(18):
		world.wait_turn()
	assert_eq(world.hero.mana, 151)
	assert_true(world.hero.restoration.is_empty())
	assert_true(world.consume_item(0))
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_true(world.hero.restoration.is_empty())
	var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
	enemy.engaged = true
	world.actors.append(enemy)
	world.hero.inventory[0] = ItemData.instance(117)
	var turn := world.turn_count
	assert_false(world.consume_item(0))
	assert_eq(world.turn_count, turn)
	assert_eq(world.hero.inventory[0].quantity, 1)


func test_shield_blocks_front_only_and_damage_reduction_uses_block_value() -> void:
	var defender := HeroState.new().melee
	defender.dodge = 0
	defender.block = 5
	defender.block_value = 2
	var attacker := MeleeProfile.new()
	attacker.damage_min = 10
	attacker.damage_max = 10
	attacker.critical = 0
	assert_eq(MeleeRules.outcome(attacker, defender, false, 7.0), &"block")
	assert_eq(MeleeRules.outcome(attacker, defender, true, 7.0), &"hit")
	assert_eq(MeleeRules.damage(attacker, defender, &"block", 0.0, 0.0), 7)


func _world() -> GridWorld:
	return GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(4, 4), 97)


func _fill(hero: HeroState) -> void:
	for index in range(40):
		hero.inventory[index] = ItemData.instance(35)


func test_class_exchange_preserves_acquired_shield_and_stows_two_handed_starter() -> void:
	var hero := HeroState.new()
	hero.inventory[0] = ItemData.instance(2129)
	assert_true(InventoryRules.equip(hero, 0))
	assert_true(hero.equipment.has("off_hand"))
	assert_false(hero.equipment.has("main_hand"))
	assert_true(StarterGear.exchange(hero, &"Druid"))
	assert_eq(hero.equipment.off_hand.id, 2129)
	assert_false(hero.equipment.has("main_hand"))
	assert_eq(hero.inventory.filter(func(item: Dictionary) -> bool:
		return not item.is_empty() and item.id == 35 and item.starter).size(), 1)
