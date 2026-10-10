extends GutTest


func _game() -> GameSession:
	var game := GameSession.new()
	game.new_game(619)
	return game


func _npc(world: GridWorld, identity: int) -> GridActor:
	for actor in world.actors:
		if actor.npc_id == identity and actor.alive:
			return actor
	return null


func _beside(world: GridWorld, actor: GridActor) -> void:
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(actor.tile + direction):
			world.player_tile = actor.tile + direction
			return
	fail_test("No free interaction tile.")


func _accept(world: GridWorld, identifier: String) -> void:
	var actor := _npc(world, int(QuestData.QUESTS[identifier].giver))
	_beside(world, actor)
	assert_true(QuestRules.accept(world, identifier, actor), identifier)


func _talk_and_hand_in(world: GridWorld, identifier: String, choice: int = 0) -> void:
	var actor := _npc(world, int(QuestData.QUESTS[identifier].receiver))
	_beside(world, actor)
	world.interact(actor)
	assert_true(QuestRules.hand_in(world, identifier, actor, choice), identifier)


func test_conversation_acceptance_prerequisites_and_rewards_are_free_and_once() -> void:
	var world := _game().world
	assert_false(QuestRules.available(world, "7"))
	_accept(world, "783")
	assert_true(world.ever_accepted_quest)
	assert_false(QuestRules.ready(world, "783"))
	QuestRules.event(world, "talk", "196")
	assert_false(QuestRules.ready(world, "783"), "Only the specified contact counts.")
	_talk_and_hand_in(world, "783")
	assert_eq(world.hero.experience, 40)
	assert_true(QuestRules.available(world, "7"))
	assert_false(QuestRules.hand_in(world, "783", _npc(world, 197)))
	assert_false(QuestRules.available(world, "783"))
	assert_eq(world.turn_count, 0)


func test_kill_objectives_count_once_only_after_acceptance_and_match_identity() -> void:
	var world := _game().world
	_accept(world, "783")
	_talk_and_hand_in(world, "783")
	var vermin := _npc(world, 6)
	vermin.health = 0
	world._check_npc_death(vermin, 0)
	_accept(world, "7")
	assert_eq(QuestRules.progress(world, "7", 0), 0)
	var wolf := _npc(world, 69)
	if wolf == null:
		wolf = _npc(world, 299)
	wolf.health = 0
	world._check_npc_death(wolf, 0)
	assert_eq(QuestRules.progress(world, "7", 0), 0)
	vermin = _npc(world, 6)
	vermin.health = 0
	world._check_npc_death(vermin, 0)
	world._check_npc_death(vermin, 0)
	assert_eq(QuestRules.progress(world, "7", 0), 1)
	assert_false(QuestRules.hand_in(world, "7", _npc(world, 197)))


func test_location_is_credited_on_crossed_tile_and_requires_all_objectives() -> void:
	var world := _game().world
	_accept(world, "783")
	_talk_and_hand_in(world, "783")
	_accept(world, "gate_survey")
	world.player_tile = Vector2i(42, 12)
	world.movement_speed = 4.0
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_eq(world.player_tile, Vector2i(46, 12))
	assert_eq(QuestRules.progress(world, "gate_survey", 0), 1)
	assert_false(QuestRules.ready(world, "gate_survey"))
	var deputy := _npc(world, 823)
	_beside(world, deputy)
	world.interact(deputy)
	assert_true(QuestRules.ready(world, "gate_survey"))
	_talk_and_hand_in(world, "gate_survey")
	assert_eq(world.turn_count, 1)


func test_accept_and_hand_in_reject_remote_dead_and_wrong_contacts() -> void:
	var world := _game().world
	var deputy := _npc(world, 823)
	world.player_tile = Vector2i(2, 40)
	assert_false(QuestRules.accept(world, "783", deputy))
	_beside(world, deputy)
	assert_false(QuestRules.accept(world, "783", _npc(world, 197)))
	deputy.alive = false
	assert_false(QuestRules.accept(world, "783", deputy))
	assert_false(world.ever_accepted_quest)


