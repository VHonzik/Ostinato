extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	world.hero.selected_class = &"Shaman"
	world.hero.class_progress[&"Shaman"] = 1000
	for identifier: StringName in [&"earth_elemental_1", &"lightning_shield_1", &"windfury_weapon_1"]:
		assert_true(world.hero.learn_skill(SkillDefinition.catalog(identifier)))
	world.hero.rage = 100
	return world


func _enemy(world: GridWorld, tile: Vector2i, engaged: bool = true) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = engaged
	enemy.max_health = 1000
	enemy.health = enemy.max_health
	enemy.awards_experience = false
	world.actors.append(enemy)
	return enemy


func test_free_preparation_costs_turns_but_preserves_battle_trance() -> void:
	var world := _world()
	world.hero.learn_skill(SkillDefinition.catalog(&"battle_trance_1"))
	ClassToolkitRules.apply(world, &"battle_trance_1", {"charges": 1})
	world.hero.rage = 0
	var start := world.turn_count
	assert_true(world.cast_skill(&"lightning_shield_1"))
	assert_true(world.cast_skill(&"windfury_weapon_1"))
	assert_eq(world.hero.rage, 0)
	assert_eq(world.turn_count, start + 2)
	assert_true(world.hero.buffs.has(&"battle_trance_1"))
	assert_eq(world.hero.progression_points(&"Shaman"), 1002)


func test_elemental_has_no_expiration_follows_player_and_cannot_be_replaced_alive() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"earth_elemental_1"))
	var elemental := SummonRules.active(world, "earth_elemental")
	assert_not_null(elemental)
	assert_eq(elemental.expires_turn, 0)
	var first_tile := elemental.tile
	world.player_tile = Vector2i(14, 14)
	for turn in range(65):
		world.wait_turn()
	assert_true(elemental.alive)
	assert_ne(elemental.tile, first_tile)
	assert_lte(GridWorld.tile_distance(elemental.tile, world.player_tile), 1)
	world.hero.rage = 100
	var before := world.turn_count
	var mastery := world.hero.progression_points(&"Shaman")
	assert_false(world.cast_skill(&"earth_elemental_1"), "An active elemental cannot be healed by resummoning.")
	assert_eq(world.hero.rage, 100)
	assert_eq(world.turn_count, before)
	assert_eq(world.hero.progression_points(&"Shaman"), mastery)
	SummonRules.remove(world, elemental)
	assert_true(world.cast_skill(&"earth_elemental_1"))
	assert_ne(SummonRules.active(world, "earth_elemental"), elemental)


func test_blocked_elemental_placement_is_free_and_dead_elemental_does_not_reset_cooldown() -> void:
	var world := _world()
	for direction in GridWorld.DIRECTIONS:
		world.blocked_tiles[world.player_tile + direction] = true
	assert_false(world.cast_skill(&"earth_elemental_1"))
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 100)
	assert_false(world.hero.cooldowns.has(&"earth_elemental"))
	assert_eq(world.hero.progression_points(&"Shaman"), 1000)
	world.blocked_tiles.clear()
	assert_true(world.cast_skill(&"earth_elemental_1"))
	SummonRules.remove(world, SummonRules.active(world, "earth_elemental"))
	assert_false(world.cast_skill(&"earth_elemental_1"), "Death leaves the long cooldown running.")
	assert_eq(world.turn_count, 1)


func test_elemental_taunts_all_nearby_engaged_hostiles_without_threat_race_or_idle_pulls() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"earth_elemental_1"))
	var elemental := SummonRules.active(world, "earth_elemental")
	var first := _enemy(world, elemental.tile + Vector2i.RIGHT)
	var second := _enemy(world, elemental.tile + Vector2i.LEFT)
	SummonRules.add_threat(world, first, null, 10000)
	assert_same(SummonRules.enemy_target(world, first), elemental)
	assert_same(SummonRules.enemy_target(world, second), elemental)
	var idle := _enemy(world, elemental.tile + Vector2i(0, -2), false)
	idle.aggro_range = 1
	assert_null(SummonRules.enemy_target(world, idle))
	elemental.tile = idle.tile + Vector2i.RIGHT
	NpcRules.acquire_hostiles(world)
	assert_false(idle.engaged, "The elemental must not pull an idle enemy.")
	first.tile = elemental.tile + Vector2i(5, 0)
	assert_null(SummonRules.enemy_target(world, first), "Taunt has a local range.")
	second.tile = elemental.tile + Vector2i(2, 0)
	world.sight_blockers[elemental.tile + Vector2i.RIGHT] = true
	assert_null(SummonRules.enemy_target(world, second), "Taunt cannot pass through walls.")
	world.sight_blockers.clear()
	assert_same(SummonRules.enemy_target(world, second), elemental)
	SummonRules.remove(world, elemental)
	assert_null(SummonRules.enemy_target(world, second), "A dead elemental cannot hold a taunt.")


