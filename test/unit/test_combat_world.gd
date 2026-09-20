extends GutTest

var _world: GridWorld


func before_each() -> void:
	_world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 10), 17)


func test_friendly_and_neutral_bumps_cost_nothing_and_cannot_harm_friendlies() -> void:
	var actor := _actor(Vector2i(11, 10), GridActor.Relationship.FRIENDLY)
	var random_before := _world.combat_random.state
	assert_false(_world.request_melee(actor))
	assert_false(_world.move_player(Vector2i.RIGHT))
	assert_string_contains(_world.interact(actor), "Welcome")
	actor.relationship = GridActor.Relationship.NEUTRAL
	assert_false(_world.move_player(Vector2i.RIGHT))
	assert_false(actor.engaged)
	assert_eq(actor.health, actor.max_health)
	assert_eq(_world.turn_count, 0)
	assert_eq(_world.combat_random.state, random_before)


func test_hostile_bump_spends_a_turn_without_movement_or_movement_credit() -> void:
	_actor(Vector2i(11, 10))
	_world.movement_credit = 0.5
	assert_true(_world.move_player(Vector2i.RIGHT))
	assert_eq(_world.turn_count, 1)
	assert_eq(_world.player_tile, Vector2i(10, 10))
	assert_eq(_world.movement_credit, 0.5)
	assert_string_contains(_world.messages[0], "You ->")


func test_neutral_preview_is_free_but_confirmation_engages_even_on_miss() -> void:
	var actor := _actor(Vector2i(11, 10), GridActor.Relationship.NEUTRAL)
	assert_eq(_world.interaction_candidates(), [actor])
	assert_false(actor.engaged)
	assert_eq(_world.turn_count, 0)
	# Find a seed with an initial miss without substituting a different production rule.
	for seed_value in range(1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() < 0.05:
			_world.combat_random.seed = seed_value
			break
	assert_eq(_world.interact(actor), "")
	assert_true(actor.engaged)
	assert_eq(actor.relationship, GridActor.Relationship.HOSTILE)
	assert_eq(actor.health, actor.max_health)
	assert_string_contains(_world.messages[0], "miss")


func test_sight_blocks_acquisition_but_not_world_presence_and_corner_touches_pass() -> void:
	var actor := _actor(Vector2i(13, 10))
	_world.blocked_tiles[Vector2i(12, 10)] = true
	_world.sight_blockers[Vector2i(12, 10)] = true
	_world.wait_turn()
	assert_false(actor.engaged)
	assert_eq(actor.tile, Vector2i(13, 10))
	assert_true(_world.actors.has(actor))
	_world.sight_blockers.clear()
	_world.wait_turn()
	assert_true(actor.engaged)
	_world.sight_blockers[Vector2i(11, 10)] = true
	_world.sight_blockers[Vector2i(10, 11)] = true
	assert_true(_world.has_sight(Vector2i(10, 10), Vector2i(11, 11)))
	assert_false(_world.has_sight(Vector2i(10, 10), Vector2i(12, 10)))
	assert_false(_world.has_sight(Vector2i(12, 10), Vector2i(10, 10)))


func test_living_actors_do_not_block_sight_and_dead_hostiles_do_not_acquire() -> void:
	_actor(Vector2i(11, 10), GridActor.Relationship.FRIENDLY)
	var actor := _actor(Vector2i(12, 10))
	actor.alive = false
	assert_true(_world.has_sight(Vector2i(10, 10), Vector2i(13, 10)))
	_world.wait_turn()
	assert_false(actor.engaged)


func test_ready_enemy_moves_adjacent_and_attacks_in_same_phase() -> void:
	var actor := _actor(Vector2i(12, 10))
	_world.wait_turn()
	assert_true(actor.engaged)
	assert_eq(GridWorld.tile_distance(actor.tile, _world.player_tile), 1)
	assert_string_contains(_world.messages[-1], "-> You")
	assert_eq(_world.turn_count, 1)


func test_enemy_entering_range_keeps_positive_swing_delay() -> void:
	var actor := _actor(Vector2i(12, 10))
	actor.swing.remaining = 2.5
	_world.wait_turn()
	assert_eq(actor.swing.remaining, 1.5)
	assert_eq(_world.hero.health, 51)
	assert_eq(_world.messages.size(), 1, "Only the engagement notice; no swing yet.")


func test_fast_movement_acquires_on_crossed_tile_outside_final_radius() -> void:
	_world.player_tile = Vector2i(2, 10)
	_world.movement_speed = 12.0
	var actor := _actor(Vector2i(8, 8))
	actor.aggro_range = 2
	assert_true(_world.move_player(Vector2i.RIGHT))
	assert_eq(_world.player_tile, Vector2i(14, 10))
	assert_true(actor.engaged)
	assert_gt(GridWorld.tile_distance(actor.tile, _world.player_tile), actor.aggro_range)


func test_hostile_on_extra_step_stops_movement_without_player_attack() -> void:
	var actor := _actor(Vector2i(12, 10))
	_world.movement_speed = 3.0
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(11, 10))
	assert_eq(_world.movement_credit, 2.0)
	assert_eq(actor.health, actor.max_health)
	assert_null(_world.pending_melee)


