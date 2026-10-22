extends GutTest


func _world() -> GridWorld:
	return GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)


func test_only_new_ranged_detection_announces_the_engage_flash() -> void:
	var world := _world()
	var spotted: Array[GridActor] = []
	world.hostile_spotted_player.connect(func(actor: GridActor) -> void: spotted.append(actor))
	var distant := GridActor.new(Vector2i(8, 5))
	var adjacent := GridActor.new(Vector2i(6, 5))
	for actor in [distant, adjacent]:
		actor.relationship = GridActor.Relationship.HOSTILE
		world.actors.append(actor)
	NpcRules.acquire_hostiles(world)
	assert_true(distant.engaged)
	assert_true(adjacent.engaged)
	assert_eq(spotted, [distant])
	NpcRules.acquire_hostiles(world)
	assert_eq(spotted, [distant], "Continuing combat never repeats detection.")
	var pulled := GridActor.new(Vector2i(5, 8))
	pulled.relationship = GridActor.Relationship.HOSTILE
	world.actors.append(pulled)
	world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	world.hero.rage = 100
	assert_true(world.cast_skill(&"lava_burst_1", pulled))
	NpcRules.acquire_hostiles(world)
	assert_eq(spotted, [distant], "A player-initiated ranged pull does not announce detection.")


func _enemy(world: GridWorld) -> GridActor:
	var enemy := GridActor.new(Vector2i(6, 5))
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.health = 100
	enemy.max_health = 100
	enemy.melee.hit = 100.0
	enemy.melee.critical = 0.0
	enemy.melee.damage_min = 20.0
	enemy.melee.damage_max = 20.0
	enemy.melee.attack_power = 0
	enemy.melee.interval = 0.25
	enemy.swing.remaining = 0.25
	enemy.swing._active = true
	world.actors.append(enemy)
	return enemy


func test_killed_summon_stops_remaining_swings_without_retargeting_player_or_granting_rage() -> void:
	var world := _world()
	var enemy := _enemy(world)
	var wolf := GridActor.new(Vector2i(6, 6))
	wolf.relationship = GridActor.Relationship.FRIENDLY
	wolf.summon_kind = "wolf"
	wolf.health = 5
	wolf.max_health = 5
	wolf.melee.armor = 0
	wolf.melee.dodge = 0.0
	world.actors.append(wolf)
	SummonRules.add_threat(world, enemy, wolf, 100)
	var health := world.hero.health
	var expected_random := RandomNumberGenerator.new()
	expected_random.state = world.combat_random.state
	expected_random.randf()
	expected_random.randf()
	NpcRules.act(world, enemy)
	assert_false(wolf.alive)
	assert_eq(wolf.health, 0)
	assert_eq(world.hero.health, health)
	assert_eq(world.hero.rage, 0)
	assert_eq(world.combat_random.state, expected_random.state, "Only one swing resolves.")


func test_fast_incoming_swings_grant_player_rage_once_per_world_turn() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.max_health = 200
	world.hero.health = 200
	world.hero.melee.armor = 0
	world.hero.melee.dodge = 0.0
	NpcRules.act(world, enemy)
	assert_eq(world.hero.health, 120)
	assert_eq(world.hero.rage, 3)
	world.turn_count += 1
	NpcRules.act(world, enemy)
	assert_eq(world.hero.health, 40)
	assert_eq(world.hero.rage, 6)


func test_lethal_incoming_hit_stops_extra_swings_and_retaliation() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.learn_skill(SkillDefinition.catalog(&"lightning_shield_1"))
	world.hero.buffs[&"lightning_shield_1"] = {"armor": 0, "until": 100, "charges": 3, "ready": 0}
	world.hero.health = 1
	world.hero.melee.dodge = 0.0
	var expected_random := RandomNumberGenerator.new()
	expected_random.state = world.combat_random.state
	expected_random.randf()
	expected_random.randf()
	NpcRules.act(world, enemy)
	assert_true(world.is_player_dead())
	assert_eq(enemy.health, 100)
	assert_eq(int(world.hero.buffs[&"lightning_shield_1"].charges), 3)
	assert_eq(world.combat_random.state, expected_random.state)
