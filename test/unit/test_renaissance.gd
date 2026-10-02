extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(10, 10), 97)
	world.hero.level = 10
	world.hero._apply_level_stats()
	world.hero.copper = 100000
	world.hero.spell_hit = 100
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(13, 10)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.max_health = 10000
	enemy.health = 10000
	enemy.melee.damage_min = 0
	enemy.melee.damage_max = 0
	enemy.melee.attack_power = 0
	world.actors.append(enemy)
	return enemy


func _learn(world: GridWorld, identifier: StringName) -> void:
	world.hero.learn_skill(SkillRank.catalog(identifier))


func _cast(world: GridWorld, identifier: StringName, target: GridActor = null) -> void:
	_learn(world, identifier)
	assert_true(world.cast_skill(identifier, target), identifier)
	for boundary in range(30):
		if world.pending_skill == null:
			break
		world.continue_cast()
	assert_null(world.pending_skill)


func test_all_fifty_nine_new_source_ranks_train_with_no_omissions_or_duplicates() -> void:
	var expected := {
		&"Warlock": [686, 687, 688, 348, 172, 702, 695, 1454, 5782, 980, 696, 697, 707, 1120, 6201],
		&"Priest": [585, 2050, 1243, 589, 2052, 17, 591, 139, 586, 594, 2006, 2053, 8092],
		&"Shaman": [331, 403, 8017, 8042, 8071, 332, 2484, 324, 529, 5730, 8018, 8044, 3599, 8024, 8050, 8075],
		&"Paladin": [465, 635, 21084, 19740, 20271, 498, 639, 21082, 853, 1152, 3127, 633, 1022, 10290, 20287],
	}
	var world := _world()
	var total := 0
	for category in expected:
		world.hero.selected_class = category
		var actual: Array[int] = []
		for skill in SkillRank.trainer_skills(category):
			actual.append(skill.source_id)
			assert_true(world.train(category, skill.id), skill.id)
			var copper := world.hero.copper
			assert_false(world.train(category, skill.id), "No duplicate training")
			assert_eq(world.hero.copper, copper)
			assert_between(skill.training_level, 1, 10)
			total += 1
		actual.sort()
		expected[category].sort()
		assert_eq(actual, expected[category])
	assert_eq(total, 59)
	assert_eq(world.turn_count, 0)
	for excluded: StringName in [&"redemption_1", &"desperate_prayer_1", &"health_funnel_1", &"bear_form_1"]:
		assert_null(SkillRank.catalog(excluded))


func test_every_new_active_rank_executes_and_passive_cannot_be_cast() -> void:
	for category: StringName in [&"Warlock", &"Priest", &"Shaman", &"Paladin"]:
		for rank in SkillRank.trainer_skills(category):
			var world := _world()
			_learn(world, rank.id)
			var enemy := _enemy(world)
			enemy.tile = Vector2i(12, 10)
			var target := enemy if rank.target == SkillRank.Target.ENEMY else null
			if rank.effect == SkillRank.Effect.RESURRECT:
				enemy.alive = false
				enemy.health = 0
				enemy.relationship = GridActor.Relationship.FRIENDLY
				target = enemy
			if rank.effect == SkillRank.Effect.JUDGEMENT:
				_cast(world, &"seal_of_righteousness_1")
			if rank.effect == SkillRank.Effect.PASSIVE:
				assert_false(world.cast_skill(rank.id))
				assert_eq(world.turn_count, 0)
			else:
				_cast(world, rank.id, target)
				assert_gte(world.hero.health, 1, rank.id)


