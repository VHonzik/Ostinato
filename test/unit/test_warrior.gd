extends GutTest


func _world() -> GridWorld:
	return GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, false)


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(6, 5)) -> GridActor:
	var actor := GridActor.new(tile)
	actor.relationship = GridActor.Relationship.NEUTRAL
	actor.max_health = 10000
	actor.health = actor.max_health
	actor.awards_experience = false
	actor.melee.damage_min = 1.0
	actor.melee.damage_max = 1.0
	actor.melee.hit = 100.0
	actor.melee.critical = 0.0
	actor.melee.dodge = 0.0
	actor.melee.armor = 0
	world.hero.melee.dodge = 0.0
	world.hero.melee.critical = 0.0
	world.hero.melee.hit = 100.0
	world.actors.append(actor)
	return actor


func test_new_game_starts_warrior_with_rage_sprite_and_two_abilities() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	assert_eq(game.world.hero.selected_class, &"Warrior")
	assert_eq([game.world.hero.rage, game.world.hero.max_mana], [0, 0])
	assert_eq(game.world.hotbar.slice(0, 2), [&"slam_1", &"battle_shout_1"])
	assert_eq(game.world.hero.learned_skills.size(), 2)
	assert_null(game.world.hero.find_skill(&"fireball_1"))
	assert_eq(GridView.class_sprite(game.world.hero.selected_class), Vector2i(2, 0))
	assert_eq(game.world.actor_at(Vector2i(31, 34)).service, &"Warrior")
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_false(game.select_class(&"Mage"))
	assert_false(game.select_class(&"Shaman"))


func test_two_turn_auto_attack_generates_fourteen_rage_and_hits_award_three() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.melee.interval = 2.0
	assert_true(world.request_melee(enemy))
	assert_eq(world.hero.rage, 17)
	world.wait_turn()
	assert_eq(world.hero.rage, 17)
	world.hero.melee.interval = 2.0
	assert_true(world.request_melee(enemy))
	assert_eq(world.hero.rage, 34)


func test_fractional_attack_speed_and_haste_retain_generation_credit() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.engaged = false
	world.hero.melee.interval = 2.9
	world.hero.haste = 2.0
	world._player_swing(enemy)
	assert_eq(world.hero.rage, 10)
	assert_almost_eq(world.hero.rage_credit, 0.15, 0.00001)
	world._player_swing(enemy)
	assert_eq(world.hero.rage, 20)
	assert_almost_eq(world.hero.rage_credit, 0.3, 0.00001)


func test_missed_auto_attack_still_generates_normalized_rage() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.melee.hit = -100.0
	world.hero.melee.interval = 2.0
	world._player_swing(enemy)
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(world.hero.rage, 14)


func test_multiple_enemies_and_fast_hits_generate_only_three_rage_per_turn() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(4, 5))
	for enemy in [first, second]:
		enemy.engaged = true
		enemy.relationship = GridActor.Relationship.HOSTILE
		enemy.melee.interval = 0.25
	world.wait_turn()
	assert_eq(world.hero.rage, 3)
	world.wait_turn()
	assert_eq(world.hero.rage, 6)


func test_misses_do_not_generate_incoming_rage_and_cap_discards_excess_credit() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.engaged = true
	enemy.relationship = GridActor.Relationship.HOSTILE
	enemy.melee.hit = -100.0
	world.wait_turn()
	assert_eq(world.hero.rage, 0)
	world.hero.gain_rage(101.7)
	assert_eq(world.hero.rage, 100)
	assert_eq(world.hero.rage_credit, 0.0)


func test_decay_is_per_turn_only_outside_combat_and_never_negative() -> void:
	var world := _world()
	world.hero.rage = 5
	world.wait_turn()
	assert_eq(world.hero.rage, 3)
	world.wait_turn()
	assert_eq(world.hero.rage, 1)
	var enemy := _enemy(world)
	enemy.engaged = true
	enemy.melee.hit = -100.0
	world.wait_turn()
	assert_eq(world.hero.rage, 1)
	enemy.alive = false
	world.wait_turn()
	world.wait_turn()
	assert_eq(world.hero.rage, 0)


