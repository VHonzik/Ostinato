extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	world.hero.selected_class = &"Paladin"
	for id in [&"seal_of_command_1", &"execution_sentence_1", &"consecration_1"]:
		assert_true(world.hero.learn_skill(SkillDefinition.catalog(id)))
	world.hero.buffs[&"seal_of_command_1"] = {"armor": 0, "until": 100}
	world.hero.rage = 100
	world.hero.melee.hit = 100
	world.hero.melee.critical = 0
	world.hero.melee.attack_power = 0
	world.hero.melee.damage_min = 20
	world.hero.melee.damage_max = 20
	world.hero.swing.remaining = 100
	world.hero.swing._active = true
	return world


func _enemy(world: GridWorld, tile: Vector2i) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.melee.dodge = 0
	enemy.stunned_until = 999
	enemy.awards_experience = false
	world.actors.append(enemy)
	return enemy


func test_sentence_is_fixed_at_cast_and_lands_once_without_retargeting_or_range_requirement() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(10, 8))
	var other := _enemy(world, Vector2i(8, 10))
	assert_true(world.cast_skill(&"execution_sentence_1", enemy))
	var damage := int(enemy.debuffs[&"execution_sentence_1"].damage)
	assert_eq(enemy.health, 10000)
	world.auto_attack_target = other
	world.last_attacked_enemy = other
	enemy.tile = Vector2i(20, 20)
	world.hero.melee.damage_min = 1000
	world.hero.melee.damage_max = 1000
	world.hero.melee.critical = 100
	for turn in range(world.hero.find_skill(&"execution_sentence_1").delay_turns - 1):
		world.wait_turn()
		assert_eq(enemy.health, 10000)
	world.wait_turn()
	assert_eq(enemy.health, 10000 - damage)
	assert_same(world.auto_attack_target, other)
	assert_same(world.last_attacked_enemy, other)
	world.wait_turn()
	assert_eq(enemy.health, 10000 - damage)


func test_dead_target_loses_sentence_without_rewards_or_retargeting() -> void:
	var world := _world()
	assert_true(world.hero.learn_skill(SkillDefinition.catalog(&"divine_purpose_1")))
	world.hero.find_skill(&"divine_purpose_1").coefficient = 1.0
	var enemy := _enemy(world, Vector2i(10, 8))
	var other := _enemy(world, Vector2i(8, 10))
	assert_true(world.cast_skill(&"execution_sentence_1", enemy))
	SpellEffects.damage(world, enemy, 10000, "Test")
	world.auto_attack_target = other
	for turn in range(4):
		world.wait_turn()
	assert_false(enemy.debuffs.has(&"execution_sentence_1"))
	assert_false(world.hero.buffs.has(&"divine_purpose_1"))
	assert_eq(other.health, 10000)
	assert_same(world.auto_attack_target, other)


func test_sentence_reserves_guaranteed_crit_and_grants_retained_rewards_only_on_impact() -> void:
	var world := _world()
	for id in [&"art_of_war_1", &"sacred_duty_1", &"divine_purpose_1",
		&"battle_trance_1", &"relentless_assault_1"]:
		assert_true(world.hero.learn_skill(SkillDefinition.catalog(id)))
	world.hero.find_skill(&"divine_purpose_1").coefficient = 1
	world.hero.find_skill(&"sacred_duty_1").coefficient = 1
	ClassToolkitRules.apply(world, &"art_of_war_1", {"critical_ready": 1})
	world.hero.melee.hit = 100
	world.hero.melee.critical = 0
	var enemy := _enemy(world, Vector2i(10, 8))
	assert_true(world.cast_skill(&"execution_sentence_1", enemy))
	assert_eq(int(enemy.debuffs[&"execution_sentence_1"].critical), 1)
	assert_false(world.hero.buffs.has(&"art_of_war_1"))
	assert_false(world.hero.buffs.has(&"divine_purpose_1"))
	assert_false(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.hero.combo_points, 0)
	for turn in range(world.hero.find_skill(&"execution_sentence_1").delay_turns):
		world.wait_turn()
	assert_true(world.hero.buffs.has(&"divine_purpose_1"))
	assert_true(world.hero.buffs.has(&"sacred_duty_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.hero.combo_points, 1)
	world.hero.cooldowns.clear()
	world.hero.rage = 0
	assert_true(world.cast_skill(&"execution_sentence_1", enemy))
	assert_false(world.hero.buffs.has(&"divine_purpose_1"))
	assert_false(world.hero.buffs.has(&"sacred_duty_1"))
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.hero.combo_points, 1, "Applying the next sentence grants no early point.")


func test_verdict_precedes_due_swings_and_enemy_actions_and_stops_on_victory() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(9, 8))
	assert_true(world.cast_skill(&"execution_sentence_1", enemy))
	enemy.stalker = true
	world.stalkers_arrived = 1
	enemy.health = 1
	for turn in range(world.hero.find_skill(&"execution_sentence_1").delay_turns - 1):
		world.wait_turn()
	world.hero.swing.remaining = 0
	enemy.stunned_until = 0
	enemy.melee.damage_min = 10000
	enemy.melee.damage_max = 10000
	var health := world.hero.health
	world.wait_turn()
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_eq(world.hero.health, health)
	assert_string_contains("\n".join(world.messages), "Execution Sentence ->")


