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
	assert_true(InventoryRules.unequip(hero, "armor"))
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
	assert_true(game.world.hero.learn_skill(SkillDefinition.catalog(&"cruelty_1")))
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
	assert_eq(game.world.hero.equipment.armor.id, 44)
	assert_almost_eq(game.world.hero.attack_haste(), 1.0, 0.00001)
	assert_not_null(game.world.hero.find_skill(&"cruelty_1"))


func test_janos_sells_common_gear_and_finite_health_supplies() -> void:
	var world := ValleyRoute.create_world(79, false)
	world.hero.inventory.fill({})
	var janos: GridActor
	for actor in world.actors:
		if actor.npc_id == 900003:
			janos = actor
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(janos.tile + direction):
			world.player_tile = janos.tile + direction
			break
	world.hero.copper = 1000
	assert_false(MerchantData.catalog(900003).has("2572"), "Uncommon is reserved for drops.")
	assert_true(world.buy_item(janos, 85, 1))
	assert_true(world.equip_item(0))
	assert_eq(world.hero.equipment.armor.id, 85)
	assert_almost_eq(world.hero.attack_haste(), 1.03, 0.00001)
	assert_true(world.buy_item(janos, 118, 3))
	assert_eq(world.vendor_stock[janos.spawn_id]["118"], 0)
	assert_false(world.buy_item(janos, 118, 1))
	assert_true(world.buy_item(janos, 117, 20))
	assert_eq(world.vendor_stock[janos.spawn_id]["117"], -1)
	world.discard()


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


func test_small_strength_bonuses_increase_average_damage_with_every_weapon_setup() -> void:
	for identifier in [5579, 5580, 2139]:
		var hero := HeroState.new(false)
		hero.level = 5
		hero.inventory[0] = ItemData.instance(identifier)
		assert_true(InventoryRules.equip(hero, 0))
		var defender := MeleeProfile.new()
		defender.level = 5
		defender.armor = 105
		var previous_power := hero.melee.attack_power
		var before := _average_damage(hero.melee, defender)
		hero.strength += 2
		hero.refresh_melee_stats()
		assert_eq(hero.melee.attack_power, previous_power + 4)
		var after := _average_damage(hero.melee, defender)
		var expected_gain := 4.0 / 14.0 * hero.melee.interval * 825.0 / 930.0
		assert_almost_eq(after - before, expected_gain, 0.002, str(identifier))
		assert_gt(after / before, 1.05, "+2 Strength remains impactful after armor and rounding.")


func test_small_agility_and_stamina_accessories_help_in_every_class_without_refilling() -> void:
	for category in ClassSkillData.PLAYABLE_CLASSES:
		var hero := HeroState.new(false)
		hero.selected_class = category
		var critical := hero.melee.critical
		var dodge := hero.melee.dodge
		var health := hero.max_health
		hero.health = 10
		hero.inventory[0] = ItemData.instance(70013)
		hero.inventory[1] = ItemData.instance(70011)
		assert_true(InventoryRules.equip(hero, 0))
		assert_true(InventoryRules.equip(hero, 1))
		assert_almost_eq(hero.melee.critical, critical + 2.0, 0.00001)
		assert_almost_eq(hero.melee.dodge, dodge + 2.0, 0.00001)
		assert_almost_eq(hero.attack_haste(), 1.06, 0.00001)
		assert_eq(hero.max_health, health + 20)
		assert_eq(hero.health, 10)
		for repeat in range(3):
			hero.refresh_stats()
		assert_almost_eq(hero.melee.critical, critical + 2.0, 0.00001)
		assert_almost_eq(hero.melee.dodge, dodge + 2.0, 0.00001)
		assert_eq(hero.health, 10)


func _average_damage(attacker: MeleeProfile, defender: MeleeProfile) -> float:
	var total := 0
	for index in range(12000):
		total += MeleeRules.damage(attacker, defender, &"hit", (index + 0.5) / 12000.0)
	return total / 12000.0
