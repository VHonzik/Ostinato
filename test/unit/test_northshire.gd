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


func test_conversation_acceptance_and_rewards_are_free_and_once() -> void:
	var world := _game().world
	_accept(world, "valley_patrol")
	assert_true(world.ever_accepted_quest)
	assert_false(QuestRules.ready(world, "valley_patrol"))
	for count in range(8):
		QuestRules.record_kill(world, 299)
	_talk_and_hand_in(world, "valley_patrol")
	assert_gt(world.hero.experience, 0)
	assert_false(QuestRules.hand_in(world, "valley_patrol", _npc(world, 197)))
	assert_false(QuestRules.available(world, "valley_patrol"))
	assert_eq(world.turn_count, 0)

func test_kill_objectives_ignore_prior_kills_and_match_identity() -> void:
	var world := _game().world
	var vermin := _npc(world, 6)
	vermin.health = 0
	world._check_npc_death(vermin, 0)
	world.hero.level = 10
	_accept(world, "valley_camp")
	assert_eq(QuestRules.progress(world, "valley_camp", 0), 0)
	var wolf := _npc(world, 299)
	wolf.health = 0
	world._check_npc_death(wolf, 0)
	assert_eq(QuestRules.progress(world, "valley_camp", 0), 0)
	vermin = _npc(world, 6)
	vermin.health = 0
	world._check_npc_death(vermin, 0)
	world._check_npc_death(vermin, 0)
	assert_eq(QuestRules.progress(world, "valley_camp", 0), 1)
	assert_false(QuestRules.hand_in(world, "valley_camp", _npc(world, 197)))

func test_accept_and_hand_in_reject_remote_dead_and_wrong_contacts() -> void:
	var world := _game().world
	var deputy := _npc(world, 823)
	world.player_tile = Vector2i(2, 40)
	assert_false(QuestRules.accept(world, "valley_explore", deputy))
	_beside(world, deputy)
	assert_false(QuestRules.accept(world, "valley_explore", _npc(world, 197)))
	deputy.alive = false
	assert_false(QuestRules.accept(world, "valley_explore", deputy))
	assert_false(world.ever_accepted_quest)


func test_abandonment_does_not_reopen_class_choice_or_reroll_loot() -> void:
	var game := _game()
	game.world.hero.health = 0
	game.restart_after_death()
	var world := game.world
	_accept(world, "valley_patrol")
	var wolf := _npc(world, 299)
	wolf.health = 0
	world._check_npc_death(wolf, 0)
	var remaining := wolf.loot.duplicate(true)
	assert_true(QuestRules.abandon(world, "valley_patrol"))
	assert_false(game.can_select_class())
	_accept(world, "valley_patrol")
	assert_eq(QuestRules.progress(world, "valley_patrol", 0), 0)
	LootData.assign(world, wolf)
	assert_eq(wolf.loot, remaining)

func test_reward_choice_and_capacity_are_atomic_and_surplus_quest_items_are_removed() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(6, 6))
	for identity in [197, 196]:
		var contact := GridActor.new(Vector2i(6, 5 if identity == 197 else 7))
		contact.npc_id = identity
		world.actors.append(contact)
	world.ever_accepted_quest = true
	world.quests["wolves"] = {"handed_in": false, "counts": [0]}
	world.loot_quests.append("wolves")
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(118, 5)
	# Occupy the reward slot so it must fit in the full inventory.
	world.hero.equipment["armor"] = ItemData.instance(2649)
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


func test_save_roundtrip_preserves_quests_population_and_reproducible_continuation() -> void:
	var game := _game()
	var world := game.world
	world.hero.level = 10
	_accept(world, "valley_camp")
	var actor := _npc(world, 6)
	actor.health = 0
	world._check_npc_death(actor, 0)
	world.player_tile = ValleyRoute.SPAWN
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
	_accept(game.world, "valley_patrol")
	var state := SaveCodec.capture(game)
	var bad := state.duplicate(true)
	bad.quests["valley_patrol"].counts[0] = 9
	assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.population.append({"area": "unknown"})
	assert_null(SaveCodec.restore(bad, true))
	for invalid_population in [null, 5, "old map", {}]:
		bad = state.duplicate(true)
		bad.population = invalid_population
		assert_null(SaveCodec.restore(bad, true))
	bad = state.duplicate(true)
	bad.actors[0].state.population_slot = 999
	assert_null(SaveCodec.restore(bad, true))


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
	var first_crate := GridActor.new(Vector2i(24, 44))
	first_crate.chest = true
	first_crate.loot_table = 161557
	LootData.assign(first, first_crate)
	first.loot_quests.append("3904")
	LootData.assign(first, first_crate)
	assert_true(first_crate.loot.is_empty(), "First opening captures chest eligibility too.")
