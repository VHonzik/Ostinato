extends GutTest


func _world(category: StringName = &"Warrior") -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 16, 16), Vector2i(5, 5), 97, false)
	world.hero.selected_class = category
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(6, 5)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.max_health = 10000
	enemy.health = enemy.max_health
	enemy.awards_experience = false
	enemy.stunned_until = 999
	enemy.melee.armor = 0
	enemy.melee.dodge = 0.0
	world.actors.append(enemy)
	return enemy


func test_retained_direct_and_area_attacks_award_neither_class_xp_track() -> void:
	var world := _world(&"Shaman")
	var enemy := _enemy(world)
	world.hero.rage = 100
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_true(world.cast_skill(&"whirlwind_1"))
	while world.pending_melee != null:
		world.continue_melee()
	assert_lt(enemy.health, enemy.max_health, "Retained attacks still work.")
	assert_eq(world.hero.progression_points(&"Warrior"), 0)
	assert_eq(world.hero.progression_points(&"Shaman"), 0)


func test_selected_class_counts_misses_but_rejected_and_cancelled_uses_award_none() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.melee.hit = -1000.0
	world.hero.rage = 100
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(world.hero.warrior_progress, 1)
	assert_false(world.cast_skill(&"mortal_strike_1", enemy), "Cooldown rejects the use.")
	assert_eq(world.hero.warrior_progress, 1)
	var whirlwind := world.hero.find_skill(&"whirlwind_1")
	whirlwind.cast_seconds = 2.0
	assert_true(world.cast_skill(whirlwind.id))
	world.cancel_cast()
	assert_eq(world.hero.warrior_progress, 1, "Cancelled cast is not a use.")
	whirlwind.cast_seconds = 1.0
	assert_true(world.cast_skill(whirlwind.id))
	assert_eq(world.hero.warrior_progress, 2, "A resolved miss counts once.")
	assert_eq(enemy.health, enemy.max_health)


func test_selected_class_counts_repeated_buffs_and_learning_keeps_cumulative_xp() -> void:
	var world := _world()
	world.add_class_progress(&"Warrior", 40)
	assert_true(world.train(&"Warrior", &"battle_shout_1"))
	assert_true(world.train(&"Warrior", &"anger_management_1"))
	assert_eq(world.hero.warrior_progress, 40)
	assert_true(world.cast_skill(&"battle_shout_1"), "Unlock is usable immediately.")
	for turn in range(30):
		world.wait_turn()
	assert_true(world.hero.buffs.has(&"battle_shout_1"), "Shout outlasts its cooldown.")
	assert_true(world.cast_skill(&"battle_shout_1"), "Repeated buff uses count.")
	assert_eq(world.hero.warrior_progress, 42)
	world.hero.selected_class = &"Shaman"
	for turn in range(30):
		world.wait_turn()
	assert_true(world.cast_skill(&"battle_shout_1"))
	assert_eq(world.hero.warrior_progress, 42)
	assert_eq(world.hero.progression_points(&"Shaman"), 0)


func _marshal(game: GameSession) -> GridActor:
	for actor in game.world.actors:
		if actor.npc_id == 197:
			return actor
	return null


func _returning_game() -> GameSession:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
	return game


func _learn_starters(world: GridWorld, category: StringName) -> void:
	for skill in SkillDefinition.starting_skills(category):
		world.hero.learn_skill(skill)


