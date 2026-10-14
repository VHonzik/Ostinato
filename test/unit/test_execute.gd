extends GutTest

var _original_options: GlobalOptions
var _options_path: String


func before_each() -> void:
	_original_options = GlobalOptions.new()
	_options_path = "user://test_execute_options_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json"


func after_each() -> void:
	_original_options.apply_bindings()
	if FileAccess.file_exists(_options_path):
		DirAccess.remove_absolute(_options_path)


func _world() -> GridWorld:
	var world := GridWorld.new(Rect2i(0, 0, 16, 16), Vector2i(5, 5), 97, false)
	world.hero.warrior_progress = 150
	world.train(&"Warrior", &"execute_1")
	world.hero.melee.hit = 100.0
	world.hero.melee.critical = 0.0
	world.hero.melee.damage_min = 20.0
	world.hero.melee.damage_max = 20.0
	world.hero.melee.attack_power = 0
	world.hero.swing.remaining = 10.0
	world.hero.swing._active = true
	return world


func _enemy(world: GridWorld, tile: Vector2i = Vector2i(6, 5)) -> GridActor:
	var enemy := GridActor.new(tile)
	enemy.title = "Enemy"
	enemy.relationship = GridActor.Relationship.NEUTRAL
	enemy.max_health = 10000
	enemy.health = 2000
	enemy.awards_experience = false
	enemy.stunned_until = 999
	enemy.melee.armor = 0
	enemy.melee.dodge = 0.0
	world.actors.append(enemy)
	return enemy


func test_execute_health_boundary_is_inclusive_and_does_not_round_up_small_targets() -> void:
	for maximum in [10000, 101, 5]:
		var world := _world()
		var enemy := _enemy(world)
		enemy.max_health = maximum
		enemy.health = floori(maximum * 0.2) + 1
		world.hero.rage = 30
		assert_false(world.cast_skill(&"execute_1", enemy))
		assert_string_contains(world.messages[-1], "at or below 20% health")
		assert_eq(world.turn_count, 0)
		assert_eq(world.hero.rage, 30)
		assert_eq(world.hero.warrior_progress, 150)
		assert_false(enemy.engaged)
		assert_eq(enemy.relationship, GridActor.Relationship.NEUTRAL)
		assert_null(world.auto_attack_target)
		enemy.health -= 1
		assert_true(world.cast_skill(&"execute_1", enemy))
		assert_eq(world.turn_count, 1)
		assert_eq(world.hero.warrior_progress, 151)


func test_execute_spends_available_rage_between_minimum_and_cap_and_scales_damage() -> void:
	for rage in [15, 16, 23, 30, 100]:
		var world := _world()
		var enemy := _enemy(world)
		world.hero.rage = rage
		var spent := mini(rage, 30)
		assert_true(world.cast_skill(&"execute_1", enemy))
		assert_eq(world.hero.rage, rage - spent)
		assert_eq(enemy.health, 2000 - (55 + (spent - 15) * 2))
		assert_true("\n".join(world.messages).contains("Execute: spent %d rage." % spent))
		assert_eq(world.turn_count, 1)


func test_invalid_execute_preserves_resources_points_time_and_attack_target() -> void:
	for reason in ["rage", "range", "sight", "dead", "friendly", "absent", "cooldown"]:
		var world := _world()
		var enemy := _enemy(world)
		world.hero.learn_skill(SkillRank.catalog(&"relentless_assault_1"))
		world.hero.combo_points = 2
		world.hero.rage = 30
		var prior := _enemy(world, Vector2i(4, 5))
		world.last_attacked_enemy = prior
		world.auto_attack_target = prior
		match reason:
			"rage":
				world.hero.rage = 14
			"range":
				enemy.tile = Vector2i(8, 5)
			"sight":
				world.sight_blockers[enemy.tile] = true
			"dead":
				enemy.health = 0
				enemy.alive = false
			"friendly":
				enemy.relationship = GridActor.Relationship.FRIENDLY
			"absent":
				world.actors.erase(enemy)
			"cooldown":
				world.global_cooldown_until = 1
		var rage_before := world.hero.rage
		var health_before := enemy.health
		assert_false(world.cast_skill(&"execute_1", enemy), reason)
		assert_eq(world.hero.rage, rage_before, reason)
		assert_eq(world.hero.combo_points, 2, reason)
		assert_eq(enemy.health, health_before, reason)
		assert_eq(world.hero.warrior_progress, 150, reason)
		assert_eq(world.turn_count, 0, reason)
		assert_almost_eq(world.hero.swing.remaining, 10.0, 0.00001, reason)
		assert_same(world.last_attacked_enemy, prior, reason)
		assert_same(world.auto_attack_target, prior, reason)
		assert_null(world.pending_skill, reason)