func test_slam_uses_two_turns_and_freezes_weapon_timer_until_completion() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.stunned_until = 999
	world.hero.rage = 50
	world.hero.swing.remaining = 1.5
	world.hero.swing._active = true
	world.hero.casting_credit = 0.9
	world.hero.haste = 2.0
	assert_true(world.cast_skill(&"slam_1", enemy))
	assert_eq(world.turn_count, 1)
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(world.hero.swing.remaining, 1.5)
	assert_eq(world.hero.warrior_progress, 0)
	assert_true(world.continue_cast())
	assert_eq(world.turn_count, 2)
	assert_lt(enemy.health, enemy.max_health)
	assert_eq(world.hero.swing.remaining, 1.5)
	assert_eq(world.hero.rage, 20, "Slam spends 30 and generates no auto-attack rage.")
	assert_eq(world.hero.warrior_progress, 1)
	assert_almost_eq(world.hero.casting_credit, 0.9, 0.00001)
	assert_true(world.request_melee(enemy))
	assert_not_null(world.pending_melee, "Bump waits for the suspended auto-attack timer.")
	assert_true(world.continue_melee())
	assert_null(world.pending_melee)


func test_slam_checks_cost_target_and_completion_without_awarding_failed_use() -> void:
	var world := _world()
	var enemy := _enemy(world)
	assert_false(world.cast_skill(&"slam_1", enemy))
	assert_eq(world.turn_count, 0)
	assert_string_contains(world.messages[-1], "Not enough rage for Slam")
	enemy.stunned_until = 999
	world.hero.rage = 30
	enemy.tile = Vector2i(8, 5)
	assert_false(world.cast_skill(&"slam_1", enemy))
	enemy.tile = Vector2i(6, 5)
	assert_true(world.cast_skill(&"slam_1", enemy))
	world.cancel_cast()
	assert_eq(world.hero.warrior_progress, 0)
	assert_eq(world.hero.rage, 30)
	assert_true(world.cast_skill(&"slam_1", enemy))
	enemy.alive = false
	world.continue_cast()
	assert_eq(world.hero.warrior_progress, 0)
	assert_eq(world.hero.rage, 28, "Failed completion spends no rage; the out-of-combat turn decays two.")


func test_slam_weapon_damage_and_shout_bonus_precede_armor_and_block() -> void:
	var attacker := MeleeProfile.new()
	var defender := MeleeProfile.new()
	attacker.damage_min = 20.0
	attacker.damage_max = 20.0
	attacker.attack_power = 0
	assert_eq(MeleeRules.damage(attacker, defender, &"hit", 0.0, 0.0, 1.5, 5), 35)
	attacker.damage_multiplier = 1.1
	assert_eq(MeleeRules.damage(attacker, defender, &"hit", 0.0, 0.0), 22)
	assert_eq(MeleeRules.damage(attacker, defender, &"hit", 0.0, 0.0, 1.5, 5), 38)
	defender.armor = 485
	assert_eq(MeleeRules.damage(attacker, defender, &"hit", 0.0, 0.0, 1.5, 5), 19)
	defender.block_value = 4
	assert_eq(MeleeRules.damage(attacker, defender, &"block", 0.0, 0.0, 1.5, 5), 15)


func test_battle_shout_is_immediate_one_turn_free_and_has_ten_turn_cooldown() -> void:
	var world := _world()
	var observed_rage: Array[int] = []
	var hero := world.hero
	world.message_added.connect(func(message: String) -> void:
		if message.begins_with("Battle Shout:"):
			observed_rage.append(hero.rage))
	assert_true(world.cast_skill(&"battle_shout_1"))
	assert_eq(observed_rage, [10])
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 8, "The one out-of-combat turn decays two rage.")
	assert_eq(world.hero.warrior_progress, 1)
	assert_almost_eq(world.hero.melee.damage_multiplier, 1.1, 0.00001)
	assert_false(world.cast_skill(&"battle_shout_1"))
	assert_eq(world.turn_count, 1)
	for index in range(9):
		world.wait_turn()
	assert_false(world.cast_skill(&"battle_shout_1"))
	world.wait_turn()
	assert_true(world.cast_skill(&"battle_shout_1"))
	assert_eq(world.hero.warrior_progress, 2)
	assert_almost_eq(world.hero.melee.damage_multiplier, 1.1, 0.00001, "Refresh does not stack.")


func test_shout_lasts_thirty_turns_and_expires_without_damage_bonus() -> void:
	var world := _world()
	world.cast_skill(&"battle_shout_1")
	for index in range(29):
		world.wait_turn()
	assert_true(world.hero.buffs.has(&"battle_shout_1"))
	world.wait_turn()
	assert_false(world.hero.buffs.has(&"battle_shout_1"))
	assert_eq(world.hero.melee.damage_multiplier, 1.0)


