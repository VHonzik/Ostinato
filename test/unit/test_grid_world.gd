extends GutTest

var _world: GridWorld


func before_each() -> void:
	_world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(10, 10), 42)


func test_each_of_eight_directions_moves_one_tile_for_one_turn() -> void:
	for direction in [
		Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1),
		Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1),
	]:
		_world.player_tile = Vector2i(10, 10)
		var turns_before := _world.turn_count
		assert_true(_world.move_player(direction))
		assert_eq(_world.player_tile, Vector2i(10, 10) + direction)
		assert_eq(_world.turn_count, turns_before + 1)
		assert_eq(_world.movement_credit, 0.0)


func test_diagonal_can_pass_between_two_blocked_neighbors() -> void:
	_world.blocked_tiles[Vector2i(11, 10)] = true
	_world.blocked_tiles[Vector2i(10, 9)] = true
	assert_true(_world.move_player(Vector2i(1, -1)))
	assert_eq(_world.player_tile, Vector2i(11, 9))
	assert_eq(_world.turn_count, 1)


func test_blocked_move_preserves_time_credit_npcs_and_random_state() -> void:
	_world.blocked_tiles[Vector2i(11, 10)] = true
	_world.movement_credit = 2.5
	var wanderer := GridActor.new(Vector2i(2, 2), Rect2i(1, 1, 4, 4))
	_world.actors.append(wanderer)
	var random_before := _world.random.state
	assert_false(_world.move_player(Vector2i.RIGHT))
	assert_eq(_world.player_tile, Vector2i(10, 10))
	assert_eq(_world.turn_count, 0)
	assert_eq(_world.movement_credit, 2.5)
	assert_eq(wanderer.tile, Vector2i(2, 2))
	assert_eq(_world.random.state, random_before)


func test_map_edges_reject_without_a_turn() -> void:
	for pair in [
		[Vector2i(0, 0), Vector2i(-1, -1)],
		[Vector2i(19, 0), Vector2i.RIGHT],
		[Vector2i(0, 19), Vector2i.DOWN],
		[Vector2i(19, 19), Vector2i(1, 1)],
	]:
		_world.player_tile = pair[0]
		assert_false(_world.move_player(pair[1]))
		assert_eq(_world.player_tile, pair[0])
	assert_eq(_world.turn_count, 0)


func test_living_npc_blocks_but_a_corpse_allows_entry() -> void:
	var actor := GridActor.new(Vector2i(11, 10))
	_world.actors.append(actor)
	assert_false(_world.move_player(Vector2i.RIGHT))
	assert_eq(_world.turn_count, 0)
	actor.alive = false
	assert_true(_world.move_player(Vector2i.RIGHT))
	assert_eq(_world.player_tile, actor.tile)
	assert_eq(_world.turn_count, 1)


func test_fast_movement_moves_one_then_two_tiles() -> void:
	_world.movement_speed = 1.5
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(11, 10))
	assert_eq(_world.movement_credit, 0.5)
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(13, 10))
	assert_eq(_world.movement_credit, 0.0)
	assert_eq(_world.turn_count, 2)


func test_slow_movement_spends_two_turns_to_move_one_tile() -> void:
	_world.movement_speed = 0.5
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(10, 10))
	assert_eq(_world.movement_credit, 0.5)
	assert_eq(_world.turn_count, 1)
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(11, 10))
	assert_eq(_world.movement_credit, 0.0)
	assert_eq(_world.turn_count, 2)


func test_extra_step_collision_retains_whole_and_fractional_credit() -> void:
	_world.movement_speed = 1.5
	_world.movement_credit = 1.0
	_world.blocked_tiles[Vector2i(12, 10)] = true
	assert_true(_world.move_player(Vector2i.RIGHT))
	assert_eq(_world.player_tile, Vector2i(11, 10))
	assert_eq(_world.movement_credit, 1.5)
	_world.wait_turn()
	_world.movement_speed = 0.5
	_world.move_player(Vector2i.DOWN)
	assert_eq(_world.player_tile, Vector2i(11, 12), "Retained credit survives wait and speed change.")
	assert_eq(_world.movement_credit, 0.0)
	assert_eq(_world.turn_count, 3)


func test_extra_step_into_an_npc_stops_at_the_last_legal_tile() -> void:
	_world.movement_speed = 3.0
	_world.actors.append(GridActor.new(Vector2i(12, 10)))
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(11, 10))
	assert_eq(_world.actors[0].tile, Vector2i(12, 10))
	assert_eq(_world.movement_credit, 2.0)
	assert_eq(_world.turn_count, 1)


