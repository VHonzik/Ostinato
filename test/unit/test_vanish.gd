extends GutTest


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 24, 24), Vector2i(8, 8), 97, false)
	world.hero.learn_skill(SkillDefinition.catalog(&"vanish_1"))
	world.hero.melee.hit = 100.0
	world.hero.melee.critical = 0.0
	world.hero.melee.dodge = 0.0
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(9, 8)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.engaged = true
	enemy.health = 10000
	enemy.max_health = 10000
	enemy.melee.dodge = 0.0
	enemy.melee.hit = 100.0
	enemy.melee.critical = 0.0
	enemy.melee.damage_min = 1.0
	enemy.melee.damage_max = 1.0
	enemy.melee.attack_power = 0
	world.actors.append(enemy)
	return enemy


func _seed_for_roll(low: float, high: float, roll_index: int = 0) -> int:
	var generator := RandomNumberGenerator.new()
	for candidate in range(1000):
		generator.seed = candidate
		for index in range(roll_index):
			generator.randf()
		var roll := generator.randf()
		if roll > low and roll < high:
			return candidate
	fail_test("No controlled seed found.")
	return 0


func test_vanish_is_free_one_turn_with_evasion_cooldown_and_four_turn_expiry() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.auto_attack_target = enemy
	var health := world.hero.health
	var enemy_tile := enemy.tile
	assert_true(world.cast_skill(&"vanish_1"))
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 0)
	assert_eq(int(world.hero.cooldowns.vanish) - world.turn_count,
		SkillDefinition.catalog(&"evasion_1").cooldown_seconds)
	assert_eq(int(world.hero.buffs[&"vanish_1"].until) - world.turn_count, 4)
	for index in range(3):
		world.wait_turn()
		assert_true(VanishRules.active(world))
		assert_eq(world.hero.health, health)
		assert_eq(enemy.health, enemy.max_health, "Automatic attacks are suppressed.")
		assert_eq(enemy.tile, enemy_tile)
		assert_true(enemy.engaged)
	assert_false(world.cast_skill(&"vanish_1"), "Cooldown attempts preserve Vanish.")
	assert_true(VanishRules.active(world))
	world.wait_turn()
	assert_eq(world.turn_count, 5)
	assert_false(VanishRules.active(world))
	assert_lt(world.hero.health, health, "Enemies resume on the expiry boundary.")
	assert_lt(enemy.health, enemy.max_health, "Ordinary swings also resume.")


func test_enemies_pursue_the_vanish_tile_and_cannot_track_hidden_movement() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(13, 8))
	SummonRules.add_threat(world, enemy, null, 10)
	var idle := _enemy(world, Vector2i(8, 10))
	idle.engaged = false
	idle.aggro_range = 2
	assert_true(world.cast_skill(&"vanish_1"))
	var enemy_tile := enemy.tile
	var origin := world.player_tile
	var threat := enemy.threat.duplicate()
	world.auto_attack_target = enemy
	for direction in [Vector2i.LEFT, Vector2i.DOWN, Vector2i.DOWN]:
		assert_true(world.move_player(direction))
		assert_true(VanishRules.active(world))
		assert_true(enemy.engaged)
		assert_lt(GridWorld.tile_distance(enemy.tile, origin),
			GridWorld.tile_distance(enemy_tile, origin))
		enemy_tile = enemy.tile
		assert_eq(enemy.threat, threat)
		assert_false(idle.engaged)
	assert_eq(world.player_tile, Vector2i(7, 10))
	assert_eq(enemy.tile, Vector2i(9, 8), "Enemy approaches the original tile.")
	world.wait_turn()
	assert_true(idle.engaged, "Reappearing in aggro range is visible again.")
	assert_ne(enemy.tile, enemy_tile, "Pursuit resumes toward the current player tile.")


func test_unreachable_vanish_tile_without_summons_keeps_enemies_engaged() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(13, 8))
	enemy.blocked_turns = 4
	for direction in GridWorld.DIRECTIONS:
		world.blocked_tiles[enemy.tile + direction] = true
	assert_true(world.cast_skill(&"vanish_1"))
	for index in range(3):
		world.wait_turn()
		assert_true(enemy.engaged)
		assert_false(enemy.returning_home)
		assert_eq(enemy.blocked_turns, 4)
		assert_null(SummonRules.enemy_target(world, enemy))
		assert_false(enemy.swing._active)


