extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	for id in [&"lava_burst_1", &"maelstrom_weapon_1"]:
		world.hero.learn_skill(SkillDefinition.catalog(id))
	world.hero.rage = 100
	world.hero.melee.hit = 100
	world.hero.melee.critical = -100
	world.hero.swing.remaining = 100
	world.hero.swing._active = true
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(9, 8)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.stunned_until = 999
	enemy.awards_experience = false
	enemy.melee.dodge = 0
	world.actors.append(enemy)
	return enemy


func _stacks(world: GridWorld, amount: int) -> void:
	if amount == 0:
		world.hero.buffs.erase(&"maelstrom_weapon_1")
	else:
		world.hero.buffs[&"maelstrom_weapon_1"] = {"armor": 0, "until": 0, "charges": amount}


func test_maelstrom_caps_active_and_many_due_main_offhand_swings_as_one_action() -> void:
	var world := _world()
	world.hero.equipment.weapons = ItemData.instance(2224)
	world.hero.refresh_stats()
	world.hero.melee.hit = 100
	world.hero.haste = 10
	world.hero.swing.remaining = 0
	world.hero.off_hand_swing.remaining = 0
	var first := _enemy(world)
	_enemy(world, Vector2i(8, 9))
	_enemy(world, Vector2i(7, 8))
	world.auto_attack_target = first
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 1)
	world.hero.swing.remaining = 0
	world.wait_turn()
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 2)


func test_only_landed_primary_physical_hits_build_stacks_including_offhand() -> void:
	var world := _world()
	var enemy := _enemy(world)
	for outcome: StringName in [&"miss", &"dodge"]:
		AttackProcs.on_attack(world, AttackEvent.new(enemy, null, outcome, 0))
	var bonus := AttackEvent.new(enemy, null, &"critical", 20)
	bonus.origin = AttackEvent.Origin.BONUS
	AttackProcs.on_attack(world, bonus)
	var fire := AttackEvent.new(enemy, world.hero.find_skill(&"lava_burst_1"),
		&"hit", 48, AttackEvent.School.FIRE)
	AttackProcs.on_attack(world, fire)
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 0)
	var offhand := AttackEvent.new(enemy, null, &"hit", 1)
	offhand.hand = AttackEvent.Hand.OFF
	AttackProcs.on_attack(world, offhand)
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 1)
	for index in range(10):
		world.wait_turn()
		AttackProcs.on_attack(world, offhand)
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 5)
	assert_eq(int(world.hero.buffs[&"maelstrom_weapon_1"].until), 0)


func test_lava_cast_times_have_unique_five_stack_instant_and_ignore_casting_credit() -> void:
	for stacks in range(6):
		var world := _world()
		_stacks(world, stacks)
		world.hero.casting_credit = 0.9
		var enemy := _enemy(world)
		assert_true(world.cast_skill(&"lava_burst_1", enemy))
		var expected := 3 if stacks < 2 else (2 if stacks < 5 else 1)
		assert_eq(world.cast_turns, expected)
		assert_eq(world.pending_skill == null, stacks == 5)
		while world.pending_skill != null:
			world.continue_cast()
		assert_eq(world.turn_count, expected)
		assert_almost_eq(world.hero.casting_credit, 0.9, 0.000001)
		assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 0)
		assert_eq(world.hero.rage, 90)
		assert_eq(world.hero.cooldowns.lava_burst - world.turn_count, 6)


func test_lava_reserves_starting_stacks_keeps_new_gains_and_does_not_accelerate() -> void:
	var world := _world()
	_stacks(world, 4)
	world.hero.swing.remaining = 0
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	assert_eq(world.cast_maelstrom, 4)
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 5)
	assert_eq(world.cast_turns, 2)
	assert_not_null(world.pending_skill)
	world.hero.swing.remaining = 100
	assert_true(world.continue_cast())
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 1)
	assert_eq(world.turn_count, 2)
	assert_eq(world.cast_maelstrom, 0)


