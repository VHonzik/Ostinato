extends GutTest


func test_death_rebuilds_world_and_preserves_only_game_progression() -> void:
	var game := GameSession.new()
	game.new_game(17)
	game.world.hero.add_experience(400)
	var learned := SkillRank.new(&"retained_test", "Retained", &"Druid", 2, 2,
		"Test rank", SkillRank.Effect.PRACTICE)
	assert_true(game.world.hero.learn_skill(learned))
	game.world.hotbar[0] = learned.id
	game.world.hotbar_locked = true
	game.world.movement_credit = 0.75
	game.world.hero.copper = 100
	game.world.hero.buffs[&"frost_armor_1"] = {"armor": 30, "until": 100}
	game.world.ever_accepted_quest = true
	game.world.actors[5].alive = false
	var old := game.world
	assert_true(old.cast_skill(&"death_1"))
	assert_true(game.restart_after_death())
	assert_eq(game.seed_value, 17)
	assert_eq(game.loop_count, 2)
	assert_eq([game.world.hero.level, game.world.hero.experience], [1, 0])
	assert_eq([game.world.hero.health, game.world.hero.mana], [51, 165])
	assert_eq(game.world.hero.selected_class, &"Mage")
	assert_eq(game.world.hero.copper, 0)
	assert_eq(game.world.hero.buffs, {})
	assert_eq(game.world.movement_credit, 0.0)
	assert_eq(game.world.hero.casting_credit, 0.0)
	assert_true(game.world.actors[5].alive)
	assert_false(game.world.ever_accepted_quest)
	assert_same(game.world.hero.find_skill(learned.id), learned)
	assert_eq(game.world.hotbar[0], learned.id)
	assert_true(game.world.hotbar_locked)
	assert_true(game.world.cast_skill(learned.id))
	assert_false(game.restart_after_death(), "One death creates exactly one Loop.")
	old.wait_turn()
	old.continue_cast()
	old.continue_melee()
	assert_eq(game.world.turn_count, 1, "Abandoned references cannot advance the new world.")


func test_new_game_clears_learning_hotbar_and_class_and_uses_requested_seed() -> void:
	var game := GameSession.new()
	game.new_game(19)
	game.world.hero.health = 0
	game.restart_after_death()
	assert_true(game.select_class(&"Druid"))
	assert_null(game.world.hero.find_skill(&"wrath_1"))
	assert_true(game.world.train(&"Druid", &"wrath_1"))
	game.world.hotbar[0] = &"wrath_1"
	game.new_game(29)
	assert_eq(game.seed_value, 29)
	assert_eq(game.loop_count, 1)
	assert_null(game.world.hero.find_skill(&"wrath_1"))
	assert_eq(game.world.hotbar, [&"", &"", &"", &"", &""])
	assert_eq(game.world.hero.selected_class, &"Mage")


func test_class_choice_is_once_per_eligible_loop_and_grants_no_skills_or_refill() -> void:
	var game := GameSession.new()
	game.new_game(3)
	assert_false(game.select_class(&"Druid"))
	game.world.hero.health = 0
	game.restart_after_death()
	game.world.hero.health = 12
	game.world.hero.mana = 41
	assert_true(game.select_class(&"Druid"))
	assert_eq([game.world.hero.health, game.world.hero.mana], [12, 41])
	assert_null(game.world.hero.find_skill(&"wrath_1"))
	assert_not_null(game.world.hero.find_skill(&"fireball_1"))
	assert_eq(game.world.hero.equipment.chest.id, 6123)
	assert_false(game.select_class(&"Mage"))
	assert_false(game.world.train(&"Mage", &"frost_armor_1"))
	assert_true(game.world.train(&"Druid", &"wrath_1"))
	assert_false(game.world.train(&"Druid", &"wrath_1"))
	assert_true(game.world.train(&"Druid", &"healing_touch_1"))
	assert_true(game.world.train(&"Druid", &"mark_1"))
	assert_eq(game.world.turn_count, 0)


