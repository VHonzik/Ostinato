extends GutTest


func test_eviscerate_intrinsic_refund_scales_with_spent_points_without_refunding_points() -> void:
	var generator := RandomNumberGenerator.new()
	var controlled_seed := -1
	for seed_value in range(1000):
		generator.seed = seed_value
		var roll := generator.randf()
		if roll > 0.25 and roll < 0.35:
			controlled_seed = seed_value
			break
	assert_ne(controlled_seed, -1)
	for points in [1, 2, 5]:
		var world := _world(&"Rogue")
		_learn(world, [&"eviscerate_1"])
		world.hero.rage = 10
		world.hero.combo_points = 0
		world.combat_random.seed = controlled_seed
		ClassToolkitRules.finish(world, points, world.hero.find_skill(&"eviscerate_1"))
		assert_eq(world.hero.rage, 10 if points == 1 else 25,
			"The same ~30% roll fails at one point, succeeds at two; five guarantees the refund.")
		assert_eq(world.hero.combo_points, 0)


func test_terminal_eviscerate_kill_spends_points_and_rage_without_late_refunds() -> void:
	var world := _world(&"Rogue")
	_learn(world, [&"eviscerate_1", &"slice_and_dice_1"])
	var enemy := _enemy(world)
	enemy.stalker = true
	enemy.health = 1
	world.stalkers_arrived = 1
	world.hero.combo_points = 5
	world.hero.rage = 20
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_eq(world.hero.rage, 5, "Victory stops the otherwise guaranteed five-point refund.")
	assert_eq(world.hero.combo_points, 0)
	assert_false(world.hero.buffs.has(&"slice_and_dice_1"))


func test_folded_passives_are_absent_from_training_and_rejected_in_saved_learning_or_buffs() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(97)
	var snapshot := SaveCodec.capture(session)
	var passive_count := 0
	for category in ClassSkillData.PLAYABLE_CLASSES:
		for skill in SkillDefinition.trainer_skills(category):
			passive_count += int(skill.effect == SkillDefinition.Effect.PASSIVE)
	assert_eq(passive_count, 33)
	for id in ["improved_shields_1", "elemental_weapons_1", "spirit_hunt_1",
		"sanctity_of_battle_1", "sacred_duty_1", "divine_purpose_1", "eye_for_an_eye_1",
		"relentless_strikes_1", "ruthlessness_1"]:
		assert_null(SkillDefinition.catalog(StringName(id)))
		var stale_learning := snapshot.duplicate(true)
		stale_learning.learned.append(id)
		assert_null(SaveCodec.restore(stale_learning, false))
		var stale_buff := snapshot.duplicate(true)
		stale_buff.buffs[id] = {"armor": 0, "until": 0}
		assert_null(SaveCodec.restore(stale_buff, false))


func test_five_point_noncritical_eviscerate_leaves_both_wolf_types_alive() -> void:
	for identity in [299, 69]:
		var world := _world(&"Rogue")
		_learn(world, [&"eviscerate_1", &"relentless_assault_1"])
		var wolf := _enemy(world)
		var profile: Dictionary = NorthshireData.CREATURES[str(identity)]
		wolf.max_health = profile.health
		wolf.health = wolf.max_health
		wolf.melee.level = profile.level
		wolf.melee.armor = profile.armor
		world.hero.combo_points = 5
		assert_true(world.cast_skill(&"eviscerate_1", wolf))
		assert_true(wolf.alive)
		assert_lt(wolf.health, wolf.max_health)
		assert_gt(wolf.health, 0)


func _world(category: StringName = &"Warrior") -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(8, 8), 97, false)
	world.hero.selected_class = category
	return world


func _learn(world: GridWorld, identifiers: Array[StringName]) -> void:
	for identifier in identifiers:
		var skill := SkillDefinition.catalog(identifier)
		assert_true(world.hero.learn_skill(skill))
	world.hero.melee.hit = 100.0
	world.hero.melee.critical = 0.0
	world.hero.melee.attack_power = 0
	world.hero.melee.damage_min = 20.0
	world.hero.melee.damage_max = 20.0
	world.hero.swing.remaining = 100.0
	world.hero.swing._active = true
	world.hero.rage = 100


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(9, 8)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.title = "Enemy"
	enemy.max_health = 10000
	enemy.health = 10000
	enemy.awards_experience = false
	enemy.stunned_until = 999
	enemy.melee.armor = 0
	enemy.melee.dodge = 0
	world.actors.append(enemy)
	return enemy


func _off_hand_procs(world: GridWorld, enemy: GridActor) -> void:
	var event := AttackEvent.new(enemy, null, &"hit", 0)
	event.hand = AttackEvent.Hand.OFF
	AttackProcs.weapon_procs(world, event)


func test_all_four_kits_require_level_and_gold_preserving_full_hotbar() -> void:
	var counts := {&"Warrior": 16, &"Shaman": 8, &"Paladin": 11, &"Rogue": 15}
	for category: StringName in counts:
		var world := _world(category)
		var skills := SkillDefinition.trainer_skills(category)
		assert_eq(skills.size(), counts[category])
		world.hotbar.fill(&"mortal_strike_1")
		for skill in skills:
			if world.hero.find_skill(skill.id) != null:
				continue
			world.hero.level = skill.training_level
			world.hero.copper = skill.training_copper
			if skill.training_level > 1:
				world.hero.level -= 1
				assert_false(world.train(category, skill.id), "Level gates learning.")
				assert_eq(world.hero.copper, skill.training_copper)
				world.hero.level += 1
			if skill.training_copper > 0:
				world.hero.copper -= 1
				assert_false(world.train(category, skill.id), "Gold gates learning.")
				assert_null(world.hero.find_skill(skill.id))
				world.hero.copper += 1
			var experience := world.hero.experience
			assert_true(world.train(category, skill.id), skill.title)
			assert_eq(world.hero.copper, 0)
			assert_eq(world.hero.experience, experience, "Training does not spend player XP.")
			assert_false(world.train(category, skill.id), "Cannot buy twice.")
			assert_eq(world.hero.copper, 0)
		assert_eq(world.hotbar.count(&"mortal_strike_1"), GridWorld.HOTBAR_SIZE)


func test_trainers_list_unlocks_in_price_order() -> void:
	for category in ClassSkillData.PLAYABLE_CLASSES:
		var previous := -1
		for skill in SkillDefinition.trainer_skills(category):
			assert_gte(skill.training_copper, previous, String(category) + ": " + skill.title)
			previous = skill.training_copper


func test_early_rogue_haste_is_paid_and_passive() -> void:
	var world := _world(&"Rogue")
	for starter in ClassSkillData.STARTERS[&"Rogue"]:
		assert_true(world.train(&"Rogue", starter))
	assert_false(world.train(&"Rogue", &"slice_and_dice_1"))
	world.hero.rage = 100
	world.hero.combo_points = 1
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	world.hero.copper = SkillDefinition.catalog(&"slice_and_dice_1").training_copper
	assert_true(world.train(&"Rogue", &"slice_and_dice_1"))
	world.hero.combo_points = 2
	assert_false(world.cast_skill(&"slice_and_dice_1"), "Slice and Dice is passive.")
	assert_false(world.assign_hotbar(0, &"slice_and_dice_1"))
	assert_true(world.cast_skill(&"eviscerate_1", enemy))