func test_twentieth_use_notifies_once_and_training_unlocks_fractional_decay() -> void:
	var world := _world()
	assert_false(world.train(&"Warrior", &"anger_management_1"))
	world.hero.warrior_progress = 19
	world.cast_skill(&"battle_shout_1")
	assert_eq(world.hero.warrior_progress, 20)
	assert_eq(world.messages.count("20 warrior progression points! Visit Llane Beshere, the warrior trainer, to learn Anger Management."), 1)
	assert_null(world.hero.find_skill(&"anger_management_1"))
	assert_true(world.train(&"Warrior", &"anger_management_1"))
	assert_false(world.assign_hotbar(2, &"anger_management_1"))
	assert_false(world.cast_skill(&"anger_management_1"))
	world.hero.rage = 4
	world.wait_turn()
	assert_eq(world.hero.rage, 4)
	world.wait_turn()
	assert_eq(world.hero.rage, 3)
	assert_eq(world.hero.warrior_progress, 20)


func test_save_roundtrip_preserves_rage_credits_progression_shout_and_future_decay() -> void:
	var game := GameSession.new()
	game.world = _world()
	game.world.hero.warrior_progress = 20
	assert_true(game.world.train(&"Warrior", &"anger_management_1"))
	game.world.cast_skill(&"battle_shout_1")
	game.world.hero.gain_rage(0.3)
	var saved := SaveCodec.capture(game)
	var restored := SaveCodec.restore(saved, false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hero.rage, game.world.hero.rage)
	assert_eq(restored.hero.rage_decay_credit, 0.5)
	assert_almost_eq(restored.hero.rage_credit, 0.3, 0.00001)
	assert_eq(restored.hero.warrior_progress, 21)
	assert_almost_eq(restored.hero.melee.damage_multiplier, 1.1, 0.00001)
	restored.wait_turn()
	game.world.wait_turn()
	assert_eq(restored.hero.rage, game.world.hero.rage)
	assert_eq(restored.hero.rage_decay_credit, game.world.hero.rage_decay_credit)
	for field: String in ["rage", "rage_credit", "rage_decay_credit", "warrior_progress"]:
		var invalid := saved.duplicate(true)
		invalid.hero[field] = -1
		assert_null(SaveCodec.restore(invalid, false), field)
	var over_cap := saved.duplicate(true)
	over_cap.hero.rage = 101
	assert_null(SaveCodec.restore(over_cap, false))


func test_death_retains_points_passive_and_hotbar_but_resets_rage_and_buffs() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	game.world.hero.warrior_progress = 20
	assert_true(game.world.train(&"Warrior", &"anger_management_1"))
	game.world.cast_skill(&"battle_shout_1")
	game.world.hero.rage_credit = 0.7
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.warrior_progress, 21)
	assert_not_null(game.world.hero.find_skill(&"anger_management_1"))
	assert_eq([game.world.hero.rage, game.world.hero.rage_credit, game.world.hero.rage_decay_credit], [0, 0.0, 0.0])
	assert_eq(game.world.hero.buffs, {})
	assert_eq(game.world.hotbar.slice(0, 2), [&"slam_1", &"battle_shout_1"])
	game.new_game(98)
	assert_eq(game.world.hero.warrior_progress, 0)
	assert_null(game.world.hero.find_skill(&"anger_management_1"))


func test_default_warrior_hotbar_and_spell_book_use_rage_in_the_live_scene() -> void:
	var scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var main := scene.instantiate() as Control
	add_child_autofree(main)
	var gameplay := main.get_node("GameContainer/GameViewport/Gameplay") as Gameplay
	gameplay.start_new_game()
	gameplay._hotbar_slot_pressed(1)
	assert_eq(gameplay.world.turn_count, 1)
	assert_eq(gameplay.world.hero.warrior_progress, 1)
	assert_true(gameplay.world.hero.buffs.has(&"battle_shout_1"))
	assert_string_contains(gameplay._hero_status.text, "Rage 8/100")
	assert_string_contains(gameplay.hotbar_panel.slots[0].tooltip_text, "30 rage")
	gameplay.hero_panel.open(gameplay.world.hero, true)
	assert_eq(gameplay.hero_panel._tabs.get_tab_title(1), "Warrior")
	assert_string_contains(gameplay.hero_panel._skill_buttons[0].text, "Slam")
	assert_string_contains(gameplay.hero_panel._skill_buttons[0].tooltip_text, "30 rage")