func test_abandonment_purges_bags_and_assigned_loot_without_rerolls_or_reopening_class_choice() -> void:
	var game := _game()
	game.world.hero.health = 0
	game.restart_after_death()
	var world := game.world
	_accept(world, "783")
	_talk_and_hand_in(world, "783")
	_accept(world, "5261")
	_talk_and_hand_in(world, "5261")
	_accept(world, "wolves")
	world.hero.inventory[0] = ItemData.instance(750, 8)
	world.hero.inventory[1] = ItemData.instance(118)
	var wolf := _npc(world, 69)
	if wolf == null:
		wolf = _npc(world, 299)
	wolf.health = 0
	world._check_npc_death(wolf, 0)
	wolf.loot.append(ItemData.instance(750))
	assert_true(QuestRules.ready(world, "wolves"))
	assert_true(QuestRules.abandon(world, "wolves"))
	assert_eq(world.hero.inventory[0], {})
	assert_eq(world.hero.inventory[1].id, 118)
	assert_false(wolf.loot.any(func(item: Dictionary) -> bool: return item.id == 750))
	assert_true(wolf.loot_assigned)
	assert_false(game.can_select_class())
	_accept(world, "wolves")
	assert_false(QuestRules.ready(world, "wolves"))
	var remaining := wolf.loot.duplicate(true)
	LootData.assign(world, wolf)
	assert_eq(wolf.loot, remaining)


func test_reward_choice_and_capacity_are_atomic_and_surplus_quest_items_are_removed() -> void:
	var world := _game().world
	_accept(world, "783")
	_talk_and_hand_in(world, "783")
	_accept(world, "5261")
	_talk_and_hand_in(world, "5261")
	_accept(world, "wolves")
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(118, 5)
	# A non-loot quest with an item reward exercises full capacity directly.
	world.quests["21"] = {"handed_in": false, "counts": [12]}
	world.loot_quests.append("21")
	var marshal := _npc(world, 197)
	_beside(world, marshal)
	var before := world.hero.inventory.duplicate(true)
	var xp := world.hero.experience
	assert_false(QuestRules.hand_in(world, "21", marshal, 2186))
	assert_eq(world.hero.inventory, before)
	assert_eq(world.hero.experience, xp)
	assert_false(world.quests["21"].handed_in)
	assert_false(QuestRules.hand_in(world, "21", marshal, 999))
	world.hero.inventory[0] = {}
	assert_true(QuestRules.hand_in(world, "21", marshal, 2186))
	assert_eq(world.hero.inventory[0].id, 2186)
	world.hero.inventory[1] = ItemData.instance(750, 10)
	world.hero.inventory[2] = ItemData.instance(750, 3)
	_talk_and_hand_in(world, "wolves", 80)
	assert_false(world.hero.inventory.any(func(item: Dictionary) -> bool:
		return not item.is_empty() and item.id == 750))
	assert_false(world.loot_quests.has("wolves"))


func test_quest_difficulty_cutoffs_and_gray_xp_are_independent() -> void:
	assert_eq(QuestRules.difficulty(15, 10), "Red")
	assert_eq(QuestRules.difficulty(14, 10), "Orange")
	assert_eq(QuestRules.difficulty(13, 10), "Orange")
	assert_eq(QuestRules.difficulty(12, 10), "Yellow")
	assert_eq(QuestRules.difficulty(8, 10), "Yellow")
	assert_eq(QuestRules.difficulty(7, 10), "Green")
	for row in [[9, 4], [10, 5], [19, 5], [20, 6], [30, 7], [40, 8],
		[45, 9], [50, 10], [55, 11], [60, 12]]:
		assert_eq(QuestRules.difficulty(row[0] - row[1], row[0]), "Green")
		assert_eq(QuestRules.difficulty(row[0] - row[1] - 1, row[0]), "Gray")
	assert_eq(QuestRules.experience(170, 2, 7), 170)
	assert_eq(QuestRules.experience(170, 2, 8), 136)
	assert_eq(QuestRules.experience(170, 2, 9), 102)
	assert_eq(QuestRules.experience(170, 2, 10), 68)
	assert_eq(QuestRules.experience(170, 2, 11), 34)
	assert_eq(QuestRules.experience(170, 2, 12), 17)
	assert_eq(QuestRules.experience(85, 2, 60), 9)


