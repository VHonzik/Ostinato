extends GutTest


func test_outdoor_enemies_wander_locally_while_mine_and_named_enemies_stay_put() -> void:
	var world := _session().world
	for actor in world.actors:
		if actor.npc_id in [299, 69, 6, 38]:
			var visited: Dictionary[Vector2i, bool] = {actor.tile: true}
			for turn in range(40):
				world.turn_count = turn
				world._wander(actor)
				visited[actor.tile] = true
				assert_true(actor.wander_area.has_point(actor.tile), actor.title)
			assert_gt(visited.size(), 1, actor.title)
		else:
			assert_false(actor.wander_area.has_area(), actor.title)
	world._spawn_stalker(ValleyRoute.STALKER_ENTRIES[0])
	assert_false(world.actors[-1].wander_area.has_area())
	for wolf in ValleyRoute.WOLVES:
		assert_gt(GridWorld.tile_distance(wolf, ValleyRoute.STALKER_ENTRIES[0]), 10)


func test_exploration_credits_mine_entrance_vineyard_approach_and_wolf_area_without_chests() -> void:
	var world := _session().world
	var deputy := _actor(world, 823)
	_beside(world, deputy)
	assert_true(QuestRules.accept(world, "valley_explore", deputy))
	world.player_tile = Vector2i(22, 15)
	QuestRules.visit(world)
	assert_eq(QuestRules.progress(world, "valley_explore", 0), 0)
	for index in range(3):
		world.player_tile = [Vector2i(22, 13), Vector2i(44, 60), Vector2i(19, 48)][index]
		QuestRules.visit(world)
		assert_eq(QuestRules.progress(world, "valley_explore", index), 1)
	assert_true(QuestRules.ready(world, "valley_explore"))
	assert_true(world.actors.filter(func(actor: GridActor) -> bool:
		return actor.chest).all(func(chest: GridActor) -> bool: return not chest.loot_assigned))


func test_closed_chest_blocks_then_bump_collects_loot_without_stepping_inside() -> void:
	var session := _session()
	var world := session.world
	var chest: GridActor = world.actors.filter(func(actor: GridActor) -> bool:
		return actor.chest)[0]
	world.player_tile = chest.tile + Vector2i.DOWN
	assert_false(world.is_open(chest.tile))
	var before := world.player_tile
	assert_false(world.move_player(Vector2i.UP))
	assert_eq(world.player_tile, before)
	assert_true(chest.loot_assigned)
	assert_true(chest.loot.is_empty())
	assert_eq(chest.loot_copper, 0)
	assert_gt(world.hero.copper, 0)
	assert_true(world.is_open(chest.tile))
	assert_true(world.move_player(Vector2i.UP))
	assert_eq(world.player_tile, chest.tile)


func test_bumping_chest_with_full_bags_preserves_items_for_later() -> void:
	var world := _session().world
	var chest: GridActor = world.actors.filter(func(actor: GridActor) -> bool:
		return actor.chest)[0]
	world.player_tile = chest.tile + Vector2i.DOWN
	world.hero.inventory.fill(ItemData.instance(35))
	assert_false(world.move_player(Vector2i.UP))
	assert_false(chest.loot.is_empty())
	assert_true(chest.corpse_visible)
	var contents := chest.loot.duplicate(true)
	world.hero.inventory[0] = {}
	assert_true(world.move_player(Vector2i.UP), "An opened chest is passable.")
	assert_true(chest.loot.is_empty())
	assert_eq(world.hero.inventory[0], contents[0])


func _session() -> GameSession:
	var session := GameSession.new()
	session.new_game(619)
	return session


func _marshal(world: GridWorld) -> GridActor:
	return _actor(world, 197)


func _actor(world: GridWorld, identity: int) -> GridActor:
	for actor in world.actors:
		if actor.npc_id == identity:
			return actor
	return null


func _beside(world: GridWorld, contact: GridActor) -> void:
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(contact.tile + direction):
			world.player_tile = contact.tile + direction
			return
	fail_test("Contact needs a free neighboring tile.")


