extends GutTest


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
	chest.loot_table = 2843
	world.actors.append(chest)
	assert_true(world.open_loot(chest))
	var original := chest.loot.duplicate(true)
	world.hero.equipment.neck = ItemData.instance(70001)
	world.hero.equipment.ring_1 = ItemData.instance(70002)
	world.hero.equipment.ring_2 = ItemData.instance(70003)
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
	assert_true(world.equip_item(0), "Armor is usable in every class.")
	assert_eq(world.hero.melee.armor, 90, "One armor outfit replaces travel clothes.")
	assert_eq(world.hero.health, 10)
	assert_eq(world.turn_count, 1)
	world.hero.inventory[1] = ItemData.instance(2572)
	var max_health := world.hero.max_health
	# Inspect the gear transaction without the world's periodic health regeneration.
	assert_true(InventoryRules.equip(world.hero, 1), "Uncommon armor is usable at level one.")
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.max_health, max_health + 10)
	assert_eq(world.hero.health, 10, "Equipment itself never refills.")
	assert_true(world.unequip_item("armor"))


func test_weapon_setups_swap_as_one_item_with_a_full_bag() -> void:
	var world := _world()
	world.hero.inventory[0] = ItemData.instance(2129)
	assert_true(world.equip_item(0))
	assert_eq(world.hero.equipment.weapons.id, 2129)
	assert_eq(world.hero.melee.armor, 78)
	_fill(world.hero)
	world.hero.inventory[0] = ItemData.instance(35)
	assert_true(world.equip_item(0), "The source slot fits the entire displaced pair.")
	assert_eq(world.hero.inventory[0].id, 2129)
	assert_eq(world.hero.equipment.weapons.id, 35)
	assert_eq(world.hero.melee.armor, 8)
	var before := world.hero.equipment.duplicate(true)
	assert_false(world.unequip_item("weapons"), "A full bag cannot hold the removed setup.")
	assert_eq(world.hero.equipment, before)


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
	trader.npc_id = 900003
	trader.spawn_id = "fixed/900003"
	world.actors.append(trader)
	world.vendor_stock = MerchantData.initial_stock(world.actors)
	world.hero.copper = 59
	assert_false(world.buy_item(trader, 118, 3))
	assert_eq(world.hero.copper, 59)
	assert_eq(world.vendor_stock["fixed/900003"]["118"], 3)
	world.hero.copper = 60
	assert_true(world.buy_item(trader, 118, 3))
	assert_eq(world.hero.copper, 0)
	assert_eq(world.hero.inventory[0].quantity, 3)
	assert_eq(world.vendor_stock["fixed/900003"]["118"], 0)
	assert_false(world.sell_item(trader, 0, 4))
	assert_true(world.sell_item(trader, 0, 2))
	assert_eq(world.hero.copper, 10)
	assert_eq(world.hero.inventory[0].quantity, 1)
	assert_eq(world.turn_count, 0)
	for turn in range(40):
		world.wait_turn()
	assert_eq(world.vendor_stock["fixed/900003"]["118"], 0)
	_fill(world.hero)
	var money := world.hero.copper
	assert_false(world.buy_item(trader, 117, 1))
	assert_eq(world.hero.copper, money)
	assert_eq(world.vendor_stock["fixed/900003"]["117"], -1)


func test_potion_cooldown_is_shared_and_rejected_use_is_free() -> void:
	var world := _world()
	world.hero.level = 5
	world.hero._apply_level_stats()
	world.hero.health = 1
	world.hero.inventory[0] = ItemData.instance(118, 2)
	world.hero.inventory[1] = ItemData.instance(118)
	assert_true(world.consume_item(0))
	assert_between(world.hero.health, 71, 91)
	assert_eq(world.hero.inventory[0].quantity, 1)
	assert_false(world.consume_item(1))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.inventory[1].quantity, 1)
	assert_eq(world.hero.potion_ready_turn, 121)
	world.turn_count = 121
	assert_true(world.consume_item(1))