func _summon(world: GridWorld, tile: Vector2i, kind: String = "wolf") -> GridActor:
	var ally := GridActor.new(tile)
	ally.summon_kind = kind
	ally.summon_skill = (ItemData.ANCESTRAL_TOTEM_HOTBAR_ID if kind == "earth_elemental"
		else &"feral_spirit_1")
	ally.health = 100
	ally.max_health = 100
	ally.melee.dodge = 0.0
	ally.relationship = GridActor.Relationship.FRIENDLY
	world.actors.append(ally)
	return ally


func test_vanish_retargets_zero_threat_summons_without_resetting_fractional_swing_delay() -> void:
	for kind in ["wolf", "earth_elemental"]:
		var world := _world()
		var enemy := _enemy(world)
		var ally := _summon(world, Vector2i(9, 9), kind)
		SummonRules.add_threat(world, enemy, null, 10000)
		enemy.melee.interval = 2.5
		enemy.swing.remaining = 1.5
		enemy.swing._active = true
		var health := world.hero.health
		assert_true(world.cast_skill(&"vanish_1"))
		assert_same(SummonRules.enemy_target(world, enemy), ally)
		assert_eq(ally.health, 100, "Retargeting must not create an immediate swing.")
		assert_almost_eq(enemy.swing.remaining, 0.5, 0.0001)
		world.wait_turn()
		assert_lt(ally.health, 100, "The pending swing lands on its original turn.")
		var after_hit := ally.health
		assert_almost_eq(enemy.swing.remaining, 2.0, 0.0001)
		world.wait_turn()
		assert_eq(ally.health, after_hit)
		world.wait_turn()
		assert_lt(ally.health, after_hit, "Normal fractional cadence continues while hidden.")
		assert_eq(world.hero.health, health)
		assert_true(VanishRules.active(world))
		world.wait_turn()
		assert_false(VanishRules.active(world))
		if kind == "wolf":
			assert_null(SummonRules.enemy_target(world, enemy), "Stored player threat returns.")
		else:
			assert_same(SummonRules.enemy_target(world, enemy), ally, "Elemental taunt still wins.")


func test_hidden_targeting_uses_summon_threat_then_pursues_the_living_summon() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"vanish_1"))
	var enemy := _enemy(world, Vector2i(13, 8))
	var first := _summon(world, Vector2i(15, 8))
	var second := _summon(world, Vector2i(16, 8))
	SummonRules.add_threat(world, enemy, null, 10000)
	SummonRules.add_threat(world, enemy, first, 5)
	SummonRules.add_threat(world, enemy, second, 10)
	assert_same(SummonRules.enemy_target(world, enemy), second)
	NpcRules.act(world, enemy)
	assert_eq(enemy.tile.x, 14, "Pursue the summon, away from the Vanish tile.")
	SummonRules.remove(world, second)
	assert_same(SummonRules.enemy_target(world, enemy), first)


func test_last_summon_dying_stops_extra_swings_and_returns_to_vanish_pursuit() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"vanish_1"))
	var enemy := _enemy(world)
	var ally := _summon(world, Vector2i(9, 9))
	ally.health = 1
	ally.melee.armor = 0
	enemy.melee.damage_min = 10.0
	enemy.melee.damage_max = 10.0
	enemy.melee.interval = 0.25
	enemy.swing.remaining = 0.25
	enemy.swing._active = true
	var health := world.hero.health
	NpcRules.act(world, enemy)
	assert_false(ally.alive)
	assert_eq(world.hero.health, health, "Remaining swings cannot hit the concealed player.")
	for index in range(2):
		NpcRules.act(world, enemy)
		assert_false(enemy.swing._active)
		assert_eq(enemy.swing.remaining, 0.0, "No attacks bank without a target.")
		assert_eq(world.hero.health, health)
		assert_true(enemy.engaged)
	var replacement := _summon(world, Vector2i(9, 9))
	NpcRules.act(world, enemy)
	assert_eq(replacement.health, 90, "Reacquiring a target cannot release banked swings.")