func test_second_stationary_neutral_bump_attacks_without_confirmation_or_movement() -> void:
	var world := _world()
	var enemy := _enemy(world)
	var random_before := world.combat_random.state
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_eq(world.turn_count, 0)
	assert_false(enemy.engaged)
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(world.combat_random.state, random_before)
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_eq(world.turn_count, 1)
	assert_eq(world.player_tile, Vector2i(5, 5))
	assert_eq(enemy.relationship, GridActor.Relationship.HOSTILE)
	assert_same(world.last_attacked_enemy, enemy)


func test_neutral_movement_even_away_and_back_requires_another_first_bump() -> void:
	var world := _world()
	var enemy := _enemy(world)
	assert_false(world.move_player(Vector2i.RIGHT))
	world._move_actor(enemy, Vector2i(6, 6))
	world._move_actor(enemy, Vector2i(6, 5))
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_eq(world.turn_count, 0)
	assert_false(enemy.engaged)
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_true(enemy.engaged)


func test_bumping_a_different_neutral_or_moving_resets_the_first_bump() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(4, 5))
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_false(world.move_player(Vector2i.LEFT))
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_eq(world.turn_count, 0)
	assert_false(first.engaged)
	assert_false(second.engaged)
	assert_true(world.move_player(Vector2i.UP))
	assert_false(world.move_player(Vector2i(1, 1)))
	assert_false(first.engaged)
	assert_true(world.move_player(Vector2i(1, 1)))
	assert_true(first.engaged)


func test_second_neutral_bump_still_waits_for_the_existing_auto_attack_timer() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.swing.remaining = 2.5
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_true(world.move_player(Vector2i.RIGHT))
	assert_eq(enemy.health, enemy.max_health)
	assert_same(world.pending_melee, enemy)
	assert_null(world.last_attacked_enemy, "A committed bump has not attacked until the swing occurs.")
	world.continue_melee()
	assert_eq(enemy.health, enemy.max_health)
	world.continue_melee()
	assert_lt(enemy.health, enemy.max_health)
	assert_same(world.last_attacked_enemy, enemy)


func test_slam_automatically_uses_the_last_attacked_enemy_and_tracks_target_changes() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(4, 5))
	for enemy in [first, second]:
		enemy.stunned_until = 999
	assert_true(world.request_melee(first))
	world.hero.rage = 80
	assert_true(world.cast_skill(&"slam_1"))
	assert_same(world.pending_target, first)
	world.continue_cast()
	assert_same(world.last_attacked_enemy, first)
	assert_true(world.request_melee(second))
	while world.pending_melee != null:
		world.continue_melee()
	assert_same(world.last_attacked_enemy, second)
	assert_true(world.cast_skill(&"slam_1"))
	assert_same(world.pending_target, second)


func test_automatic_slam_rejects_dead_or_distant_last_enemy_without_retargeting() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(4, 5))
	first.stunned_until = 999
	second.stunned_until = 999
	second.engaged = true
	world.request_melee(first)
	world.hero.rage = 80
	world._move_actor(first, Vector2i(8, 5))
	var turn_before := world.turn_count
	assert_false(world.cast_skill(&"slam_1"))
	first.alive = false
	assert_false(world.cast_skill(&"slam_1"))
	assert_eq(world.turn_count, turn_before)
	assert_eq(world.hero.rage, 80)
	assert_eq(second.health, second.max_health)
	assert_eq(world.hero.warrior_progress, 0)


func test_slam_initial_targeting_and_completion_enforce_melee_range() -> void:
	var world := _world()
	var enemy := _enemy(world)
	enemy.stunned_until = 999
	enemy.engaged = true
	world.hero.rage = 40
	assert_null(world.last_attacked_enemy)
	assert_false(world.cast_skill(&"slam_1"))
	assert_true(world.cast_skill(&"slam_1", enemy))
	world._move_actor(enemy, Vector2i(8, 5))
	world.continue_cast()
	assert_eq(enemy.health, enemy.max_health)
	assert_eq(world.hero.rage, 40)
	assert_eq(world.hero.warrior_progress, 0)
	assert_null(world.last_attacked_enemy)


func _live_gameplay(world: GridWorld) -> Gameplay:
	var scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var main := scene.instantiate() as Control
	add_child_autofree(main)
	var gameplay := main.get_node("GameContainer/GameViewport/Gameplay") as Gameplay
	gameplay.session.restore(world, 97, 1)
	return gameplay


func test_slam_hotbar_skips_target_picker_after_an_auto_attack() -> void:
	var world := _world()
	world.hotbar[0] = &"slam_1"
	var enemy := _enemy(world)
	enemy.stunned_until = 999
	world.request_melee(enemy)
	world.hero.rage = 40
	var gameplay := _live_gameplay(world)
	gameplay._hotbar_slot_pressed(0)
	assert_false(gameplay.combat_panel.visible)
	assert_same(world.pending_target, enemy)
	assert_eq(world.turn_count, 2)
	assert_eq(world.cast_elapsed, 1)


