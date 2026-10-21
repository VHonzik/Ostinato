extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 16, 16), Vector2i(5, 5), 97, false)
	world.hero.equipment.clear()
	world.hero.equipment.weapons = ItemData.instance(5580)
	world.hero.refresh_stats()
	world.hero.health = world.hero.max_health
	world.hero.learn_skill(SkillDefinition.catalog(&"shield_block_1"))
	return world


func _roll_seed(blocked: bool) -> int:
	var generator := RandomNumberGenerator.new()
	for seed_value in range(1000):
		generator.seed = seed_value
		var roll := generator.randf()
		if (blocked and roll > 0.28 and roll < 0.3
			or not blocked and roll > 0.3 and roll < 0.32):
			return seed_value
	fail_test("No controlled Shield Block roll found.")
	return -1


func _enemy(world: GridWorld) -> GridActor:
	var enemy := GridActor.new(world.player_tile + Vector2i.RIGHT)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.awards_experience = false
	enemy.max_health = 10000
	enemy.health = enemy.max_health
	enemy.melee.level = world.hero.level
	enemy.melee.ignores_dodge = true
	enemy.melee.hit = 100.0
	enemy.melee.critical = 0.0
	enemy.melee.attack_power = 0
	enemy.melee.damage_min = 20.0
	enemy.melee.damage_max = 20.0
	enemy.melee.interval = 2.4
	world.actors.append(enemy)
	return enemy


func test_shield_block_uses_thirty_percent_chance_and_rounds_partial_hits_up() -> void:
	for blocked in [true, false]:
		var world := _world()
		world.combat_random.seed = _roll_seed(blocked)
		assert_eq(ClassSpellEffects.absorb(world, null, 10, true), 3 if blocked else 10)
	var world := _world()
	world.hero.find_skill(&"shield_block_1").coefficient = 1.0
	assert_eq(ClassSpellEffects.absorb(world, null, 5, true), 2)
	assert_eq(ClassSpellEffects.absorb(world, null, 1, true), 1, "Partial block never becomes immunity.")
	assert_eq(ClassSpellEffects.absorb(world, null, 10, true), 3,
		"Every hit can block again in the same turn.")


func test_ineligible_damage_never_rolls_block() -> void:
	for condition in ["unlearned", "unarmed", "two_hand", "dual_wield", "magic", "summon", "immune", "zero"]:
		var world := _world()
		world.hero.find_skill(&"shield_block_1").coefficient = 1.0
		var physical := true
		var target: GridActor = null
		var amount := 10
		match condition:
			"unlearned": world.hero.learned_skills.clear()
			"unarmed": world.hero.equipment.erase("weapons")
			"two_hand": world.hero.equipment.weapons = ItemData.instance(5579)
			"dual_wield": world.hero.equipment.weapons = ItemData.instance(2224)
			"magic": physical = false
			"summon": target = GridActor.new(world.player_tile + Vector2i.DOWN)
			"immune": world.hero.buffs[&"divine_shield_1"] = {"armor": 0, "until": 100}
			"zero": amount = 0
		var state := world.combat_random.state
		assert_eq(ClassSpellEffects.absorb(world, target, amount, physical),
			0 if condition in ["immune", "zero"] else 10, condition)
		assert_eq(world.combat_random.state, state, condition)


func test_misses_and_dodges_do_not_consume_a_block_roll() -> void:
	for missed in [true, false]:
		var world := _world()
		var enemy := _enemy(world)
		enemy.melee.ignores_dodge = false
		world.hero.melee.dodge = 100.0
		if missed:
			enemy.melee.hit = -1000.0
		var expected := RandomNumberGenerator.new()
		expected.state = world.combat_random.state
		expected.randf()
		expected.randf()
		var health := world.hero.health
		NpcRules._attack(world, enemy, NpcTarget.new(world, null))
		assert_eq(world.hero.health, health)
		assert_eq(world.combat_random.state, expected.state)
		assert_eq(world.hero.rage, 0)


