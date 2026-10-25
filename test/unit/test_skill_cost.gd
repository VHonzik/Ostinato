extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 16, 16), Vector2i(5, 5), 97, false)
	for identifier: StringName in [&"execute_1", &"sudden_death_1", &"battle_trance_1",
		&"judgement_1", &"seal_of_command_1", &"blessing_of_kings_1"]:
		world.hero.learn_skill(SkillDefinition.catalog(identifier))
	world.hero.melee.hit = 100.0
	world.hero.melee.critical = 0.0
	world.hero.swing.remaining = 100.0
	world.hero.swing._active = true
	world.hero.rage = 30
	var enemy := GridActor.new(Vector2i(6, 5))
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.awards_experience = false
	enemy.stunned_until = 999
	enemy.melee.dodge = 0.0
	world.actors.append(enemy)
	return world


func _free_proc(world: GridWorld, identifier: StringName) -> void:
	ClassToolkitRules.apply(world, identifier, {"charges": 1})
	# Applying buffs rebuilds melee stats; keep this fixture's attacks noncritical.
	world.hero.melee.critical = 0.0


func test_repeated_cost_previews_preserve_resources_procs_and_randomness() -> void:
	var world := _world()
	_free_proc(world, &"sudden_death_1")
	_free_proc(world, &"battle_trance_1")
	var buffs := world.hero.buffs.duplicate(true)
	var random_state := world.combat_random.state
	for index in range(3):
		assert_eq(world.hero.find_skill(&"execute_1").cost(world.hero), 30)
		assert_eq(world.hero.find_skill(&"mortal_strike_1").cost(world.hero), 0)
	assert_eq(world.hero.rage, 30)
	assert_eq(world.hero.buffs, buffs)
	assert_eq(world.combat_random.state, random_state)
	assert_eq(world.turn_count, 0)


func test_execute_pays_rage_consumes_sudden_death_and_preserves_trance_for_next_attack() -> void:
	var world := _world()
	_free_proc(world, &"sudden_death_1")
	_free_proc(world, &"battle_trance_1")
	world.hero.rage = 30
	assert_true(world.cast_skill(&"execute_1", world.actors[0]))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(world.cast_skill(&"mortal_strike_1", world.actors[0]))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))


func test_sudden_death_and_trance_cannot_bypass_execute_minimum_rage() -> void:
	var world := _world()
	_free_proc(world, &"sudden_death_1")
	_free_proc(world, &"battle_trance_1")
	world.hero.rage = 14
	var random_state := world.combat_random.state
	assert_false(world.cast_skill(&"execute_1", world.actors[0]))
	assert_eq(world.hero.rage, 14)
	assert_eq(world.turn_count, 0)
	assert_eq(world.actors[0].health, 10000)
	assert_eq(world.combat_random.state, random_state)
	assert_true(world.hero.buffs.has(&"sudden_death_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))


func test_missed_sudden_death_execute_still_pays_and_preserves_trance() -> void:
	var world := _world()
	_free_proc(world, &"sudden_death_1")
	_free_proc(world, &"battle_trance_1")
	world.hero.melee.hit = -1000.0
	world.hero.rage = 22
	assert_true(world.cast_skill(&"execute_1", world.actors[0]))
	assert_eq(world.hero.rage, 0)
	assert_eq(world.actors[0].health, 10000)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))


func test_trance_pays_each_core_attack_at_zero_rage() -> void:
	for id: StringName in [&"mortal_strike_1", &"judgement_1", &"lava_burst_1", &"eviscerate_1"]:
		var world := _world()
		if world.hero.find_skill(id) == null:
			world.hero.learn_skill(SkillDefinition.catalog(id))
		_free_proc(world, &"battle_trance_1")
		world.hero.rage = 0
		world.hero.combo_points = 5
		assert_true(world.cast_skill(id, world.actors[0]), String(id))
		while world.pending_skill != null:
			world.hero.melee.critical = 0.0
			world.continue_cast()
		assert_eq(world.hero.rage, 0, String(id))
		assert_false(world.hero.buffs.has(&"battle_trance_1"), String(id))


func test_other_paid_abilities_require_rage_and_preserve_trance() -> void:
	for setup: Array in [
		[&"execute_1", 30], [&"whirlwind_1", 15], [&"evasion_1", 15],
		[&"divine_shield_1", 20], [&"consecration_1", 5], [&"feral_spirit_1", 25],
	]:
		var world := _world()
		var id: StringName = setup[0]
		if world.hero.find_skill(id) == null:
			world.hero.learn_skill(SkillDefinition.catalog(id))
		_free_proc(world, &"battle_trance_1")
		world.actors[0].health = 2000
		var skill := world.hero.find_skill(id)
		var target: GridActor = world.actors[0] if skill.target == SkillDefinition.Target.ENEMY else null
		world.hero.rage = 0
		assert_false(world.cast_skill(id, target), String(id))
		assert_eq(world.turn_count, 0, String(id))
		assert_true(world.hero.buffs.has(&"battle_trance_1"), String(id))
		world.hero.rage = 90
		assert_true(world.cast_skill(id, target), String(id))
		assert_eq(world.hero.rage, 90 - int(setup[1]), String(id))
		assert_true(world.hero.buffs.has(&"battle_trance_1"), String(id))


