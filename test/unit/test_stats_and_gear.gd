extends GutTest


func _hero() -> HeroState:
	var hero := HeroState.new(false)
	hero.level = 5
	hero._apply_level_stats()
	hero.inventory[0] = ItemData.instance(2572)
	return hero


func test_stat_gear_works_identically_across_classes_without_refilling_health() -> void:
	var hero := _hero()
	var health := hero.max_health
	var critical := hero.melee.critical
	hero.health = 10
	assert_true(InventoryRules.equip(hero, 0))
	assert_eq(hero.max_health, health + 10)
	assert_eq(hero.health, 10)
	assert_almost_eq(hero.melee.critical, critical + 1.0, 0.00001)
	assert_almost_eq(hero.attack_haste(), 1.05, 0.00001)
	var stats := [hero.strength, hero.agility, hero.stamina, hero.max_health,
		hero.melee.armor, hero.melee.attack_power, hero.melee.critical, hero.attack_haste()]
	for category in ClassSkillData.PLAYABLE_CLASSES:
		hero.selected_class = category
		hero.refresh_stats()
		assert_eq([hero.strength, hero.agility, hero.stamina, hero.max_health,
			hero.melee.armor, hero.melee.attack_power, hero.melee.critical, hero.attack_haste()], stats)
		assert_eq(hero.health, 10)
	assert_true(InventoryRules.unequip(hero, "chest"))
	assert_eq(hero.max_health, health)
	assert_almost_eq(hero.melee.critical, critical, 0.00001)
	assert_almost_eq(hero.attack_haste(), 1.0, 0.00001)
	assert_eq(hero.health, 10)


func test_gear_haste_stacks_with_buffs_and_refresh_does_not_bank_or_reset_swings() -> void:
	var hero := _hero()
	assert_true(InventoryRules.equip(hero, 0))
	hero.swing.remaining = 1.25
	hero.off_hand_swing.remaining = 0.75
	hero.buffs[&"slice_and_dice_1"] = {"armor": 0, "until": 100, "haste_percent": 30}
	for count in range(5):
		hero.refresh_stats()
	assert_almost_eq(hero.attack_haste(), 1.365, 0.00001)
	assert_eq([hero.swing.remaining, hero.off_hand_swing.remaining], [1.25, 0.75])
	var critical := hero.melee.critical
	hero.buffs.clear()
	hero.refresh_stats()
	assert_almost_eq(hero.attack_haste(), 1.05, 0.00001)
	assert_eq(hero.melee.critical, critical)
	assert_eq([hero.swing.remaining, hero.off_hand_swing.remaining], [1.25, 0.75])


func test_gear_stats_are_rebuilt_on_load_and_lost_on_death_with_learning_retained() -> void:
	var game := GameSession.new()
	game.new_game(79)
	game.world.hero.level = 5
	game.world.hero._apply_level_stats()
	game.world.hero.inventory[0] = ItemData.instance(2572)
	assert_true(InventoryRules.equip(game.world.hero, 0))
	game.world.hero.warrior_progress = 100
	assert_true(game.world.hero.learn_skill(SkillRank.catalog(&"cruelty_1")))
	game.world.hero.health = 10
	game.world.hero.swing.remaining = 1.25
	game.world.hero.off_hand_swing.remaining = 0.75
	var snapshot := SaveCodec.capture(game)
	assert_false(snapshot.hero.has("haste"), "Derived gear stats are not saved as extra bonuses.")
	assert_false(snapshot.hero.has("spell_power"))
	assert_false(snapshot.hero.has("mana"))
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_almost_eq(restored.hero.attack_haste(), 1.05, 0.00001)
	assert_eq(restored.hero.health, 10)
	assert_eq(restored.hero.max_health, game.world.hero.max_health)
	assert_eq(restored.hero.melee.critical, game.world.hero.melee.critical)
	assert_eq([restored.hero.swing.remaining, restored.hero.off_hand_swing.remaining], [1.25, 0.75])
	restored.discard()
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.level, 1)
	assert_false(game.world.hero.equipment.has("chest"))
	assert_almost_eq(game.world.hero.attack_haste(), 1.0, 0.00001)
	assert_not_null(game.world.hero.find_skill(&"cruelty_1"))
	assert_eq(game.world.hero.warrior_progress, 100)


func test_janos_sells_usable_stat_gear_and_health_supplies_with_finite_stock() -> void:
	var game := GameSession.new()
	game.new_game(79)
	var world := game.world
	var janos: GridActor
	for actor in world.actors:
		if actor.npc_id == 900003:
			janos = actor
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(janos.tile + direction):
			world.player_tile = janos.tile + direction
			break
	world.hero.level = 5
	world.hero._apply_level_stats()
	world.hero.copper = 1000
	assert_true(world.buy_item(janos, 2572, 1))
	assert_false(world.buy_item(janos, 2572, 1))
	assert_eq(world.hero.equipment.chest.id, 2572)
	assert_almost_eq(world.hero.attack_haste(), 1.05, 0.00001)
	assert_true(world.buy_item(janos, 118, 3))
	assert_eq(world.vendor_stock[janos.spawn_id]["118"], 0)
	assert_false(MerchantData.catalog(900003).has("2455"))
	for identifier in [2455, 6527, 2950]:
		assert_true(ItemData.get_item(identifier).is_empty())


func test_all_current_equipment_definitions_use_only_supported_item_stats() -> void:
	for catalog in [ItemData.ITEMS, NorthshireItems.ITEMS, ClassItems.ITEMS,
		MerchantItems.ITEMS, LootItems.ITEMS]:
		for identifier in catalog:
			for stat in catalog[identifier].stats:
				assert_has(["strength", "agility", "stamina", "crit", "haste"], stat, identifier)


func test_gear_haste_adds_swings_without_accelerating_active_actions_or_cooldowns() -> void:
	var counts: Array[int] = []
	for geared in [false, true]:
		var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
		world.hero.level = 5
		world.hero._apply_level_stats()
		if geared:
			world.hero.inventory[0] = ItemData.instance(2572)
			assert_true(InventoryRules.equip(world.hero, 0))
		var target := GridActor.new(Vector2i(6, 5))
		target.relationship = GridActor.Relationship.HOSTILE
		target.max_health = 10000
		target.health = 10000
		target.stunned_until = 1000
		target.melee.dodge = 0.0
		world.actors.append(target)
		world.hero.melee.hit = 100.0
		world.hero.rage = 100
		assert_true(world.cast_skill(&"mortal_strike_1", target))
		assert_eq(world.turn_count, 1)
		assert_eq(world.hero.cooldowns["mortal_strike"], 5)
		for turn in range(59):
			world.wait_turn()
		counts.append(Array(world.messages).filter(func(message: String) -> bool:
			return message.begins_with("You ->")).size())
		assert_eq(world.turn_count, 60)
		world.discard()
	assert_eq(counts, [21, 22])
