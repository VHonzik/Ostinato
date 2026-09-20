extends GutTest


func test_level_one_mage_stats_use_the_sourced_staff_and_attributes() -> void:
	var hero := HeroState.new()
	assert_eq(hero.melee.attack_power, 10)
	assert_eq(hero.melee.armor, 40)
	assert_almost_eq(hero.melee.critical, 1.550388, 0.00001)
	assert_almost_eq(hero.melee.dodge, 4.800388, 0.00001)
	assert_eq(hero.melee.interval, 2.9)
	assert_eq([hero.melee.damage_min, hero.melee.damage_max], [3.0, 5.0])
	hero.add_experience(400)
	assert_eq(hero.melee.level, 2)
	hero.strength += 14
	hero.agility += 10
	hero.refresh_melee_stats()
	assert_eq(hero.melee.attack_power, 24)
	assert_eq(hero.melee.armor, 60)
	assert_gt(hero.melee.critical, 1.55)


func test_controlled_rolls_select_single_attack_table_outcomes() -> void:
	var attacker := HeroState.new().melee
	var target := MeleeProfile.new()
	assert_eq(MeleeRules.outcome(attacker, target, false, 4.99), &"miss")
	assert_eq(MeleeRules.outcome(attacker, target, false, 5.0), &"dodge")
	assert_eq(MeleeRules.outcome(attacker, target, false, 10.0), &"critical")
	assert_eq(MeleeRules.outcome(attacker, target, false, 50.0), &"hit")
	target.level = 4
	assert_eq(MeleeRules.outcome(attacker, target, false, 8.99), &"miss")
	assert_eq(MeleeRules.outcome(attacker, target, false, 9.0), &"dodge")


func test_rear_attacks_remove_player_dodge_but_keep_npc_dodge() -> void:
	var hero := HeroState.new().melee
	var npc := MeleeProfile.new()
	assert_eq(MeleeRules.outcome(npc, hero, false, 6.0), &"dodge")
	assert_eq(MeleeRules.outcome(npc, hero, true, 6.0), &"critical")
	assert_eq(MeleeRules.outcome(hero, npc, true, 6.0), &"dodge")
	assert_eq(MeleeRules.outcome(npc, hero, true, 50.0), &"hit")


func test_glancing_crushing_and_level_suppression() -> void:
	var hero := HeroState.new().melee
	var npc := MeleeProfile.new()
	hero.level = 11
	npc.level = 11
	assert_eq(MeleeRules.outcome(hero, npc, false, 15.0), &"glancing")
	npc.level = 14
	assert_eq(MeleeRules.outcome(npc, hero, false, 15.0), &"crushing")
	assert_eq(MeleeRules.outcome(hero, npc, false, 50.0), &"glancing")


func test_damage_roll_armor_and_critical_have_independent_numeric_fixtures() -> void:
	var hero := HeroState.new().melee
	var npc := MeleeProfile.new()
	npc.armor = 15
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.0, 0.0), 4)
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.99, 0.0), 6)
	assert_eq(MeleeRules.damage(hero, npc, &"critical", 0.99, 0.0), 12)
	assert_eq(MeleeRules.damage(hero, npc, &"miss", 0.99, 0.0), 0)
	assert_eq(MeleeRules.damage(hero, npc, &"dodge", 0.99, 0.0), 0)
	npc.armor = 485
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.99, 0.0), 3)
	npc.armor = 100000
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.99, 0.0), 1)


func test_all_eight_facings_have_exactly_three_rear_directions() -> void:
	for facing in GridWorld.DIRECTIONS:
		var rear_count := 0
		for direction in GridWorld.DIRECTIONS:
			if MeleeRules.is_behind(facing, direction):
				rear_count += 1
		assert_eq(rear_count, 3)
	assert_true(MeleeRules.is_behind(Vector2i.RIGHT, Vector2i(-4, 1)))
	assert_false(MeleeRules.is_behind(Vector2i.RIGHT, Vector2i(4, 1)))


func test_kill_xp_level_modifiers_rounding_and_gray_boundaries() -> void:
	for fixture in [[1, 1, 50], [1, 2, 53], [1, 5, 60], [1, 20, 60],
		[2, 1, 44], [6, 1, 0], [6, 2, 15], [10, 4, 0], [10, 5, 27],
		[60, 47, 0], [60, 48, 101], [60, 60, 345]]:
		assert_eq(MeleeRules.kill_experience(fixture[0], fixture[1]), fixture[2], str(fixture))


func test_swing_timer_retains_fractional_delay_and_fast_multiple_swings() -> void:
	var timer := SwingTimer.new()
	assert_eq(timer.advance(true, 1.5), 1, "A ready initial swing is immediate.")
	assert_eq(timer.advance(true, 1.5), 0)
	assert_eq(timer.advance(true, 1.5), 1)
	assert_eq(timer.advance(true, 1.5), 1)
	assert_eq(timer.remaining, 1.5)
	timer = SwingTimer.new()
	assert_eq(timer.advance(true, 0.5), 1)
	assert_eq(timer.advance(true, 0.5), 2)
	assert_eq(timer.advance(true, 0.5), 2)


func test_idle_timer_caps_readiness_and_speed_changes_keep_delay() -> void:
	var timer := SwingTimer.new()
	assert_eq(timer.advance(true, 2.9), 1)
	assert_eq(timer.advance(false, 2.9), 0)
	assert_almost_eq(timer.remaining, 1.9, 0.00001)
	assert_eq(timer.advance(true, 0.5), 0, "New interval does not erase positive delay.")
	assert_almost_eq(timer.remaining, 0.9, 0.00001)
	for index in range(100):
		timer.advance(false, 0.5)
	assert_eq(timer.remaining, 0.0)
	assert_eq(timer.advance(true, 0.5), 1, "Idle time never banks extra swings.")