func test_execute_is_one_turn_without_cooldown_even_with_haste_and_casting_credit() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.rage = 100
	world.hero.haste = 4.0
	world.hero.casting_credit = 0.9
	world.hero.swing.remaining = 3.5
	assert_true(world.cast_skill(&"execute_1", enemy))
	assert_true(world.cast_skill(&"execute_1"))
	assert_eq(world.turn_count, 2)
	assert_eq(world.hero.rage, 40)
	assert_eq(world.hero.warrior_progress, 152)
	assert_almost_eq(world.hero.swing.remaining, 1.5, 0.00001)
	assert_almost_eq(world.hero.casting_credit, 0.9, 0.00001)
	assert_false(world.hero.cooldowns.has("execute"))
	assert_null(world.pending_skill)


func test_execute_uses_physical_buffs_armor_and_crit_for_whole_damage() -> void:
	var world := _world()
	var enemy := _enemy(world)
	world.hero.rage = 30
	world.hero.melee.damage_multiplier = 1.1
	world.hero.melee.critical = 100.0
	world.hero.melee.damage_min = 30.0
	world.hero.melee.damage_max = 30.0
	enemy.melee.armor = 485
	assert_true(world.cast_skill(&"execute_1", enemy))
	assert_eq(enemy.health, 2000 - 110,
		"(30 * 1.5 + 25 + 30) * 1.1 * 0.5 = 55, then crit * 2.")
	assert_eq(world.hero.rage, 0)


func test_execute_misses_and_dodges_spend_rage_and_award_selected_class_xp_without_points() -> void:
	for dodged in [false, true]:
		var world := _world()
		var enemy := _enemy(world)
		world.hero.learn_skill(SkillRank.catalog(&"relentless_assault_1"))
		world.hero.combo_points = 2
		world.hero.rage = 23
		if dodged:
			enemy.melee.dodge = 100.0
		else:
			world.hero.melee.hit = -1000.0
		assert_true(world.cast_skill(&"execute_1", enemy))
		assert_eq(enemy.health, 2000)
		assert_eq(world.hero.rage, 0)
		assert_eq(world.hero.warrior_progress, 151)
		assert_eq(world.hero.combo_points, 2)


func test_retained_execute_builds_points_across_targets_but_grants_neither_class_xp_track() -> void:
	var world := _world()
	var first := _enemy(world)
	var second := _enemy(world, Vector2i(4, 5))
	world.hero.selected_class = &"Shaman"
	world.hero.learn_skill(SkillRank.catalog(&"relentless_assault_1"))
	world.hero.rage = 100
	world.hero.combo_points = 3
	assert_true(world.cast_skill(&"execute_1", first))
	assert_eq(world.hero.combo_points, 4)
	assert_true(world.cast_skill(&"execute_1", second))
	assert_eq(world.hero.combo_points, 5)
	world.hero.rage = 30
	assert_true(world.cast_skill(&"execute_1", second))
	assert_eq(world.hero.combo_points, 5)
	assert_eq(world.hero.warrior_progress, 150)
	assert_eq(world.hero.progression_points(&"Shaman"), 0)
	assert_same(world.last_attacked_enemy, second)


