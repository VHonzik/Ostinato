extends GutTest


func _world(weapon: int = 2224) -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(8, 8), 97, false)
	for identifier in PoisonRules.COATINGS + [&"catalytic_venom_1", &"sudden_death_1", &"relentless_assault_1"]:
		var skill := SkillRank.catalog(identifier)
		world.hero.class_progress[skill.class_tab] = 1000
		world.hero.learn_skill(skill)
	world.hero.equipment.weapons = ItemData.instance(weapon)
	world.hero.refresh_stats()
	world.hero.rage = 100
	world.hero.find_skill(&"instant_poison_1").coefficient = 1.0
	world.hero.find_skill(&"deadly_poison_1").coefficient = 1.0
	world.hero.find_skill(&"sudden_death_1").coefficient = 1.0
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(9, 8)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.title = "Poison target"
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.max_health = 10000
	enemy.health = 10000
	enemy.stunned_until = 999
	enemy.awards_experience = false
	world.actors.append(enemy)
	return enemy


func test_poison_unlocks_share_checkpoint_and_catalyst_is_later() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(8, 8), 97, false)
	world.hero.selected_class = &"Rogue"
	world.hero.class_progress[&"Rogue"] = 79
	for identifier in PoisonRules.COATINGS:
		assert_false(world.train(&"Rogue", identifier))
	world.hero.class_progress[&"Rogue"] = 80
	for identifier in PoisonRules.COATINGS:
		assert_true(world.train(&"Rogue", identifier))
	assert_false(world.train(&"Rogue", &"catalytic_venom_1"))
	world.hero.class_progress[&"Rogue"] = 180
	assert_true(world.train(&"Rogue", &"catalytic_venom_1"))
	assert_false(world.assign_hotbar(0, &"catalytic_venom_1"))


func test_selected_hand_replacement_preserves_other_coating_and_expiration() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"instant_poison_1"))
	var original_expiry: int = world.hero.buffs[&"instant_poison_1"].off_until
	world.wait_turn()
	assert_true(world.cast_skill(&"deadly_poison_1", null, PoisonRules.Hands.MAIN))
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"deadly_poison_1")
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, true), &"instant_poison_1")
	assert_eq(int(world.hero.buffs[&"instant_poison_1"].off_until), original_expiry)
	assert_true(world.cast_skill(&"instant_poison_1", null, PoisonRules.Hands.MAIN))
	assert_false(world.hero.buffs.has(&"deadly_poison_1"))
	world.turn_count = original_expiry
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, true), &"")
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"instant_poison_1")
	world.hero.equipment.weapons = ItemData.instance(2139)
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"")


func test_single_weapon_rejects_offhand_without_cost_and_both_coats_only_main() -> void:
	for weapon in [35, 2129]:
		var world := _world(weapon)
		assert_false(world.cast_skill(&"deadly_poison_1", null, PoisonRules.Hands.OFF))
		assert_eq(world.turn_count, 0)
		assert_eq(world.hero.rage, 100)
		assert_true(world.cast_skill(&"deadly_poison_1"))
		assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"deadly_poison_1")
		assert_eq(PoisonRules.coating(world.hero, world.turn_count, true), &"")


func test_catalyst_requires_fast_instant_slow_deadly_and_draws_only_one_roll() -> void:
	for weapon in [2224, 2139]:
		for correct_orientation in [true, false]:
			var world := _world(weapon)
			var instant_hand := PoisonRules.Hands.OFF if correct_orientation else PoisonRules.Hands.MAIN
			PoisonRules.coat(world, world.hero.find_skill(&"instant_poison_1"), instant_hand)
			PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"), 3 - instant_hand)
			var enemy := _enemy(world)
			var generator := RandomNumberGenerator.new()
			generator.state = world.combat_random.state
			generator.randf()
			PoisonRules.on_hit(world, enemy, correct_orientation)
			assert_eq(world.combat_random.state, generator.state)
			assert_eq(enemy.health, 9992)
			assert_eq(enemy.debuffs.has(&"deadly_poison_1"), weapon == 2224 and correct_orientation)
			assert_eq(world.hero.combo_points, 0)
			assert_eq(world.hero.rage, 100)
			assert_false(world.hero.buffs.has(&"sudden_death_1"))