func test_first_loop_requires_warrior_and_selection_leaves_new_starters_for_training() -> void:
	for category: StringName in [&"Shaman", &"Paladin", &"Rogue"]:
		var game := GameSession.new()
		game.development_build = false
		game.new_game(97)
		game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
		assert_false(game.select_class(category, _marshal(game)))
		assert_eq(game.world.hero.selected_class, &"Warrior")
		game.world.hero.health = 0
		assert_true(game.restart_after_death())
		game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
		var equipment := game.world.hero.equipment.duplicate(true)
		assert_true(game.select_class(category, _marshal(game)))
		assert_eq(game.world.hero.selected_class, category)
		assert_eq(game.world.hero.equipment, equipment, "Choice does not exchange gear.")
		assert_eq(game.world.hero.learned_skills.size(), 2, "The marshal teaches no skills.")
		assert_eq(game.world.turn_count, 0)
		for skill in SkillDefinition.starting_skills(category):
			assert_null(game.world.hero.find_skill(skill.id))
			assert_eq(skill.resource_name(), "rage")
			assert_true(game.world.train(category, skill.id))
			assert_not_null(game.world.hero.find_skill(skill.id))
		assert_eq(game.world.hero.learned_skills.size(), 4)
		assert_eq(game.world.hero.copper, 0)
		assert_eq(game.world.hero.progression_points(category), 0)
		assert_null(game.world.hero.find_skill(&"holy_light_1"))
		assert_null(game.world.hero.find_skill(&"lightning_bolt_1"))
		assert_eq(game.world.hotbar.slice(0, 2), [&"mortal_strike_1", &"whirlwind_1"])
		assert_false(game.select_class(&"Warrior", _marshal(game)), "Only one choice per Loop.")


func test_choice_revalidates_range_combat_and_quest_cutoff_without_mutation() -> void:
	var game := _returning_game()
	var marshal := _marshal(game)
	game.world.player_tile += Vector2i.DOWN * 3
	assert_false(game.select_class(&"Rogue", marshal))
	game.world.player_tile = marshal.tile + Vector2i.DOWN
	assert_false(game.select_class(&"Mage", marshal))
	var enemy := _enemy(game.world, game.world.player_tile + Vector2i.RIGHT)
	enemy.engaged = true
	assert_false(game.select_class(&"Rogue", marshal))
	enemy.engaged = false
	assert_true(QuestRules.accept(game.world, "valley_patrol", marshal))
	assert_true(QuestRules.abandon(game.world, "valley_patrol"))
	assert_false(game.select_class(&"Rogue", marshal), "Abandoning does not reopen the choice.")
	assert_eq(game.world.hero.selected_class, &"Warrior")
	assert_null(game.world.hero.find_skill(&"relentless_assault_1"))
	assert_eq(game.world.turn_count, 0)


func test_same_class_confirmation_locks_choice_and_full_hotbar_keeps_new_skills_usable() -> void:
	var game := _returning_game()
	assert_true(game.select_class(&"Warrior", _marshal(game)))
	assert_false(game.can_select_class())
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
	game.world.hotbar.fill(&"mortal_strike_1")
	game.world.hotbar_locked = true
	game.world.hero.inventory.fill(ItemData.instance(35))
	var inventory := game.world.hero.inventory.duplicate(true)
	assert_true(game.select_class(&"Shaman", _marshal(game)))
	assert_true(game.world.train(&"Shaman", &"lightning_shield_1"))
	assert_eq(game.world.hotbar.count(&"mortal_strike_1"), GridWorld.HOTBAR_SIZE)
	assert_eq(game.world.hero.inventory, inventory)
	game.world.hero.rage = 100
	assert_true(game.world.cast_skill(&"lightning_shield_1"))
	assert_true(game.world.hotbar_locked)


func test_trainer_exposes_only_runnable_skills_and_cannot_teach_legacy_mana_kit() -> void:
	for category: StringName in [&"Shaman", &"Paladin", &"Rogue"]:
		var skills := SkillDefinition.trainer_skills(category)
		assert_gt(skills.size(), 2, "The complete class kits extend the starters.")
		for skill in skills:
			assert_true(ClassSkillData.is_playable_skill(skill.id))
	var world := _world(&"Paladin")
	world.hero.level = 10
	world.hero.copper = 100000
	assert_false(world.train(&"Paladin", &"holy_light_1"))
	world.hero.selected_class = &"Shaman"
	assert_false(world.train(&"Shaman", &"lightning_bolt_1"))
	assert_null(world.hero.find_skill(&"holy_light_1"))
	assert_null(world.hero.find_skill(&"lightning_bolt_1"))


