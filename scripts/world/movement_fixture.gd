class_name MovementFixture
extends RefCounted

## Temporary milestone-1 grounds; no Northshire, combat, or New Game data implied.
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
	var corpse := GridActor.new(Vector2i(19, 14))
	corpse.alive = false
	world.actors.append(corpse)
	return world
