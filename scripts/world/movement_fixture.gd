class_name MovementFixture
extends RefCounted

## Temporary training grounds; not the final Northshire map or New Game lifecycle.
const SEED: int = 104729


static func create_world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 40, 28), Vector2i(20, 14), SEED)
	# Ruined courtyard, with doors in its north and south walls.
	for x in range(6, 15):
		for y in [7, 12]:
			if x != 10:
				world.blocked_tiles[Vector2i(x, y)] = true
	for y in range(8, 12):
		for x in [6, 14]:
			world.blocked_tiles[Vector2i(x, y)] = true
	# Trees and stones. The two beside spawn demonstrate a legal diagonal squeeze.
	for tile in [
		Vector2i(20, 13), Vector2i(21, 14),
		Vector2i(27, 5), Vector2i(28, 5), Vector2i(29, 6),
		Vector2i(31, 8), Vector2i(32, 8), Vector2i(32, 9),
		Vector2i(8, 20), Vector2i(9, 20), Vector2i(9, 21),
		Vector2i(25, 18), Vector2i(26, 18), Vector2i(26, 19),
	]:
		world.blocked_tiles[tile] = true
	world.actors.append(GridActor.new(Vector2i(18, 12)))
	world.actors.append(GridActor.new(Vector2i(10, 9)))
	var meadow := Rect2i(22, 15, 11, 9)
	world.actors.append(GridActor.new(Vector2i(23, 16), meadow))
	world.actors.append(GridActor.new(Vector2i(28, 20), meadow))
	world.actors.append(GridActor.new(Vector2i(31, 17), meadow))
	world.actors[0].title = "Groundskeeper Mira"
	world.actors[1].title = "Courtyard keeper"
	for index in range(2, 5):
		world.actors[index].title = "Meadow wolf"
		world.actors[index].relationship = GridActor.Relationship.NEUTRAL
		_set_wolf_profile(world.actors[index], false)
	var training_wolf := GridActor.new(Vector2i(20, 16))
	training_wolf.title = "Young Wolf"
	training_wolf.relationship = GridActor.Relationship.NEUTRAL
	_set_wolf_profile(training_wolf, false)
	world.actors.append(training_wolf)
	for tile in [Vector2i(32, 12), Vector2i(33, 14), Vector2i(34, 16)]:
		var wolf := GridActor.new(tile)
		wolf.title = "Timber Wolf"
		wolf.relationship = GridActor.Relationship.HOSTILE
		_set_wolf_profile(wolf, true)
		world.actors.append(wolf)
	world.sight_blockers.assign(world.blocked_tiles)
	var corpse := GridActor.new(Vector2i(19, 14))
	corpse.alive = false
	corpse.title = "Old remains"
	world.actors.append(corpse)
	return world


static func _set_wolf_profile(actor: GridActor, timber: bool) -> void:
	# ClassicDB 299 / 69: see DATA-002 melee record for the fixture adaptation.
	actor.max_health = 55 if timber else 42
	actor.health = actor.max_health
	actor.melee.level = 2 if timber else 1
	actor.melee.armor = 16 if timber else 15
	actor.melee.damage_min = 2.0
	actor.melee.damage_max = 2.0
	actor.melee.attack_power = 1
	actor.melee.interval = 2.0