func test_accepting_any_quest_or_leveling_closes_selection() -> void:
	var game := GameSession.new()
	game.new_game(3)
	game.world.hero.health = 0
	game.restart_after_death()
	game.world.ever_accepted_quest = true
	assert_false(game.can_select_class())
	game.world.hero.health = 0
	game.restart_after_death()
	assert_true(game.can_select_class())
	game.world.hero.add_experience(400)
	assert_false(game.can_select_class())


func test_outfit_exchange_preserves_acquired_gear_and_is_atomic_when_full() -> void:
	var hero := HeroState.new()
	hero.equipment.chest.starter = false
	for index in range(40):
		hero.inventory[index] = {"id": 35, "starter": false, "quantity": 1}
	var before := hero.equipment.duplicate(true)
	assert_false(StarterGear.exchange(hero, &"Druid"))
	assert_eq(hero.equipment, before)
	assert_eq(hero.selected_class, &"Mage")
	hero.inventory[7] = {}
	assert_true(StarterGear.exchange(hero, &"Druid"))
	assert_eq(hero.equipment.chest.id, 56)
	assert_false(hero.equipment.chest.starter)
	assert_eq(hero.inventory[7].id, 6123)


func test_shared_fractional_cast_credit_cancellation_and_completion_revalidation() -> void:
	var world := _spell_world()
	var enemy := world.actors[0]
	var skill := world.hero.find_skill(&"fireball_1")
	skill.cast_seconds = 1.4
	assert_true(world.cast_skill(skill.id, enemy))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.mana, 165)
	assert_eq(world.hero.casting_credit, 0.0)
	world.continue_cast()
	assert_eq(world.turn_count, 2)
	assert_almost_eq(world.hero.casting_credit, 0.6, 0.00001)
	assert_eq(world.hero.mana, 135)
	assert_true(world.cast_skill(skill.id, enemy))
	assert_eq(world.turn_count, 3)
	assert_almost_eq(world.hero.casting_credit, 0.2, 0.00001)
	assert_true(world.cast_skill(skill.id, enemy))
	world.cancel_cast()
	assert_eq(world.hero.mana, 105)
	assert_almost_eq(world.hero.casting_credit, 0.2, 0.00001)
	assert_true(world.cast_skill(skill.id, enemy))
	world.sight_blockers[Vector2i(3, 2)] = true
	world.continue_cast()
	assert_eq(world.hero.mana, 105)
	assert_almost_eq(world.hero.casting_credit, 0.2, 0.00001)
	assert_null(world.pending_skill)


func test_target_preconditions_reject_without_time_cost_and_neutral_engages_on_commit() -> void:
	var world := _spell_world()
	var enemy := world.actors[0]
	enemy.relationship = GridActor.Relationship.FRIENDLY
	assert_false(world.cast_skill(&"fireball_1", enemy))
	enemy.relationship = GridActor.Relationship.NEUTRAL
	world.hero.mana = 29
	assert_false(world.cast_skill(&"fireball_1", enemy))
	world.hero.mana = 165
	enemy.tile = Vector2i(15, 2)
	assert_false(world.cast_skill(&"fireball_1", enemy))
	assert_eq(world.turn_count, 0)
	enemy.tile = Vector2i(5, 2)
	assert_true(world.cast_skill(&"fireball_1", enemy))
	assert_true(enemy.engaged)
	assert_eq(enemy.relationship, GridActor.Relationship.HOSTILE)
	world.cancel_cast()
	assert_true(world.in_combat())


func test_armor_stacks_between_classes_refreshes_itself_and_expires_in_turn_time() -> void:
	var world := _spell_world()
	world.actors.clear()
	world.hero.learn_skill(SkillRank.catalog(&"mark_1"))
	assert_true(world.cast_skill(&"frost_armor_1"))
	assert_eq(world.hero.melee.armor, 75)
	assert_true(world.cast_skill(&"mark_1"))
	assert_eq(world.hero.melee.armor, 100)
	assert_true(world.cast_skill(&"mark_1"))
	assert_eq(world.hero.melee.armor, 100)
	world.hero.buffs[&"frost_armor_1"].until = world.turn_count + 1
	world.wait_turn()
	assert_eq(world.hero.melee.armor, 70)
	assert_true(world.hero.buffs.has(&"mark_1"))