func test_slam_hotbar_keeps_melee_picker_until_player_has_attacked() -> void:
	for engaged in [false, true]:
		var world := _world()
		world.hotbar[0] = &"slam_1"
		var enemy := _enemy(world)
		enemy.engaged = engaged
		enemy.stunned_until = 999
		var distant := _enemy(world, Vector2i(8, 5))
		world.hero.rage = 40
		var gameplay := _live_gameplay(world)
		gameplay._hotbar_slot_pressed(0)
		assert_true(gameplay.combat_panel.visible)
		assert_eq(gameplay.combat_panel.mode, CombatPanel.Mode.SPELL)
		assert_same(gameplay.combat_panel.selected, enemy)
		assert_false(gameplay.combat_panel._candidates.has(distant))
		assert_eq(world.turn_count, 0)
		gameplay.combat_panel.confirm()
		assert_false(gameplay.combat_panel.visible)
		assert_same(world.pending_target, enemy)
		assert_eq(world.turn_count, 1)


func test_neutral_bump_and_last_attack_history_reset_on_save_load_and_death() -> void:
	var game := GameSession.new()
	game.world = _world()
	var enemy := _enemy(game.world)
	assert_false(game.world.move_player(Vector2i.RIGHT))
	var restored := SaveCodec.restore(SaveCodec.capture(game), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_false(restored.move_player(Vector2i.RIGHT), "Loading requires a fresh neutral bump.")
	game.world.request_melee(enemy)
	assert_same(game.world.last_attacked_enemy, enemy)
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_null(game.world.last_attacked_enemy)


func _charge_world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 20, 20), Vector2i(2, 10), 97, false)
	world.hero.warrior_progress = 50
	world.train(&"Warrior", &"charge_1")
	return world


func test_charge_unlock_and_passive_training_keep_all_progression_points() -> void:
	var world := _world()
	world.hero.warrior_progress = 49
	assert_false(world.train(&"Warrior", &"charge_1"))
	assert_null(world.hero.find_skill(&"charge_1"))
	world.add_class_progress(&"Warrior", 1)
	assert_string_contains(world.messages[-1], "50 warrior progression points!")
	assert_string_contains(world.messages[-1], "learn Charge")
	assert_true(world.train(&"Warrior", &"anger_management_1"))
	assert_eq(world.hero.warrior_progress, 50)
	assert_true(world.train(&"Warrior", &"charge_1"))
	assert_eq(world.hero.warrior_progress, 50)
	assert_false(world.train(&"Warrior", &"charge_1"))
	assert_eq(world.hero.warrior_progress, 50)
	assert_true(world.assign_hotbar(2, &"charge_1"))


func test_development_points_award_current_class_and_cross_both_unlocks() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 12, 12), Vector2i(5, 5), 97, true)
	assert_true(world.cast_skill(&"class_points_1"))
	assert_eq(world.hero.warrior_progress, 30)
	assert_string_contains("\n".join(world.messages), "learn Anger Management")
	assert_null(world.hero.find_skill(&"anger_management_1"))
	assert_true(world.cast_skill(&"class_points_1"))
	assert_eq(world.hero.warrior_progress, 60)
	assert_string_contains("\n".join(world.messages), "learn Charge")
	assert_null(world.hero.find_skill(&"charge_1"))
	world.hero.selected_class = &"Mage"
	assert_true(world.cast_skill(&"class_points_1"))
	assert_eq(world.hero.progression_points(&"Mage"), 30)
	assert_eq(world.hero.warrior_progress, 60)
	assert_eq(world.turn_count, 3)
	assert_false(_world().cast_skill(&"class_points_1"), "Development rank is unavailable in release.")


