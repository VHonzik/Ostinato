extends GutTest


func test_training_prefers_its_row_even_when_locked_and_preserves_full_hotbar() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(97)
	var world := session.world
	world.hero.warrior_progress = 150
	world.hotbar_locked = true
	assert_true(world.train(&"Warrior", &"battle_shout_1"))
	assert_eq(world.hotbar.slice(0, 3),
		[&"mortal_strike_1", &"whirlwind_1", &""])
	assert_eq(world.hotbar[10], &"battle_shout_1")
	assert_true(world.train(&"Warrior", &"anger_management_1"))
	assert_false(world.hotbar.has(&"anger_management_1"))
	world.hotbar.fill(&"mortal_strike_1")
	var assignments := world.hotbar.duplicate()
	assert_true(world.train(&"Warrior", &"charge_1"))
	assert_eq(world.hotbar, assignments, "A full bar never loses an assignment.")
	assert_not_null(world.hero.find_skill(&"charge_1"), "Learning still succeeds with a full bar.")
	assert_false(world.train(&"Warrior", &"charge_1"))
	assert_eq(world.hotbar, assignments)
	assert_eq(world.turn_count, 0)
	var restored := SaveCodec.restore(SaveCodec.capture(session), false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.hotbar, assignments)


func test_training_groups_maintenance_above_rotation_and_keeps_custom_assignments() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	assert_true(world.assign_hotbar(0, &"whirlwind_1"))
	assert_true(world.assign_hotbar(11, &"mortal_strike_1"))
	for identifier: StringName in [
		&"battle_shout_1", &"windfury_weapon_1", &"lightning_shield_1", &"seal_of_command_1",
		&"instant_poison_1", &"deadly_poison_1", &"blessing_of_might_1",
		&"charge_1", &"execute_1", &"booming_shout_1", &"earth_shock_1", &"feral_spirit_1",
		&"execution_sentence_1", &"divine_shield_1", &"evasion_1", &"eviscerate_1",
		&"earth_elemental_1", &"relentless_assault_1", &"consecration_1",
	]:
		var skill := SkillDefinition.catalog(identifier)
		world.hero.selected_class = skill.class_tab
		world.hero.class_progress[skill.class_tab] = 1000
		assert_true(world.train(skill.class_tab, identifier))
	assert_eq(world.hotbar.slice(0, 10), [
		&"whirlwind_1", &"charge_1", &"execute_1", &"booming_shout_1", &"earth_shock_1",
		&"feral_spirit_1", &"execution_sentence_1", &"divine_shield_1", &"evasion_1", &"eviscerate_1",
	])
	assert_eq(world.hotbar.slice(10), [
		&"battle_shout_1", &"mortal_strike_1", &"windfury_weapon_1", &"lightning_shield_1",
		&"seal_of_command_1", &"instant_poison_1", &"deadly_poison_1",
		&"blessing_of_might_1", &"earth_elemental_1", &"consecration_1",
	])
	assert_eq(world.turn_count, 0)


func test_training_uses_other_row_when_preferred_row_is_full() -> void:
	for setup: Array in [[&"battle_shout_1", 10, 0], [&"charge_1", 0, 10]]:
		var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
		world.hero.warrior_progress = 1000
		var first_slot: int = setup[1]
		for slot in range(first_slot, first_slot + 10):
			assert_true(world.assign_hotbar(slot, &"mortal_strike_1"))
		assert_true(world.train(&"Warrior", setup[0]))
		assert_eq(world.hotbar[setup[2]], setup[0])
		assert_eq(world.hotbar.count(&"mortal_strike_1"), 10, "Existing assignments survive.")