func test_mana_five_second_rule_and_health_regeneration_use_shared_two_turn_ticks() -> void:
	var world := _spell_world()
	world.actors.clear()
	world.hero.health = 10
	assert_true(world.cast_skill(&"frost_armor_1"))
	assert_eq(world.hero.mana, 105)
	for count in range(4):
		world.wait_turn()
	assert_eq(world.turn_count, 5)
	assert_eq(world.hero.mana, 105)
	world.wait_turn()
	assert_eq(world.hero.mana, 123)
	assert_eq(world.hero.health, 28, "Three ticks of floor((22*0.11+1)*2)=6 health.")
	var enemy := GridActor.new(Vector2i(3, 2))
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.swing.remaining = 100
	world.actors.append(enemy)
	var before := world.hero.health
	world.wait_turn()
	world.wait_turn()
	assert_eq(world.hero.health, before, "No ordinary health regeneration during combat.")


func test_first_stalker_is_pending_when_blocked_and_schedule_resets_after_death() -> void:
	var game := GameSession.new()
	game.new_game(101)
	var blocker := GridActor.new(Vector2i(54, 14))
	game.world.actors.append(blocker)
	for index in range(15):
		game.world.wait_turn()
	assert_false(game.world.stalker_arrived)
	blocker.alive = false
	game.world.wait_turn()
	assert_true(game.world.stalker_arrived)
	var stalker := game.world.actors[-1]
	assert_eq(stalker.melee.level, 20)
	assert_eq(stalker.health, 494)
	assert_eq(stalker.tile, Vector2i(54, 14))
	for actor in game.world.actors:
		if actor.story_guard:
			assert_false(actor.alive)
			assert_true(actor.corpse_visible)
	var announced := 0
	for message in game.world.messages:
		if message.contains("A demon stalker"):
			announced += 1
	assert_eq(announced, 1)
	game.world.hero.health = 0
	game.restart_after_death()
	assert_false(game.world.stalker_arrived)
	assert_eq(game.world.turn_count, 0)


func test_retained_heal_and_damage_are_usable_after_returning_to_mage() -> void:
	var game := GameSession.new()
	game.new_game(31)
	game.world.hero.health = 0
	game.restart_after_death()
	game.select_class(&"Druid")
	game.world.train(&"Druid", &"healing_touch_1")
	game.world.train(&"Druid", &"wrath_1")
	game.world.hero.health = 0
	game.restart_after_death()
	game.world.actors.clear()
	game.world.hero.health = 1
	assert_true(game.world.cast_skill(&"healing_touch_1"))
	game.world.continue_cast()
	assert_gt(game.world.hero.health, 1)
	assert_eq(game.world.hero.mana, 140)
	assert_eq(game.world.hero.selected_class, &"Mage")


func _spell_world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(2, 2), 1)
	var enemy := GridActor.new(Vector2i(5, 2))
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.max_health = 1000
	enemy.health = 1000
	enemy.swing.remaining = 100.0
	world.actors.append(enemy)
	return world


func test_save_is_blocked_during_player_effects_before_the_shared_phase() -> void:
	var world := _spell_world()
	world.actors.clear()
	var observed: Array[bool] = []
	var observer := func(_message: String) -> void: observed.append(world.can_save())
	world.message_added.connect(observer)
	world.cast_skill(&"frost_armor_1")
	world.message_added.disconnect(observer)
	assert_eq(observed, [false], "A successful player effect is still inside its action.")
	assert_true(world.can_save())


