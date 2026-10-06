extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 60, 30), Vector2i(10, 10), 97)
	world.hero.spell_hit = 100
	world.hero.melee.hit = 100
	return world


func _enemy(world: GridWorld, tile: Vector2i, stalker: bool = true) -> GridActor:
	var actor := GridActor.new(tile)
	actor.title = "Stalker" if stalker else "Wolf"
	actor.stalker = stalker
	actor.relationship = GridActor.Relationship.HOSTILE
	actor.aggro_range = 0
	actor.health = 1
	actor.melee.damage_min = 1
	actor.melee.damage_max = 1
	actor.melee.attack_power = 0
	actor.melee.dodge = 0
	actor.melee.parry = 0
	world.actors.append(actor)
	return actor


func _cast(world: GridWorld, identifier: StringName, target: GridActor = null) -> void:
	if world.hero.find_skill(identifier) == null:
		world.hero.learned_skills.append(SkillRank.catalog(identifier))
	assert_true(world.cast_skill(identifier, target), identifier)
	for boundary in range(10):
		if world.pending_skill == null:
			break
		world.continue_cast()


func _assert_complete(world: GridWorld) -> void:
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_null(world.pending_skill)
	assert_null(world.pending_melee)
	assert_false(world.can_save())
	var turn := world.turn_count
	var random_state := world.combat_random.state
	var tile := world.player_tile
	world.wait_turn()
	assert_false(world.move_player(Vector2i.LEFT))
	assert_false(world.cast_skill(&"frost_armor_1"))
	assert_false(world.continue_cast())
	assert_false(world.continue_melee())
	world._finish_turn()
	assert_eq(world.turn_count, turn, "Repeated callbacks cannot advance completed time.")
	assert_eq(world.combat_random.state, random_state)
	assert_eq(world.player_tile, tile)


func test_melee_victory_stops_following_actors_and_consumes_one_boundary() -> void:
	var world := _world()
	var stalker := _enemy(world, Vector2i(11, 10))
	var later := _enemy(world, Vector2i(10, 11), false)
	later.engaged = true
	later.melee.damage_min = 1000
	later.melee.damage_max = 1000
	assert_true(world.request_melee(stalker))
	assert_false(stalker.alive)
	assert_eq(world.hero.health, world.hero.max_health)
	assert_eq(world.turn_count, 1)
	_assert_complete(world)


func test_direct_spell_and_channel_tick_complete_and_cancel_remaining_cast() -> void:
	for identifier: StringName in [&"fireball_1", &"missiles_1", &"drain_soul_1"]:
		var world := _world()
		var stalker := _enemy(world, Vector2i(14, 10))
		stalker.stunned_until = 100
		_cast(world, identifier, stalker)
		assert_false(stalker.alive, identifier)
		_assert_complete(world)


func test_area_damage_stops_at_first_stalker_in_saved_actor_order() -> void:
	var world := _world()
	var first := _enemy(world, Vector2i(9, 10), false)
	var stalker := _enemy(world, Vector2i(11, 10))
	var later := _enemy(world, Vector2i(10, 11), false)
	_cast(world, &"nova_1")
	assert_false(first.alive, "Earlier ordinary target resolves normally.")
	assert_false(stalker.alive)
	assert_true(later.alive, "No later area target is damaged or rooted.")
	assert_eq(later.rooted_until, 0)
	assert_eq(later.health, 1)
	_assert_complete(world)


func test_periodic_victory_stops_later_ticks_regeneration_and_pending_arrival() -> void:
	var world := _world()
	var stalker := _enemy(world, Vector2i(20, 10))
	var later := _enemy(world, Vector2i(21, 10), false)
	world.turn_count = 15
	world.stalker_schedule = true
	world.hero.health = 20
	world.hero.mana = 0
	world.hero.buffs[&"demon_skin_1"] = {"armor": 0, "regen": 3, "next": 16, "until": 100}
	world.periodic_effects.assign([
		{"actor": 0, "skill": "fireball_1", "next": 16, "remaining": 1, "amount": 10},
		{"actor": 1, "skill": "fireball_1", "next": 16, "remaining": 1, "amount": 10},
		{"actor": -1, "skill": "rejuvenation_1", "next": 16, "remaining": 1, "amount": 20},
	])
	world.wait_turn()
	assert_false(stalker.alive)
	assert_true(later.alive)
	assert_eq(world.hero.health, 20)
	assert_eq(world.hero.mana, 0)
	assert_false(world.stalker_arrived)
	assert_eq(world.actors.size(), 2)
	_assert_complete(world)


