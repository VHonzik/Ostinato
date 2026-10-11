extends GutTest


func test_assignments_reject_unknown_ranks_and_locked_edits_without_time_or_resources() -> void:
	var world := MovementFixture.create_world()
	assert_false(world.assign_hotbar(0, &"fireball_2"))
	assert_false(world.assign_hotbar(-1, &"slam_1"))
	assert_false(world.assign_hotbar(20, &"slam_1"))
	assert_true(world.assign_hotbar(0, &"slam_1"))
	assert_true(world.assign_hotbar(4, &"battle_shout_1"))
	world.hotbar_locked = true
	assert_false(world.assign_hotbar(0, &"battle_shout_1"))
	assert_false(world.assign_hotbar(4, &""))
	assert_eq(world.hotbar, [
		&"slam_1", &"", &"", &"", &"battle_shout_1", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])
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
	assert_true(world.assign_hotbar(0, &"slam_1"))
	world.hero.warrior_progress = 20
	assert_true(world.train(&"Warrior", &"anger_management_1"))
	assert_eq(world.hotbar[0], &"slam_1")
	assert_true(world.assign_hotbar(1, &"battle_shout_1"))
	world.hotbar_locked = true
	world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hero.level, 1)
	assert_eq(session.world.hotbar[0], &"slam_1")
	assert_eq(session.world.hotbar[1], &"battle_shout_1")
	assert_true(session.world.hotbar_locked)
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(snapshot, true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, session.world.hotbar)
	assert_true(restored.hotbar_locked)
	assert_eq(restored.hero.find_skill(restored.hotbar[1]).rank, 1)
	snapshot.hotbar[4] = "wrath_1"
	assert_null(SaveCodec.restore(snapshot, true), "Unlearned saved assignments are invalid.")
	session.new_game(318)
	assert_eq(session.world.hotbar, [
		&"slam_1", &"battle_shout_1", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])
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
	assert_eq(session.world.hotbar, [
		&"slam_1", &"battle_shout_1", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])
	for index in [0, 1]:
		assert_not_null(session.world.hero.find_skill(session.world.hotbar[index]))
		assert_true(session.world.assign_hotbar(index, &""))
	var restored := SaveCodec.restore(SaveCodec.capture(session), true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, [
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])
	session.restore(restored, 318, 1)
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hotbar, [
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])


func test_last_slot_survives_save_load_and_death_and_short_arrays_are_rejected() -> void:
	var session := GameSession.new()
	session.new_game(319)
	assert_true(session.world.assign_hotbar(19, &"slam_1"))
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(snapshot, true)
	assert_not_null(restored)
	assert_eq(restored.hotbar.size(), 20)
	assert_eq(restored.hotbar[19], &"slam_1")
	session.restore(restored, 319, 1)
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hotbar[19], &"slam_1")
	snapshot.hotbar.resize(5)
	assert_null(SaveCodec.restore(snapshot, true))


func test_cooldown_countdown_updates_and_clears_when_ready_or_slot_changes() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	world.assign_hotbar(0, &"battle_shout_1")
	world.assign_hotbar(1, &"battle_shout_1")
	var panel := HotbarPanel.new()
	add_child_autofree(panel)
	var options := GlobalOptions.new()
	world.cast_skill(&"battle_shout_1")
	panel.refresh(world, options, true, true, false)
	var cooldown := panel.slots[0].get_node("Cooldown") as Label
	var duplicate := panel.slots[1].get_node("Cooldown") as Label
	assert_true(cooldown.visible)
	assert_eq(cooldown.text, "10")
	assert_eq(duplicate.text, "10", "All slots assigned this family show its cooldown.")
	assert_true(panel.slots[0].text.begins_with(options.key_label(&"hotbar_1")))
	world.wait_turn()
	panel.refresh(world, options, false, false, false)
	assert_true(panel.slots[0].disabled)
	assert_true(cooldown.visible, "Countdown remains visible while other input is blocked.")
	assert_eq(cooldown.text, "9")
	world.assign_hotbar(1, &"slam_1")
	panel.refresh(world, options, true, true, false)
	assert_false(duplicate.visible)
	assert_eq(duplicate.text, "")
	for index in range(9):
		world.wait_turn()
	panel.refresh(world, options, true, true, false)
	assert_false(cooldown.visible)
	assert_eq(cooldown.text, "")
	world.cast_skill(&"battle_shout_1")
	world.assign_hotbar(0, &"")
	panel.refresh(world, options, true, true, false)
	assert_false(cooldown.visible)
	assert_eq(cooldown.text, "")