func test_spawn_can_reach_contacts_encounters_and_connected_abbey_rooms() -> void:
	var world := _session().world
	for actor in world.actors:
		assert_true(world._terrain_open(actor.tile), actor.title)
		var goals: Array[Vector2i] = []
		for direction in GridWorld.DIRECTIONS:
			if world._terrain_open(actor.tile + direction):
				goals.append(actor.tile + direction)
		assert_false(world._route(world.player_tile, goals, false, actor.tile).is_empty(), actor.title)
	world.player_tile = Vector2i(31, 49)
	assert_true(world.move_player(Vector2i.UP), "South entrance is walkable.")
	assert_true(world.move_player(Vector2i.UP))
	assert_true(world.indoor_tiles.has(world.player_tile))
	for destination in [Vector2i(32, 35), Vector2i(39, 43)]:
		var goals: Array[Vector2i] = [destination]
		assert_false(world._route(world.player_tile, goals, false, destination).is_empty())
	world.player_tile = Vector2i(31, 49)
	assert_false(world.move_player(Vector2i(1, -1)), "A neighboring wall blocks entry.")
	assert_false(world.has_sight(Vector2i(32, 49), Vector2i(32, 47)))
	world.player_tile = Vector2i(9, 35)
	assert_false(world.move_player(Vector2i.UP), "Tree tiles block movement.")
	assert_false(world.has_sight(Vector2i(9, 35), Vector2i(9, 33)))
	var outside: Array[Vector2i] = [Vector2i.ZERO, Vector2i(83, 30), Vector2i(30, 81)]
	for destination in outside:
		var goals: Array[Vector2i] = [destination]
		assert_true(world._route(ValleyRoute.SPAWN, goals, false, destination).is_empty(),
			"The valley perimeter stays closed away from the gate road.")


func test_patrol_can_be_completed_and_handed_in_once() -> void:
	var world := _session().world
	world.player_tile = NpcDefinition.find(NpcDefinition.MARSHAL_ID).tile + Vector2i.DOWN
	assert_true(QuestRules.available(world, "valley_patrol"))
	assert_false(QuestRules.available(world, "783"), "Do not offer quests into unbuilt branches.")
	assert_true(QuestRules.accept(world, "valley_patrol", _marshal(world)))
	for actor in world.actors:
		if actor.npc_id == 299:
			actor.health = 0
			world._check_npc_death(actor, world.turn_count)
			world._check_npc_death(actor, world.turn_count)
	assert_eq(QuestRules.progress(world, "valley_patrol", 0), 8)
	assert_true(QuestRules.ready(world, "valley_patrol"))
	assert_true(QuestRules.hand_in(world, "valley_patrol", _marshal(world)))
	assert_false(QuestRules.hand_in(world, "valley_patrol", _marshal(world)))


func test_route_save_preserves_art_dead_wolves_quest_and_seeded_continuation() -> void:
	var session := _session()
	var world := session.world
	world.player_tile = NpcDefinition.find(NpcDefinition.MARSHAL_ID).tile + Vector2i.DOWN
	QuestRules.accept(world, "valley_patrol", _marshal(world))
	var wolf := _actor(world, 299)
	wolf.health = 0
	world._check_npc_death(wolf, 0)
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), true)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(restored.valley_route)
	assert_eq(restored.ground_tiles, world.ground_tiles)
	assert_eq(restored.scenery_tiles, world.scenery_tiles)
	assert_false(_actor(restored, 299).alive)
	var copy := GameSession.new()
	copy.restore(restored, session.seed_value, session.loop_count)
	assert_eq(JSON.stringify(SaveCodec.capture(copy)), JSON.stringify(snapshot))
	for turn in range(40):
		world.wait_turn()
		restored.wait_turn()
	assert_eq(JSON.stringify(SaveCodec.capture(copy)), JSON.stringify(SaveCodec.capture(session)))
	assert_false(_actor(restored, 299).alive, "No wolf respawn after thirty turns.")
	assert_eq(restored.stalkers_arrived, 1, "The gate encounter happens early without reaching the patrol.")


