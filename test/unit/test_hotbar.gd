extends GutTest


func test_potion_pickup_and_purchase_fill_only_the_empty_slot_left_of_food() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(97)
	var world := session.world
	var janos := world.actor_at(NpcDefinition.find(NpcDefinition.JANOS_ID).tile)
	world.player_tile = janos.tile + Vector2i.DOWN
	world.hero.copper = 100
	world.hotbar_locked = true
	assert_true(world.buy_item(janos, 118, 1))
	assert_eq(world.hotbar[18], ItemData.POTION_HOTBAR_ID)
	assert_eq(world.hotbar[19], GridWorld.FOOD_HOTBAR_ID)
	world.hotbar_locked = false
	assert_true(world.assign_hotbar(18, &"mortal_strike_1"))
	assert_true(world.buy_item(janos, 118, 1))
	assert_eq(world.hotbar[18], &"mortal_strike_1", "Never replace an occupied neighbor.")
	assert_false(world.hotbar.has(ItemData.POTION_HOTBAR_ID))
	assert_true(world.assign_hotbar(3, ItemData.POTION_HOTBAR_ID))
	assert_true(world.assign_hotbar(18, &""))
	assert_true(world.buy_item(janos, 118, 1))
	assert_eq(world.hotbar[18], &"", "A custom potion shortcut prevents duplicates.")
	assert_eq(world.hotbar.count(ItemData.POTION_HOTBAR_ID), 1)
	assert_true(world.assign_hotbar(3, &""))
	var chest := GridActor.new(world.player_tile + Vector2i.RIGHT)
	chest.chest = true
	chest.alive = false
	chest.loot_assigned = true
	chest.loot.append(ItemData.instance(118))
	world.actors.append(chest)
	assert_true(world.loot_item(chest, 0))
	assert_eq(world.hotbar[18], ItemData.POTION_HOTBAR_ID)
	assert_eq(world.turn_count, 0)


func test_item_assignment_ui_and_save_preserve_custom_and_cleared_shortcuts() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(97)
	var world := session.world
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(118)))
	var menu := MenuPanel.new()
	menu.session = session
	add_child_autofree(menu)
	for item_id in [117, 118, 2070, 4536, 4540]:
		if item_id not in [117, 118]:
			assert_true(InventoryRules.receive(world.hero, ItemData.instance(item_id)))
		var index := -1
		for slot in range(world.hero.inventory.size()):
			if world.hero.inventory[slot].get("id", 0) == item_id:
				index = slot
		menu._item_detail(index)
		var assign: Button
		for button in menu._buttons:
			if button.text == "Assign to hotbar":
				assign = button
		assert_not_null(assign)
		if assign == null:
			return
		assign.pressed.emit()
		assert_eq(menu.page, "item_hotbar")
		var destination := 3 if item_id == 117 else (4 if item_id == 118 else 5)
		menu._buttons[destination].pressed.emit()
		assert_eq(world.hotbar[destination], ItemData.hotbar_id(item_id))
	assert_eq(world.hotbar[3], GridWorld.FOOD_HOTBAR_ID)
	assert_eq(world.hotbar[4], ItemData.POTION_HOTBAR_ID)
	assert_true(world.assign_hotbar(19, &""))
	assert_true(world.assign_hotbar(18, &""))
	world.hotbar_locked = true
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hotbar, world.hotbar, "Loading keeps empty convenience slots empty.")
	assert_true(restored.hotbar_locked)
	assert_eq(restored.turn_count, 0)
	world.hotbar_locked = false
	world.assign_hotbar(4, &"")
	restored = SaveCodec.restore(SaveCodec.capture(session), false)
	assert_not_null(restored)
	if restored != null:
		assert_false(restored.hotbar.has(ItemData.POTION_HOTBAR_ID),
			"Loading never recreates a shortcut the player cleared.")