func test_cancel_and_invalid_completion_keep_reserved_and_new_stacks_and_rage() -> void:
	for failure in ["cancel", "dead", "range", "sight", "removed", "rage"]:
		var world := _world()
		_stacks(world, 4)
		world.hero.swing.remaining = 0
		var enemy := _enemy(world)
		_enemy(world, Vector2i(7, 8)) # Keep combat active when the cast target is lost.
		assert_true(world.cast_skill(&"lava_burst_1", enemy))
		world.hero.swing.remaining = 100
		var rage := world.hero.rage
		match failure:
			"cancel": world.cancel_cast()
			"dead": enemy.alive = false
			"range": enemy.tile = Vector2i(20, 20)
			"sight": world.sight_blockers[enemy.tile] = true
			"removed": world.actors.erase(enemy)
			"rage":
				world.hero.rage = 0
				rage = 0
		if failure != "cancel":
			assert_true(world.continue_cast())
		assert_null(world.pending_skill, failure)
		assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 5, failure)
		assert_eq(world.hero.rage, rage, failure)
		assert_false(world.hero.cooldowns.has("lava_burst"), failure)
		assert_eq(world.cast_maelstrom, 0, failure)


func test_completed_miss_spends_stacks_and_rage_without_control_or_attack_rewards() -> void:
	var world := _world()
	world.hero.learn_skill(SkillDefinition.catalog(&"relentless_assault_1"))
	_stacks(world, 5)
	world.hero.melee.hit = -1000
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	assert_eq(enemy.health, 10000)
	assert_eq(ClassToolkitRules.maelstrom_stacks(world.hero), 0)
	assert_eq(world.hero.rage, 90)
	assert_eq(world.hero.combo_points, 0)
	assert_false(enemy.debuffs.has("interrupt"))
	assert_eq(world.hero.cooldowns.lava_burst - world.turn_count, 6)


func test_fire_crit_grants_direct_spell_rewards_without_physical_or_holy_procs() -> void:
	var world := _world()
	for id in [&"relentless_assault_1", &"seal_fate_1", &"bandits_guile_1", &"battle_trance_1",
		&"vengeance_1", &"shaman_flurry_1", &"wrecking_crew_1", &"art_of_war_1"]:
		world.hero.learn_skill(SkillDefinition.catalog(id))
	_stacks(world, 5)
	world.hero.melee.hit = 100
	world.hero.melee.critical = 100
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	assert_eq(enemy.health, 10000 - 96)
	assert_eq(world.hero.combo_points, 2)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(int(world.hero.buffs[&"vengeance_1"].charges), 1)
	assert_eq(int(world.hero.buffs[&"bandits_guile_1"].charges), 1)
	for id in [&"shaman_flurry_1", &"wrecking_crew_1", &"art_of_war_1"]:
		assert_false(world.hero.buffs.has(id))
	var critical := world.hero.melee.critical
	world.hero.refresh_stats()
	assert_eq(world.hero.melee.critical, critical, "Temporary Lava crit must not leak into swings.")


func test_critical_bonus_changes_spell_roll_without_mutating_the_weapon_profile() -> void:
	var world := _world()
	var enemy := _enemy(world)
	var skill := world.hero.find_skill(&"lava_burst_1")
	for seed_value in range(100):
		world.combat_random.seed = seed_value
		var state := world.combat_random.state
		var baseline := ClassToolkitRules.magic_outcome(world, enemy, skill)
		world.combat_random.state = state
		var boosted := ClassToolkitRules.magic_outcome(world, enemy, skill, 1.0, 50)
		assert_eq(world.hero.melee.critical, -100.0)
		if boosted.critical():
			assert_false(baseline.critical())
			assert_eq(boosted.amount, baseline.amount * 2)
			return
	fail_test("Controlled roll search should exercise a Maelstrom critical.")


