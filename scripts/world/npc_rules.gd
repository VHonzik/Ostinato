class_name NpcRules
extends RefCounted


static func acquire_hostiles(world: GridWorld) -> void:
	for actor in world.actors:
		if (not actor.alive or actor.relationship != GridActor.Relationship.HOSTILE
			or actor.returning_home or actor.engaged):
			continue
		if (not VanishRules.active(world)
			and GridWorld.tile_distance(actor.tile, world.player_tile) <= actor.aggro_range
			and world.has_sight(actor.tile, world.player_tile)):
			actor.engaged = true
			SummonRules.add_threat(world, actor, null, 1)
			world.add_message("%s engages you." % actor.title)
		else:
			for ally in world.actors:
				if (ally.alive and ally.summon_kind not in ["", "earth_elemental"]
					and GridWorld.tile_distance(actor.tile, ally.tile) <= actor.aggro_range
					and world.has_sight(actor.tile, ally.tile)):
					actor.engaged = true
					SummonRules.add_threat(world, actor, ally, 1)
					break


static func act(world: GridWorld, actor: GridActor) -> void:
	if StalkerBreath.act(world, actor):
		return
	if actor.stunned_until > world.turn_count:
		actor.swing.advance(false, actor.melee.interval)
		return
	if actor.engaged and VanishRules.active(world):
		_pursue(world, actor, VanishRules.origin(world), true)
		actor.swing.advance(false, actor.melee.interval)
		return
	var target := NpcTarget.new(world, SummonRules.enemy_target(world, actor))
	_move(world, actor, target.tile)
	var in_melee := (actor.engaged and GridWorld.tile_distance(actor.tile, target.tile) == 1
		and world.has_sight(actor.tile, target.tile))
	var swings := actor.swing.advance(in_melee, actor.melee.interval)
	for index in range(swings):
		if world.is_terminal():
			return
		_attack(world, actor, target)
		if world.is_terminal() or not target.alive or not actor.alive:
			return


static func _move(world: GridWorld, actor: GridActor, target: Vector2i) -> void:
	if actor.returning_home:
		_return_home(world, actor)
	elif actor.engaged:
		_pursue(world, actor, target)
	else:
		world._wander(actor)


static func _return_home(world: GridWorld, actor: GridActor) -> void:
	if not world._route(actor.tile, [actor.home_tile], false, actor.home_tile).is_empty():
		world._step_toward(actor, [actor.home_tile], actor.home_tile)
	if actor.tile == actor.home_tile:
		actor.returning_home = false
		actor.health = actor.max_health
		actor.blocked_turns = 0


static func _pursue(world: GridWorld, actor: GridActor, target: Vector2i,
	remembered: bool = false) -> void:
	var goals: Array[Vector2i] = []
	for direction in GridWorld.DIRECTIONS:
		var tile := target + direction
		if world._terrain_open(tile) and world.has_sight(tile, target):
			goals.append(tile)
	var static_path := world._route(actor.tile, goals, false, target)
	if static_path.is_empty():
		if remembered:
			return
		actor.blocked_turns += 1
		if actor.blocked_turns >= 5:
			actor.engaged = false
			actor.threat.clear()
			actor.returning_home = true
			world.add_message("%s cannot reach you and returns home." % actor.title)
	else:
		actor.blocked_turns = 0
		world._step_toward(actor, goals, target, static_path)


static func _attack(world: GridWorld, actor: GridActor, target: NpcTarget) -> void:
	if target.is_player():
		world.melee_attacked.emit(actor, target.tile)
	var result := MeleeRules.outcome(actor.melee, target.melee,
		world.combat_random.randf() * 100.0)
	var amount := MeleeRules.damage(actor.melee, target.melee, result,
		world.combat_random.randf())
	amount = ClassSpellEffects.absorb(world, target.actor, amount, true)
	target.take_damage(amount, result)
	world.add_message("%s -> %s: %s, %d damage." % [actor.title, target.title, result, amount])
	# Death is checked before retaliation, and a killed summon cannot retaliate.
	if world.check_terminal():
		world.add_message("You died.")
		return
	if not target.alive:
		return
	if target.is_player():
		ClassToolkitRules.on_damage_taken(world, amount)
	target.retaliate(actor, amount)
