extends GutTest


func _session() -> GameSession:
	var session := GameSession.new()
	session.development_build = false
	session.new_game(619)
	return session


func _contact(world: GridWorld, identity: int) -> GridActor:
	for actor in world.actors:
		if actor.npc_id == identity:
			return actor
	return null


func _beside(world: GridWorld, actor: GridActor) -> void:
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(actor.tile + direction):
			world.player_tile = actor.tile + direction
			return
	fail_test("Contact needs a free neighboring tile.")


func _missing(hero: HeroState, category: StringName, passive: bool) -> SkillDefinition:
	for skill in SkillDefinition.trainer_skills(category):
		if (hero.find_skill(skill.id) == null
			and (skill.effect == SkillDefinition.Effect.PASSIVE) == passive):
			return skill
	return null


func test_each_training_quest_requires_new_matching_active_or_passive_after_acceptance() -> void:
	for category: StringName in ClassSkillData.PLAYABLE_CLASSES:
		for passive in [false, true]:
			var world := _session().world
			world.hero.selected_class = category
			world.hero.level = 10
			world.hero.copper = 100000
			var identifier := "valley_training_" + String(category).to_lower()
			var trainer := _contact(world, int(QuestData.QUESTS[identifier].giver))
			_beside(world, trainer)
			var earlier := _missing(world.hero, category, passive)
			assert_not_null(earlier)
			assert_true(world.train(category, earlier.id))
			assert_true(QuestRules.accept(world, identifier, trainer))
			assert_false(QuestRules.ready(world, identifier), "Earlier training does not count.")
			assert_false(world.train(category, earlier.id))
			assert_false(QuestRules.ready(world, identifier))
			var next := _missing(world.hero, category, passive)
			assert_not_null(next)
			world.hero.copper = 0
			if next.training_copper > 0:
				assert_false(world.train(category, next.id), "Paid training must actually succeed.")
			assert_false(QuestRules.ready(world, identifier))
			world.hero.copper = 100000
			assert_false(world.train(&"Unknown", next.id))
			assert_true(world.train(category, next.id))
			assert_eq(QuestRules.progress(world, identifier, 0), 1)
			assert_eq(QuestRules.marker_kind(world, trainer), &"quest_ready")
			assert_true(QuestRules.hand_in(world, identifier, trainer))
			assert_false(QuestRules.hand_in(world, identifier, trainer))
			assert_false(QuestRules.available(world, identifier))
			assert_eq(world.turn_count, 0)


func test_training_offer_includes_future_unlocks_but_requires_selected_unfinished_class() -> void:
	var world := _session().world
	var identifier := "valley_training_warrior"
	assert_true(QuestRules.available(world, identifier))
	assert_false(QuestRules.available(world, "valley_training_rogue"))
	world.class_selected = false
	assert_false(QuestRules.available(world, identifier))
	world.class_selected = true
	var last: SkillDefinition
	for skill in SkillDefinition.trainer_skills(&"Warrior"):
		if skill.training_level > world.hero.level:
			last = skill
	assert_not_null(last)
	for skill in SkillDefinition.trainer_skills(&"Warrior"):
		if skill.id != last.id:
			world.hero.learn_skill(skill)
	assert_gt(last.training_level, world.hero.level)
	assert_true(QuestRules.available(world, identifier))
	var trainer := _contact(world, 911)
	_beside(world, trainer)
	assert_true(QuestRules.accept(world, identifier, trainer))
	world.hero.level = last.training_level
	world.hero.copper = last.training_copper
	assert_true(world.train(&"Warrior", last.id))
	assert_true(QuestRules.ready(world, identifier), "The final ability retains the hand-in.")
	assert_true(QuestRules.hand_in(world, identifier, trainer))
	assert_false(QuestRules.available(world, identifier))
	world.quests.erase(identifier)
	assert_false(QuestRules.available(world, identifier), "A fully learned class has no offer.")


func test_training_progress_abandonment_save_and_loop_reset() -> void:
	var session := _session()
	var world := session.world
	world.hero.level = 5
	world.hero.copper = 100000
	var trainer := _contact(world, 911)
	_beside(world, trainer)
	var identifier := "valley_training_warrior"
	assert_true(QuestRules.accept(world, identifier, trainer))
	var restored := SaveCodec.restore(SaveCodec.capture(session), false)
	assert_not_null(restored)
	assert_false(QuestRules.ready(restored, identifier))
	var learned := _missing(world.hero, &"Warrior", true)
	assert_true(world.train(&"Warrior", learned.id))
	assert_true(QuestRules.abandon(world, identifier))
	assert_true(QuestRules.accept(world, identifier, trainer))
	assert_false(QuestRules.ready(world, identifier), "Reacceptance does not reuse old credit.")
	var next := _missing(world.hero, &"Warrior", false)
	assert_true(world.train(&"Warrior", next.id))
	restored = SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(session))), false)
	assert_not_null(restored)
	assert_true(QuestRules.ready(restored, identifier))
	assert_true(QuestRules.hand_in(world, identifier, trainer))
	assert_eq(world.hero.experience, 50)
	restored = SaveCodec.restore(SaveCodec.capture(session), false)
	assert_true(restored.quests[identifier].handed_in)
	session.restore(restored, session.seed_value, 1)
	restored.hero.health = 0
	assert_true(session.restart_after_death())
	assert_false(session.world.quests.has(identifier))
	assert_not_null(session.world.hero.find_skill(learned.id))
	assert_not_null(session.world.hero.find_skill(next.id))
	assert_false(QuestRules.available(session.world, identifier), "Choose a class again first.")


