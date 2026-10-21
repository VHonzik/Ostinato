extends GutTest


func test_level_one_warrior_stats_use_the_starter_weapon_and_attributes() -> void:
	var hero := HeroState.new()
	assert_eq(hero.melee.attack_power, 10)
	assert_eq(hero.melee.armor, 8, "The starting outfit contributes armor.")
	assert_almost_eq(hero.melee.critical, 6.550388, 0.00001)
	assert_almost_eq(hero.melee.dodge, 4.800388, 0.00001)
	assert_eq(hero.melee.interval, 2.9)
	assert_eq([hero.melee.damage_min, hero.melee.damage_max], [3.0, 5.0])
	hero.add_experience(400)
	assert_eq(hero.melee.level, 2)
	hero.strength += 14
	hero.agility += 10
	hero.refresh_melee_stats()
	assert_eq(hero.melee.attack_power, 38)
	assert_eq(hero.melee.armor, 8)
	assert_gt(hero.melee.critical, 6.55)


func test_controlled_rolls_select_single_attack_table_outcomes() -> void:
	var attacker := HeroState.new().melee
	var target := MeleeProfile.new()
	assert_eq(MeleeRules.outcome(attacker, target, 4.99), &"miss")
	assert_eq(MeleeRules.outcome(attacker, target, 5.0), &"dodge")
	assert_eq(MeleeRules.outcome(attacker, target, 10.0), &"critical")
	assert_eq(MeleeRules.outcome(attacker, target, 50.0), &"hit")
	target.level = 4
	assert_eq(MeleeRules.outcome(attacker, target, 10.99), &"miss")
	assert_eq(MeleeRules.outcome(attacker, target, 11.0), &"dodge")


func test_dodge_is_flat_and_weapon_mastery_removes_it() -> void:
	var hero := HeroState.new()
	var npc := MeleeProfile.new()
	npc.level = 10
	assert_eq(MeleeRules.outcome(npc, hero.melee, 6.0), &"dodge")
	hero.learn_skill(SkillDefinition.catalog(&"weapon_mastery_1"))
	assert_ne(MeleeRules.outcome(hero.melee, npc, 24.0), &"dodge")
	assert_eq(MeleeRules.outcome(hero.melee, npc, 0.0), &"miss",
		"Mastery prevents dodges while preserving the miss rule.")
	hero.learn_skill(SkillDefinition.catalog(&"precision_1"))
	assert_eq(MeleeRules.miss_chance(hero.melee, npc), 0.0)
	assert_ne(MeleeRules.outcome(hero.melee, npc, 0.0), &"miss")
	assert_true(hero.off_hand_melee().cannot_miss)
	assert_true(hero.off_hand_melee().ignores_dodge)


func test_level_differences_keep_misses_dodge_and_crit_without_extra_outcomes() -> void:
	var hero := HeroState.new().melee
	var npc := MeleeProfile.new()
	hero.level = 11
	npc.level = 11
	assert_eq(MeleeRules.outcome(hero, npc, 15.0), &"critical")
	npc.level = 14
	assert_eq(MeleeRules.outcome(npc, hero, 15.0), &"critical")
	assert_eq(MeleeRules.outcome(hero, npc, 50.0), &"hit")


func test_damage_roll_armor_and_critical_have_independent_numeric_fixtures() -> void:
	var hero := HeroState.new().melee
	var npc := MeleeProfile.new()
	npc.armor = 15
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.0), 5)
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.99), 6)
	assert_eq(MeleeRules.damage(hero, npc, &"critical", 0.99), 12)
	assert_eq(MeleeRules.damage(hero, npc, &"miss", 0.99), 0)
	assert_eq(MeleeRules.damage(hero, npc, &"dodge", 0.99), 0)
	npc.armor = 485
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.99), 3)
	npc.armor = 100000
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.99), 1)


func test_higher_levels_reduce_accuracy_avoidance_crit_and_damage_with_precision_help() -> void:
	var hero := MeleeProfile.new()
	hero.player = true
	hero.damage_min = 100.0
	hero.damage_max = 100.0
	var npc := MeleeProfile.new()
	npc.level = 3
	npc.damage_min = 100.0
	npc.damage_max = 100.0
	assert_eq(MeleeRules.outcome(hero, npc, 8.99), &"miss")
	assert_eq(MeleeRules.outcome(hero, npc, 9.0), &"dodge")
	assert_eq(MeleeRules.outcome(hero, npc, 14.0), &"critical")
	assert_eq(MeleeRules.outcome(hero, npc, 19.0), &"hit")
	assert_eq(MeleeRules.outcome(npc, hero, 8.0), &"dodge",
		"Dodge does not change with level; critical chance still does.")
	assert_eq(MeleeRules.damage(hero, npc, &"hit", 0.0), 76)
	assert_eq(MeleeRules.damage(npc, hero, &"hit", 0.0), 124)
	assert_eq(MeleeRules.damage(hero, npc, &"critical", 0.0), 152)
	hero.hit = 5.0
	assert_eq(MeleeRules.outcome(hero, npc, 4.0), &"dodge",
		"Precision offsets five percentage points of miss chance, including level penalties.")
	assert_eq(MeleeRules.damage(hero, npc, &"dodge", 0.0), 0)


func test_extreme_level_gaps_bound_damage_and_hit_bonuses_still_apply() -> void:
	assert_almost_eq(MeleeRules.level_damage_multiplier(1, 100), 0.1, 0.00001)
	assert_almost_eq(MeleeRules.level_damage_multiplier(100, 1), 1.9, 0.00001)
	var attacker := MeleeProfile.new()
	var defender := MeleeProfile.new()
	defender.level = 100
	assert_eq(MeleeRules.miss_chance(attacker, defender), 95.0)
	attacker.hit = 5.0
	assert_eq(MeleeRules.miss_chance(attacker, defender), 90.0)
	attacker.hit = -1000.0
	assert_eq(MeleeRules.miss_chance(attacker, defender), 100.0)


func test_damage_level_modifiers_use_equal_percentage_increases_and_reductions() -> void:
	for gap in range(1, 20):
		var outgoing := MeleeRules.level_damage_multiplier(1, 1 + gap)
		var incoming := MeleeRules.level_damage_multiplier(1 + gap, 1)
		assert_almost_eq(1.0 - outgoing, incoming - 1.0, 0.00001)
	assert_eq(MeleeRules.level_damage_multiplier(3, 3), 1.0)




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