func test_seeded_population_replacement_is_new_identity_at_thirty_turns_and_resets() -> void:
	var game := _game()
	var world := game.world
	var vermin := _npc(world, 6)
	var slot := vermin.population_slot
	var original := vermin.spawn_id
	var position := vermin.tile
	vermin.health = 0
	world._check_npc_death(vermin, 0)
	var reward := vermin.loot.duplicate(true)
	world.turn_count = 29
	NorthshireZone.tick_population(world)
	assert_true(world.population[slot].pending)
	world.turn_count = 30
	NorthshireZone.tick_population(world)
	assert_false(world.population[slot].pending)
	var replacement := world.actors[-1]
	assert_eq(replacement.population_slot, slot)
	assert_ne(replacement.spawn_id, original)
	assert_true(NorthshireZone.AREAS["vermin"].rect.has_point(replacement.tile))
	assert_false(replacement.engaged, "New arrivals do not receive a phase during spawning.")
	world.hero.health = 0
	game.restart_after_death()
	var reset := _npc(game.world, 6)
	assert_eq(reset.spawn_id, original)
	assert_eq(reset.tile, position)
	LootData.assign(game.world, reset)
	assert_eq(reset.loot, reward)
	assert_eq(game.world.population[slot].ordinal, 0)


func test_blocked_population_stays_pending_without_changing_seeded_type_or_ordinal() -> void:
	var world := _game().world
	var actor := _npc(world, 103)
	actor.health = 0
	world._check_npc_death(actor, 0)
	var record: Dictionary = world.population[actor.population_slot]
	var area: Rect2i = NorthshireZone.AREAS.garrick.rect
	for x in range(area.position.x, area.end.x):
		for y in range(area.position.y, area.end.y):
			world.blocked_tiles[Vector2i(x, y)] = true
	world.turn_count = 30
	NorthshireZone.tick_population(world)
	assert_true(record.pending)
	assert_eq(record.ordinal, 1)
	world.blocked_tiles.erase(actor.tile)
	world.turn_count = 31
	NorthshireZone.tick_population(world)
	assert_false(record.pending)
	assert_eq(world.actors[-1].npc_id, 103)
	assert_eq(world.actors[-1].tile, actor.tile)
	assert_eq(world.actors[-1].spawn_id, "garrick/0/1")


func test_save_roundtrip_preserves_quests_population_and_reproducible_continuation() -> void:
	var game := _game()
	var world := game.world
	_accept(world, "783")
	_talk_and_hand_in(world, "783")
	_accept(world, "7")
	var actor := _npc(world, 6)
	actor.health = 0
	world._check_npc_death(actor, 0)
	world.player_tile = Vector2i(20, 14)
	var snapshot := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), true)
	assert_not_null(restored)
	if restored == null:
		return
	var other := GameSession.new()
	other.restore(restored, game.seed_value, game.loop_count)
	assert_eq(JSON.stringify(snapshot), JSON.stringify(SaveCodec.capture(other)))
	for turn in range(31):
		world.wait_turn()
		restored.wait_turn()
	assert_eq(JSON.stringify(SaveCodec.capture(game)), JSON.stringify(SaveCodec.capture(other)))
	world.hero.health = 0
	game.restart_after_death()
	assert_eq(game.world.quests, {})
	assert_eq(game.world.loot_quests, [])


func test_malformed_quest_and_population_state_is_rejected() -> void:
	var game := _game()
	_accept(game.world, "783")
	var state := SaveCodec.capture(game)
	var bad := state.duplicate(true)
	bad.quests["783"].counts[0] = 2
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.population[0].area = "unknown"
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.actors[0].state.population_slot = 999
	assert_null(SaveCodec.restore(bad, true))