func test_each_class_can_be_selected_trained_retained_and_cast_as_level_one_mage() -> void:
	for category: StringName in [&"Warlock", &"Priest", &"Shaman", &"Paladin"]:
		var game := GameSession.new()
		game.new_game(29)
		game.world.hero.health = 0
		game.restart_after_death()
		var ranks_before := game.world.hero.learned_skills.size()
		assert_true(game.select_class(category))
		assert_eq(game.world.hero.learned_skills.size(), ranks_before)
		assert_eq(game.world.hero.level, 1)
		assert_eq(game.world.hero.strength, 20)
		for rank in SkillRank.trainer_skills(category):
			if rank.training_level == 1:
				assert_true(game.world.train(category, rank.id), rank.id)
		game.world.hero.health = 0
		game.restart_after_death()
		assert_eq(game.world.hero.selected_class, &"Mage")
		var spell: StringName = {&"Warlock": &"demon_skin_1", &"Priest": &"power_word_fortitude_1",
			&"Shaman": &"rockbiter_weapon_1", &"Paladin": &"devotion_aura_1"}[category]
		assert_true(game.world.cast_skill(spell), spell)
		assert_true(game.world.hero.buffs.has(spell))


func test_summon_blocking_revalidates_completion_and_preserves_existing_pet() -> void:
	var world := _world()
	_cast(world, &"summon_imp_1")
	var pet := SummonRules.active(world, "pet")
	assert_not_null(pet)
	assert_false(world.is_open(pet.tile))
	_learn(world, &"summon_voidwalker_1")
	world.hero.mana = world.hero.max_mana
	world.hero.casting_credit = 0.4
	assert_true(world.cast_skill(&"summon_voidwalker_1"))
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(world.player_tile + direction):
			world.blocked_tiles[world.player_tile + direction] = true
	for index in range(9):
		world.continue_cast()
	assert_same(SummonRules.active(world, "pet"), pet)
	assert_eq(world.hero.casting_credit, 0.4)
	assert_eq(world.hero.mana, world.hero.max_mana)
	var turn := world.turn_count
	assert_false(world.cast_skill(&"summon_voidwalker_1"))
	assert_eq(world.turn_count, turn)


func test_same_element_replacement_can_reuse_tile_and_different_elements_coexist() -> void:
	var world := _world()
	_cast(world, &"stoneskin_totem_1")
	var earth := SummonRules.active(world, "earth")
	var tile := earth.tile
	for direction in GridWorld.DIRECTIONS:
		if world.is_open(world.player_tile + direction):
			world.blocked_tiles[world.player_tile + direction] = true
	_cast(world, &"earthbind_totem_1")
	assert_false(earth.alive)
	assert_eq(SummonRules.active(world, "earth").tile, tile)
	world.blocked_tiles.erase(world.player_tile + Vector2i.RIGHT)
	_cast(world, &"searing_totem_1")
	assert_not_null(SummonRules.active(world, "earth"))
	assert_not_null(SummonRules.active(world, "fire"))
	assert_ne(SummonRules.active(world, "earth").tile, SummonRules.active(world, "fire").tile)


func test_pet_orders_are_free_and_only_player_actions_advance_attacks_and_following() -> void:
	var world := _world()
	_cast(world, &"summon_imp_1")
	var enemy := _enemy(world)
	var pet := SummonRules.active(world, "pet")
	var turn := world.turn_count
	assert_true(world.cast_skill(&"pet_attack", enemy))
	assert_eq(world.turn_count, turn)
	assert_eq(enemy.health, enemy.max_health)
	assert_true(world.in_combat())
	for index in range(5):
		world.wait_turn()
	assert_lt(enemy.health, enemy.max_health)
	assert_lt(pet.mana, pet.max_mana)
	assert_true(world.cast_skill(&"pet_follow"))
	var health := enemy.health
	for index in range(5):
		world.wait_turn()
	assert_eq(enemy.health, health)
	assert_eq(pet.summon_target, -1)
	assert_true(world.cast_skill(&"pet_dismiss"))
	assert_null(SummonRules.active(world, "pet"))
	assert_not_null(world.hero.find_skill(&"summon_imp_1"))