func test_chill_slows_movement_with_fractional_remainder_and_applies_on_melee_contact() -> void:
	var world := _spell_world()
	var actor := world.actors[0]
	actor.engaged = true
	actor.chilled_until = 10
	world.wait_turn()
	assert_eq(actor.tile, Vector2i(5, 2))
	world.wait_turn()
	assert_eq(actor.tile, Vector2i(4, 2))
	assert_almost_eq(actor.movement_credit, 0.4, 0.000001)
	actor.chilled_until = 0
	world.wait_turn()
	assert_eq(actor.tile, Vector2i(3, 2))
	assert_almost_eq(actor.movement_credit, 0.4, 0.000001)
	world.hero.buffs[&"frost_armor_1"] = {"armor": 30, "until": 1800}
	world.hero.refresh_melee_stats()
	actor.swing.remaining = 0.0
	actor.swing._active = false
	actor.melee.level = 60
	actor.melee.damage_min = 1
	actor.melee.damage_max = 1
	actor.melee.critical = 0
	world.wait_turn()
	assert_eq(actor.chilled_until, world.turn_count + 5)


func test_ten_resets_restore_seeded_world_without_accumulating_actors_or_skills() -> void:
	var game := GameSession.new()
	game.new_game(97)
	var starting_count := game.world.actors.size()
	var skill_count := game.world.hero.learned_skills.size()
	var starting_random := game.world.random.state
	for count in range(10):
		game.world.cast_skill(&"death_1")
		assert_true(game.restart_after_death())
		assert_eq(game.loop_count, count + 2)
		assert_eq(game.world.actors.size(), starting_count)
		assert_eq(game.world.hero.learned_skills.size(), skill_count)
		assert_eq(game.world.random.state, starting_random)
		assert_eq(game.world.hero.health, 51)
		assert_null(game.world.pending_skill)
		assert_null(game.world.pending_melee)


func test_direct_and_periodic_kills_record_the_resolved_turn_for_corpse_expiry() -> void:
	for periodic in [false, true]:
		var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5))
		var target := GridActor.new(Vector2i(5, 6))
		target.health = 1
		target.relationship = GridActor.Relationship.NEUTRAL
		target.awards_experience = false
		world.actors.append(target)
		if periodic:
			world.periodic_effects.append({"actor": 0, "next": 1, "remaining": 1})
			world.wait_turn()
		else:
			world.hero.melee.damage_min = 100
			world.hero.melee.damage_max = 100
			world.hero.melee.level = 60
			world.combat_random.seed = 1
			assert_true(world.request_melee(target))
		assert_false(target.alive)
		assert_eq(target.died_on_turn, world.turn_count)
		for index in range(299):
			world.wait_turn()
		assert_true(target.corpse_visible)
		world.wait_turn()
		assert_false(target.corpse_visible)


func test_current_class_cannot_consume_the_marshal_choice_or_replace_items() -> void:
	var game := GameSession.new()
	game.new_game(11)
	game.world.hero.health = 0
	game.restart_after_death()
	var before := JSON.stringify(SaveCodec.capture(game))
	assert_false(game.select_class(&"Mage"))
	assert_eq(JSON.stringify(SaveCodec.capture(game)), before)
	assert_true(game.can_select_class())
	assert_true(game.select_class(&"Druid"))


func test_fireball_mana_is_checked_at_start_and_again_at_completion() -> void:
	var world := _spell_world()
	var target := world.actors[0]
	target.tile = world.player_tile + Vector2i.RIGHT
	var skill := world.hero.find_skill(&"fireball_1")
	world.hero.mana = 29
	assert_true(world.spell_candidates(skill).has(target), "Mana does not change target eligibility.")
	assert_false(world.cast_skill(skill.id, target))
	assert_string_contains(world.messages[-1], "Not enough mana for Fireball")
	assert_eq(world.turn_count, 0)
	assert_false(target.engaged)
	world.hero.mana = 30
	assert_true(world.cast_skill(skill.id, target))
	world.hero.mana = 29
	world.hero.last_mana_turn = world.turn_count
	assert_true(world.continue_cast())
	assert_eq(world.turn_count, 2, "Elapsed casting turns remain spent.")
	assert_eq(world.hero.mana, 29)
	assert_eq(world.hero.casting_credit, 0.0)
	assert_eq(target.health, target.max_health)
	assert_null(world.pending_skill)
	assert_true(world.periodic_effects.is_empty())