func test_lightning_shield_counts_reapplications_but_discharges_grant_no_xp_or_points() -> void:
	var world := _world(&"Shaman")
	_learn_starters(world, &"Shaman")
	_learn_starters(world, &"Rogue")
	world.hero.rage = 100
	assert_true(world.cast_skill(&"lightning_shield_1"))
	assert_true(world.cast_skill(&"lightning_shield_1"))
	assert_eq(world.hero.progression_points(&"Shaman"), 2)
	var enemy := _enemy(world)
	ClassSpellEffects.retaliate(world, enemy, null, 1)
	assert_lt(enemy.health, enemy.max_health)
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 2)
	var health := enemy.health
	ClassSpellEffects.retaliate(world, enemy, null, 1)
	assert_eq(enemy.health, health, "Discharge cooldown prevents a second proc.")
	assert_eq(world.hero.progression_points(&"Shaman"), 2)
	assert_eq(world.hero.combo_points, 0)


func test_totem_replacement_range_expiry_and_failed_placement_keep_resources_and_xp() -> void:
	var world := _world(&"Shaman")
	_learn_starters(world, &"Shaman")
	world.hero.rage = 100
	var strength := world.hero.strength
	assert_true(world.cast_skill(&"strength_of_earth_totem_1"))
	var first := SummonRules.active(world, "earth")
	assert_eq(world.hero.strength, strength + 5)
	assert_true(world.cast_skill(&"strength_of_earth_totem_1"))
	assert_false(first.alive)
	var second := SummonRules.active(world, "earth")
	world.player_tile = Vector2i(14, 14)
	SummonRules.refresh_auras(world)
	assert_eq(world.hero.strength, strength)
	for direction in GridWorld.DIRECTIONS:
		world.blocked_tiles[world.player_tile + direction] = true
	var rage := world.hero.rage
	var turn := world.turn_count
	assert_false(world.cast_skill(&"strength_of_earth_totem_1"))
	assert_eq(world.hero.rage, rage)
	assert_eq(world.turn_count, turn)
	assert_eq(world.hero.progression_points(&"Shaman"), 2)
	assert_same(SummonRules.active(world, "earth"), second)
	world.turn_count = second.expires_turn - 1
	world.wait_turn()
	assert_null(SummonRules.active(world, "earth"))


func test_combo_points_require_passive_persist_between_targets_and_cap_without_proc_credit() -> void:
	var world := _world(&"Rogue")
	_learn_starters(world, &"Rogue")
	_learn_starters(world, &"Paladin")
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(5, 6))
	world.hero.melee.hit = 100.0
	world.hero.rage = 100
	assert_true(world.request_melee(first))
	assert_eq(world.hero.combo_points, 1, "Ordinary main-hand hits build points.")
	assert_true(world.cast_skill(&"seal_of_command_1"))
	assert_eq(world.hero.combo_points, 1, "Buff and its swing proc do not build points.")
	world.hero.rage = 100
	assert_true(world.cast_skill(&"mortal_strike_1", first))
	assert_eq(world.hero.combo_points, 2)
	world.hero.rage = 100
	world.hero.swing.remaining = 0.0
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.hero.combo_points, 3, "Area hits share one base point, across targets.")
	world.cancel_melee()
	first.engaged = false
	second.engaged = false
	world.wait_turn()
	assert_eq(world.hero.combo_points, 3, "Points persist outside combat.")
	for use in range(5):
		world.hero.rage = 100
		world.hero.swing.remaining = 0.0
		assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.hero.combo_points, HeroState.MAX_COMBO_POINTS)
	assert_eq(world.hero.progression_points(&"Rogue"), 0, "Retained attacks do not advance Rogue.")
	assert_eq(world.hero.warrior_progress, 0)
	assert_eq(world.hero.progression_points(&"Paladin"), 0)


