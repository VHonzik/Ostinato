extends GutTest


func test_death_rebuilds_world_and_preserves_only_game_progression() -> void:
	var game := GameSession.new()
	game.new_game(17)
	game.world.hero.add_experience(400)
	var learned := SkillDefinition.new(&"retained_test", "Retained", &"Shaman", 2,
		"Test skill", SkillDefinition.Effect.PRACTICE)
	assert_true(game.world.hero.learn_skill(learned))
	game.world.hotbar[0] = learned.id
	game.world.hotbar_locked = true
	game.world.movement_credit = 0.75
	game.world.hero.copper = 100
	game.world.hero.buffs[&"battle_shout_1"] = {"armor": 30, "until": 100}
	game.world.ever_accepted_quest = true
	game.world.actors[5].alive = false
	var old := game.world
	assert_true(old.cast_skill(&"death_1"))
	assert_true(game.restart_after_death())
	assert_eq(game.seed_value, 17)
	assert_eq(game.loop_count, 2)
	assert_eq([game.world.hero.level, game.world.hero.experience], [1, 0])
	assert_eq(game.world.hero.health, 51)
	assert_eq(game.world.hero.selected_class, &"Warrior")
	assert_eq(game.world.hero.copper, 0)
	assert_eq(game.world.hero.buffs, {})
	assert_eq(game.world.movement_credit, 0.0)
	assert_eq(game.world.hero.casting_credit, 0.0)
	assert_true(game.world.actors[5].alive)
	assert_false(game.world.ever_accepted_quest)
	assert_same(game.world.hero.find_skill(learned.id), learned)
	assert_eq(game.world.hotbar[0], learned.id)
	assert_true(game.world.hotbar_locked)
	assert_true(game.world.cast_skill(learned.id))
	assert_false(game.restart_after_death(), "One death creates exactly one Loop.")
	old.wait_turn()
	old.continue_cast()
	old.continue_melee()
	assert_eq(game.world.turn_count, 1, "Abandoned references cannot advance the new world.")


func test_new_game_resets_learning_hotbar_class_and_seed() -> void:
	var game := GameSession.new()
	game.new_game(19)
	game.world.hero.health = 0
	game.restart_after_death()
	game.world.hero.selected_class = &"Shaman"
	game.world.class_selected = true
	assert_true(game.world.train(&"Shaman", &"lightning_shield_1"))
	game.world.hotbar[0] = &"lightning_shield_1"
	game.new_game(29)
	assert_eq(game.seed_value, 29)
	assert_eq(game.loop_count, 1)
	assert_null(game.world.hero.find_skill(&"lightning_shield_1"))
	assert_eq(game.world.hotbar.slice(0, 2), [&"mortal_strike_1", &"whirlwind_1"])
	assert_eq(game.world.hotbar.count(&""), 17)
	assert_eq(game.world.hero.selected_class, &"Warrior")


func test_accepting_any_quest_closes_selection_but_leveling_keeps_it_available() -> void:
	var game := GameSession.new()
	game.new_game(3)
	game.world.hero.health = 0
	game.restart_after_death()
	game.world.ever_accepted_quest = true
	assert_false(game.can_select_class())
	game.world.hero.health = 0
	game.restart_after_death()
	assert_true(game.can_select_class())
	game.world.hero.add_experience(400)
	assert_true(game.can_select_class(), "The quest cutoff replaces the legacy level-one cutoff.")


func test_outfit_exchange_preserves_acquired_gear_and_is_atomic_when_full() -> void:
	var hero := HeroState.new()
	StarterGear.equip_outfit(hero)
	hero.equipment.armor.starter = false
	for index in range(40):
		hero.inventory[index] = ItemData.instance(35)
	var before := hero.equipment.duplicate(true)
	assert_false(StarterGear.exchange(hero, &"Paladin"))
	assert_eq(hero.equipment, before)
	assert_eq(hero.selected_class, &"Warrior")
	hero.inventory[7] = {}
	assert_true(StarterGear.exchange(hero, &"Paladin"))
	assert_eq(hero.equipment.armor.id, 2379)
	assert_false(hero.equipment.armor.starter)
	assert_eq(hero.inventory[7].id, 2379)


func test_obsolete_classes_and_abilities_are_unavailable() -> void:
	var hero := HeroState.new()
	for category: StringName in [&"Mage", &"Druid", &"Warlock", &"Priest"]:
		assert_true(SkillDefinition.starting_skills(category).is_empty())
		assert_true(SkillDefinition.trainer_skills(category).is_empty())
		assert_false(StarterGear.exchange(hero, category))
	for identifier: StringName in [&"fireball_1", &"wrath_1", &"summon_imp_1",
		&"smite_1", &"water_1", &"pet_attack", &"parry_1"]:
		assert_null(SkillDefinition.catalog(identifier))
	assert_eq(hero.selected_class, &"Warrior")