func test_pet_kill_awards_xp_and_objectives_once_and_pet_death_has_no_reward_or_respawn() -> void:
	var world := _world()
	_cast(world, &"summon_voidwalker_1")
	var pet := SummonRules.active(world, "pet")
	var enemy := _enemy(world)
	enemy.melee.level = 10
	enemy.health = 1
	var before := world.hero.experience
	SpellEffects.damage(world, enemy, 2, "Voidwalker", world.turn_count, true, pet)
	assert_gt(world.hero.experience, before)
	var earned := world.hero.experience
	world._check_npc_death(enemy)
	assert_eq(world.hero.experience, earned)
	pet.health = 0
	world._check_npc_death(pet)
	assert_null(SummonRules.active(world, "pet"))
	assert_eq(world.hero.experience, earned)
	for index in range(31):
		world.wait_turn()
	assert_false(pet.alive)
	assert_false(pet.corpse_visible)


func test_summon_auras_obey_range_and_expiry_without_refilling_resources() -> void:
	var world := _world()
	var strength := world.hero.strength
	world.hero.health = 50
	_cast(world, &"strength_of_earth_totem_1")
	assert_eq(world.hero.strength, strength + 10)
	var totem := SummonRules.active(world, "earth")
	world.player_tile = Vector2i(20, 20)
	SummonRules.refresh_auras(world)
	assert_eq(world.hero.strength, strength)
	world.player_tile = Vector2i(10, 10)
	SummonRules.refresh_auras(world)
	assert_eq(world.hero.strength, strength + 10)
	world.turn_count = totem.expires_turn - 1
	world.wait_turn()
	assert_null(SummonRules.active(world, "earth"))
	assert_eq(world.hero.strength, strength)


func test_shield_absorbs_damage_and_weakened_soul_blocks_reapplication() -> void:
	var world := _world()
	_cast(world, &"power_word_shield_1")
	assert_eq(ClassSpellEffects.absorb(world, null, 30, true), 0)
	assert_eq(ClassSpellEffects.absorb(world, null, 20, true), 6)
	var turn := world.turn_count
	var mana := world.hero.mana
	assert_false(world.cast_skill(&"power_word_shield_1"))
	assert_eq(world.turn_count, turn)
	assert_eq(world.hero.mana, mana)
	world.turn_count = world.hero.weakened_until
	assert_true(world.cast_skill(&"power_word_shield_1"))


func test_protection_forbearance_and_passive_parry_survive_the_correct_boundaries() -> void:
	var world := _world()
	_learn(world, &"parry_1")
	assert_eq(world.hero.melee.parry, 5.0)
	_cast(world, &"divine_protection_1")
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 0)
	assert_eq(ClassSpellEffects.absorb(world, null, 100, false), 100)
	var enemy := _enemy(world, world.player_tile + Vector2i.RIGHT)
	assert_false(world.request_melee(enemy))
	_learn(world, &"blessing_of_protection_1")
	assert_false(world.cast_skill(&"blessing_of_protection_1"))
	for index in range(6):
		world.wait_turn()
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 100)
	assert_false(world.cast_skill(&"blessing_of_protection_1"))


func test_drain_soul_three_turn_ticks_and_cancel_preserve_cost_and_credit() -> void:
	var world := _world()
	var enemy := _enemy(world)
	_learn(world, &"drain_soul_1")
	world.hero.casting_credit = 0.6
	var mana := world.hero.mana
	assert_true(world.cast_skill(&"drain_soul_1", enemy))
	assert_eq(world.hero.mana, mana - 55)
	assert_eq(enemy.health, enemy.max_health)
	world.continue_cast()
	assert_eq(enemy.health, enemy.max_health)
	world.continue_cast()
	assert_lt(enemy.health, enemy.max_health)
	var health := enemy.health
	world.cancel_cast()
	world.wait_turn()
	assert_eq(enemy.health, health)
	assert_eq(world.hero.casting_credit, 0.6)


