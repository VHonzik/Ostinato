extends GutTest


func test_all_included_mage_druid_ranks_are_trainable_and_resolvable() -> void:
	var world := _world()
	for category: StringName in [&"Mage", &"Druid"]:
		world.hero.selected_class = category
		for skill in SkillRank.trainer_skills(category):
			if world.hero.find_skill(skill.id) == null:
				assert_true(world.train(category, skill.id), skill.id)
			assert_lte(skill.training_level, 10)
			assert_gt(skill.source_id, 0)
	assert_eq(world.hero.learned_skills.size(), 29, "26 sourced ranks plus three development skills.")
	assert_null(SkillRank.catalog(&"bear_form_1"))
	assert_null(SkillRank.catalog(&"moonfire_3"))


func test_every_included_rank_can_execute_its_action_without_diagnostics() -> void:
	for category: StringName in [&"Mage", &"Druid"]:
		for rank in SkillRank.trainer_skills(category):
			var world := _world()
			world.hero.learn_skill(rank)
			var enemy := _enemy(world)
			var target := enemy if rank.target == SkillRank.Target.ENEMY else null
			assert_true(world.cast_skill(rank.id, target), rank.id)
			while world.pending_skill != null:
				world.continue_cast()
			assert_gt(world.turn_count, 0)
			assert_lt(world.hero.mana, world.hero.max_mana, rank.id)


func test_higher_armor_rank_replaces_lower_without_stacking_and_expiry_clamps_maxima() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"frost_armor_2"))
	var base := world.hero.melee.armor
	assert_true(world.cast_skill(&"frost_armor_1"))
	assert_eq(world.hero.melee.armor, base + 30)
	assert_true(world.cast_skill(&"frost_armor_2"))
	assert_eq(world.hero.melee.armor, base + 110)
	assert_false(world.hero.buffs.has(&"frost_armor_1"))
	var mana := world.hero.mana
	var turn := world.turn_count
	assert_false(world.cast_skill(&"frost_armor_1"), "A weaker rank cannot replace a stronger active buff.")
	assert_eq(world.hero.mana, mana)
	assert_eq(world.turn_count, turn)
	world.hero.learn_skill(SkillRank.catalog(&"mark_2"))
	var maximum := world.hero.max_mana
	assert_true(world.cast_skill(&"mark_2"))
	assert_eq(world.hero.max_mana, maximum + 30)
	world.hero.mana = world.hero.max_mana
	world.hero.buffs[&"mark_2"].until = world.turn_count + 1
	world.wait_turn()
	assert_eq(world.hero.max_mana, maximum)
	assert_eq(world.hero.mana, maximum)


func test_channel_spends_mana_once_delivers_ticks_and_cancellation_awards_no_credit() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"missiles_1"))
	var enemy := _enemy(world)
	world.hero.casting_credit = 0.6
	var mana := world.hero.mana
	assert_true(world.cast_skill(&"missiles_1", enemy))
	assert_eq(world.hero.mana, mana - 85)
	assert_lt(enemy.health, enemy.max_health)
	assert_not_null(world.pending_skill)
	var health := enemy.health
	world.cancel_cast()
	assert_eq(world.hero.casting_credit, 0.6)
	world.wait_turn()
	assert_eq(enemy.health, health, "Cancel prevents remaining missiles.")
	assert_true(world.cast_skill(&"missiles_1", enemy))
	world.continue_cast()
	world.continue_cast()
	assert_null(world.pending_skill)
	assert_eq(world.hero.casting_credit, 0.6)
	assert_eq(world.hero.mana, mana - 170)


func test_individual_cooldown_rejects_without_time_or_resource_cost() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"fire_blast_1"))
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"fire_blast_1", enemy))
	var mana := world.hero.mana
	assert_false(world.cast_skill(&"fire_blast_1", enemy))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.mana, mana)
	for index in range(8):
		world.wait_turn()
	assert_true(world.cast_skill(&"fire_blast_1", enemy))


func test_periodic_heal_first_tick_refresh_and_noncombat_save_eligibility() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"rejuvenation_1"))
	var friendly := GridActor.new(Vector2i(5, 4))
	friendly.health = 1
	world.actors.append(friendly)
	assert_true(world.cast_skill(&"rejuvenation_1", friendly))
	assert_true(world.can_save(), "Healing over time alone does not constitute combat.")
	world.wait_turn()
	world.wait_turn()
	assert_eq(friendly.health, 1)
	world.wait_turn()
	assert_eq(friendly.health, 9)
	assert_true(world.cast_skill(&"rejuvenation_1", friendly))
	assert_eq(world.periodic_effects.size(), 1)
	for index in range(12):
		world.wait_turn()
	assert_eq(friendly.health, 41)
	assert_true(world.periodic_effects.is_empty())


func test_different_damage_over_time_spells_coexist_and_same_family_refreshes() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"moonfire_1"))
	world.hero.learn_skill(SkillRank.catalog(&"fireball_2"))
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"fireball_1", enemy))
	world.continue_cast()
	assert_true(world.cast_skill(&"moonfire_1", enemy))
	assert_eq(world.periodic_effects.size(), 2)
	assert_true(world.cast_skill(&"fireball_2", enemy))
	while world.pending_skill != null:
		world.continue_cast()
	assert_eq(world.periodic_effects.size(), 2)
	var ids: Array = world.periodic_effects.map(func(effect: Dictionary) -> String: return effect.skill)
	assert_has(ids, "fireball_2")
	assert_has(ids, "moonfire_1")