func test_expired_summon_is_unavailable_before_enemy_actions_during_vanish() -> void:
	var world := _world()
	var enemy := _enemy(world)
	var ally := _summon(world, Vector2i(9, 9))
	ally.expires_turn = 1
	var health := world.hero.health
	assert_true(world.cast_skill(&"vanish_1"))
	assert_false(ally.alive)
	assert_eq(world.hero.health, health)
	assert_false(enemy.swing._active)


func test_collision_and_invalid_abilities_preserve_vanish_without_spending_time() -> void:
	var world := _world()
	assert_true(world.cast_skill(&"vanish_1"))
	world.blocked_tiles[Vector2i(7, 8)] = true
	assert_false(world.move_player(Vector2i.LEFT))
	var neutral := _enemy(world)
	neutral.relationship = GridActor.Relationship.NEUTRAL
	neutral.engaged = false
	assert_false(world.move_player(Vector2i.RIGHT), "First neutral bump is only a warning.")
	assert_false(world.cast_skill(&"mortal_strike_1", neutral), "Insufficient rage.")
	assert_false(world.cast_skill(&"unlearned_1"))
	assert_eq(world.turn_count, 1)
	assert_true(VanishRules.active(world))
	assert_true(world.move_player(Vector2i.RIGHT), "Second neutral bump attacks.")
	assert_false(VanishRules.active(world))
	assert_true(neutral.engaged)


func test_bump_opening_bonuses_only_the_first_swing_and_does_not_bank_extra_swings() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.learn_skill(SkillDefinition.catalog(&"slice_and_dice_1"))
	ClassToolkitRules.apply(world, &"slice_and_dice_1", {"haste_percent": 700})
	world.hero.swing.remaining = 0.25
	world.hero.swing._active = true
	assert_true(world.cast_skill(&"vanish_1"))
	world.wait_turn()
	world.combat_random.seed = _seed_for_roll(0.2, 0.4)
	watch_signals(world)
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_false(VanishRules.active(world))
	var events: int = get_signal_emit_count(world, "npc_combat_text")
	assert_eq(events, 1, "Hidden fast weapons cannot bank attacks.")
	assert_eq(get_signal_parameters(world, "npc_combat_text", 0)[2], &"critical")
	world.combat_random.seed = _seed_for_roll(0.2, 0.4)
	world.wait_turn()
	assert_eq(get_signal_parameters(world, "npc_combat_text", 1)[2], &"hit")
	assert_eq(world.melee_critical_bonus, 0)


func test_bump_miss_spends_the_bonus_and_slow_weapon_keeps_it_until_the_swing() -> void:
	var world := _world()
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"vanish_1"))
	world.hero.swing.remaining = 3.0
	world.hero.swing._active = true
	assert_true(world.request_melee(enemy))
	assert_false(VanishRules.active(world))
	assert_eq(world.melee_critical_bonus, 50)
	assert_not_null(world.pending_melee)
	assert_true(world.continue_melee())
	world.hero.melee.hit = -100.0
	world.combat_random.seed = _seed_for_roll(0.2, 0.4)
	watch_signals(world)
	assert_true(world.continue_melee())
	assert_eq(get_signal_parameters(world, "npc_combat_text", 0)[2], &"miss")
	assert_eq(world.melee_critical_bonus, 0)
	assert_null(world.pending_melee)


func test_physical_ability_gets_bonus_but_followup_swings_do_not() -> void:
	var world := _world()
	var enemy := _enemy(world)
	assert_true(world.cast_skill(&"vanish_1"))
	world.hero.rage = 100
	world.combat_random.seed = _seed_for_roll(0.2, 0.4)
	watch_signals(world)
	assert_true(world.cast_skill(&"mortal_strike_1", enemy))
	assert_eq(get_signal_parameters(world, "npc_combat_text", 0)[2], &"critical")
	assert_eq(get_signal_parameters(world, "npc_combat_text", 1)[2], &"hit")
	assert_false(VanishRules.active(world))
	assert_eq(world.ability_critical_bonus, 0)