func test_consecration_stays_put_ticks_six_times_and_never_triggers_attack_rewards() -> void:
	var world := _world()
	for id in [&"relentless_assault_1", &"art_of_war_1", &"battle_trance_1"]:
		assert_true(world.hero.learn_skill(SkillDefinition.catalog(id)))
	world.hero.melee.critical = 100
	var skill := world.hero.find_skill(&"consecration_1")
	skill.weapon_multiplier = 0
	skill.periodic_damage = 5
	var inside := _enemy(world, Vector2i(9, 8))
	var outside := _enemy(world, Vector2i(11, 8))
	var friendly := _enemy(world, Vector2i(8, 9))
	friendly.relationship = GridActor.Relationship.FRIENDLY
	assert_true(world.cast_skill(skill.id))
	assert_eq(inside.health, 9995)
	assert_eq(outside.health, 10000)
	assert_eq(friendly.health, 10000)
	world.player_tile = Vector2i(18, 18)
	for turn in range(5):
		world.wait_turn()
	assert_eq(inside.health, 9970)
	world.wait_turn()
	assert_eq(inside.health, 9970)
	assert_true(world.consecration.is_empty())
	assert_eq(world.hero.combo_points, 0)
	assert_false(world.hero.buffs.has(&"art_of_war_1"))
	assert_false(world.hero.buffs.has(&"battle_trance_1"))


func test_ground_and_poison_tick_once_at_the_same_boundary_in_stable_order() -> void:
	var world := _world()
	assert_true(world.hero.learn_skill(SkillDefinition.catalog(&"deadly_poison_1")))
	var enemy := _enemy(world, Vector2i(9, 8))
	enemy.title = "Target"
	var ground := world.hero.find_skill(&"consecration_1")
	ground.weapon_multiplier = 0
	ground.periodic_damage = 5
	PoisonRules.apply_deadly(world, enemy)
	assert_true(world.cast_skill(ground.id))
	assert_eq(enemy.health, 9994, "One ground tick plus one poison tick.")
	var messages := "\n".join(world.messages)
	assert_lt(messages.find("Consecration -> Target:"), messages.find("Deadly Poison -> Target:"))
	world.wait_turn()
	assert_eq(enemy.health, 9987, "The next boundary delivers each effect exactly once.")


func test_ground_respects_sight_and_replacement_does_not_stack_patches() -> void:
	var world := _world()
	var skill := world.hero.find_skill(&"consecration_1")
	skill.weapon_multiplier = 0
	skill.periodic_damage = 5
	var enemy := _enemy(world, Vector2i(9, 9))
	world.sight_blockers[enemy.tile] = true
	assert_true(world.cast_skill(skill.id))
	assert_eq(enemy.health, 10000)
	world.sight_blockers.clear()
	world.player_tile = Vector2i(18, 18)
	world.hero.cooldowns.clear()
	assert_true(world.cast_skill(skill.id))
	assert_eq(world.consecration.center, Vector2i(18, 18))
	assert_eq(enemy.health, 10000)


func test_save_restores_pending_verdict_and_ground_timing_and_rejects_invalid_effects() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	game.loop_count = 2
	game.world = _world()
	var world := game.world
	var enemy := _enemy(world, Vector2i(10, 8))
	assert_true(world.cast_skill(&"consecration_1"))
	assert_true(world.cast_skill(&"execution_sentence_1", enemy))
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	for field in ["center", "until", "next_tick"]:
		assert_eq(restored.consecration[field], world.consecration[field])
	assert_almost_eq(float(restored.consecration.damage), float(world.consecration.damage), 0.000000001)
	assert_eq(restored.actors[0].debuffs, enemy.debuffs)
	for turn in range(4):
		world.wait_turn()
		restored.wait_turn()
	assert_eq(restored.actors[0].health, enemy.health)
	assert_eq(restored.combat_random.state, world.combat_random.state)
	for field in ["damage", "until", "critical"]:
		var invalid := snapshot.duplicate(true)
		invalid.actors[0].debuffs.execution_sentence_1[field] = -1
		assert_null(SaveCodec.restore(invalid, false))
	var invalid_ground := snapshot.duplicate(true)
	invalid_ground.consecration.center = [999, 999]
	assert_null(SaveCodec.restore(invalid_ground, false))
	for id in ["consecration_1", "execution_sentence_1"]:
		var unlearned := snapshot.duplicate(true)
		unlearned.learned.erase(id)
		assert_null(SaveCodec.restore(unlearned, false))
	world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_true(game.world.consecration.is_empty())
	assert_true(game.world.actors.all(func(actor: GridActor) -> bool:
		return not actor.debuffs.has(&"execution_sentence_1")))
	assert_not_null(game.world.hero.find_skill(&"execution_sentence_1"))
	assert_not_null(game.world.hero.find_skill(&"consecration_1"))