func test_polymorph_restricts_creature_types_heals_and_any_damage_breaks_it() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"polymorph_1"))
	var enemy := _enemy(world)
	enemy.creature_type = "demon"
	assert_false(world.cast_skill(&"polymorph_1", enemy))
	assert_eq(world.turn_count, 0)
	enemy.creature_type = "beast"
	enemy.health = 100
	assert_true(world.cast_skill(&"polymorph_1", enemy))
	world.continue_cast()
	assert_gt(enemy.polymorphed_until, world.turn_count)
	var health := enemy.health
	world.wait_turn()
	assert_gt(enemy.health, health)
	SpellEffects.damage(world, enemy, 1, "Test damage")
	assert_eq(enemy.polymorphed_until, 0)


func test_roots_reject_indoors_and_stop_movement_but_not_adjacent_attacks() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"roots_1"))
	var enemy := _enemy(world)
	world.indoor_tiles[world.player_tile] = true
	assert_false(world.cast_skill(&"roots_1", enemy))
	world.indoor_tiles.clear()
	assert_true(world.cast_skill(&"roots_1", enemy))
	world.continue_cast()
	assert_gt(enemy.rooted_until, world.turn_count)
	var tile := enemy.tile
	world.wait_turn()
	assert_eq(enemy.tile, tile)
	enemy.tile = world.player_tile + Vector2i.RIGHT
	enemy.swing.remaining = 0
	enemy.melee.level = 60
	var health := world.hero.health
	world.wait_turn()
	assert_lt(world.hero.health, health)


func test_frost_nova_affects_visible_enemies_in_radius_but_not_friendlies() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"nova_1"))
	var enemy := _enemy(world)
	enemy.tile = Vector2i(6, 4)
	var friendly := GridActor.new(Vector2i(4, 5))
	world.actors.append(friendly)
	assert_true(world.cast_skill(&"nova_1"))
	assert_lt(enemy.health, enemy.max_health)
	assert_gt(enemy.rooted_until, world.turn_count)
	assert_eq(friendly.health, friendly.max_health)
	assert_eq(friendly.rooted_until, 0)


func test_conjuring_rechecks_inventory_at_completion_without_charge_or_credit_on_failure() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"water_1"))
	var mana := world.hero.mana
	assert_true(world.cast_skill(&"water_1"))
	for index in range(40):
		world.hero.inventory[index] = ItemData.instance(35)
	while world.pending_skill != null:
		world.continue_cast()
	assert_eq(world.hero.mana, mana)
	assert_eq(world.hero.casting_credit, 0.0)
	assert_eq(world.turn_count, 3)
	world.hero.inventory[0] = {}
	assert_true(world.cast_skill(&"water_1"))
	while world.pending_skill != null:
		world.continue_cast()
	assert_eq(world.hero.inventory[0].id, 5350)
	assert_eq(world.hero.inventory[0].quantity, 14, "At level 10 rank 1 produces 2 + 2*(10-4).")


func test_spell_power_healing_power_haste_and_resistance_have_numeric_effects() -> void:
	var world := _world()
	var skill := SkillRank.catalog(&"fireball_2")
	world.combat_random.seed = 67
	var base := SpellEffects.amount(world, skill, false)
	world.hero.spell_power = 100
	world.combat_random.seed = 67
	assert_eq(SpellEffects.amount(world, skill, false), base + 27)
	skill = SkillRank.catalog(&"healing_touch_2")
	world.combat_random.seed = 67
	base = SpellEffects.amount(world, skill, false)
	world.hero.healing_power = 100
	world.combat_random.seed = 67
	assert_eq(SpellEffects.amount(world, skill, false), base + 31)
	assert_eq(SpellResistance.percent(10, 10, 100, true), 75.0)
	assert_eq(SpellResistance.mitigate(100, 0.0, 0.5), 100)
	assert_lt(SpellResistance.mitigate(100, 75.0, 0.5), 100)
	world.hero.learn_skill(SkillRank.catalog(&"fireball_2"))
	world.hero.haste = 2.0
	assert_true(world.cast_skill(&"fireball_2", _enemy(world)))
	assert_eq(world.turn_count, 1)
	assert_null(world.pending_skill)


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 18, 18), Vector2i(4, 4), 97)
	world.hero.level = 10
	world.hero._apply_level_stats()
	world.hero.copper = 10000
	return world


func _enemy(world: GridWorld) -> GridActor:
	var enemy := GridActor.new(Vector2i(7, 4))
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.max_health = 1000
	enemy.health = 1000
	enemy.melee.level = 1
	enemy.swing.remaining = 1000
	world.actors.append(enemy)
	return enemy


func test_root_break_scales_with_damage_and_rooted_sheep_cannot_wander() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.rooted_until = 20
	enemy.polymorphed_until = 20
	var tile := enemy.tile
	world.wait_turn()
	assert_eq(enemy.tile, tile)
	SpellEffects.damage(world, enemy, 50, "Root-breaking damage")
	assert_eq(enemy.rooted_until, 0, "50 damage always breaks a root on a level-one target.")
	assert_eq(enemy.polymorphed_until, 0)


func test_weaker_rejuvenation_cannot_replace_stronger_active_healing() -> void:
	var world := _world()
	world.hero.learn_skill(SkillRank.catalog(&"rejuvenation_1"))
	world.hero.learn_skill(SkillRank.catalog(&"rejuvenation_2"))
	assert_true(world.cast_skill(&"rejuvenation_2"))
	var mana := world.hero.mana
	assert_false(world.cast_skill(&"rejuvenation_1"))
	assert_eq(world.hero.mana, mana)
	assert_eq(world.turn_count, 1)
	assert_eq(world.periodic_effects[0].skill, "rejuvenation_2")