func test_class_points_and_charge_survive_save_and_death_and_reject_invalid_saves() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.world = _charge_world()
	game.world.add_class_progress(&"Mage", 30)
	game.world.assign_hotbar(2, &"charge_1")
	var saved := SaveCodec.capture(game)
	var restored := SaveCodec.restore(JSON.parse_string(JSON.stringify(saved)), false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_eq(restored.hero.progression_points(&"Mage"), 30)
	assert_eq(restored.hero.warrior_progress, 50)
	assert_not_null(restored.hero.find_skill(&"charge_1"))
	assert_eq(restored.hotbar[2], &"charge_1")
	for invalid_value: Variant in [-1, 0.5, "30", [], {}]:
		var invalid := saved.duplicate(true)
		invalid.class_progress.Mage = invalid_value
		assert_null(SaveCodec.restore(invalid, false))
	var insufficient := saved.duplicate(true)
	insufficient.hero.warrior_progress = 49
	insufficient.class_progress.Warrior = 49
	assert_null(SaveCodec.restore(insufficient, false), "Charge requires its progression checkpoint.")
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_eq(game.world.hero.progression_points(&"Mage"), 30)
	assert_eq(game.world.hero.warrior_progress, 50)
	assert_not_null(game.world.hero.find_skill(&"charge_1"))
	assert_eq(game.world.hotbar[2], &"charge_1")


func test_existing_warrior_save_without_class_map_still_preserves_points() -> void:
	var game := GameSession.new()
	game.world = _world()
	game.world.hero.warrior_progress = 20
	game.world.train(&"Warrior", &"anger_management_1")
	var saved := SaveCodec.capture(game)
	saved.erase("class_progress")
	var restored := SaveCodec.restore(saved, false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.hero.warrior_progress, 20)
		assert_not_null(restored.hero.find_skill(&"anger_management_1"))


func test_charge_winds_up_then_travels_four_tiles_per_turn_and_awards_on_arrival() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	world.movement_speed = 7.0
	world.movement_credit = 0.5
	world.hero.haste = 3.0
	world.hero.casting_credit = 0.8
	var route := world.charge_route(enemy)
	assert_eq(route.size(), 7, "Route ends at a nearest empty melee tile.")
	assert_true(world.cast_skill(&"charge_1", enemy))
	assert_eq(world.turn_count, 1)
	assert_eq(world.player_tile, Vector2i(2, 10))
	assert_true(world.is_charging())
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.warrior_progress, 50)
	assert_true(world.continue_cast())
	assert_eq(world.player_tile, route[4])
	assert_true(world.is_charging())
	assert_eq(world.hero.rage, 0)
	assert_true(world.continue_cast())
	assert_eq(world.player_tile, route[-1])
	assert_eq(GridWorld.tile_distance(world.player_tile, enemy.tile), 1)
	assert_false(world.is_charging())
	assert_eq(world.turn_count, 3)
	assert_eq(world.hero.rage, 10)
	assert_eq(world.hero.warrior_progress, 51)
	assert_eq(world.movement_credit, 0.5)
	assert_almost_eq(world.hero.casting_credit, 0.8, 0.00001)
	assert_eq(enemy.health, enemy.max_health, "Charge does not perform an auto-attack.")


func test_charge_checks_range_and_reachable_empty_melee_tile_before_starting() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(12, 10))
	assert_false(world.cast_skill(&"charge_1", enemy), "Ten tiles is beyond range.")
	enemy.tile = Vector2i(9, 10)
	enemy.relationship = GridActor.Relationship.FRIENDLY
	assert_false(world.cast_skill(&"charge_1", enemy))
	enemy.relationship = GridActor.Relationship.NEUTRAL
	for direction in GridWorld.DIRECTIONS:
		var blocker := _enemy(world, enemy.tile + direction)
		blocker.relationship = GridActor.Relationship.FRIENDLY
	assert_false(world.cast_skill(&"charge_1", enemy))
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.warrior_progress, 50)
	assert_false(enemy.engaged)
	assert_null(world.pending_skill)


func test_charge_routes_around_occupied_tiles_without_crossing_them() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	var blocker := _enemy(world, Vector2i(4, 10))
	blocker.relationship = GridActor.Relationship.FRIENDLY
	var route := world.charge_route(enemy)
	assert_false(route.has(blocker.tile))
	assert_eq(route.size(), 7)
	assert_true(world.cast_skill(&"charge_1", enemy))
	world.continue_cast()
	assert_eq(world.player_tile, route[4])
	world.continue_cast()
	assert_eq(world.player_tile, route[-1])
	assert_ne(world.player_tile, blocker.tile)
	assert_eq(world.hero.rage, 10)


func test_charge_replans_moving_target_and_fails_without_rewards_when_target_dies() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	assert_true(world.cast_skill(&"charge_1", enemy))
	world._move_actor(enemy, Vector2i(9, 12))
	var changed_route := world.charge_route(enemy)
	world.continue_cast()
	assert_eq(world.player_tile, changed_route[4])
	var stopped_tile := world.player_tile
	enemy.alive = false
	world.continue_cast()
	assert_false(world.is_charging())
	assert_eq(world.player_tile, stopped_tile)
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.warrior_progress, 50)
	assert_string_contains("\n".join(world.messages), "Charge stopped")