func test_stat_passives_work_in_other_classes_and_refresh_does_not_stack_them() -> void:
	var world := _world(&"Paladin")
	var base_armor := world.hero.melee.armor
	var base_crit := world.hero.melee.critical
	_learn(world, [&"cruelty_1", &"conviction_1", &"precision_1", &"toughness_1"])
	world.hero.melee.hit = 5.0
	world.hero.refresh_stats()
	assert_eq(world.hero.melee.hit, 5.0)
	assert_almost_eq(world.hero.melee.critical, base_crit + 13, 0.001)
	assert_eq(world.hero.melee.armor, floori(base_armor * 1.2))
	world.hero.refresh_stats()
	assert_eq(world.hero.melee.hit, 5.0)
	assert_almost_eq(world.hero.melee.critical, base_crit + 13, 0.001)


func test_holy_and_fire_actives_share_level_penalties_while_bypassing_armor() -> void:
	for identifier: StringName in [&"judgement_1", &"lava_burst_1"]:
		var world := _world()
		_learn(world, [&"judgement_1", &"lava_burst_1", &"seal_of_command_1"])
		var enemy := _enemy(world)
		enemy.melee.level = 3
		enemy.melee.armor = 100000
		var expected := 36 if identifier == &"lava_burst_1" else 49
		assert_true(world.cast_skill(identifier, enemy))
		while world.pending_skill != null:
			world.hero.melee.critical = -100
			world.continue_cast()
		if identifier == &"judgement_1":
			for turn in range(world.hero.find_skill(identifier).delay_turns):
				world.wait_turn()
		assert_eq(enemy.max_health - enemy.health, expected,
			"A +2 target reduces spell damage once, without physical armor mitigation.")


func test_level_penalties_apply_once_to_seal_and_lightning_shield_damage() -> void:
	var world := _world()
	_learn(world, [&"seal_of_command_1", &"lightning_shield_1"])
	var enemy := _enemy(world)
	enemy.melee.level = 3
	ClassSpellEffects.on_melee(world, AttackEvent.new(enemy, null, &"hit", 20))
	assert_eq(enemy.max_health - enemy.health, 4,
		"Seal averages 3.8 damage: a quarter of 20, then the level penalty, with unbiased rounding.")
	world.hero.buffs[&"lightning_shield_1"] = {"armor": 0, "until": 100,
		"charges": 3, "ready": 0}
	var before := enemy.health
	ClassToolkitRules.discharge(world, enemy, true)
	assert_eq(before - enemy.health, 11, "Reactive Nature damage also respects the level gap.")
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 2)


func test_holy_weapon_damage_keeps_fractional_power_without_extra_random_draws() -> void:
	var world := _world()
	_learn(world, [&"seal_of_command_1"])
	world.hero.melee.attack_power = 4
	var enemy := _enemy(world)
	enemy.max_health = 1000000
	enemy.health = enemy.max_health
	enemy.melee.level = 3
	var generator := RandomNumberGenerator.new()
	generator.state = world.combat_random.state
	for index in range(10000):
		generator.randf()
		ClassSpellEffects.on_melee(world, AttackEvent.new(enemy, null, &"hit", 20))
	var average := (enemy.max_health - enemy.health) / 10000.0
	var raw := 20.0 + 4.0 / 14.0 * world.hero.melee.interval
	assert_almost_eq(average, raw * 0.25 * 0.76, 0.02)
	assert_eq(world.combat_random.state, generator.state,
		"Damage selection and fractional rounding share the one weapon roll.")
	assert_true(enemy.alive)
	world.discard()


func test_judgement_inherently_adds_flat_holy_damage_and_bypasses_armor() -> void:
	var world := _world()
	_learn(world, [&"judgement_1", &"seal_of_command_1"])
	var enemy := _enemy(world)
	enemy.melee.armor = 100000
	assert_true(world.cast_skill(&"judgement_1", enemy))
	for turn in range(world.hero.find_skill(&"judgement_1").delay_turns):
		world.wait_turn()
	assert_eq(enemy.max_health - enemy.health, 65, "150% of 20 plus 35 Holy damage.")


func test_main_hand_and_active_points_share_one_turn_even_with_many_due_swings() -> void:
	var world := _world(&"Rogue")
	_learn(world, [&"relentless_assault_1"])
	world.hero.equipment.weapons = ItemData.instance(2139)
	world.hero.refresh_stats()
	world.hero.melee.hit = 100
	world.hero.melee.critical = 0
	world.hero.haste = 10.0
	world.hero.swing.remaining = 0.0
	world.hero.off_hand_swing.remaining = 0.0
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(world.hero.combo_points, 1, "The active and all due swings share one base point.")
	world.wait_turn()
	assert_eq(world.hero.combo_points, 2, "The next turn can gain another main-hand point.")
	world.hero.swing.remaining = 100.0
	world.hero.off_hand_swing.remaining = 0.0
	world.wait_turn()
	assert_eq(world.hero.combo_points, 2, "An off-hand-only turn grants no point.")


func test_battle_trance_accepts_holy_and_fire_active_crits() -> void:
	for id: StringName in [&"judgement_1", &"lava_burst_1"]:
		var world := _world()
		_learn(world, [&"battle_trance_1", &"seal_of_command_1", id])
		var enemy := _enemy(world)
		world.hero.melee.critical = 100
		assert_true(world.cast_skill(id, enemy))
		while world.pending_skill != null:
			world.hero.melee.critical = 100
			world.continue_cast()
		if id == &"judgement_1":
			for turn in range(world.hero.find_skill(id).delay_turns):
				world.wait_turn()
		assert_true(world.hero.buffs.has(&"battle_trance_1"))
		var rage := world.hero.rage
		assert_true(world.cast_skill(&"mortal_strike_1", enemy))
		assert_eq(world.hero.rage, rage, "The following active is free.")
		assert_false(world.hero.buffs.has(&"battle_trance_1"))


func test_bonus_event_cannot_trigger_primary_procs_even_when_dispatched_explicitly() -> void:
	var world := _world()
	_learn(world, [&"relentless_assault_1", &"battle_trance_1", &"sudden_death_1",
		&"shaman_flurry_1", &"vengeance_1", &"windfury_weapon_1", &"seal_of_command_1"])
	ClassToolkitRules.apply(world, &"windfury_weapon_1",
		{"weapon_id": world.hero.weapon_id(), "ready": 0})
	ClassToolkitRules.apply(world, &"seal_of_command_1", {})
	world.hero.find_skill(&"sudden_death_1").coefficient = 1.0
	var enemy := _enemy(world)
	var event := AttackEvent.new(enemy, world.hero.find_skill(&"mortal_strike_1"),
		&"critical", 20)
	event.origin = AttackEvent.Origin.BONUS
	var buffs := world.hero.buffs.duplicate(true)
	var random_state := world.combat_random.state
	var rage := world.hero.rage
	AttackProcs.on_attack(world, event)
	AttackProcs.weapon_procs(world, event)
	assert_eq(world.hero.combo_points, 0)
	assert_eq(world.hero.rage, rage)
	assert_eq(world.hero.buffs, buffs)
	assert_eq(enemy.health, 10000)
	assert_eq(world.combat_random.state, random_state)


