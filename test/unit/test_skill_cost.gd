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
		assert_eq(world.hero.find_skill(&"execute_1").cost(world.hero), 0)
		assert_eq(world.hero.find_skill(&"mortal_strike_1").cost(world.hero), 0)
	assert_eq(world.hero.rage, 30)
	assert_eq(world.hero.buffs, buffs)
	assert_eq(world.combat_random.state, random_state)
	assert_eq(world.turn_count, 0)


func test_execute_uses_specific_free_proc_and_preserves_generic_proc_for_next_attack() -> void:
	var world := _world()
	_free_proc(world, &"sudden_death_1")
	_free_proc(world, &"battle_trance_1")
	world.hero.rage = 0
	assert_true(world.cast_skill(&"execute_1", world.actors[0]))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"sudden_death_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_true(world.cast_skill(&"mortal_strike_1", world.actors[0]))
	assert_eq(world.hero.rage, 0)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))


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


func test_free_whirlwind_preserves_proc_on_rejection_and_consumes_it_once_for_all_targets() -> void:
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
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.hero.rage, 7)
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_lt(first.health, 10000)
	assert_lt(second.health, 10000)
	assert_eq(world.turn_count, 1)
