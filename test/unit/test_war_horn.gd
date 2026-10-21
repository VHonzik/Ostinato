extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 80, 80), Vector2i(40, 40), 97, false)
	InventoryRules.receive(world.hero, ItemData.instance(ItemData.WAR_HORN_ID))
	return world


func _enemy(world: GridWorld, tile: Vector2i) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.stunned_until = 999
	enemy.health = 10
	enemy.max_health = 10
	world.actors.append(enemy)
	return enemy


func test_horn_is_reusable_free_and_has_thirty_turn_cooldown_after_two_turn_cast() -> void:
	var world := _world()
	world.hero.casting_credit = 0.75
	assert_true(world.consume_item(0))
	assert_eq(world.turn_count, 1)
	assert_not_null(world.pending_skill)
	assert_false(world.can_save())
	assert_false(world.hero.cooldowns.has("war_horn"))
	assert_false(world.use_war_horn(), "Cannot start another use while casting.")
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_true(world.continue_cast())
	assert_eq(world.turn_count, 2)
	assert_null(world.pending_skill)
	assert_eq(world.hero.casting_credit, 0.75)
	assert_eq(world.hero.rage, 0)
	assert_true(world.has_war_horn())
	assert_eq(world.hero.inventory[0].quantity, 1)
	assert_eq(int(world.hero.cooldowns.war_horn) - world.turn_count, 30)
	for turn in range(29):
		world.wait_turn()
	assert_false(world.consume_item(0))
	assert_eq(world.turn_count, 31)
	world.wait_turn()
	assert_true(world.use_war_horn())
	assert_true(world.continue_cast())
	assert_eq(world.turn_count, 34)


func test_cancelled_cast_has_no_effect_or_cooldown_and_item_removal_prevents_completion() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(50, 40))
	assert_true(world.use_war_horn())
	world.cancel_cast()
	assert_null(world.pending_skill)
	assert_eq(enemy.health, 10)
	assert_false(enemy.engaged)
	assert_false(world.hero.cooldowns.has("war_horn"))
	assert_true(world.has_war_horn())
	assert_true(world.use_war_horn())
	world.hero.inventory[0] = {}
	assert_true(world.continue_cast())
	assert_eq(enemy.health, 10)
	assert_false(world.hero.cooldowns.has("war_horn"))
	assert_false(world.use_war_horn())
	assert_eq(world.turn_count, 3)


func test_screen_edges_use_current_viewport_and_include_partially_visible_tiles() -> void:
	var world := _world()
	world.screen_size_tiles = Vector2(10, 6)
	var edge := _enemy(world, Vector2i(45, 43))
	var outside_x := _enemy(world, Vector2i(46, 40))
	var outside_y := _enemy(world, Vector2i(40, 44))
	assert_true(world.use_war_horn())
	assert_true(world.continue_cast())
	assert_eq(edge.health, 9)
	assert_eq(outside_x.health, 10)
	assert_eq(outside_y.health, 10)


func test_enemy_actions_and_weapon_timers_continue_and_death_interrupts_the_cast() -> void:
	var world := _world()
	var enemy := _enemy(world, world.player_tile + Vector2i.RIGHT)
	enemy.stunned_until = 0
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.melee.ignores_dodge = true
	enemy.melee.hit = 1000
	enemy.melee.critical = 0
	enemy.melee.damage_min = 100
	enemy.melee.damage_max = 100
	world.hero.swing.remaining = 5.0
	world.hero.swing._active = true
	world.auto_attack_target = enemy
	world.hero.health = 1
	assert_true(world.use_war_horn())
	assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED)
	assert_null(world.pending_skill)
	assert_eq(enemy.health, 10, "Death before completion prevents the horn effect.")
	assert_false(world.hero.cooldowns.has("war_horn"))
	assert_lt(world.hero.swing.remaining, 5.0)


func test_horn_cooldown_is_not_reduced_by_finisher_passives() -> void:
	var world := _world()
	world.hero.learn_skill(SkillDefinition.catalog(&"restless_blades_1"))
	world.hero.cooldowns = {"war_horn": 30, "charge": 10}
	ClassToolkitRules.finish(world, 5, SkillDefinition.catalog(&"eviscerate_1"))
	assert_eq(world.hero.cooldowns.war_horn, 30)
	assert_eq(world.hero.cooldowns.charge, 7)


func test_save_preserves_item_claim_and_cooldown_but_loop_reset_loses_them() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.loop_count = 2
	game.world = _world()
	var world := game.world
	world.war_horn_received = true
	world.hero.selected_class = &"Shaman"
	assert_true(world.assign_hotbar(0, ItemData.WAR_HORN_HOTBAR_ID))
	assert_true(world.use_war_horn(), "Item works in another selected class.")
	assert_true(world.continue_cast())
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(SaveCodec.capture(game))), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(restored.has_war_horn())
	assert_true(restored.war_horn_received)
	assert_eq(int(restored.hero.cooldowns.war_horn) - restored.turn_count, 30)
	assert_eq(restored.hotbar[0], ItemData.WAR_HORN_HOTBAR_ID)
	assert_false(restored.use_war_horn())
	game.restore(restored, game.seed_value, game.loop_count)
	restored.hero.health = 0
	assert_true(game.restart_after_death())
	assert_false(game.world.has_war_horn())
	assert_false(game.world.war_horn_received)
	assert_false(game.world.hotbar.has(ItemData.WAR_HORN_HOTBAR_ID))
	assert_true(game.world.hero.cooldowns.is_empty())
	assert_null(SkillDefinition.catalog(&"booming_shout_1"))
