extends GutTest


func test_hidden_northeast_wall_passage_keeps_wall_art_and_connects_inside_to_outside() -> void:
	var world := ValleyRoute.create_world(619, false)
	world.actors.clear()
	world.stalker_schedule = false
	world.player_tile = Vector2i(32, 33)
	assert_eq(world.scenery_tiles[Vector2i(33, 32)], &"abbey_wall_straight")
	assert_true(world.move_player(Vector2i(1, -1)))
	assert_true(world.move_player(Vector2i(1, -1)))
	assert_eq(world.player_tile, Vector2i(34, 31))
	assert_true(world.blocked_tiles.has(Vector2i(32, 32)), "The adjacent wall stays solid.")
	# Actors were cleared only for the passage movement check.
	world = ValleyRoute.create_world(619, false)
	var milly := _actor(world, "fixed/9296")
	var shaman := _actor(world, "fixed/900002")
	assert_true(world.indoor_tiles.has(milly.tile))
	assert_lte(GridWorld.tile_distance(shaman.tile, Vector2i(31, 48)), 2)


func test_scene_placements_set_spawn_home_and_wandering_without_changing_loot_identity() -> void:
	var map := ValleyRoute.instantiate_map()
	var wolf: ValleyActorSpawn
	for marker in map.actor_spawns():
		if marker.npc_id == 299:
			wolf = marker
			break
	var identity := wolf.spawn_id
	wolf.position += Vector2(32, 0)
	map.get_node("PlayerSpawn").position += Vector2(0, 32)
	var world := map.create_world(619, false)
	var actor := _actor(world, identity)
	assert_eq(world.player_tile, map.player_spawn())
	assert_eq(actor.tile, wolf.tile())
	assert_eq(actor.home_tile, wolf.tile())
	assert_true(actor.wander_area.has_point(wolf.tile() + Vector2i(2, 2)))
	assert_false(actor.wander_area.has_point(wolf.tile() + Vector2i(3, 0)))
	assert_eq(actor.spawn_id, identity, "Dragging a placeholder preserves its seeded loot identity.")
	var original_order: Array[String] = []
	for existing in world.actors:
		original_order.append(existing.spawn_id)
	var markers := map.get_node("Actors")
	markers.move_child(wolf, markers.get_child_count() - 1)
	var reordered := map.create_world(619, false)
	var reordered_ids: Array[String] = []
	for existing in reordered.actors:
		reordered_ids.append(existing.spawn_id)
	assert_eq(reordered_ids, original_order, "Tree organization does not change action order.")
	map.free()


func test_painted_scenery_controls_movement_and_sight_and_floor_controls_indoors() -> void:
	var map := ValleyRoute.instantiate_map()
	var scenery := map.get_node("Terrain/Scenery") as TileMapLayer
	var tree := Vector2i(9, 34)
	var destination := Vector2i(30, 58)
	scenery.set_cell(destination, scenery.get_cell_source_id(tree),
		scenery.get_cell_atlas_coords(tree), scenery.get_cell_alternative_tile(tree))
	scenery.erase_cell(tree)
	var ground := map.get_node("Terrain/Ground") as TileMapLayer
	var floor := Vector2i(28, 42)
	var new_floor := Vector2i(31, 58)
	ground.set_cell(new_floor, ground.get_cell_source_id(floor),
		ground.get_cell_atlas_coords(floor), ground.get_cell_alternative_tile(floor))
	var world := map.create_world(619, false)
	world.actors.clear()
	world.stalker_schedule = false
	world.player_tile = destination + Vector2i.LEFT
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_false(world.has_sight(destination + Vector2i.LEFT, destination + Vector2i.RIGHT))
	assert_true(world.is_open(tree), "Erasing the tree removes its collision.")
	assert_true(world.has_sight(tree + Vector2i.UP, tree + Vector2i.DOWN))
	assert_eq(world.scenery_tiles[destination], &"broadleaf_tree")
	assert_true(world.indoor_tiles.has(new_floor))
	map.free()


func test_contact_and_treasure_placements_override_definitions_and_remain_saved() -> void:
	var map := ValleyRoute.instantiate_map()
	var contact: ValleyActorSpawn
	var chest: ValleyActorSpawn
	for marker in map.actor_spawns():
		if marker.npc_id == NpcDefinition.MARSHAL_ID:
			contact = marker
		if marker.treasure_id == "mine_chest":
			chest = marker
	contact.position += Vector2(0, 32)
	chest.position += Vector2(32, 0)
	var session := GameSession.new()
	session.seed_value = 619
	session.world = map.create_world(619, false)
	session.world.class_selected = true
	assert_eq(_actor(session.world, contact.spawn_id).tile, contact.tile())
	assert_eq(_actor(session.world, contact.spawn_id).service, &"Marshal")
	assert_eq(_actor(session.world, chest.spawn_id).tile, chest.tile())
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(_actor(restored, contact.spawn_id).tile, contact.tile())
		assert_eq(_actor(restored, chest.spawn_id).tile, chest.tile())
		assert_eq(_actor(restored, chest.spawn_id).spawn_id, chest.spawn_id)
	map.free()


func test_scene_defines_arrival_and_exploration_locations() -> void:
	var map := ValleyRoute.instantiate_map()
	var entry := map.get_node("StalkerEntries/Entry1") as Marker2D
	entry.position += Vector2(32, 0)
	var region := map.get_node("Exploration/Mine") as ValleyRegion
	region.position += Vector2(0, 32)
	region.size_tiles += Vector2i(1, 0)
	var info := map.layout_info()
	assert_eq(info.entries[0], map.marker_tile(entry))
	assert_eq(info.exploration.mine, region.tile_bounds())
	assert_true(info.exploration.mine.has_point(region.tile_bounds().end - Vector2i.ONE))
	assert_false(info.exploration.mine.has_point(region.tile_bounds().end))
	map.free()


func test_all_starting_actors_have_distinct_persistent_ids_and_turn_order() -> void:
	var map := ValleyRoute.instantiate_map()
	var identities: Array[String] = []
	var orders: Array[int] = []
	for marker in map.actor_spawns():
		assert_ne(marker.spawn_id, "")
		assert_false(identities.has(marker.spawn_id), marker.name)
		assert_false(orders.has(marker.turn_order), marker.name)
		identities.append(marker.spawn_id)
		orders.append(marker.turn_order)
	map.free()


func _actor(world: GridWorld, identity: String) -> GridActor:
	for actor in world.actors:
		if actor.spawn_id == identity:
			return actor
	return null
