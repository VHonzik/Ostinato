class_name StalkerBreath
extends RefCounted

const RANGE: int = 3
const WINDUP_TURNS: int = 2
const FIRST_NORMAL_TURNS: int = 4
const NORMAL_TURNS_BETWEEN: int = 10
const DAMAGE: int = 60


## Returns true when the breath consumes this NPC turn, including its announcement.
static func act(world: GridWorld, actor: GridActor) -> bool:
	if not actor.stalker:
		return false
	if not actor.engaged or actor.returning_home:
		reset(actor)
		return false
	if actor.breath_remaining > 0:
		actor.breath_remaining -= 1
		if actor.breath_remaining == 0:
			_release(world, actor)
		else:
			world.stalker_breath_winding.emit(actor)
		return true
	if actor.stunned_until > world.turn_count or VanishRules.active(world):
		return false
	var delay := NORMAL_TURNS_BETWEEN if actor.breath_started else FIRST_NORMAL_TURNS
	if actor.breath_normal_turns < delay:
		actor.breath_normal_turns += 1
		return false
	var target := NpcTarget.new(world, SummonRules.enemy_target(world, actor))
	actor.breath_direction = MeleeRules.direction_toward(target.tile - actor.tile)
	actor.breath_origin = target.tile
	# Do not announce an unavoidable hit when terrain or occupants box the player in.
	if not _can_escape(world, actor):
		return false
	actor.breath_remaining = WINDUP_TURNS
	actor.breath_normal_turns = 0
	actor.breath_started = true
	# Hold a fresh weapon interval throughout the announcement and both response turns.
	actor.swing.remaining = actor.melee.interval
	actor.swing._active = false
	world.add_message("%s draws breath! Fel Breath in 2 turns. Leave the marked cone." % actor.title)
	world.stalker_breath_winding.emit(actor)
	return true


static func reset(actor: GridActor) -> void:
	actor.breath_remaining = 0
	actor.breath_normal_turns = 0
	actor.breath_started = false
	actor.breath_direction = Vector2i.ZERO
	actor.breath_origin = Vector2i(-1, -1)


static func threatens(world: GridWorld, actor: GridActor, tile: Vector2i) -> bool:
	return tiles(world, actor).has(tile)


static func tiles(world: GridWorld, actor: GridActor) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var direction := actor.breath_direction
	if direction == Vector2i.ZERO:
		return result
	var side := Vector2i(-direction.y, direction.x)
	for row in range(RANGE):
		for column in range(0 if row == 0 else -1, 1 if row == 0 else 2):
			var tile := actor.breath_origin + direction * row + side * column
			if (world.bounds.has_point(tile) and not world.blocked_tiles.has(tile)
				and world.has_sight(actor.tile, tile)):
				result.append(tile)
	return result


static func _can_escape(world: GridWorld, actor: GridActor) -> bool:
	var frontier: Array[Vector2i] = [world.player_tile]
	var visited: Array[Vector2i] = []
	# Match player movement: only the destination blocks a diagonal step.
	for step in range(WINDUP_TURNS + 1):
		var next: Array[Vector2i] = []
		for tile in frontier:
			if not threatens(world, actor, tile):
				return true
			for direction in GridWorld.DIRECTIONS:
				var destination := tile + direction
				if not visited.has(destination) and world.is_open(destination):
					visited.append(destination)
					next.append(destination)
		frontier = next
	return false


static func _release(world: GridWorld, actor: GridActor) -> void:
	world.add_message("%s unleashes Fel Breath!" % actor.title)
	world.stalker_breath_released.emit(tiles(world, actor))
	var targets: Array[GridActor] = [null]
	for ally in world.actors:
		if ally.alive and ally.summon_kind != "":
			targets.append(ally)
	for ally in targets:
		var target := NpcTarget.new(world, ally)
		if not target.alive or not threatens(world, actor, target.tile):
			continue
		var raw := floori(DAMAGE * actor.melee.damage_multiplier
			* MeleeRules.level_damage_multiplier(actor.melee.level, target.melee.level))
		var amount := ClassSpellEffects.absorb(world, ally, raw, false)
		target.take_damage(amount, &"hit")
		world.add_message("Fel Breath -> %s: hit, %d damage." % [target.title, amount])
		if world.check_terminal():
			world.add_message("You died.")
			return
		if target.alive:
			if target.is_player():
				ClassToolkitRules.on_damage_taken(world, amount)
			target.retaliate(actor, amount)
		if world.is_terminal() or not actor.alive:
			return