func test_apple_heals_five_per_wait_for_ten_turns_and_save_preserves_remaining_meal() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.world = GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	var world := game.world
	var control := GridWorld.new(world.bounds, world.player_tile, 97, false)
	world.hero.level = 10
	world.hero.refresh_stats()
	control.hero.level = 10
	control.hero.refresh_stats()
	world.hero.health = 1
	control.hero.health = 1
	world.hero.inventory[0] = ItemData.instance(4536)
	assert_true(world.consume_item(0))
	control.wait_turn()
	assert_eq(world.hero.health, control.hero.health, "Eating starts the next turn.")
	for elapsed in range(1, 11):
		world.wait_turn()
		control.wait_turn()
		assert_eq(world.hero.health - control.hero.health, elapsed * 5)
		if elapsed == 4:
			var restored := SaveCodec.restore(SaveCodec.capture(game), false)
			assert_not_null(restored)
			if restored == null:
				return
			game.restore(restored, 97, 1)
			world = game.world
	assert_true(world.hero.restoration.is_empty())
	world.wait_turn()
	control.wait_turn()
	assert_eq(world.hero.health - control.hero.health, 50, "No eleventh healing tick.")


func test_apple_ends_on_successful_movement_and_caps_health() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	world.hero.inventory[0] = ItemData.instance(4536, 2)
	world.hero.health = world.hero.max_health - 1
	assert_true(world.consume_item(0))
	world.wait_turn()
	assert_eq(world.hero.health, world.hero.max_health)
	world.blocked_tiles[world.player_tile + Vector2i.RIGHT] = true
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_false(world.hero.restoration.is_empty(), "Blocked movement keeps eating.")
	assert_true(world.move_player(Vector2i.DOWN))
	assert_true(world.hero.restoration.is_empty())
	assert_true(world.consume_item(0))
	var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.stunned_until = 999
	world.actors.append(enemy)
	world.wait_turn()
	assert_true(world.hero.restoration.is_empty(), "Combat still interrupts eating.")


func test_acquired_gear_fills_empty_slots_with_full_bag_and_never_displaces_hands() -> void:
	var hero := HeroState.new(false)
	hero.equipment.erase("armor")
	_fill(hero)
	assert_true(InventoryRules.receive(hero, ItemData.instance(2649)))
	assert_eq(hero.equipment.armor.id, 2649)
	var before := hero.inventory.duplicate(true)
	assert_false(InventoryRules.receive(hero, ItemData.instance(2649)))
	assert_eq(hero.inventory, before)
	assert_false(InventoryRules.receive(hero, ItemData.instance(2129)),
		"The starting two-handed staff prevents a shield from auto-equipping.")
	assert_eq(hero.equipment.weapons.id, 35)
	assert_false(hero.equipment.has("off_hand"))
	assert_false(InventoryRules.receive(hero, ItemData.instance(2653, 2)),
		"An extra copy must fit before either copy is transferred.")
	assert_eq(hero.equipment.armor.id, 2649)
	hero.inventory[0] = {}
	assert_true(InventoryRules.receive(hero, ItemData.instance(2129)))
	assert_eq(hero.inventory[0].id, 2129)
	assert_false(hero.equipment.has("off_hand"))


func test_looting_and_buying_auto_equip_vacant_slots_without_spending_turns() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	world.hero.equipment.erase("armor")
	var corpse := GridActor.new(Vector2i(4, 5))
	corpse.alive = false
	corpse.loot_assigned = true
	corpse.loot = [ItemData.instance(2649)]
	world.actors.append(corpse)
	assert_true(world.loot_item(corpse, 0))
	assert_eq(world.hero.equipment.armor.id, 2649)
	assert_true(world.hero.inventory.all(func(item: Dictionary) -> bool: return item.is_empty()))
	var trader := GridActor.new(Vector2i(6, 5))
	trader.npc_id = 900003
	trader.spawn_id = "fixed/900003"
	trader.service = &"Trader"
	world.actors.append(trader)
	world.vendor_stock = MerchantData.initial_stock(world.actors)
	world.hero.equipment.erase("weapons")
	world.hero.copper = 200
	assert_true(world.buy_item(trader, 2132, 1))
	assert_eq(world.hero.equipment.weapons.id, 2132)
	assert_true(world.hero.inventory.all(func(item: Dictionary) -> bool: return item.is_empty()))
	assert_eq(world.turn_count, 0)


func test_shield_armor_reduces_damage_from_front_and_rear() -> void:
	var defender := HeroState.new().melee
	defender.dodge = 0
	defender.armor = 485
	var attacker := MeleeProfile.new()
	attacker.damage_min = 10
	attacker.damage_max = 10
	attacker.critical = 0
	assert_eq(MeleeRules.outcome(attacker, defender, false, 7.0), &"hit")
	assert_eq(MeleeRules.outcome(attacker, defender, true, 7.0), &"hit")
	assert_eq(MeleeRules.damage(attacker, defender, &"hit", 0.0), 5)


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(4, 4), 97)
	return world