func test_live_potion_shortcut_heals_and_reports_cooldown_without_extra_use() -> void:
	var game := (load("res://scenes/gameplay.tscn") as PackedScene).instantiate() as Gameplay
	add_child_autofree(game)
	game.set_process(false)
	game.start_new_game()
	var world := game.world
	world.stalker_schedule = false
	world.actors.clear()
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(118, 2)))
	assert_true(world.assign_hotbar(4, ItemData.POTION_HOTBAR_ID))
	world.hero.health = 1
	game._hotbar_slot_pressed(4)
	assert_gt(world.hero.health, 1)
	assert_eq(world.turn_count, 1)
	var cooldown := game.hotbar_panel.slots[4].get_node("Cooldown") as Label
	assert_true(cooldown.visible)
	assert_eq(cooldown.text, "120")
	assert_string_contains(game.hotbar_panel.slots[4].text, "Potion x1")
	game._hotbar_slot_pressed(4)
	assert_eq(world.turn_count, 1, "A potion on cooldown spends no turn or charge.")
	assert_string_contains(game.hotbar_panel.slots[4].text, "Potion x1")
	world.hotbar_locked = true
	assert_false(world.assign_hotbar(5, ItemData.POTION_HOTBAR_ID))


func test_looted_food_shortcut_uses_its_own_stack_and_restoration() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(4536)))
	assert_true(InventoryRules.receive(world.hero, ItemData.instance(117)))
	var identifier := ItemData.hotbar_id(4536)
	assert_true(world.assign_hotbar(3, identifier))
	assert_true(world.consume_hotbar_item(identifier))
	assert_eq(world.hero.restoration.food.total, 50)
	assert_eq(world.hero.restoration.food.duration, 10)
	assert_eq(world.turn_count, 1)
	assert_false(world.consume_hotbar_item(identifier), "The shortcut never substitutes another food.")
	assert_eq(world.turn_count, 1)
	assert_eq(world.hotbar[3], identifier, "An exhausted stack keeps its assignment.")


func test_hotbar_reports_crit_and_free_use_without_spending_procs_and_clears_reassigned_slots() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	var panel := HotbarPanel.new()
	add_child_autofree(panel)
	assert_true(world.assign_hotbar(0, &"mortal_strike_1"))
	world.hero.buffs[&"juggernaut_1"] = {"until": 0}
	world.hero.buffs[&"battle_trance_1"] = {"until": 0}
	world.hero.learn_skill(SkillDefinition.catalog(&"judgement_1"))
	world.hero.buffs[&"art_of_war_1"] = {"until": 0, "critical_ready": 1}
	world.assign_hotbar(1, &"judgement_1")
	world.hero.learn_skill(SkillDefinition.catalog(&"seal_of_command_1"))
	var enemy := GridActor.new(Vector2i(6, 5))
	enemy.relationship = GridActor.Relationship.HOSTILE
	world.actors.append(enemy)
	var before := world.hero.buffs.duplicate(true)
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_string_contains(panel.slots[0].tooltip_text, "Guaranteed critical")
	assert_string_contains(panel.slots[0].tooltip_text, "Free use ready")
	assert_string_contains(panel.slots[1].tooltip_text, "Guaranteed critical")
	assert_string_contains(panel.slots[1].tooltip_text, "Free use ready")
	assert_eq(world.hero.buffs, before)
	world.hero.buffs.clear()
	world.hotbar[1] = &""
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_false(panel.slots[0].tooltip_text.contains("Guaranteed critical"))
	assert_false(panel.slots[0].tooltip_text.contains("Free use ready"))
	assert_true(panel.slots[1].highlight_colors.is_empty())


