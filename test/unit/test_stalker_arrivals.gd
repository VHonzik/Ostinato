extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 56, 44), Vector2i(20, 14), 97)
	world.stalker_schedule = true
	var guard := GridActor.new(Vector2i(53, 14))
	guard.story_guard = true
	world.actors.append(guard)
	return world


func _stalkers(world: GridWorld) -> Array[GridActor]:
	return world.actors.filter(func(actor: GridActor) -> bool: return actor.stalker)


func _announcements(world: GridWorld) -> int:
	var count := 0
	for message in world.messages:
		if message.begins_with("A demon stalker"):
			count += 1
	return count


func _session(world: GridWorld) -> GameSession:
	var session := GameSession.new()
	session.restore(world, world.seed_value, 1)
	return session


func _restore(world: GridWorld) -> GridWorld:
	var data: Variant = JSON.parse_string(JSON.stringify(SaveCodec.capture(_session(world))))
	return SaveCodec.restore(data, true)


func test_exact_deadlines_five_identities_legal_tiles_and_only_one_guard_event() -> void:
	var world := _world()
	var expected_deadlines := [15, 215, 395, 555, 695]
	var expected_tiles := [Vector2i(54, 14), Vector2i(54, 13), Vector2i(54, 15),
		Vector2i(53, 13), Vector2i(53, 15)]
	for turn in range(1, 706):
		world.wait_turn()
		var expected := expected_deadlines.filter(func(due: int) -> bool: return due <= turn).size()
		assert_eq(_stalkers(world).size(), expected, "Turn %d" % turn)
		assert_eq(_announcements(world), expected)
	var stalkers := _stalkers(world)
	for index in range(5):
		assert_eq(stalkers[index].spawn_id, "gate/stalker/%d" % index)
		assert_eq(stalkers[index].tile, expected_tiles[index])
		assert_true(stalkers[index].alive)
		assert_eq(stalkers[index].melee.level, 20)
		assert_eq(stalkers[index].health, 494)
		assert_false(stalkers[index].engaged)
	assert_false(world.actors[0].alive)
	assert_true(world.actors[0].corpse_visible)
	assert_eq(world.actors[0].died_on_turn, 15, "Reinforcements never repeat the guard event.")


func test_multiple_blocked_deadlines_retry_in_identity_order_without_shifting_later_arrivals() -> void:
	var world := _world()
	for tile in GridWorld.STALKER_ENTRIES:
		world.blocked_tiles[tile] = true
	world.turn_count = 394
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 0)
	assert_eq(_announcements(world), 0)
	assert_true(world.actors[0].alive)
	world.blocked_tiles.erase(Vector2i(54, 14))
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 1)
	assert_eq(world.actors[0].died_on_turn, 396)
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 1, "The first stalker now occupies the only entry.")
	world.blocked_tiles.clear()
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 3, "All overdue entries can arrive at the same boundary.")
	assert_eq(_announcements(world), 3)
	world.turn_count = 554
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 4, "Fourth deadline remains turn 555.")
	world.turn_count = 694
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 5)
	assert_eq(world.actors[0].died_on_turn, 396)
	assert_eq(world.stalker_deadlines, [15, 215, 395, 555, 695])


func test_entry_checks_player_actors_summons_terrain_and_allows_a_corpse() -> void:
	var world := _world()
	world.player_tile = Vector2i(54, 14)
	var blocker := GridActor.new(Vector2i(54, 13))
	world.actors.append(blocker)
	var summon := GridActor.new(Vector2i(54, 15))
	summon.summon_kind = "earth"
	world.actors.append(summon)
	world.blocked_tiles[Vector2i(53, 13)] = true
	var corpse := GridActor.new(Vector2i(53, 15))
	corpse.alive = false
	corpse.health = 0
	world.actors.append(corpse)
	world.turn_count = 15
	world._arrive_stalker()
	assert_eq(_stalkers(world).size(), 1)
	assert_eq(_stalkers(world)[0].tile, corpse.tile)
	assert_eq(world.player_tile, Vector2i(54, 14))


func test_arrival_can_aggro_but_first_moves_or_attacks_in_next_shared_phase() -> void:
	for player_tile in [Vector2i(53, 15), Vector2i(51, 14)]:
		var world := _world()
		world.player_tile = player_tile
		world.turn_count = 14
		var health := world.hero.health
		world.wait_turn()
		var stalker := _stalkers(world)[0]
		assert_true(stalker.engaged)
		assert_eq(stalker.tile, Vector2i(54, 14))
		assert_eq(world.hero.health, health)
		assert_eq(stalker.swing.remaining, 0.0)
		stalker.melee.hit = 100
		stalker.melee.critical = 0
		stalker.melee.damage_min = 1
		stalker.melee.damage_max = 1
		stalker.melee.attack_power = 0
		world.hero.melee.dodge = 0
		world.wait_turn()
		if player_tile == Vector2i(53, 15):
			assert_lt(world.hero.health, health)
		else:
			assert_ne(stalker.tile, Vector2i(54, 14))


func test_idle_frames_do_not_progress_arrivals() -> void:
	var world := _world()
	world.turn_count = 14
	await wait_frames(5)
	assert_eq(world.turn_count, 14)
	assert_eq(_stalkers(world).size(), 0)
	assert_eq(_announcements(world), 0)
	world.wait_turn()
	assert_eq(_stalkers(world).size(), 1)