func test_charge_blocks_other_actions_and_cancellation_but_death_stops_it() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	world.cast_skill(&"charge_1", enemy)
	assert_false(world.move_player(Vector2i.UP))
	assert_false(world.request_melee(enemy))
	assert_false(world.cast_skill(&"battle_shout_1"))
	world.wait_turn()
	world.cancel_cast()
	assert_true(world.is_charging())
	assert_false(world.can_save())
	assert_eq(world.turn_count, 1)
	world.hero.health = 0
	assert_true(world.check_terminal())
	assert_null(world.pending_skill)
	assert_eq(world.hero.warrior_progress, 50)


func test_charge_hotbar_targets_enemy_and_live_ui_cannot_cancel_or_pause_travel() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	world.assign_hotbar(2, &"charge_1")
	var gameplay := _live_gameplay(world)
	gameplay._hotbar_slot_pressed(2)
	assert_true(gameplay.combat_panel.visible)
	assert_same(gameplay.combat_panel.selected, enemy)
	assert_eq(world.turn_count, 0)
	gameplay.combat_panel.confirm()
	assert_true(world.is_charging())
	assert_false(gameplay.combat_panel.visible)
	assert_true(gameplay._cancel_attack.disabled)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	gameplay._input(escape)
	gameplay._open_options()
	gameplay._open_inventory()
	gameplay._open_hero_panel(true)
	gameplay._open_interaction()
	gameplay._cancel_pending_melee()
	assert_false(gameplay.menu.visible)
	assert_false(gameplay.hero_panel.visible)
	assert_false(gameplay.combat_panel.visible)
	assert_true(world.is_charging())
	gameplay._process(1.0)
	assert_eq(world.turn_count, 2)
	gameplay._process(1.0)
	assert_false(world.is_charging())
	assert_eq(world.hero.rage, 10)


func test_friendly_bump_opens_that_contacts_conversation_without_spending_a_turn() -> void:
	var world := ValleyRoute.create_world(97, false)
	world.player_tile = Vector2i(30, 34)
	var trainer := world.actor_at(Vector2i(31, 34))
	var gameplay := _live_gameplay(world)
	assert_false(world.move_player(Vector2i.RIGHT))
	assert_eq(world.player_tile, Vector2i(30, 34))
	assert_eq(world.turn_count, 0)
	assert_eq(world.movement_credit, 0.0)
	assert_eq(gameplay.menu.page, "conversation")
	assert_false(gameplay.combat_panel.visible)
	var train_button: Button
	for button in gameplay.menu._buttons:
		if button.text == "Train":
			train_button = button
	assert_not_null(train_button)
	if train_button != null:
		train_button.pressed.emit()
		assert_eq(gameplay.menu.page, "trainer")
		assert_eq(gameplay.menu._trainer, trainer.service)
	assert_eq(world.turn_count, 0)


func test_friendly_bump_greets_plain_npc_without_attack_confirmation() -> void:
	var world := _world()
	var friendly := _enemy(world)
	friendly.relationship = GridActor.Relationship.FRIENDLY
	friendly.title = "Helpful Neighbor"
	var gameplay := _live_gameplay(world)
	gameplay._pending_direction = Vector2i.RIGHT
	gameplay._pending_action = true
	gameplay._process(0.0)
	assert_false(gameplay.combat_panel.visible)
	assert_false(gameplay.menu.visible)
	assert_eq(gameplay._feedback.text, "Interacted with Helpful Neighbor.")
	assert_eq(world.turn_count, 0)
	assert_eq(friendly.health, friendly.max_health)
	assert_string_contains(world.messages[-1], "Helpful Neighbor")


func test_charge_rejects_partial_route_and_stops_if_new_occupants_block_arrival() -> void:
	var trapped := _charge_world()
	var target := _enemy(trapped, Vector2i(9, 10))
	for direction in GridWorld.DIRECTIONS:
		trapped.blocked_tiles[trapped.player_tile + direction] = true
	assert_false(trapped.cast_skill(&"charge_1", target))
	assert_eq(trapped.turn_count, 0)
	assert_eq(trapped.hero.warrior_progress, 50)
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	world.cast_skill(&"charge_1", enemy)
	for direction in GridWorld.DIRECTIONS:
		var blocker := _enemy(world, enemy.tile + direction)
		blocker.relationship = GridActor.Relationship.FRIENDLY
	world.continue_cast()
	assert_false(world.is_charging())
	assert_eq(world.player_tile, Vector2i(2, 10))
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.warrior_progress, 50)