func _fill(hero: HeroState) -> void:
	for index in range(40):
		hero.inventory[index] = ItemData.instance(35)


func test_empty_death_removes_corpse_without_losing_kill_identity_or_xp() -> void:
	var world := _world()
	var corpse := GridActor.new(Vector2i(4, 5))
	corpse.relationship = GridActor.Relationship.NEUTRAL
	corpse.health = 0
	world.actors.append(corpse)
	var random_before := world.random.state
	world._check_npc_death(corpse)
	assert_false(corpse.alive)
	assert_true(corpse.loot_assigned)
	assert_false(corpse.corpse_visible)
	assert_false(world.interaction_candidates().has(corpse))
	assert_true(world.is_open(corpse.tile))
	assert_same(world.actors[0], corpse, "Dead identities remain for quest progress and effect indices.")
	assert_eq(world.hero.experience, 50)
	world._check_npc_death(corpse)
	assert_eq(world.hero.experience, 50)
	assert_eq(world.random.state, random_before)
	assert_eq(world.turn_count, 0)


func test_corpse_remains_with_money_or_inventory_blocked_loot_then_disappears() -> void:
	var world := _world()
	var corpse := GridActor.new(Vector2i(4, 5))
	corpse.relationship = GridActor.Relationship.NEUTRAL
	corpse.health = 0
	corpse.loot_assigned = true
	corpse.loot_copper = 5
	corpse.loot.append(ItemData.instance(118))
	world.actors.append(corpse)
	world._check_npc_death(corpse)
	assert_true(corpse.corpse_visible)
	_fill(world.hero)
	assert_true(world.loot_all(corpse), "Money is collected even with a full inventory.")
	assert_eq(corpse.loot_copper, 0)
	assert_eq(corpse.loot.size(), 1)
	assert_true(corpse.corpse_visible)
	assert_true(world.interaction_candidates().has(corpse))
	world.hero.inventory[0] = {}
	assert_true(world.loot_item(corpse, 0))
	assert_false(corpse.corpse_visible)
	assert_false(world.open_loot(corpse))
	assert_false(world.interaction_candidates().has(corpse))
	assert_eq(world.turn_count, 0)


func test_save_load_hides_empty_corpses_and_preserves_loot_and_unopened_chests() -> void:
	var game := GameSession.new()
	game.world = _world()
	for tile in [Vector2i(4, 5), Vector2i(5, 5), Vector2i(5, 4)]:
		var source := GridActor.new(tile)
		source.alive = false
		source.health = 0
		game.world.actors.append(source)
	game.world.actors[0].loot_assigned = true
	game.world.actors[1].loot_assigned = true
	game.world.actors[1].loot_copper = 1
	game.world.actors[2].chest = true
	game.world.actors[2].loot_table = 2843
	game.world.actors[2].spawn_id = "chest/test/0"
	var restored := SaveCodec.restore(SaveCodec.capture(game), true)
	assert_not_null(restored)
	if restored == null:
		return
	assert_false(restored.actors[0].corpse_visible)
	assert_true(restored.actors[1].corpse_visible)
	assert_true(restored.actors[2].corpse_visible)
	assert_false(restored.actors[2].loot_assigned)
	assert_true(restored.open_loot(restored.actors[2]))
	assert_gt(restored.actors[2].loot_copper, 0)
	assert_true(restored.loot_money(restored.actors[1]))
	assert_false(restored.actors[1].corpse_visible)
	var next_game := GameSession.new()
	next_game.world = restored
	var again := SaveCodec.restore(SaveCodec.capture(next_game), true)
	assert_not_null(again)
	if again != null:
		assert_false(again.actors[0].corpse_visible)
		assert_false(again.actors[1].corpse_visible)


func test_opening_empty_source_hides_it_without_a_loot_panel_or_turn() -> void:
	var world := _world()
	var corpse := GridActor.new(Vector2i(4, 5))
	corpse.alive = false
	world.actors.append(corpse)
	assert_false(world.open_loot(corpse))
	assert_true(corpse.loot_assigned)
	assert_false(corpse.corpse_visible)
	assert_eq(world.turn_count, 0)