func test_pursuit_survives_lost_sight_and_navigates_static_obstacles() -> void:
	var actor := _actor(Vector2i(14, 10))
	actor.engaged = true
	for y in range(7, 14):
		_world.blocked_tiles[Vector2i(12, y)] = true
		_world.sight_blockers[Vector2i(12, y)] = true
	assert_false(_world.has_sight(actor.tile, _world.player_tile))
	for index in range(10):
		_world.wait_turn()
	assert_eq(GridWorld.tile_distance(actor.tile, _world.player_tile), 1)
	assert_true(actor.engaged)
	assert_eq(actor.blocked_turns, 0)


func test_crowded_pursuers_fill_available_melee_tiles_without_overlap_or_leash() -> void:
	_world.hero.health = 10000
	for tile in [Vector2i(6, 6), Vector2i(10, 6), Vector2i(14, 6), Vector2i(14, 10),
		Vector2i(14, 14), Vector2i(10, 14), Vector2i(6, 14), Vector2i(6, 10), Vector2i(5, 10)]:
		_actor(tile).engaged = true
	for turn in range(12):
		_world.wait_turn()
		var occupied: Array[Vector2i] = [_world.player_tile]
		for actor in _world.actors:
			assert_false(occupied.has(actor.tile))
			assert_false(_world.blocked_tiles.has(actor.tile))
			assert_eq(actor.blocked_turns, 0)
			assert_true(actor.engaged)
			occupied.append(actor.tile)
	var adjacent := 0
	for actor in _world.actors:
		if GridWorld.tile_distance(actor.tile, _world.player_tile) == 1:
			adjacent += 1
	assert_eq(adjacent, 8)
	assert_eq(_world.turn_count, 12)


func test_static_failure_leashes_after_five_turns_and_restores_health_at_home() -> void:
	var actor := _actor(Vector2i(15, 10))
	actor.home_tile = Vector2i(17, 10)
	actor.health = 5
	actor.engaged = true
	for y in range(20):
		_world.blocked_tiles[Vector2i(12, y)] = true
	for index in range(4):
		_world.wait_turn()
	assert_true(actor.engaged)
	assert_eq(actor.blocked_turns, 4)
	_world.wait_turn()
	assert_false(actor.engaged)
	assert_true(actor.returning_home)
	for index in range(3):
		_world.wait_turn()
	assert_eq(actor.tile, actor.home_tile)
	assert_eq(actor.health, actor.max_health)


func test_new_static_route_resets_counter_and_unreachable_home_stays_legal() -> void:
	var actor := _actor(Vector2i(15, 10))
	actor.engaged = true
	for y in range(20):
		_world.blocked_tiles[Vector2i(12, y)] = true
	for index in range(4):
		_world.wait_turn()
	_world.blocked_tiles.erase(Vector2i(12, 10))
	_world.wait_turn()
	assert_eq(actor.blocked_turns, 0)
	actor.engaged = false
	actor.returning_home = true
	actor.home_tile = Vector2i(19, 10)
	_world.blocked_tiles[actor.home_tile] = true
	var stranded_tile := actor.tile
	for index in range(8):
		_world.wait_turn()
	assert_true(actor.returning_home)
	assert_eq(actor.tile, stranded_tile, "An unreachable home leaves the actor idle.")
	assert_false(_world.blocked_tiles.has(actor.tile))
	_world.blocked_tiles.erase(actor.home_tile)
	for index in range(6):
		_world.wait_turn()
	assert_false(actor.returning_home)
	assert_eq(actor.tile, actor.home_tile)