func test_death_rebuilds_the_same_route_with_learning_and_fresh_encounters() -> void:
	var session := _session()
	var before := session.world
	before.player_tile = NpcDefinition.find(NpcDefinition.MARSHAL_ID).tile + Vector2i.DOWN
	QuestRules.accept(before, "valley_patrol", _marshal(before))
	_actor(before, 299).health = 0
	before._check_npc_death(_actor(before, 299), 0)
	before.actors[1].health = 0
	before._check_npc_death(before.actors[1], 0)
	before.turn_count = 40
	before.wait_turn()
	assert_false(before.actors[1].alive)
	before.hotbar[2] = &"fireball_1"
	var learning := before.hero.learned_skills.duplicate()
	before.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.loop_count, 2)
	assert_true(session.world.valley_route)
	assert_eq(session.world.player_tile, ValleyRoute.SPAWN)
	assert_eq(session.world.hero.learned_skills, learning)
	assert_eq(session.world.hotbar[2], &"fireball_1")
	assert_eq(session.world.quests, {})
	assert_true(session.world.actors.all(func(actor: GridActor) -> bool: return actor.chest or actor.alive))
	assert_eq(_actor(session.world, 299).tile, ValleyRoute.WOLVES[0])


func test_non_valley_codec_snapshots_need_no_route_marker() -> void:
	var session := GameSession.new()
	session.world = GridWorld.new(Rect2i(0, 0, 8, 8), Vector2i(4, 4), 619)
	var snapshot := SaveCodec.capture(session)
	snapshot.erase("valley_route")
	var restored := SaveCodec.restore(snapshot, true)
	assert_not_null(restored)
	if restored != null:
		assert_false(restored.valley_route)
	var route := SaveCodec.capture(_session())
	route.valley_route = "yes"
	assert_null(SaveCodec.restore(route, true))
	route.valley_route = true
	route.world.bounds = [0, 0, 56, 44]
	assert_null(SaveCodec.restore(route, true))


func test_patrol_ignores_wolves_cleared_before_the_first_conversation() -> void:
	var world := _session().world
	for actor in world.actors:
		if actor.npc_id == 299:
			actor.health = 0
			world._check_npc_death(actor, 0)
	world.player_tile = NpcDefinition.find(NpcDefinition.MARSHAL_ID).tile + Vector2i.DOWN
	assert_true(QuestRules.accept(world, "valley_patrol", _marshal(world)))
	assert_false(QuestRules.ready(world, "valley_patrol"))
	assert_true(QuestRules.abandon(world, "valley_patrol"))
	assert_true(QuestRules.accept(world, "valley_patrol", _marshal(world)))
	assert_false(QuestRules.hand_in(world, "valley_patrol", _marshal(world)))


func test_all_landmarks_and_loot_sources_are_reachable_without_overlapping_live_spawns() -> void:
	var world := _session().world
	var occupied: Array[Vector2i] = []
	for actor in world.actors:
		if actor.alive:
			assert_false(occupied.has(actor.tile), actor.title)
			occupied.append(actor.tile)
	for landmark: ValleyLandmarks.Landmark in ValleyLandmarks.CHESTS.values():
		var destination := landmark.tile
		assert_true(world._terrain_open(destination))
		var goals: Array[Vector2i] = [destination]
		assert_false(world._route(ValleyRoute.SPAWN, goals, false, destination).is_empty())
	for entry in ValleyRoute.STALKER_ENTRIES:
		var goals: Array[Vector2i] = [ValleyRoute.SPAWN + Vector2i.DOWN]
		assert_true(world._terrain_open(entry))
		assert_false(world._route(entry, goals, false, ValleyRoute.SPAWN).is_empty(),
			"The gate road connects the arrival to the valley.")