func test_wait_grants_ten_npcs_one_shared_turn_without_movement_credit() -> void:
	for index in range(10):
		_world.actors.append(GridActor.new(Vector2i(index + 1, 2), _world.bounds))
	var previous: Array[Vector2i] = []
	for actor in _world.actors:
		previous.append(actor.tile)
	_world.movement_credit = 0.5
	_world.wait_turn()
	assert_eq(_world.turn_count, 1)
	assert_eq(_world.movement_credit, 0.5)
	for index in range(_world.actors.size()):
		var difference := _world.actors[index].tile - previous[index]
		assert_eq(maxi(absi(difference.x), absi(difference.y)), 1)
	_assert_legal_occupancy(_world)


func test_player_destination_is_claimed_before_npc_movement() -> void:
	var actor := GridActor.new(Vector2i(12, 10), Rect2i(11, 10, 2, 1))
	_world.actors.append(actor)
	_world.move_player(Vector2i.RIGHT)
	assert_eq(_world.player_tile, Vector2i(11, 10))
	assert_eq(actor.tile, Vector2i(12, 10), "NPC cannot enter the player's new tile.")


func test_earlier_npc_claims_the_only_free_tile_and_later_npc_waits() -> void:
	var first := GridActor.new(Vector2i(1, 1), Rect2i(1, 1, 3, 1))
	var second := GridActor.new(Vector2i(3, 1), Rect2i(1, 1, 3, 1))
	_world.actors.assign([first, second])
	_world.wait_turn()
	assert_eq(first.tile, Vector2i(2, 1))
	assert_eq(second.tile, Vector2i(3, 1))


func test_trapped_fixed_and_dead_npcs_stay_put() -> void:
	var trapped := GridActor.new(Vector2i(1, 1), Rect2i(1, 1, 1, 1))
	var fixed := GridActor.new(Vector2i(3, 3))
	var corpse := GridActor.new(Vector2i(5, 5), _world.bounds)
	corpse.alive = false
	_world.actors.assign([trapped, fixed, corpse])
	for count in range(10):
		_world.wait_turn()
	assert_eq(trapped.tile, Vector2i(1, 1))
	assert_eq(fixed.tile, Vector2i(3, 3))
	assert_eq(corpse.tile, Vector2i(5, 5))


func test_wandering_respects_area_obstacles_and_occupancy_over_repeated_waits() -> void:
	_world = MovementFixture.create_world()
	var visited: Dictionary[Vector2i, bool] = {}
	for count in range(200):
		_world.wait_turn()
		visited[_world.actors[2].tile] = true
		_assert_legal_occupancy(_world)
	assert_gt(visited.size(), 1, "A designated wanderer actually changes tiles.")


func test_same_seed_and_actions_reproduce_npc_decisions() -> void:
	var other := MovementFixture.create_world()
	_world = MovementFixture.create_world()
	for count in range(60):
		if count % 3 == 0:
			var direction := Vector2i.LEFT if count % 2 == 0 else Vector2i.RIGHT
			_world.move_player(direction)
			other.move_player(direction)
		else:
			_world.wait_turn()
			other.wait_turn()
		for index in range(_world.actors.size()):
			assert_eq(_world.actors[index].tile, other.actors[index].tile)
	assert_eq(_world.random.state, other.random.state)
	assert_eq(_world.turn_count, other.turn_count)


func test_invalid_directions_do_not_spend_time_or_credit() -> void:
	for direction in [Vector2i.ZERO, Vector2i(2, 0), Vector2i(1, -2)]:
		assert_false(_world.move_player(direction))
	assert_eq(_world.turn_count, 0)
	assert_eq(_world.movement_credit, 0.0)


func _assert_legal_occupancy(world: GridWorld) -> void:
	var occupied: Array[Vector2i] = [world.player_tile]
	for actor in world.actors:
		if not actor.alive:
			continue
		assert_true(world.bounds.has_point(actor.tile))
		assert_false(world.blocked_tiles.has(actor.tile))
		assert_false(occupied.has(actor.tile), "Living actors never overlap.")
		if actor.wander_area.has_area():
			assert_true(actor.wander_area.has_point(actor.tile))
		occupied.append(actor.tile)
