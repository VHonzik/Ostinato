class_name ValleyRoute
extends RefCounted

## Fixed encounters and landmarks, following the valley sketch's proportions.
const BOUNDS := Rect2i(0, 0, 84, 82)
const SPAWN := Vector2i(30, 57)
const STALKER_DEADLINES: Array[int] = [25, 800, 980, 1140, 1280]
const STALKER_ENTRIES: Array[Vector2i] = [
	Vector2i(12, 73), Vector2i(11, 73), Vector2i(13, 73),
	Vector2i(12, 74), Vector2i(13, 74),
]
const OUTLINE: Array[Vector2] = [
	Vector2(16, 1), Vector2(29, 1), Vector2(29, 11), Vector2(33, 14),
	Vector2(42, 17), Vector2(45, 21), Vector2(44, 29), Vector2(49, 37),
	Vector2(69, 43), Vector2(74, 48), Vector2(74, 53), Vector2(71, 57),
	Vector2(75, 61), Vector2(81, 64), Vector2(83, 67), Vector2(82, 69),
	Vector2(75, 70), Vector2(71, 71), Vector2(71, 75), Vector2(69, 79),
	Vector2(52, 81), Vector2(40, 78), Vector2(35, 68), Vector2(28, 65),
	Vector2(22, 65), Vector2(14, 65), Vector2(14, 81), Vector2(11, 81),
	Vector2(11, 65), Vector2(2, 65), Vector2(1, 52), Vector2(3, 40),
	Vector2(3, 34), Vector2(5, 27), Vector2(8, 22), Vector2(12, 15),
	Vector2(16, 11),
]
const WOLVES: Array[Vector2i] = [
	Vector2i(19, 48), Vector2i(14, 43), Vector2i(12, 36),
	Vector2i(7, 44), Vector2i(15, 57), Vector2i(20, 32),
	Vector2i(5, 52), Vector2i(16, 39), Vector2i(9, 31),
	Vector2i(13, 50), Vector2i(18, 58),
]
const TIMBER_WOLVES: Array[Vector2i] = [
	Vector2i(7, 35), Vector2i(12, 32), Vector2i(14, 28), Vector2i(18, 30),
	Vector2i(6, 39), Vector2i(10, 42), Vector2i(20, 37), Vector2i(16, 45),
]
# Identity, home tile, encounter name. No replacement population is scheduled.
const ENCOUNTERS: Array = [
	[6, Vector2i(23, 25), "camp"], [6, Vector2i(29, 23), "camp"],
	[6, Vector2i(35, 25), "camp"], [6, Vector2i(39, 22), "camp"],
	[257, Vector2i(22, 11), "mine"], [257, Vector2i(25, 7), "mine"],
	[80, Vector2i(19, 4), "mine"],
	[38, Vector2i(47, 62), "vineyard"], [38, Vector2i(54, 58), "vineyard"],
	[38, Vector2i(59, 67), "vineyard"], [38, Vector2i(57, 73), "vineyard"],
	[103, Vector2i(78, 66), "garrick"],
	[6, Vector2i(18, 27), "camp"], [6, Vector2i(25, 22), "camp"],
	[6, Vector2i(33, 21), "camp"], [6, Vector2i(41, 25), "camp"],
	[257, Vector2i(19, 9), "mine"], [257, Vector2i(26, 11), "mine"],
	[80, Vector2i(25, 3), "mine"],
]
const QUESTS: Array[String] = [
	"valley_wolves", "valley_patrol", "valley_timber_wolves", "valley_camp",
	"valley_mine", "valley_vineyard", "valley_explore",
]


static func create_world(seed_value: int, development_build: bool) -> GridWorld:
	var world := GridWorld.new(BOUNDS, SPAWN, seed_value, development_build)
	world.northshire = true
	world.valley_route = true
	world.stalker_schedule = true
	world.stalker_deadlines = STALKER_DEADLINES.duplicate()
	InventoryRules.add(world.hero.inventory,
		ItemData.instance(GridWorld.SPAWN_FOOD_ID, GridWorld.SPAWN_FOOD_QUANTITY))
	world.hotbar[GridWorld.HOTBAR_SIZE - 1] = GridWorld.FOOD_HOTBAR_ID
	build_terrain(world)
	for contact in NpcDefinition.CONTACTS:
		world.actors.append(contact.create_actor())
	for index in range(WOLVES.size()):
		_creature(world, 299, WOLVES[index], "valley/wolf/%d" % index)
	for index in range(TIMBER_WOLVES.size()):
		_creature(world, 69, TIMBER_WOLVES[index], "valley/timber_wolf/%d" % index)
	for index in range(ENCOUNTERS.size()):
		var row: Array = ENCOUNTERS[index]
		_creature(world, int(row[0]), row[1], "valley/%s/%d" % [row[2], index])
	for destination in ValleyLandmarks.CHESTS:
		var chest := GridActor.new(ValleyLandmarks.CHESTS[destination].tile)
		chest.title = "Battered Chest"
		chest.chest = true
		chest.alive = false
		chest.loot_table = 2843
		chest.spawn_id = "valley/treasure/" + destination
		world.actors.append(chest)
	world.vendor_stock = MerchantData.initial_stock(world.actors)
	return world


