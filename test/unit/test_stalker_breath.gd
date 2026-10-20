extends GutTest

var _world: GridWorld
var _boss: GridActor


func before_each() -> void:
	_world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(9, 8), 97, false)
	_world.hero.level = 5
	_world.hero.refresh_stats()
	_world.hero.health = _world.hero.max_health
	_world.turn_count = GridWorld.STALKER_DEADLINES[0]
	_world._spawn_stalker(Vector2i(8, 8))
	_boss = _world.actors[-1]
	_boss.engaged = true
	_boss.awards_experience = false
	_boss.melee.damage_min = 0.0
	_boss.melee.damage_max = 0.0
	_boss.melee.attack_power = 0
	_boss.swing.remaining = 1000.0
	_boss.swing._active = true
	# Keep the first weapon outcome away from miss/dodge/critical boundaries.
	var rolls := RandomNumberGenerator.new()
	for seed_value in range(100):
		rolls.seed = seed_value
		var roll := rolls.randf()
		if roll > 0.5 and roll < 0.75:
			_world.combat_random.seed = seed_value
			break


func _announce() -> void:
	for turn in range(5):
		_world.wait_turn()
	assert_eq(_boss.breath_remaining, 2)


func test_two_full_response_turns_then_ten_normal_turns_between_casts() -> void:
	for turn in range(4):
		_world.wait_turn()
		assert_eq(_boss.breath_remaining, 0)
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 2)
	var origin := _boss.tile
	var health := _world.hero.health
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 1)
	assert_eq(_world.hero.health, health)
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 0)
	assert_eq(_world.hero.health, health - 81)
	assert_gt(_world.hero.health, 0, "A full-health level-five hero survives a breath.")
	assert_eq(_boss.tile, origin)
	for turn in range(10):
		_world.wait_turn()
		assert_eq(_boss.breath_remaining, 0)
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 2)


func test_second_response_dodge_keeps_fixed_cone_and_ready_melee_swing() -> void:
	_announce()
	var marked := StalkerBreath.tiles(_world, _boss)
	var health := _world.hero.health
	_world.auto_attack_target = _boss
	_world.hero.swing.remaining = 2.0
	_world.hero.swing._active = true
	_world.hero.melee.hit = 100.0
	_world.hero.melee.critical = 0.0
	_boss.melee.dodge = 0.0
	_world.wait_turn()
	var boss_health := _boss.health
	assert_true(_world.move_player(Vector2i(-1, -1)))
	assert_eq(_world.player_tile, Vector2i(8, 7))
	assert_eq(_world.hero.health, health)
	assert_eq(_boss.facing, Vector2i.RIGHT)
	assert_eq(StalkerBreath.tiles(_world, _boss), marked)
	assert_lt(_boss.health, boss_health, "A melee sidestep does not interrupt a due swing.")


func test_leaving_melee_ticks_timer_and_reentry_swings_without_backlog() -> void:
	_announce()
	_world.auto_attack_target = _boss
	_world.hero.swing.remaining = 1.0
	_world.hero.swing._active = true
	_world.hero.melee.hit = 100.0
	_world.hero.melee.critical = 0.0
	_boss.melee.dodge = 0.0
	var health := _boss.health
	assert_true(_world.move_player(Vector2i(1, -1)))
	assert_eq(_world.hero.swing.remaining, 0.0)
	assert_eq(_boss.health, health)
	assert_true(_world.move_player(Vector2i(-1, -1)))
	assert_eq(_world.hero.swing.remaining, 0.0)
	assert_eq(_boss.health, health)
	assert_true(_world.move_player(Vector2i(-1, 1)))
	assert_lt(_boss.health, health)
	assert_gt(_world.hero.swing.remaining, 0.0)


