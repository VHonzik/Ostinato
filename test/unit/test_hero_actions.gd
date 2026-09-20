extends GutTest


func test_dummy_casts_have_one_shared_phase_and_keep_movement_credit() -> void:
	for identifier: StringName in [&"practice_1", &"experience_1"]:
		var world := MovementFixture.create_world()
		var waiting := MovementFixture.create_world()
		world.movement_credit = 0.5
		var player_tile := world.player_tile
		assert_true(world.cast_skill(identifier))
		waiting.wait_turn()
		assert_eq(world.turn_count, 1)
		assert_eq(world.player_tile, player_tile)
		assert_eq(world.movement_credit, 0.5)
		assert_eq(world.random.state, waiting.random.state)
		for index in range(world.actors.size()):
			assert_eq(world.actors[index].tile, waiting.actors[index].tile)


func test_xp_cast_effect_precedes_npc_phase_and_reports_level() -> void:
	var world := MovementFixture.create_world()
	var observed_turns: Array[int] = []
	var observer := func(_message: String) -> void:
		observed_turns.append(world.turn_count)
	world.message_added.connect(observer)
	assert_true(world.cast_skill(&"experience_1"))
	assert_eq([world.hero.level, world.hero.experience], [2, 50])
	assert_eq(observed_turns, [0, 0], "Player effects finish before the shared phase.")
	world.message_added.disconnect(observer)
	assert_string_contains(world.messages[0], "450 XP")
	assert_string_contains(world.messages[1], "level 2")
	assert_eq(world.turn_count, 1)


func test_death_trigger_ends_attempt_and_discards_remaining_phase() -> void:
	var world := MovementFixture.create_world()
	world.move_player(Vector2i.LEFT)
	world.hero.add_experience(450)
	var tile_before := world.player_tile
	var random_before := world.random.state
	assert_true(world.cast_skill(&"death_1"))
	assert_eq([world.hero.level, world.hero.experience], [2, 50])
	assert_eq(world.hero.health, 0)
	assert_true(world.is_player_dead())
	assert_eq(world.player_tile, tile_before)
	assert_eq(world.turn_count, 2)
	assert_eq(world.random.state, random_before, "FR-013 discards the ended attempt's phase.")
	assert_string_contains(world.messages[-1], "Death trigger invoked")
	world.wait_turn()
	assert_false(world.move_player(Vector2i.DOWN))
	assert_false(world.cast_skill(&"experience_1"))
	assert_eq(world.turn_count, 2)
	assert_eq(world.hero.level, 2)


func test_unlearned_and_preview_casts_reject_without_simulation_changes() -> void:
	var world := MovementFixture.create_world()
	world.movement_credit = 0.75
	var random_before := world.random.state
	for identifier: StringName in [&"missing", &"fireball_1", &"frost_armor_1"]:
		assert_false(world.cast_skill(identifier))
		assert_eq(world.turn_count, 0)
		assert_eq(world.random.state, random_before)
		assert_eq(world.movement_credit, 0.75)
		assert_eq([world.hero.health, world.hero.mana], [51, 165])
	assert_string_contains(world.messages[0], "not learned")
	assert_string_contains(world.messages[-1], "preview only")


func test_learned_rank_remains_usable_below_training_level() -> void:
	var world := MovementFixture.create_world()
	world.hero.add_experience(400)
	var skill := SkillRank.new(&"retained_2", "Retained practice", &"Druid", 2, 2,
		"Test retained rank.", SkillRank.Effect.PRACTICE)
	assert_true(world.hero.learn_skill(skill))
	world.hero.level = 1
	assert_true(world.cast_skill(skill.id))
	assert_eq(world.turn_count, 1)
	assert_string_contains(world.messages[-1], "rank 2")


func test_release_world_cannot_activate_development_skills() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 5, 5), Vector2i(2, 2), 1, false)
	for identifier: StringName in [&"practice_1", &"experience_1", &"death_1"]:
		assert_false(world.cast_skill(identifier))
	assert_eq(world.turn_count, 0)
	assert_eq([world.hero.level, world.hero.experience], [1, 0])


func test_chat_retains_recent_ordered_history() -> void:
	var world := MovementFixture.create_world()
	for index in range(105):
		world.add_message("Message %d" % index)
	assert_eq(world.messages.size(), 100)
	assert_eq(world.messages[0], "Message 5")
	assert_eq(world.messages[-1], "Message 104")