func test_finite_branches_ignore_kills_after_exploration_and_abandonment() -> void:
	var session := _session()
	var world := session.world
	world.hero.add_experience(400)
	for actor in world.actors:
		if actor.relationship != GridActor.Relationship.FRIENDLY:
			actor.health = 0
			world._check_npc_death(actor, 0)
	for identifier in ["valley_camp", "valley_mine", "valley_vineyard"]:
		var giver := _actor(world, int(QuestData.QUESTS[identifier].giver))
		_beside(world, giver)
		assert_true(QuestRules.accept(world, identifier, giver))
		assert_false(QuestRules.ready(world, identifier))
		assert_true(QuestRules.abandon(world, identifier))
		assert_true(QuestRules.accept(world, identifier, giver))
		assert_false(QuestRules.hand_in(world, identifier, giver))
		assert_false(QuestRules.hand_in(world, identifier, giver))
	world.stalker_schedule = false
	world.turn_count = 1000
	world.wait_turn()
	assert_false(world.actors.any(func(actor: GridActor) -> bool:
		return actor.alive and actor.relationship == GridActor.Relationship.HOSTILE))


func test_exploration_credits_destinations_independently_and_never_rolls_chests_again() -> void:
	var world := _session().world
	var deputy := _actor(world, 823)
	_beside(world, deputy)
	assert_true(QuestRules.accept(world, "valley_explore", deputy))
	for destination in ValleyLandmarks.EXPLORATION:
		world.player_tile = ValleyLandmarks.EXPLORATION[destination].get_center()
		QuestRules.visit(world)
		QuestRules.visit(world)
	assert_true(QuestRules.ready(world, "valley_explore"))
	_beside(world, deputy)
	assert_true(QuestRules.hand_in(world, "valley_explore", deputy))
	var chest: GridActor = world.actors.filter(func(actor: GridActor) -> bool: return actor.chest)[0]
	_beside(world, chest)
	assert_true(world.open_loot(chest))
	var contents := chest.loot.duplicate(true)
	var copper := chest.loot_copper
	assert_true(world.loot_all(chest))
	assert_false(world.open_loot(chest), "An emptied chest leaves the interaction list.")
	LootData.assign(world, chest)
	assert_true(chest.loot.is_empty())
	assert_eq(chest.loot_copper, 0)
	var other := _session().world
	var same: GridActor = other.actors.filter(func(actor: GridActor) -> bool: return actor.chest)[0]
	LootData.assign(other, same)
	assert_eq(same.loot, contents)
	assert_eq(same.loot_copper, copper)


func test_stalker_uses_the_southwestern_gate_and_survives_save_roundtrip() -> void:
	var session := _session()
	var world := session.world
	world.turn_count = world.stalker_deadlines[0] - 1
	world._arrive_stalker()
	assert_eq(world.stalkers_arrived, 0)
	world.wait_turn()
	assert_eq(world.stalkers_arrived, 1)
	assert_eq(world.actors[-1].tile, ValleyRoute.STALKER_ENTRIES[0])
	var guard := _actor(world, 1642)
	assert_false(guard.alive)
	var death_turn := guard.died_on_turn
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), true)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.stalker_deadlines, world.stalker_deadlines)
	assert_eq(restored.actors[-1].spawn_id, world.actors[-1].spawn_id)
	assert_eq(restored.actors[-1].health, 600)
	assert_eq(restored.actors[-1].melee.level, 8)
	assert_eq(restored.actors[-1].melee.armor, 240)
	assert_eq(restored.actors[-1].melee.damage_min, 14.0)
	assert_eq(restored.actors[-1].melee.damage_max, 18.0)
	assert_eq(restored.actors[-1].melee.attack_power, 0)
	assert_eq(restored.actors[-1].melee.interval, 2.5)
	world.turn_count = world.stalker_deadlines[1]
	restored.turn_count = restored.stalker_deadlines[1]
	world._arrive_stalker()
	restored._arrive_stalker()
	assert_eq(restored.stalkers_arrived, 2)
	assert_eq(restored.actors[-1].tile, world.actors[-1].tile)
	world.wait_turn()
	assert_false(guard.alive)
	assert_eq(guard.died_on_turn, death_turn, "Reinforcements do not repeat the guard death.")