func test_curses_replace_each_other_and_agony_has_twelve_increasing_ticks() -> void:
	var world := _world()
	var enemy := _enemy(world)
	_cast(world, &"curse_of_agony_1", enemy)
	assert_eq(world.periodic_effects.size(), 1)
	_cast(world, &"curse_of_weakness_1", enemy)
	assert_eq(world.periodic_effects.size(), 0)
	assert_true(enemy.debuffs.has("weakness"))
	_cast(world, &"curse_of_agony_1", enemy)
	assert_false(enemy.debuffs.has("weakness"))
	assert_eq(int(world.periodic_effects[0].remaining), 12)


func test_healthstone_is_unique_usable_in_combat_and_has_its_own_cooldown() -> void:
	var world := _world()
	_cast(world, &"healthstone_1")
	var turn := world.turn_count
	assert_false(world.cast_skill(&"healthstone_1"))
	assert_eq(world.turn_count, turn)
	var enemy := _enemy(world)
	enemy.engaged = true
	world.hero.health = 1
	world.hero.potion_ready_turn = 999
	assert_true(world.consume_item(0))
	assert_eq(world.hero.health, 101)
	assert_gt(world.hero.healthstone_ready_turn, world.turn_count)
	assert_eq(world.hero.potion_ready_turn, 999)


func test_save_roundtrip_preserves_summons_effects_rng_commands_and_rejects_invalid_targets() -> void:
	var game := GameSession.new()
	game.seed_value = 97
	game.world = _world()
	_cast(game.world, &"summon_imp_1")
	_cast(game.world, &"strength_of_earth_totem_1")
	_cast(game.world, &"searing_totem_1")
	_cast(game.world, &"power_word_shield_1")
	var data := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(data)), true)
	assert_not_null(restored)
	if restored == null:
		return
	var copy := GameSession.new()
	copy.world = restored
	copy.seed_value = 97
	assert_eq(SaveCodec.capture(copy), data)
	for index in range(12):
		game.world.wait_turn()
		restored.wait_turn()
	assert_eq(SaveCodec.capture(copy), SaveCodec.capture(game))
	var bad := data.duplicate(true)
	bad.actors[0].state.summon_target = 99999
	assert_null(SaveCodec.restore(bad, true))
	bad = data.duplicate(true)
	bad.actors[0].state.summon_kind = "unknown"
	assert_null(SaveCodec.restore(bad, true))


func test_death_clears_all_summons_cooldowns_and_effects_but_retains_parry_and_summons() -> void:
	var game := GameSession.new()
	game.seed_value = 97
	game.world = _world()
	_cast(game.world, &"summon_voidwalker_1")
	_cast(game.world, &"searing_totem_1")
	_learn(game.world, &"parry_1")
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.melee.parry, 5.0)
	assert_not_null(game.world.hero.find_skill(&"summon_voidwalker_1"))
	for actor in game.world.actors:
		assert_eq(actor.summon_kind, "")
	assert_eq(game.world.hero.buffs, {})
	assert_eq(game.world.hero.cooldowns, {})
	_cast(game.world, &"summon_voidwalker_1")
	assert_eq(SummonRules.active(game.world, "pet").melee.level, 1)


func test_judgement_is_free_spends_mana_consumes_seal_and_starts_cooldown() -> void:
	var world := _world()
	var target := _enemy(world, Vector2i(11, 10))
	_cast(world, &"seal_of_righteousness_1")
	_learn(world, &"judgement_1")
	var turn := world.turn_count
	var mana := world.hero.mana
	world.hero.casting_credit = 0.6
	assert_true(world.cast_skill(&"judgement_1", target))
	assert_eq(world.turn_count, turn)
	assert_eq(world.hero.casting_credit, 0.6)
	assert_eq(world.hero.mana, mana - SkillRank.catalog(&"judgement_1").cost(world.hero))
	assert_true(ClassSpellEffects.seal(world.hero).is_empty())
	assert_eq(int(world.hero.cooldowns.judgement), turn + 10)
	assert_false(world.cast_skill(&"judgement_1", target))
	assert_eq(world.turn_count, turn)