func test_slice_and_dice_requires_points_spends_all_and_leaves_ability_cooldowns_unchanged() -> void:
	var world := _world(&"Rogue")
	_learn_starters(world, &"Rogue")
	world.hero.rage = 100
	assert_false(world.cast_skill(&"slice_and_dice_1"))
	assert_eq(world.hero.rage, 100)
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.progression_points(&"Rogue"), 0)
	assert_false(world.cast_skill(&"relentless_assault_1"), "Passive is always active, never cast.")
	world.hero.combo_points = 2
	world.hero.cooldowns["mortal_strike"] = 10
	assert_true(world.cast_skill(&"slice_and_dice_1"))
	assert_eq(world.hero.combo_points, 0)
	assert_almost_eq(world.hero.attack_haste(), 1.3, 0.00001)
	assert_eq(int(world.hero.buffs[&"slice_and_dice_1"].until) - world.turn_count, 11)
	assert_eq(int(world.hero.cooldowns.mortal_strike), 10)
	assert_eq(world.hero.progression_points(&"Rogue"), 1)
	world.hero.combo_points = 1
	world.hero.rage = 0
	assert_false(world.cast_skill(&"slice_and_dice_1"))
	assert_eq(world.hero.combo_points, 1, "Failed cast keeps points.")
	world.hero.buffs[&"slice_and_dice_1"].until = world.turn_count + 1
	world.wait_turn()
	assert_almost_eq(world.hero.attack_haste(), 1.0, 0.00001)


func test_judgement_hits_and_misses_keep_seal_and_only_hits_build_points() -> void:
	var world := _world(&"Paladin")
	_learn_starters(world, &"Paladin")
	_learn_starters(world, &"Rogue")
	var enemy := _enemy(world, Vector2i(7, 5))
	world.hero.rage = 100
	assert_false(world.cast_skill(&"judgement_1", enemy), "Requires the seal.")
	assert_eq(world.turn_count, 0)
	assert_true(world.cast_skill(&"seal_of_command_1"))
	world.hero.melee.hit = -1000.0
	assert_true(world.cast_skill(&"judgement_1", enemy))
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(world.hero.combo_points, 0)
	assert_true(world.hero.buffs.has(&"seal_of_command_1"))
	assert_eq(world.hero.progression_points(&"Paladin"), 2, "A miss counts as a use.")
	for turn in range(6):
		world.wait_turn()
	world.hero.melee.hit = 100.0
	world.hero.rage = 100
	assert_true(world.cast_skill(&"judgement_1", enemy))
	assert_lt(enemy.health, enemy.max_health)
	assert_eq(world.hero.combo_points, 1)
	assert_true(world.hero.buffs.has(&"seal_of_command_1"))
	assert_eq(world.hero.progression_points(&"Paladin"), 3)
	assert_eq(world.hero.progression_points(&"Rogue"), 0)


func test_learning_class_xp_and_previous_class_survive_death_while_combat_state_resets() -> void:
	var game := _returning_game()
	game.world.add_class_progress(&"Warrior", 40)
	assert_true(game.world.train(&"Warrior", &"anger_management_1"))
	for category: StringName in [&"Shaman", &"Paladin", &"Rogue"]:
		assert_true(game.select_class(category, _marshal(game)))
		for skill in SkillDefinition.starting_skills(category):
			assert_true(game.world.train(category, skill.id))
		game.world.add_class_progress(category, 7)
		game.world.hero.rage = 100
		game.world.hero.combo_points = 2 if category == &"Rogue" else 0
		game.world.hero.cooldowns["mortal_strike"] = 99
		var learned := game.world.hero.learned_skills.duplicate()
		game.world.hero.health = 0
		assert_true(game.restart_after_death())
		assert_eq(game.world.hero.selected_class, category)
		assert_eq(game.world.hero.learned_skills, learned)
		assert_eq(game.world.hero.progression_points(category), 7)
		assert_eq([game.world.hero.rage, game.world.hero.combo_points], [0, 0])
		assert_eq(game.world.hero.cooldowns, {})
		assert_eq(game.world.hero.buffs, {})
		assert_eq([game.world.hero.level, game.world.hero.experience, game.world.hero.copper], [1, 0, 0])
		assert_true(game.can_select_class())
		game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
	assert_not_null(game.world.hero.find_skill(&"anger_management_1"))
	game.world.hero.rage = 10
	game.world.wait_turn()
	assert_eq(game.world.hero.rage, 10, "Retained Warrior passive works while Rogue is selected.")
	game.world.wait_turn()
	assert_eq(game.world.hero.rage, 9)


