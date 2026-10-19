class_name ValleyMap
extends Node2D

## Layout only. The scene is read on New Game / Loop reset, then freed.
@export var bounds := Rect2i(0, 0, 84, 82)
@export var stalker_deadlines: Array[int] = [25, 800, 980, 1140, 1280]


func create_world(seed_value: int, development_build: bool) -> GridWorld:
	var world := GridWorld.new(bounds, player_spawn(), seed_value, development_build)
	world.northshire = true
	world.valley_route = true
	world.stalker_schedule = true
	world.stalker_deadlines = stalker_deadlines.duplicate()
	InventoryRules.add(world.hero.inventory,
		ItemData.instance(GridWorld.SPAWN_FOOD_ID, GridWorld.SPAWN_FOOD_QUANTITY))
	world.hotbar[GridWorld.HOTBAR_SIZE - 1] = GridWorld.FOOD_HOTBAR_ID
	apply_terrain(world)
	populate(world)
	world.vendor_stock = MerchantData.initial_stock(world.actors)
	return world


func player_spawn() -> Vector2i:
	return marker_tile(get_node("PlayerSpawn"))


func actor_spawns() -> Array[ValleyActorSpawn]:
	var result: Array[ValleyActorSpawn] = []
	for child in get_node("Actors").get_children():
		result.append(child as ValleyActorSpawn)
	result.sort_custom(func(a: ValleyActorSpawn, b: ValleyActorSpawn) -> bool:
		return a.turn_order < b.turn_order)
	return result


func stalker_entries() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for child in get_node("StalkerEntries").get_children():
		result.append(marker_tile(child))
	return result


func apply_terrain(world: GridWorld) -> void:
	world.blocked_tiles.clear()
	world.sight_blockers.clear()
	world.ground_tiles.clear()
	world.scenery_tiles.clear()
	world.indoor_tiles.clear()
	for layer: TileMapLayer in get_node("Terrain").get_children():
		for tile in layer.get_used_cells():
			var data := layer.get_cell_tile_data(tile)
			if data.get_custom_data("blocked"):
				world.blocked_tiles[tile] = true
			if data.get_custom_data("indoors"):
				world.indoor_tiles[tile] = true
			var sprite := StringName(data.get_custom_data("sprite"))
			if sprite != &"":
				if layer.name == &"Ground":
					world.ground_tiles[tile] = sprite
				else:
					world.scenery_tiles[tile] = sprite
	world.sight_blockers.assign(world.blocked_tiles)


func populate(world: GridWorld) -> void:
	for marker in actor_spawns():
		world.actors.append(marker.create_actor())


## Plain values only; callers may cache them without retaining scene nodes.
func layout_info() -> Dictionary:
	var contacts: Dictionary[int, Vector2i] = {}
	var chests: Dictionary = {}
	for marker in actor_spawns():
		if marker.treasure_id != "":
			chests[marker.treasure_id] = {"tile": marker.tile(), "hint": marker.treasure_hint}
		elif NpcDefinition.find(marker.npc_id) != null:
			contacts[marker.npc_id] = marker.tile()
	var exploration: Dictionary = {}
	for region: ValleyRegion in get_node("Exploration").get_children():
		exploration[String(region.location_id)] = region.tile_bounds()
	return {"bounds": bounds, "spawn": player_spawn(), "entries": stalker_entries(),
		"contacts": contacts, "chests": chests, "exploration": exploration,
		"deadlines": stalker_deadlines.duplicate()}


func marker_tile(marker: Node2D) -> Vector2i:
	return Vector2i((marker.position / 32.0).floor())