func test_devotion_aura_toggles_with_one_turn_and_applies_to_nearby_pet() -> void:
	var world := _world()
	_cast(world, &"summon_imp_1")
	var pet := SummonRules.active(world, "pet")
	var armor := pet.melee.armor
	var turn := world.turn_count
	_cast(world, &"devotion_aura_1")
	assert_eq(world.turn_count, turn + 1)
	assert_eq(pet.melee.armor, armor + 55)
	_cast(world, &"devotion_aura_1")
	assert_eq(pet.melee.armor, armor)
	assert_false(world.hero.buffs.has(&"devotion_aura_1"))


func test_repeat_fortitude_does_not_stack_pet_health_and_expiry_removes_it() -> void:
	var world := _world()
	_cast(world, &"summon_voidwalker_1")
	var pet := SummonRules.active(world, "pet")
	var health := pet.max_health
	_cast(world, &"power_word_fortitude_1", pet)
	assert_eq(pet.max_health, health + 3)
	_cast(world, &"power_word_fortitude_1", pet)
	assert_eq(pet.max_health, health + 3)
	pet.health = pet.max_health
	pet.buffs[&"power_word_fortitude_1"].until = world.turn_count + 1
	world.wait_turn()
	assert_eq(pet.max_health, health)
	assert_eq(pet.health, health, "Expiry removes only the actual stamina bonus")


func test_class_exchange_preserves_acquired_two_hander_and_stores_shaman_shield() -> void:
	var world := _world()
	world.hero.equipment.main_hand = ItemData.instance(35)
	assert_true(StarterGear.exchange(world.hero, &"Shaman"))
	assert_eq(int(world.hero.equipment.main_hand.id), 35)
	assert_false(world.hero.equipment.has("off_hand"))
	var found := false
	for item in world.hero.inventory:
		if not item.is_empty() and int(item.id) == 2362:
			found = true
	assert_true(found)


func test_life_tap_checks_health_before_spending_time_or_randomness() -> void:
	var world := _world()
	_learn(world, &"life_tap_1")
	var value := SpellEffects.amount(world, SkillRank.catalog(&"life_tap_1"), false, false)
	world.hero.health = value
	var random_state := world.combat_random.state
	assert_false(world.cast_skill(&"life_tap_1"))
	assert_eq(world.turn_count, 0)
	assert_eq(world.combat_random.state, random_state)
	world.hero.health = value + 1
	world.hero.mana = 0
	assert_true(world.cast_skill(&"life_tap_1"))
	assert_eq(world.hero.health, 1)
	assert_eq(world.hero.mana, value)


func test_fade_changes_threat_target_without_disengaging_or_allowing_combat_save() -> void:
	var world := _world()
	_cast(world, &"summon_voidwalker_1")
	var pet := SummonRules.active(world, "pet")
	var enemy := _enemy(world)
	enemy.engaged = true
	SummonRules.add_threat(world, enemy, null, 60)
	SummonRules.add_threat(world, enemy, pet, 20)
	assert_null(SummonRules.enemy_target(world, enemy))
	_cast(world, &"fade_1")
	assert_same(SummonRules.enemy_target(world, enemy), pet)
	assert_false(world.can_save())
	world.hero.buffs[&"fade_1"].until = world.turn_count + 1
	world.wait_turn()
	assert_null(SummonRules.enemy_target(world, enemy))


