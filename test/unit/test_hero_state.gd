extends GutTest


func test_starting_warrior_has_attributes_rage_and_known_abilities() -> void:
	var hero := HeroState.new()
	assert_eq(_attributes(hero), [20, 20, 20])
	assert_eq([hero.level, hero.experience], [1, 0])
	assert_eq([hero.health, hero.max_health, hero.rage], [51, 51, 0])
	assert_not_null(hero.find_skill(&"mortal_strike_1"))
	assert_not_null(hero.find_skill(&"heroic_strike_1"))
	assert_null(hero.find_skill(&"fireball_2"), "Leveling does not grant unlearned skills.")


func test_exact_first_threshold_and_noop_awards() -> void:
	var hero := HeroState.new()
	assert_eq(hero.add_experience(0).size(), 0)
	assert_eq(hero.add_experience(-100).size(), 0)
	assert_eq(hero.add_experience(399).size(), 0)
	assert_eq([hero.level, hero.experience], [1, 399])
	assert_eq(hero.add_experience(1), PackedInt32Array([2]))
	assert_eq([hero.level, hero.experience, hero.experience_to_next_level()], [2, 0, 900])
	assert_eq(_attributes(hero), [20, 20, 20])
	assert_eq(hero.health, 57)


func test_excess_xp_and_multiple_levels_are_retained() -> void:
	var hero := HeroState.new()
	assert_eq(hero.add_experience(450), PackedInt32Array([2]))
	assert_eq([hero.level, hero.experience], [2, 50])
	var another := HeroState.new()
	assert_eq(another.add_experience(1350), PackedInt32Array([2, 3]))
	assert_eq([another.level, another.experience], [3, 50])
	assert_eq(_attributes(another), [20, 20, 21])
	assert_eq(another.health, 72)


func test_level_ten_growth_and_level_up_refills_resources_without_new_skills() -> void:
	var hero := HeroState.new()
	var ranks_before := hero.learned_skills.size()
	hero.health = 1
	hero.add_experience(27600)
	assert_eq([hero.level, hero.experience, hero.experience_to_next_level()], [10, 0, 7600])
	assert_eq(_attributes(hero), [21, 22, 23])
	assert_eq(hero.health, 177)
	assert_eq(hero.learned_skills.size(), ranks_before)


func test_classic_total_to_sixty_and_uncapped_development_fallback() -> void:
	var hero := HeroState.new()
	hero.add_experience(4084700)
	assert_eq([hero.level, hero.experience, hero.experience_to_next_level()], [60, 0, 209800])
	assert_eq(_attributes(hero), [30, 35, 45])
	assert_eq(hero.health, 1630)
	hero.add_experience(419650)
	assert_eq([hero.level, hero.experience], [62, 50])
	assert_eq(_attributes(hero), [30, 35, 47])
	assert_eq(hero.health, 1734)


func test_split_and_single_rewards_produce_identical_progression() -> void:
	var single := HeroState.new()
	var split := HeroState.new()
	single.add_experience(45000)
	for index in range(100):
		split.add_experience(450)
	assert_eq([split.level, split.experience], [single.level, single.experience])
	assert_eq(_attributes(split), _attributes(single))


func test_learning_rejects_insufficient_level_and_duplicate_skill() -> void:
	var hero := HeroState.new()
	var skill := SkillDefinition.new(&"test_rank_2", "Test", &"Shaman", 2,
		"Test fixture.", SkillDefinition.Effect.PRACTICE)
	assert_false(hero.learn_skill(skill))
	assert_null(hero.find_skill(skill.id))
	hero.add_experience(400)
	assert_true(hero.learn_skill(skill))
	assert_false(hero.learn_skill(skill))
	var duplicate := SkillDefinition.new(skill.id, "Duplicate", &"Shaman", 1,
		"Test fixture.", SkillDefinition.Effect.PRACTICE)
	assert_false(hero.learn_skill(duplicate))
	assert_false(hero.learn_skill(null))
	assert_same(hero.find_skill(skill.id), skill)


func test_release_baseline_contains_no_development_skills() -> void:
	var hero := HeroState.new(false)
	assert_eq(hero.learned_skills.size(), 2)
	for skill in hero.learned_skills:
		assert_false(skill.development_only)
	assert_null(hero.find_skill(&"experience_1"))
	assert_null(hero.find_skill(&"death_1"))


func _attributes(hero: HeroState) -> Array[int]:
	return [hero.strength, hero.agility, hero.stamina]