func test_elemental_attacks_only_engaged_enemies_and_does_not_award_player_resources() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"earth_elemental_1"))
	var elemental := SummonRules.active(world, "earth_elemental")
	var enemy := _enemy(world, elemental.tile + Vector2i.RIGHT, false)
	enemy.melee.dodge = 0.0
	world.auto_attack_target = enemy
	elemental.melee.hit = 100.0
	var mastery := world.hero.progression_points(&"Shaman")
	SummonRules.act(world, elemental)
	assert_eq(enemy.health, enemy.max_health)
	enemy.engaged = true
	elemental.swing.remaining = 0.0
	world.hero.rage = 0
	SummonRules.act(world, elemental)
	assert_lt(enemy.health, enemy.max_health)
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.combo_points, 0)
	assert_eq(world.hero.progression_points(&"Shaman"), mastery)


func test_elemental_takes_a_few_stalker_turns_then_attacks_return_to_player() -> void:
	var world := _world()
	world.hero.level = 5
	world.hero.refresh_stats()
	world.hero.health = world.hero.max_health
	assert_true(world.cast_skill(&"earth_elemental_1"))
	var elemental := SummonRules.active(world, "earth_elemental")
	world._spawn_stalker(elemental.tile + Vector2i.RIGHT)
	var boss: GridActor = world.actors.back()
	boss.engaged = true
	# Isolate durability against ordinary landed hits from the live boss profile.
	boss.melee.hit = 100.0
	boss.melee.critical = -100.0
	world.hero.melee.dodge = 0.0
	var health := world.hero.health
	var elapsed := 0
	while elemental.alive and elapsed < 10:
		world.wait_turn()
		elapsed += 1
	assert_false(elemental.alive)
	assert_between(elapsed, 3, 7)
	assert_eq(world.hero.health, health, "The elemental buys time without damaging the player.")
	assert_null(SummonRules.enemy_target(world, boss))
	for turn in range(4):
		world.wait_turn()
	assert_lt(world.hero.health, health)


func test_elemental_save_roundtrip_keeps_health_cooldown_and_singleton_then_loop_clears_it() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	var world := game.world
	world.hero.class_progress[&"Shaman"] = 110
	world.hero.learn_skill(SkillDefinition.catalog(&"earth_elemental_1"))
	world.hero.rage = 100
	assert_true(world.cast_skill(&"earth_elemental_1"))
	var elemental := SummonRules.active(world, "earth_elemental")
	elemental.health -= 7
	var snapshot := SaveCodec.capture(game)
	var elemental_index := world.actors.find(elemental)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(snapshot)), false)
	assert_not_null(restored)
	if restored == null:
		return
	var saved_elemental := SummonRules.active(restored, "earth_elemental")
	assert_not_null(saved_elemental)
	assert_eq(saved_elemental.health, elemental.health)
	assert_eq(saved_elemental.expires_turn, 0)
	assert_eq(restored.hero.cooldowns, world.hero.cooldowns)
	for turn in range(5):
		world.wait_turn()
		restored.wait_turn()
	assert_eq(saved_elemental.tile, elemental.tile)
	assert_eq(restored.combat_random.state, world.combat_random.state)
	var duplicate := snapshot.duplicate(true)
	var record: Dictionary = duplicate.actors[elemental_index].duplicate(true)
	record.state.tile = [elemental.tile.x + 1, elemental.tile.y]
	duplicate.actors.append(record)
	assert_null(SaveCodec.restore(duplicate, false), "Two living elementals are invalid.")
	var expiring := snapshot.duplicate(true)
	expiring.actors[elemental_index].state.expires_turn = 100
	assert_null(SaveCodec.restore(expiring, false))
	var unlearned := snapshot.duplicate(true)
	unlearned.learned.erase("earth_elemental_1")
	assert_null(SaveCodec.restore(unlearned, false))
	world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_null(SummonRules.active(game.world, "earth_elemental"))
	assert_not_null(game.world.hero.find_skill(&"earth_elemental_1"))
	assert_false(game.world.hero.cooldowns.has(&"earth_elemental"))


func test_buffed_wolf_damage_also_improves_spirit_hunt_healing() -> void:
	var world := _world()
	world.hero.learn_skill(SkillDefinition.catalog(&"feral_spirit_1"))
	world.hero.learn_skill(SkillDefinition.catalog(&"spirit_hunt_1"))
	world.hero.melee.damage_min = 20.0
	world.hero.melee.damage_max = 20.0
	world.hero.melee.attack_power = 0
	assert_true(world.cast_skill(&"feral_spirit_1"))
	var wolf := SummonRules.active(world, "wolf")
	var enemy := _enemy(world, wolf.tile + Vector2i.RIGHT)
	enemy.melee.dodge = 0.0
	wolf.melee.hit = 100.0
	wolf.melee.critical = 0.0
	world.auto_attack_target = enemy
	world.hero.health = 10
	ClassToolkitRules.act_wolf(world, wolf)
	assert_eq(enemy.max_health - enemy.health, 15)
	assert_eq(world.hero.health, 17, "Spirit Hunt heals from the stronger actual hit.")