func test_new_class_referrals_use_current_class_and_exact_source_letters() -> void:
	for category: StringName in [&"Paladin", &"Priest", &"Warlock", &"Shaman"]:
		var world := NorthshireZone.create_world(29, true)
		world.hero.selected_class = category
		var identifier: String = {&"Paladin": "3101", &"Priest": "3103", &"Warlock": "3105", &"Shaman": "shaman_referral"}[category]
		var quest: Dictionary = QuestData.QUESTS[identifier]
		assert_eq(quest.category, String(category))
		var receiver: GridActor
		for actor in world.actors:
			if actor.npc_id == int(quest.receiver):
				receiver = actor
		assert_not_null(receiver)
		assert_eq(receiver.service, category)
	assert_eq(int(QuestData.QUESTS["3103"].source_item), 9548)


func test_low_level_spell_power_scaling_and_curse_total_have_independent_numeric_fixtures() -> void:
	var world := _world()
	world.hero.level = 1
	world.hero.spell_power = 100
	assert_eq(SpellEffects.amount(world, SkillRank.catalog(&"shadow_bolt_1"), false, false), 36)
	world.hero.spell_power = 0
	var enemy := _enemy(world)
	_learn(world, &"curse_of_agony_1")
	# Restore a learned rank directly as the Loop does; its training level never gates use.
	world.hero.learned_skills.append(SkillRank.catalog(&"curse_of_agony_1"))
	_cast(world, &"curse_of_agony_1", enemy)
	var health := enemy.health
	for index in range(24):
		world.wait_turn()
	assert_eq(health - enemy.health, 84)
	assert_true(world.periodic_effects.is_empty())


func test_pet_level_ten_stats_match_pinned_vanilla_source_fixture() -> void:
	var world := _world()
	_cast(world, &"summon_voidwalker_1")
	var pet := SummonRules.active(world, "pet")
	assert_eq(pet.max_health, 260)
	assert_eq(pet.melee.armor, 744)
	assert_eq(pet.melee.attack_power, 38)
	assert_almost_eq(pet.melee.damage_min, 7.9604, 0.0001)
	assert_almost_eq(pet.melee.damage_max, 11.9406, 0.0001)
	_cast(world, &"summon_imp_1")
	pet = SummonRules.active(world, "pet")
	assert_eq(pet.max_health, 225)
	assert_eq(pet.melee.armor, 200)
	assert_eq(pet.melee.attack_power, 19)


func test_expired_totem_cannot_hold_occupancy_or_enemy_threat_at_boundary() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(11, 10))
	_cast(world, &"stoneclaw_totem_1")
	var totem := SummonRules.active(world, "earth")
	totem.expires_turn = world.turn_count + 1
	enemy.engaged = true
	SummonRules.add_threat(world, enemy, totem, 500)
	world.wait_turn()
	assert_false(totem.alive)
	assert_null(SummonRules.enemy_target(world, enemy))
	assert_false(totem.corpse_visible)


func test_enemy_disengagement_clears_previous_pet_threat() -> void:
	var world := _world()
	_cast(world, &"summon_imp_1")
	var pet := SummonRules.active(world, "pet")
	var enemy := _enemy(world, Vector2i(20, 20))
	for direction in GridWorld.DIRECTIONS:
		world.blocked_tiles[enemy.tile + direction] = true
	enemy.engaged = true
	SummonRules.add_threat(world, enemy, pet, 500)
	for boundary in range(5):
		world.wait_turn()
	assert_false(enemy.engaged)
	assert_true(enemy.threat.is_empty())
	assert_false(world.in_combat())


func test_save_rejects_mismatched_pet_identity_and_negative_effect_deadlines() -> void:
	var game := GameSession.new()
	game.world = _world()
	_cast(game.world, &"summon_imp_1")
	var data := SaveCodec.capture(game)
	var bad := data.duplicate(true)
	bad.actors[0].state.npc_id = 1860
	assert_null(SaveCodec.restore(bad, true))
	bad = data.duplicate(true)
	bad.hero.healthstone_ready_turn = -1
	assert_null(SaveCodec.restore(bad, true))
	bad = data.duplicate(true)
	bad.actors[0].state.weakened_until = -1
	assert_null(SaveCodec.restore(bad, true))
