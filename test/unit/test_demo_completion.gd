extends GutTest


func _world() -> GridWorld:
	var world := ValleyRoute.create_world(97, true)
	world.turn_count = ValleyRoute.STALKER_DEADLINES[0]
	world._arrive_stalker()
	return world


func _stalkers(world: GridWorld) -> Array[GridActor]:
	return world.actors.filter(func(actor: GridActor) -> bool: return actor.stalker)


func _assert_complete(world: GridWorld) -> void:
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_false(world.can_save())
	assert_null(world.pending_skill)
	assert_null(world.pending_melee)
	var turn := world.turn_count
	var tile := world.player_tile
	var random_state := world.combat_random.state
	world.wait_turn()
	assert_false(world.move_player(Vector2i.LEFT))
	assert_false(world.cast_skill(&"practice_1"))
	world._finish_turn()
	world._arrive_stalker()
	assert_eq(world.turn_count, turn)
	assert_eq(world.player_tile, tile)
	assert_eq(world.combat_random.state, random_state)


func test_no_stalker_arrival_is_not_victory() -> void:
	var world := ValleyRoute.create_world(97, true)
	assert_false(world.all_stalkers_defeated())
	assert_false(world.check_terminal())
	world.wait_turn()
	assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)


func test_defeating_only_present_stalker_wins_immediately_without_moving() -> void:
	var world := _world()
	var tile := world.player_tile
	assert_true(world.cast_skill(&"kill_stalker_1"))
	assert_eq(world.turn_count, 16)
	assert_eq(world.player_tile, tile)
	assert_eq(world.stalkers_arrived, 1, "Future copies do not prevent victory.")
	_assert_complete(world)


func test_every_present_stalker_must_die_regardless_of_kill_order() -> void:
	for first_index in [0, 1]:
		var world := _world()
		world.turn_count = ValleyRoute.STALKER_DEADLINES[1]
		world._arrive_stalker()
		var stalkers := _stalkers(world)
		SpellEffects.damage(world, stalkers[first_index], 10000, "Victory fixture")
		assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)
		assert_false(world.all_stalkers_defeated())
		SpellEffects.damage(world, stalkers[1 - first_index], 10000, "Victory fixture")
		assert_true(world.all_stalkers_defeated())
		_assert_complete(world)


func test_last_kill_stops_same_turn_reinforcement_and_later_enemy_response() -> void:
	var world := _world()
	world.turn_count = ValleyRoute.STALKER_DEADLINES[1] - 1
	var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.melee.hit = 1000
	enemy.melee.damage_min = 10000
	enemy.melee.damage_max = 10000
	world.actors.append(enemy)
	assert_true(world.cast_skill(&"kill_stalker_1"))
	assert_eq(world.turn_count, ValleyRoute.STALKER_DEADLINES[1])
	assert_eq(world.stalkers_arrived, 1)
	assert_eq(world.hero.health, world.hero.max_health)
	_assert_complete(world)


func test_area_attack_stops_after_last_present_stalker_dies() -> void:
	for identifier: StringName in [&"whirlwind_1", &"booming_shout_1"]:
		var world := GridWorld.new(Rect2i(0, 0, 15, 15), Vector2i(7, 7), 97, false)
		world.hero.learned_skills.append(SkillDefinition.catalog(identifier))
		world.hero.rage = 100
		world.hero.melee.hit = 1000
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var actor := GridActor.new(world.player_tile + offset)
			actor.relationship = GridActor.Relationship.HOSTILE
			actor.health = 1
			actor.stalker = offset != Vector2i.DOWN
			actor.melee.dodge = 0
			world.actors.append(actor)
		assert_true(world.cast_skill(identifier))
		assert_false(world.actors[0].alive)
		assert_false(world.actors[1].alive)
		assert_true(world.actors[2].alive, "The last stalker ends the action before later targets.")
		_assert_complete(world)


func test_gate_has_no_lock_or_crossing_win_condition() -> void:
	var world := _world()
	# Keep the stalker out of this movement test; its presence still prevents victory.
	_stalkers(world)[0].tile = Vector2i(70, 65)
	_stalkers(world)[0].home_tile = Vector2i(70, 65)
	for x in range(11, 14):
		world.player_tile = Vector2i(x, 64)
		assert_true(world.move_player(Vector2i.DOWN))
		assert_true(world.move_player(Vector2i.DOWN))
		assert_eq(world.player_tile, Vector2i(x, 66))
		assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)


func test_player_death_cannot_be_overridden_by_simultaneous_or_later_stalker_death() -> void:
	var world := _world()
	world.hero.health = 0
	var boss := _stalkers(world)[0]
	boss.health = 0
	world._check_npc_death(boss)
	assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED)
	assert_true(world.check_terminal())
	assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED)
	var session := GameSession.new()
	session.world = world
	assert_true(session.restart_after_death())
	assert_eq(session.loop_count, 2)
	assert_false(session.world.all_stalkers_defeated())
	assert_eq(session.world.stalkers_arrived, 0)


func test_development_kill_stalker_rejects_before_arrival_without_spending_time() -> void:
	var world := ValleyRoute.create_world(97, true)
	assert_false(world.cast_skill(&"kill_stalker_1"))
	assert_eq(world.turn_count, 0)
	assert_eq(world.stalkers_arrived, 0)
	assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)


func test_beeline_witnesses_guard_death_before_passing_the_gate() -> void:
	for paladin in [false, true]:
		var world := ValleyRoute.create_world(97, false)
		if paladin:
			world.hero.learned_skills.append(SkillDefinition.catalog(&"pursuit_of_justice_1"))
		var guard: GridActor
		for actor in world.actors:
			if actor.story_guard:
				guard = actor
		while world.turn_count < ValleyRoute.STALKER_DEADLINES[0]:
			var direction := Vector2i(-1, 1) if world.player_tile.y < 64 else Vector2i.LEFT
			if not world.move_player(direction):
				world.wait_turn()
		assert_false(guard.alive)
		assert_eq(guard.died_on_turn, 15)
		assert_eq(world.stalkers_arrived, 1)
		assert_lte(world.tile_distance(world.player_tile, guard.tile), 5)
		assert_true(world.has_sight(world.player_tile, guard.tile))
		assert_lt(world.player_tile.y, guard.tile.y + 2)
		assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)