func test_pet_melee_firebolt_and_searing_totem_can_each_win_in_actor_phase() -> void:
	for identifier: StringName in [&"summon_voidwalker_1", &"summon_imp_1", &"searing_totem_1"]:
		var world := _world()
		SummonRules.summon(world, SkillRank.catalog(identifier))
		var ally := world.actors[0]
		var stalker := _enemy(world, Vector2i(11, 9))
		ally.summon_target = 1
		ally.ability_ready = 1
		ally.melee.hit = 100
		world.wait_turn()
		assert_false(stalker.alive, identifier)
		_assert_complete(world)


func test_thorns_and_lightning_shield_win_before_next_attacker() -> void:
	for identifier: StringName in [&"thorns_1", &"lightning_shield_1"]:
		var world := _world()
		var stalker := _enemy(world, Vector2i(11, 10))
		stalker.engaged = true
		stalker.melee.hit = 100
		# Rear attacks remove player avoidance even after aura refresh rebuilds stats.
		world.hero.facing = Vector2i.LEFT
		world.hero.buffs[identifier] = {"thorns": 3, "charges": 3, "ready": 0, "until": 100}
		var later := _enemy(world, Vector2i(10, 11), false)
		later.engaged = true
		later.melee.hit = 100
		later.melee.damage_min = 1000
		later.melee.damage_max = 1000
		world.wait_turn()
		assert_false(stalker.alive, identifier)
		assert_gt(world.hero.health, 0)
		_assert_complete(world)


func test_first_lethal_player_effect_stops_retaliation_and_later_periodic_victory() -> void:
	var world := _world()
	var stalker := _enemy(world, Vector2i(11, 10))
	stalker.engaged = true
	stalker.melee.hit = 100
	stalker.melee.damage_min = 1000
	stalker.melee.damage_max = 1000
	world.hero.facing = Vector2i.LEFT
	world.hero.buffs[&"thorns_1"] = {"thorns": 3, "until": 100}
	world.periodic_effects.append(
		{"actor": 0, "skill": "fireball_1", "next": 1, "remaining": 1, "amount": 10})
	world.wait_turn()
	assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED)
	assert_true(stalker.alive)
	assert_eq(stalker.health, 1)
	SpellEffects.damage(world, stalker, 100, "Late callback")
	assert_true(stalker.alive)
	var session := GameSession.new()
	session.world = world
	assert_true(session.restart_after_death())
	assert_eq(session.loop_count, 2)
	assert_false(session.restart_after_death(), "The same death cannot reset twice.")
	assert_eq(session.world.attempt_state, GridWorld.AttemptState.ACTIVE)


func test_one_effect_killing_player_and_any_stalker_wins_before_xp_can_revive() -> void:
	var world := _world()
	_enemy(world, Vector2i(15, 10))
	var second := _enemy(world, Vector2i(16, 10))
	world.hero.experience = 399
	# Controlled atomic effect: both health changes precede its one terminal checkpoint.
	world.hero.health = 0
	second.health = 0
	world._check_npc_death(second)
	assert_eq(world.hero.health, 0)
	assert_eq(world.hero.level, 1)
	_assert_complete(world)
	var session := GameSession.new()
	session.world = world
	assert_false(session.restart_after_death())
	assert_eq(session.loop_count, 1)
	world._check_npc_death(second)
	assert_true(world.check_terminal())
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)


func test_latched_player_death_cannot_be_replaced_by_a_later_stalker_death() -> void:
	var world := _world()
	var stalker := _enemy(world, Vector2i(11, 10))
	world.hero.health = 0
	assert_true(world.check_terminal())
	stalker.health = 0
	world._check_npc_death(stalker)
	assert_true(world.check_terminal())
	assert_eq(world.attempt_state, GridWorld.AttemptState.PLAYER_DIED)