func test_cone_edges_range_and_walls_for_all_eight_facings() -> void:
	for direction in GridWorld.DIRECTIONS:
		_boss.breath_direction = direction
		assert_true(StalkerBreath.threatens(_world, _boss, _boss.tile + direction * 3))
		assert_false(StalkerBreath.threatens(_world, _boss, _boss.tile + direction * 4))
		assert_false(StalkerBreath.threatens(_world, _boss, _boss.tile - direction))
		assert_false(StalkerBreath.threatens(_world, _boss, _boss.tile))
	_boss.breath_direction = Vector2i.RIGHT
	assert_true(StalkerBreath.threatens(_world, _boss, Vector2i(11, 5)))
	assert_false(StalkerBreath.threatens(_world, _boss, Vector2i(9, 6)))
	_world.sight_blockers[Vector2i(10, 8)] = true
	assert_false(StalkerBreath.threatens(_world, _boss, Vector2i(11, 8)))


func test_boss_weapon_pauses_and_resets_for_a_full_interval_after_breath() -> void:
	_boss.breath_normal_turns = 4
	_boss.melee.damage_min = 10.0
	_boss.melee.damage_max = 10.0
	_boss.melee.hit = 100.0
	_boss.melee.critical = 0.0
	_boss.swing.remaining = 0.0
	_boss.swing._active = true
	var health := _world.hero.health
	_world.wait_turn()
	assert_eq(_boss.swing.remaining, _boss.melee.interval)
	assert_eq(_world.hero.health, health)
	_world.move_player(Vector2i(-1, -1))
	assert_eq(_boss.swing.remaining, _boss.melee.interval)
	_world.wait_turn()
	assert_eq(_boss.swing.remaining, _boss.melee.interval)
	assert_eq(_world.hero.health, health)
	_world.hero.melee.dodge = 0.0
	_world.wait_turn()
	assert_eq(_world.hero.health, health, "No ready swing immediately after release.")
	_world.wait_turn()
	assert_eq(_world.hero.health, health, "The full 2.5-turn weapon interval must elapse.")
	_world.wait_turn()
	assert_lt(_world.hero.health, health)
	assert_almost_eq(_boss.swing.remaining, 2.0, 0.001)


func test_stun_delays_new_cast_but_does_not_cancel_committed_breath() -> void:
	_boss.breath_normal_turns = 4
	_boss.stunned_until = _world.turn_count + 3
	_world.wait_turn()
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 0)
	assert_eq(_boss.breath_normal_turns, 4)
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 2)
	_boss.stunned_until = 100
	_world.wait_turn()
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 0)
	assert_eq(_world.hero.health, _world.hero.max_health - 81)


func test_no_windup_when_player_cannot_escape_in_two_moves() -> void:
	for direction in GridWorld.DIRECTIONS:
		var tile := _world.player_tile + direction
		if tile != _boss.tile:
			_world.blocked_tiles[tile] = true
	_boss.breath_normal_turns = 4
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 0)
	_world.blocked_tiles.erase(Vector2i(8, 7))
	_world.wait_turn()
	assert_eq(_boss.breath_remaining, 2)


func test_fire_bypasses_armor_and_shield_block_but_respects_divine_shield() -> void:
	_announce()
	_world.hero.equipment.weapons = ItemData.instance(5580)
	_world.hero.learn_skill(SkillDefinition.catalog(&"shield_block_1"))
	_world.hero.find_skill(&"shield_block_1").coefficient = 1.0
	_world.hero.melee.armor = 100000
	_world.hero.melee.dodge = 100.0
	_world.wait_turn()
	_world.wait_turn()
	assert_eq(_world.hero.health, _world.hero.max_health - 81)
	_world.hero.health = _world.hero.max_health
	_boss.breath_remaining = 1
	_world.hero.buffs[&"divine_shield_1"] = {"until": 100}
	_world.wait_turn()
	assert_eq(_world.hero.health, _world.hero.max_health)