func test_sudden_death_only_procs_from_landed_physical_actives_other_than_execute() -> void:
	var generator := RandomNumberGenerator.new()
	# Rolls either side of 20% cover eligibility without forcing the proc chance.
	for below_chance in [true, false]:
		var chosen_seed := -1
		var roll_min := 0.10 if below_chance else 0.30
		for seed_value in range(1000):
			generator.seed = seed_value
			var roll := generator.randf()
			if roll > roll_min and roll < roll_min + 0.02:
				chosen_seed = seed_value
				break
		assert_ne(chosen_seed, -1)
		# Skill, landed, physical, off-hand, eligible.
		for setup: Array in [
			[&"mortal_strike_1", true, true, false, true],
			[&"whirlwind_1", true, true, false, true],
			[&"eviscerate_1", true, true, false, true],
			[&"execute_1", true, true, false, false],
			[&"mortal_strike_1", false, true, false, false],
			[&"lava_burst_1", true, false, false, false],
			[&"", true, true, false, false],
			[&"", true, true, true, false],
		]:
			var world := _world()
			_learn(world, [&"sudden_death_1", &"execute_1", &"eviscerate_1", &"lava_burst_1"])
			world.combat_random.seed = chosen_seed
			var enemy := _enemy(world)
			var skill := world.hero.find_skill(setup[0])
			var event := AttackEvent.new(enemy, skill, &"hit" if setup[1] else &"miss", 20,
				AttackEvent.School.PHYSICAL if setup[2] else AttackEvent.School.NATURE)
			event.hand = AttackEvent.Hand.OFF if setup[3] else AttackEvent.Hand.MAIN
			AttackProcs.on_attack(world, event)
			assert_eq(world.hero.buffs.has(&"sudden_death_1"), below_chance and setup[4],
				"Sudden Death eligibility for %s, off-hand=%s." % [setup[0], setup[3]])


func test_consumable_procs_survive_time_while_timed_damage_buffs_expire() -> void:
	var world := _world()
	var procs: Array[StringName] = [&"shaman_flurry_1",
		&"battle_trance_1", &"sudden_death_1", &"juggernaut_1", &"maelstrom_weapon_1",
		&"art_of_war_1"]
	_learn(world, procs)
	_learn(world, [&"wrecking_crew_1", &"vengeance_1", &"bandits_guile_1"])
	for identifier in procs:
		ClassToolkitRules.apply(world, identifier, {"charges": 1})
	for identifier: StringName in [&"wrecking_crew_1", &"vengeance_1", &"bandits_guile_1"]:
		ClassToolkitRules.apply(world, identifier, {})
	for turn in range(50):
		world.wait_turn()
	for identifier in procs:
		assert_true(world.hero.buffs.has(identifier), String(identifier))
	assert_false(world.hero.buffs.has(&"wrecking_crew_1"))
	assert_false(world.hero.buffs.has(&"vengeance_1"))
	assert_false(world.hero.buffs.has(&"bandits_guile_1"))


func test_shaman_flurry_consumes_swing_charges_without_changing_cooldowns() -> void:
	var world := _world()
	_learn(world, [&"shaman_flurry_1", &"wrecking_crew_1"])
	var enemy := _enemy(world)
	world.hero.melee.critical = 100
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_true(world.hero.buffs.has(&"shaman_flurry_1"))
	assert_almost_eq(world.hero.attack_haste(), 1.3, 0.001)
	assert_eq(world.hero.cooldowns.mortal_strike, 5)
	assert_true(world.hero.buffs.has(&"wrecking_crew_1"))
	for index in range(3):
		ClassToolkitRules.consume_flurry(world.hero)
	assert_almost_eq(world.hero.attack_haste(), 1.0, 0.001)


func test_timed_damage_buffs_last_ten_turns_and_refresh_without_stacking() -> void:
	for identifier: StringName in [&"enrage_1", &"wrecking_crew_1", &"vengeance_1", &"bandits_guile_1"]:
		var world := _world()
		_learn(world, [identifier])
		ClassToolkitRules.apply(world, identifier, {})
		for index in range(5):
			world.wait_turn()
		ClassToolkitRules.apply(world, identifier, {})
		for index in range(10):
			world.wait_turn()
		assert_true(world.hero.buffs.has(identifier), "Refresh grants the full window.")
		world.wait_turn()
		assert_false(world.hero.buffs.has(identifier), "Each timed damage buff expires together.")


func test_battle_trance_free_attack_consumes_once_and_rejected_use_keeps_proc() -> void:
	var world := _world()
	_learn(world, [&"battle_trance_1", &"lava_burst_1"])
	var enemy := _enemy(world)
	world.hero.melee.critical = 100
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	world.hero.rage = 0
	assert_false(world.cast_skill(&"lava_burst_1", _enemy(world, Vector2i(16, 8))))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	while world.pending_skill != null:
		world.hero.melee.critical = -100
		world.continue_cast()
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))


func test_sudden_death_allows_one_free_execute_at_full_health_and_does_not_spend_extra_rage() -> void:
	var world := _world()
	_learn(world, [&"execute_1", &"sudden_death_1"])
	var enemy := _enemy(world)
	assert_false(world.cast_skill(&"execute_1", enemy))
	ClassToolkitRules.apply(world, &"sudden_death_1", {"charges": 1})
	world.hero.melee.critical = 0
	world.hero.melee.damage_min = 20
	world.hero.melee.damage_max = 20
	world.hero.melee.attack_power = 0
	world.hero.find_skill(&"sudden_death_1").coefficient = 1
	assert_true(world.cast_skill(&"execute_1", enemy))
	assert_eq(enemy.health, 9945)
	assert_eq(world.hero.rage, 100)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))
	assert_false(world.cast_skill(&"execute_1", enemy))


func test_paid_execute_cannot_trigger_sudden_death() -> void:
	var world := _world()
	_learn(world, [&"execute_1", &"sudden_death_1"])
	world.hero.find_skill(&"sudden_death_1").coefficient = 1
	var enemy := _enemy(world)
	enemy.health = 2000
	assert_true(world.cast_skill(&"execute_1", enemy))
	assert_lt(enemy.health, 2000)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))


func test_victory_rush_heals_enemy_kills_but_not_friendly_deaths() -> void:
	var world := _world()
	_learn(world, [&"victory_rush_1"])
	world.hero.health = 1
	var enemy := _enemy(world)
	SpellEffects.damage(world, enemy, 10000, "Test hit")
	assert_eq(world.hero.health, 1 + floori(world.hero.max_health * 0.1))
	world.turn_count += world.hero.find_skill(&"victory_rush_1").cooldown_seconds + 1
	var friend := _enemy(world, Vector2i(8, 9))
	friend.relationship = GridActor.Relationship.FRIENDLY
	var health := world.hero.health
	SpellEffects.damage(world, friend, 10000, "Test hit")
	assert_eq(world.hero.health, health)
	var summon := _enemy(world, Vector2i(7, 8))
	summon.summon_kind = "wolf"
	SpellEffects.damage(world, summon, 10000, "Test hit")
	assert_eq(world.hero.health, health, "A summon dying cannot trigger a ready heal.")


func test_victory_rush_overhealing_starts_its_cooldown() -> void:
	var world := _world()
	_learn(world, [&"victory_rush_1"])
	world.hero.health = world.hero.max_health
	SpellEffects.damage(world, _enemy(world), 10000, "Full-health kill")
	world.hero.health = 1
	SpellEffects.damage(world, _enemy(world), 10000, "Second kill")
	assert_eq(world.hero.health, 1, "A fully overhealed proc still consumes its cooldown.")


func test_final_stalker_victory_stops_victory_rush_and_its_cooldown() -> void:
	var world := _world()
	_learn(world, [&"victory_rush_1"])
	world.hero.health = 1
	var enemy := _enemy(world)
	enemy.stalker = true
	SpellEffects.damage(world, enemy, 10000, "Final kill")
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_eq(world.hero.health, 1)
	assert_false(world.hero.buffs.has(&"victory_rush_1"))