func test_execute_spends_before_due_swing_and_resolves_before_enemy_without_extra_point_credit() -> void:
	var world := _world()
	var enemy := _enemy(world)
	var responder := _enemy(world, Vector2i(4, 5))
	# Execute faces right. The rear attacker cannot be dodged after aura stat refresh.
	responder.engaged = true
	responder.stunned_until = 0
	responder.melee.hit = 100.0
	responder.melee.critical = 0.0
	responder.melee.damage_min = 1.0
	responder.melee.damage_max = 1.0
	world.hero.learn_skill(SkillRank.catalog(&"relentless_assault_1"))
	# Learning refreshes stats; control the player's attack rolls and base interval.
	world.hero.melee.hit = 100.0
	world.hero.melee.critical = 0.0
	world.hero.melee.damage_min = 20.0
	world.hero.melee.damage_max = 20.0
	world.hero.melee.attack_power = 0
	world.hero.melee.interval = 2.0
	world.hero.rage = 26
	world.hero.swing.remaining = 0.5
	var health_before := world.hero.health
	assert_true(world.cast_skill(&"execute_1", enemy))
	assert_eq(enemy.health, 2000 - 77 - 20)
	assert_eq(world.hero.health, health_before - 1)
	assert_eq(world.hero.rage, 17, "Only the later swing's 14 and incoming hit's 3 remain.")
	assert_eq(world.hero.combo_points, 1, "The active and ordinary swing share one base point this turn.")
	assert_eq(world.hero.warrior_progress, 151)
	var log := "\n".join(world.messages)
	assert_gt(log.find("You ->"), log.find("Execute (hit)"))
	assert_gt(log.find("Enemy ->"), log.find("You ->"))


func test_execute_kill_prevents_due_swings_and_target_response_without_retargeting() -> void:
	var world := _world()
	var enemy := _enemy(world)
	var other := _enemy(world, Vector2i(4, 5))
	other.engaged = true
	enemy.health = 1
	enemy.stunned_until = 0
	world.hero.learn_skill(SkillRank.catalog(&"relentless_assault_1"))
	world.hero.rage = 100
	world.hero.swing.remaining = 0.1
	var health_before := world.hero.health
	assert_true(world.cast_skill(&"execute_1", enemy))
	assert_false(enemy.alive)
	assert_eq(other.health, 2000)
	assert_eq(world.hero.health, health_before)
	assert_eq(world.hero.rage, 70)
	assert_eq(world.hero.combo_points, 1, "Landed killing attacks also build points.")
	assert_null(world.auto_attack_target)
	assert_same(world.last_attacked_enemy, enemy)
	assert_false("\n".join(world.messages).contains("You ->"))
	assert_eq(world.turn_count, 1)


func test_automatic_execute_rejects_ineligible_last_target_without_switching_to_eligible_enemy() -> void:
	for invalid in ["health", "dead", "range"]:
		var world := _world()
		var prior := _enemy(world)
		var eligible := _enemy(world, Vector2i(4, 5))
		prior.engaged = true
		eligible.engaged = true
		world.last_attacked_enemy = prior
		world.auto_attack_target = prior
		world.hero.rage = 30
		match invalid:
			"health":
				prior.health = 2001
			"dead":
				prior.health = 0
				prior.alive = false
			"range":
				prior.tile = Vector2i(8, 5)
		assert_false(world.cast_skill(&"execute_1"), invalid)
		assert_eq(world.turn_count, 0, invalid)
		assert_eq(world.hero.rage, 30, invalid)
		assert_eq(eligible.health, 2000, invalid)
		assert_same(world.last_attacked_enemy, prior, invalid)
		assert_true(world.cast_skill(&"execute_1", eligible), "Explicit selection can change target.")
		assert_same(world.last_attacked_enemy, eligible)


func _live_gameplay(world: GridWorld) -> Gameplay:
	var scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	var main := scene.instantiate() as Control
	add_child_autofree(main)
	var gameplay := main.get_node("GameContainer/GameViewport/Gameplay") as Gameplay
	# Keep saved user bindings out of this fixture and restore the shared input map afterward.
	InputMap.load_from_project_settings()
	gameplay.menu.options = GlobalOptions.new(_options_path)
	gameplay.session.restore(world, 97, 1)
	return gameplay