func test_deadly_shares_capped_stacks_and_refresh_does_not_delay_or_reset_fraction() -> void:
	var world := _world()
	var enemy := _enemy(world)
	PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"))
	PoisonRules.on_hit(world, enemy, false)
	world.wait_turn()
	assert_eq(enemy.health, 9999)
	assert_almost_eq(float(enemy.debuffs[&"deadly_poison_1"].damage_credit), 0.5, 0.000001)
	PoisonRules.on_hit(world, enemy, true)
	assert_eq(int(enemy.debuffs[&"deadly_poison_1"].next_tick), 2)
	world.wait_turn()
	assert_eq(enemy.health, 9996)
	for index in range(8):
		PoisonRules.on_hit(world, enemy, index % 2 == 0)
	assert_eq(int(enemy.debuffs[&"deadly_poison_1"].stacks), 5)
	assert_eq(int(enemy.debuffs[&"deadly_poison_1"].until), 14)
	world.wait_turn()
	assert_eq(enemy.health, 9988, "Stored half damage plus five stacks produces eight.")


func test_deadly_has_twelve_ticks_with_level_penalty_and_no_random_or_proc_hooks() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.melee.level = 3
	enemy.melee.armor = 100000
	PoisonRules.apply_deadly(world, enemy)
	var random_state := world.combat_random.state
	for index in range(12):
		world.wait_turn()
	assert_eq(enemy.health, 10000 - floori(12 * 1.5 * 0.76))
	assert_false(enemy.debuffs.has(&"deadly_poison_1"))
	assert_eq(world.combat_random.state, random_state)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))
	assert_eq(world.hero.combo_points, 0)
	world.wait_turn()
	assert_eq(enemy.health, 9987)


func test_targets_keep_separate_stacks_and_reapplication_after_expiry_starts_fresh() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(7, 8))
	PoisonRules.apply_deadly(world, first)
	PoisonRules.apply_deadly(world, first)
	PoisonRules.apply_deadly(world, second)
	world.wait_turn()
	assert_eq(first.health, 9997)
	assert_eq(second.health, 9999)
	for index in range(11):
		world.wait_turn()
	assert_true(first.debuffs.is_empty())
	assert_true(second.debuffs.is_empty())
	PoisonRules.apply_deadly(world, second)
	world.wait_turn()
	assert_eq(int(second.debuffs[&"deadly_poison_1"].stacks), 1)
	assert_almost_eq(float(second.debuffs[&"deadly_poison_1"].damage_credit), 0.5, 0.000001)
	assert_true(first.debuffs.is_empty())


func test_catalyst_stops_without_passive_or_when_slower_coating_expires() -> void:
	var world := _world()
	PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"), PoisonRules.Hands.MAIN)
	world.wait_turn()
	PoisonRules.coat(world, world.hero.find_skill(&"instant_poison_1"), PoisonRules.Hands.OFF)
	var enemy := _enemy(world)
	var passive := world.hero.find_skill(&"catalytic_venom_1")
	world.hero.learned_skills.erase(passive)
	PoisonRules.on_hit(world, enemy, true)
	assert_true(enemy.debuffs.is_empty())
	world.hero.learned_skills.append(passive)
	world.turn_count = int(world.hero.buffs[&"deadly_poison_1"].main_until)
	PoisonRules.on_hit(world, enemy, true)
	assert_eq(enemy.health, 9984, "Unexpired Instant still deals damage.")
	assert_true(enemy.debuffs.is_empty(), "Expired Deadly cannot catalyze a stack.")


func test_bonus_attacks_and_failed_hits_do_not_apply_deadly_and_instant_kill_does_not_catalyze() -> void:
	var world := _world()
	var enemy := _enemy(world)
	PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"))
	ClassToolkitRules.bonus_strike(world, enemy, false, 1.0, "Windfury")
	assert_true(enemy.debuffs.is_empty())
	world.hero.melee.hit = -1000
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_true(enemy.debuffs.is_empty())
	PoisonRules.coat(world, world.hero.find_skill(&"instant_poison_1"), PoisonRules.Hands.OFF)
	enemy.health = 1
	PoisonRules.on_hit(world, enemy, true)
	assert_false(enemy.alive)
	assert_true(enemy.debuffs.is_empty())