func test_block_precedes_lethal_damage_and_preserves_reactive_effects() -> void:
	var world := _world()
	world.hero.find_skill(&"shield_block_1").coefficient = 1.0
	world.hero.learn_skill(SkillDefinition.catalog(&"enrage_1"))
	world.hero.find_skill(&"enrage_1").coefficient = 1.0
	world.hero.learn_skill(SkillDefinition.catalog(&"lightning_shield_1"))
	ClassToolkitRules.apply(world, &"lightning_shield_1", {"charges": 6, "ready": 0})
	world.hero.inventory[0] = ItemData.instance(ItemData.LUCKY_CHARM_ID)
	world.hero.health = 15
	world.hero.melee.armor = 0
	var enemy := _enemy(world)
	enemy.melee.critical = 100.0
	NpcRules._attack(world, enemy, NpcTarget.new(world, null))
	assert_eq(world.hero.health, 3, "A 40-damage critical becomes 12 before checking death.")
	assert_false(world.is_terminal())
	assert_eq(world.hero.inventory[0].id, ItemData.LUCKY_CHARM_ID)
	assert_eq(world.hero.rage, 3)
	assert_true(world.hero.buffs.has(&"enrage_1"))
	assert_eq(world.hero.buffs[&"lightning_shield_1"].charges, 5)
	assert_lt(enemy.health, enemy.max_health)
	assert_true(world.messages.has("Shield Block prevents 28 damage."))


func test_block_stacks_after_death_wish_and_banner_protection() -> void:
	var world := _world()
	world.hero.find_skill(&"shield_block_1").coefficient = 1.0
	world.hero.learn_skill(SkillDefinition.catalog(&"recklessness_1"))
	world.hero.health = 1
	world.war_banner = {"tile": world.player_tile, "until": 100}
	assert_eq(ClassSpellEffects.absorb(world, null, 100, true), 30,
		"100 -> 110 from Death Wish -> 99 from banner -> 30 after block rounding.")


func test_combat_swap_costs_one_turn_and_enables_block_before_enemy_response() -> void:
	var world := _world()
	world.hero.find_skill(&"shield_block_1").coefficient = 1.0
	world.hero.equipment.weapons = ItemData.instance(5579)
	world.hero.refresh_stats()
	world.hero.inventory[0] = ItemData.instance(5580)
	var enemy := _enemy(world)
	world.auto_attack_target = enemy
	world.hero.swing.remaining = 2.5
	world.hero.swing._active = true
	var health := world.hero.health
	assert_true(world.in_combat())
	assert_true(world.equip_item(0))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.weapon_id(), 5580)
	assert_between(health - world.hero.health, 1, 6)
	assert_almost_eq(world.hero.swing.remaining, 1.5, 0.00001)
	assert_eq(world.auto_attack_target, enemy)
	assert_true(world.equip_item(0), "The displaced two-hand weapon stays available in Bags.")
	assert_eq(world.turn_count, 2)
	assert_eq(world.hero.weapon_id(), 5579)
	assert_almost_eq(world.hero.swing.remaining, 0.5, 0.00001)
	assert_eq(ClassSpellEffects.absorb(world, null, 10, true), 10,
		"Swapping away immediately disables block without unlearning it.")


func test_learning_survives_save_and_loop_reset_below_training_level() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	var world := game.world
	world.hero.learn_skill(SkillDefinition.catalog(&"shield_block_1"))
	world.hero.equipment.weapons = ItemData.instance(5580)
	world.hero.refresh_stats()
	world.combat_random.seed = _roll_seed(true)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(ClassSpellEffects.absorb(restored, null, 10, true), 3)
	game.restore(restored, game.seed_value, game.loop_count)
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	game.world.hero.selected_class = &"Rogue"
	assert_eq(game.world.hero.level, 1)
	assert_not_null(game.world.hero.find_skill(&"shield_block_1"))
	assert_false(game.world.cast_skill(&"shield_block_1"))
	assert_false(game.world.assign_hotbar(0, &"shield_block_1"))
	game.world.hero.equipment.weapons = ItemData.instance(5580)
	game.world.hero.refresh_stats()
	game.world.combat_random.seed = _roll_seed(true)
	assert_eq(ClassSpellEffects.absorb(game.world, null, 10, true), 3)