func test_victory_rush_shares_a_cooldown_across_kills_and_damage_phases() -> void:
	var world := _world()
	_learn(world, [&"victory_rush_1", &"restless_blades_1", &"eviscerate_1"])
	world.hero.health = 1
	var heal := floori(world.hero.max_health * 0.1)
	SpellEffects.damage(world, _enemy(world), 10000, "Active kill")
	var ready := int(world.hero.buffs[&"victory_rush_1"].ready)
	SpellEffects.damage(world, _enemy(world), 10000, "Another active kill")
	world.turn_count = 1
	SpellEffects.damage(world, _enemy(world), 10000, "Same-turn periodic kill", 1)
	assert_eq(world.hero.health, 1 + heal, "Mass kills and later phases share one heal.")
	world.hero.cooldowns["mortal_strike"] = 20
	ClassToolkitRules.finish(world, 5, world.hero.find_skill(&"eviscerate_1"))
	assert_lt(int(world.hero.cooldowns.mortal_strike), 20)
	assert_eq(int(world.hero.buffs[&"victory_rush_1"].ready), ready,
		"Finisher cooldown reduction cannot accelerate the healing proc.")
	world.turn_count = ready - 2
	SpellEffects.damage(world, _enemy(world), 10000, "Early active kill")
	assert_eq(world.hero.health, 1 + heal)
	world.turn_count = ready - 1
	SpellEffects.damage(world, _enemy(world), 10000, "Boundary active kill")
	assert_eq(world.hero.health, 1 + heal * 2,
		"An action resolving on the ready boundary can heal before buff expiry runs.")
	world.turn_count = ready
	SpellEffects.damage(world, _enemy(world), 10000, "Boundary periodic kill", ready)
	assert_eq(world.hero.health, 1 + heal * 2)


func test_sweeping_strikes_copies_one_hit_without_extra_points() -> void:
	var world := _world()
	_learn(world, [&"sweeping_strikes_1", &"relentless_assault_1"])
	var enemy := _enemy(world)
	var second := _enemy(world, Vector2i(8, 9))
	var third := _enemy(world, Vector2i(7, 8))
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(enemy.health, 9960)
	assert_eq(second.health, 9980)
	assert_eq(third.health, 10000)
	assert_eq(world.hero.combo_points, 1)


func test_whirlwind_does_not_copy_hits_through_sweeping_strikes() -> void:
	var world := _world()
	_learn(world, [&"sweeping_strikes_1", &"relentless_assault_1"])
	var targets := [_enemy(world), _enemy(world, Vector2i(8, 9)),
		_enemy(world, Vector2i(7, 8))]
	assert_true(world.cast_skill(&"whirlwind_1"))
	for enemy: GridActor in targets:
		assert_eq(enemy.health, 9986, "Each enemy takes only its own Whirlwind hit.")
	assert_eq(world.hero.combo_points, 1)
	for message in world.messages:
		assert_false(message.begins_with("Sweeping Strikes"))


func test_wrecking_crew_whirlwind_bonus_lasts_through_its_expiry_action_only() -> void:
	var world := _world()
	_learn(world, [&"wrecking_crew_1"])
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"whirlwind_1"))
	var baseline := enemy.max_health - enemy.health
	AttackProcs.on_attack(world, AttackEvent.new(enemy, null, &"critical", 0))
	_learn(world, [])
	world.hero.buffs[&"wrecking_crew_1"].until = world.turn_count + 1
	var before := enemy.health
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_gt(before - enemy.health, ceili(baseline * 1.25),
		"The developed Whirlwind bonus adds to Wrecking Crew's ordinary physical buff.")
	assert_false(world.hero.buffs.has(&"wrecking_crew_1"))
	_learn(world, [])
	before = enemy.health
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(before - enemy.health, baseline, "Both bonuses end with the buff.")


func test_juggernaut_changes_charge_cooldown_and_guarantees_only_one_mortal_strike() -> void:
	var world := _world()
	_learn(world, [&"charge_1", &"juggernaut_1"])
	var enemy := _enemy(world, Vector2i(11, 8))
	assert_true(world.cast_skill(&"charge_1", enemy))
	while world.is_charging():
		world.continue_cast()
	assert_eq(world.hero.cooldowns.charge - world.turn_count, 8)
	assert_true(world.hero.buffs.has(&"juggernaut_1"))
	world.hero.melee.critical = -100
	assert_true(ClassToolkitRules.weapon_outcome(world, enemy, world.hero.find_skill(&"mortal_strike_1"), world.hero.melee).critical())
	assert_false(world.hero.buffs.has(&"juggernaut_1"))


func test_inherent_shield_and_static_shock_consume_charges_without_extra_rage_points_or_xp() -> void:
	var world := _world(&"Shaman")
	_learn(world, [&"lightning_shield_1", &"static_shock_1", &"relentless_assault_1"])
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"lightning_shield_1"))
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 6)
	world.hero.find_skill(&"static_shock_1").coefficient = 1.0
	var rage := world.hero.rage
	AttackProcs.on_attack(world, AttackEvent.new(enemy, null, &"hit", 20))
	assert_eq(enemy.health, 9985, "Lightning Shield deals 15 without an upgrade passive.")
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 5)
	ClassToolkitRules.discharge(world, enemy, true)
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 4)
	ClassToolkitRules.discharge(world, enemy, true)
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 4, "Reactive cooldown still applies.")
	assert_eq(world.hero.rage, rage)
	assert_eq(world.hero.combo_points, 1, "Only the primary main-hand hit builds a point.")


func test_lava_burst_flat_damage_and_crits_ignore_weapon_and_strength() -> void:
	for critical in [false, true]:
		for weapon_damage in [1.0, 16.0, 1000.0]:
			var world := _world(&"Shaman")
			_learn(world, [&"lava_burst_1"])
			var enemy := _enemy(world, Vector2i(10, 8))
			world.hero.melee.damage_min = weapon_damage
			world.hero.melee.damage_max = weapon_damage + 0.5
			world.hero.melee.attack_power = 1000
			world.hero.melee.critical = 100.0 if critical else 0.0
			assert_true(world.cast_skill(&"lava_burst_1", enemy))
			while world.pending_skill != null:
				world.hero.melee.critical = 100.0 if critical else -100.0
				world.continue_cast()
			assert_eq(enemy.max_health - enemy.health, 96 if critical else 48)


func test_lava_burst_bypasses_armor_builds_points_and_has_no_control_effect() -> void:
	var world := _world(&"Shaman")
	_learn(world, [&"lava_burst_1", &"relentless_assault_1"])
	var enemy := _enemy(world, Vector2i(10, 8))
	enemy.melee.armor = 10000
	enemy.stunned_until = 0
	enemy.swing.remaining = 100
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	while world.pending_skill != null:
		world.hero.melee.critical = -100
		world.continue_cast()
	assert_eq(enemy.health, 10000 - 48)
	assert_eq(enemy.stunned_until, 0)
	assert_false(enemy.debuffs.has("interrupt"))
	assert_eq(world.hero.cooldowns.lava_burst - world.turn_count, 6)
	assert_eq(world.hero.combo_points, 1)


func test_removed_shaman_abilities_are_unavailable() -> void:
	assert_null(SkillDefinition.catalog(&"strength_of_earth_totem_1"))
	assert_null(SkillDefinition.catalog(&"elemental_warding_1"))