func test_blocked_gate_retries_an_overdue_arrival_without_moving_its_deadline() -> void:
	var world := _session().world
	for entry in ValleyRoute.STALKER_ENTRIES:
		world.blocked_tiles[entry] = true
	world.turn_count = world.stalker_deadlines[0]
	world._arrive_stalker()
	assert_eq(world.stalkers_arrived, 0)
	var due := world.stalker_deadlines[0]
	world.blocked_tiles.erase(ValleyRoute.STALKER_ENTRIES[2])
	world._arrive_stalker()
	assert_eq(world.stalkers_arrived, 1)
	assert_eq(world.actors[-1].tile, ValleyRoute.STALKER_ENTRIES[2])
	assert_eq(world.stalker_deadlines[0], due)


func test_encounters_have_spare_wolves_for_both_quests_and_fourteen_kobolds() -> void:
	var world := _session().world
	assert_eq(world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id == 299).size(),
		int(QuestData.QUESTS.valley_patrol.objectives[0].count) + 3)
	assert_eq(world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id == 69).size(),
		int(QuestData.QUESTS.valley_timber_wolves.objectives[0].count) + 3)
	assert_eq(world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id in [6, 257, 80]).size(), 14)


func test_quest_marker_tracks_availability_completion_and_dead_contacts() -> void:
	var world := _session().world
	var milly := _actor(world, 9296)
	assert_false(QuestRules.has_marker(world, milly), "Level-locked quests stay hidden.")
	world.hero.level = 10
	assert_true(QuestRules.has_marker(world, milly))
	_beside(world, milly)
	assert_true(QuestRules.accept(world, "valley_vineyard", milly))
	assert_false(QuestRules.has_marker(world, milly), "Unfinished objectives are not a turn-in.")
	for identity in ["38", "38", "38", "38", "103"]:
		QuestRules.record_kill(world, int(identity))
	assert_true(QuestRules.has_marker(world, milly))
	assert_true(QuestRules.hand_in(world, "valley_vineyard", milly))
	assert_false(QuestRules.has_marker(world, milly))
	var marshal := _marshal(world)
	assert_true(QuestRules.has_marker(world, marshal))
	marshal.alive = false
	assert_false(QuestRules.has_marker(world, marshal))


func test_quest_blink_uses_presentation_seconds_without_spending_turns() -> void:
	var view := GridView.new()
	view.world = _session().world
	view._process(1.9)
	assert_false(view._blink_alternate_visible)
	view._process(0.1)
	assert_true(view._blink_alternate_visible)
	view._process(2.0)
	assert_false(view._blink_alternate_visible)
	view._process(6.0)
	assert_true(view._blink_alternate_visible, "Long frames retain the two-second phase.")
	assert_eq(view.world.turn_count, 0)
	view.free()


func test_neutral_wolves_and_kobolds_only_retaliate_after_attack_and_reset_neutral() -> void:
	for identity in [299, 69, 6]:
		var session := _session()
		var world := session.world
		for actor in world.actors:
			if actor.npc_id in [299, 69, 6]:
				assert_eq(actor.relationship, GridActor.Relationship.NEUTRAL, actor.title)
				assert_false(actor.engaged)
		assert_eq(_actor(world, 257).relationship, GridActor.Relationship.HOSTILE)
		var enemy := _actor(world, identity)
		world.actors.assign([enemy])
		_beside(world, enemy)
		var player_health := world.hero.health
		for turn in range(3):
			world.wait_turn()
		assert_eq(world.hero.health, player_health, "Proximity does not provoke " + enemy.title)
		assert_true(enemy.wander_area.has_point(enemy.tile))
		_beside(world, enemy)
		assert_false(enemy.engaged)
		assert_true(world.request_melee(enemy))
		assert_eq(enemy.relationship, GridActor.Relationship.HOSTILE)
		assert_true(enemy.engaged, "An explicit attack still provokes retaliation.")
		world.hero.health = 0
		assert_true(session.restart_after_death())
		assert_eq(_actor(session.world, identity).relationship, GridActor.Relationship.NEUTRAL)


func test_mine_kobolds_engage_on_proximity_and_reset_hostile_each_loop() -> void:
	var session := _session()
	var world := session.world
	var laborer := _actor(world, 80)
	assert_eq(laborer.relationship, GridActor.Relationship.HOSTILE)
	world.actors.assign([laborer])
	_beside(world, laborer)
	world.wait_turn()
	assert_true(laborer.engaged)
	world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(_actor(session.world, 80).relationship, GridActor.Relationship.HOSTILE)
	assert_eq(_actor(session.world, 257).relationship, GridActor.Relationship.HOSTILE)