func test_mixed_class_save_roundtrip_preserves_choice_xp_combo_points_and_buff_timing() -> void:
	var game := _returning_game()
	for category: StringName in [&"Shaman", &"Paladin", &"Rogue"]:
		assert_true(game.select_class(category, _marshal(game)))
		for skill in SkillDefinition.starting_skills(category):
			assert_true(game.world.train(category, skill.id))
		if category != &"Rogue":
			game.world.hero.health = 0
			assert_true(game.restart_after_death())
			game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
	game.world.hero.rage = 100
	assert_true(game.world.cast_skill(&"strength_of_earth_totem_1"))
	assert_true(game.world.cast_skill(&"lightning_shield_1"))
	assert_true(game.world.cast_skill(&"seal_of_command_1"))
	game.world.hero.combo_points = 3
	assert_true(game.world.cast_skill(&"slice_and_dice_1"))
	game.world.hero.combo_points = 2
	assert_true(game.world.can_save())
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	var copy := GameSession.new()
	copy.development_build = false
	copy.restore(restored, game.seed_value, game.loop_count)
	assert_eq(SaveCodec.capture(copy), snapshot)
	assert_false(copy.can_select_class(), "Confirmed choice stays locked after load.")
	assert_eq(copy.world.hero.combo_points, 2)
	assert_eq(copy.world.hero.progression_points(&"Rogue"), 1)
	assert_almost_eq(copy.world.hero.attack_haste(), 1.3, 0.00001)
	for turn in range(15):
		game.world.wait_turn()
		copy.world.wait_turn()
	assert_eq(SaveCodec.capture(copy), SaveCodec.capture(game))
	for invalid_points: Variant in [-1, 6, 1.5, "2"]:
		var invalid := snapshot.duplicate(true)
		invalid.hero.combo_points = invalid_points
		assert_null(SaveCodec.restore(invalid, false))
	var missing_passive := snapshot.duplicate(true)
	missing_passive.learned.erase("relentless_assault_1")
	assert_null(SaveCodec.restore(missing_passive, false))


func test_save_before_marshal_choice_reopens_it_and_new_game_clears_retained_learning() -> void:
	var game := _returning_game()
	assert_true(game.select_class(&"Rogue", _marshal(game)))
	assert_true(game.world.train(&"Rogue", &"relentless_assault_1"))
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(snapshot, false)
	assert_not_null(restored)
	if restored == null:
		return
	var copy := GameSession.new()
	copy.development_build = false
	copy.restore(restored, game.seed_value, game.loop_count)
	assert_true(copy.can_select_class())
	assert_eq(copy.world.hero.selected_class, &"Rogue")
	copy.new_game(12)
	assert_eq(copy.world.hero.selected_class, &"Warrior")
	assert_eq(copy.world.hero.learned_skills.size(), 2)
	assert_eq(copy.world.hero.class_progress, {})
	assert_null(copy.world.hero.find_skill(&"relentless_assault_1"))


func _menu(game: GameSession) -> MenuPanel:
	var menu := MenuPanel.new()
	menu.session = game
	menu.active_game = true
	add_child_autofree(menu)
	return menu


func _key(key: Key) -> InputEventKey:
	var event := GlobalOptions.key_event(key)
	event.keycode = event.physical_keycode
	event.pressed = true
	return event


