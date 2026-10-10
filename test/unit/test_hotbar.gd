extends GutTest


func test_assignments_reject_unknown_ranks_and_locked_edits_without_time_or_resources() -> void:
	var world := MovementFixture.create_world()
	assert_false(world.assign_hotbar(0, &"fireball_2"))
	assert_false(world.assign_hotbar(-1, &"fireball_1"))
	assert_false(world.assign_hotbar(5, &"fireball_1"))
	assert_true(world.assign_hotbar(0, &"fireball_1"))
	assert_true(world.assign_hotbar(4, &"frost_armor_1"))
	world.hotbar_locked = true
	assert_false(world.assign_hotbar(0, &"frost_armor_1"))
	assert_false(world.assign_hotbar(4, &""))
	assert_eq(world.hotbar, [&"fireball_1", &"", &"", &"", &"frost_armor_1"])
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.mana, world.hero.max_mana)
	world.hotbar_locked = false
	assert_true(world.assign_hotbar(4, &""))
	world.hero.level = 10
	assert_true(world.hero.learn_skill(SkillRank.catalog(&"parry_1")))
	assert_false(world.assign_hotbar(2, &"parry_1"), "Passives cannot be activated.")


func test_training_does_not_replace_rank_and_reset_load_new_game_keep_their_contracts() -> void:
	var session := GameSession.new()
	session.new_game(317)
	var world := session.world
	assert_true(world.assign_hotbar(0, &"fireball_1"))
	world.hero.level = 6
	world.hero.refresh_stats()
	world.hero.copper = 100
	assert_true(world.train(&"Mage", &"fireball_2"))
	assert_eq(world.hotbar[0], &"fireball_1")
	assert_true(world.assign_hotbar(1, &"fireball_2"))
	world.hotbar_locked = true
	world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hero.level, 1)
	assert_eq(session.world.hotbar[0], &"fireball_1")
	assert_eq(session.world.hotbar[1], &"fireball_2")
	assert_true(session.world.hotbar_locked)
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(snapshot, true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, session.world.hotbar)
	assert_true(restored.hotbar_locked)
	assert_eq(restored.hero.find_skill(restored.hotbar[1]).rank, 2)
	snapshot.hotbar[4] = "wrath_1"
	assert_null(SaveCodec.restore(snapshot, true), "Unlearned saved assignments are invalid.")
	session.new_game(318)
	assert_eq(session.world.hotbar, [&"fireball_1", &"frost_armor_1", &"", &"", &""])
	assert_false(session.world.hotbar_locked)


func test_pet_commands_require_a_learned_summon_and_round_trip() -> void:
	var session := GameSession.new()
	session.new_game(123)
	assert_false(session.world.assign_hotbar(0, &"pet_attack"))
	assert_true(session.world.hero.learn_skill(SkillRank.catalog(&"summon_imp_1")))
	assert_true(session.world.assign_hotbar(0, &"pet_attack"))
	assert_true(session.world.assign_hotbar(1, &"pet_follow"))
	assert_true(session.world.assign_hotbar(2, &"pet_dismiss"))
	var restored := SaveCodec.restore(SaveCodec.capture(session), true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, session.world.hotbar)


func test_new_game_defaults_are_known_and_cleared_slots_survive_save_and_death() -> void:
	var session := GameSession.new()
	session.new_game(318)
	assert_eq(session.world.hotbar, [&"fireball_1", &"frost_armor_1", &"", &"", &""])
	for index in [0, 1]:
		assert_not_null(session.world.hero.find_skill(session.world.hotbar[index]))
		assert_true(session.world.assign_hotbar(index, &""))
	var restored := SaveCodec.restore(SaveCodec.capture(session), true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, [&"", &"", &"", &"", &""])
	session.restore(restored, 318, 1)
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hotbar, [&"", &"", &"", &"", &""])