func test_save_preserves_unprovoked_and_provoked_wolf_relationships() -> void:
	var session := _session()
	var world := session.world
	var wolf := _actor(world, 299)
	var restored := SaveCodec.restore(SaveCodec.capture(session), true)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(_actor(restored, 299).relationship, GridActor.Relationship.NEUTRAL)
	_beside(world, wolf)
	assert_true(world.request_melee(wolf))
	restored = SaveCodec.restore(SaveCodec.capture(session), true)
	assert_not_null(restored)
	if restored != null:
		assert_eq(_actor(restored, 299).relationship, GridActor.Relationship.HOSTILE)
		assert_true(_actor(restored, 299).engaged)


func test_wolf_chain_uses_separate_species_same_contact_and_survives_save_and_abandonment() -> void:
	var session := _session()
	var world := session.world
	var marshal := _marshal(world)
	_beside(world, marshal)
	assert_false(QuestRules.available(world, "valley_timber_wolves"))
	assert_false(QuestRules.accept(world, "valley_timber_wolves", marshal))
	# Only kills after accepting the follow-up count.
	var timber := _actor(world, 69)
	timber.health = 0
	world._check_npc_death(timber, 0)
	assert_true(QuestRules.accept(world, "valley_patrol", marshal))
	assert_eq(QuestRules.progress(world, "valley_patrol", 0), 0)
	for count in range(8):
		var young: GridActor = world.actors.filter(func(actor: GridActor) -> bool:
			return actor.npc_id == 299 and actor.alive)[0]
		young.health = 0
		world._check_npc_death(young, 0)
	assert_true(QuestRules.ready(world, "valley_patrol"))
	assert_false(QuestRules.available(world, "valley_timber_wolves"), "Hand in the first step.")
	assert_true(QuestRules.hand_in(world, "valley_patrol", marshal))
	assert_true(QuestRules.available(world, "valley_timber_wolves"))
	assert_true(QuestRules.accept(world, "valley_timber_wolves", marshal))
	assert_eq(QuestRules.progress(world, "valley_timber_wolves", 0), 0)
	assert_false(QuestRules.ready(world, "valley_timber_wolves"), "Young wolves do not count twice.")
	for count in range(4):
		timber = world.actors.filter(func(actor: GridActor) -> bool:
			return actor.npc_id == 69 and actor.alive)[0]
		timber.health = 0
		world._check_npc_death(timber, 0)
		world._check_npc_death(timber, 0)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), true)
	assert_not_null(restored)
	if restored == null:
		return
	world = restored
	marshal = _marshal(world)
	assert_eq(QuestRules.progress(world, "valley_timber_wolves", 0), 4)
	assert_true(QuestRules.abandon(world, "valley_timber_wolves"))
	assert_true(QuestRules.accept(world, "valley_timber_wolves", marshal))
	assert_eq(QuestRules.progress(world, "valley_timber_wolves", 0), 0)
	# Abandoning discards kill credit; this finite encounter can no longer be completed.
	timber = world.actors.filter(func(actor: GridActor) -> bool:
		return actor.npc_id == 69 and actor.alive)[0]
	timber.health = 0
	world._check_npc_death(timber, 0)
	assert_false(QuestRules.hand_in(world, "valley_timber_wolves", marshal))
	assert_false(QuestRules.hand_in(world, "valley_timber_wolves", marshal))
	for identity in [299, 69]:
		assert_eq(world.actors.filter(func(actor: GridActor) -> bool:
			return actor.npc_id == identity and actor.alive).size(), 3 if identity == 299 else 2)