func test_fresh_start_preview_and_claim_use_selected_class_and_lock_quests_once_per_loop() -> void:
	for category: StringName in ClassSkillData.PLAYABLE_CLASSES:
		var world := _session().world
		world.hero.selected_class = category
		var identifier := "valley_fresh_start"
		assert_eq(QuestRules.rewards(world, identifier), StarterGear.outfit(category))
		var janos := _contact(world, NpcDefinition.JANOS_ID)
		_beside(world, janos)
		assert_true(QuestRules.accept(world, identifier, janos))
		assert_true(QuestRules.ready(world, identifier))
		assert_true(world.ever_accepted_quest)
		assert_true(QuestRules.hand_in(world, identifier, janos))
		assert_eq(world.hero.experience, 50)
		assert_false(QuestRules.hand_in(world, identifier, janos))
		assert_false(QuestRules.abandon(world, identifier))
		assert_eq(world.turn_count, 0)


func test_fresh_start_full_bag_preserves_xp_and_quest_until_all_rewards_fit() -> void:
	var world := _session().world
	var janos := _contact(world, NpcDefinition.JANOS_ID)
	_beside(world, janos)
	world.hero.equipment.weapons = ItemData.instance(35)
	world.hero.equipment.armor = ItemData.instance(85)
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(35)
	assert_true(QuestRules.accept(world, "valley_fresh_start", janos))
	var inventory := world.hero.inventory.duplicate(true)
	var equipment := world.hero.equipment.duplicate(true)
	assert_false(QuestRules.hand_in(world, "valley_fresh_start", janos))
	assert_eq(world.hero.inventory, inventory)
	assert_eq(world.hero.equipment, equipment)
	assert_eq(world.hero.experience, 0)
	assert_true(QuestRules.ready(world, "valley_fresh_start"))
	world.hero.inventory[0] = {}
	world.hero.inventory[1] = {}
	assert_true(QuestRules.hand_in(world, "valley_fresh_start", janos))
	assert_eq(world.hero.equipment, equipment)
	assert_eq(world.hero.experience, 50)


func test_janos_seeded_composition_is_order_independent_and_isolated_from_world_rng() -> void:
	var world := _session().world
	var janos := _contact(world, NpcDefinition.JANOS_ID)
	var random_state := world.random.state
	var combat_state := world.combat_random.state
	var selections: Dictionary = {}
	for seed_value in range(32):
		var stock := MerchantData.initial_stock(world.actors, seed_value)
		var offers: Dictionary = stock[janos.spawn_id]
		assert_eq(offers.size(), 5)
		assert_eq(offers["117"], -1)
		assert_eq(offers["118"], 3)
		var weapons := 0
		var extras := 0
		for key in offers:
			var data := ItemData.get_item(int(key))
			if data.weapon:
				weapons += 1
			elif data.slot != "":
				extras += 1
		assert_eq(weapons, 1)
		assert_eq(extras, 2)
		selections[str(offers.keys())] = true
		var reversed := world.actors.duplicate()
		reversed.reverse()
		assert_eq(MerchantData.initial_stock(reversed, seed_value), stock)
	assert_gt(selections.size(), 1)
	assert_eq(world.random.state, random_state)
	assert_eq(world.combat_random.state, combat_state)


func test_janos_unoffered_items_reject_and_saved_depletion_only_replenishes_on_death() -> void:
	var session := _session()
	var world := session.world
	var janos := _contact(world, NpcDefinition.JANOS_ID)
	_beside(world, janos)
	world.hero.copper = 1000
	var stock := world.vendor_stock.duplicate(true)
	var excluded := ""
	for key in MerchantData.catalog(janos.npc_id):
		if not stock[janos.spawn_id].has(key):
			excluded = key
			break
	assert_ne(excluded, "")
	assert_false(world.buy_item(janos, int(excluded), 1))
	assert_eq(world.hero.copper, 1000)
	assert_eq(world.vendor_stock, stock)
	assert_true(world.buy_item(janos, 118, 3))
	var snapshot := SaveCodec.capture(session)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	assert_eq(restored.vendor_stock[janos.spawn_id]["118"], 0)
	var menu := MenuPanel.new()
	menu.session = session
	add_child_autofree(menu)
	menu.open_trade(janos)
	menu.open_buy(janos)
	assert_eq(world.vendor_stock[janos.spawn_id]["118"], 0)
	assert_eq(menu._buttons.size(), 6, "Five offers and Back, including depleted potions.")
	snapshot.vendor_stock[janos.spawn_id][excluded] = -1
	assert_null(SaveCodec.restore(snapshot, false), "Injected unoffered gear is invalid.")
	session.restore(restored, session.seed_value, 1)
	restored.hero.health = 0
	assert_true(session.restart_after_death())
	assert_eq(session.world.vendor_stock, stock)


func test_milly_vineyard_requires_player_level_two() -> void:
	var world := _session().world
	assert_false(QuestRules.available(world, "valley_vineyard"))
	world.hero.level = 2
	assert_true(QuestRules.available(world, "valley_vineyard"))