func test_maintenance_feedback_requires_missing_effect_and_handles_weapon_changes() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	var panel := HotbarPanel.new()
	add_child_autofree(panel)
	for id: StringName in [&"battle_shout_1", &"lightning_shield_1", &"windfury_weapon_1"]:
		world.hero.learn_skill(SkillDefinition.catalog(id))
		world.assign_hotbar(0, id)
		panel.refresh(world, GlobalOptions.new(), true, true, false)
		assert_string_contains(panel.slots[0].tooltip_text, "Maintenance buff missing")
		assert_true(world.cast_skill(id))
		panel.refresh(world, GlobalOptions.new(), true, true, false)
		assert_false(panel.slots[0].tooltip_text.contains("Maintenance buff missing"), String(id))
		# One turn remaining still counts as present.
		world.hero.buffs[id].until = world.turn_count + 1
		panel.refresh(world, GlobalOptions.new(), true, true, false)
		assert_false(panel.slots[0].tooltip_text.contains("Maintenance buff missing"))
		world.wait_turn()
		panel.refresh(world, GlobalOptions.new(), true, true, false)
		assert_string_contains(panel.slots[0].tooltip_text, "Maintenance buff missing")
	world.hero.buffs[&"windfury_weapon_1"] = {"until": 100, "weapon_id": world.hero.weapon_id()}
	world.hero.equipment.weapons = ItemData.instance(2092)
	world.hero.refresh_stats()
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_string_contains(panel.slots[0].tooltip_text, "Maintenance buff missing")


func test_poison_maintenance_accepts_mixed_coatings_and_detects_an_expired_hand() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	world.hero.equipment.weapons = ItemData.instance(2092)
	world.hero.refresh_stats()
	var panel := HotbarPanel.new()
	add_child_autofree(panel)
	for id: StringName in PoisonRules.COATINGS:
		world.hero.learn_skill(SkillDefinition.catalog(id))
	world.assign_hotbar(0, &"instant_poison_1")
	world.assign_hotbar(1, &"deadly_poison_1")
	assert_true(world.cast_skill(&"instant_poison_1", null, PoisonRules.Hands.MAIN))
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_string_contains(panel.slots[0].tooltip_text, "Maintenance buff missing")
	assert_true(world.cast_skill(&"instant_poison_1", null, PoisonRules.Hands.BOTH))
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	for slot in [0, 1]:
		assert_false(panel.slots[slot].tooltip_text.contains("Maintenance buff missing"),
			"Instant on both hands also satisfies Deadly's maintenance check.")
	assert_true(world.cast_skill(&"deadly_poison_1", null, PoisonRules.Hands.OFF))
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	for slot in [0, 1]:
		assert_false(panel.slots[slot].tooltip_text.contains("Maintenance buff missing"))
	world.hero.buffs[&"instant_poison_1"].main_until = world.turn_count
	panel.refresh(world, GlobalOptions.new(), true, true, false)
	assert_string_contains(panel.slots[0].tooltip_text, "Maintenance buff missing")


func test_training_prefers_its_row_even_when_locked_and_preserves_full_hotbar() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(97)
	var world := session.world
	world.hero.level = 5
	world.hero.copper = 10000
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
		&"instant_poison_1", &"deadly_poison_1", &"blessing_of_kings_1",
		&"charge_1", &"execute_1", &"lava_burst_1", &"feral_spirit_1",
		&"judgement_1", &"divine_shield_1", &"evasion_1", &"eviscerate_1",
		&"relentless_assault_1", &"consecration_1",
	]:
		var skill := SkillDefinition.catalog(identifier)
		world.hero.selected_class = skill.class_tab
		world.hero.level = 5
		world.hero.copper = 10000
		assert_true(world.train(skill.class_tab, identifier))
	assert_eq(world.hotbar.slice(0, 10), [
		&"whirlwind_1", &"charge_1", &"execute_1", &"lava_burst_1",
		&"feral_spirit_1", &"judgement_1", &"divine_shield_1", &"evasion_1", &"eviscerate_1",
		&"consecration_1",
	])
	assert_eq(world.hotbar.slice(10), [
		&"battle_shout_1", &"mortal_strike_1", &"windfury_weapon_1", &"lightning_shield_1",
		&"instant_poison_1", &"deadly_poison_1", &"", &"", &"", &"",
	])
	assert_eq(world.turn_count, 0)


func test_training_uses_other_row_when_preferred_row_is_full() -> void:
	for setup: Array in [[&"battle_shout_1", 10, 0], [&"charge_1", 0, 10]]:
		var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
		world.hero.level = 5
		world.hero.copper = 10000
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
	world.hero.level = 5
	world.hero.copper = 10000
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
		&"", &"", &"", &"", &"", &"", &"", &"", &"", GridWorld.FOOD_HOTBAR_ID,
	])
	assert_false(session.world.hotbar_locked)