func test_windfury_bonus_hits_cannot_recurse_or_generate_rage_points_and_have_internal_cooldown() -> void:
	var world := _world()
	_learn(world, [&"windfury_weapon_1", &"relentless_assault_1", &"sudden_death_1"])
	world.hero.find_skill(&"sudden_death_1").coefficient = 1
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"windfury_weapon_1"))
	world.hero.melee.damage_min = 20
	world.hero.melee.damage_max = 20
	world.hero.melee.attack_power = 0
	var rage := world.hero.rage
	for index in range(100):
		AttackProcs.weapon_procs(world, AttackEvent.new(enemy, null, &"hit", 0))
		if enemy.health < 10000:
			break
	assert_eq(enemy.health, 9944, "Exactly two 140% bonus hits.")
	AttackProcs.weapon_procs(world, AttackEvent.new(enemy, null, &"hit", 0))
	assert_eq(enemy.health, 9944, "No proc inside the internal cooldown.")
	assert_eq(world.hero.rage, rage)
	assert_eq(world.hero.combo_points, 0)
	assert_false(world.hero.buffs.has(&"sudden_death_1"), "Windfury cannot trigger Sudden Death.")


func test_wolf_pair_placement_is_atomic_replaces_expires_and_heals_actual_damage() -> void:
	var world := _world(&"Shaman")
	_learn(world, [&"feral_spirit_1"])
	var enemy := _enemy(world, Vector2i(10, 8))
	world.auto_attack_target = enemy
	world.hero.health = 1
	assert_true(world.cast_skill(&"feral_spirit_1"))
	var wolves := world.actors.filter(func(actor: GridActor) -> bool: return actor.alive and actor.summon_kind == "wolf")
	assert_eq(wolves.size(), 2)
	var wolf: GridActor = wolves[0]
	wolf.tile = Vector2i(9, 8)
	wolf.melee.hit = 100
	ClassToolkitRules.act_wolf(world, wolf)
	assert_gt(world.hero.health, 1)
	assert_lt(enemy.health, enemy.max_health)
	world.hero.cooldowns.clear()
	world.hero.rage = 100
	assert_true(world.cast_skill(&"feral_spirit_1"))
	assert_false(wolf.alive)
	assert_eq(world.actors.filter(func(actor: GridActor) -> bool: return actor.alive and actor.summon_kind == "wolf").size(), 2)
	for index in range(12):
		world.wait_turn()
	assert_eq(world.actors.filter(func(actor: GridActor) -> bool: return actor.alive and actor.summon_kind == "wolf").size(), 0)
	var blocked := _world()
	_learn(blocked, [&"feral_spirit_1"])
	for direction in GridWorld.DIRECTIONS:
		blocked.blocked_tiles[blocked.player_tile + direction] = true
	assert_false(blocked.cast_skill(&"feral_spirit_1"))
	assert_eq(blocked.hero.rage, 100)
	assert_eq(blocked.turn_count, 0)


func test_kings_updates_existing_shout_all_primary_stats_without_healing_or_stacking() -> void:
	var world := _world()
	_learn(world, [&"battle_shout_1"])
	world.hero.refresh_stats()
	var strength := world.hero.strength
	var agility := world.hero.agility
	var stamina := world.hero.stamina
	var health := world.hero.health
	assert_true(world.cast_skill(&"battle_shout_1"))
	assert_true(world.hero.learn_skill(SkillDefinition.catalog(&"blessing_of_kings_1")))
	assert_eq(world.hero.strength, strength + 2)
	assert_eq(world.hero.agility, agility + 2)
	assert_eq(world.hero.stamina, stamina + 2)
	assert_eq(world.hero.health, health, "Learning Kings does not heal.")
	assert_false(world.cast_skill(&"blessing_of_kings_1"))
	assert_false(world.assign_hotbar(0, &"blessing_of_kings_1"))
	for index in range(3):
		world.hero.refresh_stats()
	assert_eq(world.hero.strength, strength + 2)
	assert_eq(world.hero.health, health)
	world.hero.buffs[&"battle_shout_1"].until = world.turn_count + 1
	world.wait_turn()
	assert_eq(world.hero.strength, strength)
	assert_eq(world.hero.agility, agility)
	assert_eq(world.hero.stamina, stamina)


func test_shield_protects_both_schools_penalizes_damage_and_guardians_favor_extends_it() -> void:
	var world := _world()
	_learn(world, [&"divine_shield_1", &"guardians_favor_1"])
	assert_eq(ClassSpellEffects.absorb(world, null, 100, false), 100)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 100)
	assert_true(world.cast_skill(&"divine_shield_1"))
	assert_eq(world.hero.cooldowns.divine_shield, 21)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, false), 0)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 0)
	assert_almost_eq(ClassToolkitRules.damage_multiplier(world.hero), 0.7, 0.001)
	assert_eq(int(world.hero.buffs[&"divine_shield_1"].until), 5)
	for index in range(4):
		world.wait_turn()
	assert_false(world.hero.buffs.has(&"divine_shield_1"))


func test_art_of_war_counts_one_holy_event_per_action_and_guarantees_judgement_once() -> void:
	var world := _world()
	_learn(world, [&"art_of_war_1", &"seal_of_command_1", &"judgement_1"])
	var enemy := _enemy(world, Vector2i(10, 8))
	for index in range(3):
		world.holy_event_counted = false
		ClassToolkitRules.holy_event(world)
		ClassToolkitRules.holy_event(world)
		assert_eq(int(world.hero.buffs[&"art_of_war_1"].get("critical_ready", 0)), 1 if index == 2 else 0)
	world.hero.melee.critical = -100
	var result := ClassToolkitRules.magic_attack(world, enemy, world.hero.find_skill(&"judgement_1"))
	assert_true(result.critical())
	assert_eq(int(world.hero.buffs.get(&"art_of_war_1", {}).get("critical_ready", 0)), 0)
	assert_false(ClassToolkitRules.magic_attack(world, enemy, world.hero.find_skill(&"judgement_1")).critical())


func test_judgement_impact_rewards_preserve_passive_seal_and_haste_leaves_cooldown_fixed() -> void:
	var world := _world(&"Paladin")
	_learn(world, [&"seal_of_command_1", &"judgement_1", &"battle_trance_1",
		&"heart_of_the_crusader_1"])
	var enemy := _enemy(world, Vector2i(10, 8))
	world.hero.melee.critical = 100
	world.hero.haste = 2
	assert_true(world.cast_skill(&"judgement_1", enemy))
	assert_eq(world.hero.cooldowns.judgement - world.turn_count, 6)
	assert_false(world.hero.buffs.has(&"battle_trance_1"), "Rewards wait for the verdict.")
	for turn in range(world.hero.find_skill(&"judgement_1").delay_turns):
		world.wait_turn()
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(enemy.debuffs.has(&"heart_of_the_crusader_1"))
	world.hero.cooldowns.clear()
	world.hero.rage = 0
	assert_true(world.cast_skill(&"judgement_1", enemy))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(ClassToolkitRules.has(world.hero, &"seal_of_command_1"))


func test_vengeance_caps_three_stacks_without_extra_combo_points() -> void:
	var world := _world()
	_learn(world, [&"vengeance_1", &"relentless_assault_1"])
	var enemy := _enemy(world)
	for index in range(4):
		AttackProcs.on_attack(world, AttackEvent.new(enemy, null, &"critical", 20))
	assert_almost_eq(ClassToolkitRules.damage_multiplier(world.hero), 1.09, 0.001)
	assert_eq(enemy.health, 10000)
	assert_eq(world.hero.combo_points, 1, "Only the primary hits build one base point per turn.")