static func build_terrain(world: GridWorld) -> void:
	var polygon := PackedVector2Array(OUTLINE)
	for y in range(BOUNDS.size.y):
		for x in range(BOUNDS.size.x):
			var tile := Vector2i(x, y)
			if not Geometry2D.is_point_in_polygon(Vector2(tile) + Vector2(0.5, 0.5), polygon):
				world.blocked_tiles[tile] = true
	# Only the edge needs art; the unreachable exterior stays quiet.
	for tile: Vector2i in world.blocked_tiles:
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = tile + direction
			if BOUNDS.has_point(neighbor) and not world.blocked_tiles.has(neighbor):
				world.scenery_tiles[tile] = &"cliff_face" if tile.x > 33 else &"pine_tree"
				break
	_building(world, Rect2i(26, 39, 10, 10), &"abbey_floor", &"abbey_wall_straight")
	_building(world, Rect2i(29, 32, 5, 8), &"abbey_floor", &"abbey_wall_straight")
	_building(world, Rect2i(35, 41, 7, 4), &"abbey_floor", &"abbey_wall_straight")
	for door in [Vector2i(30, 48), Vector2i(31, 48), Vector2i(31, 39), Vector2i(35, 43)]:
		_door(world, door, &"abbey_floor")
	_building(world, Rect2i(16, 1, 13, 14), &"mine_floor", &"cliff_face")
	for door in [Vector2i(21, 14), Vector2i(22, 14), Vector2i(23, 14)]:
		_door(world, door, &"mine_floor")
	_path(world, [Vector2i(30, 60), Vector2i(30, 49)])
	_path(world, [Vector2i(30, 52), Vector2i(22, 52), Vector2i(22, 46), Vector2i(17, 46)])
	_path(world, [Vector2i(24, 45), Vector2i(23, 56), Vector2i(18, 60),
		Vector2i(12, 64), Vector2i(12, 79)])
	_path(world, [Vector2i(25, 46), Vector2i(25, 31), Vector2i(29, 26),
		Vector2i(24, 19), Vector2i(22, 15)])
	_path(world, [Vector2i(41, 43), Vector2i(44, 45), Vector2i(46, 52),
		Vector2i(52, 59), Vector2i(52, 72)])
	for x in range(3, 23):
		if x not in [11, 12, 13]:
			_block(world, Vector2i(x, 65), &"fence_straight")
	_block(world, Vector2i(10, 65), &"gate_post")
	_block(world, Vector2i(14, 65), &"gate_post")
	world.scenery_tiles[Vector2i(30, 48)] = &"abbey_entrance"
	world.scenery_tiles[Vector2i(22, 14)] = &"mine_mouth"
	for row in [[Vector2i(28, 49), &"banner"], [Vector2i(33, 49), &"brazier"],
		[Vector2i(31, 33), &"abbey_cross"], [Vector2i(27, 46), &"bench"],
		[Vector2i(29, 41), &"crate"],
		[Vector2i(17, 6), &"ore"], [Vector2i(27, 4), &"ore"],
		[Vector2i(35, 31), &"grape_basket"], [Vector2i(31, 35), &"banner"],
		[Vector2i(40, 43), &"dropped_bag"], [Vector2i(38, 36), &"brazier"],
		[Vector2i(11, 62), &"banner"], [Vector2i(77, 65), &"crate"]]:
		_block(world, row[0], row[1])
	for sign in [Vector2i(24, 52), Vector2i(26, 29), Vector2i(45, 49), Vector2i(13, 62)]:
		world.scenery_tiles[sign] = &"signpost"
	for tile in [Vector2i(9, 34), Vector2i(17, 33), Vector2i(22, 35),
		Vector2i(8, 40), Vector2i(18, 39), Vector2i(23, 40), Vector2i(10, 46),
		Vector2i(16, 50), Vector2i(21, 54), Vector2i(12, 55), Vector2i(35, 58),
		Vector2i(38, 53), Vector2i(39, 37), Vector2i(11, 25), Vector2i(17, 20),
		Vector2i(33, 18), Vector2i(39, 20), Vector2i(40, 29), Vector2i(8, 56),
		Vector2i(7, 60), Vector2i(28, 61), Vector2i(32, 64), Vector2i(39, 72),
		Vector2i(44, 76), Vector2i(58, 78), Vector2i(64, 76)]:
		_block(world, tile, &"broadleaf_tree")
	for tile in [Vector2i(16, 35), Vector2i(8, 49), Vector2i(18, 53),
		Vector2i(41, 33), Vector2i(64, 48), Vector2i(66, 54), Vector2i(74, 65)]:
		_block(world, tile, &"boulder")
	for tile in [Vector2i(10, 38), Vector2i(21, 42), Vector2i(14, 51),
		Vector2i(37, 60), Vector2i(25, 58), Vector2i(32, 27), Vector2i(60, 55)]:
		world.scenery_tiles[tile] = &"flowers"
	for tile in [Vector2i(13, 30), Vector2i(20, 21), Vector2i(36, 28),
		Vector2i(45, 55), Vector2i(66, 51), Vector2i(49, 77)]:
		world.scenery_tiles[tile] = &"small_rock"
	for tile in [Vector2i(6, 46), Vector2i(15, 41), Vector2i(19, 55)]:
		world.scenery_tiles[tile] = &"bush"
	# Sparse, passable tufts; the western woods have fewer than the open routes.
	for tile in [Vector2i(5, 47), Vector2i(13, 40), Vector2i(20, 55),
		Vector2i(27, 55), Vector2i(33, 59), Vector2i(36, 56), Vector2i(30, 30),
		Vector2i(21, 24), Vector2i(34, 23), Vector2i(37, 47), Vector2i(43, 51),
		Vector2i(48, 60), Vector2i(62, 62), Vector2i(64, 71), Vector2i(47, 75),
		Vector2i(69, 67), Vector2i(19, 61)]:
		world.scenery_tiles[tile] = &"grass"
	for x in [50, 54, 58]:
		for y in range(63, 75):
			world.ground_tiles[Vector2i(x, y)] = &"tilled_soil"
			if y not in [66, 70, 73]:
				_block(world, Vector2i(x, y), &"vine_trellis")
	world.sight_blockers.assign(world.blocked_tiles)