func test_long_magic_cast_breaks_immediately_and_keeps_bonus_through_completion() -> void:
	var world := _world()
	var enemy := _enemy(world, Vector2i(13, 8))
	world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	assert_true(world.cast_skill(&"vanish_1"))
	world.hero.rage = 100
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	assert_false(VanishRules.active(world))
	assert_eq(world.cast_critical_bonus, 50)
	assert_ne(enemy.tile, Vector2i(13, 8), "Pursuit resumes during wind-up.")
	assert_true(world.continue_cast())
	world.combat_random.seed = _seed_for_roll(0.2, 0.4, 1)
	watch_signals(world)
	assert_true(world.continue_cast())
	assert_eq(get_signal_parameters(world, "npc_combat_text", 0)[2], &"critical")
	assert_eq(world.cast_critical_bonus, 0)


func test_cancelled_cast_and_nondamaging_ability_spend_the_opening() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.learn_skill(SkillDefinition.catalog(&"lava_burst_1"))
	assert_true(world.cast_skill(&"vanish_1"))
	world.hero.rage = 100
	assert_true(world.cast_skill(&"lava_burst_1", enemy))
	world.cancel_cast()
	assert_false(VanishRules.active(world))
	assert_eq(world.cast_critical_bonus, 0)
	world.hero.cooldowns.clear()
	assert_true(world.cast_skill(&"vanish_1"))
	world.hero.learn_skill(SkillDefinition.catalog(&"evasion_1"))
	assert_true(world.cast_skill(&"evasion_1"))
	assert_false(VanishRules.active(world))
	assert_true(world.hero.buffs.has(&"evasion_1"))
	assert_eq(world.ability_critical_bonus, 0)


func test_ongoing_ground_damage_does_not_break_vanish_or_gain_critical_bonus() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.learn_skill(SkillDefinition.catalog(&"consecration_1"))
	world.hero.rage = 100
	assert_true(world.cast_skill(&"consecration_1"))
	var health := enemy.health
	assert_true(world.cast_skill(&"vanish_1"))
	assert_lt(enemy.health, health)
	assert_true(VanishRules.active(world))
	health = enemy.health
	world.wait_turn()
	assert_lt(enemy.health, health)
	assert_true(VanishRules.active(world))
	assert_eq(world.ability_critical_bonus, 0)


func test_save_roundtrip_keeps_vanish_and_cooldown_and_death_clears_them() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.world = _world()
	assert_true(session.world.assign_hotbar(0, &"vanish_1"))
	assert_true(session.world.cast_skill(&"vanish_1"))
	assert_true(session.world.move_player(Vector2i.LEFT))
	assert_true(session.world.can_save())
	var snapshot: Variant = JSON.parse_string(JSON.stringify(SaveCodec.capture(session)))
	var restored := SaveCodec.restore(snapshot, false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_true(VanishRules.active(restored))
	assert_eq(restored.player_tile, session.world.player_tile)
	assert_eq(int(restored.hero.buffs[&"vanish_1"].until) - restored.turn_count, 3)
	assert_eq(restored.hero.cooldowns, session.world.hero.cooldowns)
	assert_eq(VanishRules.origin(restored), Vector2i(8, 8))
	restored.wait_turn()
	assert_true(VanishRules.active(restored))
	session.world.hero.health = 0
	assert_true(session.restart_after_death())
	assert_false(VanishRules.active(session.world))
	assert_true(session.world.hero.cooldowns.is_empty())
	assert_not_null(session.world.hero.find_skill(&"vanish_1"))
	assert_eq(session.world.hotbar[0], &"vanish_1")


func test_save_rejects_invalid_vanish_origins_and_handles_negative_map_coordinates() -> void:
	var session := GameSession.new()
	session.development_build = false
	session.world = GridWorld.new(Rect2i(-12, -12, 24, 24), Vector2i(-3, -4), 97, false)
	session.world.hero.learn_skill(SkillDefinition.catalog(&"vanish_1"))
	assert_true(session.world.cast_skill(&"vanish_1"))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(SaveCodec.capture(session)))
	var restored := SaveCodec.restore(snapshot, false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(VanishRules.origin(restored), Vector2i(-3, -4))
	for field in ["tile_offset_x", "tile_offset_y"]:
		var missing := snapshot.duplicate(true)
		missing.buffs.vanish_1.erase(field)
		assert_null(SaveCodec.restore(missing, false))
		for invalid in [-1, 1.5, 24]:
			var malformed := snapshot.duplicate(true)
			malformed.buffs.vanish_1[field] = invalid
			assert_null(SaveCodec.restore(malformed, false))