func test_pursuit_of_justice_accumulates_extra_grid_steps_and_stops_at_obstacles() -> void:
	var world := _world()
	_learn(world, [&"pursuit_of_justice_1"])
	for index in range(5):
		assert_true(world.move_player(Vector2i.RIGHT))
	assert_eq(world.player_tile, Vector2i(14, 8))
	world.blocked_tiles[Vector2i(16, 8)] = true
	world.movement_credit = 0.9
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_eq(world.player_tile, Vector2i(15, 8))


func test_evasion_can_dodge_attacks_from_behind_and_expires() -> void:
	var world := _world()
	_learn(world, [&"evasion_1"])
	var enemy := _enemy(world, Vector2i(8, 7))
	enemy.stunned_until = 0
	enemy.engaged = true
	enemy.melee.hit = 100
	enemy.melee.damage_min = 50
	enemy.melee.damage_max = 50
	world.hero.facing = Vector2i.DOWN
	assert_true(world.cast_skill(&"evasion_1"))
	world.hero.facing = Vector2i.DOWN
	world.hero.melee.dodge = 100
	enemy.swing.remaining = 0
	var health := world.hero.health
	NpcRules.act(world, enemy)
	assert_eq(world.hero.health, health)
	enemy.stunned_until = 999
	for index in range(5):
		world.wait_turn()
	assert_false(world.hero.buffs.has(&"evasion_1"))


func test_untrained_dual_wield_has_independent_offhand_timer_without_ordinary_rage() -> void:
	var world := _world()
	world.hero.inventory[0] = ItemData.instance(2139)
	assert_true(world.equip_item(0))
	assert_true(world.hero.has_off_hand_weapon())
	world.hero.swing.remaining = 2.0
	world.hero.swing._active = true
	var enemy := _enemy(world)
	world.auto_attack_target = enemy
	world.hero.rage = 0
	world.hero.melee.hit = 100
	var before := enemy.health
	world.wait_turn()
	assert_lt(enemy.health, before)
	assert_eq(world.hero.rage, 0, "Main hand is delayed; off hand supplies no ordinary rage.")
	assert_gt(world.hero.off_hand_swing.remaining, 0.0)


func test_combat_potency_and_main_gauche_distinguish_ordinary_from_bonus_offhand_hits() -> void:
	var world := _world()
	_learn(world, [&"ambidexterity_1", &"combat_potency_1", &"main_gauche_1", &"relentless_assault_1"])
	world.hero.equipment.weapons = ItemData.instance(2139)
	world.hero.refresh_stats()
	world.hero.find_skill(&"combat_potency_1").coefficient = 1
	world.hero.find_skill(&"main_gauche_1").coefficient = 1
	var enemy := _enemy(world)
	world.hero.rage = 0
	AttackProcs.on_attack(world, AttackEvent.new(enemy, null, &"hit", 20))
	assert_lt(enemy.health, enemy.max_health)
	assert_eq(world.hero.rage, 0, "Main Gauche bonus cannot trigger Combat Potency.")
	var event := AttackEvent.new(enemy, null, &"hit", 20)
	event.hand = AttackEvent.Hand.OFF
	AttackProcs.on_attack(world, event)
	assert_eq(world.hero.rage, 5)
	assert_eq(world.hero.combo_points, 1, "Off-hand and Main Gauche add no points.")


func test_eviscerate_spends_on_miss_grants_haste_then_refunds_once_and_reduces_cooldowns() -> void:
	var world := _world(&"Rogue")
	_learn(world, [&"slice_and_dice_1", &"eviscerate_1", &"relentless_assault_1", &"restless_blades_1"])
	var enemy := _enemy(world)
	assert_false(world.cast_skill(&"eviscerate_1", enemy))
	assert_false(world.cast_skill(&"slice_and_dice_1"))
	world.last_attacked_enemy = enemy
	world.hero.combo_points = 5
	world.hero.rage = 20
	world.hero.melee.hit = -1000
	world.hero.cooldowns.charge = 10
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	assert_eq(enemy.health, 10000)
	assert_eq(world.hero.combo_points, 0, "Finishers no longer refund combo points.")
	assert_eq(world.hero.rage, 20)
	assert_eq(world.hero.cooldowns.charge, 7)
	assert_eq(int(world.hero.buffs[&"slice_and_dice_1"].haste_percent), 30)


func test_seal_fate_and_bandits_guile_reward_retained_physical_crits_without_finisher_building() -> void:
	var world := _world()
	_learn(world, [&"seal_fate_1", &"bandits_guile_1", &"relentless_assault_1", &"eviscerate_1", &"slice_and_dice_1"])
	var enemy := _enemy(world)
	enemy.facing = Vector2i.RIGHT
	world.hero.melee.critical = 100
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(enemy.health, 9920, "40 damage doubled by a crit; no Opportunity bonus.")
	assert_eq(world.hero.combo_points, 2)
	for index in range(3):
		AttackProcs.on_attack(world, AttackEvent.new(enemy,
			world.hero.find_skill(&"mortal_strike_1"), &"hit", 20))
	assert_almost_eq(ClassToolkitRules.damage_multiplier(world.hero), 1.05, 0.001)
	world.hero.rage = 100
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	assert_eq(world.hero.combo_points, 0, "Finishers cannot rebuild points through Seal Fate.")
	assert_eq(int(world.hero.buffs[&"bandits_guile_1"].charges), 0)


func test_retained_holy_and_fire_crits_build_seal_fate_and_bandits_guile() -> void:
	for identifier: StringName in [&"lava_burst_1", &"judgement_1"]:
		var world := _world(&"Warrior")
		_learn(world, [identifier, &"seal_of_command_1", &"seal_fate_1", &"bandits_guile_1", &"relentless_assault_1"])
		var enemy := _enemy(world)
		world.hero.melee.critical = 100
		for index in range(4):
			world.hero.rage = 100
			world.hero.melee.critical = 100
			assert_true(world.cast_skill(identifier, enemy))
			while world.pending_skill != null:
				world.hero.melee.critical = 100
				world.continue_cast()
			if identifier == &"judgement_1":
				for turn in range(world.hero.find_skill(identifier).delay_turns):
					world.wait_turn()
			if index == 0:
				assert_eq(world.hero.combo_points, 2, "Base point plus retained Seal Fate.")
			if index < 3:
				while int(world.hero.cooldowns.get(String(world.cooldown_family(
					world.hero.find_skill(identifier))), 0)) > world.turn_count:
					world.wait_turn()
		assert_almost_eq(ClassToolkitRules.damage_multiplier(world.hero), 1.05, 0.001)
		assert_eq(int(world.hero.buffs[&"bandits_guile_1"].charges), 0)


func test_eviscerate_scales_damage_and_passive_haste_duration_with_the_same_spent_points() -> void:
	for points in [1, 5]:
		var world := _world(&"Rogue")
		_learn(world, [&"slice_and_dice_1", &"eviscerate_1", &"relentless_assault_1"])
		var enemy := _enemy(world)
		world.last_attacked_enemy = enemy
		world.hero.combo_points = points
		assert_true(world.cast_skill(&"eviscerate_1", enemy))
		assert_eq(enemy.health, 10000 - 10 - 4 * points)
		assert_eq(world.hero.combo_points, 0)
		assert_eq(int(world.hero.buffs[&"slice_and_dice_1"].until) - world.turn_count,
			5 + 3 * points)
		assert_eq(int(world.hero.buffs[&"slice_and_dice_1"].haste_percent), 30)
		if points == 5:
			assert_eq(world.hero.rage, 100, "Five points refund the 15 rage spent.")
		else:
			assert_true(world.hero.rage in [85, 100], "Pay 15 rage, with at most one 15-rage refund.")
		assert_eq(world.turn_count, 1)