func test_pending_swing_has_cancel_boundaries_and_npcs_get_every_turn() -> void:
	var actor := _actor(Vector2i(11, 10))
	_world.hero.swing.remaining = 2.5
	assert_true(_world.request_melee(actor))
	assert_same(_world.pending_melee, actor)
	assert_eq(_world.turn_count, 1)
	assert_true(_world.continue_melee())
	assert_eq(_world.turn_count, 2)
	assert_same(_world.pending_melee, actor)
	_world.cancel_melee()
	assert_null(_world.pending_melee)
	assert_eq(_world.turn_count, 2)
	assert_almost_eq(_world.hero.swing.remaining, 0.5, 0.00001)
	assert_true(_world.request_melee(actor))
	assert_eq(_world.turn_count, 3)
	assert_null(_world.pending_melee)


func test_pending_swing_revalidates_adjacency_without_refunding_time() -> void:
	var actor := _actor(Vector2i(11, 10))
	_world.hero.swing.remaining = 3.0
	_world.request_melee(actor)
	actor.tile = Vector2i(15, 15)
	assert_false(_world.continue_melee())
	assert_null(_world.pending_melee)
	assert_eq(_world.turn_count, 1)


func test_player_kill_awards_xp_once_and_corpse_is_nonblocking_selectable_and_expires() -> void:
	var actor := _actor(Vector2i(11, 10))
	actor.health = 1
	_world.hero.melee.critical = 100.0
	# Retry genuine attacks until a non-miss/dodge roll resolves.
	for index in range(30):
		if not actor.alive:
			break
		if _world.pending_melee != null:
			_world.continue_melee()
		else:
			_world.request_melee(actor)
	assert_false(actor.alive)
	assert_false(actor.engaged)
	assert_eq(_world.hero.experience, 50)
	assert_true(_world.is_open(actor.tile))
	_world.move_player(Vector2i.RIGHT)
	assert_true(_world.interaction_candidates().has(actor))
	assert_string_contains(_world.interact(actor), "no loot")
	assert_string_contains(_world.interact(actor), "no loot")
	assert_eq(_world.hero.experience, 50)
	for index in range(300):
		_world.wait_turn()
	assert_false(actor.corpse_visible)
	assert_false(_world.interaction_candidates().has(actor))


func test_death_stops_later_npcs_and_all_future_gameplay() -> void:
	var killer := _actor(Vector2i(11, 10))
	killer.melee.damage_min = 1000.0
	killer.melee.damage_max = 1000.0
	killer.melee.critical = 100.0
	killer.melee.level = 100
	var later := _actor(Vector2i(14, 10))
	_world.wait_turn()
	assert_true(_world.is_player_dead())
	assert_eq(later.tile, Vector2i(14, 10))
	var combat_state := _world.combat_random.state
	assert_false(_world.move_player(Vector2i.DOWN))
	assert_false(_world.request_melee(killer))
	assert_false(_world.cast_skill(&"experience_1"))
	_world.wait_turn()
	assert_eq(_world.turn_count, 1)
	assert_eq(_world.combat_random.state, combat_state)


func test_identical_actions_reproduce_combat_and_do_not_consume_wander_randomness() -> void:
	var actor := _actor(Vector2i(11, 10))
	var other := GridWorld.new(_world.bounds, _world.player_tile, 17)
	var other_actor := GridActor.new(actor.tile)
	other_actor.relationship = GridActor.Relationship.HOSTILE
	other.actors.append(other_actor)
	var wander_state := _world.random.state
	for index in range(20):
		_world.wait_turn()
		other.wait_turn()
	assert_eq(_world.hero.health, other.hero.health)
	assert_eq(_world.messages, other.messages)
	assert_eq(_world.combat_random.state, other.combat_random.state)
	assert_eq(_world.random.state, wander_state)


func test_corpse_beneath_living_actor_remains_an_interaction_candidate() -> void:
	var corpse := _actor(_world.player_tile + Vector2i.RIGHT)
	corpse.alive = false
	var living := _actor(corpse.tile, GridActor.Relationship.FRIENDLY)
	assert_eq(_world.interaction_candidates(), [corpse, living])


func _actor(
	tile: Vector2i, relationship: GridActor.Relationship = GridActor.Relationship.HOSTILE
) -> GridActor:
	var actor := GridActor.new(tile)
	actor.relationship = relationship
	_world.actors.append(actor)
	return actor