func test_dot_boss_kill_stops_later_dots_and_player_death_prevents_ticks() -> void:
	for player_dies in [true, false]:
		var world := _world()
		var boss := _enemy(world)
		boss.stalker = true
		boss.health = 1
		var later := _enemy(world, Vector2i(7, 8))
		PoisonRules.apply_deadly(world, boss)
		PoisonRules.apply_deadly(world, later)
		if player_dies:
			world.hero.facing = Vector2i.LEFT
			boss.stunned_until = 0
			boss.engaged = true
			boss.melee.hit = 1000
			boss.melee.damage_min = 100000
			boss.melee.damage_max = 100000
		world.wait_turn()
		assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED
			if player_dies else GridWorld.AttemptState.COMPLETED)
		assert_eq(later.health, later.max_health)
		assert_eq(boss.health, 1 if player_dies else 0)


func test_poison_picker_cancel_costs_nothing_and_confirm_uses_selected_hand() -> void:
	var world := _world()
	var panel := CombatPanel.new()
	add_child_autofree(panel)
	panel.open_poison(world, world.hero.find_skill(&"deadly_poison_1"))
	panel.navigate(Vector2i.RIGHT)
	assert_eq(panel._poison_hands, PoisonRules.Hands.MAIN)
	panel.cancel()
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 100)
	assert_true(world.hero.buffs.is_empty())
	panel.open_poison(world, world.hero.find_skill(&"deadly_poison_1"))
	panel.navigate(Vector2i.LEFT)
	assert_eq(panel._poison_hands, PoisonRules.Hands.OFF)
	panel.confirm()
	assert_false(panel.visible)
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 88, "Ten rage plus the ordinary out-of-combat decay.")
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, false), &"")
	assert_eq(PoisonRules.coating(world.hero, world.turn_count, true), &"deadly_poison_1")


func test_save_round_trip_preserves_fractional_dot_hand_timers_and_death_retains_learning() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	var world := game.world
	for identifier in PoisonRules.COATINGS + [&"catalytic_venom_1"]:
		world.hero.class_progress[&"Rogue"] = 1000
		world.hero.learn_skill(SkillRank.catalog(identifier))
	world.hero.equipment.weapons = ItemData.instance(2224)
	world.hero.refresh_stats()
	PoisonRules.coat(world, world.hero.find_skill(&"instant_poison_1"), PoisonRules.Hands.OFF)
	world.wait_turn()
	PoisonRules.coat(world, world.hero.find_skill(&"deadly_poison_1"), PoisonRules.Hands.MAIN)
	var enemy := _enemy(world, world.player_tile + Vector2i.RIGHT)
	PoisonRules.apply_deadly(world, enemy)
	world.wait_turn()
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(SaveCodec.capture(game)))
	var restored := SaveCodec.restore(snapshot, false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hero.buffs, world.hero.buffs)
	assert_eq(restored.actors[-1].debuffs, enemy.debuffs)
	var legacy := snapshot.duplicate(true)
	legacy.buffs.instant_poison_1.erase("main_until")
	legacy.buffs.instant_poison_1.erase("off_until")
	var restored_legacy := SaveCodec.restore(legacy, false)
	assert_not_null(restored_legacy, "Existing revision-18 Instant coatings still load.")
	if restored_legacy != null:
		assert_eq(PoisonRules.coating(restored_legacy.hero, restored_legacy.turn_count, true),
			&"instant_poison_1")
	for index in range(11):
		world.wait_turn()
		restored.wait_turn()
	assert_eq(restored.actors[-1].health, enemy.health)
	for invalid: Variant in [-0.1, 1.0, "0.5"]:
		var corrupt := snapshot.duplicate(true)
		corrupt.actors[-1].debuffs.deadly_poison_1.damage_credit = invalid
		assert_null(SaveCodec.restore(corrupt, false))
	var unlearned := snapshot.duplicate(true)
	unlearned.learned.erase("deadly_poison_1")
	assert_null(SaveCodec.restore(unlearned, false))
	world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_true(game.world.hero.buffs.is_empty())
	assert_not_null(game.world.hero.find_skill(&"deadly_poison_1"))
	assert_not_null(game.world.hero.find_skill(&"catalytic_venom_1"))
	assert_true(game.world.actors.all(func(actor: GridActor) -> bool: return actor.debuffs.is_empty()))