func test_save_restores_due_pending_and_arrived_identities_and_replays_continuation() -> void:
	var world := _world()
	world.turn_count = 14
	world.wait_turn()
	for tile in GridWorld.STALKER_ENTRIES:
		if world.is_open(tile):
			world.blocked_tiles[tile] = true
	world.turn_count = 554
	world.wait_turn()
	var restored := _restore(world)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.stalkers_arrived, 1)
	assert_eq(restored.stalker_deadlines, [15, 215, 395, 555, 695])
	assert_eq(_announcements(restored), 1)
	for current in [world, restored]:
		current.blocked_tiles.clear()
		current.wait_turn()
		assert_eq(_stalkers(current).size(), 4)
		current.turn_count = 694
		current.wait_turn()
		assert_eq(_stalkers(current).size(), 5)
		assert_eq(_announcements(current), 5)
	assert_eq(JSON.stringify(SaveCodec.capture(_session(restored))),
		JSON.stringify(SaveCodec.capture(_session(world))))
	var finished := _restore(restored)
	assert_not_null(finished)
	if finished != null:
		finished.wait_turn()
		assert_eq(_stalkers(finished).size(), 5)
		assert_eq(_announcements(finished), 5)


func test_invalid_saved_deadlines_counts_and_identities_are_rejected() -> void:
	var world := _world()
	world.turn_count = 215
	world._arrive_stalker()
	var data := SaveCodec.capture(_session(world))
	for deadlines in [null, [], [15, 215, 395, 555], [15, 216, 395, 555, 695],
		[15, "215", 395, 555, 695], [15, 215.5, 395, 555, 695]]:
		var bad := data.duplicate(true)
		bad.stalker_deadlines = deadlines
		assert_null(SaveCodec.restore(bad, true))
	for count in [-1, 1, 3, 6]:
		var bad := data.duplicate(true)
		bad.world.stalkers_arrived = count
		assert_null(SaveCodec.restore(bad, true))
	for identity in ["gate/stalker/0", "gate/stalker/5", "missing"]:
		var bad := data.duplicate(true)
		bad.actors[-1].state.spawn_id = identity
		assert_null(SaveCodec.restore(bad, true))
	var early := data.duplicate(true)
	early.world.turn_count = 214
	assert_null(SaveCodec.restore(early, true))


func test_each_of_five_stalkers_is_a_terminal_target_and_pending_arrivals_stop() -> void:
	for target_index in range(5):
		var world := _world()
		world.turn_count = 695
		world._arrive_stalker()
		var stalkers := _stalkers(world)
		SpellEffects.damage(world, stalkers[target_index], 10000, "Victory fixture")
		assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
		for index in range(5):
			assert_eq(stalkers[index].alive, index != target_index)
	var pending := _world()
	pending.turn_count = 15
	pending._arrive_stalker()
	for tile in GridWorld.STALKER_ENTRIES:
		if pending.is_open(tile):
			pending.blocked_tiles[tile] = true
	pending.turn_count = 695
	pending._arrive_stalker()
	SpellEffects.damage(pending, _stalkers(pending)[0], 10000, "Victory fixture")
	pending.blocked_tiles.clear()
	pending._arrive_stalker()
	pending.wait_turn()
	assert_eq(pending.turn_count, 695)
	assert_eq(_stalkers(pending).size(), 1)
	assert_eq(_announcements(pending), 1)


func test_loop_reset_restarts_all_deadlines_identities_and_guard_story() -> void:
	var game := GameSession.new()
	game.new_game(97)
	game.world.turn_count = 695
	game.world._arrive_stalker()
	assert_eq(_stalkers(game.world).size(), 5)
	var old := game.world
	old.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.stalkers_arrived, 0)
	assert_eq(game.world.turn_count, 0)
	assert_eq(game.world.stalker_deadlines, [15, 215, 395, 555, 695])
	assert_eq(_stalkers(game.world).size(), 0)
	game.world.turn_count = 14
	game.world.wait_turn()
	assert_eq(_stalkers(game.world)[0].spawn_id, "gate/stalker/0")
	old._arrive_stalker()
	assert_eq(_stalkers(game.world).size(), 1)


func test_population_reserves_five_world_slots_and_summons_are_additional() -> void:
	var world := _world()
	world.actors.clear()
	for index in range(94):
		world.actors.append(GridActor.new(Vector2i(1 + index % 30, 30 + index / 30)))
	for index in range(3):
		var summon := GridActor.new(Vector2i(40 + index, 30))
		summon.summon_kind = ["pet", "earth", "fire"][index]
		world.actors.append(summon)
	world.population.append({"area": "wolves", "slot": 0, "ordinal": 0,
		"due": 0, "pending": true})
	world.population.append({"area": "wolves", "slot": 1, "ordinal": 0,
		"due": 0, "pending": true})
	NorthshireZone.tick_population(world)
	assert_false(world.population[0].pending, "Summons do not consume ordinary world slots.")
	assert_true(world.population[1].pending, "Ordinary spawns stop at 95.")
	world.turn_count = 695
	world._arrive_stalker()
	NorthshireZone.tick_population(world)
	assert_eq(_stalkers(world).size(), 5)
	assert_eq(world.actors.size(), 103, "100 world NPCs plus pet and two totems.")
	assert_true(world.population[1].pending)


func test_all_five_pending_arrivals_survive_load_without_announcing_early() -> void:
	var world := _world()
	for tile in GridWorld.STALKER_ENTRIES:
		world.blocked_tiles[tile] = true
	world.turn_count = 694
	world.wait_turn()
	var restored := _restore(world)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.stalkers_arrived, 0)
	assert_eq(_announcements(restored), 0)
	assert_true(restored.actors[0].alive)
	restored.wait_turn()
	assert_eq(_stalkers(restored).size(), 0)
	restored.blocked_tiles.clear()
	restored.wait_turn()
	assert_eq(_stalkers(restored).size(), 5)
	assert_eq(_announcements(restored), 5)
	assert_eq(restored.actors[0].died_on_turn, 697)
	for index in range(5):
		assert_eq(_stalkers(restored)[index].spawn_id, "gate/stalker/%d" % index)