func test_ordinary_death_keeps_xp_loot_and_later_turn_stages() -> void:
	var world := _world()
	var wolf := _enemy(world, Vector2i(11, 10), false)
	wolf.loot_table = 299
	assert_true(world.request_melee(wolf))
	assert_false(wolf.alive)
	assert_eq(world.hero.experience, 50)
	assert_true(wolf.loot_assigned)
	assert_eq(world.attempt_state, GridWorld.AttemptState.ACTIVE)
	world.wait_turn()
	assert_eq(world.turn_count, 2)


func test_replaced_world_rejects_stale_casts_and_time_callbacks() -> void:
	var session := GameSession.new()
	session.new_game(97)
	var previous := session.world
	session.new_game(98)
	previous.wait_turn()
	assert_false(previous.cast_skill(&"frost_armor_1"))
	assert_false(previous.move_player(Vector2i.LEFT))
	assert_eq(previous.turn_count, 0)
	assert_eq(session.world.turn_count, 0)
	assert_eq(previous.attempt_state, GridWorld.AttemptState.DISCARDED)


func test_development_kill_stalker_rejects_before_arrival_without_changing_simulation() -> void:
	var session := GameSession.new()
	session.new_game(97)
	var world := session.world
	world.movement_credit = 0.75
	world.hero.casting_credit = 0.4
	var before := SaveCodec.capture(session)
	assert_false(world.cast_skill(&"kill_stalker_1"))
	assert_string_contains(world.messages[-1], "no living stalker")
	var after := SaveCodec.capture(session)
	# The only permitted change is the explicit feedback, not a turn or a new actor.
	before.erase("messages")
	after.erase("messages")
	assert_eq(after, before)
	assert_null(world.pending_skill)
	for boundary in range(15):
		world.wait_turn()
	assert_true(world.stalker_arrived, "Rejected use does not skip or delay the schedule.")
	assert_true(world.cast_skill(&"kill_stalker_1"))
	assert_eq(world.turn_count, 16)
	assert_eq(session.loop_count, 1)
	_assert_complete(world)


func test_development_kill_stalker_is_guaranteed_and_stops_at_first_live_stalker() -> void:
	var world := _world()
	var ordinary := _enemy(world, Vector2i(11, 10), false)
	ordinary.engaged = true
	ordinary.melee.damage_min = 1000
	ordinary.melee.damage_max = 1000
	var first := _enemy(world, Vector2i(50, 20))
	first.max_health = 494
	first.health = 494
	first.melee.level = 20
	first.resistances = {"2": 1000}
	first.buffs[&"shield_a"] = {"absorb": 1000, "until": 100}
	first.buffs[&"shield_b"] = {"absorb": 2000, "until": 100}
	var later := _enemy(world, Vector2i(12, 10))
	world.sight_blockers[Vector2i(11, 10)] = true
	assert_false(world.has_sight(world.player_tile, first.tile))
	world.hero.spell_hit = -100
	world.hero.mana = 0
	world.hero.casting_credit = 0.4
	world.movement_credit = 0.75
	assert_true(world.cast_skill(&"kill_stalker_1"))
	assert_false(first.alive)
	assert_eq(first.health, 0)
	assert_false(first.engaged)
	assert_false(first.loot_assigned, "Uses stalker death processing, without ordinary loot.")
	assert_true(later.alive, "Actor order wins over the nearer stalker.")
	assert_eq(later.health, 1)
	assert_true(ordinary.alive)
	assert_eq(ordinary.health, 1)
	assert_eq(world.hero.health, world.hero.max_health, "No later NPC phase attacks.")
	assert_eq(world.hero.mana, 0)
	assert_eq(world.hero.experience, 0)
	assert_eq(world.hero.casting_credit, 0.4)
	assert_eq(world.movement_credit, 0.75)
	assert_eq(world.turn_count, 1)
	assert_string_contains("\n".join(world.messages), "Kill stalker -> Stalker: 494 damage.")
	assert_false(world.cast_skill(&"kill_stalker_1"), "A repeated activation cannot advance time.")
	_assert_complete(world)