func test_assignments_reject_unknown_skills_and_locked_edits_without_time_or_resources() -> void:
	var world := MovementFixture.create_world()
	assert_false(world.assign_hotbar(0, &"fireball_2"))
	assert_false(world.assign_hotbar(-1, &"mortal_strike_1"))
	assert_false(world.assign_hotbar(20, &"mortal_strike_1"))
	assert_true(world.assign_hotbar(0, &"mortal_strike_1"))
	assert_true(world.assign_hotbar(4, &"whirlwind_1"))
	world.hotbar_locked = true
	assert_false(world.assign_hotbar(0, &"whirlwind_1"))
	assert_false(world.assign_hotbar(4, &""))
	assert_eq(world.hotbar, [
		&"mortal_strike_1", &"", &"", &"", &"whirlwind_1", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 0)
	world.hotbar_locked = false
	assert_true(world.assign_hotbar(4, &""))
	world.hero.level = 10
	assert_true(world.hero.learn_skill(SkillDefinition.catalog(&"anger_management_1")))
	assert_false(world.assign_hotbar(2, &"anger_management_1"), "Passives cannot be activated.")


func test_training_does_not_replace_skill_and_reset_load_new_game_keep_their_contracts() -> void:
	var session := GameSession.new()
	session.new_game(317)
	var world := session.world
	assert_true(world.assign_hotbar(0, &"mortal_strike_1"))
	world.hero.warrior_progress = 40
	assert_true(world.train(&"Warrior", &"anger_management_1"))
	assert_eq(world.hotbar[0], &"mortal_strike_1")
	assert_true(world.assign_hotbar(1, &"whirlwind_1"))
	world.hotbar_locked = true
	world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hero.level, 1)
	assert_eq(session.world.hotbar[0], &"mortal_strike_1")
	assert_eq(session.world.hotbar[1], &"whirlwind_1")
	assert_true(session.world.hotbar_locked)
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(snapshot, true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, session.world.hotbar)
	assert_true(restored.hotbar_locked)
	assert_eq(restored.hero.find_skill(restored.hotbar[1]).id, &"whirlwind_1")
	snapshot.hotbar[4] = "wrath_1"
	assert_null(SaveCodec.restore(snapshot, true), "Unlearned saved assignments are invalid.")
	session.new_game(318)
	assert_eq(session.world.hotbar, [
		&"mortal_strike_1", &"whirlwind_1", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
	])
	assert_false(session.world.hotbar_locked)


func test_new_game_defaults_are_known_and_cleared_slots_survive_save_and_death() -> void:
	var session := GameSession.new()
	session.new_game(318)
	assert_eq(session.world.hotbar, [
		&"mortal_strike_1", &"whirlwind_1", &"", &"", &"", &"", &"", &"", &"", &"",
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
	assert_true(session.world.assign_hotbar(19, &"mortal_strike_1"))
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(snapshot, true)
	assert_not_null(restored)
	assert_eq(restored.hotbar.size(), 20)
	assert_eq(restored.hotbar[19], &"mortal_strike_1")
	session.restore(restored, 319, 1)
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hotbar[19], &"mortal_strike_1")
	snapshot.hotbar.resize(5)
	assert_null(SaveCodec.restore(snapshot, true))


func test_cooldown_countdown_updates_and_clears_when_ready_or_slot_changes() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	world.hero.warrior_progress = 20
	assert_true(world.train(&"Warrior", &"battle_shout_1"))
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
	assert_eq(cooldown.text, "30")
	assert_eq(duplicate.text, "30", "All slots assigned this family show its cooldown.")
	assert_true(panel.slots[0].text.begins_with(options.key_label(&"hotbar_1")))
	world.wait_turn()
	panel.refresh(world, options, false, false, false)
	assert_true(panel.slots[0].disabled)
	assert_true(cooldown.visible, "Countdown remains visible while other input is blocked.")
	assert_eq(cooldown.text, "29")
	world.assign_hotbar(1, &"mortal_strike_1")
	panel.refresh(world, options, true, true, false)
	assert_false(duplicate.visible)
	assert_eq(duplicate.text, "")
	for index in range(29):
		world.wait_turn()
	panel.refresh(world, options, true, true, false)
	assert_false(cooldown.visible)
	assert_eq(cooldown.text, "")
	world.cast_skill(&"battle_shout_1")
	world.assign_hotbar(0, &"")
	panel.refresh(world, options, true, true, false)
	assert_false(cooldown.visible)
	assert_eq(cooldown.text, "")