func test_eviscerate_can_be_reused_while_haste_is_active_and_refreshes_without_stacking() -> void:
	var world := _world(&"Rogue")
	_learn(world, [&"eviscerate_1", &"slice_and_dice_1"])
	var enemy := _enemy(world)
	world.hero.combo_points = 1
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	var health_after_first := enemy.health
	world.hero.melee.hit = 100
	world.hero.combo_points = 5
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	assert_lt(enemy.health, health_after_first)
	assert_eq(world.hero.combo_points, 0)
	assert_almost_eq(world.hero.attack_haste(), 1.3, 0.001)
	assert_eq(int(world.hero.buffs[&"slice_and_dice_1"].until) - world.turn_count, 20)


func test_eviscerate_rejects_invalid_targets_without_spending_or_granting_haste() -> void:
	for invalid_target in ["none", "distant", "dead", "friendly", "removed", "blocked"]:
		var world := _world(&"Rogue")
		_learn(world, [&"slice_and_dice_1", &"eviscerate_1"])
		var other := _enemy(world, Vector2i(8, 9))
		var target := _enemy(world, Vector2i(9, 9))
		world.last_attacked_enemy = target
		match invalid_target:
			"none": world.last_attacked_enemy = null
			"distant": target.tile = Vector2i(12, 8)
			"dead": target.alive = false
			"friendly": target.relationship = GridActor.Relationship.FRIENDLY
			"removed": world.actors.erase(target)
			"blocked":
				world.sight_blockers[target.tile] = true
		world.hero.combo_points = 3
		assert_false(world.cast_skill(&"eviscerate_1", null if invalid_target == "none" else target), invalid_target)
		assert_eq(target.health, 10000, invalid_target)
		assert_eq(other.health, 10000, "Never silently chooses another enemy.")
		assert_eq(world.hero.combo_points, 3)
		assert_eq(world.hero.rage, 100)
		assert_eq(world.turn_count, 0)
		assert_false(world.hero.buffs.has(&"slice_and_dice_1"))


func test_eviscerate_without_slice_and_dice_only_attacks() -> void:
	var world := _world(&"Rogue")
	_learn(world, [&"eviscerate_1"])
	var enemy := _enemy(world)
	world.last_attacked_enemy = enemy
	world.hero.combo_points = 5
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	assert_eq(enemy.health, 9970)
	assert_eq(world.hero.combo_points, 0)
	assert_false(world.hero.buffs.has(&"slice_and_dice_1"))


func test_eviscerate_kill_prevents_a_due_swing_on_the_dead_target() -> void:
	var world := _world(&"Rogue")
	_learn(world, [&"slice_and_dice_1", &"eviscerate_1", &"relentless_assault_1"])
	var enemy := _enemy(world)
	world.last_attacked_enemy = enemy
	world.auto_attack_target = enemy
	world.hero.swing.remaining = 0.0
	world.hero.combo_points = 5
	world.hero.rage = 50
	enemy.health = 1
	assert_true(world.cast_skill(&"eviscerate_1", enemy))
	assert_false(enemy.alive)
	assert_eq(world.hero.combo_points, 0, "No ordinary swing builds points after the kill.")
	assert_eq(world.hero.rage, 48, "The five-point refund offsets the cost; only out-of-combat decay remains.")
	assert_true(world.hero.buffs.has(&"slice_and_dice_1"))
	assert_eq(world.turn_count, 1)


func test_windfury_lasts_sixty_turns_and_expires() -> void:
	var world := _world(&"Shaman")
	_learn(world, [&"windfury_weapon_1"])
	assert_true(world.cast_skill(&"windfury_weapon_1"))
	for index in range(59):
		world.wait_turn()
	assert_true(world.hero.buffs.has(&"windfury_weapon_1"))
	world.wait_turn()
	assert_false(world.hero.buffs.has(&"windfury_weapon_1"))


func test_whirlwind_hits_adjacent_enemies_once_and_counts_only_one_class_use() -> void:
	var world := _world()
	_learn(world, [&"relentless_assault_1"])
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(9, 9))
	second.relationship = GridActor.Relationship.NEUTRAL
	var friendly := _enemy(world, Vector2i(7, 7))
	friendly.relationship = GridActor.Relationship.FRIENDLY
	var dead := _enemy(world, Vector2i(8, 9))
	dead.alive = false
	var blocked := _enemy(world, Vector2i(8, 7))
	world.sight_blockers[blocked.tile] = true
	var distant := _enemy(world, Vector2i(10, 8))
	world.last_attacked_enemy = first
	world.auto_attack_target = first
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(first.health, 9986)
	assert_eq(second.health, 9986)
	assert_eq(distant.health, 10000)
	assert_eq(friendly.health, 10000)
	assert_eq(dead.health, 10000)
	assert_eq(blocked.health, 10000)
	assert_eq(second.relationship, GridActor.Relationship.HOSTILE)
	assert_true(second.engaged)
	assert_eq(world.hero.combo_points, 1, "All cleave targets share the base point limit.")
	assert_same(world.last_attacked_enemy, first)
	assert_same(world.auto_attack_target, first)


func test_whirlwind_requires_an_adjacent_enemy_and_rejects_without_spending() -> void:
	for distance in [1, 2, 3]:
		var world := _world()
		_learn(world, [])
		var enemy := _enemy(world, world.player_tile + Vector2i(distance, distance))
		assert_eq(world.cast_skill(&"whirlwind_1"), distance == 1)
		assert_eq(world.turn_count, 1 if distance == 1 else 0)
		assert_eq(enemy.health, 9986 if distance == 1 else 10000)
		assert_eq(world.hero.rage, 85 if distance == 1 else 100)


func test_war_horn_hits_the_screen_for_one_and_engages_without_attack_procs() -> void:
	var world := _world()
	_learn(world, [&"relentless_assault_1", &"sudden_death_1",
		&"battle_trance_1", &"seal_fate_1", &"sweeping_strikes_1"])
	world.hero.find_skill(&"sudden_death_1").coefficient = 1.0
	world.hero.melee.hit = -1000
	world.hero.melee.critical = 100
	world.hero.combo_points = 3
	world.hero.rage = 42
	var selected := _enemy(world)
	world.last_attacked_enemy = selected
	world.auto_attack_target = selected
	world.bounds = Rect2i(0, 0, 50, 30)
	var neutral := _enemy(world, Vector2i(26, 18))
	neutral.relationship = GridActor.Relationship.NEUTRAL
	neutral.returning_home = true
	var armored := _enemy(world, Vector2i(4, 8))
	armored.melee.armor = 100000
	armored.melee.level = 50
	armored.melee.dodge = 100
	var friendly := _enemy(world, Vector2i(10, 8))
	friendly.relationship = GridActor.Relationship.FRIENDLY
	var dead := _enemy(world, Vector2i(10, 9))
	dead.alive = false
	var chest := _enemy(world, Vector2i(7, 8))
	chest.relationship = GridActor.Relationship.NEUTRAL
	chest.chest = true
	var distant := _enemy(world, Vector2i(29, 8))
	var blocked := _enemy(world, Vector2i(8, 4))
	world.sight_blockers[Vector2i(8, 6)] = true
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_HORN_ID)))
	assert_true(world.consume_item(0))
	assert_eq(neutral.health, 10000, "The horn resolves only on the second turn.")
	var initial_threat: Array[int] = []
	for enemy in [selected, neutral, armored]:
		initial_threat.append(int(enemy.threat.get("-1", 0)))
	assert_true(world.continue_cast())
	for enemy in [selected, neutral, armored]:
		assert_eq(enemy.health, 9999)
		assert_true(enemy.engaged)
		assert_eq(enemy.relationship, GridActor.Relationship.HOSTILE)
		assert_eq(int(enemy.threat.get("-1", 0)), initial_threat.pop_front() + 1)
	for untouched in [friendly, dead, chest, distant, blocked]:
		assert_eq(untouched.health, 10000)
	assert_false(neutral.returning_home)
	assert_eq(chest.relationship, GridActor.Relationship.NEUTRAL)
	assert_same(world.last_attacked_enemy, selected)
	assert_same(world.auto_attack_target, selected)
	assert_eq(world.hero.combo_points, 3)
	assert_eq(world.hero.rage, 42)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.turn_count, 2)