func test_banked_maelstrom_saves_strictly_and_death_clears_stacks_but_retains_learning() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	game.world.hero.learn_skill(SkillDefinition.catalog(&"maelstrom_weapon_1"))
	game.world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	_stacks(game.world, 5)
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(ClassToolkitRules.maelstrom_stacks(restored.hero), 5)
		assert_eq(restored.cast_maelstrom, 0)
	for invalid in [-1, 0, 6, 1.5]:
		var malformed := snapshot.duplicate(true)
		malformed.buffs.maelstrom_weapon_1.charges = invalid
		assert_null(SaveCodec.restore(malformed, false))
	var unlearned := snapshot.duplicate(true)
	unlearned.learned.erase("maelstrom_weapon_1")
	assert_null(SaveCodec.restore(unlearned, false))
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(ClassToolkitRules.maelstrom_stacks(game.world.hero), 0)
	assert_not_null(game.world.hero.find_skill(&"maelstrom_weapon_1"))
	assert_not_null(game.world.hero.find_skill(&"lava_burst_1"))


func test_sacred_duty_strengthens_only_empowered_judgement_and_commits_damage_at_cast() -> void:
	var world := _world()
	for id in [&"seal_of_command_1", &"judgement_1", &"art_of_war_1", &"sacred_duty_1"]:
		world.hero.learn_skill(SkillDefinition.catalog(id))
	ClassToolkitRules.apply(world, &"art_of_war_1", {"critical_ready": 1})
	world.hero.melee.hit = 100
	world.hero.melee.critical = -100
	world.hero.melee.damage_min = 20
	world.hero.melee.damage_max = 20
	world.hero.melee.attack_power = 0
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"judgement_1", enemy))
	assert_eq(int(enemy.debuffs[&"judgement_1"].damage), 68)
	assert_eq(int(enemy.debuffs[&"judgement_1"].critical), 1)
	assert_false(world.hero.buffs.has(&"art_of_war_1"))
	assert_false(world.hero.buffs.has(&"sacred_duty_1"))
	world.hero.learned_skills.erase(world.hero.find_skill(&"sacred_duty_1"))
	world.hero.melee.damage_min = 1000
	world.hero.melee.damage_max = 1000
	for index in range(3):
		world.wait_turn()
	assert_eq(enemy.health, 10000 - 68)


func test_kings_shout_stats_rebuild_on_load_and_reject_copied_stats_or_expired_shout() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	for id in [&"battle_shout_1", &"blessing_of_kings_1"]:
		game.world.hero.learn_skill(SkillDefinition.catalog(id))
	assert_true(game.world.cast_skill(&"battle_shout_1"))
	game.world.hero.health = game.world.hero.max_health
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.hero.max_health, game.world.hero.max_health)
		assert_eq(restored.hero.health, game.world.hero.health)
		assert_eq(restored.hero.strength, game.world.hero.strength)
		assert_eq(restored.hero.agility, game.world.hero.agility)
		assert_eq(restored.hero.stamina, game.world.hero.stamina)
	for stat in ["strength", "agility", "stamina"]:
		var stale := snapshot.duplicate(true)
		stale.buffs.battle_shout_1[stat] = 2
		assert_null(SaveCodec.restore(stale, false))
	var expired := snapshot.duplicate(true)
	expired.buffs.battle_shout_1.until = game.world.turn_count
	assert_null(SaveCodec.restore(expired, false))
	for id in ["seal_of_command_1", "blessing_of_kings_1", "sacred_duty_1"]:
		var stale := snapshot.duplicate(true)
		stale.buffs[id] = {"armor": 0, "until": 0}
		assert_null(SaveCodec.restore(stale, false))


func test_lava_inspection_updates_cast_time_and_readiness_from_current_stacks() -> void:
	var world := _world()
	var button := SkillButton.new()
	add_child_autofree(button)
	for stacks in [0, 4, 5]:
		_stacks(world, stacks)
		button.describe(world.hero.find_skill(&"lava_burst_1"), world.hero)
		assert_string_contains(button.tooltip_text,
			"instant (one action)" if stacks == 5 else "Now: %d-turn cast" % (3 if stacks == 0 else 2))
		assert_string_contains(button.tooltip_text, "+%d percentage points crit" % (stacks * 10))
	for id in [&"earth_shock_1", &"elemental_assault_1", &"improved_earth_shock_1", &"blessing_of_might_1"]:
		assert_null(SkillDefinition.catalog(id))