func test_new_game_defaults_are_known_and_cleared_slots_survive_save_and_death() -> void:
	var session := GameSession.new()
	session.new_game(318)
	assert_eq(session.world.hotbar, [
		&"mortal_strike_1", &"whirlwind_1", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", GridWorld.FOOD_HOTBAR_ID,
	])
	for index in [0, 1]:
		assert_not_null(session.world.hero.find_skill(session.world.hotbar[index]))
		assert_true(session.world.assign_hotbar(index, &""))
	var restored := SaveCodec.restore(SaveCodec.capture(session), true)
	assert_not_null(restored)
	assert_eq(restored.hotbar, [
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", GridWorld.FOOD_HOTBAR_ID,
	])
	session.restore(restored, 318, 1)
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hotbar, [
		&"", &"", &"", &"", &"", &"", &"", &"", &"", &"",
		&"", &"", &"", &"", &"", &"", &"", &"", &"", GridWorld.FOOD_HOTBAR_ID,
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
	world.hero.level = 5
	world.hero.copper = 10000
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


func test_spawn_food_shortcut_survives_save_and_refills_on_death() -> void:
	var session := GameSession.new()
	session.new_game(317)
	var world := session.world
	world.stalker_schedule = false
	world.hero.health = 1
	assert_eq(world.hotbar[19], GridWorld.FOOD_HOTBAR_ID)
	assert_eq(world.hero.inventory[0], ItemData.instance(117, 5))
	assert_true(world.consume_hotbar_food())
	assert_eq(world.hero.inventory[0].quantity, 4)
	assert_eq(world.turn_count, 1)
	world.wait_turn()
	assert_gt(int(world.hero.restoration.food.delivered), 0)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hero.restoration, world.hero.restoration)
	assert_eq(restored.hotbar[19], GridWorld.FOOD_HOTBAR_ID)
	# A revision-28 save from before food shortcuts still gets the default next Loop.
	restored.hotbar[19] = &""
	session.restore(restored, session.seed_value, 1)
	assert_true(restored.move_player(Vector2i.DOWN))
	assert_true(restored.hero.restoration.is_empty())
	restored.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.hero.inventory[0], ItemData.instance(117, 5))
	assert_true(session.world.hero.restoration.is_empty())
	assert_eq(session.world.hotbar[19], GridWorld.FOOD_HOTBAR_ID)


func test_food_shortcut_rejects_empty_bags_and_combat_without_spending_a_turn() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	assert_false(world.consume_hotbar_food())
	assert_eq(world.turn_count, 0)
	world.hero.inventory[7] = ItemData.instance(117)
	var enemy := GridActor.new(Vector2i(6, 5))
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	world.actors.append(enemy)
	assert_false(world.consume_hotbar_food())
	assert_eq(world.hero.inventory[7], ItemData.instance(117))
	assert_eq(world.turn_count, 0)


func test_judgement_hotbar_requires_learned_seal_and_stays_available_without_refresh() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)
	world.hero.learn_skill(SkillDefinition.catalog(&"judgement_1"))
	world.hero.rage = 100
	world.assign_hotbar(0, &"judgement_1")
	var panel := HotbarPanel.new()
	add_child_autofree(panel)
	var options := GlobalOptions.new()
	panel.refresh(world, options, true, true, false)
	assert_eq(panel.slots[0].get_theme_color("font_color"), HotbarPanel.INSUFFICIENT_RAGE_COLOR)
	world.hero.learn_skill(SkillDefinition.catalog(&"seal_of_command_1"))
	panel.refresh(world, options, true, true, false)
	assert_false(panel.slots[0].has_theme_color_override("font_color"))
	world.wait_turn()
	panel.refresh(world, options, true, true, false)
	assert_false(panel.slots[0].has_theme_color_override("font_color"))