func test_execute_hotbar_picker_filters_health_range_and_rechecks_on_confirmation() -> void:
	var world := _world()
	world.hotbar[2] = &"execute_1"
	var enemy := _enemy(world)
	var healthy := _enemy(world, Vector2i(4, 5))
	healthy.health = 2001
	var distant := _enemy(world, Vector2i(8, 5))
	world.hero.rage = 30
	var gameplay := _live_gameplay(world)
	gameplay._hotbar_slot_pressed(2)
	assert_true(gameplay.combat_panel.visible)
	assert_eq(gameplay.combat_panel._candidates, [enemy])
	assert_same(gameplay.combat_panel.selected, enemy)
	assert_string_contains(gameplay.combat_panel._detail.text, "spends 30 rage")
	assert_eq(world.turn_count, 0)
	enemy.health = 2001
	gameplay.combat_panel.confirm()
	assert_false(gameplay.combat_panel.visible)
	assert_eq(world.turn_count, 0)
	assert_eq(world.hero.rage, 30)
	assert_eq(world.hero.warrior_progress, 150)
	assert_eq(healthy.health, 2001)
	assert_eq(distant.health, 2000)
	enemy.health = 2000
	world.hero.rage = 23
	gameplay._hotbar_slot_pressed(2)
	assert_true(gameplay.combat_panel.visible)
	assert_string_contains(gameplay.combat_panel._detail.text, "spends 23 rage")
	gameplay.combat_panel.confirm()
	assert_false(gameplay.combat_panel.visible)
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 0)
	assert_eq(world.hero.warrior_progress, 151)
	assert_same(world.last_attacked_enemy, enemy)


func test_execute_hotbar_uses_committed_enemy_and_never_opens_picker_for_another_one() -> void:
	var world := _world()
	world.hotbar[2] = &"execute_1"
	var enemy := _enemy(world)
	_enemy(world, Vector2i(4, 5))
	enemy.engaged = true
	world.last_attacked_enemy = enemy
	world.auto_attack_target = enemy
	world.hero.rage = 100
	var gameplay := _live_gameplay(world)
	gameplay._hotbar_slot_pressed(2)
	assert_false(gameplay.combat_panel.visible)
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 70)
	assert_same(world.last_attacked_enemy, enemy)
	enemy.health = 2001
	gameplay._hotbar_slot_pressed(2)
	assert_false(gameplay.combat_panel.visible)
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 70)
	assert_same(world.last_attacked_enemy, enemy)


func test_execute_checkpoint_notifies_once_teaches_free_without_prior_unlocks_and_remains_learned() -> void:
	var world := GridWorld.new(Rect2i(0, 0, 16, 16), Vector2i(5, 5), 97, false)
	world.hero.warrior_progress = 149
	assert_false(world.train(&"Warrior", &"execute_1"))
	assert_null(world.hero.find_skill(&"execute_1"))
	world.add_class_progress(&"Warrior", 1)
	assert_string_contains(world.messages[-1], "Visit Llane Beshere")
	assert_string_contains(world.messages[-1], "learn Execute")
	var notification_count := world.messages.size()
	world.add_class_progress(&"Warrior", 1)
	assert_eq(world.messages.size(), notification_count)
	world.hero.selected_class = &"Shaman"
	assert_false(world.train(&"Warrior", &"execute_1"))
	world.hero.selected_class = &"Warrior"
	assert_null(world.hero.find_skill(&"charge_1"))
	assert_true(world.train(&"Warrior", &"execute_1"))
	assert_eq(world.hero.warrior_progress, 151)
	assert_eq(world.hero.copper, 0)
	assert_eq(world.turn_count, 0)
	assert_false(world.train(&"Warrior", &"execute_1"))
	assert_true(world.assign_hotbar(2, &"execute_1"))
	var enemy := _enemy(world)
	world.hero.rage = 15
	assert_true(world.cast_skill(&"execute_1", enemy), "Usable immediately after training.")


func _trainer_button(menu: MenuPanel, prefix: String) -> Button:
	for button in menu._buttons:
		if button.text.begins_with(prefix):
			return button
	return null