func _class_choice(menu: MenuPanel, category: StringName) -> Button:
	var title := "Uhm... I seek %s teaching" % String(category).to_lower()
	for button in menu._buttons:
		if button.text == title:
			return button
	return null


func test_marshal_dialogue_offers_each_class_directly_and_confirmation_locks_all_choices() -> void:
	for category: StringName in ClassSkillData.PLAYABLE_CLASSES:
		var game := _returning_game()
		var menu := _menu(game)
		var marshal := _marshal(game)
		menu.open_conversation(marshal)
		assert_false(menu._buttons.any(func(button: Button) -> bool:
			return button.text == "Choose my class for this Loop"))
		for offered: StringName in ClassSkillData.PLAYABLE_CLASSES:
			assert_not_null(_class_choice(menu, offered))
		var choice := _class_choice(menu, category)
		if choice == null:
			continue
		choice.pressed.emit()
		assert_eq(menu.page, "confirm")
		menu.handle_key(_key(KEY_ENTER))
		assert_eq(game.world.hero.selected_class, category)
		assert_true(game.world.class_selected)
		assert_true(game.world.trainer_referral_received)
		assert_eq(game.world.turn_count, 0)
		menu.open_conversation(marshal)
		for offered: StringName in ClassSkillData.PLAYABLE_CLASSES:
			assert_null(_class_choice(menu, offered), "The confirmed choice stays locked.")


func test_marshal_keyboard_choice_focus_cancel_and_confirmation_spend_no_turns() -> void:
	var game := _returning_game()
	var menu := _menu(game)
	menu.open_conversation(_marshal(game))
	await get_tree().process_frame
	assert_eq(menu.page, "conversation")
	_class_choice(menu, &"Warrior").grab_focus()
	menu.handle_key(_key(KEY_S))
	assert_same(get_viewport().gui_get_focus_owner(), _class_choice(menu, &"Shaman"))
	menu.handle_key(_key(KEY_ENTER))
	assert_eq(menu.page, "confirm")
	menu.handle_key(_key(KEY_ESCAPE))
	assert_eq(menu.page, "conversation")
	assert_eq(game.world.hero.selected_class, &"Warrior")
	assert_true(game.can_select_class())
	_class_choice(menu, &"Warrior").grab_focus()
	menu.handle_key(_key(KEY_S))
	menu.handle_key(_key(KEY_ENTER))
	menu.handle_key(_key(KEY_ENTER))
	assert_true(menu.visible)
	assert_eq(menu.page, "class_referral")
	assert_string_contains((menu._rows.get_child(1) as Label).text, "Farseer Lopaa")
	assert_null(game.world.hero.find_skill(&"lightning_shield_1"))
	assert_eq(game.world.hero.selected_class, &"Shaman")
	assert_eq(game.world.turn_count, 0)
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
	menu.open_conversation(_marshal(game))
	assert_not_null(_class_choice(menu, &"Shaman"), "Death restores the dialogue choices.")


func test_stale_class_confirmation_cannot_bypass_quest_lock_or_grant_starters() -> void:
	var game := _returning_game()
	var menu := _menu(game)
	menu.open_conversation(_marshal(game))
	menu._confirm_class(&"Paladin", _marshal(game))
	assert_true(QuestRules.accept(game.world, "valley_patrol", _marshal(game)))
	menu.handle_key(_key(KEY_ENTER))
	assert_eq(menu.page, "notice")
	assert_eq(game.world.hero.selected_class, &"Warrior")
	assert_null(game.world.hero.find_skill(&"seal_of_command_1"))
	assert_false(game.can_select_class())
	assert_eq(game.world.turn_count, 0)