static func _creature(world: GridWorld, identity: int, tile: Vector2i, spawn_id: String) -> void:
	var creature := GridActor.new(tile)
	if identity in [299, 69, 6, 38]:
		creature.wander_area = Rect2i(tile - Vector2i(2, 2), Vector2i(5, 5))
	var data: Dictionary = NorthshireData.CREATURES[str(identity)]
	creature.npc_id = identity
	creature.title = String(data.title)
	creature.spawn_id = spawn_id
	creature.loot_table = identity
	creature.creature_type = "beast" if identity in [299, 69] else "humanoid"
	creature.relationship = (GridActor.Relationship.NEUTRAL if identity in [299, 69, 6]
		else GridActor.Relationship.HOSTILE)
	creature.aggro_range = 4
	creature.max_health = int(data.health)
	creature.health = creature.max_health
	creature.melee.level = int(data.level)
	creature.melee.armor = int(data.armor)
	creature.melee.damage_min = float(data.minimum)
	creature.melee.damage_max = float(data.maximum)
	creature.melee.attack_power = int(data.power)
	creature.melee.interval = float(data.interval)
	world.actors.append(creature)


static func _block(world: GridWorld, tile: Vector2i, sprite: StringName) -> void:
	world.blocked_tiles[tile] = true
	world.scenery_tiles[tile] = sprite


static func _door(world: GridWorld, tile: Vector2i, floor_sprite: StringName) -> void:
	world.blocked_tiles.erase(tile)
	world.scenery_tiles.erase(tile)
	world.ground_tiles[tile] = floor_sprite
	world.indoor_tiles[tile] = true


static func _building(world: GridWorld, rectangle: Rect2i,
	floor_sprite: StringName, wall_sprite: StringName) -> void:
	for y in range(rectangle.position.y, rectangle.end.y):
		for x in range(rectangle.position.x, rectangle.end.x):
			var tile := Vector2i(x, y)
			world.ground_tiles[tile] = floor_sprite
			world.indoor_tiles[tile] = true
			var edge := (x in [rectangle.position.x, rectangle.end.x - 1]
				or y in [rectangle.position.y, rectangle.end.y - 1])
			if edge:
				var sprite := wall_sprite
				if (wall_sprite == &"abbey_wall_straight"
					and y not in [rectangle.position.y, rectangle.end.y - 1]):
					sprite = &"abbey_wall_vertical"
				_block(world, tile, sprite)


static func _path(world: GridWorld, points: Array[Vector2i]) -> void:
	for index in range(points.size() - 1):
		var tile := points[index]
		var end := points[index + 1]
		while tile != end:
			for offset in [Vector2i.ZERO, Vector2i.RIGHT]:
				if not world.blocked_tiles.has(tile + offset):
					world.ground_tiles[tile + offset] = &"dirt_road"
			tile += (end - tile).sign()