func test_judgement_consumes_battle_trance_and_next_cast_pays_normal_cost() -> void:
	var world := _world()
	_free_proc(world, &"battle_trance_1")
	world.hero.rage = 0
	assert_true(world.cast_skill(&"judgement_1", world.actors[0]))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.hero.find_skill(&"judgement_1").cost(world.hero), 20)
	assert_false(world.cast_skill(&"mortal_strike_1", world.actors[0]))


func test_passive_blessing_and_seal_reject_casts_without_spending_turn_or_free_proc() -> void:
	var world := _world()
	_free_proc(world, &"battle_trance_1")
	world.hero.rage = 0
	assert_false(world.cast_skill(&"blessing_of_kings_1"))
	assert_false(world.cast_skill(&"seal_of_command_1"))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"blessing_of_kings_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.turn_count, 0)
	assert_true(world.cast_skill(&"mortal_strike_1", world.actors[0]))
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.hero.rage, 0)


func test_cast_uses_proc_gained_during_windup_instead_of_old_preview_price() -> void:
	var world := _world()
	var skill := world.hero.find_skill(&"mortal_strike_1")
	skill.cast_seconds = 2.0
	assert_true(world.cast_skill(skill.id, world.actors[0]))
	assert_eq(world.hero.rage, 30)
	_free_proc(world, &"battle_trance_1")
	assert_true(world.continue_cast())
	assert_eq(world.hero.rage, 30)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.turn_count, 2)
	assert_lt(world.actors[0].health, 10000)


func test_cast_reprices_after_free_proc_is_lost_and_fails_without_rage() -> void:
	var world := _world()
	var skill := world.hero.find_skill(&"mortal_strike_1")
	skill.cast_seconds = 2.0
	_free_proc(world, &"battle_trance_1")
	world.hero.rage = 0
	assert_true(world.cast_skill(skill.id, world.actors[0]))
	world.hero.buffs.erase(&"battle_trance_1")
	assert_true(world.continue_cast())
	assert_eq(world.hero.rage, 0)
	assert_eq(world.actors[0].health, 10000)
	assert_false(world.hero.cooldowns.has(&"mortal_strike"))
	assert_string_contains(world.messages[-1], "Cast failed at completion")


func test_invalid_completion_preserves_new_proc_without_awarding_a_cooldown() -> void:
	var world := _world()
	var skill := world.hero.find_skill(&"mortal_strike_1")
	skill.cast_seconds = 2.0
	assert_true(world.cast_skill(skill.id, world.actors[0]))
	_free_proc(world, &"battle_trance_1")
	world.actors[0].tile = Vector2i(8, 5)
	assert_true(world.continue_cast())
	assert_eq(world.hero.rage, 30)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_false(world.hero.cooldowns.has(&"mortal_strike"))
	assert_eq(world.actors[0].health, 10000)


func test_execute_spends_completion_rage_up_to_cap_instead_of_initial_quote() -> void:
	var world := _world()
	var skill := world.hero.find_skill(&"execute_1")
	skill.cast_seconds = 2.0
	world.actors[0].health = 2000
	world.hero.rage = 20
	assert_true(world.cast_skill(skill.id, world.actors[0]))
	world.hero.rage = 40
	assert_true(world.continue_cast())
	assert_eq(world.hero.rage, 10)
	assert_string_contains("\n".join(world.messages), "Execute: spent 30 rage.")


func test_whirlwind_pays_once_for_all_targets_and_preserves_trance() -> void:
	var world := _world()
	world.hero.rage = 7
	_free_proc(world, &"battle_trance_1")
	var first := world.actors[0]
	first.tile = Vector2i(8, 5)
	assert_false(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 7)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	first.tile = Vector2i(6, 5)
	var second := GridActor.new(Vector2i(5, 6))
	second.relationship = GridActor.Relationship.HOSTILE
	second.health = 10000
	second.max_health = 10000
	second.awards_experience = false
	second.stunned_until = 999
	second.melee.dodge = 0.0
	world.actors.append(second)
	assert_false(world.cast_skill(&"whirlwind_1"), "Trance cannot cover the missing rage.")
	assert_eq(world.turn_count, 0)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	world.hero.rage = 30
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.hero.rage, 15)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_lt(first.health, 10000)
	assert_lt(second.health, 10000)
	assert_eq(world.turn_count, 1)