func test_offhand_kill_before_mainhand_swing_stops_remaining_hits_and_rage() -> void:
	var world := _world()
	_learn(world, [&"ambidexterity_1", &"relentless_assault_1"])
	world.hero.equipment.weapons = ItemData.instance(2139)
	world.hero.refresh_stats()
	world.hero.swing.remaining = 0.9
	world.hero.swing._active = true
	world.hero.off_hand_swing.remaining = 0.1
	world.hero.off_hand_swing._active = true
	var enemy := _enemy(world)
	enemy.health = 1
	assert_true(world.request_melee(enemy))
	assert_false(enemy.alive)
	assert_eq(world.hero.rage, 98, "No main-hand rage; ordinary out-of-combat decay applies.")
	assert_eq(world.hero.combo_points, 0)
	assert_null(world.pending_melee)
	assert_false("\n".join(world.messages).contains("You ->"))


func test_poison_coats_both_weapons_and_bonus_damage_never_builds_points_or_rage() -> void:
	var world := _world()
	_learn(world, [&"instant_poison_1", &"ambidexterity_1", &"relentless_assault_1", &"sudden_death_1"])
	world.hero.find_skill(&"sudden_death_1").coefficient = 1
	world.hero.equipment.weapons = ItemData.instance(2139)
	world.hero.refresh_stats()
	world.hero.find_skill(&"instant_poison_1").coefficient = 1
	assert_true(world.cast_skill(&"instant_poison_1"))
	var enemy := _enemy(world)
	var rage := world.hero.rage
	AttackProcs.weapon_procs(world, AttackEvent.new(enemy, null, &"hit", 0))
	_off_hand_procs(world, enemy)
	assert_eq(enemy.health, 9984)
	assert_eq(world.hero.rage, rage)
	assert_eq(world.hero.combo_points, 0)
	assert_false(world.hero.buffs.has(&"sudden_death_1"), "Poison cannot trigger Sudden Death.")
	world.hero.equipment.weapons = ItemData.instance(70023)
	world.hero.refresh_stats()
	_off_hand_procs(world, enemy)
	assert_eq(enemy.health, 9984, "Changing the pair loses both coatings.")


func test_divine_shield_expires_before_enemy_hits_on_the_expiry_boundary() -> void:
	var world := _world()
	_learn(world, [&"divine_shield_1"])
	var enemy := _enemy(world)
	enemy.stunned_until = 0
	enemy.engaged = true
	enemy.melee.hit = 100
	enemy.melee.critical = 0
	enemy.melee.interval = 1
	enemy.melee.damage_min = 10
	enemy.melee.damage_max = 10
	assert_true(world.cast_skill(&"divine_shield_1"))
	var health := world.hero.health
	for index in range(3):
		world.wait_turn()
	assert_eq(world.hero.health, health)
	world.wait_turn()
	assert_lt(world.hero.health, health, "Four protected enemy turns include the cast turn.")


func test_whirlwind_continues_after_nonfinal_boss_death_to_later_actors() -> void:
	var world := _world()
	_learn(world, [&"sweeping_strikes_1"])
	var boss := _enemy(world)
	boss.stalker = true
	boss.health = 1
	var later := _enemy(world, Vector2i(7, 8))
	later.stalker = true
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)
	assert_lt(later.health, later.max_health)
	assert_eq(world.turn_count, 1)


func test_complete_mixed_toolkit_save_restores_proc_state_wolves_and_offhand_timing_then_death_clears_them() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	var world := game.world
	for category in ClassSkillData.PLAYABLE_CLASSES:
		for skill in SkillDefinition.trainer_skills(category):
			if world.hero.find_skill(skill.id) == null:
				assert_true(world.hero.learn_skill(skill))
	world.hero.rage = 100
	assert_true(world.cast_skill(&"feral_spirit_1"))
	world.hero.equipment.weapons = ItemData.instance(2139)
	world.hero.refresh_stats()
	world.hero.off_hand_swing.remaining = 1.25
	world.hero.off_hand_swing._active = true
	ClassToolkitRules.apply(world, &"battle_trance_1", {"charges": 1})
	ClassToolkitRules.apply(world, &"art_of_war_1", {"charges": 2, "critical_ready": 0})
	world.hero.combo_points = 4
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hero.learned_skills.size(), 50)
	assert_almost_eq(restored.hero.off_hand_swing.remaining, 1.25, 0.001)
	assert_eq(int(restored.hero.buffs[&"art_of_war_1"].charges), 2)
	assert_eq(restored.actors.filter(func(actor: GridActor) -> bool: return actor.alive and actor.summon_kind == "wolf").size(), 2)
	assert_eq(SaveCodec.capture(game), snapshot)
	var unlearned_proc := snapshot.duplicate(true)
	unlearned_proc.learned.erase("battle_trance_1")
	assert_null(SaveCodec.restore(unlearned_proc, false))
	var unlearned_wolves := snapshot.duplicate(true)
	unlearned_wolves.learned.erase("feral_spirit_1")
	assert_null(SaveCodec.restore(unlearned_wolves, false))
	var invalid_timer := snapshot.duplicate(true)
	invalid_timer.off_hand_swing = [-1, true]
	assert_null(SaveCodec.restore(invalid_timer, false))
	world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.learned_skills.size(), 50)
	assert_true(game.world.hero.buffs.is_empty())
	assert_eq(game.world.hero.combo_points, 0)
	assert_eq(game.world.hero.rage, 0)
	assert_almost_eq(game.world.hero.off_hand_swing.remaining, 0.0, 0.001)
	assert_null(SummonRules.active(game.world, "wolf"))


func test_passive_is_keyboard_focusable_and_inspectable_without_casting_or_assigning() -> void:
	var world := _world()
	_learn(world, [&"sudden_death_1"])
	var panel := HeroPanel.new()
	add_child_autofree(panel)
	panel.open(world.hero, true)
	watch_signals(panel)
	var passive: SkillButton
	for button in panel._skill_buttons:
		if button.get_meta("skill_id") == &"sudden_death_1":
			passive = button
	assert_not_null(passive)
	if passive == null:
		return
	passive.grab_focus()
	assert_same(panel.get_viewport().gui_get_focus_owner(), passive)
	assert_string_contains(panel._details.text, "allow one free Execute")
	assert_true(panel._assign.disabled)
	passive.pressed.emit()
	assert_signal_not_emitted(panel, "cast_requested")
	panel.begin_assignment()
	assert_false(panel.choosing_slot)