func test_warrior_trainer_menu_enables_execute_at_checkpoint_and_spell_book_can_assign_it() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	game.world.hero.warrior_progress = 149
	var menu := MenuPanel.new()
	menu.session = game
	menu.active_game = true
	add_child_autofree(menu)
	menu.open_trainer(&"Warrior")
	var learn := _trainer_button(menu, "Execute rank 1")
	assert_not_null(learn)
	if learn == null:
		return
	assert_true(learn.disabled)
	game.world.add_class_progress(&"Warrior", 1)
	menu.open_trainer(&"Warrior")
	learn = _trainer_button(menu, "Execute rank 1")
	assert_false(learn.disabled)
	assert_string_contains(learn.tooltip_text, "at or below 20%")
	learn.pressed.emit()
	assert_not_null(game.world.hero.find_skill(&"execute_1"))
	assert_true(_trainer_button(menu, "Execute rank 1 / Learned").disabled)
	assert_eq(game.world.hero.warrior_progress, 150)
	assert_eq(game.world.turn_count, 0)
	assert_true(game.world.hotbar.has(&"execute_1"), "Learned actives fill an empty slot.")
	var gameplay := _live_gameplay(game.world)
	gameplay.hero_panel.open(game.world.hero, true)
	var rank_button: SkillButton
	for button: SkillButton in gameplay.hero_panel._skill_buttons:
		if button.skill.id == &"execute_1":
			rank_button = button
	assert_not_null(rank_button)
	if rank_button == null:
		return
	rank_button.grab_focus()
	gameplay.hero_panel._assign.pressed.emit()
	gameplay._hotbar_slot_pressed(2)
	assert_eq(game.world.hotbar[2], &"execute_1")
	assert_eq(game.world.turn_count, 0)
	await get_tree().process_frame


func test_execute_learning_and_hotbar_roundtrip_in_revision_14_and_survive_death() -> void:
	var game := GameSession.new()
	game.development_build = false
	game.new_game(97)
	game.world.hero.warrior_progress = 150
	var before := SaveCodec.restore(SaveCodec.capture(game), false)
	assert_not_null(before)
	if before == null:
		return
	assert_null(before.hero.find_skill(&"execute_1"))
	game.restore(before, 97, 1)
	assert_true(game.world.train(&"Warrior", &"execute_1"))
	game.world.hero.learn_skill(SkillRank.catalog(&"relentless_assault_1"))
	assert_true(game.world.assign_hotbar(19, &"execute_1"))
	game.world.hero.rage = 29
	game.world.hero.combo_points = 2
	game.world.hero.swing.remaining = 1.75
	assert_true(game.world.can_save())
	var payload := SaveCodec.capture(game)
	var restored := SaveCodec.restore(payload, false)
	assert_not_null(restored)
	if restored == null:
		return
	assert_not_null(restored.hero.find_skill(&"execute_1"))
	assert_eq(restored.hotbar[19], &"execute_1")
	assert_eq(restored.hero.rage, 29)
	assert_eq(restored.hero.combo_points, 2)
	assert_almost_eq(restored.hero.swing.remaining, 1.75, 0.00001)
	var invalid := payload.duplicate(true)
	invalid.hero.warrior_progress = 149
	invalid.class_progress.Warrior = 149
	assert_null(SaveCodec.restore(invalid, false), "Learning cannot precede its XP checkpoint.")
	assert_not_null(restored.hero.find_skill(&"execute_1"), "Failed restore preserves live state.")
	game.restore(restored, 97, 1)
	var old_world := game.world
	game.world.hero.health = 0
	assert_true(game.restart_after_death())
	assert_not_null(game.world.hero.find_skill(&"execute_1"))
	assert_eq(game.world.hotbar[19], &"execute_1")
	assert_eq(game.world.hero.warrior_progress, 150)
	assert_eq([game.world.hero.rage, game.world.hero.combo_points], [0, 0])
	assert_false(old_world.cast_skill(&"execute_1"), "A dead attempt cannot act.")
	assert_true(game.world.can_save())


func test_execute_terminal_kill_spends_single_boundary_and_stops_swings_and_enemy_actions() -> void:
	var world := _world()
	var stalker := _enemy(world)
	stalker.health = 1
	stalker.stalker = true
	var other := _enemy(world, Vector2i(4, 5))
	other.engaged = true
	other.stunned_until = 0
	other.melee.hit = 100.0
	other.melee.damage_min = 1000.0
	other.melee.damage_max = 1000.0
	world.hero.health = 1
	world.hero.rage = 100
	world.hero.swing.remaining = 0.0
	world.hero.haste = 20.0
	assert_true(world.cast_skill(&"execute_1", stalker))
	assert_eq(world.attempt_state, GridWorld.AttemptState.COMPLETED)
	assert_eq(world.turn_count, 1)
	assert_eq(world.hero.rage, 70)
	assert_eq(world.hero.warrior_progress, 151)
	assert_eq(world.hero.health, 1)
	assert_eq(other.health, 2000)
	assert_false(world.can_save())
	assert_false(world.cast_skill(&"execute_1", other))
	world.wait_turn()
	assert_eq(world.turn_count, 1)