func test_misses_do_not_build_combo_points_and_retained_passive_works_as_warrior() -> void:
	var world := _world()
	_learn_starters(world, &"Rogue")
	var enemy := _enemy(world)
	world.hero.rage = 100
	world.hero.melee.hit = -1000.0
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(world.hero.combo_points, 0)
	world.hero.swing.remaining = 0.0
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.hero.combo_points, 0)
	world.hero.melee.hit = 100.0
	world.hero.rage = 100
	world.hero.swing.remaining = 0.0
	assert_true(world.cast_skill(&"whirlwind_1"))
	assert_eq(world.hero.combo_points, 1)
	assert_eq(world.hero.warrior_progress, 3)
	assert_eq(world.hero.progression_points(&"Rogue"), 0)
	assert_true(world.cast_skill(&"slice_and_dice_1"))
	assert_eq(world.hero.combo_points, 0)
	assert_eq(world.hero.progression_points(&"Rogue"), 0)
	assert_eq(world.hero.warrior_progress, 3)


func test_save_rejects_first_loop_other_class_and_legacy_kit_in_runnable_game() -> void:
	var game := _returning_game()
	assert_true(game.select_class(&"Paladin", _marshal(game)))
	var snapshot := SaveCodec.capture(game)
	var first_loop := snapshot.duplicate(true)
	first_loop.loop = 1
	assert_null(SaveCodec.restore(first_loop, false))
	var legacy := snapshot.duplicate(true)
	legacy.learned.append("holy_light_1")
	assert_null(SaveCodec.restore(legacy, false))


func test_seal_bonus_on_landed_swings_grants_no_extra_rage_xp_or_combo_points() -> void:
	var world := _world(&"Paladin")
	_learn_starters(world, &"Paladin")
	_learn_starters(world, &"Rogue")
	world.hero.rage = 100
	assert_true(world.cast_skill(&"seal_of_command_1"))
	var enemy := _enemy(world)
	enemy.facing = Vector2i.LEFT
	world.hero.melee.hit = 100.0
	world.hero.melee.interval = 2.0
	world.hero.melee.damage_min = 10.0
	world.hero.melee.damage_max = 10.0
	world.hero.melee.critical = 0.0
	world.hero.rage = 0
	assert_true(world.request_melee(enemy))
	assert_lt(enemy.health, enemy.max_health, "Landed swings trigger the Holy bonus.")
	assert_eq(world.hero.rage, 14, "Only the ordinary swing supplies rage.")
	assert_eq(world.hero.combo_points, 1, "Only the ordinary main-hand hit supplies a point.")
	assert_eq(world.hero.progression_points(&"Paladin"), 1, "Only casting the seal supplied class XP.")
	world.hero.melee.hit = -1000.0
	var health := enemy.health
	world.hero.swing.remaining = 0.0
	assert_true(world.request_melee(enemy))
	assert_eq(enemy.health, health, "Missed swings cannot trigger the Holy bonus.")


func test_class_selection_blocks_saving_until_locked_and_then_saves_without_new_starters() -> void:
	var game := _returning_game()
	var observations: Array[bool] = []
	var observer := func(_message: String) -> void: observations.append(game.world.can_save())
	game.world.message_added.connect(observer)
	assert_true(game.select_class(&"Shaman", _marshal(game)))
	game.world.message_added.disconnect(observer)
	assert_false(observations.is_empty())
	assert_false(observations.has(true), "No save can capture a partially applied class choice.")
	assert_true(game.world.can_save())
	assert_eq(game.world.turn_count, 0)
	assert_null(game.world.hero.find_skill(&"lightning_shield_1"))
	assert_not_null(SaveCodec.restore(SaveCodec.capture(game), false))


func test_judgement_retargets_without_banking_swings_or_attacking_the_previous_enemy() -> void:
	var world := _world(&"Paladin")
	_learn_starters(world, &"Paladin")
	world.hero.rage = 100
	assert_true(world.cast_skill(&"seal_of_command_1"))
	var previous := _enemy(world, Vector2i(5, 6))
	var chosen := _enemy(world, Vector2i(7, 5))
	world.hero.melee.hit = 100.0
	assert_true(world.request_melee(previous))
	var health := previous.health
	world.hero.swing.remaining = 1.0
	world.hero.rage = 100
	assert_true(world.cast_skill(&"judgement_1", chosen))
	assert_same(world.auto_attack_target, chosen)
	assert_same(world.last_attacked_enemy, chosen)
	assert_eq(previous.health, health, "The previous target receives no due swing.")
	assert_eq(world.hero.swing.remaining, 0.0, "Out-of-range time advances without banking attacks.")