func test_charge_minimum_range_rejects_adjacent_targets_and_picker_omits_them() -> void:
	var world := _charge_world()
	var adjacent := _enemy(world, Vector2i(3, 10))
	var diagonal := _enemy(world, Vector2i(3, 11))
	var distant := _enemy(world, Vector2i(4, 10))
	distant.stunned_until = 999
	var skill := world.hero.find_skill(&"charge_1")
	assert_eq(world.spell_candidates(skill), [distant])
	for enemy in [adjacent, diagonal]:
		assert_false(world.cast_skill(&"charge_1", enemy))
		assert_false(enemy.engaged)
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.warrior_progress, 50)
	assert_false(world.hero.cooldowns.has("charge"))
	assert_string_contains(skill.description, "Minimum range: 2 tiles")
	assert_string_contains(skill.description, "10-turn cooldown")
	assert_true(world.cast_skill(&"charge_1", distant))
	world.continue_cast()
	assert_false(world.is_charging())
	assert_eq(world.hero.rage, 10)


func test_charge_cooldown_starts_on_arrival_and_expires_after_ten_turns() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(9, 10))
	enemy.stunned_until = 999
	assert_true(world.cast_skill(&"charge_1", enemy))
	assert_false(world.hero.cooldowns.has("charge"))
	world.continue_cast()
	assert_false(world.hero.cooldowns.has("charge"), "Travel has not completed.")
	world.continue_cast()
	assert_eq(world.turn_count, 3)
	assert_eq(world.hero.cooldowns.get("charge"), 13)
	world._move_actor(enemy, Vector2i(10, 10))
	assert_false(world.cast_skill(&"charge_1", enemy))
	assert_eq(world.turn_count, 3)
	for index in range(9):
		world.wait_turn()
	assert_eq(world.turn_count, 12)
	assert_false(world.cast_skill(&"charge_1", enemy))
	assert_eq(world.hero.warrior_progress, 51)
	world.wait_turn()
	assert_eq(world.turn_count, 13)
	assert_true(world.cast_skill(&"charge_1", enemy))
	assert_true(world.is_charging())


func test_charge_can_finish_when_target_enters_minimum_range_during_windup() -> void:
	var world := _charge_world()
	var enemy := _enemy(world, Vector2i(4, 10))
	enemy.stunned_until = 999
	assert_true(world.cast_skill(&"charge_1", enemy))
	world._move_actor(enemy, Vector2i(3, 10))
	world.continue_cast()
	assert_false(world.is_charging())
	assert_eq(world.player_tile, Vector2i(2, 10))
	assert_eq(world.hero.rage, 10)
	assert_eq(world.hero.warrior_progress, 51)
	assert_eq(world.hero.cooldowns.get("charge"), 12)


func test_charge_arrival_cooldown_survives_save_and_failed_charge_starts_none() -> void:
	var game := GameSession.new()
	game.world = _charge_world()
	var enemy := _enemy(game.world, Vector2i(4, 10))
	enemy.stunned_until = 999
	game.world.cast_skill(&"charge_1", enemy)
	game.world.continue_cast()
	enemy.alive = false
	enemy.health = 0
	game.world.wait_turn()
	var restored := SaveCodec.restore(SaveCodec.capture(game), false)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.hero.cooldowns.get("charge"), 12)
		assert_eq(restored.turn_count, 3)
	var world := _charge_world()
	var target := _enemy(world, Vector2i(4, 10))
	target.stunned_until = 999
	world.cast_skill(&"charge_1", target)
	target.alive = false
	world.continue_cast()
	assert_false(world.hero.cooldowns.has("charge"))
	assert_eq(world.hero.warrior_progress, 50)


func test_charge_reaches_nine_tiles_and_picker_includes_extended_range() -> void:
	for distance in [8, 9]:
		var world := _charge_world()
		var enemy := _enemy(world, world.player_tile + Vector2i(distance, 0))
		enemy.stunned_until = 999
		var too_far := _enemy(world, world.player_tile + Vector2i(10, 0))
		assert_eq(world.spell_candidates(world.hero.find_skill(&"charge_1")), [enemy])
		assert_true(world.cast_skill(&"charge_1", enemy))
		while world.is_charging():
			world.continue_cast()
		assert_eq(world.turn_count, 3)
		assert_eq(GridWorld.tile_distance(world.player_tile, enemy.tile), 1)
		assert_eq(world.hero.rage, 10)
		assert_eq(world.hero.warrior_progress, 51)
		assert_false(too_far.engaged)