func test_tile_sprite_priority_hides_terrain_and_corpses_without_removing_them() -> void:
	var view := GridView.new()
	view.world = GridWorld.new(Rect2i(0, 0, 8, 8), Vector2i.ZERO)
	var world := view.world
	var tile := Vector2i(2, 2)
	world.ground_tiles[tile] = &"dirt_road"
	world.scenery_tiles[tile] = &"grass"
	assert_eq(view._terrain_sprite(tile, view._sprite_occupants()), &"grass")
	var first := GridActor.new(tile)
	first.alive = false
	var second := GridActor.new(tile)
	second.alive = false
	world.actors.assign([first, second])
	assert_same(view._sprite_occupants()[tile], first, "Stacked corpses show one sprite.")
	assert_eq(view._terrain_sprite(tile, view._sprite_occupants()), &"")
	first.corpse_visible = false
	assert_same(view._sprite_occupants()[tile], second)
	var living := GridActor.new(tile)
	world.actors.append(living)
	assert_same(view._sprite_occupants()[tile], living, "Living actors cover corpses.")
	world.actors.reverse()
	assert_same(view._sprite_occupants()[tile], living, "Priority is independent of spawn order.")
	world.player_tile = tile
	assert_false(view._sprite_occupants().has(tile), "The player covers every other occupant.")
	assert_eq(view._terrain_sprite(tile, view._sprite_occupants()), &"")
	world.player_tile = Vector2i.ZERO
	living.tile = Vector2i(3, 2)
	second.corpse_visible = false
	assert_eq(view._terrain_sprite(tile, view._sprite_occupants()), &"grass")
	assert_eq(world.actors.size(), 3, "Rendering does not delete actors or loot.")
	assert_true(world.scenery_tiles.has(tile), "Grass reappears when the tile becomes empty.")
	world.scenery_tiles.erase(tile)
	assert_eq(view._terrain_sprite(tile, view._sprite_occupants()), &"dirt_road")
	view.free()


func test_base_health_tints_include_seventy_five_and_twenty_percent_boundaries() -> void:
	var cases := [
		[101, 100, Color.WHITE], [100, 100, Color.WHITE],
		[99, 100, Color.WHITE], [75, 100, Color.WHITE],
		[74, 100, Color.YELLOW], [21, 100, Color.YELLOW],
		[20, 100, Color.RED], [0, 100, Color.RED],
		[51, 51, Color.WHITE], [50, 51, Color.WHITE],
		[39, 51, Color.WHITE], [38, 51, Color.YELLOW],
		[11, 51, Color.YELLOW], [10, 51, Color.RED],
		[5, 5, Color.WHITE], [2, 5, Color.YELLOW], [1, 5, Color.RED],
	]
	for entry: Array in cases:
		assert_eq(GridView.health_tint(entry[0], entry[1]), entry[2],
			"%d/%d HP" % [entry[0], entry[1]])


func test_faction_tints_stay_independent_of_health_and_quest_blink_phase() -> void:
	var view := GridView.new()
	view.world = _session().world
	var enemy := _actor(view.world, 299)
	var neutral_color := view._actor_color(enemy)
	enemy.relationship = GridActor.Relationship.HOSTILE
	var hostile_color := view._actor_color(enemy)
	assert_ne(neutral_color, hostile_color)
	enemy.max_health = 100
	for health in [100, 99, 21, 20, 1]:
		enemy.health = health
		assert_eq(view._actor_color(enemy), hostile_color)
		view._process(2.0)
		assert_eq(view._actor_color(enemy), hostile_color)
	view.alternate_palette = true
	assert_eq(view._actor_color(enemy), Color("#D55E00"))
	enemy.relationship = GridActor.Relationship.NEUTRAL
	assert_eq(view._actor_color(enemy), Color("#F0E442"))
	enemy.relationship = GridActor.Relationship.FRIENDLY
	assert_eq(view._actor_color(enemy), Color("#9acd95"))
	assert_eq(view.world.turn_count, 0, "Rendering never advances gameplay time.")
	view.free()