func test_friendly_summons_in_cone_take_fire_damage() -> void:
	_announce()
	var wolf := GridActor.new(Vector2i(10, 8))
	wolf.title = "Wolf"
	wolf.summon_kind = "wolf"
	wolf.summon_skill = &"feral_spirit_1"
	wolf.max_health = 60
	wolf.health = 60
	wolf.melee.level = 5
	wolf.expires_turn = 100
	_world.actors.append(wolf)
	_world.move_player(Vector2i(-1, -1))
	# Keep the pet in the fixed cone without changing combat rules for the boss.
	wolf.stunned_until = 100
	wolf.tile = Vector2i(10, 8)
	_world.wait_turn()
	assert_false(wolf.alive)
	assert_eq(_world.hero.health, _world.hero.max_health)


func test_due_player_swing_can_kill_boss_before_breath_resolves() -> void:
	_announce()
	_world.wait_turn()
	_boss.health = 1
	_world.auto_attack_target = _boss
	_world.hero.swing.remaining = 0.0
	_world.hero.melee.hit = 100.0
	_world.hero.melee.critical = 0.0
	_boss.melee.dodge = 0.0
	var impacts: Array = []
	_world.stalker_breath_released.connect(func(tiles: Array[Vector2i]) -> void: impacts.append(tiles))
	_world.wait_turn()
	assert_false(_boss.alive)
	assert_eq(_boss.breath_remaining, 0)
	assert_eq(_world.hero.health, _world.hero.max_health)
	assert_true(impacts.is_empty())


func test_save_load_preserves_locked_cone_remaining_turn_and_cadence() -> void:
	_announce()
	_world.wait_turn()
	var session := GameSession.new()
	session.seed_value = 97
	session.world = _world
	var saved := SaveCodec.capture(session)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(saved)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.actors[0].breath_remaining, 1)
	assert_eq(restored.actors[0].swing.remaining, _boss.melee.interval)
	assert_false(restored.actors[0].swing._active)
	assert_eq(StalkerBreath.tiles(restored, restored.actors[0]), StalkerBreath.tiles(_world, _boss))
	for turn in range(12):
		_world.wait_turn()
		restored.wait_turn()
		assert_eq(restored.hero.health, _world.hero.health)
		assert_eq(restored.actors[0].breath_remaining, _boss.breath_remaining)
		assert_eq(restored.actors[0].breath_normal_turns, _boss.breath_normal_turns)
	for field: String in ["breath_remaining", "breath_direction", "breath_normal_turns", "breath_started"]:
		var damaged := saved.duplicate(true)
		damaged.actors[0].state[field] = {"breath_remaining": 3, "breath_direction": [2, 0],
			"breath_normal_turns": 1, "breath_started": false}[field]
		assert_null(SaveCodec.restore(damaged, false), field)


func test_loop_reset_discards_pending_breath() -> void:
	_announce()
	var session := GameSession.new()
	session.seed_value = 97
	session.world = _world
	_world.hero.health = 0
	assert_true(session.restart_after_death())
	for actor in session.world.actors:
		assert_eq(actor.breath_remaining, 0)
		assert_eq(actor.breath_normal_turns, 0)


func test_view_warning_waits_for_turns_and_impact_clears_on_world_replacement() -> void:
	var view := GridView.new()
	add_child_autofree(view)
	view.world = _world
	view.set_process(false)
	_announce()
	view._process(20.0)
	assert_eq(_boss.breath_remaining, 2, "Idle animation time cannot consume dodge turns.")
	_world.wait_turn()
	_world.wait_turn()
	assert_false(view._breath_impact.is_empty())
	view._process(1.5)
	assert_true(view._breath_impact.is_empty())
	view._show_breath([Vector2i(9, 8)])
	view.world = GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(1, 1), 98, false)
	assert_true(view._breath_impact.is_empty())
	_world.stalker_breath_released.emit([Vector2i(9, 8)])
	assert_true(view._breath_impact.is_empty())