func test_buildings_and_all_contacts_have_terrain_routes_from_spawn() -> void:
	var world := _game().world
	for actor in world.actors:
		if not actor.alive or actor.relationship != GridActor.Relationship.FRIENDLY:
			continue
		var goals: Array[Vector2i] = []
		for direction in GridWorld.DIRECTIONS:
			if world._terrain_open(actor.tile + direction):
				goals.append(actor.tile + direction)
		assert_false(world._route(world.player_tile, goals, false, actor.tile).is_empty(), actor.title)
	world.player_tile = Vector2i(20, 13)
	assert_true(world.move_player(Vector2i.UP), "Enter the abbey doorway.")
	assert_true(world.move_player(Vector2i.UP))
	assert_true(world.indoor_tiles.has(world.player_tile))
	assert_true(world.move_player(Vector2i.DOWN))
	assert_true(world.move_player(Vector2i.DOWN))
	assert_false(world.indoor_tiles.has(world.player_tile))
	assert_lte(world.actors.filter(func(a: GridActor) -> bool: return a.alive).size(), 95)


func test_story_guard_stays_dead_and_other_scripted_friendly_deaths_respawn_at_home() -> void:
	var world := _game().world
	var friendly := _npc(world, 196)
	friendly.health = 0
	world._check_npc_death(friendly, 0)
	world.turn_count = 29
	world._respawn_friendlies()
	assert_false(friendly.alive)
	world.turn_count = 30
	world._respawn_friendlies()
	assert_true(friendly.alive)
	assert_eq(friendly.tile, friendly.home_tile)
	assert_eq(friendly.health, friendly.max_health)
	world._arrive_stalker()
	var guard: GridActor
	for actor in world.actors:
		if actor.story_guard:
			guard = actor
	world.turn_count = 1000
	world._respawn_friendlies()
	assert_false(guard.alive)
	assert_true(guard.corpse_visible)


func test_source_items_need_capacity_on_accept_and_referrals_follow_selected_class() -> void:
	var world := _game().world
	_accept(world, "783")
	_talk_and_hand_in(world, "783")
	_accept(world, "7")
	for count in range(10):
		QuestRules.event(world, "kill", "6")
	_talk_and_hand_in(world, "7")
	assert_true(QuestRules.available(world, "3104"))
	assert_false(QuestRules.available(world, "druid_referral"))
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(118, 5)
	assert_false(QuestRules.accept(world, "3104", _npc(world, 197)))
	assert_false(world.quests.has("3104"))
	world.hero.inventory[0] = {}
	_accept(world, "3104")
	assert_eq(world.hero.inventory[0].id, 9571)
	_talk_and_hand_in(world, "3104")
	assert_eq(world.hero.inventory[0], {})
	world.hero.selected_class = &"Druid"
	assert_true(QuestRules.available(world, "druid_referral"))


func test_quest_loot_filter_does_not_reroll_ordinary_loot_or_add_retroactive_drops() -> void:
	var first := _game().world
	var second := _game().world
	first.loot_quests.append("18")
	var thief := _npc(first, 38)
	var other := _npc(second, 38)
	LootData.assign(first, thief)
	LootData.assign(second, other)
	assert_eq(thief.loot_copper, other.loot_copper)
	var ordinary := thief.loot.filter(func(item: Dictionary) -> bool: return item.id != 752)
	assert_eq(other.loot, ordinary)
	second.loot_quests.append("18")
	LootData.assign(second, other)
	assert_eq(other.loot, ordinary, "Accepting later cannot change death-time eligibility.")
	var first_crate: GridActor
	for actor in first.actors:
		if actor.loot_table == 161557:
			first_crate = actor
			break
	LootData.assign(first, first_crate)
	first.loot_quests.append("3904")
	LootData.assign(first, first_crate)
	assert_true(first_crate.loot.is_empty(), "First opening captures chest eligibility too.")