func test_all_npc_kinds_get_two_layers_and_players_keep_current_art_with_empty_faction() -> void:
	var view := GridView.new()
	add_child_autofree(view)
	view.world = _session().world
	var actors: Array[GridActor] = view.world.actors.duplicate()
	for kind in ["", "pet", "earth", "fire"]:
		var actor := GridActor.new(Vector2i.ZERO)
		actor.npc_id = 416 if kind == "pet" else 0
		actor.summon_kind = kind
		actors.append(actor)
	var stalker := GridActor.new(Vector2i.ZERO)
	stalker.stalker = true
	actors.append(stalker)
	for actor in actors:
		if not actor.alive:
			continue
		var sprites := view.npc_sprite_layers(actor)
		assert_same(sprites.base_sprite, GridView.NPC_BASE_SPRITE, actor.title)
		assert_not_null(sprites.faction_sprite, actor.title)
	var wolf := view.npc_sprite_layers(_actor(view.world, 299)).faction_sprite as AtlasTexture
	assert_same(wolf.atlas, GridView.CHARACTERS)
	assert_eq(wolf.region, Rect2(112, 64, 16, 16), "The current wolf art becomes its faction layer.")
	for category in GridView.CLASS_SPRITES:
		var sprites := view.player_sprite_layers(category)
		assert_not_null(sprites.base_sprite, category)
		assert_null(sprites.faction_sprite, category)
	var warrior := view.player_sprite_layers(&"Warrior").base_sprite as AtlasTexture
	assert_same(warrior.atlas, GridView.CHARACTERS)
	assert_eq(warrior.region, Rect2(32, 0, 16, 16), "The current player art becomes its base layer.")


func test_health_changes_reach_npc_and_player_base_layers_without_changing_faction() -> void:
	var view := RecordingGridView.new()
	add_child_autofree(view)
	view.world = _session().world
	var enemy := _actor(view.world, 299)
	enemy.max_health = 100
	view.world.hero.max_health = 100
	var faction := view.npc_sprite_layers(enemy).faction_sprite
	var player := view.player_sprite_layers(&"Warrior").base_sprite
	for entry: Array in [[100, Color.WHITE], [99, Color.WHITE], [74, Color.YELLOW], [20, Color.RED],
		[21, Color.YELLOW], [100, Color.WHITE]]:
		enemy.health = entry[0]
		view.world.hero.health = entry[0]
		view._draw_actor(enemy)
		assert_eq(view.drawn_base_color, entry[1])
		assert_same(view.drawn_faction, faction)
		assert_eq(view.drawn_faction_color, view._actor_color(enemy))
		view._draw_player()
		assert_same(view.drawn_base, player)
		assert_eq(view.drawn_base_color, entry[1])
		assert_null(view.drawn_faction)
	# Later art can replace either texture without changing the actor state.
	view.npc_sprites[&"wolf"] = ActorSpriteLayers.new(player, faction)
	view._draw_actor(enemy)
	assert_same(view.drawn_base, player)
	assert_same(view.drawn_faction, faction)


func test_quest_marker_alternates_faction_layer_while_injured_base_stays_visible() -> void:
	var view := RecordingGridView.new()
	add_child_autofree(view)
	view.world = _session().world
	var marshal := _marshal(view.world)
	assert_true(QuestRules.has_marker(view.world, marshal))
	marshal.health = 1
	view._draw_actor(marshal)
	var base := view.drawn_base
	var faction := view.drawn_faction
	assert_eq(view.drawn_base_color, Color.RED)
	view._process(2.0)
	view._draw_actor(marshal)
	assert_same(view.drawn_base, base)
	assert_same(view.drawn_faction, view._quest_marker_sprite)
	assert_eq(view.drawn_base_color, Color.RED)
	assert_eq(view.drawn_faction_color, Color("#9acd95"))
	view._process(2.0)
	view._draw_actor(marshal)
	assert_same(view.drawn_faction, faction)
	assert_eq(view.drawn_base_color, Color.RED)
	assert_eq(view.world.turn_count, 0)


class RecordingGridView:
	extends GridView

	var drawn_base: Texture2D
	var drawn_faction: Texture2D
	var drawn_base_color: Color
	var drawn_faction_color: Color


	func _draw_sprite_layers(_tile: Vector2i, base: Texture2D, faction: Texture2D,
		base_color: Color, faction_color: Color) -> void:
		drawn_base = base
		drawn_faction = faction
		drawn_base_color = base_color
		drawn_faction_color = faction_color