func test_save_load_and_death_before_training_keep_the_choice_without_granting_skills() -> void:
	var game := _returning_game()
	assert_true(game.select_class(&"Paladin", _marshal(game)))
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), false)
	assert_not_null(restored)
	if restored == null:
		return
	game.restore(restored, game.seed_value, game.loop_count)
	assert_false(game.can_select_class())
	assert_null(game.world.hero.find_skill(&"seal_of_command_1"))
	assert_null(game.world.hero.find_skill(&"judgement_1"))
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.selected_class, &"Paladin")
	assert_true(game.can_select_class())
	assert_null(game.world.hero.find_skill(&"seal_of_command_1"))
	assert_false(game.world.train(&"Shaman", &"lightning_shield_1"))
	assert_true(game.world.train(&"Paladin", &"seal_of_command_1"))
	assert_eq(game.world.hotbar[10], &"seal_of_command_1")
	assert_false(game.world.train(&"Paladin", &"seal_of_command_1"), "Already learned.")
	assert_eq(game.world.hotbar.count(&"seal_of_command_1"), 1)
	var partial := SaveCodec.restore(SaveCodec.capture(game), false)
	assert_not_null(partial)
	if partial == null:
		return
	game.restore(partial, game.seed_value, game.loop_count)
	assert_not_null(game.world.hero.find_skill(&"seal_of_command_1"))
	assert_null(game.world.hero.find_skill(&"judgement_1"))
	assert_true(game.world.train(&"Paladin", &"judgement_1"))
	assert_eq(game.world.hotbar[2], &"judgement_1")
	game.world.hero.rage = 100
	assert_true(game.world.cast_skill(&"seal_of_command_1"), "Learning is usable immediately.")
	assert_eq(game.world.hero.progression_points(&"Paladin"), 1)
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	game.world.player_tile = _marshal(game).tile + Vector2i.DOWN
	assert_true(game.select_class(&"Warrior", _marshal(game)))
	game.world.hero.rage = 100
	assert_true(game.world.cast_skill(&"seal_of_command_1"), "Retained starter needs no relearning.")
	assert_eq(game.world.hero.progression_points(&"Paladin"), 1)
	assert_eq(game.world.hero.warrior_progress, 0)


func test_matching_trainer_menu_teaches_both_starters_free_and_assigns_only_actives() -> void:
	var game := _returning_game()
	assert_true(game.select_class(&"Rogue", _marshal(game)))
	var menu := _menu(game)
	var trainer: GridActor
	for actor in game.world.actors:
		if actor.service == &"Rogue":
			trainer = actor
	assert_not_null(trainer)
	if trainer == null:
		return
	game.world.player_tile = trainer.tile + Vector2i.DOWN
	menu.open_conversation(trainer)
	var train: Button
	for button in menu._buttons:
		if button.text == "Train":
			train = button
	assert_not_null(train)
	if train == null:
		return
	train.pressed.emit()
	assert_eq(menu.page, "trainer")
	for skill in SkillDefinition.starting_skills(&"Rogue"):
		var learn: Button
		for button in menu._buttons:
			if button.text.begins_with(skill.title + " / Free"):
				learn = button
		assert_not_null(learn)
		if learn != null:
			assert_false(learn.disabled)
			learn.pressed.emit()
			assert_not_null(game.world.hero.find_skill(skill.id))
	assert_eq(game.world.hotbar[2], &"slice_and_dice_1")
	assert_false(game.world.hotbar.has(&"relentless_assault_1"))
	assert_eq(game.world.hero.copper, 0)
	assert_eq(game.world.hero.progression_points(&"Rogue"), 0)
	assert_eq(game.world.turn_count, 0)
