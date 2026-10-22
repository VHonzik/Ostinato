extends RefCounted
## Normal live-encounter bots react to the visible cone with a real movement action.


static func try_dodge(world: GridWorld) -> bool:
	if world.is_charging() or not _threatened(world, world.player_tile):
		return false
	var boss: GridActor
	for actor in world.actors:
		if actor.alive and actor.stalker and actor.breath_remaining > 0 \
			and StalkerBreath.threatens(world, actor, world.player_tile):
			boss = actor
			break
	var side := Vector2i(-boss.breath_direction.y, boss.breath_direction.x)
	var directions: Array[Vector2i] = [side, -side]
	for direction in GridWorld.DIRECTIONS:
		if direction not in directions: directions.append(direction)
	var best := Vector2i.ZERO
	var score := -100000
	for direction in directions:
		if not world.is_open(world.player_tile + direction): continue
		var destination := _landing_tile(world, direction)
		if destination == world.player_tile or _threatened(world, destination): continue
		# Prefer a lateral dodge that retains melee; movement credit can add a tile.
		var candidate := -100 * absi(GridWorld.tile_distance(destination, boss.tile) - 1)
		candidate += 10 if direction in [side, -side] else 0
		if candidate > score:
			best = direction
			score = candidate
	if best == Vector2i.ZERO:
		return false
	if world.pending_skill != null:
		world.cancel_cast()
		world.set_meta("bench_dodge_cancelled_casts",
			int(world.get_meta("bench_dodge_cancelled_casts", 0)) + 1)
	if world.pending_melee != null: world.cancel_melee()
	var moved := world.move_player(best)
	assert(moved, "A selected open sidestep must consume its live movement action")
	world.set_meta("bench_breath_dodges", int(world.get_meta("bench_breath_dodges", 0)) + 1)
	return moved


static func safe_to_move(world: GridWorld, direction: Vector2i) -> bool:
	# Do not walk back into a locked cone while closing to melee after a dodge.
	return not _threatened(world, _landing_tile(world, direction))


static func _threatened(world: GridWorld, tile: Vector2i) -> bool:
	return world.actors.any(func(actor: GridActor) -> bool:
		return (actor.alive and actor.stalker and actor.breath_remaining > 0
			and StalkerBreath.threatens(world, actor, tile)))


static func _landing_tile(world: GridWorld, direction: Vector2i) -> Vector2i:
	var tile := world.player_tile
	var credit := world.movement_credit + world.movement_speed \
		* (1.0 + ClassToolkitRules.magnitude(world.hero, &"pursuit_of_justice_1") / 100.0)
	while credit >= 1.0 - 0.000001 and world.is_open(tile + direction):
		tile += direction
		credit = maxf(0.0, credit - 1.0)
	return tile


static func check_live_response() -> void:
	# All cone directions, banked movement credit, and interruption of a real cast.
	for direction in GridWorld.DIRECTIONS:
		for banked in [false, true]:
			var center := Vector2i(10, 10)
			var world := GridWorld.new(Rect2i(0, 0, 24, 24), center + direction, 971, false)
			world.hero.level = 5
			world.hero.refresh_stats()
			world.hero.health = world.hero.max_health
			if banked:
				world.hero.learn_skill(SkillDefinition.catalog(&"pursuit_of_justice_1"))
				world.movement_credit = 0.9
			world._spawn_stalker(center)
			var boss: GridActor = world.actors[0]
			boss.engaged = true
			boss.breath_normal_turns = StalkerBreath.FIRST_NORMAL_TURNS
			world.wait_turn()
			assert(boss.breath_remaining == 2)
			var health := world.hero.health
			var turn := world.turn_count
			assert(try_dodge(world))
			assert(world.turn_count == turn + 1 and not _threatened(world, world.player_tile))
			assert(not try_dodge(world), "Already safe: no second dodge action")
			world.wait_turn()
			assert(boss.breath_remaining == 0 and world.hero.health == health)
			world.discard()
	var casting := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(11, 10), 972, false)
	casting.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	casting.hero.rage = 30
	casting._spawn_stalker(Vector2i(10, 10))
	var target: GridActor = casting.actors[0]
	target.engaged = true
	target.breath_normal_turns = StalkerBreath.FIRST_NORMAL_TURNS
	assert(casting.cast_skill(&"lava_burst_1", target) and casting.pending_skill != null)
	assert(try_dodge(casting) and casting.pending_skill == null)
	assert(int(casting.get_meta("bench_dodge_cancelled_casts", 0)) == 1)
	casting.wait_turn()
	for message in casting.messages:
		assert(not message.begins_with("Fel Breath -> You:"))
	casting.discard()
	print("PASS bench dodge: real one-action responses, all directions, movement credit, cast cancellation.")
